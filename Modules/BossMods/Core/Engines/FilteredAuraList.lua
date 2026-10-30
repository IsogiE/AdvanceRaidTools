local E = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/BossMods/Core/Engines/FilteredAuraList")
local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines

function Engines.FilteredAuraList(config)
    local anchor = CreateFrame("Frame", nil, UIParent)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetSize(200, 22)
    anchor:Hide()
    local live = CreateFrame("Frame", nil, anchor)
    live:SetAllPoints()
    local preview = CreateFrame("Frame", nil, anchor)
    preview:SetAllPoints()
    preview:Hide()
    local entries, previewRows = {}, {}
    local enabled, editMode = false, false
    local settings = CopyTable(config.getSettings())
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({{
        threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%d"
    }})
    local handle = {frame = anchor}

    local function applyButton(button, entry)
        local height, width = settings.rowHeight, settings.width
        button:SetSize(width, height)
        button.artIcon:SetSize(height, height)
        button.artBar:SetStatusBarTexture(Engines.Shared.FetchStatusBar(settings.texture))
        local color = RAID_CLASS_COLORS[entry.class] or {r = 0.3, g = 0.6, b = 1}
        button.artBar:SetStatusBarColor(color.r, color.g, color.b, 0.65)
        local font = Engines.Shared.FetchFont(settings.font)
        button.artName:SetFont(font, settings.fontSize, "OUTLINE")
        button.artName:SetText(entry.name)
        button.artDuration:SetFont(font, settings.fontSize, "OUTLINE")
        button.artCount:SetFont(font, math.max(8, settings.fontSize - 2), "OUTLINE")
    end

    local function initializeButton(button, entry, isPreview)
        button:EnableMouse(false)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT")
        button.artIcon = icon
        local bar = CreateFrame("StatusBar", nil, button)
        bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, 0)
        bar:SetPoint("BOTTOMRIGHT")
        local background = bar:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.65)
        local duration = bar:CreateFontString(nil, "OVERLAY")
        duration:SetPoint("RIGHT", -3, 0)
        local name = bar:CreateFontString(nil, "OVERLAY")
        name:SetPoint("LEFT", 4, 0)
        name:SetPoint("RIGHT", duration, "LEFT", -5, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        local count = bar:CreateFontString(nil, "OVERLAY")
        count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        button.artBar, button.artName, button.artDuration, button.artCount = bar, name, duration, count
        if isPreview then
            icon:SetTexture(136182)
            bar:SetMinMaxValues(0, 10)
            bar:SetValue(7)
            duration:SetText("7")
        else
            button:SetIcon(icon)
            button:SetDurationBar(bar, {
                interpolation = Enum.StatusBarInterpolation.Immediate,
                direction = Enum.StatusBarTimerDirection.RemainingTime
            })
            button:SetDurationText(duration, {textFormatter = formatter})
            button:SetApplicationCount(count)
        end
        entry.buttons[#entry.buttons + 1] = button
        applyButton(button, entry)
    end

    local function createEntry(index)
        local container = CreateFrame("AuraContainer", nil, live,
            "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
        container:SetUnit("none")
        container:SetEnabled(false)
        container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
        container:SetFlowLayoutAnchorPoint("TOPLEFT")
        container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        local entry = {container = container, buttons = {}, name = "", class = "PRIEST"}
        if index > 1 then
            container:SetPoint("TOPLEFT", entries[index - 1].container, "BOTTOMLEFT", 0, 1)
        else
            container:SetPoint("TOPLEFT", live, "TOPLEFT")
        end
        container:AddAuraGroup("debuffs", "HARMFUL", {
            candidateFilters = {isPriorityAura = true},
            sortMethod = AuraContainerSortMethod.ExpirationOnly,
            sortDirection = AuraContainerSortDirection.Normal,
            initializeFrame = function(button) initializeButton(button, entry) end,
            layout = {elementWidth = settings.width, elementHeight = settings.rowHeight + settings.spacing + 1}
        })
        return entry
    end

    function handle:Refresh()
        if not Engines.CanConfigureUnitFrameAuras() then return end
        if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
            if not ok or not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then return end
        end
        local nextSettings = CopyTable(config.getSettings())
        settings = nextSettings
        anchor:SetSize(settings.width, settings.rowHeight)
        local members = config.getMembers()
        for index = 1, 40 do
            local entry = entries[index]
            if not entry then entry = createEntry(index); entries[index] = entry end
            local member = members[index]
            entry.container:SetEnabled(false)
            entry.container:SetUnit("none")
            entry.container:SetFlowLayoutMaximumLineSize(settings.width)
            entry.container:SetAuraGroupLayout("debuffs", {
                elementWidth = settings.width,
                elementHeight = settings.rowHeight + settings.spacing + 1
            })
            if member then
                entry.name, entry.class = member.name, member.class
                for _, button in ipairs(entry.buttons) do applyButton(button, entry) end
                entry.container:SetUnit(member.unit)
                entry.container:SetEnabled(enabled)
            end
            entry.container:Show()
        end
        for index = 1, settings.previewRows do
            local row = previewRows[index]
            local entry = {buttons = {}, name = "Player " .. index, class = index % 2 == 0 and "MAGE" or "PRIEST"}
            if not row then
                row = CreateFrame("Frame", nil, preview)
                initializeButton(row, entry, true)
                previewRows[index] = row
            end
            applyButton(row, entry)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -(index - 1) * (settings.rowHeight + settings.spacing))
            row:Show()
        end
        for index = settings.previewRows + 1, #previewRows do previewRows[index]:Hide() end
        anchor:SetShown(enabled)
        live:SetShown(not editMode)
        preview:SetShown(editMode)
    end

    function handle:SetActive(value)
        enabled = value == true
        anchor:SetShown(enabled)
        self:Refresh()
    end

    function handle:SetEditMode(value)
        editMode = value == true
        live:SetShown(not editMode)
        if not editMode then preview:Hide() end
        self:Refresh()
    end

    return handle
end
