local E = unpack(ART)

E.VoidspireAbilityData = {
    {
        bossKey = "Imperator",
        bossName = "Imperator Averzian",
        bossOrder = 10,
        abilities = {
            { spellID = 1249262, name = "Umbrall Collapse (Soaks)", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 10 },
            { spellID = 1258883, name = "Void Fall (Knockback)", defaultBarColor = "C400FF", defaultBarEnabled = true, order = 20 },
            { spellID = 1249251, name = "Dark Upheaval (Damage)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2.5, order = 30 },
        },
    },
    {
        bossKey = "Vorasius",
        bossName = "Vorasius",
        bossOrder = 20,
        abilities = {
            { spellID = 1256855, name = "Void Breath (Beam)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 5, postHitStages = { stages = { { duration = 15, text = "Void Breath" } } }, order = 10 },
            { spellID = 1254199, name = "Parasite Expulsion (Intermission)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2, postHitStages = { stages = { { duration = 4, text = "Parasite Expulsion" } } }, order = 20 },
            { spellID = 1241692, name = "Shadowclaw Slam (Tank Soak + Damage)", defaultBarColor = "FF0011", defaultBarEnabled = false, order = 30 },
            { spellID = 1260052, name = "Primordial Roar (Knockback)", defaultBarColor = "C400FF", defaultBarEnabled = true, castTimeAdjustment = 5, order = 40 },
        },
    },
    {
        bossKey = "Salhadaar",
        bossName = "Fallen-King Salhadaar",
        bossOrder = 30,
        abilities = {
            { spellID = 1247738, name = "Void Convergence (Orbs)", defaultBarColor = "00FF41", defaultBarEnabled = true, order = 10 },
            { spellID = 1250803, name = "Shattering Twilight (Spikes)", defaultBarColor = "00FFC3", defaultBarEnabled = true, postHitStages = { stages = { { duration = 5, text = "Shattering Twilight" } } }, order = 20 },
            { spellID = 1246175, name = "Entropic Unraveling (Beams)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2, postHitStages = { stages = { { duration = 20, text = "Beams" } } }, order = 30 },
            { spellID = 1254081, name = "Fractured Projection (CC Adds)", defaultBarColor = "00FF41", defaultBarEnabled = true, order = 40 },
            { spellID = 1248697, name = "Despotic Command (Pool Drops)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 50 },
        },
    },
    {
        bossKey = "VaelgorEzzorak",
        bossName = "Vaelgor & Ezzorak",
        bossOrder = 40,
        abilities = {
            { spellID = 1249748, name = "Midnight Flames (Intermission)", order = 10 },
            { spellID = 1245391, name = "Gloom", defaultBarColor = "FF7400", defaultBarEnabled = true, postHitStages = { stages = { { duration = 4, text = "Gloom" } } }, order = 20 },
            { spellID = 1244917, name = "Void Howl (Spread Circles + Adds)", defaultBarColor = "00FF41", defaultBarEnabled = true, castTimeAdjustment = 2, order = 30 },
            { spellID = 1244221, name = "Dread Breath (Frontal)", defaultBarColor = "00FFC3", defaultBarEnabled = true, postHitStages = { stages = { { duration = 4, text = "Dread Breath" } } }, order = 40 },
            { spellID = 1244672, name = "Tether", defaultBarColor = "FF0011", defaultBarEnabled = true, order = 50 },
        },
    },
    {
        bossKey = "Vanguard",
        bossName = "Lightblinded Vanguard",
        bossOrder = 50,
        abilities = {
            { spellID = 1248983, name = "Execution Sentence (Soaks)", defaultBarColor = "FF7400", defaultBarEnabled = true, postHitStages = { stages = { { duration = 8, text = "Execution Sentence" } } }, order = 10 },
            { spellID = 1246749, name = "Sacred Toll (Damage)", defaultBarColor = "FF0011", defaultBarEnabled = false, castTimeAdjustment = 2, order = 20 },
            { spellID = 1246485, name = "Avenger's Shield (Dispels)", defaultBarColor = "00FFC3", defaultBarEnabled = false, order = 30 },
            { spellID = 1248710, name = "Tyr's Wrath (Heal Absorbs)", defaultBarColor = "00FFC3", defaultBarEnabled = false, order = 40 },
            { spellID = 1255738, name = "Searing Radiance (Raid Damage)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2, postHitStages = { stages = { { duration = 15, text = "Raid Damage" } } }, order = 50 },
            { spellID = 1248674, name = "Searing Shield (Charge + Shield)", defaultBarColor = "FFF90F", defaultBarEnabled = true, castTimeAdjustment = 2, order = 60 },
            { spellID = 1248451, name = "Aura of Peace (Senn Out)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 70 },
            { spellID = 1246162, name = "Aura of Devotion (Bellamy Out)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 80 },
            { spellID = 1248449, name = "Aura of Wrath (Venel Out)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 90 },
        },
    },
    {
        bossKey = "Alleria",
        bossName = "Crown of the Cosmos",
        bossOrder = 60,
        abilities = {
            { spellID = 1232467, name = "Grasp of Emptiness (Obelisks)", defaultBarColor = "00FFC3", defaultBarEnabled = true, order = 10 },
            { spellID = 1233602, name = "Silverstrike Arrow (Arrows)", defaultBarColor = "0094FF", defaultBarEnabled = false, order = 20 },
            { spellID = 1255368, name = "Void Expulsion (Bait Balls)", defaultBarColor = "FFF90F", defaultBarEnabled = true, order = 30 },
            { spellID = 1233865, name = "Null Corona (Heal Absorb)", defaultBarColor = "A000FF", defaultBarEnabled = true, castTimeAdjustment = 1.5, order = 40 },
            { spellID = 1237614, name = "Ranger General's Mark (P2 Arrows)", defaultBarColor = "0094FF", defaultBarEnabled = false, order = 50 },
            { spellID = 1239080, name = "Aspect of the End (Chains)", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 3, order = 60 },
            { spellID = 1243743, name = "Interrupting Tremor", defaultBarColor = "00FF41", defaultBarEnabled = true, castTimeAdjustment = 5, order = 70 },
        },
    },
    {
        bossKey = "Chimaerus",
        bossName = "Chimaerus",
        bossOrder = 70,
        abilities = {
            { spellID = 1264756, name = "Rift Madness (Mythic)", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 10 },
            { spellID = 1245396, name = "Consume (Adds)", defaultBarColor = "FF0011", defaultBarEnabled = true, order = 20 },
            { spellID = 1245406, name = "Ravenous Dive (Return to Stage 1)", defaultBarColor = "FF0011", defaultBarEnabled = true, order = 30 },
            { spellID = 1262289, name = "Alndust Upheaval (Soak)", defaultBarColor = "FF7400", defaultBarEnabled = true, order = 40 },
            { spellID = 1272726, name = "Rending Tear (Frontal Cone)", defaultBarColor = "0094FF", defaultBarEnabled = true, order = 50 },
        },
    },
    {
        bossKey = "Beloren",
        bossName = "Belo'ren",
        bossOrder = 80,
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
        bossOrder = 90,
        abilities = {
            { spellID = 1253915, name = "Heaven's Glaives", defaultBarColor = "00FFDD", defaultBarEnabled = true, castTimeAdjustment = 3, order = 10 },
            { spellID = 1249620, name = "Death's Dirge", defaultBarColor = "6B00FF", defaultBarEnabled = false, order = 30 },
            { spellID = 1267049, name = "Heaven's Lance (Tank)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 60 },
            { spellID = 1284931, name = "Termination Prism (Mythic)", defaultBarColor = "00FF41", defaultBarEnabled = true, castTimeAdjustment = 3, order = 80 },
            { spellID = 1282441, name = "Starsplinter (Intermission)", shortName = "Starsplinter", defaultBarColor = "FF0011", defaultBarEnabled = true, postHitStages = { stages = { { duration = 3, text = "Starsplinter" } } }, order = 90 },
            { spellID = 1285510, triggerSpellID = 1282441, name = "Starsplinter (Phase 4)", shortName = "Starsplinter", order = 95 },
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
    {
        bossKey = "Rotmire",
        bossName = "Rotmire",
        bossOrder = 100,
        abilities = {
            { spellID = 1221622, name = "Awaken Fungi", defaultBarColor = "00FF41", defaultBarEnabled = true, castTimeAdjustment = 2, order = 10 },
            { spellID = 1221637, name = "Fungal Bloom", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 6, postHitStages = { stages = { { duration = 16, text = "DoT" } } }, order = 20 },
            { spellID = 1222088, name = "Festering Vines", defaultBarColor = "00FFC3", defaultBarEnabled = true, castTimeAdjustment = 2, order = 30 },
            { spellID = 1221787, name = "Bursting Pustules", defaultBarColor = "FF0011", defaultBarEnabled = true, castTimeAdjustment = 2, order = 40 },
            { spellID = 1221781, name = "Putrid Fist (Tank)", defaultBarColor = "001FFF", defaultBarEnabled = false, order = 50 },
        },
    },
}

-------------------------------------------------------------------------------
-- Combat Tools features
--
-- The boss names and ordering are read directly from AbilityData above.
-------------------------------------------------------------------------------

for _, boss in ipairs(E.VoidspireAbilityData or {}) do
    E:RegisterBossModFeature(
        "Voidspire" .. boss.bossKey,
        {
            tab = "Voidspire",
            order = boss.bossOrder or 100,

            -- Use bossName directly as the display text.
            labelKey = boss.bossName or boss.bossKey,

            moduleName = "BossMods_VoidspireAbilityAlerts"
        }
    )
end
