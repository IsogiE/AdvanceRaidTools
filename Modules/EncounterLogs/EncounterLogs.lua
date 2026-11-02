local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/EncounterLogs/EncounterLogs")

local MODULE_NAME = "EncounterLogs"
local PREFIX_LOG = "ART_ELOG"
local PREFIX_COLLECT = "ART_ELOG_COL"
local COLLECTOR_CHARACTERS = {["isogichi-draenor"] = true}
local MAX_COLLECTOR_RANK = 2
local LOG_FORMAT = 2
local MAX_LINES = 5000
local MAX_LINE_CHARS = 200
local MAX_TEXT_CHARS = 250000
local MAX_ERRORS = 10
local MAX_REPORTS_PER_PULL = 40
local PRE_START_WINDOW = 12
local MAX_PENDING_LINES = 60
local SEND_DELAY_MIN, SEND_DELAY_MAX = 1, 8
local COLLECTOR_TTL = 15 * 60
local PULL_MATCH_WINDOW = 15
local ANNOUNCE_DEBOUNCE = 5
local BOSS_UNITS = {}
for index = 1, 10 do BOSS_UNITS["boss" .. index] = true end
local ADD_UNITS = {target = true, focus = true}
for index = 1, 40 do ADD_UNITS["nameplate" .. index] = true end
local CAST_EVENTS = {
    UNIT_SPELLCAST_START = "cast start", UNIT_SPELLCAST_SUCCEEDED = "cast success",
    UNIT_SPELLCAST_STOP = "cast stop", UNIT_SPELLCAST_INTERRUPTED = "cast interrupted",
    UNIT_SPELLCAST_FAILED = "cast failed", UNIT_SPELLCAST_CHANNEL_START = "channel start",
    UNIT_SPELLCAST_CHANNEL_STOP = "channel stop"
}
local CAST_BAR_LAST = {UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_CHANNEL_STOP = true}
local CAST_INFO = {UNIT_SPELLCAST_START = "UnitCastingInfo", UNIT_SPELLCAST_CHANNEL_START = "UnitChannelInfo"}
local CAPTURE_EVENTS = {
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = "OnEngageUnit",
    ENCOUNTER_TIMELINE_EVENT_ADDED = "OnTimelineEvent",
    ENCOUNTER_TIMELINE_EVENT_REMOVED = "OnTimelineEvent",
    ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = "OnTimelineStateChanged",
    ENCOUNTER_WARNING = "OnEncounterWarning",
    UNIT_TARGETABLE_CHANGED = "OnBossState", UNIT_FLAGS = "OnBossState", UNIT_FACTION = "OnBossState",
    UNIT_POWER_UPDATE = "OnBossPower", UNIT_ABSORB_AMOUNT_CHANGED = "OnBossShield",
    NAME_PLATE_UNIT_REMOVED = "OnNameplateRemoved", UPDATE_EXTRA_ACTIONBAR = "OnExtraButton",
    RAID_BOSS_EMOTE = "OnBossEmote", RAID_BOSS_WHISPER = "OnBossEmote", CHAT_MSG_MONSTER_YELL = "OnBossEmote",
    ZONE_CHANGED = "OnZoneChanged", ZONE_CHANGED_INDOORS = "OnZoneChanged",
    ZONE_CHANGED_NEW_AREA = "OnZoneChanged", PLAYER_MAP_CHANGED = "OnZoneChanged"
}
local EMOTE_KINDS = {RAID_BOSS_EMOTE = "emote", RAID_BOSS_WHISPER = "whisper", CHAT_MSG_MONSTER_YELL = "yell"}
local ENCOUNTER_SOURCE = Enum and Enum.EncounterTimelineEventSource and Enum.EncounterTimelineEventSource.Encounter or 0
local RANGE_ITEM = 32825
local MAX_EMOTE_CHARS = 100

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

local function isTrue(v)
    return not E:IsSecret(v) and v and true or false
end

local function flag(v)
    if E:IsSecret(v) then return "?" end
    if v == nil then return "nil" end
    return v and "yes" or "no"
end

local function clean(v, limit)
    local s = E:SafeString(v)
    if not s then return value(v) end
    s = s:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s:sub(1, limit or MAX_LINE_CHARS)
end

local function castBarKey(v)
    if not E:IsSecret(v) and v ~= nil then return tostring(v) end
end

local function isAddUnit(unit)
    if not ADD_UNITS[unit] then return false end
    if isTrue(UnitIsUnit(unit, "player")) or isTrue(UnitIsFriend("player", unit)) then return false end
    for boss in pairs(BOSS_UNITS) do
        if isTrue(UnitIsUnit(unit, boss)) then return false end
    end
    return true
end

local function npcTag(unit)
    local guid = UnitGUID(unit)
    if E:IsSecret(guid) or type(guid) ~= "string" then return "?" end
    local npc, spawn = guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-(%x+)$")
    return npc and (npc .. ":" .. spawn:sub(-6)) or "?"
end

local function rangeTag(unit)
    if not (C_Item and C_Item.IsItemInRange) then return "?" end
    if InCombatLockdown() and not isTrue(UnitCanAttack("player", unit)) then return "?" end
    local ok, inRange = pcall(C_Item.IsItemInRange, RANGE_ITEM, unit)
    if not ok or E:IsSecret(inRange) or inRange == nil then return "?" end
    return inRange and "60" or "far"
end

local function addTag(unit)
    return ("lvl=%s mark=%s npc=%s range=%s"):format(number(UnitLevel(unit)) or "?",
        number(GetRaidTargetIndex(unit)) or "-", npcTag(unit), rangeTag(unit))
end

local function castDetails(event, unit)
    local getInfo = CAST_INFO[event] and _G[CAST_INFO[event]]
    if not getInfo then return end
    local results = {getInfo(unit)}
    local startMS, endMS = number(results[4]), number(results[5])
    local locked = results[event == "UNIT_SPELLCAST_START" and 8 or 7]
    local len = startMS and endMS and endMS >= startMS and (endMS - startMS) / 1000 or nil
    local kick = not E:IsSecret(locked) and locked ~= nil and (locked and "no" or "yes") or nil
    return len, kick
end

local function hasExtraButton()
    local check = C_ActionBar and C_ActionBar.HasExtraActionBar or HasExtraActionBar
    if not check then return nil end
    local shown = check()
    if E:IsSecret(shown) then return nil end
    return shown and true or false
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
    local castBar = (E:SafeString(barText) or ""):find("^<") ~= nil
    if self.active and self.active.sawTimer and not castBar then return end
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

function Mod:OnBigWigsMessage(key, messageText, color)
    self:Log(("BW message: key=%s text=%s color=%s"):format(value(key), clean(messageText, 80), value(color)))
end

function Mod:OnBigWigsSound(key, sound)
    self:Log(("BW sound: key=%s sound=%s"):format(value(key), value(sound)))
end

function Mod:OnUnitCast(event, unit, castGUID, spellID, castBarID, interruptedCastBarID)
    local capture = self.active
    if not capture or E:IsSecret(unit) then return end
    local castBar = castBarKey(CAST_BAR_LAST[event] and interruptedCastBarID or castBarID)
    local seenKey = castBar and (event .. castBar)
    if BOSS_UNITS[unit] then
        if seenKey then capture.castBars[seenKey] = true end
        local len = castDetails(event, unit)
        local name = C_Spell and C_Spell.GetSpellName and not E:IsSecret(spellID) and spellID and C_Spell.GetSpellName(spellID)
        self:Log(("%s %s: spell=%s%s castBar=%s%s%s"):format(unit, CAST_EVENTS[event] or event, value(spellID),
            name and (" (" .. name .. ")") or "", value(castBarID),
            interruptedCastBarID ~= nil and (" interrupted=" .. value(interruptedCastBarID)) or "",
            len and (" len=%.1f"):format(len) or ""))
        return
    end
    if not isAddUnit(unit) or (seenKey and capture.castBars[seenKey]) then return end
    if seenKey then capture.castBars[seenKey] = true end
    local len, kick = castDetails(event, unit)
    local tag = addTag(unit)
    if unit:find("^nameplate") then capture.addTokens[unit] = tag end
    self:Log(("add %s: unit=%s spell=%s %s%s%s%s castBar=%s"):format(CAST_EVENTS[event] or event, unit, value(spellID), tag,
        len and (" len=%.1f"):format(len) or "", kick and (" kick=" .. kick) or "",
        CAST_BAR_LAST[event] and (" by=" .. value(castBarID)) or "", value(castBar)))
end

function Mod:OnNameplateRemoved(_, unit)
    local capture = self.active
    if not capture or E:IsSecret(unit) or not capture.addTokens[unit] then return end
    local tag = capture.addTokens[unit]
    capture.addTokens[unit] = nil
    local dead = UnitIsDead(unit)
    if isTrue(dead) then
        self:Log(("add died: unit=%s %s"):format(unit, tag))
    else
        self:Log(("add lost: unit=%s dead=%s %s"):format(unit, flag(dead), tag))
    end
end

function Mod:BossState(unit)
    return ("attackable=%s friendly=%s"):format(flag(UnitCanAttack("player", unit)), flag(UnitIsFriend("player", unit)))
end

function Mod:BossPower(unit)
    local power, maxPower = number(UnitPower(unit)), number(UnitPowerMax(unit))
    if not power or not maxPower or maxPower <= 0 then return end
    return math.floor(power / maxPower * 10 + 1e-6) * 10
end

function Mod:BossShield(unit)
    local amount = number(UnitGetTotalAbsorbs(unit))
    return amount and math.floor(amount)
end

function Mod:SnapshotBoss(unit)
    local capture = self.active
    capture.bossState[unit] = self:BossState(unit)
    capture.bossPower[unit] = self:BossPower(unit)
    local shield = self:BossShield(unit)
    capture.bossShield[unit] = shield and shield > 0
end

function Mod:ForgetBoss(unit)
    local capture = self.active
    capture.bossState[unit], capture.bossPower[unit], capture.bossShield[unit] = nil, nil, nil
end

local function bossUnitOf(self, unit)
    return self.active and not E:IsSecret(unit) and BOSS_UNITS[unit] and isTrue(UnitExists(unit))
end

function Mod:OnBossState(_, unit)
    if not bossUnitOf(self, unit) then return end
    local state = self:BossState(unit)
    if self.active.bossState[unit] == state then return end
    self.active.bossState[unit] = state
    self:Log(("boss state: unit=%s %s"):format(unit, state))
end

function Mod:OnBossPower(_, unit)
    if not bossUnitOf(self, unit) then return end
    local bucket = self:BossPower(unit)
    if bucket == nil or self.active.bossPower[unit] == bucket then return end
    self.active.bossPower[unit] = bucket
    self:Log(("boss power: unit=%s pct=%d"):format(unit, bucket))
end

function Mod:OnBossShield(_, unit)
    if not bossUnitOf(self, unit) then return end
    local amount = self:BossShield(unit)
    if amount == nil then return end
    local up = amount > 0
    if self.active.bossShield[unit] == up then return end
    self.active.bossShield[unit] = up
    self:Log(("boss shield: unit=%s up=%s amount=%d"):format(unit, up and "yes" or "no", amount))
end

function Mod:OnExtraButton()
    local capture = self.active
    if not capture then return end
    local shown = hasExtraButton()
    if shown == nil or shown == capture.extraButton then return end
    capture.extraButton = shown
    self:Log("extra button: " .. (shown and "shown" or "hidden"))
end

function Mod:OnBossEmote(event, message)
    if not self.active then return end
    local msg = E:SafeString(message)
    local spell = msg and msg:match("|Hspell:(%d+)")
    self:Log(("boss %s: spell=%s text=%s"):format(EMOTE_KINDS[event] or event, spell or "-", clean(message, MAX_EMOTE_CHARS)))
end

function Mod:ZoneLine()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local sub = text(GetSubZoneText and GetSubZoneText(), 60)
    return ("zone: map=%s sub=%s"):format(number(map) or "?", sub ~= "" and sub or "-")
end

function Mod:OnZoneChanged()
    local capture = self.active
    if not capture then return end
    local line = self:ZoneLine()
    if line == capture.zone then return end
    capture.zone = line
    self:Log(line)
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
    local current, added, removed, levels = self:BossPresence(), {}, {}, {}
    for unit, name in pairs(current) do
        if not capture.presence[unit] then
            added[#added + 1] = unit .. "=" .. name
            levels[#levels + 1] = unit .. ":" .. (number(UnitLevel(unit)) or "?")
            self:SnapshotBoss(unit)
        end
    end
    for unit, name in pairs(capture.presence) do
        if not current[unit] then
            removed[#removed + 1] = unit .. "=" .. name
            self:ForgetBoss(unit)
        end
    end
    table.sort(added); table.sort(removed); table.sort(levels)
    capture.presence = current
    if #added > 0 or #removed > 0 then
        self:Log(("engage: added=%s removed=%s levels=%s"):format(
            #added > 0 and table.concat(added, ",") or "-", #removed > 0 and table.concat(removed, ",") or "-",
            #levels > 0 and table.concat(levels, ",") or "-"))
    end
end

function Mod:OnTimelineEvent(event, info)
    local capture = self.active
    if not capture then return end
    if type(info) ~= "table" then
        if not E:IsSecret(info) and capture.scriptBars[info] then return end
        self:Log(("timeline %s: id=%s"):format(event:match("EVENT_(%a+)$") or event, value(info)))
        return
    end
    local source = info.source
    if not E:IsSecret(source) and source ~= nil and source ~= ENCOUNTER_SOURCE then
        if not E:IsSecret(info.id) and info.id ~= nil then capture.scriptBars[info.id] = true end
        return
    end
    local spellID = info.spellID
    local spellName = info.spellName or (C_Spell and C_Spell.GetSpellName and not E:IsSecret(spellID)
        and spellID and C_Spell.GetSpellName(spellID))
    self:Log(("timeline %s: id=%s spell=%s%s duration=%s queue=%s source=%s"):format(event:match("EVENT_(%a+)$") or event,
        value(info.id), value(spellID), spellName and (" (" .. value(spellName) .. ")") or "", value(info.duration),
        value(info.maxQueueDuration), value(source)))
end

function Mod:OnTimelineStateChanged(_, eventID)
    if not self.active then return end
    if not E:IsSecret(eventID) and self.active.scriptBars[eventID] then return end
    local state
    if C_EncounterTimeline and C_EncounterTimeline.GetEventState and eventID ~= nil and not E:IsSecret(eventID) then
        local ok, result = pcall(C_EncounterTimeline.GetEventState, eventID)
        if ok then state = result end
    end
    local stateName = state
    if state ~= nil and not E:IsSecret(state) and Enum and Enum.EncounterTimelineEventState then
        for name, id in pairs(Enum.EncounterTimelineEventState) do
            if id == state then stateName = name break end
        end
    end
    self:Log(("timeline STATE: id=%s state=%s"):format(value(eventID), value(stateName)))
end

function Mod:OnEncounterWarning(_, info)
    if not self.active or type(info) ~= "table" then return end
    self:Log(("warning: severity=%s duration=%s sound=%s target=%s"):format(value(info.severity),
        value(info.duration), value(info.shouldPlaySound), info.targetGUID == nil and "no" or "yes"))
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
        castBars = {}, addTokens = {}, scriptBars = {}, bossState = {}, bossPower = {}, bossShield = {},
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
    self:Log(("ENCOUNTER_START %s (%d) difficulty=%s size=%d | ART %s | BigWigs %s | %s %s | log %d"):format(
        capture.encounterName, encounterID, value(difficultyID), capture.groupSize, E.version,
        text(C_AddOns.GetAddOnMetadata("BigWigs", "Version"), 32), specName, text(E:GetPlayerRole(), 12), LOG_FORMAT))
    capture.presence = self:BossPresence()
    local units = {}
    for unit, name in pairs(capture.presence) do
        units[#units + 1] = unit .. "=" .. name
        self:SnapshotBoss(unit)
    end
    table.sort(units)
    self:Log("bosses: " .. (#units > 0 and table.concat(units, ",") or "-"))
    capture.zone = self:ZoneLine()
    self:Log(capture.zone)
    capture.extraButton = hasExtraButton()
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, RANGE_ITEM) end
    for event in pairs(CAST_EVENTS) do self:RegisterEvent(event, "OnUnitCast") end
    local validEvent = C_EventUtils and C_EventUtils.IsEventValid
    for event, handler in pairs(CAPTURE_EVENTS) do
        if not validEvent or validEvent(event) then self:RegisterEvent(event, handler) end
    end
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
    for event in pairs(CAPTURE_EVENTS) do self:UnregisterEvent(event) end

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
        success = success == true, incomplete = incomplete == true, lines = #capture.lines,
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
            onStopPull = function(...) self:OnBigWigsStopPull(...) end,
            onMessage = function(...) self:OnBigWigsMessage(...) end,
            onSound = function(...) self:OnBigWigsSound(...) end
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
