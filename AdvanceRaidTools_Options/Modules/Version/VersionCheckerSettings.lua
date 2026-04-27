local E, L = unpack(ART)
local T = E.Templates
local CP = E.OptionsHelpers.CHECKER_PALETTE

local function mod()
    return E:GetModule("VersionChecker", true)
end

local SORT_MODES = {
    status = L["SortByStatus"],
    version = L["SortByVersion"],
    name = L["SortByName"]
}
local SORT_ORDER = {"status", "version", "name"}

local ui = {
    sortMode = "status",
    contextOverride = nil
}

local VersionCheckerEvents = E:NewCallbackHandle()
VersionCheckerEvents:RegisterMessage("ART_VERSIONCHECK_UPDATED", function()
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
end)

local function fmtVersion(v)
    v = tostring(v or "")
    if not v:find("%.") and #v == 2 then
        return v:sub(1, 1) .. "." .. v:sub(2, 2)
    end
    return v
end

local function reportCheckError(err)
    if not err or err == "DISABLED" then
        return
    end
    if err == "NO_CONTEXT" then
        E:Printf(L["VersionCheckNoContext"])
    elseif err == "TOO_SOON" then
        E:Printf(L["CheckTooSoon"])
    else
        E:Printf(L["VersionCheckFailed"], err or "?")
    end
end

local function getResultText(m, sortMode)
    local state = m.state
    if not state then
        return ""
    end

    local highest = m:GetHighestVersion()
    local list = m:GetSortedResults(sortMode or "status")
    local lines = {}

    for _, item in ipairs(list) do
        local entry = item.entry
        local nameColor = entry.isSelf and CP.self or E:ClassColorCode(entry.class)
        local valueColor, valueText

        if entry.status == m.STATUS_RESPONDED then
            if highest and m:CompareVersions(entry.version, highest) < 0 then
                valueColor = CP.outdated
                valueText = fmtVersion(entry.version) .. "  " .. L["Outdated"]
            else
                valueColor = CP.ok
                valueText = fmtVersion(entry.version)
            end
        elseif entry.status == m.STATUS_PENDING then
            valueColor, valueText = CP.pending, L["Pending"]
        elseif entry.status == m.STATUS_NO_ADDON then
            valueColor, valueText = CP.noAddon, L["NotInstalled"]
        elseif entry.status == m.STATUS_OFFLINE then
            valueColor, valueText = CP.offline, L["Offline"]
        else
            valueColor, valueText = "|cffffffff", "?"
        end

        lines[#lines + 1] = nameColor .. entry.displayName .. "|r   " .. valueColor .. valueText .. "|r"
    end

    if #lines == 0 then
        return CP.muted .. L["VersionCheckEmpty"] .. "|r"
    end
    return table.concat(lines, "\n")
end

local function getStatusText(m)
    local state = m.state
    if not state then
        return ""
    end

    if state.inProgress then
        if state.expected > 0 then
            return ("|cffffcc00%s|r  %d / %d"):format(L["Checking"], state.received, state.expected)
        end
        return "|cffffcc00" .. L["Checking"] .. "|r"
    end

    if state.completedAt > 0 then
        local c = m:GetCounts()
        local parts = {}
        if c.upToDate > 0 then
            parts[#parts + 1] = CP.ok .. c.upToDate .. " " .. L["UpToDate"] .. "|r"
        end
        if c.outdated > 0 then
            parts[#parts + 1] = CP.outdated .. c.outdated .. " " .. L["Outdated"] .. "|r"
        end
        if c.missing > 0 then
            parts[#parts + 1] = CP.noAddon .. c.missing .. " " .. L["NotInstalled"] .. "|r"
        end
        if c.offline > 0 then
            parts[#parts + 1] = CP.offline .. c.offline .. " " .. L["Offline"] .. "|r"
        end
        return table.concat(parts, "    ")
    end

    return ""
end

local function exportResults(m)
    local state = m.state
    if not state then
        return nil
    end
    if state.completedAt == 0 and not state.inProgress then
        return nil
    end

    local highest = m:GetHighestVersion()
    local lines = {}
    local header = ("Version Check — %s"):format(state.context or "?")
    lines[#lines + 1] = header
    if highest then
        lines[#lines + 1] = ("Latest seen: %s"):format(highest)
    end
    lines[#lines + 1] = string.rep("=", #header)

    local upToDate, outdated, missing, offline = {}, {}, {}, {}
    for _, item in ipairs(m:GetSortedResults("name")) do
        local entry = item.entry
        local name = entry.displayName or item.key or "?"
        if entry.status == m.STATUS_RESPONDED then
            if highest and m:CompareVersions(entry.version, highest) < 0 then
                outdated[#outdated + 1] = ("%s (%s)"):format(name, tostring(entry.version))
            else
                upToDate[#upToDate + 1] = name
            end
        elseif entry.status == m.STATUS_NO_ADDON then
            missing[#missing + 1] = name
        elseif entry.status == m.STATUS_OFFLINE then
            offline[#offline + 1] = name
        end
    end

    local function section(label, list)
        if #list > 0 then
            lines[#lines + 1] = ("%s (%d): %s"):format(label, #list, table.concat(list, ", "))
        end
    end

    section("Up to date", upToDate)
    section("Outdated", outdated)
    section("Not installed", missing)
    section("Offline", offline)

    return table.concat(lines, "\n")
end

local function buildPanel()
    local m = mod()
    if not m then
        return {
            type = "group",
            name = L["VersionChecker"],
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

    local runner = T:CheckerPanel({
        mod = mod,
        ui = ui,
        orderBase = 20,

        sortModes = SORT_MODES,
        sortOrder = SORT_ORDER,

        onStart = function(c, ctx)
            return c:StartVersionCheck(ctx)
        end,
        reportStartError = function(_, err)
            reportCheckError(err)
        end,
        statusText = function(c)
            return getStatusText(c)
        end,
        resultsText = function(c)
            return getResultText(c, ui.sortMode)
        end,
        exportResults = function(c)
            return exportResults(c)
        end,
        resultsHeight = 340
    })

    local header = {
        desc = {
            order = 1,
            build = function(parent)
                return T:Description(parent, {
                    text = L["VersionCheckerDesc"],
                    sizeDelta = 1
                })
            end
        },
        spacer = {
            order = 1.5,
            build = function(parent)
                return T:Spacer(parent, {
                    height = 12
                })
            end
        },
        runHeader = {
            order = 2,
            build = function(parent)
                return T:Header(parent, {
                    text = L["RunCheck"]
                })
            end
        }
    }

    return {
        type = "group",
        name = L["VersionChecker"],
        args = T:MergeArgs(header, runner)
    }
end

E:RegisterOptions("VersionChecker", 30, buildPanel)
