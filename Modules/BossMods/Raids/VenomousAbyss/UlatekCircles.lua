local E = unpack(ART)

local BossMods = E:GetModule("BossMods")

local ENCOUNTER_ID = 3492
local BOSS_KEY = "Ulatek"
local BOSS_LABEL_KEY = "BossMods_Ulatek"
local BOSS_ORDER = 80
local SERPENTS_BITE_TIMER_ID = 1295905
local SERPENTS_BITE_AURA_ID = 1288879
local BLIGHT_VEIN_AURA_ID = 1311609
local VOLATILE_PURGE_AURA_ID = 1312967

local DEFINITIONS = {
    {
        moduleName = "BossMods_SerpentsBiteTarget",
        featureKey = "SerpentsBiteTarget",
        labelKey = "BossMods_SerpentsBiteTarget",
        descKey = "BossMods_SerpentsBiteTargetDesc",
        tab = "VenomousAbyss",
        bossKey = BOSS_KEY,
        bossLabelKey = BOSS_LABEL_KEY,
        bossOrder = BOSS_ORDER,
        encounterID = ENCOUNTER_ID,
        order = 68,
        mode = "aura",
        auraSpellIDs = {SERPENTS_BITE_AURA_ID},
        timerSpellID = SERPENTS_BITE_TIMER_ID,
        maxDuration = 15,
        windowDuration = 15,
        audio = {
            ttsText = "Serpent's Bite"
        },
        color = {1, 0.08, 0.08, 0.95},
        position = {point = "CENTER", x = 0, y = 0}
    },
    {
        moduleName = "BossMods_BlightVeinCircle",
        featureKey = "BlightVeinCircle",
        labelKey = "BossMods_BlightVeinCircle",
        descKey = "BossMods_BlightVeinCircleDesc",
        tab = "VenomousAbyss",
        bossKey = BOSS_KEY,
        bossLabelKey = BOSS_LABEL_KEY,
        bossOrder = BOSS_ORDER,
        encounterID = ENCOUNTER_ID,
        order = 69,
        mode = "aura",
        auraSpellIDs = {BLIGHT_VEIN_AURA_ID},
        maxDuration = 6,
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
        tab = "VenomousAbyss",
        bossKey = BOSS_KEY,
        bossLabelKey = BOSS_LABEL_KEY,
        bossOrder = BOSS_ORDER,
        encounterID = ENCOUNTER_ID,
        order = 71,
        mode = "aura",
        auraSpellIDs = {VOLATILE_PURGE_AURA_ID},
        maxDuration = 5,
        stageWindow = 3,
        stageWindowEnd = 4,
        color = {0.1, 1, 0.2, 0.95},
        position = {point = "CENTER", x = 0, y = 0}
    }
}

for _, definition in ipairs(DEFINITIONS) do
    BossMods:RegisterAuraCircleFeature(definition)
end
