local E, L = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local EQoL

local function GetEQoL()
    if EQoL then
        return EQoL
    end
    local addon = _G["EnhanceQoL"]
    if addon and addon.Aura and addon.Aura.UF and addon.Aura.UF.GroupFrames then
        EQoL = addon.Aura.UF.GroupFrames
    end
    return EQoL
end

local function PostUpdateName(self, frame)
    if not Nicknames:IsIntegrationActive("EnhanceQoL") then
        return
    end

    local unit = frame and (frame.unit or (frame.GetAttribute and frame:GetAttribute("unit")))
    if not unit or not UnitIsPlayer(unit) or not Nicknames:Has(unit) then
        return
    end

    local st = frame._eqolUFState
    local fs = st and (st.nameText or st.name)
    if not fs then
        return
    end

    if fs.IsShown and not fs:IsShown() then
        return
    end

    local nickname = Nicknames:GetIfAny(unit)
    if not nickname or nickname == "" then
        return
    end

    local connected = UnitIsConnected and UnitIsConnected(unit)
    local displayName = nickname
    if connected == false then
        displayName = displayName .. " |cffff6666DC|r"
    end

    st._lastName = nil

    if fs.SetText then
        fs:SetText(displayName)
    end
end

local function ForceUpdate()
    local GF = GetEQoL()
    if not GF then
        return
    end
    if GF.RefreshNames then
        GF:RefreshNames()
    end
end

local function Update()
    if not Nicknames:IsIntegrationActive("EnhanceQoL") then
        return
    end
    ForceUpdate()
end

local function OnToggle(_enabled)
    ForceUpdate()
end

local function Init()
    local GF = GetEQoL()
    if not GF then
        return
    end

    hooksecurefunc(GF, "UpdateName", PostUpdateName)

    Update()
end

Nicknames:RegisterIntegration("EnhanceQoL", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
