local E, L = unpack(ART)
local T = E.Templates
local BossMods = E:GetModule("BossMods")
local Displays = BossMods.DisplayTemplates
local GAP = 6

local function controls(parent)
    local tracker = T:MakeTracker()
    local width = parent:GetWidth()
    local ui = {tracker = tracker, y = 0, rows = {}}
    function ui:full(widget, opts)
        tracker.track(widget)
        self.rows[#self.rows + 1] = {full = widget, opts = opts}
        self.y = self.y + T:PlaceFull(parent, widget, self.y, width, opts) + GAP
    end
    function ui:row(widgets)
        for _, widget in ipairs(widgets) do tracker.track(widget) end
        self.rows[#self.rows + 1] = {widgets = widgets}
        self.y = self.y + T:PlaceRow(parent, widgets, self.y, width) + GAP
    end
    function ui:header(text) self:full(T:Header(parent, {text = text})) end
    function ui:layout()
        self.y = 0
        for _, row in ipairs(self.rows) do
            local height = row.full and T:PlaceFull(parent, row.full, self.y, parent:GetWidth(), row.opts)
                or T:PlaceRow(parent, row.widgets, self.y, parent:GetWidth())
            self.y = self.y + height + GAP
        end
        parent:SetHeight(self.y)
    end
    return ui
end

local function buildTemplates(host)
    local parent = CreateFrame("Frame", nil, host)
    parent:SetWidth(host:GetWidth())
    local ui = controls(parent)
    ui:header(L["BossMods_RaidAnchors"])
    ui:full(T:Description(parent, {
        text = L["BossMods_RaidAnchorsDesc"],
        sizeDelta = 1
    }))
    local moveButton = T:Button(parent, {
        text = L["BossMods_MoveAnchors"], width = 160, disabled = InCombatLockdown,
        onClick = function()
            if Displays:AreMoversShown() then
                Displays:HideMovers()
            else
                Displays:HidePreviews()
                for _, category in ipairs(Displays.templateOrder) do Displays:ShowMover(category) end
            end
            ui.tracker.refresh()
        end
    })
    local refreshMoveButton = moveButton.Refresh
    moveButton.Refresh = function()
        refreshMoveButton()
        moveButton.SetLabel(Displays:AreMoversShown() and L["BossMods_LockAnchors"] or L["BossMods_MoveAnchors"])
    end
    local previewButton = T:Button(parent, {
        text = L["Preview"], width = 160, disabled = InCombatLockdown,
        tooltip = L["BossMods_RaidAnchorsPreviewTooltip"],
        onClick = function()
            if Displays.previewActive then Displays:HidePreviews()
            else Displays:ShowPreviews() end
        end
    })
    local refreshPreviewButton = previewButton.Refresh
    previewButton.Refresh = function()
        refreshPreviewButton()
        previewButton.SetLabel(Displays.previewActive and L["HidePreview"] or L["Preview"])
    end
    ui:row({
        moveButton, previewButton,
        T:Button(parent, {
            text = L["BossMods_ResetAllPositions"], width = 160, disabled = InCombatLockdown,
            tooltip = L["BossMods_ResetAllPositionsTooltip"],
            confirm = L["BossMods_ResetAllPositionsConfirm"],
            confirmTitle = L["BossMods_ResetAllPositions"],
            onClick = function() Displays:ResetPositions(); ui.tracker.refresh() end
        })
    })
    for _, category in ipairs(Displays.templateOrder) do
        local key = category
        local template = Displays.templates[key]
        ui:full(T:PositionSectionWidget(parent, {
            headerText = template.label,
            showOffsets = true,
            hideUnlock = true,
            lockOnHide = false,
            isDisabled = InCombatLockdown,
            getPosition = function()
                local pos = Displays:GetSettings(key)
                return {point = pos.point, x = pos.x, y = pos.y}
            end,
            setPosition = function(pos) Displays:SetGroupPosition(key, pos) end,
            resetPosition = function() Displays:ResetGroupPosition(key) end,
            resetConfirm = L["BossMods_ResetAnchorPositionConfirm"]:format(template.label),
            resetConfirmTitle = L["ResetPosition"],
            onChanged = ui.tracker.refresh
        }), {padX = 0})
        if template.stack then
            ui:row({
                T:Dropdown(parent, {
                    label = L["BossMods_StackDirection"], values = {DOWN = L["Down"], UP = L["Up"], LEFT = L["Left"], RIGHT = L["Right"]},
                    sorting = {"DOWN", "UP", "LEFT", "RIGHT"},
                    get = function() return Displays:GetSettings(key).growth end,
                    onChange = function(value) Displays:GetSettings(key).growth = value; Displays:Layout(key) end,
                    disabled = InCombatLockdown
                }),
                T:NumericStepper(parent, {
                    label = L["Spacing"], min = 0, max = 150,
                    get = function() return Displays:GetSettings(key).spacing end,
                    set = function(value)
                        Displays:GetSettings(key).spacing = math.max(0, math.min(150, value))
                        Displays:Layout(key)
                    end,
                    disabled = InCombatLockdown
                })
            })
        end
    end
    parent:SetHeight(ui.y)
    parent:HookScript("OnHide", function() Displays:HideMovers(); Displays:HidePreviews() end)
    local callbacks = E:NewCallbackHandle()
    callbacks:RegisterMessage("ART_DISPLAY_POSITION_CHANGED", ui.tracker.refresh)
    callbacks:RegisterMessage("ART_DISPLAY_ANCHORS_CHANGED", ui.tracker.refresh)
    callbacks:RegisterEvent("PLAYER_REGEN_DISABLED", ui.tracker.refresh)
    callbacks:RegisterEvent("PLAYER_REGEN_ENABLED", ui.tracker.refresh)
    local handle = {frame = parent, height = ui.y, Refresh = ui.tracker.refresh}
    handle._relayout = function() ui:layout(); handle.height = ui.y end
    handle.Release = function()
        callbacks:UnregisterAllMessages()
        callbacks:UnregisterAllEvents()
        Displays:HideMovers()
        Displays:HidePreviews()
        ui.tracker.release()
        parent:Hide()
        parent:SetParent(nil)
    end
    return handle
end

BossMods:RegisterBossSettingsBuilder("DisplayTemplates", buildTemplates)
