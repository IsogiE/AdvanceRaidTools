local E = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local newFont = P.newFont
local measureStringWidth = P.measureStringWidth
local shallowCopy = P.shallowCopy
local applyTextColor = P.applyTextColor
local evalMaybeFn = P.evalMaybeFn
local setTemplate = P.setTemplate
local applyOpaqueTemplate = P.applyOpaqueTemplate

-- =============================================================================
-- Template: ScrollBar
-- -----------------------------------------------------------------------------
-- opts = {
--     width        = 12,     -- bar width (also button size)
--     step         = 20,     -- pixels per up/down button click
-- }
--
-- Returns {
--     frame,       -- outer Frame (caller anchors this)
--     width,
--     Refresh(),   -- recompute range + visibility from current content
--     IsShown(),
-- }
-- =============================================================================
function T:ScrollBar(parent, scrollFrame, opts)
    opts = opts or {}
    local width = opts.width or 12
    local step = opts.step or 20

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetWidth(width)

    local function makeArrowButton(rotation)
        local btn = CreateFrame("Button", nil, bar, "BackdropTemplate")
        btn:SetSize(width, width)
        setTemplate(btn, "Default")

        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetTexture([[Interface\ChatFrame\ChatFrameExpandArrow]])
        arrow:SetDesaturated(true)
        arrow:SetSize(8, 8)
        arrow:SetPoint("CENTER")
        arrow:SetRotation(rotation)
        E:RegisterAccentTexture(arrow)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(E.media.valueColor))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(E.media.borderColor))
        end)

        btn._arrow = arrow
        return btn
    end

    local upBtn = makeArrowButton(math.pi / 2)
    upBtn:SetPoint("TOP")

    local downBtn = makeArrowButton(-math.pi / 2)
    downBtn:SetPoint("BOTTOM")

    local track = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    track:SetPoint("TOPLEFT", upBtn, "BOTTOMLEFT", 0, -2)
    track:SetPoint("BOTTOMRIGHT", downBtn, "TOPRIGHT", 0, 2)
    setTemplate(track, "Transparent")

    local slider = CreateFrame("Slider", nil, track)
    slider:SetOrientation("VERTICAL")
    slider:SetAllPoints(track)
    slider:SetMinMaxValues(0, 1)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(false)
    slider:SetValue(0)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(E.media.blankTex)
    thumb:SetSize(width - 4, 30)
    E:RegisterAccentTexture(thumb)
    slider:SetThumbTexture(thumb)

    local MIN_THUMB_H = 20 -- don't let the thumb disappear on very long content

    local isSyncing = false

    local thumbHit = CreateFrame("Button", nil, bar)
    thumbHit:SetFrameLevel(slider:GetFrameLevel() + 5)
    thumbHit:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    thumbHit:Hide()

    local function layoutThumbHit()
        if not bar:IsShown() then
            thumbHit:Hide()
            return
        end
        local trackH = track:GetHeight() or 0
        local thumbH = thumb:GetHeight() or 0
        if trackH <= 0 or thumbH <= 0 then
            thumbHit:Hide()
            return
        end
        local minV, maxV = slider:GetMinMaxValues()
        local range = maxV - minV
        if range <= 0 then
            thumbHit:Hide()
            return
        end
        local value = slider:GetValue() or 0
        local pct = math.max(0, math.min(1, (value - minV) / range))
        local travel = math.max(0, trackH - thumbH)
        local yOff = math.floor(pct * travel)
        thumbHit:ClearAllPoints()
        thumbHit:SetSize(width - 4, thumbH)
        thumbHit:SetPoint("TOP", track, "TOP", 0, -yOff)
        thumbHit:Show()
    end

    local dragging = false
    local dragStartCursorY, dragStartValue
    local function endThumbDrag()
        if not dragging then
            return
        end
        dragging = false
        thumbHit:SetScript("OnUpdate", nil)
        layoutThumbHit()
    end
    thumbHit:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or dragging then
            return
        end
        local _, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        dragStartCursorY = cy / scale
        dragStartValue = slider:GetValue() or 0
        dragging = true
        self:SetScript("OnUpdate", function()
            local _, ncy = GetCursorPosition()
            local s = UIParent:GetEffectiveScale()
            local dy = (ncy / s) - dragStartCursorY
            local trackH = track:GetHeight() or 0
            local thumbH = thumb:GetHeight() or 0
            local travel = math.max(1, trackH - thumbH)
            local minV, maxV = slider:GetMinMaxValues()
            local range = maxV - minV
            if range <= 0 then
                return
            end
            local newVal = dragStartValue - dy * (range / travel)
            if newVal < minV then
                newVal = minV
            end
            if newVal > maxV then
                newVal = maxV
            end
            slider:SetValue(newVal)
        end)
    end)
    thumbHit:SetScript("OnMouseUp", endThumbDrag)
    thumbHit:SetScript("OnHide", endThumbDrag)

    local function updateHitRect()
        local trackH = track:GetHeight() or 0
        local thumbH = thumb:GetHeight() or 0
        if trackH <= 0 or thumbH <= 0 then
            slider:SetHitRectInsets(0, 0, 0, 0)
            layoutThumbHit()
            return
        end
        local minV, maxV = slider:GetMinMaxValues()
        local range = maxV - minV
        if range <= 0 then
            slider:SetHitRectInsets(0, 0, 0, 0)
            layoutThumbHit()
            return
        end
        local value = slider:GetValue() or 0
        local pct = math.max(0, math.min(1, (value - minV) / range))
        local travel = math.max(0, trackH - thumbH)
        local topInset = math.floor(pct * travel)
        local bottomInset = math.max(0, travel - topInset)
        slider:SetHitRectInsets(0, 0, topInset, bottomInset)
        layoutThumbHit()
    end

    local function refresh()
        local child = scrollFrame:GetScrollChild()
        if not child then
            bar:Hide()
            return
        end
        local contentH = child:GetHeight() or 0
        local viewportH = scrollFrame:GetHeight() or 0
        local maxScroll = math.max(0, contentH - viewportH)

        if maxScroll <= 0 then
            bar:Hide()
            scrollFrame:SetVerticalScroll(0)
            return
        end
        bar:Show()

        local trackH = track:GetHeight() or 0
        if trackH > 0 and contentH > 0 then
            local ratio = math.min(1, viewportH / contentH)
            local thumbH = math.max(MIN_THUMB_H, math.floor(trackH * ratio))
            thumbH = math.min(thumbH, trackH)
            thumb:SetSize(width - 4, thumbH)
            slider:SetThumbTexture(thumb)
        end

        isSyncing = true
        slider:SetMinMaxValues(0, maxScroll)
        slider:SetValue(math.min(scrollFrame:GetVerticalScroll() or 0, maxScroll))
        isSyncing = false
        updateHitRect()
    end

    local refreshPending = false
    local function scheduleRefresh()
        if refreshPending then
            return
        end
        refreshPending = true
        C_Timer.After(0, function()
            refreshPending = false
            refresh()
        end)
    end

    if E.OptionsUI and E.OptionsUI.AddResizeFlusher then
        E.OptionsUI:AddResizeFlusher(refresh)
    end

    slider:SetScript("OnValueChanged", function(_, value)
        if not isSyncing then
            scrollFrame:SetVerticalScroll(value)
        end
        updateHitRect()
    end)

    scrollFrame:HookScript("OnVerticalScroll", function(_, offset)
        if isSyncing then
            return
        end
        isSyncing = true
        local _, maxV = slider:GetMinMaxValues()
        slider:SetValue(math.min(math.max(0, offset or 0), maxV))
        isSyncing = false
    end)

    scrollFrame:HookScript("OnScrollRangeChanged", scheduleRefresh)
    scrollFrame:HookScript("OnSizeChanged", scheduleRefresh)
    bar:HookScript("OnSizeChanged", scheduleRefresh)

    local function scrollBy(delta)
        local _, maxV = slider:GetMinMaxValues()
        local current = scrollFrame:GetVerticalScroll() or 0
        scrollFrame:SetVerticalScroll(math.max(0, math.min(maxV, current + delta)))
    end
    upBtn:SetScript("OnClick", function()
        scrollBy(-step)
    end)
    downBtn:SetScript("OnClick", function()
        scrollBy(step)
    end)

    refresh()
    scheduleRefresh() -- first paint with proper dimensions after layout settles

    return {
        frame = bar,
        width = width,
        Refresh = refresh,
        IsShown = function()
            return bar:IsShown()
        end
    }
end

-- =============================================================================
-- Template: ScrollFrame
-- -----------------------------------------------------------------------------
-- opts = {
--     height              = nil,          -- if set, applied to the outer frame
--     mouseWheelStep      = 20,           -- pixels per wheel notch
--     insets              = {l,t,r,b},    -- inner padding around scroll viewport
--     template            = "Default"|"Transparent"|"Opaque",
--     chrome              = true,         -- outer gets BackdropTemplate + template
--     minContentWidth     = nil,          -- content won't shrink below this
--     autoWidth           = false,        -- stretch content to match viewport width
--     forwardWheelToOuter = false,        -- bubble wheel to an ancestor ScrollFrame
--                                         -- once we hit our own bounds
--     scrollbarWidth      = 12,           -- width of the integrated scrollbar
--     scrollbarGap        = 2,            -- gap between viewport and scrollbar
-- }
--
-- Returns {
--     frame, scroll, content,
--     scrollbar,               -- the T:ScrollBar instance
--     ApplyAutoWidth(),
--     SetContentSize(w, h),
--     ScrollTo(y), ScrollToTop(), ScrollToBottom(),
-- }
-- =============================================================================
function T:ScrollFrame(parent, opts)
    opts = shallowCopy(opts)
    local insets = opts.insets or {4, 4, 4, 4}
    local wheelStep = opts.mouseWheelStep or 20
    local chrome = opts.chrome
    if chrome == nil then
        chrome = true
    end
    local sbWidth = opts.scrollbarWidth or 12
    local sbGap = opts.scrollbarGap or 6

    local outer
    if chrome then
        outer = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        if opts.template == "Opaque" then
            applyOpaqueTemplate(outer, "box")
        else
            setTemplate(outer, opts.template or "Default")
        end
    else
        outer = CreateFrame("Frame", nil, parent)
    end

    if opts.height then
        outer:SetHeight(opts.height)
    end

    local leftInset, topInset, bottomInset
    if chrome then
        leftInset, topInset, bottomInset = insets[1], insets[2], insets[4]
    else
        leftInset, topInset, bottomInset = 0, 0, 0
    end

    local viewportRightInset = sbWidth + sbGap

    local scroll = CreateFrame("ScrollFrame", nil, outer)
    scroll:SetPoint("TOPLEFT", leftInset, -topInset)
    scroll:SetPoint("BOTTOMRIGHT", -viewportRightInset, bottomInset)

    local forwardToOuter = opts.forwardWheelToOuter
    local function findOuterScroll(self_)
        local p = self_:GetParent()
        while p do
            if p.GetObjectType and p:GetObjectType() == "ScrollFrame" and p.IsMouseWheelEnabled and
                p:IsMouseWheelEnabled() then
                local script = p:GetScript("OnMouseWheel")
                if script then
                    return p, script
                end
            end
            p = p.GetParent and p:GetParent() or nil
        end
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self_, delta)
        local c = self_:GetScrollChild()
        if not c then
            return
        end
        local cur = self_:GetVerticalScroll()
        local maxY = math.max(0, c:GetHeight() - self_:GetHeight())

        if forwardToOuter and maxY <= 0 then
            local p, script = findOuterScroll(self_)
            if p then
                script(p, delta)
            end
            return
        end

        local new = cur - delta * wheelStep
        if new < 0 then
            self_:SetVerticalScroll(0)
            if forwardToOuter then
                local p, script = findOuterScroll(self_)
                if p then
                    script(p, delta)
                end
            end
        elseif new > maxY then
            self_:SetVerticalScroll(maxY)
            if forwardToOuter then
                local p, script = findOuterScroll(self_)
                if p then
                    script(p, delta)
                end
            end
        else
            self_:SetVerticalScroll(new)
        end
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(opts.minContentWidth or 1, 1)
    scroll:SetScrollChild(content)

    local scrollbar = T:ScrollBar(outer, scroll, {
        width = sbWidth,
        step = wheelStep
    })
    scrollbar.frame:SetPoint("TOPRIGHT", outer, "TOPRIGHT", 0, -topInset)
    scrollbar.frame:SetPoint("BOTTOMRIGHT", outer, "BOTTOMRIGHT", 0, bottomInset)

    local minW = opts.minContentWidth
    local function ApplyAutoWidth()
        if not opts.autoWidth then
            return
        end
        local w = scroll:GetWidth()
        if w and w > 0 then
            local target = math.max(minW or 0, w)
            if content._lastW ~= target then
                content._lastW = target
                content:SetWidth(target)
            end
        end
    end
    if opts.autoWidth then
        ApplyAutoWidth()
    end

    return {
        frame = outer,
        scroll = scroll,
        content = content,
        scrollbar = scrollbar,
        ApplyAutoWidth = ApplyAutoWidth,
        SetContentSize = function(w, h)
            content:SetSize(w or content:GetWidth(), h or content:GetHeight())
            scroll:UpdateScrollChildRect()
            scrollbar.Refresh()
        end,
        ScrollTo = function(y)
            scroll:SetVerticalScroll(math.max(0, y or 0))
        end,
        ScrollToTop = function()
            scroll:SetVerticalScroll(0)
        end,
        ScrollToBottom = function()
            scroll:UpdateScrollChildRect()
            local c = scroll:GetScrollChild()
            local maxY = c and math.max(0, c:GetHeight() - scroll:GetHeight()) or 0
            scroll:SetVerticalScroll(maxY)
        end
    }
end

-- =============================================================================
-- Template: Spacer
-- -----------------------------------------------------------------------------
-- opts = {
--     height = 8,
-- }
--
-- Returns {
--     frame, height,
--     fullWidth = true,
-- }
-- =============================================================================
function T:Spacer(parent, opts)
    opts = opts or {}
    local height = opts.height or 8
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    return {
        frame = f,
        height = height,
        fullWidth = true,
        Refresh = function()
        end
    }
end

-- =============================================================================
-- Template: Label
-- -----------------------------------------------------------------------------
-- opts = {
--     text      = "..." | function,
--     height    = 16,
--     sizeDelta = 0,
--     justify   = "LEFT" | "CENTER" | "RIGHT",
--     accent    = true,              -- false = do not track accent color
--     color     = {r,g,b}|nil,       -- used only when accent == false
-- }
--
-- Returns {
--     frame, height, label,
--     SetText(s), Refresh(),
-- }
-- =============================================================================
function T:Label(parent, opts)
    opts = shallowCopy(opts)
    local height = opts.height or 16

    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)

    local fs = newFont(f, opts.sizeDelta or 0)
    local justify = opts.justify or "LEFT"
    local anchor = (justify == "RIGHT" and "TOPRIGHT") or (justify == "CENTER" and "TOP") or "TOPLEFT"
    fs:SetPoint(anchor, 0, 0)
    fs:SetJustifyH(justify)
    fs:SetJustifyV("TOP")
    fs:SetWordWrap(false)

    local function computeText()
        return tostring(evalMaybeFn(opts.text) or "")
    end

    -- Frame sizing
    local function applyText(s)
        fs:SetText(s or "")
        if opts.width then
            f:SetWidth(opts.width)
        else
            local w = measureStringWidth(fs)
            f:SetWidth(math.max(w, 1))
        end
    end

    applyText(computeText())

    if opts.accent == false then
        if type(opts.color) == "table" then
            applyTextColor(fs, opts.color)
        end
    else
        E:RegisterAccentText(fs)
    end

    return {
        frame = f,
        height = height,
        label = fs,
        SetText = function(s)
            applyText(s or "")
        end,
        Refresh = function()
            applyText(computeText())
        end
    }
end

-- =============================================================================
-- Template: StatusLine
-- -----------------------------------------------------------------------------
-- opts = {
--     text      = "..." | function,
--     height    = 18,
--     sizeDelta = 0,                 -- font size delta
--     justify   = "LEFT",            -- "LEFT" | "CENTER" | "RIGHT"
--     padding   = 4,                 -- horizontal inset
--     color     = {r,g,b} | nil,     -- nil = default text color
-- }
--
-- Returns {
--     frame, height, label, fullWidth = true,
--     SetText(s), GetText(),
--     Refresh(),
-- }
-- =============================================================================
function T:StatusLine(parent, opts)
    opts = shallowCopy(opts)
    local height = opts.height or 18
    local pad = opts.padding or 4

    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)

    local fs = newFont(f, opts.sizeDelta or 0)
    fs:SetPoint("LEFT", pad, 0)
    fs:SetPoint("RIGHT", -pad, 0)
    fs:SetJustifyH(opts.justify or "LEFT")
    fs:SetWordWrap(false)

    if type(opts.color) == "table" then
        applyTextColor(fs, opts.color)
    end

    local function computeText()
        return tostring(evalMaybeFn(opts.text) or "")
    end

    local lastText = computeText()
    fs:SetText(lastText)

    local function SetText(s)
        s = s or ""
        if s == lastText then
            return
        end
        lastText = s
        fs:SetText(s)
    end

    return {
        frame = f,
        height = height,
        label = fs,
        fullWidth = true,
        SetText = SetText,
        GetText = function()
            return lastText
        end,
        Refresh = function()
            SetText(computeText())
        end
    }
end

-- =============================================================================
-- Template: LabelAlignedButton
-- -----------------------------------------------------------------------------
-- Accepts everything T:Button accepts, plus:
--     totalHeight  = 40,   -- overall container height
--     labelHeight  = 16,   -- reserved gap above the button
--     buttonHeight = 20,   -- (auto-derived from total - label if omitted)
--     buttonWidth  = nil,  -- fixed visible button width inside the row cell
--
-- Returns {
--     frame, height, button, fullWidth?,
--     SetLabel, SetDisabled, SetOnClick, SetTooltip,
--     Refresh(),   -- re-evaluates a function-typed `text` option
-- }
-- =============================================================================
function T:LabelAlignedButton(parent, opts)
    opts = shallowCopy(opts)
    local totalH = opts.totalHeight or 40
    local labelH = opts.labelHeight or 16
    local btnH = opts.buttonHeight or (totalH - labelH - 4)

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(totalH)

    local textOpt = opts.text
    local isDynamicText = type(textOpt) == "function"
    local initialText = isDynamicText and (textOpt() or "") or (textOpt or "")

    -- Hand T:Button a flattened opts table with just the button-relevant bits
    local buttonOpts = shallowCopy(opts)
    buttonOpts.text = initialText
    buttonOpts.height = btnH
    buttonOpts.width = opts.buttonWidth or buttonOpts.width or 1
    buttonOpts.totalHeight = nil
    buttonOpts.labelHeight = nil
    buttonOpts.buttonHeight = nil
    buttonOpts.buttonWidth = nil

    local btn = T:Button(parent, buttonOpts)
    btn.frame:SetParent(container)
    btn.frame:ClearAllPoints()
    btn.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -labelH)
    if opts.buttonWidth then
        btn.frame:SetWidth(opts.buttonWidth)
    else
        btn.frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -labelH)
    end

    local function Refresh()
        if isDynamicText and btn.SetLabel then
            btn.SetLabel(textOpt() or "")
        end
        if btn.Refresh then
            btn.Refresh()
        end
    end

    return {
        frame = container,
        height = totalH,
        button = btn,
        SetLabel = btn.SetLabel,
        SetDisabled = btn.SetDisabled,
        SetOnClick = btn.SetOnClick,
        SetTooltip = btn.SetTooltip,
        Refresh = Refresh
    }
end

-- =============================================================================
-- Template: ScrollingText
-- -----------------------------------------------------------------------------
-- opts = {
--     height              = 320,
--     template            = "Transparent" | "Default" | "Opaque" | nil,
--     forwardWheelToOuter = true,
--     text                = "..." | function,   -- reactive via Refresh()
--     sizeDelta           = 0,                  -- font size delta
--     spacing             = 2,                  -- fontstring line spacing
--     padding             = 4,                  -- inner padding around text
--     insets              = {l,t,r,b},          -- passed through to ScrollFrame
-- }
--
-- Returns {
--     frame, height, fullWidth = true,
--     content, scroll, fontString,
--     SetText(s), GetText(),
--     Refresh(),
--     _relayout(),
-- }
-- =============================================================================
function T:ScrollingText(parent, opts)
    opts = shallowCopy(opts)
    local height = opts.height or 200
    local pad = opts.padding or 4

    local sf = T:ScrollFrame(parent, {
        height = height,
        template = opts.template,
        insets = opts.insets,
        forwardWheelToOuter = opts.forwardWheelToOuter
    })

    local fs = newFont(sf.content, opts.sizeDelta or 0)
    fs:SetPoint("TOPLEFT", pad, -pad)
    fs:SetPoint("TOPRIGHT", -pad, -pad)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if opts.spacing then
        fs:SetSpacing(opts.spacing)
    end

    local function computeText()
        return tostring(evalMaybeFn(opts.text) or "")
    end

    local function relayout()
        local w = sf.scroll:GetWidth()
        if w and w > 0 then
            sf.content:SetWidth(w)
        end
        local scrollH = sf.scroll:GetHeight() or 0
        local h
        if lastText == "" then
            h = scrollH
        else
            h = math.max((fs:GetStringHeight() or 0) + pad * 2, scrollH)
        end
        sf.content:SetHeight(h)
        sf.scroll:UpdateScrollChildRect()
    end

    local lastText = computeText()
    fs:SetText(lastText)
    sf.scroll:HookScript("OnSizeChanged", relayout)
    if E.OptionsUI and E.OptionsUI.AddResizeFlusher then
        E.OptionsUI:AddResizeFlusher(relayout)
    end
    relayout()

    local function SetText(s)
        s = s or ""
        if s ~= lastText then
            lastText = s
            fs:SetText(s)
        end
        relayout()
    end

    return {
        frame = sf.frame,
        height = height,
        fullWidth = true,
        content = sf.content,
        scroll = sf.scroll,
        fontString = fs,
        SetText = SetText,
        GetText = function()
            return lastText
        end,
        Refresh = function()
            SetText(computeText())
        end,
        _relayout = relayout
    }
end

-- =============================================================================
-- Template: ScrollingPanel
-- -----------------------------------------------------------------------------
-- opts = {
--     height              = 320,
--     rowHeight           = 20,
--     rowGap              = 0,            -- vertical gap between rows
--     topPad              = 2,            -- inner top padding
--     template            = "Transparent" | "Default" | nil,
--     forwardWheelToOuter = true,
--     insets              = {l,t,r,b},    -- passed through to ScrollFrame
--
--     createRow = function(parent) return rowFrame end,      -- required
--     updateRow = function(rowFrame, item, index) end,       -- required
--     items     = list | function -> list,                   -- optional
--     emptyText = "..." | function,                          -- shown when list is empty
-- }
--
-- Returns {
--     frame, height, fullWidth = true,
--     content, scroll,
--     SetItems(list),   -- list may itself be a function
--     GetItems(),
--     Refresh(),        -- re-evaluates items() and repaints
--     _relayout(),
-- }
-- =============================================================================
function T:ScrollingPanel(parent, opts)
    opts = shallowCopy(opts)
    assert(type(opts.createRow) == "function", "T:ScrollingPanel requires opts.createRow")
    assert(type(opts.updateRow) == "function", "T:ScrollingPanel requires opts.updateRow")

    local height = opts.height or 200
    local rowH = opts.rowHeight or 20
    local rowGap = opts.rowGap or 0
    local topPad = opts.topPad or 2

    local sf = T:ScrollFrame(parent, {
        height = height,
        template = opts.template,
        insets = opts.insets,
        forwardWheelToOuter = opts.forwardWheelToOuter
    })

    local pool = {}
    local active = {}
    local itemsOpt = opts.items

    local emptyFs
    if opts.emptyText then
        emptyFs = newFont(sf.content, 0)
        emptyFs:SetPoint("TOP", 0, -8)
        emptyFs:SetJustifyH("CENTER")
        emptyFs:Hide()
    end

    local function releaseRows()
        for i = #active, 1, -1 do
            local r = active[i]
            r:Hide()
            pool[#pool + 1] = r
            active[i] = nil
        end
    end

    local function currentItems()
        return evalMaybeFn(itemsOpt) or {}
    end

    local function populate()
        releaseRows()
        local list = currentItems()
        local y = -topPad
        for i, item in ipairs(list) do
            local row = table.remove(pool) or opts.createRow(sf.content)
            row:SetParent(sf.content)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sf.content, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", sf.content, "TOPRIGHT", 0, y)
            local ok, err = pcall(opts.updateRow, row, item, i)
            if not ok then
                E:ChannelWarn("Options", "ScrollingPanel.updateRow error: %s", err)
            end
            row:Show()
            active[#active + 1] = row
            y = y - (rowH + rowGap)
        end

        if emptyFs then
            if #list == 0 then
                emptyFs:SetText(tostring(evalMaybeFn(opts.emptyText) or ""))
                emptyFs:Show()
            else
                emptyFs:Hide()
            end
        end

        local usedH = math.abs(y) + topPad
        sf.content:SetHeight(math.max(usedH, sf.scroll:GetHeight() or 0))
        sf.scroll:UpdateScrollChildRect()
    end

    local function relayout()
        local w = sf.scroll:GetWidth()
        if w and w > 0 then
            sf.content:SetWidth(w)
        end
        populate()
    end
    sf.scroll:HookScript("OnSizeChanged", relayout)
    if E.OptionsUI and E.OptionsUI.AddResizeFlusher then
        E.OptionsUI:AddResizeFlusher(relayout)
    end

    if itemsOpt then
        populate()
    end

    return {
        frame = sf.frame,
        height = height,
        fullWidth = true,
        content = sf.content,
        scroll = sf.scroll,
        SetItems = function(list)
            itemsOpt = list
            populate()
        end,
        GetItems = function()
            return currentItems()
        end,
        Refresh = populate,
        _relayout = relayout
    }
end

-- Utility: MergeArgs
function T:MergeArgs(...)
    local out = {}
    for i = 1, select("#", ...) do
        local t = select(i, ...)
        if t then
            for k, v in pairs(t) do
                out[k] = v
            end
        end
    end
    return out
end
