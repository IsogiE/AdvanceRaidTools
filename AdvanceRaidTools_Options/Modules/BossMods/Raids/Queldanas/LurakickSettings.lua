local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local JUSTIFY_VALUES = {
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function buildLurakickBody(rightPanel, mod, isDisabled)
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
                if opts.playSample then
                    opts.playSample(v)
                end
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
        text = L["BossMods_Lurakick"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_LurakickDesc"],
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
    y = row(y, {enableBorder})

    -- Background & Border
    y = section(y, L["Background"] .. " & " .. L["Border"])

    local bgOpacity = slider({
        label = (L["Background"] .. " " .. L["Opacity"]),
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.background.opacity
        end,
        onChange = function(v)
            mod.db.background.opacity = v
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
    y = row(y, {bgOpacity, borderTex})

    local borderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        step = 1,
        get = function()
            return mod.db.border.size
        end,
        onChange = function(v)
            mod.db.border.size = math.floor(v)
        end
    })
    local borderCol = color({
        label = (L["Border"] .. " " .. L["Color"]),
        get = function()
            return mod.db.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderCol})

    -- Font
    y = section(y, "Font")

    local fontSize = slider({
        label = (L["Font"] .. " " .. L["Size"]),
        min = 8,
        max = 32,
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

    local fontJustify = dropdown({
        label = L["BossMods_Justify"],
        values = JUSTIFY_VALUES,
        get = function()
            return mod.db.font.justify
        end,
        onChange = function(v)
            mod.db.font.justify = v
        end
    })
    y = row(y, {fontJustify})

    -- Sound
    y = section(y, "BossMods_LKSoundSection")

    local soundName = dropdown({
        label = L["BossMods_LKKickSound"],
        values = function()
            return E:GetModule("BossMods").Alerts:GetSoundOptions()
        end,
        get = function()
            return mod.db.sound.name
        end,
        onChange = function(v)
            mod.db.sound.name = v
        end,
        playSample = function(v)
            E:GetModule("BossMods").Alerts:PlaySound({
                name = v,
                channel = mod.db.sound.channel
            })
        end
    })
    local soundChannel = dropdown({
        label = L["BossMods_LKSoundChannel"],
        values = E:GetModule("BossMods").Alerts.SOUND_CHANNELS,
        get = function()
            return mod.db.sound.channel
        end,
        onChange = function(v)
            mod.db.sound.channel = v
        end
    })
    y = row(y, {soundName, soundChannel})

    -- Position
    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.list and mod.list.frame,
        label = L["BossMods_Lurakick"],
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
            x = 300,
            y = 0
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl
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
        BossMods:RegisterBossSettingsBuilder("Lurakick", buildLurakickBody)
    end
end
