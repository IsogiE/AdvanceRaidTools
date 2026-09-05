local E = unpack(ART)

local NoteTargets = {}
E.NoteTargets = NoteTargets

local ROLE_TAGS = {
    tanks = "TANK",
    healers = "HEALER",
    dps = "DAMAGER"
}

local MELEE_SPECS = {
    [65] = true, [70] = true, [71] = true, [72] = true,
    [103] = true, [251] = true, [252] = true, [255] = true,
    [259] = true, [260] = true, [261] = true, [263] = true,
    [269] = true, [270] = true, [577] = true
}

local function normalize(token)
    token = E:SafeString(token)
    if not token then return "" end
    token = E:StripColorCodes(token):gsub("|T.-|t", "")
    return (token:gsub("^%s+", ""):gsub("%s+$", "")):lower()
end

local function publicNumber(value)
    if E:IsSecret(value) then return nil end
    return tonumber(value)
end

function NoteTargets:GetPlayerIdentifiers()
    local name = normalize(UnitName("player"))
    local full = normalize(E:GetUnitFullName("player", true))
    local nickname = E.GetNickname and normalize(E:GetNickname("player")) or ""
    return {
        name = name,
        full = full,
        nickname = nickname ~= "" and nickname or nil
    }
end

function NoteTargets:IsPlayerToken(token, ids)
    token = normalize(token)
    if token == "" then return false end
    ids = ids or self:GetPlayerIdentifiers()
    return token == ids.name or token == ids.full or token == ids.nickname
end

function NoteTargets:GetPlayerContext()
    local role = E:SafeString(E:GetUnitRole("player")) or E:SafeString(E:GetPlayerRole())
    local specIndex = GetSpecialization and publicNumber(GetSpecialization())
    local specID = specIndex and GetSpecializationInfo and publicNumber(GetSpecializationInfo(specIndex))
    local _, class, classID = UnitClass("player")
    local subgroup = 1
    local raidIndex = UnitInRaid and publicNumber(UnitInRaid("player"))
    if raidIndex and GetRaidRosterInfo then
        subgroup = publicNumber(select(3, GetRaidRosterInfo(raidIndex)))
    end
    local position
    if role == "TANK" or (specID and MELEE_SPECS[specID]) then
        position = "melee"
    elseif specID then
        position = "ranged"
    end
    return {
        ids = self:GetPlayerIdentifiers(),
        role = role,
        specID = specID,
        class = normalize(class),
        classID = publicNumber(classID),
        subgroup = subgroup,
        position = position
    }
end

function NoteTargets:GetPlayerContextKey(context)
    context = context or self:GetPlayerContext()
    return table.concat({context.role or "", context.specID or "", context.subgroup or ""}, ":")
end

function NoteTargets:MatchesPlayer(targets, context)
    targets = normalize(targets)
    if targets == "" then return false end
    context = context or self:GetPlayerContext()
    for token in targets:gmatch("[^,%s]+") do
        if token == "everyone" or self:IsPlayerToken(token, context.ids) then
            return true
        end
        local role = ROLE_TAGS[token]
        if role and role == context.role then return true end
        if token == context.position or token == context.class then return true end
        local id = tonumber(token)
        if id and (id == context.classID or id == context.specID) then return true end
        local subgroup = tonumber(token:match("^group([1-8])$"))
        if subgroup and subgroup == context.subgroup then return true end
    end
    return false
end
