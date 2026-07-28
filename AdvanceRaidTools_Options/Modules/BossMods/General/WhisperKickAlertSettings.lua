local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local OUTLINE_VALUES = {
    [""] = L["None"] or "None",
    OUTLINE = L["Outline"] or "Outline",
    THICKOUTLINE = L["ThickOutline"] or "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
}

local AUDIO_MODE_VALUES = {
    tts = "Text to Speech",
    sound = "Sound file"
}

local AUDIO_MODE_SORTING = {"tts", "sound"}

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

local function buildWhisperKickAlertBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    mod:EnsureDefaults()
    mod:EnsureAlert()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local refreshPanel = tracker.refresh
    local needsRebuild = false

    local function refreshLive(rebuild)
        mod:CallIfEnabled("Refresh")
        refreshPanel()
        if rebuild then
            needsRebuild = true
            if E.OptionsUI and E.OptionsUI.QueueRefresh then
                E.OptionsUI:QueueRefresh("current")
            end
        end
    end

    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            labelTop = opts.labelTop,
            get = opts.get,
            onChange = function(_, value)
                opts.set(value)
                refreshLive(opts.rebuild)
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
                refreshLive(opts.rebuild)
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
            decimals = opts.decimals,
            min = opts.min,
            max = opts.max,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function editbox(opts)
        return track(T:EditBox(rightPanel, {
            label = opts.label,
            default = opts.get(),
            get = opts.get,
            numeric = opts.numeric,
            commitOn = "enter",
            onCommit = function(value)
                opts.set(value)
                refreshLive(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local c = opts.get()
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = c[1] or 1,
            g = c[2] or 1,
            b = c[3] or 1,
            a = c[4] or 1,
            onChange = function(r, g, b, a)
                opts.set({r, g, b, a})
                refreshLive(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function button(opts)
        return track(T:Button(rightPanel, {
            text = opts.text,
            tooltip = opts.tooltip,
            onClick = opts.onClick,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, widthPx) + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(rightPanel, {
            text = text
        }))
        return y + T:PlaceFull(rightPanel, header, y, widthPx)
            + HEADER_GAP
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = "Kick Alert"
    })))
    y = full(y, track(T:Description(rightPanel, {
        text =
            "Opens a listening window relative to a selected BigWigs timer. "
            .. "Any incoming normal whisper received while that window is open "
            .. "shows \"Your kick Next\". Whisper contents and sender are not read.",
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(
        rightPanel,
        y,
        widthPx,
        {
            tracker = tracker,
            isDisabled = isDisabled,
            onEditModeChanged = function(value)
                mod:SetEditMode(value)
            end
        }
    )
    y = unlockY

    y = section(y, "BigWigs trigger")
    y = row(y, {
        dropdown({
            label = "Boss",
            values = function()
                return mod:GetEncounterValues()
            end,
            sorting = function()
                return mod:GetEncounterSorting()
            end,
            get = function()
                return mod.db.trigger.encounterID
            end,
            set = function(value)
                mod.db.trigger.encounterID = tonumber(value) or 3421
            end
        }),
        editbox({
            label = "BigWigs spell ID",
            numeric = true,
            get = function()
                return tostring(mod.db.trigger.spellID or 0)
            end,
            set = function(value)
                mod.db.trigger.spellID = math.max(
                    0,
                    math.floor(tonumber(value) or 0)
                )
            end
        })
    })

    y = row(y, {
        stepper({
            label = "Open window seconds before timer 0",
            min = 0,
            max = 60,
            step = 0.1,
            decimals = 1,
            get = function()
                return mod.db.trigger.secondsBefore or 2
            end,
            set = function(value)
                mod.db.trigger.secondsBefore =
                    math.max(0, math.min(60, tonumber(value) or 2))
            end
        }),
        stepper({
            label = "Listening window duration",
            min = 0.1,
            max = 60,
            step = 0.1,
            decimals = 1,
            get = function()
                return mod.db.trigger.windowDuration or 17
            end,
            set = function(value)
                mod.db.trigger.windowDuration =
                    math.max(0.1, math.min(60, tonumber(value) or 17))
            end
        })
    })

    local secondsBefore =
        tonumber(mod.db.trigger.secondsBefore) or 2
    local windowDuration =
        tonumber(mod.db.trigger.windowDuration) or 17
    local endRelativeToZero = windowDuration - secondsBefore
    local closingText

    if math.abs(endRelativeToZero) < 0.05 then
        closingText = "The listening window closes when the BigWigs timer reaches 0."
    elseif endRelativeToZero > 0 then
        closingText = ("The listening window closes %.1f seconds after the BigWigs timer reaches 0."):format(
            endRelativeToZero
        )
    else
        closingText = ("The listening window closes %.1f seconds before the BigWigs timer reaches 0."):format(
            -endRelativeToZero
        )
    end

    y = full(y, track(T:Description(rightPanel, {
        text = closingText,
        sizeDelta = 0
    })))

    y = section(y, "Alert")
    y = row(y, {
        slider({
            label = "Alert display duration",
            min = 1,
            max = 5,
            step = 1,
            get = function()
                return mod.db.duration or 3
            end,
            set = function(value)
                mod.db.duration =
                    math.max(1, math.min(5, math.floor(value + 0.5)))
            end
        }),
        button({
            text = "Test alert",
            tooltip = "Shows the configured text alert without requiring a whisper.",
            onClick = function()
                mod:ShowTriggeredAlert(false)
            end
        })
    })

    y = section(y, "Text appearance")
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
            get = function()
                return mod.db.font.outline
            end,
            set = function(value)
                mod.db.font.outline = value
            end
        })
    })

    y = row(y, {
        slider({
            label = (L["Font"] or "Font")
                .. " "
                .. (L["Size"] or "Size"),
            min = 8,
            max = 72,
            step = 1,
            get = function()
                return mod.db.font.size or 34
            end,
            set = function(value)
                mod.db.font.size = math.floor(value + 0.5)
            end
        }),
        color({
            label = (L["Font"] or "Font")
                .. " "
                .. (L["Color"] or "Color"),
            get = function()
                return mod.db.font.color
            end,
            set = function(value)
                mod.db.font.color = value
            end
        })
    })

    y = section(y, "Audio")
    y = row(y, {
        checkbox({
            text = "Enable audio",
            labelTop = true,
            get = function()
                return mod.db.audio.enabled
            end,
            set = function(value)
                mod.db.audio.enabled = value and true or false
            end,
            rebuild = true
        })
    })

    if mod.db.audio.enabled then
        y = row(y, {
            dropdown({
                label = "Audio type",
                values = AUDIO_MODE_VALUES,
                sorting = AUDIO_MODE_SORTING,
                get = function()
                    return mod.db.audio.mode
                end,
                set = function(value)
                    mod.db.audio.mode = value
                end,
                rebuild = true
            })
        })

        if mod.db.audio.mode == "sound" then
            y = row(y, {
                dropdown({
                    label = "Sound file",
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
                }),
                dropdown({
                    label = "Sound channel",
                    values = SOUND_CHANNEL_VALUES,
                    sorting = SOUND_CHANNEL_SORTING,
                    get = function()
                        return mod.db.audio.channel
                    end,
                    set = function(value)
                        mod.db.audio.channel = value
                    end
                })
            })
        else
            y = row(y, {
                editbox({
                    label = "Text to Speech message",
                    get = function()
                        return mod.db.audio.ttsText or "Your kick next"
                    end,
                    set = function(value)
                        mod.db.audio.ttsText =
                            strtrim(value or "") ~= ""
                            and value
                            or "Your kick next"
                    end
                }),
                dropdown({
                    label = "TTS voice",
                    values = function()
                        return E:GetModule("BossMods").Alerts:GetTTSVoices()
                    end,
                    get = function()
                        return mod.db.audio.voiceID or 0
                    end,
                    set = function(value)
                        mod.db.audio.voiceID = tonumber(value) or 0
                        E:GetModule("BossMods").Alerts:SpeakTTS({
                            text = mod.db.audio.ttsText
                                or "Your kick next",
                            voiceID = mod.db.audio.voiceID
                        })
                    end
                })
            })
        end
    end

    local posNewY, posHandle = T:PositionSection(
        rightPanel,
        y,
        widthPx,
        {
            anchor = mod.frame,
            label = "Kick Alert",
            headerText = "Kick Alert Position",
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
            defaultPosition = {
                point = "CENTER",
                x = 0,
                y = 200
            },
            onChanged = function()
                refreshLive(false)
            end,
            isDisabled = isDisabled,
            unlockController = unlockCtrl,
            showOffsets = true
        }
    )
    y = posNewY

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
            posHandle.Release()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder(
            "WhisperKickAlert",
            buildWhisperKickAlertBody
        )
    end
end
