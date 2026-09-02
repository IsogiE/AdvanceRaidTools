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

local function buildBody(rightPanel, mod, isDisabled, options)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track

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

    local function section(y, text)
        local header = track(T:Header(rightPanel, {text = text}))
        return y + T:PlaceFull(rightPanel, header, y, width) + HEADER_GAP
    end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step,
            value = opts.get(),
            get = opts.get,
            onChange = function(value)
                opts.set(value)
                refreshLive()
            end,
            disabled = isDisabled
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
                refreshLive()
            end,
            disabled = isDisabled
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
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {text = L[options.labelKey]})))
    y = full(y, track(T:Description(rightPanel, {
        text = L[options.descKey],
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

    y = section(y, L["BossMods_TFDelugeAppearance"])
    y = row(y, {
        slider({
            label = L["Width"],
            min = options.isList and 240 or 180,
            max = 700,
            step = 5,
            get = function() return mod.db.width or options.defaultWidth end,
            set = function(value) mod.db.width = math.floor(value + 0.5) end
        }),
        slider({
            label = options.isList and L["BossMods_TFDelugeRowHeight"] or L["Height"],
            min = 14,
            max = 60,
            step = 1,
            get = function() return mod.db.height or options.defaultHeight end,
            set = function(value) mod.db.height = math.floor(value + 0.5) end
        })
    })

    y = row(y, {
        slider({
            label = L["Scale"],
            min = 0.5,
            max = 2,
            step = 0.05,
            get = function() return mod.db.scale or 1 end,
            set = function(value) mod.db.scale = value end
        }),
        slider({
            label = L["Opacity"],
            min = 0.1,
            max = 1,
            step = 0.05,
            get = function() return mod.db.opacity or 1 end,
            set = function(value) mod.db.opacity = value end
        })
    })

    local backgroundOpacity = slider({
        label = L["BossMods_TFDelugeBackgroundOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function() return mod.db.backgroundOpacity or 0.55 end,
        set = function(value) mod.db.backgroundOpacity = value end
    })
    if options.isList then
        y = row(y, {
            backgroundOpacity,
            slider({
                label = L["BossMods_TFDelugeRowSpacing"],
                min = 0,
                max = 12,
                step = 1,
                get = function() return mod.db.rowSpacing or 2 end,
                set = function(value) mod.db.rowSpacing = math.floor(value + 0.5) end
            })
        })
    else
        y = full(y, backgroundOpacity)
    end

    y = section(y, L["BossMods_TFDelugeText"])
    y = row(y, {
        dropdown({
            label = L["Font"] or "Font",
            values = function() return E:MediaList("font") end,
            get = function() return mod.db.font.name end,
            set = function(value) mod.db.font.name = value end
        }),
        dropdown({
            label = L["Outline"] or "Outline",
            values = OUTLINE_VALUES,
            sorting = OUTLINE_SORTING,
            get = function() return mod.db.font.outline end,
            set = function(value) mod.db.font.outline = value or "" end
        })
    })
    y = full(y, slider({
        label = (L["Font"] or "Font") .. " " .. (L["Size"] or "Size"),
        min = 8,
        max = 36,
        step = 1,
        get = function() return mod.db.font.size end,
        set = function(value) mod.db.font.size = math.floor(value + 0.5) end
    }))

    y = section(y, L["BossMods_TFDelugeColors"])
    y = row(y, {
        color({
            label = L["BossMods_TFDelugeSafeColor"],
            get = function() return mod.db.safeColor end,
            set = function(value) mod.db.safeColor = value end
        }),
        color({
            label = L["BossMods_TFDelugeDangerColor"],
            get = function() return mod.db.dangerColor end,
            set = function(value) mod.db.dangerColor = value end
        })
    })
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_TFDelugeDangerDesc"]
    })))

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frames and mod.frames.anchor,
        label = L[options.labelKey],
        headerText = L[options.labelKey] .. " " .. (L["Position"] or "Position"),
        tracker = tracker,
        getPosition = function()
            local position = mod.db.position
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        defaultPosition = options.defaultPosition,
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = positionY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)
            positionHandle.Release()
            unlockController:Release()
            tracker.release()
        end
    }
end

local function buildBar(rightPanel, mod, isDisabled)
    return buildBody(rightPanel, mod, isDisabled, {
        labelKey = "BossMods_TwinFangsDelugeBar",
        descKey = "BossMods_TwinFangsDelugeBarDesc",
        defaultWidth = 300,
        defaultHeight = 30,
        defaultPosition = {point = "CENTER", x = 0, y = -180}
    })
end

local function buildList(rightPanel, mod, isDisabled)
    return buildBody(rightPanel, mod, isDisabled, {
        labelKey = "BossMods_TwinFangsDelugeList",
        descKey = "BossMods_TwinFangsDelugeListDesc",
        defaultWidth = 360,
        defaultHeight = 20,
        defaultPosition = {point = "CENTER", x = 360, y = 0},
        isList = true
    })
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("TwinFangsDelugeBar", buildBar)
    BossMods:RegisterBossSettingsBuilder("TwinFangsDelugeList", buildList)
end

