local E = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_UlatekNameplateBuffs"
local ENCOUNTER_ID = 3492
local RAWLING_LEVEL = 91
local GROUP_KEY = "ARTUlatekNameplateBuffs"
local ICON_SIZE = 30

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    strata = "MEDIUM",
    size = ICON_SIZE,
    offsetX = 8,
    offsetY = 0,
    maxIcons = 8
})

local Buffs = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function initializeAuraButton(button)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetMouseClickEnabled(false)
    button:SetMouseMotionEnabled(false)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetIcon(icon)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    button:SetDurationCooldown(cooldown)

    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    local duration = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    duration:SetPoint("BOTTOM", 0, 1)
    duration:SetTextColor(1, 1, 1)
    button:SetDurationText(duration)

    local count = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetPoint("TOPRIGHT", -1, -1)
    count:SetTextColor(1, 1, 1)
    button:SetApplicationCount(count)
end

function Buffs:LoadAuraContainer()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer")
end

function Buffs:CreateDisplay()
    local anchor = CreateFrame("Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
    anchor:SetFrameStrata(self.db.strata or "MEDIUM")
    anchor:SetFrameLevel(95)
    anchor:Hide()
    local container = CreateFrame("AuraContainer", nil, anchor,
        "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
    container:SetEnabled(false)
    container:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:AddAuraGroup(GROUP_KEY, "HELPFUL", {
        maxFrameCount = self.db.maxIcons,
        sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
        sortDirection = AuraContainerSortDirection.Normal,
        initializeFrame = initializeAuraButton,
        layout = {elementWidth = ICON_SIZE, elementHeight = ICON_SIZE, elementSpacing = 2}
    })
    return {anchor = anchor, container = container}
end

function Buffs:ApplyDisplaySettings(display)
    local size = math.max(16, math.min(80, tonumber(self.db.size) or ICON_SIZE))
    display.anchor:SetFrameStrata(self.db.strata or "MEDIUM")
    display.anchor:SetSize(size, size)
    display.container:SetScale(size / ICON_SIZE)
    display.container:SetAuraGroupMaxFrameCount(GROUP_KEY,
        math.max(1, math.min(10, math.floor(tonumber(self.db.maxIcons) or 8))))
    if display.plate then
        BossMods.KickDisplay.AnchorToNameplate(display.anchor, display.plate,
            "RIGHT", self.db.offsetX, self.db.offsetY)
    end
end

function Buffs:RemoveNameplate(unit)
    local display = self.displays[unit]
    if not display then return end
    display.anchor:Hide()
    display.container:SetEnabled(false)
    display.container:SetUnit("none")
    display.anchor:ClearAllPoints()
    display.plate = nil
end

function Buffs:AddNameplate(unit)
    if not self.encounterActive or not self.auraContainerReady then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or not UnitIsEnemy("player", unit) or UnitLevel(unit) ~= RAWLING_LEVEL then
        self:RemoveNameplate(unit)
        return
    end
    local display = self.displays[unit]
    if not display then
        display = self:CreateDisplay()
        self.displays[unit] = display
    end
    display.plate = plate
    self:ApplyDisplaySettings(display)
    display.container:SetUnit(unit)
    display.container:SetEnabled(true)
    display.anchor:Show()
    display.container:UpdateAllAuras()
end

function Buffs:RefreshNameplates()
    local active = {}
    if self.encounterActive then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = plate.namePlateUnitToken
            if unit then
                active[unit] = true
                self:AddNameplate(unit)
            end
        end
    end
    for unit in pairs(self.displays) do
        if not active[unit] then self:RemoveNameplate(unit) end
    end
end

function Buffs:NAME_PLATE_UNIT_ADDED(_, unit)
    self:AddNameplate(unit)
end

function Buffs:NAME_PLATE_UNIT_REMOVED(_, unit)
    self:RemoveNameplate(unit)
end

function Buffs:OnEncounterStart(_, encounterID)
    self.encounterActive = encounterID == ENCOUNTER_ID
    self:RefreshNameplates()
end

function Buffs:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then return end
    self.encounterActive = false
    self:RefreshNameplates()
end

function Buffs:OnLeavingWorld()
    self.encounterActive = false
    self:RefreshNameplates()
end

function Buffs:Refresh()
    if not self:IsEnabled() then return end
    self.auraContainerReady = self:LoadAuraContainer()
    self:RefreshNameplates()
end

function Buffs:OnInitialize()
    self.displays = {}
    self.encounterActive = false
end

function Buffs:OnEnable()
    self:Refresh()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("PLAYER_LEAVING_WORLD", "OnLeavingWorld")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
end

function Buffs:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self:RefreshNameplates()
end

E:RegisterBossModFeature("UlatekNameplateBuffs", {
    tab = "VenomousAbyss",
    order = 100,
    bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek",
    bossOrder = 80,
    labelKey = "BossMods_UlatekNameplateBuffs",
    navLabelKey = "BossMods_UlatekNameplateBuffsNav",
    descKey = "BossMods_UlatekNameplateBuffsDesc",
    moduleName = MODULE_NAME
})
