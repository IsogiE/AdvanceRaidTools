local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/EncounterLogs/EncounterLogs")

local MODULE_NAME = "EncounterLogs"
local PREFIX_LOG = "ART_ELOG"
local PREFIX_COLLECT = "ART_ELOG_COL"
local COLLECTOR_CHARACTERS = {["isogichi-draenor"] = true}
local MAX_COLLECTOR_RANK = 2
local MAX_LINES = 2500
local MAX_LINE_CHARS = 200
local MAX_TEXT_CHARS = 120000
local MAX_ERRORS = 10
local MAX_REPORTS_PER_PULL = 40
local PRE_START_WINDOW = 12
local MAX_PENDING_LINES = 60
local SEND_DELAY_MIN, SEND_DELAY_MAX = 1, 8
local COLLECTOR_TTL = 15 * 60
local PULL_MATCH_WINDOW = 15
local ANNOUNCE_DEBOUNCE = 5
local BOSS_UNITS = {}
for index = 1, 8 do BOSS_UNITS["boss" .. index] = true end
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = "cast start", UNIT_SPELLCAST_SUCCEEDED = "cast success",
    UNIT_SPELLCAST_STOP = "cast stop", UNIT_SPELLCAST_INTERRUPTED = "cast interrupted",
    UNIT_SPELLCAST_FAILED = "cast failed", UNIT_SPELLCAST_CHANNEL_START = "channel start",
    UNIT_SPELLCAST_CHANNEL_STOP = "channel stop"
}

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true, collect = false, maxPulls = 25, maxDays = 14, maxStorageKB = 4096
})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function value(v)
    if v == nil then return "nil" end
    if E:IsSecret(v) then return "<secret>" end
    return tostring(v)
end

local function number(v)
    if not E:IsSecret(v) and type(v) == "number" and v == v and math.abs(v) < math.huge then return v end
end

local function text(v, limit)
    v = E:SafeString(v)
    return v and v:sub(1, limit) or ""
end

local function normalizeName(name)
    name = E:SafeString(name)
    return name and name:gsub("%s+", ""):lower() or nil
end

local function inRaidInstance()
    return select(2, GetInstanceInfo()) == "raid"
end

local function errorsAvailable()
    return BugGrabber and type(BugGrabber.GetDB) == "function" and type(BugGrabber.GetSessionId) == "function"
end

local function errorSnapshot()
    local snapshot = {}
    if errorsAvailable() then
        for _, err in ipairs(BugGrabber:GetDB()) do
            if type(err) == "table" then snapshot[err] = number(err.counter) or 0 end
        end
    end
    return snapshot
end

function Mod:GetOwnGuild()
    if not IsInGuild() then return nil end
    local guildName, _, rankIndex, guildRealm = GetGuildInfo("player")
    guildName = normalizeName(guildName)
    if not guildName or guildName == "" then return nil end
    local realm = normalizeName(guildRealm)
    if not realm or realm == "" then realm = normalizeName(GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()) end
    return guildName .. "-" .. (realm or ""), number(rankIndex)
end

function Mod:ComputeCollector()
    if COLLECTOR_CHARACTERS[normalizeName(E:GetUnitFullName("player", true)) or ""] then return true end
    local guild, rank = self:GetOwnGuild()
    return rank ~= nil and rank <= MAX_COLLECTOR_RANK
end

function Mod:IsCollector()
    return self.collector == true
end

function Mod:RefreshAccess()
    local collector = self:ComputeCollector()
    if collector ~= self.collector then
        self.collector = collector
        if collector then self:Prune() end
        E:SendMessage("ART_ENCOUNTERLOGS_ACCESS_CHANGED", collector)
        self:ScheduleAnnounce()
    end
end

function Mod:RefreshGuildRanks()
    local ranks, online = {}, {}
    local total = GetNumGuildMembers() or 0
    for index = 1, total do
        local name, _, rankIndex, _, _, _, _, _, isOnline = GetGuildRosterInfo(index)
        local key = normalizeName(name)
        rankIndex = number(rankIndex)
        if key and rankIndex then
            ranks[key] = rankIndex
            if (rankIndex <= MAX_COLLECTOR_RANK or COLLECTOR_CHARACTERS[key]) and isOnline and not E:IsSecret(isOnline) then
                online[#online + 1] = (E:SafeString(name) or key):gsub("%s+", "")
            end
        end
    end
    table.sort(online)
    self.guildRanks, self.onlineOfficers = ranks, online
    self.guildRanksLoaded = total > 0
    self:RefreshAccess()
end

function Mod:RequestGuildRoster()
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

function Mod:IsTrustedCollector(fullName)
    local unit = E:GetGroupUnitByName(fullName)
    if not unit or UnitIsUnit(unit, "player") then return false end
    local inGuild = UnitIsInMyGuild(unit)
    if E:IsSecret(inGuild) or not inGuild then return false end
    local key = normalizeName(E:GetUnitFullName(unit, true))
    if COLLECTOR_CHARACTERS[key or ""] then return true end
    local rank = self.guildRanks[key]
    return rank ~= nil and rank <= MAX_COLLECTOR_RANK
end

function Mod:Announce()
    if self.announceTimer then self.announceTimer:Cancel(); self.announceTimer = nil end
    if not self:IsEnabled() or not self:IsCollector() or not IsInRaid() then return end
    local comms = E:GetModule("Comms")
    if comms:IsEnabled() then comms:Broadcast(PREFIX_COLLECT, self.db.collect == true and "1" or "0", "RAID") end
end

function Mod:SetCollecting(enabled)
    self.db.collect = enabled and true or false
    self:Announce()
end

function Mod:ShouldRecord()
    if not self:IsEnabled() or not inRaidInstance() then return false end
    if self:IsCollector() and self.db.collect == true then return true end
    return #self:GetActiveCollectors() > 0
end

function Mod:ScheduleAnnounce()
    if self.announceTimer then return end
    self.announceTimer = C_Timer.NewTimer(ANNOUNCE_DEBOUNCE, function() self:Announce() end)
end

function Mod:QueryCollectors()
    if not self:IsEnabled() or not IsInRaid() then return end
    local comms = E:GetModule("Comms")
    if comms:IsEnabled() then comms:Broadcast(PREFIX_COLLECT, "?", "RAID") end
end

function Mod:OnCollectorAnnounce(_, message, distribution, sender)
    message = E:SafeString(message)
    if distribution ~= "RAID" or not E:GetGroupUnitByName(sender) then return end
    if message == "?" then
        if self:IsCollector() then self:ScheduleAnnounce() end
        return
    end
    if message ~= "1" and message ~= "0" then return end
    local unit = E:GetGroupUnitByName(sender)
    local fullName = E:GetUnitFullName(unit, true)
    if not fullName then return end
    self.collectors[fullName] = message == "1" and GetTime() or nil
    if not self.guildRanksLoaded then self:RequestGuildRoster() end
end

function Mod:GetActiveCollectors()
    local now, list = GetTime(), {}
    for fullName, seenAt in pairs(self.collectors) do
        if now - seenAt > COLLECTOR_TTL or not E:GetGroupUnitByName(fullName) then
            self.collectors[fullName] = nil
        elseif self:IsTrustedCollector(fullName) then
            list[#list + 1] = fullName
        end
    end
    table.sort(list)
    return list
end

function Mod:Log(message)
    if type(message) ~= "string" and type(message) ~= "number" then return end
    message = E:IsSecret(message) and "<secret>" or tostring(message)
    local capture = self.active
    if not capture then
        local pending = self.pending
        pending[#pending + 1] = {GetTime(), message}
        if #pending > MAX_PENDING_LINES then table.remove(pending, 1) end
        return
    end
    if capture.lineCount >= MAX_LINES then capture.truncated = true; return end
    local line = ("%8.2f | %s"):format(GetTime() - capture.clock, message:sub(1, MAX_LINE_CHARS))
    capture.lines[#capture.lines + 1] = line
    capture.lineCount = capture.lineCount + 1
    capture.chars = capture.chars + #line + 1
    if capture.chars > MAX_TEXT_CHARS then capture.truncated = true end
end

function Mod:OnBigWigsTimer(key, barText, time, maxTime, count, _, isApprox)
    local capture = self.active
    if capture then
        capture.sawTimer = true
        local occurrenceKey = tostring(value(key))
        capture.occurrences[occurrenceKey] = (capture.occurrences[occurrenceKey] or 0) + 1
        self:Log(("BW timer: key=%s text=%s time=%s max=%s count=%s occurrence=%d%s"):format(
            value(key), value(barText), value(time), value(maxTime), value(count),
            capture.occurrences[occurrenceKey], isApprox and " approx" or ""))
    else
        self:Log(("BW timer: key=%s text=%s time=%s"):format(value(key), value(barText), value(time)))
    end
end

function Mod:OnBigWigsStartBar(key, barText, time)
    if self.active and self.active.sawTimer then return end
    self:Log(("BW bar: key=%s text=%s time=%s"):format(value(key), value(barText), value(time)))
end

function Mod:OnBigWigsStopBar(barText)
    self:Log(("BW stop bar: text=%s"):format(value(barText)))
end

function Mod:OnBigWigsStage(_, stage)
    self:Log(("BW stage: %s"):format(value(stage)))
end

function Mod:OnBigWigsPull(duration)
    self:Log(("BW pull timer: %s"):format(value(duration)))
end

function Mod:OnBigWigsStopPull(reason)
    self:Log(("BW pull cancelled: %s"):format(value(reason)))
end

function Mod:OnUnitCast(event, unit, castGUID, spellID, castBarID, interruptedCastBarID)
    if not self.active or E:IsSecret(unit) or not BOSS_UNITS[unit] then return end
    local name = C_Spell and C_Spell.GetSpellName and not E:IsSecret(spellID) and spellID and C_Spell.GetSpellName(spellID)
    self:Log(("%s %s: spell=%s%s castBar=%s%s"):format(unit, CAST_EVENTS[event] or event, value(spellID),
        name and (" (" .. name .. ")") or "", value(castBarID),
        interruptedCastBarID ~= nil and (" interrupted=" .. value(interruptedCastBarID)) or ""))
end

function Mod:BossPresence()
    local presence = {}
    for unit in pairs(BOSS_UNITS) do
        local exists = UnitExists(unit)
        if not E:IsSecret(exists) and exists then presence[unit] = text(UnitName(unit), 40) end
    end
    return presence
end

function Mod:OnEngageUnit()
    local capture = self.active
    if not capture then return end
    local current, added, removed = self:BossPresence(), {}, {}
    for unit, name in pairs(current) do
        if not capture.presence[unit] then added[#added + 1] = unit .. "=" .. name end
    end
    for unit, name in pairs(capture.presence) do
        if not current[unit] then removed[#removed + 1] = unit .. "=" .. name end
    end
    table.sort(added); table.sort(removed)
    capture.presence = current
    if #added > 0 or #removed > 0 then
        self:Log(("engage: added=%s removed=%s"):format(
            #added > 0 and table.concat(added, ",") or "-", #removed > 0 and table.concat(removed, ",") or "-"))
    end
end

function Mod:OnTimelineEvent(event, info)
    if not self.active then return end
    if type(info) ~= "table" then
        self:Log(("timeline %s: id=%s"):format(event:match("EVENT_(%a+)$") or event, value(info)))
        return
    end
    local spellID = info.spellID
    local spellName = info.spellName or (C_Spell and C_Spell.GetSpellName and not E:IsSecret(spellID)
        and spellID and C_Spell.GetSpellName(spellID))
    self:Log(("timeline %s: id=%s spell=%s%s duration=%s"):format(event:match("EVENT_(%a+)$") or event,
        value(info.id), value(spellID), spellName and (" (" .. value(spellName) .. ")") or "", value(info.duration)))
end

function Mod:OnEncounterStart(_, encounterID, encounterName, difficultyID, groupSize)
    if not self:ShouldRecord() then return end
    if self.active then self:Finish(nil, true) end
    if E:IsSecret(encounterID) or E:IsSecret(difficultyID) then return end
    local now = GetTime()
    local capture = {
        encounterID = encounterID, encounterName = text(encounterName, 64), difficulty = difficultyID,
        groupSize = number(groupSize) or 0, started = GetServerTime(), clock = now,
        lines = {}, lineCount = 0, chars = 0, occurrences = {}, presence = {},
        errorBaseline = errorSnapshot()
    }
    for _, pending in ipairs(self.pending) do
        if now - pending[1] <= PRE_START_WINDOW then
            local line = ("%8.2f | %s"):format(pending[1] - now, pending[2]:sub(1, MAX_LINE_CHARS))
            capture.lines[#capture.lines + 1] = line
            capture.lineCount = capture.lineCount + 1
            capture.chars = capture.chars + #line + 1
        end
    end
    wipe(self.pending)
    self.active = capture
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local getSpecInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    local okSpec, specIndex = pcall(function() return getSpec and getSpec() end)
    local okName, specName = pcall(function() return specIndex and getSpecInfo and select(2, getSpecInfo(specIndex)) end)
    specName = (okSpec and okName and E:SafeString(specName)) or "?"
    self:Log(("ENCOUNTER_START %s (%d) difficulty=%s size=%d | ART %s | BigWigs %s | %s %s"):format(
        capture.encounterName, encounterID, value(difficultyID), capture.groupSize, E.version,
        text(C_AddOns.GetAddOnMetadata("BigWigs", "Version"), 32), specName, text(E:GetPlayerRole(), 12)))
    capture.presence = self:BossPresence()
    local units = {}
    for unit, name in pairs(capture.presence) do units[#units + 1] = unit .. "=" .. name end
    table.sort(units)
    self:Log("bosses: " .. (#units > 0 and table.concat(units, ",") or "-"))
    for event in pairs(CAST_EVENTS) do self:RegisterEvent(event, "OnUnitCast") end
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "OnEngageUnit")
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", "OnTimelineEvent")
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED", "OnTimelineEvent")
    E:SendMessage("ART_ENCOUNTERLOGS_UPDATED")
end

function Mod:OnEncounterEnd(_, encounterID, _, _, _, success)
    if self.active and self.active.encounterID == encounterID then self:Finish(success == 1, false) end
end

function Mod:CollectErrors(capture)
    local errors, total = {}, 0
    if not errorsAvailable() then return errors, 0 end
    for _, err in ipairs(BugGrabber:GetDB()) do
        if type(err) == "table" and err.session == BugGrabber:GetSessionId() then
            local count = math.max(0, (number(err.counter) or 0) - (capture.errorBaseline[err] or 0))
            if count > 0 then
                total = total + count
                if #errors < MAX_ERRORS then
                    local message = text(err.message, 300)
                    local addon = message:match("AddOns[/\\]([^/\\]+)[/\\]")
                        or text(err.stack, 2000):match("AddOns[/\\]([^/\\]+)[/\\]") or "?"
                    local offset = math.max(0, (number(err.time) or capture.started) - capture.started)
                    errors[#errors + 1] = ("%8.2f | ERROR x%d %s: %s"):format(offset, count, addon, message)
                end
            end
        end
    end
    return errors, total
end

function Mod:Finish(success, incomplete)
    local capture = self.active
    if not capture then return end
    self.active = nil
    for event in pairs(CAST_EVENTS) do self:UnregisterEvent(event) end
    self:UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")

    local duration = math.max(0, GetTime() - capture.clock)
    local outcome = incomplete and "incomplete" or (success and "kill" or "wipe")
    capture.lines[#capture.lines + 1] = ("%8.2f | ENCOUNTER_END %s%s"):format(duration, outcome,
        capture.truncated and " (log truncated)" or "")
    local errors, totalErrors = self:CollectErrors(capture)
    for _, line in ipairs(errors) do capture.lines[#capture.lines + 1] = line end
    if totalErrors > #errors then
        capture.lines[#capture.lines + 1] = ("%8.2f | %d more errors not shown"):format(duration, totalErrors - #errors)
    end
    local body = table.concat(capture.lines, "\n")
    if #body > MAX_TEXT_CHARS then body = body:sub(1, MAX_TEXT_CHARS) .. "\n... truncated" end

    local report = {
        v = 1, player = E:GetUnitFullName("player", true) or UnitName("player"),
        encounterID = capture.encounterID, encounterName = capture.encounterName,
        difficulty = capture.difficulty, started = capture.started, duration = duration,
        success = success == true, incomplete = incomplete == true, lines = capture.lineCount,
        truncated = capture.truncated == true, errors = totalErrors, art = E.version, text = body
    }
    if self:IsCollector() then self:Store(report, true) end
    if not incomplete then self:ScheduleSend(report) end
end

function Mod:ScheduleSend(report)
    local targets = self:GetActiveCollectors()
    if #targets == 0 then return end
    local delay = SEND_DELAY_MIN + math.random() * (SEND_DELAY_MAX - SEND_DELAY_MIN)
    C_Timer.After(delay, function()
        if not self:IsEnabled() then return end
        local comms = E:GetModule("Comms")
        if not comms:IsEnabled() or not IsInRaid() then return end
        for _, target in ipairs(self:GetActiveCollectors()) do
            comms:SendPayload(PREFIX_LOG, report, target)
        end
    end)
end

function Mod:ValidateReport(data, sender, allowOld)
    if type(data) ~= "table" or data.v ~= 1 or type(data.text) ~= "string" or #data.text > MAX_TEXT_CHARS + 64 then return end
    for _, key in ipairs({"encounterID", "difficulty", "started", "duration", "lines", "errors"}) do
        if not number(data[key]) then return end
    end
    if data.duration > 7200 then return end
    if not allowOld and math.abs(GetServerTime() - data.started - data.duration) > 600 then return end
    return {
        v = 1, player = sender, encounterID = data.encounterID, encounterName = text(data.encounterName, 64),
        difficulty = data.difficulty, started = data.started, duration = data.duration,
        success = data.success == true, incomplete = data.incomplete == true, lines = math.floor(data.lines),
        truncated = data.truncated == true, errors = math.floor(data.errors), art = text(data.art, 32),
        text = data.text
    }
end

function Mod:OnCommReceived(_, message, distribution, sender)
    if distribution ~= "WHISPER" or not self:IsCollector() or self.db.collect ~= true or not IsInRaid() then return end
    if not E:GetGroupUnitByName(sender) or not E:SafeString(message) or #message > 200000 then return end
    self.receivedAt = self.receivedAt or {}
    if GetTime() - (self.receivedAt[sender] or -10) < 2 then return end
    self.receivedAt[sender] = GetTime()
    local data = E:GetModule("Comms"):DecodePayload(message)
    local report = self:ValidateReport(data, sender)
    if report then self:Store(report, false) end
end

function Mod:GetStore()
    local store = E:GetGlobal(MODULE_NAME)
    store.pulls = store.pulls or {}
    return store
end

function Mod:FindPull(report)
    for _, pull in ipairs(self:GetStore().pulls) do
        if pull.encounterID == report.encounterID and pull.difficulty == report.difficulty
            and math.abs(pull.started - report.started) <= PULL_MATCH_WINDOW then return pull end
    end
end

function Mod:Store(report, own)
    local store = self:GetStore()
    local pull = self:FindPull(report)
    if not pull then
        pull = {
            encounterID = report.encounterID, encounterName = report.encounterName, difficulty = report.difficulty,
            started = report.started, duration = report.duration, success = report.success,
            incomplete = report.incomplete, reports = {}
        }
        table.insert(store.pulls, 1, pull)
    elseif own then
        pull.duration, pull.success, pull.incomplete = report.duration, report.success, report.incomplete
    end
    local count = 0
    for _ in pairs(pull.reports) do count = count + 1 end
    if count >= MAX_REPORTS_PER_PULL and not pull.reports[report.player] then return end
    pull.reports[report.player] = report
    self:Prune()
    E:SendMessage("ART_ENCOUNTERLOGS_UPDATED")
end

function Mod:PullSize(pull)
    local size = 0
    for _, report in pairs(pull.reports) do size = size + #(report.text or "") + 200 end
    return size
end

function Mod:Prune()
    local store = self:GetStore()
    local pulls = store.pulls
    table.sort(pulls, function(a, b) return (a.started or 0) > (b.started or 0) end)
    local maxPulls = math.max(1, math.floor(tonumber(self.db.maxPulls) or 25))
    local maxAge = math.max(1, math.floor(tonumber(self.db.maxDays) or 14)) * 86400
    local budget = math.max(256, math.floor(tonumber(self.db.maxStorageKB) or 4096)) * 1024
    local now, used = GetServerTime(), 0
    for index = #pulls, 1, -1 do
        local pull = pulls[index]
        if index > maxPulls or now - (pull.started or 0) > maxAge then table.remove(pulls, index) end
    end
    for index = 1, #pulls do
        used = used + self:PullSize(pulls[index])
        if used > budget then
            for remove = #pulls, index, -1 do table.remove(pulls, remove) end
            break
        end
    end
end

function Mod:GetStorageStats()
    local pulls, reports, bytes = self:GetStore().pulls, 0, 0
    for _, pull in ipairs(pulls) do
        for _ in pairs(pull.reports) do reports = reports + 1 end
        bytes = bytes + self:PullSize(pull)
    end
    return #pulls, reports, bytes / 1024
end

function Mod:DeletePull(pull)
    local pulls = self:GetStore().pulls
    for index, entry in ipairs(pulls) do
        if entry == pull then table.remove(pulls, index); break end
    end
    E:SendMessage("ART_ENCOUNTERLOGS_UPDATED")
end

function Mod:ClearAll()
    wipe(self:GetStore().pulls)
    E:SendMessage("ART_ENCOUNTERLOGS_UPDATED")
end

function Mod:DescribePull(pull)
    local outcome = pull.incomplete and L["Diagnostics_Incomplete"] or (pull.success and L["Diagnostics_Kill"] or L["Diagnostics_Wipe"])
    local count = 0
    for _ in pairs(pull.reports) do count = count + 1 end
    return ("%s - %s (%s, %d:%02d, %d %s)"):format(date("%d/%m %H:%M", pull.started), pull.encounterName, outcome,
        math.floor((pull.duration or 0) / 60), math.floor((pull.duration or 0) % 60), count, L["EncounterLogs_Logs"])
end

function Mod:FormatReport(report)
    if not report then return L["EncounterLogs_NoLogs"] end
    local header = ("%s | %s | %s | %s | ART %s | %d %s%s | %d %s"):format(
        report.encounterName, report.player, date("%Y-%m-%d %H:%M:%S", report.started),
        report.incomplete and L["Diagnostics_Incomplete"] or (report.success and L["Diagnostics_Kill"] or L["Diagnostics_Wipe"]),
        report.art or "?", report.lines or 0, L["EncounterLogs_Lines"], report.truncated and " (truncated)" or "",
        report.errors or 0, L["EncounterLogs_Errors"])
    return header .. "\n" .. string.rep("-", 60) .. "\n" .. (report.text or "")
end

function Mod:ExportPull(pull)
    if not pull then return L["EncounterLogs_NoLogs"] end
    local names = {}
    for name in pairs(pull.reports) do names[#names + 1] = name end
    table.sort(names)
    local parts = {}
    for _, name in ipairs(names) do parts[#parts + 1] = self:FormatReport(pull.reports[name]) end
    return table.concat(parts, "\n\n")
end

local SHARE_TYPE, SHARE_VERSION, MAX_IMPORT_PULLS = "encounterLogs", "ART_ELOG1", 200

function Mod:GetSendTargets()
    local seen, list = {}, {}
    local own = normalizeName(E:GetUnitFullName("player", true))
    local function add(name)
        local key = normalizeName(name)
        if key and key ~= own and not seen[key] then seen[key] = true; list[#list + 1] = name end
    end
    for _, name in ipairs(IsInRaid() and self:GetActiveCollectors() or {}) do add(name) end
    for _, name in ipairs(self.onlineOfficers or {}) do add(name) end
    return list
end

function Mod:SendPull(pull, target)
    if not pull or not E:SafeString(target) or target == "" then return false, L["ImportInvalid"] end
    return E:ShareDataToChat(SHARE_TYPE, self:PullsPayload({pull}), self:DescribePull(pull), "WHISPER", target)
end

function Mod:PullsPayload(list)
    local pulls = {}
    for _, pull in ipairs(list or {}) do
        local reports = {}
        for player, report in pairs(pull.reports or {}) do reports[player] = report end
        pulls[#pulls + 1] = {
            encounterID = pull.encounterID, encounterName = pull.encounterName, difficulty = pull.difficulty,
            started = pull.started, duration = pull.duration, success = pull.success, incomplete = pull.incomplete,
            reports = reports
        }
    end
    return {pulls = pulls}
end

function Mod:ExportPulls(list)
    return E:EncodeShareString(SHARE_TYPE, self:PullsPayload(list))
end

function Mod:SanitizeImport(data)
    if type(data) ~= "table" or type(data.pulls) ~= "table" then return end
    local pulls = {}
    for _, pull in ipairs(data.pulls) do
        if #pulls >= MAX_IMPORT_PULLS then break end
        if type(pull) == "table" and type(pull.reports) == "table" then
            local reports, count = {}, 0
            for player, raw in pairs(pull.reports) do
                player = text(player, 64)
                local report = player ~= "" and self:ValidateReport(raw, player, true)
                if report then reports[player] = report; count = count + 1 end
            end
            if count > 0 then pulls[#pulls + 1] = {reports = reports} end
        end
    end
    return {pulls = pulls}
end

function Mod:MergeImport(data)
    local before = select(2, self:GetStorageStats())
    local pullCount = 0
    for _, pull in ipairs(data.pulls) do
        pullCount = pullCount + 1
        for _, report in pairs(pull.reports) do self:Store(report, false) end
    end
    local after = select(2, self:GetStorageStats())
    return math.max(0, after - before), pullCount
end

function Mod:ImportString(input)
    local data, err = E:DecodeShareString(SHARE_TYPE, input or "")
    if not data then return nil, err or L["ImportInvalid"] end
    data = self:SanitizeImport(data)
    if not data or #data.pulls == 0 then return nil, L["ImportInvalid"] end
    local added, pulls = self:MergeImport(data)
    return added, pulls
end

function Mod:RegisterShareType()
    if E.GetShareType and E:GetShareType(SHARE_TYPE) then return end
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = L["EncounterLogs"],
        sanitize = function(data) return self:SanitizeImport(data) end,
        getImportName = function(data)
            return L["EncounterLogs_ShareName"]:format(data and data.pulls and #data.pulls or 0)
        end,
        confirmTitle = L["EncounterLogs"],
        confirmText = function(data)
            return L["EncounterLogs_ImportConfirm"]:format(data and data.pulls and #data.pulls or 0)
        end,
        onImport = function(data)
            if self:IsCollector() and data and data.pulls then self:MergeImport(data) end
        end
    })
end

function Mod:GetStatusText()
    local pulls, reports, kb = self:GetStorageStats()
    local collectors = IsInRaid() and #self:GetActiveCollectors() or 0
    return L["EncounterLogs_Status"]:format(pulls, reports, kb, collectors)
end

function Mod:OnWorldChanged()
    if self.active and not IsEncounterInProgress() then self:Finish(nil, true) end
    wipe(self.collectors)
    self:RequestGuildRoster()
    self:RefreshAccess()
    self.wasInRaid = IsInRaid()
    self:ScheduleAnnounce()
    self:QueryCollectors()
end

function Mod:OnRosterChanged()
    local inRaid = IsInRaid()
    if not inRaid then wipe(self.collectors) end
    if inRaid and not self.wasInRaid then self:QueryCollectors() end
    self.wasInRaid = inRaid
end

function Mod:OnProfileChanged()
    if self:IsCollector() then self:Prune() end
    self:ScheduleAnnounce()
end

function Mod:OnInitialize()
    self.pending, self.collectors, self.guildRanks = {}, {}, {}
    self.collector = false
    if E.RegisterShareType then self:RegisterShareType() end
end

function Mod:OnEnable()
    E.EncounterLogs = self
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnWorldChanged")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterEvent("READY_CHECK", "ScheduleAnnounce")
    self:RegisterEvent("START_PLAYER_COUNTDOWN", "ScheduleAnnounce")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "RefreshGuildRanks")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "RefreshAccess")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    local comms = E:GetModule("Comms")
    comms:RegisterProtocol(PREFIX_LOG, self)
    comms:RegisterProtocol(PREFIX_COLLECT, function(...) self:OnCollectorAnnounce(...) end)
    local boss = E:GetModule("BossMods", true)
    if boss and boss.BigWigs then
        self.bigWigsSubscription = boss.BigWigs:Subscribe({
            owner = MODULE_NAME,
            onTimer = function(...) self:OnBigWigsTimer(...) end,
            onStartBar = function(...) self:OnBigWigsStartBar(...) end,
            onStopBar = function(...) self:OnBigWigsStopBar(...) end,
            onStage = function(...) self:OnBigWigsStage(...) end,
            onStartPull = function(...) self:OnBigWigsPull(...) end,
            onStopPull = function(...) self:OnBigWigsStopPull(...) end
        })
    end
    self:RequestGuildRoster()
    self:RefreshAccess()
    self:ScheduleAnnounce()
end

function Mod:OnDisable()
    if E.EncounterLogs == self then E.EncounterLogs = nil end
    self:Finish(nil, true)
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.announceTimer then self.announceTimer:Cancel(); self.announceTimer = nil end
    if self.bigWigsSubscription then self.bigWigsSubscription:Unsubscribe(); self.bigWigsSubscription = nil end
    local comms = E:GetModule("Comms")
    comms:UnregisterProtocol(PREFIX_LOG)
    comms:UnregisterProtocol(PREFIX_COLLECT)
    wipe(self.collectors)
end

function E:EncounterLog(message)
    if Mod:IsEnabled() then Mod:Log(message) end
end

_G.ART = _G.ART or {}
E:MountMethods(_G.ART, {
    EncounterLog = function(_, message)
        E:EncounterLog(message)
    end
}, {
    noClobber = true
})
