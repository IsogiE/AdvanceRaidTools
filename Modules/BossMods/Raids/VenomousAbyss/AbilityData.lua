local E, L = unpack(ART)

-- settingsKey values are locale-independent profile identifiers. Keep them
-- equal to the English short names used before these display labels moved to L.
E.VenomousAbyssAbilityData = {
    ---------------------------------------------------------------------------
    -- Nek'zali
    ---------------------------------------------------------------------------
    {
        bossKey = "Nekzali",
        bossName = L["BossMods_VA_Boss_Nekzali"],
        bossOrder = 10,

        abilities = {
            {
                spellID = 1285681,
                settingsKey = "Soulcoil Ignition",
                name = L["BossMods_VA_Ability_SoulcoilIgnition"],
                defaultBarColor = "FF0011",
                order = 10,
            },

            {
                spellID = 1292036,
                settingsKey = "possessionBarrage",
                name = L["BossMods_VA_Ability_PossessionBarrage"],
                defaultBarColor = "FF0011",
                order = 20,
                castTimeAdjustment = 6,
                castWindowBar = true,
            },

            {
                spellID = 1287426,
                settingsKey = "Essence Rend",
                name = L["BossMods_VA_Ability_EssenceRend"],
                defaultBarColor = "00FFC3",
                order = 30,
            },

            {
                spellID = 1299673,
                settingsKey = "Invoke",
                name = L["BossMods_VA_Ability_Invoke"],
                defaultBarColor = "0044FF",
                order = 40,
                castTimeAdjustment = 5,
            },

            {
                spellID = 1305421,
                settingsKey = "hungeringPyre",
                name = L["BossMods_VA_Ability_HungeringPyre"],
                defaultBarColor = "FF7400",
                order = 50,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 7.5, text = L["BossMods_VA_Stage_Soak"] },
                    },
                },
            },

            {
                spellID = 1293212,
                settingsKey = "Grasping Depths",
                name = L["BossMods_VA_Ability_GraspingDepths"],
                defaultBarColor = "F7FF00",
                order = 60,
            },

            {
                spellID = -1293212,
                triggerSpellID = 1293212,
                kind = "assignmentText",
                textOnly = true,
                settingsKey = "Grasping Depths Assignment",
                name = L["BossMods_VA_Ability_GraspingDepthsAssignment"],
                shortName = L["BossMods_VA_Ability_GraspingDepthsAssignment"],
                defaultBarEnabled = false,
                defaultTextEnabled = true,
                defaultTextSecondsBefore = 5,
                order = 65,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- Entombed Sentinels
    ---------------------------------------------------------------------------
    {
        bossKey = "EntombedSentinels",
        bossName = L["BossMods_VA_Boss_EntombedSentinels"],
        bossOrder = 20,

        abilities = {
            {
                spellID = 1284588,
                settingsKey = "vitrolicStasis",
                name = L["BossMods_VA_Ability_VitrolicStasis"],
                defaultBarColor = "FF7400",
                order = 10,
            },

            {
                spellID = 1296878,
                settingsKey = "Shifting Protovenom",
                name = L["BossMods_VA_Ability_ShiftingProtovenom"],
                defaultBarColor = "C400FF",
                order = 20,
            },

            {
                spellID = 1284251,
                settingsKey = "Venom Coagulation",
                name = L["BossMods_VA_Ability_VenomCoagulation"],
                defaultBarColor = "00FF41",
                order = 30,
            },

            {
                spellID = 1284434,
                settingsKey = "Toxic Droplets",
                name = L["BossMods_VA_Ability_ToxicDroplets"],
                defaultBarColor = "FF7400",
                order = 40,
                castTimeAdjustment = 2,
            },

            {
                spellID = 1288232,
                settingsKey = "Unstable Miasma",
                name = L["BossMods_VA_Ability_UnstableMiasma"],
                defaultBarColor = "FF7400",
                order = 60,
                castTimeAdjustment = 1,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 8, text = L["BossMods_VA_Stage_Soak"] },
                        { duration = 7, text = L["BossMods_VA_Stage_PoolDrop"] },
                    },
                },
            },

            {
                spellID = 1284483,
                settingsKey = "Blighted Blood",
                name = L["BossMods_VA_Ability_BlightedBlood"],
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
        bossName = L["BossMods_VA_Boss_LostExplorers"],
        bossOrder = 30,

        abilities = {
            {
                spellID = 1296092,
                settingsKey = "Mighty Thud",
                name = L["BossMods_VA_Ability_MightyThud"],
                defaultBarColor = "FF7400",
                defaultBarEnabled = false,
                order = 10,
            },

            {
                spellID = -1296092,
                triggerSpellID = 1296092,
                kind = "mightyThudHits",
                settingsKey = "Mighty Thud Hit",
                name = L["BossMods_VA_Ability_MightyThudHitBar"],
                defaultBarColor = "FF7400",
                shortName = L["BossMods_VA_Short_MightyThudHit"],
                order = 15,
            },

            {
                spellID = 1291759,
                settingsKey = "shellSpin",
                name = L["BossMods_VA_Ability_ShellSpin"],
                defaultBarColor = "FFF90F",
                order = 20,
            },

            {
                spellID = 1290711,
                settingsKey = "blinkNova",
                name = L["BossMods_VA_Ability_BlinkNova"],
                defaultBarColor = "FF0011",
                order = 30,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 7, text = L["BossMods_VA_Stage_Teleport"] },
                    },
                },
            },

            {
                spellID = 1295886,
                settingsKey = "Frostfire Volley",
                name = L["BossMods_VA_Ability_FrostfireVolley"],
                defaultBarColor = "FF7400",
                order = 40,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 8, text = L["BossMods_VA_Stage_FrostfireVolley"] },
                    },
                },
            },

            {
                spellID = 1292104,
                settingsKey = "Mushroom Toss",
                name = L["BossMods_VA_Ability_MushroomToss"],
                defaultBarColor = "FFF90F",
                order = 50,
                castTimeAdjustment = 7,
            },

            {
                spellID = 1296249,
                settingsKey = "explosiveSurprise",
                name = L["BossMods_VA_Ability_ExplosiveSurprise"],
                defaultBarColor = "FF7400",
                order = 60,
            },

            {
                spellID = 1286921,
                settingsKey = "Icebound Flames",
                name = L["BossMods_VA_Ability_IceboundFlames"],
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
        bossName = L["BossMods_VA_Boss_Vashnik"],
        bossOrder = 40,

        abilities = {
            {
                spellID = 1283164,
                settingsKey = "Imbibe",
                name = L["BossMods_VA_Ability_Imbibe"],
                defaultBarColor = "FF0011",
                order = 10,
            },

            {
                spellID = 1281907,
                settingsKey = "Plague Froth",
                name = L["BossMods_VA_Ability_PlagueFroth"],
                barName = L["BossMods_VA_Stage_Waves"],
                defaultBarColor = "00FFC3",
                order = 20,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    countDown = true,
                    stages = {
                        { duration = 6, text = L["BossMods_VA_Stage_Waves"] },
                    },
                },
            },

            {
                spellID = 1282525,
                settingsKey = "Malignant Catalyst",
                name = L["BossMods_VA_Ability_MalignantCatalyst"],
                barName = "Damage+Soaks",
                defaultBarColor = "FF7400",
                order = 30,
                castTimeAdjustment = 5,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    countDown = true,
                    stages = {
                        {
                            duration = 7,
                            text = L["BossMods_VA_Stage_Soaks"],
                            barText = "Catch",
                        },
                    },
                },
            },

            {
                spellID = 1282117,
                settingsKey = "Adaptive Infection",
                name = L["BossMods_VA_Ability_AdaptiveInfection"],
                barName = "Absorbs+Dispels",
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
        bossName = L["BossMods_VA_Boss_Sszorak"],
        bossOrder = 50,

        abilities = {
            {
                spellID = 1277025,
                settingsKey = "Apex Predator",
                name = L["BossMods_VA_Ability_ApexPredator"],
                order = 10,
            },

            {
                spellID = 1285425,
                settingsKey = "ragingCrosswinds",
                name = L["BossMods_VA_Ability_RagingCrosswinds"],
                order = 20,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 8, text = L["BossMods_VA_Stage_Knock"] },
                    },
                },
            },

            {
                spellID = 1305959,
                settingsKey = "Venomous Surge",
                name = L["BossMods_VA_Ability_VenomousSurge"],
                order = 30,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 4, text = L["BossMods_VA_Stage_VenomousSurge"] },
                    },
                },
            },

            {
                spellID = 1285732,
                settingsKey = "Howling Maelstorm",
                name = L["BossMods_VA_Ability_HowlingMaelstorm"],
                order = 40,
            },

            {
                spellID = -1285732,
                triggerSpellID = 1285732,
                kind = "howlingMaelstromWinds",
                settingsKey = "Howling Maelstorm Winds",
                name = L["BossMods_VA_Ability_HowlingMaelstormWindBar"],
                shortName = L["BossMods_VA_Short_HowlingMaelstormWinds"],
                order = 45,
            },
        },
    },

    ---------------------------------------------------------------------------
    -- The Twin Fangs
    ---------------------------------------------------------------------------
    {
        bossKey = "TwinFangs",
        bossName = L["BossMods_VA_Boss_TwinFangs"],
        bossOrder = 60,

        abilities = {
            {
                spellID = 1289192,
                settingsKey = "Caustic Deluge",
                name = L["BossMods_VA_Ability_CausticDeluge"],
                defaultBarColor = "FF7400",
                order = 10,
            },

            {
                spellID = 1288538,
                settingsKey = "Stone Breaker",
                name = L["BossMods_VA_Ability_StoneBreaker"],
                defaultBarColor = "C400FF",
                order = 20,
            },

            {
                spellID = 1308356,
                settingsKey = "Rouse The Brood",
                name = L["BossMods_VA_Ability_RouseTheBrood"],
                defaultBarColor = "00FF41",
                order = 30,
                castTimeAdjustment = 3,
            },

            {
                spellID = 1290809,
                settingsKey = "Coiling Ichor",
                name = L["BossMods_VA_Ability_CoilingIchor"],
                defaultBarColor = "00FFC3",
                order = 40,
                castTimeAdjustment = 3,
            },

            {
                spellID = 1290516,
                settingsKey = "Ravenous Feast",
                name = L["BossMods_VA_Ability_RavenousFeast"],
                defaultBarColor = "FF7400",
                defaultBarEnabled = false,
                order = 50,
            },

            {
                spellID = -1290516,
                triggerSpellID = 1290516,
                kind = "ravenousFeastHits",
                settingsKey = "Ravenous Feast Hits",
                name = L["BossMods_VA_Ability_RavenousFeastHitBar"],
                defaultBarColor = "FF7400",
                shortName = L["BossMods_VA_Short_RavenousFeastHits"],
                order = 55,
            },

            {
                spellID = 1294293,
                settingsKey = "Vile Flood",
                name = L["BossMods_VA_Ability_VileFlood"],
                defaultBarColor = "FFF90F",
                defaultBarEnabled = false,
                order = 60,
            },

            {
                spellID = -1294293,
                triggerSpellID = 1294293,
                kind = "beamBar",
                settingsKey = "Beam",
                name = L["BossMods_VA_Ability_BeamBar"],
                defaultBarColor = "FFF90F",
                shortName = L["BossMods_VA_Short_Beam"],
                ignoreTriggerDuration = 18,
                order = 65,
            },

            {
                spellID = -1290956,
                triggerSpellID = 1290956,
                kind = "markerSequence",
                settingsKey = "Stir The Depths",
                name = L["BossMods_VA_Ability_StirTheDepths"],
                defaultBarColor = "FF0011",
                shortName = L["BossMods_VA_Short_StirTheDepths"],
                order = 70,
                mechanic = {
                    duration = 6,
                    text = L["BossMods_VA_Marker_StirTheDepths"],
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
        bossName = L["BossMods_VA_Boss_CoiledAltar"],
        bossOrder = 70,

        abilities = {
            {
                spellID = 1282487,
                settingsKey = "Fangs of the Crucible",
                name = L["BossMods_VA_Ability_FangsOfTheCrucible"],
                defaultBarColor = "FF0011",
                order = 10,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 7, text = L["BossMods_VA_Stage_FangsOfTheCrucible"] },
                    },
                },
            },

            {
                spellID = 1299680,
                settingsKey = "Sever",
                name = L["BossMods_VA_Ability_Sever"],
                defaultBarColor = "FFF90F",
                order = 20,
                castTimeAdjustment = 3,
                countdownTargetChoice = true,
            },

            {
                spellID = -1299680,
                triggerSpellIDs = { 1299680, 1307279 },
                kind = "latestPickup",
                settingsKey = "Latest Pickup",
                name = L["BossMods_VA_Ability_LatestPickupBar"],
                shortName = L["BossMods_VA_Short_LatestPickup"],
                order = 25,
            },

            {
                spellID = 1299960,
                settingsKey = "Toxic Deluge",
                name = L["BossMods_VA_Ability_ToxicDeluge"],
                defaultBarColor = "00FF41",
                order = 30,
            },

            {
                spellID = 1283489,
                settingsKey = "Guillotine",
                name = L["BossMods_VA_Ability_Guillotine"],
                defaultBarColor = "FF7400",
                order = 40,
            },

            {
                spellID = 1282281,
                settingsKey = "Venomfang",
                name = L["BossMods_VA_Ability_Venomfang"],
                order = 45,
            },

            {
                spellID = -1283489,
                triggerSpellIDs = { 1283489, 1299266 },
                kind = "guillotineSequence",
                settingsKey = "Guillotine Hit/Explode",
                name = L["BossMods_VA_Ability_GuillotineHitExplodeBar"],
                defaultBarColor = "FF7400",
                shortName = L["BossMods_VA_Short_GuillotineHitExplode"],
                order = 47,
            },

            {
                spellID = -1299266,
                triggerSpellIDs = { 1283489, 1299266 },
                kind = "assignmentText",
                assignmentType = "guillotine",
                assignmentAudio = true,
                textOnly = true,
                settingsKey = "Guillotine Assignment",
                name = L["BossMods_VA_Ability_GuillotineAssignment"],
                shortName = L["BossMods_VA_Ability_GuillotineAssignment"],
                defaultBarEnabled = false,
                defaultTextEnabled = true,
                defaultTextUnattached = true,
                defaultTextSecondsBefore = 5,
                defaultTextPosition = {
                    point = "CENTER",
                    x = 0,
                    y = 120,
                },
                defaultTextPositionVersion = 1,
                previousDefaultTextPosition = {
                    point = "CENTER",
                    x = 0,
                    y = -120,
                },
                defaultAudioSecondsBefore = 3,
                defaultAudioTTSText = "Soak",
                order = 48,
            },

            {
                spellID = 1286573,
                settingsKey = "soulSever",
                name = L["BossMods_VA_Ability_SoulSever"],
                defaultBarColor = "FFF90F",
                order = 50,
                castTimeAdjustment = 4,
                countdownTargetChoice = true,
            },

            {
                spellID = 1289900,
                settingsKey = "dreadmarch",
                name = L["BossMods_VA_Ability_Dreadmarch"],
                defaultBarColor = "7400FF",
                order = 60,
            },

            {
                spellID = 1286918,
                settingsKey = "Eternal Nightfall",
                name = L["BossMods_VA_Ability_EternalNightfall"],
                defaultBarColor = "FF0011",
                order = 70,
            },

            {
                spellID = 1286895,
                settingsKey = "Gloombomb",
                name = L["BossMods_VA_Ability_Gloombomb"],
                defaultBarColor = "00FFC3",
                order = 80,
                castTimeAdjustment = 2,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 5, text = L["BossMods_VA_Stage_BombHits"] },
                    },
                },
            },

            {
                spellID = 1286441,
                settingsKey = "Spiritcackle",
                name = L["BossMods_VA_Ability_Spiritcackle"],
                defaultBarColor = "00FF41",
                order = 90,
            },

            {
                spellID = 1307279,
                settingsKey = "Blighted Sever",
                name = L["BossMods_VA_Ability_BlightedSever"],
                defaultBarColor = "FFF90F",
                order = 100,
                castTimeAdjustment = 3,
                countdownTargetChoice = true,
            },

            {
                spellID = 1299266,
                settingsKey = "grimGuillotine",
                name = L["BossMods_VA_Ability_GrimGuillotine"],
                defaultBarColor = "FF7400",
                order = 110,
            },

            {
                spellID = 1298381,
                settingsKey = "Defilement of the Crucible",
                name = L["BossMods_VA_Ability_DefilementOfTheCrucible"],
                defaultBarColor = "FF0011",
                order = 120,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    stages = {
                        { duration = 7, text = L["BossMods_VA_Stage_DefilementOfTheCrucible"] },
                    },
                },
            },

            {
                spellID = 1283832,
                settingsKey = "Axegrinder",
                name = L["BossMods_VA_Ability_Axegrinder"],
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
        bossName = L["BossMods_VA_Boss_Ulatek"],
        bossOrder = 80,

        abilities = {
            {
                spellID = 1292999,
                settingsKey = "Submerge",
                name = L["BossMods_VA_Ability_Submerge"],
                defaultBarEnabled = false,
                order = 10,
            },
            {
                spellID = 1292188,
                settingsKey = "Caustic Waves",
                name = L["BossMods_VA_Ability_CausticWaves"],
                defaultBarEnabled = false,
                order = 20,
            },
            {
                spellID = 1300751,
                settingsKey = "Call of the Serpent",
                name = L["BossMods_VA_Ability_CallOfTheSerpent"],
                defaultBarEnabled = false,
                order = 30,
            },
            {
                spellID = 1298367,
                settingsKey = "Mother's Wrath",
                name = L["BossMods_VA_Ability_MothersWrath"],
                defaultBarEnabled = false,
                order = 40,
            },
            {
                spellID = 1298559,
                settingsKey = "Gore Rattle",
                name = L["BossMods_VA_Ability_GoreRattle"],
                defaultBarEnabled = false,
                order = 50,
            },
            {
                spellID = 1296301,
                settingsKey = "Mephitic Thrash",
                name = L["BossMods_VA_Ability_MephiticThrash"],
                defaultBarEnabled = false,
                order = 60,
                castTimeAdjustment = 4,
            },
            {
                spellID = 1300530,
                settingsKey = "Spectral Coils",
                name = L["BossMods_VA_Ability_SpectralCoils"],
                defaultBarEnabled = false,
                order = 70,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    countDown = true,
                    stages = {
                        {
                            duration = 12,
                            barText = L["BossMods_VA_Stage_Soaks"],
                            showText = false,
                            markers = {
                                {time = 8},
                                {time = 11},
                            },
                        },
                    },
                },
            },
            {
                spellID = 1286860,
                settingsKey = "Rage of the Shackled",
                name = L["BossMods_VA_Ability_RageOfTheShackled"],
                defaultBarEnabled = false,
                order = 80,
                ignoreTriggerDuration = 6.5,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    countDown = true,
                    stages = {
                        {
                            duration = 20,
                            barText = "",
                            showText = false,
                            markers = {
                                {time = 16},
                                {time = 12},
                                {time = 8},
                                {time = 4},
                                {time = 0},
                            },
                        },
                    },
                },
            },
            {
                spellID = 1302982,
                settingsKey = "Virulent Spit",
                name = L["BossMods_VA_Ability_VirulentSpit"],
                defaultBarEnabled = false,
                order = 90,
                embeddedMechanicDefaultEnabled = true,
                postHitStages = {
                    countDown = true,
                    stages = {
                        {
                            duration = 10,
                            barText = "",
                            showText = false,
                            markers = {
                                {time = 4},
                                {time = 5},
                                {time = 6},
                                {time = 7},
                                {time = 8},
                                {time = 9},
                                {time = 10},
                            },
                        },
                    },
                },
            },
            {
                spellID = 1301510,
                settingsKey = "Circling Prey",
                name = L["BossMods_VA_Ability_CirclingPrey"],
                defaultBarEnabled = false,
                order = 100,
            },
            {
                spellID = -3492006,
                kind = "assignmentText",
                assignmentType = "ulatekStage2",
                hideInAbilityAlerts = true,
                textOnly = true,
                settingsKey = "Stage 2 Side Assignment",
                name = L["BossMods_VA_Ability_StageTwoSideAssignment"],
                shortName = L["BossMods_VA_Ability_StageTwoSideAssignment"],
                defaultBarEnabled = false,
                defaultTextEnabled = true,
                defaultTextSecondsBefore = 5,
                order = 105,
            },
            {
                spellID = 1295905,
                settingsKey = "Serpent's Bite",
                name = L["BossMods_VA_Ability_SerpentsBite"],
                defaultBarEnabled = false,
                order = 110,
            },
            {
                spellID = 1286905,
                settingsKey = "Fury Unleashed",
                name = L["BossMods_VA_Ability_FuryUnleashed"],
                defaultBarEnabled = false,
                order = 120,
            },
            {
                spellID = -3492005,
                settingsKey = "Knock Up",
                name = L["BossMods_VA_Ability_KnockUp"],
                defaultBarEnabled = false,
                order = 130,
            },
        },
    },
}
