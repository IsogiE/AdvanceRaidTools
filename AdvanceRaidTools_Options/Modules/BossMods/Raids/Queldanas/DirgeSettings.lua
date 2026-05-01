local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local KEYBIND_LABEL_VALUES = {
    below = L["BossMods_DirgeKBBelow"],
    above = L["BossMods_DirgeKBAbove"],
    hidden = L["BossMods_DirgeKBHidden"]
}

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function buildDirgeBody(rightPanel, mod, isDisabled)
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

    local posHandles = {}
    local frames = mod.frames

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_Dirge"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_DirgeDesc"],
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

    -- Buttons
    y = section(y, "BossMods_DirgeButtonsSection")

    local btnScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2.0,
        step = 0.05,
        get = function()
            return mod.db.buttons.scale
        end,
        onChange = function(v)
            mod.db.buttons.scale = v
        end
    })
    local btnOpacity = slider({
        label = L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.buttons.opacity
        end,
        onChange = function(v)
            mod.db.buttons.opacity = v
        end
    })
    y = row(y, {btnScale, btnOpacity})

    local clickthrough = checkbox({
        text = L["BossMods_DirgeClickthrough"],
        labelTop = true,
        get = function()
            return mod.db.buttons.clickthrough
        end,
        onChange = function(v)
            mod.db.buttons.clickthrough = v
        end
    })
    local kbPos = dropdown({
        label = L["BossMods_DirgeKBLabel"],
        values = KEYBIND_LABEL_VALUES,
        get = function()
            return mod.db.buttons.keybindLabelPos or "below"
        end,
        onChange = function(v)
            mod.db.buttons.keybindLabelPos = v
        end
    })
    y = row(y, {clickthrough, kbPos})

    local btnPosY, btnHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = frames and frames.barAnchor,
        label = L["BossMods_DirgeButtons"],
        headerText = (L["BossMods_DirgeButtons"] .. " " .. L["Position"]),
        tracker = tracker,
        getPosition = function()
            local p = mod.db.buttons.position
            return {
                point = p.point,
                x = p.x,
                y = p.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition("buttons", pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = -150
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl
    })
    y = btnPosY
    posHandles[#posHandles + 1] = btnHandle

    -- Squad
    y = section(y, "BossMods_DirgeSquadSection")

    local squadScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2.0,
        step = 0.05,
        get = function()
            return mod.db.squad.scale
        end,
        onChange = function(v)
            mod.db.squad.scale = v
        end
    })
    local squadBgOp = slider({
        label = (L["Background"] .. " " .. L["Opacity"]),
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.squad.background.opacity
        end,
        onChange = function(v)
            mod.db.squad.background.opacity = v
        end
    })
    y = row(y, {squadScale, squadBgOp})

    local squadBorderEnable = checkbox({
        text = (L["Enable"] .. " " .. L["Border"]),
        labelTop = true,
        get = function()
            return mod.db.squad.border.enabled
        end,
        onChange = function(v)
            mod.db.squad.border.enabled = v
        end
    })
    local squadBorderTex = dropdown({
        label = (L["Border"] .. " " .. L["Texture"]),
        values = borderValues,
        get = function()
            return mod.db.squad.border.texture
        end,
        onChange = function(v)
            mod.db.squad.border.texture = v
        end
    })
    y = row(y, {squadBorderEnable, squadBorderTex})

    local squadBorderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        step = 1,
        get = function()
            return mod.db.squad.border.size
        end,
        onChange = function(v)
            mod.db.squad.border.size = math.floor(v)
        end
    })
    local squadBorderColor = color({
        label = (L["Border"] .. " " .. L["Color"]),
        get = function()
            return mod.db.squad.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.squad.border.color = {r, g, b, a}
        end
    })
    y = row(y, {squadBorderSize, squadBorderColor})

    local squadPosY, squadHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = frames and frames.squadAnchor,
        label = L["BossMods_DirgeSquad"],
        headerText = (L["BossMods_DirgeSquad"] .. " " .. L["Position"]),
        tracker = tracker,
        getPosition = function()
            local p = mod.db.squad.position
            return {
                point = p.point,
                x = p.x,
                y = p.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition("squad", pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = -200,
            y = 50
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl
    })
    y = squadPosY
    posHandles[#posHandles + 1] = squadHandle

    -- Bar
    y = section(y, "BossMods_DirgeBar")

    local barScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2.0,
        step = 0.05,
        get = function()
            return mod.db.bar.scale
        end,
        onChange = function(v)
            mod.db.bar.scale = v
        end
    })
    local barBgOp = slider({
        label = (L["Background"] .. " " .. L["Opacity"]),
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.bar.background.opacity
        end,
        onChange = function(v)
            mod.db.bar.background.opacity = v
        end
    })
    y = row(y, {barScale, barBgOp})

    local barBorderEnable = checkbox({
        text = (L["Enable"] .. " " .. L["Border"]),
        labelTop = true,
        get = function()
            return mod.db.bar.border.enabled
        end,
        onChange = function(v)
            mod.db.bar.border.enabled = v
        end
    })
    local barBorderTex = dropdown({
        label = (L["Border"] .. " " .. L["Texture"]),
        values = borderValues,
        get = function()
            return mod.db.bar.border.texture
        end,
        onChange = function(v)
            mod.db.bar.border.texture = v
        end
    })
    y = row(y, {barBorderEnable, barBorderTex})

    local barBorderSize = slider({
        label = (L["Border"] .. " " .. L["Size"]),
        min = 1,
        max = 16,
        step = 1,
        get = function()
            return mod.db.bar.border.size
        end,
        onChange = function(v)
            mod.db.bar.border.size = math.floor(v)
        end
    })
    local barBorderColor = color({
        label = (L["Border"] .. " " .. L["Color"]),
        get = function()
            return mod.db.bar.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.bar.border.color = {r, g, b, a}
        end
    })
    y = row(y, {barBorderSize, barBorderColor})

    local barPosY, barHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = frames and frames.seqBarAnchor,
        label = L["BossMods_DirgeBar"],
        headerText = (L["BossMods_DirgeBar"] .. " " .. L["Position"]),
        tracker = tracker,
        getPosition = function()
            local p = mod.db.bar.position
            return {
                point = p.point,
                x = p.x,
                y = p.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition("bar", pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = 50
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl
    })
    y = barPosY
    posHandles[#posHandles + 1] = barHandle

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
                text = L["VoiceTest"],
                voiceID = mod.db.tts.voice
            })
        end,
        disabled = function()
            return isDisabled() or not mod.db.tts.enabled
        end
    })
    y = row(y, {ttsEnable, ttsVoice})

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            for _, h in ipairs(posHandles) do
                h.Release()
            end
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("Dirge", buildDirgeBody)
    end
end
