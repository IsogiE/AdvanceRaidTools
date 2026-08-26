local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6

local function buildVashnikWaveCrossBody(rightPanel, mod, isDisabled)
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

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_VashnikWaveCross"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_VashnikWaveCrossDesc"],
        sizeDelta = 1
    })))

    local preview = track(T:Checkbox(rightPanel, {
        text = L["BossMods_VWCPreviewFrame"],
        get = function()
            return mod.previewMode and true or false
        end,
        onChange = function(_, value)
            mod:SetPreviewMode(value)
            tracker.refresh()
        end,
        disabled = isDisabled
    }))
    y = full(y, preview)

    local displayTiming = track(T:Dropdown(rightPanel, {
        label = L["BossMods_VWCDisplayTiming"],
        values = {
            before = L["BossMods_VWCBeforePlagueFroth"],
            always = L["BossMods_VWCAlwaysEnabled"]
        },
        sorting = {"before", "always"},
        get = function()
            return mod.db.displayMode or "before"
        end,
        onChange = function(value)
            mod.db.displayMode = value == "always" and "always" or "before"
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local secondsBefore = track(T:Slider(rightPanel, {
        label = L["BossMods_VWCSecondsBefore"],
        min = 1,
        max = 30,
        step = 0.5,
        value = mod.db.secondsBefore or 7,
        get = function()
            return mod.db.secondsBefore or 7
        end,
        onChange = function(value)
            mod.db.secondsBefore = value
            refreshLive()
        end,
        disabled = function()
            return isDisabled() or mod.db.displayMode == "always"
        end
    }))
    y = row(y, {displayTiming, secondsBefore})

    local current = type(mod.db.color) == "table" and mod.db.color or {}
    local color = track(T:ColorSwatch(rightPanel, {
        label = L["BossMods_VWCColor"],
        labelTop = true,
        hasAlpha = true,
        r = current[1] or current.r or 1,
        g = current[2] or current.g or 0.82,
        b = current[3] or current.b or 0,
        a = current[4] or current.a or 0.55,
        onChange = function(r, g, b, a)
            mod.db.color = {r, g, b, a}
            refreshLive()
        end,
        disabled = isDisabled
    }))

    local thickness = track(T:Slider(rightPanel, {
        label = L["BossMods_VWCThickness"],
        min = 1,
        max = 10,
        step = 0.5,
        value = mod.db.thickness or 2,
        get = function()
            return mod.db.thickness or 2
        end,
        onChange = function(value)
            mod.db.thickness = value
            refreshLive()
        end,
        disabled = isDisabled
    }))
    y = row(y, {color, thickness})

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetPreviewMode(false)
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("VashnikWaveCross", buildVashnikWaveCrossBody)
end
