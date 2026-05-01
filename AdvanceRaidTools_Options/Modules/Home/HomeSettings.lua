local E, L = unpack(ART)
local T = E.Templates

local OUTLINES = {
    NONE = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    MONOCHROME = L["Monochrome"],
    MONOCHROMEOUTLINE = (L["Monochrome"] .. " " .. L["Outline"])
}
local OUTLINE_ORDER = {"NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "MONOCHROMEOUTLINE"}

local PRESET_ORDER = {"default", "classColor", "midnight", "highContrast"}

local W_HALF = "1/2"
local W_THIRD = "1/3"
local W_QUARTER = "1/4"
local W_BUTTON = 0.9

local function cosmetic()
    return E.db.profile.cosmetic
end
local function general()
    return E.db.profile.general
end
local function Home()
    return E:GetModule("HomeSettings")
end

local function buildMediaList(mediaType)
    return function()
        return E:MediaList(mediaType)
    end
end

local function colorKind(key)
    if key == "accent" then
        return "accent"
    end
    if key == "border" then
        return "border"
    end
    return "backdropColor"
end

local mediaDebounceSeq = 0
local function scheduleCosmeticApply(kind, skipNotify)
    mediaDebounceSeq = mediaDebounceSeq + 1
    local seq = mediaDebounceSeq
    C_Timer.After(0.1, function()
        if mediaDebounceSeq == seq then
            Home():UpdateCosmetics(skipNotify, kind)
        end
    end)
end

local function setColor(key)
    return function(r, g, b)
        local t = cosmetic().colors[key]
        t.r, t.g, t.b = r, g, b
        scheduleCosmeticApply(colorKind(key), true)
    end
end
local function getColor(key)
    return function()
        local t = cosmetic().colors[key]
        return t.r, t.g, t.b, t.a or 1
    end
end

local function setOpacity(key)
    return function(v)
        cosmetic().opacity[key] = v
        scheduleCosmeticApply("backdropColor", true)
    end
end
local function getOpacity(key)
    return function()
        return cosmetic().opacity[key]
    end
end

local function setFont(field)
    return function(v)
        cosmetic().fonts[field] = v
        -- Font-size slider skips the notify sweep
        local skipNotify = (field == "size")
        scheduleCosmeticApply("font", skipNotify)
    end
end
local function getFont(field)
    return function()
        return cosmetic().fonts[field]
    end
end

-- General tab
local function generalGroup()
    return {
        type = "group",
        name = L["General"],
        order = 1,
        args = {
            intro = {
                order = 1,
                build = function(parent)
                    return T:Description(parent, {
                        text = L["GeneralDesc"],
                        sizeDelta = 1
                    })
                end
            },

            displayHeader = {
                order = 10,
                build = function(parent)
                    return T:Header(parent, {
                        text = L["Display"]
                    })
                end
            },

            locale = {
                order = 11,
                build = function(parent)
                    return T:Dropdown(parent, {
                        label = L["Language"],
                        tooltip = {
                            title = L["Language"],
                            desc = L["LanguageDesc"]
                        },
                        values = function()
                            local langs = {}
                            for code, tbl in pairs(ART.Locales or {}) do
                                langs[code] = tbl["LOCALE_NAME"] or code
                            end
                            if not next(langs) then
                                langs["enUS"] = "English"
                            end
                            return langs
                        end,
                        get = function()
                            return general().locale or GetLocale()
                        end,
                        onChange = function(v)
                            general().locale = v
                            E:RetranslateOptions()
                        end
                    })
                end
            },

            minimap = {
                order = 12,
                width = "full",
                build = function(parent)
                    return T:Checkbox(parent, {
                        text = L["ShowMinimapIcon"],
                        tooltip = {
                            title = L["ShowMinimapIcon"],
                            desc = L["MinimapIconDesc"]
                        },
                        get = function()
                            return not general().minimapIcon.hide
                        end,
                        onChange = function(_, v)
                            general().minimapIcon.hide = not v
                            Home():UpdateMinimap()
                        end
                    })
                end
            }
        }
    }
end

-- Appearance tab
local function presetsArgs()
    local args = {
        header = {
            order = 0,
            build = function(parent)
                return T:Header(parent, {
                    text = L["ThemePresets"]
                })
            end
        },
        desc = {
            order = 1,
            build = function(parent)
                return T:Description(parent, {
                    text = L["PresetsDesc"],
                    sizeDelta = 1
                })
            end
        }
    }
    for i, key in ipairs(PRESET_ORDER) do
        local preset = Home().PRESETS[key]
        args["preset_" .. key] = {
            order = 10 + i,
            width = W_QUARTER,
            build = function(parent)
                return T:Button(parent, {
                    text = L[preset.label] or preset.label,
                    onClick = function()
                        Home():ApplyPreset(key)
                    end
                })
            end
        }
    end
    return args
end

local function colorsArgs()
    return {
        colorsHeader = {
            order = 10,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Colors"]
                })
            end
        },

        accent = {
            order = 11,
            width = "half",
            build = function(parent)
                return T:ColorSwatch(parent, {
                    label = L["Accent"],
                    tooltip = {
                        title = L["Accent"],
                        desc = L["AccentDesc"]
                    },
                    hasAlpha = false,
                    get = getColor("accent"),
                    onChange = setColor("accent"),
                    onCancel = setColor("accent")
                })
            end
        },

        useClassColor = {
            order = 12,
            width = "normal",
            build = function(parent)
                return T:Button(parent, {
                    text = L["UseClassColor"],
                    tooltip = {
                        title = L["UseClassColor"],
                        desc = L["UseClassColorDesc"]
                    },
                    onClick = function()
                        Home():ApplyClassColor()
                    end
                })
            end
        },

        -- Empty spacer row so backdrop / border wrap to the next line
        colorRowBreak = {
            order = 13,
            build = function(parent)
                return T:Spacer(parent, {
                    height = 1
                })
            end
        },

        backdrop = {
            order = 14,
            width = "half",
            build = function(parent)
                return T:ColorSwatch(parent, {
                    label = L["Backdrop"],
                    tooltip = {
                        title = L["Backdrop"],
                        desc = L["BackdropDesc"]
                    },
                    hasAlpha = false,
                    get = getColor("backdrop"),
                    onChange = setColor("backdrop"),
                    onCancel = setColor("backdrop")
                })
            end
        },

        border = {
            order = 15,
            width = "half",
            build = function(parent)
                return T:ColorSwatch(parent, {
                    label = L["Border"],
                    tooltip = {
                        title = L["Border"],
                        desc = L["BorderDesc"]
                    },
                    hasAlpha = false,
                    get = getColor("border"),
                    onChange = setColor("border"),
                    onCancel = setColor("border")
                })
            end
        }
    }
end

local function opacityArgs()
    return {
        opacityHeader = {
            order = 20,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Opacity"]
                })
            end
        },

        backdropOpacity = {
            order = 21,
            width = W_HALF,
            build = function(parent)
                return T:Slider(parent, {
                    label = (L["Background"] .. " " .. L["Opacity"]),
                    tooltip = {
                        title = (L["Background"] .. " " .. L["Opacity"]),
                        desc = L["BackgroundOpacityDesc"]
                    },
                    min = 0,
                    max = 1,
                    step = 0.05,
                    isPercent = true,
                    get = getOpacity("backdrop"),
                    onChange = setOpacity("backdrop")
                })
            end
        },

        fadedOpacity = {
            order = 22,
            width = W_HALF,
            build = function(parent)
                return T:Slider(parent, {
                    label = L["PanelOpacity"],
                    tooltip = {
                        title = L["PanelOpacity"],
                        desc = L["PanelOpacityDesc"]
                    },
                    min = 0,
                    max = 1,
                    step = 0.05,
                    isPercent = true,
                    get = getOpacity("backdropFaded"),
                    onChange = setOpacity("backdropFaded")
                })
            end
        }
    }
end

local function fontArgs()
    return {
        fontHeader = {
            order = 30,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Font"]
                })
            end
        },

        font = {
            order = 31,
            width = W_THIRD,
            build = function(parent)
                return T:Dropdown(parent, {
                    label = (L["Font"] .. " Family"),
                    tooltip = {
                        title = (L["Font"] .. " Family"),
                        desc = L["AddonFontDesc"]
                    },
                    values = buildMediaList("font"),
                    get = getFont("normal"),
                    onChange = setFont("normal")
                })
            end
        },

        fontSize = {
            order = 32,
            width = W_THIRD,
            build = function(parent)
                return T:Slider(parent, {
                    label = (L["Font"] .. " " .. L["Size"]),
                    tooltip = {
                        title = (L["Font"] .. " " .. L["Size"]),
                        desc = L["FontSizeDesc"]
                    },
                    min = 8,
                    max = 24,
                    step = 1,
                    get = getFont("size"),
                    onChange = setFont("size")
                })
            end
        },

        fontOutline = {
            order = 33,
            width = W_THIRD,
            build = function(parent)
                return T:Dropdown(parent, {
                    label = (L["Font"] .. " " .. L["Outline"]),
                    tooltip = {
                        title = (L["Font"] .. " " .. L["Outline"]),
                        desc = L["FontOutlineDesc"]
                    },
                    values = OUTLINES,
                    sorting = OUTLINE_ORDER,
                    get = getFont("outline"),
                    onChange = setFont("outline")
                })
            end
        }
    }
end

local function moduleVisualsArgs()
    return {
        moduleVisualsHeader = {
            order = 40,
            build = function(parent)
                return T:Header(parent, {
                    text = L["ModuleVisuals"]
                })
            end
        },

        moduleFont = {
            order = 41,
            width = W_HALF,
            build = function(parent)
                return T:Dropdown(parent, {
                    label = (L["Font"] .. " Family"),
                    tooltip = {
                        title = (L["Font"] .. " Family"),
                        desc = L["ModuleFontDesc"]
                    },
                    values = buildMediaList("font"),
                    get = getFont("module"),
                    onChange = setFont("module")
                })
            end
        },

        statusbar = {
            order = 42,
            width = W_HALF,
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["StatusbarTexture"],
                    tooltip = {
                        title = L["StatusbarTexture"],
                        desc = L["StatusbarTextureDesc"]
                    },
                    values = buildMediaList("statusbar"),
                    get = function()
                        return cosmetic().textures.statusbar
                    end,
                    onChange = function(v)
                        cosmetic().textures.statusbar = v
                        Home():UpdateCosmetics()
                    end
                })
            end
        }
    }
end

local function resetArgs()
    return {
        resetHeader = {
            order = 90,
            build = function(parent)
                return T:Header(parent, {
                    text = L["Reset"]
                })
            end
        },

        reset = {
            order = 91,
            width = W_BUTTON,
            build = function(parent)
                return T:Button(parent, {
                    text = L["RestoreDefaults"],
                    tooltip = {
                        title = L["RestoreDefaults"],
                        desc = L["RestoreDefaultsDesc"]
                    },
                    confirm = L["RestoreDefaultsConfirm"],
                    confirmTitle = L["RestoreDefaults"],
                    onClick = function()
                        Home():ApplyPreset("default")
                    end
                })
            end
        }
    }
end

local function appearanceGroup()
    return {
        type = "group",
        name = L["Appearance"],
        order = 2,
        args = T:MergeArgs({
            -- Presets render as an inline sub-group
            presets = {
                type = "group",
                inline = true,
                order = 1,
                name = "",
                args = presetsArgs()
            }
        }, colorsArgs(), opacityArgs(), fontArgs(), moduleVisualsArgs(), resetArgs())
    }
end

-- Panel core
local function buildHomePanel()
    return {
        type = "group",
        name = L["Home"],
        childGroups = "tab",
        args = {
            general = generalGroup(),
            appearance = appearanceGroup()
        }
    }
end

E:RegisterOptions("Home", 1, buildHomePanel, {
    core = true
})
