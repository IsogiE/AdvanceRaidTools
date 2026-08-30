local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local AUDIO_MODE_VALUES = {
    sound = "Sound file",
    tts = "Text to Speech"
}

local SOUND_CHANNEL_VALUES = {
    Master = "Master",
    SFX = "Sound Effects",
    Dialog = "Dialog",
    Music = "Music",
    Ambience = "Ambience"
}

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

local function buildCoiledAltarKickerBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    mod:EnsureDefaults()
    local tracker = T:MakeTracker()
    local track = tracker.track
    local needsRebuild = false

    local function refreshLive(rebuild)
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
        if rebuild then
            needsRebuild = true
            if E.OptionsUI and E.OptionsUI.QueueRefresh then
                E.OptionsUI:QueueRefresh("current")
            end
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

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_CAKPreview"],
        get = function()
            return mod.previewMode and true or false
        end,
        onChange = function(_, value)
            mod:SetPreviewMode(value)
            tracker.refresh()
        end,
        disabled = isDisabled
    })))

    y = section(y, L["BossMods_CAKAppearance"])

    local size = track(T:Slider(rightPanel, {
        label = L["BossMods_CAKSquareSize"],
        min = 48,
        max = 180,
        step = 1,
        value = mod.db.squareSize,
        get = function()
            return mod.db.squareSize
        end,
        onChange = function(value)
            mod.db.squareSize = math.floor(value + 0.5)
            refreshLive(false)
        end,
        disabled = isDisabled
    }))

    local opacity = track(T:Slider(rightPanel, {
        label = L["BossMods_CAKOpacity"],
        min = 0.1,
        max = 1,
        step = 0.05,
        value = mod.db.opacity,
        get = function()
            return mod.db.opacity
        end,
        onChange = function(value)
            mod.db.opacity = value
            refreshLive(false)
        end,
        disabled = isDisabled
    }))
    y = row(y, {size, opacity})

    local iconOffsetX = track(T:Slider(rightPanel, {
        label = L["BossMods_CAKIconOffsetX"] or "Icon X offset",
        min = -300,
        max = 300,
        step = 1,
        value = mod.db.iconOffsetX,
        get = function()
            return mod.db.iconOffsetX
        end,
        onChange = function(value)
            mod.db.iconOffsetX = math.floor(value + 0.5)
            refreshLive(false)
        end,
        disabled = isDisabled
    }))

    local iconOffsetY = track(T:Slider(rightPanel, {
        label = L["BossMods_CAKIconOffsetY"] or "Icon Y offset",
        min = -300,
        max = 300,
        step = 1,
        value = mod.db.iconOffsetY,
        get = function()
            return mod.db.iconOffsetY
        end,
        onChange = function(value)
            mod.db.iconOffsetY = math.floor(value + 0.5)
            refreshLive(false)
        end,
        disabled = isDisabled
    }))
    y = row(y, {iconOffsetX, iconOffsetY})

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_CAKShowList"],
        get = function()
            return mod.db.showList
        end,
        onChange = function(_, value)
            mod.db.showList = value and true or false
            refreshLive(false)
        end,
        disabled = isDisabled
    })))

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frame,
        label = L["BossMods_CAKListPosition"],
        headerText = L["BossMods_CAKListPosition"],
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.position.point,
                x = mod.db.position.x,
                y = mod.db.position.y
            }
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        defaultPosition = {point = "CENTER", x = 260, y = 80},
        onChanged = function()
            refreshLive(false)
        end,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = positionY

    y = section(y, L["BossMods_CAKNextKickText"] or "Your kick next text")

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_CAKEnableNextKickText"]
            or "Enable Your kick next text",
        get = function()
            return mod.db.nextKickText.enabled
        end,
        onChange = function(_, value)
            mod.db.nextKickText.enabled = value and true or false
            refreshLive(true)
        end,
        disabled = isDisabled
    })))

    if mod.db.nextKickText.enabled then
        local textFont = dropdown({
            label = L["Font"] or "Font",
            values = function()
                return E:MediaList("font")
            end,
            get = function()
                return mod.db.nextKickText.font.name
            end,
            set = function(value)
                mod.db.nextKickText.font.name = value
            end
        })

        local textOutline = dropdown({
            label = L["Outline"] or "Outline",
            values = OUTLINE_VALUES,
            sorting = OUTLINE_SORTING,
            get = function()
                return mod.db.nextKickText.font.outline
            end,
            set = function(value)
                mod.db.nextKickText.font.outline = value or ""
            end
        })
        y = row(y, {textFont, textOutline})

        local textSize = track(T:Slider(rightPanel, {
            label = (L["Font"] or "Font") .. " " .. (L["Size"] or "Size"),
            min = 12,
            max = 72,
            step = 1,
            value = mod.db.nextKickText.font.size,
            get = function()
                return mod.db.nextKickText.font.size
            end,
            onChange = function(value)
                mod.db.nextKickText.font.size = math.floor(value + 0.5)
                refreshLive(false)
            end,
            disabled = isDisabled
        }))
        y = row(y, {textSize})

        local textOffsetX = track(T:Slider(rightPanel, {
            label = L["BossMods_CAKTextOffsetX"] or "Text X position",
            min = -1000,
            max = 1000,
            step = 1,
            value = mod.db.nextKickText.position.x,
            get = function()
                return mod.db.nextKickText.position.x
            end,
            onChange = function(value)
                mod.db.nextKickText.position.x = math.floor(value + 0.5)
                refreshLive(false)
            end,
            disabled = isDisabled
        }))

        local textOffsetY = track(T:Slider(rightPanel, {
            label = L["BossMods_CAKTextOffsetY"] or "Text Y position",
            min = -1000,
            max = 1000,
            step = 1,
            value = mod.db.nextKickText.position.y,
            get = function()
                return mod.db.nextKickText.position.y
            end,
            onChange = function(value)
                mod.db.nextKickText.position.y = math.floor(value + 0.5)
                refreshLive(false)
            end,
            disabled = isDisabled
        }))
        y = row(y, {textOffsetX, textOffsetY})
    end

    y = section(y, L["BossMods_CAKAudio"])

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_CAKEnableAudio"],
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
            sorting = {"sound", "tts"},
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
                sorting = {"Master", "SFX", "Dialog", "Music", "Ambience"},
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
                label = L["BossMods_AAOptions_TextToSpeechMessage"] or "Text to Speech message",
                default = mod.db.audio.ttsText,
                get = function()
                    return mod.db.audio.ttsText
                end,
                commitOn = "enter",
                onCommit = function(value)
                    mod.db.audio.ttsText = strtrim(value or "") ~= "" and value or "Your kick"
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
                        text = mod.db.audio.ttsText or "Your kick",
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
        Refresh = function()
            tracker.refresh()
            if needsRebuild then
                needsRebuild = false
                return true
            end
        end,
        Release = function()
            mod:SetPreviewMode(false)
            mod:SetEditMode(false)
            positionHandle.Release()
            unlockController:Release()
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
