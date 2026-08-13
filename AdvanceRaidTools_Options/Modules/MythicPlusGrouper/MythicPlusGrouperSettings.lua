local E, L = unpack(ART)
local T = E.Templates
local CP = E.OptionsHelpers.CHECKER_PALETTE

local function Mod()
    return E:GetModule("MythicPlusGrouper", true)
end

local updateGroupFinder
local groupFinderPanel
local groupFinderSeason
local MythicPlusGrouperEvents = E:NewCallbackHandle()
local function queueRefresh()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
    if updateGroupFinder then updateGroupFinder(false) end
end
MythicPlusGrouperEvents:RegisterMessage("ART_MYTHIC_PLUS_GROUPER_UPDATED", queueRefresh)
MythicPlusGrouperEvents:RegisterMessage("ART_MEDIA_UPDATED", function()
    if groupFinderPanel and groupFinderPanel.tabs then
        groupFinderPanel.tabs.ReapplyHighlight()
    end
end)

local function scanStatus(mod)
    local state = mod:GetScanState()
    if not state then
        return CP.muted .. L["MythicPlusGrouper_NotScanned"] .. "|r"
    end
    if state.inProgress then
        return ("%s%s|r"):format(CP.pending, L["MythicPlusGrouper_Scanning"])
    end
    return ("%s%s|r"):format(CP.ok, L["MythicPlusGrouper_ScanComplete"])
end

local function scanButtonText(mod)
    local state = mod:GetScanState()
    if state and state.inProgress then return L["StopCheck"] end
    if state then return L["MythicPlusGrouper_ScanAgain"] end
    return L["MythicPlusGrouper_Request"]
end

local function reportScanError(err)
    if err == "IN_COMBAT" then
        E:Printf("|cffff4040%s|r", L["MythicPlusGrouper_InCombat"])
    elseif err == "IN_INSTANCE" then
        E:Printf("|cffff4040%s|r", L["MythicPlusGrouper_InInstance"])
    elseif err == "TOO_SOON" then
        E:Printf(L["CheckTooSoon"])
    elseif err then
        E:Printf("|cffff4040%s|r", err)
    end
end

local function createResultRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(20)
    local name = E:CreateFontString(row, nil, "OVERLAY", 12)
    name:SetPoint("LEFT", row, "LEFT", 6, 0)
    name:SetPoint("RIGHT", row, "CENTER", -6, 0)
    name:SetJustifyH("LEFT")
    row._name = name
    local key = E:CreateFontString(row, nil, "OVERLAY", 12)
    key:SetPoint("LEFT", row, "CENTER", 6, 0)
    key:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    key:SetJustifyH("RIGHT")
    row._key = key
    return row
end

local function updateResultRow(row, item)
    row._name:SetText(item.isMatch and (CP.ok .. item.name .. "|r") or item.name)
    if item.dungeonName and item.level then
        row._key:SetText(("%s +%d"):format(item.dungeonName, item.level))
    else
        row._key:SetText(CP.muted .. L["MythicPlusGrouper_NoKeystone"] .. "|r")
    end
end

local function getMatchItems(mod)
    local items = {}
    local owned, interested = mod:GetInterestedForOwnKey()
    local owners = mod:GetInterestedKeystoneOwners()
    for _, entry in ipairs(interested) do
        items[#items + 1] = {
            name = entry.name,
            character = entry.character,
            detail = owned and owned.mapName and owned.level
                and L["MythicPlusGrouper_InterestedInYourKey"]:format(owned.mapName, owned.level)
                or L["MythicPlusGrouper_InterestedPlayers"]
        }
    end
    for _, entry in ipairs(owners) do
        items[#items + 1] = {
            name = entry.name,
            character = entry.character,
            detail = ("%s +%d"):format(entry.dungeonName, entry.level)
        }
    end
    if #items == 0 then
        items[1] = {empty = true, name = L["MythicPlusGrouper_NoMatches"]}
    end
    return items
end

local function createMatchRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)
    local label = T:Label(row, {height = 20, accent = false})
    label.frame:SetPoint("LEFT", 4, 0)
    label.frame:SetPoint("RIGHT", -76, 0)
    row._label = label
    local invite = T:Button(row, {
        text = L["MythicPlusGrouper_Invite"],
        width = 68,
        height = 20,
        onClick = function()
            local mod = Mod()
            if mod and row._character then mod:InvitePlayer(row._character) end
        end
    })
    invite.frame:SetPoint("RIGHT", 0, 0)
    row._invite = invite
    return row
end

local function updateMatchRow(row, item)
    local text = item.detail and ("%s  —  %s"):format(item.name, item.detail) or item.name
    row._label.SetText(text)
    row._character = item.character
    row._invite.frame:SetShown(item.character and true or false)
    if item.empty then
        row._label.label:SetTextColor(0.55, 0.55, 0.55, 1)
    else
        row._label.label:SetTextColor(1, 1, 1, 1)
    end
end

local function groupFinderStatus(mod)
    local state = mod:GetScanState()
    if not state then return L["MythicPlusGrouper_NotScanned"] end
    if state.inProgress then return L["MythicPlusGrouper_Scanning"] end
    return L["MythicPlusGrouper_ScanComplete"]
end

local function refreshGroupFinderControls(mod)
    if not groupFinderPanel then return end
    if groupFinderPanel.status then
        groupFinderPanel.status.SetText(groupFinderStatus(mod))
    end
    if groupFinderPanel.tabs then
        groupFinderPanel.tabs.ActivateTab(groupFinderSeason or mod:GetSelectedSeason())
        groupFinderPanel.tabs.ReapplyHighlight()
    end
    for _, entry in ipairs(groupFinderPanel.interests or {}) do
        local visible = entry.season == (groupFinderSeason or mod:GetSelectedSeason())
        entry.checkbox.frame:SetShown(visible)
        if visible then entry.checkbox.Refresh() end
    end
    if groupFinderPanel.results then
        groupFinderPanel.results.SetItems(function() return getMatchItems(mod) end)
    end
    local popup = T:GetPopup("MythicPlusGrouperMatches")
    if popup and popup._buttons and popup._buttons[1] then
        popup._buttons[1].SetLabel(scanButtonText(mod))
    end
end

local function saveGroupFinderPosition(mod, popup)
    local point, _, relativePoint, x, y = popup:GetPoint(1)
    mod.db.groupFinderPoint = point or "CENTER"
    mod.db.groupFinderRelativePoint = relativePoint or mod.db.groupFinderPoint
    mod.db.groupFinderX = math.floor((x or 0) + 0.5)
    mod.db.groupFinderY = math.floor((y or 0) + 0.5)
end

updateGroupFinder = function(forceOpen)
    local mod = Mod()
    if not mod or not mod.db.showGroupFinder then
        if T:IsPopupActive("MythicPlusGrouperMatches") then T:HidePopup("MythicPlusGrouperMatches") end
        groupFinderPanel = nil
        return
    end
    local existing = T:GetPopup("MythicPlusGrouperMatches")
    if existing and existing:IsShown() then
        refreshGroupFinderControls(mod)
        return
    end
    if not forceOpen then return end
    groupFinderSeason = groupFinderSeason or mod:GetSelectedSeason()

    local popup
    popup = T:Popup({
        key = "MythicPlusGrouperMatches",
        title = L["MythicPlusGrouper_MatchWindowTitle"],
        themed = true,
        width = mod.db.groupFinderWidth or 500,
        height = math.max(mod.db.groupFinderHeight or 420, 390),
        anchor = {
            point = mod.db.groupFinderPoint or "CENTER",
            relativePoint = mod.db.groupFinderRelativePoint or "CENTER",
            x = mod.db.groupFinderX or 0,
            y = mod.db.groupFinderY or 0
        },
        resizable = true,
        resizeBounds = {420, 390, 800, 700},
        onMove = function(frame) saveGroupFinderPosition(mod, frame) end,
        onResize = function(frame, width, height)
            mod.db.groupFinderWidth = math.floor(width + 0.5)
            mod.db.groupFinderHeight = math.floor(height + 0.5)
            saveGroupFinderPosition(mod, frame)
            if groupFinderPanel then groupFinderPanel._relayout() end
        end,
        onCancel = function()
            mod.db.showGroupFinder = false
            groupFinderPanel = nil
            queueRefresh()
        end,
        build = function(_, body, info)
            local status = T:StatusLine(body, {text = groupFinderStatus(mod)})
            status.frame:SetPoint("TOPLEFT", 0, info.offsetY)
            status.frame:SetPoint("TOPRIGHT", 0, info.offsetY)

            local tabs
            tabs = T:TabBar(body, {
                tabs = {
                    {key = "season2", label = L["MythicPlusGrouper_Season2"]}
                },
                autoActivateFirst = false,
                onTabChange = function(seasonKey)
                    groupFinderSeason = seasonKey
                    if groupFinderPanel then
                        local visibleIndex = 0
                        for _, entry in ipairs(groupFinderPanel.interests or {}) do
                            local visible = entry.season == seasonKey
                            entry.checkbox.frame:SetShown(visible)
                            if visible then
                                visibleIndex = visibleIndex + 1
                                entry.checkbox.frame:ClearAllPoints()
                                local column = (visibleIndex - 1) % 2
                                local row = math.floor((visibleIndex - 1) / 2)
                                if column == 0 then
                                    entry.checkbox.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -72 - row * 22)
                                    entry.checkbox.frame:SetPoint("TOPRIGHT", body, "TOP", -4, -72 - row * 22)
                                else
                                    entry.checkbox.frame:SetPoint("TOPLEFT", body, "TOP", 4, -72 - row * 22)
                                    entry.checkbox.frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -72 - row * 22)
                                end
                                entry.checkbox.Refresh()
                            end
                        end
                    end
                end
            })
            tabs.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -24)
            tabs.frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -24)

            local interestLabel = T:Label(body, {
                text = L["MythicPlusGrouper_InterestHeader"],
                height = 18
            })
            interestLabel.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -52)

            local interests = {}
            for _, season in ipairs(mod:GetSeasons()) do
                for _, dungeon in ipairs(season.dungeons) do
                    local dungeonKey = dungeon.key
                    local checkbox = T:Checkbox(body, {
                        text = dungeon.name,
                        width = 196,
                        get = function() return mod:IsInterested(dungeonKey) end,
                        onChange = function(_, value) mod:SetInterested(dungeonKey, value) end
                    })
                    checkbox.frame:Hide()
                    interests[#interests + 1] = {
                        season = season.key,
                        checkbox = checkbox
                    }
                end
            end

            local timeout = T:Slider(body, {
                label = L["Timeout"],
                tooltip = {
                    title = L["Timeout"],
                    desc = L["TimeoutDesc"]
                },
                min = 3,
                max = 30,
                step = 1,
                get = function() return mod.db.timeoutSeconds or 5 end,
                onChange = function(value) mod.db.timeoutSeconds = value end
            })
            timeout.frame:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -160)
            timeout.frame:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -160)

            local panel = T:ScrollingPanel(body, {
                height = 150,
                rowHeight = 22,
                topPad = 0,
                template = "Transparent",
                createRow = createMatchRow,
                updateRow = updateMatchRow,
                items = function() return getMatchItems(mod) end
            })
            panel.frame:ClearAllPoints()
            panel.frame:SetPoint("TOPLEFT", 0, -206)
            panel.frame:SetPoint("TOPRIGHT", 0, -206)
            panel.frame:SetPoint("BOTTOMLEFT", 0, 0)
            panel.frame:SetPoint("BOTTOMRIGHT", 0, 0)
            groupFinderPanel = {
                status = status,
                tabs = tabs,
                interests = interests,
                results = panel,
                _relayout = panel._relayout
            }
            tabs.ActivateTab(groupFinderSeason)
            return 150
        end,
        buttons = {
            {
                text = scanButtonText(mod),
                onClick = function()
                    if mod then
                        local ok, err = mod:RequestGuildData()
                        if not ok then reportScanError(err) end
                    end
                    return true
                end
            },
            {text = L["Close"], preset = "cancel"}
        }
    })
    return popup
end

MythicPlusGrouperEvents:RegisterMessage("ART_MYTHIC_PLUS_GROUPER_SHOW_FINDER", function()
    local mod = Mod()
    if not mod then return end
    mod.db.showGroupFinder = true
    updateGroupFinder(true)
end)

local function buildPanel()
    local mod = Mod()
    if not mod then
        return {
            type = "group",
            name = L["MythicPlusGrouper"],
            args = {
                notice = {order = 1, build = function(parent)
                    return T:Description(parent, {text = L["LoadModule"]})
                end}
            }
        }
    end

    local args = {
        description = {
            order = 1,
            width = "full",
            build = function(parent)
                return T:Description(parent, {text = L["MythicPlusGrouper_Desc"], sizeDelta = 1})
            end
        },
        seasonTabs = {
            order = 5,
            width = "full",
            build = function(parent)
                local tabs = T:TabBar(parent, {
                    tabs = {
                        {key = "season2", label = L["MythicPlusGrouper_Season2"]}
                    },
                    autoActivateFirst = false,
                    onTabChange = function(seasonKey)
                        if mod:SetSelectedSeason(seasonKey) then E:RefreshOptions() end
                    end
                })
                tabs.ActivateTab(mod:GetSelectedSeason())
                return tabs
            end
        },
        interestHeader = {
            order = 10,
            width = "full",
            build = function(parent)
                return T:Header(parent, {text = L["MythicPlusGrouper_InterestHeader"]})
            end
        }
    }

    for _, season in ipairs(mod:GetSeasons()) do
        local seasonKey = season.key
        for index, dungeon in ipairs(season.dungeons) do
            local dungeonKey, dungeonName = dungeon.key, dungeon.name
            args["dungeon_" .. dungeonKey] = {
                order = 10 + index,
                width = "1/2",
                hidden = function() return mod:GetSelectedSeason() ~= seasonKey end,
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = dungeonName,
                        get = function() return mod:IsInterested(dungeonKey) end,
                        onChange = function(_, value) mod:SetInterested(dungeonKey, value) end
                    })
                end
            }
        end
    end

    args.refresh = {
        order = 20,
        width = "2/3",
        build = function(parent)
            return T:LabelAlignedButton(parent, {
                text = function()
                    return scanButtonText(mod)
                end,
                emphasize = true,
                disabled = function() return not IsInGuild() or not mod:IsEnabled() end,
                onClick = function()
                    if mod:IsScanInProgress() then
                        mod:CancelScan()
                        return
                    end
                    local ok, err = mod:RequestGuildData()
                    if not ok then reportScanError(err) end
                end
            })
        end
    }
    args.timeout = {
        order = 20.5,
        width = "1/3",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Timeout"],
                tooltip = {
                    title = L["Timeout"],
                    desc = L["TimeoutDesc"]
                },
                min = 3,
                max = 30,
                step = 1,
                get = function() return mod.db.timeoutSeconds or 5 end,
                onChange = function(value) mod.db.timeoutSeconds = value end
            })
        end
    }
    args.scanStatus = {
        order = 22,
        width = "full",
        build = function(parent)
            return T:StatusLine(parent, {text = function() return scanStatus(mod) end})
        end
    }
    args.showGroupFinder = {
        order = 23,
        width = "full",
        build = function(parent)
            return T:LabelAlignedButton(parent, {
                text = L["MythicPlusGrouper_OpenGroupFinder"],
                onClick = function()
                    mod.db.showGroupFinder = true
                    updateGroupFinder(true)
                end
            })
        end
    }
    args.keysHeader = {
        order = 30,
        width = "full",
        build = function(parent)
            return T:Header(parent, {text = L["MythicPlusGrouper_KeysHeader"]})
        end
    }
    args.resultsLegend = {
        order = 30.25,
        width = "full",
        build = function(parent)
            return T:Description(parent, {text = L["MythicPlusGrouper_ResultsLegend"]})
        end
    }
    args.keystoneLevelRange = {
        order = 30.5,
        width = "full",
        build = function(parent)
            return T:RangeSlider(parent, {
                label = L["MythicPlusGrouper_KeystoneLevelRange"],
                min = 1,
                max = 25,
                step = 1,
                low = mod.db.minKeystoneLevel or 1,
                high = mod.db.maxKeystoneLevel or 25,
                get = function() return mod.db.minKeystoneLevel or 1, mod.db.maxKeystoneLevel or 25 end,
                onChange = function(low, high) mod:SetKeystoneLevelRange(low, high) end,
                onCommit = function() mod:NotifyUpdated() end
            })
        end
    }
    args.results = {
        order = 31,
        width = "full",
        build = function(parent)
            return T:ScrollingPanel(parent, {
                height = 210,
                rowHeight = 20,
                template = "Transparent",
                forwardWheelToOuter = true,
                createRow = createResultRow,
                updateRow = updateResultRow,
                items = function() return mod:GetScanResults() end
            })
        end
    }

    return {type = "group", name = L["MythicPlusGrouper"], args = args}
end

E:RegisterOptions("MythicPlusGrouper", 30.25, buildPanel, {core = true})
