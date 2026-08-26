local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6

local function buildSszorakCompassBody(rightPanel, mod, isDisabled)
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
        text = L["BossMods_SszorakCompass"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_SszorakCompassDesc"],
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

    local iconSize = slider({
        label = L["BossMods_SCIconSize"],
        min = 12,
        max = 48,
        step = 1,
        get = function()
            return mod.db.iconSize or 22
        end,
        set = function(value)
            mod.db.iconSize = math.floor(value + 0.5)
        end
    })
    local ringRadius = slider({
        label = L["BossMods_SCRingRadius"],
        min = 24,
        max = 100,
        step = 1,
        get = function()
            return mod.db.ringRadius or 46
        end,
        set = function(value)
            mod.db.ringRadius = math.floor(value + 0.5)
        end
    })
    y = row(y, {iconSize, ringRadius})

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
    y = row(y, {opacity})

    local positionY, positionHandle = T:PositionSection(rightPanel, y, width, {
        anchor = mod.frame,
        label = L["BossMods_SszorakCompass"],
        headerText = L["BossMods_SszorakCompass"] .. " " .. L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod.db.position
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        defaultPosition = {point = "CENTER", x = 0, y = 0},
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
    BossMods:RegisterBossSettingsBuilder("SszorakCompass", buildSszorakCompassBody)
end
