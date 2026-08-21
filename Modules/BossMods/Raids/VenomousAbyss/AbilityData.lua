local E = unpack(ART)

E.VenomousAbyssAbilityData = {
    ---------------------------------------------------------------------------
    -- Nek'zali
    ---------------------------------------------------------------------------
    {
        bossKey = "Nekzali",
        bossName = "Nek'zali",
        bossOrder = 10,

        abilities = {
            {
                spellID = 1285681,
                name = "Soulcoil Ignition (Raid Damage)",
                defaultBarColor = "FF0011",
                order = 10,
            },

            {
                spellID = 1292036,
                legacySpellID = 1284103,
                name = "Possession Barrage (Tank Debuff + Raid Damage)",
                defaultBarColor = "FF0011",
                order = 20,
                castTimeAdjustment = 6,
                castWindowBar = true,
            },

            {
                spellID = 1287426,
                name = "Essence Rend (Debuffs)",
                defaultBarColor = "00FFC3",
                order = 30,
            },

            {
                spellID = 1299673,
                name = "Invoke (Stop casting)",
                defaultBarColor = "0044FF",
                order = 40,
                castTimeAdjustment = 5,
            },

            {
                spellID = 1305421,
                legacySpellID = 1289855,
                name = "Hungering Pyre (Soak)",
                defaultBarColor = "FF7400",
                order = 50,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 7.5, text = "Soak" },
                    },
                },
            },

            {
                spellID = 1293212,
                name = "Grasping Depths (Mythic Pull-In)",
                defaultBarColor = "F7FF00",
                order = 60,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- Entombed Sentinels
    ---------------------------------------------------------------------------
    {
        bossKey = "EntombedSentinels",
        bossName = "Entombed Sentinels",
        bossOrder = 20,

        abilities = {
            {
                spellID = 1284588,
                legacySpellID = 1284606,
                name = "Vitrolic Stasis (Intermission)",
                defaultBarColor = "FF7400",
                order = 10,
            },

            {
                spellID = 1296878,
                name = "Shifting Protovenom (Mythic Circles)",
                defaultBarColor = "C400FF",
                order = 20,
                castTimeAdjustment = 4,
            },

            {
                spellID = 1284251,
                name = "Venom Coagulation (Green Add)",
                defaultBarColor = "00FF41",
                order = 30,
            },

            {
                spellID = 1284434,
                name = "Toxic Droplets (Green Soaks)",
                defaultBarColor = "FF7400",
                order = 40,
                castTimeAdjustment = 2,
            },

            {
                spellID = 1288232,
                name = "Unstable Miasma (Red Soak)",
                defaultBarColor = "FF7400",
                order = 60,
                castTimeAdjustment = 1,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1288232,
                postHitStages = {
                    stages = {
                        { duration = 8, text = "Soak" },
                        { duration = 6, text = "Pool drop" },
                    },
                },
            },

            {
                spellID = 1284483,
                name = "Blighted Blood (Healer Dispel)",
                defaultBarColor = "00FFC3",
                order = 70,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- The Lost Explorers
    ---------------------------------------------------------------------------
    {
        bossKey = "LostExplorers",
        bossName = "The Lost Explorers",
        bossOrder = 30,

        abilities = {
            {
                spellID = 1296092,
                name = "Mighty Thud (Soaks)",
                defaultBarColor = "FF7400",
                defaultBarEnabled = false,
                order = 10,
            },

            {
                spellID = -1296092,
                triggerSpellID = 1296092,
                kind = "mightyThudHits",
                name = "Mighty Thud Hit Bar",
                defaultBarColor = "FF7400",
                shortName = "Mighty Thud Hit",
                order = 15,
            },

            {
                spellID = 1291759,
                legacySpellID = 1296061,
                name = "Shell Spin (Frontal)",
                defaultBarColor = "FFF90F",
                order = 20,
            },

            {
                spellID = 1290711,
                legacySpellID = 1296025,
                name = "Blink Nova (Teleport + Raid Damage)",
                defaultBarColor = "FF0011",
                order = 30,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1296025,
                postHitStages = {
                    stages = {
                        { duration = 7, text = "Teleport" },
                    },
                },
            },

            {
                spellID = 1295886,
                name = "Frostfire Volley (Damage)",
                defaultBarColor = "FF7400",
                order = 40,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 8, text = "Frostfire Volley" },
                    },
                },
            },

            {
                spellID = 1292104,
                name = "Mushroom Toss (Bait)",
                defaultBarColor = "FFF90F",
                order = 50,
                castTimeAdjustment = 7,
            },

            {
                spellID = 1296249,
                legacySpellID = 1297625,
                name = "Explosive Surprise (Bomb)",
                defaultBarColor = "FF7400",
                order = 60,
            },

            {
                spellID = 1286921,
                name = "Icebound Flames (Interrupt)",
                defaultBarColor = "00FFC3",
                order = 80,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- Vashnik the Malignant
    ---------------------------------------------------------------------------
    {
        bossKey = "Vashnik",
        bossName = "Vashnik the Malignant",
        bossOrder = 40,

        abilities = {
            {
                spellID = 1283164,
                name = "Imbibe",
                defaultBarColor = "FF0011",
                order = 10,
            },

            {
                spellID = 1281907,
                name = "Plague Froth (Waves)",
                defaultBarColor = "00FFC3",
                order = 20,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1281907,
                postHitStages = {
                    stages = {
                        { duration = 6, text = "Waves" },
                    },
                },
            },

            {
                spellID = 1282525,
                name = "Malignant Catalyst (Green Soaks)",
                defaultBarColor = "FF7400",
                order = 30,
                castTimeAdjustment = 5,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1282525,
                postHitStages = {
                    stages = {
                        { duration = 7, text = "Soaks" },
                    },
                },
            },

            {
                spellID = 1282117,
                name = "Adaptive Infection (Infections)",
                defaultBarColor = "FFF90F",
                order = 40,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- Sszorak
    ---------------------------------------------------------------------------
    {
        bossKey = "Sszorak",
        bossName = "Sszorak",
        bossOrder = 50,

        abilities = {
            {
                spellID = 1277025,
                name = "Apex Predator (Tank/Group Combo)",
                order = 10,
            },

            {
                spellID = 1285425,
                legacySpellID = 1285419,
                name = "Raging Crosswinds (Knockbacks)",
                order = 20,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1285419,
                postHitStages = {
                    stages = {
                        { duration = 8, text = "Knock" },
                    },
                },
            },

            {
                spellID = 1305959,
                name = "Venomous Surge (Orb placement)",
                order = 30,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 4, text = "Venomous Surge" },
                    },
                },
            },

            {
                spellID = 1285732,
                name = "Howling Maelstorm (Intermission)",
                order = 40,
            },

            {
                spellID = -1285732,
                triggerSpellID = 1285732,
                kind = "howlingMaelstromWinds",
                name = "Howling Maelstorm Wind Bar",
                shortName = "Howling Maelstorm Winds",
                order = 45,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- The Twin Fangs
    ---------------------------------------------------------------------------
    {
        bossKey = "TwinFangs",
        bossName = "The Twin Fangs",
        bossOrder = 60,

        abilities = {
            {
                spellID = 1289192,
                name = "Caustic Deluge (Orbs)",
                defaultBarColor = "FF7400",
                order = 10,
            },

            {
                spellID = 1288538,
                name = "Stone Breaker (Tank Soaks + Knockback)",
                defaultBarColor = "C400FF",
                order = 20,
            },

            {
                spellID = 1308356,
                name = "Rouse The Brood (Adds)",
                defaultBarColor = "00FF41",
                order = 30,
                castTimeAdjustment = 3,
            },

            {
                spellID = 1290809,
                name = "Coiling Ichor (Red Circles)",
                defaultBarColor = "00FFC3",
                order = 40,
                castTimeAdjustment = 3,
            },

            {
                spellID = 1290516,
                name = "Ravenous Feast (Soaks)",
                defaultBarColor = "FF7400",
                defaultBarEnabled = false,
                order = 50,
            },

            {
                spellID = -1290516,
                triggerSpellID = 1290516,
                kind = "ravenousFeastHits",
                name = "Ravenous Feast Hit Bar",
                defaultBarColor = "FF7400",
                shortName = "Ravenous Feast Hits",
                order = 55,
            },

            {
                spellID = 1294293,
                name = "Vile Flood (Beam)",
                defaultBarColor = "FFF90F",
                defaultBarEnabled = false,
                order = 60,
            },

            {
                spellID = -1294293,
                triggerSpellID = 1294293,
                kind = "beamBar",
                name = "Beam Bar",
                defaultBarColor = "FFF90F",
                shortName = "Beam",
                ignoreTriggerDuration = 18,
                order = 65,
            },

            {
                spellID = -1290956,
                triggerSpellID = 1290956,
                kind = "markerSequence",
                name = "Stir The Depths (Raid Damage)",
                defaultBarColor = "FF0011",
                shortName = "Stir The Depths",
                order = 70,
                mechanic = {
                    duration = 6,
                    text = "Stir The Depths",
                    markers = {
                        { time = 0 },
                        { time = 2 },
                        { time = 4 },
                        { time = 6 },
                    },
                },
            },
        },
    },

    ---------------------------------------------------------------------------
    -- The Coiled Altar
    ---------------------------------------------------------------------------
    {
        bossKey = "CoiledAltar",
        bossName = "The Coiled Altar",
        bossOrder = 70,

        abilities = {
            {
                spellID = 1282487,
                name = "Fangs of the Crucible (Damage + Orbs)",
                defaultBarColor = "FF0011",
                order = 10,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1282487,
                postHitStages = {
                    stages = {
                        { duration = 7, text = "Fangs of the Crucible" },
                    },
                },
            },

            {
                spellID = 1299680,
                name = "Sever (Frontal)",
                defaultBarColor = "FFF90F",
                order = 20,
                castTimeAdjustment = 3,
                countdownTargetChoice = true,
            },

            {
                spellID = -1299680,
                triggerSpellIDs = { 1299680, 1307279 },
                kind = "latestPickup",
                name = "Latest Pickup Bar",
                shortName = "Latest Pickup",
                order = 25,
            },

            {
                spellID = 1299960,
                name = "Toxic Deluge (Orbs)",
                defaultBarColor = "00FF41",
                order = 30,
            },

            {
                spellID = 1283489,
                name = "Guillotine (Soak)",
                defaultBarColor = "FF7400",
                order = 40,
            },

            {
                spellID = 1282281,
                name = "Venomfang (DoT)",
                order = 45,
            },

            {
                spellID = -1283489,
                triggerSpellIDs = { 1283489, 1299266 },
                kind = "guillotineSequence",
                name = "Guillotine Hit/Explode Bar",
                defaultBarColor = "FF7400",
                shortName = "Guillotine Hit/Explode",
                order = 47,
            },

            {
                spellID = 1286573,
                legacySpellID = 1286620,
                name = "Soul Sever (Frontal)",
                defaultBarColor = "FFF90F",
                order = 50,
                castTimeAdjustment = 4,
                countdownTargetChoice = true,
            },

            {
                spellID = 1289900,
                legacySpellID = 1285643,
                name = "Dreadmarch (Mind Control)",
                defaultBarColor = "7400FF",
                order = 60,
            },

            {
                spellID = 1286918,
                name = "Eternal Nightfall (Shield + Raid Damage)",
                defaultBarColor = "FF0011",
                order = 70,
            },

            {
                spellID = 1286895,
                name = "Gloombomb (Bombs)",
                defaultBarColor = "00FFC3",
                order = 80,
                castTimeAdjustment = 2,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1286895,
                postHitStages = {
                    stages = {
                        { duration = 5, text = "Bomb hits" },
                    },
                },
            },

            {
                spellID = 1286441,
                name = "Spiritcackle (Interrupt Adds)",
                defaultBarColor = "00FF41",
                order = 90,
            },

            {
                spellID = 1307279,
                name = "Blighted Sever (Frontal)",
                defaultBarColor = "FFF90F",
                order = 100,
                castTimeAdjustment = 3,
                countdownTargetChoice = true,
            },

            {
                spellID = 1299266,
                legacySpellID = 1299267,
                name = "Grim Guillotine (Soak)",
                defaultBarColor = "FF7400",
                order = 110,
            },

            {
                spellID = 1298381,
                name = "Defilement of the Crucible (Healing Absorb)",
                defaultBarColor = "FF0011",
                order = 120,
                embeddedMechanicDefaultEnabled = true,
                legacyMergedSpellID = -1298381,
                postHitStages = {
                    stages = {
                        { duration = 7, text = "Defilement of the Crucible" },
                    },
                },
            },

            {
                spellID = 1283832,
                name = "Axegrinder (Dodge)",
                defaultBarColor = "E7FF00",
                order = 130,
                castTimeAdjustment = 2,
            },
        },
    },
    ---------------------------------------------------------------------------
    -- Ula'tek
    ---------------------------------------------------------------------------
    {
        bossKey = "Ulatek",
        bossName = "Ula'tek",
        bossOrder = 80,

        abilities = {
            {
                spellID = 1292999,
                name = "Submerge (Boss Dive)",
                defaultBarEnabled = false,
                order = 10,
            },
            {
                spellID = 1292188,
                name = "Caustic Waves (Waves)",
                defaultBarEnabled = false,
                order = 20,
            },
            {
                spellID = 1300751,
                name = "Call of the Serpent (Adds from ceiling)",
                defaultBarEnabled = false,
                order = 30,
            },
            {
                spellID = 1298367,
                name = "Mother's Wrath (Tank Hit)",
                defaultBarEnabled = false,
                order = 40,
            },
            {
                spellID = 1298559,
                name = "Gore Rattle",
                defaultBarEnabled = false,
                order = 50,
            },
            {
                spellID = 1296301,
                name = "Mephitic Thrash (Circle + Knock)",
                defaultBarEnabled = false,
                order = 60,
            },
            {
                spellID = 1300530,
                name = "Spectral Coils (Soaks)",
                defaultBarEnabled = false,
                order = 70,
            },
            {
                spellID = 1286860,
                name = "Rage of the Shackled (Swirlies)",
                defaultBarEnabled = false,
                order = 80,
            },
            {
                spellID = 1302982,
                name = "Virulent Spit (Swirlies)",
                defaultBarEnabled = false,
                order = 90,
            },
            {
                spellID = 1301510,
                name = "Circling Prey (Platform Break)",
                defaultBarEnabled = false,
                order = 100,
            },
            {
                spellID = 1295905,
                name = "Serpent's Bite (Debuff)",
                defaultBarEnabled = false,
                order = 110,
            },
            {
                spellID = 1286905,
                name = "Fury Unleashed (Enrage)",
                defaultBarEnabled = false,
                order = 120,
            },
        },
    },
}
