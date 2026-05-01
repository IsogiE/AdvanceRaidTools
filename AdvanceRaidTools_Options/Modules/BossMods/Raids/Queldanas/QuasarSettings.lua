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

local function buildQuasarBody(rightPanel, mod, isDisabled)
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
    local header = track(T:Header(rightPanel, {
        text = L["BossMods_DarkQuasar"]
    }))
    y = full(y, header)
    local desc = track(T:Description(rightPanel, {
        text = L["BossMods_DarkQuasarDesc"],
        sizeDelta = 1
    }))
    y = full(y, desc)

    local unlockY, unlockCtrl = T:UnlockController(rightPanel, y, widthPx, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end
    })
    y = unlockY

    -- General
    y = section(y, "General")

    local showInt = checkbox({
        text = L["BossMods_DQShowIntermission"],
        tooltip = {
            title = L["BossMods_DQShowIntermission"],
            desc = L["BossMods_DQShowIntermissionDesc"]
        },
        get = function()
            return mod.db.showIntermission
        end,
        onChange = function(v)
            mod.db.showIntermission = v
        end
    })
    y = row(y, {showInt})

    -- Bar
    y = section(y, "Bar")

    local barWidth = slider({
        label = L["Width"],
        min = 100,
        max = 600,
        step = 1,
        get = function()
            return mod.db.bar.width
        end,
        onChange = function(v)
            mod.db.bar.width = math.floor(v)
        end
    })
    local barHeight = slider({
        label = L["Height"],
        min = 8,
        max = 64,
        step = 1,
        get = function()
            return mod.db.bar.height
        end,
        onChange = function(v)
            mod.db.bar.height = math.floor(v)
        end
    })
    y = row(y, {barWidth, barHeight})

    local safeCol = color({
        label = (L["Safe"] .. " " .. L["Color"]),
        hasAlpha = true,
        get = function()
            return mod.db.bar.safeColor
        end,
        onChange = function(r, g, b, a)
            mod.db.bar.safeColor = {r, g, b, a}
        end
    })
    local dangerCol = color({
        label = (L["Danger"] .. " " .. L["Color"]),
        hasAlpha = true,
        get = function()
            return mod.db.bar.dangerColor
        end,
        onChange = function(r, g, b, a)
            mod.db.bar.dangerColor = {r, g, b, a}
        end
    })
    y = row(y, {safeCol, dangerCol})

    -- Background / Border
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
    y = row(y, {bgOpacity})

    local borderEnable = checkbox({
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
    y = row(y, {borderEnable, borderTex})

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
        hasAlpha = true,
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
        max = 36,
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

    -- TTS
    y = section(y, "TextToSpeech")

    local ttsEnable = checkbox({
        text = (L["Enable"] .. " " .. L["TTS"]),
        labelTop = true,
        get = function()
            return mod.db.tts.enabled
        end,
        onChange = function(v)
            mod.db.tts.enabled = v
        end
    })
    local ttsVoice = dropdown({
        label = L["BossMods_DQTTSVoice"],
        values = function()
            return E:GetModule("BossMods").Alerts:GetTTSVoices()
        end,
        get = function()
            return mod.db.tts.voice or 0
        end,
        onChange = function(v)
            mod.db.tts.voice = tonumber(v) or 0
            E:GetModule("BossMods").Alerts:SpeakTTS({
                text = "Voice test",
                voiceID = mod.db.tts.voice
            })
        end,
        disabled = function()
            return isDisabled() or not mod.db.tts.enabled
        end
    })
    y = row(y, {ttsEnable, ttsVoice})

    local function ttsSubDisabled()
        return isDisabled() or not mod.db.tts.enabled
    end

    local ttsBeam = checkbox({
        text = L["BossMods_DQTTSBeamSoon"],
        labelTop = true,
        get = function()
            return mod.db.tts.beamSoon
        end,
        onChange = function(v)
            mod.db.tts.beamSoon = v
        end,
        disabled = ttsSubDisabled
    })
    local ttsUnsafe = checkbox({
        text = L["BossMods_DQTTSUnsafeSoon"],
        labelTop = true,
        get = function()
            return mod.db.tts.unsafeSoon
        end,
        onChange = function(v)
            mod.db.tts.unsafeSoon = v
        end,
        disabled = ttsSubDisabled
    })
    local ttsDanger = checkbox({
        text = L["BossMods_DQTTSDangerCountdown"],
        labelTop = true,
        get = function()
            return mod.db.tts.dangerCountdown
        end,
        onChange = function(v)
            mod.db.tts.dangerCountdown = v
        end,
        disabled = ttsSubDisabled
    })
    y = row(y, {ttsBeam, ttsUnsafe, ttsDanger})

    -- Position
    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.bar and mod.bar.frame,
        label = L["BossMods_DarkQuasar"],
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
            y = 300
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
        BossMods:RegisterBossSettingsBuilder("DarkQuasar", buildQuasarBody)
    end
end
