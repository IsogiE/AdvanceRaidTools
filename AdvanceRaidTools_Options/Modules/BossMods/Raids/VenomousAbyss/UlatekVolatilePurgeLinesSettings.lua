local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local STRATA_VALUES = {
    BACKGROUND = L["Background"],
    LOW = L["QoL_StrataLow"],
    MEDIUM = L["QoL_StrataMedium"],
    HIGH = L["QoL_StrataHigh"],
    DIALOG = L["QoL_StrataDialog"]
}
local STRATA_ORDER = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}

local function build(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then
        return {}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track

    local function refresh()
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
        text = L["BossMods_UlatekVolatilePurgeLines"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_UlatekVolatilePurgeLinesDesc"],
        sizeDelta = 1
    })))

    y = full(y, T:PreviewToggle(rightPanel, {
        module = mod,
        tracker = tracker,
        disabled = isDisabled
    }))

    local current = type(mod.db.color) == "table" and mod.db.color or {}
    local color = track(T:ColorSwatch(rightPanel, {
        label = L["BossMods_UlatekVPLColor"],
        labelTop = true,
        hasAlpha = false,
        r = current[1] or current.r or 0.08,
        g = current[2] or current.g or 0.52,
        b = current[3] or current.b or 1,
        a = 1,
        onChange = function(r, g, b)
            mod.db.color = {r, g, b}
            refresh()
        end,
        disabled = isDisabled
    }))

    local thickness = track(T:Slider(rightPanel, {
        label = L["BossMods_UlatekVPLThickness"],
        min = 1,
        max = 10,
        step = 0.5,
        value = mod.db.thickness or 2,
        get = function()
            return mod.db.thickness or 2
        end,
        onChange = function(value)
            mod.db.thickness = value
            refresh()
        end,
        disabled = isDisabled
    }))
    y = row(y, {color, thickness})

    local opacity = track(T:Slider(rightPanel, {
        label = L["BossMods_UlatekVPLOpacity"],
        min = 0.05,
        max = 1,
        step = 0.05,
        value = mod.db.opacity or 0.7,
        get = function()
            return mod.db.opacity or 0.7
        end,
        onChange = function(value)
            mod.db.opacity = value
            refresh()
        end,
        disabled = isDisabled
    }))

    local strata = track(T:Dropdown(rightPanel, {
        label = L["QoL_Strata"],
        values = STRATA_VALUES,
        sorting = STRATA_ORDER,
        tooltip = {
            title = L["QoL_Strata"],
            desc = L["QoL_StrataDesc"]
        },
        get = function()
            return mod.db.strata or "MEDIUM"
        end,
        onChange = function(value)
            mod.db.strata = STRATA_VALUES[value] and value or "MEDIUM"
            refresh()
        end,
        disabled = isDisabled
    }))
    y = row(y, {opacity, strata})

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
    BossMods:RegisterBossSettingsBuilder("UlatekVolatilePurgeLines", build)
end
