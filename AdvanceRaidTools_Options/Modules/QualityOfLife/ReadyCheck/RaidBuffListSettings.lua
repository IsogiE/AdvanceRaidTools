local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    NONE = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    OUTLINE_SLUG = "Slug Outline",
    MONOCHROME = L["Monochrome"],
    MONOCHROMEOUTLINE = "Monochrome Outline"
}
local OUTLINE_ORDER = {
    "NONE",
    "OUTLINE",
    "THICKOUTLINE",
    "OUTLINE_SLUG",
    "MONOCHROME",
    "MONOCHROMEOUTLINE"
}

local function refresh(mod)
    if mod.Refresh then
        mod:Refresh()
    end
end

local function buildRaidBuffListTab(mod, isDisabled)
    return {
        scale = {
            order = 10,
            width = "1/2",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["Scale"],
                    min = 0.75,
                    max = 1.5,
                    step = 0.05,
                    value = tonumber(mod.db.scale) or 1,
                    get = function()
                        return tonumber(mod.db.scale) or 1
                    end,
                    onChange = function(value)
                        mod.db.scale = value
                        refresh(mod)
                    end,
                    format = function(value)
                        return ("%d%%"):format(math.floor(value * 100 + 0.5))
                    end,
                    disabled = isDisabled
                })
            end
        },

        test = {
            order = 11,
            width = "1/2",
            build = function(parent)
                return T:LabelAlignedButton(parent, {
                    text = L["Test"],
                    tooltip = {
                        title = L["Test"],
                        desc = L["QoL_RaidBuffListTestDesc"]
                    },
                    onClick = function()
                        mod:Test()
                    end,
                    disabled = isDisabled
                })
            end
        },

        resetPosition = {
            order = 12,
            width = "full",
            build = function(parent)
                return T:Button(parent, {
                    text = L["QoL_RaidBuffListResetPosition"],
                    onClick = function()
                        mod:ResetPosition()
                    end,
                    disabled = isDisabled
                })
            end
        },

        textHeader = {
            order = 20,
            width = "full",
            build = function(parent)
                return T:Header(parent, {
                    text = L["QoL_RaidBuffListTextAppearance"]
                })
            end
        },

        font = {
            order = 21,
            width = "1/3",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["Font"],
                    values = function()
                        return E:MediaList("font")
                    end,
                    get = function()
                        return mod.db.fontName or "PT Sans Narrow"
                    end,
                    onChange = function(value)
                        mod.db.fontName = value
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        },

        fontSize = {
            order = 22,
            width = "1/3",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["QoL_RaidBuffListFontSize"],
                    min = 8,
                    max = 22,
                    step = 1,
                    value = tonumber(mod.db.fontSize) or 11,
                    get = function()
                        return tonumber(mod.db.fontSize) or 11
                    end,
                    onChange = function(value)
                        mod.db.fontSize = math.floor(tonumber(value) or 11)
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        },

        fontOutline = {
            order = 23,
            width = "1/3",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["Outline"],
                    values = OUTLINE_VALUES,
                    sorting = OUTLINE_ORDER,
                    get = function()
                        return mod.db.fontOutline or "OUTLINE"
                    end,
                    onChange = function(value)
                        mod.db.fontOutline = value
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        },

        textColor = {
            order = 24,
            width = "1/2",
            build = function(parent)
                local color =
                    type(mod.db.textColor) == "table" and mod.db.textColor or {}
                local function setColor(r, g, b, a)
                    mod.db.textColor = {
                        r = r,
                        g = g,
                        b = b,
                        a = a or 1
                    }
                    refresh(mod)
                end

                return T:ColorSwatch(parent, {
                    label = L["QoL_RaidBuffListTextColor"],
                    labelTop = true,
                    r = color.r or color[1] or 1,
                    g = color.g or color[2] or 1,
                    b = color.b or color[3] or 1,
                    a = color.a or color[4] or 1,
                    hasAlpha = false,
                    get = function()
                        local current =
                            type(mod.db.textColor) == "table" and
                                mod.db.textColor or {}
                        return current.r or current[1] or 1,
                            current.g or current[2] or 1,
                            current.b or current[3] or 1,
                            current.a or current[4] or 1
                    end,
                    onChange = setColor,
                    onCancel = setColor,
                    disabled = isDisabled
                })
            end
        },

        useClassColors = {
            order = 25,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_RaidBuffListClassColors"],
                    get = function()
                        return mod.db.useClassColors ~= false
                    end,
                    onChange = function(_, value)
                        mod.db.useClassColors = value and true or false
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        },

        backgroundHeader = {
            order = 30,
            width = "full",
            build = function(parent)
                return T:Header(parent, {
                    text = L["Background"]
                })
            end
        },

        backgroundEnabled = {
            order = 31,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_RaidBuffListEnableBackground"],
                    get = function()
                        return mod.db.backgroundEnabled ~= false
                    end,
                    onChange = function(_, value)
                        mod.db.backgroundEnabled = value and true or false
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        },

        borderEnabled = {
            order = 32,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = L["QoL_RaidBuffListEnableBorder"],
                    get = function()
                        return mod.db.borderEnabled ~= false
                    end,
                    onChange = function(_, value)
                        mod.db.borderEnabled = value and true or false
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        }
    }
end

E:RegisterQoLFeatureSettings("RaidBuffList", buildRaidBuffListTab)
