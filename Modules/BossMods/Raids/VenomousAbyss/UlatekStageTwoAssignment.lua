local E = unpack(ART)

local MODULE_NAME = "BossMods_UlatekStageTwoAssignment"
local ABILITY_MODULE_NAME = "BossMods_VenomousAbyssAbilityAlerts"
local ABILITY_ID = -3492006

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    arrow = {
        size = 58,
        x = 0,
        y = -55,
        color = {1, 0.82, 0.10, 1}
    }
})

local Mod = E:NewModule(MODULE_NAME)

function Mod:GetAbilityModule()
    return E:GetModule(ABILITY_MODULE_NAME, true)
end

function Mod:EnsureAbilityModule()
    local abilityMod = self:GetAbilityModule()

    if abilityMod and not abilityMod:IsEnabled() then
        E:SetModuleEnabled(ABILITY_MODULE_NAME, true)
    end

    return abilityMod
end

function Mod:GetAbilitySettings()
    local abilityMod = self:GetAbilityModule()
    if not abilityMod then return nil end
    if abilityMod.EnsureCustomBarDefaults then
        abilityMod:EnsureCustomBarDefaults()
    end
    local settings = abilityMod:GetAbilitySettings(ABILITY_ID)
    if settings and settings.text then
        settings.text.enabled = true
        settings.text.unattached = true
    end
    return settings
end

function Mod:GetAnchor()
    local abilityMod = self:GetAbilityModule()
    if not abilityMod then return nil end
    abilityMod:EnsurePreviewFrames(ABILITY_ID)
    local alert = abilityMod.textAlerts and abilityMod.textAlerts[ABILITY_ID]
    return alert and alert.frame
end

function Mod:GetPosition()
    local abilityMod = self:GetAbilityModule()
    return abilityMod and abilityMod:GetTextPosition(ABILITY_ID)
        or {point = "CENTER", x = 0, y = 120}
end

function Mod:SavePosition(position)
    local abilityMod = self:GetAbilityModule()
    if abilityMod then abilityMod:SaveTextPosition(ABILITY_ID, position) end
end

function Mod:SetEditMode(value)
    local abilityMod = self:GetAbilityModule()
    if not abilityMod then return end
    self:GetAbilitySettings()
    abilityMod:SetEditMode(value, "Ulatek", ABILITY_ID)
end

function Mod:Preview()
    local abilityMod = self:GetAbilityModule()
    if not abilityMod then return end
    self:GetAbilitySettings()
    abilityMod:SetEditMode(false, "Ulatek", ABILITY_ID)
    abilityMod:TestAbility(ABILITY_ID)
end

function Mod:Refresh()
    local abilityMod = self:GetAbilityModule()
    if not abilityMod then return end
    if abilityMod.CallIfEnabled then
        abilityMod:CallIfEnabled("Refresh")
    elseif abilityMod:IsEnabled() then
        abilityMod:Refresh()
    end
end

function Mod:OnInitialize()
    self.db.arrow = type(self.db.arrow) == "table" and self.db.arrow or {}
    self.db.arrow.size = tonumber(self.db.arrow.size) or 58
    self.db.arrow.x = tonumber(self.db.arrow.x) or 0
    self.db.arrow.y = tonumber(self.db.arrow.y) or -55
    self.db.arrow.color = type(self.db.arrow.color) == "table"
        and self.db.arrow.color or {1, 0.82, 0.10, 1}
end

function Mod:OnEnable()
    self:EnsureAbilityModule()
    self:GetAbilitySettings()
end

function Mod:OnDisable()
    local abilityMod = self:GetAbilityModule()
    if not abilityMod then return end
    abilityMod:InvalidateAbility(ABILITY_ID)
    local alert = abilityMod.textAlerts and abilityMod.textAlerts[ABILITY_ID]
    if alert then alert:Hide() end
    if abilityMod.HideAssignmentVisual then
        abilityMod:HideAssignmentVisual(abilityMod:GetAbility(ABILITY_ID))
    end
end

E:RegisterBossModFeature("UlatekStageTwoAssignment", {
    tab = "AbyssCustom",
    order = 74,
    bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek",
    bossOrder = 80,
    labelKey = "BossMods_UlatekStageTwoAssignment",
    navLabelKey = "BossMods_UlatekStageTwoAssignmentNav",
    descKey = "BossMods_UlatekStageTwoAssignmentDesc",
    moduleName = MODULE_NAME
})
