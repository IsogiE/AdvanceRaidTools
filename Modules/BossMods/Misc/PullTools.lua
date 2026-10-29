local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_PullTools"
local PREFIX = "ART_PULL_RECOVER"
local REQUEST_DELAY = 1
local RESTART_DEBOUNCE = 5
local REQUEST_MAX_AGE = 10

E:RegisterModuleDefaults(MODULE_NAME, {enabled = true, recoverCountdown = true, benchGuard = true})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function doCountdown(seconds)
    local countdown = BigWigsLoader and BigWigsLoader.DoCountdown or C_PartyInfo.DoCountdown
    return countdown(seconds)
end

local function publicNumber(value)
    if E:IsSecret(value) then return end
    value = tonumber(value)
    if value and value == value and math.abs(value) < math.huge then return value end
end

function Mod:IsActive()
    return self:IsEnabled() and BossMods:IsEnabled() and BossMods:IsFeatureEnabled("PullTools")
end

function Mod:CanUseCountdown()
    return self:IsActive() and IsInRaid() and not InCombatLockdown()
        and not C_InstanceEncounter.IsEncounterInProgress()
        and not C_ChatInfo.InChatMessagingLockdown()
end

function Mod:ClearPull()
    self.pullEndsAt = nil
    if self.guardTimer then self.guardTimer:Cancel(); self.guardTimer = nil end
end

function Mod:CancelRecoveryRequest()
    if self.recoveryTimer then self.recoveryTimer:Cancel(); self.recoveryTimer = nil end
end

function Mod:RequestRecovery()
    self.recoveryTimer = nil
    if not self:CanUseCountdown() or self.db.recoverCountdown ~= true then return end
    if self.pullEndsAt and self.pullEndsAt > GetTime() then return end
    local comms = E:GetModule("Comms")
    if comms:IsEnabled() then comms:Broadcast(PREFIX, "1:" .. GetServerTime(), "RAID") end
end

function Mod:ScheduleRecovery()
    self:CancelRecoveryRequest()
    if self.db.recoverCountdown == true then
        self.recoveryTimer = C_Timer.NewTimer(REQUEST_DELAY, function() self:RequestRecovery() end)
    end
end

function Mod:OnEnteringWorld(_, initialLogin, reloading)
    if initialLogin or reloading then self:ScheduleRecovery() end
end

function Mod:OnRecoveryRequest(_, message, distribution, sender)
    if distribution ~= "RAID" or not self:CanUseCountdown()
        or self.db.recoverCountdown ~= true or not UnitIsGroupLeader("player")
        or not E:GetGroupUnitByName(sender) then return end
    message = E:SafeString(message)
    local sentAt = message and publicNumber(message:match("^1:(%d+)$"))
    if not sentAt or math.abs(GetServerTime() - sentAt) > REQUEST_MAX_AGE then return end
    local now = GetTime()
    local remaining = self.pullEndsAt and self.pullEndsAt - now
    if not remaining or remaining <= 0 or now - (self.lastRestartAt or -math.huge) < RESTART_DEBOUNCE then return end
    if self:CheckBenchGuard() then return end
    self.lastRestartAt = now
    doCountdown(math.ceil(remaining))
end

function Mod:IsGuardedLocation()
    local _, instanceType, difficulty = GetInstanceInfo()
    if instanceType ~= "raid" or (difficulty ~= 16 and difficulty ~= 233) then return false end
    local mapID = C_Map.GetBestMapForUnit("player")
    return mapID == 2534 or mapID == 2610
        or (mapID == 2609 and GetSubZoneText() == "Altar of the Six Winds")
end

function Mod:CheckBenchGuard()
    if not self:CanUseCountdown() or self.db.benchGuard ~= true
        or not UnitIsGroupLeader("player") or not self:IsGuardedLocation() then return false end
    local benched = {}
    for index = 1, GetNumGroupMembers() do
        local name, _, group = GetRaidRosterInfo(index)
        group = publicNumber(group)
        if group and group > 4 then
            name = E:SafeString(name)
            benched[#benched + 1] = name and Ambiguate(name, "short") or ("raid" .. index)
        end
    end
    if #benched > 0 then
        self:ClearPull()
        if doCountdown(0) ~= false then
            local prefix = L["BossMods_PullBenchWarning"]
            local names, length = {}, #prefix + 1
            for _, name in ipairs(benched) do
                if length + #name + 2 > 240 then names[#names + 1] = "..."; break end
                names[#names + 1] = name
                length = length + #name + 2
            end
            C_ChatInfo.SendChatMessage(prefix .. " " .. table.concat(names, ", "), "RAID_WARNING")
        end
        return true
    end
    return false
end

function Mod:OnCountdown(_, _, seconds)
    self:ClearPull()
    seconds = publicNumber(seconds)
    if not self:CanUseCountdown() or not seconds or seconds <= 0 then return end
    self.pullEndsAt = GetTime() + seconds
    if self.db.benchGuard == true then
        self.guardTimer = C_Timer.NewTimer(0, function()
            self.guardTimer = nil
            if self.pullEndsAt and self.pullEndsAt > GetTime() then self:CheckBenchGuard() end
        end)
    end
end

function Mod:OnGroupChanged()
    if not IsInRaid() then
        self:ClearPull()
        self:CancelRecoveryRequest()
    elseif self.pullEndsAt and self.pullEndsAt > GetTime() then
        self:CheckBenchGuard()
    end
end

function Mod:Refresh()
    self:CancelRecoveryRequest()
end

function Mod:OnEnable()
    self:ClearPull()
    self.lastRestartAt = -math.huge
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("START_PLAYER_COUNTDOWN", "OnCountdown")
    self:RegisterEvent("CANCEL_PLAYER_COUNTDOWN", "ClearPull")
    self:RegisterEvent("ENCOUNTER_START", "ClearPull")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "ClearPull")
    self:RegisterEvent("GROUP_LEFT", "OnGroupChanged")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    E:GetModule("Comms"):RegisterProtocol(PREFIX, function(...) self:OnRecoveryRequest(...) end)
    self:ScheduleRecovery()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:ClearPull()
    self:CancelRecoveryRequest()
    E:GetModule("Comms"):UnregisterProtocol(PREFIX)
end

E:RegisterBossModFeature("PullTools", {
    tab = "Misc", order = 51, moduleName = MODULE_NAME,
    labelKey = "BossMods_PullTools", descKey = "BossMods_PullToolsDesc"
})
