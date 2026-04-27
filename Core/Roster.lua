local E, L, P = unpack(ART)

P.modules.Roster = {
    enabled = true
}

local Roster = E:NewModule("Roster", "AceEvent-3.0")

local strtrim = strtrim
local strlower = string.lower
local strupper = string.upper
local strfind = string.find
local strsub = string.sub
local strmatch = string.match
local tinsert = table.insert
local GetRaidRosterInfo = GetRaidRosterInfo
local GetGuildRosterInfo = GetGuildRosterInfo
local GetNumGroupMembers = GetNumGroupMembers
local GetNumGuildMembers = GetNumGuildMembers
local GetNormalizedRealmName = GetNormalizedRealmName

local GUILD_CACHE_TTL = 300
local GUILD_REBUILD_THROTTLE = 5

local _guildCache
local _guildCacheAt = 0
local _classByName

local function normalizeName(name)
    if not name or name == "" then
        return name or ""
    end
    local trimmed = strtrim(name)
    local dash = strfind(trimmed, "-", 1, true)
    if dash then
        local base = strsub(trimmed, 1, dash - 1)
        local realm = strsub(trimmed, dash)
        return (strlower(base):gsub("^%l", strupper)) .. realm
    end
    return (strlower(trimmed):gsub("^%l", strupper))
end

local function buildClassMap()
    local realm = GetNormalizedRealmName()
    local map = {}

    if IsInGroup() or IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class, _, _, _, _, _, _, server = GetRaidRosterInfo(i)
            if name then
                local display = (server and server ~= "" and server ~= realm) and (name .. "-" .. server) or name
                map[normalizeName(display)] = class
            end
        end
    end

    if _guildCache then
        for _, entry in ipairs(_guildCache) do
            local k = normalizeName(entry.name)
            if not map[k] then
                map[k] = entry.class
            end
        end
    end

    return map
end

function Roster:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "OnRosterUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "OnGuildRosterUpdate")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "OnPlayerGuildUpdate")
    if IsInGuild() and C_GuildInfo and C_GuildInfo.RequestGuildRoster then
        C_GuildInfo.RequestGuildRoster()
    end
end

function Roster:OnDisable()
    _guildCache = nil
    _guildCacheAt = 0
    _classByName = nil
    self._pendingPublish = false
end

function Roster:NormalizeName(name)
    return normalizeName(name)
end

function Roster:GetGuildCache()
    return _guildCache
end

function Roster:RebuildGuildCache()
    if C_GuildInfo and C_GuildInfo.RequestGuildRoster then
        C_GuildInfo.RequestGuildRoster()
    end
    local realm = GetNormalizedRealmName()
    local g = {}
    local n = GetNumGuildMembers() or 0
    for i = 1, n do
        local name, _, rank, _, _, _, _, _, _, _, classToken = GetGuildRosterInfo(i)
        if name then
            local base, server = strmatch(name, "^(.-)%-(.+)$")
            local display = (server and server == realm) and base or name
            tinsert(g, {
                name = display,
                class = classToken,
                rank = rank or i
            })
        end
    end
    table.sort(g, function(a, b)
        return a.rank < b.rank
    end)
    _guildCache = g
    _guildCacheAt = GetTime()
    _classByName = nil
end

function Roster:EnsureGuildCache()
    if _guildCache and (GetTime() - (_guildCacheAt or 0)) < GUILD_CACHE_TTL then
        return
    end
    self:RebuildGuildCache()
end

function Roster:InvalidateRosterCache()
    _classByName = nil
    self:Publish()
end

function Roster:InvalidateGuildCache()
    _guildCache = nil
    _guildCacheAt = 0
    _classByName = nil
end

function Roster:Publish()
    if InCombatLockdown() then
        self._pendingPublish = true
        return
    end
    E:SendMessage("ART_ROSTER_INVALIDATED")
end

function Roster:GetClassForName(name)
    if not name or name == "" then
        return nil
    end
    _classByName = _classByName or buildClassMap()
    local key = normalizeName(name)
    local class = _classByName[key]
    if class then
        return class
    end
    local base, server = strmatch(name, "^(.-)%-(.+)$")
    if base and server then
        local myRealm = GetNormalizedRealmName() or ""
        if server == myRealm or server:gsub("%s+", "") == myRealm:gsub("%s+", "") then
            return _classByName[normalizeName(base)]
        end
    end
    return nil
end

function Roster:OnPlayerEnteringWorld()
    _classByName = nil
    if IsInGuild() and C_GuildInfo and C_GuildInfo.RequestGuildRoster then
        C_GuildInfo.RequestGuildRoster()
    end
    self:Publish()
end

function Roster:OnGuildRosterUpdate()
    if not IsInGuild() then
        if _guildCache then
            self:InvalidateGuildCache()
            self:Publish()
        end
        return
    end
    local hasData = _guildCache and #_guildCache > 0
    if hasData and (GetTime() - (_guildCacheAt or 0)) < GUILD_REBUILD_THROTTLE then
        return
    end
    self:RebuildGuildCache()
    self:Publish()
end

function Roster:OnPlayerGuildUpdate()
    self:InvalidateGuildCache()
    self:Publish()
end

function Roster:OnRosterUpdate()
    _classByName = nil
    self:Publish()
end

function Roster:OnRegenEnabled()
    if self._pendingPublish then
        self._pendingPublish = false
        E:SendMessage("ART_ROSTER_INVALIDATED")
    end
end

function E:GetClassByName(name)
    return Roster:GetClassForName(name)
end

function E:NormalizeName(name)
    return normalizeName(name)
end

function E:EnsureGuildCache()
    Roster:EnsureGuildCache()
end

function E:InvalidateRosterCache()
    Roster:InvalidateRosterCache()
end

function E:GetGuildCache()
    return Roster:GetGuildCache()
end
