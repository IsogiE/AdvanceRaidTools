local E = unpack(ART)

local Data = {}
E.ReadyCheckData = Data

Data.FOOD_SPELLS = {
    [308488] = true,
    [308506] = true,
    [308434] = true,
    [308514] = true,
    [327708] = true,
    [327706] = true,
    [327709] = true,
    [308525] = true,
    [327707] = true,
    [308637] = true,
    [308474] = true,
    [308504] = true,
    [308430] = true,
    [308509] = true,
    [327704] = true,
    [327701] = true,
    [327705] = true,
    [327702] = true,
    [341449] = true,
    [382145] = true,
    [382150] = true,
    [382146] = true,
    [382149] = true,
    [396092] = true,
    [382246] = true,
    [382247] = true,
    [382152] = true,
    [382153] = true,
    [382157] = true,
    [382230] = true,
    [382231] = true,
    [382232] = true,
    [382154] = true,
    [382155] = true,
    [382156] = true,
    [382234] = true,
    [382235] = true,
    [382236] = true
}

Data.FLASK_SPELLS = {
    [1235057] = true,
    [1235111] = true,
    [1235110] = true,
    [1235108] = true,
    [432021] = true,
    [432473] = true,
    [431971] = true,
    [431972] = true,
    [431974] = true,
    [431973] = true,
    [371339] = true,
    [374000] = true,
    [371354] = true,
    [371204] = true,
    [370662] = true,
    [373257] = true,
    [371386] = true,
    [370652] = true,
    [371172] = true,
    [371186] = true,
    [307187] = true,
    [307185] = true,
    [307166] = true
}

Data.RUNE_SPELLS = {
    [224001] = true,
    [270058] = true,
    [317065] = true,
    [347901] = true,
    [367405] = true,
    [393438] = true,
    [453250] = true,
    [1234969] = true,
    [1242347] = true,
    [1264426] = true
}

Data.RAID_BUFF_SPELLS = {
    intellect = {
        [1459] = true,
        [264760] = true
    },
    stamina = {
        [21562] = true,
        [264764] = true
    },
    attackPower = {
        [6673] = true,
        [264761] = true
    },
    versatility = {
        [1126] = true
    },
    mastery = {
        [462854] = true
    },
    movement = {
        [381758] = true,
        [381732] = true,
        [381741] = true,
        [381746] = true,
        [381748] = true,
        [381750] = true,
        [381749] = true,
        [381751] = true,
        [381752] = true,
        [381753] = true,
        [381754] = true,
        [381756] = true,
        [381757] = true
    }
}

-- Keep equivalent ranks and fleeting variants together. A secure action can
-- safely choose within one effect family, but must not guess between different
-- stat flasks when the player owns several.
Data.FLASK_ITEM_GROUPS = {
    {
        241320,
        245926,
        241321,
        245927
    },
    {
        241322,
        245933,
        241323,
        245932
    },
    {
        241324,
        245931,
        241325,
        245930
    },
    {
        241326,
        245929,
        241327,
        245928
    }
}

Data.RUNE_ITEMS = {
    259085,
    246492,
    243191,
    224572,
    211495
}

local RANGED_WEAPON_SUBCLASSES = {
    [2] = true, -- Bow
    [3] = true, -- Gun
    [18] = true -- Crossbow
}

local OIL_WEAPON_SUBCLASSES = {
    [0] = true,
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [17] = true,
    [18] = true,
    [19] = true
}

-- Only temporary weapon consumables belong here. Permanent enchants are read
-- from equipped item links instead, matching NSRT's gear check. Compatibility
-- metadata keeps secure actions from targeting ammunition or stones at an
-- invalid weapon.
Data.WEAPON_ENCHANT_ITEM_GROUPS = {
    {
        items = {
            257750,
            257749
        },
        mainHandOnly = true,
        subclasses = RANGED_WEAPON_SUBCLASSES
    },
    {
        items = {
            257752,
            257751
        },
        mainHandOnly = true,
        subclasses = RANGED_WEAPON_SUBCLASSES
    },
    {
        items = {
            243734,
            243733
        },
        minimumItemLevel = 120,
        subclasses = OIL_WEAPON_SUBCLASSES
    },
    {
        items = {
            243736,
            243735
        },
        minimumItemLevel = 120,
        subclasses = OIL_WEAPON_SUBCLASSES
    },
    {
        items = {
            243738,
            243737
        },
        minimumItemLevel = 120,
        subclasses = OIL_WEAPON_SUBCLASSES
    },
    {
        items = {
            237369,
            237367
        },
        subclasses = {
            [4] = true, -- One-handed mace
            [5] = true, -- Two-handed mace
            [10] = true, -- Staff
            [13] = true -- Fist weapon
        }
    },
    {
        items = {
            237371,
            237370
        },
        subclasses = {
            [0] = true, -- One-handed axe
            [1] = true, -- Two-handed axe
            [6] = true, -- Polearm
            [7] = true, -- One-handed sword
            [8] = true, -- Two-handed sword
            [9] = true, -- Warglaive
            [13] = true, -- Fist weapon
            [15] = true -- Dagger
        }
    }
}

Data.PERMANENT_ENCHANT_SLOTS = {
    {
        slot = 1,
        label = "HEADSLOT",
        fallback = "Head"
    },
    {
        slot = 3,
        label = "SHOULDERSLOT",
        fallback = "Shoulders"
    },
    {
        slot = 5,
        label = "CHESTSLOT",
        fallback = "Chest"
    },
    {
        slot = 7,
        label = "LEGSSLOT",
        fallback = "Legs"
    },
    {
        slot = 8,
        label = "FEETSLOT",
        fallback = "Feet"
    },
    {
        slot = 11,
        label = "FINGER0SLOT",
        fallback = "Finger 1"
    },
    {
        slot = 12,
        label = "FINGER1SLOT",
        fallback = "Finger 2"
    },
    {
        slot = 16,
        label = "MAINHANDSLOT",
        fallback = "Main Hand"
    },
    {
        slot = 17,
        label = "SECONDARYHANDSLOT",
        fallback = "Off Hand"
    }
}

Data.HEALTHSTONE_ITEMS = {
    5512,
    224464
}
Data.HEALTHSTONE_ITEM = Data.HEALTHSTONE_ITEMS[1]

local function valueIsAccessible(value)
    local ok, secret = pcall(E.IsSecret, E, value)
    return ok and not secret
end

local function safeString(value)
    if not valueIsAccessible(value) then
        return nil
    end

    local ok, result = pcall(E.SafeString, E, value)
    if not ok then
        return nil
    end
    return result
end

local function readAuraField(auraData, key)
    if not valueIsAccessible(auraData) then
        return nil, false
    end

    local ok, value = pcall(function()
        return auraData[key]
    end)
    if not ok or not valueIsAccessible(value) then
        return nil, false
    end
    return value, true
end

local function getEquippedItemLink(slot)
    local ok, link = pcall(GetInventoryItemLink, "player", slot)
    if not ok or not valueIsAccessible(link) then
        return nil, false
    end
    return link, true
end

local function getItemInfoInstant(item)
    if not C_Item or type(C_Item.GetItemInfoInstant) ~= "function" then
        return nil, nil, false
    end

    local ok, _, _, _, _, _, classID, subclassID =
        pcall(C_Item.GetItemInfoInstant, item)
    if not ok or not valueIsAccessible(classID) or
        not valueIsAccessible(subclassID) or type(classID) ~= "number" or
        type(subclassID) ~= "number" then
        return nil, nil, false
    end
    return classID, subclassID, true
end

local function getDetailedItemLevel(item)
    if not C_Item or type(C_Item.GetDetailedItemLevelInfo) ~= "function" then
        return nil, false
    end

    local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, item)
    if not ok or not valueIsAccessible(itemLevel) or
        type(itemLevel) ~= "number" then
        return nil, false
    end
    return itemLevel, true
end

function Data:GetPermanentEnchantState()
    local missing = {}
    local armorClassID =
        Enum and Enum.ItemClass and Enum.ItemClass.Armor or 4

    for _, entry in ipairs(self.PERMANENT_ENCHANT_SLOTS) do
        local link, linkAvailable = getEquippedItemLink(entry.slot)
        if not linkAvailable then
            return false, false, {}
        end

        if link then
            local skip = false
            if entry.slot == 17 then
                local classID, _, infoAvailable = getItemInfoInstant(link)
                if not infoAvailable then
                    return false, false, {}
                end
                skip = classID == armorClassID
            end

            if not skip then
                local canonicalLink = link
                if C_Item and type(C_Item.GetItemInfo) == "function" then
                    local ok, resolvedLink =
                        pcall(function()
                            return select(2, C_Item.GetItemInfo(link))
                        end)
                    if ok and valueIsAccessible(resolvedLink) and resolvedLink then
                        canonicalLink = resolvedLink
                    end
                end

                if type(canonicalLink) ~= "string" then
                    return false, false, {}
                end
                local enchantField =
                    canonicalLink:match("item:[^:]+:([^:]*)")
                if enchantField == nil then
                    return false, false, {}
                end
                if (tonumber(enchantField) or 0) <= 0 then
                    missing[#missing + 1] =
                        _G[entry.label] or entry.fallback
                end
            end
        end
    end

    return #missing == 0, true, missing
end

function Data:CanScanAuras()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or not valueIsAccessible(secret) then
            return false
        end
        if secret then
            return false
        end
    end

    return C_UnitAuras and
        (type(C_UnitAuras.GetUnitAuraBySpellID) == "function" or
            type(C_UnitAuras.GetUnitAuras) == "function" or
            type(C_UnitAuras.GetAuraDataByIndex) == "function") or false
end

local vantusPrefix
local wellFedName

local function getSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok then
            return safeString(name)
        end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok then
            return safeString(name)
        end
    end
end

function Data:GetVantusPrefix()
    if vantusPrefix ~= nil then
        return vantusPrefix or nil
    end

    local name = getSpellName(1276691) or getSpellName(237825)
    if type(name) == "string" then
        vantusPrefix = name:match("^(.-)[:%-]")
    end
    if not vantusPrefix or vantusPrefix == "" then
        vantusPrefix = "Vantus Rune"
    end
    return vantusPrefix
end

function Data:GetWellFedName()
    if wellFedName then
        return wellFedName
    end

    -- "Well Fed" is shared by food from different expansions. Resolving its
    -- localized aura name avoids a spell-ID update for every new food item.
    wellFedName = getSpellName(19705) or getSpellName(308488)
    return wellFedName
end

local function blankScan()
    return {
        food = false,
        flask = false,
        rune = false,
        vantus = false,
        intellect = false,
        stamina = false,
        attackPower = false,
        versatility = false,
        mastery = false,
        movement = false,
        details = {}
    }
end

local function storeDetail(result, key, auraData, spellID)
    result[key] = true
    local icon, iconAvailable = readAuraField(auraData, "icon")
    local expirationTime, expirationAvailable =
        readAuraField(auraData, "expirationTime")
    result.details[key] = {
        icon = iconAvailable and icon or nil,
        expirationTime = expirationAvailable and expirationTime or nil,
        spellID = spellID
    }
end

local function getAuraBySpellID(unit, spellID)
    if not C_UnitAuras or
        type(C_UnitAuras.GetUnitAuraBySpellID) ~= "function" then
        return nil, false
    end

    local ok, auraData =
        pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    if not ok then
        return nil, false
    end

    -- A protected result is not evidence that every aura on the unit is
    -- unavailable. Treat only this lookup as unreadable and continue.
    if not valueIsAccessible(auraData) then
        return nil, true
    end
    return auraData, true
end

local function getAuraBySpellName(unit, spellName)
    if not C_UnitAuras or
        type(C_UnitAuras.GetAuraDataBySpellName) ~= "function" then
        return nil, false
    end

    local ok, auraData =
        pcall(C_UnitAuras.GetAuraDataBySpellName, unit, spellName)
    if not ok then
        return nil, false
    end
    if not valueIsAccessible(auraData) then
        return nil, true
    end
    return auraData, true
end

local function scanSpellSet(result, key, unit, spellSet)
    local queried = false
    for spellID in pairs(spellSet) do
        local auraData, available = getAuraBySpellID(unit, spellID)
        if available then
            queried = true
        end
        if auraData then
            storeDetail(result, key, auraData, spellID)
            break
        end
    end
    return queried
end

local function scanFood(self, result, unit)
    local queried = false
    local foodName = self:GetWellFedName()

    -- The localized Well Fed name covers foods whose spell IDs have not yet
    -- been added to the fallback list.
    if type(foodName) == "string" then
        local auraData, available = getAuraBySpellName(unit, foodName)
        if available then
            queried = true
        end
        if auraData then
            local spellID, spellIDAvailable =
                readAuraField(auraData, "spellId")
            if not spellIDAvailable or type(spellID) ~= "number" then
                spellID = nil
            end
            storeDetail(result, "food", auraData, spellID)
        end
    end

    if not result.food and
        scanSpellSet(result, "food", unit, self.FOOD_SPELLS) then
        queried = true
    end
    return queried
end

local function scanVantus(self, result, unit)
    if not C_UnitAuras or
        type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then
        return false
    end

    local queried = false
    local prefix = self:GetVantusPrefix()
    for index = 1, 100 do
        local ok, auraData =
            pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok then
            break
        end
        queried = true

        if valueIsAccessible(auraData) then
            if not auraData then
                break
            end

            local auraName, nameAvailable = readAuraField(auraData, "name")
            if nameAvailable and type(auraName) == "string" and
                type(prefix) == "string" and
                auraName:find(prefix, 1, true) then
                local spellID, spellIDAvailable =
                    readAuraField(auraData, "spellId")
                if not spellIDAvailable or type(spellID) ~= "number" then
                    spellID = nil
                end
                storeDetail(result, "vantus", auraData, spellID)
                break
            end
        end
    end
    return queried
end

local function scanKnownAuras(self, result, unit)
    local queried = scanFood(self, result, unit)

    if scanSpellSet(result, "flask", unit, self.FLASK_SPELLS) then
        queried = true
    end
    if scanSpellSet(result, "rune", unit, self.RUNE_SPELLS) then
        queried = true
    end
    for key, spellSet in pairs(self.RAID_BUFF_SPELLS) do
        if scanSpellSet(result, key, unit, spellSet) then
            queried = true
        end
    end
    if scanVantus(self, result, unit) then
        queried = true
    end

    return queried
end

local function collectAurasByIndex(unit)
    if not C_UnitAuras or
        type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then
        return nil, false
    end

    local auras = {}
    for index = 1, 255 do
        local ok, auraData =
            pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok then
            return nil, false
        end
        if valueIsAccessible(auraData) then
            if not auraData then
                break
            end
            auras[#auras + 1] = auraData
        end
    end
    return auras, true
end

local function collectAuras(unit)
    if C_UnitAuras and type(C_UnitAuras.GetUnitAuras) == "function" then
        local ok, auras = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
        if ok then
            if valueIsAccessible(auras) and type(auras) == "table" then
                return auras, true
            end
        end
    end

    return collectAurasByIndex(unit)
end

local function processAuras(self, result, auras)
    local vantus = self:GetVantusPrefix()
    local foodName = self:GetWellFedName()
    for _, auraData in ipairs(auras) do
        if valueIsAccessible(auraData) then
            local spellID, spellIDAvailable =
                readAuraField(auraData, "spellId")
            if not spellIDAvailable or type(spellID) ~= "number" then
                spellID = nil
            end

            local auraName
            if not result.food or not result.vantus then
                auraName = readAuraField(auraData, "name")
            end

            if (spellID and self.FOOD_SPELLS[spellID]) or
                (not result.food and foodName and auraName == foodName) then
                storeDetail(result, "food", auraData, spellID)
            elseif spellID and self.FLASK_SPELLS[spellID] then
                storeDetail(result, "flask", auraData, spellID)
            elseif spellID and self.RUNE_SPELLS[spellID] then
                storeDetail(result, "rune", auraData, spellID)
            end

            if spellID then
                for key, spellTable in pairs(self.RAID_BUFF_SPELLS) do
                    if spellTable[spellID] then
                        storeDetail(result, key, auraData, spellID)
                    end
                end
            end

            if not result.vantus and type(vantus) == "string" and
                type(auraName) == "string" and
                auraName:find(vantus, 1, true) then
                storeDetail(result, "vantus", auraData, spellID)
            end
        end
    end

    return true
end

function Data:ScanUnit(unit)
    local result = blankScan()
    if not self:CanScanAuras() then
        return result, false
    end

    if C_UnitAuras and
        type(C_UnitAuras.GetUnitAuraBySpellID) == "function" then
        local ok, available =
            pcall(scanKnownAuras, self, result, unit)
        if ok and available then
            return result, true
        end
        result = blankScan()
    end

    local ok, auras, available = pcall(collectAuras, unit)
    if not ok or not available or type(auras) ~= "table" then
        return result, false
    end

    local processed, scanAvailable = pcall(processAuras, self, result, auras)
    if not processed or not scanAvailable then
        return blankScan(), false
    end

    return result, true
end

function Data:FormatRemaining(expirationTime)
    if not valueIsAccessible(expirationTime) or type(expirationTime) ~= "number" or
        expirationTime <= 0 then
        return ""
    end

    local seconds = math.max(0, expirationTime - GetTime())
    if seconds >= 60 then
        return ("%dm"):format(math.ceil(seconds / 60))
    end
    return ("%ds"):format(math.ceil(seconds))
end

local function getItemCount(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID, false, true) or 0
    end
    return GetItemCount(itemID, false, true) or 0
end

function Data:FindOwnedItem(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        local count = getItemCount(itemID)
        if count > 0 then
            return itemID, count
        end
    end
end

function Data:FindOwnedItemGroup(itemGroups)
    local firstOwnedItem
    local total = 0
    local ownedGroups = 0

    for _, group in ipairs(itemGroups) do
        local items = group.items or group
        local firstInGroup
        for _, itemID in ipairs(items) do
            local count = getItemCount(itemID)
            total = total + count
            if count > 0 and not firstInGroup then
                firstInGroup = itemID
            end
        end

        if firstInGroup then
            ownedGroups = ownedGroups + 1
            firstOwnedItem = firstOwnedItem or firstInGroup
        end
    end

    return firstOwnedItem, total, ownedGroups
end

local function weaponGroupIsCompatible(group, slot, subclassID, itemLevel)
    if group.mainHandOnly and slot ~= 16 then
        return false
    end
    if group.minimumItemLevel and itemLevel < group.minimumItemLevel then
        return false
    end
    return not group.subclasses or group.subclasses[subclassID] == true
end

function Data:FindOwnedWeaponEnhancement(slot)
    local link, linkAvailable = getEquippedItemLink(slot)
    if not linkAvailable then
        return nil, 0, 0, false
    end
    if not link then
        return nil, 0, 0, true
    end

    local classID, subclassID, infoAvailable = getItemInfoInstant(link)
    if not infoAvailable then
        return nil, 0, 0, false
    end

    local weaponClassID =
        Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
    if classID ~= weaponClassID then
        return nil, 0, 0, true
    end

    local itemLevel, levelAvailable = getDetailedItemLevel(link)
    if not levelAvailable then
        return nil, 0, 0, false
    end

    local firstOwnedItem
    local total = 0
    local ownedGroups = 0
    for _, group in ipairs(self.WEAPON_ENCHANT_ITEM_GROUPS) do
        if weaponGroupIsCompatible(group, slot, subclassID, itemLevel) then
            local firstInGroup
            for _, itemID in ipairs(group.items) do
                local count = getItemCount(itemID)
                total = total + count
                if count > 0 and not firstInGroup then
                    firstInGroup = itemID
                end
            end
            if firstInGroup then
                ownedGroups = ownedGroups + 1
                firstOwnedItem = firstOwnedItem or firstInGroup
            end
        end
    end

    return firstOwnedItem, total, ownedGroups, true
end

function Data:GetTotalItemCount(itemIDs)
    local total = 0
    for _, itemID in ipairs(itemIDs) do
        total = total + getItemCount(itemID)
    end
    return total
end

function Data:GetItemTexture(itemID)
    if C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID)
    end
    if GetItemIcon then
        return GetItemIcon(itemID)
    end
end

local function getShortName(unit, fullName)
    local shortName
    if type(E.GetNickname) == "function" then
        local ok, nickname = pcall(E.GetNickname, E, unit)
        if ok then
            shortName = safeString(nickname)
        end
    end

    if not shortName or shortName == "" then
        local ok, bareName = pcall(E.BareName, E, fullName)
        if ok then
            shortName = safeString(bareName)
        end
    end

    return shortName
end

local function getRosterEntry(unit, subgroup)
    local ok, fullName = pcall(E.GetUnitFullName, E, unit, true)
    fullName = ok and safeString(fullName) or nil
    if not fullName or fullName == "" then
        return nil
    end

    local class
    ok, _, class = pcall(UnitClass, unit)
    class = ok and safeString(class) or nil
    if not class then
        return nil
    end

    local shortName = getShortName(unit, fullName)
    if not shortName or shortName == "" then
        return nil
    end

    return {
        unit = unit,
        fullName = fullName,
        shortName = shortName,
        class = class,
        subgroup = subgroup
    }
end

local function getUnitExists(unit)
    local ok, exists = pcall(UnitExists, unit)
    if not ok or not valueIsAccessible(exists) then
        return false, false
    end
    return exists and true or false, true
end

function Data:GetRoster()
    local roster = {}

    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local unit = "raid" .. index
            local exists, available = getUnitExists(unit)
            if not available then
                return {}
            end
            if exists then
                local ok, _, _, subgroup = pcall(GetRaidRosterInfo, index)
                if not ok or not valueIsAccessible(subgroup) or
                    type(subgroup) ~= "number" then
                    return {}
                end

                local entry = getRosterEntry(unit, subgroup)
                if not entry then
                    return {}
                end
                roster[#roster + 1] = entry
            end
        end
    else
        local units = {"player"}
        for index = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. index
        end

        for _, unit in ipairs(units) do
            local exists, available = getUnitExists(unit)
            if not available then
                return {}
            end
            if exists then
                local entry = getRosterEntry(unit, 1)
                if not entry then
                    return {}
                end
                roster[#roster + 1] = entry
            end
        end
    end

    table.sort(roster, function(a, b)
        if a.subgroup ~= b.subgroup then
            return a.subgroup < b.subgroup
        end
        return a.shortName < b.shortName
    end)
    return roster
end
