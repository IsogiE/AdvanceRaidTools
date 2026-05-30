local E = unpack(ART)

E:RegisterModuleDefaults("PhaseTimers", {
    enabled = true
})

local PhaseTimers = E:NewModule("PhaseTimers", "AceEvent-3.0")

local GetTime = GetTime
local GetInstanceInfo = GetInstanceInfo
local UnitExists = UnitExists
local abs = math.abs
local insert = table.insert
local remove = table.remove

local DEFAULT_PHASE_DEBOUNCE = 5
local RECENT_TIMELINE_WINDOW = 0.3
local DEFAULT_DURATION_TOLERANCE = 0.1

local PHASE_TIMER_REGISTRY = {
    encounters = {}
}

local DIFFICULTY_IDS = {
    [14] = "Normal",
    [15] = "Heroic",
    [16] = "Mythic"
}

local EVENT_TRIGGER_KEYS = {
    ENCOUNTER_TIMELINE_EVENT_ADDED = "timelineAdded",
    ENCOUNTER_TIMELINE_EVENT_REMOVED = "timelineRemoved",
    INSTANCE_ENCOUNTER_ENGAGE_UNIT = "engageUnit"
}

local function normalizeDifficulty(difficulty)
    if type(difficulty) == "number" then
        return DIFFICULTY_IDS[difficulty]
    end
    if type(difficulty) == "string" then
        local lower = difficulty:lower()
        if lower == "mythic" or lower == "m" then
            return "Mythic"
        end
        if lower == "heroic" or lower == "heroicnormal" or lower == "heroic/normal" or lower == "h" then
            return "Heroic"
        end
        if lower == "normal" or lower == "n" then
            return "Normal"
        end
        local id = tonumber(difficulty)
        if id then
            return DIFFICULTY_IDS[id]
        end
    end
    return nil
end

local function currentDifficultyID()
    local _, _, difficultyID = GetInstanceInfo()
    return difficultyID
end

local function encounterTimelineSource()
    return Enum and Enum.EncounterTimelineEventSource and Enum.EncounterTimelineEventSource.Encounter or 0
end

local function encounterTimelineFinishedState()
    return Enum and Enum.EncounterTimelineEventState and Enum.EncounterTimelineEventState.Finished or 2
end

local function isEncounterTimelineInfo(info)
    if type(info) ~= "table" then
        return false
    end
    local source = info.source
    return source == nil or source == 0 or source == encounterTimelineSource()
end

local function durationEquals(value, target, tolerance)
    value = tonumber(value)
    target = tonumber(target)
    if not value or not target then
        return false
    end
    return abs(value - target) <= (tolerance or DEFAULT_DURATION_TOLERANCE)
end

local function durationMatches(info, value, tolerance)
    if type(value) == "table" then
        for _, duration in ipairs(value) do
            if durationEquals(info and info.duration, duration, tolerance) then
                return true
            end
        end
        return false
    end
    return durationEquals(info and info.duration, value, tolerance)
end

local function pruneRecentEvents(events, now)
    local cutoff = now - RECENT_TIMELINE_WINDOW
    while events[1] and events[1].time < cutoff do
        remove(events, 1)
    end
end

local function addRecentEvent(events, info, now)
    pruneRecentEvents(events, now)
    insert(events, {
        time = now,
        info = info
    })
end

local function recentCount(events, now, predicate)
    pruneRecentEvents(events, now)
    local count = 0
    for _, event in ipairs(events) do
        if not predicate or predicate(event.info) then
            count = count + 1
        end
    end
    return count
end

local function recentHasDuration(events, now, durations, tolerance)
    return recentCount(events, now, function(info)
        return durationMatches(info, durations, tolerance)
    end) > 0
end

local function recentDurationCount(events, now, durations, tolerance)
    return recentCount(events, now, function(info)
        return durationMatches(info, durations, tolerance)
    end)
end

local function difficultyKeyFor(difficulty)
    return normalizeDifficulty(difficulty or currentDifficultyID())
end

local function maxPhaseFromDifficultyData(difficultyData)
    local maxPhase = 1
    local phases = difficultyData and difficultyData.phases
    if type(phases) == "table" then
        for phase in pairs(phases) do
            if type(phase) == "number" and phase > maxPhase then
                maxPhase = phase
            end
        end
    end
    return maxPhase
end

local function targetPhase(target, currentPhase)
    if target == "next" then
        return (currentPhase or 1) + 1
    end
    return tonumber(target)
end

local function triggerList(entries)
    if type(entries) ~= "table" then
        return nil
    end
    if type(entries[1]) == "table" then
        return entries
    end
    return {entries}
end

function PhaseTimers:GetData()
    return PHASE_TIMER_REGISTRY
end

function PhaseTimers:RegisterEncounter(encounterID, data)
    encounterID = tonumber(encounterID)
    if not encounterID or type(data) ~= "table" then
        return false
    end

    data.id = encounterID
    PHASE_TIMER_REGISTRY.encounters[encounterID] = data
    return true
end

function PhaseTimers:GetEncounter(encounterID)
    encounterID = tonumber(encounterID or self.currentEncounterID)
    return encounterID and PHASE_TIMER_REGISTRY.encounters[encounterID] or nil
end

function PhaseTimers:GetDifficultyData(encounterID, difficulty)
    local encounter = self:GetEncounter(encounterID)
    local difficulties = encounter and encounter.difficulties
    if type(difficulties) ~= "table" then
        return nil
    end

    local key = difficultyKeyFor(difficulty or self.currentDifficultyID)
    if key and difficulties[key] then
        return difficulties[key], key
    end

    return nil
end

function PhaseTimers:IsActiveEncounter(encounterID, difficulty)
    encounterID = tonumber(encounterID or self.currentEncounterID)
    if not self.encounterStartTime or not self.currentEncounterID or encounterID ~= self.currentEncounterID then
        return false
    end
    if difficulty and normalizeDifficulty(difficulty) then
        return normalizeDifficulty(difficulty) == normalizeDifficulty(self.currentDifficultyID)
    end
    return true
end

function PhaseTimers:GetPhaseStart(encounterID, phase, difficulty)
    phase = tonumber(phase) or 1
    if not self:IsActiveEncounter(encounterID, difficulty) then
        return nil
    end
    if phase == 1 then
        return 0
    end
    local liveStart = self.phaseStarts and self.phaseStarts[phase] or nil
    if liveStart then
        return liveStart
    end

    local difficultyData = self:GetDifficultyData(encounterID, difficulty)
    local staticStart = difficultyData and difficultyData.phases and difficultyData.phases[phase] or nil
    return tonumber(staticStart)
end

function PhaseTimers:GetPhaseRelativeTarget(encounterID, phase, phaseTime, difficulty)
    phaseTime = tonumber(phaseTime)
    if not phaseTime then
        return nil
    end

    local phaseStart = self:GetPhaseStart(encounterID, phase, difficulty)
    if not phaseStart then
        return nil
    end
    return phaseStart + phaseTime
end

function PhaseTimers:GetPhaseRelativeRemaining(encounterID, phase, phaseTime, encounterStartTime, difficulty)
    local target = self:GetPhaseRelativeTarget(encounterID, phase, phaseTime, difficulty)
    if not target or not encounterStartTime then
        return nil
    end
    return target - (GetTime() - encounterStartTime)
end

function PhaseTimers:GetPhaseAtElapsed(encounterID, elapsed, difficulty)
    elapsed = tonumber(elapsed)
    if not elapsed or not self:IsActiveEncounter(encounterID, difficulty) then
        return nil
    end

    local activePhase, activeStart = 1, 0
    for phase, start in pairs(self.phaseStarts or {}) do
        if type(phase) == "number" and type(start) == "number" and start <= elapsed and start >= activeStart then
            activePhase = phase
            activeStart = start
        end
    end
    return activePhase, activeStart
end

function PhaseTimers:GetActivePhase()
    if not self.encounterStartTime then
        return nil
    end
    return self:GetPhaseAtElapsed(self.currentEncounterID, GetTime() - self.encounterStartTime, self.currentDifficultyID)
end

function PhaseTimers:CanSwapPhase(now, trigger)
    return self.phaseSwapTime and now >= self.phaseSwapTime + (trigger.debounce or DEFAULT_PHASE_DEBOUNCE)
end

function PhaseTimers:TriggerContextMatches(target, trigger, now)
    local phase = targetPhase(target, self.currentPhase)
    if not phase then
        return false
    end

    local expectedFrom = trigger.from or (target ~= "next" and phase - 1 or nil)
    if expectedFrom and expectedFrom ~= self.currentPhase then
        return false
    end
    return self:CanSwapPhase(now, trigger)
end

function PhaseTimers:TriggerConditionsMatch(eventKey, trigger, info, now)
    local durationTolerance = trigger.durationTolerance
    if trigger.duration and not durationMatches(info, trigger.duration, durationTolerance) then
        return false
    end
    if trigger.durationAtLeast then
        local duration = info and tonumber(info.duration)
        if not duration or duration + (durationTolerance or DEFAULT_DURATION_TOLERANCE) < trigger.durationAtLeast then
            return false
        end
    end
    if trigger.afterLastAdded then
        local sinceLast = self.previousTimelineAddedTime and now - self.previousTimelineAddedTime or 999
        if sinceLast < trigger.afterLastAdded then
            return false
        end
    end

    local addedCount = recentCount(self.recentTimelineAdded, now)
    local removedCount = recentCount(self.recentTimelineRemoved, now)
    local eventCount = eventKey == "timelineRemoved" and removedCount or addedCount
    if trigger.count and eventCount < trigger.count then
        return false
    end
    if trigger.addedMin and addedCount < trigger.addedMin then
        return false
    end
    if trigger.addedMax and addedCount > trigger.addedMax then
        return false
    end
    if trigger.removedMin and removedCount < trigger.removedMin then
        return false
    end
    if trigger.removedMax and removedCount > trigger.removedMax then
        return false
    end

    if trigger.all then
        for _, durations in ipairs(trigger.all) do
            if not recentHasDuration(self.recentTimelineAdded, now, durations, durationTolerance) then
                return false
            end
        end
    end

    if trigger.match and recentDurationCount(self.recentTimelineAdded, now, trigger.match.durations,
        trigger.match.durationTolerance or durationTolerance) <
        trigger.match.count then
        return false
    end

    if trigger.unitMissing and UnitExists and UnitExists(trigger.unitMissing) then
        return false
    end

    return true
end

function PhaseTimers:RecordPhaseTarget(target, now, updateCurrent)
    local phase = targetPhase(target, self.currentPhase)
    if not phase or not self.encounterStartTime then
        return false
    end
    if self.currentPhase and phase < self.currentPhase then
        return false
    end
    if self.currentPhase and phase == self.currentPhase and not updateCurrent then
        return false
    end

    local difficultyData = self:GetDifficultyData(self.currentEncounterID, self.currentDifficultyID)
    if phase > maxPhaseFromDifficultyData(difficultyData) then
        return false
    end

    now = now or GetTime()
    self.currentPhase = phase
    self.phaseSwapTime = now
    self.phaseStarts[phase] = now - self.encounterStartTime
    return true
end

function PhaseTimers:IsTimelineEventFinished(eventID)
    if not C_EncounterTimeline or not C_EncounterTimeline.GetEventState then
        return false
    end
    return C_EncounterTimeline.GetEventState(eventID) == encounterTimelineFinishedState()
end

function PhaseTimers:EvaluateTriggerSet(eventKey, info, eventID, now)
    local difficultyData = self:GetDifficultyData(self.currentEncounterID, self.currentDifficultyID)
    local triggers = difficultyData and difficultyData[eventKey]
    if type(triggers) ~= "table" then
        return
    end

    for target, entries in pairs(triggers) do
        for _, trigger in ipairs(triggerList(entries) or {}) do
            if self:TriggerContextMatches(target, trigger, now) and self:TriggerConditionsMatch(eventKey, trigger, info, now) then
                if eventKey == "timelineFinished" and eventID then
                    self.pendingTimelineTriggers[eventID] = {target = target, trigger = trigger}
                else
                    self:RecordPhaseTarget(target, now)
                end
                return
            end
        end
    end
end

function PhaseTimers:OnTimelineAdded(_, info)
    if not self.encounterStartTime or type(info) ~= "table" then
        return
    end
    if not isEncounterTimelineInfo(info) then
        if info.id then
            self.customTimelineEvents[info.id] = true
        end
        return
    end

    local now = GetTime()
    self.previousTimelineAddedTime = self.lastTimelineAddedTime
    self.lastTimelineAddedTime = now

    if info.id then
        self.activeTimelineEvents[info.id] = info
        self:EvaluateTriggerSet("timelineFinished", info, info.id, now)
    end
    addRecentEvent(self.recentTimelineAdded, info, now)
    self:EvaluateTriggerSet(EVENT_TRIGGER_KEYS.ENCOUNTER_TIMELINE_EVENT_ADDED, info, info.id, now)
end

function PhaseTimers:OnTimelineRemoved(_, eventID)
    if not self.encounterStartTime or not eventID then
        return
    end
    if self.customTimelineEvents[eventID] then
        self.customTimelineEvents[eventID] = nil
        return
    end

    local now = GetTime()
    local info = self.activeTimelineEvents[eventID] or {
        id = eventID
    }
    if not isEncounterTimelineInfo(info) then
        return
    end

    self.pendingTimelineTriggers[eventID] = nil
    self.activeTimelineEvents[eventID] = nil
    addRecentEvent(self.recentTimelineRemoved, info, now)
    self:EvaluateTriggerSet(EVENT_TRIGGER_KEYS.ENCOUNTER_TIMELINE_EVENT_REMOVED, info, eventID, now)
end

function PhaseTimers:OnTimelineStateChanged(_, eventID)
    if not self.encounterStartTime or not eventID then
        return
    end

    local pending = self.pendingTimelineTriggers[eventID]
    local info = self.activeTimelineEvents[eventID]
    if info and not isEncounterTimelineInfo(info) then
        return
    end
    local now = GetTime()
    if pending and self:IsTimelineEventFinished(eventID) and self:TriggerContextMatches(pending.target, pending.trigger, now) then
        self.pendingTimelineTriggers[eventID] = nil
        self:RecordPhaseTarget(pending.target, now)
    end
end

function PhaseTimers:OnEncounterEngageUnit()
    if not self.encounterStartTime then
        return
    end
    self:EvaluateTriggerSet(EVENT_TRIGGER_KEYS.INSTANCE_ENCOUNTER_ENGAGE_UNIT, nil, nil, GetTime())
end

function PhaseTimers:ResetEncounterState()
    self.currentEncounterID = nil
    self.currentEncounterName = nil
    self.currentDifficultyID = nil
    self.encounterStartTime = nil
    self.currentPhase = nil
    self.phaseSwapTime = nil
    self.phaseStarts = {}
    self.activeTimelineEvents = {}
    self.pendingTimelineTriggers = {}
    self.customTimelineEvents = {}
    self.recentTimelineAdded = {}
    self.recentTimelineRemoved = {}
    self.lastTimelineAddedTime = nil
    self.previousTimelineAddedTime = nil
end

function PhaseTimers:OnEncounterStart(_, encounterID, encounterName, difficultyID)
    self:ResetEncounterState()
    self.currentEncounterID = tonumber(encounterID)
    self.currentEncounterName = encounterName
    self.currentDifficultyID = difficultyID
    self.encounterStartTime = GetTime()
    self.currentPhase = 1
    self.phaseSwapTime = self.encounterStartTime
    self.phaseStarts[1] = 0
end

function PhaseTimers:OnEncounterEnd()
    self:ResetEncounterState()
end

function PhaseTimers:OnEnable()
    self:ResetEncounterState()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", "OnTimelineAdded")
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED", "OnTimelineRemoved")
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED", "OnTimelineStateChanged")
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "OnEncounterEngageUnit")
end

function PhaseTimers:OnDisable()
    self:UnregisterAllEvents()
    self:ResetEncounterState()
end

E.phaseTimers = PHASE_TIMER_REGISTRY
_G.ART_PhaseTimers = PHASE_TIMER_REGISTRY
_G.ART = _G.ART or {}
_G.ART.PhaseTimers = PHASE_TIMER_REGISTRY

E:MountMethods(E, {
    GetPhaseTimerData = function()
        return PhaseTimers:GetData()
    end,
    RegisterEncounterPhaseTimers = function(_, encounterID, data)
        return PhaseTimers:RegisterEncounter(encounterID, data)
    end,
    GetEncounterPhaseStart = function(_, encounterID, phase, difficulty)
        return PhaseTimers:GetPhaseStart(encounterID, phase, difficulty)
    end,
    GetEncounterPhaseRelativeTarget = function(_, encounterID, phase, phaseTime, difficulty)
        return PhaseTimers:GetPhaseRelativeTarget(encounterID, phase, phaseTime, difficulty)
    end,
    GetEncounterPhaseRelativeRemaining = function(_, encounterID, phase, phaseTime, encounterStartTime, difficulty)
        return PhaseTimers:GetPhaseRelativeRemaining(encounterID, phase, phaseTime, encounterStartTime, difficulty)
    end,
    GetActiveEncounterPhase = function()
        return PhaseTimers:GetActivePhase()
    end
}, {
    noClobber = true
})

E:MountMethods(_G.ART, {
    GetPhaseTimerData = function()
        return PhaseTimers:GetData()
    end,
    GetEncounterPhaseStart = function(_, encounterID, phase, difficulty)
        return PhaseTimers:GetPhaseStart(encounterID, phase, difficulty)
    end,
    GetEncounterPhaseRelativeTarget = function(_, encounterID, phase, phaseTime, difficulty)
        return PhaseTimers:GetPhaseRelativeTarget(encounterID, phase, phaseTime, difficulty)
    end
}, {
    noClobber = true
})
