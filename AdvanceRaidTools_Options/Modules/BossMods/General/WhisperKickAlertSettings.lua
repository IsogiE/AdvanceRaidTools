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

local OUTLINE_SORTING = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}

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

local SOUND_CHANNEL_SORTING = {"Master", "SFX", "Dialog", "Music", "Ambience"}

local function buildBody(parent, mod, isDisabled)
    local widthPx = parent:GetWidth() or 0
    if widthPx <= 0 then
        return {height = 1}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local needsRebuild = false
    local setup = mod:GetSelectedSetup()

    local function unavailable()
        return isDisabled() or not setup
    end

    local function refresh(rebuild)
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
        if rebuild then
            needsRebuild = true
            if E.OptionsUI and E.OptionsUI.QueueRefresh then
                E.OptionsUI:QueueRefresh("current")
            end
        end
    end

    local function row(y, widgets)
        return y + T:PlaceRow(parent, widgets, y, widthPx) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(parent, widget, y, widthPx) + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(parent, {text = text}))
        return y + T:PlaceFull(parent, header, y, widthPx) + HEADER_GAP
    end

    local function button(opts)
        return track(T:Button(parent, {
            text = opts.text,
            tooltip = opts.tooltip,
            onClick = opts.onClick,
            confirm = opts.confirm,
            confirmTitle = opts.confirmTitle,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function checkbox(opts)
        local control = track(T:Checkbox(parent, {
            text = opts.text,
            labelTop = opts.labelTop,
            checked = opts.get(),
            get = opts.get,
            onChange = function(_, value)
                opts.set(value)
                refresh(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
        control.Refresh()
        return control
    end

    local function dropdown(opts)
        return track(T:Dropdown(parent, {
            label = opts.label,
            values = opts.values,
            sorting = opts.sorting,
            placeholder = opts.placeholder,
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                if opts.playSample then
                    opts.playSample(value)
                end
                refresh(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function editbox(opts)
        return track(T:EditBox(parent, {
            label = opts.label,
            get = opts.get,
            default = opts.get(),
            numeric = opts.numeric,
            commitOn = "enter",
            onCommit = function(value)
                opts.set(value)
                refresh(opts.rebuild)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function stepper(opts)
        return track(T:NumericStepper(parent, {
            label = opts.label,
            get = opts.get,
            set = function(value)
                opts.set(value)
                refresh(false)
            end,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            decimals = opts.decimals,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function slider(opts)
        return track(T:Slider(parent, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refresh(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local value = opts.get()
        return track(T:ColorSwatch(parent, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = value[1] or 1,
            g = value[2] or 1,
            b = value[3] or 1,
            a = value[4] or 1,
            onChange = function(r, g, b, a)
                opts.set({r, g, b, a})
                refresh(false)
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(parent, {text = "Kick Alert"})))
    y = full(y, track(T:Description(parent, {
        text = "Each enabled setup opens its own listening window relative to its selected BigWigs timer. Any normal whisper received during that window activates the setup. Whisper contents and sender are not read.",
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(parent, y, widthPx, {
        tracker = tracker,
        isDisabled = unavailable,
        onEditModeChanged = function(value) mod:SetEditMode(value) end
    })
    y = unlockY

    y = section(y, "Saved Setups")
    local setupValues = {}
    for index, item in ipairs(mod:GetSetups()) do
        setupValues[index] = item.name
    end

    y = full(y, dropdown({
        label = "Selected setup",
        values = setupValues,
        placeholder = "None",
        get = function() return mod.db.selectedSetup end,
        set = function(value)
            mod.db.selectedSetup = tonumber(value)
            mod:SetEditMode(false)
        end,
        rebuild = true,
        disabled = function() return isDisabled() or #mod:GetSetups() == 0 end
    }))

    y = row(y, {
        button({
            text = "Add",
            onClick = function() mod:AddSetup(); refresh(true) end
        }),
        button({
            text = "Duplicate",
            onClick = function() mod:DuplicateSetup(); refresh(true) end,
            disabled = unavailable
        }),
        button({
            text = "Delete",
            confirmTitle = "Delete Kick Alert Setup",
            confirm = function()
                return setup and ("Delete '%s'?"):format(setup.name)
            end,
            onClick = function() mod:DeleteSetup(); refresh(true) end,
            disabled = unavailable
        })
    })

    y = row(y, {
        button({
            text = "Import",
            onClick = function()
                E:PromptMultiline({
                    key = "ART_KICK_ALERT_IMPORT",
                    title = "Import Kick Alert Setup",
                    parent = parent,
                    input = {multiline = 8, default = "", maxLetters = 200000},
                    onAccept = function(text)
                        local index, err = mod:ImportSetupString(text or "")
                        if index then
                            E:Printf("Imported Kick Alert setup")
                            refresh(true)
                        elseif err then
                            E:Printf("|cffff4040%s|r", err)
                        end
                    end
                })
            end
        }),
        button({
            text = "Export",
            onClick = function()
                E:ShowText({
                    key = "ART_KICK_ALERT_EXPORT",
                    title = "Export Kick Alert Setup",
                    parent = parent,
                    viewer = {text = mod:ExportSetupString(), lines = 10}
                })
            end,
            disabled = unavailable
        }),
        button({
            text = "Share in Chat",
            onClick = function()
                local ok, err = mod:ShareSetupToChat()
                if not ok and err then E:Printf("|cffff4040%s|r", err) end
            end,
            disabled = unavailable
        })
    })

    if setup then
        y = section(y, "Setup")
        y = row(y, {
            checkbox({
                text = "Enable setup",
                labelTop = true,
                get = function() return setup.enabled end,
                set = function(value) setup.enabled = value end,
                disabled = unavailable
            }),
            editbox({
                label = "Setup name",
                get = function() return setup.name end,
                set = function(value)
                    value = strtrim(value or "")
                    setup.name = value ~= "" and value or "Kick Alert"
                end,
                rebuild = true,
                disabled = unavailable
            })
        })

        y = section(y, "BigWigs Trigger")
        y = row(y, {
            dropdown({
                label = "Boss",
                values = function() return mod:GetEncounterValues() end,
                sorting = function() return mod:GetEncounterSorting() end,
                get = function() return setup.trigger.encounterID end,
                set = function(value) setup.trigger.encounterID = tonumber(value) or 3421 end,
                disabled = unavailable
            }),
            dropdown({
                label = "Difficulty",
                values = function() return mod:GetDifficultyValues() end,
                sorting = function() return mod:GetDifficultySorting() end,
                get = function() return setup.trigger.difficulty end,
                set = function(value) setup.trigger.difficulty = value end,
                disabled = unavailable
            })
        })

        y = full(y, editbox({
            label = "BigWigs spell ID",
            numeric = true,
            get = function() return tostring(setup.trigger.spellID or 0) end,
            set = function(value)
                setup.trigger.spellID = math.max(0, math.floor(tonumber(value) or 0))
            end,
            disabled = unavailable
        }))

        y = row(y, {
            stepper({
                label = "Open window seconds before timer 0",
                min = 0, max = 60, step = 0.1, decimals = 1,
                get = function() return setup.trigger.secondsBefore end,
                set = function(value) setup.trigger.secondsBefore = value end,
                disabled = unavailable
            }),
            stepper({
                label = "Listening window duration",
                min = 0.1, max = 60, step = 0.1, decimals = 1,
                get = function() return setup.trigger.windowDuration end,
                set = function(value) setup.trigger.windowDuration = value end,
                disabled = unavailable
            })
        })

        local ending = setup.trigger.windowDuration - setup.trigger.secondsBefore
        local endingText
        if math.abs(ending) < 0.05 then
            endingText = "The listening window closes when the BigWigs timer reaches 0."
        elseif ending > 0 then
            endingText = ("The listening window closes %.1f seconds after timer 0."):format(ending)
        else
            endingText = ("The listening window closes %.1f seconds before timer 0."):format(-ending)
        end
        y = full(y, track(T:Description(parent, {text = endingText, sizeDelta = 0})))

        y = section(y, "Alert")
        y = row(y, {
            slider({
                label = "Alert display duration",
                min = 1, max = 5, step = 1,
                get = function() return setup.duration end,
                set = function(value) setup.duration = math.floor(value + 0.5) end,
                disabled = unavailable
            }),
            button({
                text = "Test Alert",
                tooltip = "Shows this setup without requiring a whisper.",
                onClick = function() mod:ShowTriggeredAlert(false) end,
                disabled = unavailable
            })
        })

        y = section(y, "Text Appearance")
        y = row(y, {
            dropdown({
                label = "Font",
                values = function() return E:MediaList("font") end,
                get = function() return setup.font.name end,
                set = function(value) setup.font.name = value end,
                disabled = unavailable
            }),
            dropdown({
                label = "Outline",
                values = OUTLINE_VALUES,
                sorting = OUTLINE_SORTING,
                get = function() return setup.font.outline end,
                set = function(value) setup.font.outline = value end,
                disabled = unavailable
            })
        })

        y = row(y, {
            slider({
                label = "Font size",
                min = 8, max = 72, step = 1,
                get = function() return setup.font.size end,
                set = function(value) setup.font.size = math.floor(value + 0.5) end,
                disabled = unavailable
            }),
            color({
                label = "Font color",
                get = function() return setup.font.color end,
                set = function(value) setup.font.color = value end,
                disabled = unavailable
            })
        })

        y = section(y, "Audio")
        y = full(y, checkbox({
            text = "Enable audio",
            labelTop = true,
            get = function() return setup.audio.enabled end,
            set = function(value) setup.audio.enabled = value end,
            rebuild = true,
            disabled = unavailable
        }))

        if setup.audio.enabled then
            y = full(y, dropdown({
                label = "Audio type",
                values = AUDIO_MODE_VALUES,
                sorting = AUDIO_MODE_SORTING,
                get = function() return setup.audio.mode end,
                set = function(value) setup.audio.mode = value end,
                rebuild = true,
                disabled = unavailable
            }))

            if setup.audio.mode == "sound" then
                y = row(y, {
                    dropdown({
                        label = "Sound file",
                        values = function() return E:GetModule("BossMods").Alerts:GetSoundOptions() end,
                        get = function() return setup.audio.sound end,
                        set = function(value) setup.audio.sound = value end,
                        playSample = function(value)
                            E:GetModule("BossMods").Alerts:PlaySound({
                                name = value,
                                channel = setup.audio.channel
                            })
                        end,
                        disabled = unavailable
                    }),
                    dropdown({
                        label = "Sound channel",
                        values = SOUND_CHANNEL_VALUES,
                        sorting = SOUND_CHANNEL_SORTING,
                        get = function() return setup.audio.channel end,
                        set = function(value) setup.audio.channel = value end,
                        disabled = unavailable
                    })
                })
            else
                y = row(y, {
                    editbox({
                        label = "Text to Speech message",
                        get = function() return setup.audio.ttsText end,
                        set = function(value)
                            value = strtrim(value or "")
                            setup.audio.ttsText = value ~= "" and value or "Your kick next"
                        end,
                        disabled = unavailable
                    }),
                    dropdown({
                        label = "TTS voice",
                        values = function() return E:GetModule("BossMods").Alerts:GetTTSVoices() end,
                        get = function() return setup.audio.voiceID end,
                        set = function(value)
                            setup.audio.voiceID = tonumber(value) or 0
                            E:GetModule("BossMods").Alerts:SpeakTTS({
                                text = setup.audio.ttsText,
                                voiceID = setup.audio.voiceID
                            })
                        end,
                        disabled = unavailable
                    })
                })
            end
        end

        local frame = mod:GetSelectedFrame()
        local nextY, positionHandle = T:PositionSection(parent, y, widthPx, {
            anchor = frame,
            label = setup.name,
            headerText = "Kick Alert Position",
            tracker = tracker,
            getPosition = function() return setup.position end,
            setPosition = function(position) mod:SavePosition(position) end,
            defaultPosition = {point = "CENTER", x = 0, y = 200},
            onChanged = function() refresh(false) end,
            isDisabled = unavailable,
            unlockController = unlockCtrl,
            showOffsets = true
        })
        y = nextY

        local totalHeight = math.max(y + 10, 1)
        parent:SetHeight(totalHeight)
        return {
            height = totalHeight,
            Refresh = function()
                tracker.refresh()
                if needsRebuild then needsRebuild = false; return true end
            end,
            Release = function()
                positionHandle.Release()
                unlockCtrl:Release()
                tracker.release()
            end
        }
    end

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = function()
            tracker.refresh()
            if needsRebuild then needsRebuild = false; return true end
        end,
        Release = function()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("WhisperKickAlert", buildBody)
end
