local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    OUTLINE_SLUG = "Slug Outline"
}
local OUTLINE_ORDER = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}

local DEFAULT_POSITIONS = {
    bar = {point = "CENTER", x = 0, y = 220},
    assignment = {point = "CENTER", x = 0, y = 150},
    clicker = {point = "CENTER", x = 0, y = 80}
}

local function buildUlatekIntermissionBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    mod:EnsureDefaults()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local positionHandles = {}
    local unlockController

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, width) + ROW_GAP
    end

    local function slider(options)
        return track(T:Slider(rightPanel, {
            label = options.label,
            min = options.min,
            max = options.max,
            step = options.step,
            value = options.get(),
            get = options.get,
            onChange = function(value)
                options.set(value)
                refreshLive()
            end,
            disabled = options.disabled or isDisabled
        }))
    end

    local function color(options)
        local current = options.get()
        return track(T:ColorSwatch(rightPanel, {
            label = options.label,
            labelTop = true,
            hasAlpha = true,
            r = current[1] or current.r or 1,
            g = current[2] or current.g or 1,
            b = current[3] or current.b or 1,
            a = current[4] or current.a or 1,
            onChange = function(r, g, b, a)
                options.set({r, g, b, a})
                refreshLive()
            end,
            disabled = options.disabled or isDisabled
        }))
    end

    local function fontControls(y, data, title)
        y = full(y, track(T:Header(rightPanel, {text = title})))

        local font = track(T:Dropdown(rightPanel, {
            label = L["Font"],
            values = function()
                return E:MediaList("font")
            end,
            get = function()
                return data.font.name
            end,
            onChange = function(value)
                data.font.name = value
                refreshLive()
            end,
            disabled = isDisabled
        }))
        local outline = track(T:Dropdown(rightPanel, {
            label = L["Outline"],
            values = OUTLINE_VALUES,
            sorting = OUTLINE_ORDER,
            get = function()
                return data.font.outline or ""
            end,
            onChange = function(value)
                data.font.outline = value or ""
                refreshLive()
            end,
            disabled = isDisabled
        }))
        y = row(y, {font, outline})

        local fontSize = slider({
            label = L["Font"] .. " " .. L["Size"],
            min = 8,
            max = 60,
            step = 1,
            get = function()
                return data.font.size
            end,
            set = function(value)
                data.font.size = math.floor(value + 0.5)
            end
        })
        local fontColor = color({
            label = L["Color"],
            get = function()
                return data.font.color
            end,
            set = function(value)
                data.font.color = value
            end
        })
        y = row(y, {fontSize, fontColor})

        return y
    end

    local function addPositionSection(y, kind, label, anchor)
        local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
            anchor = anchor,
            label = label,
            headerText = label .. " " .. L["Position"],
            tracker = tracker,
            getPosition = function()
                local position = mod.db[kind].position
                return {
                    point = position.point,
                    x = position.x,
                    y = position.y
                }
            end,
            setPosition = function(position)
                mod:SavePosition(kind, position)
            end,
            defaultPosition = DEFAULT_POSITIONS[kind],
            onChanged = refreshLive,
            isDisabled = isDisabled,
            unlockController = unlockController,
            showOffsets = true
        })

        positionHandles[#positionHandles + 1] = positionHandle
        return positionY
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_UlatekIntermission"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_UlatekIntermissionDesc"],
        sizeDelta = 1
    })))
    local unlockY
    unlockY, unlockController = T:UnlockController(rightPanel, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value)
            mod:SetEditMode(value)
        end
    })
    y = unlockY

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_TimelineSequenceTextOnly"],
        get = function()
            return mod.db.textOnly == true
        end,
        onChange = function(_, value)
            mod.db.textOnly = value and true or false
            refreshLive()
        end,
        disabled = isDisabled
    })))

    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_UlatekIntermissionBarAppearance"]
    })))
    local barWidth = slider({
        label = L["Width"],
        min = 180,
        max = 900,
        step = 5,
        get = function()
            return mod.db.bar.width
        end,
        set = function(value)
            mod.db.bar.width = math.floor(value + 0.5)
        end
    })
    local barHeight = slider({
        label = L["Height"],
        min = 10,
        max = 80,
        step = 1,
        get = function()
            return mod.db.bar.height
        end,
        set = function(value)
            mod.db.bar.height = math.floor(value + 0.5)
        end
    })
    y = row(y, {barWidth, barHeight})

    local barScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function()
            return mod.db.bar.scale
        end,
        set = function(value)
            mod.db.bar.scale = value
        end
    })
    local barOpacity = slider({
        label = L["Opacity"],
        min = 0.1,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.bar.opacity
        end,
        set = function(value)
            mod.db.bar.opacity = value
        end
    })
    y = row(y, {barScale, barOpacity})

    local backgroundOpacity = slider({
        label = L["Background"] .. " " .. L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.bar.backgroundOpacity
        end,
        set = function(value)
            mod.db.bar.backgroundOpacity = value
        end
    })
    local markerWidth = slider({
        label = L["BossMods_AAOptions_MarkerThickness"],
        min = 1,
        max = 14,
        step = 1,
        get = function()
            return mod.db.bar.markerWidth
        end,
        set = function(value)
            mod.db.bar.markerWidth = math.floor(value + 0.5)
        end
    })
    y = row(y, {backgroundOpacity, markerWidth})

    local texture = track(T:Dropdown(rightPanel, {
        label = L["Texture"],
        values = function()
            return E:MediaList("statusbar")
        end,
        get = function()
            return mod.db.bar.texture
        end,
        onChange = function(value)
            mod.db.bar.texture = value
            refreshLive()
        end,
        disabled = isDisabled
    }))
    local barColor = color({
        label = L["BossMods_AAOptions_BarColor"],
        get = function()
            return mod.db.bar.color
        end,
        set = function(value)
            mod.db.bar.color = value
        end
    })
    y = row(y, {texture, barColor})

    y = fontControls(y, mod.db.bar, L["BossMods_UlatekIntermissionBarText"])
    y = fontControls(y, mod.db.assignment, L["BossMods_UlatekIntermissionAssignmentText"])

    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_UlatekIntermissionClickerAppearance"]
    })))

    local clickerScale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function()
            return mod.db.clicker.scale
        end,
        set = function(value)
            mod.db.clicker.scale = value
        end
    })
    local clickerOpacity = slider({
        label = L["Opacity"],
        min = 0.1,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.clicker.opacity
        end,
        set = function(value)
            mod.db.clicker.opacity = value
        end
    })
    y = row(y, {clickerScale, clickerOpacity})

    local frames = mod.frames or {}
    y = addPositionSection(
        y,
        "bar",
        L["BossMods_UlatekIntermissionBar"],
        frames.barAnchor
    )
    y = addPositionSection(
        y,
        "assignment",
        L["BossMods_UlatekIntermissionAssignmentText"],
        frames.assignmentAnchor
    )
    y = addPositionSection(
        y,
        "clicker",
        L["BossMods_UlatekIntermissionClicker"],
        frames.clickerAnchor
    )

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)

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
    BossMods:RegisterBossSettingsBuilder(
        "UlatekIntermission",
        buildUlatekIntermissionBody
    )
end
