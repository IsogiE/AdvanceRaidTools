local E = unpack(ART)

local issecretvalue = issecretvalue or function() return false end

local MIGHTY_THUD_SPELL_ID = 1296092
local ROUSE_THE_BROOD_SPELL_ID = 1308356
local RAVENOUS_FEAST_SPELL_ID = 1290516
local VENOM_COAGULATION_SPELL_ID = 1284251
local UNSTABLE_MIASMA_SPELL_ID = 1288232

local ENTOMBED_HIDDEN_CASTS = {
    green = {
        [VENOM_COAGULATION_SPELL_ID] = {
            [2] = true, [3] = true, [6] = true,
            [7] = true, [10] = true, [11] = true
        },
        [UNSTABLE_MIASMA_SPELL_ID] = {
            [1] = true, [4] = true, [5] = true,
            [8] = true, [9] = true
        }
    },
    red = {
        [VENOM_COAGULATION_SPELL_ID] = {
            [1] = true, [4] = true, [5] = true,
            [8] = true, [9] = true
        },
        [UNSTABLE_MIASMA_SPELL_ID] = {
            [2] = true, [3] = true, [6] = true,
            [7] = true, [10] = true, [11] = true
        }
    }
}

local function getReadyAssignmentContext()
    local bossMods = E:GetModule("BossMods", true)
    local ready = bossMods and bossMods.ReadyAssignments

    if not ready or not ready.BuildContext
        or not ready.FindPlayerInHashTag
        or not ready.NormalizeTag
        or not ready.Words
        or not ready.TokenIsPlayer
    then
        return nil, nil
    end

    local nicknames = E:GetModule("Nicknames", true)

    if nicknames and nicknames.SyncSelfNickname then
        nicknames:SyncSelfNickname()
    end

    local context = ready:BuildContext()
    local configuredNickname = nicknames
        and nicknames.db
        and nicknames.db.myNickname

    if type(configuredNickname) == "string"
        and configuredNickname ~= ""
        and context
    then
        context.ids = context.ids or {}
        context.ids.nickname = configuredNickname:lower()
    end

    return ready, context
end

local function findPlayerPositionInHashTag(ready, context, tag, maxPosition)
    tag = ready:NormalizeTag(tag)

    if not tag or not context or not context.tags then
        return nil
    end

    for _, section in ipairs(context.tags[tag] or {}) do
        local text = section.text or section.headerText or ""
        local words = ready:Words(text)

        for position = 1, math.min(#words, maxPosition) do
            if ready:TokenIsPlayer(words[position], context) then
                return position
            end
        end
    end
end

local function findPlayerHitsInTags(ready, context, prefix, count)
    local hits = {}
    local found

    for hit = 1, count do
        if ready:FindPlayerInHashTag(
            context,
            prefix .. hit,
            { hashtagMultiline = true }
        ) then
            hits[hit] = true
            found = true
        end
    end

    return found and hits or nil
end

local function isMightyThudAbility(ability)
    local spellID = ability and tonumber(ability.spellID)
    local triggerSpellID = ability and tonumber(ability.triggerSpellID)

    return spellID == MIGHTY_THUD_SPELL_ID
        or spellID == -MIGHTY_THUD_SPELL_ID
        or triggerSpellID == MIGHTY_THUD_SPELL_ID
end

local function getAbilityAssignment(ability)
    local spellID = ability and tonumber(ability.spellID)
    local mightyThud = isMightyThudAbility(ability)

    if not mightyThud
        and spellID ~= ROUSE_THE_BROOD_SPELL_ID
        and spellID ~= RAVENOUS_FEAST_SPELL_ID
    then
        return nil
    end

    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    local assignments = {}

    if mightyThud then
        for hit = 1, 3 do
            if ready:FindPlayerInHashTag(
                context,
                "LEThud" .. hit,
                { hashtagMultiline = true }
            ) then
                assignments[#assignments + 1] = "Soak Thud " .. hit
            end
        end
    elseif spellID == ROUSE_THE_BROOD_SPELL_ID then
        for addNumber = 1, 10 do
            local position = findPlayerPositionInHashTag(
                ready,
                context,
                "TFKick" .. addNumber,
                2
            )

            if position then
                local order = position == 1 and "First" or "Second"
                assignments[#assignments + 1] =
                    "Kick Add " .. addNumber .. " " .. order
            end
        end
    else
        local hits = findPlayerHitsInTags(ready, context, "TFFeast", 3)

        for hit = 1, 3 do
            if hits and hits[hit] then
                assignments[#assignments + 1] = "Soak Hit " .. hit
            end
        end
    end

    return #assignments > 0 and table.concat(assignments, " | ") or nil
end

local function getAssignedHits(kind)
    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    if kind == "mightyThud" then
        return findPlayerHitsInTags(ready, context, "LEThud", 3)
    elseif kind == "ravenousFeast" then
        return findPlayerHitsInTags(ready, context, "TFFeast", 3)
    end
end

local function getEntombedAssignment()
    local _, _, difficultyID = GetInstanceInfo()

    if not issecretvalue(difficultyID) and tonumber(difficultyID) == 16 then
        if not IsInRaid or not IsInRaid() then
            return nil
        end

        local raidIndex = UnitInRaid and UnitInRaid("player")
        if type(raidIndex) ~= "number" or issecretvalue(raidIndex) then
            return nil
        end

        local subgroup = select(3, GetRaidRosterInfo(raidIndex))
        if type(subgroup) ~= "number" or issecretvalue(subgroup) then
            return nil
        end

        if subgroup == 1 or subgroup == 2 then
            return "green"
        elseif subgroup == 3 or subgroup == 4 then
            return "red"
        end

        return nil
    end

    local ready, context = getReadyAssignmentContext()

    if not ready then
        return nil
    end

    local green = ready:FindPlayerInHashTag(
        context,
        "ESGreen",
        { hashtagMultiline = true }
    )
    local red = ready:FindPlayerInHashTag(
        context,
        "ESRed",
        { hashtagMultiline = true }
    )

    if green and not red then
        return "green"
    elseif red and not green then
        return "red"
    end
end

local function resetEncounterTracking(self)
    self.entombedCastCounts = self.entombedCastCounts or {}
    self.entombedLastCast = self.entombedLastCast or {}
    wipe(self.entombedCastCounts)
    wipe(self.entombedLastCast)
    self.entombedAssignment = nil
    self.entombedAssignmentResolved = false
end

local function shouldSuppressCast(self, spellID)
    spellID = tonumber(spellID)

    if spellID ~= VENOM_COAGULATION_SPELL_ID
        and spellID ~= UNSTABLE_MIASMA_SPELL_ID
    then
        return false
    end

    self.entombedCastCounts = self.entombedCastCounts or {}
    self.entombedLastCast = self.entombedLastCast or {}

    local now = GetTime()
    local lastCast = self.entombedLastCast[spellID]

    if lastCast and now - lastCast.time < 1 then
        return lastCast.suppressed == true
    end

    local castNumber = (self.entombedCastCounts[spellID] or 0) + 1
    self.entombedCastCounts[spellID] = castNumber

    if not self.entombedAssignmentResolved then
        self.entombedAssignment = getEntombedAssignment()
        self.entombedAssignmentResolved = true
    end

    local hiddenCasts = self.entombedAssignment
        and ENTOMBED_HIDDEN_CASTS[self.entombedAssignment]
    local filteringEnabled = not self.db
        or self.db.entombedAssignmentFilteringEnabled ~= false
    local suppressed = filteringEnabled
        and hiddenCasts
        and hiddenCasts[spellID]
        and hiddenCasts[spellID][castNumber]
        or false

    self.entombedLastCast[spellID] = {
        time = now,
        suppressed = suppressed
    }

    return suppressed
end

E:CreateAbilityAlertsModule({
    moduleName = "BossMods_VenomousAbyssAbilityAlerts",
    featurePrefix = "VenomousAbyss",
    getAbilityData = function()
        return E.VenomousAbyssAbilityData or {}
    end,
    abilitySettingsMigration = {
        aliases = {
            [1284103] = 1292036,
            [1289855] = 1305421,
            [1284606] = 1284588,
            [1296061] = 1291759,
            [1296025] = 1290711,
            [1297625] = 1296249,
            [1285419] = 1285425,
            [1286620] = 1286573,
            [1285643] = 1289900,
            [1299267] = 1299266
        },
        merged = {
            [-1288232] = 1288232,
            [-1296025] = 1290711,
            [-1281907] = 1281907,
            [-1282525] = 1282525,
            [-1285419] = 1285425,
            [-1282487] = 1282487,
            [-1286895] = 1286895,
            [-1298381] = 1298381
        }
    },
    extraDefaults = {
        entombedAssignmentFilteringEnabled = true
    },
    presetVersionField = "venomousBarPresetVersion",
    enableAllBarsMigrationField = "enableAllVenomousBarsMigration",
    defaultBarEnabledWhenUnset = true,
    getAbilityAssignment = getAbilityAssignment,
    getAssignedHits = getAssignedHits,
    resetEncounterTracking = resetEncounterTracking,
    shouldSuppressCast = shouldSuppressCast
})
