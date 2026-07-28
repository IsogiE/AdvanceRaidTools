local E = unpack(ART)
local T = E.Templates

local BossMods = E:GetModule("BossMods", true)
if not BossMods then
    return
end

local MODULE_NAME = "BossMods_AbilityAlertDefaults"
local FEATURE_KEYS = {
    "VoidspireDefaultAlertAppearance",
    "VenomousAbyssDefaultAlertAppearance"
}
local ROW_GAP = 6
local HEADER_GAP = 10

local OUTLINE_VALUES = {
    [""] = "None",
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
}

local OUTLINE_SORTING = {
    "",
    "OUTLINE",
    "THICKOUTLINE",
    "OUTLINE_SLUG"
}

local GROWTH_VALUES = {
    DOWN = "Down",
    UP = "Up"
}

local GROWTH_SORTING = {
    "DOWN",
    "UP"
}

local function fontValues()
    return E:MediaList("font")
end

local function statusBarValues()
    return E:MediaList("statusbar")
end

local function refreshAbilityAlerts()
    for _, moduleName in ipairs({
        "BossMods_VenomousAbyssAbilityAlerts",
        "BossMods_VoidspireAbilityAlerts"
    }) do
        local mod = E:GetModule(moduleName, true)
        if mod and mod.CallIfEnabled then
            mod:CallIfEnabled("Refresh")
        end
    end
end

local function buildBody(parent, defaultsMod, isDisabled)
    local widthPx = parent:GetWidth() or 0
    if widthPx <= 0 then
        return { height = 1 }
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local appearance = defaultsMod:GetAppearance()
    local positionChangedCallback = function()
        tracker.refresh()
    end

    defaultsMod.positionChangedCallback = positionChangedCallback

    local function row(y, widgets)
        return y + T:PlaceRow(parent, widgets, y, widthPx) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(parent, widget, y, widthPx) + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(parent, { text = text }))
        return y + T:PlaceFull(parent, header, y, widthPx) + HEADER_GAP
    end

    local function dropdown(opts)
        return track(T:Dropdown(parent, {
            label = opts.label,
            values = opts.values,
            sorting = opts.sorting,
            get = opts.get,
            onChange = function(value)
                opts.onChange(value)
                refreshAbilityAlerts()
                defaultsMod:RefreshPreview()
                tracker.refresh()
            end,
            disabled = isDisabled
        }))
    end

    local function slider(opts)
        return track(T:Slider(parent, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.onChange(value)
                refreshAbilityAlerts()
                defaultsMod:RefreshPreview()
                tracker.refresh()
            end,
            disabled = function()
                return isDisabled()
                    or (opts.disabled and opts.disabled())
            end
        }))
    end

    local function checkbox(opts)
        return track(T:Checkbox(parent, {
            text = opts.text,
            labelTop = opts.labelTop,
            get = opts.get,
            onChange = function(value)
                opts.onChange(value)
                refreshAbilityAlerts()
                defaultsMod:RefreshPreview()
                tracker.refresh()
            end,
            disabled = function()
                return isDisabled()
                    or (opts.disabled and opts.disabled())
            end
        }))
    end

    local function color(opts)
        local current = opts.get()
        return track(T:ColorSwatch(parent, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = current[1] or current.r or 1,
            g = current[2] or current.g or 1,
            b = current[3] or current.b or 1,
            a = current[4] or current.a or 1,
            onChange = function(r, g, b, a)
                opts.onChange(r, g, b, a)
                refreshAbilityAlerts()
                defaultsMod:RefreshPreview()
                tracker.refresh()
            end,
            disabled = isDisabled
        }))
    end

    local function button(opts)
        return track(T:Button(parent, {
            text = opts.text,
            tooltip = opts.tooltip,
            onClick = opts.onClick,
            disabled = isDisabled
        }))
    end

    local y = 0
    local unlockCtrl

    y = full(y, track(T:Header(parent, {
        text = "Default Alert Appearance"
    })))

    y = full(y, track(T:Description(parent, {
        text = "These appearance settings are used by every boss and every ability unless that ability has its own appearance override enabled.",
        sizeDelta = 1
    })))

    local previewButton = button({
        text = "Preview bar and text",
        tooltip = "Shows a 30-second preview using the current default appearance.",
        onClick = function()
            defaultsMod:PreviewAppearance()
        end
    })

    local stopPreviewButton = button({
        text = "Stop preview",
        tooltip = "Stops and hides the current bar and text preview.",
        onClick = function()
            defaultsMod:StopPreview()
        end
    })

    y = row(y, { previewButton, stopPreviewButton })


    local unlockY
    unlockY, unlockCtrl =
        T:UnlockController(
            parent,
            y,
            widthPx,
            {
                tracker = tracker,
                isDisabled = isDisabled,
                onEditModeChanged = function(value)
                    defaultsMod:SetGroupEditMode(value)
                end
            }
        )
    y = unlockY

    local addPreviewBar = button({
        text = "Add preview bar",
        tooltip = "Adds another preview bar. Up to four bars can be shown at once.",
        onClick = function()
            defaultsMod:SetPreviewCount(
                "bar",
                defaultsMod:GetPreviewCount("bar") + 1
            )
            tracker.refresh()
        end
    })

    local removePreviewBar = button({
        text = "Remove preview bar",
        tooltip = "Removes one preview bar. At least one bar remains.",
        onClick = function()
            defaultsMod:SetPreviewCount(
                "bar",
                defaultsMod:GetPreviewCount("bar") - 1
            )
            tracker.refresh()
        end
    })

    local addPreviewText = button({
        text = "Add preview text",
        tooltip = "Adds another preview text alert. Up to four can be shown at once.",
        onClick = function()
            defaultsMod:SetPreviewCount(
                "text",
                defaultsMod:GetPreviewCount("text") + 1
            )
            tracker.refresh()
        end
    })

    local removePreviewText = button({
        text = "Remove preview text",
        tooltip = "Removes one preview text alert. At least one remains.",
        onClick = function()
            defaultsMod:SetPreviewCount(
                "text",
                defaultsMod:GetPreviewCount("text") - 1
            )
            tracker.refresh()
        end
    })

    y = row(y, { addPreviewBar, removePreviewBar })
    y = row(y, { addPreviewText, removePreviewText })

    y = section(y, "Default bar appearance")

    local barGroup =
        defaultsMod:GetGroupSettings("bar")

    local barGrowth = dropdown({
        label = "Grow bars",
        values = GROWTH_VALUES,
        sorting = GROWTH_SORTING,
        get = function()
            return barGroup.growth
        end,
        onChange = function(value)
            barGroup.growth = value
            refreshAbilityAlerts()
        end
    })

    local barSpacing = slider({
        label = "Spacing between bars",
        min = 0,
        max = 100,
        step = 1,
        get = function()
            return barGroup.spacing
        end,
        onChange = function(value)
            barGroup.spacing = math.floor(value)
            refreshAbilityAlerts()
        end
    })

    y = row(y, { barGrowth, barSpacing })

    y = T:XYOffsetControls(parent, y, widthPx, {
        tracker = tracker,
        getPosition = function()
            return barGroup
        end,
        setPosition = function(position)
            barGroup.point = position.point or "CENTER"
            barGroup.x = position.x or -400
            barGroup.y = position.y or 80
            defaultsMod:ApplyPreviewPositions()
            refreshAbilityAlerts()
        end,
        disabled = isDisabled,
        xInputLabel = "Bar anchor X value",
        yInputLabel = "Bar anchor Y value"
    })

    local barFont = dropdown({
        label = "Font",
        values = fontValues,
        get = function() return appearance.bar.font.name end,
        onChange = function(value) appearance.bar.font.name = value end
    })

    local barFontSize = slider({
        label = "Font size", min = 8, max = 40,
        get = function() return appearance.bar.font.size end,
        onChange = function(value) appearance.bar.font.size = math.floor(value) end
    })

    local barFontOutline = dropdown({
        label = "Font outline",
        values = OUTLINE_VALUES,
        sorting = OUTLINE_SORTING,
        get = function() return appearance.bar.font.outline end,
        onChange = function(value) appearance.bar.font.outline = value end
    })

    y = row(y, { barFont, barFontSize, barFontOutline })

    local barWidth = slider({
        label = "Bar width", min = 100, max = 800, step = 5,
        get = function() return appearance.bar.width end,
        onChange = function(value) appearance.bar.width = math.floor(value) end
    })

    local barHeight = slider({
        label = "Bar height", min = 10, max = 80,
        get = function() return appearance.bar.height end,
        onChange = function(value) appearance.bar.height = math.floor(value) end
    })

    local barTexture = dropdown({
        label = "Bar texture",
        values = statusBarValues,
        get = function() return appearance.bar.texture end,
        onChange = function(value) appearance.bar.texture = value end
    })

    y = row(y, { barWidth, barHeight, barTexture })

    local barIconEnabled = checkbox({
        text = "Enable ability icon",
        labelTop = true,
        get = function() return appearance.bar.iconEnabled ~= false end,
        onChange = function(value) appearance.bar.iconEnabled = value end
    })

    local barIconSize = slider({
        label = "Icon size", min = 8, max = 80,
        get = function() return appearance.bar.iconSize end,
        onChange = function(value) appearance.bar.iconSize = math.floor(value) end,
        disabled = function() return appearance.bar.iconEnabled == false end
    })

    y = row(y, { barIconEnabled, barIconSize })

    local backgroundColor = color({
        label = "Background color",
        get = function() return appearance.bar.backgroundColor end,
        onChange = function(r, g, b, a)
            appearance.bar.backgroundColor = {r, g, b, a}
            defaultsMod:RefreshPreview()
            refreshAbilityAlerts()
        end
    })

    local backgroundOpacity = slider({
        label = "Background opacity",
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return appearance.bar.backgroundOpacity
        end,
        onChange = function(value)
            appearance.bar.backgroundOpacity = value
            defaultsMod:RefreshPreview()
            refreshAbilityAlerts()
        end
    })

    y = row(y, { backgroundColor, backgroundOpacity })

    y = section(y, "Default text appearance")

    local textGroup =
        defaultsMod:GetGroupSettings("text")

    local textGrowth = dropdown({
        label = "Grow text alerts",
        values = GROWTH_VALUES,
        sorting = GROWTH_SORTING,
        get = function()
            return textGroup.growth
        end,
        onChange = function(value)
            textGroup.growth = value
            refreshAbilityAlerts()
        end
    })

    local textSpacing = slider({
        label = "Spacing between text alerts",
        min = 0,
        max = 150,
        step = 1,
        get = function()
            return textGroup.spacing
        end,
        onChange = function(value)
            textGroup.spacing = math.floor(value)
            refreshAbilityAlerts()
        end
    })

    y = row(y, { textGrowth, textSpacing })

    y = T:XYOffsetControls(parent, y, widthPx, {
        tracker = tracker,
        getPosition = function()
            return textGroup
        end,
        setPosition = function(position)
            textGroup.point = position.point or "CENTER"
            textGroup.x = position.x or 0
            textGroup.y = position.y or 200
            defaultsMod:ApplyPreviewPositions()
            refreshAbilityAlerts()
        end,
        disabled = isDisabled,
        xInputLabel = "Text anchor X value",
        yInputLabel = "Text anchor Y value"
    })

    local textFont = dropdown({
        label = "Font",
        values = fontValues,
        get = function() return appearance.text.font.name end,
        onChange = function(value) appearance.text.font.name = value end
    })

    local textFontSize = slider({
        label = "Font size", min = 8, max = 72,
        get = function() return appearance.text.font.size end,
        onChange = function(value) appearance.text.font.size = math.floor(value) end
    })

    local textFontOutline = dropdown({
        label = "Font outline",
        values = OUTLINE_VALUES,
        sorting = OUTLINE_SORTING,
        get = function() return appearance.text.font.outline end,
        onChange = function(value) appearance.text.font.outline = value end
    })

    y = row(y, { textFont, textFontSize, textFontOutline })

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            if defaultsMod.positionChangedCallback
                == positionChangedCallback
            then
                defaultsMod.positionChangedCallback = nil
            end

            if unlockCtrl then
                unlockCtrl:Release()
            end
            tracker.release()
        end
    }
end

for _, featureKey in ipairs(FEATURE_KEYS) do
    BossMods:RegisterBossSettingsBuilder(
        featureKey,
        function(parent, defaultsMod, isDisabled)
            return buildBody(parent, defaultsMod, isDisabled)
        end
    )
end
