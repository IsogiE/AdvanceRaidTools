local E = unpack(ART)

E.QueldanasAbilityData = {
    {
        bossKey = "Beloren",
        bossName = "Belo'ren, Child of Al'ar",
        bossOrder = 10,
        abilities = {
            { spellID = 1242515, name = "Voidlight Convergence (Color Swaps)", defaultBarColor = "FF0011", defaultBarEnabled = true, postHitStages = { stages = { { duration = 6, text = "Voidlight Convergence" } } }, order = 10 },
            { spellID = 1241282, name = "Embers of Belo'ren", defaultBarColor = "00FF41", defaultBarEnabled = false, order = 20 },
            { spellID = 1241292, name = "Light/Void Dive", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 30 },
            { spellID = 1242981, name = "Radiant Echoes", defaultBarColor = "FF009B", defaultBarEnabled = true, order = 40 },
            { spellID = 1260763, name = "Guardian's Edict", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 50 },
            { spellID = 1244344, name = "Eternal Burns", defaultBarColor = "00FFC3", defaultBarEnabled = true, order = 60 },
            { spellID = 1242260, name = "Infused Quills", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 70 },
            { spellID = 1246709, name = "Death Drop", defaultBarColor = "FF0011", defaultBarEnabled = true, order = 80 },
        },
    },
    {
        bossKey = "Lura",
        bossName = "Midnight Falls",
        bossOrder = 20,
        abilities = {
            { spellID = 1253915, name = "Heaven's Glaives", defaultBarColor = "00FFDD", defaultBarEnabled = true, castTimeAdjustment = 3, order = 10 },
            { spellID = 1249620, name = "Death's Dirge", defaultBarColor = "6B00FF", defaultBarEnabled = false, order = 30 },
            { spellID = 1267049, name = "Heaven's Lance (Tank)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 60 },
            { spellID = 1284931, name = "Termination Prism (Mythic)", defaultBarColor = "00FF41", defaultBarEnabled = true, castTimeAdjustment = 3, order = 80 },
            { spellID = 1282441, settingsKey = "starsplinterIntermission", name = "Starsplinter (Intermission)", shortName = "Starsplinter", defaultBarColor = "FF0011", defaultBarEnabled = true, postHitStages = { stages = { { duration = 3, text = "Starsplinter" } } }, order = 90 },
            { spellID = 1285510, settingsKey = "starsplinterPhase4", triggerSpellID = 1282441, name = "Starsplinter (Phase 4)", shortName = "Starsplinter", order = 95 },
            { spellID = 1284525, name = "Galvanize (Stage 2)", defaultBarColor = "FF7400", defaultBarEnabled = true, postHitStages = { stages = { { duration = 6, text = "Galvanize" } } }, order = 110 },
            { spellID = 1282412, name = "Core Harvest (Stage 2)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2.5, order = 120 },
            { spellID = 1281194, name = "Dark Meltdown (Stage 2 Knockback)", defaultBarColor = "C400FF", defaultBarEnabled = true, castTimeAdjustment = 8, order = 130 },
            { spellID = 1250898, name = "The Dark Archangel (Stage 3)", defaultBarColor = "FF0011", defaultBarEnabled = false, order = 140 },
            { spellID = 1266388, name = "Dark Constellation (Stage 3)", defaultBarColor = "FF0011", defaultBarEnabled = false, order = 150 },
            { spellID = 1266897, name = "Light Siphon (Stage 3)", defaultBarColor = "FF7400", defaultBarEnabled = false, order = 160 },
            { spellID = 1273158, name = "Death's Requiem (Mythic)", defaultBarColor = "0084FF", defaultBarEnabled = false, order = 170 },
            { spellID = 1276525, name = "Heaven & Hell (Mythic)", defaultBarColor = "FF0011", defaultBarEnabled = true, postHitStages = { stages = { { duration = 10, text = "MOVE" } } }, order = 180 },
        },
    },
}

E:RegisterAbilityAlertData(
    "Queldanas",
    "BossMods_VoidspireAbilityAlerts",
    E.QueldanasAbilityData,
    "Voidspire"
)
