local E, L, P = unpack(ART)

P.modules.Comms = {
    enabled = true
}

local Comms = E:NewModule("Comms", "AceEvent-3.0", "AceComm-3.0")

local LibSerialize = E.Libs.LibSerialize
local LibDeflate = E.Libs.LibDeflate

-- Combat lockdown queues and state
local receiveQueue = {}
local sendQueue = {}
local registeredProtocols = {}
local registeredSyncs = {}
local lastRosterGUIDs = {}

function Comms:OnEnable()
    -- re-bind anything registered while we were disabled
    for prefix in pairs(registeredProtocols) do
        self:RegisterComm(prefix, "OnProtocolMessage")
    end

    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRosterDelta")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterDelta")

    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
end

function Comms:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:UnregisterAllComm()
    wipe(lastRosterGUIDs)
    wipe(receiveQueue)
    wipe(sendQueue)
    for _, sync in pairs(registeredSyncs) do
        wipe(sync.versions)
        sync.broadcastQueued = false
    end
end

function Comms:OnProfileChanged()
    wipe(lastRosterGUIDs)
    wipe(receiveQueue)
    wipe(sendQueue)
    for _, sync in pairs(registeredSyncs) do
        wipe(sync.versions)
        sync.broadcastQueued = false
    end
end

-- generic module comms
-- Register a comm prefix and the handler that should receive its messages
function Comms:RegisterProtocol(prefix, handler)
    assert(type(prefix) == "string" and prefix ~= "", "RegisterProtocol: prefix must be a non-empty string")
    assert(handler, "RegisterProtocol: handler must not be nil")
    registeredProtocols[prefix] = handler
    if self:IsEnabled() then
        self:RegisterComm(prefix, "OnProtocolMessage")
    end
end

function Comms:UnregisterProtocol(prefix)
    if not prefix or not registeredProtocols[prefix] then
        return
    end
    registeredProtocols[prefix] = nil
    if self:IsEnabled() then
        self:UnregisterComm(prefix)
    end
end

-- drops inbound messages whose sender doesn't pass E:HasBroadcastAuthority
function Comms:RegisterAuthorizedProtocol(prefix, handler)
    assert(handler, "RegisterAuthorizedProtocol: handler must not be nil")
    local wrapped
    if type(handler) == "function" then
        wrapped = function(p, msg, dist, sender)
            if not E:HasBroadcastAuthority(sender) then
                return
            end
            handler(p, msg, dist, sender)
        end
    else
        wrapped = {
            OnCommReceived = function(_, p, msg, dist, sender)
                if not E:HasBroadcastAuthority(sender) then
                    return
                end
                handler:OnCommReceived(p, msg, dist, sender)
            end
        }
    end
    self:RegisterProtocol(prefix, wrapped)
end

-- sender for every registered protocol prefix
function Comms:OnProtocolMessage(prefix, message, distribution, sender)
    if not sender then
        return
    end
    if InCombatLockdown() then
        receiveQueue[#receiveQueue + 1] = {prefix, message, distribution, sender}
        return
    end
    self:_dispatchProtocol(prefix, message, distribution, sender)
end

function Comms:_dispatchProtocol(prefix, message, distribution, sender)
    if UnitIsUnit(sender, "player") then
        return
    end
    if not E:SafeString(sender) then
        return
    end
    if message ~= nil and not E:SafeString(message) then
        return
    end
    local handler = registeredProtocols[prefix]
    if not handler then
        return
    end
    if type(handler) == "function" then
        handler(prefix, message, distribution, sender)
    elseif type(handler) == "table" and handler.OnCommReceived then
        handler:OnCommReceived(prefix, message, distribution, sender)
    end
end

function Comms:_sendOrQueue(prefix, msg, dist, target)
    if InCombatLockdown() then
        sendQueue[#sendQueue + 1] = {prefix, msg, dist, target}
        return
    end
    self:SendCommMessage(prefix, msg, dist, target)
end

-- simple broadcast since we're not doing much complicated stuff with these
function Comms:Broadcast(prefix, message, context)
    if not prefix or not context then
        return
    end
    self:_sendOrQueue(prefix, message or "", context)
end

function Comms:Whisper(prefix, message, toName)
    if not prefix or not toName or toName == "" then
        return
    end
    self:_sendOrQueue(prefix, message or "", "WHISPER", toName)
end

function Comms:SendPayload(prefix, data, target)
    if not IsInGroup() and not target then
        return
    end

    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

    if target then
        self:_sendOrQueue(prefix, encoded, "WHISPER", target)
    else
        local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
        self:_sendOrQueue(prefix, encoded, chatType)
    end
end

function Comms:DecodePayload(payload)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(payload)
    if not decoded then
        return nil
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil
    end

    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then
        return nil
    end

    return data
end

function Comms:RegisterVersionedSync(config)
    assert(type(config) == "table", "RegisterVersionedSync: config must be a table")
    assert(type(config.name) == "string" and config.name ~= "", "RegisterVersionedSync: config.name required")
    assert(type(config.requestPrefix) == "string", "RegisterVersionedSync: requestPrefix required")
    assert(type(config.dataPrefix) == "string", "RegisterVersionedSync: dataPrefix required")
    assert(type(config.getPayload) == "function", "RegisterVersionedSync: getPayload required")
    assert(type(config.applyPayload) == "function", "RegisterVersionedSync: applyPayload required")
    assert(not registeredSyncs[config.name], "RegisterVersionedSync: duplicate sync " .. config.name)

    local sync = {
        config = config,
        versions = {},
        broadcastQueued = false
    }

    local function broadcast()
        if not IsInGroup() then
            return
        end
        if InCombatLockdown() then
            sync.broadcastQueued = true
            return
        end
        local payload = config.getPayload()
        if not payload then
            return
        end
        sync.versions["player"] = (sync.versions["player"] or 0) + 1
        payload.version = sync.versions["player"]
        self:SendPayload(config.dataPrefix, payload)
    end
    sync.broadcast = broadcast

    self:RegisterProtocol(config.requestPrefix, function(_, _, _, sender)
        if UnitIsUnit(sender, "player") then
            return
        end
        broadcast()
    end)

    self:RegisterProtocol(config.dataPrefix, function(_, encoded, _, sender)
        if UnitIsUnit(sender, "player") then
            return
        end
        local data = self:DecodePayload(encoded)
        if type(data) ~= "table" or type(data.version) ~= "number" then
            return
        end
        local curr = sync.versions[sender] or 0
        if data.version <= curr then
            return
        end
        sync.versions[sender] = data.version
        config.applyPayload(sender, data)
    end)

    registeredSyncs[config.name] = sync
    return sync
end

function Comms:UnregisterVersionedSync(name)
    local sync = registeredSyncs[name]
    if not sync then
        return
    end
    self:UnregisterProtocol(sync.config.requestPrefix)
    self:UnregisterProtocol(sync.config.dataPrefix)
    wipe(sync.versions)
    sync.broadcastQueued = false
    registeredSyncs[name] = nil
end

function Comms:TriggerVersionedSync(name)
    local sync = registeredSyncs[name]
    if not sync then
        return
    end
    sync.broadcast()
end

-- better be safe, combat scary
function Comms:PLAYER_REGEN_ENABLED()
    if #receiveQueue > 0 then
        local pending = receiveQueue
        receiveQueue = {}
        for _, item in ipairs(pending) do
            self:_dispatchProtocol(item[1], item[2], item[3], item[4])
        end
    end

    if #sendQueue > 0 then
        local pending = sendQueue
        sendQueue = {}
        for _, item in ipairs(pending) do
            self:SendCommMessage(item[1], item[2], item[3], item[4])
        end
    end

    for _, sync in pairs(registeredSyncs) do
        if sync.broadcastQueued then
            sync.broadcastQueued = false
            sync.broadcast()
        end
    end
end

function Comms:OnRosterDelta()
    if not IsInGroup() then
        wipe(lastRosterGUIDs)
        return
    end
    if next(registeredSyncs) == nil then
        return
    end

    local seen = {}
    local hasNew = false
    local num = GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, num do
        local unit = prefix .. i
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local guid = UnitGUID(unit)
            if guid then
                seen[guid] = true
                if not lastRosterGUIDs[guid] then
                    hasNew = true
                end
            end
        end
    end
    lastRosterGUIDs = seen

    if not hasNew then
        return
    end

    local chatType = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    for _, sync in pairs(registeredSyncs) do
        self:_sendOrQueue(sync.config.requestPrefix, "ping", chatType)
        sync.broadcast()
    end
end
