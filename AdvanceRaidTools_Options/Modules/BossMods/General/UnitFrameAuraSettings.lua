local E, L = unpack(ART)
local T = E.Templates
local BossMods = E:GetModule("BossMods")
local collapsedSections = {}

local function build(parent, mod, isDisabled, requestLayout)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track, y = tracker.track, 0
    local featureKey = mod.definition.featureKey
    local collapsed = collapsedSections[featureKey] or {}
    collapsedSections[featureKey] = collapsed
    local sections, ui = {}, {}
    local relayout
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
    local topHeight = y
    for index, display in ipairs(mod.definition.displays) do
        if collapsed[display.key] == nil then collapsed[display.key] = index > 1 end
        local function settings() return mod:GetDisplaySettings(display) end
        local section = {rows = {}}
        sections[#sections + 1] = section
        section.key = display.key
        section.header = track(T:Header(parent, {
            text = display.label,
            collapsed = function() return collapsed[display.key] end,
            onToggle = function(value)
                collapsed[display.key] = value
                if value and mod.previewKey == display.key then mod:SetPreview(nil) end
                relayout()
                tracker.refresh()
            end
        }))
        local function row(...)
            section.rows[#section.rows + 1] = {...}
        end
        local function checkbox(text, key)
            return track(T:Checkbox(parent, {
                text = text, get = function() return settings()[key] == true end,
                onChange = function(_, value) settings()[key] = value; refresh() end,
                disabled = disabled
            }))
        end
        row(checkbox(L["Enable"], "enabled"))
        row(checkbox(L["BossMods_RaidFrameAurasAllRoles"], "allRoles"))
        row(track(T:Checkbox(parent, {
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
        row(slider(L["Size"], "size", 16, 64))
        local x = slider(L["OffsetX"], "x", -100, 100)
        local offsetY = slider(L["OffsetY"], "y", -100, 100)
        row(x, offsetY)
        row(checkbox(L["BossMods_RaidFrameAurasCooldown"], "showCooldown"))
        row(checkbox(L["BossMods_RaidFrameAurasCountdown"], "showCountdown"))
    end
    relayout = function()
        y = topHeight
        for _, section in ipairs(sections) do
            full(section.header)
            local shown = not collapsed[section.key]
            for _, widgets in ipairs(section.rows) do
                for _, widget in ipairs(widgets) do widget.frame:SetShown(shown) end
                if shown then
                    if #widgets == 1 then full(widgets[1])
                    else y = y + T:PlaceRow(parent, widgets, y, width) + 6 end
                end
            end
        end
        ui.height = y + 10
        parent:SetHeight(ui.height)
        if requestLayout then requestLayout() end
    end
    ui.Refresh = tracker.refresh
    ui.Release = function() mod:SetPreview(nil); tracker.release() end
    relayout()
    return ui
end

for _, featureKey in ipairs(BossMods.unitFrameAuraFeatures) do
    BossMods:RegisterBossSettingsBuilder(featureKey, build)
end
