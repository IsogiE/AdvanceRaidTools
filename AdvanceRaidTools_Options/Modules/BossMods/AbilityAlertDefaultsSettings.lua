local E, L = unpack(ART)
local T = E.Templates

local BossMods = E:GetModule("BossMods", true)
if not BossMods then
    return
end

local MODULE_NAME = "BossMods_AbilityAlertDefaults"
local FEATURE_KEYS = {
    "DefaultAlertAppearance"
}
local ROW_GAP = 6
local HEADER_GAP = 10

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    OUTLINE_SLUG = L["BossMods_AAOptions_SlugOutline"]
}

local OUTLINE_SORTING = {
    "",
    "OUTLINE",
    "THICKOUTLINE",
    "OUTLINE_SLUG"
}

local function fontValues()
    return E:MediaList("font")
end

local function statusBarValues()
    return E:MediaList("statusbar")
end

local function refreshAbilityAlerts()
    for _, mod in E:IterateModules() do
        if mod.GetBarAppearance and mod.CallIfEnabled then
            mod:CallIfEnabled("Refresh")
        end
    end
    local custom = E:GetModule("BossMods_CustomBars", true)
    if custom then custom:CallIfEnabled("Refresh") end
    BossMods.DisplayTemplates:Refresh()
end

local function buildBody(parent, defaultsMod, isDisabled)
    local widthPx = parent:GetWidth() or 0
    if widthPx <= 0 then
        return { height = 1 }
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local appearance = defaultsMod:GetAppearance()
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

    y = full(y, track(T:Header(parent, {
        text = L["BossMods_DefaultAlertAppearance"]
    })))

    y = full(y, track(T:Description(parent, {
        text = L["BossMods_DefaultAlertAppearanceDesc"],
        sizeDelta = 1
    })))

    local previewButton = button({
        text = L["BossMods_DefaultPreview"],
        tooltip = L["BossMods_DefaultPreviewTooltip"],
        onClick = function()
            defaultsMod:PreviewAppearance()
        end
    })

    local stopPreviewButton = button({
        text = L["BossMods_StopPreview"],
        tooltip = L["BossMods_StopPreviewTooltip"],
        onClick = function()
            defaultsMod:StopPreview()
        end
    })

    y = row(y, { previewButton, stopPreviewButton })


    local addPreviewBar = button({
        text = L["BossMods_AddPreviewBar"],
        tooltip = L["BossMods_AddPreviewBarTooltip"],
        onClick = function()
            defaultsMod:SetPreviewCount(
                "bar",
                defaultsMod:GetPreviewCount("bar") + 1
            )
            tracker.refresh()
        end
    })

    local removePreviewBar = button({
        text = L["BossMods_RemovePreviewBar"],
        tooltip = L["BossMods_RemovePreviewBarTooltip"],
        onClick = function()
            defaultsMod:SetPreviewCount(
                "bar",
                defaultsMod:GetPreviewCount("bar") - 1
            )
            tracker.refresh()
        end
    })

    local addPreviewText = button({
        text = L["BossMods_AddPreviewText"],
        tooltip = L["BossMods_AddPreviewTextTooltip"],
        onClick = function()
            defaultsMod:SetPreviewCount(
                "text",
                defaultsMod:GetPreviewCount("text") + 1
            )
            tracker.refresh()
        end
    })

    local removePreviewText = button({
        text = L["BossMods_RemovePreviewText"],
        tooltip = L["BossMods_RemovePreviewTextTooltip"],
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

    y = section(y, L["BossMods_DefaultBarAppearance"])

    local barFont = dropdown({
        label = L["Font"],
        values = fontValues,
        get = function() return appearance.bar.font.name end,
        onChange = function(value) appearance.bar.font.name = value end
    })

    local barFontSize = slider({
        label = L["BossMods_AAOptions_FontSize"], min = 8, max = 40,
        get = function() return appearance.bar.font.size end,
        onChange = function(value) appearance.bar.font.size = math.floor(value) end
    })

    local barFontOutline = dropdown({
        label = L["BossMods_AAOptions_FontOutline"],
        values = OUTLINE_VALUES,
        sorting = OUTLINE_SORTING,
        get = function() return appearance.bar.font.outline end,
        onChange = function(value) appearance.bar.font.outline = value end
    })

    y = row(y, { barFont, barFontSize, barFontOutline })

    local barWidth = slider({
        label = L["BossMods_AAOptions_BarWidth"], min = 100, max = 800, step = 5,
        get = function() return appearance.bar.width end,
        onChange = function(value) appearance.bar.width = math.floor(value) end
    })

    local barHeight = slider({
        label = L["BossMods_AAOptions_BarHeight"], min = 10, max = 80,
        get = function() return appearance.bar.height end,
        onChange = function(value) appearance.bar.height = math.floor(value) end
    })

    local barTexture = dropdown({
        label = L["BossMods_AAOptions_BarTexture"],
        values = statusBarValues,
        get = function() return appearance.bar.texture end,
        onChange = function(value) appearance.bar.texture = value end
    })

    y = row(y, { barWidth, barHeight, barTexture })

    local barIconEnabled = checkbox({
        text = L["BossMods_AAOptions_EnableAbilityIcon"],
        labelTop = true,
        get = function() return appearance.bar.iconEnabled ~= false end,
        onChange = function(value) appearance.bar.iconEnabled = value end
    })

    local barIconSize = slider({
        label = L["BossMods_AAOptions_IconSize"], min = 8, max = 80,
        get = function() return appearance.bar.iconSize end,
        onChange = function(value) appearance.bar.iconSize = math.floor(value) end,
        disabled = function() return appearance.bar.iconEnabled == false end
    })

    y = row(y, { barIconEnabled, barIconSize })

    local backgroundColor = color({
        label = L["BossMods_AAOptions_BackgroundColor"],
        get = function() return appearance.bar.backgroundColor end,
        onChange = function(r, g, b, a)
            appearance.bar.backgroundColor = {r, g, b, a}
            defaultsMod:RefreshPreview()
            refreshAbilityAlerts()
        end
    })

    local backgroundOpacity = slider({
        label = L["BossMods_AuraCircleBackgroundOpacity"],
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

    y = section(y, L["BossMods_DefaultTextAppearance"])

    local textFont = dropdown({
        label = L["Font"],
        values = fontValues,
        get = function() return appearance.text.font.name end,
        onChange = function(value) appearance.text.font.name = value end
    })

    local textFontSize = slider({
        label = L["BossMods_AAOptions_FontSize"], min = 8, max = 72,
        get = function() return appearance.text.font.size end,
        onChange = function(value) appearance.text.font.size = math.floor(value) end
    })

    local textFontOutline = dropdown({
        label = L["BossMods_AAOptions_FontOutline"],
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
