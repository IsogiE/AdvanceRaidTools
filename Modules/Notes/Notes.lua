local E, L = unpack(ART)

local MAIN_SLOT = 1
local PINNED_PERSONAL_SLOT = 2

local MAX_SLOTS = 20
local DEFAULT_FRAME_W, DEFAULT_FRAME_H = 300, 200
local MIN_FRAME_W, MIN_FRAME_H = 160, 80
local MAX_SPELL_ICON = 40
local DEFAULT_SPELL_ICON = 16

-- Profile defaults

local function makeDefaultSlotDisplay()
    return {
        fontSize = 12,
        fontOutline = "OUTLINE",
        fontName = "PT Sans Narrow",
        spacing = 2,
        backdrop = {
            r = 0,
            g = 0,
            b = 0,
            a = 0.6
        },
        border = {
            r = 0,
            g = 0,
            b = 0,
            a = 1
        },
        -- New slots are ALWAYS unlocked 
        locked = false
    }
end

E:RegisterModuleDefaults("Notes", {
    enabled = true,
    slots = {{
        -- Main's name is empty
        name = "",
        text = "",
        active = true,
        display = {
            fontSize = 12,
            fontOutline = "OUTLINE",
            fontName = "PT Sans Narrow",
            spacing = 2,
            backdrop = {
                r = 0,
                g = 0,
                b = 0,
                a = 0.6
            },
            border = {
                r = 0,
                g = 0,
                b = 0,
                a = 1
            },
            locked = false
        },
        pos = nil -- set on first drag
    }},
    display = {
        -- Per-slot lock lives on slot.display.locked
        strata = "MEDIUM"
    }
})

-- Module
local Notes = E:NewModule("Notes", "AceEvent-3.0")

-- per-session state
Notes.tokens = {} -- ordered list of { pattern, handler }
Notes.frames = {} -- [slotIndex] = frame instance
Notes.processedCache = {} -- [slotIndex] = { key = cacheKey, text = processed }
Notes.renderRevision = 0 -- bumped on anything that invalidates rendered output
Notes.nicknameRevision = 0 -- bumped on ART_NICKNAME_CHANGED
Notes.currentEncounterID = nil
Notes.currentEncounterName = nil
Notes.encounterStartTime = nil
Notes.encounterTicker = nil --
Notes.undoStacks = {} -- [slotIndex] = { previous text, ... } (session-only)
Notes._isResizing = false -- true only while a user is dragging a frame's resize grip
Notes._resizingFrame = nil -- the frame currently being drag-resized; scopes the OnBackdropSizeChanged gate

local GetTime = GetTime
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture or GetSpellTexture
local UnitName = UnitName
local strsplit = strsplit
local strtrim = strtrim
local strlower = string.lower
local gsub = string.gsub
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local wipe = wipe
local tinsert = table.insert
local tremove = table.remove
local max = math.max

-- Utilities

local function normalizeName(s)
    s = E:SafeString(s) or ""
    s = strtrim(E:StripColorCodes(s))
    if s == "" then
        return "", ""
    end
    local lower = strlower(s)
    local bare = strsplit("-", lower)
    return bare, lower
end

local function classTokenMatches(token)
    if not token or token == "" then
        return false
    end
    token = strlower(strtrim(E:StripColorCodes(token)))
    local _, englishClass = UnitClass("player")
    if not englishClass then
        return false
    end
    if strlower(englishClass) == token then
        return true
    end
    local localizedMale = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[englishClass]
    if localizedMale and strlower(localizedMale) == token then
        return true
    end
    local localizedFemale = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[englishClass]
    if localizedFemale and strlower(localizedFemale) == token then
        return true
    end
    return false
end

-- Token registry

function Notes:RegisterToken(pattern, handler)
    assert(type(pattern) == "string" and pattern ~= "", "pattern must be a non-empty string")
    assert(type(handler) == "function", "handler must be a function")
    tinsert(self.tokens, {
        pattern = pattern,
        handler = handler
    })
    self:BumpRenderRevision()
end

function Notes:UnregisterToken(pattern)
    for i = #self.tokens, 1, -1 do
        if self.tokens[i].pattern == pattern then
            tremove(self.tokens, i)
        end
    end
    self:BumpRenderRevision()
end

-- Built-in tokens

local function registerBuiltinTokens()
    -- {spell:ID} / {spell:ID:size}
    Notes:RegisterToken("{spell:(%d+):?(%d*)}", function(idStr, sizeStr)
        local id = tonumber(idStr)
        if not id then
            return ""
        end
        local size = tonumber(sizeStr)
        size = (size and size > 0) and math.min(size, MAX_SPELL_ICON) or DEFAULT_SPELL_ICON
        local tex = GetSpellTexture and GetSpellTexture(id) or nil
        return "|T" .. (tex or [[Interface\Icons\INV_Misc_QuestionMark]]) .. ":" .. size .. "|t"
    end)

    -- {p:name1,name2,...} / {!p:...}
    Notes:RegisterToken("{(!?)p:([^}]+)}([^\n]*)", function(anti, list, rest)
        local meBare, meFull = normalizeName(UnitName("player") or "")
        local meNickBare
        if E.GetNickname then
            local nick = E:GetNickname("player")
            if nick then
                meNickBare = strlower(strtrim(E:StripColorCodes(nick)))
            end
        end
        local found = false
        for candidate in string.gmatch(list, "([^,]+)") do
            local bare, full = normalizeName(candidate)
            if bare == meBare or full == meFull or (meNickBare and bare == meNickBare) then
                found = true
                break
            end
            if not found and E.GetCharacterInGroup then
                local unit = E:GetCharacterInGroup(bare)
                if unit and UnitIsUnit(unit, "player") then
                    found = true
                    break
                end
            end
        end
        if (found and anti == "") or ((not found) and anti == "!") then
            return rest
        end
        return ""
    end)

    -- {class:warrior,mage,...}
    Notes:RegisterToken("{class:([^}]+)}([^\n]*)", function(list, rest)
        for token in string.gmatch(list, "([^,]+)") do
            if classTokenMatches(token) then
                return rest
            end
        end
        return ""
    end)

    -- {time:N}
    Notes:RegisterToken("{time:(%d+)}([^\n]*)", function(secondsStr, rest)
        local seconds = tonumber(secondsStr)
        if not seconds then
            return ""
        end
        local start = Notes.encounterStartTime
        if not start then
            return ""
        end
        if (GetTime() - start) <= seconds then
            return rest
        end
        return ""
    end)

    -- {zone:nameOrID,...}
    Notes:RegisterToken("{zone:([^}]+)}([^\n]*)", function(list, rest)
        local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        local lname = name and strlower(name) or ""
        local idStr = tostring(instanceID or -1)
        for candidate in string.gmatch(list, "([^,]+)") do
            local c = strlower(strtrim(E:StripColorCodes(candidate)))
            if c == lname or c == idStr then
                return rest
            end
        end
        return ""
    end)
end

-- Text processing / cache

function Notes:BumpRenderRevision()
    self.renderRevision = (self.renderRevision or 0) + 1
    wipe(self.processedCache)
end

-- Process the raw text of a slot through the token registry plus nickname substitution
function Notes:ProcessText(slotIndex)
    local slot = self:GetSlot(slotIndex)
    if not slot then
        return ""
    end
    local raw = slot.text or ""
    if raw == "" then
        return ""
    end
    local cacheKey = (self.renderRevision or 0) .. ":" .. (self.nicknameRevision or 0)
    local entry = self.processedCache[slotIndex]
    if entry and entry.key == cacheKey and entry.raw == raw then
        return entry.text
    end

    -- Normalize line endings so the "up to \n" patterns behave consistently
    local text = gsub(raw, "\r\n", "\n")

    for _, token in ipairs(self.tokens) do
        local ok, result = pcall(gsub, text, token.pattern, token.handler)
        if ok and type(result) == "string" then
            text = result
        else
            self:Warn("token %s failed: %s", token.pattern, tostring(result))
        end
    end

    if E.SubstituteNicknames then
        text = E:SubstituteNicknames(text)
    end

    self.processedCache[slotIndex] = {
        key = cacheKey,
        raw = raw,
        text = text
    }
    return text
end

-- Slot management
local function clampIndex(self, index)
    index = tonumber(index)
    if not index then
        return nil
    end
    local slots = self.db and self.db.slots
    if not slots or #slots == 0 then
        return nil
    end
    if index < 1 or index > #slots then
        return nil
    end
    return index
end

function Notes:GetSlot(index)
    index = clampIndex(self, index)
    if not index then
        return nil
    end
    return self.db.slots[index]
end

function Notes:GetSlotCount()
    return self.db and self.db.slots and #self.db.slots or 0
end

function Notes:GetMaxSlots()
    return MAX_SLOTS
end

function Notes:GetSlotName(index)
    local slot = self:GetSlot(index)
    return slot and slot.name or nil
end

function Notes:IsMainSlot(index)
    return clampIndex(self, index) == MAIN_SLOT
end

function Notes:IsPinnedPersonalSlot(index)
    return clampIndex(self, index) == PINNED_PERSONAL_SLOT
end

function Notes:SetSlotName(index, name)
    local slot = self:GetSlot(index)
    if not slot then
        return false
    end
    if self:IsMainSlot(index) or self:IsPinnedPersonalSlot(index) then
        return false
    end
    name = strtrim(tostring(name or ""))
    if name == "" then
        name = L["Notes_DefaultSlotName"] or ("Slot " .. index)
    end
    if slot.name == name then
        return false
    end
    slot.name = name
    E:SendMessage("ART_NOTE_SLOT_RENAMED", index, name)
    self:RefreshFrame(index)
    return true
end

function Notes:GetSlotText(index)
    local slot = self:GetSlot(index)
    return slot and slot.text or ""
end

function Notes:SetSlotText(index, text)
    local slot = self:GetSlot(index)
    if not slot then
        return false
    end
    text = tostring(text or "")
    if slot.text == text then
        return false
    end
    slot.text = text
    self:SyncReadOnlyDB()
    -- Invalidate just this slot's cache entry
    self.processedCache[index] = nil
    E:SendMessage("ART_NOTE_CHANGED", index, text)
    self:RefreshFrame(index)
    return true
end

-- `E:GetNote()` without an explicit slot defaults to Main
function Notes:GetMainSlotIndex()
    return MAIN_SLOT
end

function Notes:AddSlot(name, text)
    if self:GetSlotCount() >= MAX_SLOTS then
        E:Printf(L["Notes_MaxSlotsReached"], MAX_SLOTS)
        return nil
    end

    name = strtrim(tostring(name or ""))
    local slot = {
        name = name,
        text = tostring(text or ""),
        active = false,
        display = makeDefaultSlotDisplay(),
        pos = nil
    }
    tinsert(self.db.slots, slot)
    self:SyncReadOnlyDB()
    self:BumpRenderRevision()
    E:SendMessage("ART_NOTES_LIST_CHANGED")
    return #self.db.slots
end

function Notes:RemoveSlot(index)
    index = clampIndex(self, index)
    if not index then
        return false
    end
    if index == MAIN_SLOT then
        E:Printf(L["Notes_CannotRemove"], L["Notes_MainTag"])
        return false
    end
    if index == PINNED_PERSONAL_SLOT then
        E:Printf(L["Notes_CannotRemove"], L["Notes_PersonalTag"])
        return false
    end
    if self:GetSlotCount() <= 1 then
        return false
    end
    -- Drop any frame bound to this slot before the array shifts
    local frame = self.frames[index]
    if frame then
        frame:Hide()
        self.frames[index] = nil
    end
    tremove(self.db.slots, index)
    -- Shift frame references down for slots after the removed one
    local shifted = {}
    for i, f in pairs(self.frames) do
        if i > index then
            shifted[i - 1] = f
            f.slotIndex = i - 1
        else
            shifted[i] = f
        end
    end
    self.frames = shifted
    self:SyncReadOnlyDB()
    self:BumpRenderRevision()
    E:SendMessage("ART_NOTES_LIST_CHANGED")
    self:RefreshAllFrames()
    return true
end

function Notes:MoveSlot(index, direction)
    index = clampIndex(self, index)
    if not index then
        return false
    end
    -- Main is pinned to index 1, PersonalNote is pinned to index 2
    if index == MAIN_SLOT or index == PINNED_PERSONAL_SLOT then
        return false
    end
    local target = index + (direction < 0 and -1 or 1)
    target = clampIndex(self, target)
    if not target or target == index or target == MAIN_SLOT or target == PINNED_PERSONAL_SLOT then
        return false
    end
    local slots = self.db.slots
    slots[index], slots[target] = slots[target], slots[index]
    -- Frame references follow the slot data
    local a, b = self.frames[index], self.frames[target]
    self.frames[index], self.frames[target] = b, a
    if self.frames[index] then
        self.frames[index].slotIndex = index
    end
    if self.frames[target] then
        self.frames[target].slotIndex = target
    end
    self:SyncReadOnlyDB()
    self:BumpRenderRevision()
    E:SendMessage("ART_NOTES_LIST_CHANGED")
    return true
end

function Notes:IsSlotPersonal(index)
    index = clampIndex(self, index)
    if not index then
        return false
    end
    return index ~= MAIN_SLOT
end

function Notes:IsSlotActive(index)
    local slot = self:GetSlot(index)
    return slot and slot.active or false
end

function Notes:SetSlotActive(index, active)
    local slot = self:GetSlot(index)
    if not slot then
        return false
    end
    active = active and true or false
    if slot.active == active then
        return false
    end
    slot.active = active
    self:RefreshAllFrames()
    E:SendMessage("ART_NOTE_SLOT_ACTIVE_CHANGED", index, active)
    return true
end

-- Undo stack

local UNDO_DEBOUNCE = 1.0 -- seconds between distinct undo entries for a slot
local UNDO_LIMIT = 20

function Notes:PushUndo(index, previousText)
    index = clampIndex(self, index)
    if not index then
        return
    end
    self.undoStacks[index] = self.undoStacks[index] or {}
    local stack = self.undoStacks[index]
    local now = GetTime()
    local last = stack[#stack]
    if last and last.text == previousText then
        last.ts = now
        return
    end

    if last and (now - last.ts) < UNDO_DEBOUNCE then
        last.ts = now
        return
    end
    tinsert(stack, {
        text = previousText or "",
        ts = now
    })
    while #stack > UNDO_LIMIT do
        tremove(stack, 1)
    end
end

function Notes:CanUndo(index)
    index = clampIndex(self, index)
    if not index then
        return false
    end
    local stack = self.undoStacks[index]
    return stack and #stack > 0 or false
end

function Notes:Undo(index)
    index = clampIndex(self, index)
    if not index then
        return false
    end
    local stack = self.undoStacks[index]
    if not stack or #stack == 0 then
        return false
    end
    local entry = tremove(stack)
    -- Apply via the raw set path so we don't push back onto the stack
    local slot = self:GetSlot(index)
    if slot then
        slot.text = entry.text or ""
        self:SyncReadOnlyDB()
        self.processedCache[index] = nil
        E:SendMessage("ART_NOTE_CHANGED", index, slot.text)
        self:RefreshFrame(index)
    end
    return true
end

-- Send / receive

local NOTE_COMM_PREFIX = "ART_NOTE"

function Notes:CanSend(index)
    index = clampIndex(self, index or MAIN_SLOT)
    if not index then
        return false, "NO_SLOT"
    end

    -- Only Main is broadcastable
    if index ~= MAIN_SLOT then
        return false, "PERSONAL"
    end

    if not IsInGroup() then
        return false, "NOT_IN_GROUP"
    end

    if not E:HasBroadcastAuthority(UnitName("player") or "") then
        return false, "NOT_AUTHORIZED"
    end

    local slot = self:GetSlot(index)
    if not slot or not slot.text or slot.text == "" then
        return false, "EMPTY"
    end
    return true
end

function Notes:SendSlot(index)
    index = clampIndex(self, index or MAIN_SLOT)
    if not index then
        return false
    end
    local ok, reason = self:CanSend(index)
    if not ok then
        if reason == "NOT_IN_GROUP" then
            E:Printf(L["NotInGroup"])
        elseif reason == "PERSONAL" then
            E:Printf(L["Notes_SendPersonal"])
        elseif reason == "EMPTY" then
            E:Printf(L["Notes_SendEmpty"])
        elseif reason == "NOT_AUTHORIZED" then
            E:Printf(L["Notes_SendNotAuthorized"])
        end
        return false
    end
    local slot = self:GetSlot(index)
    local payload = {
        name = slot.name or "",
        text = slot.text or ""
    }
    -- Don't infer success from CallModule's return value 
    if not E:GetEnabledModule("Comms") then
        E:Printf(L["Notes_SendFailed"])
        return false
    end
    E:CallModule("Comms", "SendPayload", NOTE_COMM_PREFIX, payload)
    return true
end

function Notes:OnNoteReceive(prefix, message, distribution, sender)
    if not self:IsEnabled() then
        return
    end
    local Comms = E:GetModule("Comms", true)
    if not Comms or not Comms.DecodePayload then
        return
    end
    local data = Comms:DecodePayload(message)
    if type(data) ~= "table" or type(data.text) ~= "string" then
        return
    end
    self:SetSlotText(MAIN_SLOT, data.text)
    E:SendMessage("ART_NOTE_RECEIVED", MAIN_SLOT, sender, data.name)
end

-- Combat tracking

function Notes:IsWithinEncounterTime(seconds)
    if not self.encounterStartTime then
        return false
    end
    return (GetTime() - self.encounterStartTime) <= seconds
end

function Notes:AnyVisibleSlotUsesTime()
    for i = 1, self:GetSlotCount() do
        if self:ShouldSlotBeVisible(i) then
            local slot = self.db.slots[i]
            if slot and slot.text and slot.text:find("{time:%d+}") then
                return true
            end
        end
    end
    return false
end

function Notes:StartEncounterTicker()
    if self.encounterTicker then
        return
    end
    if not self:AnyVisibleSlotUsesTime() then
        return
    end
    self.encounterTicker = C_Timer.NewTicker(0.5, function()
        if not self.encounterStartTime then
            return
        end
        wipe(self.processedCache)
        self:RefreshAllFrames()
    end)
end

function Notes:StopEncounterTicker()
    if self.encounterTicker then
        self.encounterTicker:Cancel()
        self.encounterTicker = nil
    end
end

function Notes:OnEncounterStart(_, encounterID, encounterName, difficultyID, groupSize)
    self.currentEncounterID = encounterID
    self.currentEncounterName = encounterName
    self.encounterStartTime = GetTime()
    self:BumpRenderRevision()
    E:SendMessage("ART_NOTE_ENCOUNTER_START", encounterID, encounterName, difficultyID, groupSize)
    self:RefreshAllFrames()
    self:StartEncounterTicker()
end

function Notes:OnEncounterEnd(_, encounterID, encounterName, difficultyID, groupSize, success)
    self:StopEncounterTicker()
    self.encounterStartTime = nil
    self.currentEncounterID = nil
    self.currentEncounterName = nil
    self:BumpRenderRevision()
    E:SendMessage("ART_NOTE_ENCOUNTER_END", encounterID, success == 1 or success == true)
    self:RefreshAllFrames()
end

function Notes:OnNicknameChanged()
    self.nicknameRevision = (self.nicknameRevision or 0) + 1
    self:BumpRenderRevision()
    self:RefreshAllFrames()
end

function Notes:OnZoneChanged()
    self:BumpRenderRevision()
    self:RefreshAllFrames()
end

-- Display frames

local function applyFontToText(fs, display)
    local outline = display.fontOutline
    if outline == "NONE" then
        outline = ""
    end
    fs:SetFont(E:FetchFont(display.fontName), display.fontSize or 12, outline or "OUTLINE")
    fs:SetSpacing(display.spacing or 2)
end

local function applyBackdropColors(frame, display)
    if not frame.SetBackdropColor then
        return
    end
    local bg = display.backdrop or {
        r = 0,
        g = 0,
        b = 0,
        a = 0.6
    }
    local br = display.border or {
        r = 0,
        g = 0,
        b = 0,
        a = 1
    }
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    frame:SetBackdropBorderColor(br.r, br.g, br.b, br.a)
end

local function savePosition(frame)
    local slot = Notes:GetSlot(frame.slotIndex)
    if not slot then
        return
    end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    slot.pos = {
        point = point,
        relPoint = relPoint,
        x = x,
        y = y,
        w = frame:GetWidth(),
        h = frame:GetHeight()
    }
end

-- first display offset for pinned frames that have no saved position
local FIRST_DISPLAY_OFFSET_X = 20
local FIRST_DISPLAY_OFFSET_Y = -20

local function assignStaggeredSpawn(slotIndex)
    -- How many frames already own a saved position? Offset by that count
    local count = 0
    for i = 1, Notes:GetSlotCount() do
        local s = Notes.db.slots[i]
        if s and s.pos and i ~= slotIndex then
            count = count + 1
        end
    end
    return count * FIRST_DISPLAY_OFFSET_X, count * FIRST_DISPLAY_OFFSET_Y
end

local function restorePosition(frame)
    local slot = Notes:GetSlot(frame.slotIndex)
    local pos = slot and slot.pos
    frame:ClearAllPoints()
    if pos and pos.point then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        frame:SetSize(pos.w or DEFAULT_FRAME_W, pos.h or DEFAULT_FRAME_H)
    else
        local dx, dy = assignStaggeredSpawn(frame.slotIndex)
        frame:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
        frame:SetSize(DEFAULT_FRAME_W, DEFAULT_FRAME_H)
    end
end

-- each slot owns its own `locked` flag on slot.display
local function isFrameLocked(frame)
    if not frame then
        return false
    end
    local slot = Notes:GetSlot(frame.slotIndex)
    return slot and slot.display and slot.display.locked or false
end

-- RegisterForDrag + OnDragStart/OnDragStop
local function onFrameDragStart(self)
    if isFrameLocked(self) then
        return
    end
    self:StartMoving()
end

local function onFrameDragStop(self)
    self:StopMovingOrSizing()
    savePosition(self)
end

local CHILD_ANCHORS = {
    scroll = {{"TOPLEFT", 4, -20}, {"BOTTOMRIGHT", -4, 4}},
    grip = {{"BOTTOMRIGHT", -1, 1}},
    lockToggle = {{"TOPRIGHT", -1, -1}}
}

-- Re-anchor a child frame to a new target without changing its parent
local function reanchorChild(child, target, anchors)
    if not child then
        return
    end
    child:ClearAllPoints()
    for _, a in ipairs(anchors) do
        child:SetPoint(a[1], target, a[1], a[2], a[3])
    end
end

-- ghost-preview resize, lil performance fix attempt
local function getResizeGhost()
    local ghost = Notes._resizeGhost
    if ghost then
        return ghost
    end
    ghost = CreateFrame("Frame", "ARTNotesResizeGhost", UIParent)
    ghost:SetFrameStrata("BACKGROUND")
    ghost:SetResizable(true)
    ghost:Hide()
    local fill = ghost:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    ghost.fill = fill
    ghost.edges = {}
    local function makeEdge(p1, p2, vertical)
        local t = ghost:CreateTexture(nil, "BORDER")
        t:SetPoint(p1)
        t:SetPoint(p2)
        if vertical then
            t:SetWidth(1)
        else
            t:SetHeight(1)
        end
        tinsert(ghost.edges, t)
    end
    makeEdge("TOPLEFT", "TOPRIGHT", false)
    makeEdge("BOTTOMLEFT", "BOTTOMRIGHT", false)
    makeEdge("TOPLEFT", "BOTTOMLEFT", true)
    makeEdge("TOPRIGHT", "BOTTOMRIGHT", true)
    Notes._resizeGhost = ghost
    return ghost
end

local function applyGhostColors(ghost, display)
    local bg = (display and display.backdrop) or {
        r = 0,
        g = 0,
        b = 0,
        a = 0.6
    }
    local br = (display and display.border) or {
        r = 0,
        g = 0,
        b = 0,
        a = 1
    }
    ghost.fill:SetColorTexture(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.6)
    for _, edge in ipairs(ghost.edges) do
        edge:SetColorTexture(br.r or 0, br.g or 0, br.b or 0, br.a or 1)
    end
end

local function onGripDragStart(self)
    local parent = self:GetParent()
    if isFrameLocked(parent) then
        return
    end
    Notes._isResizing = true
    Notes._resizingFrame = parent
    -- parent frame stays at its current size for the entire drag

    local ghost = getResizeGhost()
    local slot = Notes:GetSlot(parent.slotIndex)
    applyGhostColors(ghost, slot and slot.display)
    local point, relFrame, relPoint, x, y = parent:GetPoint(1)
    ghost:ClearAllPoints()
    ghost:SetPoint(point, relFrame or UIParent, relPoint or point, x or 0, y or 0)
    ghost:SetSize(parent:GetWidth(), parent:GetHeight())
    if ghost.SetResizeBounds then
        ghost:SetResizeBounds(MIN_FRAME_W, MIN_FRAME_H)
    end
    ghost:Show()
    reanchorChild(parent.scroll, ghost, CHILD_ANCHORS.scroll)
    reanchorChild(parent.grip, ghost, CHILD_ANCHORS.grip)
    reanchorChild(parent.lockToggle, ghost, CHILD_ANCHORS.lockToggle)
    parent:SetBackdropColor(0, 0, 0, 0)
    parent:SetBackdropBorderColor(0, 0, 0, 0)
    ghost:StartSizing("BOTTOMRIGHT")
end

local function onGripDragStop(self)
    local parent = self:GetParent()
    local slotIndex = parent.slotIndex
    local ghost = Notes._resizeGhost
    local newW, newH, newPoint, newRelFrame, newRelPoint, newX, newY
    if ghost and ghost:IsShown() then
        ghost:StopMovingOrSizing()
        newW, newH = ghost:GetWidth(), ghost:GetHeight()
        -- Capture the ghost's final anchor too
        newPoint, newRelFrame, newRelPoint, newX, newY = ghost:GetPoint(1)
    end
    Notes._isResizing = false
    Notes._resizingFrame = nil
    -- Re-anchor chrome back to parent
    reanchorChild(parent.scroll, parent, CHILD_ANCHORS.scroll)
    reanchorChild(parent.grip, parent, CHILD_ANCHORS.grip)
    reanchorChild(parent.lockToggle, parent, CHILD_ANCHORS.lockToggle)
    if ghost then
        ghost:Hide()
    end
    -- Flush
    if newPoint and newW and newH then
        parent:ClearAllPoints()
        parent:SetPoint(newPoint, newRelFrame or UIParent, newRelPoint or newPoint, newX or 0, newY or 0)
        parent:SetSize(newW, newH)
    end
    if parent.ApplyBackdrop then
        parent:ApplyBackdrop()
    end
    if slotIndex then
        Notes:RefreshFrame(slotIndex)
    end
    savePosition(parent)
end

-- Apply the current locked state to one frame
local function applyLockState(frame)
    if not frame then
        return
    end
    local locked = isFrameLocked(frame)
    frame:EnableMouse(not locked)
    if locked then
        if frame.lockToggle then
            frame.lockToggle:Hide()
        end
        if frame.grip then
            frame.grip:Hide()
        end
        return
    end
    if frame.lockToggle then
        frame.lockToggle:Show()
    end
    if frame.grip then
        frame.grip:Show()
    end
end

-- Build a full display frame for a single slot
function Notes:BuildFrame(slotIndex)
    local existing = self.frames[slotIndex]
    if existing then
        return existing
    end

    local slot = self:GetSlot(slotIndex)
    local frame = CreateFrame("Frame", "ARTNotesFrame" .. slotIndex, UIParent, "BackdropTemplate")
    frame.slotIndex = slotIndex
    frame:SetFrameStrata(self.db.display.strata or "MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_FRAME_W, MIN_FRAME_H)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_FRAME_W, MIN_FRAME_H)
    end
    -- frame drag. When locked, applyLockState calls EnableMouse(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", onFrameDragStart)
    frame:SetScript("OnDragStop", onFrameDragStop)
    E:SetTemplate(frame, "Default")
    local origOnBackdropSizeChanged = frame.OnBackdropSizeChanged
    if origOnBackdropSizeChanged then
        frame.OnBackdropSizeChanged = function(self_, w, h)
            if Notes._isResizing and Notes._resizingFrame == self_ then
                return
            end
            origOnBackdropSizeChanged(self_, w, h)
        end
    end
    applyBackdropColors(frame, slot and slot.display or {})

    -- Scrolling text body
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 4, -20)
    scroll:SetPoint("BOTTOMRIGHT", -4, 4)
    scroll:EnableMouse(false)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self_, delta)
        local cur = self_:GetVerticalScroll()
        local child = self_:GetScrollChild()
        local maxY = child and max(0, child:GetHeight() - self_:GetHeight()) or 0
        local new = cur - delta * 20
        if new < 0 then
            new = 0
        end
        if new > maxY then
            new = maxY
        end
        self_:SetVerticalScroll(new)
    end)
    frame.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    content:EnableMouse(false)
    scroll:SetScrollChild(content)
    frame.content = content

    local textFS = content:CreateFontString(nil, "OVERLAY")
    textFS:SetPoint("TOPLEFT", 2, -2)
    textFS:SetPoint("TOPRIGHT", -2, -2)
    textFS:SetJustifyH("LEFT")
    textFS:SetJustifyV("TOP")
    textFS:SetWordWrap(true)
    applyFontToText(textFS, (slot and slot.display) or makeDefaultSlotDisplay())
    frame.textFS = textFS

    -- Resize grip
    local grip = CreateFrame("Frame", nil, frame)
    grip:SetSize(12, 12)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", onGripDragStart)
    grip:SetScript("OnDragStop", onGripDragStop)
    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetColorTexture(1, 1, 1, 0.25)
    grip.tex = gripTex
    grip:Hide()
    frame.grip = grip

    -- Lock toggle button
    local lockBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    E:SetTemplate(lockBtn, "Default")
    lockBtn:SetSize(16, 16)
    lockBtn:SetPoint("TOPRIGHT", -1, -1)
    lockBtn:SetFrameLevel(frame:GetFrameLevel() + 5)
    local lockGlyph = lockBtn:CreateFontString(nil, "OVERLAY")
    E:RegisterFontString(lockGlyph, 0)
    lockGlyph:SetPoint("CENTER", 0, 0)
    lockGlyph:SetText("L") -- simple glyph; avoids dependency on a lock icon asset
    lockBtn:SetScript("OnClick", function()
        Notes:SetSlotLocked(frame.slotIndex, true)
    end)
    lockBtn:SetScript("OnEnter", function(self_)
        GameTooltip:SetOwner(self_, "ANCHOR_LEFT")
        GameTooltip:SetText(L["Notes_LockFrame"], 1, 1, 1)
        GameTooltip:AddLine(L["Notes_LockFrameDesc"], nil, nil, nil, true)
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", GameTooltip_Hide)
    lockBtn:Hide()
    frame.lockToggle = lockBtn

    frame.artOnMediaUpdate = function(self_)
        local s = Notes:GetSlot(self_.slotIndex)
        applyBackdropColors(self_, (s and s.display) or {})
    end

    restorePosition(frame)
    applyLockState(frame)
    self.frames[slotIndex] = frame
    return frame
end

function Notes:GetFrame(slotIndex)
    return self.frames[slotIndex]
end

function Notes:RefreshFrame(slotIndex)
    local frame = self.frames[slotIndex]
    if not frame then
        return
    end
    local slot = self:GetSlot(slotIndex)
    if not slot then
        frame:Hide()
        return
    end
    local display = slot.display or makeDefaultSlotDisplay()
    applyFontToText(frame.textFS, display)
    applyBackdropColors(frame, display)
    -- Lock state owns grip/lockToggle visibility.
    applyLockState(frame)

    local processed = self:ProcessText(slotIndex)
    frame.textFS:SetText(processed)
    -- After setting text, size the scroll child to fit
    local w = frame.scroll:GetWidth()
    if w and w > 0 then
        frame.content:SetWidth(w)
    end
    local h = max(frame.textFS:GetStringHeight() or 0, frame.scroll:GetHeight() or 0)
    frame.content:SetHeight(h)
    frame.scroll:UpdateScrollChildRect()
end

-- Per slot lock
function Notes:SetSlotLocked(index, locked)
    local slot = self:GetSlot(index)
    if not slot then
        return false
    end
    slot.display = slot.display or makeDefaultSlotDisplay()
    locked = locked and true or false
    if slot.display.locked == locked then
        return false
    end
    slot.display.locked = locked
    local frame = self.frames[index]
    if frame then
        applyLockState(frame)
    end
    E:SendMessage("ART_NOTES_LOCK_CHANGED", index, locked)
    return true
end

function Notes:IsSlotLocked(index)
    local slot = self:GetSlot(index)
    return slot and slot.display and slot.display.locked or false
end

-- Visibility
function Notes:ShouldSlotBeVisible(slotIndex)
    if not self:IsEnabled() then
        return false
    end
    local slot = self:GetSlot(slotIndex)
    if not slot then
        return false
    end
    return slot.active and true or false
end

function Notes:RefreshAllFrames()
    if not self.db or not self.db.slots then
        return
    end
    for i = 1, self:GetSlotCount() do
        if self:ShouldSlotBeVisible(i) then
            local frame = self:BuildFrame(i)
            frame:Show()
            self:RefreshFrame(i)
        else
            local frame = self.frames[i]
            if frame then
                frame:Hide()
            end
        end
    end
end

function Notes:HideAllFrames()
    for _, frame in pairs(self.frames) do
        if frame and frame.Hide then
            frame:Hide()
        end
    end
end

local readOnlyDB = E:CreateReadOnlyProxy("ART_NotesDB is read-only; use E:SetNote or ART:SetNote to write.")

function Notes:SyncReadOnlyDB()
    wipe(readOnlyDB)
    if not self.db or not self.db.slots then
        return
    end
    for i, slot in ipairs(self.db.slots) do
        rawset(readOnlyDB, i, slot.text or "")
    end
end

-- Expose
_G.ART = _G.ART or {}
_G.ART_NotesDB = readOnlyDB

local function notesLive()
    return Notes.db and Notes:IsEnabled() and true or false
end

E:MountMethods(_G.ART, {
    GetNote = function(_, index)
        if not notesLive() then
            return ""
        end
        return Notes:ProcessText(index or MAIN_SLOT) or ""
    end,
    GetRawNote = function(_, index)
        if not notesLive() then
            return ""
        end
        return Notes:GetSlotText(index or MAIN_SLOT) or ""
    end,
    GetMainNoteSlot = function()
        return MAIN_SLOT
    end,
    GetPersonalNote = function(_, personalIndex)
        if not notesLive() then
            return ""
        end
        personalIndex = tonumber(personalIndex) or 0
        if personalIndex < 1 then
            return ""
        end
        return Notes:ProcessText(personalIndex + 1) or ""
    end,
    GetPersonalNoteCount = function()
        if not notesLive() then
            return 0
        end
        return math.max(0, Notes:GetSlotCount() - 1)
    end,
    GetNoteSlotName = function(_, index)
        if not notesLive() then
            return ""
        end
        return Notes:GetSlotName(index) or ""
    end
}, {
    noClobber = true
})

-- Internal calls
function Notes:Publish()
    self._eHandle = E:MountMethods(E, {
        GetNote = function(_, index)
            return Notes:ProcessText(index or MAIN_SLOT)
        end,
        GetRawNote = function(_, index)
            return Notes:GetSlotText(index or MAIN_SLOT)
        end,
        SetNote = function(_, index, text)
            return Notes:SetSlotText(index, text)
        end,
        GetNoteSlotName = function(_, index)
            return Notes:GetSlotName(index)
        end,
        GetMainNoteSlot = function()
            return MAIN_SLOT
        end,
        GetPersonalNoteCount = function()
            return math.max(0, Notes:GetSlotCount() - 1)
        end
    })
end

function Notes:Unpublish()
    if self._eHandle then
        self._eHandle:Unmount();
        self._eHandle = nil
    end
    wipe(readOnlyDB)
end

-- MRT read

function Notes:IsMRTLoaded()
    return type(_G.VMRT) == "table" and type(_G.VMRT.Note) == "table"
end

function Notes:GetMRTNote()
    if not self:IsMRTLoaded() then
        return nil
    end
    return _G.VMRT.Note.Text1
end

function Notes:ImportFromMRT(slotIndex)
    if not self:IsMRTLoaded() then
        E:Printf(L["Notes_MRTNotLoaded"])
        return false
    end
    local text = _G.VMRT.Note.Text1
    if type(text) ~= "string" or text == "" then
        E:Printf(L["Notes_MRTEmpty"])
        return false
    end
    slotIndex = clampIndex(self, slotIndex) or MAIN_SLOT
    if not self:GetSlot(slotIndex) then
        return false
    end
    self:SetSlotText(slotIndex, text)
    return true
end

-- Lifecycle

local function normalizeSlots(db)
    db.slots = db.slots or {}
    if #db.slots == 0 then
        tinsert(db.slots, {
            name = "",
            text = "",
            active = true,
            display = makeDefaultSlotDisplay()
        })
    end
    if #db.slots < 2 then
        tinsert(db.slots, {
            name = "",
            text = "",
            active = false,
            display = makeDefaultSlotDisplay()
        })
    end
    for i, slot in ipairs(db.slots) do
        -- Drop obsolete fields from earlier versions so they don't leak
        slot.personal = nil
        slot.boss = nil
        slot.hidden = nil
        if slot.display then
            slot.display.title = nil
        end
        -- Rename pinned -> active when migrating older profiles
        if slot.pinned ~= nil then
            slot.active = slot.active or (slot.pinned and true or false)
            slot.pinned = nil
        end
        if i == MAIN_SLOT then
            slot.name = ""
            if slot.active == nil then
                slot.active = true
            end
        elseif i == PINNED_PERSONAL_SLOT then
            slot.name = ""
            slot.active = slot.active and true or false
        else
            slot.active = slot.active and true or false
        end
        slot.display = slot.display or makeDefaultSlotDisplay()
        local defaults = makeDefaultSlotDisplay()
        for k, v in pairs(defaults) do
            if slot.display[k] == nil then
                slot.display[k] = v
            end
        end
    end
end

function Notes:OnInitialize(db)
    db.display = db.display or {
        strata = "MEDIUM"
    }
    -- If an older profile had db.display.locked, propagate it to every slot's display
    local legacyLocked = db.display.locked
    normalizeSlots(db)
    if legacyLocked ~= nil then
        for _, slot in ipairs(db.slots) do
            if slot.display.locked == nil then
                slot.display.locked = legacyLocked and true or false
            end
        end
    end
    if db.display.strata == nil then
        db.display.strata = "MEDIUM"
    end
    -- Drop stale top-level display keys left over from the old schema
    db.display.locked = nil
    db.display.fontSize = nil
    db.display.fontOutline = nil
    db.display.fontName = nil
    db.display.spacing = nil
    db.display.backdrop = nil
    db.display.border = nil
    db.display.title = nil
    db.active = nil
    db.mrt = nil
end

function Notes:OnEnable()
    if #self.tokens == 0 then
        registerBuiltinTokens()
    end

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneChanged")

    self:RegisterMessage("ART_NICKNAME_CHANGED", "OnNicknameChanged")

    E:CallModule("Comms", "RegisterAuthorizedProtocol", NOTE_COMM_PREFIX, {
        OnCommReceived = function(_, prefix, msg, distribution, sender)
            Notes:OnNoteReceive(prefix, msg, distribution, sender)
        end
    })

    self:SyncReadOnlyDB()
    self:Publish()
    self:BumpRenderRevision()
    self:RefreshAllFrames()

    C_Timer.After(0, function()
        Notes:ReplaySlotStates()
    end)
end

function Notes:ReplaySlotStates()
    if not self.db or not self.db.slots then
        return
    end
    for i, slot in ipairs(self.db.slots) do
        E:SendMessage("ART_NOTE_CHANGED", i, slot.text or "")
    end
end

function Notes:OnDisable()
    self:UnregisterAllEvents()
    self:StopEncounterTicker()
    self:HideAllFrames()
    self:Unpublish()
    E:CallModule("Comms", "UnregisterProtocol", NOTE_COMM_PREFIX)
    -- Keep the token registry intact across disable/re-enable
end

function Notes:OnProfileChanged()
    wipe(self.processedCache)
    wipe(self.undoStacks)
    self:StopEncounterTicker()
    self.encounterStartTime = nil

    if self.db then
        normalizeSlots(self.db)
    end

    if not self:IsEnabled() then
        return
    end

    for _, frame in pairs(self.frames) do
        if frame and frame.Hide then
            frame:Hide()
        end
    end
    self.frames = {}

    self:SyncReadOnlyDB()
    self:BumpRenderRevision()
    self:RefreshAllFrames()
end

-- register on the module, not on E
Notes:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
