local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6

local function buildUlatekFangsBody(rightPanel, mod, isDisabled)
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
        text = L["BossMods_UlatekGraspingFangsOverview"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_UlatekGraspingFangsOverviewDesc"],
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
        min = 180,
        max = 600,
        step = 5,
        get = function()
            return mod.db.width or 300
        end,
        set = function(value)
            mod.db.width = math.floor(value + 0.5)
        end
    })
    local rowHeight = slider({
        label = L["Height"],
        min = 16,
        max = 40,
        step = 1,
        get = function()
            return mod.db.rowHeight or 24
        end,
        set = function(value)
            mod.db.rowHeight = math.floor(value + 0.5)
        end
    })
    y = row(y, {displayWidth, rowHeight})

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
    y = row(y, {scale, opacity})

    local fontSize = slider({
        label = L["Font"] .. " " .. L["Size"],
        min = 8,
        max = 24,
        step = 1,
        get = function()
            return mod.db.fontSize or 14
        end,
        set = function(value)
            mod.db.fontSize = math.floor(value + 0.5)
        end
    })
    local backgroundOpacity = slider({
        label = L["Background"] .. " " .. L["Opacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.backgroundOpacity or 0.85
        end,
        set = function(value)
            mod.db.backgroundOpacity = value
        end
    })
    y = row(y, {fontSize, backgroundOpacity})

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frames and mod.frames.anchor,
        label = L["BossMods_UlatekGraspingFangsOverview"],
        headerText = L["BossMods_UlatekGraspingFangsOverview"] .. " " .. L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod.db.position
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        defaultPosition = {point = "CENTER", x = 0, y = 120},
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
            positionHandle.Release()
            unlockController:Release()
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("UlatekFangs", buildUlatekFangsBody)
end
