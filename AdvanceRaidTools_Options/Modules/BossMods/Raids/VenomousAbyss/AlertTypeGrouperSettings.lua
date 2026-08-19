local E = unpack(ART)
local T = E.Templates

local BossMods = E:GetModule("BossMods", true)
if not BossMods then
    return
end

local FEATURE_KEY = "VenomousAbyssAlertTypeGrouper"
local MODULE_NAME = "BossMods_VenomousAbyssAbilityAlerts"
local ROW_GAP = 6
local HEADER_GAP = 10

local AUDIO_MODE_VALUES = {
    tts = "Text to Speech",
    sound = "Sound file"
}

local AUDIO_MODE_SORTING = {"tts", "sound"}

local SOUND_CHANNEL_VALUES = {
    Master = "Master",
    SFX = "Sound Effects",
    Ambience = "Ambience",
    Dialog = "Dialog"
}

local SOUND_CHANNEL_SORTING = {"Master", "SFX", "Ambience", "Dialog"}

local GROWTH_VALUES = {
    DOWN = "Down",
    UP = "Up"
}

local GROWTH_SORTING = {"DOWN", "UP"}

local function buildBody(parent, abilityMod, isDisabled)
    local widthPx = parent:GetWidth() or 0
    if widthPx <= 0 then
        return {height = 1}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local currentBody
    local released = false
    local proxy = {height = 1}
    local selectedGroupID

    local function orderedGroups()
        local result = {}

        for _, group in pairs(abilityMod:GetAlertTypeGroups()) do
            result[#result + 1] = group
        end

        table.sort(result, function(a, b)
            return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
        end)

        return result
    end

    local function getSelectedGroup()
        local groups = abilityMod:GetAlertTypeGroups()
        local group = selectedGroupID and groups[selectedGroupID]

        if group then
            return group
        end

        local ordered = orderedGroups()
        group = ordered[1]
        selectedGroupID = group and group.id or nil
        return group
    end

    local function refreshScrollRange()
        if released then
            return
        end

        local content = parent:GetParent()

        if content then
            content:SetHeight(proxy.height)
        end

        local scroll = content and content:GetParent()
        if scroll and scroll.UpdateScrollChildRect then
            scroll:UpdateScrollChildRect()
        end
    end

    local rebuild

    local function applyGroup(group)
        if group then
            abilityMod:ApplyAlertTypeGroup(group.id)
        end
    end

    local function buildCurrentBody()
        local controls = T:MakeTracker()
        local keep = controls.track

        local function row(y, widgets)
            return y + T:PlaceRow(parent, widgets, y, widthPx) + ROW_GAP
        end

        local function full(y, widget)
            return y + T:PlaceFull(parent, widget, y, widthPx) + ROW_GAP
        end

        local function section(y, text)
            local header = keep(T:Header(parent, {text = text}))
            return y + T:PlaceFull(parent, header, y, widthPx) + HEADER_GAP
        end

        local function disabled(extra)
            return isDisabled() or (extra and extra())
        end

        local function checkbox(opts)
            local control = keep(T:Checkbox(parent, {
                text = opts.text,
                labelTop = opts.labelTop,
                checked = type(opts.get) == "function" and opts.get() or false,
                get = opts.get,
                onChange = function(_, value)
                    opts.onChange(value)
                end,
                disabled = function()
                    return disabled(opts.disabled)
                end
            }))

            if control.Refresh then
                control.Refresh()
            end

            return control
        end

        local function dropdown(opts)
            return keep(T:Dropdown(parent, {
                label = opts.label,
                values = opts.values,
                sorting = opts.sorting,
                get = opts.get,
                onChange = opts.onChange,
                playSample = opts.playSample,
                disabled = function()
                    return disabled(opts.disabled)
                end
            }))
        end

        local function editBox(opts)
            return keep(T:EditBox(parent, {
                label = opts.label,
                get = opts.get,
                onCommit = opts.onCommit,
                disabled = function()
                    return disabled(opts.disabled)
                end
            }))
        end

        local function numberInput(opts)
            return keep(T:NumericStepper(parent, {
                label = opts.label,
                get = opts.get,
                set = opts.set,
                min = opts.min,
                max = opts.max,
                step = opts.step or 1,
                disabled = function()
                    return disabled(opts.disabled)
                end
            }))
        end

        local function button(text, onClick, extraDisabled)
            return keep(T:Button(parent, {
                text = text,
                onClick = onClick,
                disabled = function()
                    return disabled(extraDisabled)
                end
            }))
        end

        local y = 0
        y = full(y, keep(T:Header(parent, {text = "Alert Type Grouper"})))
        y = full(y, keep(T:Description(parent, {
            text = "Create saved groups of Venomous Abyss alerts and give every selected alert the same bar color and audio settings. An alert can belong to one group at a time. Removing it from a group does not reset settings already applied.",
            sizeDelta = 0
        })))

        local groupValues = {}
        local groupSorting = {}

        for _, group in ipairs(orderedGroups()) do
            groupValues[group.id] = group.name
            groupSorting[#groupSorting + 1] = group.id
        end

        local groupPicker = dropdown({
            label = "Saved group",
            values = groupValues,
            sorting = groupSorting,
            get = function()
                local group = getSelectedGroup()
                return group and group.id
            end,
            onChange = function(value)
                selectedGroupID = tonumber(value) or value
                rebuild()
            end
        })

        local newGroup = button("New Group", function()
            local group = abilityMod:CreateAlertTypeGroup()
            selectedGroupID = group.id
            rebuild()
        end)

        y = row(y, {groupPicker, newGroup})

        local group = getSelectedGroup()
        if not group then
            y = full(y, keep(T:Description(parent, {
                text = "Create a group to begin selecting abilities.",
                sizeDelta = 0
            })))
        else
            local groupName = editBox({
                label = "Group name",
                get = function() return group.name end,
                onCommit = function(value)
                    value = tostring(value or ""):match("^%s*(.-)%s*$")
                    group.name = value ~= "" and value or ("Alert Group " .. group.id)
                    rebuild()
                    return group.name
                end
            })

            local deleteGroup = button("Delete Group", function()
                abilityMod:DeleteAlertTypeGroup(group.id)
                selectedGroupID = nil
                rebuild()
            end)

            y = row(y, {groupName, deleteGroup})

            y = section(y, "Shared Bar Settings")

            local color = group.fillColor or {0.20, 0.60, 1.00, 1.00}
            y = full(y, keep(T:ColorSwatch(parent, {
                label = "Bar color",
                labelTop = true,
                hasAlpha = true,
                r = color[1] or 0.20,
                g = color[2] or 0.60,
                b = color[3] or 1.00,
                a = color[4] or 1.00,
                onChange = function(r, g, b, a)
                    group.fillColor = {r, g, b, a}
                    applyGroup(group)
                end,
                disabled = isDisabled
            })))

            local unattach = checkbox({
                text = "Unattach from bar group anchor",
                labelTop = true,
                get = function() return group.unattached == true end,
                onChange = function(value)
                    group.unattached = value
                    abilityMod:ApplyPositions()
                    rebuild()
                end
            })
            y = full(y, unattach)

            if group.unattached then
                y = T:XYOffsetControls(parent, y, widthPx, {
                    tracker = controls,
                    getPosition = function()
                        return group.position
                    end,
                    setPosition = function(position)
                        group.position = position
                    end,
                    onChanged = function()
                        abilityMod:ApplyPositions()
                    end,
                    disabled = isDisabled,
                    anchorLabel = "Anchor point on grouped bars"
                })

                local growth = dropdown({
                    label = "Growth direction",
                    values = GROWTH_VALUES,
                    sorting = GROWTH_SORTING,
                    get = function() return group.growth end,
                    onChange = function(value)
                        group.growth = value
                        abilityMod:ApplyPositions()
                    end
                })

                local spacing = numberInput({
                    label = "Bar spacing",
                    get = function() return group.spacing or 4 end,
                    set = function(value)
                        group.spacing = tonumber(value) or 4
                        abilityMod:ApplyPositions()
                    end,
                    min = 0,
                    max = 50,
                    step = 1
                })

                y = row(y, {growth, spacing})
            end

            y = section(y, "Shared Audio Settings")

            local audioEnabled = checkbox({
                text = "Enable Audio",
                labelTop = true,
                get = function() return group.audio.enabled == true end,
                onChange = function(value)
                    group.audio.enabled = value
                    applyGroup(group)
                    rebuild()
                end
            })
            y = full(y, audioEnabled)

            if group.audio.enabled then
                local secondsBefore = numberInput({
                    label = "Seconds before",
                    get = function() return group.audio.secondsBefore or 3 end,
                    set = function(value)
                        group.audio.secondsBefore = tonumber(value) or 3
                        applyGroup(group)
                    end,
                    min = 0,
                    max = 30,
                    step = 1
                })

                local delayBy = numberInput({
                    label = "Delay by",
                    get = function() return group.audio.delayBy or 0 end,
                    set = function(value)
                        group.audio.delayBy = tonumber(value) or 0
                        applyGroup(group)
                    end,
                    min = 0,
                    max = 30,
                    step = 1
                })
                y = row(y, {secondsBefore, delayBy})

                local audioMode = dropdown({
                    label = "Audio type",
                    values = AUDIO_MODE_VALUES,
                    sorting = AUDIO_MODE_SORTING,
                    get = function() return group.audio.mode end,
                    onChange = function(value)
                        group.audio.mode = value
                        applyGroup(group)
                        rebuild()
                    end
                })

                local countdown = checkbox({
                    text = "Countdown every second",
                    labelTop = true,
                    get = function() return group.audio.countdown == true end,
                    onChange = function(value)
                        group.audio.countdown = value
                        applyGroup(group)
                    end,
                    disabled = function() return group.audio.mode ~= "tts" end
                })
                y = row(y, {audioMode, countdown})

                if group.audio.mode == "tts" then
                    local message = editBox({
                        label = "Text to Speech message",
                        get = function() return group.audio.ttsText end,
                        onCommit = function(value)
                            group.audio.ttsText = value
                            applyGroup(group)
                            return value
                        end
                    })

                    local voice = dropdown({
                        label = "TTS voice",
                        values = function()
                            return E:GetModule("BossMods").Alerts:GetTTSVoices()
                        end,
                        get = function() return group.audio.voiceID or 0 end,
                        onChange = function(value)
                            group.audio.voiceID = tonumber(value) or 0
                            applyGroup(group)
                            E:GetModule("BossMods").Alerts:SpeakTTS({
                                text = "Voice test",
                                voiceID = group.audio.voiceID
                            })
                        end
                    })
                    y = row(y, {message, voice})
                else
                    local sound = dropdown({
                        label = "Sound file",
                        values = function()
                            return E:GetModule("BossMods").Alerts:GetSoundOptions()
                        end,
                        get = function() return group.audio.sound end,
                        onChange = function(value)
                            group.audio.sound = value
                            applyGroup(group)
                        end,
                        playSample = function(value)
                            E:GetModule("BossMods").Alerts:PlaySound({
                                name = value,
                                channel = group.audio.channel or "Master"
                            })
                        end
                    })

                    local channel = dropdown({
                        label = "Sound channel",
                        values = SOUND_CHANNEL_VALUES,
                        sorting = SOUND_CHANNEL_SORTING,
                        get = function() return group.audio.channel end,
                        onChange = function(value)
                            group.audio.channel = value
                            applyGroup(group)
                        end
                    })
                    y = row(y, {sound, channel})
                end

                local endEnabled = checkbox({
                    text = "Enable additional audio when bar reaches 0",
                    labelTop = true,
                    get = function() return group.barEndAudio.enabled == true end,
                    onChange = function(value)
                        group.barEndAudio.enabled = value
                        applyGroup(group)
                        rebuild()
                    end
                })
                y = full(y, endEnabled)

                if group.barEndAudio.enabled then
                    local endMode = dropdown({
                        label = "Audio type at 0",
                        values = AUDIO_MODE_VALUES,
                        sorting = AUDIO_MODE_SORTING,
                        get = function() return group.barEndAudio.mode end,
                        onChange = function(value)
                            group.barEndAudio.mode = value
                            applyGroup(group)
                            rebuild()
                        end
                    })
                    y = full(y, endMode)

                    if group.barEndAudio.mode == "tts" then
                        local message = editBox({
                            label = "Text to Speech message at 0",
                            get = function() return group.barEndAudio.ttsText end,
                            onCommit = function(value)
                                group.barEndAudio.ttsText = value
                                applyGroup(group)
                                return value
                            end
                        })

                        local voice = dropdown({
                            label = "TTS voice at 0",
                            values = function()
                                return E:GetModule("BossMods").Alerts:GetTTSVoices()
                            end,
                            get = function() return group.barEndAudio.voiceID or 0 end,
                            onChange = function(value)
                                group.barEndAudio.voiceID = tonumber(value) or 0
                                applyGroup(group)
                                E:GetModule("BossMods").Alerts:SpeakTTS({
                                    text = "Voice test",
                                    voiceID = group.barEndAudio.voiceID
                                })
                            end
                        })
                        y = row(y, {message, voice})
                    else
                        local sound = dropdown({
                            label = "Sound file at 0",
                            values = function()
                                return E:GetModule("BossMods").Alerts:GetSoundOptions()
                            end,
                            get = function() return group.barEndAudio.sound end,
                            onChange = function(value)
                                group.barEndAudio.sound = value
                                applyGroup(group)
                            end,
                            playSample = function(value)
                                E:GetModule("BossMods").Alerts:PlaySound({
                                    name = value,
                                    channel = group.barEndAudio.channel or "Master"
                                })
                            end
                        })

                        local channel = dropdown({
                            label = "Sound channel at 0",
                            values = SOUND_CHANNEL_VALUES,
                            sorting = SOUND_CHANNEL_SORTING,
                            get = function() return group.barEndAudio.channel end,
                            onChange = function(value)
                                group.barEndAudio.channel = value
                                applyGroup(group)
                            end
                        })
                        y = row(y, {sound, channel})
                    end
                end
            end

            y = section(y, "Abilities in This Group")

            for _, boss in ipairs(E.VenomousAbyssAbilityData or {}) do
                y = full(y, keep(T:Header(parent, {text = boss.bossName})))

                for _, ability in ipairs(boss.abilities or {}) do
                    local spellID = tonumber(ability.spellID)
                    local label = ability.name

                    local abilityCheckbox = checkbox({
                        text = label,
                        get = function()
                            return group.abilities[spellID] == true
                                or group.abilities[tostring(spellID)] == true
                        end,
                        onChange = function(value)
                            abilityMod:SetAlertTypeGroupAbility(group.id, spellID, value)
                        end
                    })
                    y = full(y, abilityCheckbox)
                end
            end

            y = full(y, button("Apply Group Settings", function()
                applyGroup(group)
            end))
        end

        local height = math.max(y + 10, 1)
        parent:SetHeight(height)

        return {
            height = height,
            Refresh = controls.refresh,
            Release = controls.release
        }
    end

    rebuild = function()
        if released then
            return
        end

        if currentBody and currentBody.Release then
            currentBody.Release()
        end

        currentBody = buildCurrentBody()
        proxy.height = currentBody.height or 1
        parent:SetHeight(proxy.height)
        refreshScrollRange()
        C_Timer.After(0, refreshScrollRange)
    end

    rebuild()

    proxy.Refresh = function()
        if currentBody and currentBody.Refresh then
            currentBody.Refresh()
        end
    end

    proxy.Release = function()
        released = true
        if currentBody and currentBody.Release then
            currentBody.Release()
        end
        currentBody = nil
        tracker.release()
    end

    return proxy
end

BossMods.settingsBuilders[FEATURE_KEY] = function(parent, _, isDisabled)
    local abilityMod = E:GetModule(MODULE_NAME, true)
    if not abilityMod then
        return {height = 1}
    end

    return buildBody(parent, abilityMod, isDisabled)
end
