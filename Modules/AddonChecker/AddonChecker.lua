local E, L, P = unpack(ART)

local DEFAULT_ADDONS = {"AdvanceRaidTools", "AdvanceRaidTools_Media", "BigWigs", "NorthernSkyRaidTools",
                        "RCLootCouncil", "SharedMedia_Causese", "TimelineReminders"}

P.modules.AddonChecker = {
    enabled = true,
    timeoutSeconds = 5,
    lastAddon = "AdvanceRaidTools"
}

local AddonChecker = E:NewChecker("AddonChecker", {
    prefix = "ART_ACK",
    messagePrefix = "ART_ADDONCHECK",
    defaultTimeout = 5,

    buildRequest = function(self, addonName)
        if type(addonName) ~= "string" or addonName == "" then
            return nil, "NO_ADDON"
        end
        self.db.lastAddon = addonName
        return addonName, {
            addonName = addonName,
            requestKey = addonName
        }
    end,

    respondToRequest = function(self, addonName, _sender)
        if not addonName or addonName == "" then
            return nil
        end
        local loaded = C_AddOns.IsAddOnLoaded(addonName) and 1 or 0
        local version = "-"
        if loaded == 1 then
            version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "-"
            if version == "" then
                version = "-"
            end
        end
        return addonName .. ":" .. loaded .. ":" .. version
    end,

    parseResponse = function(self, payload, _sender)
        if not payload or payload == "" then
            return nil
        end
        local name, loadedStr, version = strsplit(":", payload, 3)
        if not name or name == "" then
            return nil
        end
        -- Drop stale responses for a prior addon check
        if name ~= self.state.requestKey then
            return nil
        end
        return {
            loaded = loadedStr == "1",
            version = (loadedStr == "1") and (version or "-") or nil
        }
    end,

    onSelfEntry = function(self, myEntry)
        local addonName = self.state.addonName
        if not addonName then
            return
        end
        local loaded = C_AddOns.IsAddOnLoaded(addonName) and true or false
        local version
        if loaded then
            version = C_AddOns.GetAddOnMetadata(addonName, "Version")
            if not version or version == "" then
                version = "-"
            end
        end
        myEntry.loaded = loaded
        myEntry.version = version
    end
})

local function versionAtLeast(a, b)
    return E:VersionAtLeast(a, b)
end

AddonChecker.IsVersionAtLeast = function(_, a, b)
    return E:VersionAtLeast(a, b)
end

-- Addon list

function AddonChecker:GetDefaultAddons()
    local out = {}
    for _, name in ipairs(DEFAULT_ADDONS) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

function AddonChecker:IsDefault(name)
    for _, n in ipairs(DEFAULT_ADDONS) do
        if n == name then
            return true
        end
    end
    return false
end

-- Query

function AddonChecker:GetLatestVersion()
    if not self.state then
        return nil
    end
    local best
    for _, e in pairs(self.state.results) do
        if e.loaded and e.version and e.version ~= "-" then
            if not best or not versionAtLeast(best, e.version) then
                best = e.version
            end
        end
    end
    return best
end

function AddonChecker:GetEntryStatus(entry)
    if not entry then
        return "no_response"
    end
    if entry.status == self.STATUS_PENDING then
        return "pending"
    end
    if entry.status == self.STATUS_OFFLINE then
        return "offline"
    end
    if entry.status == self.STATUS_NO_RESPONSE then
        return "no_response"
    end
    if not entry.loaded then
        return "missing"
    end
    local latest = self:GetLatestVersion()
    if latest and not versionAtLeast(entry.version, latest) then
        return "outdated"
    end
    return "up_to_date"
end

function AddonChecker:GetSortedResults()
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
    local rank = {
        missing = 4,
        outdated = 3,
        pending = 2,
        no_response = 1,
        offline = 1,
        up_to_date = 0
    }
    table.sort(list, function(a, b)
        local ra = rank[self:GetEntryStatus(a.entry)] or 0
        local rb = rank[self:GetEntryStatus(b.entry)] or 0
        if ra ~= rb then
            return ra > rb
        end
        return (a.entry.displayName or "") < (b.entry.displayName or "")
    end)
    return list
end

function AddonChecker:GetAddonChoices(extraCustom)
    local t = {}
    for _, name in ipairs(self:GetDefaultAddons()) do
        t[name] = name
    end
    if extraCustom then
        for _, name in ipairs(extraCustom) do
            t[name] = name
        end
    end
    return t
end
