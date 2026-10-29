local E = unpack(ART)
local BossMods = E:GetModule("BossMods")

BossMods:RegisterUnitFrameAuraFeature({
    featureKey = "CoiledAltarRaidFrameAuras", moduleName = "BossMods_CoiledAltarRaidFrameAuras",
    encounterID = 3429, tab = "VenomousAbyss", bossKey = "CoiledAltar",
    bossLabelKey = "BossMods_CoiledAltar", bossOrder = 70,
    displays = {{
        key = "coiled-altar-stage-1-boss-auras", label = "Guillotine (stage 1)", icon = 7966625,
        previewSpellIDs = {1283485},
        defaultEnabled = true, roles = {HEALER = true, TANK = true}, stages = {[1] = true},
        aura = {filters = {"HARMFUL"}, candidateFilters = {
            isBossAura = true, isFromPlayerOrPlayerPet = false
        }}
    }, {
        key = "coiled-altar-stage-2-important-auras", label = "Gravebound (stage 2)", icon = 7966625,
        previewSpellIDs = {1286837},
        defaultEnabled = false, roles = {HEALER = true}, stages = {[2] = true},
        aura = {filters = {"HARMFUL|IMPORTANT"}, candidateFilters = {
            isFromPlayerOrPlayerPet = false
        }}
    }, {
        key = "coiled-altar-stage-2-short-harmful-auras", label = "Gloombomb / Orb (stages 2-3)", icon = 7966625,
        previewSpellIDs = {1310881, 1282419, 1310498},
        defaultEnabled = true, roles = {HEALER = true}, stages = {[2] = true, [3] = true},
        hideDuringUnitChannel = "boss2",
        aura = {filters = {"HARMFUL|!IMPORTANT|!CROWD_CONTROL"}, candidateFilters = {
            isFromPlayerOrPlayerPet = false, isBossAura = false, maxDuration = 5
        }}
    }, {
        key = "coiled-altar-stage-3-boss-auras", label = "Grim Guillotine (stage 3)", icon = 7966625,
        previewSpellIDs = {1299266},
        defaultEnabled = true, roles = {HEALER = true, TANK = true}, stages = {[3] = true},
        aura = {filters = {"HARMFUL"}, candidateFilters = {
            isBossAura = true, isFromPlayerOrPlayerPet = false, maxDuration = 11
        }}
    }}
})

BossMods:RegisterUnitFrameAuraFeature({
    featureKey = "UlatekRaidFrameAuras", moduleName = "BossMods_UlatekRaidFrameAuras",
    encounterID = 3492, tab = "VenomousAbyss", bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek", bossOrder = 80,
    displays = {{
        key = "ulatek-boss-auras", label = "Boss aura (stage 3)", icon = 7966624,
        previewSpellIDs = {1293046, 1313529, 1312967},
        defaultEnabled = true, roles = {HEALER = true, DPS = true},
        stages = {[4] = true},
        aura = {filters = {"HARMFUL"}, candidateFilters = {
            isBossAura = false, isFromPlayerOrPlayerPet = false
        }}
    }}
})
