local E, L = unpack(ART)
local T = E.Templates
local BossMods = E:GetModule("BossMods")

local function build(parent, mod, isDisabled)
    mod:EnsureFrame()
    local tracker = T:MakeTracker()
    local y, width = 0, parent:GetWidth()
    local function full(widget)
        tracker.track(widget)
        y = y + T:PlaceFull(parent, widget, y, width) + 6
    end
    local function disabled()
        return InCombatLockdown() or (type(isDisabled) == "function" and isDisabled() or isDisabled == true)
    end
    local function changed() mod:Refresh(); tracker.refresh() end
    full(T:Header(parent, {text = L["BossMods_SentinelsRange"]}))
    full(T:Description(parent, {text = L["BossMods_SentinelsRangeDesc"]}))
    full(T:Checkbox(parent, {
        text = L["BossMods_SentinelsRangeAllClasses"], get = function() return mod.db.allClasses == true end,
        onChange = function(_, value) mod.db.allClasses = value; changed() end, disabled = disabled
    }))
    full(T:PreviewToggle(parent, {module = mod, disabled = disabled}))
    full(T:Header(parent, {text = L["Appearance"]}))
    full(T:Slider(parent, {
        label = L["Size"], min = 48, max = 192, step = 1, value = mod.db.height,
        get = function() return mod.db.height end,
        onChange = function(value) mod.db.height = value; changed() end, disabled = disabled
    }))
    full(T:Checkbox(parent, {
        text = L["BossMods_RaidFrameAurasCountdown"], get = function() return mod.db.showDurationText == true end,
        onChange = function(_, value) mod.db.showDurationText = value; changed() end, disabled = disabled
    }))
    local position
    y, position = T:PositionSection(parent, y, width, {
        anchor = mod.frame, tracker = tracker, label = L["BossMods_SentinelsRange"],
        getPosition = function() return mod.db.position end,
        setPosition = function(value) mod.db.position = value; mod:Refresh() end,
        defaultPosition = {point = "CENTER", x = -175, y = 175},
        showOffsets = true, hideUnlock = true, isDisabled = disabled, onChanged = changed
    })
    parent:SetHeight(y)
    return {
        height = y, Refresh = tracker.refresh,
        Release = function()
            BossMods.DisplayTemplates:SetModulePreview(mod, false)
            position.Release()
            tracker.release()
        end
    }
end

BossMods:RegisterBossSettingsBuilder("SentinelsRange", build)
