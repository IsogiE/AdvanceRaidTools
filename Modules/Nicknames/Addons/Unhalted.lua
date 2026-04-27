local E, L, P = unpack(ART)
local Nicknames = E:GetModule("Nicknames")

local nicknameMethods = {}
local hookedTags = {}
local tags

local function GetColoredNickname(unit, maxChars)
    local name = Nicknames:GetIfAny(unit)

    if name and maxChars then
        name = string.sub(name, 1, maxChars)
    end

    local class = UnitClassBase(unit)
    local color = class and C_ClassColor.GetClassColor(class)

    if color and name then
        return color:WrapTextInColorCode(name)
    else
        return name
    end
end

local function Update()
    if not _G.UUFG then
        return
    end
    if not tags then
        return
    end

    for tagName in pairs(nicknameMethods) do
        if tags.RefreshMethods then
            tags:RefreshMethods(tagName)
        end
    end
end

local function OnToggle(_enabled)
    Update()
end

local function Init()
    local UUFG = _G.UUFG
    if not UUFG then
        return
    end
    if not UUFG.GetTags then
        return
    end

    tags = UUFG:GetTags()
    if not tags or not tags.Methods then
        return
    end

    nicknameMethods = {
        ["name"] = function(unit)
            return Nicknames:GetIfAny(unit)
        end,
        ["name:colour"] = function(unit)
            return GetColoredNickname(unit)
        end
    }

    for i = 1, 25 do
        nicknameMethods["name:short:" .. i] = function(unit)
            local name = Nicknames:GetIfAny(unit)
            return name and string.sub(name, 1, i)
        end

        nicknameMethods["name:short:" .. i .. ":colour"] = function(unit)
            return GetColoredNickname(unit, i)
        end
    end

    for tagName, NicknameMethod in pairs(nicknameMethods) do
        local OriginalMethod = tags.Methods[tagName]

        if OriginalMethod and not hookedTags[tagName] then
            hookedTags[tagName] = true

            tags.Methods[tagName] = function(unit)
                local useNicknameMethod = Nicknames:IsIntegrationActive("UnhaltedUnitFrames") and
                                              Nicknames:GetIfAny(unit)

                if useNicknameMethod then
                    return NicknameMethod(unit)
                else
                    return OriginalMethod(unit)
                end
            end
        end
    end

    Update()
end

Nicknames:RegisterIntegration("UnhaltedUnitFrames", {
    Init = Init,
    Update = Update,
    OnToggle = OnToggle
})
