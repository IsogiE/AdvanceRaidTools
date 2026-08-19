local E = unpack(ART)

local MODULE_NAME = "BossMods_AbilityAlertDefaults"
local Shared = E:GetModule("BossMods").Engines.Shared
local normalizeAnchorPoint = Shared.NormalizeAnchorPoint
local getCenterRelativePosition = Shared.GetCenterRelativePosition
local updateAnchorPointMarker = Shared.UpdateAnchorPointMarker

local defaults = {
    enabled = true,

    groupAnchors = {
        bar = {
            point = "CENTER",
            x = -400,
            y = 80,
            growth = "DOWN",
            spacing = 4
        },
        text = {
            point = "CENTER",
            x = 0,
            y = 200,
            growth = "DOWN",
            spacing = 8
        }
    },

    appearance = {
        bar = {
            width = 300,
            height = 24,
            iconEnabled = true,
            iconSize = 24,
            texture = "Clean",
            fillColor = {0.20, 0.60, 1.00, 1.00},
            backgroundColor = {0.00, 0.00, 0.00, 1.00},
            backgroundOpacity = 0.30,
            font = {
                name = "Friz Quadrata TT",
                size = 14,
                outline = "OUTLINE"
            }
        },

        text = {
            font = {
                name = "Friz Quadrata TT",
                size = 34,
                outline = "THICKOUTLINE"
            }
        }
    }
}

E:RegisterModuleDefaults(MODULE_NAME, defaults)

local AlertDefaults = E:NewModule(MODULE_NAME)
E:SetModuleParent(MODULE_NAME, "BossMods")

function AlertDefaults:GetAppearance()
    self.db.appearance = self.db.appearance or {}

    local appearance = self.db.appearance
    appearance.bar = appearance.bar or {}
    appearance.bar.font = appearance.bar.font or {}
    appearance.text = appearance.text or {}
    appearance.text.font = appearance.text.font or {}

    appearance.bar.width = tonumber(appearance.bar.width) or 300
    appearance.bar.height = tonumber(appearance.bar.height) or 24
    if appearance.bar.iconEnabled == nil then
        appearance.bar.iconEnabled = true
    end
    appearance.bar.iconSize = tonumber(appearance.bar.iconSize) or 24
    appearance.bar.texture = appearance.bar.texture or "Clean"
    appearance.bar.fillColor = appearance.bar.fillColor or {0.20, 0.60, 1.00, 1.00}
    appearance.bar.backgroundColor = appearance.bar.backgroundColor or {0.00, 0.00, 0.00, 1.00}

    if self.db.backgroundOpacityDefaultVersion ~= 1 then
        local currentOpacity = tonumber(appearance.bar.backgroundOpacity)

        if currentOpacity == nil
            or math.abs(currentOpacity - 0.65) < 0.0001
        then
            appearance.bar.backgroundOpacity = 0.30
        end

        self.db.backgroundOpacityDefaultVersion = 1
    end

    appearance.bar.backgroundOpacity = tonumber(appearance.bar.backgroundOpacity) or 0.30
    appearance.bar.font.name = appearance.bar.font.name or "Friz Quadrata TT"
    appearance.bar.font.size = tonumber(appearance.bar.font.size) or 14
    appearance.bar.font.outline = appearance.bar.font.outline or "OUTLINE"

    appearance.text.font.name = appearance.text.font.name or "Friz Quadrata TT"
    appearance.text.font.size = tonumber(appearance.text.font.size) or 34
    appearance.text.font.outline = appearance.text.font.outline or "THICKOUTLINE"

    return appearance
end

local function buildPreviewBarConfig(appearance)
    local bar = appearance.bar or {}
    local font = bar.font or {}
    local fill = bar.fillColor or {0.20, 0.60, 1.00, 1.00}
    local background = bar.backgroundColor or {0, 0, 0, 1}

    return {
        parent = UIParent,
        showFill = true,
        strata = "DIALOG",
        textUpdateInterval = 0.1,
        size = { w = bar.width or 300, h = bar.height or 24 },
        icon = {
            enabled = bar.iconEnabled ~= false,
            size = bar.iconSize or 24,
            texture = 134400
        },
        statusBar = { texture = bar.texture or "Clean", color = fill },
        label = { font = font.name, size = font.size, outline = font.outline, color = {1,1,1,1}, justify = "LEFT" },
        right = { font = font.name, size = font.size, outline = font.outline, color = {1,1,1,1}, justify = "RIGHT" },
        background = { color = background, opacity = bar.backgroundOpacity or 0.30 },
        border = { enabled = true, texture = "Pixel", size = 1, color = {0,0,0,1} }
    }
end

local function buildPreviewTextConfig(appearance)
    local text = appearance.text or {}
    local font = text.font or {}
    return {
        parent = UIParent,
        strata = "DIALOG",
        size = { w = 600, h = 80 },
        font = { name = font.name, size = font.size, outline = font.outline, color = {1,1,1,1} }
    }
end

function AlertDefaults:GetGroupSettings(kind)
    self.db.groupAnchors = self.db.groupAnchors or {}
    self.db.groupAnchors[kind] =
        self.db.groupAnchors[kind] or {}

    local fallbackX = kind == "bar" and -400 or 0
    local fallbackY = kind == "bar" and 80 or 200
    local fallbackSpacing = kind == "bar" and 4 or 8
    local settings = self.db.groupAnchors[kind]

    settings.point = normalizeAnchorPoint(settings.point)
    settings.x = tonumber(settings.x) or fallbackX
    settings.y = tonumber(settings.y) or fallbackY
    settings.growth =
        settings.growth == "UP" and "UP" or "DOWN"
    settings.spacing =
        math.max(
            0,
            tonumber(settings.spacing) or fallbackSpacing
        )

    return settings
end

function AlertDefaults:GetPreviewPosition(kind)
    return self:GetGroupSettings(kind)
end

function AlertDefaults:GetPreviewCount(kind)
    local key = kind == "bar" and "previewBarCount" or "previewTextCount"
    local count = math.floor(tonumber(self[key]) or 1)
    count = math.max(1, math.min(4, count))
    self[key] = count
    return count
end

function AlertDefaults:SetPreviewCount(kind, count)
    local key = kind == "bar" and "previewBarCount" or "previewTextCount"
    self[key] = math.max(1, math.min(4, math.floor(tonumber(count) or 1)))

    if self.previewActive then
        self:RefreshPreview()
        self:RestartPreviewFrames()
    end
end

function AlertDefaults:ApplyPreviewPositions()
    local function applyFrames(frames, kind)
        local position = self:GetPreviewPosition(kind)
        local group = self:GetGroupSettings(kind)
        local growthSign = group.growth == "UP" and 1 or -1

        for index, preview in ipairs(frames or {}) do
            local frame = preview.frame
            local offset = 0

            if index > 1 then
                if kind == "bar" then
                    local appearance = self:GetAppearance()
                    local height = tonumber(appearance.bar.height) or 24
                    offset = (index - 1) * (height + group.spacing) * growthSign
                else
                    local appearance = self:GetAppearance()
                    local fontSize =
                        tonumber(
                            appearance.text
                            and appearance.text.font
                            and appearance.text.font.size
                        ) or 34
                    local rowHeight = math.max(fontSize + 8, 24)
                    offset =
                        (index - 1)
                        * (rowHeight + group.spacing)
                        * growthSign
                end
            end

            frame:ClearAllPoints()
            frame:SetPoint(
                position.point,
                UIParent,
                "CENTER",
                position.x,
                position.y + offset
            )

            if index == 1 then
                updateAnchorPointMarker(
                    frame,
                    position.point
                )
            end
        end
    end

    applyFrames(self.previewBars, "bar")
    applyFrames(self.previewTexts, "text")
end

function AlertDefaults:SetPreviewUnlocked(unlocked)
    local previewStrata = unlocked and "MEDIUM" or "DIALOG"

    local function setGroupStrata(previews)
        for _, preview in ipairs(previews or {}) do
            if preview.frame then
                preview.frame:SetFrameStrata(previewStrata)
            end
        end
    end

    setGroupStrata(self.previewBars)
    setGroupStrata(self.previewTexts)

    local function configure(frame, kind)
        if not frame then
            return
        end

        if unlocked then
            frame:SetMovable(true)
            frame:EnableMouse(true)
            frame:RegisterForDrag("LeftButton")

            frame:SetScript("OnDragStart", function(currentFrame)
                currentFrame:StartMoving()
            end)

            frame:SetScript("OnDragStop", function(currentFrame)
                currentFrame:StopMovingOrSizing()

                local position = self:GetPreviewPosition(kind)
                local draggedPosition =
                    getCenterRelativePosition(currentFrame, position.point)
                position.point = draggedPosition.point
                position.x = draggedPosition.x
                position.y = draggedPosition.y
                self:ApplyPreviewPositions()

                if self.positionChangedCallback then
                    self.positionChangedCallback(kind)
                end
            end)
        else
            frame:RegisterForDrag()
            frame:EnableMouse(false)
            frame:SetMovable(false)
            frame:SetScript("OnDragStart", nil)
            frame:SetScript("OnDragStop", nil)
        end

        updateAnchorPointMarker(
            frame,
            self:GetPreviewPosition(kind).point,
            unlocked
        )
    end

    -- Only the first preview in each group is draggable. It is the group anchor.
    configure(self.previewBars and self.previewBars[1] and self.previewBars[1].frame, "bar")
    configure(self.previewTexts and self.previewTexts[1] and self.previewTexts[1].frame, "text")
end

function AlertDefaults:EnsurePreview()
    local BossMods = E:GetModule("BossMods")
    local appearance = self:GetAppearance()

    self.previewBars = self.previewBars or {}
    self.previewTexts = self.previewTexts or {}

    local barCount = self:GetPreviewCount("bar")
    local textCount = self:GetPreviewCount("text")

    for index = 1, barCount do
        local preview = self.previewBars[index]

        if not preview then
            preview = BossMods.Engines.Bar(buildPreviewBarConfig(appearance))
            preview.onTick = function(elapsed, total)
                preview:SetRight(("%.1f"):format(math.max(0, total - elapsed)))
            end
            preview.onStop = function()
                preview:Hide()
            end
            self.previewBars[index] = preview
        else
            preview:Apply(buildPreviewBarConfig(appearance))
        end
    end

    for index = barCount + 1, #self.previewBars do
        local preview = self.previewBars[index]
        if preview:IsRunning() then
            preview:Stop()
        end
        preview:Hide()
    end

    for index = 1, textCount do
        local preview = self.previewTexts[index]

        if not preview then
            preview = BossMods.Engines.TextAlert(buildPreviewTextConfig(appearance))
            self.previewTexts[index] = preview
        else
            preview:Apply(buildPreviewTextConfig(appearance))
        end
    end

    for index = textCount + 1, #self.previewTexts do
        self.previewTexts[index]:Hide()
    end

    self:ApplyPreviewPositions()
end

function AlertDefaults:StopPreview()
    self.previewToken = (self.previewToken or 0) + 1
    self.previewActive = false

    for _, preview in ipairs(self.previewBars or {}) do
        if preview:IsRunning() then
            preview:Stop()
        end

        if not self.groupEditMode then
            preview:Hide()
        end
    end

    for _, preview in ipairs(self.previewTexts or {}) do
        if not self.groupEditMode then
            preview:Hide()
        end
    end

    self:SetPreviewUnlocked(self.groupEditMode == true)
end

function AlertDefaults:SetGroupEditMode(enabled)
    self.groupEditMode = enabled and true or false

    self:EnsurePreview()

    if self.groupEditMode then
        for index = 1, self:GetPreviewCount("bar") do
            local preview = self.previewBars[index]

            if preview:IsRunning() then
                preview:Stop()
            end

            preview:SetMode("label")
            preview:SetLabel(
                index == 1
                and "Bar group anchor — drag to move"
                or "Attached bar preview " .. index
            )
            preview:SetRight("30.0")
            preview.frame:Show()
        end

        for index = 1, self:GetPreviewCount("text") do
            local preview = self.previewTexts[index]
            preview:SetText(
                index == 1
                and "Text group anchor — drag to move"
                or "Attached text preview " .. index
            )
            preview.frame:Show()
        end

        self:ApplyPreviewPositions()
        self:SetPreviewUnlocked(true)
        return
    end

    self:SetPreviewUnlocked(self.previewActive == true)

    if not self.previewActive then
        for _, preview in ipairs(self.previewBars or {}) do
            if preview:IsRunning() then
                preview:Stop()
            end
            preview:Hide()
        end

        for _, preview in ipairs(self.previewTexts or {}) do
            preview:Hide()
        end
    end
end

function AlertDefaults:RestartPreviewFrames()
    if not self.previewActive then
        return
    end

    local duration = 30

    for index = 1, self:GetPreviewCount("bar") do
        local preview = self.previewBars[index]

        if preview:IsRunning() then
            preview:Stop()
        end

        preview:SetMode("label")
        preview:SetLabel("Default ability bar " .. index)
        preview:SetRight(("%.1f"):format(duration))
        preview:Start({ total = duration })
    end

    for index = 1, self:GetPreviewCount("text") do
        local preview = self.previewTexts[index]
        preview:SetText("Default text alert " .. index)
        preview:Show()
    end

    self:ApplyPreviewPositions()
    self:SetPreviewUnlocked(
        self.previewActive == true
        or self.groupEditMode == true
    )
end

function AlertDefaults:PreviewAppearance()
    self:EnsurePreview()
    self.previewActive = true

    self.previewToken = (self.previewToken or 0) + 1
    local token = self.previewToken
    local duration = 30

    self:RestartPreviewFrames()

    C_Timer.After(duration, function()
        if self.previewToken ~= token then
            return
        end

        self:StopPreview()
    end)
end

function AlertDefaults:RefreshPreview()
    if not self.previewBars and not self.previewTexts then
        return
    end

    self:EnsurePreview()

    if self.previewActive then
        self:RestartPreviewFrames()
    elseif self.groupEditMode then
        self:SetGroupEditMode(true)
    end
end

E:RegisterBossModFeature("VoidspireDefaultAlertAppearance", {
    tab = "Voidspire",
    order = 1,
    labelKey = "BossMods_DefaultAlertAppearance",
    moduleName = MODULE_NAME
})

E:RegisterBossModFeature("VenomousAbyssDefaultAlertAppearance", {
    tab = "VenomousAbyss",
    order = 1,
    labelKey = "BossMods_DefaultAlertAppearance",
    moduleName = MODULE_NAME
})
