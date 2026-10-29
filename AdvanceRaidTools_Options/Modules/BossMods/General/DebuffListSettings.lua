local E, L = unpack(ART)
local T = E.Templates

local function build(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    mod:GetSettings()
    mod:Refresh()
    local tracker = T:MakeTracker()
    local track, y = tracker.track, 0
    local function full(widget) y = y + T:PlaceFull(parent, widget, y, width) + 6 end
    local function disabled()
        return (type(isDisabled) == "function" and isDisabled() or isDisabled == true) or InCombatLockdown()
    end
    local function refresh() mod:CallIfEnabled("Refresh"); tracker.refresh() end
    full(track(T:Header(parent, {text = L["BossMods_DebuffList"]})))
    full(track(T:Description(parent, {text = L["BossMods_DebuffListDesc"]})))
    local unlock
    y, unlock = T:UnlockController(parent, y, width, {
        tracker = tracker, isDisabled = disabled,
        onEditModeChanged = function(value) mod:SetEditMode(value) end
    })
    local function slider(label, key, minimum, maximum)
        full(track(T:Slider(parent, {
            label = label, min = minimum, max = maximum, step = 1,
            value = mod.db[key], get = function() return mod.db[key] end,
            onChange = function(value) mod.db[key] = value; refresh() end, disabled = disabled
        })))
    end
    slider(L["Width"], "width", 100, 500)
    slider(L["Height"], "rowHeight", 16, 60)
    slider(L["Spacing"], "spacing", 0, 20)
    slider(L["Font"] .. " " .. L["Size"], "fontSize", 8, 32)
    for _, field in ipairs({{key = "font", kind = "font", label = L["Font"]}, {key = "texture", kind = "statusbar", label = L["Texture"]}}) do
        full(track(T:Dropdown(parent, {
            label = field.label, values = function() return E:MediaList(field.kind) end,
            get = function() return mod.db[field.key] end,
            onChange = function(value) mod.db[field.key] = value; refresh() end, disabled = disabled
        })))
    end
    local position
    y, position = T:PositionSection(parent, y, width, {
        anchor = mod.display and mod.display.frame, label = L["BossMods_DebuffList"], tracker = tracker,
        getPosition = function() return mod.db.position end,
        setPosition = function(value) mod:SavePosition(value) end,
        defaultPosition = {point = "CENTER", x = -360, y = 0},
        onChanged = refresh, isDisabled = disabled, unlockController = unlock, showOffsets = true
    })
    parent:SetHeight(y + 10)
    return {
        height = y + 10, Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)
            position.Release()
            unlock:Release()
            tracker.release()
        end
    }
end

E:GetModule("BossMods"):RegisterBossSettingsBuilder("DebuffList", build)
