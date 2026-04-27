local E, L = unpack(ART)
local T = E.Templates

local function buildCDMTweaksTab(mod, isDisabled)
    local function refreshLive()
        mod:Refresh()
    end

    local function refreshPanel()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("current")
        end
    end

    local args = {
        intro = {
            order = 10,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_CDMTweaksLongDesc"],
                    sizeDelta = 0
                })
            end
        },

        -- Centering section
        centerHeader = {
            order = 20,
            build = function(parent)
                return T:Header(parent, {
                    text = L["QoL_CDMCenter"]
                })
            end
        },
        centerDesc = {
            order = 21,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_CDMCenterDesc"],
                    sizeDelta = 0
                })
            end
        },
        centerEssential = {
            order = 22,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_CDMCenterEssential"],
                    get = function()
                        return mod.db.centerEssential
                    end,
                    onChange = function(_, v)
                        mod.db.centerEssential = v and true or false
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        },
        centerUtility = {
            order = 23,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_CDMCenterUtility"],
                    get = function()
                        return mod.db.centerUtility
                    end,
                    onChange = function(_, v)
                        mod.db.centerUtility = v and true or false
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        },
        centerBuffIcon = {
            order = 24,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_CDMCenterBuffIcon"],
                    get = function()
                        return mod.db.centerBuffIcon
                    end,
                    onChange = function(_, v)
                        mod.db.centerBuffIcon = v and true or false
                        refreshLive()
                    end,
                    disabled = isDisabled,
                    tooltip = {
                        title = L["QoL_CDMCenterBuffIcon"],
                        desc = L["QoL_CDMCenterBuffDesc"]
                    }
                })
            end
        },
        centerBuffBar = {
            order = 25,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_CDMCenterBuffBar"],
                    get = function()
                        return mod.db.centerBuffBar
                    end,
                    onChange = function(_, v)
                        mod.db.centerBuffBar = v and true or false
                        refreshLive()
                    end,
                    disabled = isDisabled,
                    tooltip = {
                        title = L["QoL_CDMCenterBuffBar"],
                        desc = L["QoL_CDMCenterBuffDesc"]
                    }
                })
            end
        },

        -- Aura CD override
        auraHeader = {
            order = 30,
            build = function(parent)
                return T:Header(parent, {
                    text = L["QoL_CDMAuraOverride"]
                })
            end
        },
        auraDesc = {
            order = 31,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_CDMAuraOverrideDesc"],
                    sizeDelta = 0
                })
            end
        },
        auraOverride = {
            order = 32,
            width = "full",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_CDMAuraOverrideEnable"],
                    get = function()
                        return mod.db.auraOverride
                    end,
                    onChange = function(_, v)
                        mod.db.auraOverride = v and true or false
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        },

        -- Stack font section
        stackHeader = {
            order = 40,
            build = function(parent)
                return T:Header(parent, {
                    text = L["QoL_CDMStackFont"]
                })
            end
        },
        stackDesc = {
            order = 41,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_CDMStackFontDesc"],
                    sizeDelta = 0
                })
            end
        },
        stackEnabled = {
            order = 42,
            width = "full",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_CDMStackFontEnable"],
                    get = function()
                        return mod.db.stackFontEnabled
                    end,
                    onChange = function(_, v)
                        mod.db.stackFontEnabled = v and true or false
                        refreshLive()
                        refreshPanel()
                    end,
                    disabled = isDisabled
                })
            end
        },
        stackViewer = {
            order = 43,
            width = "full",
            build = function(parent)
                local values = {
                    EssentialCooldownViewer = L["QoL_CDMViewerEssential"],
                    UtilityCooldownViewer = L["QoL_CDMViewerUtility"],
                    BuffIconCooldownViewer = L["QoL_CDMViewerBuffIcon"],
                    BuffBarCooldownViewer = L["QoL_CDMViewerBuffBar"]
                }
                return T:Dropdown(parent, {
                    label = L["QoL_CDMStackViewer"],
                    values = values,
                    get = function()
                        local v = mod.db.stackFontViewer
                        if not values[v] then
                            v = "EssentialCooldownViewer"
                            mod.db.stackFontViewer = v
                        end
                        return v
                    end,
                    onChange = function(v)
                        mod.db.stackFontViewer = v
                        refreshLive()
                        refreshPanel()
                    end,
                    disabled = function()
                        return isDisabled() or not mod.db.stackFontEnabled
                    end,
                    tooltip = {
                        title = L["QoL_CDMStackViewer"],
                        desc = L["QoL_CDMStackViewerDesc"]
                    }
                })
            end
        }
    }

    local function stackDisabled()
        return isDisabled() or not mod.db.stackFontEnabled
    end

    args.stackFontSize = {
        order = 44,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["FontSize"],
                min = 6,
                max = 40,
                step = 1,
                value = mod.db.stackFontSize,
                onChange = function(v)
                    mod.db.stackFontSize = math.floor(v)
                    refreshLive()
                end,
                get = function()
                    return mod.db.stackFontSize
                end,
                disabled = stackDisabled
            })
        end
    }

    args.stackColor = {
        order = 45,
        width = "1/2",
        build = function(parent)
            return T:ColorSwatch(parent, {
                label = L["QoL_CDMStackColor"],
                labelTop = true,
                hasAlpha = true,
                r = mod.db.stackColor[1],
                g = mod.db.stackColor[2],
                b = mod.db.stackColor[3],
                a = mod.db.stackColor[4],
                onChange = function(r, g, b, a)
                    mod.db.stackColor = {r, g, b, a}
                    refreshLive()
                end,
                disabled = stackDisabled
            })
        end
    }

    return args
end

E:RegisterQoLFeatureSettings("CDMTweaks", buildCDMTweaksTab)
