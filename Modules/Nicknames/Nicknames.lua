local E, L, P = unpack(ART)

P.modules.Nicknames = {
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
}

local Nicknames = E:NewModule("Nicknames", "AceEvent-3.0")

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

local nicknameToUnitCache = {}

local function realmKey(unit)
    return E:GetUnitFullName(unit)
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

function Nicknames:OnModuleInitialize(db)
    local selfKey = realmKey("player")
    if selfKey and db.myNickname and db.myNickname ~= "" then
        db.map[selfKey] = db.myNickname
    end
end

function Nicknames:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "InvalidateCache")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "InvalidateCache")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")

    local selfKey = realmKey("player")
    if selfKey then
        local nick = self.db.myNickname
        if nick and nick ~= "" then
            self.db.map[selfKey] = nick
        else
            self.db.map[selfKey] = nil
        end
    end

    self:Publish()
    self:RegisterSync()
    self:InitIntegrations()
    self:RefreshIntegrations()
end

function Nicknames:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
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
end

function Nicknames:RegisterSync()
    local Comms = E:GetEnabledModule("Comms")
    if not Comms or not Comms.RegisterVersionedSync then
        return
    end
    Comms:RegisterVersionedSync({
        name = "Nicknames",
        requestPrefix = "ART_NREQ",
        dataPrefix = "ART_NDAT",
        getPayload = function()
            local nick = self.db and self.db.myNickname
            if not nick or nick == "" then
                return nil
            end
            return {
                nickname = nick
            }
        end,
        applyPayload = function(sender, data)
            if not data.nickname then
                return
            end
            local unit = E:GetGroupUnitByName(sender)
            if unit then
                self:Set(unit, data.nickname)
            end
        end
    })
end

function Nicknames:UnregisterSync()
    local Comms = E:GetModule("Comms", true)
    if Comms and Comms.UnregisterVersionedSync then
        Comms:UnregisterVersionedSync("Nicknames")
    end
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

    local old = self.db.map[key]
    if old == nickname then
        return
    end

    self.db.map[key] = nickname
    if unit == "player" then
        self.db.myNickname = nickname
    end

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

    if unit == "player" then
        local Comms = E:GetEnabledModule("Comms")
        if Comms and Comms.TriggerVersionedSync then
            Comms:TriggerVersionedSync("Nicknames")
        end
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
    if cached then
        return cached
    end
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        if self:GetIfAny(unit) == nickname then
            nicknameToUnitCache[nickname] = unit
            return unit
        end
    end
end

function Nicknames:RegisterIntegration(addonKey, handlers)
    assert(type(addonKey) == "string", "addonKey must be a string")
    assert(type(handlers) == "table", "handlers must be a table")
    self.integrations[addonKey] = handlers

    if not self:IsEnabled() then
        return
    end

    if self.db and self.db.integrations[addonKey] and not self.initialized[addonKey] and
        (addonKey == "Blizzard" or C_AddOns.IsAddOnLoaded(addonKey)) and handlers.Init then
        if safeCall(addonKey, handlers, "Init") then
            self.initialized[addonKey] = true
            safeCall(addonKey, handlers, "OnToggle", true)
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
            self.db.integrations[addonKey] and handlers.Init then
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
    if not (self.db.integrations[loadedAddon] and handlers.Init) then
        return
    end

    if safeCall(loadedAddon, handlers, "Init") then
        self.initialized[loadedAddon] = true
        safeCall(loadedAddon, handlers, "OnToggle", true)
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
    if enabled and handlers and not self.initialized[addonKey] and handlers.Init and
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
        local selfName = E:SafeString(UnitName("player"))
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
        local name = E:SafeString(UnitName(unit))
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
