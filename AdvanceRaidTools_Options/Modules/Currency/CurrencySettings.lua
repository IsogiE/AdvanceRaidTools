local E, L = unpack(ART)
local T = E.Templates
local CP = E.OptionsHelpers.CHECKER_PALETTE

local function mod()
    return E:GetModule("Currency", true)
end

local SORT_MODES = {
    amount = L["SortByAmount"],
    name = L["SortByName"]
}
local SORT_ORDER = {"amount", "name"}

local NO_FAV_KEY = 0
local FAV_NAME_MAX = 28

local ui = {
    sortMode = "amount",
    contextOverride = nil,
    pendingID = nil,
    favoriteSelection = NO_FAV_KEY
}

local CurrencyEvents = E:NewCallbackHandle()
local function queueRefresh()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
end
CurrencyEvents:RegisterMessage("ART_CURRENCYCHECK_UPDATED", queueRefresh)
CurrencyEvents:RegisterMessage("ART_CURRENCYCHECK_FAVORITES_CHANGED", queueRefresh)

local function truncate(s, n)
    s = tostring(s or "")
    if #s > n then
        return s:sub(1, n - 1) .. "…"
    end
    return s
end

local function reportCheckError(err, id)
    if not err or err == "DISABLED" then
        return
    end
    if err == "NO_CONTEXT" then
        E:Printf(L["CurrencyCheckNoContext"])
    elseif err == "INVALID_ID" then
        E:Printf(L["CurrencyCheckInvalidID"])
    elseif err == "UNKNOWN_CURRENCY" then
        E:Printf(L["CurrencyCheckUnknown"]:format(tostring(id)))
    elseif err == "TOO_SOON" then
        E:Printf(L["CheckTooSoon"])
    else
        E:Printf(L["CurrencyCheckFailed"], err or "?")
    end
end

local function reportFavoriteAction(action, id)
    if action == "INVALID_ID" then
        E:Printf(L["CurrencyCheckInvalidID"])
    elseif action == "UNKNOWN_CURRENCY" then
        E:Printf(L["CurrencyCheckUnknown"]:format(tostring(id)))
    end
end

local function getPreviewText(m, id)
    if not id or id <= 0 then
        return CP.muted .. L["CurrencyEnterID"] .. "|r"
    end
    local info = m:GetCurrencyInfo(id)
    if not info then
        return CP.missing .. L["CurrencyInvalidID"]:format(id) .. "|r"
    end
    local icon = info.iconFileID and ("|T" .. info.iconFileID .. ":16:16:0:0|t ") or ""
    local fav = m:IsFavorite(id) and ("  " .. CP.muted .. "(" .. L["Favorited"] .. ")|r") or ""
    return icon .. "|cffffffff" .. info.name .. "|r" .. fav
end

local function getFavoriteChoices(m)
    local t = {
        [NO_FAV_KEY] = L["FavNone"]
    }
    for _, fav in ipairs(m:GetFavorites()) do
        t[fav.id] = truncate(fav.name, FAV_NAME_MAX)
    end
    return t
end

local function getResultText(m, sortMode)
    local state = m.state
    if not state then
        return ""
    end

    local list = m:GetSortedResults(sortMode or "amount")
    local lines = {}

    for _, item in ipairs(list) do
        local entry = item.entry
        local nameColor = entry.isSelf and CP.self or E:ClassColorCode(entry.class)
        local valueColor, valueText

        if entry.status == m.STATUS_RESPONDED then
            if type(entry.amount) == "number" and entry.amount > 0 then
                valueColor, valueText = CP.ok, E:FormatAmount(entry.amount)
            else
                valueColor, valueText = CP.zero, E:FormatAmount(entry.amount or 0)
            end
        elseif entry.status == m.STATUS_PENDING then
            valueColor, valueText = CP.pending, L["Pending"]
        elseif entry.status == m.STATUS_NO_ADDON then
            valueColor, valueText = CP.noAddon, L["NotInstalled"]
        elseif entry.status == m.STATUS_OFFLINE then
            valueColor, valueText = CP.offline, L["Offline"]
        else
            valueColor, valueText = "|cffffffff", "?"
        end

        lines[#lines + 1] = nameColor .. entry.displayName .. "|r   " .. valueColor .. valueText .. "|r"
    end

    if #lines == 0 then
        return CP.muted .. L["CurrencyCheckEmpty"] .. "|r"
    end
    return table.concat(lines, "\n")
end

local function getStatusText(m)
    local state = m.state
    if not state then
        return ""
    end

    if state.inProgress then
        local prefix = state.currencyName and ("|cffffffff" .. state.currencyName .. "|r  -  ") or ""
        if state.expected > 0 then
            return prefix .. ("|cffffcc00%s|r  %d / %d"):format(L["Checking"], state.received, state.expected)
        end
        return prefix .. "|cffffcc00" .. L["Checking"] .. "|r"
    end

    if state.completedAt > 0 then
        local icon = state.currencyIcon and ("|T" .. state.currencyIcon .. ":16:16:0:0|t ") or ""
        return icon .. "|cffffffff" .. (state.currencyName or "?") .. "|r"
    end

    return ""
end

local function exportResults(m)
    local state = m.state
    if not state or not state.currencyID then
        return nil
    end
    if state.completedAt == 0 and not state.inProgress then
        return nil
    end

    local lines = {("Currency: %s"):format(state.currencyName or "?")}

    local list = m:GetSortedResults("amount")
    for _, item in ipairs(list) do
        local entry = item.entry
        local name = entry.displayName or item.key or "?"
        if entry.status == m.STATUS_RESPONDED then
            lines[#lines + 1] = ("%s: %s"):format(name, E:FormatAmount(entry.amount or 0))
        elseif entry.status == m.STATUS_NO_ADDON then
            lines[#lines + 1] = ("%s: (not installed)"):format(name)
        elseif entry.status == m.STATUS_OFFLINE then
            lines[#lines + 1] = ("%s: (offline)"):format(name)
        elseif entry.status == m.STATUS_PENDING then
            lines[#lines + 1] = ("%s: (pending)"):format(name)
        end
    end

    return table.concat(lines, "\n")
end

local function buildPanel()
    local m = mod()
    if not m then
        return {
            type = "group",
            name = L["CurrencyChecker"],
            args = {
                notice = {
                    order = 1,
                    build = function(parent)
                        return T:Description(parent, {
                            text = L["LoadModule"],
                            sizeDelta = 1
                        })
                    end
                }
            }
        }
    end

    local function isModuleDisabled()
        local mm = mod()
        return not (mm and mm:IsEnabled())
    end

    local runner = T:CheckerPanel({
        mod = mod,
        ui = ui,
        orderBase = 20,

        sortModes = SORT_MODES,
        sortOrder = SORT_ORDER,

        onStart = function(c, ctx)
            return c:StartCheck(ui.pendingID, ctx)
        end,
        reportStartError = function(_, err)
            reportCheckError(err, ui.pendingID)
        end,
        statusText = function(c)
            return getStatusText(c)
        end,
        resultsText = function(c)
            return getResultText(c, ui.sortMode)
        end,
        exportResults = function(c)
            return exportResults(c)
        end,
        resultsHeight = 320
    })

    local header = {
        desc = {
            order = 1,
            build = function(parent)
                return T:Description(parent, {
                    text = L["CurrencyCheckerDesc"],
                    sizeDelta = 1
                })
            end
        },
        spacer = {
            order = 1.5,
            build = function(parent)
                return T:Spacer(parent, {
                    height = 12
                })
            end
        },
        pickHeader = {
            order = 2,
            build = function(parent)
                return T:Header(parent, {
                    text = L["PickCurrency"]
                })
            end
        },

        idInput = {
            order = 10,
            width = "1/3",
            build = function(parent)
                return T:EditBox(parent, {
                    label = L["CurrencyID"],
                    commitOn = "enter",
                    tooltip = {
                        title = L["CurrencyID"],
                        desc = L["CurrencyIDDesc"]
                    },
                    get = function()
                        local id = ui.pendingID
                        return (id and id > 0) and tostring(id) or ""
                    end,
                    validate = function(text)
                        if text == nil or text == "" then
                            return true
                        end
                        if tonumber(text) == nil then
                            E:Printf(L["CurrencyIDMustBeNumber"])
                            return false
                        end
                        return true
                    end,
                    onCommit = function(text)
                        local id = tonumber(text)
                        ui.pendingID = (id and id > 0) and id or nil
                        local cc = mod()
                        if cc and ui.pendingID and cc:IsFavorite(ui.pendingID) then
                            ui.favoriteSelection = ui.pendingID
                        else
                            ui.favoriteSelection = NO_FAV_KEY
                        end
                        queueRefresh()
                    end,
                    disabled = isModuleDisabled
                })
            end
        },

        favSel = {
            order = 11,
            width = "1/3",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["Favorites"],
                    tooltip = {
                        title = L["Favorites"],
                        desc = L["FavoritesDesc"]
                    },
                    values = function()
                        local cc = mod()
                        return cc and getFavoriteChoices(cc) or {
                            [NO_FAV_KEY] = L["FavNone"]
                        }
                    end,
                    get = function()
                        return ui.favoriteSelection
                    end,
                    onChange = function(v)
                        ui.favoriteSelection = v
                        local n = tonumber(v)
                        ui.pendingID = (n and n > 0) and n or nil
                        queueRefresh()
                    end,
                    disabled = isModuleDisabled
                })
            end
        },

        favToggle = {
            order = 12,
            width = "1/3",
            build = function(parent)
                return T:LabelAlignedButton(parent, {
                    text = function()
                        local cc = mod()
                        if cc and ui.pendingID and ui.pendingID > 0 and cc:IsFavorite(ui.pendingID) then
                            return L["RemoveFavorite"]
                        end
                        return L["SaveFavorite"]
                    end,
                    tooltip = {
                        title = L["SaveFavorite"],
                        desc = L["SaveFavoriteDesc"]
                    },
                    onClick = function()
                        local cc = mod()
                        if not cc then
                            return
                        end
                        local id = ui.pendingID
                        local ok, action, resultID = cc:ToggleFavorite(id)
                        reportFavoriteAction(action, id)
                        if ok and action == "REMOVED" and ui.favoriteSelection == resultID then
                            ui.favoriteSelection = NO_FAV_KEY
                        end
                    end,
                    disabled = isModuleDisabled
                })
            end
        },

        preview = {
            order = 13,
            width = "full",
            build = function(parent)
                return T:StatusLine(parent, {
                    height = 22,
                    sizeDelta = 1,
                    text = function()
                        local cc = mod()
                        return cc and getPreviewText(cc, ui.pendingID) or ""
                    end
                })
            end
        },

        runHeader = {
            order = 19,
            build = function(parent)
                return T:Header(parent, {
                    text = L["RunCheck"]
                })
            end
        }
    }

    return {
        type = "group",
        name = L["CurrencyChecker"],
        args = T:MergeArgs(header, runner)
    }
end

E:RegisterOptions("Currency", 31, buildPanel)
