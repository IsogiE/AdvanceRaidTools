local E, L = unpack(ART)
local T = E.Templates

local RaidGroups = E:GetModule("RaidGroups", true)
if not RaidGroups then
    return
end

ART.RaidGroupsEditor = RaidGroups

local strtrim = strtrim
local strmatch = string.match
local strgmatch = string.gmatch
local strformat = string.format
local tinsert = table.insert
local tconcat = table.concat

-- Read the shared constants 
local GROUP_COUNT = RaidGroups.GROUP_COUNT
local SLOTS_PER_GROUP = RaidGroups.SLOTS_PER_GROUP
local SLOT_W = RaidGroups.SLOT_W
local SLOT_H = RaidGroups.SLOT_H
local SLOT_GAP = RaidGroups.SLOT_GAP
local NAME_ROW_H = RaidGroups.NAME_ROW_H
local EDITOR_W = RaidGroups.EDITOR_W
local EDITOR_H = RaidGroups.EDITOR_H
local classColor = RaidGroups.classColor
local colorize = RaidGroups.colorize
local stripColor = RaidGroups.stripColor

-- Editor-only
local function cursorOver(frame, mx, my)
    if not frame or not frame:IsShown() then
        return false
    end
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (l and r and t and b) then
        return false
    end
    mx = mx or (select(1, GetCursorPosition()) / frame:GetEffectiveScale())
    my = my or (select(2, GetCursorPosition()) / frame:GetEffectiveScale())
    return mx >= l and mx <= r and my >= b and my <= t
end

local function ensureDragContainer(self)
    if self._dragContainer then
        return self._dragContainer
    end
    local c = CreateFrame("Frame", nil, UIParent)
    c:SetAllPoints(UIParent)
    c:SetFrameStrata("TOOLTIP")
    self._dragContainer = c
    return c
end

local function getDragPreview(self)
    if self._dragPreview then
        return self._dragPreview
    end
    local parent = ensureDragContainer(self)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(SLOT_W, SLOT_H)
    E:SetTemplate(f, "Default")
    E:SetSolidBackdrop(f)
    -- Keep the accent-colored border during drag; opt out of the auto reskin
    f.artSkipAutoBorder = true
    f:SetBackdropBorderColor(unpack(E.media.valueColor))
    f:SetFrameStrata("TOOLTIP")
    f.text = E:CreateFontString(f, nil, "OVERLAY")
    f.text:SetPoint("CENTER")
    f:EnableMouse(false)
    f:Hide()
    self._dragPreview = f
    return f
end

local function startDragPreview(self, text, r, g, b)
    local p = getDragPreview(self)
    p.text:SetText(text or "")
    p.text:SetTextColor(r or 1, g or 1, b or 1)
    p:ClearAllPoints()
    p:SetScript("OnUpdate", function(frame)
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / scale, cy / scale)
    end)
    p:Show()
end

local function stopDragPreview(self)
    if self._dragPreview then
        self._dragPreview:SetScript("OnUpdate", nil)
        self._dragPreview:Hide()
    end
end

local function clearAllEditFocus(editor)
    local focus = GetCurrentKeyBoardFocus()
    if focus and focus.ClearFocus then
        focus:ClearFocus()
    end
    if editor._slots then
        for _, group in ipairs(editor._slots) do
            for _, eb in ipairs(group) do
                eb:ClearFocus()
            end
        end
    end
end

local function setSlotValue(self, eb, name)
    name = name and strtrim(name) or ""
    if name == "" then
        eb:SetText("")
        eb.usedName = nil
        return
    end
    local class = E:GetClassByName(name)
    local r, g, b = classColor(class)
    local display = self:DisplayName(name)
    eb:SetText(colorize(display, r, g, b))
    eb:SetCursorPosition(0)
    eb.usedName = name -- always the real name; display is cosmetic
end

function RaidGroups:FindSlotUnderCursor()
    if not self._editor or not self._slots then
        return nil
    end
    local scale = self._editor:GetEffectiveScale()
    local mx, my = GetCursorPosition()
    mx, my = mx / scale, my / scale
    for _, group in ipairs(self._slots) do
        for _, eb in ipairs(group) do
            local container = eb._container
            if container and cursorOver(container, mx, my) then
                return eb
            end
        end
    end
end

local sharedSlotEditBox

local function applyEditBoxFont(eb)
    local size = (E.media.normFontSize or 12) - 2
    local outline = E.media.normFontOutline or "OUTLINE"
    if outline == "NONE" then
        outline = ""
    end
    eb:SetFont(E.media.normFont, size, outline)
end

local function getSharedSlotEditBox()
    if sharedSlotEditBox then
        return sharedSlotEditBox
    end

    local eb = CreateFrame("EditBox", nil, UIParent)
    eb:SetAutoFocus(false)
    applyEditBoxFont(eb)
    eb:SetJustifyH("LEFT")
    eb:SetMaxLetters(24)
    eb:Hide()

    eb:SetScript("OnEscapePressed", function(self_)
        self_:ClearFocus()
    end)
    eb:SetScript("OnEnterPressed", function(self_)
        self_:ClearFocus()
    end)

    eb:SetScript("OnEditFocusLost", function(self_)
        local slot = self_._activeSlot
        self_._activeSlot = nil
        self_:Hide()
        if slot and slot._label then
            slot._label:Show()
        end
        if slot then
            local plain = strtrim(self_:GetText() or "")
            if plain == "" then
                slot._label:SetText("")
                slot.usedName = nil
            else
                local real = RaidGroups:ResolveNickname(plain)
                setSlotValue(RaidGroups, slot, real)
            end
            RaidGroups:PopulateNameList()
            RaidGroups:UpdateSlotTints()
        end
    end)

    sharedSlotEditBox = eb
    return eb
end

local function activateSlotEdit(slot)
    local eb = getSharedSlotEditBox()

    -- Commit any pending edit on a different slot first
    if eb._activeSlot and eb._activeSlot ~= slot then
        eb:ClearFocus()
    end

    eb:ClearAllPoints()
    eb:SetParent(slot)
    eb:SetPoint("TOPLEFT", slot, "TOPLEFT", 4, -2)
    eb:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -4, 2)
    eb:SetFrameLevel(slot:GetFrameLevel() + 5)
    eb._activeSlot = slot

    if slot._label then
        slot._label:Hide()
    end

    eb:SetText(slot.usedName or "")
    eb:Show()
    eb:SetFocus()
end

local function createSlotEditBox(self, parent, group, slot)
    local container = CreateFrame("Button", nil, parent, "BackdropTemplate")
    container:SetSize(SLOT_W, SLOT_H)
    E:SetTemplate(container, "Default")
    E:SetSolidBackdrop(container)
    container:RegisterForClicks("LeftButtonUp")

    local label = E:CreateFontString(container, nil, "OVERLAY", (E.media.normFontSize or 12) - 2)
    label:SetPoint("TOPLEFT", 4, -2)
    label:SetPoint("BOTTOMRIGHT", -4, 2)
    label:SetJustifyH("LEFT")
    container._label = label

    container._container = container
    container._group = group
    container._slot = slot
    container.usedName = nil

    function container:SetText(text)
        self._label:SetText(text or "")
    end
    function container:GetText()
        return self._label:GetText() or ""
    end
    function container:SetCursorPosition()
    end
    function container:ClearFocus()
        if sharedSlotEditBox and sharedSlotEditBox._activeSlot == self then
            sharedSlotEditBox:ClearFocus()
        end
    end
    function container:HasFocus()
        return sharedSlotEditBox and sharedSlotEditBox._activeSlot == self and sharedSlotEditBox:HasFocus() or false
    end

    container:SetScript("OnClick", function(self_)
        activateSlotEdit(self_)
    end)

    -- Drag handling
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(self_)
        if not self_.usedName or self_.usedName == "" then
            return
        end
        clearAllEditFocus(RaidGroups._editor)
        local class = E:GetClassByName(self_.usedName)
        local r, g, b = classColor(class)
        self_._dragging = true
        startDragPreview(RaidGroups, self_.usedName, r, g, b)
    end)

    container:SetScript("OnDragStop", function(self_)
        if not self_._dragging then
            return
        end
        self_._dragging = nil
        stopDragPreview(RaidGroups)

        local srcName = self_.usedName
        if not srcName then
            return
        end

        local target = RaidGroups:FindSlotUnderCursor()
        if target and target ~= self_ then
            local targetName = target.usedName
            if targetName and targetName ~= "" then
                setSlotValue(RaidGroups, self_, targetName)
                setSlotValue(RaidGroups, target, srcName)
            else
                setSlotValue(RaidGroups, target, srcName)
                setSlotValue(RaidGroups, self_, "")
            end
        elseif RaidGroups._nameListFrame and cursorOver(RaidGroups._nameListFrame) then
            setSlotValue(RaidGroups, self_, "")
        end

        RaidGroups:PopulateNameList()
        RaidGroups:UpdateSlotTints()
    end)

    return container, container
end

local function createNameRow(self, parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(NAME_ROW_H)
    if not row.SetBackdrop then
        Mixin(row, BackdropTemplateMixin)
    end

    E:SetTemplate(row, "Default")
    row:SetBackdropColor(0, 0, 0, 0.25)
    row:SetBackdropBorderColor(unpack(E.media.borderColor))
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")

    local label = E:CreateFontString(row, nil, "OVERLAY")
    label:SetPoint("LEFT", 4, 0)
    label:SetPoint("RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    row._label = label

    row:SetScript("OnEnter", function(self_)
        if not self_._dragging then
            self_:SetBackdropBorderColor(unpack(E.media.valueColor))
        end
    end)
    row:SetScript("OnLeave", function(self_)
        if not self_._dragging then
            self_:SetBackdropBorderColor(unpack(E.media.borderColor))
        end
    end)

    row:SetScript("OnDragStart", function(self_)
        if not self_._playerName or self_._playerName == "" then
            return
        end
        self_._dragging = true
        self_:SetAlpha(0.35)
        startDragPreview(RaidGroups, RaidGroups:DisplayName(self_._playerName), self_._r, self_._g, self_._b)
    end)

    row:SetScript("OnDragStop", function(self_)
        if not self_._dragging then
            return
        end
        self_._dragging = nil
        self_:SetAlpha(1)
        stopDragPreview(RaidGroups)

        local target = RaidGroups:FindSlotUnderCursor()
        if target and self_._playerName then
            setSlotValue(RaidGroups, target, self_._playerName)
        end
        RaidGroups:PopulateNameList()
        RaidGroups:UpdateSlotTints()
    end)

    row:SetScript("OnHide", function(self_)
        if self_._dragging then
            self_._dragging = nil
            self_:SetAlpha(1)
            stopDragPreview(RaidGroups)
        end
    end)

    return row
end

function RaidGroups:EnsureVisibleRowCapacity(capacity)
    self._visibleRows = self._visibleRows or {}
    local content = self._nameListContent
    if not content then
        return
    end
    for i = #self._visibleRows + 1, capacity do
        self._visibleRows[i] = createNameRow(self, content)
    end
end

function RaidGroups:GetUsedSlotNames()
    local used = {}
    if not self._slots then
        return used
    end
    for _, group in ipairs(self._slots) do
        for _, eb in ipairs(group) do
            if eb.usedName and eb.usedName ~= "" then
                used[E:NormalizeName(eb.usedName)] = true
            end
        end
    end
    return used
end

function RaidGroups:BuildAvailableList()
    if not self._editor then
        return {}
    end
    local source = self._editor._listSource
    if not source then
        return {}
    end

    local realm = GetNormalizedRealmName()
    local all = {}

    if source == "raid" and (IsInRaid() or IsInGroup()) then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, class, _, _, _, _, _, _, server = GetRaidRosterInfo(i)
            if name then
                local display = (server and server ~= "" and server ~= realm) and (name .. "-" .. server) or name
                tinsert(all, {
                    name = display,
                    class = class,
                    order = i
                })
            end
        end
    elseif source == "guild" then
        for _, entry in ipairs(E:GetGuildCache() or {}) do
            tinsert(all, {
                name = entry.name,
                class = entry.class,
                order = entry.rank
            })
        end
    end

    local used = self:GetUsedSlotNames()
    local out = {}
    for _, p in ipairs(all) do
        if not used[E:NormalizeName(p.name)] then
            tinsert(out, p)
        end
    end
    return out
end

function RaidGroups:RefreshVisibleRows()
    local scroll = self._nameListScroll
    local content = self._nameListContent
    if not scroll or not content then
        return
    end

    local list = self._nameList or {}
    content:SetHeight(math.max(1, #list * NAME_ROW_H))

    -- Nothing to show. Hide any existing rows and bail before creating more
    if #list == 0 then
        if self._visibleRows then
            for _, row in ipairs(self._visibleRows) do
                row:Hide()
            end
        end
        return
    end

    local viewH = scroll:GetHeight()
    if not viewH or viewH <= 0 then
        return
    end
    local offset = scroll:GetVerticalScroll() or 0
    local capacity = math.ceil(viewH / NAME_ROW_H) + 2

    self:EnsureVisibleRowCapacity(capacity)

    local firstIdx = math.max(1, math.floor(offset / NAME_ROW_H) + 1)

    for i, row in ipairs(self._visibleRows) do
        local idx = firstIdx + i - 1
        local player = list[idx]
        if player then
            if row._dragging then
                -- Don't mess a row that's mid-drag, leave it alone
                row:Show()
            else
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(idx - 1) * NAME_ROW_H)
                row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                row._playerName = player.name
                local r, g, b = classColor(player.class)
                row._r, row._g, row._b = r, g, b
                row._label:SetText(self:DisplayName(player.name))
                row._label:SetTextColor(r, g, b)
                row:SetAlpha(1)
                row:Show()
            end
        else
            row:Hide()
        end
    end
end

-- Size the available-list frame to fit its content
function RaidGroups:UpdateNameListHeight()
    local frame = self._nameListFrame
    local leftCol = self._nameListLeftCol
    local header = self._nameListHeader
    if not (frame and leftCol and header) then
        return
    end
    local rows = #(self._nameList or {})
    local desired = rows * NAME_ROW_H + 8

    local headerBottom = header:GetBottom()
    local colBottom = leftCol:GetBottom()
    local maxH = (headerBottom and colBottom) and math.max(NAME_ROW_H * 3 + 8, headerBottom - colBottom - 4) or 300
    frame:SetHeight(math.min(math.max(NAME_ROW_H + 8, desired), maxH))
end

function RaidGroups:RefreshListScrollbar()
    local sf = self._nameListSF
    if not sf or not sf.scrollbar or not sf.scrollbar.frame then
        return
    end
    local content = sf.content
    local scroll = sf.scroll
    if not content or not scroll then
        return
    end
    local contentH = content:GetHeight() or 0
    local viewportH = scroll:GetHeight() or 0
    self._nameListScrollbarShouldShow = (contentH - viewportH) > 0.5
    if self._nameListScrollbarShouldShow then
        if sf.scrollbar.Refresh then
            sf.scrollbar.Refresh()
        end
    else
        sf.scrollbar.frame:Hide()
    end
end

function RaidGroups:PopulateNameList()
    self._nameList = self:BuildAvailableList()
    self:UpdateNameListHeight()
    self:RefreshVisibleRows()
    self:RefreshListScrollbar()
end

local TINT_DEFAULT = {0.07, 0.07, 0.07, 1.0}
local TINT_MISSING = {0.55, 0.15, 0.15, 0.8}
local TINT_EXTRA = {0.55, 0.50, 0.10, 0.8}

function RaidGroups:UpdateSlotTints()
    if not self._slots then
        return
    end
    if not (IsInRaid() or IsInGroup()) then
        for _, group in ipairs(self._slots) do
            for _, eb in ipairs(group) do
                eb._container:SetBackdropColor(unpack(TINT_DEFAULT))
            end
        end
        return
    end

    local realm = GetNormalizedRealmName()
    local inGroup, subs = {}, {}
    for i = 1, GetNumGroupMembers() do
        local name, _, subgroup, _, _, _, _, _, _, _, _, _, server = GetRaidRosterInfo(i)
        if name then
            local display = (server and server ~= "" and server ~= realm) and (name .. "-" .. server) or name
            inGroup[display] = true
            subs[display] = subgroup
        end
    end

    for _, group in ipairs(self._slots) do
        for _, eb in ipairs(group) do
            local name = eb.usedName
            if name and name ~= "" then
                if not inGroup[name] then
                    eb._container:SetBackdropColor(unpack(TINT_MISSING))
                elseif subs[name] and subs[name] >= 7 then
                    eb._container:SetBackdropColor(unpack(TINT_EXTRA))
                else
                    eb._container:SetBackdropColor(unpack(TINT_DEFAULT))
                end
            else
                eb._container:SetBackdropColor(unpack(TINT_DEFAULT))
            end
        end
    end
end

function RaidGroups:ClearSlots()
    if not self._slots then
        return
    end
    for _, group in ipairs(self._slots) do
        for _, eb in ipairs(group) do
            eb:SetText("")
            eb.usedName = nil
            eb._container:SetBackdropColor(unpack(TINT_DEFAULT))
        end
    end
    self:PopulateNameList()
end

function RaidGroups:ImportRosterToSlots()
    if not self._slots then
        return
    end
    self:ClearSlots()
    if not (IsInRaid() or IsInGroup()) then
        E:Printf(L["RG_NotInRaid"])
        return
    end
    local realm = GetNormalizedRealmName()
    local byGroup = {}
    for i = 1, GetNumGroupMembers() do
        local name, _, subgroup, _, _, class, _, _, _, _, _, _, server = GetRaidRosterInfo(i)
        if name and subgroup and subgroup <= GROUP_COUNT then
            byGroup[subgroup] = byGroup[subgroup] or {}
            local display = (server and server ~= "" and server ~= realm) and (name .. "-" .. server) or name
            tinsert(byGroup[subgroup], {
                name = display,
                class = class
            })
        end
    end
    for g = 1, GROUP_COUNT do
        local entries = byGroup[g] or {}
        for s = 1, SLOTS_PER_GROUP do
            local eb = self._slots[g][s]
            local entry = entries[s]
            if entry then
                setSlotValue(self, eb, entry.name)
            end
        end
    end
    self:PopulateNameList()
    self:UpdateSlotTints()
end

function RaidGroups:ApplyFromEditor()
    if not self._slots then
        return
    end
    local list = {}
    local counts = {}
    for g = 1, GROUP_COUNT do
        for s = 1, SLOTS_PER_GROUP do
            local eb = self._slots[g][s]
            local name = eb.usedName or ""
            list[(g - 1) * SLOTS_PER_GROUP + s] = name
            if name ~= "" then
                if counts[name] then
                    E:Printf(L["RG_DuplicateOnApply"], name)
                    return
                end
                counts[name] = 1
            end
        end
    end
    self:ApplyGroups(list)
end

function RaidGroups:GetRosterExportString()
    if not (IsInRaid() or IsInGroup()) then
        return ""
    end
    local realm = GetNormalizedRealmName()
    local out = {}
    for i = 1, GetNumGroupMembers() do
        local name = GetRaidRosterInfo(i)
        if name then
            local base, server = strmatch(name, "^(.-)%-(.+)$")
            if not base then
                base, server = name, realm
            end
            tinsert(out, base .. "-" .. (server or realm))
        end
    end
    return tconcat(out, "\n")
end

function RaidGroups:LoadPresetIntoSlots(dataString)
    if not self._slots or not dataString then
        return
    end
    self:ClearSlots()
    for part in strgmatch(dataString, "Group%d+:%s*[^;]+") do
        local gnum, namesStr = strmatch(part, "Group(%d+):%s*(.*)")
        gnum = tonumber(gnum)
        if gnum and self._slots[gnum] then
            local names = {}
            for n in strgmatch(namesStr, "([^,]+)") do
                tinsert(names, strtrim(n))
            end
            for s = 1, SLOTS_PER_GROUP do
                local eb = self._slots[gnum][s]
                local name = names[s]
                if name and name ~= "" then
                    setSlotValue(self, eb, name)
                end
            end
        end
    end
    self:PopulateNameList()
    self:UpdateSlotTints()
end

function RaidGroups:SaveCurrentSlotsAsPreset(name)
    name = name and strtrim(name) or ""
    if name == "" then
        return false, L["RG_ErrorNameEmpty"]
    end
    -- check if any slot has data
    local hasData = false
    for _, group in ipairs(self._slots) do
        for _, eb in ipairs(group) do
            if eb.usedName and eb.usedName ~= "" then
                hasData = true
                break
            end
        end
        if hasData then
            break
        end
    end
    if not hasData then
        return false, L["RG_EmptyPreset"]
    end
    local data = self:SerializeSlots(self._slots)
    return self:SavePreset(name, data)
end

function RaidGroups:BuildEditor()
    if self._editor then
        return self._editor
    end

    local f = CreateFrame("Frame", "ART_RaidGroupsEditor", UIParent, "BackdropTemplate")
    f:SetSize(EDITOR_W, EDITOR_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    E:SetTemplate(f, "Default")
    E:SetSolidBackdrop(f)
    tinsert(UISpecialFrames, "ART_RaidGroupsEditor")
    self._editor = f

    -- Title
    local title = E:CreateFontString(f, nil, "OVERLAY", (E.media.normFontSize or 12) + 4)
    title:SetPoint("TOP", f, "TOP", 0, -8)
    title:SetText(L["RaidGroups"])
    E:RegisterAccentText(title)

    local close = T:CloseButton(f, {
        size = 20,
        tooltip = L["Close"]
    })
    close.frame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local leftW = 220
    local leftCol = CreateFrame("Frame", nil, f)
    leftCol:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    leftCol:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 60)
    leftCol:SetWidth(leftW)

    local srcHeader = T:Label(leftCol, {
        text = L["RG_Source"]
    })
    srcHeader.frame:SetPoint("TOPLEFT", leftCol, "TOPLEFT", 0, 0)

    local raidChk = T:Checkbox(leftCol, {
        text = L["Raid"],
        onChange = function(_, checked)
            if checked then
                f._guildChk.SetChecked(false)
                f._listSource = "raid"
            else
                f._listSource = nil
            end
            if RaidGroups._nameListFrame then
                RaidGroups._nameListFrame:SetShown(f._listSource ~= nil)
            end
            if RaidGroups._nameListScroll then
                RaidGroups._nameListScroll:SetVerticalScroll(0)
            end
            RaidGroups:PopulateNameList()
        end
    })
    raidChk.frame:SetPoint("TOPLEFT", srcHeader.frame, "BOTTOMLEFT", 0, -4)

    local guildChk = T:Checkbox(leftCol, {
        text = L["Guild"],
        onChange = function(_, checked)
            if checked then
                f._raidChk.SetChecked(false)
                f._listSource = "guild"
                E:EnsureGuildCache()
            else
                f._listSource = nil
            end
            if RaidGroups._nameListFrame then
                RaidGroups._nameListFrame:SetShown(f._listSource ~= nil)
            end
            if RaidGroups._nameListScroll then
                RaidGroups._nameListScroll:SetVerticalScroll(0)
            end
            RaidGroups:PopulateNameList()
        end
    })
    guildChk.frame:SetPoint("LEFT", raidChk.frame, "RIGHT", 10, 0)

    f._raidChk, f._guildChk = raidChk, guildChk

    local listHeader = T:Label(leftCol, {
        text = L["RG_AvailableNames"]
    })
    listHeader.frame:SetPoint("TOPLEFT", raidChk.frame, "BOTTOMLEFT", 0, -10)

    local listSF = T:ScrollFrame(leftCol, {
        template = "Default",
        insets = {4, 4, 4, 4},
        mouseWheelStep = NAME_ROW_H
    })

    listSF.frame:SetPoint("TOPLEFT", listHeader.frame, "BOTTOMLEFT", 0, -4)
    listSF.frame:SetWidth(leftW)
    self._nameListFrame = listSF.frame
    self._nameListLeftCol = leftCol
    self._nameListHeader = listHeader.frame
    self._nameListSF = listSF
    self._nameListScrollbarShouldShow = false

    if listSF.scrollbar and listSF.scrollbar.frame then
        hooksecurefunc(listSF.scrollbar.frame, "Show", function(barFrame)
            if not RaidGroups._nameListScrollbarShouldShow then
                barFrame:Hide()
            end
        end)
    end

    local scroll = listSF.scroll
    local refreshPending = false
    scroll:HookScript("OnVerticalScroll", function()
        if refreshPending then
            return
        end
        refreshPending = true
        C_Timer.After(0.05, function()
            refreshPending = false
            RaidGroups:RefreshVisibleRows()
        end)
    end)
    -- Hide the whole listSF frame until source picked
    listSF.frame:Hide()
    self._nameListScroll = scroll

    local content = listSF.content
    content:SetSize(leftW - 32, 1)
    self._nameListContent = content

    -- 8 groups of 5 slots
    local centreX = 10 + leftW + 14
    local centreW = SLOT_W * SLOTS_PER_GROUP + (SLOTS_PER_GROUP - 1) * SLOT_GAP + 40
    local centreCol = CreateFrame("Frame", nil, f)
    centreCol:SetPoint("TOPLEFT", f, "TOPLEFT", centreX, -40)
    centreCol:SetSize(centreW, 500)

    self._slots = {}
    for g = 1, GROUP_COUNT do
        local rowY = -(g - 1) * (SLOT_H + 14)
        local label = E:CreateFontString(centreCol, nil, "OVERLAY")
        label:SetPoint("TOPLEFT", centreCol, "TOPLEFT", -3, rowY)
        label:SetText(strformat(L["RG_GroupN"], g))
        E:RegisterAccentText(label)

        self._slots[g] = {}
        for s = 1, SLOTS_PER_GROUP do
            local eb, container = createSlotEditBox(self, centreCol, g, s)
            container:SetPoint("TOPLEFT", centreCol, "TOPLEFT", 50 + (s - 1) * (SLOT_W + SLOT_GAP), rowY - 2)
            self._slots[g][s] = eb
        end
    end

    -- presets
    local rightX = centreX + centreW + 14
    local rightW = EDITOR_W - rightX - 10
    local rightCol = CreateFrame("Frame", nil, f)
    rightCol:SetPoint("TOPLEFT", f, "TOPLEFT", rightX, -40)
    rightCol:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 60)
    rightCol:SetWidth(rightW)

    local presetHeader = T:Label(rightCol, {
        text = L["RG_Presets"]
    })
    presetHeader.frame:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 0, 0)

    self._selectedPreset = self._selectedPreset or nil

    local presetDropdown = T:Dropdown(rightCol, {
        placeholder = L["RG_SelectPreset"],
        values = function()
            local t = {}
            for _, preset in ipairs(RaidGroups:GetPresets()) do
                t[preset.name] = preset.name
            end
            return t
        end,
        get = function()
            local cur = RaidGroups._selectedPreset
            if cur and RaidGroups:GetPresetByName(cur) then
                return cur
            end
            local first = RaidGroups:GetPresets()[1]
            RaidGroups._selectedPreset = first and first.name or nil
            return RaidGroups._selectedPreset
        end,
        onChange = function(key)
            RaidGroups._selectedPreset = key
        end,
        buttonHeight = 24
    })
    presetDropdown.frame:SetWidth(rightW)
    presetDropdown.frame:SetPoint("TOPLEFT", presetHeader.frame, "BOTTOMLEFT", 0, -4)
    f._presetDropdown = presetDropdown

    local function currentPresetName()
        return RaidGroups._selectedPreset
    end

    local function needsSelection(fn)
        return function()
            local name = currentPresetName()
            if not name then
                return
            end
            fn(name)
        end
    end

    local btnW = (rightW - 4) / 2

    local loadBtn = T:Button(rightCol, {
        text = L["RG_Load"],
        width = btnW,
        height = 22,
        onClick = needsSelection(function(name)
            local preset = RaidGroups:GetPresetByName(name)
            if preset then
                RaidGroups:LoadPresetIntoSlots(preset.data)
            end
        end)
    })
    loadBtn.frame:SetPoint("TOPLEFT", presetDropdown.frame, "BOTTOMLEFT", 0, -6)

    local saveBtn = T:Button(rightCol, {
        text = L["RG_SaveAsPreset"],
        width = btnW,
        height = 22,
        onClick = function()
            ART.RaidGroupsUI:ShowSavePresetPrompt(RaidGroups._editor)
        end
    })
    saveBtn.frame:SetPoint("LEFT", loadBtn.frame, "RIGHT", 4, 0)

    local renameBtn = T:Button(rightCol, {
        text = L["RG_Rename"],
        width = btnW,
        height = 22,
        onClick = needsSelection(function(name)
            ART.RaidGroupsUI:ShowRenamePrompt(RaidGroups._editor, name)
        end)
    })
    renameBtn.frame:SetPoint("TOPLEFT", loadBtn.frame, "BOTTOMLEFT", 0, -4)

    local deleteBtn = T:Button(rightCol, {
        text = L["RG_Delete"],
        width = btnW,
        height = 22,
        onClick = needsSelection(function(name)
            ART.RaidGroupsUI:ShowDeleteConfirm(RaidGroups._editor, name)
        end)
    })
    deleteBtn.frame:SetPoint("LEFT", renameBtn.frame, "RIGHT", 4, 0)

    local importBtn = T:Button(rightCol, {
        text = L["Import"],
        width = btnW,
        height = 22,
        onClick = function()
            ART.RaidGroupsUI:ShowImportPrompt(RaidGroups._editor)
        end
    })
    importBtn.frame:SetPoint("TOPLEFT", renameBtn.frame, "BOTTOMLEFT", 0, -4)

    local exportBtn = T:Button(rightCol, {
        text = L["Export"],
        width = btnW,
        height = 22,
        onClick = needsSelection(function(name)
            ART.RaidGroupsUI:ShowExportViewer(RaidGroups._editor, name)
        end)
    })
    exportBtn.frame:SetPoint("LEFT", importBtn.frame, "RIGHT", 4, 0)

    local presetBtns = {loadBtn, saveBtn, renameBtn, deleteBtn, importBtn, exportBtn}
    local function fitPresetButtons()
        for _, b in ipairs(presetBtns) do
            b.frame:SetWidth(btnW)
        end
    end
    fitPresetButtons()
    f:HookScript("OnShow", fitPresetButtons)

    -- action buttons
    local actionBar = CreateFrame("Frame", nil, f)
    actionBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
    actionBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    actionBar:SetHeight(40)

    local getRosterBtn = T:Button(actionBar, {
        text = L["RG_GetRoster"],
        width = 130,
        height = 26,
        onClick = function()
            RaidGroups:ImportRosterToSlots()
        end
    })
    getRosterBtn.frame:SetPoint("LEFT", actionBar, "LEFT", 0, 0)

    local applyBtn = T:Button(actionBar, {
        text = L["RG_ApplyGroups"],
        width = 130,
        height = 26,
        onClick = function()
            RaidGroups:ApplyFromEditor()
        end
    })
    applyBtn.frame:SetPoint("LEFT", getRosterBtn.frame, "RIGHT", 10, 0)

    local clearBtn = T:Button(actionBar, {
        text = L["RG_Clear"],
        width = 100,
        height = 26,
        onClick = function()
            RaidGroups:ClearSlots()
        end
    })
    clearBtn.frame:SetPoint("LEFT", applyBtn.frame, "RIGHT", 10, 0)

    local exportRosterBtn = T:Button(actionBar, {
        text = L["RG_ExportRoster"],
        width = 130,
        height = 26,
        onClick = function()
            local text = RaidGroups:GetRosterExportString()
            if text == "" then
                E:Printf(L["RG_NotInRaid"])
                return
            end
            ART.RaidGroupsUI:ShowRosterViewer(RaidGroups._editor, text)
        end
    })
    exportRosterBtn.frame:SetPoint("LEFT", clearBtn.frame, "RIGHT", 10, 0)

    local actionBtns = {getRosterBtn, applyBtn, clearBtn, exportRosterBtn}
    local function fitActionButtons()
        for _, b in ipairs(actionBtns) do
            local textW = b.label and b.label:GetStringWidth() or 0
            if textW > 0 then
                local minimum = math.floor(textW + 0.5) + 20
                if b.frame:GetWidth() < minimum then
                    b.frame:SetWidth(minimum)
                end
            end
        end
    end
    fitActionButtons()
    f:HookScript("OnShow", fitActionButtons)

    -- populate preset list
    self:RefreshPresetList()

    f:SetScript("OnShow", function()
        E:InvalidateRosterCache()
        RaidGroups:PopulateNameList()
        RaidGroups:UpdateSlotTints()
        RaidGroups:RefreshPresetList()
        if RaidGroups._nameListFrame then
            RaidGroups._nameListFrame:SetShown(f._listSource ~= nil)
        end
    end)
    f:SetScript("OnHide", function()
        stopDragPreview(RaidGroups)
        if f._raidChk then
            f._raidChk.SetChecked(false)
        end
        if f._guildChk then
            f._guildChk.SetChecked(false)
        end
        f._listSource = nil
    end)

    return f
end

function RaidGroups:RefreshPresetList(touchedName)
    local f = self._editor
    if not f or not f._presetDropdown then
        return
    end

    -- Bias the selected preset based on what just changed
    if touchedName and self:GetPresetByName(touchedName) then
        self._selectedPreset = touchedName
    elseif self._selectedPreset and not self:GetPresetByName(self._selectedPreset) then
        local first = self:GetPresets()[1]
        self._selectedPreset = first and first.name or nil
    end

    f._presetDropdown.Refresh()
end

function RaidGroups:OpenEditor()
    if not self:IsEnabled() then
        return
    end
    local f = self:BuildEditor()
    f:Show()
    f:Raise()
end

function RaidGroups:CloseEditor()
    if self._editor then
        self._editor:Hide()
    end
end

function RaidGroups:ToggleEditor()
    if self._editor and self._editor:IsShown() then
        self:CloseEditor()
    else
        self:OpenEditor()
    end
end

local editorEvents = E:NewCallbackHandle()

editorEvents:RegisterMessage("ART_ROSTER_INVALIDATED", function()
    local editor = RaidGroups._editor
    if not editor or not editor:IsShown() then
        return
    end
    if editor._listSource == "raid" or editor._listSource == "guild" then
        RaidGroups:PopulateNameList()
    end
    RaidGroups:UpdateSlotTints()
    if RaidGroups._slots then
        for _, group in ipairs(RaidGroups._slots) do
            for _, eb in ipairs(group) do
                if eb.usedName and eb.usedName ~= "" then
                    local class = E:GetClassByName(eb.usedName)
                    local r, g, b = classColor(class)
                    eb:SetText(colorize(RaidGroups:DisplayName(eb.usedName), r, g, b))
                    eb:SetCursorPosition(0)
                end
            end
        end
    end
end)

editorEvents:RegisterMessage("ART_RAIDGROUPS_PRESETS_CHANGED", function(_, touchedName)
    if RaidGroups._editor then
        RaidGroups:RefreshPresetList(touchedName)
    end
end)

editorEvents:RegisterMessage("ART_NICKNAME_CHANGED", function()
    local f = RaidGroups._editor
    if not f or not f:IsShown() then
        return
    end
    if RaidGroups._slots then
        for _, group in ipairs(RaidGroups._slots) do
            for _, eb in ipairs(group) do
                if eb.usedName and eb.usedName ~= "" then
                    local class = E:GetClassByName(eb.usedName)
                    local r, g, b = classColor(class)
                    eb:SetText(colorize(RaidGroups:DisplayName(eb.usedName), r, g, b))
                    eb:SetCursorPosition(0)
                end
            end
        end
    end
    RaidGroups:RefreshVisibleRows()
end)

editorEvents:RegisterMessage("ART_RAIDGROUPS_DISABLED", function()
    if RaidGroups._editor and RaidGroups._editor:IsShown() then
        RaidGroups._editor:Hide()
    end
end)

editorEvents:RegisterMessage("ART_MEDIA_UPDATED", function()
    if sharedSlotEditBox then
        applyEditBoxFont(sharedSlotEditBox)
    end
end)
