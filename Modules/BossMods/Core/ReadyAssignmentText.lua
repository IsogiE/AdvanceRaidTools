local E, L = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.ReadyAssignmentText = BossMods.ReadyAssignmentText or {}
local Text = BossMods.ReadyAssignmentText

local function loc(key)
    return (L and L[key]) or key
end

local function withNicknames(text)
    if type(text) ~= "string" then
        return text
    end
    if E.SubstituteNicknames then
        return E:SubstituteNicknames(text)
    end
    return text
end

local function ordinal(n)
    n = tonumber(n) or 0
    local mod100 = n % 100
    if mod100 >= 11 and mod100 <= 13 then
        return tostring(n) .. "th"
    end
    local mod10 = n % 10
    if mod10 == 1 then
        return tostring(n) .. "st"
    elseif mod10 == 2 then
        return tostring(n) .. "nd"
    elseif mod10 == 3 then
        return tostring(n) .. "rd"
    end
    return tostring(n) .. "th"
end

local function clampColorChannel(value)
    value = tonumber(value) or 0
    if value < 0 then
        return 0
    elseif value > 1 then
        return 1
    end
    return value
end

local function colorCode(color)
    if type(color) == "string" and color:match("^|c%x%x%x%x%x%x%x%x$") then
        return color
    end
    if type(color) ~= "table" then
        return nil
    end

    local r, g, b = E:ColorTuple(color, 1, 0.82, 0, 1)
    return ("|cff%02x%02x%02x"):format(math.floor(clampColorChannel(r) * 255 + 0.5),
        math.floor(clampColorChannel(g) * 255 + 0.5), math.floor(clampColorChannel(b) * 255 + 0.5))
end

local function highlightValue(value, opts)
    value = tostring(value or "")
    local code = opts and opts.highlightCode
    if not code or value == "" then
        return value
    end
    return code .. value .. "|r"
end

local function fill(template, values, opts)
    if type(template) ~= "string" then
        return nil
    end
    values = values or {}
    return (template:gsub("{([%w_]+):ordinal}", function(key)
        return highlightValue(ordinal(values[key]), opts)
    end):gsub("{([%w_]+)}", function(key)
        local value = values[key]
        if value == nil then
            return ""
        end
        return highlightValue(value, opts)
    end))
end

local function playerList(count, first)
    count = tonumber(count) or 0
    first = tonumber(first) or 1

    local out = {}
    for i = first, first + count - 1 do
        out[#out + 1] = "Player" .. i
    end
    return table.concat(out, " ")
end

local function playerRows(rows)
    if type(rows) == "number" then
        return playerList(rows)
    end
    if type(rows) ~= "table" then
        return ""
    end

    local out = {}
    local first = 1
    for _, count in ipairs(rows) do
        out[#out + 1] = playerList(count, first)
        first = first + count
    end
    return table.concat(out, "\n")
end

local function noteBlockTemplate(tag, lines)
    if type(lines) == "string" then
        lines = {lines}
    end
    return tag .. "Start\n" .. table.concat(lines or {}, "\n") .. "\n" .. tag .. "End"
end

-- =============================================================================
-- Assignment Reminder Registry
-- -----------------------------------------------------------------------------
-- Raid files register their own reminders with Text:Register. The registry,
-- note dropdown templates, and ready-check text/actions all derive from those
-- rows.
--
-- reminders[] = {
--     key        = "luraCrystals",
--     sheet      = "LuraCrystals",        -- optional dropdown/provider group
--     standalone = true,                  -- auto-register from Assignment Reminders
--     labelKey   = "BossMods_LuraCrystals",
--     tab        = "Queldanas",           -- Notes dropdown grouping for standalone sheets
--     order      = 25,
--     source     = "hashtag"|"noteBlock", -- how ReadyAssignments finds the player
--                  "hashtagWord"          -- #tag word action trigger
--     tag        = "lurapickup",          -- hashtag source, without '#'
--     word       = "lura",                -- hashtagWord source
--     noteBlock  = "kick",                -- noteBlock source, matches fooStart/fooEnd
--     type       = "kick",                -- display family for sorting/compat
--     moduleName = "BossMods_Lurakick",   -- optional enabled gate
--     textKey    = "BossMods_AR_TextKick",
--     action     = {                      -- optional ready-check side effect
--         moduleName = "BossMods_LuraMap",
--         method = "ShowReadyAssignments",
--         hideMethod = "HideReadyAssignments",
--         args = {"duration", "visualAnchor"}
--     },
--     priority   = 50,
--     players    = 6,                     -- hashtag: #tag Player1..Player6
--     rows       = {3, 3, 3},             -- noteBlock: Player rows in fooStart/fooEnd
--     values     = {prism = "lineIndex"}, -- text placeholders from reminder fields
--     localeValues = {direction = "Right"} -- localized placeholder values
-- }
-- =============================================================================
local REGISTRY = {
    fallbackKey = "hashtag",
    fallback = {
        key = "hashtag",
        textKey = "BossMods_AR_TextGenericTag",
        values = {
            tag = "tag"
        }
    },
    sheets = {},
    sheetMeta = {}
}

local function prepareReminder(def)
    if type(def) ~= "table" then
        return nil
    end

    if not def.note then
        if def.source == "hashtag" and def.tag and def.players then
            def.note = {
                tag = def.tag,
                template = "#" .. def.tag .. " " .. playerList(def.players)
            }
        elseif def.source == "hashtagWord" and def.tag and def.word then
            def.note = {
                tag = def.tag,
                template = "#" .. def.tag .. " " .. def.word
            }
        elseif def.source == "noteBlock" and def.noteBlock and def.rows then
            def.note = {
                tag = def.noteBlock,
                template = noteBlockTemplate(def.noteBlock, playerRows(def.rows))
            }
        end
    end

    if def.sheet then
        local sheets = type(def.sheet) == "table" and def.sheet or {def.sheet}
        for _, sheet in ipairs(sheets) do
            REGISTRY.sheets[sheet] = REGISTRY.sheets[sheet] or {}
            local found = false
            for _, key in ipairs(REGISTRY.sheets[sheet]) do
                if key == def.key then
                    found = true
                    break
                end
            end
            if not found then
                REGISTRY.sheets[sheet][#REGISTRY.sheets[sheet] + 1] = def.key
            end

            local meta = REGISTRY.sheetMeta[sheet] or {}
            meta.key = sheet
            meta.labelKey = meta.labelKey or def.labelKey
            meta.tab = meta.tab or def.tab
            meta.order = meta.order or def.order
            meta.moduleName = meta.moduleName or def.moduleName
            meta.standalone = meta.standalone or def.standalone
            meta.raidKey = meta.raidKey or def.raidKey or def.tab
            meta.raidLabelKey = meta.raidLabelKey or def.raidLabelKey
            meta.bossKey = meta.bossKey or def.bossKey
            meta.bossLabelKey = meta.bossLabelKey or def.bossLabelKey
            meta.bossOrder = meta.bossOrder or def.bossOrder or def.order
            meta.itemKey = meta.itemKey or def.itemKey or sheet
            meta.itemLabelKey = meta.itemLabelKey or def.itemLabelKey or def.labelKey
            meta.itemOrder = meta.itemOrder or def.itemOrder or def.order
            meta.noteBlockSeparator = meta.noteBlockSeparator or def.noteBlockSeparator or def.blockSeparator
            REGISTRY.sheetMeta[sheet] = meta
        end
    end

    return def
end

Text.REMINDER_TEXT = REGISTRY
Text.definitions = Text.definitions or {}
Text.definitionOrder = Text.definitionOrder or {}

local function copyInto(dst, src)
    if type(src) ~= "table" then
        return dst
    end
    for k, v in pairs(src) do
        dst[k] = v
    end
    return dst
end

function Text:Register(key, opts)
    assert(type(key) == "string" and key ~= "", "ReadyAssignmentText:Register: key required")
    assert(type(opts) == "table", "ReadyAssignmentText:Register: opts required")

    if not self.definitions[key] then
        self.definitionOrder[#self.definitionOrder + 1] = key
    end

    local entry = {}
    copyInto(entry, opts)
    entry.key = key
    prepareReminder(entry)
    self.definitions[key] = entry
    return entry
end

function Text:Get(key, seen)
    if type(key) ~= "string" or key == "" then
        return nil
    end

    local entry = self.definitions[key]
    if not entry then
        return nil
    end

    if not entry.extends then
        return entry
    end

    seen = seen or {}
    if seen[key] then
        return entry
    end
    seen[key] = true

    local parent = self:Get(entry.extends, seen)
    if not parent then
        return entry
    end

    local merged = {}
    copyInto(merged, parent)
    copyInto(merged, entry)
    merged.key = key
    return merged
end

function Text:ResolveKeys(keys)
    if type(keys) == "string" then
        keys = REGISTRY.sheets[keys] or {keys}
    end

    local out = {}
    if type(keys) ~= "table" then
        return out
    end

    for _, key in ipairs(keys) do
        if type(key) == "string" and key ~= "" then
            out[#out + 1] = key
        end
    end
    return out
end

function Text:BuildNoteBlocks(keys)
    local out = {}
    for _, key in ipairs(self:ResolveKeys(keys)) do
        local def = self:Get(key)
        local note = def and def.note
        if note and type(note.template) == "string" and note.template ~= "" then
            out[#out + 1] = {
                tag = note.tag or def.noteBlock or def.tag or key,
                template = note.template
            }
        end
    end
    return out
end

function Text:GetSheets(standaloneOnly)
    local out = {}

    for sheet, keys in pairs(REGISTRY.sheets or {}) do
        local meta = REGISTRY.sheetMeta and REGISTRY.sheetMeta[sheet] or {}
        if type(keys) == "table" and #keys > 0 and (not standaloneOnly or meta.standalone) then
            out[#out + 1] = {
                key = sheet,
                labelKey = meta.labelKey or sheet,
                tab = meta.tab or "General",
                order = meta.order or 100,
                moduleName = meta.moduleName,
                standalone = meta.standalone,
                raidKey = meta.raidKey,
                raidLabelKey = meta.raidLabelKey,
                bossKey = meta.bossKey,
                bossLabelKey = meta.bossLabelKey,
                bossOrder = meta.bossOrder,
                itemKey = meta.itemKey,
                itemLabelKey = meta.itemLabelKey,
                itemOrder = meta.itemOrder,
                noteBlockSeparator = meta.noteBlockSeparator
            }
        end
    end

    table.sort(out, function(a, b)
        if a.tab ~= b.tab then
            return tostring(a.tab or "") < tostring(b.tab or "")
        end
        if a.order ~= b.order then
            return a.order < b.order
        end
        return a.key < b.key
    end)

    return out
end

function Text:GetStandaloneSheets()
    return self:GetSheets(true)
end

function Text:GetDefinitionForReminder(reminder)
    if type(reminder) ~= "table" then
        return nil
    end

    local def = self:Get(reminder.key or reminder.reminderKey)
    if def then
        return def
    end

    if reminder.type == "hashtag" then
        return self:Get(reminder.tag) or self:Get(REGISTRY.fallbackKey)
    end

    return self:Get(reminder.type)
end

function Text:BuildValues(def, reminder)
    local values = {}
    copyInto(values, def.defaultValues)

    if type(def.values) == "function" then
        copyInto(values, def.values(reminder, def))
    elseif type(def.values) == "table" then
        for key, source in pairs(def.values) do
            local value
            if type(source) == "string" then
                value = reminder[source]
                if value == nil then
                    value = def[source]
                end
            else
                value = source
            end
            if value ~= nil then
                values[key] = value
            end
        end
    end

    if type(def.localeValues) == "table" then
        for key, source in pairs(def.localeValues) do
            local value = source
            if type(source) == "string" then
                value = reminder[source]
                if value == nil then
                    value = def[source]
                end
                if value == nil then
                    value = source
                end
            end
            values[key] = loc(value)
        end
    end

    if type(reminder.values) == "table" and reminder.values ~= def.values then
        copyInto(values, reminder.values)
    end
    return values
end

Text:Register(REGISTRY.fallback.key or REGISTRY.fallbackKey, REGISTRY.fallback)

function Text:Compile(reminder, opts)
    if type(reminder) ~= "table" then
        return nil
    end

    if type(reminder.text) == "string" and reminder.text ~= "" then
        return withNicknames(reminder.text)
    end

    local def = self:GetDefinitionForReminder(reminder)
    local fillOpts = {
        highlightCode = colorCode(opts and opts.highlightColor)
    }
    if def and type(def.textKey) == "string" and def.textKey ~= "" then
        return withNicknames(fill(loc(def.textKey), self:BuildValues(def, reminder), fillOpts))
    end

    if type(reminder.textKey) == "string" and reminder.textKey ~= "" then
        return withNicknames(fill(loc(reminder.textKey), self:BuildValues(reminder, reminder), fillOpts))
    end

    return nil
end

function Text:CompileAll(reminders, opts)
    local out = {}
    if type(reminders) ~= "table" then
        return out
    end

    for _, reminder in ipairs(reminders) do
        local line = self:Compile(reminder, opts)
        if line and line ~= "" then
            out[#out + 1] = line
        end
    end

    return out
end
