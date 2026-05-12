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
            format = opts.format,
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
            tooltip = opts.tooltip,
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
    local previewUnlocked = false
    local fullPreview
    local p2Preview
    local function previewDisabled()
        local moduleDisabled = isDisabled
        if type(isDisabled) == "function" then
            moduleDisabled = isDisabled()
        end
        return moduleDisabled or not previewUnlocked
    end
    local function refreshPreviewControls()
        local disabled = previewDisabled()
        if fullPreview and fullPreview.SetDisabled then
            fullPreview.SetDisabled(disabled)
        end
        if p2Preview and p2Preview.SetDisabled then
            p2Preview.SetDisabled(disabled)
        end
    end

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
            previewUnlocked = v and true or false
            refreshPreviewControls()
            mod:SetEditMode(v)
        end
    })
    y = unlockY

    fullPreview = checkbox({
        text = L["BossMods_LMFullP2Preview"] or "Full P2 circle preview",
        labelTop = true,
        tooltip = {
            title = L["BossMods_LMFullP2Preview"] or "Full P2 circle preview",
            desc = L["BossMods_LMFullP2PreviewDesc"] or
                "When frames are unlocked, the P2 maps show the complete circle instead of your current slice."
        },
        get = function()
            return mod.db.anchors.main.fullPreview
        end,
        onChange = function(v)
            mod.db.anchors.main.fullPreview = v
        end,
        disabled = previewDisabled
    })

    p2Preview = slider({
        label = L["BossMods_LMP2PreviewMap"] or "P2 preview map",
        min = 1,
        max = 2,
        step = 1,
        get = function()
            return mod.db.anchors.main.previewLayout or 1
        end,
        onChange = function(v)
            mod.db.anchors.main.previewLayout = math.max(1, math.min(2, math.floor(v + 0.5)))
        end,
        format = function(v)
            return v >= 1.5 and (L["BossMods_LMP2PreviewMap2"] or "Alt") or
                (L["BossMods_LMP2PreviewMap1"] or "Normal")
        end,
        disabled = previewDisabled
    })
    y = row(y, {fullPreview, p2Preview})

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
        label = (L["Font"] .. " " .. L["Size"]),
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
        label = (L["Background"] .. " " .. L["Color"]),
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
        label = (L["Background"] .. " " .. L["Opacity"]),
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
        label = (L["Border"] .. " " .. L["Color"]),
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
        label = (L["Border"] .. " " .. L["Opacity"]),
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
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = intPosY
    posHandles[#posHandles + 1] = intHandle

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
        unlockController = unlockCtrl,
        showOffsets = true
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
