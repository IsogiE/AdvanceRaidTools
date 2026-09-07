local E, L = unpack(ART)
local T = E.Templates

local function build(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track = tracker.track
    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + 6
    end
    local function slider(label, key, minimum, maximum)
        return track(T:Slider(rightPanel, {
            label = label, min = minimum, max = maximum, step = 1,
            value = mod.db[key],
            get = function() return mod.db[key] end,
            onChange = function(value)
                mod.db[key] = math.floor(value + 0.5)
                mod:CallIfEnabled("Refresh")
                tracker.refresh()
            end,
            disabled = isDisabled
        }))
    end

    local y = full(0, track(T:Header(rightPanel, {text = L["BossMods_UlatekNameplateBuffs"]})))
    y = full(y, track(T:Description(rightPanel, {text = L["BossMods_UlatekNameplateBuffsDesc"]})))
    y = full(y, slider(L["Size"], "size", 16, 80))
    y = full(y, slider(L["BossMods_UlatekNameplateBuffsMaxIcons"], "maxIcons", 1, 10))
    y = full(y, slider(L["QoL_XOffset"], "offsetX", -200, 200))
    y = full(y, slider(L["QoL_YOffset"], "offsetY", -200, 200))
    rightPanel:SetHeight(y + 10)
    return {height = y + 10, Refresh = tracker.refresh, Release = tracker.release}
end

E:GetModule("BossMods"):RegisterBossSettingsBuilder("UlatekNameplateBuffs", build)
