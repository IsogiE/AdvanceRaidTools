local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function buildLuraMapBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local refreshPanel = tracker.refresh
    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        refreshPanel()
    end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            onChange = function(v)
                opts.onChange(v);
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end
    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            labelTop = opts.labelTop,
            get = opts.get,
            onChange = function(_, v)
                opts.onChange(v);
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end
    local function dropdown(opts)
        return track(T:Dropdown(rightPanel, {
            label = opts.label,
            values = opts.values,
            get = opts.get,
            onChange = function(v)
                opts.onChange(v);
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end
    local function color(opts)
        local c = opts.get()
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = opts.hasAlpha ~= false,
            r = c[1] or c.r or 1,
            g = c[2] or c.g or 1,
            b = c[3] or c.b or 1,
            a = c[4] or c.a or 1,
            onChange = function(r, g, b, a)
                opts.onChange(r, g, b, a);
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end
    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx) + ROW_GAP
    end
    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, widthPx) + ROW_GAP
    end
    local function section(y, key)
        local h = track(T:Header(rightPanel, {
            text = L[key] or key
        }))
        return y + T:PlaceFull(rightPanel, h, y, widthPx) + HEADER_GAP
    end

    local posHandles = {}

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_LuraMap"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_LuraMapDesc"],
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(rightPanel, y, widthPx, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end
    })
    y = unlockY

    -- Enables
    local intEnable = checkbox({
        text = L["BossMods_LMEnableIntermission"] or (L["BossMods_LMIntermission"] .. " " .. L["Enable"]),
        labelTop = true,
        get = function()
            return mod.db.anchors.intermission.enabled
        end,
        onChange = function(v)
            mod.db.anchors.intermission.enabled = v
        end
    })
    local mainEnable = checkbox({
        text = L["BossMods_LMEnableMain"] or (L["BossMods_LMMain"] .. " " .. L["Enable"]),
        labelTop = true,
        get = function()
            return mod.db.anchors.main.enabled
        end,
        onChange = function(v)
            mod.db.anchors.main.enabled = v
        end
    })
    y = row(y, {intEnable, mainEnable})

    -- Font
    y = section(y, "Font")

    local fontSize = slider({
        label = L["FontSize"],
        min = 6,
        max = 24,
        step = 1,
        get = function()
            return mod.db.font.size
        end,
        onChange = function(v)
            mod.db.font.size = math.floor(v)
        end
    })
    local fontOutline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.font.outline
        end,
        onChange = function(v)
            mod.db.font.outline = v
        end
    })
    y = row(y, {fontSize, fontOutline})

    -- Intermission
    y = section(y, "BossMods_LMIntermission")

    local intScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2.0,
        step = 0.05,
        get = function()
            return mod.db.anchors.intermission.scale
        end,
        onChange = function(v)
            mod.db.anchors.intermission.scale = v
        end
    })
    local intOpacity = slider({
        label = L["Opacity"],
        min = 0.1,
        max = 1.0,
        step = 0.05,
        get = function()
            return mod.db.anchors.intermission.opacity
        end,
        onChange = function(v)
            mod.db.anchors.intermission.opacity = v
        end
    })
    y = row(y, {intScale, intOpacity})

    local intPosY, intHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.map and mod.map.anchors and mod.map.anchors.intermission,
        label = L["BossMods_LMIntermission"],
        headerText = L["BossMods_LMIntermissionPosition"],
        tracker = tracker,
        getPosition = function()
            local p = mod.db.anchors.intermission.position
            return {
                point = p.point,
                x = p.x,
                y = p.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition("intermission", pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = -200,
            y = 0
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl
    })
    y = intPosY
    posHandles[#posHandles + 1] = intHandle

    -- Main
    y = section(y, "BossMods_LMMain")

    local mainScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2.0,
        step = 0.05,
        get = function()
            return mod.db.anchors.main.scale
        end,
        onChange = function(v)
            mod.db.anchors.main.scale = v
        end
    })
    local mainOpacity = slider({
        label = L["Opacity"],
        min = 0.1,
        max = 1.0,
        step = 0.05,
        get = function()
            return mod.db.anchors.main.opacity
        end,
        onChange = function(v)
            mod.db.anchors.main.opacity = v
        end
    })
    y = row(y, {mainScale, mainOpacity})

    local bgColor = color({
        label = L["BossMods_BgColor"],
        hasAlpha = false,
        get = function()
            return mod.db.anchors.main.bgColor
        end,
        onChange = function(r, g, b)
            mod.db.anchors.main.bgColor = {
                r = r,
                g = g,
                b = b
            }
        end
    })
    local bgOpacity = slider({
        label = L["BackgroundOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.anchors.main.bgOpacity
        end,
        onChange = function(v)
            mod.db.anchors.main.bgOpacity = v
        end
    })
    y = row(y, {bgColor, bgOpacity})

    local borderCol = color({
        label = L["BorderColor"],
        hasAlpha = false,
        get = function()
            return mod.db.anchors.main.borderColor
        end,
        onChange = function(r, g, b)
            mod.db.anchors.main.borderColor = {
                r = r,
                g = g,
                b = b
            }
        end
    })
    local borderOpacity = slider({
        label = L["BossMods_BorderOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.anchors.main.borderOpacity
        end,
        onChange = function(v)
            mod.db.anchors.main.borderOpacity = v
        end
    })
    y = row(y, {borderCol, borderOpacity})

    local mainPosY, mainHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.map and mod.map.anchors and mod.map.anchors.main,
        label = L["BossMods_LMMain"],
        headerText = L["BossMods_LMMainPosition"],
        tracker = tracker,
        getPosition = function()
            local p = mod.db.anchors.main.position
            return {
                point = p.point,
                x = p.x,
                y = p.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition("main", pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 200,
            y = 0
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl
    })
    y = mainPosY
    posHandles[#posHandles + 1] = mainHandle

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            for _, h in ipairs(posHandles) do
                h.Release()
            end
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("LuraMap", buildLuraMapBody)
    end
end
