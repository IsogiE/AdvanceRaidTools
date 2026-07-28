local E, L = unpack(ART)

local MODULE_NAME = "MythicPlusGrouper"
local COMM_PREFIX = "ARTMPG1"
local RECENT_SECONDS = 1800
local MIN_WIDTH, MIN_HEIGHT = 260, 100
local issecretvalue = issecretvalue or function() return false end

local SEASONS = {
    season1 = {
        key = "season1",
        name = "Season 1",
        dungeons = {
            {key = "magisters_terrace", name = "Magister's Terrace"},
            {key = "maisara_caverns", name = "Maisara Caverns"},
            {key = "nexus_point_xenas", name = "Nexus-Point Xenas"},
            {key = "windrunner_spire", name = "Windrunner Spire"},
            {key = "algethar_academy", name = "Algeth'ar Academy"},
            {key = "pit_of_saron", name = "Pit of Saron"},
            {key = "seat_triumvirate", name = "Seat of the Triumvirate"},
            {key = "skyreach", name = "Skyreach"}
        }
    },
    season2 = {
        key = "season2",
        name = "Season 2",
        dungeons = {
            {key = "alter_fangs", name = "Alter of Fangs", aliases = {"Alter of Fangs", "Altar of Fangs"}},
            {key = "den_nalorakk", name = "Den of Nalorakk"},
            {key = "murder_row", name = "Murder Row"},
            {key = "blinding_vale", name = "The Blinding Vale"},
            {key = "voidscar_arena", name = "Voidscar Arena"},
            {key = "kings_rest", name = "Kings' Rest"},
            {key = "ruby_life_pools", name = "Ruby Life Pools"},
            {key = "temple_sethraliss", name = "Temple of Sethraliss"}
        }
    }
}

local SEASON_ORDER = {"season1", "season2"}
local DUNGEONS, DUNGEON_BY_KEY = {}, {}
for _, seasonKey in ipairs(SEASON_ORDER) do
    local season = SEASONS[seasonKey]
    for _, dungeon in ipairs(season.dungeons) do
        dungeon.season = seasonKey
        DUNGEONS[#DUNGEONS + 1] = dungeon
        DUNGEON_BY_KEY[dungeon.key] = dungeon
    end
end

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    selectedSeason = "season2",
    interests = {},
    members = {},
    showWindow = true,
    unlocked = false,
    hideInInstance = false,
    minKeystoneLevel = 1,
    maxKeystoneLevel = 20,
    backgroundEnabled = true,
    borderEnabled = true,
    backgroundColor = {r = 0, g = 0, b = 0, a = 0.72},
    borderColor = {r = 0.35, g = 0.35, b = 0.35, a = 1},
    fontName = "PT Sans Narrow",
    fontSize = 14,
    fontOutline = "OUTLINE",
    textColor = {r = 1, g = 1, b = 1, a = 1},
    point = "CENTER",
    relativePoint = "CENTER",
    x = 360,
    y = 120,
    width = 360,
    height = 190
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

function Mod:GetSeasons()
    local result = {}
    for _, seasonKey in ipairs(SEASON_ORDER) do
        result[#result + 1] = SEASONS[seasonKey]
    end
    return result
end

function Mod:GetSelectedSeason()
    return SEASONS[self.db.selectedSeason] and self.db.selectedSeason or "season2"
end

function Mod:SetSelectedSeason(seasonKey)
    if not SEASONS[seasonKey] then return false end
    if self.db.selectedSeason == seasonKey then return false end
    self.db.selectedSeason = seasonKey
    return true
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
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, 20))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or 20, 1, 20))
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
    minimum = math.floor(clamp(minimum or 1, 1, 20))
    maximum = math.floor(clamp(maximum or 20, 1, 20))
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
    self.db.members[full] = state
    self:NotifyUpdated()
    return true
end

function Mod:StoreOwnState()
    local state = self:BuildOwnState()
    local full = normalizeName(state.character)
    if full then self.db.members[full] = self:SanitizeState(state, state.character) end
    return state
end

function Mod:GetComms()
    return E:GetEnabledModule("Comms")
end

function Mod:BroadcastState()
    if isInsideInstance() then return false end
    if not IsInGuild() then return false end
    local Comms = self:GetComms()
    if not Comms then return false end
    local state = self:StoreOwnState()
    Comms:SendPayload(COMM_PREFIX, state, nil, "GUILD")
    self:NotifyUpdated()
    return true
end

function Mod:RequestGuildData()
    if isInsideInstance() then return false end
    if not IsInGuild() then return false, L["SharingGuildUnavailable"] end
    if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
    local Comms = self:GetComms()
    if not Comms then return false, L["LoadModule"] end
    self:BroadcastState()
    Comms:SendPayload(COMM_PREFIX, {kind = "REQUEST"}, nil, "GUILD")
    return true
end

function Mod:OnCommReceived(_, message, distribution, sender)
    if isInsideInstance() then return end
    if distribution ~= "GUILD" then return end
    local Comms = E:GetModule("Comms", true)
    if not Comms then return end
    local payload = Comms:DecodePayload(message)
    if type(payload) ~= "table" then return end
    if payload.kind == "REQUEST" then
        if self.requestResponseTimer then
            return
        end
        self.requestResponseTimer = C_Timer.NewTimer(math.random(2, 12) / 10, function()
            self.requestResponseTimer = nil
            if self:IsEnabled() then self:BroadcastState() end
        end)
    elseif payload.kind == "STATE" then
        self:StoreMember(sender, payload)
    end
end

function Mod:RegisterSync()
    if self.syncRegistered or isInsideInstance() then return end
    local Comms = E:GetModule("Comms", true)
    if Comms and Comms.RegisterProtocol then
        Comms:RegisterProtocol(COMM_PREFIX, self)
        self.syncRegistered = true
    end
end

function Mod:UnregisterSync()
    if not self.syncRegistered then return end
    local Comms = E:GetModule("Comms", true)
    if Comms and Comms.UnregisterProtocol then
        Comms:UnregisterProtocol(COMM_PREFIX)
    end
    self.syncRegistered = nil
end

function Mod:IsInterested(dungeonKey)
    return self.db.interests and self.db.interests[dungeonKey] and true or false
end

function Mod:SetInterested(dungeonKey, selected)
    if not DUNGEON_BY_KEY[dungeonKey] then return end
    self.db.interests[dungeonKey] = selected and true or nil
    self:BroadcastState()
    self:NotifyUpdated()
end

function Mod:SetKeystoneLevelRange(minimum, maximum)
    minimum = math.floor(clamp(minimum or 1, 1, 20))
    maximum = math.floor(clamp(maximum or 20, 1, 20))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    if self.db.minKeystoneLevel == minimum and self.db.maxKeystoneLevel == maximum then return end
    self.db.minKeystoneLevel = minimum
    self.db.maxKeystoneLevel = maximum
    self:NotifyUpdated()
    if self.levelRangeBroadcastTimer then
        self.levelRangeBroadcastTimer:Cancel()
    end
    self.levelRangeBroadcastTimer = C_Timer.NewTimer(0.5, function()
        self.levelRangeBroadcastTimer = nil
        if self:IsEnabled() then
            self:BroadcastState()
        end
    end)
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
    if type(state) ~= "table" then return false end
    local full, short = normalizeName(state.character)
    if IsInGuild() and (GetNumGuildMembers() or 0) > 0 then
        return full and (onlineMap[full] or onlineMap[short]) and true or false
    end
    return now() - (tonumber(state.updated) or 0) <= RECENT_SECONDS
end

function Mod:DisplayName(state)
    return safeString(state and state.nickname) or safeString(state and state.character) or L["Unknown"] or "Unknown"
end

function Mod:GetOwners(dungeonKey)
    local result, onlineMap = {}, self:BuildOnlineGuildMap()
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, 20))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or 20, 1, 20))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    for _, state in pairs(self.db.members or {}) do
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

function Mod:GetInterestedForOwnKey()
    local owned = self:GetOwnedKeystone()
    if not owned or not owned.dungeonKey then return owned, {} end
    local result, onlineMap = {}, self:BuildOnlineGuildMap()
    local me = playerFullName()
    for _, state in pairs(self.db.members or {}) do
        local minimum = math.floor(clamp(state.minKeystoneLevel or 1, 1, 20))
        local maximum = math.floor(clamp(state.maxKeystoneLevel or 20, 1, 20))
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
    local minimum = math.floor(clamp(self.db.minKeystoneLevel or 1, 1, 20))
    local maximum = math.floor(clamp(self.db.maxKeystoneLevel or 20, 1, 20))
    if minimum > maximum then minimum, maximum = maximum, minimum end
    local me = playerFullName()
    for _, state in pairs(self.db.members or {}) do
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

function Mod:GetWindowText()
    local _, interested = self:GetInterestedForOwnKey()
    local owners = self:GetInterestedKeystoneOwners()
    local lines = {}
    if #interested > 0 then
        lines[#lines + 1] = L["MythicPlusGrouper_InterestedPlayers"]
        for _, player in ipairs(interested) do
            lines[#lines + 1] = player.name
        end
    end
    if #owners > 0 then
        if #lines > 0 then lines[#lines + 1] = "" end
        lines[#lines + 1] = L["MythicPlusGrouper_InterestedKeystoneOwners"]
        for _, player in ipairs(owners) do
            lines[#lines + 1] = ("%s  %s +%d"):format(player.name, player.dungeonName, player.level)
        end
    end
    return table.concat(lines, "\n")
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

local function acquireWindowRow(frame, index)
    frame.rows = frame.rows or {}
    local row = frame.rows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, frame)
    row:SetHeight(20)
    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", 0, 0)
    label:SetPoint("RIGHT", -70, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    row.label = label
    local invite = CreateFrame("Button", nil, row, "BackdropTemplate")
    E:SetTemplate(invite, "Default")
    invite:SetSize(62, 20)
    invite:SetPoint("RIGHT", 0, 0)
    invite:RegisterForClicks("AnyUp")
    local inviteText = invite:CreateFontString(nil, "OVERLAY")
    E:RegisterFontString(inviteText, 0)
    inviteText:SetPoint("CENTER")
    inviteText:SetText(L["MythicPlusGrouper_Invite"] or "Invite")
    invite.label = inviteText
    invite:SetScript("OnClick", function(button)
        if button.character then Mod:InvitePlayer(button.character) end
    end)
    row.invite = invite
    frame.rows[index] = row
    return row
end

function Mod:RefreshWindowContent(interested, owners)
    local frame = self.frame
    if not frame then return end
    interested = interested or {}
    owners = owners or {}
    frame.headers = frame.headers or {}
    for index = 1, 2 do
        if not frame.headers[index] then
            local header = frame:CreateFontString(nil, "OVERLAY")
            header:SetJustifyH("LEFT")
            header:SetWordWrap(false)
            frame.headers[index] = header
        end
        frame.headers[index]:Hide()
    end
    for _, row in ipairs(frame.rows or {}) do row:Hide() end

    local outline = self.db.fontOutline or "OUTLINE"
    if outline == "NONE" then outline = "" end
    local font = E:FetchFont(self.db.fontName)
    local fontSize = clamp(self.db.fontSize, 8, 40)
    local color = type(self.db.textColor) == "table" and self.db.textColor or {}
    local r, g = clamp(color.r or color[1] or 1, 0, 1), clamp(color.g or color[2] or 1, 0, 1)
    local b, a = clamp(color.b or color[3] or 1, 0, 1), clamp(color.a or color[4] or 1, 0, 1)
    local y, rowIndex = -8, 0

    local function addSection(headerText, entries, labelBuilder)
        if #entries == 0 then return end
        local headerIndex = rowIndex == 0 and 1 or 2
        local header = frame.headers[headerIndex]
        E:ApplyFontString(header, font, fontSize, outline)
        header:SetTextColor(r, g, b, a)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
        header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, y)
        header:SetText(headerText)
        header:Show()
        y = y - math.max(20, fontSize + 5)
        for _, entry in ipairs(entries) do
            rowIndex = rowIndex + 1
            local row = acquireWindowRow(frame, rowIndex)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y)
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, y)
            E:ApplyFontString(row.label, font, fontSize, outline)
            row.label:SetTextColor(r, g, b, a)
            row.label:SetText(labelBuilder(entry))
            row.invite.character = entry.character
            row.invite:SetEnabled(entry.character and true or false)
            row:Show()
            y = y - math.max(20, fontSize + 4)
        end
        y = y - 8
    end

    addSection(L["MythicPlusGrouper_InterestedPlayers"], interested, function(entry)
        return entry.name
    end)
    addSection(L["MythicPlusGrouper_InterestedKeystoneOwners"], owners, function(entry)
        return ("%s  -  %s +%d"):format(entry.name, entry.dungeonName, entry.level)
    end)
end

function Mod:ApplyFrameBackdrop()
    local frame = self.frame
    if not frame then return end
    local background = type(self.db.backgroundColor) == "table" and self.db.backgroundColor or {}
    local border = type(self.db.borderColor) == "table" and self.db.borderColor or {}
    if self.db.backgroundEnabled ~= false then
        frame:SetBackdropColor(clamp(background.r or background[1] or 0, 0, 1),
            clamp(background.g or background[2] or 0, 0, 1), clamp(background.b or background[3] or 0, 0, 1),
            clamp(background.a or background[4] or 0.72, 0, 1))
    else
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if self.db.borderEnabled ~= false then
        frame:SetBackdropBorderColor(clamp(border.r or border[1] or 0.35, 0, 1),
            clamp(border.g or border[2] or 0.35, 0, 1), clamp(border.b or border[3] or 0.35, 0, 1),
            clamp(border.a or border[4] or 1, 0, 1))
    else
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function Mod:SaveFramePosition()
    local frame = self.frame
    if not frame then return end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    self.db.point = point or "CENTER"
    self.db.relativePoint = relativePoint or self.db.point
    self.db.x = math.floor((x or 0) + 0.5)
    self.db.y = math.floor((y or 0) + 0.5)
    self.db.width = math.floor((frame:GetWidth() or 360) + 0.5)
    self.db.height = math.floor((frame:GetHeight() or 190) + 0.5)
end

function Mod:BuildFrame()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", "ARTMythicPlusGrouperFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT) end
    E:SetTemplate(frame, "Default")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if Mod.db.unlocked and not InCombatLockdown() then frame:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        Mod:SaveFramePosition()
    end)

    local grip = CreateFrame("Frame", nil, frame)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:EnableMouse(true)
    local texture = grip:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 1, 0.35)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and Mod.db.unlocked and not InCombatLockdown() then frame:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        Mod:SaveFramePosition()
        Mod:RefreshFrame()
    end)
    frame.grip = grip

    frame:SetPoint(self.db.point or "CENTER", UIParent, self.db.relativePoint or "CENTER", self.db.x or 360, self.db.y or 120)
    frame:SetSize(clamp(self.db.width, MIN_WIDTH, 1200), clamp(self.db.height, MIN_HEIGHT, 1200))
    self.frame = frame
    self:ApplyFrameBackdrop()
    return frame
end

function Mod:ApplyFramePosition(allowInInstance)
    local frame = self:BuildFrame()
    frame:ClearAllPoints()
    frame:SetPoint(self.db.point or "CENTER", UIParent, self.db.relativePoint or "CENTER", self.db.x or 360, self.db.y or 120)
    frame:SetSize(clamp(self.db.width, MIN_WIDTH, 1200), clamp(self.db.height, MIN_HEIGHT, 1200))
    self:RefreshFrame(allowInInstance)
end

function Mod:SetUnlocked(value)
    self.db.unlocked = value and true or false
    self:RefreshFrame()
end

function Mod:RefreshFrame(allowInInstance)
    if not self:IsEnabled() then return end
    local inInstance = isInsideInstance()
    if inInstance and self.db.hideInInstance then
        if self.frame then self.frame:Hide() end
        return
    end
    if inInstance and not allowInInstance then
        return
    end
    local frame = self:BuildFrame()
    local _, interested = self:GetInterestedForOwnKey()
    local owners = self:GetInterestedKeystoneOwners()
    if not self.db.showWindow
        or (not self.db.unlocked and #interested == 0 and #owners == 0)
        or (not self.db.unlocked and self.db.hideInInstance and inInstance)
    then
        frame:Hide()
        return
    end
    frame:Show()
    self:ApplyFrameBackdrop()
    frame:EnableMouse(self.db.unlocked and true or false)
    if self.db.unlocked then frame.grip:Show() else frame.grip:Hide() end
    self:RefreshWindowContent(interested, owners)
end

function Mod:NotifyUpdated()
    if not isInsideInstance() then self:RefreshFrame() end
    E:SendMessage("ART_MYTHIC_PLUS_GROUPER_UPDATED")
    if E.RefreshOptions then E:RefreshOptions() end
end

function Mod:RefreshOwnKey()
    if isInsideInstance() then return end
    local state = self:BuildOwnState()
    local signature = table.concat({state.dungeonKey or "", state.mapID or 0, state.level or 0, state.nickname or "",
        state.minKeystoneLevel or 1, state.maxKeystoneLevel or 20}, ":")
    self:StoreOwnState()
    if signature ~= self.lastOwnSignature then
        self.lastOwnSignature = signature
        self:BroadcastState()
    else
        self:NotifyUpdated()
    end
end

function Mod:PLAYER_ENTERING_WORLD()
    if self.worldTimer then
        self.worldTimer:Cancel()
    end
    self.worldTimer = C_Timer.NewTimer(3, function()
        self.worldTimer = nil
        if self:IsEnabled() and not isInsideInstance() then
            self:RegisterSync()
            self:RequestGuildData()
            self:RefreshOwnKey()
        end
    end)
end

function Mod:BAG_UPDATE_DELAYED()
    if self.bagTimer then
        self.bagTimer:Cancel()
    end
    self.bagTimer = C_Timer.NewTimer(0.5, function()
        self.bagTimer = nil
        if self:IsEnabled() and not isInsideInstance() then self:RefreshOwnKey() end
    end)
end

function Mod:GUILD_ROSTER_UPDATE()
    if isInsideInstance() then return end
    self:NotifyUpdated()
end

function Mod:ZONE_CHANGED_NEW_AREA()
    if isInsideInstance() then
        self:UnregisterSync()
        if self.db.hideInInstance and self.frame then self.frame:Hide() end
        return
    end
    self:RegisterSync()
    self:RequestGuildData()
    self:RefreshOwnKey()
end

function Mod:OnProfileChanged()
    self.db.interests = self.db.interests or {}
    self.db.members = self.db.members or {}
    self.db.selectedSeason = self:GetSelectedSeason()
    self:ApplyFramePosition()
    self:RefreshOwnKey()
end

function Mod:OnEnable()
    self.db.interests = self.db.interests or {}
    self.db.members = self.db.members or {}
    self.db.selectedSeason = self:GetSelectedSeason()
    if not isInsideInstance() then self:RegisterSync() end
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "RefreshOwnKey")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    self:RegisterMessage("ART_MEDIA_UPDATED", "RefreshFrame")
    self:ApplyFramePosition(true)
    self:RefreshOwnKey()
end

function Mod:OnDisable()
    for _, key in ipairs({
        "requestResponseTimer",
        "levelRangeBroadcastTimer",
        "worldTimer",
        "bagTimer"
    }) do
        local timer = self[key]
        if timer then
            timer:Cancel()
            self[key] = nil
        end
    end
    self:UnregisterSync()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.frame then self.frame:Hide() end
end
