local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local OUTLINE_VALUES = {
    [""] = L["BossMods_AAOptions_None"],
    OUTLINE = L["BossMods_AAOptions_Outline"],
    THICKOUTLINE = L["BossMods_AAOptions_ThickOutline"],
    OUTLINE_SLUG = L["BossMods_AAOptions_SlugOutline"]
}

local OUTLINE_SORTING = {
    "",
    "OUTLINE",
    "THICKOUTLINE",
    "OUTLINE_SLUG"
}

local function colorValue(value)
    value = value or {}

    return {
        value[1] or value.r or 1,
        value[2] or value.g or 1,
        value[3] or value.b or 1,
        value[4] or value.a or 1
    }
end

local function buildTimelineSequenceBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    local definition = mod.definition or {}
    local display = mod.EnsureDisplay and mod:EnsureDisplay()
    local anchor = display and display.GetFrame and display:GetFrame()

    if display and display.Apply then
        display:Apply()
    end

    local tracker = T:MakeTracker()
    local track = tracker.track

    local function refreshLive()
        if mod.CallIfEnabled then
            mod:CallIfEnabled("Refresh")
        elseif mod.Refresh then
            mod:Refresh()
        end
        tracker.refresh()
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, width) + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(rightPanel, {text = text}))
        return y + T:PlaceFull(rightPanel, header, y, width) + HEADER_GAP
    end

    local function dropdown(opts)
        return track(T:Dropdown(rightPanel, {
            label = opts.label,
            values = opts.values,
            sorting = opts.sorting,
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local function color(opts)
        local current = colorValue(opts.get())
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = current[1],
            g = current[2],
            b = current[3],
            a = current[4],
            onChange = function(r, g, b, a)
                opts.set({r, g, b, a})
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L[definition.labelKey] or definition.labelKey or mod.moduleName
    })))

    if definition.descKey then
        y = full(y, track(T:Description(rightPanel, {
            text = L[definition.descKey] or definition.descKey,
            sizeDelta = 1
        })))
    end

    y = row(y, {
        track(T:Checkbox(rightPanel, {
            text = L["BossMods_TimelineSequencePreview"],
            get = function()
                return mod.previewMode == true
            end,
            onChange = function(_, value)
                if mod.SetPreviewMode then
                    mod:SetPreviewMode(value)
                end
                tracker.refresh()
            end,
            disabled = isDisabled
        })),
        track(T:Checkbox(rightPanel, {
            text = L["BossMods_TimelineSequenceTextOnly"],
            get = function()
                return mod.db.textOnly == true
            end,
            onChange = function(_, value)
                mod.db.textOnly = value and true or false
                refreshLive()
            end,
            disabled = isDisabled
        }))
    })

    local unlockY, unlockController = T:UnlockController(rightPanel, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value)
            if mod.SetEditMode then
                mod:SetEditMode(value)
            end
        end
    })
    y = unlockY

    y = section(y, L["BossMods_TimelineSequenceAppearance"])

    y = row(y, {
        slider({
            label = L["Width"],
            min = 140,
            max = 900,
            step = 5,
            get = function()
                return mod.db.width or definition.width or 360
            end,
            set = function(value)
                mod.db.width = math.floor(value + 0.5)
            end
        }),
        slider({
            label = L["Height"],
            min = 10,
            max = 80,
            step = 1,
            get = function()
                return mod.db.height or definition.height or 24
            end,
            set = function(value)
                mod.db.height = math.floor(value + 0.5)
            end
        })
    })

    y = row(y, {
        slider({
            label = L["BossMods_TimelineSequenceSpacing"],
            min = 0,
            max = 30,
            step = 1,
            get = function()
                return mod.db.spacing or definition.spacing or 4
            end,
            set = function(value)
                mod.db.spacing = math.floor(value + 0.5)
            end
        }),
        slider({
            label = L["Scale"],
            min = 0.5,
            max = 2,
            step = 0.05,
            get = function()
                return mod.db.scale or 1
            end,
            set = function(value)
                mod.db.scale = value
            end
        })
    })

    y = row(y, {
        slider({
            label = L["Opacity"],
            min = 0.1,
            max = 1,
            step = 0.05,
            get = function()
                return mod.db.opacity or 1
            end,
            set = function(value)
                mod.db.opacity = value
            end
        }),
        slider({
            label = L["BossMods_TimelineSequenceBackgroundOpacity"],
            min = 0,
            max = 1,
            step = 0.05,
            get = function()
                return mod.db.backgroundOpacity or 0.65
            end,
            set = function(value)
                mod.db.backgroundOpacity = value
            end
        })
    })

    y = row(y, {
        dropdown({
            label = L["Texture"],
            values = function()
                return E:MediaList("statusbar")
            end,
            get = function()
                return mod.db.statusBarTexture or definition.statusBarTexture or "Blizzard"
            end,
            set = function(value)
                mod.db.statusBarTexture = value
            end
        }),
        dropdown({
            label = L["BossMods_AAOptions_Font"],
            values = function()
                return E:MediaList("font")
            end,
            get = function()
                return mod.db.font and mod.db.font.name or "Friz Quadrata TT"
            end,
            set = function(value)
                mod.db.font = mod.db.font or {}
                mod.db.font.name = value
            end
        })
    })

    y = row(y, {
        dropdown({
            label = L["BossMods_AAOptions_FontOutline"],
            values = OUTLINE_VALUES,
            sorting = OUTLINE_SORTING,
            get = function()
                return mod.db.font and mod.db.font.outline or "OUTLINE"
            end,
            set = function(value)
                mod.db.font = mod.db.font or {}
                mod.db.font.outline = value or ""
            end
        }),
        slider({
            label = L["BossMods_AAOptions_FontSize"],
            min = 8,
            max = 48,
            step = 1,
            get = function()
                return mod.db.font and mod.db.font.size or 14
            end,
            set = function(value)
                mod.db.font = mod.db.font or {}
                mod.db.font.size = math.floor(value + 0.5)
            end
        })
    })

    y = full(y, color({
        label = L["BossMods_TimelineSequenceTextColor"],
        get = function()
            return mod.db.font and mod.db.font.color or {1, 1, 1, 1}
        end,
        set = function(value)
            mod.db.font = mod.db.font or {}
            mod.db.font.color = value
        end
    }))

    local rows = definition.rows or {}
    if #rows > 0 then
        y = section(y, L["BossMods_TimelineSequenceRowColors"])

        for index = 1, #rows, 2 do
            local widgets = {}

            for offset = 0, 1 do
                local rowDefinition = rows[index + offset]
                if rowDefinition then
                    widgets[#widgets + 1] = color({
                        label = L[rowDefinition.labelKey]
                            or rowDefinition.label
                            or rowDefinition.key,
                        get = function()
                            mod.db.barColors = mod.db.barColors or {}
                            return mod.db.barColors[rowDefinition.key]
                                or rowDefinition.color
                        end,
                        set = function(value)
                            mod.db.barColors = mod.db.barColors or {}
                            mod.db.barColors[rowDefinition.key] = value
                        end
                    })
                end
            end

            y = row(y, widgets)
        end
    end

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = anchor,
        label = L[definition.labelKey] or definition.labelKey or mod.moduleName,
        headerText = (L[definition.labelKey] or definition.labelKey or mod.moduleName)
            .. " "
            .. L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod.db.position or definition.position or {}
            return {
                point = position.point or "CENTER",
                x = position.x or 0,
                y = position.y or 0
            }
        end,
        setPosition = function(position)
            if mod.SavePosition then
                mod:SavePosition(position)
            end
        end,
        defaultPosition = definition.position or {point = "CENTER", x = 0, y = 0},
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = positionY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            if mod.SetPreviewMode then
                mod:SetPreviewMode(false)
            end
            if mod.SetEditMode then
                mod:SetEditMode(false)
            end
            if positionHandle and positionHandle.Release then
                positionHandle.Release()
            end
            if unlockController and unlockController.Release then
                unlockController:Release()
            end
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    function BossMods:RegisterTimelineSequenceSettingsBuilder(featureKey)
        self:RegisterBossSettingsBuilder(featureKey, buildTimelineSequenceBody)
    end
end
