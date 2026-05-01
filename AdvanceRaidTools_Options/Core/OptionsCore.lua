local E, L = unpack(ART)

local AceConfig = E.Libs.AceConfig
local AceConfigReg = E.Libs.AceConfigRegistry
local AceDBOptions = E.Libs.AceDBOptions

E.optionsContributions = E.optionsContributions or {}

local cachedOptions

-- opts.minWidth / opts.minHeight: when this panel is selected, grow the options window to at least these dimensions
function E:RegisterOptions(name, order, builder, opts)
    self.optionsContributions[name] = {
        order = order or 100,
        builder = builder or function()
            return {
                type = "group",
                name = name,
                args = {}
            }
        end,
        name = name,
        core = opts and opts.core or false,
        minWidth = opts and opts.minWidth or nil,
        minHeight = opts and opts.minHeight or nil
    }
end

function E:RefreshOptions()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    elseif E.OptionsUI then
        E.OptionsUI:RefreshAll()
    end
end

-- per-module toggle wrapper
local function wrapWithEnableToggle(contribution)
    local baseGroup = contribution.builder()
    local mod = E:GetModule(contribution.name, true)

    baseGroup.args = baseGroup.args or {}

    -- push all authored entries down so the enable toggle sits first
    for _, entry in pairs(baseGroup.args) do
        entry.order = (entry.order or 1) + 10
    end

    if not mod then
        baseGroup.args.__unavailable = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = L["LoadModule"]
        }
        return baseGroup
    end

    baseGroup.args.__enable = {
        type = "toggle",
        order = 1,
        width = "full",
        name = L["Enable"] .. " " .. (L[contribution.name] or contribution.name),
        desc = L["Modulenoff"],
        get = function()
            return mod:IsEnabled()
        end,
        set = function(_, val)
            E:SetModuleEnabled(contribution.name, val)
        end
    }

    baseGroup.args.__enableSpacer = {
        type = "description",
        order = 2,
        name = " ",
        width = "full"
    }

    local function disabledFn()
        return not mod:IsEnabled()
    end

    local function applyDisabledToArgs(args)
        if not args then
            return
        end
        for key, entry in pairs(args) do
            if key ~= "__enable" and key ~= "__enableSpacer" and key ~= "__unavailable" then
                if entry.type == "group" then
                    applyDisabledToArgs(entry.args)
                else
                    local prior = entry.disabled
                    if type(prior) == "function" then
                        entry.disabled = function(info)
                            return disabledFn() or prior(info)
                        end
                    elseif prior == nil then
                        entry.disabled = disabledFn
                    end
                end
            end
        end
    end
    applyDisabledToArgs(baseGroup.args)

    return baseGroup
end

-- Profiles / Spec Profiles / Export / Import tabs
local function buildSpecArgs()
    local classID = select(3, UnitClass("player"))
    local specArgs = {
        specDesc = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = L["SpecProfilesDesc"]
        },
        specEnable = {
            type = "toggle",
            order = 2,
            width = "full",
            name = (L["Enable"] .. " " .. L["SpecProfiles"]),
            get = function()
                return E.db.char.specProfilesEnabled
            end,
            set = function(_, v)
                E.db.char.specProfilesEnabled = v
                if v then
                    E:ApplySpecProfile()
                end
                if E.OptionsUI then
                    E.OptionsUI:RefreshAll()
                end
            end
        }
    }

    for slot = 1, 4 do
        local specID
        if GetSpecializationInfoForClassID then
            specID = GetSpecializationInfoForClassID(classID, slot)
        end
        if specID then
            local _, specName, _, specIcon = GetSpecializationInfoByID(specID)
            specArgs["spec_" .. slot] = {
                type = "select",
                order = 10 + slot,
                name = function()
                    local icon = specIcon and ("|T" .. specIcon .. ":16:16:0:0|t ") or ""
                    return icon .. (specName or ("Spec " .. slot))
                end,
                desc = L["SpecProfileDesc"],
                values = function()
                    local t = {}
                    for _, name in ipairs(E.db:GetProfiles()) do
                        t[name] = name
                    end
                    return t
                end,
                get = function()
                    return (E.db.char.specProfiles or {})[slot]
                end,
                set = function(_, v)
                    E.db.char.specProfiles = E.db.char.specProfiles or {}
                    E.db.char.specProfiles[slot] = v
                end,
                hidden = function()
                    return not E.db.char.specProfilesEnabled
                end
            }
        end
    end

    return specArgs
end

local exportCategories = {}

local function getExportCategories()
    if not next(exportCategories) then
        for _, cat in ipairs(E.sharingCategories) do
            exportCategories[cat.key] = true
        end
    end
    return exportCategories
end

local function buildExportArgs()
    local args = {
        desc = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = L["ExportDesc"]
        },
        categoriesHeader = {
            type = "header",
            order = 2,
            name = L["ExportInclude"]
        }
    }

    for i, cat in ipairs(E.sharingCategories) do
        local key = cat.key
        args["cat_" .. key] = {
            type = "toggle",
            order = 10 + i,
            name = L[cat.label] or cat.label,
            desc = L[cat.desc] or cat.desc,
            width = "compact",
            get = function()
                return getExportCategories()[key]
            end,
            set = function(_, v)
                getExportCategories()[key] = v
                if E.OptionsUI then
                    E.OptionsUI:RefreshCurrent()
                end
            end
        }
    end

    args.stringHeader = {
        type = "header",
        order = 20,
        name = L["ExportString"]
    }
    args.exportString = {
        type = "input",
        order = 21,
        multiline = 8,
        width = "full",
        name = "",
        get = function()
            return E:GetExportString(getExportCategories())
        end,
        set = function()
        end
    }

    return args
end

local pendingImport = ""
local parsedImport = nil
local importCategories = {}

local function onImportStringChanged(v)
    pendingImport = v or ""
    parsedImport = pendingImport ~= "" and E:VerifyImportString(pendingImport) or nil
    wipe(importCategories)
    if parsedImport and parsedImport.categories then
        for catKey in pairs(parsedImport.categories) do
            importCategories[catKey] = true
        end
    end
    AceConfigReg:NotifyChange(E.addonName)
end

local function anyImportCategorySelected()
    for _, v in pairs(importCategories) do
        if v then
            return true
        end
    end
    return false
end

local function buildImportArgs()
    local args = {
        desc = {
            type = "description",
            order = 1,
            fontSize = "medium",
            name = L["ImportDesc"]
        },
        importString = {
            type = "input",
            order = 2,
            multiline = 8,
            width = "full",
            name = L["ImportString"],
            get = function()
                return pendingImport
            end,
            set = function(_, v)
                onImportStringChanged(v)
            end
        },
        categoriesHeader = {
            type = "header",
            order = 10,
            name = L["ImportSelectCategories"],
            hidden = function()
                return parsedImport == nil
            end
        }
    }

    for i, cat in ipairs(E.sharingCategories) do
        local key = cat.key
        args["cat_" .. key] = {
            type = "toggle",
            order = 20 + i,
            name = L[cat.label] or cat.label,
            desc = L[cat.desc] or cat.desc,
            width = "compact",
            hidden = function()
                return not (parsedImport and parsedImport.categories and parsedImport.categories[key])
            end,
            get = function()
                return importCategories[key]
            end,
            set = function(_, v)
                importCategories[key] = v
            end
        }
    end

    args.importApply = {
        type = "execute",
        order = 30,
        width = "full",
        name = (L["Apply"] .. " " .. L["Import"]),
        hidden = function()
            return parsedImport == nil
        end,
        disabled = function()
            return not anyImportCategorySelected()
        end,
        func = function()
            -- Capture the current paste state locally, then clear the UI
            local importStr = pendingImport
            local importCats = CopyTable(importCategories)

            pendingImport = ""
            parsedImport = nil
            wipe(importCategories)
            AceConfigReg:NotifyChange(E.addonName)

            E:Prompt({
                key = "ART_IMPORT_PROFILE",
                title = L["Import"],
                text = L["ImportPopupText"],
                input = {
                    default = "",
                    maxLetters = 64,
                    highlight = true
                },
                parent = E.OptionsUI and E.OptionsUI.mainFrame,
                onAccept = function(profileName)
                    local target = strtrim(profileName or "")
                    if target == "" then
                        target = nil
                    end
                    E:ImportProfile(importStr, target, importCats)
                    if E.OptionsUI then
                        E.OptionsUI:RefreshAll()
                    end
                end
            })
        end
    }

    return args
end

-- builder
local function BuildRoot()
    if cachedOptions then
        return cachedOptions
    end

    local args = {}

    for name, entry in pairs(E.optionsContributions) do
        local group
        if entry.core then
            group = entry.builder()
        else
            group = wrapWithEnableToggle(entry)
        end
        group.order = entry.order
        args[name] = group
    end

    local aceDBOTable = AceDBOptions:GetOptionsTable(E.db)

    args.profiles = {
        type = "group",
        name = L["Profiles"],
        order = 900,
        childGroups = "tab",
        handler = aceDBOTable.handler,
        args = {
            manage = {
                type = "group",
                name = aceDBOTable.name,
                order = 1,
                args = aceDBOTable.args
            },
            specProfiles = {
                type = "group",
                name = L["SpecProfiles"],
                order = 2,
                args = buildSpecArgs()
            },
            export = {
                type = "group",
                name = L["Export"],
                order = 3,
                args = buildExportArgs()
            },
            import = {
                type = "group",
                name = L["Import"],
                order = 4,
                args = buildImportArgs()
            }
        }
    }

    cachedOptions = {
        type = "group",
        name = L["AdvanceRaidTools"],
        args = args
    }

    return cachedOptions
end

-- Register with AceConfig
AceConfig:RegisterOptionsTable(E.addonName, BuildRoot)

function E:InitializeOptionsUI()
    if E.OptionsUI and E.OptionsUI.Build and not E.OptionsUI.mainFrame then
        E.OptionsUI:Build(BuildRoot())
    end
end

function E:RebuildOptions()
    cachedOptions = nil
    E._rootOptions = BuildRoot()
    AceConfigReg:NotifyChange(E.addonName)
    if E.OptionsUI and E.OptionsUI.ScheduleRebuild then
        E.OptionsUI:ScheduleRebuild()
    end
end

local function deepMergeOptions(target, source)
    local sArgs = source.args
    local tArgs = target.args
    if sArgs or tArgs then
        if not tArgs then
            target.args = {}
            tArgs = target.args
        end
        for k in pairs(tArgs) do
            if sArgs == nil or sArgs[k] == nil then
                tArgs[k] = nil
            end
        end
        if sArgs then
            for k, sChild in pairs(sArgs) do
                local tChild = tArgs[k]
                if type(tChild) == "table" and type(sChild) == "table" then
                    deepMergeOptions(tChild, sChild)
                else
                    tArgs[k] = sChild
                end
            end
        end
    end
    for k in pairs(target) do
        if k ~= "args" and source[k] == nil then
            target[k] = nil
        end
    end
    for k, v in pairs(source) do
        if k ~= "args" then
            target[k] = v
        end
    end
end

function E:RetranslateOptions()
    if not cachedOptions then
        return self:RebuildOptions()
    end
    local prev = cachedOptions
    cachedOptions = nil
    local fresh = BuildRoot()
    cachedOptions = prev
    deepMergeOptions(prev, fresh)
    AceConfigReg:NotifyChange(self.addonName)
    if self.OptionsUI and self.OptionsUI.Retranslate then
        self.OptionsUI:Retranslate()
    end
end

local OptionsEvents = E:NewCallbackHandle()
OptionsEvents:RegisterMessage("ART_MODULE_TOGGLED", function()
    if E.OptionsUI then
        if E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("all")
        else
            E.OptionsUI:RefreshAll()
        end
    end
end)
