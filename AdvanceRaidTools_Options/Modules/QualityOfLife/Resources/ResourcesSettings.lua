local E, L, P = unpack(ART)
local T = E.Templates

local POWER_TEXT_MODES = {
    off = "None",
    numeric = "QoL_PowerTextNumeric",
    percent = "QoL_PowerTextPercent"
}

local ROLE_ORDER = {"TANK", "HEALER", "DAMAGER"}
local ROLE_LABELS = {
    TANK = "QoL_RoleTank",
    HEALER = "QoL_RoleHealer",
    DAMAGER = "QoL_RoleDamager"
}

local function sharedMediaValues(kind)
    return E:MediaList(kind)
end

local function textModeValues()
    local out = {}
    for k, labelKey in pairs(POWER_TEXT_MODES) do
        out[k] = L[labelKey] or labelKey
    end
    return out
end

local function buildColumnLabel(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(22)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetAllPoints(f)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetText(text)
    E:RegisterAccentText(fs)
    return {
        frame = f,
        height = 22,
        label = fs
    }
end

local function buildResourcesTab(mod, isDisabled)
    local function refreshLive()
        mod:Refresh()
    end

    local function refreshPanel()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("current")
        end
    end

    local function healthDisabled()
        return isDisabled() or not mod.db.showHealthBar
    end
    local function powerDisabled()
        return isDisabled() or not mod.db.showPowerBar
    end

    local args = {
        desc = {
            order = 10,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_ResourcesLongDesc"],
                    sizeDelta = 0
                })
            end
        },

        rolesHeader = {
            order = 20,
            build = function(parent)
                return T:Header(parent, {
                    text = L["QoL_ActiveForRoles"]
                })
            end
        },

        rolesDesc = {
            order = 21,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_ActiveForRolesDesc"],
                    sizeDelta = 0
                })
            end
        }
    }

    for i, role in ipairs(ROLE_ORDER) do
        args["role_" .. role] = {
            order = 22 + i,
            width = "compact",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L[ROLE_LABELS[role]] or role,
                    get = function()
                        return mod.db.roles[role]
                    end,
                    onChange = function(_, v)
                        mod.db.roles[role] = v and true or false
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        }
    end

    args.visibilityHeader = {
        order = 30,
        build = function(parent)
            return T:Header(parent, {
                text = L["Display"]
            })
        end
    }

    args.showHealthBar = {
        order = 31,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["QoL_ShowHealthBar"],
                get = function()
                    return mod.db.showHealthBar
                end,
                onChange = function(_, v)
                    mod.db.showHealthBar = v and true or false
                    refreshLive()
                    refreshPanel()
                end,
                disabled = isDisabled
            })
        end
    }

    args.showPowerBar = {
        order = 32,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["QoL_ShowPowerBar"],
                get = function()
                    return mod.db.showPowerBar
                end,
                onChange = function(_, v)
                    mod.db.showPowerBar = v and true or false
                    refreshLive()
                    refreshPanel()
                end,
                disabled = isDisabled
            })
        end
    }

    args.showClassFrame = {
        order = 33,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["QoL_ShowClassFrame"],
                get = function()
                    return mod.db.showClassFrame
                end,
                onChange = function(_, v)
                    mod.db.showClassFrame = v and true or false
                    refreshLive()
                end,
                disabled = isDisabled
            })
        end
    }

    args.barSettingsHeader = {
        order = 40,
        build = function(parent)
            return T:Header(parent, {
                text = L["QoL_BarSettings"]
            })
        end
    }

    args.healthBarLabel = {
        order = 41,
        width = "1/2",
        build = function(parent)
            return buildColumnLabel(parent, L["QoL_HealthBar"])
        end
    }

    args.powerBarLabel = {
        order = 42,
        width = "1/2",
        build = function(parent)
            return buildColumnLabel(parent, L["QoL_PowerBar"])
        end
    }

    args.healthWidth = {
        order = 43,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Width"],
                min = 50,
                max = 600,
                step = 1,
                value = mod.db.healthWidth,
                get = function()
                    return mod.db.healthWidth
                end,
                onChange = function(v)
                    mod.db.healthWidth = math.floor(v)
                    refreshLive()
                end,
                disabled = healthDisabled
            })
        end
    }

    args.powerWidth = {
        order = 44,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Width"],
                min = 50,
                max = 600,
                step = 1,
                value = mod.db.powerWidth,
                get = function()
                    return mod.db.powerWidth
                end,
                onChange = function(v)
                    mod.db.powerWidth = math.floor(v)
                    refreshLive()
                end,
                disabled = powerDisabled
            })
        end
    }

    args.healthHeight = {
        order = 45,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Height"],
                min = 6,
                max = 100,
                step = 1,
                value = mod.db.healthHeight,
                get = function()
                    return mod.db.healthHeight
                end,
                onChange = function(v)
                    mod.db.healthHeight = math.floor(v)
                    refreshLive()
                end,
                disabled = healthDisabled
            })
        end
    }

    args.powerHeight = {
        order = 46,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Height"],
                min = 6,
                max = 100,
                step = 1,
                value = mod.db.powerHeight,
                get = function()
                    return mod.db.powerHeight
                end,
                onChange = function(v)
                    mod.db.powerHeight = math.floor(v)
                    refreshLive()
                end,
                disabled = powerDisabled
            })
        end
    }

    args.healthTexture = {
        order = 47,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["StatusbarTexture"],
                values = function() return sharedMediaValues("statusbar") end,
                get = function()
                    return mod.db.healthTexture
                end,
                onChange = function(v)
                    mod.db.healthTexture = v
                    refreshLive()
                end,
                disabled = healthDisabled
            })
        end
    }

    args.powerTexture = {
        order = 48,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["StatusbarTexture"],
                values = function() return sharedMediaValues("statusbar") end,
                get = function()
                    return mod.db.texture
                end,
                onChange = function(v)
                    mod.db.texture = v
                    refreshLive()
                end,
                disabled = powerDisabled
            })
        end
    }

    args.showHealthBorder = {
        order = 49,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["QoL_ShowBorder"],
                labelTop = true,
                get = function()
                    return mod.db.showHealthBorder
                end,
                onChange = function(_, v)
                    mod.db.showHealthBorder = v and true or false
                    refreshLive()
                    refreshPanel()
                end,
                disabled = healthDisabled
            })
        end
    }

    args.showPowerBorder = {
        order = 50,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["QoL_ShowBorder"],
                labelTop = true,
                get = function()
                    return mod.db.showPowerBorder
                end,
                onChange = function(_, v)
                    mod.db.showPowerBorder = v and true or false
                    refreshLive()
                    refreshPanel()
                end,
                disabled = powerDisabled
            })
        end
    }

    args.healthBorderColor = {
        order = 51,
        width = "1/2",
        build = function(parent)
            return T:ColorSwatch(parent, {
                label = L["BorderColor"],
                labelTop = true,
                hasAlpha = true,
                r = mod.db.healthBorderColor[1],
                g = mod.db.healthBorderColor[2],
                b = mod.db.healthBorderColor[3],
                a = mod.db.healthBorderColor[4],
                onChange = function(r, g, b, a)
                    mod.db.healthBorderColor = {r, g, b, a}
                    refreshLive()
                end,
                disabled = function()
                    return healthDisabled() or not mod.db.showHealthBorder
                end
            })
        end
    }

    args.powerBorderColor = {
        order = 52,
        width = "1/2",
        build = function(parent)
            return T:ColorSwatch(parent, {
                label = L["BorderColor"],
                labelTop = true,
                hasAlpha = true,
                r = mod.db.powerBorderColor[1],
                g = mod.db.powerBorderColor[2],
                b = mod.db.powerBorderColor[3],
                a = mod.db.powerBorderColor[4],
                onChange = function(r, g, b, a)
                    mod.db.powerBorderColor = {r, g, b, a}
                    refreshLive()
                end,
                disabled = function()
                    return powerDisabled() or not mod.db.showPowerBorder
                end
            })
        end
    }

    args.barTextHeader = {
        order = 60,
        build = function(parent)
            return T:Header(parent, {
                text = L["QoL_BarText"]
            })
        end
    }

    args.healthTextLabel = {
        order = 61,
        width = "1/2",
        build = function(parent)
            return buildColumnLabel(parent, L["QoL_HealthBar"])
        end
    }

    args.powerTextLabel = {
        order = 62,
        width = "1/2",
        build = function(parent)
            return buildColumnLabel(parent, L["QoL_PowerBar"])
        end
    }

    args.healthTextMode = {
        order = 63,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["QoL_TextMode"],
                values = textModeValues(),
                get = function()
                    return mod.db.healthTextMode
                end,
                onChange = function(v)
                    mod.db.healthTextMode = v
                    refreshLive()
                    refreshPanel()
                end,
                disabled = healthDisabled
            })
        end
    }

    args.powerTextMode = {
        order = 64,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["QoL_TextMode"],
                values = textModeValues(),
                get = function()
                    return mod.db.powerTextMode
                end,
                onChange = function(v)
                    mod.db.powerTextMode = v
                    refreshLive()
                    refreshPanel()
                end,
                disabled = powerDisabled
            })
        end
    }

    args.healthFont = {
        order = 65,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["FontFamily"],
                values = function() return sharedMediaValues("font") end,
                get = function()
                    return mod.db.healthFont
                end,
                onChange = function(v)
                    mod.db.healthFont = v
                    refreshLive()
                end,
                disabled = function()
                    return healthDisabled() or mod.db.healthTextMode == "off"
                end
            })
        end
    }

    args.powerFont = {
        order = 66,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["FontFamily"],
                values = function() return sharedMediaValues("font") end,
                get = function()
                    return mod.db.font
                end,
                onChange = function(v)
                    mod.db.font = v
                    refreshLive()
                end,
                disabled = function()
                    return powerDisabled() or mod.db.powerTextMode == "off"
                end
            })
        end
    }

    args.healthFontSize = {
        order = 67,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["FontSize"],
                min = 6,
                max = 40,
                step = 1,
                value = mod.db.healthFontSize,
                get = function()
                    return mod.db.healthFontSize
                end,
                onChange = function(v)
                    mod.db.healthFontSize = math.floor(v)
                    refreshLive()
                end,
                disabled = function()
                    return healthDisabled() or mod.db.healthTextMode == "off"
                end
            })
        end
    }

    args.powerFontSize = {
        order = 68,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["FontSize"],
                min = 6,
                max = 40,
                step = 1,
                value = mod.db.fontSize,
                get = function()
                    return mod.db.fontSize
                end,
                onChange = function(v)
                    mod.db.fontSize = math.floor(v)
                    refreshLive()
                end,
                disabled = function()
                    return powerDisabled() or mod.db.powerTextMode == "off"
                end
            })
        end
    }

    args.positionHeader = {
        order = 80,
        build = function(parent)
            return T:Header(parent, {
                text = L["Position"]
            })
        end
    }

    args.positionDesc = {
        order = 81,
        build = function(parent)
            return T:Description(parent, {
                text = L["QoL_ResourcesEditModeHint"],
                sizeDelta = 0
            })
        end
    }

    args.restoreDefaults = {
        order = 90,
        width = "full",
        build = function(parent)
            return T:Button(parent, {
                text = L["RestoreDefaults"],
                confirm = L["QoL_RestoreDefaultsConfirm"],
                confirmTitle = L["RestoreDefaults"],
                onClick = function()
                    local defaults = P.modules.QoL_Resources
                    for k, v in pairs(defaults) do
                        if k ~= "enabled" then
                            if type(v) == "table" then
                                mod.db[k] = CopyTable(v)
                            else
                                mod.db[k] = v
                            end
                        end
                    end
                    refreshLive()
                    refreshPanel()
                end,
                disabled = isDisabled
            })
        end
    }

    return args
end

E:RegisterQoLFeatureSettings("Resources", buildResourcesTab)
