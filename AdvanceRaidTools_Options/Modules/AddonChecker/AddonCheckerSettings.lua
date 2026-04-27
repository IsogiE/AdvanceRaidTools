local E, L = unpack(ART)
local T = E.Templates
local CP = E.OptionsHelpers.CHECKER_PALETTE

local function mod()
    return E:GetModule("AddonChecker", true)
end
local function db()
    return E.db.profile.modules.AddonChecker
end

local ui = {
    contextOverride = nil,
    selectedAddon = nil,
    newAddonName = "",
    customAddons = {}
}

local AddonCheckerEvents = E:NewCallbackHandle()
local function queueRefresh()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
end
AddonCheckerEvents:RegisterMessage("ART_ADDONCHECK_UPDATED", queueRefresh)

local function currentAddon()
    return ui.selectedAddon or (db() and db().lastAddon) or nil
end

local ICON_TEX = [[Interface\AddOns\AdvanceRaidTools\Media\Textures\DiesalGUIcons16x256x128]]
local ICON = {
    up_to_date = {
        coords = {0.5625, 0.625, 0.5, 0.625},
        color = {0, 0.8, 0, 1}
    },
    missing = {
        coords = {0.5, 0.5625, 0.5, 0.625},
        color = {0.8, 0, 0, 1}
    },
    outdated = {
        coords = {0.3125, 0.375, 0.625, 0.75},
        color = {1, 1, 0, 1}
    }
}

local function applyIcon(tex, kind)
    local spec = ICON[kind]
    if not spec then
        tex:Hide()
        return
    end
    tex:SetTexture(ICON_TEX)
    tex:SetTexCoord(unpack(spec.coords))
    tex:SetVertexColor(unpack(spec.color))
    tex:Show()
end

local function reportCheckError(err)
    if not err or err == "DISABLED" then
        return
    end
    if err == "NO_ADDON" then
        E:Printf(L["AddonCheckerPickOne"])
    elseif err == "NO_CONTEXT" then
        E:Printf(L["CheckerNoContext"])
    elseif err == "TOO_SOON" then
        E:Printf(L["CheckTooSoon"])
    else
        E:Printf(L["AddonCheckerFailed"]:format(err or "?"))
    end
end

local function getStatusText(m)
    local state = m.state
    if not state or not state.addonName then
        return CP.muted .. L["AddonCheckerEmpty"] .. "|r"
    end

    if state.inProgress then
        local head = ("|cffffffff%s %s|r"):format(L["Checking"], state.addonName)
        if state.expected > 0 then
            return ("%s   %s%d / %d|r"):format(head, CP.outdated, state.received, state.expected)
        end
        return head
    end

    local ok, outdated, missing, noResp, offline = 0, 0, 0, 0, 0
    for _, e in pairs(state.results) do
        local s = m:GetEntryStatus(e)
        if s == "up_to_date" then
            ok = ok + 1
        elseif s == "outdated" then
            outdated = outdated + 1
        elseif s == "missing" then
            missing = missing + 1
        elseif s == "offline" then
            offline = offline + 1
        elseif s == "no_response" then
            noResp = noResp + 1
        end
    end

    local parts = {"|cffffffff" .. state.addonName .. "|r"}
    if ok > 0 then
        parts[#parts + 1] = ("%s%d %s|r"):format(CP.ok, ok, L["UpToDate"])
    end
    if outdated > 0 then
        parts[#parts + 1] = ("%s%d %s|r"):format(CP.outdated, outdated, L["Outdated"])
    end
    if missing > 0 then
        parts[#parts + 1] = ("%s%d %s|r"):format(CP.missing, missing, L["NotInstalled"])
    end
    if noResp > 0 then
        parts[#parts + 1] = ("%s%d %s|r"):format(CP.noResponse, noResp, L["AddonCheckerNoResponse"])
    end
    if offline > 0 then
        parts[#parts + 1] = ("%s%d %s|r"):format(CP.offline, offline, L["Offline"])
    end
    return table.concat(parts, "   ")
end

local function createResultRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row._icon = icon

    local name = E:CreateFontString(row, nil, "OVERLAY", 12)
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetJustifyH("LEFT")
    row._name = name

    local version = E:CreateFontString(row, nil, "OVERLAY", 12)
    version:SetPoint("LEFT", name, "RIGHT", 12, 0)
    version:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    version:SetJustifyH("RIGHT")
    row._version = version

    return row
end

local function updateResultRow(m, row, item)
    local entry = item.entry
    local st = m:GetEntryStatus(entry)
    local latest = m:GetLatestVersion()

    if st == "up_to_date" or st == "outdated" or st == "missing" then
        applyIcon(row._icon, st)
    else
        row._icon:Hide()
    end

    local nameColor = entry.isSelf and CP.self or E:ClassColorCode(entry.class)
    row._name:SetText(nameColor .. (entry.displayName or "?") .. "|r")

    local vtext
    if st == "up_to_date" then
        vtext = CP.ok .. (entry.version or "-") .. "|r"
    elseif st == "outdated" then
        vtext = ("%s%s|r  %s(%s %s)|r"):format(CP.outdated, entry.version or "-", CP.dim, L["AddonCheckerLatest"],
            latest or "?")
    elseif st == "missing" then
        vtext = CP.missing .. L["NotInstalled"] .. "|r"
    elseif st == "pending" then
        vtext = CP.pending .. L["Pending"] .. "|r"
    elseif st == "offline" then
        vtext = CP.offline .. L["Offline"] .. "|r"
    elseif st == "no_response" then
        vtext = CP.dim .. L["AddonCheckerNoResponse"] .. "|r"
    else
        vtext = ""
    end
    row._version:SetText(vtext)
end

local function exportResults(m)
    local state = m.state
    if not state or not state.addonName then
        return nil
    end
    if state.completedAt == 0 and not state.inProgress then
        return nil
    end

    local lines = {}
    local header = ("%s - %s"):format(state.addonName, state.context or "?")
    lines[#lines + 1] = header
    lines[#lines + 1] = string.rep("=", #header)

    local latest = m:GetLatestVersion()
    for _, item in ipairs(m:GetSortedResults()) do
        local entry = item.entry
        local name = entry.displayName or item.key or "?"
        local st = m:GetEntryStatus(entry)
        if st == "up_to_date" then
            lines[#lines + 1] = ("%s: %s"):format(name, entry.version or "-")
        elseif st == "outdated" then
            lines[#lines + 1] = ("%s: %s (outdated, latest %s)"):format(name, entry.version or "-", latest or "?")
        elseif st == "missing" then
            lines[#lines + 1] = ("%s: (not installed)"):format(name)
        elseif st == "offline" then
            lines[#lines + 1] = ("%s: (offline)"):format(name)
        elseif st == "pending" then
            lines[#lines + 1] = ("%s: (pending)"):format(name)
        elseif st == "no_response" then
            lines[#lines + 1] = ("%s: (no response)"):format(name)
        end
    end
    return table.concat(lines, "\n")
end

-- fold a typed name into the custom list for this session
local function setCustomAddon()
    local cc = mod()
    local typed = (ui.newAddonName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if typed == "" then
        E:Printf(L["AddonCheckerTypeAName"])
        return
    end

    local inList = (cc and cc:IsDefault(typed)) or false
    if not inList then
        for _, n in ipairs(ui.customAddons) do
            if n == typed then
                inList = true
                break
            end
        end
    end
    if not inList then
        table.insert(ui.customAddons, typed)
        table.sort(ui.customAddons)
    end

    ui.selectedAddon = typed
    ui.newAddonName = ""
    queueRefresh()
end

local function buildPanel()
    local m = mod()
    if not m then
        return {
            type = "group",
            name = L["AddonChecker"],
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
        local mm = mod()
        return not (mm and mm:IsEnabled())
    end

    local runner = T:CheckerPanel({
        mod = mod,
        ui = ui,
        orderBase = 20,

        onStart = function(c, ctx)
            return c:StartCheck(currentAddon(), ctx)
        end,
        reportStartError = function(_, err)
            reportCheckError(err)
        end,
        statusText = function(c)
            return getStatusText(c)
        end,
        resultsRows = {
            rowHeight = 20,
            items = function(c)
                return c:GetSortedResults()
            end,
            createRow = function(_, parent)
                return createResultRow(parent)
            end,
            updateRow = function(c, row, item)
                updateResultRow(c, row, item)
            end
        },
        exportResults = function(c)
            return exportResults(c)
        end,
        resultsHeight = 320
    })

    local header = {
        desc = {
            order = 1,
            build = function(parent)
                return T:Description(parent, {
                    text = L["AddonCheckerDesc"],
                    sizeDelta = 1
                })
            end
        },
        spacer = {
            order = 1.5,
            build = function(parent)
                return T:Spacer(parent, {
                    height = 10
                })
            end
        },
        pickHeader = {
            order = 2,
            build = function(parent)
                return T:Header(parent, {
                    text = L["AddonCheckerPickHeader"]
                })
            end
        },
        addonSel = {
            order = 10,
            width = "1/3",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["Addon"],
                    values = function()
                        local cc = mod()
                        if cc then
                            return cc:GetAddonChoices(ui.customAddons)
                        end
                        return {
                            BigWigs = "BigWigs"
                        }
                    end,
                    get = currentAddon,
                    onChange = function(v)
                        ui.selectedAddon = v
                    end,
                    disabled = isModuleDisabled
                })
            end
        },
        customName = {
            order = 11,
            width = "1/3",
            build = function(parent)
                return T:EditBox(parent, {
                    label = L["AddonCheckerCustom"],
                    tooltip = {
                        title = L["AddonCheckerCustom"],
                        desc = L["AddonCheckerCustomTooltip"]
                    },
                    height = 20,
                    commitOn = "enter",
                    get = function()
                        return ui.newAddonName or ""
                    end,
                    onCommit = function(text)
                        ui.newAddonName = text or ""
                    end,
                    disabled = isModuleDisabled
                })
            end
        },
        setBtn = {
            order = 12,
            width = "1/3",
            build = function(parent)
                return T:LabelAlignedButton(parent, {
                    text = L["AddonCheckerSet"],
                    tooltip = {
                        title = L["AddonCheckerSet"],
                        desc = L["AddonCheckerSetTooltip"]
                    },
                    onClick = setCustomAddon,
                    disabled = isModuleDisabled
                })
            end
        },
        runHeader = {
            order = 19,
            build = function(parent)
                return T:Header(parent, {
                    text = L["RunCheck"]
                })
            end
        }
    }

    return {
        type = "group",
        name = L["AddonChecker"],
        args = T:MergeArgs(header, runner)
    }
end

E:RegisterOptions("AddonChecker", 32, buildPanel)
