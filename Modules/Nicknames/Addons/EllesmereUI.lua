local E, L = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local ADDON_KEY = "EllesmereUI"
local REFRESH_KEY = "Nicknames:EllesmereUI"

local refreshPending = false
local needsFullRefresh = false
local liquidHooked = false
local originalGetNicknameForEllesmereUI
local originalNameUpdates = setmetatable({}, {
    __mode = "k"
})
local wrappedTextTaggers = setmetatable({}, {
    __mode = "k"
})
local wrappedBottomTextTaggers = setmetatable({}, {
    __mode = "k"
})
local wrappedNameplateUpdaters = setmetatable({}, {
    __mode = "k"
})

local unitFrameNames = {
    "EllesmereUIUnitFrames_Player",
    "EllesmereUIUnitFrames_Target",
    "EllesmereUIUnitFrames_Focus",
    "EllesmereUIUnitFrames_TargetTarget",
    "EllesmereUIUnitFrames_FocusTarget"
}

local function SafeLower(value)
    if type(value) ~= "string" then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value:lower()
end

local function MatchesUnitName(unit, lowerName)
    local name, realm = UnitNameUnmodified(unit)
    if SafeLower(name) == lowerName then
        return true
    end
    if name and realm and realm ~= "" and SafeLower(name .. "-" .. realm) == lowerName then
        return true
    end
    return SafeLower(UnitName(unit)) == lowerName
end

local function FindUnit(characterName)
    local lowerName = SafeLower(characterName)
    if not lowerName then
        return nil
    end

    if UnitExists("player") and MatchesUnitName("player", lowerName) then
        return "player"
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and MatchesUnitName(unit, lowerName) then
                return unit
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if UnitExists(unit) and MatchesUnitName(unit, lowerName) then
                return unit
            end
        end
    end
end

local function HookLiquidAPI()
    local LiquidAPI = _G.LiquidAPI
    if liquidHooked or not LiquidAPI then
        return
    end

    originalGetNicknameForEllesmereUI = LiquidAPI.GetNicknameForEllesmereUI

    LiquidAPI.GetNicknameForEllesmereUI = function(...)
        local first, second = ...
        local characterName = type(first) == "table" and second or first

        if Nicknames:IsIntegrationActive(ADDON_KEY) then
            local unit = FindUnit(characterName)
            local nickname = unit and Nicknames:GetIfAny(unit)
            if nickname then
                return nickname
            end
        end

        if originalGetNicknameForEllesmereUI then
            return originalGetNicknameForEllesmereUI(...)
        end
    end

    liquidHooked = true
end

local function UpdateNameFontString(fontString)
    local parent = fontString.parent
    local unit = parent and (fontString.overrideUnit and parent.realUnit or parent.unit)
    local nickname = Nicknames:IsIntegrationActive(ADDON_KEY) and unit and Nicknames:GetIfAny(unit)

    if nickname then
        fontString:SetText(nickname)
        return
    end

    local originalUpdate = originalNameUpdates[fontString]
    if originalUpdate then
        return originalUpdate(fontString)
    end

    fontString:SetText(unit and UnitName(unit) or "")
end

local function PatchNameFontString(fontString)
    if not fontString or fontString._curTag ~= "[name]" or type(fontString.UpdateTag) ~= "function" then
        return
    end
    if fontString.UpdateTag == UpdateNameFontString then
        return
    end

    originalNameUpdates[fontString] = fontString.UpdateTag
    fontString.UpdateTag = UpdateNameFontString
end

local function RefreshNameFontString(fontString)
    PatchNameFontString(fontString)
    if fontString and fontString._curTag == "[name]" and fontString.UpdateTag then
        fontString:UpdateTag()
    end
end

local RefreshUnitFrame

local function WrapTextTagger(owner, methodName, wrappedTable, refreshFrame)
    local original = owner and owner[methodName]
    if type(original) ~= "function" or original == wrappedTable[owner] then
        return
    end

    local wrapped = function(...)
        local result = original(...)
        RefreshUnitFrame(refreshFrame)
        return result
    end

    wrappedTable[owner] = wrapped
    owner[methodName] = wrapped
end

RefreshUnitFrame = function(frame)
    if not frame then
        return
    end

    WrapTextTagger(frame, "_applyTextTags", wrappedTextTaggers, frame)

    RefreshNameFontString(frame.LeftText)
    RefreshNameFontString(frame.RightText)
    RefreshNameFontString(frame.CenterText)

    local bottomTextBar = frame.BottomTextBar or frame._btb
    if bottomTextBar then
        WrapTextTagger(bottomTextBar, "_applyBTBTextTags", wrappedBottomTextTaggers, frame)
        RefreshNameFontString(bottomTextBar.LeftText)
        RefreshNameFontString(bottomTextBar.RightText)
        RefreshNameFontString(bottomTextBar.CenterText)
    end
end

local function RefreshUnitFrames()
    for _, frameName in ipairs(unitFrameNames) do
        RefreshUnitFrame(_G[frameName])
    end
end

local function ApplyNameplateNickname(plate)
    if not plate or not plate.name then
        return
    end

    local unit = plate.unit
    local nameplate = plate.nameplate
    if nameplate and nameplate.namePlateUnitToken then
        unit = nameplate.namePlateUnitToken
    end

    local nickname = Nicknames:IsIntegrationActive(ADDON_KEY) and unit and Nicknames:GetIfAny(unit)
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

    if plate.UpdateName ~= wrappedNameplateUpdaters[plate] then
        local originalUpdateName = plate.UpdateName
        local wrapped = function(self, ...)
            local result = originalUpdateName(self, ...)
            ApplyNameplateNickname(self)
            return result
        end

        wrappedNameplateUpdaters[plate] = wrapped
        plate.UpdateName = wrapped
    end

    plate:UpdateName()
end

local function RefreshNameplates()
    local ns = _G.EllesmereNameplates_NS
    if not ns then
        return
    end

    if ns.plates then
        for _, plate in pairs(ns.plates) do
            RefreshNameplate(plate)
        end
    end

    if ns.friendlyPlates then
        for _, plate in pairs(ns.friendlyPlates) do
            RefreshNameplate(plate)
        end
    end
end

local function DoRefresh(fullRefresh)
    HookLiquidAPI()
    RefreshUnitFrames()
    RefreshNameplates()

    local ERF = _G.EllesmereUIRaidFrames
    if ERF and ERF.UpdateAllFrames then
        ERF:UpdateAllFrames()
    end

    if not fullRefresh or not _G._ERF_RefreshAll then
        return
    end

    if InCombatLockdown() then
        E:RunWhenOutOfCombat(REFRESH_KEY, function()
            if _G._ERF_RefreshAll then
                _G._ERF_RefreshAll()
            end
        end)
    else
        _G._ERF_RefreshAll()
    end
end

local function QueueRefresh(fullRefresh)
    needsFullRefresh = needsFullRefresh or fullRefresh
    if refreshPending then
        return
    end

    refreshPending = true
    C_Timer.After(0, function()
        local full = needsFullRefresh
        refreshPending = false
        needsFullRefresh = false
        DoRefresh(full)
    end)
end

local function Update()
    if not Nicknames:IsIntegrationActive(ADDON_KEY) then
        return
    end
    HookLiquidAPI()
    QueueRefresh(true)
end

local function OnToggle(_enabled)
    HookLiquidAPI()
    QueueRefresh(true)
end

local function Init()
    HookLiquidAPI()
    QueueRefresh(true)
end

local addonLoadFrame = CreateFrame("Frame")
addonLoadFrame:RegisterEvent("ADDON_LOADED")
addonLoadFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
addonLoadFrame:SetScript("OnEvent", function(_, event, addonName)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if Nicknames.initialized and Nicknames.initialized[ADDON_KEY] then
            QueueRefresh(false)
        end
        return
    end

    if addonName == "EllesmereUI" or addonName == "EllesmereUIRaidFrames" or addonName == "EllesmereUIUnitFrames" or
        addonName == "EllesmereUINameplates" then
        HookLiquidAPI()
        if Nicknames.initialized and Nicknames.initialized[ADDON_KEY] then
            QueueRefresh(true)
        end
    end
end)

Nicknames:RegisterIntegration(ADDON_KEY, {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
