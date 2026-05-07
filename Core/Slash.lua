local E, L = unpack(ART)

local function printHelp()
    E:Printf(L["SlashHelpHeader"])
    E:Printf("  /art            %s", L["SlashHelpOpen"])
    E:Printf("  /art map        %s", L["SlashHelpMap"])
    E:Printf("  /art pi         %s", L["SlashHelpPI"])
    E:Printf("  /art innervate  %s", L["SlashHelpInnervate"])
    E:Printf("  /art help       %s", L["SlashHelpHelp"])
end

local DEFAULT_SPELL_TARGET_COMMANDS = {
    inn = {
        slotID = 2,
        spell = "Innervate"
    },
    innervate = {
        slotID = 2,
        spell = "Innervate"
    },
    pi = {
        slotID = 1,
        spell = "Power Infusion"
    },
    powerinfusion = {
        slotID = 1,
        spell = "Power Infusion"
    }
}

local function onOffToBool(token)
    if token == "on" or token == "enable" or token == "enabled" or token == "true" or token == "1" then
        return true
    end
    if token == "off" or token == "disable" or token == "disabled" or token == "false" or token == "0" then
        return false
    end
    return nil
end

local function printDebugHelp()
    E:Printf(L["DebugHelpHeader"])
    E:Printf("  /art debug                %s", L["DebugHelpStatus"])
    E:Printf("  /art debug on|off         %s", L["DebugHelpMaster"])
    E:Printf("  /art debug list           %s", L["DebugHelpList"])
    E:Printf("  /art debug <channel>      %s", L["DebugHelpChannel"])
    E:Printf("  /art debug <channel> on|off")
    E:Printf("  /art debug log [sev|@chan]  %s", L["DebugHelpLog"])
    E:Printf("  /art debug log clear      %s", L["DebugHelpLogClear"])
end

local function printDebugStatus()
    local d = E.db and E.db.profile.general.debug
    if not d then
        E:Printf(L["DebugUnavailable"])
        return
    end
    E:Printf(L["DebugStateMaster"], d.enabled and L["DebugOn"] or L["DebugOff"])
    local any = false
    for chan, on in pairs(d.channels or {}) do
        if on then
            any = true
            E:Printf("  - %s: %s", chan, L["DebugOn"])
        end
    end
    if not any then
        E:Printf(L["DebugStateNoChannels"])
    end
end

local function reportMacroResult(m, ok, err, extra, successText)
    if ok then
        E:Printf(err == "QUEUED" and L["Macros_UpdateQueued"] or successText or L["Macros_UpdateDone"])
        return
    end

    if err == "TOO_LONG" then
        E:Printf(L["Macros_ErrorTooLong"]:format(#tostring(extra or ""), m and m:GetTextLimit() or 255))
    elseif err == "EMPTY" then
        E:Printf(L["Macros_ErrorEmpty"])
    elseif err == "NAME_IN_USE" then
        E:Printf(L["Macros_ErrorNameInUse"])
    elseif err == "GENERAL_FULL" then
        E:Printf(L["Macros_ErrorGeneralFull"])
    elseif err == "MEGAMACRO_BLOCKED" then
        E:Printf(L["Macros_ErrorMegaMacro"])
    elseif err == "WRITE_FAILED" then
        E:Printf(L["Macros_ErrorWriteFailed"]:format(tostring(extra or "")))
    elseif err == "NO_TARGET" then
        E:Printf(L["Macros_ErrorNoTarget"])
    elseif err == "TARGET_NOT_PLAYER" then
        E:Printf(L["Macros_ErrorTargetNotPlayer"])
    elseif err == "NO_SLOT" then
        E:Printf(L["Macros_NoSlot"])
    else
        E:Printf(L["Macros_ErrorGeneric"]:format(tostring(err or "?")))
    end
end

local function defaultSpellTargetHandler(command)
    local m = E:GetModule("Macros", true)
    if not (m and m:IsEnabled() and m.SetDefaultSpellTargetFromUnit) then
        E:Printf(L["LoadModule"])
        return
    end

    local ok, err, extra, targetName = m:SetDefaultSpellTargetFromUnit(command.slotID, "target")
    local successText = targetName and L["Macros_DefaultSpellTargetUpdated"]:format(command.spell, targetName) or
                            L["Macros_UpdateDone"]
    reportMacroResult(m, ok, err, extra, successText)
end

local function printDebugList()
    local channels = E:ListDebugChannels()
    local d = E.db and E.db.profile.general.debug
    local names = {}
    for name in pairs(channels) do
        table.insert(names, name)
    end
    table.sort(names)
    if #names == 0 then
        E:Printf(L["DebugListEmpty"])
        return
    end
    E:Printf(L["DebugListHeader"])
    for _, name in ipairs(names) do
        local on = d and d.channels and d.channels[name]
        E:Printf("  - %s: %s", name, on and L["DebugOn"] or L["DebugOff"])
    end
end

-- /art debug ...
local function debugHandler(rest)
    rest = (rest or ""):trim()
    if rest == "" then
        printDebugStatus()
        E:Printf(L["DebugHelpHint"])
        return
    end

    if rest == "help" or rest == "?" then
        printDebugHelp()
        return
    end
    if rest == "list" then
        printDebugList()
        return
    end
    if rest == "log" then
        E:DumpLog()
        return
    end
    if rest == "log clear" then
        E:ClearLog()
        E:Printf(L["LogCleared"])
        return
    end

    local sev = rest:match("^log%s+(.+)$")
    if sev then
        E:DumpLog(sev)
        return
    end

    -- Master toggle / per-channel toggle share a parser:
    --   "on" | "off" | "toggle"              → master
    --   "<chan>" | "<chan> on|off|toggle"    → channel
    local first, second = rest:match("^(%S+)%s*(.*)$")
    first = first or ""
    second = (second or ""):trim()

    local bool = onOffToBool(first)
    if bool ~= nil and second == "" then
        E:SetDebugEnabled(nil, bool)
        E:Printf(L["DebugStateMaster"], bool and L["DebugOn"] or L["DebugOff"])
        return
    end
    if first == "toggle" and second == "" then
        local cur = E:IsDebugEnabled()
        E:SetDebugEnabled(nil, not cur)
        E:Printf(L["DebugStateMaster"], (not cur) and L["DebugOn"] or L["DebugOff"])
        return
    end

    -- Unknown channels are auto-registered so tools like
    -- /run E:SetDebugEnabled("Stuff", true) still work before the thing
    -- has called RegisterDebugChannel itself
    local channel = first
    local action = second
    local d = E.db and E.db.profile.general.debug
    local current = d and d.channels and d.channels[channel] or false
    local want
    if action == "" or action == "toggle" then
        want = not current
    else
        want = onOffToBool(action)
        if want == nil then
            E:Printf(L["SlashUnknown"], "debug " .. rest)
            printDebugHelp()
            return
        end
    end
    E:SetDebugEnabled(channel, want)
    E:Printf(L["DebugStateChannel"], channel, want and L["DebugOn"] or L["DebugOff"])
end

local function handler(input)
    input = (input or ""):trim()

    if input == "" then
        E:OpenOptions()
        return
    end

    local verb, rest = input:match("^(%S+)%s*(.*)$")
    verb = (verb or ""):lower()
    rest = rest or ""

    local spellCommand = DEFAULT_SPELL_TARGET_COMMANDS[verb]
    if verb == "map" then
        local profile = E.db.profile.general
        profile.minimapIcon.hide = not profile.minimapIcon.hide
        -- /art map must never error if HomeSettings failed to register
        E:CallModule("HomeSettings", "UpdateMinimap")
    elseif spellCommand then
        defaultSpellTargetHandler(spellCommand)
    elseif verb == "help" then
        printHelp()
    elseif verb == "update" then
        E:CallModule("Updater", "Trigger")
    elseif verb == "debug" then
        debugHandler(rest)
    else
        E:Printf(L["SlashUnknown"], input)
        printHelp()
    end
end

function E:RegisterSlashCommands()
    self:RegisterChatCommand("art", handler)
    self:RegisterChatCommand("advanceraidtools", handler)
end
