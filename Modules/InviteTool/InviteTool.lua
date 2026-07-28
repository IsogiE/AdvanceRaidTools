local E, L = unpack(ART)

E:RegisterModuleDefaults("InviteTool", {
    enabled = true,
    inviteRanks = {},
    keywordEnabled = false,
    keywords = "inv",
    autoAcceptFriends = false,
    autoAcceptGuild = true,
    autoPromoteEnabled = false,
    promoteRanks = {},
    promoteNicknames = ""
})

local InviteTool = E:NewModule("InviteTool", "AceEvent-3.0")

local C_GuildInfo_GuildRoster = C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster
local C_PartyInfo_InviteUnit = C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit
local C_PartyInfo_ConvertToRaid = C_PartyInfo and C_PartyInfo.ConvertToRaid or ConvertToRaid
local issecretvalue = issecretvalue or function() return false end

local INVITE_INTERVAL = 0.2
local CONVERT_RETRY_DELAY = 0.75
local KEYWORD_THROTTLE = 2

local function safeString(value)
    if type(value) ~= "string" or issecretvalue(value) then
        return nil
    end
    value = strtrim(value)
    return value ~= "" and value or nil
end

local function normalizeName(name)
    name = safeString(name)
    if not name then
        return nil, nil
    end
    local full = name:lower():gsub("%s+", "")
    local short = full:match("^([^%-]+)") or full
    return full, short
end

local function namesMatch(a, b)
    local fullA, shortA = normalizeName(a)
    local fullB, shortB = normalizeName(b)
    if not fullA or not fullB then
        return false
    end
    return fullA == fullB or shortA == shortB
end

local function addNameKeys(map, name, value)
    local full, short = normalizeName(name)
    if full then
        map[full] = value
        map[short] = value
    end
end

local function selectedRank(tableRef, rankIndex)
    if type(tableRef) ~= "table" or type(rankIndex) ~= "number" or issecretvalue(rankIndex) then
        return false
    end
    return tableRef[rankIndex + 1] and true or false
end

local function hasSelectedRanks(tableRef)
    if type(tableRef) ~= "table" then
        return false
    end
    for _, selected in pairs(tableRef) do
        if selected then
            return true
        end
    end
    return false
end

local function canInviteToGroup()
    return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function isPlayerGrouped(name)
    name = safeString(name)
    if not name then
        return true
    end
    local playerName = GetUnitName and GetUnitName("player", true) or UnitName("player")
    return UnitInRaid(name) or UnitInParty(name) or namesMatch(name, playerName)
end

local function buildBattleNetCharacterName(info)
    if type(info) ~= "table" then
        return nil
    end
    local characterName = safeString(info.characterName)
    if not characterName then
        return nil
    end
    local realmName = safeString(info.realmName)
    local realmDisplayName = safeString(info.realmDisplayName)
    if realmName and realmDisplayName and realmDisplayName ~= GetRealmName() then
        return characterName .. "-" .. realmName
    end
    return characterName
end

function InviteTool:GetGuildRankChoices()
    local values, sorting = {}, {}
    if not IsInGuild() then
        return values, sorting
    end
    local count = GuildControlGetNumRanks and GuildControlGetNumRanks() or 0
    for rank = 1, count do
        values[rank] = GuildControlGetRankName(rank) or ("Rank " .. rank)
        sorting[#sorting + 1] = rank
    end
    return values, sorting
end

function InviteTool:IsInviteRankSelected(rank)
    rank = tonumber(rank)
    return rank and self.db.inviteRanks and self.db.inviteRanks[rank] and true or false
end

function InviteTool:SetInviteRankSelected(rank, selected)
    rank = tonumber(rank)
    if not rank then return end
    self.db.inviteRanks = self.db.inviteRanks or {}
    self.db.inviteRanks[rank] = selected and true or nil
end

function InviteTool:IsPromoteRankSelected(rank)
    rank = tonumber(rank)
    return rank and self.db.promoteRanks and self.db.promoteRanks[rank] and true or false
end

function InviteTool:SetPromoteRankSelected(rank, selected)
    rank = tonumber(rank)
    if not rank then return end
    self.db.promoteRanks = self.db.promoteRanks or {}
    self.db.promoteRanks[rank] = selected and true or nil
    self:ScheduleAutoPromote()
end

function InviteTool:RequestGuildRoster()
    if IsInGuild() and C_GuildInfo_GuildRoster then
        pcall(C_GuildInfo_GuildRoster)
    end
end

function InviteTool:BuildGuildRankMap()
    local ranks = {}
    if not IsInGuild() then
        return ranks
    end
    for index = 1, (GetNumGuildMembers() or 0) do
        local name, _, rankIndex = GetGuildRosterInfo(index)
        name = safeString(name)
        if name and type(rankIndex) == "number" and not issecretvalue(rankIndex) then
            addNameKeys(ranks, name, rankIndex + 1)
        end
    end
    return ranks
end

function InviteTool:GetGuildRankForName(name)
    local full, short = normalizeName(name)
    if not full then
        return nil
    end
    local ranks = self:BuildGuildRankMap()
    return ranks[full] or ranks[short]
end

function InviteTool:ParseKeywords()
    self.keywordSet = {}
    local text = safeString(self.db.keywords or "") or ""
    for word in text:gmatch("[^%s,;]+") do
        word = strtrim(word):lower()
        if word ~= "" then
            self.keywordSet[word] = true
        end
    end
end

function InviteTool:SetKeywords(value)
    self.db.keywords = safeString(value) or ""
    self:ParseKeywords()
end

function InviteTool:ParsePromoteNicknames()
    self.promoteNicknameSet = {}
    local text = safeString(self.db.promoteNicknames or "") or ""
    for nickname in text:gmatch("[^%s,;]+") do
        nickname = strtrim(nickname):lower()
        if nickname ~= "" then
            self.promoteNicknameSet[nickname] = true
        end
    end
end

function InviteTool:SetPromoteNicknames(value)
    self.db.promoteNicknames = safeString(value) or ""
    self:ParsePromoteNicknames()
    self:ScheduleAutoPromote()
end

function InviteTool:HasPromoteNicknames()
    return self.promoteNicknameSet and next(self.promoteNicknameSet) ~= nil
end

function InviteTool:IsKeyword(message)
    message = safeString(message)
    if not message then
        return false
    end
    return self.keywordSet and self.keywordSet[strtrim(message):lower()] and true or false
end

function InviteTool:ResolveBattleNetCharacter(accountID)
    if not accountID or issecretvalue(accountID) or not BNGetFriendIndex or not C_BattleNet then
        return nil
    end
    local friendIndex = BNGetFriendIndex(accountID)
    if not friendIndex then
        return nil
    end
    local count = C_BattleNet.GetFriendNumGameAccounts(friendIndex) or 0
    for gameIndex = 1, count do
        local info = C_BattleNet.GetFriendGameAccountInfo(friendIndex, gameIndex)
        if info
            and info.clientProgram == (BNET_CLIENT_WOW or "WoW")
            and (not info.wowProjectID or info.wowProjectID == WOW_PROJECT_ID)
            and info.isInCurrentRegion ~= false
            and info.realmID and info.realmID > 0
        then
            local player = buildBattleNetCharacterName(info)
            if player and not isPlayerGrouped(player) then
                return player
            end
        end
    end
    return nil
end

function InviteTool:IsFriendCharacter(name)
    name = safeString(name)
    if not name then
        return false
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for index = 1, (C_FriendList.GetNumFriends() or 0) do
            local info = C_FriendList.GetFriendInfoByIndex(index)
            local friendName = type(info) == "table" and info.name or info
            if namesMatch(name, friendName) then
                return true
            end
        end
    end

    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendNumGameAccounts then
        local total = BNGetNumFriends() or 0
        for friendIndex = 1, total do
            local gameCount = C_BattleNet.GetFriendNumGameAccounts(friendIndex) or 0
            for gameIndex = 1, gameCount do
                local info = C_BattleNet.GetFriendGameAccountInfo(friendIndex, gameIndex)
                if info
                    and info.clientProgram == (BNET_CLIENT_WOW or "WoW")
                    and (not info.wowProjectID or info.wowProjectID == WOW_PROJECT_ID)
                    and namesMatch(name, buildBattleNetCharacterName(info))
                then
                    return true
                end
            end
        end
    end

    return false
end

function InviteTool:HideInvitePopup()
    if StaticPopup_Hide then
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
    end
end

function InviteTool:AcceptPendingInvite(name)
    if type(AcceptGroup) ~= "function" then
        return false
    end
    local ok = pcall(AcceptGroup)
    if ok then
        self.pendingAutoAcceptName = nil
        self.pendingAutoAcceptAttempts = nil
        self:HideInvitePopup()
        E:Printf(L["InviteTool_AcceptedInvite"], name)
    end
    return ok
end

function InviteTool:ScheduleAutoAcceptRosterRetry(expectedName)
    C_Timer.After(1, function()
        if not self:IsEnabled() or self.pendingAutoAcceptName ~= expectedName then
            return
        end
        if (GetNumGuildMembers() or 0) > 0 then
            self:TryAutoAccept(expectedName, false)
            return
        end
        self.pendingAutoAcceptAttempts = (self.pendingAutoAcceptAttempts or 0) + 1
        if self.pendingAutoAcceptAttempts >= 3 then
            self.pendingAutoAcceptName = nil
            self.pendingAutoAcceptAttempts = nil
            return
        end
        self:RequestGuildRoster()
        self:ScheduleAutoAcceptRosterRetry(expectedName)
    end)
end

function InviteTool:TryAutoAccept(name, allowRosterRefresh)
    name = safeString(name)
    if not name then
        return false
    end

    if self.db.autoAcceptFriends and self:IsFriendCharacter(name) then
        self.pendingAutoAcceptName = nil
        return self:AcceptPendingInvite(name)
    end

    if self.db.autoAcceptGuild and IsInGuild() then
        if (GetNumGuildMembers() or 0) == 0 and allowRosterRefresh then
            self.pendingAutoAcceptName = name
            self.pendingAutoAcceptAttempts = 0
            self:RequestGuildRoster()
            self:ScheduleAutoAcceptRosterRetry(name)
            return false
        end
        if self:GetGuildRankForName(name) then
            self.pendingAutoAcceptName = nil
            return self:AcceptPendingInvite(name)
        end
    end

    self.pendingAutoAcceptName = nil
    self.pendingAutoAcceptAttempts = nil
    return false
end

function InviteTool:PARTY_INVITE_REQUEST(_, inviterName)
    if not self.db.autoAcceptFriends and not self.db.autoAcceptGuild then
        return
    end
    self:TryAutoAccept(inviterName, true)
end

function InviteTool:CanProcessKeyword(senderKey)
    local now = GetTime()
    self.keywordThrottle = self.keywordThrottle or {}
    local last = self.keywordThrottle[senderKey]
    if last and now - last < KEYWORD_THROTTLE then
        return false
    end
    self.keywordThrottle[senderKey] = now
    return true
end

function InviteTool:CHAT_MSG_WHISPER(_, message, sender, _, _, _, flags, _, _, _, _, _, guid)
    if not self.db.keywordEnabled or not self:IsKeyword(message) then
        return
    end
    sender = safeString(sender)
    flags = safeString(flags)
    if not sender or issecretvalue(guid) or flags == "GM" or flags == "DEV" then
        return
    end
    if self:CanProcessKeyword(sender:lower()) then
        self:QueueInvites({sender})
    end
end

function InviteTool:CHAT_MSG_BN_WHISPER(_, message, sender, ...)
    if not self.db.keywordEnabled or not self:IsKeyword(message) then
        return
    end
    local accountID = select(11, ...)
    if not accountID or issecretvalue(accountID) or (BNIsSelf and BNIsSelf(accountID)) then
        return
    end
    if not self:CanProcessKeyword("bn:" .. tostring(accountID)) then
        return
    end
    local characterName = self:ResolveBattleNetCharacter(accountID)
    if characterName then
        self:QueueInvites({characterName})
    end
end

function InviteTool:TryConvertToRaid()
    if IsInRaid() then
        return true
    end
    if not IsInGroup() then
        return false
    end
    if not UnitIsGroupLeader("player") then
        if not self.reportedConversionBlock then
            self.reportedConversionBlock = true
            E:Printf(L["InviteTool_NeedLeaderConvert"])
        end
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if type(C_PartyInfo_ConvertToRaid) == "function" then
        return pcall(C_PartyInfo_ConvertToRaid)
    end
    return false
end

function InviteTool:ScheduleInviteStep(delay)
    if self.inviteStepPending then
        return
    end
    self.inviteStepPending = true
    local serial = self.inviteSerial
    C_Timer.After(delay or 0, function()
        if not self:IsEnabled() or self.inviteSerial ~= serial then
            return
        end
        self.inviteStepPending = false
        self:ProcessInviteQueue()
    end)
end

function InviteTool:ProcessInviteQueue()
    if not self.inviteQueue or #self.inviteQueue == 0 then
        self.inviteQueued = {}
        self.partyInvitesSent = 0
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    if not canInviteToGroup() then
        if not self.reportedInviteBlock then
            self.reportedInviteBlock = true
            E:Printf(L["InviteTool_NeedInvitePermission"])
        end
        return
    end

    if IsInGroup() and not IsInRaid() then
        if self:TryConvertToRaid() then
            self:ScheduleInviteStep(CONVERT_RETRY_DELAY)
        end
        return
    end

    if not IsInRaid() and (self.partyInvitesSent or 0) >= 4 then
        return
    end

    local name = table.remove(self.inviteQueue, 1)
    if name and not isPlayerGrouped(name) and type(C_PartyInfo_InviteUnit) == "function" then
        pcall(C_PartyInfo_InviteUnit, name)
        if not IsInRaid() then
            self.partyInvitesSent = (self.partyInvitesSent or 0) + 1
        end
    end
    self:ScheduleInviteStep(INVITE_INTERVAL)
end

function InviteTool:QueueInvites(names)
    if type(names) ~= "table" or #names == 0 then
        return 0
    end
    if not canInviteToGroup() then
        E:Printf(L["InviteTool_NeedInvitePermission"])
        return 0
    end

    self.inviteQueue = self.inviteQueue or {}
    self.inviteQueued = self.inviteQueued or {}
    local added = 0
    for _, rawName in ipairs(names) do
        local name = safeString(rawName)
        local full = name and normalizeName(name)
        if name and full and not self.inviteQueued[full] and not isPlayerGrouped(name) then
            self.inviteQueued[full] = true
            self.inviteQueue[#self.inviteQueue + 1] = name
            added = added + 1
        end
    end
    if added > 0 then
        self.autoConvertPending = true
        self.autoConvertExpires = GetTime() + 120
        self.reportedInviteBlock = nil
        self.reportedConversionBlock = nil
        self:ScheduleInviteStep(0)
    end
    return added
end

function InviteTool:InviteSelectedGuildRanks(fromRosterUpdate)
    if not IsInGuild() then
        E:Printf(L["InviteTool_NotInGuild"])
        return false
    end
    if not hasSelectedRanks(self.db.inviteRanks) then
        E:Printf(L["InviteTool_SelectRank"])
        return false
    end
    if (GetNumGuildMembers() or 0) == 0 then
        if not fromRosterUpdate then
            self.pendingGuildInvite = true
            self:RequestGuildRoster()
            E:Printf(L["InviteTool_RefreshingRoster"])
        end
        return false
    end

    local names = {}
    for index = 1, GetNumGuildMembers() do
        local name, _, rankIndex, _, _, _, _, _, online, _, _, _, _, isMobile = GetGuildRosterInfo(index)
        name = safeString(name)
        local safeOnline = not issecretvalue(online) and online
        local safeMobile = not issecretvalue(isMobile) and isMobile
        if name and selectedRank(self.db.inviteRanks, rankIndex) and safeOnline and not safeMobile and not isPlayerGrouped(name) then
            names[#names + 1] = name
        end
    end

    local count = self:QueueInvites(names)
    if count > 0 then
        E:Printf(L["InviteTool_QueuedInvites"], count)
        return true
    end
    E:Printf(L["InviteTool_NoEligiblePlayers"])
    return false
end

function InviteTool:PromotePlayer(name)
    if C_PartyInfo and C_PartyInfo.PromoteToAssistant then
        return pcall(C_PartyInfo.PromoteToAssistant, name)
    elseif type(PromoteToAssistant) == "function" then
        return pcall(PromoteToAssistant, name, true)
    end
    return false
end

function InviteTool:RunAutoPromote()
    local useGuildRanks = hasSelectedRanks(self.db.promoteRanks)
    local useNicknames = self:HasPromoteNicknames()
    if not self.db.autoPromoteEnabled or (not useGuildRanks and not useNicknames) then
        return
    end
    if not IsInRaid() or not UnitIsGroupLeader("player") then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self.promoteAfterCombat = true
        return
    end
    if useGuildRanks and IsInGuild() and (GetNumGuildMembers() or 0) == 0 then
        self:RequestGuildRoster()
        return
    end

    local guildRanks = useGuildRanks and self:BuildGuildRankMap() or {}
    local Nicknames = useNicknames and E:GetModule("Nicknames", true)
    for index = 1, GetNumGroupMembers() do
        local name, raidRank = GetRaidRosterInfo(index)
        name = safeString(name)
        if name and raidRank == 0 then
            local full, short = normalizeName(name)
            local guildRank = full and (guildRanks[full] or guildRanks[short])
            local rankMatches = guildRank and self.db.promoteRanks[guildRank]
            local nicknameMatches = false
            if Nicknames and Nicknames:IsEnabled() then
                local nickname = safeString(Nicknames:GetIfAny("raid" .. index))
                nicknameMatches = nickname and self.promoteNicknameSet[nickname:lower()] and true or false
            end
            if rankMatches or nicknameMatches then
                self:PromotePlayer(name)
            end
        end
    end
end

function InviteTool:ScheduleAutoPromote()
    if self.autoPromotePending then
        return
    end
    self.autoPromotePending = true
    C_Timer.After(1, function()
        if not self:IsEnabled() then
            return
        end
        self.autoPromotePending = false
        self:RunAutoPromote()
    end)
end

function InviteTool:GROUP_ROSTER_UPDATE()
    self.reportedInviteBlock = nil
    self.reportedConversionBlock = nil
    if IsInRaid() then
        self.autoConvertPending = nil
        self.autoConvertExpires = nil
    elseif self.autoConvertPending and self.autoConvertExpires and GetTime() > self.autoConvertExpires then
        self.autoConvertPending = nil
        self.autoConvertExpires = nil
    elseif IsInGroup() and self.autoConvertPending then
        self:TryConvertToRaid()
    end
    if self.inviteQueue and #self.inviteQueue > 0 then
        self:ScheduleInviteStep(CONVERT_RETRY_DELAY)
    end
    self:ScheduleAutoPromote()
end

function InviteTool:GUILD_ROSTER_UPDATE()
    if self.pendingGuildInvite then
        self.pendingGuildInvite = nil
        self:InviteSelectedGuildRanks(true)
    end
    if self.pendingAutoAcceptName and (GetNumGuildMembers() or 0) > 0 then
        self:TryAutoAccept(self.pendingAutoAcceptName, false)
    end
    self:ScheduleAutoPromote()
end

function InviteTool:PLAYER_REGEN_ENABLED()
    if self.inviteQueue and #self.inviteQueue > 0 then
        self:ScheduleInviteStep(0)
    end
    if self.promoteAfterCombat then
        self.promoteAfterCombat = nil
        self:ScheduleAutoPromote()
    end
end

function InviteTool:ART_NICKNAME_CHANGED()
    self:ScheduleAutoPromote()
end

function InviteTool:OnEnable()
    self.db.inviteRanks = self.db.inviteRanks or {}
    self.db.promoteRanks = self.db.promoteRanks or {}
    self.inviteQueue = self.inviteQueue or {}
    self.inviteQueued = self.inviteQueued or {}
    self.inviteSerial = (self.inviteSerial or 0) + 1
    self.partyInvitesSent = 0
    self:ParseKeywords()
    self:ParsePromoteNicknames()
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER")
    self:RegisterEvent("PARTY_INVITE_REQUEST")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterMessage("ART_NICKNAME_CHANGED")
    self:RequestGuildRoster()
end

function InviteTool:OnDisable()
    self.inviteSerial = (self.inviteSerial or 0) + 1
    self.inviteStepPending = nil
    self.autoPromotePending = nil
    self.pendingGuildInvite = nil
    self.pendingAutoAcceptName = nil
    self.pendingAutoAcceptAttempts = nil
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end
