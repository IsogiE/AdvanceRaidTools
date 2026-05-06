local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6

local STRATA_VALUES = {
    BACKGROUND = "Background",
    LOW = "QoL_StrataLow",
    MEDIUM = "QoL_StrataMedium",
    HIGH = "QoL_StrataHigh",
    DIALOG = "QoL_StrataDialog"
}
local STRATA_ORDER = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}

local function buildBreakTimerBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end
    if mod.EnsureFrame then
        mod:EnsureFrame()
    end

    local tracker = T:MakeTracker()
    local track = tracker.track

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, widthPx) + ROW_GAP
    end
    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx) + ROW_GAP
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_BreakTimer"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_BreakTimerDesc"] or
            "Show a popup with a random meme image and a countdown when BigWigs starts a break.",
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

    local strataValues = {}
    for key, labelKey in pairs(STRATA_VALUES) do
        strataValues[key] = L[labelKey] or key
    end
    local strataDropdown = track(T:Dropdown(rightPanel, {
        label = L["QoL_Strata"],
        values = strataValues,
        sorting = STRATA_ORDER,
        tooltip = {
            title = L["QoL_Strata"],
            desc = L["QoL_StrataDesc"] or ""
        },
        get = function()
            return mod.db.strata or "DIALOG"
        end,
        onChange = function(v)
            mod.db.strata = v
            mod:ApplyStrata()
        end,
        disabled = function()
            return isDisabled()
        end
    }))
    local scaleSlider = track(T:Slider(rightPanel, {
        label = L["Scale"],
        min = 0.5,
        max = 2.0,
        step = 0.05,
        isPercent = true,
        value = mod.db.scale or 1.0,
        get = function()
            return mod.db.scale or 1.0
        end,
        onChange = function(v)
            mod.db.scale = v
            mod:ApplyScale()
        end,
        disabled = function()
            return isDisabled()
        end
    }))
    y = row(y, {strataDropdown, scaleSlider})

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.frame,
        label = L["BossMods_BreakTimer"],
        tracker = tracker,
        getPosition = function()
            local p = mod.db.position or {}
            return {
                point = p.point,
                x = p.x,
                y = p.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition(pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = 0
        },
        onChanged = tracker.refresh,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            posHandle.Release()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("BreakTimer", buildBreakTimerBody)
    end
end
