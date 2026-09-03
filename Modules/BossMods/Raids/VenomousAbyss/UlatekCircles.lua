local E = unpack(ART)

local BossMods = E:GetModule("BossMods")

local ENCOUNTER_ID = 3492
local BOSS_KEY = "Ulatek"
local BOSS_LABEL_KEY = "BossMods_Ulatek"
local BOSS_ORDER = 80
local SERPENTS_BITE_TIMER_ID = 1295905
local SERPENTS_BITE_AURA_ID = 1288879
local BLIGHT_VEIN_AURA_ID = 1311609
local FURY_UNLEASHED_TIMER_ID = 1286905

local DEFINITIONS = {
    {
        moduleName = "BossMods_SerpentsBiteTarget",
        featureKey = "SerpentsBiteTarget",
        labelKey = "BossMods_SerpentsBiteTarget",
        descKey = "BossMods_SerpentsBiteTargetDesc",
        bossKey = BOSS_KEY,
        bossLabelKey = BOSS_LABEL_KEY,
        bossOrder = BOSS_ORDER,
        encounterID = ENCOUNTER_ID,
        order = 68,
        mode = "aura",
        auraSpellIDs = {SERPENTS_BITE_AURA_ID},
        timerSpellID = SERPENTS_BITE_TIMER_ID,
        maxDuration = 8,
        windowDuration = 8,
        color = {1, 0.08, 0.08, 0.95},
        position = {point = "CENTER", x = 0, y = 0}
    },
    {
        moduleName = "BossMods_BlightVeinCircle",
        featureKey = "BlightVeinCircle",
        labelKey = "BossMods_BlightVeinCircle",
        descKey = "BossMods_BlightVeinCircleDesc",
        bossKey = BOSS_KEY,
        bossLabelKey = BOSS_LABEL_KEY,
        bossOrder = BOSS_ORDER,
        encounterID = ENCOUNTER_ID,
        order = 69,
        mode = "aura",
        auraSpellIDs = {BLIGHT_VEIN_AURA_ID},
        maxDuration = 30,
        showStacks = true,
        stageWindow = 2,
        color = {1, 0.45, 0.05, 0.95},
        position = {point = "CENTER", x = 0, y = 0}
    },
    {
        moduleName = "BossMods_VolatilePurgeCircle",
        featureKey = "VolatilePurgeCircle",
        labelKey = "BossMods_VolatilePurgeCircle",
        descKey = "BossMods_VolatilePurgeCircleDesc",
        bossKey = BOSS_KEY,
        bossLabelKey = BOSS_LABEL_KEY,
        bossOrder = BOSS_ORDER,
        encounterID = ENCOUNTER_ID,
        order = 71,
        mode = "timed",
        timerSpellID = FURY_UNLEASHED_TIMER_ID,
        triggerOffset = 20,
        windowDuration = 5,
        color = {0.1, 1, 0.2, 0.95},
        position = {point = "CENTER", x = 0, y = 0}
    }
}

for _, definition in ipairs(DEFINITIONS) do
    BossMods:RegisterAuraCircleFeature(definition)
end
