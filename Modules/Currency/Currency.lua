local E, L, P = unpack(ART)

P.modules.Currency = {
    enabled = true,
    timeoutSeconds = 5,
    favorites = {} -- array of { id = number, name = string, icon = fileID }
}

local Currency = E:NewChecker("Currency", {
    prefix = "ART_CUR",
    messagePrefix = "ART_CURRENCYCHECK",
    defaultTimeout = 5,
    finalizedStatus = "no_addon",

    buildRequest = function(self, currencyID)
        currencyID = tonumber(currencyID)
        if not currencyID or currencyID <= 0 then
            return nil, "INVALID_ID"
        end
        local info = self:GetCurrencyInfo(currencyID)
        if not info then
            return nil, "UNKNOWN_CURRENCY"
        end
        return tostring(currencyID), {
            currencyID = currencyID,
            currencyName = info.name,
            currencyIcon = info.iconFileID,
            requestKey = currencyID
        }
    end,

    respondToRequest = function(self, payload, _sender)
        local reqID = tonumber(payload)
        if not reqID then
            return nil
        end
        local amount = self:GetCurrencyAmount(reqID)
        return reqID .. ":" .. amount
    end,

    parseResponse = function(self, payload, _sender)
        if not payload or payload == "" then
            return nil
        end
        local idStr, amtStr = strsplit(":", payload, 2)
        local rspID = tonumber(idStr)
        local amount = tonumber(amtStr)
        if not rspID or not amount then
            return nil
        end
        if rspID ~= self.state.requestKey then
            return nil
        end -- stale
        return {
            amount = amount
        }
    end,

    onSelfEntry = function(self, myEntry)
        local id = self.state.currencyID
        if id then
            myEntry.amount = self:GetCurrencyAmount(id)
        end
    end
})

-- Currency-specific lookups

function Currency:GetCurrencyInfo(currencyID)
    currencyID = tonumber(currencyID)
    if not currencyID or currencyID <= 0 then
        return nil
    end
    return C_CurrencyInfo.GetCurrencyInfo(currencyID)
end

function Currency:GetCurrencyAmount(currencyID)
    local info = self:GetCurrencyInfo(currencyID)
    return info and info.quantity or 0
end

-- Favorites

function Currency:GetFavorites()
    return self.db.favorites
end

function Currency:IsFavorite(currencyID)
    currencyID = tonumber(currencyID)
    if not currencyID then
        return false
    end
    for _, fav in ipairs(self.db.favorites) do
        if fav.id == currencyID then
            return true
        end
    end
    return false
end

function Currency:AddFavorite(currencyID)
    currencyID = tonumber(currencyID)
    if not currencyID or currencyID <= 0 then
        return false
    end
    if self:IsFavorite(currencyID) then
        return false
    end
    local info = self:GetCurrencyInfo(currencyID)
    if not info then
        return false
    end
    table.insert(self.db.favorites, {
        id = currencyID,
        name = info.name,
        icon = info.iconFileID
    })
    table.sort(self.db.favorites, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    E:SendMessage("ART_CURRENCYCHECK_FAVORITES_CHANGED")
    return true
end

function Currency:RemoveFavorite(currencyID)
    currencyID = tonumber(currencyID)
    if not currencyID then
        return false
    end
    for i, fav in ipairs(self.db.favorites) do
        if fav.id == currencyID then
            table.remove(self.db.favorites, i)
            E:SendMessage("ART_CURRENCYCHECK_FAVORITES_CHANGED")
            return true
        end
    end
    return false
end

function Currency:ToggleFavorite(currencyID)
    currencyID = tonumber(currencyID)
    if not currencyID or currencyID <= 0 then
        return false, "INVALID_ID"
    end
    if self:IsFavorite(currencyID) then
        if self:RemoveFavorite(currencyID) then
            return true, "REMOVED", currencyID
        end
        return false, "FAILED"
    end
    if not self:GetCurrencyInfo(currencyID) then
        return false, "UNKNOWN_CURRENCY"
    end
    if self:AddFavorite(currencyID) then
        return true, "ADDED", currencyID
    end
    return false, "FAILED"
end

-- Query

function Currency:GetStats()
    local s = {
        count = 0,
        sum = 0,
        avg = 0,
        min = nil,
        max = nil
    }
    if not (self.state and self.state.results) then
        s.min = 0;
        s.max = 0;
        return s
    end
    for _, e in pairs(self.state.results) do
        if e.status == self.STATUS_RESPONDED and type(e.amount) == "number" then
            s.count = s.count + 1
            s.sum = s.sum + e.amount
            if not s.min or e.amount < s.min then
                s.min = e.amount
            end
            if not s.max or e.amount > s.max then
                s.max = e.amount
            end
        end
    end
    s.avg = s.count > 0 and math.floor(s.sum / s.count) or 0
    s.min = s.min or 0
    s.max = s.max or 0
    return s
end

function Currency:GetSortedResults(sortMode)
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

    sortMode = sortMode or "amount"

    if sortMode == "name" then
        table.sort(list, function(a, b)
            return (a.entry.displayName or "") < (b.entry.displayName or "")
        end)
    else
        table.sort(list, function(a, b)
            local aa = (a.entry.status == self.STATUS_RESPONDED) and (a.entry.amount or 0) or -1
            local bb = (b.entry.status == self.STATUS_RESPONDED) and (b.entry.amount or 0) or -1
            if aa ~= bb then
                return aa > bb
            end
            return (a.entry.displayName or "") < (b.entry.displayName or "")
        end)
    end
    return list
end

local baseOnProfileChanged = Currency.OnProfileChanged
function Currency:OnProfileChanged()
    baseOnProfileChanged(self)
    if self:IsEnabled() then
        E:SendMessage("ART_CURRENCYCHECK_FAVORITES_CHANGED")
    end
end
