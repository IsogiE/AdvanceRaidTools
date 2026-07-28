local E, L = unpack(ART)
local T = E.Templates

local function Mod()
    return E:GetModule("InviteTool", true)
end

local function rankValues()
    local mod = Mod()
    local values = mod and mod:GetGuildRankChoices() or {}
    return values
end

local function rankSorting()
    local mod = Mod()
    if not mod then
        return {}
    end
    local _, sorting = mod:GetGuildRankChoices()
    return sorting
end

local function buildPanel()
    local mod = Mod()
    if not mod then
        return {
            type = "group",
            name = L["InviteTool"],
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

    local function notInGuild()
        return not IsInGuild()
    end

    return {
        type = "group",
        name = L["InviteTool"],
        args = {
            description = {
                order = 1,
                width = "full",
                build = function(parent)
                    return T:Description(parent, {
                        text = L["InviteTool_Desc"],
                        sizeDelta = 1
                    })
                end
            },

            guildHeader = {
                order = 10,
                width = "full",
                build = function(parent)
                    return T:Header(parent, {
                        text = L["InviteTool_GuildInvite"]
                    })
                end
            },
            guildRanks = {
                order = 11,
                width = "2/3",
                build = function(parent)
                    return T:Dropdown(parent, {
                        label = L["InviteTool_GuildRanks"],
                        values = rankValues,
                        sorting = rankSorting,
                        multi = true,
                        get = function(rank)
                            return mod:IsInviteRankSelected(rank)
                        end,
                        onChange = function(rank, selected)
                            mod:SetInviteRankSelected(rank, selected)
                        end,
                        disabled = notInGuild,
                        tooltip = {
                            title = L["InviteTool_GuildRanks"],
                            desc = L["InviteTool_GuildRanksDesc"]
                        }
                    })
                end
            },
            inviteButton = {
                order = 12,
                width = "1/3",
                build = function(parent)
                    return T:LabelAlignedButton(parent, {
                        text = L["InviteTool_InviteButton"],
                        onClick = function()
                            mod:InviteSelectedGuildRanks()
                        end,
                        disabled = notInGuild,
                        tooltip = {
                            title = L["InviteTool_InviteButton"],
                            desc = L["InviteTool_InviteButtonDesc"]
                        }
                    })
                end
            },

            keywordHeader = {
                order = 20,
                width = "full",
                build = function(parent)
                    return T:Header(parent, {
                        text = L["InviteTool_KeywordHeader"]
                    })
                end
            },
            keywordEnabled = {
                order = 21,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["InviteTool_EnableKeywords"],
                        get = function()
                            return mod.db.keywordEnabled and true or false
                        end,
                        onChange = function(_, value)
                            mod.db.keywordEnabled = value and true or false
                        end,
                        tooltip = {
                            title = L["InviteTool_EnableKeywords"],
                            desc = L["InviteTool_EnableKeywordsDesc"]
                        }
                    })
                end
            },
            keywords = {
                order = 22,
                width = "2/3",
                build = function(parent)
                    return T:EditBox(parent, {
                        label = L["InviteTool_Keywords"],
                        default = mod.db.keywords or "",
                        get = function()
                            return mod.db.keywords or ""
                        end,
                        commitOn = "enter",
                        onCommit = function(value)
                            mod:SetKeywords(value)
                            return mod.db.keywords
                        end,
                        tooltip = {
                            title = L["InviteTool_Keywords"],
                            desc = L["InviteTool_KeywordsDesc"]
                        }
                    })
                end
            },
            keywordNote = {
                order = 23,
                width = "full",
                build = function(parent)
                    return T:Description(parent, {
                        text = L["InviteTool_KeywordMatchDesc"]
                    })
                end
            },

            acceptHeader = {
                order = 30,
                width = "full",
                build = function(parent)
                    return T:Header(parent, {
                        text = L["InviteTool_AutoAcceptHeader"]
                    })
                end
            },
            acceptFriends = {
                order = 31,
                width = "1/2",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["InviteTool_AutoAcceptFriends"],
                        get = function()
                            return mod.db.autoAcceptFriends and true or false
                        end,
                        onChange = function(_, value)
                            mod.db.autoAcceptFriends = value and true or false
                        end,
                        tooltip = {
                            title = L["InviteTool_AutoAcceptFriends"],
                            desc = L["InviteTool_AutoAcceptFriendsDesc"]
                        }
                    })
                end
            },
            acceptGuild = {
                order = 32,
                width = "1/2",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["InviteTool_AutoAcceptGuild"],
                        get = function()
                            return mod.db.autoAcceptGuild and true or false
                        end,
                        onChange = function(_, value)
                            mod.db.autoAcceptGuild = value and true or false
                            if value then
                                mod:RequestGuildRoster()
                            end
                        end,
                        disabled = notInGuild,
                        tooltip = {
                            title = L["InviteTool_AutoAcceptGuild"],
                            desc = L["InviteTool_AutoAcceptGuildDesc"]
                        }
                    })
                end
            },

            promoteHeader = {
                order = 40,
                width = "full",
                build = function(parent)
                    return T:Header(parent, {
                        text = L["InviteTool_AutoPromoteHeader"]
                    })
                end
            },
            promoteEnabled = {
                order = 41,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["InviteTool_EnableAutoPromote"],
                        get = function()
                            return mod.db.autoPromoteEnabled and true or false
                        end,
                        onChange = function(_, value)
                            mod.db.autoPromoteEnabled = value and true or false
                            if value then
                                mod:RequestGuildRoster()
                                mod:ScheduleAutoPromote()
                            end
                        end,
                        disabled = notInGuild,
                        tooltip = {
                            title = L["InviteTool_EnableAutoPromote"],
                            desc = L["InviteTool_EnableAutoPromoteDesc"]
                        }
                    })
                end
            },
            promoteRanks = {
                order = 42,
                width = "2/3",
                build = function(parent)
                    return T:Dropdown(parent, {
                        label = L["InviteTool_PromoteRanks"],
                        values = rankValues,
                        sorting = rankSorting,
                        multi = true,
                        get = function(rank)
                            return mod:IsPromoteRankSelected(rank)
                        end,
                        onChange = function(rank, selected)
                            mod:SetPromoteRankSelected(rank, selected)
                        end,
                        disabled = notInGuild,
                        tooltip = {
                            title = L["InviteTool_PromoteRanks"],
                            desc = L["InviteTool_PromoteRanksDesc"]
                        }
                    })
                end
            },
            promoteNicknames = {
                order = 43,
                width = "full",
                build = function(parent)
                    return T:EditBox(parent, {
                        label = L["InviteTool_PromoteNicknames"],
                        default = mod.db.promoteNicknames or "",
                        get = function()
                            return mod.db.promoteNicknames or ""
                        end,
                        commitOn = "enter",
                        onCommit = function(value)
                            mod:SetPromoteNicknames(value)
                            return mod.db.promoteNicknames
                        end,
                        tooltip = {
                            title = L["InviteTool_PromoteNicknames"],
                            desc = L["InviteTool_PromoteNicknamesDesc"]
                        }
                    })
                end
            },
            promoteNote = {
                order = 44,
                width = "full",
                build = function(parent)
                    return T:Description(parent, {
                        text = L["InviteTool_AutoPromoteNote"]
                    })
                end
            }
        }
    }
end

E:RegisterOptions("InviteTool", 30.5, buildPanel, {
    core = true
})
