local E, L = unpack(ART)

local ENCOUNTER_ID = 3421
local INSTANCE_ID = 3004
local ETERNAL_VENOM_ID = 1290336
local SEGMENT_COUNT = 9
local DANGER_START = 7
local MAX_RAID_ROWS = 40
local DEFAULT_FONT = "Friz Quadrata TT"

local PERSONAL_DEFAULTS = {
    enabled = false,
    position = {point = "CENTER", x = 0, y = -180},
    width = 300,
    height = 30,
    scale = 1,
    opacity = 1,
    backgroundOpacity = 0.55,
    font = {name = DEFAULT_FONT, size = 15, outline = "OUTLINE"},
    safeColor = {0.12, 0.72, 0.20, 1},
    dangerColor = {0.92, 0.12, 0.10, 1}
}

local LIST_DEFAULTS = {
    enabled = false,
    position = {point = "CENTER", x = 360, y = 0},
    width = 360,
    height = 20,
    rowSpacing = 2,
    scale = 1,
    opacity = 1,
    backgroundOpacity = 0.55,
    font = {name = DEFAULT_FONT, size = 12, outline = "OUTLINE"},
    safeColor = {0.12, 0.72, 0.20, 1},
    dangerColor = {0.92, 0.12, 0.10, 1}
}

E:RegisterModuleDefaults("BossMods_TwinFangsDelugeBar", PERSONAL_DEFAULTS)
E:RegisterModuleDefaults("BossMods_TwinFangsDelugeList", LIST_DEFAULTS)

local DelugeBar = E:NewModule("BossMods_TwinFangsDelugeBar", "AceEvent-3.0")
local DelugeList = E:NewModule("BossMods_TwinFangsDelugeList", "AceEvent-3.0")

local function currentLocationIsSupported()
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    return tonumber(mapID) == INSTANCE_ID
end

local function areAurasRestricted()
    if not C_Secrets or type(C_Secrets.ShouldAurasBeSecret) ~= "function" then
        return false
    end
    local ok, restricted = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or restricted == true
end

local function loadAuraContainer()
    if not C_AddOns or type(C_AddOns.LoadAddOn) ~= "function" then
        return false
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        if not ok then
            return false
        end
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") == true
end

local function copyColor(color, fallback)
    color = type(color) == "table" and color or fallback
    return color[1] or color.r or fallback[1],
        color[2] or color.g or fallback[2],
        color[3] or color.b or fallback[3],
        color[4] or color.a or fallback[4] or 1
end

local function getDisplayName(unit)
    if E.GetNickname then
        local nickname = E:GetNickname(unit)
        if type(nickname) == "string" and nickname ~= "" then
            return nickname
        end
    end
    return (UnitNameUnmodified and UnitNameUnmodified(unit)) or UnitName(unit) or unit
end

local function getClassColor(unit)
    local classFile = UnitClassBase and UnitClassBase(unit)
    if not classFile then
        local _, fallback = UnitClass(unit)
        classFile = fallback
    end
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b, 1
    end
    return 1, 1, 1, 1
end

local function getAuraIcon()
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(ETERNAL_VENOM_ID)
    return info and info.iconID or 136016
end

local function getFont(db)
    db.font = db.font or {}
    db.font.name = db.font.name or DEFAULT_FONT
    db.font.size = tonumber(db.font.size) or 12
    db.font.outline = db.font.outline or "OUTLINE"
    return E:FetchFont(db.font.name), db.font.size, db.font.outline
end

local function getGeometry(module, isList)
    local width = math.max(isList and 240 or 180, tonumber(module.db.width) or (isList and 360 or 300))
    local height = math.max(14, tonumber(module.db.height) or (isList and 20 or 30))
    local countWidth = math.max(48, math.floor(height * 2.35))
    local nameWidth = isList and math.max(76, math.floor(width * 0.28)) or 0
    local iconWidth = isList and 0 or height
    local gap = 3
    local barLeft = nameWidth + iconWidth + (iconWidth > 0 and gap or 0)
    local barWidth = math.max(90, width - barLeft - countWidth - gap)
    return {
        width = width,
        height = height,
        countWidth = countWidth,
        nameWidth = nameWidth,
        iconWidth = iconWidth,
        gap = gap,
        barLeft = barLeft,
        barWidth = barWidth
    }
end

local function createNumericFormatter()
    if not C_StringUtil or not C_StringUtil.CreateNumericRuleFormatter
        or not Enum.NumericRuleFormatRounding then
        return nil
    end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    local ok = pcall(formatter.SetBreakpoints, formatter, {
        {
            threshold = 0,
            format = "%d",
            step = 1,
            rounding = Enum.NumericRuleFormatRounding.Down
        }
    })
    return ok and formatter or nil
end

local function createStaticRow(parent)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetBackdrop({bgFile = E.media.blankTex})

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexture(getAuraIcon())
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetJustifyH("LEFT")

    row.zero = row:CreateFontString(nil, "OVERLAY")
    row.zero:SetJustifyH("RIGHT")

    row.maximum = row:CreateFontString(nil, "OVERLAY")
    row.maximum:SetJustifyH("LEFT")

    row.segmentBackgrounds = {}
    row.previewFills = {}
    row.separators = {}
    for index = 1, SEGMENT_COUNT do
        row.segmentBackgrounds[index] = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.previewFills[index] = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row.previewFills[index]:Hide()
        if index < SEGMENT_COUNT then
            row.separators[index] = row:CreateTexture(nil, "OVERLAY", nil, 4)
            row.separators[index]:SetColorTexture(0, 0, 0, 1)
        end
    end
    return row
end

local function styleStaticRow(module, row, isList)
    local geo = getGeometry(module, isList)
    local font, fontSize, outline = getFont(module.db)
    local safeR, safeG, safeB, safeA = copyColor(module.db.safeColor, PERSONAL_DEFAULTS.safeColor)
    local dangerR, dangerG, dangerB, dangerA = copyColor(module.db.dangerColor, PERSONAL_DEFAULTS.dangerColor)
    local bgAlpha = math.max(0, math.min(1, tonumber(module.db.backgroundOpacity) or 0.55))

    row:SetSize(geo.width, geo.height)
    row:SetBackdropColor(0, 0, 0, bgAlpha)

    row.icon:ClearAllPoints()
    if isList then
        row.icon:Hide()
    else
        row.icon:SetSize(geo.iconWidth, geo.height)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.icon:Show()
    end

    row.name:ClearAllPoints()
    if isList then
        row.name:SetPoint("LEFT", row, "LEFT", 3, 0)
        row.name:SetWidth(geo.nameWidth - 6)
        row.name:Show()
    else
        row.name:Hide()
    end
    E:ApplyFontString(row.name, font, math.max(8, fontSize), outline)

    local segmentWidth = geo.barWidth / SEGMENT_COUNT
    for index = 1, SEGMENT_COUNT do
        local left = geo.barLeft + (index - 1) * segmentWidth
        local width = index == SEGMENT_COUNT and (geo.barLeft + geo.barWidth - left) or segmentWidth
        local background = row.segmentBackgrounds[index]
        background:ClearAllPoints()
        background:SetPoint("TOPLEFT", row, "TOPLEFT", left, 0)
        background:SetSize(width, geo.height)
        if index >= DANGER_START then
            background:SetColorTexture(dangerR, dangerG, dangerB, bgAlpha * 0.45)
        else
            background:SetColorTexture(safeR, safeG, safeB, bgAlpha * 0.45)
        end

        local preview = row.previewFills[index]
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", row, "TOPLEFT", left, 0)
        preview:SetSize(width, geo.height)
        if index >= DANGER_START then
            preview:SetColorTexture(dangerR, dangerG, dangerB, dangerA)
        else
            preview:SetColorTexture(safeR, safeG, safeB, safeA)
        end

        if index < SEGMENT_COUNT then
            local separator = row.separators[index]
            separator:ClearAllPoints()
            separator:SetPoint("TOP", row, "TOP", 0, 0)
            separator:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
            separator:SetPoint("LEFT", row, "LEFT", geo.barLeft + index * segmentWidth - 0.5, 0)
            separator:SetWidth(1)
        end
    end

    E:ApplyFontString(row.zero, font, math.max(8, fontSize), outline)
    E:ApplyFontString(row.maximum, font, math.max(8, fontSize), outline)
    row.zero:SetText("0")
    row.maximum:SetText("/ 10")
    row.zero:ClearAllPoints()
    row.zero:SetPoint("RIGHT", row, "RIGHT", -math.floor(geo.countWidth * 0.55), 0)
    row.zero:SetWidth(math.floor(geo.countWidth * 0.35))
    row.maximum:ClearAllPoints()
    row.maximum:SetPoint("LEFT", row.zero, "RIGHT", 2, 0)
    row.maximum:SetWidth(math.floor(geo.countWidth * 0.55))
end

local function setPreviewStacks(row, count)
    count = math.max(0, math.min(SEGMENT_COUNT, tonumber(count) or 0))
    for index = 1, SEGMENT_COUNT do
        row.previewFills[index]:SetShown(index <= count)
    end
    row.zero:SetText(tostring(count))
end

local function configureAuraButton(module, button, row, isList)
    local geo = getGeometry(module, isList)
    local font, fontSize, outline = getFont(module.db)
    local safeR, safeG, safeB, safeA = copyColor(module.db.safeColor, PERSONAL_DEFAULTS.safeColor)
    local dangerR, dangerG, dangerB, dangerA = copyColor(module.db.dangerColor, PERSONAL_DEFAULTS.dangerColor)
    local bgAlpha = math.max(0, math.min(1, tonumber(module.db.backgroundOpacity) or 0.55))

    local regions = button._artDelugeRegions
    if not regions then
        regions = {}
        button._artDelugeRegions = regions
        if button.SetMouseClickEnabled then
            button:SetMouseClickEnabled(false)
        end
        if button.SetMouseMotionEnabled then
            button:SetMouseMotionEnabled(false)
        end

        regions.bar = CreateFrame("StatusBar", nil, button)
        regions.bar:SetOrientation("HORIZONTAL")
        regions.bar:SetStatusBarTexture(E.media.blankTex)
        regions.fill = regions.bar:GetStatusBarTexture()

        regions.mask = regions.bar:CreateMaskTexture()
        regions.mask:SetTexture(
            "Interface\\Buttons\\WHITE8x8",
            "CLAMPTOBLACKADDITIVE",
            "CLAMPTOBLACKADDITIVE",
            "NEAREST"
        )
        regions.mask:SetAllPoints(regions.fill)

        regions.danger = regions.bar:CreateTexture(nil, "ARTWORK", nil, 1)
        regions.danger:AddMaskTexture(regions.mask)

        regions.countBackground = button:CreateTexture(nil, "ARTWORK", nil, 2)
        regions.count = button:CreateFontString(nil, "OVERLAY")
        regions.count:SetJustifyH("RIGHT")
        E:ApplyFontString(regions.count, font, math.max(8, fontSize), outline)

        regions.separators = {}
        for index = 1, SEGMENT_COUNT - 1 do
            local separator = button:CreateTexture(nil, "OVERLAY", nil, 4)
            separator:SetColorTexture(0, 0, 0, 1)
            regions.separators[index] = separator
        end

        local barOptions = {maxApplications = SEGMENT_COUNT}
        if Enum.StatusBarInterpolation then
            barOptions.interpolation = Enum.StatusBarInterpolation.Immediate
        end
        button:SetApplicationBar(regions.bar, barOptions)

        local formatter = createNumericFormatter()
        button:SetApplicationCount(
            regions.count,
            formatter and {formatter = formatter} or nil
        )
    end

    button:SetSize(geo.width, geo.height)
    regions.bar:ClearAllPoints()
    regions.bar:SetPoint("TOPLEFT", button, "TOPLEFT", geo.barLeft, 0)
    regions.bar:SetSize(geo.barWidth, geo.height)
    regions.fill:SetVertexColor(safeR, safeG, safeB, safeA)

    local dangerLeft = geo.barWidth * (DANGER_START - 1) / SEGMENT_COUNT
    regions.danger:ClearAllPoints()
    regions.danger:SetPoint("TOPLEFT", regions.bar, "TOPLEFT", dangerLeft, 0)
    regions.danger:SetPoint("BOTTOMRIGHT", regions.bar, "BOTTOMRIGHT", 0, 0)
    regions.danger:SetColorTexture(dangerR, dangerG, dangerB, dangerA)

    local segmentWidth = geo.barWidth / SEGMENT_COUNT
    for index, separator in ipairs(regions.separators) do
        separator:ClearAllPoints()
        separator:SetPoint("TOP", button, "TOP", 0, 0)
        separator:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
        separator:SetPoint("LEFT", button, "LEFT", geo.barLeft + index * segmentWidth - 0.5, 0)
        separator:SetWidth(1)
    end

    regions.countBackground:ClearAllPoints()
    regions.countBackground:SetPoint("TOPRIGHT", button, "TOPRIGHT", -math.floor(geo.countWidth * 0.55), 0)
    regions.countBackground:SetSize(math.floor(geo.countWidth * 0.45), geo.height)
    regions.countBackground:SetColorTexture(0, 0, 0, bgAlpha)

    regions.count:ClearAllPoints()
    regions.count:SetPoint("RIGHT", button, "RIGHT", -math.floor(geo.countWidth * 0.55), 0)
    regions.count:SetWidth(math.floor(geo.countWidth * 0.35))
    E:ApplyFontString(regions.count, font, math.max(8, fontSize), outline)
    regions.count:SetTextColor(1, 1, 1, 1)
end

local function createAuraContainer(module, parent, unit, row, isList)
    local container = CreateFrame(
        "AuraContainer",
        nil,
        parent,
        "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate"
    )
    container:SetFrameStrata("HIGH")
    container:SetUnit(unit)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(
        AnchorUtil.FlowDirection.Right,
        AnchorUtil.FlowDirection.Down
    )
    container:AddAuraGroup("ARTTwinFangsEternalVenom", "HARMFUL", {
        maxFrameCount = 1,
        -- Harmful auras on friendly units cannot be identity-filtered while
        -- aura secrecy is active. Eternal Venom is the permanent, non-role,
        -- non-player aura in this encounter, so use the same safe filter and
        -- expiration ordering as the working NSRT Twin Fangs overview.
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        candidateFilters = {
            isFromPlayerOrPlayerPet = false,
            isBossOrRoleAura = false
        },
        initializeFrame = function(button)
            configureAuraButton(module, button, row, isList)
        end,
        layout = {
            elementWidth = 1,
            elementHeight = 1,
            elementSpacing = 0,
            lineSpacing = 0
        }
    })
    container:SetEnabled(false)
    container:Hide()
    return container
end

local function ensurePersonalFrames(module)
    if module.frames then
        return true
    end
    local anchor = CreateFrame(
        "Frame",
        "ART_TwinFangsDelugeBar",
        UIParent,
        "DisableUntrustedLayoutScriptsTemplate"
    )
    anchor:SetClampedToScreen(true)
    anchor:Hide()
    local row = createStaticRow(anchor)
    row:SetAllPoints(anchor)
    module.frames = {anchor = anchor, row = row}
    return true
end

local function ensurePersonalContainer(module)
    if module.container then
        return true
    end
    if not ensurePersonalFrames(module) or not loadAuraContainer() or areAurasRestricted() then
        module.pendingSecureRefresh = true
        return false
    end
    module.container = createAuraContainer(module, module.frames.anchor, "player", module.frames.row, false)
    module.container:SetAllPoints(module.frames.anchor)
    module.pendingSecureRefresh = false
    return true
end

local function ensureListFrames(module)
    if module.frames then
        return true
    end
    local anchor = CreateFrame(
        "Frame",
        "ART_TwinFangsDelugeList",
        UIParent,
        "DisableUntrustedLayoutScriptsTemplate"
    )
    anchor:SetClampedToScreen(true)
    anchor:Hide()
    module.frames = {anchor = anchor, rows = {}}
    for index = 1, MAX_RAID_ROWS do
        local row = createStaticRow(anchor)
        row.unit = "raid" .. index
        module.frames.rows[index] = row
    end
    return true
end

local function ensureListContainers(module)
    if module.containers then
        return true
    end
    if not ensureListFrames(module) or not loadAuraContainer() or areAurasRestricted() then
        module.pendingSecureRefresh = true
        return false
    end
    module.containers = {}
    for index, row in ipairs(module.frames.rows) do
        local container = createAuraContainer(module, row, row.unit, row, true)
        container:SetAllPoints(row)
        module.containers[index] = container
    end
    module.pendingSecureRefresh = false
    return true
end

local PersonalMethods = {}

function PersonalMethods:ApplySettings()
    ensurePersonalFrames(self)
    local geo = getGeometry(self, false)
    local anchor, row = self.frames.anchor, self.frames.row
    anchor:SetSize(geo.width, geo.height)
    anchor:SetScale(tonumber(self.db.scale) or 1)
    anchor:SetAlpha(tonumber(self.db.opacity) or 1)
    E:ApplyFramePosition(anchor, self.db.position)
    styleStaticRow(self, row, false)
    if self.container and not areAurasRestricted() then
        for index = 1, self.container:GetAuraGroupFrameCount("ARTTwinFangsEternalVenom") do
            local button = self.container:GetAuraGroupFrame("ARTTwinFangsEternalVenom", index)
            if button then
                pcall(configureAuraButton, self, button, row, false)
            end
        end
    end
end

function PersonalMethods:ApplyVisibility()
    ensurePersonalFrames(self)
    local preview = self.editMode == true or self.previewMode == true
    local live = self.encounterActive == true and currentLocationIsSupported()
    self.frames.anchor:SetShown(preview or live)
    setPreviewStacks(self.frames.row, preview and 8 or 0)
    self.frames.row.zero:SetShown(preview)
    if preview then
        self.frames.row.zero:SetText("8")
    end
    if ensurePersonalContainer(self) then
        self.container:SetShown(live and not preview)
        self.container:SetEnabled(live and not preview)
    end
end

function PersonalMethods:SetPreviewMode(value)
    self.previewMode = value == true
    self:ApplyVisibility()
end

function PersonalMethods:SetEditMode(value)
    self.editMode = value == true
    self:ApplyVisibility()
end

function PersonalMethods:SavePosition(position)
    self.db.position.point = position.point or "CENTER"
    self.db.position.x = tonumber(position.x) or 0
    self.db.position.y = tonumber(position.y) or 0
    self:ApplySettings()
end

function PersonalMethods:Refresh()
    self:ApplySettings()
    self:ApplyVisibility()
end

function PersonalMethods:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == ENCOUNTER_ID
    self:ApplyVisibility()
end

function PersonalMethods:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) == ENCOUNTER_ID then
        self.encounterActive = false
        self:ApplyVisibility()
    end
end

function PersonalMethods:OnRegenEnabled()
    if self.pendingSecureRefresh then
        ensurePersonalContainer(self)
    end
    self:Refresh()
end

function PersonalMethods:OnInitialize()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    ensurePersonalFrames(self)
    self:ApplySettings()
    ensurePersonalContainer(self)
end

function PersonalMethods:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:Refresh()
end

function PersonalMethods:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    if self.container then
        self.container:SetEnabled(false)
        self.container:Hide()
    end
    if self.frames then
        self.frames.anchor:Hide()
    end
end

local ListMethods = {}

function ListMethods:ApplySettings()
    ensureListFrames(self)
    local geo = getGeometry(self, true)
    local spacing = math.max(0, tonumber(self.db.rowSpacing) or 2)
    local anchor = self.frames.anchor
    anchor:SetSize(geo.width, MAX_RAID_ROWS * geo.height + (MAX_RAID_ROWS - 1) * spacing)
    anchor:SetScale(tonumber(self.db.scale) or 1)
    anchor:SetAlpha(tonumber(self.db.opacity) or 1)
    E:ApplyFramePosition(anchor, self.db.position)

    local previous
    for _, row in ipairs(self.frames.rows) do
        row:ClearAllPoints()
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -spacing)
        else
            row:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        end
        styleStaticRow(self, row, true)
        previous = row
    end

    if self.containers and not areAurasRestricted() then
        for index, container in ipairs(self.containers) do
            local row = self.frames.rows[index]
            for buttonIndex = 1, container:GetAuraGroupFrameCount("ARTTwinFangsEternalVenom") do
                local button = container:GetAuraGroupFrame("ARTTwinFangsEternalVenom", buttonIndex)
                if button then
                    pcall(configureAuraButton, self, button, row, true)
                end
            end
        end
    end
end

function ListMethods:UpdateNames()
    for _, row in ipairs(self.frames and self.frames.rows or {}) do
        row.name:SetText(getDisplayName(row.unit))
        row.name:SetTextColor(getClassColor(row.unit))
    end
end

function ListMethods:ApplyVisibility()
    ensureListFrames(self)
    self:UpdateNames()
    local preview = self.editMode == true or self.previewMode == true
    local live = self.encounterActive == true and currentLocationIsSupported()
    local visibleRows = 0
    for index, row in ipairs(self.frames.rows) do
        local rowVisible = preview and index <= 20 or (live and UnitExists(row.unit))
        row:SetShown(rowVisible)
        if rowVisible then
            visibleRows = visibleRows + 1
        end
        if preview and rowVisible then
            local stacks = ((index * 3) % SEGMENT_COUNT) + 1
            setPreviewStacks(row, stacks)
            row.zero:Show()
            row.name:SetText(index == 1 and (UnitName("player") or "Player") or ("Raid Player " .. index))
        else
            setPreviewStacks(row, 0)
            row.zero:Hide()
        end
    end

    local geo = getGeometry(self, true)
    local spacing = math.max(0, tonumber(self.db.rowSpacing) or 2)
    self.frames.anchor:SetHeight(math.max(geo.height, visibleRows * geo.height + math.max(0, visibleRows - 1) * spacing))
    self.frames.anchor:SetShown(preview or (live and visibleRows > 0))

    if ensureListContainers(self) then
        for index, container in ipairs(self.containers) do
            local enabled = live and not preview and UnitExists(self.frames.rows[index].unit)
            container:SetShown(enabled)
            container:SetEnabled(enabled)
        end
    end
end

function ListMethods:SetPreviewMode(value)
    self.previewMode = value == true
    self:ApplyVisibility()
end

function ListMethods:SetEditMode(value)
    self.editMode = value == true
    self:ApplyVisibility()
end

function ListMethods:SavePosition(position)
    self.db.position.point = position.point or "CENTER"
    self.db.position.x = tonumber(position.x) or 0
    self.db.position.y = tonumber(position.y) or 0
    self:ApplySettings()
end

function ListMethods:Refresh()
    self:ApplySettings()
    self:ApplyVisibility()
end

function ListMethods:OnRosterChanged()
    self:ApplyVisibility()
end

function ListMethods:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == ENCOUNTER_ID
    self:ApplyVisibility()
end

function ListMethods:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) == ENCOUNTER_ID then
        self.encounterActive = false
        self:ApplyVisibility()
    end
end

function ListMethods:OnRegenEnabled()
    if self.pendingSecureRefresh then
        ensureListContainers(self)
    end
    self:Refresh()
end

function ListMethods:OnInitialize()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    ensureListFrames(self)
    self:ApplySettings()
    ensureListContainers(self)
end

function ListMethods:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "OnRosterChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:Refresh()
end

function ListMethods:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    for _, container in ipairs(self.containers or {}) do
        container:SetEnabled(false)
        container:Hide()
    end
    if self.frames then
        self.frames.anchor:Hide()
    end
end

for name, method in pairs(PersonalMethods) do
    DelugeBar[name] = method
end
for name, method in pairs(ListMethods) do
    DelugeList[name] = method
end

E:RegisterBossModFeature("TwinFangsDelugeBar", {
    tab = "AbyssCustom",
    order = 56,
    bossKey = "TwinFangs",
    bossLabelKey = "BossMods_TwinFangs",
    bossOrder = 60,
    labelKey = "BossMods_TwinFangsDelugeBar",
    navLabelKey = "BossMods_TwinFangsDelugeBarNav",
    descKey = "BossMods_TwinFangsDelugeBarDesc",
    moduleName = "BossMods_TwinFangsDelugeBar"
})

E:RegisterBossModFeature("TwinFangsDelugeList", {
    tab = "AbyssCustom",
    order = 57,
    bossKey = "TwinFangs",
    bossLabelKey = "BossMods_TwinFangs",
    bossOrder = 60,
    labelKey = "BossMods_TwinFangsDelugeList",
    navLabelKey = "BossMods_TwinFangsDelugeListNav",
    descKey = "BossMods_TwinFangsDelugeListDesc",
    moduleName = "BossMods_TwinFangsDelugeList"
})

