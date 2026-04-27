local E, L, P = unpack(ART)

local STATUS_RESPONDED = "responded"
local STATUS_PENDING = "pending"
local STATUS_OFFLINE = "offline"
local STATUS_NO_RESPONSE = "no_response"
local STATUS_NO_ADDON = "no_addon"

local function resolveContext(req)
    req = req or "auto"
    if req == "auto" then
        if IsInRaid() then
            return "RAID"
        end
        if IsInGroup() then
            return "PARTY"
        end
        if IsInGuild() then
            return "GUILD"
        end
        return nil
    end
    if req == "RAID" then
        return IsInRaid() and "RAID" or nil
    end
    if req == "PARTY" then
        return IsInGroup() and "PARTY" or nil
    end
    if req == "GUILD" then
        return IsInGuild() and "GUILD" or nil
    end
    return nil
end

local function fullNameFromUnit(unit)
    return E:GetUnitFullName(unit, true)
end

local function senderToKey(sender)
    if not sender or sender == "" then
        return nil
    end
    if sender:find("-") then
        return sender
    end
    local realm = (GetRealmName() or ""):gsub("%s+", "")
    return sender .. "-" .. realm
end

local function unitForSender(sender)
    if not sender or sender == "" then
        return nil
    end
    if UnitIsUnit(sender, "player") then
        return "player"
    end
    local n = GetNumGroupMembers()
    if n == 0 then
        return nil
    end
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, n do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsUnit(unit, sender) then
            return unit
        end
    end
    return nil
end

local function resolveDisplayName(fullName, unit)
    if unit and E.HasNickname and E:HasNickname(unit) then
        return E:GetNickname(unit)
    end
    return Ambiguate(fullName, "short")
end

local function getClass(unit, fullName)
    if unit then
        local _, class = UnitClass(unit)
        if class then
            return class
        end
    end
    if fullName then
        return E:GetClassByName(fullName)
    end
    return nil
end

function E:NewChecker(name, opts)
    assert(type(name) == "string", "NewChecker: name must be a string")
    assert(type(opts) == "table", "NewChecker: opts required")
    assert(opts.prefix and opts.messagePrefix, "NewChecker: prefix and messagePrefix required")
    assert(type(opts.buildRequest) == "function", "NewChecker: buildRequest required")
    assert(type(opts.respondToRequest) == "function", "NewChecker: respondToRequest required")
    assert(type(opts.parseResponse) == "function", "NewChecker: parseResponse required")

    local mod = self:NewModule(name, "AceEvent-3.0")

    local PREFIX = opts.prefix
    local MSG_STARTED = opts.messagePrefix .. "_STARTED"
    local MSG_UPDATED = opts.messagePrefix .. "_UPDATED"
    local MSG_RESPONSE = opts.messagePrefix .. "_RESPONSE"
    local MSG_COMPLETED = opts.messagePrefix .. "_COMPLETED"
    local MSG_FAILED = opts.messagePrefix .. "_FAILED"

    local defaultTimeout = opts.defaultTimeout or 5
    local finalizedStatus = opts.finalizedStatus or STATUS_NO_RESPONSE
    local minStartInterval = opts.minStartInterval or 2
    local minResponseInterval = opts.minResponseInterval or 3
    local extraState = opts.extraState

    -- expose status constants
    mod.STATUS_RESPONDED = STATUS_RESPONDED
    mod.STATUS_PENDING = STATUS_PENDING
    mod.STATUS_OFFLINE = STATUS_OFFLINE
    mod.STATUS_NO_RESPONSE = STATUS_NO_RESPONSE
    mod.STATUS_NO_ADDON = STATUS_NO_ADDON
    mod.ResolveContext = function(_, req)
        return resolveContext(req)
    end
    mod._fullNameFromUnit = fullNameFromUnit
    mod._senderToKey = senderToKey
    mod._unitForSender = unitForSender
    mod._resolveDisplayName = resolveDisplayName
    mod._getClass = getClass

    -- Lifecycle

    function mod:OnEnable()
        self.comms = E:GetModule("Comms", true)
        if self.comms then
            self.comms:RegisterProtocol(PREFIX, self)
        end
        self._lastStartedAt = 0
        self._respondedBySender = {} -- sender -> GetTime() of our last RSP to them
        self:ResetState()
        self:RegisterMessage("ART_NICKNAME_CHANGED", "OnNicknameChanged")
        self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    end

    function mod:OnDisable()
        self:CancelTimer()
        if self.comms then
            self.comms:UnregisterProtocol(PREFIX)
            self.comms = nil
        end
        self:UnregisterAllMessages()
        self.state = nil
        self._respondedBySender = nil
    end

    function mod:OnProfileChanged()
        if self:IsEnabled() then
            self:ResetState()
            E:SendMessage(MSG_UPDATED)
        end
    end

    -- State

    function mod:ResetState()
        self:CancelTimer()
        local s = {
            context = nil,
            results = {},
            inProgress = false,
            startedAt = 0,
            completedAt = 0,
            expected = 0,
            received = 0,
            requestKey = nil,
            input = nil
        }
        if extraState then
            for k, v in pairs(extraState) do
                s[k] = v
            end
        end
        self.state = s
    end

    function mod:CancelTimer()
        if self.state and self.state.timer then
            self.state.timer:Cancel()
            self.state.timer = nil
        end
    end

    function mod:GetState()
        return self.state
    end

    function mod:IsInProgress()
        return self.state and self.state.inProgress or false
    end

    -- Check flow

    function mod:StartCheck(input, requestedContext)
        if not self:IsEnabled() then
            E:SendMessage(MSG_FAILED, "DISABLED")
            return false, "DISABLED"
        end

        local now = GetTime()
        if now - (self._lastStartedAt or 0) < minStartInterval then
            E:SendMessage(MSG_FAILED, "TOO_SOON")
            return false, "TOO_SOON"
        end

        local payload, stateOverrides = opts.buildRequest(self, input)
        if not payload then
            local err = stateOverrides or "INVALID_INPUT"
            E:SendMessage(MSG_FAILED, err)
            return false, err
        end

        local context = resolveContext(requestedContext)
        if not context then
            E:SendMessage(MSG_FAILED, "NO_CONTEXT")
            return false, "NO_CONTEXT"
        end

        if not self.comms then
            E:SendMessage(MSG_FAILED, "NO_COMMS")
            return false, "NO_COMMS"
        end

        self:CancelTimer()
        self.state.context = context
        self.state.results = {}
        self.state.inProgress = true
        self.state.startedAt = now
        self.state.completedAt = 0
        self.state.expected = 0
        self.state.received = 0
        self.state.input = input
        -- requestKey and any module-specific fields arrive via overrides
        if type(stateOverrides) == "table" then
            for k, v in pairs(stateOverrides) do
                self.state[k] = v
            end
        end

        if context == "RAID" or context == "PARTY" then
            local groupPrefix = (context == "RAID") and "raid" or "party"
            for i = 1, GetNumGroupMembers() do
                local unit = groupPrefix .. i
                if UnitExists(unit) then
                    local key = fullNameFromUnit(unit)
                    if key and not UnitIsUnit(unit, "player") then
                        local entry
                        if opts.initResultEntry then
                            entry = opts.initResultEntry(self, unit, key)
                        else
                            entry = {
                                status = STATUS_PENDING,
                                displayName = resolveDisplayName(key, unit),
                                class = getClass(unit, key)
                            }
                        end
                        if not UnitIsConnected(unit) then
                            entry.status = STATUS_OFFLINE
                        else
                            entry.status = entry.status or STATUS_PENDING
                            self.state.expected = self.state.expected + 1
                        end
                        self.state.results[key] = entry
                    end
                end
            end
        end

        local myKey = fullNameFromUnit("player")
        if myKey then
            local myEntry = {
                status = STATUS_RESPONDED,
                displayName = resolveDisplayName(myKey, "player"),
                class = getClass("player", myKey),
                isSelf = true
            }
            if opts.onSelfEntry then
                opts.onSelfEntry(self, myEntry)
            end
            self.state.results[myKey] = myEntry
        end

        self.comms:Broadcast(PREFIX, "REQ:" .. payload, context)
        self._lastStartedAt = now

        local timeout = (self.db and self.db.timeoutSeconds) or defaultTimeout
        self.state.timer = C_Timer.NewTimer(timeout, function()
            self:OnTimeout()
        end)

        E:SendMessage(MSG_STARTED, context, input)
        E:SendMessage(MSG_UPDATED)
        return true, context
    end

    function mod:CancelCheck()
        if not (self.state and self.state.inProgress) then
            return
        end
        self:Finalize()
    end

    -- Comms

    function mod:OnCommReceived(prefix, message, distribution, sender)
        if prefix ~= PREFIX or not self:IsEnabled() then
            return
        end
        if not message or message == "" then
            return
        end

        local cmd, payload = strsplit(":", message, 2)

        if cmd == "REQ" then
            local now = GetTime()
            local last = self._respondedBySender[sender]
            if last and (now - last) < minResponseInterval then
                return
            end
            self._respondedBySender[sender] = now

            local rspPayload = opts.respondToRequest(self, payload, sender)
            if rspPayload and self.comms then
                self.comms:Whisper(PREFIX, "RSP:" .. rspPayload, sender)
            end
            return
        end

        if cmd == "RSP" then
            if not (self.state and self.state.inProgress) then
                return
            end
            local fields, err = opts.parseResponse(self, payload, sender)
            if not fields then
                return -- stale response, or malformed
            end
            self:RecordResponse(sender, fields)
        end
    end

    function mod:RecordResponse(sender, fields)
        local key = senderToKey(sender)
        if not key then
            return
        end

        local unit = unitForSender(sender)
        local entry = self.state.results[key]
        local wasPending = entry and entry.status == STATUS_PENDING

        if not entry then
            entry = {
                displayName = resolveDisplayName(key, unit),
                class = getClass(unit, key)
            }
            self.state.results[key] = entry
        else
            if not entry.class then
                entry.class = getClass(unit, key)
            end
            if unit and E.HasNickname and E:HasNickname(unit) then
                entry.displayName = E:GetNickname(unit)
            end
        end

        for k, v in pairs(fields) do
            entry[k] = v
        end
        entry.status = STATUS_RESPONDED

        if wasPending then
            self.state.received = self.state.received + 1
        end

        E:SendMessage(MSG_RESPONSE, key)
        E:SendMessage(MSG_UPDATED)

        if self.state.context ~= "GUILD" and self.state.expected > 0 and self.state.received >= self.state.expected then
            self:Finalize()
        end
    end

    function mod:OnTimeout()
        if self.state then
            self.state.timer = nil
        end
        self:Finalize()
    end

    function mod:Finalize()
        if not self.state then
            return
        end
        self:CancelTimer()
        for _, entry in pairs(self.state.results) do
            if entry.status == STATUS_PENDING then
                entry.status = finalizedStatus
            end
        end
        self.state.inProgress = false
        self.state.completedAt = GetTime()
        E:SendMessage(MSG_COMPLETED)
        E:SendMessage(MSG_UPDATED)
    end

    function mod:OnNicknameChanged(_, unit)
        if not (self.state and self.state.results) then
            return
        end
        if not unit or not UnitExists(unit) then
            return
        end
        local key = fullNameFromUnit(unit)
        if not key then
            return
        end
        local entry = self.state.results[key]
        if not entry then
            return
        end
        entry.displayName = resolveDisplayName(key, unit)
        E:SendMessage(MSG_UPDATED)
    end

    -- Sort

    function mod:GetSortedResults(sortMode)
        local list = {}
        if not (self.state and self.state.results) then
            return list
        end
        for key, entry in pairs(self.state.results) do
            list[#list + 1] = {
                key = key,
                entry = entry
            }
        end

        if sortMode == "name" then
            table.sort(list, function(a, b)
                return (a.entry.displayName or "") < (b.entry.displayName or "")
            end)
        else
            local ord = {
                [STATUS_RESPONDED] = 1,
                [STATUS_PENDING] = 2,
                [STATUS_NO_ADDON] = 3,
                [STATUS_NO_RESPONSE] = 3,
                [STATUS_OFFLINE] = 4
            }
            table.sort(list, function(a, b)
                local sa = ord[a.entry.status] or 99
                local sb = ord[b.entry.status] or 99
                if sa ~= sb then
                    return sa < sb
                end
                return (a.entry.displayName or "") < (b.entry.displayName or "")
            end)
        end

        return list
    end

    return mod
end
