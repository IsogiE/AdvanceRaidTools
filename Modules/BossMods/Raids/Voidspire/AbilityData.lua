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
}

-------------------------------------------------------------------------------
-- Combat Tools features
--
-- The boss names and ordering are read directly from AbilityData above.
-------------------------------------------------------------------------------

E:RegisterAbilityAlertData(
    "Voidspire",
    "BossMods_VoidspireAbilityAlerts",
    E.VoidspireAbilityData
)
