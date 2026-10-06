local E = unpack(ART)
local Nicknames = E:GetModule("Nicknames")
local refreshPending = false

local function RefreshNames()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        local modules = _G.EllesmereUI and _G.EllesmereUI._ModuleNS
        if not modules then return end
        local raid = modules.EllesmereUIRaidFrames
        local units = modules.EllesmereUIUnitFrames
        if raid and raid.RefreshAllNames then raid.RefreshAllNames() end
        if units and units.RefreshAllUnitNames then units.RefreshAllUnitNames() end
    end)
end

Nicknames:RegisterIntegration("EllesmereUI", {
    Init = RefreshNames,
    Update = RefreshNames,
    OnToggle = RefreshNames
})
