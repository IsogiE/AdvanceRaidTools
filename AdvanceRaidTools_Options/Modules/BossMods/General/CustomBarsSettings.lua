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
local AUDIO_MODE_VALUES = {tts="Text to Speech", sound="Sound file"}
local AUDIO_MODE_SORTING = {"tts", "sound"}
local SOUND_CHANNEL_VALUES = {
    Master="Master", SFX="Sound Effects", Dialog="Dialog", Music="Music", Ambience="Ambience"
}
local SOUND_CHANNEL_SORTING = {"Master", "SFX", "Dialog", "Music", "Ambience"}

local function clamp(value, low, high)
    return math.max(low, math.min(high, tonumber(value) or low))
end

local function selected(mod)
    return mod:GetSelectedBar()
end

local function barValues(mod)
    local values = {}
    for i, bar in ipairs(mod:GetBars()) do values[i] = bar.name end
    return values
end

local function abilityValues()
    local values, sorting = {}, {}
    local function addRaid(raidName, data)
        for _, boss in ipairs(type(data) == "table" and data or {}) do
            for _, ability in ipairs(boss.abilities or {}) do
                local id = tonumber(ability.spellID)
                if id and id > 0 and not values[id] then
                    values[id] = ("%s — %s — %s (%d)"):format(raidName, boss.bossName or boss.bossKey or "Boss", ability.name or "Ability", id)
                    sorting[#sorting + 1] = id
                end
            end
        end
    end
    addRaid("Voidspire", E.VoidspireAbilityData)
    addRaid("Venomous Abyss", E.VenomousAbyssAbilityData)
    table.sort(sorting, function(a, b) return values[a] < values[b] end)
    return values, sorting
end

local function markerTimes(bar)
    local out = {}
    for _, marker in ipairs(bar and bar.markers or {}) do out[#out + 1] = tostring(marker.time) end
    return table.concat(out, ", ")
end

local function markerTexts(bar)
    local out = {}
    for _, marker in ipairs(bar and bar.markers or {}) do out[#out + 1] = marker.text or "" end
    return table.concat(out, ", ")
end

local function markerDurations(bar)
    local out = {}
    for _, marker in ipairs(bar and bar.markers or {}) do out[#out + 1] = tostring(marker.duration or 0) end
    return table.concat(out, ", ")
end

local function splitCSV(text)
    local out = {}
    for part in (tostring(text or "") .. ","):gmatch("(.-),") do
        out[#out + 1] = strtrim(part)
        if #out >= 10 then break end
    end
    return out
end

local function setMarkerTimes(bar, text)
    local oldTexts = {}
    local oldDurations = {}
    for i, marker in ipairs(bar.markers or {}) do
        oldTexts[i] = marker.text or ""
        oldDurations[i] = marker.duration or 0
    end
    local markers = {}
    for _, part in ipairs(splitCSV(text)) do
        local value = tonumber(part)
        if value and value >= 0 and value <= bar.duration then
            markers[#markers + 1] = {
                time = value,
                duration = math.min(oldDurations[#markers + 1] or 0, math.max(0, bar.duration - value)),
                text = oldTexts[#markers + 1] or ""
            }
        end
    end
    table.sort(markers, function(a, b) return a.time < b.time end)
    bar.markers = markers
end

local function setMarkerTexts(bar, text)
    local parts = splitCSV(text)
    for i, marker in ipairs(bar.markers or {}) do marker.text = parts[i] or "" end
end


local function setMarkerDurations(bar, text)
    local parts = splitCSV(text)
    for i, marker in ipairs(bar.markers or {}) do
        marker.duration = clamp(parts[i], 0, math.max(0, bar.duration - marker.time))
    end
end

local function build(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then return {} end

    local tracker = T:MakeTracker()
    local track, refreshPanel = tracker.track, tracker.refresh
    local needsRebuild = false

    local function refresh(rebuild)
        mod:Changed(rebuild)
        refreshPanel()
    end

    local function refreshFull(rebuild)
        refresh(rebuild)
        if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
    end

    local function noBar()
        return isDisabled() or not selected(mod)
    end

    local function button(opts)
        return track(T:Button(rightPanel, {
            text = opts.text,
            tooltip = opts.tooltip,
            confirm = opts.confirm,
            confirmTitle = opts.confirmTitle,
            onClick = opts.onClick,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            labelTop = opts.labelTop,
            get = opts.get,
            onChange = function(_, value)
                opts.set(value)
                if opts.fullRefresh then
                    needsRebuild = true
                    refreshFull(opts.rebuild)
                else
                    refresh(opts.rebuild)
                end
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function dropdown(opts)
        return track(T:Dropdown(rightPanel, {
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
                if opts.fullRefresh then
                    needsRebuild = true
                    refreshFull(opts.rebuild)
                else
                    refresh(opts.rebuild)
                end
            end,
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
            onCommit = function(value) opts.set(value); refresh(opts.rebuild) end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function stepper(opts)
        return track(T:NumericStepper(rightPanel, {
            label = opts.label,
            get = opts.get,
            set = function(value) opts.set(value); refresh(opts.rebuild) end,
            step = opts.step or 1,
            decimals = opts.decimals,
            min = opts.min,
            max = opts.max,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local c = opts.get()
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = true,
            r = c[1], g = c[2], b = c[3], a = c[4] or 1,
            onChange = function(r, g, b, a) opts.set({r, g, b, a}); refresh(false) end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function row(y, widgets, opts)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx, opts) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, widthPx) + ROW_GAP
    end

    local function section(y, text)
        local h = track(T:Header(rightPanel, {text = text}))
        return y + T:PlaceFull(rightPanel, h, y, widthPx) + HEADER_GAP
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {text = "Custom Bars"})))
    y = full(y, track(T:Description(rightPanel, {
        text = "Create bars triggered by a BigWigs timer. Negative start offsets begin before timer zero; positive offsets begin after timer zero.",
        sizeDelta = 1
    })))

    y = section(y, "Custom bars")
    y = row(y, {dropdown({
        label = "Selected bar",
        values = function() return barValues(mod) end,
        placeholder = L["None"] or "None",
        get = function() return mod.db.selectedBar end,
        set = function(value) mod.db.selectedBar = value end,
        disabled = function() return isDisabled() or #mod:GetBars() == 0 end
    })})

    y = row(y, {
        button({text = L["Add"] or "Add", onClick = function() mod:AddBar(); refreshFull(true) end}),
        button({text = L["Duplicate"] or "Duplicate", onClick = function() mod:DuplicateBar(); refreshFull(true) end, disabled = noBar}),
        button({
            text = L["Delete"] or "Delete",
            confirmTitle = L["Delete"] or "Delete",
            confirm = function() local b = selected(mod); return b and ("Delete '%s'?"):format(b.name) end,
            onClick = function() mod:DeleteBar(); refreshFull(true) end,
            disabled = noBar
        })
    })

    y = row(y, {
        button({
            text = L["Import"] or "Import",
            onClick = function()
                E:PromptMultiline({
                    key = "ART_CUSTOM_BAR_IMPORT", title = "Import Custom Bar", parent = rightPanel,
                    input = {multiline = 8, default = "", maxLetters = 200000},
                    onAccept = function(text)
                        local index, err = mod:ImportBarString(text or "")
                        if index then E:Printf("Imported Custom Bar"); refreshFull(true)
                        elseif err then E:Printf("|cffff4040%s|r", err) end
                    end
                })
            end
        }),
        button({
            text = L["Export"] or "Export",
            onClick = function()
                E:ShowText({key = "ART_CUSTOM_BAR_EXPORT", title = "Export Custom Bar", parent = rightPanel, viewer = {text = mod:ExportBarString(), lines = 10}})
            end,
            disabled = noBar
        }),
        button({
            text = "Share in raid chat",
            onClick = function() local ok, err = mod:ShareBarToChat(); if not ok and err then E:Printf("|cffff4040%s|r", err) end end,
            disabled = noBar
        })
    })

    y = section(y, "Trigger and timing")
    y = row(y, {
        checkbox({text = L["Enable"] or "Enable", labelTop = true, get = function() local b=selected(mod); return b and b.enabled end, set = function(v) selected(mod).enabled=v end, rebuild=true, disabled=noBar}),
        button({text = "Preview", onClick = function() mod:Preview() end, disabled = noBar})
    })

    y = section(y, "Active difficulties")
    y = row(y, {
        checkbox({
            text = "Normal",
            labelTop = true,
            get = function()
                local b = selected(mod)
                return b and b.difficulties.normal
            end,
            set = function(value)
                selected(mod).difficulties.normal = value
            end,
            disabled = noBar
        }),
        checkbox({
            text = "Heroic",
            labelTop = true,
            get = function()
                local b = selected(mod)
                return b and b.difficulties.heroic
            end,
            set = function(value)
                selected(mod).difficulties.heroic = value
            end,
            disabled = noBar
        }),
        checkbox({
            text = "Mythic",
            labelTop = true,
            get = function()
                local b = selected(mod)
                return b and b.difficulties.mythic
            end,
            set = function(value)
                selected(mod).difficulties.mythic = value
            end,
            disabled = noBar
        })
    })

    y = row(y, {editbox({label="Name", get=function() local b=selected(mod); return b and b.name or "" end, set=function(v) local b=selected(mod); b.name=strtrim(v or "")~="" and strtrim(v) or "Custom Bar" end, disabled=noBar})})

    local abilities, abilitySorting = abilityValues()
    y = row(y, {dropdown({
        label = "BigWigs ability",
        values = abilities,
        sorting = abilitySorting,
        placeholder = "Choose a known ability",
        get = function() local b=selected(mod); return b and abilities[b.triggerSpellID] and b.triggerSpellID or nil end,
        set = function(value)
            local b=selected(mod); b.triggerSpellID=tonumber(value) or 0
            local label=abilities[b.triggerSpellID]; if label then b.triggerName=label:gsub(" %(%d+%)$", "") end
        end,
        rebuild = true,
        disabled = noBar
    })})
    y = row(y, {
        editbox({label="Manual spell ID", numeric=true, get=function() local b=selected(mod); return b and tostring(b.triggerSpellID) or "0" end, set=function(v) selected(mod).triggerSpellID=math.max(0, math.floor(tonumber(v) or 0)) end, rebuild=true, disabled=noBar}),
        editbox({label="Ability name", get=function() local b=selected(mod); return b and b.triggerName or "" end, set=function(v) selected(mod).triggerName=strtrim(v or "") end, disabled=noBar})
    })
    y = row(y, {
        stepper({label="Start relative to BigWigs timer 0 (seconds)", get=function() local b=selected(mod); return b and b.startOffset or 0 end, set=function(v) selected(mod).startOffset=clamp(v,-20,20) end, step=0.1, decimals=1, min=-20, max=20, rebuild=true, disabled=noBar}),
        stepper({label="Bar duration (seconds)", get=function() local b=selected(mod); return b and b.duration or 6 end, set=function(v) local b=selected(mod); b.duration=clamp(v,0.1,300); setMarkerTimes(b,markerTimes(b)) end, step=0.1, decimals=1, min=0.1, max=300, disabled=noBar})
    })
    y = full(y, track(T:Description(rightPanel, {text = "Start can be set from -20.0 seconds (before timer 0) to +20.0 seconds (after timer 0). Bar duration controls how long the custom bar remains visible."})))

    y = section(y, "Bar and markers")
    y = row(y, {editbox({label="Bar text", get=function() local b=selected(mod); return b and b.text or "" end, set=function(v) selected(mod).text=v or "" end, disabled=noBar})})
    y = row(y, {editbox({label="Marker times (comma separated)", get=function() return markerTimes(selected(mod)) end, set=function(v) setMarkerTimes(selected(mod),v) end, disabled=noBar})})
    y = row(y, {editbox({label="Marker texts (same order)", get=function() return markerTexts(selected(mod)) end, set=function(v) setMarkerTexts(selected(mod),v) end, disabled=noBar})})
    y = row(y, {editbox({label="Marker durations in seconds (same order)", get=function() return markerDurations(selected(mod)) end, set=function(v) setMarkerDurations(selected(mod),v) end, disabled=noBar})})
    y = full(y, track(T:Description(rightPanel, {text = "Up to 10 markers. Example times: 1.5, 3, 4.5, 6. Duration 0 creates a normal pixel marker; a higher value creates a colored time window."})))
    y = row(y, {
        color({label="Marker color", get=function() local b=selected(mod); return b and b.markerColor or {1,1,1,1} end, set=function(v) selected(mod).markerColor=v end, disabled=noBar}),
        stepper({label="Marker thickness", get=function() local b=selected(mod); return b and b.markerThickness or 5 end, set=function(v) selected(mod).markerThickness=clamp(v,1,30) end, step=1, disabled=noBar})
    })
    y = row(y, {
        stepper({label="Marker text size", get=function() local b=selected(mod); return b and b.markerTextSize or 12 end, set=function(v) selected(mod).markerTextSize=clamp(v,8,48) end, step=1, disabled=noBar}),
        stepper({label="Marker text Y", get=function() local b=selected(mod); return b and b.markerTextY or 0 end, set=function(v) selected(mod).markerTextY=clamp(v,-100,100) end, step=1, disabled=noBar})
    })

    y = section(y, "Audio")
    y = row(y, {checkbox({
        text="Enable audio", labelTop=true,
        get=function() local b=selected(mod); return b and b.audio.enabled end,
        set=function(v) selected(mod).audio.enabled=v end,
        fullRefresh=true,
        disabled=noBar
    })})
    local currentBar = selected(mod)
    if currentBar and currentBar.audio.enabled then
        local function audioDisabled() return noBar() or not selected(mod).audio.enabled end
        local function ttsDisabled() return audioDisabled() or selected(mod).audio.mode ~= "tts" end
        local function soundDisabled() return audioDisabled() or selected(mod).audio.mode ~= "sound" end

        y = row(y, {
            stepper({label="Seconds before bar ends", get=function() return selected(mod).audio.secondsBefore end, set=function(v) selected(mod).audio.secondsBefore=clamp(v,0,300) end, step=0.1, decimals=1, min=0, max=300, disabled=audioDisabled}),
            stepper({label="Delay by (seconds)", get=function() return selected(mod).audio.delayBy end, set=function(v) selected(mod).audio.delayBy=clamp(v,0,30) end, step=0.1, decimals=1, min=0, max=30, disabled=audioDisabled})
        })
        y = row(y, {
            dropdown({label="Audio type", values=AUDIO_MODE_VALUES, sorting=AUDIO_MODE_SORTING, get=function() return selected(mod).audio.mode end, set=function(v) selected(mod).audio.mode=v end, disabled=audioDisabled}),
            checkbox({text="Countdown every second", labelTop=true, get=function() return selected(mod).audio.countdown end, set=function(v) selected(mod).audio.countdown=v end, disabled=ttsDisabled})
        })
        y = row(y, {
            editbox({label="Text to Speech message", get=function() return selected(mod).audio.ttsText end, set=function(v) selected(mod).audio.ttsText=v end, disabled=ttsDisabled}),
            dropdown({
                label="TTS voice",
                values=function() return E:GetModule("BossMods").Alerts:GetTTSVoices() end,
                get=function() return selected(mod).audio.voiceID or 0 end,
                set=function(v)
                    selected(mod).audio.voiceID=tonumber(v) or 0
                    E:GetModule("BossMods").Alerts:SpeakTTS({text="Voice test", voiceID=selected(mod).audio.voiceID})
                end,
                disabled=ttsDisabled
            })
        })
        y = row(y, {
            dropdown({
                label="Sound file",
                values=function() return E:GetModule("BossMods").Alerts:GetSoundOptions() end,
                get=function() return selected(mod).audio.sound end,
                set=function(v) selected(mod).audio.sound=v end,
                playSample=function(v) E:GetModule("BossMods").Alerts:PlaySound({name=v, channel=selected(mod).audio.channel or "Master"}) end,
                disabled=soundDisabled
            }),
            dropdown({label="Sound channel", values=SOUND_CHANNEL_VALUES, sorting=SOUND_CHANNEL_SORTING, get=function() return selected(mod).audio.channel end, set=function(v) selected(mod).audio.channel=v end, disabled=soundDisabled})
        })
        y = full(y, track(T:Description(rightPanel, {
            text="Audio timing is relative to the end of the custom bar. Variables: {spell} uses the selected ability, {bar} uses the custom bar name, and {time} uses the countdown number."
        })))
    end

    y = section(y, "Appearance")
    y = row(y, {checkbox({
        text="Override default bar appearance", labelTop=true,
        get=function() local b=selected(mod); return b and b.overrideAppearance end,
        set=function(v) selected(mod).overrideAppearance=v end,
        disabled=noBar
    })})
    local function appearanceDisabled() local b=selected(mod); return noBar() or not b or not b.overrideAppearance end
    y = row(y, {
        stepper({label="Width", get=function() local b=selected(mod); return b and b.appearance.width or 300 end, set=function(v) selected(mod).appearance.width=clamp(v,80,1200) end, step=1, disabled=appearanceDisabled}),
        stepper({label="Height", get=function() local b=selected(mod); return b and b.appearance.height or 24 end, set=function(v) selected(mod).appearance.height=clamp(v,8,120) end, step=1, disabled=appearanceDisabled})
    })
    y = row(y, {dropdown({
        label="Bar texture", values=function() return E:MediaList("statusbar") end,
        get=function() local b=selected(mod); return b and b.appearance.texture end,
        set=function(v) selected(mod).appearance.texture=v end,
        disabled=appearanceDisabled
    })})
    y = row(y, {
        dropdown({label="Font", values=function() return E:MediaList("font") end, get=function() local b=selected(mod); return b and b.appearance.font.name end, set=function(v) selected(mod).appearance.font.name=v end, disabled=appearanceDisabled}),
        dropdown({label="Outline", values=OUTLINE_VALUES, get=function() local b=selected(mod); return b and b.appearance.font.outline end, set=function(v) selected(mod).appearance.font.outline=v end, disabled=appearanceDisabled})
    })
    y = row(y, {stepper({label="Font size", get=function() local b=selected(mod); return b and b.appearance.font.size or 14 end, set=function(v) selected(mod).appearance.font.size=clamp(v,8,48) end, step=1, disabled=appearanceDisabled})})
    y = row(y, {
        color({label="Bar color", get=function() local b=selected(mod); return b and b.appearance.fillColor or {0.2,0.6,1,1} end, set=function(v) selected(mod).appearance.fillColor=v end, disabled=appearanceDisabled}),
        color({label="Background color", get=function() local b=selected(mod); return b and b.appearance.backgroundColor or {0,0,0,1} end, set=function(v) selected(mod).appearance.backgroundColor=v end, disabled=appearanceDisabled})
    })

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)
    return {
        height=totalHeight,
        Refresh=function()
            tracker.refresh()
            if needsRebuild then
                needsRebuild = false
                return true
            end
        end,
        Release=function() tracker.release() end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then BossMods:RegisterBossSettingsBuilder("CustomBars", build) end
end

local events = E:NewCallbackHandle()
events:RegisterMessage("ART_CUSTOM_BARS_CHANGED", function()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then E.OptionsUI:QueueRefresh("current") end
end)
