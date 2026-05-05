local E = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local H_EDITBOX = P.H_EDITBOX
local H_SLIDER = P.H_SLIDER
local H_COLOR = P.H_COLOR
local MULTI_LINE_DEFAULT = P.MULTI_LINE_DEFAULT
local c_textDim = P.c_textDim
local c_text = P.c_text
local c_border = P.c_border
local c_accent = P.c_accent
local fontPath = P.fontPath
local fontSize = P.fontSize
local fontOutline = P.fontOutline
local newFont = P.newFont
local shallowCopy = P.shallowCopy
local safeCall = P.safeCall
local evalMaybeFn = P.evalMaybeFn
local setTemplate = P.setTemplate
local applyOpaqueTemplate = P.applyOpaqueTemplate
local attachTooltip = P.attachTooltip

-- =============================================================================
-- Template: EditBox  (single-line)
-- -----------------------------------------------------------------------------
-- opts = {
--     label           = "Field label" | nil,   -- nil = no external label
--     default         = "",
--     placeholder     = nil,                   -- NYI; reserved
--     maxLetters      = nil,
--     numeric         = false,
--     autoFocus       = false,
--     highlight       = false,                 -- select-all on focus gain
--     showCommitButton= true,                  -- inline checkmark OK button
--     template        = "Default"|"Transparent"|"Opaque",
--     commitOn        = "enter"|"change"|"focuslost"|"explicit",
--                       -- defaults "enter"; "explicit" means only via API
--     onCommit        = function(text) end,    -- fires when committed & valid
--     onChange        = function(text, userInput) end,
--     onEnter         = function(text) end,    -- override default Enter behavior
--     onEscape        = function() end,        -- override default Escape behavior
--     validate        = function(text) return true / false, "err msg" end,
--     tooltip         = "desc" | {title, desc} | function,
--     disabled        = bool | function,
--     width           = nil,  -- layout-controlled by default
--     height          = 22,
-- }
--
-- Returns {
--     frame, height, editBox,
--     SetText(t), GetText(),
--     SetFocus(), ClearFocus(),
--     Commit(),        -- programmatic commit
--     Revert(),        -- discard edits, restore last committed text
--     SetLabel(t), SetTooltip(t),
--     SetDisabled(d), IsDisabled(),
--     Refresh(),
-- }
-- =============================================================================
function T:EditBox(parent, opts)
    opts = shallowCopy(opts)
    local height = opts.height or H_EDITBOX
    local commitOn = opts.commitOn or "enter"

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(opts.label and (height + 16) or height)

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

    local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
    if opts.template == "Opaque" then
        applyOpaqueTemplate(box, "box")
    else
        setTemplate(box, opts.template or "Default")
    end
    if labelFS then
        box:SetPoint("TOPLEFT", 0, -16)
        box:SetPoint("TOPRIGHT", 0, -16)
    else
        box:SetPoint("TOPLEFT", 0, 0)
        box:SetPoint("TOPRIGHT", 0, 0)
    end
    box:SetHeight(height)

    local eb = CreateFrame("EditBox", nil, box)
    eb:SetPoint("TOPLEFT", 2, -1)
    eb:SetPoint("BOTTOMRIGHT", opts.showCommitButton ~= false and -22 or -2, 1)
    eb:SetAutoFocus(opts.autoFocus and true or false)
    eb:SetFont(fontPath(), fontSize(), fontOutline())
    eb:SetTextInsets(4, 4, 0, 0)
    eb:SetTextColor(1, 1, 1)
    if opts.maxLetters then
        eb:SetMaxLetters(opts.maxLetters)
    end
    if opts.numeric then
        eb:SetNumeric(true)
    end
    E.skinnedFontStrings[eb] = 0

    local okBtn
    if opts.showCommitButton ~= false then
        okBtn = CreateFrame("Button", nil, box, "BackdropTemplate")
        setTemplate(okBtn, opts.template == "Opaque" and "Default" or opts.template or "Default")
        okBtn:SetSize(18, 18)
        okBtn:SetPoint("RIGHT", -1, 0)
        okBtn:SetFrameLevel(box:GetFrameLevel() + 5)
        local okTex = okBtn:CreateTexture(nil, "OVERLAY")
        okTex:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
        okTex:SetDesaturated(true)
        okTex:SetPoint("TOPLEFT", -2, 2)
        okTex:SetPoint("BOTTOMRIGHT", 2, -2)
        E:RegisterAccentTexture(okTex)
        okBtn:Hide()
        okBtn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(c_accent()))
        end)
        okBtn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(c_border()))
        end)
    end

    local state = {
        original = opts.default or "",
        committed = false,
        disabled = false
    }
    eb:SetText(state.original)
    eb:SetCursorPosition(0)

    local function showOK(show)
        if okBtn then
            if show then
                okBtn:Show()
            else
                okBtn:Hide()
            end
        end
    end

    local function refreshOK()
        showOK((eb:GetText() or "") ~= (state.original or ""))
    end

    local function doValidate(text)
        if opts.validate then
            local ok, err = safeCall("EditBox.validate", opts.validate, text)
            if ok == false then
                if err and err ~= "" then
                    E:Printf(err)
                end
                return false
            end
        end
        return true
    end

    local function commitNow()
        local text = eb:GetText() or ""
        if not doValidate(text) then
            state.committed = true
            eb:SetText(state.original)
            eb:SetCursorPosition(0)
            showOK(false)
            eb:ClearFocus()
            return
        end
        state.original = text
        state.committed = true
        showOK(false)
        safeCall("EditBox.onCommit", opts.onCommit, text)
        eb:ClearFocus()
    end

    local function revert()
        eb:SetText(state.original)
        eb:SetCursorPosition(0)
        showOK(false)
        eb:ClearFocus()
    end

    eb:SetScript("OnEditFocusGained", function(self)
        state.original = self:GetText() or state.original
        state.committed = false
        if opts.highlight then
            self:HighlightText()
        end
    end)

    eb:SetScript("OnEscapePressed", function()
        if opts.onEscape then
            safeCall("EditBox.onEscape", opts.onEscape)
            return
        end
        state.committed = true
        revert()
    end)

    eb:SetScript("OnEnterPressed", function(self)
        if opts.onEnter then
            safeCall("EditBox.onEnter", opts.onEnter, self:GetText() or "")
            return
        end
        if commitOn == "explicit" then
            self:ClearFocus()
            return
        end
        local cur = self:GetText() or ""
        if cur ~= state.original then
            commitNow()
        else
            self:ClearFocus()
        end
    end)

    eb:SetScript("OnEditFocusLost", function(self)
        if okBtn and okBtn:IsShown() and okBtn:IsMouseOver() then
            state.committed = true
            return
        end
        if not state.committed and commitOn == "focuslost" then
            commitNow()
        elseif not state.committed then
            local typed = self:GetText() or ""
            if typed ~= state.original then
                doValidate(typed) -- show error if any, but still revert
            end
            revert()
        end
        showOK(false)
        state.committed = false
    end)

    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            refreshOK()
            safeCall("EditBox.onChange", opts.onChange, self:GetText() or "", true)
            if commitOn == "change" then
                commitNow()
            end
        end
    end)

    if okBtn then
        okBtn:SetScript("OnClick", function()
            commitNow()
        end)
    end

    if opts.tooltip then
        attachTooltip(box, opts.tooltip, opts.tooltipAnchor)
    end

    local function SetText(t)
        t = tostring(t or "")
        state.original = t
        eb:SetText(t)
        eb:SetCursorPosition(0)
        showOK(false)
    end

    local function SetDisabled(d)
        state.disabled = d and true or false
        eb:EnableMouse(not state.disabled)
        eb:SetEnabled(not state.disabled)
        if okBtn then
            okBtn:EnableMouse(not state.disabled)
        end
        if labelFS then
            labelFS:SetTextColor(unpack(state.disabled and c_textDim() or c_text()))
        end
        eb:SetTextColor(state.disabled and c_textDim()[1] or 1, state.disabled and c_textDim()[2] or 1,
            state.disabled and c_textDim()[3] or 1)
    end

    SetDisabled(evalMaybeFn(opts.disabled, eb))

    return {
        frame = container,
        height = container:GetHeight(),
        editBox = eb,
        box = box,
        SetText = SetText,
        GetText = function()
            return eb:GetText() or ""
        end,
        SetFocus = function()
            eb:SetFocus()
        end,
        ClearFocus = function()
            eb:ClearFocus()
        end,
        Commit = commitNow,
        Revert = revert,
        SetLabel = function(t)
            if labelFS then
                labelFS:SetText(t or "")
            end
        end,
        SetTooltip = function(t)
            opts.tooltip = t
        end,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = function()
            if type(opts.get) == "function" and not eb:HasFocus() then
                local v = tostring(opts.get() or "")
                if v ~= state.original then
                    state.original = v
                    eb:SetText(v)
                    eb:SetCursorPosition(0)
                    showOK(false)
                end
            end
            SetDisabled(evalMaybeFn(opts.disabled, eb))
        end
    }
end

-- =============================================================================
-- Template: MultilineEditBox
-- -----------------------------------------------------------------------------
-- opts = {
--     label         = nil,
--     default       = "",
--     maxLetters    = 100000,
--     lines         = 8,              -- visible line count for sizing
--     autoFocus     = false,
--     highlight     = false,
--     readOnly      = false,
--     template      = "Default"|"Transparent"|"Opaque",
--     onTextChanged = function(text, userInput) end,
--     onEscape      = function() end,
--     tooltip       = ..., disabled = ...,
-- }
--
-- Returns {
--     frame, height, editBox, scrollFrame, content,
--     SetText(t), GetText(),
--     SetFocus(), ClearFocus(),
--     SetReadOnly(bool),
--     SetDisabled(d), Refresh(),
-- }
-- =============================================================================
function T:MultilineEditBox(parent, opts)
    opts = shallowCopy(opts)
    local lines = (type(opts.lines) == "number" and opts.lines > 0) and opts.lines or MULTI_LINE_DEFAULT
    local lineH = fontSize() + 4
    local boxH = lines * lineH + 10
    local hasLabel = opts.label ~= nil and opts.label ~= ""
    local labelH = hasLabel and 16 or 0

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(boxH + labelH)

    local labelFS
    if hasLabel then
        labelFS = newFont(container, 0)
        labelFS:SetTextColor(unpack(c_text()))
        labelFS:SetPoint("TOPLEFT", 0, 0)
        labelFS:SetPoint("TOPRIGHT", 0, 0)
        labelFS:SetJustifyH("LEFT")
        labelFS:SetWordWrap(false)
        labelFS:SetText(opts.label)
    end

    local sfInstance = T:ScrollFrame(container, {
        template = opts.template or "Default",
        insets = {4, 4, 6, 4}
    })
    local box = sfInstance.frame
    if labelFS then
        box:SetPoint("TOPLEFT", 0, -labelH)
        box:SetPoint("TOPRIGHT", 0, -labelH)
    else
        box:SetPoint("TOPLEFT", 0, 0)
        box:SetPoint("TOPRIGHT", 0, 0)
    end
    box:SetHeight(boxH)

    -- replace scroll child with an EditBox
    local scroll = sfInstance.scroll
    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(opts.autoFocus and true or false)
    eb:SetFont(fontPath(), fontSize(), fontOutline())
    eb:SetTextInsets(2, 2, 2, 2)
    eb:SetTextColor(1, 1, 1)
    eb:SetMaxLetters(opts.maxLetters or 100000)
    E.skinnedFontStrings[eb] = 0

    local state = {
        text = tostring(opts.default or ""),
        readOnly = opts.readOnly and true or false,
        disabled = false
    }
    eb:SetText(state.text)
    scroll:SetScrollChild(eb)

    local measurer = container:CreateFontString(nil, "BACKGROUND")
    measurer:Hide()
    measurer:SetFont(fontPath(), fontSize(), fontOutline())
    measurer:SetWordWrap(true)
    measurer:SetNonSpaceWrap(true)
    measurer:SetJustifyH("LEFT")
    measurer:SetJustifyV("TOP")

    local function applyTextHeight()
        local ebW = eb:GetWidth() or 0
        if ebW <= 0 then
            return
        end
        measurer:SetWidth(ebW - 4)
        measurer:SetText(eb:GetText() or "")
        local naturalH = measurer:GetStringHeight() or 0
        local target = math.max(naturalH + 4, lineH)
        if math.abs((eb:GetHeight() or 0) - target) > 0.5 then
            eb:SetHeight(target)
        end
        scroll:UpdateScrollChildRect()
    end

    -- Width will be adjusted when the outer frame gets its width
    local function syncWidth()
        local w = scroll:GetWidth()
        if w and w > 0 then
            eb:SetWidth(w - 2)
            applyTextHeight()
        end
    end
    scroll:HookScript("OnSizeChanged", syncWidth)
    if E.OptionsUI and E.OptionsUI.AddResizeFlusher then
        E.OptionsUI:AddResizeFlusher(function()
            applyTextHeight()
            scroll:UpdateScrollChildRect()
        end)
    end
    syncWidth()

    eb:SetScript("OnTextChanged", function(self_, userInput)
        if state.readOnly and userInput then
            self_:SetText(state.text)
            return
        end
        if userInput then
            state.text = self_:GetText() or ""
            applyTextHeight()
        end
        safeCall("MultilineEditBox.onTextChanged", opts.onTextChanged, self_:GetText() or "", userInput)
    end)
    eb:SetScript("OnCursorChanged", function(self_, _, y, _, h)
        if not self_:HasFocus() then
            return
        end
        scroll:UpdateScrollChildRect()
        local top = scroll:GetVerticalScroll()
        local bot = top + scroll:GetHeight()
        if -y < top then
            scroll:SetVerticalScroll(-y)
        elseif -y + h > bot then
            scroll:SetVerticalScroll(-y + h - scroll:GetHeight())
        end
    end)
    eb:SetScript("OnEscapePressed", function(self_)
        if opts.onEscape then
            safeCall("MultilineEditBox.onEscape", opts.onEscape)
        else
            self_:ClearFocus()
        end
    end)

    -- click-anywhere-to-focus
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
        if not eb:IsEnabled() then
            return
        end
        if not eb:HasFocus() then
            eb:SetFocus()
            eb:SetCursorPosition(#(eb:GetText() or ""))
        end
    end)
    scroll:EnableMouse(true)
    scroll:HookScript("OnMouseDown", function()
        if not eb:IsEnabled() then
            return
        end
        if not eb:HasFocus() then
            eb:SetFocus()
            eb:SetCursorPosition(#(eb:GetText() or ""))
        end
    end)

    eb:HookScript("OnMouseDown", function(self_)
        if not self_:IsEnabled() then
            return
        end
        if not self_:HasFocus() then
            self_:SetFocus()
        end
    end)
    eb:HookScript("OnMouseUp", function(self_)
        if not self_:IsEnabled() or not self_:HasFocus() then
            return
        end
        local pos = self_:GetCursorPosition() or 0
        local len = #(self_:GetText() or "")
        if len == 0 then
            return
        end
        self_:SetCursorPosition(pos == 0 and math.min(1, len) or 0)
        self_:SetCursorPosition(pos)
    end)
    eb:HookScript("OnEditFocusGained", function(self_)
        local pos = self_:GetCursorPosition() or 0
        local len = #(self_:GetText() or "")
        if len == 0 then
            return
        end
        self_:SetCursorPosition(pos == 0 and math.min(1, len) or 0)
        self_:SetCursorPosition(pos)
    end)

    if opts.highlight and state.text ~= "" then
        eb:HighlightText()
    end
    eb:SetCursorPosition(opts.cursorEnd and #state.text or 0)

    if opts.tooltip then
        attachTooltip(box, opts.tooltip, opts.tooltipAnchor)
    end

    local function SetText(t)
        t = tostring(t or "")
        state.text = t
        eb:SetText(t)
        eb:SetCursorPosition(0)
        applyTextHeight()
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(0)
    end

    local function SetReadOnly(r)
        state.readOnly = r and true or false
    end

    local function SetDisabled(d)
        state.disabled = d and true or false
        eb:EnableMouse(not state.disabled)
        eb:SetEnabled(not state.disabled)
        if labelFS then
            labelFS:SetTextColor(unpack(state.disabled and c_textDim() or c_text()))
        end
        eb:SetTextColor(state.disabled and c_textDim()[1] or 1, state.disabled and c_textDim()[2] or 1,
            state.disabled and c_textDim()[3] or 1)
    end

    SetDisabled(evalMaybeFn(opts.disabled, eb))

    return {
        frame = container,
        height = container:GetHeight(),
        editBox = eb,
        scrollFrame = scroll,
        box = box,
        SetText = SetText,
        GetText = function()
            return eb:GetText() or ""
        end,

        SetFocus = function()
            eb:SetFocus()
        end,

        ClearFocus = function()
            eb:ClearFocus()
        end,

        SetLabel = function(t)
            if labelFS then
                labelFS:SetText(t or "")
            end
        end,

        SetReadOnly = SetReadOnly,
        IsReadOnly = function()
            return state.readOnly
        end,

        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,

        Refresh = function()
            if type(opts.get) == "function" and not eb:HasFocus() then
                local v = tostring(opts.get() or "")
                if v ~= state.text then
                    state.text = v
                    eb:SetText(v)
                    eb:SetCursorPosition(0)
                    applyTextHeight()
                    scroll:UpdateScrollChildRect()
                    scroll:SetVerticalScroll(0)
                end
            end
            SetDisabled(evalMaybeFn(opts.disabled, eb))
        end
    }
end

-- =============================================================================
-- Template: TextViewer
-- -----------------------------------------------------------------------------
-- opts = Same shape as MultilineEditBox, plus:
--     autoSelect = true,   -- select all on open for easy copy
--
-- Returns same shape as MultilineEditBox.
-- =============================================================================
function T:TextViewer(parent, opts)
    opts = shallowCopy(opts)
    opts.readOnly = true
    opts.highlight = opts.highlight == nil and true or opts.highlight

    local inst = T:MultilineEditBox(parent, opts)

    -- click focuses and selects all (nicer for copy)
    local eb = inst.editBox
    local box = inst.box
    box:SetScript("OnMouseDown", function()
        if not eb:HasFocus() then
            eb:SetFocus()
        end
        if opts.autoSelect ~= false then
            eb:HighlightText()
        end
    end)

    if opts.autoSelect ~= false then
        eb:HighlightText()
        eb:SetCursorPosition(0)
    end

    return inst
end

-- =============================================================================
-- Template: Slider
-- -----------------------------------------------------------------------------
-- opts = {
--     label       = "Label",
--     value       = 0,
--     min         = 0,
--     max         = 1,
--     step        = 0.01,
--     isPercent   = false,
--     format      = function(v) return string end,   -- overrides isPercent
--     onChange    = function(v) end,
--     disabled    = bool | function,
--     tooltip     = ...,
--     height      = 40,          -- total: label+slider
-- }
--
-- Returns {
--     frame, height, slider,
--     SetValue(v), GetValue(), SetMinMax(min,max), SetStep(s),
--     SetLabel(t), SetDisabled(d), Refresh(),
-- }
-- =============================================================================
function T:Slider(parent, opts)
    opts = shallowCopy(opts)
    local height = opts.height or 40

    local container = CreateFrame("Frame", nil, parent)
    container:SetHeight(height)

    local valueFS = newFont(container, 0)
    E:RegisterAccentText(valueFS)
    valueFS:SetPoint("TOPRIGHT", 0, 0)
    valueFS:SetJustifyH("RIGHT")

    local labelFS = newFont(container, 0)
    labelFS:SetTextColor(unpack(c_text()))
    labelFS:SetPoint("TOPLEFT", 0, 0)
    labelFS:SetPoint("TOPRIGHT", valueFS, "TOPLEFT", -4, 0)
    labelFS:SetJustifyH("LEFT")
    labelFS:SetWordWrap(false)
    labelFS:SetText(opts.label or "")

    local slider = CreateFrame("Slider", nil, container, "BackdropTemplate")
    setTemplate(slider, "Default")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", 0, -16)
    slider:SetPoint("TOPRIGHT", 0, -16)
    slider:SetHeight(H_SLIDER)
    slider:SetMinMaxValues(opts.min or 0, opts.max or 1)
    slider:SetValueStep(opts.step or 0.01)
    slider:SetObeyStepOnDrag(true)

    local borderOverlay = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    borderOverlay:SetAllPoints(slider)
    borderOverlay:SetFrameLevel(slider:GetFrameLevel() + 1)
    borderOverlay:EnableMouse(false)
    setTemplate(borderOverlay, "Default")
    borderOverlay:SetBackdropColor(0, 0, 0, 0)
    borderOverlay.artOnMediaUpdate = function(self_)
        self_:SetBackdropColor(0, 0, 0, 0)
    end
    slider.artSkipAutoBorder = true
    slider:SetBackdropBorderColor(0, 0, 0, 0)

    local thumb = slider:CreateTexture()
    thumb:SetColorTexture(1, 1, 1)
    thumb:SetSize(10, H_SLIDER - 4)
    slider:SetThumbTexture(thumb)
    E:RegisterAccentTexture(thumb)

    local function fmt(v)
        if not v then
            return ""
        end
        if type(opts.format) == "function" then
            local ok, out = pcall(opts.format, v)
            if ok and out then
                return tostring(out)
            end
        end
        if opts.isPercent then
            return ("%d%%"):format(math.floor(v * 100 + 0.5))
        end
        local step = opts.step or 1
        if step >= 1 then
            return ("%d"):format(v)
        end
        return ("%.2f"):format(v)
    end

    slider._suppress = false
    slider:SetScript("OnValueChanged", function(self_, v)
        if self_._suppress then
            return
        end
        valueFS:SetText(fmt(v))
        safeCall("Slider.onChange", opts.onChange, v)
    end)

    local state = {
        disabled = false,
        hovered = false
    }
    slider:SetScript("OnEnter", function(self_)
        state.hovered = true
        if not state.disabled then
            borderOverlay:SetBackdropBorderColor(unpack(c_accent()))
        end
    end)
    slider:SetScript("OnLeave", function(self_)
        state.hovered = false
        if not state.disabled then
            borderOverlay:SetBackdropBorderColor(unpack(c_border()))
        end
    end)

    if opts.tooltip then
        attachTooltip(slider, opts.tooltip, opts.tooltipAnchor or "ANCHOR_CURSOR")
    end

    local function SetValue(v)
        slider._suppress = true
        slider:SetValue(v or opts.min or 0)
        slider._suppress = false
        valueFS:SetText(fmt(v))
    end

    local function SetMinMax(lo, hi)
        opts.min, opts.max = lo, hi
        slider:SetMinMaxValues(lo, hi)
    end

    local function SetStep(s)
        opts.step = s
        slider:SetValueStep(s)
    end

    local function SetDisabled(d)
        state.disabled = d and true or false
        slider:EnableMouse(not state.disabled)
        if state.disabled then
            labelFS:SetTextColor(unpack(c_textDim()))
            valueFS:SetTextColor(unpack(c_textDim()))
            borderOverlay:SetBackdropBorderColor(unpack(c_textDim()))
        else
            labelFS:SetTextColor(unpack(c_text()))
            valueFS:SetTextColor(unpack(c_accent()))
            borderOverlay:SetBackdropBorderColor(unpack(c_border()))
        end
    end

    SetValue(opts.value or opts.min or 0)
    SetDisabled(evalMaybeFn(opts.disabled, slider))

    return {
        frame = container,
        height = height,
        slider = slider,
        SetValue = SetValue,
        GetValue = function()
            return slider:GetValue()
        end,
        SetMinMax = SetMinMax,
        SetStep = SetStep,
        SetLabel = function(t)
            labelFS:SetText(t or "")
        end,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = function()
            if type(opts.get) == "function" then
                SetValue(opts.get())
            end
            SetDisabled(evalMaybeFn(opts.disabled, slider))
        end
    }
end

-- =============================================================================
-- Template: ColorSwatch
-- -----------------------------------------------------------------------------
-- opts = {
--     label     = "Label",
--     r, g, b   = 1, 1, 1,
--     a         = 1,
--     hasAlpha  = false,
--     onChange  = function(r,g,b,a) end,     -- called when the picker is confirmed
--     onCancel  = function(r,g,b,a) end,     -- called if user cancels (prev values)
--     disabled  = bool | function,
--     tooltip   = ...,
--     swatchSize= 18,
-- }
--
-- Returns {
--     frame, height, button,
--     SetColor(r,g,b,a), GetColor(),
--     SetLabel(t), SetDisabled(d), Refresh(),
-- }
-- =============================================================================
local colorPickerCommitHooked = false

local function ensureColorPickerCommitHook()
    if colorPickerCommitHooked then
        return
    end
    ColorPickerFrame:HookScript("OnHide", function(self)
        local request = self._artColorPickerRequest
        if not request or request.finished then
            return
        end
        request.finished = true
        self._artColorPickerRequest = nil
        if request.cancelled then
            return
        end
        request.commit()
    end)
    colorPickerCommitHooked = true
end

local function readPickerColor(hasAlpha)
    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
    local na = 1
    if hasAlpha then
        if ColorPickerFrame.GetColorAlpha then
            na = ColorPickerFrame:GetColorAlpha()
        elseif OpacitySliderFrame then
            na = 1 - (OpacitySliderFrame:GetValue() or 0)
        end
    end
    return nr, ng, nb, na
end

local function previousPickerColor(prev, fallback)
    if type(prev) == "table" then
        return prev.r or prev[1] or fallback.r, prev.g or prev[2] or fallback.g, prev.b or prev[3] or fallback.b,
            prev.opacity or prev.a or prev[4] or fallback.a
    end
    return fallback.r, fallback.g, fallback.b, fallback.a
end

local function openColorPicker(r, g, b, a, hasAlpha, onCommit, onCancel)
    ensureColorPickerCommitHook()

    local prior = ColorPickerFrame._artColorPickerRequest
    if prior and not prior.finished then
        prior.finished = true
        prior.cancelled = true
        ColorPickerFrame._artColorPickerRequest = nil
    end

    local initial = {
        r = r or 1,
        g = g or 1,
        b = b or 1,
        a = a or 1
    }
    local pending = {
        r = initial.r,
        g = initial.g,
        b = initial.b,
        a = initial.a
    }
    local request

    local function updatePending()
        pending.r, pending.g, pending.b, pending.a = readPickerColor(hasAlpha)
    end

    local function cancel(prev)
        pending.r, pending.g, pending.b, pending.a = previousPickerColor(prev, initial)
        if request then
            request.cancelled = true
        end
        if onCancel then
            onCancel(pending.r, pending.g, pending.b, pending.a)
        end
    end

    request = {
        cancelled = false,
        finished = false,
        commit = function()
            if onCommit then
                onCommit(pending.r, pending.g, pending.b, pending.a)
            end
        end
    }

    if type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = initial.r,
            g = initial.g,
            b = initial.b,
            opacity = initial.a,
            hasOpacity = hasAlpha,
            swatchFunc = updatePending,
            opacityFunc = updatePending,
            cancelFunc = cancel
        })
        ColorPickerFrame._artColorPickerRequest = request
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = hasAlpha
        ColorPickerFrame.opacity = hasAlpha and (1 - initial.a) or nil
        ColorPickerFrame.previousValues = {
            r = initial.r,
            g = initial.g,
            b = initial.b,
            opacity = hasAlpha and initial.a or nil
        }
        ColorPickerFrame.func = updatePending
        ColorPickerFrame.opacityFunc = updatePending
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame:SetColorRGB(initial.r, initial.g, initial.b)
        ColorPickerFrame._artColorPickerRequest = request
        ColorPickerFrame:Show()
    end
end

function T:ColorSwatch(parent, opts)
    opts = shallowCopy(opts)
    local size = opts.swatchSize or H_COLOR

    local labelTop = opts.labelTop and opts.label and opts.label ~= ""
    local LABEL_TOP_H = 16 -- matches Dropdown's labelH so rows line up

    local container = CreateFrame("Frame", nil, parent)
    if labelTop then
        container:SetHeight(40) -- matches Dropdown's labelH + buttonH + 4
    else
        container:SetHeight(math.max(size + 2, 20))
    end

    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
    setTemplate(btn, "Default")
    btn:SetSize(size, size)
    if labelTop then
        btn:SetPoint("TOPLEFT", 0, -LABEL_TOP_H)
    else
        btn:SetPoint("LEFT", 0, 0)
    end

    local swatch = btn:CreateTexture(nil, "OVERLAY")
    swatch:SetPoint("TOPLEFT", 1, -1)
    swatch:SetPoint("BOTTOMRIGHT", -1, 1)

    local label = newFont(container, 0)
    label:SetTextColor(unpack(c_text()))
    if labelTop then
        label:SetPoint("TOPLEFT", 0, 0)
        label:SetPoint("TOPRIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
    else
        label:SetPoint("LEFT", btn, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", container, "RIGHT", -4, 0)
        label:SetJustifyH("LEFT")
    end
    label:SetText(opts.label or "")

    local state = {
        r = opts.r or 1,
        g = opts.g or 1,
        b = opts.b or 1,
        a = opts.a or 1,
        disabled = false,
        hovered = false
    }

    local function paintSwatch()
        swatch:SetColorTexture(state.r, state.g, state.b, state.a)
    end

    local function commit(r, g, b, a)
        state.r, state.g, state.b, state.a = r, g, b, a or state.a
        paintSwatch()
        safeCall("ColorSwatch.onChange", opts.onChange, state.r, state.g, state.b, state.a)
    end

    local function cancel(r, g, b, a)
        state.r, state.g, state.b, state.a = r, g, b, a or state.a
        paintSwatch()
        safeCall("ColorSwatch.onCancel", opts.onCancel, state.r, state.g, state.b, state.a)
    end

    paintSwatch()

    btn:SetScript("OnEnter", function(self_)
        state.hovered = true
        if not state.disabled then
            self_:SetBackdropBorderColor(unpack(c_accent()))
        end
    end)
    btn:SetScript("OnLeave", function(self_)
        state.hovered = false
        if not state.disabled then
            self_:SetBackdropBorderColor(unpack(c_border()))
        end
    end)
    btn:SetScript("OnClick", function(self_)
        if state.disabled then
            return
        end
        openColorPicker(state.r, state.g, state.b, state.a, opts.hasAlpha, commit, cancel)
    end)

    if opts.tooltip then
        attachTooltip(btn, opts.tooltip, opts.tooltipAnchor or "ANCHOR_CURSOR")
    end

    local function SetDisabled(d)
        state.disabled = d and true or false
        btn:EnableMouse(not state.disabled)
        if state.disabled then
            label:SetTextColor(unpack(c_textDim()))
            btn:SetBackdropBorderColor(unpack(c_textDim()))
            swatch:SetDesaturated(true)
        else
            label:SetTextColor(unpack(c_text()))
            btn:SetBackdropBorderColor(unpack(c_border()))
            swatch:SetDesaturated(false)
        end
    end

    SetDisabled(evalMaybeFn(opts.disabled, btn))

    return {
        frame = container,
        height = container:GetHeight(),
        button = btn,
        SetColor = function(r, g, b, a)
            state.r, state.g, state.b, state.a = r or state.r, g or state.g, b or state.b, a or state.a
            paintSwatch()
        end,
        GetColor = function()
            return state.r, state.g, state.b, state.a
        end,
        SetLabel = function(t)
            label:SetText(t or "")
        end,
        SetDisabled = SetDisabled,
        IsDisabled = function()
            return state.disabled
        end,
        Refresh = function()
            if type(opts.get) == "function" then
                local r, g, b, a = opts.get()
                state.r = r or state.r
                state.g = g or state.g
                state.b = b or state.b
                state.a = a or state.a
                paintSwatch()
            end
            SetDisabled(evalMaybeFn(opts.disabled, btn))
        end
    }
end
