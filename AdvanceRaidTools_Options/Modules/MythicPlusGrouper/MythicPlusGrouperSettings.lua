local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    NONE = "None",
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    OUTLINE_SLUG = "Slug Outline",
    MONOCHROME = "Monochrome",
    MONOCHROMEOUTLINE = "Monochrome Outline"
}
local OUTLINE_ORDER = {"NONE", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG", "MONOCHROME", "MONOCHROMEOUTLINE"}

local function Mod()
    return E:GetModule("MythicPlusGrouper", true)
end

local function buildPanel()
    local mod = Mod()
    if not mod then
        return {
            type = "group",
            name = L["MythicPlusGrouper"],
            args = {
                notice = {order = 1, build = function(parent) return T:Description(parent, {text = L["LoadModule"]}) end}
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
                        {key = "season1", label = L["MythicPlusGrouper_Season1"]},
                        {key = "season2", label = L["MythicPlusGrouper_Season2"]}
                    },
                    autoActivateFirst = false,
                    onTabChange = function(seasonKey)
                        if mod:SetSelectedSeason(seasonKey) then
                            E:RefreshOptions()
                        end
                    end
                })
                tabs.ActivateTab(mod:GetSelectedSeason())
                return tabs
            end
        },
        interestHeader = {
            order = 10,
            width = "full",
            build = function(parent) return T:Header(parent, {text = L["MythicPlusGrouper_InterestHeader"]}) end
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
        width = "1/3",
        build = function(parent)
            return T:Button(parent, {
                text = L["MythicPlusGrouper_Request"],
                disabled = function() return not IsInGuild() end,
                onClick = function()
                    local ok, err = mod:RequestGuildData()
                    if not ok and err then E:Printf("|cffff4040%s|r", err) end
                end
            })
        end
    }
    args.interestNote = {
        order = 21,
        width = "2/3",
        build = function(parent)
            return T:Description(parent, {text = L["MythicPlusGrouper_InterestNote"]})
        end
    }
    args.keysHeader = {
        order = 30,
        width = "full",
        build = function(parent) return T:Header(parent, {text = L["MythicPlusGrouper_KeysHeader"]}) end
    }
    for _, season in ipairs(mod:GetSeasons()) do
        local seasonKey = season.key
        for index, dungeon in ipairs(season.dungeons) do
            local dungeonKey, dungeonName = dungeon.key, dungeon.name
            args["owners_" .. dungeonKey] = {
                order = 30 + index,
                width = "1/2",
                hidden = function() return mod:GetSelectedSeason() ~= seasonKey end,
                build = function(parent)
                    return T:MultilineEditBox(parent, {
                        label = dungeonName,
                        default = mod:GetOwnersText(dungeonKey),
                        get = function() return mod:GetOwnersText(dungeonKey) end,
                        lines = 4,
                        readOnly = true,
                        forwardWheelToOuter = true
                    })
                end
            }
        end
    end
    args.windowHeader = {
        order = 40,
        width = "full",
        build = function(parent) return T:Header(parent, {text = L["MythicPlusGrouper_WindowHeader"]}) end
    }
    args.showWindow = {
        order = 41,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["MythicPlusGrouper_ShowWindow"],
                get = function() return mod.db.showWindow and true or false end,
                onChange = function(_, value) mod.db.showWindow = value and true or false; mod:RefreshFrame() end
            })
        end
    }
    args.unlock = {
        order = 42,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["MythicPlusGrouper_UnlockWindow"],
                get = function() return mod.db.unlocked and true or false end,
                onChange = function(_, value) mod:SetUnlocked(value) end
            })
        end
    }
    args.keystoneLevelRange = {
        order = 30.5,
        width = "full",
        build = function(parent)
            return T:RangeSlider(parent, {
                label = L["MythicPlusGrouper_KeystoneLevelRange"],
                min = 1,
                max = 20,
                step = 1,
                low = mod.db.minKeystoneLevel or 1,
                high = mod.db.maxKeystoneLevel or 20,
                get = function() return mod.db.minKeystoneLevel or 1, mod.db.maxKeystoneLevel or 20 end,
                onChange = function(low, high)
                    mod:SetKeystoneLevelRange(low, high)
                end
            })
        end
    }
    args.hideInInstance = {
        order = 44,
        width = "full",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["MythicPlusGrouper_HideInInstance"],
                get = function() return mod.db.hideInInstance and true or false end,
                onChange = function(_, value) mod.db.hideInInstance = value and true or false; mod:RefreshFrame() end
            })
        end
    }
    args.background = {
        order = 45,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["MythicPlusGrouper_Background"],
                get = function() return mod.db.backgroundEnabled ~= false end,
                onChange = function(_, value) mod.db.backgroundEnabled = value and true or false; mod:RefreshFrame() end
            })
        end
    }
    args.border = {
        order = 46,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["MythicPlusGrouper_Border"],
                get = function() return mod.db.borderEnabled ~= false end,
                onChange = function(_, value) mod.db.borderEnabled = value and true or false; mod:RefreshFrame() end
            })
        end
    }
    args.backgroundColor = {
        order = 47,
        width = "1/2",
        build = function(parent)
            local color = type(mod.db.backgroundColor) == "table" and mod.db.backgroundColor or {}
            local function setColor(r, g, b, a)
                mod.db.backgroundColor = {r = r, g = g, b = b, a = a or 1}
                mod:RefreshFrame()
            end
            return T:ColorSwatch(parent, {
                label = L["MythicPlusGrouper_BackgroundColor"], labelTop = true, hasAlpha = true,
                r = color.r or 0, g = color.g or 0, b = color.b or 0, a = color.a or 0.72,
                get = function()
                    local c = type(mod.db.backgroundColor) == "table" and mod.db.backgroundColor or {}
                    return c.r or 0, c.g or 0, c.b or 0, c.a or 0.72
                end,
                onChange = setColor,
                onCancel = setColor
            })
        end
    }
    args.borderColor = {
        order = 48,
        width = "1/2",
        build = function(parent)
            local color = type(mod.db.borderColor) == "table" and mod.db.borderColor or {}
            local function setColor(r, g, b, a)
                mod.db.borderColor = {r = r, g = g, b = b, a = a or 1}
                mod:RefreshFrame()
            end
            return T:ColorSwatch(parent, {
                label = L["MythicPlusGrouper_BorderColor"], labelTop = true, hasAlpha = true,
                r = color.r or 0.35, g = color.g or 0.35, b = color.b or 0.35, a = color.a or 1,
                get = function()
                    local c = type(mod.db.borderColor) == "table" and mod.db.borderColor or {}
                    return c.r or 0.35, c.g or 0.35, c.b or 0.35, c.a or 1
                end,
                onChange = setColor,
                onCancel = setColor
            })
        end
    }
    args.font = {
        order = 50,
        width = "1/3",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["TodoList_Font"],
                values = function() return E:MediaList("font") end,
                get = function() return mod.db.fontName end,
                onChange = function(value) mod.db.fontName = value; mod:RefreshFrame() end
            })
        end
    }
    args.fontSize = {
        order = 51,
        width = "1/3",
        build = function(parent)
            return T:Slider(parent, {
                label = L["TodoList_FontSize"], min = 8, max = 40, step = 1,
                get = function() return mod.db.fontSize or 14 end,
                onChange = function(value) mod.db.fontSize = math.floor(tonumber(value) or 14); mod:RefreshFrame() end
            })
        end
    }
    args.outline = {
        order = 52,
        width = "1/3",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["TodoList_FontOutline"], values = OUTLINE_VALUES, sorting = OUTLINE_ORDER,
                get = function() return mod.db.fontOutline or "OUTLINE" end,
                onChange = function(value) mod.db.fontOutline = value; mod:RefreshFrame() end
            })
        end
    }
    args.textColor = {
        order = 53,
        width = "1/2",
        build = function(parent)
            local color = type(mod.db.textColor) == "table" and mod.db.textColor or {}
            local function setColor(r, g, b, a)
                mod.db.textColor = {r = r, g = g, b = b, a = a or 1}
                mod:RefreshFrame()
            end
            return T:ColorSwatch(parent, {
                label = L["TodoList_TextColor"], labelTop = true, hasAlpha = false,
                r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a or 1,
                get = function()
                    local c = type(mod.db.textColor) == "table" and mod.db.textColor or {}
                    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
                end,
                onChange = setColor,
                onCancel = setColor
            })
        end
    }
    return {type = "group", name = L["MythicPlusGrouper"], args = args}
end

E:RegisterOptions("MythicPlusGrouper", 30.25, buildPanel, {core = true})
