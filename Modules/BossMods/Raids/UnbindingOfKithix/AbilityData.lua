local E, L = unpack(ART)

-- Spell keys match BigWigs_TheUnbindingOfKithix. BigWigs supplies the live
-- durations, including its damage/stun delays; do not add those delays again.
E.UnbindingOfKithixAbilityData = {
    {
        bossKey = "Kithix",
        bossName = L["BossMods_Kithix"],
        bossOrder = 10,
        abilities = {
            { spellID = 1301511, name = "Voidswarm (Adds)", settingsKey = "Voidswarm", shortName = "Adds", defaultBarColor = "00FFC3", defaultBarEnabled = true, defaultTextEnabled = false, order = 10 },
            { spellID = 1304424, name = "Extinguish", defaultBarColor = "FF0011", defaultBarEnabled = false, defaultTextEnabled = false, order = 20 },
            { spellID = 1304508, name = "Light's Embrace (Orbs)", defaultBarColor = "F7FF00", defaultBarEnabled = false, defaultTextEnabled = false, order = 30 },
            { spellID = 1304045, name = "Unspeakable Horrors (Debuffs)", settingsKey = "Unspeakable Horrors", shortName = "Dispells", postHitStages = { countDown = true, stages = {{ duration = 6, text = "Dispels Out" }} }, defaultBarColor = "FF7400", defaultBarEnabled = true, defaultTextEnabled = false, order = 40 },
            { spellID = 1303681, name = "Twisted Appendage (Tentacles)", settingsKey = "Twisted Appendage", shortName = "Tentacle Spawn", postHitStages = { countDown = true, stages = {{ duration = 6.5, text = "Slam" }} }, defaultBarColor = "F7FF00", defaultBarEnabled = true, defaultTextEnabled = false, order = 50 },
            { spellID = 1304930, name = "Dark Devastation (Tank Bomb)", defaultBarColor = "A335EE", defaultBarEnabled = false, defaultTextEnabled = false, order = 60 },
            { spellID = 1302951, name = "Suffocating Darkness (Intermission)", settingsKey = "Suffocating Darkness", shortName = "Intermission", defaultTextSecondsBefore = 5, defaultBarColor = "00FFC3", defaultBarEnabled = false, defaultTextEnabled = true, order = 70 },
            { spellID = 1303406, name = "Abyssal Grasp (Heal Absorbs)", settingsKey = "Abyssal Grasp", shortName = "Heal absorbs in", defaultTextSecondsBefore = 5, defaultBarColor = "F7FF00", defaultBarEnabled = false, defaultTextEnabled = true, order = 80 },
            { spellID = 1303169, name = "Divine Radiance (Return to Stage 1)", defaultBarColor = "00FFC3", defaultBarEnabled = false, defaultTextEnabled = false, order = 90 },
            { spellID = 1308873, name = "Null Gate", defaultBarColor = "F7FF00", defaultBarEnabled = false, defaultTextEnabled = false, order = 100 },
            { spellID = 1318467, name = "Negation (Tank Debuff)", defaultBarColor = "A335EE", defaultBarEnabled = false, defaultTextEnabled = false, order = 110 },
            { spellID = 1301479, name = "Eightfold Eclipse", defaultBarColor = "FF0011", defaultBarEnabled = false, defaultTextEnabled = false, order = 120 },
        },
    },
}

local boss = E.UnbindingOfKithixAbilityData[1]
boss.raidKey = "UnbindingOfKithix"
boss.featureKey = "UnbindingOfKithixKithix"
E:RegisterBossModFeature(boss.featureKey, {
    tab = "UnbindingOfKithix",
    order = 1,
    bossKey = "Kithix",
    bossLabelKey = "BossMods_Kithix",
    bossOrder = 10,
    navLabelKey = "BossMods_BossGeneral",
    labelKey = "BossMods_Kithix",
    moduleName = "BossMods_KithixAbilityAlerts"
})