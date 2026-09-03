local E = unpack(ART)

local MODULE_NAME = "BossMods_HealerAuras"

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = false,
    selectedAura = "gloombomb",
    auras = {gloombomb = {
        enabled = true,
        showIcon = true,
        iconSize = 36,
        iconPosition = {point = "CENTER", x = 0, y = 0},
        showGlow = false,
        glowType = "Pixel",
        glowColor = {0.55, 0.20, 1, 1},
        glowLines = 8,
        glowFrequency = 3,
        glowThickness = 2,
        glowScale = 10
    }}
})

E:NewModule(MODULE_NAME, "AceEvent-3.0")

E:RegisterBossModFeature("HealerAuras", {
    tab = "AbyssCustom",
    order = 10,
    bossKey = "CoiledAltar",
    bossLabelKey = "BossMods_CoiledAltar",
    bossOrder = 70,
    labelKey = "BossMods_HealerAuras",
    descKey = "BossMods_HealerAurasDesc",
    moduleName = MODULE_NAME
})
