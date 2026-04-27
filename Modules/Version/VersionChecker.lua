local E, L, P = unpack(ART)

P.modules.VersionChecker = {
    enabled = true,
    timeoutSeconds = 5
}

local function compareVersions(a, b)
    return E:CompareVersions(a, b)
end

local function getMyVersion()
    return E.version or C_AddOns.GetAddOnMetadata(E.addonName, "Version") or "0.0.0"
end

local VersionChecker = E:NewChecker("VersionChecker", {
    prefix = "ART_VER",
    messagePrefix = "ART_VERSIONCHECK",
    defaultTimeout = 5,
    -- VersionChecker keeps a pending peer as STATUS_NO_ADDON on timeout
    finalizedStatus = "no_addon",

    buildRequest = function(self, _input)
        return getMyVersion(), {
            requestKey = getMyVersion()
        }
    end,

    respondToRequest = function(self, _reqPayload, _sender)
        return getMyVersion()
    end,

    parseResponse = function(self, payload, _sender)
        if not payload or payload == "" then
            return nil
        end
        return {
            version = payload
        }
    end,

    onSelfEntry = function(self, myEntry)
        myEntry.version = getMyVersion()
    end
})

function VersionChecker:CompareVersions(a, b)
    return compareVersions(a, b)
end

function VersionChecker:GetMyVersion()
    return getMyVersion()
end

-- Simple wrapper so the panel can call StartCheck() with just the context
function VersionChecker:StartVersionCheck(requestedContext)
    return self:StartCheck(nil, requestedContext)
end

function VersionChecker:GetHighestVersion()
    local highest
    for _, entry in pairs(self.state.results) do
        if entry.status == self.STATUS_RESPONDED and entry.version then
            if not highest or compareVersions(entry.version, highest) > 0 then
                highest = entry.version
            end
        end
    end
    return highest
end

function VersionChecker:GetCounts()
    local c = {
        total = 0,
        responded = 0,
        upToDate = 0,
        outdated = 0,
        missing = 0,
        offline = 0
    }
    local highest = self:GetHighestVersion()
    for _, entry in pairs(self.state.results) do
        c.total = c.total + 1
        if entry.status == self.STATUS_RESPONDED then
            c.responded = c.responded + 1
            if highest and compareVersions(entry.version, highest) < 0 then
                c.outdated = c.outdated + 1
            else
                c.upToDate = c.upToDate + 1
            end
        elseif entry.status == self.STATUS_PENDING or entry.status == self.STATUS_NO_ADDON then
            c.missing = c.missing + 1
        elseif entry.status == self.STATUS_OFFLINE then
            c.offline = c.offline + 1
        end
    end
    return c
end

function VersionChecker:GetSortedResults(sortMode)
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

    sortMode = sortMode or "status"

    if sortMode == "name" then
        table.sort(list, function(a, b)
            return (a.entry.displayName or "") < (b.entry.displayName or "")
        end)
    elseif sortMode == "version" then
        table.sort(list, function(a, b)
            local av = (a.entry.status == self.STATUS_RESPONDED) and a.entry.version or nil
            local bv = (b.entry.status == self.STATUS_RESPONDED) and b.entry.version or nil
            if av and bv then
                local c = compareVersions(av, bv)
                if c ~= 0 then
                    return c > 0
                end
            elseif av then
                return true
            elseif bv then
                return false
            end
            return (a.entry.displayName or "") < (b.entry.displayName or "")
        end)
    else
        local ord = {
            [self.STATUS_RESPONDED] = 1,
            [self.STATUS_PENDING] = 2,
            [self.STATUS_NO_ADDON] = 3,
            [self.STATUS_OFFLINE] = 4
        }
        local highest = self:GetHighestVersion()
        table.sort(list, function(a, b)
            local sa = ord[a.entry.status] or 99
            local sb = ord[b.entry.status] or 99
            if sa ~= sb then
                return sa < sb
            end
            -- within "responded" put outdated first so they're easy to spot
            if a.entry.status == self.STATUS_RESPONDED and highest then
                local aOut = compareVersions(a.entry.version, highest) < 0
                local bOut = compareVersions(b.entry.version, highest) < 0
                if aOut ~= bOut then
                    return aOut
                end
            end
            return (a.entry.displayName or "") < (b.entry.displayName or "")
        end)
    end
    return list
end

