local E, L = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local c_textDim = P.c_textDim
local c_text = P.c_text
local c_border = P.c_border
local c_accent = P.c_accent
local c_backdrop = P.c_backdrop
local newFont = P.newFont
local measureStringWidth = P.measureStringWidth
local shallowCopy = P.shallowCopy
local safeCall = P.safeCall
local evalMaybeFn = P.evalMaybeFn
local setTemplate = P.setTemplate
local attachTooltip = P.attachTooltip

-- =============================================================================
-- Template: Dropdown
-- -----------------------------------------------------------------------------
-- opts = {
--     label       = "Label" | nil,
--     values      = { key = displayLabel, ... } | function,
--     sorting     = { "keyA", "keyB", ... } | nil,       -- explicit order
--     multi       = false,                               -- multi-select mode
--     get         = function(keyIfMulti) return value end,
--                   -- single: returns the currently selected key (or nil)
--                   -- multi:  returns bool for whether `keyIfMulti` is selected
--     onChange    = function(key, newBoolIfMulti) end,
--                   -- single: called with new key
--                   -- multi:  called with (key, newSelectedBool)
--     disabled    = bool | function,
--     tooltip     = "desc" | {title, desc} | function,
--     buttonHeight= 20,
--     height      = 40,   -- full container height (label + button)
--     maxPulloutH = 220,
-- }
--
-- Returns {
--     frame, height, button,
--     SetLabel(t), SetDisabled(d),
--     Refresh(),
--     GetNaturalWidth(),    -- measures widest value for layout
-- }
-- =============================================================================

local dropdownPullout
local function getDropdownPullout()
    if dropdownPullout then
        return dropdownPullout
    end

    local p = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    E:SetTemplate(p, "Default")
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetClampedToScreen(true)
    p:Hide()

    -- full-screen blocker so clicking anywhere outside closes the dropdown
    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("FULLSCREEN")
    blocker:Hide()
    blocker:SetScript("OnMouseDown", function()
        p:Hide()
    end)
    p._blocker = blocker

    p:HookScript("OnShow", function()
        blocker:Show()
        local bg = E.media and E.media.backdropColor
        if bg then
            p:SetBackdropColor(bg[1], bg[2], bg[3], 1)
        end
    end)
    p:HookScript("OnHide", function()
        blocker:Hide()
        if p._owner and p._owner._highlight then
            p._owner:SetBackdropBorderColor(unpack(c_border()))
        end
        p._owner = nil
    end)

    local sfInstance = T:ScrollFrame(p, {
        chrome = false,
        insets = {4, 4, 4, 4},
        mouseWheelStep = 18
    })
    sfInstance.frame:SetPoint("TOPLEFT", 4, -4)
    sfInstance.frame:SetPoint("BOTTOMRIGHT", -4, 4)
    p._scroll = sfInstance.scroll
    p._content = sfInstance.content
    p._scrollInstance = sfInstance

    p._rowPool = {}
    p._createRow = function()
        local row = CreateFrame("Button", nil, p._content)
        row:SetHeight(18)
        row:EnableMouse(true)

        local check = row:CreateTexture(nil, "OVERLAY")
        check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
        check:SetDesaturated(true)
        check:SetSize(14, 14)
        check:SetPoint("LEFT", 2, 0)
        E:RegisterAccentTexture(check)
        check:Hide()
        row._check = check

        local fs = newFont(row, 0)
        fs:SetTextColor(unpack(c_text()))
        fs:SetPoint("LEFT", check, "RIGHT", 4, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row._text = fs

        local hi = row:CreateTexture(nil, "HIGHLIGHT")
        hi:SetColorTexture(c_accent()[1], c_accent()[2], c_accent()[3], 0.25)
        hi:SetAllPoints()

        return row
    end

    dropdownPullout = p
    return p
end

-- order entries table honoring opts.sorting first, then anything else alphabetically
local function orderDropdownKeys(vals, sorting)
    local keys = {}
    if type(sorting) == "table" then
        for _, k in ipairs(sorting) do
            if vals[k] ~= nil then
                keys[#keys + 1] = k
            end
        end
        -- append any leftovers not explicitly listed
        for k in pairs(vals) do
            local found
            for _, sk in ipairs(sorting) do
                if sk == k then
                    found = true;
                    break
                end
            end
            if not found then
                keys[#keys + 1] = k
            end
        end
    else
        for k in pairs(vals) do
            keys[#keys + 1] = k
        end
        table.sort(keys, function(a, b)
            return tostring(vals[a]) < tostring(vals[b])
        end)
    end
    return keys
end

function T:Dropdown(parent, opts)
    opts = shallowCopy(opts)
    local multi = opts.multi and true or false
    local buttonH = opts.buttonHeight or 20
    local labelH = opts.label and 16 or 0
    local containerH = opts.height or (labelH + buttonH + 4)

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(containerH)

    local labelFS
    if opts.label then
        labelFS = newFont(container, 0)
        labelFS:SetTextColor(unpack(c_text()))
        labelFS:SetPoint("TOPLEFT", 0, 0)
        labelFS:SetPoint("TOPRIGHT", 0, 0)
        labelFS:SetJustifyH("LEFT")
        labelFS:SetWordWrap(false)
        labelFS:SetText(opts.label)
    end

    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    setTemplate(btn, "Default")
    btn:SetPoint("TOPLEFT", 0, -labelH)
    btn:SetPoint("TOPRIGHT", 0, -labelH)
    btn:SetHeight(buttonH)

    local text = newFont(btn, 0)
    text:SetTextColor(1, 1, 1)
    text:SetPoint("LEFT", 4, 0)
    text:SetPoint("RIGHT", -18, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture([[Interface\ChatFrame\ChatFrameExpandArrow]])
    arrow:SetDesaturated(true)
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -2, 0)
    E:RegisterAccentTexture(arrow)

    local state = {
        disabled = false
    }
    local _widestCache

    local function resolveValues()
        return evalMaybeFn(opts.values) or {}
    end

    local function currentDisplayText()
        local vals = resolveValues()
        if multi then
            local bits = {}
            for key, lbl in pairs(vals) do
                if opts.get and opts.get(key) then
                    bits[#bits + 1] = tostring(lbl)
                end
            end
            if #bits == 0 then
                return opts.placeholder or ""
            end
            table.sort(bits)
            return table.concat(bits, ", ")
        else
            local cur = opts.get and opts.get()
            local lbl = cur ~= nil and vals[cur] or nil
            if lbl == nil then
                return opts.placeholder or ""
            end
            return tostring(lbl)
        end
    end

    local function isShowingPlaceholder()
        if multi then
            for key in pairs(resolveValues()) do
                if opts.get and opts.get(key) then
                    return false
                end
            end
            return true
        end
        local cur = opts.get and opts.get()
        if cur == nil then
            return true
        end
        return resolveValues()[cur] == nil
    end

    local function applyDisplayText()
        text:SetText(currentDisplayText())
        if isShowingPlaceholder() then
            text:SetTextColor(0.55, 0.55, 0.55)
        else
            text:SetTextColor(1, 1, 1)
        end
    end

    btn:SetScript("OnClick", function(self)
        if state.disabled then
            return
        end
        local p = getDropdownPullout()
        if p:IsShown() and p._owner == self then
            p:Hide()
            return
        end

        local vals = resolveValues()
        local keys = orderDropdownKeys(vals, opts.sorting)

        for _, r in ipairs(p._rowPool) do
            r:Hide()
        end

        local y = 0

        if #keys == 0 then
            local row = p._rowPool[1]
            if not row then
                row = p._createRow()
                p._rowPool[1] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", p._content, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", p._content, "TOPRIGHT", 0, 0)
            row._text:SetText(opts.emptyText or "(" .. L["None"] .. ")")
            row._text:SetTextColor(0.55, 0.55, 0.55)
            row._check:Hide()
            row:SetScript("OnClick", nil)
            row:EnableMouse(false)
            row:Show()
            y = 18
        else
            for i, k in ipairs(keys) do
                local row = p._rowPool[i]
                if not row then
                    row = p._createRow()
                    p._rowPool[i] = row
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", p._content, "TOPLEFT", 0, -y)
                row:SetPoint("TOPRIGHT", p._content, "TOPRIGHT", 0, -y)
                row._text:SetText(tostring(vals[k] or k))
                row._text:SetTextColor(unpack(c_text()))
                row:EnableMouse(true)

                local isSelected
                if multi then
                    isSelected = opts.get and opts.get(k) and true or false
                else
                    isSelected = (opts.get and opts.get() == k)
                end
                if isSelected then
                    row._check:Show()
                else
                    row._check:Hide()
                end

                row:SetScript("OnClick", function()
                    if multi then
                        local cur = opts.get and opts.get(k)
                        safeCall("Dropdown.onChange", opts.onChange, k, not cur)
                        if cur then
                            row._check:Hide()
                        else
                            row._check:Show()
                        end
                        applyDisplayText()
                    else
                        safeCall("Dropdown.onChange", opts.onChange, k)
                        applyDisplayText()
                        p:Hide()
                    end
                end)
                row:Show()
                y = y + 18
            end
        end
        p._content:SetSize(self:GetWidth(), math.max(1, y))
        if p._scrollInstance and p._scrollInstance.scrollbar then
            p._scrollInstance.scrollbar.Refresh()
        end

        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        p:SetWidth(self:GetWidth())

        local maxH = opts.maxPulloutH or 220
        p:SetHeight(math.min(maxH, y + 8))
        p._owner = self
        p:Show()
        self:SetBackdropBorderColor(unpack(c_accent()))
        self._highlight = true
    end)

    btn:SetScript("OnEnter", function(self)
        if not state.disabled then
            self:SetBackdropBorderColor(unpack(c_accent()))
            self._highlight = true
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local p = dropdownPullout
        if not state.disabled and not (p and p:IsShown() and p._owner == self) then
            self:SetBackdropBorderColor(unpack(c_border()))
            self._highlight = false
        end
    end)

    if opts.tooltip then
        attachTooltip(btn, opts.tooltip, opts.tooltipAnchor or "ANCHOR_CURSOR")
    end

    local function SetDisabled(d)
        state.disabled = d and true or false
        btn:EnableMouse(not state.disabled)
        if state.disabled then
            if labelFS then
                labelFS:SetTextColor(unpack(c_textDim()))
            end
            text:SetTextColor(unpack(c_textDim()))
            arrow:SetVertexColor(unpack(c_textDim()))
            btn:SetBackdropBorderColor(unpack(c_textDim()))
        else
            if labelFS then
                labelFS:SetTextColor(unpack(c_text()))
            end
            text:SetTextColor(1, 1, 1)
            arrow:SetVertexColor(unpack(c_accent()))
            btn:SetBackdropBorderColor(unpack(c_border()))
        end
    end

    local _measureFS
    local function widestValueWidth()
        if _widestCache ~= nil then
            return _widestCache
        end
        if not _measureFS then
            _measureFS = newFont(container, 0)
            _measureFS:ClearAllPoints()
            _measureFS:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 10000)
            _measureFS:Hide()
        end
        local vals = resolveValues()
        local widest = 0
        if type(vals) == "table" then
            for _, lbl in pairs(vals) do
                _measureFS:SetText(tostring(lbl or ""))
                local w = measureStringWidth(_measureFS)
                if w > widest then
                    widest = w
                end
            end
        end
        _widestCache = widest
        return widest
    end

    -- Initial paint
    applyDisplayText()
    SetDisabled(evalMaybeFn(opts.disabled, btn))

    return {
        frame = container,
        height = containerH,
        button = btn,
        SetLabel = function(t)
            if labelFS then
                labelFS:SetText(t or "")
            end
        end,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = function()
            applyDisplayText()
            _widestCache = nil
            SetDisabled(evalMaybeFn(opts.disabled, btn))
        end,
        GetNaturalWidth = function()
            local labelW = labelFS and measureStringWidth(labelFS) or 0
            local curW = measureStringWidth(text)
            local optionsW = widestValueWidth()
            local contentW = math.max(optionsW, curW)
            local btnW = contentW + 22
            return math.max(120, math.max(labelW, btnW))
        end
    }
end

function T:HideDropdownPullout()
    if dropdownPullout and dropdownPullout:IsShown() then
        dropdownPullout:Hide()
    end
end

-- =============================================================================
-- Template: TabBar
-- -----------------------------------------------------------------------------
-- opts = {
--     tabs        = { { key = "...", label = "..." }, ... },   -- required
--     height      = 24,
--     minTabW     = 80,
--     tabPadX     = 16,                                        -- 8px each side
--     tabGap      = 2,
--     onTabChange = function(key, button) end,                 -- click handler
--     autoActivateFirst = true,                                -- activate tabs[1] at build time
-- }
--
-- Returns {
--     frame, height, tabs (array), buttons (map by key),
--     ActivateTab(key)     -- programmatically select a tab (fires onTabChange)
--     GetActiveKey()       -- key of currently active tab
--     SetTabLabel(key, s)  -- change a tab's label (also resizes the button)
--     ReapplyHighlight()   -- re-apply accent/bg colors after media changes
-- }
-- =============================================================================
function T:TabBar(parent, opts)
    opts = shallowCopy(opts)
    local H = opts.height or 24
    local MIN_W = opts.minTabW or 80
    local PAD_X = opts.tabPadX or 16
    local GAP = opts.tabGap or 2
    local onTabChange = opts.onTabChange

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(H)

    local buttons = {}
    local tabs = {}
    local activeKey

    local function paintButton(btn, active)
        if active then
            local ac = c_accent()
            btn:SetBackdropColor(ac[1], ac[2], ac[3], 0.35)
            btn._label:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(unpack(c_backdrop()))
            btn._label:SetTextColor(unpack(c_text()))
        end
    end

    local function ActivateTab(key)
        if activeKey == key then
            return false
        end
        local oldKey = activeKey
        activeKey = key
        if oldKey and buttons[oldKey] then
            paintButton(buttons[oldKey], false)
        end
        if buttons[key] then
            paintButton(buttons[key], true)
        end
        if onTabChange then
            local btn = buttons[key]
            safeCall("TabBar.onTabChange", onTabChange, key, btn, oldKey)
        end
        return true
    end

    local function restack()
        local xx = 0
        for _, t in ipairs(tabs) do
            local textW = measureStringWidth(t.button._label)
            local tabW = math.max(MIN_W, math.ceil(textW) + PAD_X)
            t.button:SetWidth(tabW)
            t.button:ClearAllPoints()
            t.button:SetPoint("LEFT", xx, 0)
            xx = xx + tabW + GAP
        end
    end

    local x = 0
    for _, def in ipairs(opts.tabs or {}) do
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        setTemplate(btn, "Default")

        local label = newFont(btn, 0)
        label:SetTextColor(unpack(c_text()))
        label:SetPoint("CENTER")
        label:SetText(tostring(def.label or ""))
        btn._label = label
        btn._tabKey = def.key

        local textW = measureStringWidth(label)
        local tabW = math.max(MIN_W, math.ceil(textW) + PAD_X)
        btn:SetSize(tabW, H)
        btn:SetPoint("LEFT", x, 0)
        x = x + tabW + GAP

        btn:SetScript("OnClick", function()
            ActivateTab(def.key)
        end)
        btn:SetScript("OnEnter", function(self_)
            self_:SetBackdropBorderColor(unpack(c_accent()))
        end)
        btn:SetScript("OnLeave", function(self_)
            self_:SetBackdropBorderColor(unpack(c_border()))
        end)

        buttons[def.key] = btn
        tabs[#tabs + 1] = {
            key = def.key,
            label = def.label,
            button = btn
        }
    end

    frame:HookScript("OnShow", function(self_)
        C_Timer.After(0, function()
            if self_:IsShown() then
                restack()
            end
        end)
    end)

    for _, t in ipairs(tabs) do
        paintButton(t.button, false)
    end

    if opts.autoActivateFirst ~= false and tabs[1] then
        ActivateTab(tabs[1].key)
    end

    return {
        frame = frame,
        height = H,
        tabs = tabs,
        buttons = buttons,
        ActivateTab = ActivateTab,
        GetActiveKey = function()
            return activeKey
        end,
        SetTabLabel = function(key, text)
            local btn = buttons[key]
            if not btn then
                return
            end
            btn._label:SetText(tostring(text or ""))
            restack()
        end,
        Relayout = restack,
        ReapplyHighlight = function()
            for _, t in ipairs(tabs) do
                paintButton(t.button, t.key == activeKey)
            end
        end
    }
end
