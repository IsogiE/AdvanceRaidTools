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

    local durationSlider = track(T:Slider(rightPanel, {
        label = L["BossMods_BreakTimer_Duration"],
        min = 10,
        max = 600,
        step = 5,
        value = mod.db.defaultDuration or 60,
        get = function()
            return mod.db.defaultDuration or 60
        end,
        onChange = function(v)
            mod.db.defaultDuration = math.floor(v)
        end,
        disabled = function()
            return isDisabled()
        end
    }))
    y = row(y, {durationSlider})

    local testBtn = track(T:Button(rightPanel, {
        text = L["BossMods_BreakTimer_Test"],
        onClick = function()
            mod:Test(mod.db.defaultDuration or 60)
            tracker.refresh()
        end,
        disabled = function()
            return isDisabled()
        end
    }))
    local stopBtn = track(T:Button(rightPanel, {
        text = L["BossMods_BreakTimer_Stop"],
        onClick = function()
            mod:Stop()
            tracker.refresh()
        end,
        disabled = function()
            return isDisabled() or not mod:IsRunning()
        end
    }))
    y = row(y, {testBtn, stopBtn})

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
    local resetBtn = track(T:LabelAlignedButton(rightPanel, {
        text = (L["Reset"] .. " " .. L["Position"]) or "Reset Position",
        onClick = function()
            mod:ResetPosition()
            tracker.refresh()
        end,
        disabled = function()
            return isDisabled()
        end
    }))
    y = row(y, {strataDropdown, scaleSlider, resetBtn})

    local stateHandle = E:NewCallbackHandle()
    stateHandle:RegisterMessage("ART_BREAKTIMER_STATE", function()
        tracker.refresh()
    end)
    stateHandle:RegisterMessage("ART_MODULE_TOGGLED", function(_, name)
        if name == "BossMods_BreakTimer" or name == "BossMods" then
            tracker.refresh()
        end
    end)
    stateHandle:RegisterMessage("ART_OPTIONS_HIDDEN", function()
        if mod:IsTest() then
            mod:Stop()
        end
    end)

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            stateHandle:UnregisterAllMessages()
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
