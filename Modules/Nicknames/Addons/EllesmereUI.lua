local E, L = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local ADDON_KEY = "EllesmereUI"
local refreshPending = false
local lookupMap
local fullNames = {}
local shortNames = {}
local wrappedLiquidAPIs = setmetatable({}, {
    __mode = "k"
})
local hookedNameplates = setmetatable({}, {
    __mode = "k"
})

local function SafeString(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then
        return nil
    end
    return value ~= "" and value or nil
end

local function RebuildNameLookup(map)
    wipe(fullNames)
    wipe(shortNames)
    lookupMap = map

    for key, nickname in pairs(map) do
        key = SafeString(key)
        nickname = SafeString(nickname)
        if key and nickname then
            local lowerKey = key:lower()
            fullNames[lowerKey] = nickname
            local name = lowerKey:match("^([^-]+)-")
            if name then
                local previous = shortNames[name]
                if previous == nil or previous == nickname then
                    shortNames[name] = nickname
                else
                    shortNames[name] = false
                end
            end
        end
    end
end

local function GetNicknameForName(characterName)
    characterName = SafeString(characterName)
    local map = Nicknames.db and Nicknames.db.map
    if not characterName or not map then
        return nil
    end
    if lookupMap ~= map then
        RebuildNameLookup(map)
    end
    local lowerName = characterName:lower()
    return fullNames[lowerName] or shortNames[lowerName] or nil
end

local function HookLiquidAPI()
    local api = _G.LiquidAPI
    if type(api) ~= "table" then
        return
    end
    local original = api.GetNicknameForEllesmereUI
    if wrappedLiquidAPIs[api] and original == wrappedLiquidAPIs[api] then
        return
    end

    local wrapped = function(...)
        local first, second = ...
        local characterName = type(first) == "table" and second or first
        if Nicknames:IsIntegrationActive(ADDON_KEY) then
            local nickname = GetNicknameForName(characterName)
            if nickname then
                return nickname
            end
        end
        if type(original) == "function" then
            return original(...)
        end
    end
    wrappedLiquidAPIs[api] = wrapped
    api.GetNicknameForEllesmereUI = wrapped
    return true
end

local function GetModuleNamespace(addonName)
    local eui = _G.EllesmereUI
    local modules = eui and eui._ModuleNS
    return modules and modules[addonName]
end

local function RefreshUnitFrames()
    local ns = GetModuleNamespace("EllesmereUIUnitFrames")
    if ns and type(ns.RefreshAllUnitNames) == "function" then
        ns.RefreshAllUnitNames()
    elseif type(_G._EUF_RefreshUnitNames) == "function" then
        _G._EUF_RefreshUnitNames()
    end
end

local function RefreshRaidFrames()
    local ns = GetModuleNamespace("EllesmereUIRaidFrames")
    if ns and type(ns.RefreshAllNames) == "function" then
        ns.RefreshAllNames()
        return
    end
    local erf = _G.EllesmereUIRaidFrames
    if erf and type(erf.UpdateAllFrames) == "function" then
        erf:UpdateAllFrames()
    end
end

local function ApplyNameplateNickname(plate)
    if not plate or not plate.name or not Nicknames:IsIntegrationActive(ADDON_KEY) then
        return
    end
    local nameplate = plate.nameplate
    local unit = (nameplate and nameplate.namePlateUnitToken) or plate.unit
    local nickname = unit and Nicknames:GetIfAny(unit)
    if not nickname then
        return
    end
    plate.name:SetText(nickname)
    if plate.UpdateNameWidth then
        plate:UpdateNameWidth()
    end
end

local function RefreshNameplate(plate)
    if not plate or type(plate.UpdateName) ~= "function" then
        return
    end
    if plate.UpdateName ~= hookedNameplates[plate] then
        hooksecurefunc(plate, "UpdateName", ApplyNameplateNickname)
        hookedNameplates[plate] = plate.UpdateName
    end
    plate:UpdateName()
end

local function RefreshNameplates()
    local ns = _G.EllesmereNameplates_NS
    if not ns then
        return
    end
    for _, plates in pairs({ns.plates, ns.friendlyPlates}) do
        for _, plate in pairs(plates) do
            RefreshNameplate(plate)
        end
    end
end

local function QueueRefresh()
    lookupMap = nil
    if refreshPending then
        return
    end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        HookLiquidAPI()
        RefreshUnitFrames()
        RefreshRaidFrames()
        RefreshNameplates()
    end)
end

local function Update()
    if Nicknames:IsIntegrationActive(ADDON_KEY) then
        QueueRefresh()
    end
end

local function OnToggle()
    HookLiquidAPI()
    QueueRefresh()
end

local addonLoadFrame = CreateFrame("Frame")
addonLoadFrame:RegisterEvent("ADDON_LOADED")
addonLoadFrame:RegisterEvent("PLAYER_LOGIN")
addonLoadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
addonLoadFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
addonLoadFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addonLoadFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" then
        local apiChanged = HookLiquidAPI()
        if not apiChanged and addonName ~= "EllesmereUI" and addonName ~= "EllesmereUIRaidFrames" and
            addonName ~= "EllesmereUIUnitFrames" and addonName ~= "EllesmereUINameplates" then
            return
        end
    end
    if Nicknames.initialized and Nicknames.initialized[ADDON_KEY] then
        QueueRefresh()
    end
end)

Nicknames:RegisterIntegration(ADDON_KEY, {
    Init = OnToggle,
    Update = Update,
    OnToggle = OnToggle
})
