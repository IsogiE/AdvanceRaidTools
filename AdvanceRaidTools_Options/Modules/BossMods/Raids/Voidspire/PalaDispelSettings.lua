local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local NAME_MODE_VALUES = {
    class = L["ClassColor"],
    custom = L["BossMods_PDNameCustom"]
}

local AUDIO_TYPE_VALUES = {
    sound = L["BossMods_PDAudioSound"],
    tts = L["BossMods_PDAudioTTS"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function fontValues()
    return E:MediaList("font")
end

local function buildPalaDispelBody(rightPanel, mod, isDisabled)
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
                opts.onChange(v)
                if opts.afterChange then
                    opts.afterChange(v)
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

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_PalaDispel"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_PalaDispelDesc"],
        sizeDelta = 1
    })))

    -- Text
    y = section(y, "BossMods_PDTextSection")

    local fontFace = dropdown({
        label = L["Font"],
        values = fontValues,
        get = function()
            return mod.db.font.face
        end,
        onChange = function(v)
            mod.db.font.face = v
        end
    })
    local fontSize = slider({
        label = L["FontSize"],
        min = 10,
        max = 72,
        step = 1,
        get = function()
            return mod.db.font.size
        end,
        onChange = function(v)
            mod.db.font.size = math.floor(v)
        end
    })
    y = row(y, {fontFace, fontSize})

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
    y = row(y, {fontOutline})

    -- Colors
    y = section(y, "Colors")

    local actionCol = color({
        label = L["BossMods_PDActionColor"],
        hasAlpha = false,
        get = function()
            return mod.db.colors.action
        end,
        onChange = function(r, g, b)
            mod.db.colors.action = {r, g, b, 1}
        end
    })
    local dwarfCol = color({
        label = L["BossMods_PDDwarfColor"],
        hasAlpha = false,
        get = function()
            return mod.db.colors.dwarf
        end,
        onChange = function(r, g, b)
            mod.db.colors.dwarf = {r, g, b, 1}
        end
    })
    y = row(y, {actionCol, dwarfCol})

    local nameMode = dropdown({
        label = L["BossMods_PDNameMode"],
        values = NAME_MODE_VALUES,
        get = function()
            return mod.db.colors.nameMode
        end,
        onChange = function(v)
            mod.db.colors.nameMode = v
        end
    })
    local nameCustom = color({
        label = L["BossMods_PDNameCustomColor"],
        hasAlpha = false,
        get = function()
            return mod.db.colors.nameCustom
        end,
        onChange = function(r, g, b)
            mod.db.colors.nameCustom = {r, g, b, 1}
        end,
        disabled = function()
            return isDisabled() or mod.db.colors.nameMode == "class"
        end
    })
    y = row(y, {nameMode, nameCustom})

    -- Glow
    y = section(y, "BossMods_PDGlowSection")

    local glowType = dropdown({
        label = L["BossMods_PDGlowType"],
        values = E:GetModule("BossMods").Alerts:GetGlowTypes(),
        get = function()
            return mod.db.glow.glowType
        end,
        onChange = function(v)
            mod.db.glow.glowType = v
        end
    })
    local glowColor = color({
        label = L["BossMods_PDGlowColor"],
        hasAlpha = true,
        get = function()
            return mod.db.glow.color
        end,
        onChange = function(r, g, b, a)
            mod.db.glow.color = {r, g, b, a}
        end
    })
    y = row(y, {glowType, glowColor})

    local glowLines = slider({
        label = L["BossMods_PDGlowLines"],
        min = 1,
        max = 20,
        step = 1,
        get = function()
            return mod.db.glow.lines
        end,
        onChange = function(v)
            mod.db.glow.lines = math.floor(v)
        end,
        disabled = function()
            if isDisabled() then
                return true
            end
            local t = mod.db.glow.glowType
            return t ~= "Pixel" and t ~= "Autocast"
        end
    })
    local glowThickness = slider({
        label = L["BossMods_PDGlowThickness"],
        min = 1,
        max = 10,
        step = 1,
        get = function()
            return mod.db.glow.thickness
        end,
        onChange = function(v)
            mod.db.glow.thickness = math.floor(v)
        end,
        disabled = function()
            return isDisabled() or mod.db.glow.glowType ~= "Pixel"
        end
    })
    y = row(y, {glowLines, glowThickness})

    local glowFreq = slider({
        label = L["BossMods_PDGlowFrequency"],
        min = 0,
        max = 20,
        step = 1,
        get = function()
            return mod.db.glow.frequency
        end,
        onChange = function(v)
            mod.db.glow.frequency = math.floor(v)
        end
    })
    local glowScale = slider({
        label = L["Scale"],
        min = 5,
        max = 30,
        step = 1,
        get = function()
            return mod.db.glow.scale
        end,
        onChange = function(v)
            mod.db.glow.scale = math.floor(v)
        end,
        disabled = function()
            return isDisabled() or mod.db.glow.glowType ~= "Autocast"
        end
    })
    y = row(y, {glowFreq, glowScale})

    -- Audio
    y = section(y, "BossMods_PDAudioSection")

    local audioType = dropdown({
        label = L["BossMods_PDAudioType"],
        values = AUDIO_TYPE_VALUES,
        get = function()
            return mod.db.audio.type
        end,
        onChange = function(v)
            mod.db.audio.type = v
        end
    })
    y = row(y, {audioType})

    local audioSound = dropdown({
        label = L["BossMods_PDAudioSoundFile"],
        values = function()
            return E:GetModule("BossMods").Alerts:GetSoundOptions()
        end,
        get = function()
            return mod.db.audio.sound
        end,
        onChange = function(v)
            mod.db.audio.sound = v
        end,
        afterChange = function(v)
            E:GetModule("BossMods").Alerts:PlaySound({
                name = v,
                channel = mod.db.audio.channel
            })
        end,
        disabled = function()
            return isDisabled() or mod.db.audio.type ~= "sound"
        end
    })
    local audioChannel = dropdown({
        label = L["BossMods_LKSoundChannel"],
        values = E:GetModule("BossMods").Alerts.SOUND_CHANNELS,
        get = function()
            return mod.db.audio.channel
        end,
        onChange = function(v)
            mod.db.audio.channel = v
        end,
        disabled = function()
            return isDisabled() or mod.db.audio.type ~= "sound"
        end
    })
    y = row(y, {audioSound, audioChannel})

    local audioVoice = dropdown({
        label = L["BossMods_DQTTSVoice"],
        values = function()
            return E:GetModule("BossMods").Alerts:GetTTSVoices()
        end,
        get = function()
            return mod.db.audio.voice or 0
        end,
        onChange = function(v)
            mod.db.audio.voice = tonumber(v) or 0
        end,
        afterChange = function(v)
            E:GetModule("BossMods").Alerts:SpeakTTS({
                text = "Voice test",
                voiceID = tonumber(v) or 0
            })
        end,
        disabled = function()
            return isDisabled() or mod.db.audio.type ~= "tts"
        end
    })
    y = row(y, {audioVoice})

    -- Position
    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.alert and mod.alert.frame,
        label = L["BossMods_PalaDispel"],
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
            y = 0
        },
        onChanged = refreshLive,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end,
        isDisabled = isDisabled
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            posHandle.Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("PalaDispel", buildPalaDispelBody)
    end
end
