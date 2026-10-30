local E, L = unpack(ART)
local T = E.Templates

local events = E:NewCallbackHandle()
events:RegisterMessage("ART_ENCOUNTERLOGS_UPDATED", function()
    if E.OptionsUI and E.OptionsUI:IsShown() then E.OptionsUI:QueueRefresh("current") end
end)

local selectedTarget, lastSendMessage

local function build()
    local mod = E:GetModule("EncounterLogs")
    local function isDisabled() return not mod:IsEnabled() end
    local selectedPull, selectedPlayer
    local function pullKey(pull) return pull.encounterID .. ":" .. pull.started end
    local function pulls() return mod:GetStore().pulls end
    local function currentPull()
        for _, pull in ipairs(pulls()) do if pullKey(pull) == selectedPull then return pull end end
        selectedPull = pulls()[1] and pullKey(pulls()[1]) or nil
        return pulls()[1]
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
    local function targets() return mod:GetSendTargets() end
    local function currentTarget()
        local list = targets()
        for _, name in ipairs(list) do if name == selectedTarget then return name end end
        selectedTarget = list[1]
        return selectedTarget
    end
    local function refresh()
        if E.RefreshOptions then E:RefreshOptions() end
    end
    local function retentionChanged()
        mod:Prune()
        E:SendMessage("ART_ENCOUNTERLOGS_UPDATED")
    end
    return {
        type = "group",
        name = L["EncounterLogs"],
        args = {
            desc = {order = 1, width = "full", build = function(parent)
                return T:Description(parent, {text = L["EncounterLogs_Desc"], sizeDelta = 1})
            end},
            status = {order = 2, width = "full", build = function(parent)
                return T:Description(parent, {text = mod:GetStatusText(), sizeDelta = 0})
            end},
            collect = {order = 10, width = "full", build = function(parent)
                return T:Checkbox(parent, {
                    disabled = isDisabled,
                    text = L["EncounterLogs_Collect"], tooltip = L["EncounterLogs_CollectDesc"],
                    get = function() return mod.db.collect == true end,
                    onChange = function(_, value) mod:SetCollecting(value); refresh() end
                })
            end},
            maxPulls = {order = 11, width = "1/3", build = function(parent)
                return T:Slider(parent, {
                    disabled = isDisabled,
                    label = L["EncounterLogs_MaxPulls"], min = 5, max = 100, step = 5,
                    get = function() return tonumber(mod.db.maxPulls) or 25 end,
                    onChange = function(value) mod.db.maxPulls = math.floor(value); retentionChanged() end
                })
            end},
            maxDays = {order = 12, width = "1/3", build = function(parent)
                return T:Slider(parent, {
                    disabled = isDisabled,
                    label = L["EncounterLogs_MaxDays"], min = 1, max = 60, step = 1,
                    get = function() return tonumber(mod.db.maxDays) or 14 end,
                    onChange = function(value) mod.db.maxDays = math.floor(value); retentionChanged() end
                })
            end},
            maxStorage = {order = 13, width = "1/3", build = function(parent)
                return T:Slider(parent, {
                    disabled = isDisabled,
                    label = L["EncounterLogs_MaxStorage"], min = 1, max = 32, step = 1,
                    format = function(value) return ("%d MB"):format(value) end,
                    get = function() return math.max(1, math.floor((tonumber(mod.db.maxStorageKB) or 4096) / 1024 + 0.5)) end,
                    onChange = function(value) mod.db.maxStorageKB = math.floor(value) * 1024; retentionChanged() end
                })
            end},
            history = {order = 20, width = "full", build = function(parent)
                return T:Header(parent, {text = L["Diagnostics_History"]})
            end},
            pull = {order = 21, width = "1/2", build = function(parent)
                return T:Dropdown(parent, {
                    disabled = isDisabled,
                    label = L["Diagnostics_Pull"], placeholder = L["EncounterLogs_NoLogs"], emptyText = L["EncounterLogs_NoLogs"],
                    values = function()
                        local values = {}
                        for _, pull in ipairs(pulls()) do values[pullKey(pull)] = mod:DescribePull(pull) end
                        return values
                    end,
                    sorting = function()
                        local list = {}
                        for _, pull in ipairs(pulls()) do list[#list + 1] = pullKey(pull) end
                        return list
                    end,
                    get = function() currentPull(); return selectedPull end,
                    onChange = function(key) selectedPull = key; selectedPlayer = nil; refresh() end
                })
            end},
            player = {order = 22, width = "1/2", build = function(parent)
                return T:Dropdown(parent, {
                    disabled = isDisabled,
                    label = L["Diagnostics_Player"], placeholder = L["EncounterLogs_NoLogs"], emptyText = L["EncounterLogs_NoLogs"],
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
                    label = L["EncounterLogs_Log"], lines = 22, autoSelect = false, maxLetters = 500000,
                    get = function() return mod:FormatReport(currentReport()):gsub("|", "||") end
                })
            end},
            copyText = {order = 24, width = "1/3", build = function(parent)
                return T:Button(parent, {
                    disabled = isDisabled,
                    text = L["EncounterLogs_CopyText"],
                    onClick = function()
                        local pull = currentPull()
                        if not pull then return end
                        T:ShowText({
                            title = mod:DescribePull(pull),
                            text = mod:ExportPull(pull):gsub("|", "||"),
                            parent = E.OptionsUI and E.OptionsUI.mainFrame
                        })
                    end,
                    disabled = function() return isDisabled() or (currentPull() == nil) end
                })
            end},
            deletePull = {order = 25, width = "1/3", build = function(parent)
                return T:Button(parent, {
                    text = L["EncounterLogs_DeletePull"],
                    onClick = function()
                        local pull = currentPull()
                        if pull then mod:DeletePull(pull); selectedPull = nil; selectedPlayer = nil; refresh() end
                    end,
                    disabled = function() return isDisabled() or (currentPull() == nil) end
                })
            end},
            clear = {order = 26, width = "1/3", build = function(parent)
                return T:Button(parent, {
                    disabled = isDisabled,
                    text = L["EncounterLogs_ClearAll"],
                    onClick = function()
                        T:Confirm({
                            key = "ART_ENCOUNTERLOGS_CLEAR", title = L["EncounterLogs"], text = L["EncounterLogs_ClearConfirm"],
                            parent = E.OptionsUI and E.OptionsUI.mainFrame,
                            onAccept = function() mod:ClearAll(); selectedPull = nil; selectedPlayer = nil; refresh() end
                        })
                    end,
                    disabled = function() return isDisabled() or (#pulls() == 0) end
                })
            end},
            shareHeader = {order = 30, width = "full", build = function(parent)
                return T:Header(parent, {text = L["EncounterLogs_ShareHeader"]})
            end},
            shareDesc = {order = 31, width = "full", build = function(parent)
                return T:Description(parent, {text = L["EncounterLogs_ShareDesc"], sizeDelta = 0})
            end},
            sendTarget = {order = 32, width = "1/2", build = function(parent)
                return T:Dropdown(parent, {
                    disabled = isDisabled,
                    label = L["EncounterLogs_SendTo"], placeholder = L["EncounterLogs_NoOfficers"], emptyText = L["EncounterLogs_NoOfficers"],
                    values = function()
                        local values = {}
                        for _, name in ipairs(targets()) do values[name] = name end
                        return values
                    end,
                    sorting = targets,
                    get = function() return currentTarget() end,
                    onChange = function(name) selectedTarget = name; refresh() end
                })
            end},
            send = {order = 33, width = "1/4", build = function(parent)
                return T:LabelAlignedButton(parent, {
                    text = L["EncounterLogs_Send"],
                    onClick = function()
                        local pull, target = currentPull(), currentTarget()
                        local ok, err = mod:SendPull(pull, target)
                        lastSendMessage = ok and L["EncounterLogs_Sent"]:format(target) or L["EncounterLogs_SendFailed"]:format(tostring(err or "?"))
                        refresh()
                    end,
                    disabled = function() return isDisabled() or (currentPull() == nil or currentTarget() == nil) end
                })
            end},
            sendResult = {order = 34, width = "full", build = function(parent)
                return T:Description(parent, {text = lastSendMessage or "", sizeDelta = 0})
            end}
        }
    }
end

local registered = false
local function registerPanel()
    local mod = E:GetModule("EncounterLogs", true)
    local collector = mod and mod:IsCollector() or false
    if collector == registered then return end
    registered = collector
    if collector then
        E:RegisterOptions("EncounterLogs", 41, build)
    else
        E.optionsContributions["EncounterLogs"] = nil
    end
    if E.OptionsUI and E.OptionsUI.mainFrame then E:RebuildOptions() end
end

registerPanel()
events:RegisterMessage("ART_ENCOUNTERLOGS_ACCESS_CHANGED", registerPanel)
