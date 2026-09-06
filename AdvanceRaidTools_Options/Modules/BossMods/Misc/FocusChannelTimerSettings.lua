local E, L = unpack(ART)
local T = E.Templates

local DISPLAY_VALUES = {icon = "Icon", bar = "Bar"}
local DISPLAY_ORDER = {"icon", "bar"}
local OUTLINE_VALUES = {
    [""] = L["None"] or "None",
    OUTLINE = L["Outline"] or "Outline",
    THICKOUTLINE = L["ThickOutline"] or "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
}
local OUTLINE_ORDER = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}
local ROW_GAP = 6
local HEADER_GAP = 10

local function build(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end

    mod:EnsureDefaults()
    mod:EnsureFrames()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local unlockController

    local function refresh()
        mod:Refresh()
        tracker.refresh()
    end
    local function full(y, widget)
        return y + T:PlaceFull(parent, widget, y, width) + ROW_GAP
    end
    local function row(y, widgets)
        return y + T:PlaceRow(parent, widgets, y, width) + ROW_GAP
    end
    local function header(y, text)
        return full(y, track(T:Header(parent, {text = text}))) + HEADER_GAP
    end
    local function slider(label, low, high, step, get, set, disabled)
        return track(T:Slider(parent, {
            label = label, min = low, max = high, step = step,
            value = get(), get = get,
            onChange = function(value) set(value); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function dropdown(label, values, sorting, get, set, disabled)
        return track(T:Dropdown(parent, {
            label = label, values = values, sorting = sorting, get = get,
            onChange = function(value) set(value); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function checkbox(text, get, set, disabled)
        return track(T:Checkbox(parent, {
            text = text, labelTop = true, get = get,
            onChange = function(_, value) set(value); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function editbox(label, get, set, disabled)
        return track(T:EditBox(parent, {
            label = label, default = tostring(get()), get = function() return tostring(get()) end,
            numeric = true, commitOn = "enter",
            onCommit = function(value) set(tonumber(value)); refresh() end,
            disabled = disabled or isDisabled
        }))
    end
    local function color(label, get, set, disabled)
        local value = get()
        return track(T:ColorSwatch(parent, {
            label = label, labelTop = true, hasAlpha = true,
            r = value[1] or 1, g = value[2] or 1,
            b = value[3] or 1, a = value[4] or 1,
            onChange = function(r, g, b, a) set({r, g, b, a}); refresh() end,
            disabled = disabled or isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(parent, {text = L["BossMods_FocusChannelTimer"]})))
    y = full(y, track(T:Description(parent, {
        text = L["BossMods_FocusChannelTimerDesc"], sizeDelta = 1
    })))

    y, unlockController = T:UnlockController(parent, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value) mod:SetEditMode(value) end
    })
    y = full(y, T:PreviewToggle(parent, {
        module = mod, tracker = tracker, disabled = isDisabled
    }))

    y = header(y, "Timer")
    y = row(y, {
        dropdown("Display type", DISPLAY_VALUES, DISPLAY_ORDER,
            function() return mod.db.displayType end,
            function(value) mod.db.displayType = value end),
        slider("Duration", 1, 120, 0.5,
            function() return mod.db.duration end,
            function(value) mod.db.duration = value end)
    })

    local function moduleDisabled()
        if type(isDisabled) == "function" then
            return isDisabled()
        end
        return isDisabled == true
    end
    local function iconDisabled()
        return moduleDisabled() or mod.db.displayType ~= "icon"
    end
    y = header(y, "Icon appearance")
    y = row(y, {
        editbox("Icon ID", function() return mod.db.iconID end,
            function(value) mod.db.iconID = value or 64843 end, iconDisabled),
        slider("Icon size", 16, 256, 1,
            function() return mod.db.icon.size end,
            function(value) mod.db.icon.size = math.floor(value + 0.5) end, iconDisabled)
    })
    y = row(y, {
        checkbox("Cooldown swipe",
            function() return mod.db.icon.cooldownSwipe end,
            function(value) mod.db.icon.cooldownSwipe = value end, iconDisabled),
        checkbox("Enable border",
            function() return mod.db.icon.border.enabled end,
            function(value) mod.db.icon.border.enabled = value end, iconDisabled)
    })
    y = row(y, {
        dropdown(L["Font"] or "Font", function() return E:MediaList("font") end, nil,
            function() return mod.db.icon.font.name end,
            function(value) mod.db.icon.font.name = value end, iconDisabled),
        dropdown(L["Outline"] or "Outline", OUTLINE_VALUES, OUTLINE_ORDER,
            function() return mod.db.icon.font.outline end,
            function(value) mod.db.icon.font.outline = value or "" end, iconDisabled)
    })
    y = row(y, {
        slider("Text size", 8, 72, 1,
            function() return mod.db.icon.font.size end,
            function(value) mod.db.icon.font.size = math.floor(value + 0.5) end, iconDisabled),
        color("Text color", function() return mod.db.icon.font.color end,
            function(value) mod.db.icon.font.color = value end, iconDisabled)
    })
    y = row(y, {
        dropdown("Border texture", function() return E:MediaList("border") end, nil,
            function() return mod.db.icon.border.texture end,
            function(value) mod.db.icon.border.texture = value end, iconDisabled),
        slider("Border size", 1, 16, 1,
            function() return mod.db.icon.border.size end,
            function(value) mod.db.icon.border.size = math.floor(value + 0.5) end, iconDisabled)
    })
    y = row(y, {
        color("Border color", function() return mod.db.icon.border.color end,
            function(value) mod.db.icon.border.color = value end, iconDisabled)
    })

    local function barDisabled()
        return moduleDisabled() or mod.db.displayType ~= "bar"
    end
    y = header(y, "Bar appearance")
    y = row(y, {
        slider("Width", 100, 1000, 5,
            function() return mod.db.bar.width end,
            function(value) mod.db.bar.width = math.floor(value + 0.5) end, barDisabled),
        slider("Height", 10, 100, 1,
            function() return mod.db.bar.height end,
            function(value) mod.db.bar.height = math.floor(value + 0.5) end, barDisabled)
    })
    y = row(y, {
        dropdown(L["Texture"] or "Texture", function() return E:MediaList("statusbar") end, nil,
            function() return mod.db.bar.texture end,
            function(value) mod.db.bar.texture = value end, barDisabled),
        dropdown(L["Font"] or "Font", function() return E:MediaList("font") end, nil,
            function() return mod.db.bar.font.name end,
            function(value) mod.db.bar.font.name = value end, barDisabled)
    })
    y = row(y, {
        slider("Font size", 8, 60, 1,
            function() return mod.db.bar.font.size end,
            function(value) mod.db.bar.font.size = math.floor(value + 0.5) end, barDisabled),
        dropdown(L["Outline"] or "Outline", OUTLINE_VALUES, OUTLINE_ORDER,
            function() return mod.db.bar.font.outline end,
            function(value) mod.db.bar.font.outline = value or "" end, barDisabled)
    })
    y = row(y, {
        color("Bar color", function() return mod.db.bar.color end,
            function(value) mod.db.bar.color = value end, barDisabled),
        color("Background color", function() return mod.db.bar.background end,
            function(value) mod.db.bar.background = value end, barDisabled)
    })
    y = row(y, {
        color("Text color", function() return mod.db.bar.font.color end,
            function(value) mod.db.bar.font.color = value end, barDisabled)
    })

    local positionHandle
    y, positionHandle = T:PositionSection(parent, y, width, {
        anchor = mod:GetAnchor(),
        label = L["BossMods_FocusChannelTimer"],
        tracker = tracker,
        getPosition = function()
            return {point = mod.db.position.point, x = mod.db.position.x, y = mod.db.position.y}
        end,
        setPosition = function(position) mod:SavePosition(position) end,
        defaultPosition = {point = "CENTER", x = 0, y = 180},
        onChanged = refresh,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            positionHandle.Release()
            unlockController:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("FocusChannelTimer", build)
    end
end
