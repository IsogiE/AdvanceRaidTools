local E, L = unpack(ART)

E:RegisterModuleDefaults("QoL_Diagnostics", {enabled = true, shareWithLeader = false, detailed = true, history = {}})
local Mod = E:NewModule("QoL_Diagnostics", "AceEvent-3.0")
local PREFIX = "ART_PULL_DIAG"
local MAX_PULLS, MAX_ADDONS, MAX_ERRORS = 10, 25, 10
local THRESHOLDS = {5, 10, 50, 100}
local MAX_TIMELINE, MAX_TRACE = 2000, 500

local function number(value)
    if not E:IsSecret(value) and type(value) == "number" and value == value
        and value >= 0 and value < math.huge then return value end
end

local function text(value, limit)
    value = E:SafeString(value)
    return value and value:sub(1, limit) or ""
end

local function addonVersion(name)
    local ok, version = pcall(C_AddOns.GetAddOnMetadata, name, "Version")
    return ok and text(version, 64) or ""
end

local function profilerReady()
    return C_AddOnProfiler and C_AddOnProfiler.IsEnabled and C_AddOnProfiler.IsEnabled()
        and Enum.AddOnProfilerMetric and C_AddOnProfiler.GetAddOnMetric
end

local function metric(name, key)
    local id = Enum.AddOnProfilerMetric[key]
    if not id then return end
    local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, name, id)
    return ok and number(value) or nil
end

local function counters(name)
    local values = {}
    for index, threshold in ipairs(THRESHOLDS) do
        values[index] = metric(name, "CountTimeOver" .. threshold .. "Ms")
        if values[index] == nil then return end
    end
    return values
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

function Mod:Trace(channel, ...)
    local capture = self.active
    if not capture or not capture.detailed then return end
    if #capture.trace >= MAX_TRACE then capture.traceTruncated = true; return end
    local parts = {}
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if E:IsSecret(value) then parts[#parts + 1] = "<restricted>"
        elseif type(value) == "string" then parts[#parts + 1] = value:sub(1, 160)
        elseif type(value) == "number" or type(value) == "boolean" then parts[#parts + 1] = tostring(value) end
    end
    capture.trace[#capture.trace + 1] = {offset = GetTime() - capture.clock,
        channel = text(channel, 80), message = table.concat(parts, " "):sub(1, 320)}
end

function Mod:BeginDispatch()
    if E.DiagnosticTimingEnabled and self.active and self.active.detailed then return debugprofilestop() end
end

function Mod:EndDispatch(owner, event, started)
    local capture = self.active
    if not capture or not started then return end
    local elapsed = math.max(0, debugprofilestop() - started)
    local key = text(owner, 128) .. ":" .. event
    local row = capture.handlers[key]
    if not row then row = {name = key, calls = 0, total = 0, peak = 0}; capture.handlers[key] = row end
    row.calls, row.total, row.peak = row.calls + 1, row.total + elapsed, math.max(row.peak, elapsed)
    if elapsed > 5 then self:Trace(owner, event, ("%.2f ms"):format(elapsed)) end
end

local function activeProfiler()
    local profiler = _G.NumyAddonProfiler
    return profiler and profiler.initialized and profiler.db and profiler.db.mode == "active"
        and type(profiler.OnUpdateActiveMode) == "function" and profiler
end

function Mod:CaptureProfilerTick(profiler)
    local capture = self.active
    if not capture or not capture.detailed then return end
    local bucket = profiler.snapshots and profiler.snapshots.lastBucket
    local tick = bucket and bucket.curTickIndex
    local timestamp = tick and bucket.tickMap and number(bucket.tickMap[tick])
    if not timestamp or timestamp < capture.clock or not bucket.lastTick then return end
    if capture.lastBucket == bucket and capture.lastTick == tick then return end
    capture.lastBucket, capture.lastTick = bucket, tick
    for addon in pairs(profiler.loadedAddons or {}) do
        local values = bucket.lastTick[addon]
        local duration = values and number(values[tick])
        if duration and duration > 5 then
            if #capture.timeline >= MAX_TIMELINE then capture.timelineComplete = false; return end
            capture.timeline[#capture.timeline + 1] = {addon = text(addon, 128),
                offset = math.max(0, timestamp - capture.clock), duration = duration}
        end
    end
end

function Mod:InstallProfilerHooks()
    local profiler = _G.NumyAddonProfiler
    if not profiler or self.hookedProfiler == profiler or type(profiler.OnUpdateActiveMode) ~= "function"
        or type(profiler.SwitchMode) ~= "function" then return end
    self.hookedProfiler = profiler
    hooksecurefunc(profiler, "OnUpdateActiveMode", function() self:CaptureProfilerTick(profiler) end)
    hooksecurefunc(profiler, "SwitchMode", function()
        if self.active then self.active.timelineComplete = false end
    end)
end

function Mod:GetStatusDetails()
    return (profilerReady() and L["Diagnostics_ProfilerReady"] or L["Diagnostics_ProfilerMissing"])
        .. "\n" .. (errorsAvailable() and L["Diagnostics_ErrorsReady"] or L["Diagnostics_ErrorsMissing"])
        .. "\n" .. (activeProfiler() and L["Diagnostics_TimelineReady"] or L["Diagnostics_TimelineMissing"])
        .. "\n" .. (E.DiagnosticTimingEnabled and L["Diagnostics_TimingOn"] or L["Diagnostics_TimingOff"])
end

function Mod:OnEncounterStart(_, encounterID, name, difficulty)
    if select(2, GetInstanceInfo()) ~= "raid" then return end
    if self.active then self:Finish(false, true) end
    self:InstallProfilerHooks()
    local capture = {
        encounterID = encounterID, encounterName = text(name, 128), difficulty = difficulty,
        started = GetServerTime(), clock = GetTime(), baselines = {}, errorBaseline = errorSnapshot(),
        profiler = profilerReady() and true or false, errorCapture = errorsAvailable() and true or false,
        detailed = self.db.detailed == true, marker = {}, timeline = {}, trace = {}, handlers = {}, features = {}, modules = {},
        timelineComplete = self.db.detailed == true and activeProfiler() and true or false
    }
    if capture.profiler then
        for index = 1, C_AddOns.GetNumAddOns() do
            local addon = C_AddOns.GetAddOnInfo(index)
            if addon and C_AddOns.IsAddOnLoaded(addon) then capture.baselines[addon] = counters(addon) end
        end
    end
    local boss = E:GetModule("BossMods", true)
    if boss and boss.features then
        for _, feature in ipairs(boss.features:All()) do
            local module = E:GetModule(feature.moduleName, true)
            if module and module:IsEnabled() and boss:IsFeatureEnabled(feature.key) then
                capture.features[#capture.features + 1] = feature.key
            end
        end
        table.sort(capture.features)
    end
    if E.IterateModules then
        for moduleName, module in E:IterateModules() do
            if module:IsEnabled() then capture.modules[#capture.modules + 1] = moduleName end
        end
        table.sort(capture.modules)
    end
    self.active = capture
    E.RaidDiagnosticsCapture = capture.detailed and E.DiagnosticTimingEnabled and capture or nil
    E:SendMessage("ART_DIAGNOSTICS_UPDATED")
end

function Mod:Finish(success, incomplete)
    local capture = self.active
    if not capture then return end
    self.active = nil
    E.RaidDiagnosticsCapture = nil
    local report = {
        version = 1, encounterID = capture.encounterID, encounterName = capture.encounterName,
        difficulty = capture.difficulty, started = capture.started,
        duration = math.max(0, GetTime() - capture.clock), success = success == true,
        incomplete = incomplete == true, player = E:GetUnitFullName("player", true),
        artVersion = text(E.version, 64), profiler = capture.profiler and profilerReady() and true or false,
        errorCapture = capture.errorCapture and errorsAvailable() and true or false,
        addons = {}, errors = {}, totalErrors = 0, timeline = capture.timeline, trace = capture.trace,
        features = capture.features, modules = capture.modules, handlers = {}, detailed = capture.detailed,
        timelineComplete = capture.timelineComplete, traceTruncated = capture.traceTruncated == true,
        timings = capture.detailed and E.DiagnosticTimingEnabled or false
    }
    for _, row in pairs(capture.handlers) do report.handlers[#report.handlers + 1] = row end
    table.sort(report.handlers, function(a, b)
        if a.peak ~= b.peak then return a.peak > b.peak end
        return a.total > b.total
    end)
    while #report.handlers > 50 do table.remove(report.handlers) end
    if report.profiler then
        for addon, baseline in pairs(capture.baselines) do
            local current = counters(addon)
            local average = metric(addon, "EncounterAverageTime")
            if current and average then
                local row = {name = addon, version = addonVersion(addon), average = average, spikes = {}}
                for index = 1, #THRESHOLDS do row.spikes[index] = math.max(0, current[index] - baseline[index]) end
                if average > 0 or row.spikes[1] > 0 then report.addons[#report.addons + 1] = row end
            end
        end
        table.sort(report.addons, function(a, b)
            for index = #THRESHOLDS, 1, -1 do
                if a.spikes[index] ~= b.spikes[index] then return a.spikes[index] > b.spikes[index] end
            end
            if a.average ~= b.average then return a.average > b.average end
            return a.name < b.name
        end)
        while #report.addons > MAX_ADDONS do table.remove(report.addons) end
    end
    if report.errorCapture then
        for _, err in ipairs(BugGrabber:GetDB()) do
            if type(err) == "table" and err.session == BugGrabber:GetSessionId() then
                local count = math.max(0, (number(err.counter) or 0) - (capture.errorBaseline[err] or 0))
                if count > 0 then
                    report.totalErrors = report.totalErrors + count
                    if #report.errors < MAX_ERRORS then
                        local message = text(err.message, 2048)
                        local addon = message:match("AddOns[/\\]([^/\\]+)[/\\]")
                            or text(err.stack, 4096):match("AddOns[/\\]([^/\\]+)[/\\]") or ""
                        report.errors[#report.errors + 1] = {
                            message = message, stack = text(err.stack, 4096), count = count,
                            addon = text(addon, 128), version = addon ~= "" and addonVersion(addon) or "",
                            offset = math.min(report.duration, math.max(0, (number(err.time) or capture.started) - capture.started))
                        }
                    end
                end
            end
        end
    end
    self:AddReport(report, true)
    if self.db.shareWithLeader and not incomplete then
        E:RunWhenOutOfCombat("Diagnostics:Share", function()
            if not self:IsEnabled() or not self.db.shareWithLeader or GetServerTime() - report.started - report.duration > 120
                or not IsInRaid() or UnitIsGroupLeader("player") then return end
            local comms = E:GetModule("Comms")
            if not comms:IsEnabled() then return end
            for index = 1, GetNumGroupMembers() do
                local unit = "raid" .. index
                if UnitIsGroupLeader(unit) then
                    comms:SendPayload(PREFIX, report, E:GetUnitFullName(unit, true))
                    break
                end
            end
        end)
    end
end

function Mod:OnEncounterEnd(_, encounterID, _, _, _, success)
    if self.active and self.active.encounterID == encounterID then self:Finish(success == 1, false) end
end

function Mod:AddReport(report, own)
    self.db.history = self.db.history or {}
    local pull
    for _, entry in ipairs(self.db.history) do
        if entry.encounterID == report.encounterID and entry.difficulty == report.difficulty
            and math.abs(entry.started - report.started) <= 5 then pull = entry; break end
    end
    if not pull then
        if not own then return end
        pull = {encounterID = report.encounterID, encounterName = report.encounterName,
            difficulty = report.difficulty, started = report.started, reports = {}}
        table.insert(self.db.history, 1, pull)
    end
    local count = 0
    for _ in pairs(pull.reports) do count = count + 1 end
    if count >= 40 and not pull.reports[report.player] then return end
    pull.reports[report.player] = report
    while #self.db.history > MAX_PULLS do table.remove(self.db.history) end
    E:SendMessage("ART_DIAGNOSTICS_UPDATED")
end

function Mod:ValidateReport(data, sender)
    if type(data) ~= "table" or data.version ~= 1 or type(data.addons) ~= "table" or type(data.errors) ~= "table"
        or #data.addons > MAX_ADDONS or #data.errors > MAX_ERRORS then return end
    for _, key in ipairs({"encounterID", "difficulty", "started", "duration", "totalErrors"}) do
        if not number(data[key]) then return end
    end
    if data.duration > 7200 or data.totalErrors > 1000000 or math.abs(GetServerTime() - data.started - data.duration) > 180 then return end
    local report = {version = 1, player = sender, encounterID = data.encounterID, encounterName = text(data.encounterName, 128),
        difficulty = data.difficulty, started = data.started, duration = data.duration, success = data.success == true,
        incomplete = data.incomplete == true, artVersion = text(data.artVersion, 64), profiler = data.profiler == true,
        errorCapture = data.errorCapture == true, totalErrors = data.totalErrors, addons = {}, errors = {},
        detailed = data.detailed == true, timings = data.timings == true, timelineComplete = data.timelineComplete == true,
        traceTruncated = data.traceTruncated == true, timeline = {}, trace = {}, features = {}, modules = {}, handlers = {}}
    for _, row in ipairs(data.addons) do
        if type(row) ~= "table" or not number(row.average) or row.average > 100000 or type(row.spikes) ~= "table" then return end
        local clean = {name = text(row.name, 128), version = text(row.version, 64), average = row.average, spikes = {}}
        for index = 1, #THRESHOLDS do
            if not number(row.spikes[index]) or row.spikes[index] > 10000000 then return end
            clean.spikes[index] = math.floor(row.spikes[index])
        end
        report.addons[#report.addons + 1] = clean
    end
    for _, err in ipairs(data.errors) do
        if type(err) ~= "table" or not number(err.count) or err.count > 1000000 or not number(err.offset) then return end
        report.errors[#report.errors + 1] = {message = text(err.message, 2048), stack = text(err.stack, 4096),
            count = math.floor(err.count), offset = math.min(err.offset, report.duration), addon = text(err.addon, 128), version = text(err.version, 64)}
    end
    for _, key in ipairs({"timeline", "trace", "features", "modules", "handlers"}) do
        if type(data[key]) ~= "table" then return end
    end
    if #data.timeline > MAX_TIMELINE or #data.trace > MAX_TRACE or #data.features > 300 or #data.modules > 300 or #data.handlers > 50 then return end
    for _, row in ipairs(data.timeline) do
        if type(row) ~= "table" or not number(row.offset) or not number(row.duration) or row.duration > 100000 then return end
        report.timeline[#report.timeline + 1] = {addon = text(row.addon, 128), offset = math.min(row.offset, report.duration), duration = row.duration}
    end
    for _, row in ipairs(data.trace) do
        if type(row) ~= "table" or not number(row.offset) then return end
        report.trace[#report.trace + 1] = {offset = math.min(row.offset, report.duration), channel = text(row.channel, 80), message = text(row.message, 320)}
    end
    for _, name in ipairs(data.features) do report.features[#report.features + 1] = text(name, 128) end
    for _, name in ipairs(data.modules) do report.modules[#report.modules + 1] = text(name, 128) end
    for _, row in ipairs(data.handlers) do
        if type(row) ~= "table" or not number(row.calls) or not number(row.total) or not number(row.peak)
            or row.total > 10000000 or row.peak > 100000 then return end
        report.handlers[#report.handlers + 1] = {name = text(row.name, 160), calls = math.floor(row.calls), total = row.total, peak = row.peak}
    end
    return report
end

function Mod:OnCommReceived(_, message, channel, sender)
    if channel ~= "WHISPER" or not IsInRaid() or not UnitIsGroupLeader("player")
        or not E:GetGroupUnitByName(sender) or not E:SafeString(message) or #message > 128000 then return end
    self.receivedAt = self.receivedAt or {}
    if GetTime() - (self.receivedAt[sender] or -10) < 2 then return end
    self.receivedAt[sender] = GetTime()
    local data = E:GetModule("Comms"):DecodePayload(message)
    local report = self:ValidateReport(data, sender)
    if report then self:AddReport(report, false) end
end

function Mod:FormatReport(report)
    if not report then return L["Diagnostics_NoReports"] end
    local outcome = report.incomplete and L["Diagnostics_Incomplete"] or (report.success and L["Diagnostics_Kill"] or L["Diagnostics_Wipe"])
    local lines = {
        ("%s | %s | %s"):format(report.encounterName, report.player or "?", outcome),
        ("%s | %.1fs | ART %s"):format(date("%Y-%m-%d %H:%M:%S", report.started), report.duration, report.artVersion),
        "", L["Diagnostics_PerformanceHeader"]
    }
    if report.profiler then
        for _, row in ipairs(report.addons) do
            lines[#lines + 1] = ("%s (%s): %.3f ms | %d / %d / %d / %d"):format(
                row.name, row.version, row.average, unpack(row.spikes))
        end
    else lines[#lines + 1] = L["Diagnostics_ProfilerMissing"] end
    lines[#lines + 1] = ""
    lines[#lines + 1] = L["Diagnostics_ErrorCount"]:format(report.totalErrors)
    if not report.errorCapture then lines[#lines + 1] = L["Diagnostics_ErrorsMissing"] end
    for _, err in ipairs(report.errors) do
        lines[#lines + 1] = ("\n+%.1fs | %s %s | x%d\n%s\n%s"):format(err.offset, err.addon, err.version, err.count, err.message, err.stack)
    end
    lines[#lines + 1] = "\n" .. L["Diagnostics_Modules"] .. "\n" .. table.concat(report.modules or {}, ", ")
    lines[#lines + 1] = "\n" .. L["Diagnostics_Features"] .. "\n" .. table.concat(report.features or {}, ", ")
    if report.detailed then
        lines[#lines + 1] = "\n" .. L["Diagnostics_Handlers"]
        if not report.timings then lines[#lines + 1] = L["Diagnostics_TimingOff"] end
        for _, row in ipairs(report.handlers or {}) do
            lines[#lines + 1] = ("%s: %d | %.3f / %.3f ms"):format(row.name, row.calls, row.total, row.peak)
        end
        lines[#lines + 1] = "\n" .. L["Diagnostics_Timeline"]
        if not report.timelineComplete then lines[#lines + 1] = L["Diagnostics_TimelineIncomplete"] end
        for _, row in ipairs(report.timeline or {}) do
            lines[#lines + 1] = ("+%.3fs | %s | %.3f ms"):format(row.offset, row.addon, row.duration)
        end
        lines[#lines + 1] = "\n" .. L["Diagnostics_Trace"]
        if report.traceTruncated then lines[#lines + 1] = L["Diagnostics_TraceTruncated"] end
        for _, row in ipairs(report.trace or {}) do
            lines[#lines + 1] = ("+%.3fs | %s | %s"):format(row.offset, row.channel, row.message)
        end
    end
    return table.concat(lines, "\n")
end

function Mod:ClearHistory()
    if self.active then return end
    self.db.history = {}
    E:SendMessage("ART_DIAGNOSTICS_UPDATED")
end

function Mod:OnWorldChanged()
    if self.active and not IsEncounterInProgress() then self:Finish(false, true) end
end

function Mod:OnProfileChanged()
    self.active = nil
    E.RaidDiagnosticsCapture = nil
    E:CancelRunWhenOutOfCombat("Diagnostics:Share")
    E:SendMessage("ART_DIAGNOSTICS_UPDATED")
end

function Mod:OnEnable()
    E.RaidDiagnostics = self
    self:InstallProfilerHooks()
    self:RegisterEvent("ADDON_LOADED", "InstallProfilerHooks")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnWorldChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    E:GetModule("Comms"):RegisterProtocol(PREFIX, self)
end

function Mod:OnDisable()
    E.RaidDiagnostics = nil
    self:Finish(false, true)
    E:CancelRunWhenOutOfCombat("Diagnostics:Share")
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    E:GetModule("Comms"):UnregisterProtocol(PREFIX)
end

E:RegisterQoLFeature("Diagnostics", {
    order = 70, labelKey = "Diagnostics_Title", descKey = "Diagnostics_Desc", moduleName = "QoL_Diagnostics"
})
