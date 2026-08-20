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
    local values = E:MediaList("border")
    values["None"] = nil
    return values
end

local function buildSszorakMarkersBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
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
            onChange = function(value)
                opts.onChange(value)
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
            onChange = function(_, value)
                opts.onChange(value)
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
            onChange = function(value)
                opts.onChange(value)
                refreshLive()
            end,
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
                opts.onChange(r, g, b, a)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, width) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
    end

    local function section(y, key)
        local header = track(T:Header(rightPanel, {text = L[key] or key}))
        return y + T:PlaceFull(rightPanel, header, y, width) + HEADER_GAP
    end

    local frames = mod.frames
    local positionHandles = {}
    local y = 0

    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_SszorakMarkers"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_SszorakMarkersDesc"],
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

    y = section(y, "BossMods_SMButtonsSection")

    local buttonScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function()
            return mod.db.buttons.scale
        end,
        onChange = function(value)
            mod.db.buttons.scale = value
        end
    })
    local buttonOpacity = slider({
        label = L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.buttons.opacity
        end,
        onChange = function(value)
            mod.db.buttons.opacity = value
        end
    })
    y = row(y, {buttonScale, buttonOpacity})

    local clickthrough = checkbox({
        text = L["BossMods_DirgeClickthrough"],
        labelTop = true,
        get = function()
            return mod.db.buttons.clickthrough
        end,
        onChange = function(value)
            mod.db.buttons.clickthrough = value
        end
    })
    local keybindPosition = dropdown({
        label = L["BossMods_DirgeKBLabel"],
        values = KEYBIND_LABEL_VALUES,
        get = function()
            return mod.db.buttons.keybindLabelPos or "below"
        end,
        onChange = function(value)
            mod.db.buttons.keybindLabelPos = value
        end
    })
    y = row(y, {clickthrough, keybindPosition})

    y = section(y, "BossMods_SMBarSection")

    local barScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function()
            return mod.db.bar.scale
        end,
        onChange = function(value)
            mod.db.bar.scale = value
        end
    })
    local backgroundOpacity = slider({
        label = L["Background"] .. " " .. L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.bar.background.opacity
        end,
        onChange = function(value)
            mod.db.bar.background.opacity = value
        end
    })
    y = row(y, {barScale, backgroundOpacity})

    local borderEnabled = checkbox({
        text = L["Enable"] .. " " .. L["Border"],
        labelTop = true,
        get = function()
            return mod.db.bar.border.enabled
        end,
        onChange = function(value)
            mod.db.bar.border.enabled = value
        end
    })
    local borderTexture = dropdown({
        label = L["Border"] .. " " .. L["Texture"],
        values = borderValues,
        get = function()
            return mod.db.bar.border.texture
        end,
        onChange = function(value)
            mod.db.bar.border.texture = value
        end
    })
    y = row(y, {borderEnabled, borderTexture})

    local borderSize = slider({
        label = L["Border"] .. " " .. L["Size"],
        min = 1,
        max = 16,
        step = 1,
        get = function()
            return mod.db.bar.border.size
        end,
        onChange = function(value)
            mod.db.bar.border.size = math.floor(value)
        end
    })
    local borderColor = color({
        label = L["Border"] .. " " .. L["Color"],
        get = function()
            return mod.db.bar.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.bar.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderColor})

    local buttonPositionY, buttonPositionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = frames and frames.buttonAnchor,
        label = L["BossMods_SMButtons"],
        headerText = L["BossMods_SMButtons"] .. " " .. L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod.db.buttons.position
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition("buttons", position)
        end,
        defaultPosition = {point = "CENTER", x = 0, y = -150},
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = buttonPositionY
    positionHandles[#positionHandles + 1] = buttonPositionHandle

    local barPositionY, barPositionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = frames and frames.barAnchor,
        label = L["BossMods_SMBar"],
        headerText = L["BossMods_SMBar"] .. " " .. L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod.db.bar.position
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition("bar", position)
        end,
        defaultPosition = {point = "CENTER", x = 0, y = 50},
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = barPositionY
    positionHandles[#positionHandles + 1] = barPositionHandle

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            for _, handle in ipairs(positionHandles) do
                handle.Release()
            end
            unlockController:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("SszorakMarkers", buildSszorakMarkersBody)
end
