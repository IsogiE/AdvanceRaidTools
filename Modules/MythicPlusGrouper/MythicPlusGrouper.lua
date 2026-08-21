local E, L = unpack(ART)

local MODULE_NAME = "MythicPlusGrouper"
local COMM_PREFIX = "ARTMPG2"
local LEGACY_COMM_PREFIX = "ARTMPG1"
local SCAN_TIMEOUT_SECONDS = 5
local MIN_SCAN_INTERVAL = 2
local MAX_KEYSTONE_LEVEL = 25
local issecretvalue = issecretvalue or function() return false end

local DUNGEONS = {
    {key = "alter_fangs", name = "Alter of Fangs", aliases = {"Alter of Fangs", "Altar of Fangs"}},
    {key = "den_nalorakk", name = "Den of Nalorakk"},
    {key = "murder_row", name = "Murder Row"},
    {key = "blinding_vale", name = "The Blinding Vale"},
    {key = "voidscar_arena", name = "Voidscar Arena"},
    {key = "kings_rest", name = "Kings' Rest"},
    {key = "ruby_life_pools", name = "Ruby Life Pools"},
    {key = "temple_sethraliss", name = "Temple of Sethraliss"}
}

local DUNGEON_BY_KEY = {}
for _, dungeon in ipairs(DUNGEONS) do
    DUNGEON_BY_KEY[dungeon.key] = dungeon
end

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    interests = {},
    minKeystoneLevel = 1,
    maxKeystoneLevel = MAX_KEYSTONE_LEVEL,
    timeoutSeconds = 5,
    showGroupFinder = false,
    groupFinderWidth = 500,
    groupFinderHeight = 420,
    groupFinderPoint = "CENTER",
    groupFinderRelativePoint = "CENTER",
    groupFinderX = 0,
    groupFinderY = 0
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function clamp(value, low, high)
    value = tonumber(value) or low
    return math.max(low, math.min(high, value))
end

local function safeString(value)
    if type(value) ~= "string" or issecretvalue(value) then return nil end
    value = strtrim(value)
    return value ~= "" and value or nil
end

local function safeNumber(value)
    if type(value) ~= "number" or issecretvalue(value) then return nil end
    return value
end

local function normalizeName(value)
    value = safeString(value)
    if not value then return nil, nil end
    local full = value:lower():gsub("%s+", "")
    local short = full:match("^([^%-]+)") or full
    return full, short
end

local function namesMatch(a, b)
    local fullA, shortA = normalizeName(a)
    local fullB, shortB = normalizeName(b)
    return fullA and fullB and (fullA == fullB or shortA == shortB) or false
end

local function normalizeDungeonName(value)
    value = safeString(value)
    return value and value:lower():gsub("[^%w]", "") or nil
end

local function playerFullName()
    local name, realm = UnitFullName("player")
    name = safeString(name) or safeString(UnitName("player")) or "player"
    realm = safeString(realm)
    return realm and (name .. "-" .. realm) or name
end

local function now()
    return GetServerTime and GetServerTime() or time()
end

local function isInsideInstance()
    if not IsInInstance then return false end
    local value = IsInInstance()
    if issecretvalue(value) then return false end
    return value and true or false
end

function Mod:GetDungeons()
    return DUNGEONS
end

function Mod:MatchDungeonName(name)
    local normalized = normalizeDungeonName(name)
    if not normalized then return nil end
    for _, dungeon in ipairs(DUNGEONS) do
        if normalizeDungeonName(dungeon.name) == normalized then
            return dungeon.key
        end
        for _, alias in ipairs(dungeon.aliases or {}) do
            if normalizeDungeonName(alias) == normalized then
                return dungeon.key
            end
        end
    end
    return nil
end

function Mod:GetOwnedKeystone()
    if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneLevel) then
        return nil
    end
    local okMap, mapID = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
    local okLevel, level = pcall(C_MythicPlus.GetOwnedKeystoneLevel)
    mapID = okMap and safeNumber(mapID) or nil
    level = okLevel and safeNumber(level) or nil
    if not mapID or mapID <= 0 or not level or level <= 0 then
        return nil
    end
    local mapName
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local ok, value = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        mapName = ok and safeString(value) or nil
    end
    local dungeonKey = self:MatchDungeonName(mapName)
    return {
        mapID = math.floor(mapID),
        level = math.floor(level),
        mapName = mapName,
        dungeonKey = dungeonKey
    }
end

function Mod:GetOwnNickname()
    local Nicknames = E:GetModule("Nicknames", true)
    if Nicknames and Nicknames:IsEnabled() then
        return safeString(Nicknames:GetIfAny("player"))
    end
    return nil
end

function Mod:BuildOwnState()
    local key = self:GetOwnedKeystone()
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, MAX_KEYSTONE_LEVEL))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    local interests = {}
    for dungeonKey, selected in pairs(self.db.interests or {}) do
        if selected and DUNGEON_BY_KEY[dungeonKey] then
            interests[dungeonKey] = true
        end
    end
    return {
        kind = "STATE",
        character = playerFullName(),
        nickname = self:GetOwnNickname(),
        dungeonKey = key and key.dungeonKey or nil,
        mapID = key and key.mapID or nil,
        mapName = key and key.mapName or nil,
        level = key and key.level or nil,
        minKeystoneLevel = minimum,
        maxKeystoneLevel = maximum,
        interests = interests,
        updated = now()
    }
end

function Mod:SanitizeState(payload, sender)
    if type(payload) ~= "table" or payload.kind ~= "STATE" then return nil end
    local dungeonKey = safeString(payload.dungeonKey)
    if dungeonKey and not DUNGEON_BY_KEY[dungeonKey] then dungeonKey = nil end
    local interests = {}
    if type(payload.interests) == "table" then
        for key, selected in pairs(payload.interests) do
            if selected and DUNGEON_BY_KEY[key] then interests[key] = true end
        end
    end
    local level = safeNumber(payload.level)
    if level then level = math.floor(clamp(level, 1, 100)) end
    local minimum = safeNumber(payload.minKeystoneLevel)
    local maximum = safeNumber(payload.maxKeystoneLevel)
    minimum = math.floor(clamp(minimum or 1, 1, MAX_KEYSTONE_LEVEL))
    maximum = math.floor(clamp(maximum or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    local mapID = safeNumber(payload.mapID)
    if mapID then mapID = math.floor(mapID) end
    if not dungeonKey then
        dungeonKey = self:MatchDungeonName(payload.mapName)
    end
    if not dungeonKey and mapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local ok, localMapName = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        if ok then dungeonKey = self:MatchDungeonName(localMapName) end
    end
    return {
        character = safeString(payload.character) or safeString(sender),
        nickname = safeString(payload.nickname),
        dungeonKey = dungeonKey,
        mapID = mapID,
        mapName = safeString(payload.mapName),
        level = level,
        minKeystoneLevel = minimum,
        maxKeystoneLevel = maximum,
        interests = interests,
        updated = safeNumber(payload.updated) or now()
    }
end

function Mod:StoreMember(sender, state)
    sender = safeString(sender) or (state and state.character)
    state = state and self:SanitizeState(state, sender)
    if not sender or not state then return false end
    local full = normalizeName(sender)
    if not full then return false end
    state.updated = now()
    self.members[full] = state
    if self.scan and self.scan.inProgress and not self.scan.responders[full] then
        self.scan.responders[full] = true
        self.scan.received = self.scan.received + 1
    end
    self:NotifyUpdated()
    return true
end

function Mod:StoreOwnState()
    local state = self:BuildOwnState()
    local full = normalizeName(state.character)
    if full then self.members[full] = self:SanitizeState(state, state.character) end
    return state
end

function Mod:GetComms()
    return E:GetEnabledModule("Comms")
end

function Mod:SendState(target, requestID)
    if not target or not requestID then return false end
    local Comms = self:GetComms()
    if not Comms then return false end
    local state = self:BuildOwnState()
    state.requestID = requestID
    Comms:SendPayload(COMM_PREFIX, state, target)
    return true
end

function Mod:IsScanInProgress()
    return self.scan and self.scan.inProgress or false
end

function Mod:GetScanState()
    return self.scan
end

function Mod:FinalizeScan()
    if not self.scan or not self.scan.inProgress then return end
    if self.scan.timer then
        self.scan.timer:Cancel()
        self.scan.timer = nil
    end
    self.scan.inProgress = false
    self.scan.completedAt = now()
    self:NotifyUpdated()
end

function Mod:CancelScan()
    self:FinalizeScan()
end

function Mod:RequestGuildData()
    if InCombatLockdown() then return false, "IN_COMBAT" end
    if isInsideInstance() then return false, "IN_INSTANCE" end
    if not IsInGuild() then return false, L["SharingGuildUnavailable"] end
    local Comms = self:GetComms()
    if not Comms then return false, L["LoadModule"] end

    if GetTime() - (self.lastScanStartedAt or 0) < MIN_SCAN_INTERVAL then
        return false, "TOO_SOON"
    end
    if self.scan and self.scan.timer then self.scan.timer:Cancel() end
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    wipe(self.members)
    self:StoreOwnState()

    local requestID = ("%s:%d:%d"):format(playerFullName(), now(), math.random(1000, 9999))
    self.scan = {
        requestID = requestID,
        inProgress = true,
        startedAt = now(),
        completedAt = 0,
        received = 0,
        responders = {}
    }
    self.lastScanStartedAt = GetTime()
    Comms:SendPayload(COMM_PREFIX, {kind = "REQUEST", requestID = requestID}, nil, "GUILD")
    Comms:SendPayload(LEGACY_COMM_PREFIX, {kind = "REQUEST"}, nil, "GUILD")
    local timeout = math.floor(clamp(self.db.timeoutSeconds or SCAN_TIMEOUT_SECONDS, 3, 30))
    self.scan.timer = C_Timer.NewTimer(timeout, function()
        if self:IsEnabled() then self:FinalizeScan() end
    end)
    self:NotifyUpdated()
    return true
end

function Mod:OnCommReceived(prefix, message, distribution, sender)
    if isInsideInstance() then return end
    local Comms = E:GetModule("Comms", true)
    if not Comms then return end
    local payload = Comms:DecodePayload(message)
    if type(payload) ~= "table" then return end
    if prefix == LEGACY_COMM_PREFIX then
        if payload.kind == "STATE" and distribution == "GUILD" and self.scan and self.scan.inProgress then
            self:StoreMember(sender, payload)
        end
        return
    end
    if payload.kind == "REQUEST" then
        if distribution ~= "GUILD" then return end
        local requestID = safeString(payload.requestID)
        if not requestID or InCombatLockdown() then return end
        local fullSender = normalizeName(sender)
        local lastResponse = fullSender and self.lastResponses[fullSender]
        if lastResponse and GetTime() - lastResponse < 3 then return end
        if fullSender then self.lastResponses[fullSender] = GetTime() end
        C_Timer.After(math.random(2, 12) / 10, function()
            if self:IsEnabled() and not InCombatLockdown() then
                self:SendState(sender, requestID)
            end
        end)
    elseif payload.kind == "STATE" then
        if distribution ~= "WHISPER" then return end
        if self.scan and self.scan.inProgress and safeString(payload.requestID) == self.scan.requestID then
            self:StoreMember(sender, payload)
        end
    end
end

function Mod:RegisterSync()
    if self.syncRegistered or isInsideInstance() then return end
    local Comms = E:GetModule("Comms", true)
    if Comms and Comms.RegisterProtocol then
        Comms:RegisterProtocol(COMM_PREFIX, self)
        Comms:RegisterProtocol(LEGACY_COMM_PREFIX, self)
        self.syncRegistered = true
    end
end

function Mod:UnregisterSync()
    if not self.syncRegistered then return end
    local Comms = E:GetModule("Comms", true)
    if Comms and Comms.UnregisterProtocol then
        Comms:UnregisterProtocol(COMM_PREFIX)
        Comms:UnregisterProtocol(LEGACY_COMM_PREFIX)
    end
    self.syncRegistered = nil
end

function Mod:IsInterested(dungeonKey)
    return self.db.interests and self.db.interests[dungeonKey] and true or false
end

function Mod:SetInterested(dungeonKey, selected)
    if not DUNGEON_BY_KEY[dungeonKey] then return end
    self.db.interests[dungeonKey] = selected and true or nil
    self:NotifyUpdated()
end

function Mod:SetKeystoneLevelRange(minimum, maximum)
    minimum = math.floor(clamp(minimum or 1, 1, MAX_KEYSTONE_LEVEL))
    maximum = math.floor(clamp(maximum or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    if self.db.minKeystoneLevel == minimum and self.db.maxKeystoneLevel == maximum then return end
    self.db.minKeystoneLevel = minimum
    self.db.maxKeystoneLevel = maximum
end

function Mod:BuildOnlineGuildMap()
    local online = {}
    if not IsInGuild() then return online end
    for index = 1, (GetNumGuildMembers() or 0) do
        local name, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(index)
        name = safeString(name)
        if name and not issecretvalue(isOnline) and isOnline then
            local full, short = normalizeName(name)
            if full then online[full], online[short] = true, true end
        end
    end
    local full, short = normalizeName(playerFullName())
    if full then online[full], online[short] = true, true end
    return online
end

function Mod:IsStateVisible(state, onlineMap)
    return type(state) == "table"
end

function Mod:DisplayName(state)
    return safeString(state and state.nickname) or safeString(state and state.character) or L["Unknown"] or "Unknown"
end

function Mod:GetOwners(dungeonKey)
    local result, onlineMap = {}, self:BuildOnlineGuildMap()
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, MAX_KEYSTONE_LEVEL))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    for _, state in pairs(self.members or {}) do
        if state.dungeonKey == dungeonKey and state.level and state.level >= minimum and state.level <= maximum
            and self:IsStateVisible(state, onlineMap)
        then
            result[#result + 1] = {name = self:DisplayName(state), level = state.level}
        end
    end
    table.sort(result, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name:lower() < b.name:lower()
    end)
    return result
end

function Mod:GetGuildKeystoneSummary()
    local lines = {}
    for _, dungeon in ipairs(DUNGEONS) do
        local owners = self:GetOwners(dungeon.key)
        local names = {}
        for _, owner in ipairs(owners) do names[#names + 1] = owner.name .. " +" .. owner.level end
        lines[#lines + 1] = ("|cffffffff%s|r: %s"):format(dungeon.name,
            #names > 0 and table.concat(names, ", ") or (L["MythicPlusGrouper_NoReportedKeys"] or "None reported"))
    end
    return table.concat(lines, "\n")
end

function Mod:GetOwnersText(dungeonKey)
    local owners = self:GetOwners(dungeonKey)
    if #owners == 0 then
        return L["MythicPlusGrouper_NoReportedKeys"] or "None reported"
    end
    local lines = {}
    for _, owner in ipairs(owners) do
        lines[#lines + 1] = owner.name .. "  +" .. owner.level
    end
    return table.concat(lines, "\n")
end

function Mod:GetScanResults()
    local result = {}
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, MAX_KEYSTONE_LEVEL))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    for _, state in pairs(self.members or {}) do
        local dungeon = state.dungeonKey and DUNGEON_BY_KEY[state.dungeonKey]
        local inRange = state.level and state.level >= minimum and state.level <= maximum
        result[#result + 1] = {
            name = self:DisplayName(state),
            character = state.character,
            dungeonName = dungeon and dungeon.name or nil,
            level = state.level,
            isMatch = dungeon and inRange and self:IsInterested(state.dungeonKey) or false
        }
    end
    table.sort(result, function(a, b)
        if a.isMatch ~= b.isMatch then return a.isMatch end
        if (a.dungeonName or "") ~= (b.dungeonName or "") then
            return (a.dungeonName or "") < (b.dungeonName or "")
        end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return a.name:lower() < b.name:lower()
    end)
    return result
end

function Mod:GetInterestedForOwnKey()
    local owned = self:GetOwnedKeystone()
    if not owned or not owned.dungeonKey then return owned, {} end
    local result, onlineMap = {}, self:BuildOnlineGuildMap()
    local me = playerFullName()
    for _, state in pairs(self.members or {}) do
        local minimum = math.floor(clamp(state.minKeystoneLevel or 1, 1, MAX_KEYSTONE_LEVEL))
        local maximum = math.floor(clamp(state.maxKeystoneLevel or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
        if minimum > maximum then minimum, maximum = maximum, minimum end
        if state.interests and state.interests[owned.dungeonKey]
            and owned.level >= minimum and owned.level <= maximum
            and not namesMatch(state.character, me)
            and self:IsStateVisible(state, onlineMap)
        then
            result[#result + 1] = {
                name = self:DisplayName(state),
                character = safeString(state.character)
            }
        end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return owned, result
end

function Mod:GetInterestedKeystoneOwners()
    local result, onlineMap = {}, self:BuildOnlineGuildMap()
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, MAX_KEYSTONE_LEVEL))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or MAX_KEYSTONE_LEVEL, 1, MAX_KEYSTONE_LEVEL))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    local me = playerFullName()
    for _, state in pairs(self.members or {}) do
        local dungeon = state.dungeonKey and DUNGEON_BY_KEY[state.dungeonKey]
        if dungeon and self:IsInterested(state.dungeonKey)
            and state.level and state.level >= minimum and state.level <= maximum
            and not namesMatch(state.character, me)
            and self:IsStateVisible(state, onlineMap)
        then
            result[#result + 1] = {
                name = self:DisplayName(state),
                character = safeString(state.character),
                dungeonName = dungeon.name,
                level = state.level
            }
        end
    end
    table.sort(result, function(a, b)
        if a.dungeonName ~= b.dungeonName then return a.dungeonName < b.dungeonName end
        if a.level ~= b.level then return a.level > b.level end
        return a.name:lower() < b.name:lower()
    end)
    return result
end

function Mod:InvitePlayer(character)
    character = safeString(character)
    if not character then return false end
    local InviteTool = E:GetEnabledModule("InviteTool")
    if InviteTool and InviteTool.QueueInvites then
        return (InviteTool:QueueInvites({character}) or 0) > 0
    end
    local inviteUnit = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
    if type(inviteUnit) == "function" then
        return pcall(inviteUnit, character)
    end
    return false
end

function Mod:NotifyUpdated()
    E:SendMessage("ART_MYTHIC_PLUS_GROUPER_UPDATED")
end

function Mod:RefreshOwnKey()
    if isInsideInstance() then return end
    if self.scan and (self.scan.inProgress or self.scan.completedAt > 0) then
        self:StoreOwnState()
        self:NotifyUpdated()
    end
end

function Mod:PLAYER_ENTERING_WORLD()
    if not isInsideInstance() then self:RegisterSync() end
end

function Mod:BAG_UPDATE_DELAYED()
    C_Timer.After(0.5, function()
        if self:IsEnabled() and not isInsideInstance() then self:RefreshOwnKey() end
    end)
end

function Mod:GUILD_ROSTER_UPDATE()
    if isInsideInstance() then return end
    if self.scan then self:NotifyUpdated() end
end

function Mod:ZONE_CHANGED_NEW_AREA()
    if isInsideInstance() then
        self:CancelScan()
        self:UnregisterSync()
        return
    end
    self:RegisterSync()
end

function Mod:OnProfileChanged()
    self.db.interests = self.db.interests or {}
    wipe(self.members)
    self.scan = nil
    self:NotifyUpdated()
end

function Mod:OnEnable()
    self.db.interests = self.db.interests or {}
    -- Window visibility is session-only; size and position remain persistent.
    self.db.showGroupFinder = false
    self.members = {}
    self.lastResponses = {}
    self.scan = nil
    if not isInsideInstance() then self:RegisterSync() end
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "RefreshOwnKey")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
end

function Mod:OnDisable()
    if self.scan and self.scan.timer then self.scan.timer:Cancel() end
    self:UnregisterSync()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.scan = nil
    self.members = nil
    self.lastResponses = nil
end
