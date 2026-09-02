local E = unpack(ART)

local BossMods = E:GetModule("BossMods")

local ENCOUNTER_ID = 3492
local CAUSTIC_WAVES_SPELL_ID = 1292188

BossMods:RegisterTimelineSequenceFeature({
    moduleName = "BossMods_UlatekWaves",
    featureKey = "UlatekWaves",
    tab = "AbyssCustom",
    order = 72,
    labelKey = "BossMods_UlatekWaves",
    descKey = "BossMods_UlatekWavesDesc",
    encounterID = ENCOUNTER_ID,
    timerSpellID = CAUSTIC_WAVES_SPELL_ID,
    bigWigsModuleName = "Ula'tek",
    stageRequired = 1,
    endStage = 2,
    duplicateWindow = 2,
    maxSequenceCount = 2,
    previewSequenceKey = 2,
    position = {point = "CENTER", x = 0, y = 200},
    width = 360,
    height = 24,
    spacing = 4,
    rows = {
        {
            key = "sequence",
            labelKey = "BossMods_TimelineSequenceStageColor",
            color = {0.1, 0.75, 0.9, 1}
        },
        {
            key = "main",
            labelKey = "BossMods_TimelineSequenceMainColor",
            color = {1, 0.45, 0.05, 1}
        }
    },
    sequences = {
        [1] = {
            rows = {
                sequence = {
                    phases = {
                        {textKey = "BossMods_VA_UlatekWave_BossWaves", duration = 6},
                        {textKey = "BossMods_VA_UlatekWave_TailWaves", duration = 3},
                        {textKey = "BossMods_VA_UlatekWave_BossTailWaves", duration = 4},
                        {textKey = "BossMods_VA_UlatekWave_Behind", duration = 2},
                        {textKey = "BossMods_VA_UlatekWave_Sides", duration = 4.2}
                    }
                },
                main = {
                    start = 6,
                    duration = 16,
                    textKey = "BossMods_VA_Stage_Waves"
                }
            }
        },
        [2] = {
            rows = {
                sequence = {
                    phases = {
                        {textKey = "BossMods_VA_UlatekWave_BossWaves", duration = 6},
                        {textKey = "BossMods_VA_UlatekWave_TailWaves", duration = 3},
                        {textKey = "BossMods_VA_UlatekWave_BossTailWaves", duration = 4},
                        {textKey = "BossMods_VA_UlatekWave_Behind", duration = 2},
                        {textKey = "BossMods_VA_UlatekWave_Sides", duration = 4.2},
                        {textKey = "BossMods_VA_UlatekWave_Extra", duration = 5.7}
                    }
                },
                main = {
                    start = 6,
                    duration = 22,
                    textKey = "BossMods_VA_Stage_Waves"
                }
            }
        }
    }
})
