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

local function buildCoiledAltarKickerBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    mod:EnsureDefaults()
    mod:EnsureFrames()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local positionHandles = {}
    local refreshAudioLayout

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
        if refreshAudioLayout then
            refreshAudioLayout()
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

    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            get = opts.get,
            onChange = function(_, value)
                opts.set(value and true or false)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
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
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refreshLive(false)
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
        text = L["BossMods_CoiledAltarKicker"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_CoiledAltarKickerDesc"],
        sizeDelta = 1
    })))

    local unlockY, unlockController = T:UnlockController(rightPanel, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value)
            mod:SetEditMode(value)
        end
    })
    y = unlockY

    y = section(y, L["BossMods_NoteKickAssignments"])
    local boxSize = slider({
        label = L["Size"],
        min = 18,
        max = 90,
        step = 1,
        get = function()
            return mod.db.box.size
        end,
        set = function(value)
            mod.db.box.size = math.floor(value + 0.5)
        end
    })
    local opacity = slider({
        label = L["Opacity"],
        min = 0.05,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.box.opacity
        end,
        set = function(value)
            mod.db.box.opacity = value
        end
    })
    y = row(y, {boxSize, opacity})

    y = row(y, {
        stepper({
            label = L["OffsetX"],
            min = -200,
            max = 200,
            get = function()
                return mod.db.box.offsetX or -8
            end,
            set = function(value)
                mod.db.box.offsetX = math.max(
                    -200,
                    math.min(200, tonumber(value) or -8)
                )
            end
        }),
        stepper({
            label = L["OffsetY"],
            min = -200,
            max = 200,
            get = function()
                return mod.db.box.offsetY or 0
            end,
            set = function(value)
                mod.db.box.offsetY = math.max(
                    -200,
                    math.min(200, tonumber(value) or 0)
                )
            end
        })
    })

    y = section(y, L["Text"])
    y = row(y, {
        dropdown({
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
        }),
        dropdown({
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
    })
    y = row(y, {
        slider({
            label = (L["Font"] or "Font") .. " " .. (L["Size"] or "Size"),
            min = 8,
            max = 36,
            step = 1,
            get = function()
                return mod.db.font.size
            end,
            set = function(value)
                mod.db.font.size = math.floor(value + 0.5)
            end
        }),
        color({
            label = L["Color"],
            get = function()
                return mod.db.font.color
            end,
            set = function(value)
                mod.db.font.color = value
            end
        })
    })

    y = section(y, L["Text"])
    y = full(y, checkbox({
        text = (L["Show"] or "Show") .. " "
            .. (L["BossMods_CAKYourKickNext"] or "Your kick next"),
        get = function()
            return mod.db.nextText.enabled
        end,
        set = function(value)
            mod.db.nextText.enabled = value
        end
    }))
    y = row(y, {
        dropdown({
            label = L["Font"] or "Font",
            values = function()
                return E:MediaList("font")
            end,
            get = function()
                return mod.db.nextText.name
            end,
            set = function(value)
                mod.db.nextText.name = value
            end
        }),
        dropdown({
            label = L["Outline"] or "Outline",
            values = OUTLINE_VALUES,
            sorting = OUTLINE_SORTING,
            get = function()
                return mod.db.nextText.outline
            end,
            set = function(value)
                mod.db.nextText.outline = value or ""
            end
        })
    })
    y = row(y, {
        slider({
            label = (L["Font"] or "Font") .. " " .. (L["Size"] or "Size"),
            min = 12,
            max = 60,
            step = 1,
            get = function()
                return mod.db.nextText.size
            end,
            set = function(value)
                mod.db.nextText.size = math.floor(value + 0.5)
            end
        }),
        color({
            label = L["Color"],
            get = function()
                return mod.db.nextText.color
            end,
            set = function(value)
                mod.db.nextText.color = value
            end
        })
    })

    y = section(y, L["Position"] or "Position")
    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frames and mod.frames.anchor,
        label = L["Position"],
        headerText = L["Position"],
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.position.point,
                x = mod.db.position.x,
                y = mod.db.position.y
            }
        end,
        setPosition = function(position)
            mod:SavePosition(position, "position")
        end,
        defaultPosition = {point = "CENTER", x = 0, y = 160},
        onChanged = function()
            refreshLive(false)
        end,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    positionHandles[#positionHandles + 1] = positionHandle
    y = positionY

    positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frames and mod.frames.nextTextAnchor,
        label = (L["Text"] or "Text") .. " " .. (L["Position"] or "Position"),
        headerText = (L["Text"] or "Text") .. " "
            .. (L["Position"] or "Position"),
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.nextTextPosition.point,
                x = mod.db.nextTextPosition.x,
                y = mod.db.nextTextPosition.y
            }
        end,
        setPosition = function(position)
            mod:SavePosition(position, "nextTextPosition")
        end,
        defaultPosition = {point = "CENTER", x = 0, y = 215},
        onChanged = function()
            refreshLive(false)
        end,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    positionHandles[#positionHandles + 1] = positionHandle
    y = positionY

    y = section(y, L["Audio"])
    y = full(y, checkbox({
        text = L["BossMods_AAOptions_EnableAudio"] or "Enable audio",
        get = function()
            return mod.db.audio.enabled
        end,
        set = function(value)
            mod.db.audio.enabled = value
        end
    }))

    local audioContainer = CreateFrame("Frame", nil, rightPanel)
    local audioStartY = y

    local audioType = track(T:Dropdown(audioContainer, {
        label = L["BossMods_AAOptions_AudioType"] or "Audio type",
        values = AUDIO_MODE_VALUES,
        sorting = AUDIO_MODE_SORTING,
        get = function()
            return mod.db.audio.mode
        end,
        onChange = function(value)
            mod.db.audio.mode = value == "tts" and "tts" or "sound"
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local soundFile = track(T:Dropdown(audioContainer, {
        label = L["BossMods_AAOptions_SoundFile"] or "Sound file",
        values = function()
            return E:GetModule("BossMods").Alerts:GetSoundOptions()
        end,
        get = function()
            return mod.db.audio.sound
        end,
        onChange = function(value)
            mod.db.audio.sound = value
            E:GetModule("BossMods").Alerts:PlaySound({
                name = value,
                channel = mod.db.audio.channel or "Master"
            })
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local soundChannel = track(T:Dropdown(audioContainer, {
        label = L["BossMods_AAOptions_SoundChannel"] or "Sound channel",
        values = SOUND_CHANNEL_VALUES,
        sorting = SOUND_CHANNEL_SORTING,
        get = function()
            return mod.db.audio.channel
        end,
        onChange = function(value)
            mod.db.audio.channel = value
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local ttsText = track(T:EditBox(audioContainer, {
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
                or "Kick"
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local ttsVoice = track(T:Dropdown(audioContainer, {
        label = L["BossMods_AAOptions_TTSVoice"] or "TTS voice",
        values = function()
            return E:GetModule("BossMods").Alerts:GetTTSVoices()
        end,
        get = function()
            return mod.db.audio.voiceID or 0
        end,
        onChange = function(value)
            mod.db.audio.voiceID = tonumber(value) or 0
            E:GetModule("BossMods").Alerts:SpeakTTS({
                text = mod.db.audio.ttsText or "Kick",
                voiceID = mod.db.audio.voiceID or 0
            })
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local audioWidget
    refreshAudioLayout = function()
        local innerWidth = audioContainer:GetWidth()
        if not innerWidth or innerWidth <= 0 then
            innerWidth = width - 20
        end

        local enabled = mod.db.audio.enabled == true
        local mode = mod.db.audio.mode == "tts" and "tts" or "sound"
        audioType.frame:SetShown(enabled)
        soundFile.frame:SetShown(enabled and mode == "sound")
        soundChannel.frame:SetShown(enabled and mode == "sound")
        ttsText.frame:SetShown(enabled and mode == "tts")
        ttsVoice.frame:SetShown(enabled and mode == "tts")

        local audioY = 0
        if enabled then
            audioY = audioY
                + T:PlaceFull(audioContainer, audioType, audioY, innerWidth)
                + ROW_GAP
            if mode == "sound" then
                audioY = audioY
                    + T:PlaceRow(
                        audioContainer,
                        {soundFile, soundChannel},
                        audioY,
                        innerWidth
                    )
                    + ROW_GAP
            else
                audioY = audioY
                    + T:PlaceRow(
                        audioContainer,
                        {ttsText, ttsVoice},
                        audioY,
                        innerWidth
                    )
                    + ROW_GAP
            end
        end

        audioContainer:SetHeight(audioY)
        rightPanel:SetHeight(math.max(audioStartY + audioY + 10, 1))
    end

    audioWidget = track({
        frame = audioContainer,
        _relayout = refreshAudioLayout,
        Refresh = refreshAudioLayout
    })
    refreshAudioLayout()
    y = y + T:PlaceFull(rightPanel, audioWidget, y, width) + ROW_GAP

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = function()
            tracker.refresh()
            refreshAudioLayout()
        end,
        Release = function()
            mod:SetEditMode(false)
            for _, handle in ipairs(positionHandles) do
                if handle and handle.Release then
                    handle.Release()
                end
            end
            if unlockController and unlockController.Release then
                unlockController:Release()
            end
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder(
        "CoiledAltarKicker",
        buildCoiledAltarKickerBody
    )
end
