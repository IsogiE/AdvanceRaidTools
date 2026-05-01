local E, L = unpack(ART)
local T = E.Templates

local SHAPES = {
    circle = "QoL_ShapeCircle",
    square = "QoL_ShapeSquare",
    crosshair = "Crosshair"
}

local STRATA_VALUES = {
    BACKGROUND = "Background",
    LOW = "QoL_StrataLow",
    MEDIUM = "QoL_StrataMedium",
    HIGH = "QoL_StrataHigh",
    DIALOG = "QoL_StrataDialog"
}

local function buildCircleTab(mod, isDisabled)
    local function refreshLive()
        mod:Refresh()
    end

    local function refreshPanel()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("current")
        end
    end

    local function isCrosshair()
        return mod.db.shape == "crosshair"
    end

    local function borderInapplicable()
        return isDisabled() or isCrosshair()
    end

    local function crosshairInapplicable()
        return isDisabled() or not isCrosshair()
    end

    local movable
    local function ensureMovable()
        if movable then
            return movable
        end
        if not (mod and mod.EnsureFrame) then
            return nil
        end
        local f = mod:EnsureFrame()
        if not f then
            return nil
        end
        movable = T:MovableFrame(f, {
            label = L["QoL_Circle"] or "Character Marker",
            getPosition = function()
                return {
                    point = mod.db.position.point,
                    x = mod.db.position.x,
                    y = mod.db.position.y
                }
            end,
            setPosition = function(pos)
                mod.db.position.point = pos.point or "CENTER"
                mod.db.position.x = pos.x or 0
                mod.db.position.y = pos.y or 0
                refreshLive()
            end,
            onChanged = refreshPanel
        })
        return movable
    end

    return {
        unlockFrame = {
            order = 4,
            width = "full",
            build = function(parent)
                local cb = T:Checkbox(parent, {
                    text = L["BossMods_UnlockFrame"] or "Unlock Frame",
                    labelTop = true,
                    tooltip = {
                        title = L["BossMods_UnlockFrame"] or "Unlock Frame",
                        desc = L["DragToMove"] or ""
                    },
                    get = function()
                        return movable and movable:IsUnlocked() or false
                    end,
                    onChange = function(_, v)
                        local m = ensureMovable()
                        if m then
                            m:SetUnlocked(v)
                        end
                    end,
                    disabled = isDisabled
                })
                cb.frame:HookScript("OnHide", function()
                    if movable then
                        movable:SetUnlocked(false)
                    end
                end)
                return cb
            end
        },

        appearanceHeader = {
            order = 10,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Appearance"]
                })
            end
        },

        shape = {
            order = 11,
            width = "1/2",
            build = function(parent)
                local values = {}
                for key, labelKey in pairs(SHAPES) do
                    values[key] = L[labelKey] or labelKey
                end
                return T:Dropdown(parent, {
                    label = L["Shape"],
                    values = values,
                    get = function()
                        return mod.db.shape
                    end,
                    onChange = function(v)
                        mod.db.shape = v
                        refreshLive()
                        refreshPanel()
                    end,
                    disabled = isDisabled
                })
            end
        },

        strata = {
            order = 12,
            width = "1/2",
            build = function(parent)
                local values = {}
                for key, labelKey in pairs(STRATA_VALUES) do
                    values[key] = L[labelKey] or key
                end
                return T:Dropdown(parent, {
                    label = L["QoL_Strata"],
                    values = values,
                    get = function()
                        return mod.db.strata
                    end,
                    onChange = function(v)
                        mod.db.strata = v
                        refreshLive()
                    end,
                    disabled = isDisabled,
                    tooltip = {
                        title = L["QoL_Strata"],
                        desc = L["QoL_StrataDesc"]
                    }
                })
            end
        },

        color = {
            order = 13,
            width = "1/2",
            build = function(parent)
                return T:ColorSwatch(parent, {
                    label = (L["Fill"] .. " " .. L["Color"]),
                    labelTop = true,
                    hasAlpha = true,
                    r = mod.db.color[1],
                    g = mod.db.color[2],
                    b = mod.db.color[3],
                    a = mod.db.color[4],
                    onChange = function(r, g, b, a)
                        mod.db.color = {r, g, b, a}
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        },

        opacity = {
            order = 14,
            width = "1/2",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["Opacity"],
                    min = 0.05,
                    max = 1.0,
                    step = 0.05,
                    value = mod.db.alpha,
                    isPercent = true,
                    onChange = function(v)
                        mod.db.alpha = v
                        refreshLive()
                    end,
                    get = function()
                        return mod.db.alpha
                    end,
                    disabled = isDisabled
                })
            end
        },

        size = {
            order = 15,
            width = "full",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["Size"],
                    min = 10,
                    max = 400,
                    step = 1,
                    value = mod.db.size,
                    onChange = function(v)
                        mod.db.size = math.floor(v)
                        refreshLive()
                    end,
                    get = function()
                        return mod.db.size
                    end,
                    disabled = isDisabled
                })
            end
        },

        -- Position
        positionHeader = {
            order = 20,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Position"]
                })
            end
        },

        positionDesc = {
            order = 21,
            build = function(parent)
                return T:Description(parent, {
                    text = L["QoL_PositionDesc"],
                    sizeDelta = 0
                })
            end
        },

        xOffset = {
            order = 22,
            width = "1/2",
            build = function(parent)
                return T:NumericStepper(parent, {
                    label = L["QoL_XOffset"],
                    get = function()
                        return mod.db.position.x
                    end,
                    set = function(v)
                        mod.db.position.x = math.floor(v)
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        },

        yOffset = {
            order = 23,
            width = "1/2",
            build = function(parent)
                return T:NumericStepper(parent, {
                    label = L["QoL_YOffset"],
                    get = function()
                        return mod.db.position.y
                    end,
                    set = function(v)
                        mod.db.position.y = math.floor(v)
                        refreshLive()
                    end,
                    disabled = isDisabled
                })
            end
        },

        resetPos = {
            order = 24,
            width = "full",
            build = function(parent)
                return T:LabelAlignedButton(parent, {
                    text = (L["Reset"] .. " " .. L["Position"]),
                    disabled = isDisabled,
                    onClick = function()
                        mod.db.position = {
                            point = "CENTER",
                            x = 0,
                            y = 0
                        }
                        refreshLive()
                        refreshPanel()
                    end
                })
            end
        },

        -- Borders (circle/square only)
        borderHeader = {
            order = 30,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Border"]
                })
            end
        },

        showBorder = {
            order = 31,
            width = "1/2",
            build = function(parent)
                return T:Checkbox(parent, {
                    text = (L["Show"] .. " " .. L["Border"]),
                    labelTop = true,
                    get = function()
                        return mod.db.showBorder
                    end,
                    onChange = function(_, v)
                        mod.db.showBorder = v and true or false
                        refreshLive()
                        refreshPanel()
                    end,
                    disabled = borderInapplicable
                })
            end
        },

        borderColor = {
            order = 32,
            width = "1/2",
            build = function(parent)
                return T:ColorSwatch(parent, {
                    label = (L["Border"] .. " " .. L["Color"]),
                    labelTop = true,
                    hasAlpha = true,
                    r = mod.db.borderColor[1],
                    g = mod.db.borderColor[2],
                    b = mod.db.borderColor[3],
                    a = mod.db.borderColor[4],
                    onChange = function(r, g, b, a)
                        mod.db.borderColor = {r, g, b, a}
                        refreshLive()
                    end,
                    disabled = borderInapplicable
                })
            end
        },

        borderWidth = {
            order = 33,
            width = "full",
            build = function(parent)
                return T:Slider(parent, {
                    label = (L["Border"] .. " " .. L["Width"]),
                    min = 1,
                    max = 20,
                    step = 1,
                    value = mod.db.borderWidth,
                    onChange = function(v)
                        mod.db.borderWidth = math.floor(v)
                        refreshLive()
                    end,
                    get = function()
                        return mod.db.borderWidth
                    end,
                    disabled = borderInapplicable
                })
            end
        },

        -- Crosshair-specific
        crosshairHeader = {
            order = 40,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Crosshair"]
                })
            end
        },

        crosshairThickness = {
            order = 41,
            width = "full",
            build = function(parent)
                return T:Slider(parent, {
                    label = (L["Crosshair"] .. " " .. L["Thickness"]),
                    min = 1,
                    max = 10,
                    step = 1,
                    value = mod.db.crosshairThickness,
                    onChange = function(v)
                        mod.db.crosshairThickness = math.floor(v)
                        refreshLive()
                    end,
                    get = function()
                        return mod.db.crosshairThickness
                    end,
                    disabled = crosshairInapplicable
                })
            end
        }
    }
end

E:RegisterQoLFeatureSettings("Circle", buildCircleTab)
