local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.NoteBlock = BossMods.NoteBlock or {}
local NoteBlock = BossMods.NoteBlock

local function cleanToken(token)
    if type(token) ~= "string" then
        return ""
    end
    token = token:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    token = token:gsub("|T.-|t", "")
    return token:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizedToken(token)
    token = cleanToken(token)
    if token == "" then
        return ""
    end
    return token:lower()
end

local function forEachGroupUnit(fn)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do
            local unit = "raid" .. i
            if UnitExists(unit) and fn(unit, i) then
                return true
            end
        end
        return false
    end

    if UnitExists("player") and fn("player", 1) then
        return true
    end

    local num = GetNumGroupMembers() or 0
    for i = 1, math.max(num - 1, 0) do
        local unit = "party" .. i
        if UnitExists(unit) and fn(unit, i + 1) then
            return true
        end
    end
    return false
end

local function unitNameMatches(unit, token)
    local wanted = normalizedToken(token)
    if wanted == "" or not UnitExists(unit) then
        return false
    end

    local name = UnitName(unit)
    if name and normalizedToken(name) == wanted then
        return true
    end

    if E.GetUnitFullName then
        local full = E:GetUnitFullName(unit, true)
        if full and normalizedToken(full) == wanted then
            return true
        end
    end

    if E.GetNickname then
        local nick = E:GetNickname(unit)
        if nick and normalizedToken(nick) == wanted then
            return true
        end
    end

    return false
end

function NoteBlock:GetMainNoteText()
    if _G.ART and ART.GetRawNote then
        return ART:GetRawNote(1) or ""
    end
    return ""
end

function NoteBlock:ExtractBlock(text, blockName)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    if type(blockName) ~= "string" or blockName == "" then
        return nil
    end
    local lower = text:lower()
    local startTag = blockName:lower() .. "start"
    local endTag = blockName:lower() .. "end"
    local s, e = lower:find(startTag, 1, true)
    if not s then
        return nil
    end
    local eS = lower:find(endTag, e + 1, true)
    if not eS then
        return nil
    end
    return text:sub(e + 1, eS - 1)
end

function NoteBlock:Lines(block)
    local out = {}
    if type(block) ~= "string" then
        return out
    end
    for raw in block:gmatch("[^\r\n]+") do
        local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            out[#out + 1] = line
        end
    end
    return out
end

function NoteBlock:Words(text)
    local out = {}
    if type(text) ~= "string" then
        return out
    end
    for word in text:gmatch("%S+") do
        out[#out + 1] = word
    end
    return out
end

function NoteBlock:GetPlayerIdentifiers()
    local lname = (UnitName("player") or ""):lower()
    local realmName = (GetRealmName() or ""):lower():gsub("%s+", "")
    local full = lname .. "-" .. realmName
    local nickname
    if E.GetNickname then
        local n = E:GetNickname("player")
        if n and n ~= "" then
            nickname = n:lower()
        end
    end
    return {
        name = lname,
        full = full,
        nickname = nickname
    }
end

function NoteBlock:IsPlayerToken(token, ids)
    if type(token) ~= "string" then
        return false
    end
    local t = normalizedToken(token)
    ids = ids or self:GetPlayerIdentifiers()
    if t == ids.name or t == ids.full then
        return true
    end
    if ids.nickname and t == ids.nickname then
        return true
    end
    return false
end

function NoteBlock:FindUnitByToken(token)
    if type(token) ~= "string" or token == "" then
        return nil
    end

    if E.GetCharacterInGroup then
        local unit = E:GetCharacterInGroup(cleanToken(token))
        if unit and UnitExists(unit) then
            return unit
        end
    end

    if E.GetGroupUnitByName then
        local unit = E:GetGroupUnitByName(cleanToken(token))
        if unit and UnitExists(unit) then
            return unit
        end
    end

    local found
    forEachGroupUnit(function(unit)
        if unitNameMatches(unit, token) then
            found = unit
            return true
        end
        return false
    end)
    return found
end

function NoteBlock:ResolveTokenToName(token)
    if type(token) ~= "string" or token == "" then
        return nil
    end
    local unit = self:FindUnitByToken(token)
    if unit then
        return UnitName(unit)
    end
    return nil
end

function NoteBlock:ParseNodeMapping(slotText, blockName, nodeCount)
    local block = self:ExtractBlock(slotText, blockName)
    if not block then
        return nil
    end

    local nameToIndex = {}
    local num = GetNumGroupMembers() or 0
    local inRaid = IsInRaid()

    local function addUnit(unit, idx)
        if not UnitExists(unit) then
            return
        end
        local n = UnitName(unit)
        if n and n ~= "" then
            nameToIndex[normalizedToken(n)] = idx
        end
        if E.GetUnitFullName then
            local full = E:GetUnitFullName(unit, true)
            if full and full ~= "" then
                nameToIndex[normalizedToken(full)] = idx
            end
        end
        if E.GetNickname then
            local nick = E:GetNickname(unit)
            if nick and nick ~= "" then
                nameToIndex[normalizedToken(nick)] = idx
            end
        end
    end

    if inRaid then
        for i = 1, num do
            addUnit("raid" .. i, i)
        end
    else
        addUnit("player", 1)
        for i = 1, num - 1 do
            addUnit("party" .. i, i + 1)
        end
    end

    local map = {}
    local matched = false
    local nodeIdx = 0
    for word in block:gmatch("%S+") do
        nodeIdx = nodeIdx + 1
        if nodeCount and nodeIdx > nodeCount then
            break
        end
        local raidIdx = nameToIndex[normalizedToken(word)]
        if raidIdx then
            map[raidIdx] = nodeIdx
            matched = true
        end
    end

    if not matched then
        return nil
    end
    return map
end

function NoteBlock:GetUnitDisplayName(unit, fallback)
    if unit and UnitExists(unit) then
        if E.GetNickname then
            local nick = E:GetNickname(unit)
            if nick and nick ~= "" then
                return nick
            end
        end

        local raw = UnitName(unit)
        if raw and raw ~= "" then
            return raw
        end
    end
    return fallback
end

function NoteBlock:GetDisplayName(charName)
    if type(charName) ~= "string" or charName == "" then
        return charName
    end
    local unit = self:FindUnitByToken(charName)
    return self:GetUnitDisplayName(unit, charName)
end

NoteBlock._noteBlocks = NoteBlock._noteBlocks or {}
NoteBlock._noteBlockOrder = NoteBlock._noteBlockOrder or {}

local function registerNoteBlockEntry(registry, key, entry)
    if not registry._noteBlocks[key] then
        registry._noteBlockOrder[#registry._noteBlockOrder + 1] = key
    end
    registry._noteBlocks[key] = entry
end

function NoteBlock:RegisterNoteBlock(key, opts)
    assert(type(key) == "string" and key ~= "", "RegisterNoteBlock: key required")
    assert(type(opts) == "table", "RegisterNoteBlock: opts required")
    assert(type(opts.blocks) == "table" and #opts.blocks > 0,
        "RegisterNoteBlock: opts.blocks must be a non-empty array of {tag, template}")

    registerNoteBlockEntry(self, key, {
        key = key,
        entryType = "block",
        blocks = opts.blocks,
        moduleName = opts.moduleName,
        labelKey = opts.labelKey or key,
        descKey = opts.descKey,
        tab = opts.tab,
        order = opts.order or 100,
        raidKey = opts.raidKey,
        raidLabelKey = opts.raidLabelKey,
        bossKey = opts.bossKey,
        bossLabelKey = opts.bossLabelKey,
        bossOrder = opts.bossOrder,
        itemKey = opts.itemKey,
        itemLabelKey = opts.itemLabelKey,
        itemOrder = opts.itemOrder,
        blockSeparator = opts.blockSeparator or opts.noteBlockSeparator
    })
end

function NoteBlock:RegisterNoteBlockGroup(key, opts)
    assert(type(key) == "string" and key ~= "", "RegisterNoteBlockGroup: key required")
    assert(type(opts) == "table", "RegisterNoteBlockGroup: opts required")

    local entries = opts.entries or opts.noteBlocks or opts.blockKeys
    assert(type(entries) == "table" and #entries > 0,
        "RegisterNoteBlockGroup: opts.entries must be a non-empty array of note block keys")

    registerNoteBlockEntry(self, key, {
        key = key,
        entryType = "group",
        entries = entries,
        moduleName = opts.moduleName,
        labelKey = opts.labelKey or key,
        descKey = opts.descKey,
        tab = opts.tab,
        order = opts.order or 100,
        raidKey = opts.raidKey,
        raidLabelKey = opts.raidLabelKey,
        bossKey = opts.bossKey,
        bossLabelKey = opts.bossLabelKey,
        bossOrder = opts.bossOrder,
        itemKey = opts.itemKey,
        itemLabelKey = opts.itemLabelKey,
        itemOrder = opts.itemOrder
    })
end

E:FlushBossModNoteBlockRegistrations()

function NoteBlock:GetNoteBlockEntry(key)
    return self._noteBlocks[key]
end

local function normalizeTemplate(template)
    if type(template) ~= "string" then
        return ""
    end
    template = template:gsub("\r\n", "\n"):gsub("\r", "\n")
    template = template:gsub("[ \t]+\n", "\n")
    return template:gsub("^\n+", ""):gsub("\n+$", "")
end

function NoteBlock:BuildBlockTemplate(entry, seen)
    if type(entry) ~= "table" then
        return ""
    end

    seen = seen or {}
    if entry.key then
        if seen[entry.key] then
            return ""
        end
        seen[entry.key] = true
    end

    local out = {}
    if entry.entryType == "group" then
        for _, childKey in ipairs(entry.entries or {}) do
            local body = self:BuildBlockTemplate(self:GetNoteBlockEntry(childKey), seen)
            if body ~= "" then
                out[#out + 1] = body
            end
        end
    elseif type(entry.blocks) == "table" then
        for _, b in ipairs(entry.blocks) do
            local tpl = b.template
            if type(tpl) ~= "string" or tpl == "" then
                local tag = b.tag or ""
                tpl = tag .. "Start\n\n" .. tag .. "End"
            end
            tpl = normalizeTemplate(tpl)
            if tpl ~= "" then
                out[#out + 1] = tpl
            end
        end
    end

    local separator = entry.blockSeparator
    if type(separator) ~= "string" then
        separator = "\n\n"
    end
    return table.concat(out, separator)
end

function NoteBlock:GetRegisteredNoteBlocks()
    local out = {}
    for _, key in ipairs(self._noteBlockOrder) do
        local entry = self._noteBlocks[key]
        if entry then
            out[#out + 1] = entry
        end
    end
    local BossMods = E:GetModule("BossMods", true)
    local raidTabs = BossMods and BossMods.raidTabs or nil
    table.sort(out, function(a, b)
        if a.tab ~= b.tab then
            local ta = raidTabs and a.tab and raidTabs:Get(a.tab) or nil
            local tb = raidTabs and b.tab and raidTabs:Get(b.tab) or nil
            local ao = ta and ta.order or 1000
            local bo = tb and tb.order or 1000
            if ao ~= bo then
                return ao < bo
            end
            return tostring(a.tab or "") < tostring(b.tab or "")
        end
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.key < b.key
    end)
    return out
end
