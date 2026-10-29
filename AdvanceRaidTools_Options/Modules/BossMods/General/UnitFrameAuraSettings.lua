local E, L = unpack(ART)
local T = E.Templates
local BossMods = E:GetModule("BossMods")

local function build(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track, y = tracker.track, 0
    local function full(widget)
        y = y + T:PlaceFull(parent, widget, y, width) + 6
    end
    local function refresh()
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
    end
    local function disabled()
        return (type(isDisabled) == "function" and isDisabled() or isDisabled == true) or InCombatLockdown()
    end
    full(track(T:Header(parent, {text = L["BossMods_RaidFrameAuras"]})))
    full(track(T:Description(parent, {text = L["BossMods_RaidFrameAurasDesc"]})))
    for _, display in ipairs(mod.definition.displays) do
        local function settings() return mod:GetDisplaySettings(display) end
        full(track(T:Header(parent, {text = display.label})))
        local function checkbox(text, key)
            return track(T:Checkbox(parent, {
                text = text, get = function() return settings()[key] == true end,
                onChange = function(_, value) settings()[key] = value; refresh() end,
                disabled = disabled
            }))
        end
        full(checkbox(L["Enable"], "enabled"))
        full(checkbox(L["BossMods_RaidFrameAurasAllRoles"], "allRoles"))
        full(track(T:Checkbox(parent, {
            text = L["Preview"], get = function() return mod.previewKey == display.key end,
            onChange = function(_, value)
                mod:SetPreview(value and display.key or nil)
                tracker.refresh()
            end,
            disabled = disabled
        })))
        local function slider(label, key, minimum, maximum)
            return track(T:Slider(parent, {
                label = label, min = minimum, max = maximum, step = 1,
                value = settings()[key], get = function() return settings()[key] end,
                onChange = function(value) settings()[key] = value; refresh() end,
                disabled = disabled
            }))
        end
        full(slider(L["Size"], "size", 16, 64))
        local x = slider(L["OffsetX"], "x", -100, 100)
        local offsetY = slider(L["OffsetY"], "y", -100, 100)
        y = y + T:PlaceRow(parent, {x, offsetY}, y, width) + 6
        full(checkbox(L["BossMods_RaidFrameAurasCooldown"], "showCooldown"))
        full(checkbox(L["BossMods_RaidFrameAurasCountdown"], "showCountdown"))
    end
    parent:SetHeight(y + 10)
    return {
        height = y + 10, Refresh = tracker.refresh,
        Release = function() mod:SetPreview(nil); tracker.release() end
    }
end

for _, featureKey in ipairs(BossMods.unitFrameAuraFeatures) do
    BossMods:RegisterBossSettingsBuilder(featureKey, build)
end
