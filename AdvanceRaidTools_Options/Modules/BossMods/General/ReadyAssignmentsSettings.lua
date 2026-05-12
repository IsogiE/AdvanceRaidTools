local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function buildReadyAssignmentsBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    if mod.EnsureVisualAnchor then
        mod:EnsureVisualAnchor()
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
                opts.onChange(v)
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
                opts.onChange(v)
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
                opts.onChange(v)
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
                opts.onChange(r, g, b, a)
                refreshLive()
            end,
            disabled = isDisabled
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

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_AssignmentReminders"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_AssignmentRemindersDesc"],
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

    y = section(y, "Display")
    local duration = slider({
        label = L["BossMods_RA_Duration"],
        min = 2,
        max = 30,
        get = function()
            return mod.db.duration or 10
        end,
        onChange = function(v)
            mod.db.duration = math.floor(v)
        end
    })
    local width = slider({
        label = L["Width"],
        min = 220,
        max = 900,
        step = 10,
        get = function()
            return mod.db.size.w or 520
        end,
        onChange = function(v)
            mod.db.size.w = math.floor(v)
        end
    })
    y = row(y, {duration, width})

    y = section(y, "Font")
    local fontSize = slider({
        label = (L["Font"] .. " " .. L["Size"]),
        min = 12,
        max = 48,
        get = function()
            return mod.db.font.size or 24
        end,
        onChange = function(v)
            mod.db.font.size = math.floor(v)
        end
    })
    local fontOutline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.font.outline or "OUTLINE"
        end,
        onChange = function(v)
            mod.db.font.outline = v
        end
    })
    y = row(y, {fontSize, fontOutline})

    local fontColor = color({
        label = (L["Font"] .. " " .. L["Color"]),
        get = function()
            return mod.db.font.color
        end,
        onChange = function(r, g, b, a)
            mod.db.font.color = {r, g, b, a}
        end
    })
    y = row(y, {fontColor})

    y = section(y, "Background")
    local enableBg = checkbox({
        text = (L["Enable"] .. " " .. L["Background"]),
        labelTop = true,
        get = function()
            return mod.db.background.enabled
        end,
        onChange = function(v)
            mod.db.background.enabled = v
        end
    })
    local bgOpacity = slider({
        label = (L["Background"] .. " " .. L["Opacity"]),
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.background.opacity or 0
        end,
        onChange = function(v)
            mod.db.background.opacity = v
        end
    })
    y = row(y, {enableBg, bgOpacity})

    local bgColor = color({
        label = (L["Background"] .. " " .. L["Color"]),
        hasAlpha = false,
        get = function()
            return mod.db.background.color
        end,
        onChange = function(r, g, b)
            mod.db.background.color = {r, g, b}
        end
    })
    y = row(y, {bgColor})

    y = section(y, "Border")
    local enableBorder = checkbox({
        text = (L["Enable"] .. " " .. L["Border"]),
        labelTop = true,
        get = function()
            return mod.db.border.enabled
        end,
        onChange = function(v)
            mod.db.border.enabled = v
        end
    })
    local borderTex = dropdown({
        label = (L["Border"] .. " " .. L["Texture"]),
        values = borderValues,
        get = function()
            return mod.db.border.texture
        end,
        onChange = function(v)
            mod.db.border.texture = v
        end
    })
    y = row(y, {enableBorder, borderTex})

    local borderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        get = function()
            return mod.db.border.size or 1
        end,
        onChange = function(v)
            mod.db.border.size = math.floor(v)
        end
    })
    local borderColor = color({
        label = (L["Border"] .. " " .. L["Color"]),
        get = function()
            return mod.db.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderColor})

    local textPosY, textPosHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.frame,
        label = L["BossMods_AR_TextAnchor"],
        headerText = L["BossMods_AR_TextAnchor"],
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.position.point,
                x = mod.db.position.x,
                y = mod.db.position.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition(pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = 190
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = textPosY

    local visualPosY, visualPosHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.visualAnchor,
        label = L["BossMods_AR_VisualAnchor"],
        headerText = L["BossMods_AR_VisualAnchor"],
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.visualPosition.point,
                x = mod.db.visualPosition.x,
                y = mod.db.visualPosition.y
            }
        end,
        setPosition = function(pos)
            mod:SaveVisualPosition(pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = -170
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = visualPosY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            textPosHandle.Release()
            visualPosHandle.Release()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("ReadyAssignments", buildReadyAssignmentsBody)
    end
end
