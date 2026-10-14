local E = unpack(ART)
local BossMods = E:GetModule("BossMods")

local Mod = BossMods:RegisterAuraCircleFeature({
    moduleName = "BossMods_KithixAddSoakCircle",
    featureKey = "KithixAddSoakCircle",
    labelKey = BigWigsAPI:GetLocale("BigWigs: Common").debuffs,
    descKey = "BossMods_KithixAddSoakCircleDesc",
    tab = "UnbindingOfKithix",
    bossKey = "Kithix", bossLabelKey = "BossMods_Kithix", bossOrder = 10,
    encounterID = 3513, order = 30, defaultEnabled = true,
    mode = "aura", maxDuration = 4, isBossOrRoleAura = false,
    filter = "HARMFUL|!DISPELLABLE|!CROWD_CONTROL",
    candidateFilters = {isFromPlayerOrPlayerPet = false},
    stageWindow = 1, stageWindowEnd = 2, bigWigsModuleName = "Kith'ix",
    color = {1, 0.08, 0.08, 0.95},
    position = {point = "CENTER", x = 0, y = 0}
})

local onEncounterStart = Mod.OnEncounterStart
function Mod:OnEncounterStart(event, encounterID)
    onEncounterStart(self, event, encounterID)
    if encounterID == self.definition.encounterID then
        self:EnsureDisplay():SetLiveWindow(true)
    end
end
