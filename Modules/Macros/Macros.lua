local E, L = unpack(ART)

local TEXT_LIMIT = 255
local NAME_LIMIT = 16
local DRAFT_NAME_LIMIT = 64
local GENERAL_MACRO_MAX = 120
local CHARACTER_MACRO_MAX = 30
local DEFAULT_MACRO_ICON = "INV_Misc_QuestionMark"

local TYPE_SPELL = "spell"
local TYPE_MARK = "mark"
local TYPE_WORLD = "world"
local TYPE_FOCUS = "focus"
local TYPE_FOCUS_MARK = "focus_mark"
local TYPE_CUSTOM = "custom"

local LINE_PREFIX = "prefix"
local LINE_SUFFIX = "suffix"

local TARGET_MODE_TARGET = "target"
local TARGET_MODE_MOUSEOVER = "mouseover"
local TARGET_MODE_NAME = "name"
local DEFAULT_PI_SLOT_ID = 1
local DEFAULT_INNERVATE_SLOT_ID = 2

local WORLD_MARKER_TO_TARGET_ICON = {
    [1] = 6,
    [2] = 4,
    [3] = 3,
    [4] = 7,
    [5] = 1,
    [6] = 2,
    [7] = 5,
    [8] = 8
}

local DEFAULT_SLOTS = {{
    id = DEFAULT_PI_SLOT_ID,
    name = "Power Infusion",
    macroName = "ART PI",
    type = TYPE_SPELL,
    spell = "Power Infusion",
    targetName = "",
    useMouseover = false,
    useTrinket1 = false,
    useTrinket2 = false,
    customLines = {}
}, {
    id = DEFAULT_INNERVATE_SLOT_ID,
    name = "Innervate",
    macroName = "ART Innervate",
    type = TYPE_SPELL,
    spell = "Innervate",
    targetName = "",
    useMouseover = false,
    useTrinket1 = false,
    useTrinket2 = false,
    customLines = {}
}, {
    id = 3,
    name = "Mark Target",
    macroName = "ART Mark",
    type = TYPE_MARK,
    marker = 8,
    targetMode = TARGET_MODE_MOUSEOVER,
    useMouseover = true,
    customLines = {}
}, {
    id = 4,
    name = "World Marker",
    macroName = "ART World",
    type = TYPE_WORLD,
    marker = 1,
    useCursor = true,
    clearFirst = true,
    customLines = {}
}, {
    id = 5,
    name = "Focus",
    macroName = "ART Focus",
    type = TYPE_FOCUS,
    targetMode = TARGET_MODE_MOUSEOVER,
    useMouseover = true,
    customLines = {}
}}

local DEFAULT_SLOT_BY_ID = {}
for _, slot in ipairs(DEFAULT_SLOTS) do
    DEFAULT_SLOT_BY_ID[slot.id] = slot
end

E:RegisterModuleDefaults("Macros", {
    enabled = true,
    selectedID = 1,
    nextID = 6,
    slots = CopyTable(DEFAULT_SLOTS)
})

local Macros = E:NewModule("Macros", "AceEvent-3.0")
Macros._macroCache = nil
Macros._macroUpdateMutedUntil = nil

Macros.TYPES = {
    SPELL = TYPE_SPELL,
    MARK = TYPE_MARK,
    WORLD = TYPE_WORLD,
    FOCUS = TYPE_FOCUS,
    FOCUS_MARK = TYPE_FOCUS_MARK,
    CUSTOM = TYPE_CUSTOM
}

Macros.LINE_PREFIX = LINE_PREFIX
Macros.LINE_SUFFIX = LINE_SUFFIX
Macros.TARGET_MODE_TARGET = TARGET_MODE_TARGET
Macros.TARGET_MODE_MOUSEOVER = TARGET_MODE_MOUSEOVER
Macros.TARGET_MODE_NAME = TARGET_MODE_NAME

local TARGET_MODES = {
    [TARGET_MODE_TARGET] = true,
    [TARGET_MODE_MOUSEOVER] = true,
    [TARGET_MODE_NAME] = true,
    focus = true,
    player = true,
    pet = true,
    boss1 = true,
    boss2 = true,
    boss3 = true,
    boss4 = true,
    boss5 = true,
    arena1 = true,
    arena2 = true,
    arena3 = true,
    arena4 = true,
    arena5 = true,
    party1 = true,
    party2 = true,
    party3 = true,
    party4 = true
}

local function trim(text)
    text = tostring(text or "")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function clampMarker(marker)
    marker = tonumber(marker) or 1
    if marker < 1 then
        return 1
    end
    if marker > 8 then
        return 8
    end
    return math.floor(marker)
end

local function macroName(text, fallback)
    text = trim(text)
    if text == "" then
        text = fallback or "ART Macro"
    end
    text = text:gsub("[%c]", ""):gsub("%s+", " ")
    if #text > NAME_LIMIT then
        text = trim(text:sub(1, NAME_LIMIT))
    end
    if text == "" then
        text = "ART Macro"
    end
    return text
end

local function macroLookupName(text)
    text = trim(text)
    if text == "" then
        return ""
    end
    text = text:gsub("[%c]", ""):gsub("%s+", " ")
    if #text > NAME_LIMIT then
        text = trim(text:sub(1, NAME_LIMIT))
    end
    return text
end

local function draftName(text, fallback)
    text = trim(text)
    if text == "" then
        text = fallback or L["Macros_DefaultName"] or "Macro"
    end
    text = text:gsub("[%c]", ""):gsub("%s+", " ")
    if #text > DRAFT_NAME_LIMIT then
        text = trim(text:sub(1, DRAFT_NAME_LIMIT))
    end
    if text == "" then
        text = fallback or L["Macros_DefaultName"] or "Macro"
    end
    return text
end

local function targetPlayerName(text)
    text = trim(text)
    if text == "" then
        return ""
    end
    text = text:gsub("[%c]", ""):gsub("%s+", "")
    local name, realm = text:match("^([^%-]+)%-(.+)$")
    if name then
        realm = trim(realm):gsub("%s+", "")
        return realm ~= "" and (name .. "-" .. realm) or name
    end
    return text
end

local function defaultSlotForID(id)
    return DEFAULT_SLOT_BY_ID[tonumber(id)]
end

local function normalizeType(value)
    if value == TYPE_MARK or value == "target_marker" then
        return TYPE_MARK
    end
    if value == TYPE_WORLD or value == "world_marker" then
        return TYPE_WORLD
    end
    if value == TYPE_FOCUS then
        return TYPE_FOCUS
    end
    if value == TYPE_FOCUS_MARK or value == "focus_marker" then
        return TYPE_FOCUS_MARK
    end
    if value == TYPE_CUSTOM then
        return TYPE_CUSTOM
    end
    return TYPE_SPELL
end

local function normalizeLinePosition(value)
    if value == LINE_SUFFIX or value == "after" then
        return LINE_SUFFIX
    end
    return LINE_PREFIX
end

local function normalizeTargetMode(value, useMouseover)
    value = trim(value)
    if value == "" then
        return useMouseover and TARGET_MODE_MOUSEOVER or TARGET_MODE_TARGET
    end
    value = value:lower()
    if TARGET_MODES[value] then
        return value
    end
    return useMouseover and TARGET_MODE_MOUSEOVER or TARGET_MODE_TARGET
end

local function addLine(lines, line)
    line = trim(line)
    if line ~= "" then
        lines[#lines + 1] = line
    end
end

local function addLines(lines, text)
    text = tostring(text or "")
    if text == "" then
        return
    end
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"
    for line in text:gmatch("(.-)\n") do
        addLine(lines, line)
    end
end

local function addCustomLines(lines, slot, position)
    position = normalizeLinePosition(position)
    for _, line in ipairs(slot.customLines or {}) do
        if normalizeLinePosition(line.position) == position then
            addLine(lines, line.text)
        end
    end
end

local function appendCustomLines(out, text, position)
    text = tostring(text or "")
    if text == "" then
        return
    end
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"
    for line in text:gmatch("(.-)\n") do
        local cleaned = trim(line)
        if cleaned ~= "" then
            out[#out + 1] = {
                text = cleaned,
                position = normalizeLinePosition(position)
            }
        end
    end
end

local function normalizeCustomLines(slot)
    local out = {}
    if type(slot.customLines) == "table" then
        for _, entry in ipairs(slot.customLines) do
            if type(entry) == "table" then
                out[#out + 1] = {
                    text = tostring(entry.text or entry.line or entry.value or ""),
                    position = normalizeLinePosition(entry.position or entry.placement or entry.kind)
                }
            elseif type(entry) == "string" then
                out[#out + 1] = {
                    text = entry,
                    position = LINE_PREFIX
                }
            end
        end
    end

    appendCustomLines(out, slot.extraLines or slot.extra or slot.customBefore, LINE_PREFIX)
    appendCustomLines(out, slot.customAfter, LINE_SUFFIX)
    return out
end

local function spellTarget(slot)
    if slot.useMouseover then
        return "[@mouseover,help,nodead][]"
    end
    local targetName = trim(slot.targetName)
    if targetName ~= "" then
        return ("[@%s,help,nodead][]"):format(targetName)
    end
    return ""
end

local function unitTarget(slot)
    local mode = normalizeTargetMode(slot.targetMode, slot.useMouseover)
    if mode == TARGET_MODE_MOUSEOVER then
        return "[@mouseover,exists,nodead][]"
    end
    if mode == TARGET_MODE_NAME then
        local targetName = trim(slot.targetName)
        if targetName ~= "" then
            return ("[@%s,exists,nodead]"):format(targetName)
        end
        mode = TARGET_MODE_TARGET
    end
    return ("[@%s,exists,nodead]"):format(mode)
end

local function isMegaMacroLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MegaMacro")
end

local function getNumMacros()
    if C_Macro and C_Macro.GetNumMacros then
        return C_Macro.GetNumMacros()
    end
    if GetNumMacros then
        return GetNumMacros()
    end
    return 0, 0
end

local function getMacroInfo(indexOrName)
    if C_Macro and C_Macro.GetMacroInfo then
        return C_Macro.GetMacroInfo(indexOrName)
    end
    if GetMacroInfo then
        return GetMacroInfo(indexOrName)
    end
end

local function getMacroIndexByName(name)
    if C_Macro and C_Macro.GetMacroIndexByName then
        return C_Macro.GetMacroIndexByName(name)
    end
    if GetMacroIndexByName then
        return GetMacroIndexByName(name)
    end
end

function Macros:InvalidateMacroCache()
    self._macroCache = nil
end

function Macros:MuteOwnMacroUpdate()
    if GetTime then
        self._macroUpdateMutedUntil = GetTime() + 0.5
    end
end

function Macros:IsOwnMacroUpdateMuted()
    if not (GetTime and self._macroUpdateMutedUntil) then
        return false
    end
    if GetTime() <= self._macroUpdateMutedUntil then
        return true
    end
    self._macroUpdateMutedUntil = nil
    return false
end

function Macros:GetMacroCache()
    if self._macroCache then
        return self._macroCache
    end

    -- Macro slot IDs are sparse, so scan the fixed slot ranges rather than 1..GetNumMacros().
    local cache = {}
    for i = 1, GENERAL_MACRO_MAX do
        local name = getMacroInfo(i)
        if name and name ~= "" then
            cache[name] = {
                index = i,
                scope = "general"
            }
        end
    end

    for i = 1, CHARACTER_MACRO_MAX do
        local index = GENERAL_MACRO_MAX + i
        local name = getMacroInfo(index)
        if name and name ~= "" and not cache[name] then
            cache[name] = {
                index = index,
                scope = "character"
            }
        end
    end

    self._macroCache = cache
    return cache
end

local function editMacro(index, name, icon, text)
    if C_Macro and C_Macro.EditMacro then
        return C_Macro.EditMacro(index, name, icon, text)
    end
    return EditMacro(index, name, icon, text)
end

local function createGeneralMacro(name, icon, text)
    if C_Macro and C_Macro.CreateMacro then
        return C_Macro.CreateMacro(name, icon, text, nil)
    end
    return CreateMacro(name, icon, text, nil)
end

local function deleteMacro(index)
    if C_Macro and C_Macro.DeleteMacro then
        return C_Macro.DeleteMacro(index)
    end
    return DeleteMacro(index)
end

function Macros:GetMarkerIcon(marker)
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. clampMarker(marker)
end

function Macros:GetMarkerIconText(marker)
    return ("|T%s:16:16:0:0:64:64:4:60:4:60|t"):format(self:GetMarkerIcon(marker))
end

function Macros:GetWorldMarkerIcon(marker)
    local iconID = WORLD_MARKER_TO_TARGET_ICON[clampMarker(marker)] or 1
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. iconID
end

function Macros:GetWorldMarkerIconText(marker)
    return ("|T%s:16:16:0:0:64:64:4:60:4:60|t"):format(self:GetWorldMarkerIcon(marker))
end

function Macros:IsMacroManagerBlocked()
    return isMegaMacroLoaded()
end

function Macros:NormalizeSlot(slot, index)
    slot.id = tonumber(slot.id) or index or 1
    local defaultSlot = defaultSlotForID(slot.id)
    if defaultSlot then
        slot.name = defaultSlot.name
        slot.macroName = defaultSlot.macroName
    else
        slot.name = draftName(slot.name or slot.label)
        slot.macroName = macroName(slot.macroName, "ART " .. slot.name)
    end
    slot.type = normalizeType(slot.type or slot.kind)
    slot.spell = trim(slot.spell or slot.spellName)
    if slot.type == TYPE_SPELL and slot.spell == "" then
        slot.spell = "Power Infusion"
    end
    slot.targetName = targetPlayerName(slot.targetName)
    slot.marker = clampMarker(slot.marker)
    local priorMouseover
    if slot.type == TYPE_SPELL then
        priorMouseover = slot.useMouseover
        if priorMouseover == nil then
            priorMouseover = slot.targetMode == TARGET_MODE_MOUSEOVER
        end
        priorMouseover = priorMouseover and true or false
    else
        priorMouseover = slot.useMouseover or slot.targetMode == TARGET_MODE_MOUSEOVER or false
    end
    slot.targetMode = normalizeTargetMode(slot.targetMode, priorMouseover)
    if slot.type == TYPE_SPELL then
        slot.useMouseover = priorMouseover
    else
        slot.useMouseover = slot.targetMode == TARGET_MODE_MOUSEOVER
    end
    slot.useTrinket1 = slot.useTrinket1 and true or false
    slot.useTrinket2 = slot.useTrinket2 and true or false
    slot.useCursor = slot.useCursor ~= false
    slot.clearFirst = slot.clearFirst ~= false
    slot.customLines = normalizeCustomLines(slot)
    slot.extraLines = nil
    slot.body = tostring(slot.body or slot.customBody or "#showtooltip\n")

    slot.label = nil
    slot.kind = nil
    slot.spellName = nil
    slot.extra = nil
    slot.customBefore = nil
    slot.customAfter = nil
    slot.customBody = nil
    return slot
end

local function ensureDefaultSlots(slots)
    local byID = {}
    for _, slot in ipairs(slots) do
        local id = tonumber(slot.id)
        if id then
            byID[id] = slot
        end
    end

    local ordered = {}
    for _, defaultSlot in ipairs(DEFAULT_SLOTS) do
        ordered[#ordered + 1] = byID[defaultSlot.id] or CopyTable(defaultSlot)
    end
    for _, slot in ipairs(slots) do
        if not defaultSlotForID(slot.id) then
            ordered[#ordered + 1] = slot
        end
    end

    wipe(slots)
    for i, slot in ipairs(ordered) do
        slots[i] = slot
    end
end

function Macros:NormalizeDB()
    self.db.slots = type(self.db.slots) == "table" and self.db.slots or CopyTable(DEFAULT_SLOTS)
    if #self.db.slots == 0 then
        self.db.slots = CopyTable(DEFAULT_SLOTS)
    end
    ensureDefaultSlots(self.db.slots)

    local usedIDs, maxID = {}, 0
    for i, slot in ipairs(self.db.slots) do
        self:NormalizeSlot(slot, i)
        while usedIDs[slot.id] do
            slot.id = slot.id + 1
        end
        usedIDs[slot.id] = true
        maxID = math.max(maxID, slot.id)
    end

    self.db.nextID = math.max(tonumber(self.db.nextID) or 1, maxID + 1)
    if not self:GetSlot(self.db.selectedID) then
        self.db.selectedID = self.db.slots[1] and self.db.slots[1].id or nil
    end
end

function Macros:OnInitialize()
    self:NormalizeDB()
end

function Macros:OnEnable()
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    self:RegisterEvent("UPDATE_MACROS", "OnMacrosUpdated")
end

function Macros:OnDisable()
    self:UnregisterAllMessages()
    self:UnregisterAllEvents()
end

function Macros:OnProfileChanged()
    self:InvalidateMacroCache()
    self:NormalizeDB()
    E:SendMessage("ART_MACROS_CHANGED")
end

function Macros:OnMacrosUpdated()
    self:InvalidateMacroCache()
    if self:IsOwnMacroUpdateMuted() then
        return
    end
    E:SendMessage("ART_MACROS_CHANGED")
end

function Macros:GetSlots()
    return self.db.slots
end

function Macros:GetSlot(id)
    id = tonumber(id)
    if not id then
        return nil
    end
    for _, slot in ipairs(self.db.slots or {}) do
        if slot.id == id then
            return slot
        end
    end
end

function Macros:IsDefaultSlot(slotOrID)
    local id = type(slotOrID) == "table" and slotOrID.id or slotOrID
    return defaultSlotForID(id) ~= nil
end

function Macros:GetSelectedSlot()
    return self:GetSlot(self.db.selectedID)
end

function Macros:SelectSlot(id)
    if self:GetSlot(id) then
        self.db.selectedID = tonumber(id)
        E:SendMessage("ART_MACROS_CHANGED")
    end
end

function Macros:IsMacroNameUsed(name, ignoreID)
    name = macroName(name, "")
    ignoreID = tonumber(ignoreID)
    for _, slot in ipairs(self.db.slots or {}) do
        if slot.id ~= ignoreID and macroName(slot.macroName, "") == name then
            return true
        end
    end
    return false
end

function Macros:IsDraftNameUsed(name, ignoreID)
    name = draftName(name, "")
    ignoreID = tonumber(ignoreID)
    for _, slot in ipairs(self.db.slots or {}) do
        if slot.id ~= ignoreID and draftName(slot.name, "") == name then
            return true
        end
    end
    return false
end

function Macros:MakeUniqueMacroName(base, ignoreID)
    base = macroName(base, "ART Macro")
    local candidate, n = base, 2
    while self:IsMacroNameUsed(candidate, ignoreID) do
        local suffix = " " .. n
        candidate = macroName(base:sub(1, NAME_LIMIT - #suffix) .. suffix, "ART Macro")
        n = n + 1
    end
    return candidate
end

function Macros:MakeUniqueDraftName(base, ignoreID)
    base = draftName(base, L["Macros_DefaultName"] or "Macro")
    local candidate, n = base, 2
    while self:IsDraftNameUsed(candidate, ignoreID) do
        local suffix = " " .. n
        candidate = draftName(base:sub(1, DRAFT_NAME_LIMIT - #suffix) .. suffix, L["Macros_DefaultName"] or "Macro")
        n = n + 1
    end
    return candidate
end

function Macros:AddSlot(slotType)
    self:NormalizeDB()
    local id = self.db.nextID
    self.db.nextID = id + 1

    local slot = {
        id = id,
        name = self:MakeUniqueDraftName(L["Macros_DefaultName"] or "Macro", id),
        macroName = self:MakeUniqueMacroName("ART Macro", id),
        type = normalizeType(slotType),
        spell = "Power Infusion",
        targetName = "",
        marker = slotType == TYPE_WORLD and 1 or 8,
        useMouseover = slotType ~= TYPE_SPELL,
        targetMode = slotType ~= TYPE_SPELL and slotType ~= TYPE_WORLD and TARGET_MODE_MOUSEOVER or TARGET_MODE_TARGET,
        useCursor = true,
        clearFirst = true,
        customLines = {},
        body = "#showtooltip\n"
    }
    self:NormalizeSlot(slot, #self.db.slots + 1)
    table.insert(self.db.slots, slot)
    self.db.selectedID = slot.id
    E:SendMessage("ART_MACROS_CHANGED")
end

function Macros:DuplicateSlot(id)
    self:NormalizeDB()
    local source = self:GetSlot(id)
    if not source then
        return
    end
    local slot = CopyTable(source)
    slot.id = self.db.nextID
    self.db.nextID = self.db.nextID + 1
    slot.name = self:MakeUniqueDraftName((slot.name or slot.macroName or "Macro") .. " Copy", slot.id)
    slot.macroName = self:MakeUniqueMacroName(slot.macroName, slot.id)
    table.insert(self.db.slots, slot)
    self.db.selectedID = slot.id
    E:SendMessage("ART_MACROS_CHANGED")
end

function Macros:AddCustomLine(slot, position, silent)
    if not slot then
        return
    end
    self:NormalizeSlot(slot)
    slot.customLines[#slot.customLines + 1] = {
        text = "",
        position = normalizeLinePosition(position)
    }
    if not silent then
        E:SendMessage("ART_MACROS_CHANGED")
    end
end

function Macros:RemoveCustomLine(slot, index, silent)
    if not (slot and slot.customLines) then
        return
    end
    index = tonumber(index)
    if index and slot.customLines[index] then
        table.remove(slot.customLines, index)
        if not silent then
            E:SendMessage("ART_MACROS_CHANGED")
        end
    end
end

function Macros:SetCustomLineText(slot, index, text, silent)
    if not (slot and slot.customLines) then
        return
    end
    index = tonumber(index)
    if index and slot.customLines[index] then
        slot.customLines[index].text = tostring(text or "")
        if not silent then
            E:SendMessage("ART_MACROS_CHANGED")
        end
    end
end

function Macros:SetCustomLinePosition(slot, index, position, silent)
    if not (slot and slot.customLines) then
        return
    end
    index = tonumber(index)
    if index and slot.customLines[index] then
        slot.customLines[index].position = normalizeLinePosition(position)
        if not silent then
            E:SendMessage("ART_MACROS_CHANGED")
        end
    end
end

function Macros:DeleteSlot(id)
    id = tonumber(id)
    if self:IsDefaultSlot(id) then
        return false, "DEFAULT_LOCKED"
    end
    for _, slot in ipairs(self.db.slots or {}) do
        if slot.id == id then
            local function deleteNow()
                local slotIndex, currentSlot
                for i, candidate in ipairs(self.db.slots or {}) do
                    if candidate.id == id then
                        slotIndex, currentSlot = i, candidate
                        break
                    end
                end
                if not currentSlot then
                    return true
                end

                local macroIndex = self:FindMacro(currentSlot.macroName)
                if macroIndex and isMegaMacroLoaded() then
                    return false, "MEGAMACRO_BLOCKED"
                end

                if macroIndex then
                    self:MuteOwnMacroUpdate()
                    local ok, result = pcall(deleteMacro, macroIndex)
                    if not ok then
                        return false, "WRITE_FAILED", result
                    end
                    self:InvalidateMacroCache()
                end

                self:ClearBinding(currentSlot, true)
                table.remove(self.db.slots, slotIndex)
                local nextSlot = self.db.slots[math.min(slotIndex, #self.db.slots)] or self.db.slots[1]
                self.db.selectedID = nextSlot and nextSlot.id or nil
                self:InvalidateMacroCache()
                E:SendMessage("ART_MACROS_CHANGED")
                return true
            end

            if InCombatLockdown and InCombatLockdown() then
                E:RunWhenOutOfCombat("Macros:Delete:" .. slot.id, deleteNow, {
                    alwaysQueue = true
                })
                return true, "QUEUED"
            end
            return deleteNow()
        end
    end
end

function Macros:BuildText(slot)
    if not slot then
        return nil, "NO_SLOT"
    end

    local lines = {}
    if slot.type == TYPE_CUSTOM then
        addLines(lines, slot.body)
    else
        if slot.type == TYPE_SPELL then
            local spell = trim(slot.spell)
            if spell == "" then
                spell = "Power Infusion"
            end
            addLine(lines, "#showtooltip " .. spell)
            addCustomLines(lines, slot, LINE_PREFIX)
            if slot.useTrinket1 then
                addLine(lines, "/use 13")
            end
            if slot.useTrinket2 then
                addLine(lines, "/use 14")
            end
            local target = spellTarget(slot)
            addLine(lines, (target ~= "" and "/cast " .. target .. " " or "/cast ") .. spell)
            addLine(lines, "/cast [@player] " .. spell)
            addCustomLines(lines, slot, LINE_SUFFIX)
        elseif slot.type == TYPE_MARK then
            addCustomLines(lines, slot, LINE_PREFIX)
            addLine(lines, ("/tm %s %d"):format(unitTarget(slot), clampMarker(slot.marker)))
            addCustomLines(lines, slot, LINE_SUFFIX)
        elseif slot.type == TYPE_WORLD then
            local marker = clampMarker(slot.marker)
            addCustomLines(lines, slot, LINE_PREFIX)
            if slot.clearFirst then
                addLine(lines, "/cwm " .. marker)
            end
            addLine(lines, (slot.useCursor and "/wm [@cursor] " or "/wm ") .. marker)
            addCustomLines(lines, slot, LINE_SUFFIX)
        elseif slot.type == TYPE_FOCUS then
            addCustomLines(lines, slot, LINE_PREFIX)
            addLine(lines, "/focus " .. unitTarget(slot))
            addCustomLines(lines, slot, LINE_SUFFIX)
        elseif slot.type == TYPE_FOCUS_MARK then
            local marker = clampMarker(slot.marker)
            addCustomLines(lines, slot, LINE_PREFIX)
            addLine(lines, "/focus " .. unitTarget(slot))
            addLine(lines, "/tm [@focus] " .. marker)
            addCustomLines(lines, slot, LINE_SUFFIX)
        end
    end

    local text = table.concat(lines, "\n")
    if text == "" then
        return nil, "EMPTY"
    end
    if #text > TEXT_LIMIT then
        return text, "TOO_LONG"
    end
    return text
end

function Macros:GetTextLength(slot)
    local text = self:BuildText(slot)
    return #(text or "")
end

function Macros:GetTextLimit()
    return TEXT_LIMIT
end

function Macros:GetNameLimit()
    return NAME_LIMIT
end

function Macros:GetDraftNameLimit()
    return DRAFT_NAME_LIMIT
end

function Macros:NormalizeTargetName(name)
    return targetPlayerName(name)
end

function Macros:GetCurrentTargetName(unit)
    unit = unit or "target"
    if UnitExists and not UnitExists(unit) then
        return nil, "NO_TARGET"
    end
    if UnitIsPlayer and not UnitIsPlayer(unit) then
        return nil, "TARGET_NOT_PLAYER"
    end

    local fullName = targetPlayerName(E:GetUnitFullName(unit, true))
    if fullName == "" then
        return nil, "NO_TARGET"
    end

    local name, realm = fullName:match("^([^%-]+)%-(.+)$")
    if not name then
        return fullName
    end

    local playerRealm = targetPlayerName(E:GetUnitFullName("player", true)):match("^[^%-]+%-(.+)$")
    if realm == "" or realm == playerRealm then
        return name
    end
    return name .. "-" .. realm
end

function Macros:SetDefaultSpellTargetFromUnit(slotID, unit)
    local slot = self:GetSlot(slotID)
    if not (slot and self:IsDefaultSlot(slot) and slot.type == TYPE_SPELL) then
        return false, "NO_SLOT"
    end

    local name, err = self:GetCurrentTargetName(unit or "target")
    if not name then
        return false, err
    end

    slot.targetName = name
    local ok, syncErr, extra = self:SyncSlot(slot, nil, true)
    E:SendMessage("ART_MACROS_CHANGED")
    if not ok then
        return false, syncErr, extra, name
    end
    return true, syncErr, nil, name
end

function Macros:FindMacro(name, scope)
    name = macroLookupName(name)
    if name == "" then
        return nil
    end

    local cached = self:GetMacroCache()[name]
    if cached and (scope ~= "general" or cached.scope == "general") then
        return cached.index, cached.scope
    end

    local index = getMacroIndexByName(name)
    if index and index > 0 then
        local foundScope = index <= GENERAL_MACRO_MAX and "general" or "character"
        if scope ~= "general" or foundScope == "general" then
            if self._macroCache then
                self._macroCache[name] = {
                    index = index,
                    scope = foundScope
                }
            end
            return index, foundScope
        end
    end
end

function Macros:MacroExists(slot)
    return slot and self:FindMacro(slot.macroName, "general") ~= nil
end

function Macros:IconForSlot(slot)
    return DEFAULT_MACRO_ICON
end

local function moveBindings(oldAction, newAction)
    if not oldAction or not newAction or oldAction == newAction then
        return false
    end
    local keys = {}
    while true do
        local key = GetBindingKey(oldAction)
        if not key then
            break
        end
        keys[#keys + 1] = key
        SetBinding(key, nil)
    end
    for _, key in ipairs(keys) do
        SetBinding(key, newAction)
    end
    return #keys > 0
end

function Macros:Write(slot, previousName, silent)
    if not slot then
        return false, "NO_SLOT"
    end
    self:NormalizeSlot(slot)
    if self:IsMacroNameUsed(slot.macroName, slot.id) then
        return false, "NAME_IN_USE"
    end
    if isMegaMacroLoaded() then
        return false, "MEGAMACRO_BLOCKED"
    end

    local text, err = self:BuildText(slot)
    if err then
        return false, err, text
    end

    local queuedWrite = false

    local function writeNow()
        local index = self:FindMacro(slot.macroName, "general")
        local previousIndex, previousScope
        previousName = macroLookupName(previousName)
        if not index and previousName ~= "" and previousName ~= slot.macroName then
            previousIndex, previousScope = self:FindMacro(previousName, "general")
            if not previousIndex then
                previousIndex, previousScope = self:FindMacro(previousName)
            end
        end
        local fallbackIndex, fallbackScope
        if not index and not previousIndex then
            fallbackIndex, fallbackScope = self:FindMacro(slot.macroName)
        end

        local targetIndex = index or (previousScope == "general" and previousIndex) or
                                (fallbackScope == "general" and fallbackIndex)
        local staleIndex = (previousScope == "character" and previousIndex) or
                               (fallbackScope == "character" and fallbackIndex)
        local deletedStale
        local ok, result = pcall(function()
            if targetIndex then
                self:MuteOwnMacroUpdate()
                return editMacro(targetIndex, slot.macroName, self:IconForSlot(slot), text)
            end

            local globalCount = getNumMacros()
            if globalCount and globalCount >= GENERAL_MACRO_MAX then
                error("GENERAL_FULL", 0)
            end

            self:MuteOwnMacroUpdate()
            local createdIndex = createGeneralMacro(slot.macroName, self:IconForSlot(slot), text)
            if staleIndex then
                self:MuteOwnMacroUpdate()
                pcall(deleteMacro, staleIndex)
                deletedStale = true
            end
            return createdIndex
        end)
        if not ok then
            if result == "GENERAL_FULL" then
                return false, "GENERAL_FULL"
            end
            return false, "WRITE_FAILED", result
        end
        if previousName ~= "" and previousName ~= slot.macroName then
            local oldAction = "MACRO " .. previousName
            if moveBindings(oldAction, self:GetBindingAction(slot)) then
                SaveBindings(GetCurrentBindingSet())
            end
        end
        if deletedStale then
            self:InvalidateMacroCache()
        elseif self._macroCache then
            if previousName ~= "" and previousName ~= slot.macroName then
                self._macroCache[previousName] = nil
            end
            local writtenIndex = targetIndex or tonumber(result)
            if writtenIndex and writtenIndex > 0 then
                self._macroCache[slot.macroName] = {
                    index = writtenIndex,
                    scope = writtenIndex <= GENERAL_MACRO_MAX and "general" or "character"
                }
            else
                self:InvalidateMacroCache()
            end
        end
        if not silent or queuedWrite then
            E:SendMessage("ART_MACROS_CHANGED")
        end
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        queuedWrite = true
        E:RunWhenOutOfCombat("Macros:Write:" .. slot.id, writeNow, {
            alwaysQueue = true
        })
        return true, "QUEUED"
    end
    return writeNow()
end

function Macros:SyncSlot(slot, previousName, silent)
    if not slot then
        return false, "NO_SLOT"
    end
    if self:MacroExists(slot) or self:GetBinding(slot) or (previousName and self:FindMacro(previousName)) then
        return self:Write(slot, previousName, silent)
    end
    return true, "SKIPPED"
end

function Macros:GetBindingAction(slot)
    if not slot then
        return nil
    end
    return "MACRO " .. macroName(slot.macroName, "ART Macro")
end

function Macros:GetBinding(slot)
    local action = self:GetBindingAction(slot)
    if not action then
        return nil
    end
    local key1, key2 = GetBindingKey(action)
    if key1 and key2 then
        return key1 .. ", " .. key2
    end
    return key1
end

function Macros:BindingText(slot)
    return self:GetBinding(slot) or L["Macros_Unbound"]
end

local function clearAction(action)
    local changed = false
    while true do
        local key = GetBindingKey(action)
        if not key then
            break
        end
        SetBinding(key, nil)
        changed = true
    end
    return changed
end

function Macros:NormalizeKey(key)
    key = tostring(key or "")
    key = key:gsub("^LCTRL$", "CTRL"):gsub("^RCTRL$", "CTRL")
    key = key:gsub("^LSHIFT$", "SHIFT"):gsub("^RSHIFT$", "SHIFT")
    key = key:gsub("^LALT$", "ALT"):gsub("^RALT$", "ALT")
    key = key:gsub("^LeftButton$", "BUTTON1"):gsub("^RightButton$", "BUTTON2")
    key = key:gsub("^MiddleButton$", "BUTTON3"):gsub("^Button4$", "BUTTON4"):gsub("^Button5$", "BUTTON5")

    if key == "" or key == "CTRL" or key == "SHIFT" or key == "ALT" or key == "UNKNOWN" then
        return nil
    end

    local prefix = ""
    if IsControlKeyDown and IsControlKeyDown() then
        prefix = prefix .. "CTRL-"
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
        prefix = prefix .. "SHIFT-"
    end
    if IsAltKeyDown and IsAltKeyDown() then
        prefix = prefix .. "ALT-"
    end
    if prefix == "" and (key == "BUTTON1" or key == "BUTTON2") then
        return nil
    end
    return prefix .. key
end

function Macros:Bind(slot, key)
    if not slot then
        return false, "NO_SLOT"
    end
    key = trim(key)
    if key == "" then
        return false, "NO_KEY"
    end

    local function bindNow()
        local ok, err, extra = self:Write(slot, nil, true)
        if not ok then
            return false, err, extra
        end
        if err == "QUEUED" then
            return true, "QUEUED"
        end

        local action = self:GetBindingAction(slot)
        local existing = GetBindingAction(key)
        if existing and existing ~= "" and existing ~= action then
            SetBinding(key, nil)
        end
        clearAction(action)
        if not SetBinding(key, action) then
            return false, "BIND_FAILED"
        end
        SaveBindings(GetCurrentBindingSet())
        E:SendMessage("ART_MACROS_CHANGED")
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        E:RunWhenOutOfCombat("Macros:Bind:" .. slot.id, bindNow, {
            alwaysQueue = true
        })
        return true, "QUEUED"
    end
    return bindNow()
end

function Macros:ClearBinding(slot, silent)
    local action = self:GetBindingAction(slot)
    if not action then
        return false
    end
    local function clearNow()
        local changed = clearAction(action)
        if changed then
            SaveBindings(GetCurrentBindingSet())
            if not silent then
                E:SendMessage("ART_MACROS_CHANGED")
            end
        end
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        E:RunWhenOutOfCombat("Macros:Clear:" .. action, clearNow, {
            alwaysQueue = true
        })
        return true, "QUEUED"
    end
    return clearNow()
end
