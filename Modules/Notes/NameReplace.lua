local E = unpack(ART)
local Notes = E:GetModule("Notes")

local function plainName(value)
    return strtrim((value or ""):gsub("|+c%x%x%x%x%x%x%x%x", ""):gsub("|+r", ""))
end

local function shortName(value)
    return plainName(value):match("^[^-]+") or ""
end

local function targetsFor(query)
    local key = shortName(query):lower()
    local targets = {[key] = true}
    local nicknames = E:GetModule("Nicknames", true)
    local map = nicknames and nicknames.db and nicknames.db.map or {}
    local alias = key
    for character, nickname in pairs(map) do
        if shortName(character):lower() == key then alias = nickname:lower(); break end
    end
    targets[alias] = true
    for character, nickname in pairs(map) do
        if nickname:lower() == alias then targets[shortName(character):lower()] = true end
    end
    return targets
end

local function replacementName(value)
    value = plainName(value)
    local nicknames = E:GetModule("Nicknames", true)
    if nicknames and nicknames.GetCharacterInGroup then
        for _, nickname in pairs(nicknames.db.map or {}) do
            if nickname:lower() == value:lower() then
                local unit = nicknames:GetCharacterInGroup(nickname)
                if unit then return E:GetUnitFullName(unit, true) or value end
            end
        end
    end
    return value
end

function Notes:ReplacePlayerNames(source, query, replacement)
    source = source or ""
    query = plainName(query)
    if query == "" then return source, 0 end
    local targets, count = targetsFor(query), 0
    local replaceWith = replacement ~= nil and replacementName(replacement) or nil
    if replaceWith and (replaceWith == "" or not replaceWith:match("^[%w_\128-\255%-]+$")) then return source, 0 end
    local function replaceWord(word)
        if targets[shortName(word):lower()] then
            count = count + 1
            return replaceWith or word
        end
        return word
    end
    local parts, position = {}, 1
    local function matchAt(pattern)
        local first, last = source:find(pattern, position)
        if first == position then return source:sub(first, last) end
    end
    while position <= #source do
        local token = matchAt("^|+T.-|+t") or matchAt("^|+A.-|+a")
            or matchAt("^|+H.-|+h.-|+h") or matchAt("^|+c%x%x%x%x%x%x%x%x") or matchAt("^|+r")
            or matchAt("^#[%w_\128-\255%-]+")
        if token then
            parts[#parts + 1] = token
        elseif source:sub(position, position) == "{" then
            token = matchAt("^%b{}")
            if token then
                local prefix, names = token:match("^({!?[Pp]:)(.-)}$")
                parts[#parts + 1] = prefix and (prefix .. names:gsub("[%w_\128-\255][%w_\128-\255%-]*", replaceWord) .. "}") or token
            end
        end
        if not token then
            token = matchAt("^[%w_\128-\255][%w_\128-\255%-]*")
            if token then parts[#parts + 1] = replaceWord(token)
            else token = matchAt("^[^%w_\128-\255{|#]+") or source:sub(position, position); parts[#parts + 1] = token end
        end
        position = position + #token
    end
    return table.concat(parts), count
end

function Notes:ReplacePlayerInSlot(index, query, replacement)
    local slot = self:GetSlot(index)
    if not slot then return 0 end
    local original = slot.text or ""
    local updated, count = self:ReplacePlayerNames(original, query, replacement)
    if count == 0 or updated == original then return 0 end
    self:PushUndo(index, original, true)
    self:SetSlotText(index, updated)
    return count
end
