local E = unpack(ART)
local MODULE_NAME = "BossMods_UlatekAutoRelease"
local ENCOUNTER_ID = 3492

E:RegisterModuleDefaults(MODULE_NAME, {enabled = true})

local AutoRelease = E:NewModule(MODULE_NAME, "AceEvent-3.0", "AceTimer-3.0")

function AutoRelease:CancelRelease()
    if self.releaseTimer then
        self:CancelTimer(self.releaseTimer)
        self.releaseTimer = nil
    end
end

function AutoRelease:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then return end
    self:CancelRelease()
    -- Allow the encounter's release restriction to clear before releasing.
    self.releaseTimer = self:ScheduleTimer(function()
        self.releaseTimer = nil
        if self:IsEnabled() and not IsEncounterInProgress()
            and UnitIsDead("player") and not UnitIsGhost("player") then
            RepopMe()
        end
    end, 0.5)
end

function AutoRelease:OnEnable()
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("ENCOUNTER_START", "CancelRelease")
    self:RegisterEvent("PLAYER_LEAVING_WORLD", "CancelRelease")
end

function AutoRelease:OnDisable()
    self:UnregisterAllEvents()
    self:CancelRelease()
end

E:RegisterBossModFeature("UlatekAutoRelease", {
    tab = "VenomousAbyss",
    order = 110,
    bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek",
    bossOrder = 80,
    labelKey = "BossMods_UlatekAutoRelease",
    navLabelKey = "BossMods_UlatekAutoReleaseNav",
    descKey = "BossMods_UlatekAutoReleaseDesc",
    moduleName = MODULE_NAME
})
