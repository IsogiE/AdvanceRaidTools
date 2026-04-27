local E = _G.ART and _G.ART[1]
local Nicknames = E and E:GetModule("Nicknames", true)

-- Might as well keep it supported for now till prepatch, and in case they somehow keep using it in the future
-- Thanks Ironi <3
local unitIDs = {
    player = true,
    focus = true,
    focustarget = true,
    target = true,
    targettarget = true,
    mouseover = true,
    npc = true,
    vehicle = true,
    pet = true
}

for i = 1, 4 do
    unitIDs["party" .. i] = true
    unitIDs["party" .. i .. "target"] = true
end

for i = 1, 40 do
    unitIDs["raid" .. i] = true
    unitIDs["raid" .. i .. "target"] = true
end

for i = 1, 40 do
    unitIDs["nameplate" .. i] = true
    unitIDs["nameplate" .. i .. "target"] = true
end

for i = 1, 15 do
    unitIDs["boss" .. i .. "target"] = true
end

local LiquidAPI = {
    GetName = function(_, characterName, formatting, atlasSize)
        if not characterName then
            error("LiquidAPI:GetName(characterName[, formatting, atlasSize]), characterName is nil")
            return
        end

        local unit
        local lowerCharName = characterName:lower()

        if unitIDs[lowerCharName] and UnitExists(lowerCharName) then
            unit = lowerCharName
        elseif E and E.GetCharacterInGroup then
            unit = E:GetCharacterInGroup(characterName)
            if not unit then
                for i = 1, GetNumGroupMembers() do
                    local currentUnit = "raid" .. i
                    if UnitExists(currentUnit) then
                        local name = E:SafeString(UnitNameUnmodified(currentUnit))
                        if name and name:lower() == lowerCharName then
                            unit = currentUnit
                            break
                        end
                    end
                end
            end
        end

        local displayName
        if unit and E and E.GetNickname then
            displayName = E:GetNickname(unit)
        else
            displayName = characterName
        end

        if not formatting then
            return displayName
        end

        if not unit then
            return displayName, "%s", ""
        end

        local classFileName = UnitClassBase(unit)
        local colorStr = (classFileName and RAID_CLASS_COLORS[classFileName] and
                             RAID_CLASS_COLORS[classFileName].colorStr) or "ffffffff"
        local colorFormat = string.format("|c%s%%s|r", colorStr)

        local role = UnitGroupRolesAssigned(unit)
        local roleAtlas = (role == "TANK" and "Role-Tank-SM") or (role == "HEALER" and "Role-Healer-SM") or
                              (role == "DAMAGER" and "Role-DPS-SM")
        local roleIcon = roleAtlas and CreateAtlasMarkup(roleAtlas, atlasSize or 12, atlasSize or 12) or ""

        return displayName, colorFormat, roleIcon, RAID_CLASS_COLORS[classFileName] or {}
    end,

    GetCharacterInGroup = function(_, nickname)
        if not nickname or not E or not E.GetCharacterInGroup then
            return nil
        end

        local unit = E:GetCharacterInGroup(nickname)

        if unit and UnitExists(unit) then
            local characterName = E:SafeString(UnitNameUnmodified(unit))
            local guid = UnitGUID(unit)
            local classFileName = UnitClassBase(unit)

            if characterName and guid and classFileName and RAID_CLASS_COLORS[classFileName] then
                local colorFormat = string.format("|c%s%%s|r", RAID_CLASS_COLORS[classFileName].colorStr)
                return characterName, colorFormat, guid
            end
        end

        return nil
    end,

    GetCharacters = function(_, nickname)
        if not nickname then
            error("LiquidAPI:GetCharacters(nickname), nickname is nil")
            return
        end

        local chars = {}
        local found = false

        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            if UnitExists(unit) and E and E.HasNickname and E:HasNickname(unit) then
                local currentNickname = E:GetNickname(unit)
                if currentNickname and currentNickname:lower() == nickname:lower() then
                    local unitName = E:SafeString(UnitNameUnmodified(unit))
                    if unitName then
                        chars[unitName] = true
                        found = true
                    end
                end
            end
        end

        if found then
            return chars
        end
        return nil
    end
}

-- published on OnEnable, cleared on OnDisable
if Nicknames and Nicknames.RegisterLiquidAPI then
    Nicknames:RegisterLiquidAPI(LiquidAPI)
end
