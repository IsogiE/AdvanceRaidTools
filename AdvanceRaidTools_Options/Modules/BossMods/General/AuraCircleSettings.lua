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

local function buildAuraCircleBody(rightPanel, mod, isDisabled)
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
        local current = opts.get() or {}
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = current[1] or current.r or 1,
            g = current[2] or current.g or 1,
            b = current[3] or current.b or 1,
            a = current[4] or current.a or 1,
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

    y = section(y, L["BossMods_AuraCircleAppearance"])

    local size = slider({
        label = L["BossMods_AuraCircleSize"],
        min = 30,
        max = 180,
        step = 1,
        get = function()
            return mod.db.size or definition.size or 72
        end,
        set = function(value)
            mod.db.size = math.floor(value + 0.5)
        end
    })

    local opacity = slider({
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
    })
    y = row(y, {size, opacity})

    local circleColor = color({
        label = L["BossMods_AuraCircleColor"],
        get = function()
            return mod.db.color
        end,
        set = function(value)
            mod.db.color = value
        end
    })

    local backgroundOpacity = slider({
        label = L["BossMods_AuraCircleBackgroundOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.backgroundOpacity or 0.72
        end,
        set = function(value)
            mod.db.backgroundOpacity = value
        end
    })
    y = row(y, {circleColor, backgroundOpacity})

    local font = dropdown({
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

    local outline = dropdown({
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
    })
    y = row(y, {font, outline})

    local fontSize = slider({
        label = L["BossMods_AAOptions_FontSize"],
        min = 8,
        max = 72,
        step = 1,
        get = function()
            return mod.db.font and mod.db.font.size or 24
        end,
        set = function(value)
            mod.db.font = mod.db.font or {}
            mod.db.font.size = math.floor(value + 0.5)
        end
    })

    local textColor = color({
        label = L["BossMods_AuraCircleTextColor"],
        get = function()
            return mod.db.font and mod.db.font.color or {1, 1, 1, 1}
        end,
        set = function(value)
            mod.db.font = mod.db.font or {}
            mod.db.font.color = value
        end
    })
    y = row(y, {fontSize, textColor})

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
    function BossMods:RegisterAuraCircleSettingsBuilder(featureKey)
        self:RegisterBossSettingsBuilder(featureKey, buildAuraCircleBody)
    end
end
