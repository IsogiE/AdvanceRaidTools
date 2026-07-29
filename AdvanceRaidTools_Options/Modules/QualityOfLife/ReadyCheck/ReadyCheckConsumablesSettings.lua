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

local DEFAULT_POSITION = {
    point = "CENTER",
    x = 0,
    y = 160
}

local function buildReadyCheckConsumablesTab(mod, isDisabled)
    local positionWidget

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
                    text = function()
                        return mod:IsTesting() and "Stop Testing" or L["Test"]
                    end,
                    onClick = function()
                        if positionWidget then
                            positionWidget:SetUnlocked(false)
                        elseif mod:IsUnlocked() then
                            mod:SetUnlocked(false)
                        end
                        mod:Test()
                    end,
                    disabled = isDisabled
                })
            end
        },

        iconSize = {
            order = 20,
            width = "1/2",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["QoL_ReadyCheckConsumablesIconSize"],
                    min = 32,
                    max = 64,
                    step = 1,
                    value = tonumber(mod.db.iconSize) or 44,
                    get = function()
                        return tonumber(mod.db.iconSize) or 44
                    end,
                    onChange = function(value)
                        mod.db.iconSize = value
                        refresh(mod)
                    end,
                    format = function(value)
                        return ("%d px"):format(value)
                    end,
                    disabled = isDisabled
                })
            end
        },

        textHeader = {
            order = 30,
            width = "full",
            build = function(parent)
                return T:Header(parent, {
                    text = L["QoL_ReadyCheckConsumablesTextAppearance"]
                })
            end
        },

        font = {
            order = 31,
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
            order = 32,
            width = "1/3",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["QoL_ReadyCheckConsumablesFontSize"],
                    min = 8,
                    max = 24,
                    step = 1,
                    value = tonumber(mod.db.fontSize) or 10,
                    get = function()
                        return tonumber(mod.db.fontSize) or 10
                    end,
                    onChange = function(value)
                        mod.db.fontSize = math.floor(tonumber(value) or 10)
                        refresh(mod)
                    end,
                    disabled = isDisabled
                })
            end
        },

        fontOutline = {
            order = 33,
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
            order = 34,
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
                    label = L["Color"],
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

        position = {
            order = 90,
            width = "full",
            build = function(parent)
                positionWidget = T:PositionSectionWidget(parent, {
                    anchor = function()
                        return mod.frame or mod:CreateDisplay()
                    end,
                    label = L["QoL_ReadyCheckConsumables"],
                    getPosition = function()
                        return mod.db.position or DEFAULT_POSITION
                    end,
                    setPosition = function(position)
                        mod:SavePosition(position)
                    end,
                    resetPosition = function()
                        mod:ResetPosition()
                    end,
                    defaultPosition = DEFAULT_POSITION,
                    getUnlocked = function()
                        return mod:IsUnlocked()
                    end,
                    setUnlocked = function(value)
                        mod:SetUnlocked(value)
                    end,
                    isDisabled = isDisabled,
                    showOffsets = true
                })
                return positionWidget
            end
        }
    }
end

E:RegisterQoLFeatureSettings(
    "ReadyCheckConsumables",
    buildReadyCheckConsumablesTab
)
