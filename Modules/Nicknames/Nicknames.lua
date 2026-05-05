local E, L = unpack(ART)

E:RegisterModuleDefaults("Nicknames", {
    enabled = true,
    myNickname = nil,
    map = {},

    integrations = {
        Blizzard = false,
        EnhanceQoL = false,
        Cell = false,
        DandersFrames = false,
        ElvUI = false,
        Grid2 = false,
        UnhaltedUnitFrames = false,
        VuhDo = false
    }
})

local Nicknames = E:NewModule("Nicknames", "AceEvent-3.0", "AceTimer-3.0")

Nicknames.integrations = {}
Nicknames.initialized = {}

Nicknames.integrationDisplay = {{
    key = "Blizzard",
    labelKey = "Blizzard Raid Frames",
    order = 1
}, {
    key = "EnhanceQoL",
    labelKey = "Enhance QoL",
    order = 2
}, {
    key = "Cell",
    labelKey = "Cell",
    order = 3
}, {
    key = "DandersFrames",
    labelKey = "Danders Frames",
    order = 4
}, {
    key = "ElvUI",
    labelKey = "ElvUI",
    order = 5
}, {
    key = "Grid2",
    labelKey = "Grid2",
    order = 6
}, {
    key = "UnhaltedUnitFrames",
    labelKey = "Unhalted Unit Frames",
    order = 7
}, {
    key = "VuhDo",
    labelKey = "VuhDo",
    order = 8
}}

local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitNameUnmodified = UnitNameUnmodified
local UnitInRaid = UnitInRaid
local UnitInParty = UnitInParty
local GetNormalizedRealmName = GetNormalizedRealmName
local issecretvalue = _G.issecretvalue

local NICK_PREFIX_DATA = "ART_NDAT"
local NICK_PREFIX_REQUEST = "ART_NREQ"
local BROADCAST_DEBOUNCE = 2

local nicknameToUnitCache = {}

local function safeName(s)
    if type(s) ~= "string" then
        return nil
    end
    if issecretvalue and issecretvalue(s) then
        return nil
    end
    if s == "" then
        return nil
    end
    return s
end

local function realmKey(unit)
    if not unit then
        return nil
    end
    local name, realm = UnitNameUnmodified(unit)
    name = safeName(name)
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        realm = safeName(realm)
        if not realm then
            return nil
        end
    else
        realm = GetNormalizedRealmName()
    end
    if not realm or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

local function buildKey(name, realm)
    name = safeName(name)
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        realm = safeName(realm)
        if not realm then
            return nil
        end
    else
        realm = GetNormalizedRealmName()
    end
    if not realm or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

Nicknames.GetKey = realmKey

local function safeCall(addonKey, handlers, method, ...)
    local fn = handlers and handlers[method]
    if type(fn) ~= "function" then
        return true
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        Nicknames:Warn("%s %s failed: %s", addonKey, method, err)
    end
    return ok
end

function Nicknames:OnInitialize(db)
    local selfKey = realmKey("player")
    if selfKey and db.myNickname and db.myNickname ~= "" then
        db.map[selfKey] = db.myNickname
    end
end

function Nicknames:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("GROUP_FORMED", "OnGroupFormed")
    self:RegisterEvent("GROUP_LEFT", "OnGroupLeft")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")

    self._broadcastTimer = nil
    self._broadcastPending = false
    self._lastBroadcastAt = 0

    local selfKey = realmKey("player")
    if selfKey then
        local nick = self.db.myNickname
        if nick and nick ~= "" then
            self.db.map[selfKey] = nick
        else
            self.db.map[selfKey] = nil
        end
    end

    self:ValidateMap()

    self:Publish()
    self:RegisterSync()
    self:InitIntegrations()
    self:RefreshIntegrations()

    if IsInGroup() then
        self:RequestNicknames()
    end
end

function Nicknames:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    E:CancelRunWhenOutOfCombat("Nicknames:Broadcast")
    self:CancelBroadcastTimer()
    self._broadcastPending = false
    wipe(nicknameToUnitCache)

    for addonKey, handlers in pairs(self.integrations) do
        if self.initialized[addonKey] then
            safeCall(addonKey, handlers, "OnToggle", false)
        end
    end

    self:UnregisterSync()
    self:Unpublish()
end

function Nicknames:OnProfileChanged()
    wipe(nicknameToUnitCache)
    self:CancelBroadcastTimer()
    self._broadcastPending = false

    local selfKey = realmKey("player")
    if selfKey then
        local nick = self.db.myNickname
        if nick and nick ~= "" then
            self.db.map[selfKey] = nick
        else
            self.db.map[selfKey] = nil
        end
    end

    self:RefreshIntegrations()

    if IsInGroup() then
        self:RequestNicknames()
    end
end

function Nicknames:CancelBroadcastTimer()
    if self._broadcastTimer then
        self:CancelTimer(self._broadcastTimer)
        self._broadcastTimer = nil
    end
end

function Nicknames:RegisterSync()
    local Comms = E:GetModule("Comms", true)
    if not Comms or not Comms.RegisterProtocol then
        return
    end

    Comms:RegisterProtocol(NICK_PREFIX_DATA, function(_, encoded, _, sender)
        Nicknames:OnReceiveData(encoded, sender)
    end)

    Comms:RegisterProtocol(NICK_PREFIX_REQUEST, function(_, _, _, sender)
        Nicknames:OnReceiveRequest(sender)
    end)
end

function Nicknames:UnregisterSync()
    local Comms = E:GetModule("Comms", true)
    if not Comms or not Comms.UnregisterProtocol then
        return
    end
    Comms:UnregisterProtocol(NICK_PREFIX_DATA)
    Comms:UnregisterProtocol(NICK_PREFIX_REQUEST)
end

local function senderInGroup(sender)
    if not sender or sender == "" then
        return false
    end
    if UnitIsUnit(sender, "player") then
        return false
    end
    if not UnitExists(sender) then
        return false
    end
    if UnitInRaid(sender) then
        return true
    end
    if UnitInParty(sender) then
        return true
    end
    return false
end

function Nicknames:OnReceiveData(encoded, sender)
    if not self:IsEnabled() then
        return
    end
    if not senderInGroup(sender) then
        return
    end

    local Comms = E:GetEnabledModule("Comms")
    if not Comms or not Comms.DecodePayload then
        return
    end
    local data = Comms:DecodePayload(encoded)
    if type(data) ~= "table" then
        return
    end
    if type(data.name) ~= "string" or type(data.realm) ~= "string" then
        return
    end
    if type(data.nickname) ~= "string" then
        return
    end

    local key = buildKey(data.name, data.realm)
    if not key then
        return
    end

    local nickname = strtrim(data.nickname)
    if nickname == "" then
        nickname = nil
    end

    self:_storeAndPropagate(sender, key, nickname)
end

function Nicknames:OnReceiveRequest(sender)
    if not self:IsEnabled() then
        return
    end
    if not senderInGroup(sender) then
        return
    end
    self:QueueBroadcast()
end

function Nicknames:_storeAndPropagate(unit, key, nickname)
    local old = self.db.map[key]
    if old == nickname then
        return
    end

    self.db.map[key] = nickname

    if old then
        nicknameToUnitCache[old] = nil
    end
    if nickname then
        nicknameToUnitCache[nickname] = unit
    end

    for addonKey, handlers in pairs(self.integrations) do
        if self:IsIntegrationActive(addonKey) then
            safeCall(addonKey, handlers, "Update", unit, key, old, nickname)
        end
    end

    E:SendMessage("ART_NICKNAME_CHANGED", unit, old, nickname)
end

function Nicknames:RefreshIntegrations()
    if not self:IsEnabled() then
        return
    end
    for addonKey, handlers in pairs(self.integrations) do
        if self.initialized[addonKey] then
            local enabled = self.db.integrations[addonKey] and true or false
            safeCall(addonKey, handlers, "OnToggle", enabled)
        end
    end
end

function Nicknames:InvalidateCache()
    wipe(nicknameToUnitCache)
end

function Nicknames:IsIntegrationActive(addonKey)
    if not self:IsEnabled() then
        return false
    end
    if not addonKey then
        return false
    end
    if not self.db.integrations[addonKey] then
        return false
    end
    if not self.initialized[addonKey] then
        return false
    end
    return true
end

function Nicknames:GetActiveIntegrations()
    local out = {}
    if not self:IsEnabled() then
        return out
    end
    for addonKey in pairs(self.integrations) do
        if self:IsIntegrationActive(addonKey) then
            out[#out + 1] = addonKey
        end
    end
    return out
end

function Nicknames:GetIfAny(unit)
    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
        return nil
    end
    local key = realmKey(unit)
    if not key then
        return nil
    end
    return self.db.map[key]
end

function Nicknames:Get(unit)
    return self:GetIfAny(unit) or (unit and UnitNameUnmodified(unit)) or nil
end

function Nicknames:Has(unit)
    return self:GetIfAny(unit) ~= nil
end

function Nicknames:Set(unit, nickname)
    if not self:IsEnabled() then
        return
    end
    if not unit or not UnitExists(unit) then
        return
    end
    local key = realmKey(unit)
    if not key then
        return
    end

    nickname = nickname and strtrim(nickname)
    if nickname == "" then
        nickname = nil
    end

    if unit == "player" then
        self.db.myNickname = nickname
    end

    local hadChange = self.db.map[key] ~= nickname
    self:_storeAndPropagate(unit, key, nickname)

    if hadChange and unit == "player" then
        self:QueueBroadcast()
    end
end

function Nicknames:GetCharacterInGroup(nickname)
    if not self:IsEnabled() then
        return nil
    end
    if not nickname or nickname == "" then
        return nil
    end
    local cached = nicknameToUnitCache[nickname]
    if cached and UnitExists(cached) and self:GetIfAny(cached) == nickname then
        return cached
    end
    nicknameToUnitCache[nickname] = nil

    local num = GetNumGroupMembers() or 0
    if num == 0 then
        if self:GetIfAny("player") == nickname then
            nicknameToUnitCache[nickname] = "player"
            return "player"
        end
        return nil
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, num do
        local unit = prefix .. i
        if UnitExists(unit) and self:GetIfAny(unit) == nickname then
            nicknameToUnitCache[nickname] = unit
            return unit
        end
    end
    if self:GetIfAny("player") == nickname then
        nicknameToUnitCache[nickname] = "player"
        return "player"
    end
end

function Nicknames:RegisterIntegration(addonKey, handlers)
    assert(type(addonKey) == "string", "addonKey must be a string")
    assert(type(handlers) == "table", "handlers must be a table")
    self.integrations[addonKey] = handlers

    if not self:IsEnabled() then
        return
    end

    if not self.initialized[addonKey] and (addonKey == "Blizzard" or C_AddOns.IsAddOnLoaded(addonKey)) and
        handlers.Init then
        if safeCall(addonKey, handlers, "Init") then
            self.initialized[addonKey] = true
            if self.db and self.db.integrations[addonKey] then
                safeCall(addonKey, handlers, "OnToggle", true)
            end
        end
    end
end

function Nicknames:InitIntegrations()
    if not self:IsEnabled() then
        return
    end
    local changed = false
    for addonKey, handlers in pairs(self.integrations) do
        if not self.initialized[addonKey] and (addonKey == "Blizzard" or C_AddOns.IsAddOnLoaded(addonKey)) and
            handlers.Init then
            if safeCall(addonKey, handlers, "Init") then
                self.initialized[addonKey] = true
                changed = true
            end
        end
    end
    if changed then
        E:SendMessage("ART_NICKNAMES_INTEGRATIONS_UPDATED")
    end
end

function Nicknames:OnAddonLoaded(event, loadedAddon)
    if not self:IsEnabled() then
        return
    end
    local handlers = self.integrations[loadedAddon]
    if not handlers then
        return
    end
    if self.initialized[loadedAddon] then
        return
    end
    if not handlers.Init then
        return
    end

    if safeCall(loadedAddon, handlers, "Init") then
        self.initialized[loadedAddon] = true
        if self.db.integrations[loadedAddon] then
            safeCall(loadedAddon, handlers, "OnToggle", true)
        end
        E:SendMessage("ART_NICKNAMES_INTEGRATIONS_UPDATED")
    end
end

function Nicknames:SetIntegrationEnabled(addonKey, enabled)
    enabled = enabled and true or false
    self.db.integrations[addonKey] = enabled

    if not self:IsEnabled() then
        E:SendMessage("ART_NICKNAMES_INTEGRATIONS_UPDATED", addonKey, enabled)
        return
    end

    local handlers = self.integrations[addonKey]
    if handlers and not self.initialized[addonKey] and handlers.Init and
        (addonKey == "Blizzard" or C_AddOns.IsAddOnLoaded(addonKey)) then
        if safeCall(addonKey, handlers, "Init") then
            self.initialized[addonKey] = true
        end
    end

    if handlers and self.initialized[addonKey] then
        safeCall(addonKey, handlers, "OnToggle", enabled)
        if not enabled then
            safeCall(addonKey, handlers, "Cleanup")
        end
    end

    E:SendMessage("ART_NICKNAMES_INTEGRATIONS_UPDATED", addonKey, enabled)
end

function Nicknames:Substitute(text)
    if not self:IsEnabled() or type(text) ~= "string" or text == "" then
        return text
    end
    local num = GetNumGroupMembers() or 0
    if num == 0 then
        local selfName = safeName(UnitName("player"))
        local nick = selfName and self:GetIfAny("player")
        if selfName and nick and nick ~= selfName then
            return (text:gsub(selfName, nick))
        end
        return text
    end

    local prefix = IsInRaid() and "raid" or "party"
    local replacements
    for i = 0, num do
        local unit = (i == 0) and "player" or (prefix .. i)
        local name = safeName(UnitName(unit))
        local nick = name and self:GetIfAny(unit)
        if name and nick and name ~= nick then
            replacements = replacements or {}
            replacements[name] = nick
        end
    end

    if not replacements then
        return text
    end

    for name, nick in pairs(replacements) do
        text = text:gsub(name, nick)
    end
    return text
end

function Nicknames:QueueBroadcast()
    if not self:IsEnabled() then
        return
    end
    if not IsInGroup() then
        return
    end
    if self._broadcastTimer then
        return
    end

    self._broadcastTimer = self:ScheduleTimer("DoBroadcast", BROADCAST_DEBOUNCE)
end

function Nicknames:DoBroadcast()
    self._broadcastTimer = nil

    if not self:IsEnabled() or not IsInGroup() then
        return
    end
    if InCombatLockdown() then
        self._broadcastPending = true
        E:RunWhenOutOfCombat("Nicknames:Broadcast", function()
            if self:IsEnabled() and self._broadcastPending then
                self._broadcastPending = false
                self:QueueBroadcast()
            end
        end)
        return
    end
    self._broadcastPending = false

    local Comms = E:GetEnabledModule("Comms")
    if not Comms or not Comms.SendPayload then
        return
    end

    local name, realm = UnitNameUnmodified("player")
    name = safeName(name)
    if not name then
        return
    end
    if realm and realm ~= "" then
        realm = safeName(realm)
        if not realm then
            return
        end
    else
        realm = GetNormalizedRealmName()
    end
    if not realm or realm == "" then
        return
    end

    local nickname = self.db.myNickname
    if type(nickname) ~= "string" then
        nickname = ""
    end

    Comms:SendPayload(NICK_PREFIX_DATA, {
        name = name,
        realm = realm,
        nickname = nickname
    })
    self._lastBroadcastAt = GetTime()
end

function Nicknames:RequestNicknames()
    if not self:IsEnabled() or not IsInGroup() then
        return
    end
    local Comms = E:GetEnabledModule("Comms")
    if not Comms or not Comms.Broadcast then
        return
    end
    local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or
                         (IsInRaid() and "RAID" or "PARTY")
    Comms:Broadcast(NICK_PREFIX_REQUEST, "ping", chatType)
    self:QueueBroadcast()
end

function Nicknames:ValidateMap()
    if not self.db or not self.db.map then
        return
    end
    local keep = {}
    local selfKey = realmKey("player")
    if selfKey then
        keep[selfKey] = true
    end
    if IsInGroup() then
        local num = GetNumGroupMembers() or 0
        local prefix = IsInRaid() and "raid" or "party"
        for i = 1, num do
            local unit = prefix .. i
            if UnitExists(unit) then
                local key = realmKey(unit)
                if key then
                    keep[key] = true
                end
            end
        end
    end
    for key in pairs(self.db.map) do
        if not keep[key] then
            self.db.map[key] = nil
        end
    end
    wipe(nicknameToUnitCache)
end

function Nicknames:WipeMapExceptSelf()
    if not self.db or not self.db.map then
        return
    end
    local selfKey = realmKey("player")
    local selfNick = selfKey and self.db.map[selfKey]
    wipe(self.db.map)
    if selfKey and selfNick then
        self.db.map[selfKey] = selfNick
    end
    wipe(nicknameToUnitCache)
end

function Nicknames:OnGroupRosterUpdate()
    self:InvalidateCache()
    if IsInGroup() then
        self:QueueBroadcast()
    end
end

function Nicknames:OnPlayerEnteringWorld()
    self:InvalidateCache()
    self:ValidateMap()
    if IsInGroup() then
        self:RequestNicknames()
    end
end

function Nicknames:OnGroupFormed()
    if IsInGroup() then
        self:RequestNicknames()
    end
end

function Nicknames:OnGroupLeft()
    self:WipeMapExceptSelf()
    self:RefreshIntegrations()
end

local liquidAPITable

function Nicknames:RegisterLiquidAPI(api)
    liquidAPITable = api
    if self:IsEnabled() and api and _G.LiquidAPI == nil then
        _G.LiquidAPI = api
    end
end

function Nicknames:Publish()
    self._eHandle = E:MountMethods(E, {
        GetNickname = function(_, unit)
            return Nicknames:Get(unit)
        end,
        HasNickname = function(_, unit)
            return Nicknames:Has(unit)
        end,
        GetCharacterInGroup = function(_, nick)
            return Nicknames:GetCharacterInGroup(nick)
        end,
        SubstituteNicknames = function(_, text)
            return Nicknames:Substitute(text)
        end
    })

    if liquidAPITable and _G.LiquidAPI == nil then
        _G.LiquidAPI = liquidAPITable
    end
end

function Nicknames:Unpublish()
    if self._eHandle then
        self._eHandle:Unmount()
        self._eHandle = nil
    end
    if liquidAPITable and _G.LiquidAPI == liquidAPITable then
        _G.LiquidAPI = nil
    end
end

_G.ART = _G.ART or {}
E:MountMethods(_G.ART, {
    GetNickname = function(_, unit)
        if not Nicknames:IsEnabled() then
            return unit and UnitNameUnmodified(unit) or nil
        end
        return Nicknames:Get(unit)
    end,
    GetRawNickname = function(_, unit)
        if not Nicknames:IsEnabled() then
            return nil
        end
        return Nicknames:GetIfAny(unit)
    end,
    HasNickname = function(_, unit)
        if not Nicknames:IsEnabled() then
            return false
        end
        return Nicknames:Has(unit)
    end,
    GetCharacterInGroup = function(_, nick)
        if not Nicknames:IsEnabled() then
            return nil
        end
        return Nicknames:GetCharacterInGroup(nick)
    end
}, {
    noClobber = true
})
