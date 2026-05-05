local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.NoteBlock = BossMods.NoteBlock or {}
local NoteBlock = BossMods.NoteBlock

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
    local t = token:lower()
    ids = ids or self:GetPlayerIdentifiers()
    if t == ids.name or t == ids.full then
        return true
    end
    if ids.nickname and t == ids.nickname then
        return true
    end
    return false
end

function NoteBlock:ResolveTokenToName(token)
    if type(token) ~= "string" or token == "" then
        return nil
    end
    local lower = token:lower()

    local pname = UnitName("player")
    if pname and pname:lower() == lower then
        return pname
    end

    local num = GetNumGroupMembers() or 0
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, num do
        local unit = prefix .. i
        if UnitExists(unit) then
            local n = UnitName(unit)
            if n and n:lower() == lower then
                return n
            end
        end
    end

    if E.GetCharacterInGroup then
        local unit = E:GetCharacterInGroup(token)
        if unit then
            return UnitName(unit)
        end
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
            nameToIndex[n:lower()] = idx
        end
        if E.GetNickname then
            local nick = E:GetNickname(unit)
            if nick and nick ~= "" then
                nameToIndex[nick:lower()] = idx
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
        local raidIdx = nameToIndex[word:lower()]
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

function NoteBlock:GetDisplayName(charName)
    if type(charName) ~= "string" or charName == "" or not E.GetNickname then
        return charName
    end
    local num = GetNumGroupMembers() or 0
    for i = 1, num do
        local unit = "raid" .. i
        if UnitName(unit) == charName then
            local nick = E:GetNickname(unit)
            if nick and nick ~= "" then
                return nick
            end
            return charName
        end
    end
    return charName
end

NoteBlock._noteBlocks = NoteBlock._noteBlocks or {}
NoteBlock._noteBlockOrder = NoteBlock._noteBlockOrder or {}

function NoteBlock:RegisterNoteBlock(key, opts)
    assert(type(key) == "string" and key ~= "", "RegisterNoteBlock: key required")
    assert(type(opts) == "table", "RegisterNoteBlock: opts required")
    assert(type(opts.blocks) == "table" and #opts.blocks > 0,
        "RegisterNoteBlock: opts.blocks must be a non-empty array of {tag, template}")

    if not self._noteBlocks[key] then
        self._noteBlockOrder[#self._noteBlockOrder + 1] = key
    end
    self._noteBlocks[key] = {
        key = key,
        blocks = opts.blocks,
        moduleName = opts.moduleName,
        labelKey = opts.labelKey or key,
        descKey = opts.descKey,
        tab = opts.tab,
        order = opts.order or 100
    }
end

E:FlushBossModNoteBlockRegistrations()

function NoteBlock:GetNoteBlockEntry(key)
    return self._noteBlocks[key]
end

function NoteBlock:BuildBlockTemplate(entry)
    if type(entry) ~= "table" or type(entry.blocks) ~= "table" then
        return ""
    end
    local out = {}
    for _, b in ipairs(entry.blocks) do
        local tpl = b.template
        if type(tpl) ~= "string" or tpl == "" then
            local tag = b.tag or ""
            tpl = tag .. "Start\n\n" .. tag .. "End"
        end
        out[#out + 1] = tpl
    end
    return table.concat(out, "\n\n")
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
