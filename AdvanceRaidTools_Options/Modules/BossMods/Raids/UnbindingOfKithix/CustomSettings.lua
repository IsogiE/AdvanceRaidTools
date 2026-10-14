local E, L = unpack(ART)
local T = E.Templates
local BossMods = E:GetModule("BossMods")
BossMods:RegisterAuraCircleSettingsBuilder("KithixAddSoakCircle")

BossMods:RegisterBossSettingsBuilder("KithixOrbPickup", function(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    mod:EnsureDisplay()
    local tracker = T:MakeTracker()
    local y = T:PlaceFull(parent, tracker.track(T:Header(parent, {text = L["BossMods_PickUpOrb"]})), 0, width) + 10
    y = y + T:PlaceFull(parent, tracker.track(T:Description(parent, {
        text = L["BossMods_KithixOrbPickupDesc"]
    })), y, width) + 10
    local unlock
    y, unlock = T:UnlockController(parent, y, width, {
        tracker = tracker, isDisabled = isDisabled,
        onEditModeChanged = function(value) mod:SetEditMode(value) end
    })
    y = y + T:PlaceFull(parent, T:PreviewToggle(parent, {
        module = mod, tracker = tracker, disabled = isDisabled
    }), y, width) + 10
    y = y + T:PlaceFull(parent, tracker.track(T:Dropdown(parent, {
        label = L["Font"],
        values = function() return E:MediaList("font") end,
        get = function() return mod.db.font.name end,
        onChange = function(value) mod.db.font.name = value; mod:Refresh(); tracker.refresh() end,
        disabled = isDisabled
    })), y, width) + 10
    y = y + T:PlaceFull(parent, tracker.track(T:Dropdown(parent, {
        label = L["Outline"],
        values = {[""] = L["None"], OUTLINE = L["Outline"], THICKOUTLINE = L["ThickOutline"], OUTLINE_SLUG = L["BossMods_AAOptions_SlugOutline"]},
        sorting = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"},
        get = function() return mod.db.font.outline end,
        onChange = function(value) mod.db.font.outline = value; mod:Refresh(); tracker.refresh() end,
        disabled = isDisabled
    })), y, width) + 10
    y = y + T:PlaceFull(parent, tracker.track(T:Slider(parent, {
        label = L["Size"], min = 12, max = 72, step = 1,
        value = mod.db.font.size, get = function() return mod.db.font.size end,
        onChange = function(value) mod.db.font.size = value; mod:Refresh() end,
        disabled = isDisabled
    })), y, width) + 10
    local position
    y, position = T:PositionSection(parent, y, width, {
        anchor = mod:GetAnchor(), label = L["BossMods_PickUpOrb"], tracker = tracker,
        getPosition = function() return mod.db.position end,
        setPosition = function(value) mod:SavePosition(value) end,
        defaultPosition = {point = "CENTER", x = 0, y = 120},
        onChanged = function() mod:Refresh() end,
        isDisabled = isDisabled, unlockController = unlock, showOffsets = true
    })
    parent:SetHeight(y + 10)
    return {height = y + 10, Refresh = tracker.refresh, Release = function()
        mod:SetEditMode(false)
        mod:SetPreviewMode(false)
        position.Release()
        unlock:Release()
        tracker.release()
    end}
end)
