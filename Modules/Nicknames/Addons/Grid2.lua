local E, L, P = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local gridEvents = E:NewCallbackHandle()
local initialized = false

local Grid2NicknameStatus
local Grid2NameStatus

local function Update(unit, ...)
    if not (_G.Grid2 and initialized) then
        return
    end

    local targetUnit = unit

    local function findAndApplyUpdate(groupUnit)
        if UnitExists(groupUnit) and UnitIsUnit(targetUnit, groupUnit) then
            if Grid2NameStatus then
                Grid2NameStatus:UpdateIndicators(groupUnit)
            end
            if Grid2NicknameStatus then
                Grid2NicknameStatus:UpdateIndicators(groupUnit)
            end
            return true
        end
        return false
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if findAndApplyUpdate("raid" .. i) then
                return
            end
        end
    elseif IsInGroup() then
        if findAndApplyUpdate("player") then
            return
        end
        for i = 1, GetNumSubgroupMembers() do
            if findAndApplyUpdate("party" .. i) then
                return
            end
        end
    else
        findAndApplyUpdate("player")
    end
end

local function UpdateAll()
    if not (_G.Grid2 and initialized) then
        return
    end

    local function updateAllIndicators(unit)
        if UnitExists(unit) then
            if Grid2NameStatus then
                Grid2NameStatus:UpdateIndicators(unit)
            end
            if Grid2NicknameStatus then
                Grid2NicknameStatus:UpdateIndicators(unit)
            end
        end
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            updateAllIndicators("raid" .. i)
        end
    elseif IsInGroup() then
        updateAllIndicators("player")
        for i = 1, GetNumSubgroupMembers() do
            updateAllIndicators("party" .. i)
        end
    else
        updateAllIndicators("player")
    end
end

local function OnToggle(_enabled)
    UpdateAll()
end

local function CreateNicknameStatus()
    local Grid2 = _G.Grid2
    if not Grid2 then
        return
    end

    local statusName = "ART Nickname"
    Grid2NicknameStatus = Grid2.statusPrototype:new(statusName)
    Grid2NicknameStatus.IsActive = Grid2.statusLibrary.IsActive

    function Grid2NicknameStatus:UNIT_NAME_UPDATE(_, unit)
        self:UpdateIndicators(unit)
    end

    function Grid2NicknameStatus:OnEnable()
        self:RegisterEvent("UNIT_NAME_UPDATE")
    end

    function Grid2NicknameStatus:OnDisable()
        self:UnregisterEvent("UNIT_NAME_UPDATE")
    end

    function Grid2NicknameStatus:GetText(unit)
        if Nicknames:IsIntegrationActive("Grid2") then
            return Nicknames:GetIfAny(unit) or ""
        else
            return GetUnitName(unit)
        end
    end

    local function Create(baseKey, dbx)
        Grid2:RegisterStatus(Grid2NicknameStatus, {"text"}, baseKey, dbx)
        return Grid2NicknameStatus
    end

    Grid2.setupFunc[statusName] = Create
    Grid2:DbSetStatusDefaultValue(statusName, {
        type = statusName
    })
end

local function OverrideNameFunction()
    local Grid2 = _G.Grid2
    if initialized or not (Grid2.statuses and Grid2.statuses.name) then
        return
    end

    Grid2NameStatus = Grid2.statuses.name
    local strCyr2Lat = Grid2.strCyr2Lat
    local owner_of_unit = Grid2.owner_of_unit

    local function GetText1(self, unit)
        local defaultName = self.dbx.defaultName
        return Nicknames:GetIfAny(unit) or (defaultName == 1 and unit) or defaultName
    end

    local function GetText2(self, unit)
        local defaultName = self.dbx.defaultName
        local name = Nicknames:GetIfAny(unit)
        return (name and strCyr2Lat(name)) or (defaultName == 1 and unit) or defaultName
    end

    local function GetText3(self, unit)
        local GetTextNoPet = self.dbx.enableTransliterate and GetText2 or GetText1
        local displayPetOwner = self.dbx.displayPetOwner
        local displayVehicleOwner = self.dbx.displayVehicleOwner
        local owner = owner_of_unit[unit]

        if owner and (displayPetOwner or (displayVehicleOwner and UnitHasVehicleUI(owner))) then
            unit = owner
        end
        return GetTextNoPet(self, unit)
    end

    local function NicknameFunction(self, unit)
        local dbx = self.dbx
        local GetTextNoPet = dbx.enableTransliterate and GetText2 or GetText1
        local displayPetOwner = dbx.displayPetOwner
        local displayVehicleOwner = dbx.displayVehicleOwner

        return (displayPetOwner or displayVehicleOwner) and GetText3(self, unit) or GetTextNoPet(self, unit)
    end

    local OriginalFunction = Grid2NameStatus.GetText

    Grid2NameStatus.GetText = function(self, unit)
        local useNickname = Nicknames:IsIntegrationActive("Grid2") and Nicknames:Has(unit)

        if useNickname then
            return NicknameFunction(self, unit)
        else
            return OriginalFunction(self, unit)
        end
    end

    initialized = true
end

local function Init()
    local Grid2 = _G.Grid2
    if not Grid2 then
        return
    end

    CreateNicknameStatus()

    if Grid2.statuses and Grid2.statuses.name then
        OverrideNameFunction()
        UpdateAll()
    else
        gridEvents:RegisterMessage("Grid_Enabled", function()
            OverrideNameFunction()
            UpdateAll()
        end)
    end
end

local function AddGrid2Options()
    if Grid2NicknameStatus and _G.Grid2Options then
        _G.Grid2Options:RegisterStatusOptions("ART Nickname", "misc", function()
        end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, addOnName)
    if addOnName == "Grid2Options" then
        AddGrid2Options()
    end
end)

Nicknames:RegisterIntegration("Grid2", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
