local E, L = unpack(ART)
local T = E.Templates

local PAD, CARD_GAP, ROW_GAP, HEAD_GAP = 12, 10, 5, 8
local NAME_MIN, NAME_MAX, AURA_GAP = 110, 150, 12
local CELL_MIN, CELL_MAX, GAP_MIN, GAP_MAX = 26, 40, 3, 6
local PLAYERS_MIN_W, PLAYERS_MAX_W, PLAYER_PITCH_MIN, PLAYER_PITCH_MAX = 280, 460, 46, 60
local TITLE_H, PLAYER_HEAD_H, PLAYER_CELL, PLAYER_NAME_MIN, PLAYER_NAME_MAX = 22, 16, 26, 90, 150
local TAB, TAB_GAP = 24, 4
local FOOTER_H, BUTTON_H = 36, 22
local MENU_W, MENU_ROW_H, MENU_PAD = 220, 24, 5
local CLICK_SOUND = 852
local RED = {0.9, 0.25, 0.25, 1}
local DIM = {0.55, 0.55, 0.55}
local BAR_PAD, BAR_MAX_W = 10, 640

local selectedClass
local menu

local function accent()
    return E.media.valueColor
end

local function font(parent, size, justify)
    local fs = E:CreateFontString(parent, nil, "OVERLAY", size)
    fs:SetWordWrap(false)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function shortName(name)
    return name:match("^(%S+)") or name
end

local function className(mod, classIndex)
    local class = mod.CLASSES[classIndex]
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
    return E:ClassColorCode(class) .. name .. "|r"
end

local function paladinText(name)
    return E:ClassColorCode("PALADIN") .. shortName(name) .. "|r"
end

local function entriesOf(mod, spec)
    return spec.kind == "aura" and mod.AURAS or mod.BLESSINGS
end

local function currentValue(mod, spec)
    local plan = mod:GetPlan(spec.paladin)
    if spec.kind == "aura" then return plan.aura or 0 end
    if spec.kind == "class" then return plan.classes[spec.classIndex] or 0 end
    local own = plan.players[spec.member.name]
    return own and own[2] or -1
end

local function shownValue(mod, spec)
    local plan = mod:GetPlan(spec.paladin)
    if spec.kind == "player" then return mod:BlessingFor(plan, spec.member) end
    local value = currentValue(mod, spec)
    return value ~= 0 and value or nil, true
end

local function choicesOf(mod, spec)
    local plan = mod:GetPlan(spec.paladin)
    local order = spec.kind == "aura" and mod.AURA_ORDER or mod.BLESSING_ORDER
    local known = spec.kind == "aura" and plan.auraKnown or plan.known
    local anyKnown = known and next(known)
    local list = {}
    if spec.kind == "player" then list[1] = -1 end
    for _, i in ipairs(order) do
        if not anyKnown or known[i] then list[#list + 1] = i end
    end
    if spec.kind ~= "player" then list[#list + 1] = 0 end
    return list
end

local function setValue(mod, spec, value)
    if spec.kind == "aura" then
        mod:SetAura(spec.paladin, value)
    elseif spec.kind == "class" then
        mod:SetClassBlessing(spec.paladin, spec.classIndex, value ~= 0 and value or nil)
    else
        mod:SetPlayerBlessing(spec.paladin, spec.member, value ~= -1 and value or nil)
    end
end

local function valueName(mod, spec, value)
    if value == -1 then return L["BlessingsUseClass"] end
    local entry = value and entriesOf(mod, spec)[value]
    return entry and mod.SpellName(entry) or L["None"]
end

local function valueIcon(mod, spec, value)
    if value == -1 then
        value = mod:GetPlan(spec.paladin).classes[spec.classIndex]
    end
    local entry = value and entriesOf(mod, spec)[value]
    return entry and mod.SpellIcon(entry)
end

local function otherGivers(mod, spec, value)
    if spec.kind == "aura" then return {} end
    return mod:OtherGivers(spec.paladin, value, spec.classIndex, spec.kind == "player" and spec.member or nil)
end

local function conflicts(mod, spec, value, own)
    if not value or spec.kind == "aura" then return false end
    if spec.kind == "class" then return #mod:OtherGivers(spec.paladin, value, spec.classIndex) > 0 end
    for _, paladin in ipairs(mod:GetPaladins()) do
        if paladin.name ~= spec.paladin then
            local given, otherOwn = mod:BlessingFor(paladin.plan, spec.member)
            if given == value and (own or otherOwn) then return true end
        end
    end
    return false
end

local function giverNames(names)
    local short = {}
    for i, name in ipairs(names) do short[i] = shortName(name) end
    return table.concat(short, ", ")
end

local function targetText(mod, spec)
    if spec.kind == "aura" then return L["BlessingsAura"] end
    if spec.kind == "class" then return className(mod, spec.classIndex) end
    return E:ClassColorCode(spec.member.class) .. shortName(spec.member.name) .. "|r"
end

local function step(list, current, delta)
    local index = 1
    for i, v in ipairs(list) do
        if v == current then
            index = i
            break
        end
    end
    return list[((index - 1 + delta) % #list) + 1]
end

local function paintBorder(cell)
    local color = E.media.borderColor
    if cell.editable and (cell.hovered or cell.open) then
        color = accent()
    elseif cell.borderColor then
        color = cell.borderColor
    end
    cell:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

local function showCellTooltip(cell)
    local mod, spec = cell.view.mod, cell.spec
    local value, own = shownValue(mod, spec)
    GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
    GameTooltip:AddLine(valueName(mod, spec, value), 1, 1, 1)
    GameTooltip:AddLine(paladinText(spec.paladin) .. "  |cff8c8c8c>|r  " .. targetText(mod, spec))
    if spec.kind == "player" and not own and value then
        GameTooltip:AddLine(L["BlessingsUseClass"], DIM[1], DIM[2], DIM[3])
    end
    local others = value and otherGivers(mod, spec, value) or {}
    if #others > 0 then
        GameTooltip:AddLine(L["BlessingsAlsoFrom"]:format(giverNames(others)), RED[1], RED[2], RED[3])
    end
    if cell.exceptions and cell.exceptions > 0 then
        GameTooltip:AddLine(L["BlessingsDiffer"]:format(cell.exceptions), 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function paintCell(cell)
    local view, spec = cell.view, cell.spec
    if not spec then return end
    local mod = view.mod
    local value, own = shownValue(mod, spec)
    local icon = valueIcon(mod, spec, value)
    local editable = view.enabled and mod:CanEdit(spec.paladin)

    cell.icon:SetTexture(icon)
    cell.icon:SetShown(icon ~= nil)
    cell.icon:SetDesaturated(not own)
    cell.icon:SetAlpha(own and 1 or 0.45)
    cell.plus:SetShown(icon == nil and editable)

    cell.exceptions = nil
    if spec.kind == "class" then
        local count = 0
        for _, choice in pairs(mod:GetPlan(spec.paladin).players) do
            if choice[1] == spec.classIndex then count = count + 1 end
        end
        cell.exceptions = count
    end
    cell.badge:SetText(cell.exceptions and cell.exceptions > 0 and cell.exceptions or "")

    cell.borderColor = conflicts(mod, spec, value, own) and RED or (spec.kind == "player" and own and value and accent()) or nil
    cell.editable = editable
    cell:EnableMouseWheel(editable)
    cell:SetAlpha(editable and 1 or 0.6)
    paintBorder(cell)
    if GameTooltip:IsOwned(cell) then showCellTooltip(cell) end
end

local function getMenu()
    if menu then return menu end
    local p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    E:SetTemplate(p, "Default")
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:SetWidth(MENU_W)
    p:Hide()

    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN")
    blocker:Hide()
    blocker:SetScript("OnMouseDown", function() p:Hide() end)

    p.title = font(p, 12)
    p.title:SetPoint("TOPLEFT", 10, -7)
    p.title:SetPoint("TOPRIGHT", -10, -7)
    p.line = p:CreateTexture(nil, "ARTWORK")
    p.line:SetColorTexture(1, 1, 1, 0.08)
    p.line:SetHeight(1)
    p.line:SetPoint("TOPLEFT", 1, -TITLE_H - 4)
    p.line:SetPoint("TOPRIGHT", -1, -TITLE_H - 4)
    p.rows = {}

    p:SetScript("OnShow", function()
        blocker:Show()
        local bg = E.media.backdropColor
        p:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    end)
    p:SetScript("OnHide", function()
        blocker:Hide()
        local owner = p.owner
        p.owner = nil
        if owner then
            owner.open = false
            paintBorder(owner)
        end
    end)

    menu = p
    return p
end

local function hideMenu()
    if menu and menu:IsShown() then menu:Hide() end
end

local function menuRow(p, index)
    local row = p.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, p)
    row:SetHeight(MENU_ROW_H)
    row:SetPoint("TOPLEFT", 1, -(TITLE_H + 4 + MENU_PAD + (index - 1) * MENU_ROW_H))
    row:SetPoint("TOPRIGHT", -1, -(TITLE_H + 4 + MENU_PAD + (index - 1) * MENU_ROW_H))

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    local a = accent()
    hover:SetColorTexture(a[1], a[2], a[3], 0.25)

    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetPoint("TOPLEFT", 0, -3)
    row.mark:SetPoint("BOTTOMLEFT", 0, 3)
    row.mark:SetWidth(3)
    row.mark:SetColorTexture(1, 1, 1, 1)
    E:RegisterAccentTexture(row.mark)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", 12, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.note = font(row, 11, "RIGHT")
    row.note:SetPoint("RIGHT", -10, 0)
    row.note:SetTextColor(DIM[1], DIM[2], DIM[3])

    row.label = font(row, 13)
    row.label:SetPoint("LEFT", 38, 0)
    row.label:SetPoint("RIGHT", row.note, "LEFT", -6, 0)

    row:SetScript("OnClick", function(self)
        local owner = p.owner
        p:Hide()
        if not owner or not owner.spec then return end
        PlaySound(CLICK_SOUND)
        setValue(owner.view.mod, owner.spec, self.value)
    end)
    p.rows[index] = row
    return row
end

local function openMenu(cell)
    local p = getMenu()
    if p:IsShown() and p.owner == cell then
        p:Hide()
        return
    end
    p:Hide()
    local mod, spec = cell.view.mod, cell.spec
    local list = choicesOf(mod, spec)
    local current = currentValue(mod, spec)
    p.title:SetText(paladinText(spec.paladin) .. "  |cff8c8c8c>|r  " .. targetText(mod, spec))

    for index, value in ipairs(list) do
        local row = menuRow(p, index)
        local icon = valueIcon(mod, spec, value)
        row.value = value
        row.icon:SetTexture(icon)
        row.icon:SetShown(icon ~= nil)
        row.icon:SetDesaturated(value == -1)
        row.icon:SetAlpha(value == -1 and 0.6 or 1)
        row.label:SetText(valueName(mod, spec, value))
        row.mark:SetShown(value == current)
        if value == current then
            row.label:SetTextColor(1, 1, 1)
        else
            row.label:SetTextColor(0.8, 0.8, 0.8)
        end
        local others = value > 0 and otherGivers(mod, spec, value) or {}
        row.note:SetText(giverNames(others))
        row:Show()
    end
    for index = #list + 1, #p.rows do p.rows[index]:Hide() end

    p:SetHeight(TITLE_H + 4 + MENU_PAD * 2 + #list * MENU_ROW_H)
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", cell, "TOPRIGHT", 6, 0)
    p.owner = cell
    cell.open = true
    paintBorder(cell)
    p:Show()
end

local function cellEnter(self)
    self.hovered = true
    paintBorder(self)
    if self.spec then showCellTooltip(self) end
end

local function cellLeave(self)
    self.hovered = false
    paintBorder(self)
    GameTooltip:Hide()
end

local function cellClick(self, button)
    if not (self.editable and self.spec) then return end
    if button == "RightButton" then
        hideMenu()
        PlaySound(CLICK_SOUND)
        setValue(self.view.mod, self.spec, self.spec.kind == "player" and -1 or 0)
    else
        openMenu(self)
    end
end

local function cellWheel(self, delta)
    if not (self.editable and self.spec) then return end
    local mod = self.view.mod
    setValue(mod, self.spec, step(choicesOf(mod, self.spec), currentValue(mod, self.spec), delta > 0 and -1 or 1))
end

local function createTile(parent)
    local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
    E:SetTemplate(tile, "Default")
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", 1, -1)
    tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local hover = tile:CreateTexture(nil, "HIGHLIGHT")
    hover:SetPoint("TOPLEFT", 1, -1)
    hover:SetPoint("BOTTOMRIGHT", -1, 1)
    hover:SetColorTexture(1, 1, 1, 0.1)
    tile.badge = font(tile, 11, "RIGHT")
    tile.badge:SetPoint("BOTTOMRIGHT", -2, 2)
    return tile
end

local function createCell(parent, view)
    local cell = createTile(parent)
    cell.view = view
    cell.plus = font(cell, 14, "CENTER")
    cell.plus:SetPoint("CENTER", 0, 0)
    cell.plus:SetText("+")
    cell.plus:SetTextColor(1, 1, 1, 0.3)
    cell.badge:SetTextColor(1, 0.82, 0)
    cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cell:SetScript("OnEnter", cellEnter)
    cell:SetScript("OnLeave", cellLeave)
    cell:SetScript("OnClick", cellClick)
    cell:SetScript("OnMouseWheel", cellWheel)
    cell:EnableMouseWheel(false)
    return cell
end

local function createCard(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    E:SetTemplate(card, "Transparent")
    return card
end

local function buildBarBody(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end
    local tracker = T:MakeTracker()
    local track = tracker.track
    local gap = 8

    local function barDisabled()
        return isDisabled() or not mod:BarSettings().enabled
    end

    local function changed()
        mod:RefreshBar()
        tracker.refresh()
    end

    local show = track(T:Checkbox(parent, {
        text = L["BlessingsBarShow"],
        labelTop = true,
        get = function() return mod:BarSettings().enabled end,
        onChange = function(_, value)
            mod:BarSettings().enabled = value and true or false
            changed()
        end,
        disabled = isDisabled
    }))
    local unlock = track(T:Checkbox(parent, {
        text = L["BossMods_UnlockFrame"],
        labelTop = true,
        tooltip = {title = L["BossMods_UnlockFrame"], desc = L["DragToMove"]},
        get = function() return not mod:BarSettings().locked end,
        onChange = function(_, value) mod:SetBarLocked(not value) end,
        disabled = barDisabled
    }))
    local scale = track(T:Slider(parent, {
        label = L["Scale"],
        min = 0.6,
        max = 1.6,
        step = 0.05,
        value = mod:BarSettings().scale,
        get = function() return mod:BarSettings().scale end,
        onChange = function(value)
            mod:BarSettings().scale = value
            mod:ApplyBarPosition()
        end,
        disabled = barDisabled
    }))
    local y = T:PlaceRow(parent, {show, unlock, scale}, 0, width, {widths = {1, 1, 2}}) + gap

    local positionY, position = T:PositionSection(parent, y, width, {
        hideHeader = true,
        hideUnlock = true,
        tracker = tracker,
        getPosition = function()
            local saved = mod:GetBarPosition()
            return {point = saved.point, x = saved.x, y = saved.y}
        end,
        setPosition = function(saved) mod:SaveBarPosition(saved) end,
        resetPosition = function() mod:ResetBarPosition() end,
        resetConfirm = L["BossMods_ResetAnchorPositionConfirm"]:format(L["BlessingsBar"]),
        resetConfirmTitle = L["ResetPosition"],
        isDisabled = barDisabled,
        showOffsets = true
    })

    local height = math.max(positionY, 1)
    parent:SetHeight(height)
    return {
        height = height,
        Refresh = function()
            tracker.refresh()
            position.Refresh()
        end,
        Release = function()
            position.Release()
            tracker.release()
        end
    }
end

local function createBarPanel(parent, mod, isDisabled)
    local panel = {frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")}
    E:SetTemplate(panel.frame, "Transparent")
    local inner = CreateFrame("Frame", nil, panel.frame)
    inner:SetPoint("TOPLEFT", panel.frame, "TOPLEFT", 0, -BAR_PAD)
    local header = T:Header(inner, {text = L["BlessingsBar"]})
    local body = CreateFrame("Frame", nil, inner)
    local handle, builtWidth

    function panel.Layout(width)
        panel.frame:SetWidth(width)
        inner:SetWidth(width)
        local top = T:PlaceFull(inner, header, 0, width) + 6
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", inner, "TOPLEFT", 0, -top)
        body:SetWidth(width)
        if not builtWidth or math.abs(builtWidth - width) >= 0.5 then
            if handle and handle.Release then handle.Release() end
            builtWidth = width
            handle = buildBarBody(body, mod, isDisabled)
        end
        local height = top + (handle and handle.height or 1)
        inner:SetHeight(height)
        panel.frame:SetHeight(height + BAR_PAD * 2)
        return height + BAR_PAD * 2
    end

    function panel.Refresh()
        if handle and handle.Refresh then handle.Refresh() end
    end

    return panel
end

local function createView(parent, mod, isDisabled)
    local view = {mod = mod, enabled = true}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(1)
    view.frame = frame

    local grid = createCard(frame)
    grid:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    local band = grid:CreateTexture(nil, "BORDER")
    local columns = #mod.CLASSES + 1
    local gridMinW = PAD * 2 + NAME_MIN + AURA_GAP + columns * CELL_MIN + (columns - 1) * GAP_MIN
    local heads, rows = {}, {}
    local auraLabel = font(grid, 12, "CENTER")
    auraLabel:SetTextColor(DIM[1], DIM[2], DIM[3])
    auraLabel:SetText(L["BlessingsAura"])
    local empty = font(grid, 13)
    empty:SetTextColor(DIM[1], DIM[2], DIM[3])
    empty:SetText(L["BlessingsNoPaladins"])
    empty:SetPoint("TOPLEFT", PAD, -PAD - 4)
    local divider = grid:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.08)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 1, FOOTER_H)
    divider:SetPoint("BOTTOMRIGHT", -1, FOOTER_H)

    local clearButton = T:Button(grid, {
        text = L["BlessingsClear"],
        height = BUTTON_H,
        tooltip = {title = L["BlessingsClear"], desc = L["BlessingsClearDesc"]},
        confirm = L["BlessingsClearConfirm"],
        confirmTitle = L["BlessingsClear"],
        onClick = function() mod:ClearAll() end,
        disabled = function() return not view.enabled end
    })
    clearButton.frame:SetPoint("BOTTOMRIGHT", grid, "BOTTOMRIGHT", -PAD, (FOOTER_H - BUTTON_H) / 2)
    local refreshButton = T:Button(grid, {
        text = L["BlessingsRefresh"],
        height = BUTTON_H,
        tooltip = {title = L["BlessingsRefresh"], desc = L["BlessingsRefreshDesc"]},
        onClick = function() mod:RequestPlans() end,
        disabled = function() return not view.enabled or not IsInGroup() end
    })
    refreshButton.frame:SetPoint("RIGHT", clearButton.frame, "LEFT", -6, 0)
    local autoButton = T:Button(grid, {
        text = L["BlessingsAuto"],
        height = BUTTON_H,
        tooltip = {title = L["BlessingsAuto"], desc = L["BlessingsAutoDesc"]},
        confirm = function() return mod:HasAssignments() and L["BlessingsAutoConfirm"] or nil end,
        confirmTitle = L["BlessingsAuto"],
        onClick = function() mod:AutoAssign() end,
        disabled = function() return not view.enabled or #mod:AutoPlanners() == 0 end
    })
    autoButton.frame:SetPoint("BOTTOMLEFT", grid, "BOTTOMLEFT", PAD, (FOOTER_H - BUTTON_H) / 2)

    local players = createCard(frame)
    local playersTitle = font(players, 13)
    playersTitle:SetPoint("LEFT", players, "TOPLEFT", PAD + 6, -(PAD + TAB + 8 + PLAYER_HEAD_H / 2))
    local tabs, playerHeads, playerRows = {}, {}, {}
    local barPanel = createBarPanel(frame, mod, isDisabled or function() return false end)

    local signature, builtWidth
    local sync

    local function selectClass(classIndex)
        if selectedClass == classIndex then return end
        selectedClass = classIndex
        hideMenu()
        if E.OptionsUI and E.OptionsUI.QueueRefresh then
            E.OptionsUI:QueueRefresh("current")
        else
            sync()
        end
    end

    local function classButton(parent, i)
        local tile = createTile(parent)
        tile.icon:SetTexture(mod.CLASS_ICONS[mod.CLASSES[i]])
        tile.badge:SetTextColor(1, 1, 1)
        tile:SetScript("OnClick", function()
            if (mod:ClassCounts()[i] or 0) == 0 then return end
            PlaySound(CLICK_SOUND)
            selectClass(i)
        end)
        tile:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(className(mod, i))
            GameTooltip:Show()
        end)
        tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return tile
    end

    for i = 1, #mod.CLASSES do
        heads[i] = classButton(grid, i)
        tabs[i] = classButton(players, i)
        tabs[i].tab = true
        tabs[i]:SetSize(TAB, TAB)
    end

    local function gridRow(index)
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, grid)
            row.name = font(row, 14)
            row.status = font(row, 10)
            row.status:SetTextColor(DIM[1], DIM[2], DIM[3])
            row.status:SetText(L["BlessingsNoReply"])
            row.status:SetPoint("LEFT", row, "LEFT", 0, -8)
            row.cells = {}
            for i = 1, columns do row.cells[i] = createCell(row, view) end
            rows[index] = row
        end
        row:Show()
        return row
    end

    local function playerRow(index)
        local row = playerRows[index]
        if not row then
            row = CreateFrame("Frame", nil, players)
            row.stripe = row:CreateTexture(nil, "BACKGROUND")
            row.stripe:SetAllPoints()
            row.stripe:SetColorTexture(1, 1, 1, 0.04)
            row.name = font(row, 13)
            row.name:SetPoint("LEFT", 6, 0)
            row.cells = {}
            playerRows[index] = row
        end
        row.stripe:SetShown(index % 2 == 1)
        row:Show()
        return row
    end

    local function structure(paladins, members, counts)
        local bits = {tostring(selectedClass)}
        for i = 1, #mod.CLASSES do bits[#bits + 1] = (counts[i] or 0) > 0 and "1" or "0" end
        for _, paladin in ipairs(paladins) do bits[#bits + 1] = paladin.name end
        bits[#bits + 1] = mod:IsPaladin() and "|bar" or "|"
        for _, member in ipairs(members) do bits[#bits + 1] = member.name end
        return table.concat(bits, "\031")
    end

    local function layoutGrid(width, paladins)
        local inner = width - PAD * 2
        local room = inner - NAME_MIN - AURA_GAP
        local size = clamp(math.floor((room - (columns - 1) * GAP_MIN) / columns), CELL_MIN, CELL_MAX)
        local gap = clamp(math.floor((room - columns * size) / (columns - 1)), GAP_MIN, GAP_MAX)
        local nameW = clamp(inner - AURA_GAP - columns * size - (columns - 1) * gap, NAME_MIN, NAME_MAX)
        local gridW = PAD * 2 + nameW + AURA_GAP + columns * size + (columns - 1) * gap
        local function colX(i)
            return nameW + (i - 1) * (size + gap) + (i == columns and AURA_GAP or 0)
        end

        local hasPaladins = #paladins > 0
        empty:SetShown(not hasPaladins)
        auraLabel:SetShown(hasPaladins)
        for i, head in ipairs(heads) do
            head:SetShown(hasPaladins)
            head:SetSize(size, size)
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", grid, "TOPLEFT", PAD + colX(i), -PAD)
        end
        auraLabel:ClearAllPoints()
        auraLabel:SetPoint("CENTER", grid, "TOPLEFT", PAD + colX(columns) + size / 2, -(PAD + size / 2))

        local y = PAD
        if hasPaladins then
            y = y + size + HEAD_GAP
            for index, paladin in ipairs(paladins) do
                local row = gridRow(index)
                row.paladin = paladin.name
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", grid, "TOPLEFT", PAD, -y)
                row:SetSize(inner, size)
                row.name:SetWidth(nameW - 10)
                row.status:SetWidth(nameW - 10)
                row.name:SetText(paladinText(paladin.name))
                for i, cell in ipairs(row.cells) do
                    cell:SetSize(size, size)
                    cell:ClearAllPoints()
                    cell:SetPoint("LEFT", row, "LEFT", colX(i), 0)
                    if i == columns then
                        cell.spec = {kind = "aura", paladin = paladin.name}
                    else
                        cell.spec = {kind = "class", paladin = paladin.name, classIndex = i}
                    end
                end
                y = y + size + ROW_GAP
            end
            y = y - ROW_GAP
        else
            y = y + 24
        end
        for index = #paladins + 1, #rows do rows[index]:Hide() end

        if hasPaladins and selectedClass then
            band:ClearAllPoints()
            band:SetPoint("TOPLEFT", grid, "TOPLEFT", PAD + colX(selectedClass) - gap / 2, -(PAD - gap / 2))
            band:SetSize(size + gap, y - PAD + gap)
            local a = accent()
            band:SetColorTexture(a[1], a[2], a[3], 0.12)
            band:Show()
        else
            band:Hide()
        end

        grid:SetWidth(gridW)
        return gridW, y + PAD + FOOTER_H
    end

    local function layoutPlayers(width, paladins, members, counts)
        local inner = width - PAD * 2
        local count = math.max(1, #paladins)
        local pitch = clamp(math.floor((inner - PLAYER_NAME_MIN) / count), 24, PLAYER_PITCH_MAX)
        local size = math.min(PLAYER_CELL, pitch - 4)
        local nameW = inner - count * pitch

        local x = PAD
        for i, tab in ipairs(tabs) do
            local present = (counts[i] or 0) > 0
            tab:SetShown(present)
            if present then
                tab:ClearAllPoints()
                tab:SetPoint("TOPLEFT", players, "TOPLEFT", x, -PAD)
                x = x + TAB + TAB_GAP
            end
        end

        local y = PAD + TAB + 8
        playersTitle:SetWidth(nameW - 8)
        for index, paladin in ipairs(paladins) do
            local head = playerHeads[index]
            if not head then
                head = font(players, 11, "CENTER")
                playerHeads[index] = head
            end
            head:SetWidth(pitch - 2)
            head:SetText(paladinText(paladin.name))
            head:ClearAllPoints()
            head:SetPoint("CENTER", players, "TOPLEFT", PAD + nameW + (index - 0.5) * pitch, -(y + PLAYER_HEAD_H / 2))
            head:Show()
        end
        for index = #paladins + 1, #playerHeads do playerHeads[index]:Hide() end

        y = y + PLAYER_HEAD_H + 4
        for index, member in ipairs(members) do
            local row = playerRow(index)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", players, "TOPLEFT", PAD, -y)
            row:SetSize(inner, size + 4)
            row.name:SetWidth(nameW - 12)
            row.name:SetText(E:ClassColorCode(member.class) .. shortName(member.name) .. "|r")
            for p, paladin in ipairs(paladins) do
                local cell = row.cells[p]
                if not cell then
                    cell = createCell(row, view)
                    row.cells[p] = cell
                end
                cell:SetSize(size, size)
                cell:ClearAllPoints()
                cell:SetPoint("CENTER", row, "LEFT", nameW + (p - 0.5) * pitch, 0)
                cell.spec = {
                    kind = "player", paladin = paladin.name, member = member,
                    classIndex = mod.CLASS_INDEX[member.class]
                }
                cell:Show()
            end
            for p = #paladins + 1, #row.cells do row.cells[p]:Hide() end
            y = y + size + 4
        end
        for index = #members + 1, #playerRows do playerRows[index]:Hide() end

        players:SetWidth(width)
        return y + PAD
    end

    local function layout(width, paladins, members, counts)
        hideMenu()
        local showPlayers = #paladins > 0 and selectedClass ~= nil
        local showBar = mod:IsPaladin()
        players:SetShown(showPlayers)
        players:ClearAllPoints()
        barPanel.frame:SetShown(showBar)
        barPanel.frame:ClearAllPoints()

        local need = math.max(PLAYERS_MIN_W, PAD * 2 + PLAYER_NAME_MIN + #paladins * PLAYER_PITCH_MIN)
        local most = math.max(need, PLAYERS_MAX_W)
        local side = showPlayers and width - CARD_GAP - gridMinW >= need
        local total
        if side then
            local playersW = clamp(math.floor(width * 0.3), need, most)
            local gridW, gridH = layoutGrid(width - CARD_GAP - playersW, paladins)
            playersW = clamp(width - CARD_GAP - gridW, need, most)
            local playersH = layoutPlayers(playersW, paladins, members, counts)
            local left = gridH
            if showBar then
                barPanel.frame:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -CARD_GAP)
                left = left + CARD_GAP + barPanel.Layout(gridW)
            end
            total = math.max(left, playersH)
            players:SetPoint("TOPLEFT", grid, "TOPRIGHT", CARD_GAP, 0)
            players:SetHeight(total)
            grid:SetHeight(gridH)
        else
            local _, gridH = layoutGrid(width, paladins)
            grid:SetWidth(width)
            grid:SetHeight(gridH)
            total = gridH
            local above = grid
            if showPlayers then
                local hug = math.max(PLAYERS_MIN_W, PAD * 2 + PLAYER_NAME_MAX + #paladins * PLAYER_PITCH_MAX)
                local playersH = layoutPlayers(math.min(width, hug), paladins, members, counts)
                players:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -CARD_GAP)
                players:SetHeight(playersH)
                total = total + CARD_GAP + playersH
                above = players
            end
            if showBar then
                barPanel.frame:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -CARD_GAP)
                total = total + CARD_GAP + barPanel.Layout(math.min(width, BAR_MAX_W))
            end
        end
        frame:SetHeight(total)
        view.height = total
    end

    local function paint(paladins, counts)
        for i, head in ipairs(heads) do
            local count = counts[i] or 0
            head.badge:SetText(count > 0 and count or "")
            head.icon:SetDesaturated(count == 0)
            head.icon:SetAlpha(count == 0 and 0.35 or 1)
            local color = selectedClass == i and accent() or E.media.borderColor
            head:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        end
        for index = 1, #paladins do
            local row = rows[index]
            local heard = paladins[index].plan.heard
            row.status:SetShown(not heard)
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row, "LEFT", 0, heard and 0 or 5)
            row.name:SetAlpha(heard and 1 or 0.6)
            for _, cell in ipairs(row.cells) do paintCell(cell) end
        end
        for _, row in ipairs(playerRows) do
            if row:IsShown() then
                for _, cell in ipairs(row.cells) do
                    if cell:IsShown() then paintCell(cell) end
                end
            end
        end
        for i, tab in ipairs(tabs) do
            local on = selectedClass == i
            local color = on and accent() or E.media.borderColor
            tab:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            tab.icon:SetDesaturated(not on)
            tab.icon:SetAlpha(on and 1 or 0.6)
        end
        if selectedClass then playersTitle:SetText(className(mod, selectedClass)) end
        autoButton.Refresh()
        clearButton.Refresh()
        refreshButton.Refresh()
        barPanel.Refresh()
    end

    sync = function()
        local width = frame:GetWidth() or 0
        if width <= 0 then return end
        view.enabled = not (isDisabled and isDisabled())
        local paladins = mod:GetPaladins()
        local counts = mod:ClassCounts()
        if not selectedClass or (counts[selectedClass] or 0) == 0 then
            selectedClass = nil
            for i = 1, #mod.CLASSES do
                if (counts[i] or 0) > 0 then
                    selectedClass = i
                    break
                end
            end
        end
        local members = selectedClass and mod:MembersOfClass(selectedClass) or {}
        local now = structure(paladins, members, counts)
        if now ~= signature or not builtWidth or math.abs(builtWidth - width) >= 0.5 then
            signature, builtWidth = now, width
            layout(width, paladins, members, counts)
        end
        paint(paladins, counts)
    end
    view.Sync = sync

    frame:SetScript("OnShow", function() mod:SetBarPlacing(true) end)
    frame:SetScript("OnHide", function()
        hideMenu()
        mod:SetBarPlacing(false)
    end)
    if frame:IsVisible() then mod:SetBarPlacing(true) end
    return view
end

local function isDisabled()
    local mod = E:GetModule("Blessings", true)
    return not (mod and mod:IsEnabled())
end

local function buildPage(parent)
    local view = createView(parent, E:GetModule("Blessings"), isDisabled)
    local widget = {frame = view.frame, height = 1, fullWidth = true}

    local function sync()
        view.Sync()
        widget.height = view.height or 1
    end
    widget._relayout = sync
    widget.Refresh = sync
    return widget
end

local function buildPanel()
    return {
        type = "group",
        name = L["Blessings"],
        args = {
            desc = {order = 1, width = "full", build = function(parent)
                return T:Description(parent, {text = L["BlessingsDesc"], sizeDelta = 1})
            end},
            page = {order = 10, width = "full", build = buildPage}
        }
    }
end

if E:IsForeverClient() then
    E:RegisterOptions("Blessings", 35, buildPanel)
    local events = E:NewCallbackHandle()
    events:RegisterMessage("ART_BLESSINGS_UPDATED", function()
        local ui = E.OptionsUI
        if ui and ui.currentKey == "Blessings" and ui.QueueRefresh and ui.IsShown and ui:IsShown() then
            ui:QueueRefresh("current")
        end
    end)
end
