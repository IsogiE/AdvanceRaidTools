local E, L = unpack(ART)

function E:GetDB(moduleName)
    assert(self.db, "E:GetDB called before OnInitialize")
    self.db.profile.modules = self.db.profile.modules or {}
    self.db.profile.modules[moduleName] = self.db.profile.modules[moduleName] or {}
    return self.db.profile.modules[moduleName]
end

-- import strings, cross-character nickname lists, etc
function E:GetGlobal(moduleName)
    assert(self.db, "E:GetGlobal called before OnInitialize")
    self.db.global.modules = self.db.global.modules or {}
    self.db.global.modules[moduleName] = self.db.global.modules[moduleName] or {}
    return self.db.global.modules[moduleName]
end

function E:IsModuleEnabled(moduleName)
    local mod = self:GetModule(moduleName, true)
    if not mod then
        return false
    end
    return mod:IsEnabled()
end

function E:GetEnabledModule(moduleName)
    local mod = self:GetModule(moduleName, true)
    if not mod or not mod:IsEnabled() then
        return nil
    end
    return mod
end

function E:CallModule(moduleName, methodName, ...)
    local mod = self:GetEnabledModule(moduleName)
    if not mod then
        return nil
    end
    local fn = mod[methodName]
    if type(fn) ~= "function" then
        return nil
    end
    return fn(mod, ...)
end

function E:WithModule(moduleName, fn, ...)
    local mod = self:GetEnabledModule(moduleName)
    if not mod or type(fn) ~= "function" then
        return nil
    end
    return fn(mod, ...)
end

local outOfCombatQueue = {}
local outOfCombatOrder = {}

local function queueOutOfCombat(key, fn, opts)
    if not outOfCombatQueue[key] then
        outOfCombatOrder[#outOfCombatOrder + 1] = key
    end
    outOfCombatQueue[key] = {
        fn = fn,
        opts = opts
    }
end

local function hasQueuedOutOfCombat()
    return next(outOfCombatQueue) ~= nil
end

function E:CancelRunWhenOutOfCombat(key)
    if key ~= nil then
        outOfCombatQueue[key] = nil
    end
end

function E:FlushRunWhenOutOfCombat()
    if InCombatLockdown() then
        return
    end
    if self.UnregisterEvent then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end

    local queue = outOfCombatQueue
    local order = outOfCombatOrder
    outOfCombatQueue = {}
    outOfCombatOrder = {}

    for i = 1, #order do
        local item = queue[order[i]]
        if item and type(item.fn) == "function" then
            local ok, err = pcall(item.fn)
            if not ok then
                geterrorhandler()(err)
            end
        end
    end

    if hasQueuedOutOfCombat() and self.RegisterEvent then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "FlushRunWhenOutOfCombat")
    end
end

function E:RunWhenOutOfCombat(key, fn, opts)
    if type(key) == "function" and fn == nil then
        fn = key
        key = tostring(fn)
    end
    assert(type(fn) == "function", "RunWhenOutOfCombat requires a function")

    if not InCombatLockdown() and not (opts and opts.alwaysQueue) then
        return fn()
    end

    key = tostring(key or fn)
    queueOutOfCombat(key, fn, opts)
    if self.RegisterEvent then
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "FlushRunWhenOutOfCombat")
    end
    return true
end

function E:SetModuleEnabled(moduleName, enabled)
    local mod = self:GetModule(moduleName, true)
    if not mod then
        return
    end
    self.db.profile.modules = self.db.profile.modules or {}
    self.db.profile.modules[moduleName] = self.db.profile.modules[moduleName] or {}
    self.db.profile.modules[moduleName].enabled = enabled and true or false

    self:_reapplyModuleEnable(mod)
    for _, child in self:IterateModules() do
        if child._parentModule == moduleName then
            self:_reapplyModuleEnable(child)
        end
    end
    self:SendMessage("ART_MODULE_TOGGLED", moduleName, enabled)
end

function E:CreateReadOnlyProxy(errorMsg)
    errorMsg = errorMsg or "ART read-only table; writes go through the owning module's setter."
    return setmetatable({}, {
        __newindex = function(_, k)
            error(("%s (key: %s)"):format(errorMsg, tostring(k)), 2)
        end,
        __metatable = "read-only"
    })
end

-- Mount a map of { key = fn } onto target
function E:MountMethods(target, methods, opts)
    assert(type(target) == "table", "MountMethods: target must be a table")
    assert(type(methods) == "table", "MountMethods: methods must be a table")
    local noClobber = opts and opts.noClobber
    local installed = {}
    for key, fn in pairs(methods) do
        if (not noClobber) or target[key] == nil then
            target[key] = fn
            installed[key] = true
        end
    end
    return {
        Unmount = function()
            for key in pairs(installed) do
                target[key] = nil
                installed[key] = nil
            end
        end
    }
end

-- :)
local issecretvalue = _G.issecretvalue
function E:SafeString(s)
    if type(s) ~= "string" then
        return nil
    end
    if issecretvalue and issecretvalue(s) then
        return nil
    end
    return s
end

function E:IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

function E:BareName(s)
    s = self:SafeString(s)
    if not s or s == "" then
        return ""
    end
    local bare = s:match("^([^%-]+)")
    return bare or s
end

function E:GetUnitFullName(unit, stripSpaces)
    local name, realm = UnitNameUnmodified(unit)
    name = self:SafeString(name)
    if not name then
        return nil
    end
    if realm and realm ~= "" then
        realm = self:SafeString(realm)
        if not realm then
            return nil
        end
    else
        realm = GetRealmName()
    end
    if not realm then
        return nil
    end
    if stripSpaces then
        realm = realm:gsub("%s+", "")
    end
    return name .. "-" .. realm
end

function E:GetPlayerRole()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then
        return nil
    end
    local role = GetSpecializationRole and GetSpecializationRole(specIndex)
    return role
end

function E:GetGroupUnitByName(name)
    name = self:SafeString(name)
    if not name or name == "" then
        return nil
    end
    local num = GetNumGroupMembers() or 0
    if num == 0 then
        return nil
    end

    local senderRef = name
    if not name:find("-", 1, true) then
        local realm = (GetRealmName() or ""):gsub("%s+", "")
        senderRef = name .. "-" .. realm
    end
    if not UnitExists(senderRef) then
        return nil
    end
    local senderGUID = UnitGUID(senderRef)
    if not senderGUID then
        return nil
    end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, num do
        local unit = prefix .. i
        if UnitExists(unit) and UnitGUID(unit) == senderGUID then
            return unit
        end
    end
    return nil
end

-- Auth for sharing
function E:HasBroadcastAuthority(player)
    local bare = self:BareName(player)
    if bare == "" or not IsInGroup() then
        return false
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and self:BareName(name) == bare then
                return (rank or 0) >= 1 -- 0 = member, 1 = assist, 2 = leader
            end
        end
        return false
    end
    if self:BareName(UnitName("player") or "") == bare then
        return true
    end
    for i = 1, (GetNumGroupMembers() or 1) - 1 do
        local partyName = UnitName("party" .. i)
        if partyName and self:BareName(partyName) == bare then
            return true
        end
    end
    return false
end

-- callback (ART:RegisterCallback)

local callbacks = {}

function _G.ART.RegisterCallback(_, event, fn)
    callbacks[event] = callbacks[event] or {}
    callbacks[event][fn] = true
end

function _G.ART.UnregisterCallback(_, event, fn)
    if callbacks[event] then
        callbacks[event][fn] = nil
    end
end

-- Wrap E:SendMessage once
local origSendMessage = E.SendMessage
function E:SendMessage(event, ...)
    origSendMessage(self, event, ...)
    local list = event and callbacks[event]
    if not list then
        return
    end
    for fn in pairs(list) do
        pcall(fn, ...)
    end
end

-- Debug

local LOG_CAPACITY = 100
local logBuf = {}
local logNext = 1
local logCount = 0

local function logAppend(severity, channel, msg)
    logBuf[logNext] = {
        t = time(),
        severity = severity,
        channel = channel,
        msg = msg
    }
    logNext = logNext + 1
    if logNext > LOG_CAPACITY then
        logNext = 1
    end
    if logCount < LOG_CAPACITY then
        logCount = logCount + 1
    end
end

E.debugChannels = E.debugChannels or {}

local function debugState(self)
    local g = self.db and self.db.profile and self.db.profile.general
    if not g then
        return nil
    end
    local d = g.debug
    if type(d) ~= "table" then
        -- Shape hasn't been normalized yet. Treat as off
        return nil
    end
    d.channels = d.channels or {}
    return d
end

function E:RegisterDebugChannel(name, description)
    if type(name) ~= "string" or name == "" then
        return
    end
    self.debugChannels[name] = description or self.debugChannels[name] or ""
end

function E:ListDebugChannels()
    return self.debugChannels
end

function E:IsDebugEnabled(channel)
    local d = debugState(self)
    if not d then
        return false
    end
    if d.enabled then
        return true
    end
    if channel and d.channels[channel] then
        return true
    end
    return false
end

-- SetDebugEnabled(nil, bool)
-- SetDebugEnabled(name, bool)
function E:SetDebugEnabled(channel, enabled)
    local d = debugState(self)
    if not d then
        return false
    end
    enabled = enabled and true or false
    if channel == nil then
        d.enabled = enabled
        return enabled
    end
    if not self.debugChannels[channel] then
        self:RegisterDebugChannel(channel)
    end
    d.channels[channel] = enabled or nil
    return enabled
end

function E:Printf(fmt, ...)
    local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
    logAppend("info", nil, msg)
    print(("|cff1784d1%s:|r %s"):format(L["AdvanceRaidTools"], msg))
end

local function formatChannelTag(channel)
    if channel then
        return ("[%s]"):format(channel)
    end
    return ""
end

function E:ChannelDebug(channel, fmt, ...)
    local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
    logAppend("debug", channel, msg)
    if not self:IsDebugEnabled(channel) then
        return
    end
    print(("|cffff7700%s[debug]%s:|r %s"):format(L["AdvanceRaidTools"], formatChannelTag(channel), msg))
end

function E:ChannelWarn(channel, fmt, ...)
    local msg = (select("#", ...) > 0) and fmt:format(...) or fmt
    logAppend("warn", channel, msg)
    if not self:IsDebugEnabled(channel) then
        return
    end
    print(("|cffff7700%s[warn]%s:|r %s"):format(L["AdvanceRaidTools"], formatChannelTag(channel), msg))
end

function E:Debug(fmt, ...)
    return self:ChannelDebug(nil, fmt, ...)
end

function E:Warn(fmt, ...)
    return self:ChannelWarn(nil, fmt, ...)
end

-- Filter can be a severity (info|warn|debug) or a channel prefixed with @ (e.g. "@Nicknames"). Nil dumps everything
function E:DumpLog(filter)
    if logCount == 0 then
        self:Printf(L["LogEmpty"])
        return
    end

    local wantChannel
    local wantSeverity
    if filter then
        if filter:sub(1, 1) == "@" then
            wantChannel = filter:sub(2)
        else
            wantSeverity = filter
        end
    end

    local start = (logCount < LOG_CAPACITY) and 1 or logNext
    local snapshot = logCount
    local printed = 0
    for i = 0, snapshot - 1 do
        local idx = ((start - 1 + i) % LOG_CAPACITY) + 1
        local e = logBuf[idx]
        local matches = e and (not wantSeverity or e.severity == wantSeverity) and
                            (not wantChannel or e.channel == wantChannel)
        if matches then
            local color = (e.severity == "warn" and "ff7700") or (e.severity == "debug" and "aaaaaa") or "1784d1"
            local chanTag = e.channel and (" |cff888888[%s]|r"):format(e.channel) or ""
            print(("|cff888888[%s]|r |cff%s%s|r%s %s"):format(date("%H:%M:%S", e.t), color, e.severity, chanTag, e.msg))
            printed = printed + 1
        end
    end
    if printed == 0 then
        self:Printf(L["LogNoMatches"], filter or "")
    end
end

function E:ClearLog()
    wipe(logBuf)
    logNext = 1
    logCount = 0
end

function E:L(key, ...)
    local s = L[key] or key
    if select("#", ...) > 0 then
        s = s:format(...)
    end
    return s
end

function E:ClassColorRGB(class)
    if not class then
        return 1, 1, 1
    end
    local src = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local c = src and src[class]
    if c then
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

function E:ClassColorCode(class)
    local r, g, b = self:ClassColorRGB(class)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

-- Accepts {r,g,b,a}, {r=,g=,b=,a=}, or nil. Returns four numbers, falling back to the supplied defaults for any missing channel
function E:ColorTuple(c, fr, fg, fb, fa)
    if type(c) == "table" then
        return c[1] or c.r or fr, c[2] or c.g or fg, c[3] or c.b or fb, c[4] or c.a or fa
    end
    return fr, fg, fb, fa
end

-- Strip color escapes from a string
function E:StripColorCodes(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function parseVersion(v)
    local out = {}
    local s = tostring(v or ""):gsub("^[vV]", "")
    local base, rest = s:match("^([%d%.]+)(.*)$")
    if not base then
        return out
    end
    for part in base:gmatch("[^.]+") do
        out[#out + 1] = tonumber(part) or 0
    end
    local ahead = rest:match("^%-(%d+)%-")
    if ahead then
        out[#out + 1] = tonumber(ahead) or 0
    end
    return out
end

-- Returns -1, 0, or 1 — same sense as a comparator
function E:CompareVersions(a, b)
    local pa, pb = parseVersion(a), parseVersion(b)
    local n = math.max(#pa, #pb)
    for i = 1, n do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

function E:VersionAtLeast(a, b)
    if a == nil or b == nil or a == "" or b == "" or a == "-" or b == "-" then
        return true
    end
    return self:CompareVersions(a, b) >= 0
end

-- Format a number for compact display
function E:FormatAmount(n)
    if type(n) ~= "number" then
        return "?"
    end
    if FormatLargeNumber then
        return FormatLargeNumber(n)
    end
    return tostring(n)
end

function E:PrebuildOptions()
    if self._handlesArmed or C_AddOns.IsAddOnLoaded("AdvanceRaidTools_Options") then
        return
    end
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo("AdvanceRaidTools_Options")
    if not loadable and (reason == "MISSING" or reason == "DISABLED") then
        return
    end
    self._prebuildActive = true
    local loaded, err = C_AddOns.LoadAddOn("AdvanceRaidTools_Options")
    self._prebuildActive = false
    if not loaded then
        self:Printf(L["OptionsLoadFailed"], err or "unknown")
        return
    end
    self:ArmOptionsDeferredHandles()
    if self.InitializeOptionsUI then
        self:InitializeOptionsUI()
    end
end

function E:EnsureOptions()
    if C_AddOns.IsAddOnLoaded("AdvanceRaidTools_Options") then
        self:ArmOptionsDeferredHandles()
        return true
    end
    local loaded, reason = C_AddOns.LoadAddOn("AdvanceRaidTools_Options")
    if not loaded then
        self:Printf(L["OptionsLoadFailed"], reason or "unknown")
        return false
    end
    self:ArmOptionsDeferredHandles()
    return true
end

function E:OpenOptions()
    if not self:EnsureOptions() then
        return
    end

    -- ensure the UI is built right before we attempt to open it
    if self.InitializeOptionsUI then
        self:InitializeOptionsUI()
    end

    if self.OptionsUI and self.OptionsUI.Toggle then
        self.OptionsUI:Toggle()
    end
end
