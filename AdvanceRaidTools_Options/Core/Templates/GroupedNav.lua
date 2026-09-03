local E, L = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local shallowCopy = P.shallowCopy
local evalMaybeFn = P.evalMaybeFn
local newFont = P.newFont
local c_textDim = P.c_textDim
local c_accent = P.c_accent
local setTemplate = P.setTemplate
local loc = P.loc

local function optionsResizeActive()
    return E.OptionsUI and E.OptionsUI.IsResizing and E.OptionsUI:IsResizing()
end

local function safeCall(label, fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        E:ChannelWarn("Options", "GroupedNav %s callback error: %s", label, a)
        return nil
    end

    return a, b, c
end

local function textForKey(key, fallback)
    if not key then
        return fallback or ""
    end

    return loc(key, fallback or key)
end

local function optionalTextForKey(key)
    if not key then
        return nil
    end

    local text = loc(key)
    if text == key then
        return nil
    end

    return text
end

local function sortNodes(a, b)
    if a.order ~= b.order then
        return a.order < b.order
    end

    if a.label ~= b.label then
        return a.label < b.label
    end

    return a.key < b.key
end

-- =============================================================================
-- Template: GroupedNavList
-- -----------------------------------------------------------------------------
-- A narrow, scrollable selector list with optional collapsible group headers.
-- Items without a group key render as plain rows; grouped items render below
-- their sorted group header.
--
-- opts = {
--     width, height, minHeight, fillViewport, rowHeight, rowGap, pad, indent,
--     items              = list | function -> list,
--     emptyText          = string | function,
--     collapsedState     = table keyed by group key,
--     defaultCollapsed   = false,
--
--     itemKey(item)      -> string,
--     itemLabel(item)    -> string,
--     itemOrder(item)    -> number,
--     itemEnabled(item)  -> bool,
--     itemSelected(item, selectedKey) -> bool,
--     onItemClick(item),
--     getItemToggle(item) -> bool,
--     onItemToggle(item, checked),
--     itemToggleDisabled(item) -> bool,
--
--     groupKey(item)     -> string|nil,
--     groupLabel(key, firstItem) -> string,
--     groupOrder(key, firstItem) -> number,
--     onGroupClick(group),
-- }
--
-- Returns {
--     frame, height, minHeight, fillViewport,
--     SetItems(list|function), GetItems(),
--     SetSelectedKey(key), GetSelectedKey(),
--     SetHeight(px),
--     Refresh(), _relayout(),
-- }
-- =============================================================================
function T:GroupedNavList(parent, opts)
    opts = shallowCopy(opts)

    local width = opts.width or 220
    local height = opts.height or 200
    local rowH = opts.rowHeight or 24
    local rowGap = opts.rowGap or 2
    local pad = opts.pad or 4
    local indent = opts.indent or 14
    local scrollbarWidth = opts.scrollbarWidth or 10
    local scrollbarGap = opts.scrollbarGap or 4
    local collapsedState = opts.collapsedState or {}
    local defaultCollapsed = opts.defaultCollapsed and true or false

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    setTemplate(frame, opts.template or "Transparent")
    frame:SetSize(width, height)

    local scroll = T:ScrollFrame(frame, {
        chrome = false,
        autoWidth = true,
        mouseWheelStep = opts.mouseWheelStep or (rowH + rowGap),
        scrollbarWidth = scrollbarWidth,
        scrollbarGap = scrollbarGap
    })
    scroll.frame:SetPoint("TOPLEFT", pad, -pad)
    scroll.frame:SetPoint("BOTTOMRIGHT", -pad, pad)

    local state = {
        itemsOpt = opts.items,
        selectedKey = nil,
        itemRows = {},
        groupRows = {},
        empty = nil
    }

    local function getItems()
        return evalMaybeFn(state.itemsOpt) or {}
    end

    local function itemKey(item)
        return safeCall("itemKey", opts.itemKey, item)
            or item.key
            or item.featureKey
            or tostring(item)
    end

    local function itemLabel(item)
        return safeCall("itemLabel", opts.itemLabel, item)
            or optionalTextForKey(item.navLabelKey)
            or item.navLabel
            or textForKey(item.labelKey, item.label or item.key)
    end

    local function itemOrder(item)
        return tonumber(safeCall("itemOrder", opts.itemOrder, item) or item.order) or 100
    end

    local function groupKey(item)
        local key = safeCall("groupKey", opts.groupKey, item)
            or item.groupKey
            or item.bossKey
        if key == "" then
            return nil
        end
        return key
    end

    local function groupLabel(key, item)
        return safeCall("groupLabel", opts.groupLabel, key, item)
            or item.groupLabel
            or optionalTextForKey(item.groupLabelKey)
            or optionalTextForKey(item.bossLabelKey)
            or item.bossName
            or key
    end

    local function groupOrder(key, item)
        return tonumber(
            safeCall("groupOrder", opts.groupOrder, key, item)
                or item.groupOrder
                or item.bossOrder
                or itemOrder(item)
        ) or 100
    end

    local function isItemEnabled(item)
        local enabled = safeCall("itemEnabled", opts.itemEnabled, item)
        if enabled == nil then
            enabled = true
        end
        return enabled and true or false
    end

    local function isItemSelected(item)
        local selected = safeCall("itemSelected", opts.itemSelected, item, state.selectedKey)
        if selected ~= nil then
            return selected and true or false
        end
        return itemKey(item) == state.selectedKey
    end

    local function buildRows()
        local groups = {}
        local nodes = {}

        for _, item in ipairs(getItems()) do
            if not safeCall("itemHidden", opts.itemHidden, item) then
                local key = itemKey(item)
                local gk = groupKey(item)

                if gk then
                    local group = groups[gk]
                    if not group then
                        group = {
                            key = tostring(gk),
                            label = groupLabel(gk, item),
                            order = groupOrder(gk, item),
                            firstItem = item,
                            items = {}
                        }
                        groups[gk] = group
                        nodes[#nodes + 1] = {
                            type = "group",
                            key = group.key,
                            label = group.label,
                            order = group.order,
                            group = group
                        }
                    end
                    group.items[#group.items + 1] = item
                else
                    nodes[#nodes + 1] = {
                        type = "item",
                        key = key,
                        label = itemLabel(item),
                        order = itemOrder(item),
                        item = item
                    }
                end
            end
        end

        for _, group in pairs(groups) do
            table.sort(group.items, function(a, b)
                local ao, bo = itemOrder(a), itemOrder(b)
                if ao ~= bo then
                    return ao < bo
                end

                local al, bl = itemLabel(a), itemLabel(b)
                if al ~= bl then
                    return al < bl
                end

                return itemKey(a) < itemKey(b)
            end)
        end

        table.sort(nodes, sortNodes)

        local rows = {}
        for _, node in ipairs(nodes) do
            if node.type == "group" then
                local group = node.group
                local collapsed = collapsedState[group.key]
                if collapsed == nil then
                    collapsed = defaultCollapsed
                end

                rows[#rows + 1] = {
                    type = "group",
                    key = group.key,
                    label = group.label,
                    count = #group.items,
                    collapsed = collapsed,
                    group = group
                }

                if not collapsed then
                    for _, item in ipairs(group.items) do
                        rows[#rows + 1] = {
                            type = "item",
                            item = item,
                            grouped = true
                        }
                    end
                end
            else
                rows[#rows + 1] = {
                    type = "item",
                    item = node.item
                }
            end
        end

        return rows
    end

    local function releaseRows(rows)
        for _, row in ipairs(rows) do
            row._hovered = nil
            row._pressed = nil
            row:Hide()
            row:ClearAllPoints()
        end
    end

    local function createItemRow()
        local row = CreateFrame("Button", nil, scroll.content)
        row:SetHeight(rowH)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        row._bg = bg

        local check = T:Checkbox(row, {
            text = "",
            get = function()
                return row._item and safeCall("getItemToggle", opts.getItemToggle, row._item) or false
            end,
            onChange = function(_, value)
                if row._item then
                    safeCall("onItemToggle", opts.onItemToggle, row._item, value)
                end
            end,
            disabled = function()
                return row._item and safeCall("itemToggleDisabled", opts.itemToggleDisabled, row._item) or false
            end
        })
        check.frame:SetPoint("LEFT", row, "LEFT", 4, 0)
        row._check = check

        local label = newFont(row, 0)
        label:SetPoint("LEFT", row, "LEFT", 28, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        row._label = label

        row:SetScript("OnClick", function(self)
            if self._check and self._check.frame and self._check.frame:IsMouseOver() then
                return
            end
            if self._item then
                safeCall("onItemClick", opts.onItemClick, self._item)
            end
        end)

        return row
    end

    local function paintGroupChrome(row)
        local ac = c_accent()
        local alpha = 0.12
        if row._pressed then
            alpha = 0.32
        elseif row._hovered then
            alpha = 0.22
        end
        row._bg:SetColorTexture(ac[1], ac[2], ac[3], alpha)
    end

    local function createGroupRow()
        local row = CreateFrame("Button", nil, scroll.content)
        row:SetHeight(rowH)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        row._bg = bg

        local arrow = newFont(row, 0)
        arrow:SetPoint("LEFT", row, "LEFT", 6, 0)
        arrow:SetWidth(10)
        arrow:SetJustifyH("CENTER")
        E:RegisterAccentText(arrow)
        row._arrow = arrow

        local label = newFont(row, 0)
        label:SetPoint("LEFT", row, "LEFT", 22, 0)
        label:SetPoint("RIGHT", row, "RIGHT", -36, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        E:RegisterAccentText(label)
        row._label = label

        local count = newFont(row, -1)
        count:SetTextColor(unpack(c_textDim()))
        count:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        count:SetJustifyH("RIGHT")
        row._count = count

        row:SetScript("OnEnter", function(self)
            self._hovered = true
            paintGroupChrome(self)
        end)
        row:SetScript("OnLeave", function(self)
            self._hovered = nil
            self._pressed = nil
            paintGroupChrome(self)
        end)
        row:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self._pressed = true
                paintGroupChrome(self)
            end
        end)
        row:SetScript("OnMouseUp", function(self)
            self._pressed = nil
            paintGroupChrome(self)
        end)
        row:SetScript("OnClick", function(self)
            local group = self._group
            if not group then
                return
            end
            PlaySound(856)

            local collapsed = collapsedState[group.key]
            if collapsed == nil then
                collapsed = defaultCollapsed
            end
            collapsedState[group.key] = not collapsed

            safeCall("onGroupClick", opts.onGroupClick, group)
            self._owner.Refresh()
        end)

        row._owner = state
        return row
    end

    local function paintItemRow(row, item)
        row._item = item

        local selected = isItemSelected(item)
        local enabled = isItemEnabled(item)

        if selected then
            local ac = c_accent()
            row._bg:SetColorTexture(ac[1], ac[2], ac[3], 0.35)
        else
            row._bg:SetColorTexture(0, 0, 0, 0)
        end

        row._label:SetText(itemLabel(item))
        row._label:SetTextColor(enabled and 1 or 0.55, enabled and 0.82 or 0.55, enabled and 0 or 0.55)

        if opts.getItemToggle or opts.onItemToggle then
            row._check.frame:Show()
            row._check.Refresh()
        else
            row._check.frame:Hide()
        end
    end

    local function paintGroupRow(row, entry)
        row._group = entry.group

        paintGroupChrome(row)
        row._arrow:SetText(entry.collapsed and "+" or "-")
        row._label:SetText(entry.label)
        row._count:SetText(("(%d)"):format(entry.count or 0))
    end

    local function showEmpty(text)
        if not state.empty then
            local desc = T:Description(scroll.content, {
                text = text,
                sizeDelta = 0
            })
            state.empty = desc
        end

        state.empty.frame:ClearAllPoints()
        state.empty.frame:SetPoint("TOPLEFT", 4, -4)
        state.empty.frame:SetPoint("TOPRIGHT", -4, -4)
        state.empty.SetText(text or "")
        state.empty.frame:Show()
        state.empty.Relayout()
        scroll.content:SetHeight(state.empty.frame:GetHeight() or 30)
    end

    local function hideEmpty()
        if state.empty then
            state.empty.frame:Hide()
        end
    end

    local function refresh()
        local savedScroll = scroll.scroll:GetVerticalScroll() or 0
        local rows = buildRows()

        releaseRows(state.itemRows)
        releaseRows(state.groupRows)
        hideEmpty()

        local itemIndex = 0
        local groupIndex = 0
        local visualSlot = 0

        for _, entry in ipairs(rows) do
            visualSlot = visualSlot + 1

            if entry.type == "group" then
                groupIndex = groupIndex + 1
                local row = state.groupRows[groupIndex]
                if not row then
                    row = createGroupRow()
                    state.groupRows[groupIndex] = row
                end

                row:SetParent(scroll.content)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, -(visualSlot - 1) * (rowH + rowGap))
                row:SetPoint("TOPRIGHT", scroll.content, "TOPRIGHT", 0, -(visualSlot - 1) * (rowH + rowGap))
                paintGroupRow(row, entry)
                row:Show()
            else
                itemIndex = itemIndex + 1
                local row = state.itemRows[itemIndex]
                if not row then
                    row = createItemRow()
                    state.itemRows[itemIndex] = row
                end

                local x = entry.grouped and indent or 0
                row:SetParent(scroll.content)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", x, -(visualSlot - 1) * (rowH + rowGap))
                row:SetPoint("TOPRIGHT", scroll.content, "TOPRIGHT", 0, -(visualSlot - 1) * (rowH + rowGap))
                paintItemRow(row, entry.item)
                row:Show()
            end
        end

        if #rows == 0 then
            showEmpty(tostring(evalMaybeFn(opts.emptyText) or ""))
        else
            local totalH = #rows * rowH + math.max(0, #rows - 1) * rowGap
            scroll.content:SetHeight(math.max(1, totalH))
        end

        scroll.scroll:UpdateScrollChildRect()
        scroll.scrollbar.Refresh()

        local maxScroll = math.max(0, (scroll.content:GetHeight() or 0) - (scroll.scroll:GetHeight() or 0))
        scroll.scroll:SetVerticalScroll(math.min(savedScroll, maxScroll))
    end

    state.Refresh = refresh

    local function relayout()
        local w = scroll.scroll:GetWidth()
        if w and w > 0 then
            scroll.content:SetWidth(w)
        end
        refresh()
    end

    scroll.scroll:HookScript("OnSizeChanged", function()
        if not optionsResizeActive() then
            relayout()
        end
    end)

    if E.OptionsUI and E.OptionsUI.AddResizeFlusher then
        E.OptionsUI:AddResizeFlusher(relayout, frame)
    end

    local api
    api = {
        frame = frame,
        height = height,
        minHeight = opts.minHeight,
        fillViewport = opts.fillViewport and true or false,
        scroll = scroll.scroll,
        content = scroll.content,
        SetItems = function(selfOrItems, maybeItems)
            local items = selfOrItems == api and maybeItems or selfOrItems
            state.itemsOpt = items
            refresh()
        end,
        GetItems = function()
            return getItems()
        end,
        SetSelectedKey = function(selfOrKey, maybeKey)
            local key = selfOrKey == api and maybeKey or selfOrKey
            state.selectedKey = key
            refresh()
        end,
        SetHeight = function(selfOrHeight, maybeHeight)
            local nextHeight = tonumber(selfOrHeight == api and maybeHeight or selfOrHeight)
            if not nextHeight or nextHeight <= 0 then
                return
            end
            height = nextHeight
            api.height = nextHeight
            frame:SetHeight(nextHeight)
            relayout()
        end,
        GetSelectedKey = function()
            return state.selectedKey
        end,
        Refresh = refresh,
        _relayout = relayout
    }
    return api
end
