local E, L = unpack(ART)
local T = E.Templates

local MAIN_SLOT = 1
local PINNED_PERSONAL_SLOT = 2

-- Shared panel 
local editingSlot = MAIN_SLOT

-- Which slot the Display tab is currently targeting
local displayingSlot = MAIN_SLOT

-- Track the last-committed text per slot
local lastCommittedText = {}

-- Cached reference
local editorRef

local function refreshPanel()
    if not (E.OptionsUI and E.OptionsUI:IsShown()) then
        return
    end
    E.OptionsUI:QueueRefresh("current")
end

local NoteEvents = E:NewCallbackHandle()
NoteEvents:RegisterMessage("ART_NOTES_LIST_CHANGED", refreshPanel)
NoteEvents:RegisterMessage("ART_NOTE_SLOT_RENAMED", refreshPanel)
NoteEvents:RegisterMessage("ART_NOTE_SLOT_ACTIVE_CHANGED", refreshPanel)
NoteEvents:RegisterMessage("ART_NOTES_LOCK_CHANGED", refreshPanel)
NoteEvents:RegisterMessage("ART_NOTE_RECEIVED", refreshPanel)
NoteEvents:RegisterMessage("ART_NOTE_CHANGED", refreshPanel)
NoteEvents:RegisterMessage("ART_NICKNAME_CHANGED", refreshPanel)
NoteEvents:RegisterMessage("ART_PROFILE_CHANGED", function()
    editingSlot = MAIN_SLOT
    displayingSlot = MAIN_SLOT
    wipe(lastCommittedText)
    refreshPanel()
end)

local function clampSlot(mod, value)
    local count = mod:GetSlotCount()
    if count == 0 then
        return 1
    end
    value = tonumber(value) or MAIN_SLOT
    if value < 1 then
        return 1
    end
    if value > count then
        return count
    end
    return value
end

local function clampEditingSlot(mod)
    editingSlot = clampSlot(mod, editingSlot)
    return editingSlot
end

local function clampDisplayingSlot(mod)
    displayingSlot = clampSlot(mod, displayingSlot)
    return displayingSlot
end

-- Force-reload the editor's text from the current slot's raw text
local function reloadEditor(mod)
    local idx = clampEditingSlot(mod)
    local text = mod:GetSlotText(idx) or ""
    lastCommittedText[idx] = text
    if editorRef and editorRef.editBox then
        editorRef.editBox:ClearFocus()
    end
    if editorRef and editorRef.SetText then
        editorRef.SetText(text)
    end
end

local EDITOR_LINES = 20
local TOOLBAR_H = 40
local TOKEN_STRIP_H = 22
local ACTION_ROW_H = 24
local GAP = 4
local COL_GAP = 8
local SLOT_LIST_W = 170
local ACTION_COL_W = 220
local SLOT_ROW_H = 22
local ROSTER_ROW_H = 18
local MRT_BTN_H = 24
local DROPDOWN_BTN_H = 26
local DROPDOWN_LABEL_H = 16
local DROPDOWN_CONTAINER_H = DROPDOWN_LABEL_H + DROPDOWN_BTN_H + GAP
local ROSTER_HEADER_H = 16
local PRE_EDITOR_H = TOOLBAR_H + GAP + TOKEN_STRIP_H + GAP + ACTION_ROW_H + GAP
local PRE_ROSTER_H = MRT_BTN_H + GAP + DROPDOWN_CONTAINER_H + GAP + ROSTER_HEADER_H + GAP
local EDITOR_INNER_H = EDITOR_LINES * 16 + 10
local EDITOR_HEIGHT = math.max(PRE_EDITOR_H, PRE_ROSTER_H) + EDITOR_INNER_H

local function fmtSlotLabel(mod, index)
    if index == MAIN_SLOT then
        return "|cff1784d1" .. L["Notes_MainTag"] .. "|r"
    end
    if index == PINNED_PERSONAL_SLOT then
        return "|cff66ccff" .. L["Notes_PersonalTag"] .. "|r"
    end
    local name = mod:GetSlotName(index)
    if not name or name == "" then
        name = L["Notes_PersonalDefault"] .. (index - 1)
    end
    return "|cff888888#" .. index .. "|r  " .. name
end

local TOKEN_INSERTS = {{
    label = "{spell}",
    insert = "{spell:12345}"
}, {
    label = "{p}",
    insert = "{p:Name}"
}, {
    label = "{class}",
    insert = "{class:warrior,mage}"
}, {
    label = "{time}",
    insert = "{time:30}"
}, {
    label = "{zone}",
    insert = "{zone:name}"
}}

local function bossModNoteRegistry()
    local BossMods = E:GetModule("BossMods", true)
    return BossMods and BossMods.NoteBlock or nil
end

local function resolveDisplay(unit, rawName)
    if E.GetNickname and unit and UnitExists(unit) then
        local nick = E:GetNickname(unit)
        if nick and nick ~= "" then
            return nick
        end
    end
    return rawName
end

local function buildRosterList()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local name, _, subgroup, _, _, class = GetRaidRosterInfo(i)
            local safe = E:SafeString(name)
            if safe and safe ~= "" then
                list[#list + 1] = {
                    name = safe,
                    display = resolveDisplay(unit, safe),
                    class = class,
                    order = i,
                    subgroup = subgroup
                }
            end
        end
    elseif IsInGroup() then
        local pname = E:SafeString(UnitName("player"))
        local _, pclass = UnitClass("player")
        if pname and pname ~= "" then
            list[#list + 1] = {
                name = pname,
                display = resolveDisplay("player", pname),
                class = pclass,
                order = 0
            }
        end
        local n = GetNumGroupMembers() or 0
        for i = 1, n - 1 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local raw = E:SafeString(UnitName(unit))
                local _, cls = UnitClass(unit)
                if raw and raw ~= "" then
                    list[#list + 1] = {
                        name = raw,
                        display = resolveDisplay(unit, raw),
                        class = cls,
                        order = i
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.order or 0) < (b.order or 0)
    end)
    return list
end

local function buildEditorArea(parent, mod, isModuleDisabled)
    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(EDITOR_HEIGHT)

    container:HookScript("OnShow", function()
        NoteEvents:RegisterEvent("GROUP_ROSTER_UPDATE", refreshPanel)
    end)
    container:HookScript("OnHide", function()
        NoteEvents:UnregisterEvent("GROUP_ROSTER_UPDATE")
    end)

    local listHost = CreateFrame("Frame", nil, container, "BackdropTemplate")
    E:SetTemplate(listHost, "Transparent")
    listHost:SetPoint("TOPLEFT", 0, 0)
    listHost:SetPoint("BOTTOMLEFT", 0, 0)
    listHost:SetWidth(SLOT_LIST_W)

    local actionCol = CreateFrame("Frame", nil, container)
    actionCol:SetPoint("TOPRIGHT", 0, 0)
    actionCol:SetPoint("BOTTOMRIGHT", 0, 0)
    actionCol:SetWidth(ACTION_COL_W)

    local editorCol = CreateFrame("Frame", nil, container)
    editorCol:SetPoint("TOPLEFT", listHost, "TOPRIGHT", COL_GAP, 0)
    editorCol:SetPoint("BOTTOMLEFT", listHost, "BOTTOMRIGHT", COL_GAP, 0)
    editorCol:SetPoint("TOPRIGHT", actionCol, "TOPLEFT", -COL_GAP, 0)
    editorCol:SetPoint("BOTTOMRIGHT", actionCol, "BOTTOMLEFT", -COL_GAP, 0)

    local rowPool = {}
    local addBtn, removeBtn

    local function acquireRow()
        for _, row in ipairs(rowPool) do
            if not row._inUse then
                row._inUse = true
                row:Show()
                return row
            end
        end
        local row = CreateFrame("Button", nil, listHost, "BackdropTemplate")
        E:SetTemplate(row, "Default")
        row:SetHeight(SLOT_ROW_H)
        local fs = row:CreateFontString(nil, "OVERLAY")
        E:RegisterFontString(fs, 0)
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
        row._text = fs
        row:SetScript("OnEnter", function(self_)
            if not self_._selected then
                self_:SetBackdropBorderColor(unpack(E.media.valueColor))
            end
        end)
        row:SetScript("OnLeave", function(self_)
            if not self_._selected then
                self_:SetBackdropBorderColor(unpack(E.media.borderColor))
            end
        end)
        row._inUse = true
        rowPool[#rowPool + 1] = row
        return row
    end

    local function rebuildRows()
        for _, row in ipairs(rowPool) do
            row._inUse = false
        end
        local selected = clampEditingSlot(mod)
        local y = 4
        for i = 1, mod:GetSlotCount() do
            local row = acquireRow()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listHost, "TOPLEFT", 4, -y)
            row:SetPoint("TOPRIGHT", listHost, "TOPRIGHT", -4, -y)
            row._text:SetText(fmtSlotLabel(mod, i))
            row._selected = (i == selected)
            if row._selected then
                row:SetBackdropBorderColor(unpack(E.media.valueColor))
                row:SetBackdropColor(E.media.valueColor[1] * 0.3, E.media.valueColor[2] * 0.3,
                    E.media.valueColor[3] * 0.3, 0.5)
            else
                row:SetBackdropBorderColor(unpack(E.media.borderColor))
                row:SetBackdropColor(unpack(E.media.backdropColor))
            end
            row:SetScript("OnClick", function()
                editingSlot = i
                displayingSlot = i
                reloadEditor(mod)
                refreshPanel()
            end)
            y = y + SLOT_ROW_H + 2
        end
        for _, row in ipairs(rowPool) do
            if not row._inUse then
                row:Hide()
            end
        end

        if not addBtn then
            addBtn = T:Button(listHost, {
                text = L["Notes_AddSlot"],
                onClick = function()
                    if mod:GetSlotCount() >= mod:GetMaxSlots() then
                        return
                    end
                    local newIdx = mod:AddSlot("", "")
                    if newIdx then
                        editingSlot = newIdx
                        displayingSlot = newIdx
                        reloadEditor(mod)
                    end
                end,
                disabled = function()
                    return isModuleDisabled() or mod:GetSlotCount() >= mod:GetMaxSlots()
                end
            })
            addBtn.frame:ClearAllPoints()
            addBtn.frame:SetPoint("BOTTOMLEFT", listHost, "BOTTOMLEFT", 4, 4)
            addBtn.frame:SetPoint("BOTTOMRIGHT", listHost, "BOTTOMRIGHT", -4, 4)
        end
        if addBtn.Refresh then
            addBtn.Refresh()
        end

        if not removeBtn then
            removeBtn = T:Button(listHost, {
                text = L["Notes_RemoveSlot"],
                confirm = true,
                confirmTitle = L["Notes_RemoveSlotConfirmTitle"],
                confirmText = function()
                    return L["Notes_RemoveSlotConfirm"]:format(mod:GetSlotName(clampEditingSlot(mod)) or "?")
                end,
                onClick = function()
                    local idx = clampEditingSlot(mod)
                    if mod:RemoveSlot(idx) then
                        editingSlot = math.min(idx, mod:GetSlotCount())
                        displayingSlot = editingSlot
                        reloadEditor(mod)
                    end
                end,
                disabled = function()
                    if isModuleDisabled() then
                        return true
                    end
                    local idx = clampEditingSlot(mod)
                    return idx == MAIN_SLOT or idx == PINNED_PERSONAL_SLOT
                end,
                tooltip = function()
                    local idx = clampEditingSlot(mod)
                    if idx == MAIN_SLOT then
                        return {
                            title = L["Notes_RemoveSlot"],
                            desc = L["Notes_CannotRemoveMain"]
                        }
                    end
                    if idx == PINNED_PERSONAL_SLOT then
                        return {
                            title = L["Notes_RemoveSlot"],
                            desc = L["Notes_CannotRemovePinnedPersonal"]
                        }
                    end
                    return {
                        title = L["Notes_RemoveSlot"]
                    }
                end
            })
            removeBtn.frame:ClearAllPoints()
            removeBtn.frame:SetPoint("BOTTOMLEFT", addBtn.frame, "TOPLEFT", 0, GAP)
            removeBtn.frame:SetPoint("BOTTOMRIGHT", addBtn.frame, "TOPRIGHT", 0, GAP)
        end
        if removeBtn.Refresh then
            removeBtn.Refresh()
        end
    end

    local toolbar = CreateFrame("Frame", nil, editorCol)
    toolbar:SetPoint("TOPLEFT", 0, 0)
    toolbar:SetPoint("TOPRIGHT", 0, 0)
    toolbar:SetHeight(TOOLBAR_H)

    local nameBox = T:EditBox(toolbar, {
        label = L["Notes_SlotName"],
        commitOn = "enter",
        get = function()
            return mod:GetSlotName(clampEditingSlot(mod)) or ""
        end,
        onCommit = function(text)
            mod:SetSlotName(clampEditingSlot(mod), text)
        end,
        disabled = function()
            if isModuleDisabled() then
                return true
            end
            local idx = clampEditingSlot(mod)
            return idx == MAIN_SLOT or idx == PINNED_PERSONAL_SLOT
        end,
        tooltip = function()
            local idx = clampEditingSlot(mod)
            if idx == MAIN_SLOT then
                return {
                    title = L["Notes_SlotName"],
                    desc = L["Notes_MainNameLocked"]
                }
            end
            if idx == PINNED_PERSONAL_SLOT then
                return {
                    title = L["Notes_SlotName"],
                    desc = L["Notes_PersonalNameLocked"]
                }
            end
            return {
                title = L["Notes_SlotName"]
            }
        end
    })

    nameBox.frame:ClearAllPoints()
    nameBox.frame:SetPoint("TOPLEFT", 0, 0)
    nameBox.frame:SetPoint("TOPRIGHT", 0, 0)

    local tokenStrip = CreateFrame("Frame", nil, editorCol)
    tokenStrip:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -GAP)
    tokenStrip:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -GAP)
    tokenStrip:SetHeight(TOKEN_STRIP_H)

    local actionRow = CreateFrame("Frame", nil, editorCol)
    actionRow:SetPoint("TOPLEFT", tokenStrip, "BOTTOMLEFT", 0, -GAP)
    actionRow:SetPoint("TOPRIGHT", tokenStrip, "BOTTOMRIGHT", 0, -GAP)
    actionRow:SetHeight(ACTION_ROW_H)

    local editor = T:MultilineEditBox(editorCol, {
        lines = EDITOR_LINES,
        get = function()
            return mod:GetSlotText(clampEditingSlot(mod))
        end,
        onTextChanged = function(text, userInput)
            if not userInput then
                return
            end
            local idx = clampEditingSlot(mod)
            local prev = lastCommittedText[idx]
            if prev == nil then
                prev = mod:GetSlotText(idx)
            end
            if prev ~= text then
                mod:PushUndo(idx, prev)
            end
            lastCommittedText[idx] = text
            mod:SetSlotText(idx, text)
        end,
        disabled = isModuleDisabled
    })
    editor.frame:ClearAllPoints()
    editor.frame:SetPoint("TOPLEFT", actionRow, "BOTTOMLEFT", 0, -GAP)
    editor.frame:SetPoint("TOPRIGHT", actionRow, "BOTTOMRIGHT", 0, -GAP)
    editorRef = editor

    if editor.editBox and editor.scrollFrame then
        local eb = editor.editBox
        local sc = editor.scrollFrame
        eb:EnableMouseWheel(true)
        eb:SetScript("OnMouseWheel", function(_, delta)
            local handler = sc:GetScript("OnMouseWheel")
            if handler then
                handler(sc, delta)
            end
        end)
    end

    local function insertAtCursor(text, options)
        if isModuleDisabled() then
            return
        end
        local eb = editor.editBox
        if not eb or type(text) ~= "string" or text == "" then
            return
        end
        local cur = eb:GetText() or ""
        local pos = eb:GetCursorPosition() or #cur
        local prefix = cur:sub(1, pos)
        local suffix = cur:sub(pos + 1)
        local needsLeadingSpace = options and options.spacePad and prefix ~= "" and not prefix:match("[%s\n]$")
        local needsTrailingSpace = options and options.spacePad and suffix ~= "" and not suffix:match("^[%s\n]")
        local insert = (needsLeadingSpace and " " or "") .. text .. (needsTrailingSpace and " " or "")
        local new = prefix .. insert .. suffix
        local idx = clampEditingSlot(mod)
        mod:PushUndo(idx, cur)
        lastCommittedText[idx] = new
        eb:SetText(new)
        eb:SetCursorPosition(pos + #insert)
        eb:SetFocus()
        mod:SetSlotText(idx, new)
        refreshPanel()
    end

    local stripX = 0
    for _, entry in ipairs(TOKEN_INSERTS) do
        local btn = T:Button(tokenStrip, {
            text = entry.label,
            height = 20,
            onClick = function()
                insertAtCursor(entry.insert)
            end,
            disabled = isModuleDisabled
        })
        btn.frame:ClearAllPoints()
        btn.frame:SetPoint("TOPLEFT", tokenStrip, "TOPLEFT", stripX, 0)
        stripX = stripX + (btn.frame:GetWidth() or 60) + 4
    end

    local undoBtn = T:Button(actionRow, {
        text = L["Notes_Undo"],
        width = 80,
        onClick = function()
            local idx = clampEditingSlot(mod)
            if mod:Undo(idx) then
                reloadEditor(mod)
                refreshPanel()
            end
        end,
        disabled = function()
            if isModuleDisabled() then
                return true
            end
            return not mod:CanUndo(clampEditingSlot(mod))
        end,
        tooltip = function()
            if not mod:CanUndo(clampEditingSlot(mod)) then
                return {
                    title = L["Notes_Undo"],
                    desc = L["Notes_UndoEmpty"]
                }
            end
            return {
                title = L["Notes_Undo"]
            }
        end
    })
    undoBtn.frame:ClearAllPoints()
    undoBtn.frame:SetPoint("TOPLEFT", actionRow, "TOPLEFT", 0, 0)

    local sendBtn = T:Button(actionRow, {
        text = L["Notes_Send"],
        width = 80,
        emphasize = true,
        onClick = function()
            mod:SendSlot(MAIN_SLOT)
        end,
        disabled = function()
            if isModuleDisabled() then
                return true
            end
            return not mod:CanSend(MAIN_SLOT)
        end,
        tooltip = function()
            local ok, reason = mod:CanSend(MAIN_SLOT)
            if ok then
                return {
                    title = L["Notes_Send"],
                    desc = L["Notes_SendDesc"]
                }
            end
            if reason == "NOT_IN_GROUP" then
                return {
                    title = L["Notes_Send"],
                    desc = L["Notes_SendNotInGroup"]
                }
            elseif reason == "EMPTY" then
                return {
                    title = L["Notes_Send"],
                    desc = L["Notes_SendEmpty"]
                }
            elseif reason == "NOT_AUTHORIZED" then
                return {
                    title = L["Notes_Send"],
                    desc = L["Notes_SendNotAuthorized"]
                }
            end
            return {
                title = L["Notes_Send"]
            }
        end
    })
    sendBtn.frame:ClearAllPoints()
    sendBtn.frame:SetPoint("LEFT", undoBtn.frame, "RIGHT", GAP, 0)

    local activeChk = T:Checkbox(actionRow, {
        text = L["Notes_Active"],
        get = function()
            return mod:IsSlotActive(clampEditingSlot(mod))
        end,
        onChange = function(_, v)
            mod:SetSlotActive(clampEditingSlot(mod), v)
        end,
        tooltip = {
            title = L["Notes_Active"],
            desc = L["Notes_ActiveDesc"]
        },
        disabled = isModuleDisabled
    })
    activeChk.frame:ClearAllPoints()
    activeChk.frame:SetPoint("RIGHT", actionRow, "RIGHT", 0, 0)

    local mrtBtn = T:Button(actionCol, {
        text = L["Notes_ImportFromMRT"],
        height = MRT_BTN_H,
        onClick = function()
            local idx = clampEditingSlot(mod)
            if mod:ImportFromMRT(idx) then
                reloadEditor(mod)
                refreshPanel()
            end
        end,
        disabled = function()
            if isModuleDisabled() then
                return true
            end
            return not mod:IsMRTLoaded()
        end,
        tooltip = function()
            if not mod:IsMRTLoaded() then
                return {
                    title = L["Notes_ImportFromMRT"],
                    desc = L["Notes_MRTNotLoaded"]
                }
            end
            return {
                title = L["Notes_ImportFromMRT"],
                desc = L["Notes_ImportFromMRTDesc"]
            }
        end
    })
    mrtBtn.frame:ClearAllPoints()
    mrtBtn.frame:SetPoint("TOPLEFT", actionCol, "TOPLEFT", 0, 0)
    mrtBtn.frame:SetPoint("TOPRIGHT", actionCol, "TOPRIGHT", 0, 0)

    local bossModDropdown = T:Dropdown(actionCol, {
        label = L["Notes_InsertBossMod"],
        placeholder = L["Notes_InsertBossModPlaceholder"],
        emptyText = L["Notes_NoBossModNotes"],
        buttonHeight = DROPDOWN_BTN_H,
        height = DROPDOWN_CONTAINER_H,
        values = function()
            local NoteBlock = bossModNoteRegistry()
            if not NoteBlock or not NoteBlock.GetRegisteredNoteBlocks then
                return {}
            end
            local out = {}
            for _, entry in ipairs(NoteBlock:GetRegisteredNoteBlocks()) do
                out[entry.key] = (entry.labelKey and L[entry.labelKey]) or entry.labelKey or entry.key
            end
            return out
        end,
        get = function()
            return nil
        end,
        onChange = function(key)
            local NoteBlock = bossModNoteRegistry()
            if not NoteBlock then
                return
            end
            local entry = NoteBlock:GetNoteBlockEntry(key)
            if not entry then
                return
            end
            local body = NoteBlock:BuildBlockTemplate(entry)
            if body == "" then
                return
            end
            local eb = editor.editBox
            local cur = eb and eb:GetText() or ""
            local pos = eb and eb:GetCursorPosition() or 0
            local prefix = cur:sub(1, pos)
            local needsLeadingNewline = prefix ~= "" and not prefix:match("\n$")
            insertAtCursor((needsLeadingNewline and "\n" or "") .. body .. "\n")
        end,
        tooltip = {
            title = L["Notes_InsertBossMod"],
            desc = L["Notes_InsertBossModDesc"]
        },
        disabled = isModuleDisabled
    })
    bossModDropdown.frame:ClearAllPoints()
    bossModDropdown.frame:SetPoint("TOPLEFT", mrtBtn.frame, "BOTTOMLEFT", 0, -GAP)
    bossModDropdown.frame:SetPoint("TOPRIGHT", mrtBtn.frame, "BOTTOMRIGHT", 0, -GAP)

    local rosterHeader = T:Label(actionCol, {
        text = L["Notes_Roster"],
        height = ROSTER_HEADER_H
    })
    rosterHeader.frame:ClearAllPoints()
    rosterHeader.frame:SetPoint("TOPLEFT", bossModDropdown.frame, "BOTTOMLEFT", 0, -GAP)
    rosterHeader.frame:SetPoint("TOPRIGHT", bossModDropdown.frame, "BOTTOMRIGHT", 0, -GAP)

    local rosterScroll = T:ScrollFrame(actionCol, {
        template = "Default",
        insets = {4, 4, 4, 4},
        mouseWheelStep = ROSTER_ROW_H,
        forwardWheelToOuter = true
    })
    rosterScroll.frame:ClearAllPoints()
    rosterScroll.frame:SetPoint("TOPLEFT", rosterHeader.frame, "BOTTOMLEFT", 0, -GAP)
    rosterScroll.frame:SetPoint("BOTTOMRIGHT", actionCol, "BOTTOMRIGHT", 0, 0)

    local rosterEmpty = rosterScroll.content:CreateFontString(nil, "OVERLAY")
    E:RegisterFontString(rosterEmpty, 0)
    rosterEmpty:SetPoint("TOPLEFT", rosterScroll.content, "TOPLEFT", 6, -6)
    rosterEmpty:SetPoint("TOPRIGHT", rosterScroll.content, "TOPRIGHT", -6, -6)
    rosterEmpty:SetJustifyH("LEFT")
    rosterEmpty:SetText(L["Notes_RosterEmpty"])
    rosterEmpty:Hide()

    local rosterRowPool = {}
    local function acquireRosterRow(index)
        local row = rosterRowPool[index]
        if row then
            row:Show()
            return row
        end
        row = CreateFrame("Button", nil, rosterScroll.content, "BackdropTemplate")
        E:SetTemplate(row, "Default")
        row:SetHeight(ROSTER_ROW_H)
        row:RegisterForClicks("LeftButtonUp")
        local fs = row:CreateFontString(nil, "OVERLAY")
        E:RegisterFontString(fs, 0)
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
        row._text = fs
        row:SetScript("OnEnter", function(self_)
            self_:SetBackdropBorderColor(unpack(E.media.valueColor))
        end)
        row:SetScript("OnLeave", function(self_)
            self_:SetBackdropBorderColor(unpack(E.media.borderColor))
        end)
        rosterRowPool[index] = row
        return row
    end

    local rosterScrollbarShouldShow = false

    if rosterScroll.scrollbar and rosterScroll.scrollbar.frame then
        hooksecurefunc(rosterScroll.scrollbar.frame, "Show", function(self)
            if not rosterScrollbarShouldShow then
                self:Hide()
            end
        end)
    end

    local function refreshRosterScrollbar()
        local sb = rosterScroll.scrollbar
        local sbFrame = sb and sb.frame or nil
        if not sbFrame then
            return
        end
        local content = rosterScroll.content
        local contentH = (content and content:GetHeight()) or 0
        local viewportH = rosterScroll.scroll:GetHeight() or 0
        rosterScrollbarShouldShow = (contentH - viewportH) > 0.5
        if rosterScrollbarShouldShow then
            if sb.Refresh then
                sb.Refresh()
            end
        else
            sbFrame:Hide()
        end
    end

    local function rebuildRoster()
        local list = buildRosterList()
        local viewW = rosterScroll.scroll:GetWidth() or 0
        local viewH = rosterScroll.scroll:GetHeight() or 0
        if viewW > 0 then
            rosterScroll.content:SetWidth(viewW)
        end
        if #list == 0 then
            for _, row in ipairs(rosterRowPool) do
                row:Hide()
            end
            rosterEmpty:Show()
            rosterScroll.SetContentSize(viewW > 0 and viewW or nil, math.max(1, viewH))
            refreshRosterScrollbar()
            return
        end
        rosterEmpty:Hide()
        for i, p in ipairs(list) do
            local row = acquireRosterRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rosterScroll.content, "TOPLEFT", 0, -(i - 1) * ROSTER_ROW_H)
            row:SetPoint("TOPRIGHT", rosterScroll.content, "TOPRIGHT", 0, -(i - 1) * ROSTER_ROW_H)
            local r, g, b = E:ClassColorRGB(p.class)
            local display = p.display or p.name
            row._text:SetText(display)
            row._text:SetTextColor(r or 1, g or 1, b or 1)
            row:SetScript("OnClick", function()
                insertAtCursor(display, {
                    spacePad = true
                })
            end)
        end
        for i = #list + 1, #rosterRowPool do
            rosterRowPool[i]:Hide()
        end
        local contentH = #list * ROSTER_ROW_H + 4
        rosterScroll.SetContentSize(viewW > 0 and viewW or nil, math.max(viewH, contentH))
        refreshRosterScrollbar()
    end

    rosterScroll.frame:HookScript("OnSizeChanged", function()
        rebuildRoster()
    end)
    rosterScroll.frame:HookScript("OnShow", function()
        rebuildRoster()
    end)

    rebuildRows()
    rebuildRoster()

    local function refreshAll()
        rebuildRows()
        rebuildRoster()
        if nameBox.Refresh then
            nameBox.Refresh()
        end
        if activeChk.Refresh then
            activeChk.Refresh()
        end
        if mrtBtn.Refresh then
            mrtBtn.Refresh()
        end
        if bossModDropdown.Refresh then
            bossModDropdown.Refresh()
        end
        if editor.Refresh then
            editor.Refresh()
        end
        if undoBtn.Refresh then
            undoBtn.Refresh()
        end
        if sendBtn.Refresh then
            sendBtn.Refresh()
        end
        if rosterScroll.scrollbar and rosterScroll.scrollbar.Refresh then
            rosterScroll.scrollbar.Refresh()
        end
    end

    return {
        frame = container,
        height = EDITOR_HEIGHT,
        fullWidth = true,
        Refresh = refreshAll
    }
end

-- Display tab

local FONT_OUTLINES = {
    NONE = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    MONOCHROME = L["Monochrome"]
}

local function slotValues(mod)
    local t = {}
    for i = 1, mod:GetSlotCount() do
        if i == MAIN_SLOT then
            t[i] = L["Notes_MainTag"]
        elseif i == PINNED_PERSONAL_SLOT then
            t[i] = L["Notes_PersonalTag"]
        else
            local name = mod:GetSlotName(i)
            if not name or name == "" then
                name = L["Notes_PersonalDefault"] .. (i - 1)
            end
            t[i] = "#" .. i .. "  " .. name
        end
    end
    return t
end

local function currentSlotDisplay(mod)
    local idx = clampDisplayingSlot(mod)
    local slot = mod:GetSlot(idx)
    return idx, slot and slot.display or nil
end

local function buildDisplayArgs(mod, isModuleDisabled)
    local args = {}

    args.header = {
        order = 1,
        build = function(parent)
            return T:Header(parent, {
                text = L["Display"]
            })
        end
    }

    args.slotPicker = {
        order = 2,
        width = "full",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["Notes_DisplayForSlot"],
                values = function()
                    return slotValues(mod)
                end,
                get = function()
                    return clampDisplayingSlot(mod)
                end,
                onChange = function(v)
                    displayingSlot = v
                    refreshPanel()
                end,
                disabled = isModuleDisabled
            })
        end
    }

    args.fontSize = {
        order = 10,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["FontSize"],
                min = 8,
                max = 32,
                step = 1,
                get = function()
                    local _, d = currentSlotDisplay(mod)
                    return (d and d.fontSize) or 12
                end,
                onChange = function(v)
                    local idx, d = currentSlotDisplay(mod)
                    if d then
                        d.fontSize = math.floor(v + 0.5)
                        mod:RefreshFrame(idx)
                    end
                end,
                disabled = isModuleDisabled
            })
        end
    }

    args.locked = {
        order = 11,
        width = "1/2",
        build = function(parent)
            return T:Checkbox(parent, {
                text = L["Notes_Locked"],
                labelTop = true,
                get = function()
                    return mod:IsSlotLocked(clampDisplayingSlot(mod))
                end,
                onChange = function(_, v)
                    mod:SetSlotLocked(clampDisplayingSlot(mod), v)
                end,
                tooltip = {
                    title = L["Notes_Locked"],
                    desc = L["Notes_LockedDesc"]
                },
                disabled = isModuleDisabled
            })
        end
    }

    args.spacing = {
        order = 12,
        width = "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Notes_LineSpacing"],
                min = 0,
                max = 10,
                step = 1,
                get = function()
                    local _, d = currentSlotDisplay(mod)
                    return (d and d.spacing) or 2
                end,
                onChange = function(v)
                    local idx, d = currentSlotDisplay(mod)
                    if d then
                        d.spacing = math.floor(v + 0.5)
                        mod:RefreshFrame(idx)
                    end
                end,
                disabled = isModuleDisabled
            })
        end
    }

    args.fontOutline = {
        order = 13,
        width = "1/2",
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["FontOutline"],
                values = function()
                    return FONT_OUTLINES
                end,
                get = function()
                    local _, d = currentSlotDisplay(mod)
                    return (d and d.fontOutline) or "OUTLINE"
                end,
                onChange = function(v)
                    local idx, d = currentSlotDisplay(mod)
                    if d then
                        d.fontOutline = v
                        mod:RefreshFrame(idx)
                    end
                end,
                disabled = isModuleDisabled
            })
        end
    }

    -- backdrop shares the row with fontOutline
    args.backdrop = {
        order = 14,
        width = "1/2",
        build = function(parent)
            local _, d = currentSlotDisplay(mod)
            local init = (d and d.backdrop) or {
                r = 0,
                g = 0,
                b = 0,
                a = 0.6
            }
            return T:ColorSwatch(parent, {
                label = L["Notes_Backdrop"],
                labelTop = true,
                r = init.r,
                g = init.g,
                b = init.b,
                a = init.a,
                hasAlpha = true,
                onChange = function(r, g, b, a)
                    local idx, dd = currentSlotDisplay(mod)
                    if dd then
                        dd.backdrop = {
                            r = r,
                            g = g,
                            b = b,
                            a = a
                        }
                        mod:RefreshFrame(idx)
                    end
                end,
                disabled = isModuleDisabled
            })
        end
    }

    args.border = {
        order = 15,
        width = "1/2",
        build = function(parent)
            local _, d = currentSlotDisplay(mod)
            local init = (d and d.border) or {
                r = 0,
                g = 0,
                b = 0,
                a = 1
            }
            return T:ColorSwatch(parent, {
                label = L["Notes_Border"],
                labelTop = true,
                r = init.r,
                g = init.g,
                b = init.b,
                a = init.a,
                hasAlpha = true,
                onChange = function(r, g, b, a)
                    local idx, dd = currentSlotDisplay(mod)
                    if dd then
                        dd.border = {
                            r = r,
                            g = g,
                            b = b,
                            a = a
                        }
                        mod:RefreshFrame(idx)
                    end
                end,
                disabled = isModuleDisabled
            })
        end
    }

    return args
end

-- Panel core

local function buildNotesPanel()
    local mod = E:GetModule("Notes", true)

    if not mod then
        return {
            type = "group",
            name = L["Notes"],
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

    local function isModuleDisabled()
        return not mod:IsEnabled()
    end

    return {
        type = "group",
        name = L["Notes"],
        childGroups = "tab",
        args = {
            notes = {
                type = "group",
                order = 1,
                name = L["Notes"],
                args = {
                    intro = {
                        order = 1,
                        build = function(parent)
                            return T:Description(parent, {
                                text = L["Notes_Intro"],
                                sizeDelta = 1
                            })
                        end
                    },
                    editor = {
                        order = 10,
                        build = function(parent)
                            return buildEditorArea(parent, mod, isModuleDisabled)
                        end
                    }
                }
            },
            display = {
                type = "group",
                order = 2,
                name = L["Display"],
                args = buildDisplayArgs(mod, isModuleDisabled)
            }
        }
    }
end

E:RegisterOptions("Notes", 25, buildNotesPanel)
