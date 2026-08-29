local E, L = unpack(ART)
local T = E.Templates

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

local AUDIO_MODE_VALUES = {
    sound = "Sound file",
    tts = "Text to Speech"
}

local AUDIO_MODE_SORTING = {"sound", "tts"}

local SOUND_CHANNEL_VALUES = {
    Master = "Master",
    SFX = "Sound Effects",
    Dialog = "Dialog",
    Music = "Music",
    Ambience = "Ambience"
}

local SOUND_CHANNEL_SORTING = {
    "Master",
    "SFX",
    "Dialog",
    "Music",
    "Ambience"
}

local function buildRavenousFeastSoakCircleBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    mod:EnsureDefaults()

    local tracker = T:MakeTracker()
    local track = tracker.track

    local function refreshLive(rebuild)
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
        if rebuild and E.OptionsUI and E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("current")
        end
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, width) + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(rightPanel, {text = text}))
        return y + T:PlaceFull(rightPanel, header, y, width) + HEADER_GAP
    end

    local function dropdown(opts)
        return track(T:Dropdown(rightPanel, {
            label = opts.label,
            values = opts.values,
            sorting = opts.sorting,
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                if opts.playSample then
                    opts.playSample(value)
                end
                refreshLive(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function stepper(opts)
        return track(T:NumericStepper(rightPanel, {
            label = opts.label,
            get = opts.get,
            set = function(value)
                opts.set(value)
                refreshLive(false)
            end,
            step = opts.step or 1,
            decimals = opts.decimals,
            min = opts.min,
            max = opts.max,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local current = opts.get()
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = current[1] or current.r or 1,
            g = current[2] or current.g or 1,
            b = current[3] or current.b or 1,
            a = current[4] or current.a or 1,
            onChange = function(r, g, b, a)
                opts.set({r, g, b, a})
                refreshLive(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_RavenousFeastSoakCircle"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_RavenousFeastSoakCircleDesc"],
        sizeDelta = 1
    })))

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_RFSCPreview"],
        get = function()
            return mod.previewMode and true or false
        end,
        onChange = function(_, value)
            mod:SetPreviewMode(value)
            tracker.refresh()
        end,
        disabled = isDisabled
    })))

    y = section(y, L["BossMods_RFSCTextAppearance"])

    local font = dropdown({
        label = L["Font"] or "Font",
        values = function()
            return E:MediaList("font")
        end,
        get = function()
            return mod.db.font.name
        end,
        set = function(value)
            mod.db.font.name = value
        end
    })

    local outline = dropdown({
        label = L["Outline"] or "Outline",
        values = OUTLINE_VALUES,
        sorting = OUTLINE_SORTING,
        get = function()
            return mod.db.font.outline
        end,
        set = function(value)
            mod.db.font.outline = value or ""
        end
    })
    y = row(y, {font, outline})

    local fontSize = track(T:Slider(rightPanel, {
        label = (L["Font"] or "Font") .. " " .. (L["Size"] or "Size"),
        min = 8,
        max = 32,
        step = 1,
        value = mod.db.font.size,
        get = function()
            return mod.db.font.size
        end,
        onChange = function(value)
            mod.db.font.size = math.floor(value + 0.5)
            refreshLive(false)
        end,
        disabled = isDisabled
    }))

    local textColor = color({
        label = L["BossMods_RFSCTextColor"],
        get = function()
            return mod.db.font.color
        end,
        set = function(value)
            mod.db.font.color = value
        end
    })
    y = row(y, {fontSize, textColor})

    local offsetX = stepper({
        label = L["BossMods_RFSCTextOffsetX"],
        min = -100,
        max = 100,
        step = 1,
        get = function()
            return mod.db.font.offsetX or 0
        end,
        set = function(value)
            mod.db.font.offsetX = math.max(-100, math.min(100, value or 0))
        end
    })

    local offsetY = stepper({
        label = L["BossMods_RFSCTextOffsetY"],
        min = -100,
        max = 100,
        step = 1,
        get = function()
            return mod.db.font.offsetY or 0
        end,
        set = function(value)
            mod.db.font.offsetY = math.max(-100, math.min(100, value or 0))
        end
    })
    y = row(y, {offsetX, offsetY})

    y = section(y, L["BossMods_RFSCAudio"])

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_RFSCEnableAudio"],
        get = function()
            return mod.db.audio.enabled
        end,
        onChange = function(_, value)
            mod.db.audio.enabled = value and true or false
            refreshLive(true)
        end,
        disabled = isDisabled
    })))

    if mod.db.audio.enabled then
        y = full(y, dropdown({
            label = L["BossMods_AAOptions_AudioType"] or "Audio type",
            values = AUDIO_MODE_VALUES,
            sorting = AUDIO_MODE_SORTING,
            get = function()
                return mod.db.audio.mode
            end,
            set = function(value)
                mod.db.audio.mode = value == "tts" and "tts" or "sound"
            end,
            rebuild = true
        }))

        if mod.db.audio.mode == "sound" then
            local sound = dropdown({
                label = L["BossMods_AAOptions_SoundFile"] or "Sound file",
                values = function()
                    return E:GetModule("BossMods").Alerts:GetSoundOptions()
                end,
                get = function()
                    return mod.db.audio.sound
                end,
                set = function(value)
                    mod.db.audio.sound = value
                end,
                playSample = function(value)
                    E:GetModule("BossMods").Alerts:PlaySound({
                        name = value,
                        channel = mod.db.audio.channel or "Master"
                    })
                end
            })

            local channel = dropdown({
                label = L["BossMods_AAOptions_SoundChannel"] or "Sound channel",
                values = SOUND_CHANNEL_VALUES,
                sorting = SOUND_CHANNEL_SORTING,
                get = function()
                    return mod.db.audio.channel
                end,
                set = function(value)
                    mod.db.audio.channel = value
                end
            })
            y = row(y, {sound, channel})
        else
            local message = track(T:EditBox(rightPanel, {
                label = L["BossMods_AAOptions_TextToSpeechMessage"]
                    or "Text to Speech message",
                default = mod.db.audio.ttsText,
                get = function()
                    return mod.db.audio.ttsText
                end,
                commitOn = "enter",
                onCommit = function(value)
                    mod.db.audio.ttsText = strtrim(value or "") ~= ""
                        and value
                        or "GO"
                    refreshLive(false)
                end,
                disabled = isDisabled
            }))

            local voice = dropdown({
                label = L["BossMods_AAOptions_TTSVoice"] or "TTS voice",
                values = function()
                    return E:GetModule("BossMods").Alerts:GetTTSVoices()
                end,
                get = function()
                    return mod.db.audio.voiceID or 0
                end,
                set = function(value)
                    mod.db.audio.voiceID = tonumber(value) or 0
                end,
                playSample = function()
                    E:GetModule("BossMods").Alerts:SpeakTTS({
                        text = mod.db.audio.ttsText or "GO",
                        voiceID = mod.db.audio.voiceID or 0
                    })
                end
            })
            y = row(y, {message, voice})
        end
    end

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetPreviewMode(false)
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder(
        "RavenousFeastSoakCircle",
        buildRavenousFeastSoakCircleBody
    )
end
