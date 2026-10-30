local E, L = unpack(ART)
local T = E.Templates

local events = E:NewCallbackHandle()
events:RegisterMessage("ART_DIAGNOSTICS_UPDATED", function()
    if E.OptionsUI and E.OptionsUI:IsShown() then E.OptionsUI:QueueRefresh("current") end
end)

local function build(mod, isDisabled)
    local selectedPull, selectedPlayer
    local function pullKey(pull) return pull.encounterID .. ":" .. pull.started end
    local function currentPull()
        local history = mod.db.history or {}
        for _, pull in ipairs(history) do if pullKey(pull) == selectedPull then return pull end end
        selectedPull = history[1] and pullKey(history[1]) or nil
        return history[1]
    end
    local function players()
        local pull = currentPull()
        local list = {}
        for name in pairs(pull and pull.reports or {}) do list[#list + 1] = name end
        table.sort(list)
        return list
    end
    local function currentReport()
        local pull = currentPull()
        if not pull then selectedPlayer = nil; return end
        if not selectedPlayer or not pull.reports[selectedPlayer] then
            local own = E:GetUnitFullName("player", true)
            selectedPlayer = pull.reports[own] and own or players()[1]
        end
        return pull.reports[selectedPlayer]
    end
    local function refresh()
        if E.RefreshOptions then E:RefreshOptions() end
    end
    return {
        __desc = {order = 3, width = "full", build = function(parent)
            return T:Description(parent, {
                text = L["Diagnostics_Desc"], sizeDelta = 1,
                tooltip = function() return mod:GetStatusDetails() end
            })
        end},
        share = {order = 10, width = "full", build = function(parent)
            return T:Checkbox(parent, {
                    disabled = isDisabled,
                text = L["Diagnostics_Share"], tooltip = L["Diagnostics_ShareDesc"],
                get = function() return mod.db.shareWithLeader == true end,
                onChange = function(_, value) mod.db.shareWithLeader = value and true or false end
            })
        end},
        detailed = {order = 11, width = "full", build = function(parent)
            return T:Checkbox(parent, {
                    disabled = isDisabled,
                text = L["Diagnostics_Detailed"], tooltip = L["Diagnostics_DetailedDesc"],
                get = function() return mod.db.detailed == true end,
                onChange = function(_, value) mod.db.detailed = value and true or false end
            })
        end},
        timings = {order = 12, width = "1/2", build = function(parent)
            return T:Checkbox(parent, {
                    disabled = isDisabled,
                text = L["Diagnostics_Timing"], tooltip = L["Diagnostics_TimingDesc"],
                get = function() return E.db.global.diagnosticsTiming == true end,
                onChange = function(_, value) E.db.global.diagnosticsTiming = value and true or false; refresh() end
            })
        end},
        reload = {order = 13, width = "1/2", build = function(parent)
            return T:Button(parent, {
                text = L["Diagnostics_Reload"], onClick = function() if not InCombatLockdown() then C_UI.Reload() end end,
                disabled = function() return isDisabled() or (InCombatLockdown() or (E.db.global.diagnosticsTiming == true) == E.DiagnosticTimingEnabled) end
            })
        end},
        history = {order = 20, width = "full", build = function(parent)
            return T:Header(parent, {text = L["Diagnostics_History"]})
        end},
        pull = {order = 21, width = "1/2", build = function(parent)
            return T:Dropdown(parent, {
                    disabled = isDisabled,
                label = L["Diagnostics_Pull"], placeholder = L["Diagnostics_NoReports"], emptyText = L["Diagnostics_NoReports"],
                values = function()
                    local values = {}
                    for _, pull in ipairs(mod.db.history or {}) do
                        values[pullKey(pull)] = date("%d/%m %H:%M:%S", pull.started) .. " - " .. pull.encounterName
                    end
                    return values
                end,
                sorting = function()
                    local list = {}
                    for _, pull in ipairs(mod.db.history or {}) do list[#list + 1] = pullKey(pull) end
                    return list
                end,
                get = function() currentPull(); return selectedPull end,
                onChange = function(key) selectedPull = key; selectedPlayer = nil; refresh() end
            })
        end},
        player = {order = 22, width = "1/2", build = function(parent)
            return T:Dropdown(parent, {
                    disabled = isDisabled,
                label = L["Diagnostics_Player"], placeholder = L["Diagnostics_NoReports"], emptyText = L["Diagnostics_NoReports"],
                values = function()
                    local values = {}
                    for _, name in ipairs(players()) do values[name] = name end
                    return values
                end,
                sorting = players,
                get = function() currentReport(); return selectedPlayer end,
                onChange = function(name) selectedPlayer = name; refresh() end
            })
        end},
        report = {order = 23, width = "full", build = function(parent)
            return T:TextViewer(parent, {
                    disabled = isDisabled,
                label = L["Diagnostics_Report"], lines = 20, autoSelect = false, maxLetters = 500000,
                get = function() return mod:FormatReport(currentReport()):gsub("|", "||") end
            })
        end},
        clear = {order = 24, width = "1/2", build = function(parent)
            return T:Button(parent, {
                text = L["Diagnostics_Clear"], onClick = function() mod:ClearHistory(); refresh() end,
                disabled = function() return isDisabled() or (mod.active ~= nil or #(mod.db.history or {}) == 0) end
            })
        end}
    }
end

E:RegisterQoLFeatureSettings("Diagnostics", build)
