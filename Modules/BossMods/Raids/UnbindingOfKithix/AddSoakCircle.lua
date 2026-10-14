local E = unpack(ART)
local BossMods = E:GetModule("BossMods")

local Mod = BossMods:RegisterAuraCircleFeature({
    moduleName = "BossMods_KithixAddSoakCircle",
    featureKey = "KithixAddSoakCircle",
    labelKey = "Add soak Circle",
    descKey = "Shows a circle for player debuffs with a total duration of up to 4 seconds during Kith'ix.",
    tab = "UnbindingOfKithix",
    bossKey = "Kithix", bossLabelKey = "BossMods_Kithix", bossOrder = 10,
    encounterID = 3513, order = 30, defaultEnabled = true,
    mode = "aura", maxDuration = 4, isBossOrRoleAura = false,
    color = {1, 0.08, 0.08, 0.95},
    position = {point = "CENTER", x = 0, y = 0}
})

-- Unlike Serpent's Bite this is eligible throughout the encounter.
local onEncounterStart = Mod.OnEncounterStart
function Mod:OnEncounterStart(event, encounterID)
    onEncounterStart(self, event, encounterID)
    if self.encounterActive then self:EnsureDisplay():SetLiveWindow(true) end
end
