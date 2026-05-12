local E = unpack(ART)
local unpack = unpack or table.unpack

local BossMods = E:GetModule("BossMods")
BossMods.ReadyAssignments = BossMods.ReadyAssignments or {}
local Ready = BossMods.ReadyAssignments

Ready.providers = Ready.providers or {}
Ready.providerOrder = Ready.providerOrder or {}
Ready.staticReminders = Ready.staticReminders or {}
Ready.staticReminderOrder = Ready.staticReminderOrder or {}
Ready.actions = Ready.actions or {}
Ready.actionOrder = Ready.actionOrder or {}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyInto(dst, src)
    if type(src) ~= "table" then
        return dst
    end
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

function Ready:NormalizeTag(tag)
    if type(tag) ~= "string" then
        return nil
    end
    tag = trim(tag):lower():gsub("^#", "")
    if tag == "" then
        return nil
    end
    return tag
end

function Ready:CleanToken(token)
    if type(token) ~= "string" then
        return ""
    end
    token = token:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    token = token:gsub("|T.-|t", "")
    token = token:gsub("^[%s,;:]+", ""):gsub("[%s,;:]+$", "")
    return token
end

function Ready:GetMainNoteText()
    if BossMods.NoteBlock and BossMods.NoteBlock.GetMainNoteText then
        return BossMods.NoteBlock:GetMainNoteText() or ""
    end
    if _G.ART and ART.GetRawNote then
        return ART:GetRawNote(1) or ""
    end
    return ""
end

function Ready:Words(text)
    local out = {}
    if type(text) ~= "string" then
        return out
    end
    for raw in text:gmatch("%S+") do
        local token = self:CleanToken(raw)
        if token ~= "" then
            out[#out + 1] = token
        end
    end
    return out
end

function Ready:TokenIsPlayer(token, ctx)
    token = self:CleanToken(token)
    if token == "" then
        return false
    end

    local noteBlock = BossMods.NoteBlock
    if noteBlock and noteBlock.IsPlayerToken then
        return noteBlock:IsPlayerToken(token, ctx and ctx.ids)
    end

    local lname = (UnitName("player") or ""):lower()
    return token:lower() == lname
end

function Ready:FindPlayerInText(text, ctx)
    local idx = 0
    for _, token in ipairs(self:Words(text)) do
        idx = idx + 1
        if self:TokenIsPlayer(token, ctx) then
            return idx, token
        end
    end
    return nil
end

function Ready:ParseHashSections(noteText)
    local sections = {}
    local byTag = {}
    local current

    local function finish()
        if not current then
            return
        end
        current.text = table.concat(current.lines, "\n")
        sections[#sections + 1] = current
        byTag[current.tag] = byTag[current.tag] or {}
        byTag[current.tag][#byTag[current.tag] + 1] = current
        current = nil
    end

    if type(noteText) ~= "string" or noteText == "" then
        return sections, byTag
    end

    for raw in noteText:gmatch("[^\r\n]+") do
        local line = trim(raw)
        if line == "" then
            finish()
        else
            local tag, rest = line:match("^#(%S+)%s*(.*)$")
            if tag then
                finish()
                tag = self:NormalizeTag(tag)
                if tag then
                    current = {
                        tag = tag,
                        lines = {}
                    }
                    rest = trim(rest or "")
                    if rest ~= "" then
                        current.lines[#current.lines + 1] = rest
                    end
                end
            elseif current then
                current.lines[#current.lines + 1] = line
            end
        end
    end

    finish()
    return sections, byTag
end

function Ready:BuildContext()
    local noteText = self:GetMainNoteText()
    local sections, tags = self:ParseHashSections(noteText)
    local noteBlock = BossMods.NoteBlock

    return {
        noteText = noteText,
        hashSections = sections,
        tags = tags,
        ids = noteBlock and noteBlock.GetPlayerIdentifiers and noteBlock:GetPlayerIdentifiers() or nil
    }
end

function Ready:FindPlayerInBlock(ctx, blockName)
    if not (BossMods.NoteBlock and BossMods.NoteBlock.ExtractBlock) then
        return nil
    end

    local block = BossMods.NoteBlock:ExtractBlock(ctx and ctx.noteText or "", blockName)
    if not block then
        return nil
    end

    local lineIndex = 0
    for raw in block:gmatch("[^\r\n]+") do
        local line = trim(raw)
        if line ~= "" then
            lineIndex = lineIndex + 1
            local tokenIndex = self:FindPlayerInText(line, ctx)
            if tokenIndex then
                return lineIndex, tokenIndex, line
            end
        end
    end

    return nil
end

function Ready:PlayerInBlock(ctx, blockName)
    return self:FindPlayerInBlock(ctx, blockName) ~= nil
end

function Ready:FindPlayerInHashTag(ctx, tag)
    tag = self:NormalizeTag(tag)
    if not tag or not ctx or not ctx.tags then
        return nil
    end

    local matches = ctx.tags[tag]
    if not matches then
        return nil
    end

    for _, section in ipairs(matches) do
        local tokenIndex = self:FindPlayerInText(section.text, ctx)
        if tokenIndex then
            return section, tokenIndex
        end
    end

    return nil
end

function Ready:HashTagHasWord(ctx, tag, word)
    tag = self:NormalizeTag(tag)
    word = self:NormalizeTag(word)
    if not tag or not word or not ctx or not ctx.tags then
        return false
    end

    local matches = ctx.tags[tag]
    if not matches then
        return false
    end

    for _, section in ipairs(matches) do
        for _, token in ipairs(self:Words(section.text)) do
            if self:NormalizeTag(token) == word then
                return true
            end
        end
    end

    return false
end

function Ready:HashTagExists(ctx, tag)
    tag = self:NormalizeTag(tag)
    if not tag or not ctx or not ctx.tags then
        return false
    end

    local matches = ctx.tags[tag]
    return type(matches) == "table" and #matches > 0
end

local function hasAction(opts)
    return type(opts) == "table" and
               (type(opts.action) == "table" or type(opts.execute) == "function" or type(opts.stopAction) == "table")
end

local function resolveActionArg(arg, opts, env)
    if type(arg) == "string" then
        if type(env) == "table" and env[arg] ~= nil then
            return env[arg]
        end
        if type(opts) == "table" and opts[arg] ~= nil then
            return opts[arg]
        end
    end
    return arg
end

function Ready:ActionMatches(opts, ctx)
    if type(opts.match) == "function" then
        return opts:match(ctx, self)
    end

    local source = opts.source or opts.kind
    if source == "hashtagWord" then
        return self:HashTagHasWord(ctx, opts.tag or opts.key, opts.word)
    elseif source == "hashtag" then
        if opts.requiresPlayer == false then
            return self:HashTagExists(ctx, opts.tag or opts.key)
        end
        return self:FindPlayerInHashTag(ctx, opts.tag or opts.key) ~= nil
    elseif source == "noteBlock" then
        return self:PlayerInBlock(ctx, opts.noteBlock or opts.block or opts.tag or opts.key)
    end

    return false
end

function Ready:RegisterAction(key, opts)
    assert(type(key) == "string" and key ~= "", "ReadyAssignments:RegisterAction: key required")
    assert(type(opts) == "table", "ReadyAssignments:RegisterAction: opts required")

    if not self.actions[key] then
        self.actionOrder[#self.actionOrder + 1] = key
    end
    self.actions[key] = opts
end

function Ready:InvokeModuleAction(action, opts, env, requireEnabled)
    if type(action) ~= "table" then
        return false
    end

    local moduleName = action.moduleName or opts.moduleName
    local method = action.method
    if type(moduleName) ~= "string" or moduleName == "" or type(method) ~= "string" or method == "" then
        return false
    end

    local mod = E:GetModule(moduleName, true)
    if not mod or type(mod[method]) ~= "function" then
        return false
    end
    if requireEnabled ~= false and mod.IsEnabled and not mod:IsEnabled() then
        return false
    end

    local args = {}
    for _, arg in ipairs(action.args or {}) do
        args[#args + 1] = resolveActionArg(arg, opts, env)
    end
    mod[method](mod, unpack(args))
    return true
end

function Ready:RunAction(opts, ctx, env)
    if type(opts.execute) == "function" then
        return opts:execute(ctx, env, self)
    end
    return self:InvokeModuleAction(opts.action, opts, env, true)
end

function Ready:RunActions(ctx, env)
    ctx = ctx or self:BuildContext()

    for _, key in ipairs(self.actionOrder) do
        local opts = self.actions[key]
        if opts and self:IsModuleEnabled(opts.moduleName) and self:ActionMatches(opts, ctx) then
            local ok, err = pcall(self.RunAction, self, opts, ctx, env)
            if not ok then
                E:ChannelWarn("BossMods_AssignmentReminders", "action '%s' failed: %s", key, tostring(err))
            end
        end
    end
end

function Ready:StopAction(opts, env)
    local stopAction = opts.stopAction
    local action = opts.action
    if not stopAction and type(action) == "table" and action.hideMethod then
        stopAction = {
            moduleName = action.moduleName,
            method = action.hideMethod,
            args = action.hideArgs
        }
    end

    if stopAction then
        return self:InvokeModuleAction(stopAction, opts, env, false)
    end
end

function Ready:StopActions(env)
    for _, key in ipairs(self.actionOrder) do
        local opts = self.actions[key]
        if opts then
            local ok, err = pcall(self.StopAction, self, opts, env)
            if not ok then
                E:ChannelWarn("BossMods_AssignmentReminders", "action '%s' stop failed: %s", key, tostring(err))
            end
        end
    end
end

function Ready:RegisterProvider(key, opts)
    assert(type(key) == "string" and key ~= "", "ReadyAssignments:RegisterProvider: key required")
    assert(type(opts) == "table", "ReadyAssignments:RegisterProvider: opts required")
    assert(type(opts.evaluate) == "function", "ReadyAssignments:RegisterProvider: opts.evaluate required")

    if not self.providers[key] then
        self.providerOrder[#self.providerOrder + 1] = key
    end
    self.providers[key] = opts
end

function Ready:NewReminder(opts, extra)
    local reminder = {}
    copyInto(reminder, opts)
    copyInto(reminder, extra)
    reminder.priority = reminder.priority or 50
    return reminder
end

function Ready:RegisterStaticReminder(tag, opts)
    tag = self:NormalizeTag(tag)
    assert(tag, "ReadyAssignments:RegisterStaticReminder: tag required")
    assert(type(opts) == "table", "ReadyAssignments:RegisterStaticReminder: opts required")

    if not self.staticReminders[tag] then
        self.staticReminderOrder[#self.staticReminderOrder + 1] = tag
    end
    self.staticReminders[tag] = opts
end

function Ready:RegisterNoteBlockReminder(key, opts)
    assert(type(key) == "string" and key ~= "", "ReadyAssignments:RegisterNoteBlockReminder: key required")
    assert(type(opts) == "table", "ReadyAssignments:RegisterNoteBlockReminder: opts required")

    local blockName = opts.noteBlock or opts.block or opts.tag or key
    assert(type(blockName) == "string" and blockName ~= "",
        "ReadyAssignments:RegisterNoteBlockReminder: opts.noteBlock required")

    self:RegisterProvider(opts.providerKey or key, {
        moduleName = opts.moduleName,
        evaluate = function(_, ctx, out, api)
            local lineIndex, tokenIndex, line = api:FindPlayerInBlock(ctx, blockName)
            if not (lineIndex and tokenIndex) then
                return
            end

            local reminder = api:NewReminder(opts, {
                key = opts.key or key,
                type = opts.type or key,
                noteBlock = blockName,
                lineIndex = lineIndex,
                tokenIndex = tokenIndex,
                line = line,
                priority = opts.priority or 50
            })

            if type(opts.map) == "function" then
                local mapped = opts.map(reminder, ctx, api)
                if mapped == false then
                    return
                elseif type(mapped) == "table" then
                    copyInto(reminder, mapped)
                end
            end

            api:Add(out, reminder)
        end
    })
end

function Ready:RegisterTextReminder(key, overrides)
    local text = BossMods.ReadyAssignmentText
    assert(text and text.Get, "ReadyAssignments:RegisterTextReminder: ReadyAssignmentText unavailable")

    local def = text:Get(key)
    if not def then
        E:ChannelWarn("BossMods_AssignmentReminders", "reminder text '%s' is not registered", tostring(key))
        return false
    end

    local opts = {}
    copyInto(opts, def)
    copyInto(opts, overrides)
    opts.key = key

    local source = opts.source or opts.kind
    local registered = false
    if hasAction(opts) then
        self:RegisterAction(opts.actionKey or opts.providerKey or key, opts)
        registered = true
    end

    if source == "hashtag" then
        self:RegisterStaticReminder(opts.tag or key, opts)
        registered = true
    elseif source == "noteBlock" then
        self:RegisterNoteBlockReminder(key, opts)
        registered = true
    elseif source == "hashtagWord" then
        -- Action-only source. The matcher lives in RunActions.
    elseif type(opts.evaluate) == "function" then
        self:RegisterProvider(opts.providerKey or key, opts)
        registered = true
    end

    if registered then
        return true
    end

    E:ChannelWarn("BossMods_AssignmentReminders", "reminder text '%s' has no source", tostring(key))
    return false
end

function Ready:RegisterTextReminders(keys, overrides)
    local text = BossMods.ReadyAssignmentText
    assert(text and text.ResolveKeys, "ReadyAssignments:RegisterTextReminders: ReadyAssignmentText unavailable")

    for _, key in ipairs(text:ResolveKeys(keys)) do
        local override = type(overrides) == "table" and (overrides[key] or overrides.default) or nil
        self:RegisterTextReminder(key, override)
    end
end

function Ready:Add(out, reminder)
    if type(out) ~= "table" or type(reminder) ~= "table" then
        return
    end
    out[#out + 1] = reminder
end

function Ready:IsModuleEnabled(moduleName)
    if type(moduleName) ~= "string" or moduleName == "" then
        return true
    end
    local mod = E:GetModule(moduleName, true)
    return mod and mod.IsEnabled and mod:IsEnabled() or false
end

function Ready:Collect(ctx)
    ctx = ctx or self:BuildContext()
    local out = {}

    for _, tag in ipairs(self.staticReminderOrder) do
        local opts = self.staticReminders[tag]
        if opts and self:IsModuleEnabled(opts.moduleName) then
            local section = self:FindPlayerInHashTag(ctx, tag)
            if section or opts.requiresPlayer == false then
                self:Add(out, self:NewReminder(opts, {
                    key = opts.key or tag,
                    type = opts.type or "hashtag",
                    tag = tag,
                    priority = opts.priority or 50,
                    section = section
                }))
            end
        end
    end

    for _, key in ipairs(self.providerOrder) do
        local provider = self.providers[key]
        if provider and self:IsModuleEnabled(provider.moduleName) then
            local ok, err = pcall(provider.evaluate, provider, ctx, out, self)
            if not ok then
                E:ChannelWarn("BossMods_AssignmentReminders", "provider '%s' failed: %s", key, tostring(err))
            end
        end
    end

    table.sort(out, function(a, b)
        if (a.priority or 50) == (b.priority or 50) then
            return tostring(a.type or "") < tostring(b.type or "")
        end
        return (a.priority or 50) > (b.priority or 50)
    end)

    return out
end
