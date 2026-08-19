local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local KEYBIND_LABEL_VALUES = {
    below = "Below Icon",
    above = "Above Icon",
    hidden = "Hidden"
}

local function buildBody(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then
        return {height = 1}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track

    local function refresh()
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
    end

    local function row(y, widgets)
        return y + T:PlaceRow(parent, widgets, y, width) + ROW_GAP
    end

    local function full(y, widget)
        return y + T:PlaceFull(parent, widget, y, width) + ROW_GAP
    end

    local function section(y, text)
        return full(y, track(T:Header(parent, {text = text}))) + HEADER_GAP - ROW_GAP
    end

    local function slider(opts)
        return track(T:Slider(parent, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refresh()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function checkbox(opts)
        local control = track(T:Checkbox(parent, {
            text = opts.text,
            labelTop = true,
            checked = opts.get(),
            get = opts.get,
            onChange = function(_, value)
                opts.set(value)
                refresh()
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
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refresh()
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
                refresh()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(parent, {text = L["BossMods_SszorakSurgeIcons"] or "Sszorak Surge Icons"})))
    y = full(y, track(T:Description(parent, {
        text = "Authorized callers are read from the surgestart/surgeend note block. The six buttons send raid-marker messages, while the display keeps the first four icons until 20 seconds after Howling Maelstorm reaches 0.",
        sizeDelta = 1
    })))

    local unlockY, unlockController = T:UnlockController(parent, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value)
            mod:SetEditMode(value)
        end
    })
    y = unlockY

    y = section(y, "Caller Button Bar")
    y = row(y, {
        slider({
            label = "Scale",
            min = 0.5,
            max = 2,
            step = 0.05,
            get = function() return mod.db.buttons.scale end,
            set = function(value) mod.db.buttons.scale = value end
        }),
        slider({
            label = "Opacity",
            min = 0,
            max = 1,
            step = 0.05,
            get = function() return mod.db.buttons.opacity end,
            set = function(value) mod.db.buttons.opacity = value end
        })
    })

    y = row(y, {
        checkbox({
            text = "Clickthrough",
            get = function() return mod.db.buttons.clickthrough end,
            set = function(value) mod.db.buttons.clickthrough = value end
        }),
        dropdown({
            label = "Keybind Label",
            values = KEYBIND_LABEL_VALUES,
            get = function() return mod.db.buttons.keybindLabelPos end,
            set = function(value) mod.db.buttons.keybindLabelPos = value end
        })
    })

    y = section(y, "Four-Icon Display")
    y = row(y, {
        slider({
            label = "Scale",
            min = 0.5,
            max = 2,
            step = 0.05,
            get = function() return mod.db.display.scale end,
            set = function(value) mod.db.display.scale = value end
        }),
        slider({
            label = "Background Opacity",
            min = 0,
            max = 1,
            step = 0.05,
            get = function() return mod.db.display.background.opacity end,
            set = function(value) mod.db.display.background.opacity = value end
        })
    })

    y = row(y, {
        checkbox({
            text = "Enable Border",
            get = function() return mod.db.display.border.enabled end,
            set = function(value) mod.db.display.border.enabled = value end
        }),
        dropdown({
            label = "Border Texture",
            values = function() return E:MediaList("border") end,
            get = function() return mod.db.display.border.texture end,
            set = function(value) mod.db.display.border.texture = value end
        })
    })

    y = row(y, {
        slider({
            label = "Border Size",
            min = 1,
            max = 16,
            step = 1,
            get = function() return mod.db.display.border.size end,
            set = function(value) mod.db.display.border.size = math.floor(value + 0.5) end
        }),
        color({
            label = "Border Color",
            get = function() return mod.db.display.border.color end,
            set = function(value) mod.db.display.border.color = value end
        })
    })

    local frames = mod.frames
    local positionHandles = {}

    local buttonY, buttonHandle = T:PositionSection(parent, y, width, {
        anchor = frames and frames.buttonAnchor,
        label = "Caller Buttons",
        headerText = "Caller Button Position",
        tracker = tracker,
        getPosition = function() return mod.db.buttons.position end,
        setPosition = function(position) mod:SavePosition("buttons", position) end,
        defaultPosition = {point = "CENTER", x = 0, y = -150},
        onChanged = refresh,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = buttonY
    positionHandles[#positionHandles + 1] = buttonHandle

    local displayY, displayHandle = T:PositionSection(parent, y, width, {
        anchor = frames and frames.displayAnchor,
        label = "Surge Icons",
        headerText = "Four-Icon Display Position",
        tracker = tracker,
        getPosition = function() return mod.db.display.position end,
        setPosition = function(position) mod:SavePosition("display", position) end,
        defaultPosition = {point = "CENTER", x = 0, y = 50},
        onChanged = refresh,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = displayY
    positionHandles[#positionHandles + 1] = displayHandle

    local height = math.max(y + 10, 1)
    parent:SetHeight(height)
    return {
        height = height,
        Refresh = tracker.refresh,
        Release = function()
            for _, handle in ipairs(positionHandles) do
                if handle and handle.Release then
                    handle.Release()
                end
            end
            unlockController:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("SszorakSurgeIcons", buildBody)
end
