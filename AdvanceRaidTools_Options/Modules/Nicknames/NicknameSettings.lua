local E, L = unpack(ART)
local T = E.Templates

local function buildNicknamesPanel()
    local mod = E:GetModule("Nicknames", true)

    -- sanity check

    if not mod then
        return {
            type = "group",
            name = L["Nicknames"],
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
        return not mod:IsEnabled()
    end

    -- Integrations tab args
    local integrationArgs = {
        header = {
            order = 1,
            build = function(parent)
                return T:Header(parent, {
                    text = L["EnableIntegrations"]
                })
            end
        },
        desc = {
            order = 2,
            build = function(parent)
                return T:Description(parent, {
                    text = L["AddonIntegration"],
                    sizeDelta = 1
                })
            end
        }
    }

    for _, entry in ipairs(mod.integrationDisplay) do
        local addonKey = entry.key
        local isBlizzard = addonKey == "Blizzard"
        local label = L[entry.labelKey] or entry.labelKey
        local tip = L[entry.labelKey .. "_desc"]

        integrationArgs[addonKey] = {
            order = entry.order + 10,
            width = "normal",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = label,
                    get = function()
                        return mod.db.integrations[addonKey]
                    end,
                    onChange = function(_, val)
                        mod:SetIntegrationEnabled(addonKey, val)
                    end,
                    disabled = function()
                        if isModuleDisabled() then
                            return true
                        end
                        if isBlizzard then
                            return false
                        end
                        return not C_AddOns.IsAddOnLoaded(addonKey)
                    end,
                    tooltip = tip and {
                        title = label,
                        desc = tip
                    } or {
                        title = label
                    }
                })
            end
        }
    end

    -- Panel core
    return {
        type = "group",
        name = L["Nicknames"],
        childGroups = "tab",
        args = {
            intro = {
                order = 1,
                build = function(parent)
                    return T:Description(parent, {
                        text = L["NickDesc"],
                        sizeDelta = 1
                    })
                end
            },

            general = {
                type = "group",
                order = 2,
                name = L["General"],
                args = {
                    header = {
                        order = 1,
                        build = function(parent)
                            return T:Header(parent, {
                                text = L["NicknameSetup"]
                            })
                        end
                    },

                    myNickname = {
                        order = 2,
                        width = "1/2",
                        build = function(parent)
                            return T:EditBox(parent, {
                                label = L["YourNickname"],
                                commitOn = "enter",
                                get = function()
                                    return mod.db.myNickname or ""
                                end,
                                validate = function(text)
                                    if text and #text > 12 then
                                        E:Printf(L["NickLimit"])
                                        return false
                                    end
                                    return true
                                end,
                                onCommit = function(text)
                                    text = strtrim(text or "")
                                    mod:Set("player", text ~= "" and text or nil)
                                end,
                                disabled = isModuleDisabled,
                                tooltip = {
                                    title = L["YourNickname"],
                                    desc = L["ShownNick"]
                                }
                            })
                        end
                    }
                }
            },

            integrations = {
                type = "group",
                order = 3,
                name = L["Integrations"],
                args = integrationArgs
            }
        }
    }
end

E:RegisterOptions("Nicknames", 20, buildNicknamesPanel)
