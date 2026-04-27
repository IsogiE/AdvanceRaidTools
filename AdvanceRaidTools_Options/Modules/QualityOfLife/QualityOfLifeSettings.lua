local E, L = unpack(ART)
local T = E.Templates

E.qolFeatureSettings = E.qolFeatureSettings or {}

function E:RegisterQoLFeatureSettings(key, builder)
    assert(type(key) == "string" and key ~= "", "RegisterQoLFeatureSettings: key required")
    assert(type(builder) == "function", "RegisterQoLFeatureSettings: builder must be a function")
    self.qolFeatureSettings[key] = builder

    if self.OptionsUI and self.OptionsUI.ScheduleRebuild and self.OptionsUI.mainFrame then
        self:RebuildOptions()
    end
end

local function buildFeatureTab(feature)
    local modName = feature.moduleName
    local mod = E:GetModule(modName, true)

    local builder = E.qolFeatureSettings[feature.key]

    local function isDisabled()
        return not (mod and mod:IsEnabled())
    end

    local enableToggle = {
        order = 1,
        width = "full",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["Enable"] .. " " .. (L[feature.labelKey] or feature.labelKey),
                get = function()
                    return mod and mod:IsEnabled()
                end,
                onChange = function(_, val)
                    E:SetModuleEnabled(modName, val)
                    if mod and mod.Refresh then
                        mod:Refresh()
                    end
                end,
                tooltip = feature.descKey and L[feature.descKey] and {
                    title = L[feature.labelKey] or feature.labelKey,
                    desc = L[feature.descKey]
                } or nil
            })
        end
    }

    local args = {
        __enable = enableToggle,
        __spacer = {
            order = 2,
            build = function(parent)
                return T:Spacer(parent, {
                    height = 6
                })
            end
        }
    }

    if feature.descKey and L[feature.descKey] then
        args.__desc = {
            order = 3,
            build = function(parent)
                return T:Description(parent, {
                    text = L[feature.descKey],
                    sizeDelta = 1
                })
            end
        }
    end

    if mod and builder then
        local extra = builder(mod, isDisabled) or {}
        for k, v in pairs(extra) do
            args[k] = v
        end
    elseif not mod then
        args.__unavailable = {
            order = 10,
            build = function(parent)
                return T:Description(parent, {
                    text = L["LoadModule"],
                    sizeDelta = 1
                })
            end
        }
    end

    return {
        type = "group",
        order = feature.order,
        name = L[feature.labelKey] or feature.labelKey,
        args = args
    }
end

local function buildQualityOfLifePanel()
    local QoL = E:GetModule("QualityOfLife", true)

    if not QoL then
        return {
            type = "group",
            name = L["QualityOfLife"],
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

    local features = QoL:GetFeatures()

    -- If no features have registered yet, show a friendly notice
    if #features == 0 then
        return {
            type = "group",
            name = L["QualityOfLife"],
            args = {
                intro = {
                    order = 1,
                    build = function(parent)
                        return T:Description(parent, {
                            text = L["QualityOfLifeDesc"],
                            sizeDelta = 1
                        })
                    end
                },
                empty = {
                    order = 2,
                    build = function(parent)
                        return T:Description(parent, {
                            text = L["QoL_NoFeatures"],
                            sizeDelta = 0
                        })
                    end
                }
            }
        }
    end

    local tabs = {}
    for _, feat in ipairs(features) do
        tabs[feat.key] = buildFeatureTab(feat)
    end

    return {
        type = "group",
        name = L["QualityOfLife"],
        childGroups = "tab",
        args = T:MergeArgs({
            intro = {
                order = 1,
                build = function(parent)
                    return T:Description(parent, {
                        text = L["QualityOfLifeDesc"],
                        sizeDelta = 1
                    })
                end
            }
        }, tabs)
    }
end

E:RegisterOptions("QualityOfLife", 40, buildQualityOfLifePanel, {
    core = true
})

-- Rebuild the panel when a feature registers after the panel is first built
local qolEvents = E:NewCallbackHandle()
qolEvents:RegisterMessage("ART_QOL_FEATURES_CHANGED", function()
    if E.RebuildOptions then
        E:RebuildOptions()
    end
end)
