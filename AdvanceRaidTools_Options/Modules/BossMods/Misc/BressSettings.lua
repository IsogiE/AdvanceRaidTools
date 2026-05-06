local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local ANCHOR_VALUES = {
    TOPLEFT = L["TopLeft"],
    TOP = L["Top"],
    TOPRIGHT = L["TopRight"],
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"],
    BOTTOMLEFT = L["BottomLeft"],
    BOTTOM = L["Bottom"],
    BOTTOMRIGHT = L["BottomRight"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function buildBressBody(rightPanel, mod, isDisabled)
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

    local function textGroup(y, dbField, headerKey, colorLabelKey)
        y = section(y, headerKey)

        local anchorDd = dropdown({
            label = L["Anchor"],
            values = ANCHOR_VALUES,
            get = function()
                return mod.db[dbField].anchor
            end,
            onChange = function(v)
                mod.db[dbField].anchor = v
            end
        })
        y = row(y, {anchorDd})

        local ox = slider({
            label = L["OffsetX"],
            min = -30,
            max = 30,
            get = function()
                return mod.db[dbField].offsetX
            end,
            onChange = function(v)
                mod.db[dbField].offsetX = math.floor(v)
            end
        })
        local oy = slider({
            label = L["OffsetY"],
            min = -30,
            max = 30,
            get = function()
                return mod.db[dbField].offsetY
            end,
            onChange = function(v)
                mod.db[dbField].offsetY = math.floor(v)
            end
        })
        y = row(y, {ox, oy})

        local sz = slider({
            label = (L["Font"] .. " " .. L["Size"]),
            min = 7,
            max = 32,
            get = function()
                return mod.db[dbField].size
            end,
            onChange = function(v)
                mod.db[dbField].size = math.floor(v)
            end
        })
        local outline = dropdown({
            label = L["Outline"],
            values = OUTLINE_VALUES,
            get = function()
                return mod.db[dbField].outline
            end,
            onChange = function(v)
                mod.db[dbField].outline = v
            end
        })
        y = row(y, {sz, outline})

        local col = color({
            label = L[colorLabelKey] or colorLabelKey,
            hasAlpha = true,
            get = function()
                return mod.db[dbField].color
            end,
            onChange = function(r, g, b, a)
                mod.db[dbField].color = {r, g, b, a}
            end
        })
        y = row(y, {col})

        return y
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_Bress"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_BressDesc"],
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
    local enableSwipe = checkbox({
        text = L["BossMods_BressSwipe"],
        labelTop = true,
        get = function()
            return mod.db.cooldownSwipe and true or false
        end,
        onChange = function(v)
            mod.db.cooldownSwipe = v
        end
    })
    y = row(y, {enableBorder, enableSwipe})

    -- Icon
    y = section(y, "Icon")
    local iconSize = slider({
        label = (L["Icon"] .. " " .. L["Size"]),
        min = 16,
        max = 256,
        get = function()
            return mod.db.iconSize
        end,
        onChange = function(v)
            mod.db.iconSize = math.floor(v)
        end
    })
    y = row(y, {iconSize})

    -- Border
    y = section(y, "Border")
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
    y = row(y, {borderTex})

    local borderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        get = function()
            return mod.db.border.size
        end,
        onChange = function(v)
            mod.db.border.size = math.floor(v)
        end
    })
    local borderColor = color({
        label = (L["Border"] .. " " .. L["Color"]),
        hasAlpha = true,
        get = function()
            return mod.db.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderColor})

    -- Cooldown text
    y = textGroup(y, "timeText", L["Cooldown"] .. " " .. L["Text"], L["Cooldown"] .. " " .. L["Color"])

    -- Charge text
    y = textGroup(y, "chargeText", L["Charge"] .. " " .. L["Text"], L["Charge"] .. " " .. L["Color"])

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.frame,
        label = L["BossMods_Bress"],
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
            y = 350
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            posHandle.Release()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("Bress", buildBressBody)
    end
end
