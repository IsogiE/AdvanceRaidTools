local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local DEFAULT_POSITION = {point = "CENTER", x = 0, y = 160}

local function buildUlatekWrongTargetBody(rightPanel, mod, isDisabled)
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
            disabled = isDisabled
        }))
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_UlatekWrongTarget"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_UlatekWrongTargetDesc"],
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

    local displayWidth = slider({
        label = L["Width"],
        min = 260,
        max = 1200,
        step = 10,
        get = function()
            return mod.db.width or 760
        end,
        set = function(value)
            mod.db.width = math.floor(value + 0.5)
        end
    })
    local displayHeight = slider({
        label = L["Height"],
        min = 40,
        max = 160,
        step = 5,
        get = function()
            return mod.db.height or 90
        end,
        set = function(value)
            mod.db.height = math.floor(value + 0.5)
        end
    })
    y = row(y, {displayWidth, displayHeight})

    local fontSize = slider({
        label = L["Font"] .. " " .. L["Size"],
        min = 16,
        max = 90,
        step = 1,
        get = function()
            return mod.db.fontSize or 48
        end,
        set = function(value)
            mod.db.fontSize = math.floor(value + 0.5)
        end
    })
    local scale = slider({
        label = L["Scale"],
        min = 0.5,
        max = 2,
        step = 0.05,
        get = function()
            return mod.db.scale or 1
        end,
        set = function(value)
            mod.db.scale = value
        end
    })
    y = row(y, {fontSize, scale})

    local opacity = slider({
        label = L["Opacity"],
        min = 0.1,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.opacity or 1
        end,
        set = function(value)
            mod.db.opacity = value
        end
    })
    y = full(y, opacity)

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frame,
        label = L["BossMods_UlatekWrongTarget"],
        headerText = L["BossMods_UlatekWrongTarget"] .. " " .. L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod.db.position
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        defaultPosition = DEFAULT_POSITION,
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

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder(
        "UlatekWrongTarget",
        buildUlatekWrongTargetBody
    )
end
