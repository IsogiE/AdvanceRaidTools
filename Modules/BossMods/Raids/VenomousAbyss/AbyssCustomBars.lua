local E = unpack(ART)

local ABILITY_MODULE = "BossMods_VenomousAbyssAbilityAlerts"

local definitions = {
    {
        key = "CoiledAltarNightfallBar",
        moduleName = "BossMods_CoiledAltarNightfallBar",
        labelKey = "BossMods_CoiledAltarNightfallBar",
        descKey = "BossMods_CoiledAltarNightfallBarDesc",
        legacyField = "coiledAltarNightfallBarEnabled",
        order = 10
    },
    {
        key = "UlatekShriekerBar",
        moduleName = "BossMods_UlatekShriekerBar",
        labelKey = "BossMods_UlatekBrightscaleShrieker",
        descKey = "BossMods_UlatekShriekerBarDesc",
        legacyField = "ulatekShriekerBarEnabled",
        order = 20
    }
}

local function refreshAbilityModule()
    local abilityMod = E:GetModule(ABILITY_MODULE, true)
    if abilityMod and abilityMod.Refresh then
        abilityMod:Refresh()
    end
end

for _, entry in ipairs(definitions) do
    local definition = entry
    E:RegisterModuleDefaults(definition.moduleName, {
        enabled = true,
        legacyPreferenceMigrated = false
    })

    local module = E:NewModule(definition.moduleName)

    function module:OnInitialize()
        if self.db.legacyPreferenceMigrated then
            return
        end

        local abilityMod = E:GetModule(ABILITY_MODULE, true)
        if abilityMod
            and abilityMod.db
            and abilityMod.db[definition.legacyField] == false
        then
            local BossMods = E:GetModule("BossMods", true)
            if BossMods then
                BossMods:SetFeatureEnabled(definition.key, false)
            end
        end
        self.db.legacyPreferenceMigrated = true
    end

    function module:OnEnable()
        E:SetModuleEnabled(ABILITY_MODULE, true)
        refreshAbilityModule()
    end

    function module:OnDisable()
        refreshAbilityModule()
    end

    E:RegisterBossModFeature(definition.key, {
        tab = "AbyssCustom",
        order = definition.order,
        labelKey = definition.labelKey,
        descKey = definition.descKey,
        moduleName = definition.moduleName
    })
end
