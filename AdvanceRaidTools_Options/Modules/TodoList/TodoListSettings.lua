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
    return E:GetModule("TodoList", true)
end

local function buildPanel()
    local mod = Mod()
    if not mod then
        return {
            type = "group",
            name = L["TodoList"],
            args = {
                notice = {
                    order = 1,
                    build = function(parent)
                        return T:Description(parent, {text = L["LoadModule"], sizeDelta = 1})
                    end
                }
            }
        }
    end

    return {
        type = "group",
        name = L["TodoList"],
        args = {
            description = {
                order = 1,
                width = "full",
                build = function(parent)
                    return T:Description(parent, {text = L["TodoList_Desc"], sizeDelta = 1})
                end
            },
            editorHeader = {
                order = 10,
                width = "full",
                build = function(parent)
                    return T:Header(parent, {text = L["TodoList_EditorHeader"]})
                end
            },
            editor = {
                order = 11,
                width = "full",
                build = function(parent)
                    return T:MultilineEditBox(parent, {
                        label = L["TodoList_EditorLabel"],
                        default = mod.db.text or "",
                        get = function() return mod.db.text or "" end,
                        lines = 12,
                        maxLetters = 100000,
                        forwardWheelToOuter = true,
                        onTextChanged = function(value, userInput)
                            if userInput then
                                mod:SetText(value)
                            end
                        end
                    })
                end
            },
            editorHelp = {
                order = 12,
                width = "full",
                build = function(parent)
                    return T:Description(parent, {text = L["TodoList_EditorHelp"]})
                end
            },
            reset = {
                order = 13,
                width = "1/4",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["TodoList_ResetAll"],
                        confirm = L["TodoList_ResetConfirm"],
                        confirmTitle = L["TodoList_ResetAll"],
                        onClick = function() mod:ResetAll() end
                    })
                end
            },
            import = {
                order = 14,
                width = "1/4",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["Import"],
                        onClick = function()
                            E:PromptMultiline({
                                key = "ART_TODO_LIST_IMPORT",
                                title = L["TodoList_ImportTitle"],
                                parent = E.OptionsUI and E.OptionsUI.frame,
                                input = {multiline = 10, default = "", maxLetters = 200000},
                                onAccept = function(value)
                                    local ok, err = mod:ImportListString(value or "")
                                    if ok then
                                        E:Printf(L["TodoList_Imported"])
                                        if E.RefreshOptions then E:RefreshOptions() end
                                    else
                                        E:Printf("|cffff4040%s|r", err or L["ImportInvalid"])
                                    end
                                end
                            })
                        end
                    })
                end
            },
            export = {
                order = 15,
                width = "1/4",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["Export"],
                        onClick = function()
                            E:ShowText({
                                key = "ART_TODO_LIST_EXPORT",
                                title = L["TodoList_ExportTitle"],
                                parent = E.OptionsUI and E.OptionsUI.frame,
                                viewer = {text = mod:ExportListString(), lines = 10}
                            })
                        end
                    })
                end
            },
            shareGuild = {
                order = 16,
                width = "1/4",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["TodoList_ShareGuild"],
                        disabled = function() return not IsInGuild() end,
                        onClick = function()
                            local ok, err = mod:ShareToGuild()
                            if ok then
                                E:Printf(L["TodoList_SharedGuild"])
                            elseif err then
                                E:Printf("|cffff4040%s|r", err)
                            end
                        end
                    })
                end
            },
            shareParty = {
                order = 17,
                width = "1/3",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["TodoList_ShareParty"],
                        disabled = function() return not IsInGroup() or IsInRaid() end,
                        onClick = function()
                            local ok, err = mod:ShareToParty()
                            if ok then
                                E:Printf(L["TodoList_SharedParty"])
                            elseif err then
                                E:Printf("|cffff4040%s|r", err)
                            end
                        end
                    })
                end
            },
            shareRaid = {
                order = 18,
                width = "1/3",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["TodoList_ShareRaid"],
                        disabled = function() return not IsInRaid() end,
                        onClick = function()
                            local ok, err = mod:ShareToRaid()
                            if ok then
                                E:Printf(L["TodoList_SharedRaid"])
                            elseif err then
                                E:Printf("|cffff4040%s|r", err)
                            end
                        end
                    })
                end
            },
            shareWhisper = {
                order = 19,
                width = "1/3",
                build = function(parent)
                    return T:Button(parent, {
                        text = L["TodoList_ShareWhisper"],
                        onClick = function()
                            local ok, err, target = mod:ShareToLastWhisper()
                            if ok then
                                E:Printf(L["TodoList_SharedWhisper"], target)
                            elseif err then
                                E:Printf("|cffff4040%s|r", err)
                            end
                        end
                    })
                end
            },
            appearanceHeader = {
                order = 20,
                width = "full",
                build = function(parent)
                    return T:Header(parent, {text = L["TodoList_AppearanceHeader"]})
                end
            },
            shown = {
                order = 21,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["TodoList_ShowNote"],
                        get = function() return mod.db.shown and true or false end,
                        onChange = function(_, value)
                            mod.db.shown = value and true or false
                            mod:Refresh()
                        end
                    })
                end
            },
            hideInInstance = {
                order = 22,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["TodoList_HideInInstance"],
                        get = function() return mod.db.hideInInstance and true or false end,
                        onChange = function(_, value)
                            mod.db.hideInInstance = value and true or false
                            mod:Refresh()
                        end
                    })
                end
            },
            unlocked = {
                order = 23,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["TodoList_UnlockFrame"],
                        get = function() return mod.db.unlocked and true or false end,
                        onChange = function(_, value) mod:SetUnlocked(value) end
                    })
                end
            },
            background = {
                order = 24,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["TodoList_Background"],
                        get = function() return mod.db.backgroundEnabled ~= false end,
                        onChange = function(_, value)
                            mod.db.backgroundEnabled = value and true or false
                            mod:ApplyAppearance()
                        end
                    })
                end
            },
            border = {
                order = 25,
                width = "1/3",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["TodoList_Border"],
                        get = function() return mod.db.borderEnabled ~= false end,
                        onChange = function(_, value)
                            mod.db.borderEnabled = value and true or false
                            mod:ApplyAppearance()
                        end
                    })
                end
            },
            appearanceSpacer = {
                order = 26,
                width = "1/3",
                build = function(parent)
                    return T:Description(parent, {text = ""})
                end
            },
            font = {
                order = 27,
                width = "1/3",
                build = function(parent)
                    return T:Dropdown(parent, {
                        label = L["TodoList_Font"],
                        values = function() return E:MediaList("font") end,
                        get = function() return mod.db.fontName end,
                        onChange = function(value)
                            mod.db.fontName = value
                            mod:Refresh()
                        end
                    })
                end
            },
            fontSize = {
                order = 28,
                width = "1/3",
                build = function(parent)
                    return T:Slider(parent, {
                        label = L["TodoList_FontSize"],
                        min = 8,
                        max = 40,
                        step = 1,
                        get = function() return mod.db.fontSize or 14 end,
                        onChange = function(value)
                            mod.db.fontSize = math.floor(tonumber(value) or 14)
                            mod:Refresh()
                        end
                    })
                end
            },
            fontOutline = {
                order = 29,
                width = "1/3",
                build = function(parent)
                    return T:Dropdown(parent, {
                        label = L["TodoList_FontOutline"],
                        values = OUTLINE_VALUES,
                        sorting = OUTLINE_ORDER,
                        get = function() return mod.db.fontOutline or "OUTLINE" end,
                        onChange = function(value)
                            mod.db.fontOutline = value
                            mod:Refresh()
                        end
                    })
                end
            },
            textColor = {
                order = 30,
                width = "1/2",
                build = function(parent)
                    local color = type(mod.db.textColor) == "table" and mod.db.textColor or {}
                    local function setColor(r, g, b, a)
                        mod.db.textColor = {r = r, g = g, b = b, a = a or 1}
                        mod:Refresh()
                    end
                    return T:ColorSwatch(parent, {
                        label = L["TodoList_TextColor"],
                        labelTop = true,
                        r = color.r or color[1] or 1,
                        g = color.g or color[2] or 1,
                        b = color.b or color[3] or 1,
                        a = color.a or color[4] or 1,
                        hasAlpha = false,
                        get = function()
                            local current = type(mod.db.textColor) == "table" and mod.db.textColor or {}
                            return current.r or current[1] or 1,
                                current.g or current[2] or 1,
                                current.b or current[3] or 1,
                                current.a or current[4] or 1
                        end,
                        onChange = setColor,
                        onCancel = setColor
                    })
                end
            }
        }
    }
end

E:RegisterOptions("TodoList", 30.6, buildPanel, {core = true})
