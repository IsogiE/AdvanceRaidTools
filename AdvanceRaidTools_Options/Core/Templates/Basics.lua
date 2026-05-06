local E = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local H_HEADER = P.H_HEADER
local H_CHECKBOX = P.H_CHECKBOX
local H_BUTTON = P.H_BUTTON
local H_CLOSE_BTN = P.H_CLOSE_BTN
local BUTTON_MIN_W = P.BUTTON_MIN_W
local BUTTON_PAD_X = P.BUTTON_PAD_X
local BUTTON_PAD_X_INNER = P.BUTTON_PAD_X_INNER
local c_textDim = P.c_textDim
local c_text = P.c_text
local c_border = P.c_border
local c_accent = P.c_accent
local c_backdrop = P.c_backdrop
local fontSize = P.fontSize
local newFont = P.newFont
local measureStringWidth = P.measureStringWidth
local shallowCopy = P.shallowCopy
local applyTextColor = P.applyTextColor
local safeCall = P.safeCall
local evalMaybeFn = P.evalMaybeFn
local loc = P.loc
local setTemplate = P.setTemplate
local newBackdropFrame = P.newBackdropFrame
local paintOpaque = P.paintOpaque
local applyOpaqueTemplate = P.applyOpaqueTemplate
local attachTooltip = P.attachTooltip

local function optionsResizeActive()
    return E.OptionsUI and E.OptionsUI.IsResizing and E.OptionsUI:IsResizing()
end

-- =============================================================================
-- Template: Header
-- -----------------------------------------------------------------------------
-- opts = {
--     text        = "Section Title",   -- required
--     height      = 24,                -- override the default row height
--     sizeDelta   = 1,                 -- font size delta above normFontSize
--     color       = {r,g,b} | nil,     -- nil = accent (tracks media)
-- }
--
-- Returns {
--     frame, height,
--     SetText   (text)  -- change the label
-- }
-- =============================================================================
function T:Header(parent, opts)
    opts = opts or {}
    local height = opts.height or H_HEADER

    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)

    local label = newFont(f, opts.sizeDelta or 1)
    label:SetPoint("CENTER")
    label:SetText(tostring(evalMaybeFn(opts.text) or ""))

    if opts.color then
        applyTextColor(label, opts.color)
    else
        E:RegisterAccentText(label) -- tracks user accent color automatically
    end

    local lineL = f:CreateTexture(nil, "BACKGROUND")
    lineL:SetColorTexture(unpack(c_border()))
    lineL:SetHeight(1)
    lineL:SetPoint("LEFT", f, "LEFT", 0, 0)
    lineL:SetPoint("RIGHT", label, "LEFT", -6, 0)
    E:RegisterBorderTexture(lineL)

    local lineR = f:CreateTexture(nil, "BACKGROUND")
    lineR:SetColorTexture(unpack(c_border()))
    lineR:SetHeight(1)
    lineR:SetPoint("LEFT", label, "RIGHT", 6, 0)
    lineR:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    E:RegisterBorderTexture(lineR)

    return {
        frame = f,
        height = height,
        label = label,
        fullWidth = true,
        SetText = function(text)
            label:SetText(text or "")
        end,
        Refresh = function()
            label:SetText(tostring(evalMaybeFn(opts.text) or ""))
        end
    }
end

-- =============================================================================
-- Template: Description
-- -----------------------------------------------------------------------------
-- opts = {
--     text      = "...",              -- required
--     sizeDelta = 0 | 1 | 2,          -- 0 normal, 1 medium, 2 large
--     justify   = "LEFT"|"CENTER"|"RIGHT",  -- defaults LEFT
--     color     = {r,g,b}|"accent"|nil,     -- nil = normal text color
--     wrap      = true,               -- defaults true
--     minHeight = 14,
-- }
--
-- Returns {
--     frame, height,
--     SetText      (text)  -- setting to an unchanged value is a no-op
--     Relayout     ()      -- call after frame width changes
--     GetMeasuredHeight()
-- }
-- =============================================================================
function T:Description(parent, opts)
    opts = opts or {}
    local minH = opts.minHeight or 14
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(minH)

    local fs = newFont(f, opts.sizeDelta or 0)
    fs:SetJustifyH(opts.justify or "LEFT")
    fs:SetJustifyV("TOP")
    fs:SetPoint("TOPLEFT")
    fs:SetPoint("TOPRIGHT")
    if opts.wrap == false then
        fs:SetWordWrap(false)
    end
    fs:SetText(tostring(evalMaybeFn(opts.text) or ""))

    -- Only set a text color if the caller asked for one
    if opts.color == "accent" then
        E:RegisterAccentText(fs)
    elseif type(opts.color) == "table" then
        applyTextColor(fs, opts.color)
    end

    local lastText = tostring(evalMaybeFn(opts.text) or "")
    local function measure()
        local sizeBias = (opts.sizeDelta or 0)
        local size = (fontSize() or 12) + sizeBias
        local lineH = size + 2

        local availW = f:GetWidth() or 0
        if availW <= 0 then
            availW = fs:GetWidth() or 0
        end

        if availW <= 1 then
            return minH
        end

        local unbounded = 0
        if fs.GetUnboundedStringWidth then
            unbounded = fs:GetUnboundedStringWidth() or 0
        end
        if unbounded <= 0 then
            local text = fs:GetText() or ""
            unbounded = #text * size * 0.5
        end

        local lines = math.max(1, math.ceil(unbounded / availW))
        local h = lines * lineH

        local reported = fs:GetStringHeight() or 0
        if reported > h and reported < (lines + 4) * lineH then
            h = reported
        end
        if h <= 0 then
            h = lineH
        end
        return math.max(h + 6, minH)
    end

    local function setText(text)
        text = text or ""
        if text == lastText then
            return
        end
        lastText = text
        fs:SetText(text)
        f:SetHeight(measure())
    end

    local function relayout()
        fs:SetText(lastText)
        f:SetHeight(measure())
    end

    return {
        frame = f,
        height = minH,
        label = fs,
        fullWidth = true, -- descriptions always span the full row in a layout
        SetText = setText,
        Relayout = relayout,
        _relayout = relayout,
        GetMeasuredHeight = measure,
        -- Refresh pulls a fresh value from text() if it's a function
        Refresh = function()
            setText(tostring(evalMaybeFn(opts.text) or ""))
        end
    }
end

-- =============================================================================
-- Template: Button
-- -----------------------------------------------------------------------------
-- opts = {
--     text         = "Click me",
--     width        = nil,              -- nil = natural (text+pad, floored)
--     height       = 24,
--     icon         = "path" | nil,     -- drawn flush-left, text centers in remainder
--     iconSize     = 16,
--     tooltip      = "desc" | {title, desc} | function,
--     onClick      = function(self, ...) end,
--     disabled     = bool | function,  -- evaluated on Refresh()
--     confirm      = false | true | "text" | function,
--     confirmTitle = "Confirm?",       -- title of the confirm popup
--     confirmText  = "Are you sure?",  -- fallback when confirm==true
--     sound        = 852,              -- play on click; false to disable
--     emphasize    = false,            -- accent border always on (primary action)
--     template     = "Default" | "Transparent",
-- }
--
-- Returns {
--     frame, height,
--     GetNaturalWidth(),
--     SetLabel(text), SetTooltip(tooltip), SetOnClick(fn),
--     SetDisabled(bool), IsDisabled(),
--     Refresh()   -- re-eval disabled/label if you passed functions
-- }
-- =============================================================================
function T:Button(parent, opts)
    opts = shallowCopy(opts)
    local height = opts.height or H_BUTTON

    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    setTemplate(f, opts.template or "Default")
    f:SetHeight(height)
    f:RegisterForClicks("AnyUp")

    local iconTex
    if opts.icon then
        iconTex = f:CreateTexture(nil, "OVERLAY")
        iconTex:SetTexture(opts.icon)
        iconTex:SetSize(opts.iconSize or 16, opts.iconSize or 16)
        iconTex:SetPoint("LEFT", BUTTON_PAD_X_INNER, 0)
    end

    local label = newFont(f, 0)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    if iconTex then
        label:SetPoint("LEFT", iconTex, "RIGHT", 4, 0)
    else
        label:SetPoint("CENTER")
    end
    label:SetText(opts.text or "")
    label:SetTextColor(unpack(c_text()))

    local naturalW = math.max(BUTTON_MIN_W, measureStringWidth(label) + BUTTON_PAD_X)
    if iconTex then
        naturalW = naturalW + (opts.iconSize or 16) + 4
    end
    if opts.width then
        f:SetWidth(opts.width)
    else
        f:SetWidth(naturalW)
    end

    local state = {
        disabled = false,
        hovered = false,
        pressed = false,
        click = opts.onClick,
        tooltip = opts.tooltip
    }

    local function blendColor(base, overlay, amount)
        if not base or not overlay then
            return base or overlay
        end
        return {
            (base[1] or 0) * (1 - amount) + (overlay[1] or 0) * amount,
            (base[2] or 0) * (1 - amount) + (overlay[2] or 0) * amount,
            (base[3] or 0) * (1 - amount) + (overlay[3] or 0) * amount,
            base[4] or 1
        }
    end

    local function buttonBackdropColor()
        if opts.template == "Transparent" and E.media and E.media.backdropFadeColor then
            return E.media.backdropFadeColor
        end
        return c_backdrop()
    end

    local function paintButton()
        local bg = buttonBackdropColor()
        local accent = c_accent()
        if state.disabled then
            f:SetBackdropColor(unpack(bg))
        elseif state.pressed then
            f:SetBackdropColor(unpack(blendColor(bg, accent, 0.35)))
        elseif state.hovered then
            f:SetBackdropColor(unpack(blendColor(bg, accent, 0.15)))
        else
            f:SetBackdropColor(unpack(bg))
        end

        if opts.emphasize or (state.hovered and not state.disabled) then
            f:SetBackdropBorderColor(unpack(c_accent()))
        elseif state.disabled then
            f:SetBackdropBorderColor(unpack(c_textDim()))
        else
            f:SetBackdropBorderColor(unpack(c_border()))
        end
    end

    f:SetScript("OnEnter", function(self)
        state.hovered = true
        self._artHovered = true -- opaque painter reads this on media updates
        paintButton()
    end)
    f:SetScript("OnLeave", function(self)
        state.hovered = false
        state.pressed = false
        self._artHovered = false
        paintButton()
    end)
    f:SetScript("OnMouseDown", function(_, button)
        if state.disabled or button ~= "LeftButton" then
            return
        end
        state.pressed = true
        paintButton()
    end)
    f:SetScript("OnMouseUp", function()
        if not state.pressed then
            return
        end
        state.pressed = false
        paintButton()
    end)

    if opts.tooltip then
        attachTooltip(f, function()
            return state.tooltip
        end, opts.tooltipAnchor)
    end

    local function doFire(self, ...)
        safeCall("Button.onClick", state.click, self, ...)
    end

    f:SetScript("OnClick", function(self, ...)
        if state.disabled then
            return
        end
        if opts.sound ~= false then
            PlaySound(opts.sound or 852)
        end
        local needConfirm, confirmBody = false, nil
        if type(opts.confirm) == "function" then
            local result = opts.confirm(self)
            if result ~= nil and result ~= false then
                needConfirm = true
                if type(result) == "string" then
                    confirmBody = result
                end
            end
        elseif type(opts.confirm) == "string" then
            needConfirm, confirmBody = true, opts.confirm
        elseif opts.confirm == true then
            needConfirm = true
        end
        if needConfirm then
            local args = {...}
            confirmBody = confirmBody or opts.confirmText or loc("AreYouSure")
            local title = evalMaybeFn(opts.confirmTitle) or loc("Confirm")
            T:Confirm({
                title = title,
                text = confirmBody,
                onAccept = function()
                    doFire(self, unpack(args))
                end
            })
        else
            doFire(self, ...)
        end
    end)

    local function SetDisabled(d)
        state.disabled = d and true or false
        if state.disabled then
            state.pressed = false
        end
        f:EnableMouse(not state.disabled)
        if state.disabled then
            label:SetTextColor(unpack(c_textDim()))
            if iconTex then
                iconTex:SetDesaturated(true)
            end
        else
            label:SetTextColor(unpack(c_text()))
            if iconTex then
                iconTex:SetDesaturated(false)
            end
        end
        paintButton()
    end

    local function SetLabel(text)
        label:SetText(text or "")
        if not opts.width then
            local nw = math.max(BUTTON_MIN_W, measureStringWidth(label) + BUTTON_PAD_X)
            if iconTex then
                nw = nw + (opts.iconSize or 16) + 4
            end
            f:SetWidth(nw)
        end
    end

    local function SetTooltip(t)
        state.tooltip = t
    end

    local function SetOnClick(fn)
        state.click = fn
    end

    local function Refresh()
        SetDisabled(evalMaybeFn(opts.disabled, f))
        paintButton()
    end

    SetDisabled(evalMaybeFn(opts.disabled, f))
    f.artOnMediaUpdate = paintButton

    return {
        frame = f,
        height = height,
        label = label,
        GetNaturalWidth = function()
            local w = math.max(BUTTON_MIN_W, measureStringWidth(label) + BUTTON_PAD_X)
            if iconTex then
                w = w + (opts.iconSize or 16) + 4
            end
            return w
        end,
        SetLabel = SetLabel,
        SetTooltip = SetTooltip,
        SetOnClick = SetOnClick,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = Refresh
    }
end

-- =============================================================================
-- Template: CloseButton
-- -----------------------------------------------------------------------------
-- opts = {
--     size        = 20,
--     onClick     = function() end,      -- defaults to parent:Hide()
--     opaque      = false,               -- true = use opaque backdrop (popups)
--     tooltip     = "Close" | {...} | fn,
-- }
--
-- Returns same shape as Button, plus:
--     frame.glyph   -- the "X" fontstring so callers can restyle if needed
-- =============================================================================
function T:CloseButton(parent, opts)
    opts = shallowCopy(opts)
    local size = opts.size or H_CLOSE_BTN

    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(size, size)
    f:RegisterForClicks("AnyUp")
    if opts.opaque then
        applyOpaqueTemplate(f, "button")
    else
        setTemplate(f, "Default")
    end

    local glyph = newFont(f, 2)
    glyph:SetPoint("CENTER", 1, 0)
    glyph:SetText("X")
    glyph:SetTextColor(unpack(c_text()))

    local state = {
        hovered = false,
        disabled = false
    }
    local function repaint()
        if opts.opaque then
            paintOpaque(f, "button")
        else
            if state.hovered and not state.disabled then
                f:SetBackdropBorderColor(unpack(c_accent()))
            elseif state.disabled then
                f:SetBackdropBorderColor(unpack(c_textDim()))
            else
                f:SetBackdropBorderColor(unpack(c_border()))
            end
        end
    end
    f:SetScript("OnEnter", function()
        state.hovered = true
        f._artHovered = true
        repaint()
    end)
    f:SetScript("OnLeave", function()
        state.hovered = false
        f._artHovered = false
        repaint()
    end)

    if opts.tooltip then
        attachTooltip(f, opts.tooltip, opts.tooltipAnchor or "ANCHOR_RIGHT")
    end

    local handler = opts.onClick or function()
        if parent and parent.Hide then
            parent:Hide()
        end
    end
    f:SetScript("OnClick", function(self)
        if state.disabled then
            return
        end
        safeCall("CloseButton.onClick", handler, self)
    end)

    return {
        frame = f,
        height = size,
        glyph = glyph,
        SetDisabled = function(d)
            state.disabled = d and true or false
            f:EnableMouse(not state.disabled)
            if state.disabled then
                glyph:SetTextColor(unpack(c_textDim()))
            else
                glyph:SetTextColor(unpack(c_text()))
            end
            repaint()
        end,
        SetOnClick = function(fn)
            handler = fn or handler
        end
    }
end

-- =============================================================================
-- Template: Checkbox
-- -----------------------------------------------------------------------------
-- opts = {
--     text        = "Label",
--     checked     = false,
--     onChange    = function(self, newValue) end,
--     disabled    = bool | function,
--     tooltip     = "desc" | {title, desc} | function,
--     height      = 18,
--     labelTop    = false,                  -- stack the label above the
--                                           -- box (container grows to 40px
--                                           -- to match Slider/Dropdown).
--                                           -- Use when sharing a row with
--                                           -- a labelled widget so the
--                                           -- checkbox aligns with that
--                                           -- widget's body instead of
--                                           -- floating next to its label.
--     sound       = 856,
-- }
--
-- Returns {
--     frame, height,
--     SetChecked(bool), GetChecked(), SetLabel(text),
--     SetDisabled(bool), IsDisabled(), Refresh(),
-- }
-- =============================================================================
function T:Checkbox(parent, opts)
    opts = shallowCopy(opts)
    local labelTop = opts.labelTop and opts.text and opts.text ~= ""
    local LABEL_TOP_H = 16 -- matches Slider/Dropdown label row so rows align
    local BOX_TOP_NUDGE = 2
    local height = labelTop and 40 or (opts.height or H_CHECKBOX)
    local BOX, GAP, PAD_R = 16, 6, 4

    local f = CreateFrame("Button", nil, parent)
    f:SetHeight(height)
    f:EnableMouse(true)
    local box = newBackdropFrame(f, "Default")
    box:SetSize(BOX, BOX)
    if labelTop then
        box:SetPoint("TOPLEFT", 0, -(LABEL_TOP_H + BOX_TOP_NUDGE))
    else
        box:SetPoint("LEFT", 0, 0)
    end

    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
    mark:SetDesaturated(true)
    mark:SetPoint("TOPLEFT", box, "TOPLEFT", -3, 3)
    mark:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 3, -3)
    E:RegisterAccentTexture(mark)
    mark:Hide()

    local label = newFont(f, 0)
    label:SetTextColor(unpack(c_text()))
    if labelTop then
        label:SetPoint("TOPLEFT", 0, 0)
        label:SetPoint("TOPRIGHT", 0, 0)
    else
        label:SetPoint("LEFT", box, "RIGHT", GAP, 0)
        label:SetPoint("RIGHT", f, "RIGHT", -PAD_R, 0)
    end
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(opts.text or "")

    local state = {
        checked = opts.checked and true or false,
        disabled = false,
        hovered = false
    }

    local function updateHitRect()
        local total = f:GetWidth() or 0
        if total <= 0 then
            return
        end
        if labelTop then
            f:SetHitRectInsets(0, math.max(0, total - BOX - PAD_R), LABEL_TOP_H, 0)
            return
        end
        local textW = label:GetStringWidth() or 0
        local used = BOX + GAP + textW + PAD_R
        f:SetHitRectInsets(0, math.max(0, total - used), 0, 0)
    end

    f:HookScript("OnSizeChanged", function()
        if not optionsResizeActive() then
            updateHitRect()
        end
    end)

    local function renderCheck()
        if state.checked then
            mark:Show()
        else
            mark:Hide()
        end
    end
    renderCheck()

    local function setHover(hovered)
        state.hovered = hovered and true or false
        if not state.disabled then
            if hovered then
                box:SetBackdropBorderColor(unpack(c_accent()))
            else
                box:SetBackdropBorderColor(unpack(c_border()))
            end
        end
    end

    f:SetScript("OnEnter", function()
        setHover(true)
    end)
    f:SetScript("OnLeave", function()
        setHover(false)
    end)

    if opts.tooltip then
        box:EnableMouse(true)
        box:SetScript("OnEnter", function()
            setHover(true)
        end)
        box:SetScript("OnLeave", function()
            setHover(false)
        end)
        attachTooltip(box, opts.tooltip, opts.tooltipAnchor or "ANCHOR_CURSOR")
    end

    local function onClick(self)
        if state.disabled then
            return
        end
        if opts.sound ~= false then
            PlaySound(opts.sound or 856)
        end
        state.checked = not state.checked
        renderCheck()
        safeCall("Checkbox.onChange", opts.onChange, self, state.checked)
    end

    f:SetScript("OnClick", onClick)
    if opts.tooltip then
        box:SetScript("OnMouseUp", function(_, button)
            if button == "LeftButton" then
                onClick(f)
            end
        end)
    end

    local function SetDisabled(d)
        state.disabled = d and true or false
        f:EnableMouse(not state.disabled)
        if opts.tooltip then
            box:EnableMouse(not state.disabled)
        end
        if state.disabled then
            label:SetTextColor(unpack(c_textDim()))
            mark:SetVertexColor(unpack(c_textDim()))
            box:SetBackdropBorderColor(unpack(c_textDim()))
        else
            label:SetTextColor(unpack(c_text()))
            if c_accent() then
                mark:SetVertexColor(unpack(c_accent()))
            end
            box:SetBackdropBorderColor(unpack(c_border()))
        end
    end

    SetDisabled(evalMaybeFn(opts.disabled, f))

    local LABEL_RENDER_PAD = 4
    local function natW()
        local w = measureStringWidth(label)
        return BOX + GAP + w + PAD_R + LABEL_RENDER_PAD
    end
    if opts.width then
        f:SetWidth(opts.width)
    else
        f:SetWidth(natW())
    end

    return {
        frame = f,
        height = height,
        label = label,
        GetNaturalWidth = natW,
        SetChecked = function(v)
            state.checked = v and true or false
            renderCheck()
        end,
        GetChecked = function()
            return state.checked
        end,
        SetLabel = function(t)
            label:SetText(t or "")
            if not opts.width then
                f:SetWidth(natW())
            end
            updateHitRect()
        end,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = function()
            if type(opts.get) == "function" then
                local v = opts.get()
                state.checked = v and true or false
                renderCheck()
            end
            SetDisabled(evalMaybeFn(opts.disabled, f))
            updateHitRect()
        end
    }
end
