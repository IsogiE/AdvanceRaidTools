local E, L = unpack(ART)
local T = E.Templates

-- Share main + editor UI
ART.RaidGroupsUI = ART.RaidGroupsUI or {}
local RGUI = ART.RaidGroupsUI

local function Mod()
    return E:GetModule("RaidGroups", true)
end

function RGUI:ShowSavePresetPrompt(parent, onAccepted)
    local m = Mod()
    if not m then
        return
    end
    E:Prompt({
        key = "ART_RG_SAVE_PRESET",
        title = L["RG_SaveAsPreset"],
        text = L["RG_PromptSaveName"],
        parent = parent,
        input = {
            default = "",
            maxLetters = 48,
            highlight = true
        },
        onAccept = function(val)
            local name = strtrim(val or "")
            if name == "" then
                return
            end
            local ok, err = m:SaveCurrentSlotsAsPreset(name)
            if not ok then
                if err then
                    E:Printf(err)
                end
                return
            end
            if onAccepted then
                onAccepted(name)
            end
        end
    })
end

function RGUI:ShowRenamePrompt(parent, oldName, onAccepted)
    local m = Mod()
    if not m or not oldName then
        return
    end
    E:Prompt({
        key = "ART_RG_RENAME_PRESET",
        title = L["RG_Rename"],
        text = L["RG_PromptRenameName"],
        parent = parent,
        input = {
            default = oldName,
            maxLetters = 48,
            highlight = true
        },
        onAccept = function(val)
            local newName = strtrim(val or "")
            if newName == "" or newName == oldName then
                return
            end
            local ok, err = m:RenamePreset(oldName, newName)
            if not ok then
                if err then
                    E:Printf(err)
                end
                return
            end
            if onAccepted then
                onAccepted(newName)
            end
        end
    })
end

function RGUI:ShowDeleteConfirm(parent, name, onAccepted)
    local m = Mod()
    if not m or not name then
        return
    end
    E:Confirm({
        key = "ART_RG_DELETE_PRESET",
        title = L["RG_Delete"],
        text = L["RG_ConfirmDelete"]:format(name),
        parent = parent,
        onAccept = function()
            m:DeletePreset(name)
            if onAccepted then
                onAccepted(name)
            end
        end
    })
end

-- Single-preset import
function RGUI:ShowImportPrompt(parent, onAccepted)
    local m = Mod()
    if not m then
        return
    end
    E:PromptMultiline({
        key = "ART_RG_IMPORT_PRESET",
        title = L["Import"],
        text = L["RG_PromptImport"],
        parent = parent,
        input = {
            multiline = 8,
            default = "",
            maxLetters = 200000
        },
        onAccept = function(raw)
            local text = strtrim(raw or "")
            if text == "" then
                return
            end
            local imported, errors, importedNames = m:BulkImport(text)
            if imported > 0 then
                E:Printf(L["RG_BulkImportedN"]:format(imported))
            end
            for _, err in ipairs(errors or {}) do
                E:Printf("|cffff4040%s|r", err)
            end
            if onAccepted and imported > 0 then
                onAccepted(importedNames and importedNames[1], importedNames)
            end
        end
    })
end

function RGUI:ShowExportViewer(parent, preset)
    local m = Mod()
    if not m or not preset then
        return
    end
    if type(preset) == "string" then
        preset = m:GetPresetByName(preset)
        if not preset then
            return
        end
    end
    E:ShowText({
        key = "ART_RG_EXPORT_PRESET",
        title = preset.name or "Preset",
        parent = parent,
        viewer = {
            text = m:ExportPresetString(preset) or "",
            lines = 12
        }
    })
end

function RGUI:ShowRosterViewer(parent, text)
    E:ShowText({
        key = "ART_RG_EXPORT_ROSTER",
        title = L["RG_ExportRoster"],
        parent = parent,
        viewer = {
            text = text or "",
            lines = 12
        }
    })
end

-- Settings panel
local selectedPreset
local TOOLTIP_ANCHOR = "ANCHOR_CURSOR"

local function presetCount()
    local m = Mod()
    return m and #m:GetPresets() or 0
end

local function presetValues()
    local t = {}
    local m = Mod()
    if m then
        for _, p in ipairs(m:GetPresets()) do
            t[p.name] = p.name
        end
    end
    return t
end

-- Popup anchor
local function popupParent()
    return E.OptionsUI and E.OptionsUI:GetMainFrame()
end

local function openEditor()
    if E.OpenRaidGroups then
        E:OpenRaidGroups()
    end
end

local function isModuleDisabled()
    local m = Mod()
    return not m or not m:IsEnabled()
end

-- General tab
local function generalArgs()
    return {
        intro = {
            order = 1,
            build = function(parent)
                return T:Description(parent, {
                    text = L["RG_GeneralDesc"],
                    sizeDelta = 1
                })
            end
        },

        spacer = {
            order = 1.5,
            build = function(parent)
                return T:Spacer(parent, {
                    height = 5
                })
            end
        },

        setupHeader = {
            order = 10,
            build = function(parent)
                return T:Header(parent, {
                    text = L["RG_Setup"]
                })
            end
        },

        openEditor = {
            order = 11,
            width = "full",
            build = function(parent)
                return T:Button(parent, {
                    text = L["RG_OpenEditor"],
                    tooltip = {
                        title = L["RG_OpenEditor"],
                        desc = L["RG_OpenEditorDesc"]
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    onClick = openEditor,
                    disabled = isModuleDisabled
                })
            end
        }
    }
end

local function savedPresetsArgs()
    local function havePresets()
        return presetCount() > 0
    end
    local function selectedPresetData()
        local m = Mod()
        return m and selectedPreset and m:GetPresetByName(selectedPreset)
    end
    local function noSelection()
        return not selectedPresetData()
    end

    return {
        listHeader = {
            order = 50,
            build = function(parent)
                return T:Header(parent, {
                    text = L["RG_QuickActions"]
                })
            end
        },

        empty = {
            order = 51,
            hidden = function()
                return havePresets()
            end,
            build = function(parent)
                return T:Description(parent, {
                    text = L["RG_NoPresetsYet"],
                    sizeDelta = 1
                })
            end
        },

        presetSelect = {
            order = 60,
            width = "full",
            hidden = function()
                return not havePresets()
            end,
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["RG_SelectPreset"],
                    tooltip = {
                        title = L["RG_SelectPreset"],
                        desc = "Choose a saved preset for the actions below"
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    values = presetValues,
                    get = function()
                        local m = Mod()
                        if selectedPreset and m and m:GetPresetByName(selectedPreset) then
                            return selectedPreset
                        end
                        local first = m and m:GetPresets()[1]
                        selectedPreset = first and first.name or nil
                        return selectedPreset
                    end,
                    onChange = function(v)
                        selectedPreset = v
                    end,
                    disabled = isModuleDisabled
                })
            end
        },

        loadBtn = {
            order = 61,
            width = "1/5",
            hidden = function()
                return not havePresets()
            end,
            build = function(parent)
                return T:Button(parent, {
                    text = L["RG_Load"],
                    tooltip = {
                        title = L["RG_Load"],
                        desc = L["RG_LoadIntoEditorDesc"]
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    disabled = function()
                        if isModuleDisabled() then
                            return true
                        end
                        return noSelection()
                    end,
                    onClick = function()
                        openEditor()
                        local preset = selectedPresetData()
                        if preset then
                            local m = Mod()
                            m:LoadPresetIntoSlots(preset.data, preset.note, preset.name)
                        end
                    end
                })
            end
        },

        applyBtn = {
            order = 62,
            width = "1/5",
            hidden = function()
                return not havePresets()
            end,
            build = function(parent)
                return T:Button(parent, {
                    text = L["RG_ApplyPreset"],
                    tooltip = {
                        title = L["RG_ApplyPreset"],
                        desc = "Apply this preset immediately without opening the editor"
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    disabled = function()
                        if isModuleDisabled() then
                            return true
                        end
                        return noSelection()
                    end,
                    onClick = function()
                        local m = Mod()
                        local preset = selectedPresetData()
                        if not (m and preset) then
                            return
                        end
                        local assignment, err = m:PresetStringToAssignment(preset.data)
                        if not assignment then
                            if err then
                                E:Printf(err)
                            end
                            return
                        end
                        local note = preset.note
                        if note == nil then
                            note = assignment.note
                        end
                        m:ApplyAssignment(assignment.groups, note)
                    end
                })
            end
        },

        renameBtn = {
            order = 63,
            width = "1/5",
            hidden = function()
                return not havePresets()
            end,
            build = function(parent)
                return T:Button(parent, {
                    text = L["RG_Rename"],
                    tooltip = {
                        title = L["RG_Rename"],
                        desc = "Rename this preset"
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    disabled = function()
                        if isModuleDisabled() then
                            return true
                        end
                        return noSelection()
                    end,
                    onClick = function()
                        RGUI:ShowRenamePrompt(popupParent(), selectedPreset, function(newName)
                            selectedPreset = newName
                        end)
                    end
                })
            end
        },

        exportBtn = {
            order = 64,
            width = "1/5",
            hidden = function()
                return not havePresets()
            end,
            build = function(parent)
                return T:Button(parent, {
                    text = L["Export"],
                    tooltip = {
                        title = L["ExportString"],
                        desc = L["RG_ExportStringDesc"]
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    disabled = function()
                        if isModuleDisabled() then
                            return true
                        end
                        return noSelection()
                    end,
                    onClick = function()
                        RGUI:ShowExportViewer(popupParent(), selectedPreset)
                    end
                })
            end
        },

        deleteBtn = {
            order = 65,
            width = "1/5",
            hidden = function()
                return not havePresets()
            end,
            build = function(parent)
                return T:Button(parent, {
                    text = L["RG_Delete"],
                    tooltip = {
                        title = L["RG_Delete"],
                        desc = "Delete this preset"
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    disabled = function()
                        if isModuleDisabled() then
                            return true
                        end
                        return noSelection()
                    end,
                    onClick = function()
                        RGUI:ShowDeleteConfirm(popupParent(), selectedPreset)
                    end
                })
            end
        }
    }
end

local function dangerArgs()
    return {
        dangerHeader = {
            order = 900,
            hidden = function()
                return presetCount() == 0
            end,
            build = function(parent)
                return T:Header(parent, {
                    text = L["RG_DangerZone"]
                })
            end
        },

        deleteAll = {
            order = 901,
            width = "full",
            hidden = function()
                return presetCount() == 0
            end,
            build = function(parent)
                return T:Button(parent, {
                    text = L["RG_DeleteAll"],
                    tooltip = {
                        title = L["RG_DeleteAll"],
                        desc = L["RG_DeleteAllDesc"]
                    },
                    tooltipAnchor = TOOLTIP_ANCHOR,
                    confirm = L["RG_DeleteAllConfirm"],
                    confirmTitle = L["RG_DeleteAll"],
                    onClick = function()
                        local m = Mod()
                        if not m then
                            return
                        end
                        local list = m:GetPresets()
                        for i = #list, 1, -1 do
                            list[i] = nil
                        end
                        E:SendMessage("ART_RAIDGROUPS_PRESETS_CHANGED")
                    end,
                    disabled = isModuleDisabled
                })
            end
        }
    }
end

-- Panel core
local function buildPanel()
    local mod = Mod()
    if not mod then
        return {
            type = "group",
            name = L["RaidGroups"],
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

    return {
        type = "group",
        name = L["RaidGroups"],
        args = T:MergeArgs(generalArgs(), savedPresetsArgs(), dangerArgs())
    }
end

E:RegisterOptions("RaidGroups", 30, buildPanel, {
    core = true
})

local RaidGroupSettingsEvents = E:NewCallbackHandle()

-- Keep the panel's selection in sync with the underlying preset list
RaidGroupSettingsEvents:RegisterMessage("ART_RAIDGROUPS_PRESETS_CHANGED", function(_, touchedName)
    local m = Mod()
    if touchedName and m and m:GetPresetByName(touchedName) then
        selectedPreset = touchedName
    elseif selectedPreset and m and not m:GetPresetByName(selectedPreset) then
        selectedPreset = nil
    end
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("all")
    elseif E.RefreshOptions then
        E:RefreshOptions()
    end
end)
