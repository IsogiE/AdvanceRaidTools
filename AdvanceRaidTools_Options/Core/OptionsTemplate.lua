local E, L = unpack(ART)

E:RegisterDebugChannel("Options")

-- =============================================================================
-- Templates
-- =============================================================================
-- Basics
--   E.Templates:Header(parent, opts)
--   E.Templates:Description(parent, opts)
--   E.Templates:Spacer(parent, opts)
--   E.Templates:Label(parent, opts)
--   E.Templates:StatusLine(parent, opts)
--   E.Templates:Button(parent, opts)
--   E.Templates:LabelAlignedButton(parent, opts)
--   E.Templates:CloseButton(parent, opts)
--   E.Templates:Checkbox(parent, opts)
--   E.Templates:EditBox(parent, opts)
--   E.Templates:MultilineEditBox(parent, opts)
--   E.Templates:TextViewer(parent, opts)
--   E.Templates:Slider(parent, opts)
--   E.Templates:ColorSwatch(parent, opts)
--   E.Templates:Dropdown(parent, opts)
--   E.Templates:ScrollFrame(parent, opts)
--   E.Templates:ScrollingText(parent, opts)
--   E.Templates:ScrollingPanel(parent, opts)
--   E.Templates:MovableFrame(anchor, opts)
--   E.Templates:PlaceRow(parent, widgets, y, widthPx, opts)
--   E.Templates:PlaceFull(parent, widget, y, widthPx)
--   E.Templates:PositionSection(parent, y, widthPx, opts)
--   E.Templates:MakeTracker()
--
-- Popups (standalone top-level windows):
--   E.Templates:Popup(opts) // generic
--   E.Templates:Confirm(opts) // yes/no
--   E.Templates:Prompt(opts) // single-line input
--   E.Templates:PromptMultiline(opts) //multi-line input
--   E.Templates:ShowText(opts) // read-only viewer
--
-- Shortcuts
--   E:ShowPopup, E:Confirm, E:Prompt, E:PromptMultiline, E:ShowText
--   E:HidePopup(key), E:GetPopup(key), E:IsPopupActive(key)
--
-- Utilities
--   E.Templates:MergeArgs(...) // shallow-merge args tables
-- =============================================================================

E.Templates = E.Templates or {}
local T = E.Templates
local OH = E.OptionsHelpers

-- Constants
local PIXEL = 1
local H_HEADER = 30
local H_CHECKBOX = 18
local H_BUTTON = 24
local H_EDITBOX = 22
local H_SLIDER = 20
local H_COLOR = 18
local H_CLOSE_BTN = 20

-- Button sizing
local BUTTON_MIN_W = 60
local BUTTON_PAD_X = 16
local BUTTON_PAD_X_INNER = 4

-- Popup chrome
local POPUP_DEFAULT_W = 420
local POPUP_MIN_W = 260
local POPUP_MAX_W = 900
local POPUP_PAD_X = 14
local POPUP_PAD_Y = 12
local POPUP_TITLE_H = 24
local POPUP_TITLE_GAP = 8
local POPUP_DESC_GAP = 8
local POPUP_BODY_GAP = 10
local POPUP_FOOTER_GAP = 12
local POPUP_BTN_GAP = 6
local POPUP_BTN_MIN_W = 86
local POPUP_BTN_PAD_X = 14

-- Multiline defaults
local MULTI_LINE_DEFAULT = 8

-- Strata ordering
local STRATA_RANK = {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8
}
local POPUP_DEFAULT_STRATA = "FULLSCREEN_DIALOG"

-- Shared state
-- Popup registry: [key] = popup instance
local POPUPS_ACTIVE = {}
local POPUP_ANON_SEQ = 0
local POPUP_NAME_SEQ = 0
local POPUP_LEVEL_CURSOR = 10

local OPAQUE_PAINT = setmetatable({}, {
    __mode = "k"
})

-- Palette & font
local C_TEXT_DIM_RGB = {0.55, 0.55, 0.55}
local function c_textDim()
    return C_TEXT_DIM_RGB
end

local c_text = OH.c_text
local c_border = OH.c_border
local c_accent = OH.c_accent
local c_backdrop = OH.c_backdrop

local fontPath = OH.fontPath
local fontSize = OH.fontSize
local fontOutline = OH.fontOutline
local newFont = OH.newFont

local measureStringWidth = OH.measureStringWidth

local function shallowCopy(t)
    if not t then
        return {}
    end
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

local function applyTextColor(fs, color)
    if type(color) ~= "table" then
        return
    end
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function safeCall(label, fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        E:ChannelWarn("Options", "Template %s callback error: %s", label, a)
        return nil
    end
    return a, b, c, d
end

local function evalMaybeFn(v, ...)
    if type(v) == "function" then
        local ok, result = pcall(v, ...)
        if ok then
            return result
        end
        return nil
    end
    return v
end

local function loc(key, fallback)
    if not key then
        return fallback or ""
    end
    local s = L and L[key]
    if s == nil or s == true or s == key then
        return fallback or key
    end
    return s
end

-- Skin
local setTemplate = OH.setTemplate
local newBackdropFrame = OH.newBackdropFrame

local function paintOpaque(frame, kind)
    local bg = c_backdrop()
    local br = c_border()
    if frame.SetBackdropColor and bg then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], 1.0)
    end
    if frame.SetBackdropBorderColor and br then
        if kind == "button" and frame._artHovered then
            local ac = c_accent()
            if ac then
                frame:SetBackdropBorderColor(ac[1], ac[2], ac[3], 1.0)
            end
        else
            frame:SetBackdropBorderColor(br[1], br[2], br[3], 1.0)
        end
    end
end

local function applyOpaqueTemplate(frame, kind)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop(nil)
    frame:SetBackdrop({
        bgFile = E.media.blankTex,
        edgeFile = E.media.blankTex,
        edgeSize = PIXEL,
        insets = {
            left = PIXEL,
            right = PIXEL,
            top = PIXEL,
            bottom = PIXEL
        }
    })
    OPAQUE_PAINT[frame] = kind or "backdrop"
    paintOpaque(frame, kind)
end

local TemplateEvents = E:NewCallbackHandle()
TemplateEvents:RegisterMessage("ART_MEDIA_UPDATED", function()
    for frame, kind in pairs(OPAQUE_PAINT) do
        if frame and frame.SetBackdropColor then
            paintOpaque(frame, kind)
        end
    end
end)

-- Tooltip attach to some frames
local function attachTooltip(frame, tooltip, anchor)
    local function resolve()
        local t = evalMaybeFn(tooltip, frame)
        if type(t) == "string" then
            return nil, t
        end
        if type(t) == "table" then
            return t.title, t.desc
        end
        return nil, nil
    end

    frame:HookScript("OnEnter", function(self)
        local title, desc = resolve()
        if not title and not desc then
            return
        end
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        if title then
            GameTooltip:SetText(title, 1, 1, 1)
        end
        if desc then
            if title then
                GameTooltip:AddLine(desc, nil, nil, nil, true)
            else
                GameTooltip:SetText(desc, nil, nil, nil, nil, true)
            end
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
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

        local unbounded = 0
        if fs.GetUnboundedStringWidth then
            unbounded = fs:GetUnboundedStringWidth() or 0
        end
        if unbounded <= 0 then
            local text = fs:GetText() or ""
            unbounded = #text * size * 0.5
        end

        local lines = 1
        if availW > 0 and unbounded > 0 then
            lines = math.max(1, math.ceil(unbounded / availW))
        end
        local h = lines * lineH

        local reported = fs:GetStringHeight() or 0
        if reported > h then
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
        click = opts.onClick,
        tooltip = opts.tooltip
    }

    local function paintBorder()
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
        paintBorder()
    end)
    f:SetScript("OnLeave", function(self)
        state.hovered = false
        self._artHovered = false
        paintBorder()
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
            confirmBody = confirmBody or opts.confirmText or loc("AreYouSure", "Are you sure?")
            local title = evalMaybeFn(opts.confirmTitle) or loc("Confirm", "Confirm")
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
        paintBorder()
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
    end

    SetDisabled(evalMaybeFn(opts.disabled, f))

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
        if labelTop then
            f:SetHitRectInsets(0, 0, LABEL_TOP_H, 0)
            return
        end
        local total = f:GetWidth() or 0
        if total <= 0 then
            return
        end
        local textW = label:GetStringWidth() or 0
        local used = BOX + GAP + textW + PAD_R
        f:SetHitRectInsets(0, math.max(0, total - used), 0, 0)
    end

    f:HookScript("OnSizeChanged", updateHitRect)

    local function renderCheck()
        if state.checked then
            mark:Show()
        else
            mark:Hide()
        end
    end
    renderCheck()

    f:SetScript("OnEnter", function()
        state.hovered = true
        if not state.disabled then
            box:SetBackdropBorderColor(unpack(c_accent()))
        end
    end)
    f:SetScript("OnLeave", function()
        state.hovered = false
        if not state.disabled then
            box:SetBackdropBorderColor(unpack(c_border()))
        end
    end)

    if opts.tooltip then
        attachTooltip(f, opts.tooltip, opts.tooltipAnchor or "ANCHOR_RIGHT")
    end

    f:SetScript("OnClick", function(self)
        if state.disabled then
            return
        end
        if opts.sound ~= false then
            PlaySound(opts.sound or 856)
        end
        state.checked = not state.checked
        renderCheck()
        safeCall("Checkbox.onChange", opts.onChange, self, state.checked)
    end)

    local function SetDisabled(d)
        state.disabled = d and true or false
        f:EnableMouse(not state.disabled)
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
    buttonOpts.totalHeight = nil
    buttonOpts.labelHeight = nil
    buttonOpts.buttonHeight = nil

    local btn = T:Button(parent, buttonOpts)
    btn.frame:SetParent(container)
    btn.frame:ClearAllPoints()
    btn.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -labelH)
    btn.frame:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -labelH)

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
            self_:SetBackdropBorderColor(unpack(c_accent()))
        end
    end)
    slider:SetScript("OnLeave", function(self_)
        state.hovered = false
        if not state.disabled then
            self_:SetBackdropBorderColor(unpack(c_border()))
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
            slider:SetBackdropBorderColor(unpack(c_textDim()))
        else
            labelFS:SetTextColor(unpack(c_text()))
            valueFS:SetTextColor(unpack(c_accent()))
            slider:SetBackdropBorderColor(unpack(c_border()))
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
--     onChange  = function(r,g,b,a) end,     -- called while picking and on confirm
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
local function openColorPicker(r, g, b, a, hasAlpha, onChange, onCancel)
    if type(ColorPickerFrame.SetupColorPickerAndShow) == "function" then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = a,
            hasOpacity = hasAlpha,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = hasAlpha and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or
                               (1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0))) or 1
                if onChange then
                    onChange(nr, ng, nb, na)
                end
            end,
            opacityFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = hasAlpha and (ColorPickerFrame.GetColorAlpha and ColorPickerFrame:GetColorAlpha() or
                               (1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0))) or 1
                if onChange then
                    onChange(nr, ng, nb, na)
                end
            end,
            cancelFunc = function(prev)
                if prev and onCancel then
                    onCancel(prev.r, prev.g, prev.b, prev.opacity or 1)
                end
            end
        })
    else
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = hasAlpha
        ColorPickerFrame.opacity = hasAlpha and (1 - (a or 1)) or nil
        ColorPickerFrame.previousValues = {
            r = r,
            g = g,
            b = b,
            opacity = hasAlpha and (1 - (a or 1)) or nil
        }
        ColorPickerFrame.func = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            if onChange then
                onChange(nr, ng, nb, 1)
            end
        end
        ColorPickerFrame.opacityFunc = function()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = hasAlpha and (1 - (OpacitySliderFrame:GetValue() or 0)) or 1
            if onChange then
                onChange(nr, ng, nb, na)
            end
        end
        ColorPickerFrame.cancelFunc = function()
            local prev = ColorPickerFrame.previousValues
            if prev and onCancel then
                local pa = prev.opacity and (1 - prev.opacity) or 1
                onCancel(prev.r, prev.g, prev.b, pa)
            end
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
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
        activeKey = key
        for _, t in ipairs(tabs) do
            paintButton(t.button, t.key == key)
        end
        if onTabChange then
            local btn = buttons[key]
            safeCall("TabBar.onTabChange", onTabChange, key, btn)
        end
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

    if opts.autoActivateFirst ~= false and tabs[1] then
        ActivateTab(tabs[1].key)
    else
        for _, t in ipairs(tabs) do
            paintButton(t.button, false)
        end
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

-- =============================================================================
-- T:MakeTracker()
--   track(widget)  -- stashes the widget and returns it (so you can chain
--                     `local foo = track(T:Slider(...))`)
--   refresh()      -- calls :Refresh() on every tracked widget so their
--                     get(), disabled(), hidden() callbacks re-evaluate.
--                     Call from onChange of a widget whose value gates
--                     other widgets' disabled state.
--   release()      -- Hide + unparent every tracked widget and wipes the
--                     bookkeeping. Call from the builder's Release().
-- =============================================================================
function T:MakeTracker()
    local widgets = {}
    return {
        track = function(w)
            widgets[#widgets + 1] = w
            return w
        end,
        refresh = function()
            for _, w in ipairs(widgets) do
                if w.Refresh then
                    local ok, err = pcall(w.Refresh)
                    if not ok then
                        E:ChannelWarn("Options", "Tracker refresh failed: %s", tostring(err))
                    end
                end
            end
        end,
        release = function()
            for _, w in ipairs(widgets) do
                if w.frame then
                    w.frame:Hide()
                    w.frame:SetParent(nil)
                    w.frame:ClearAllPoints()
                end
            end
            wipe(widgets)
        end
    }
end

-- =============================================================================
-- T:PlaceRow(parent, widgets, yOffset, widthPx, opts)
-- T:PlaceFull(parent, widget, yOffset, widthPx)
-- =============================================================================
local DEFAULT_ROW_PAD_X = 10
local DEFAULT_ROW_GAP = 8

function T:PlaceRow(parent, widgets, yOffset, widthPx, opts)
    opts = opts or {}
    local n = #widgets
    if n == 0 then
        return 0
    end
    local padX = opts.padX or DEFAULT_ROW_PAD_X
    local gap = opts.gap or DEFAULT_ROW_GAP
    local usable = widthPx - 2 * padX - (n - 1) * gap
    if usable < 0 then
        usable = 0
    end

    local weights = opts.widths
    local totalWeight = 0
    if weights then
        for i = 1, n do
            totalWeight = totalWeight + (weights[i] or 1)
        end
    end

    local x = padX
    local rowH = 0
    for i, w in ipairs(widgets) do
        local share
        if weights and totalWeight > 0 then
            share = usable * ((weights[i] or 1) / totalWeight)
        else
            share = usable / n
        end
        local f = w.frame
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -yOffset)
        f:SetWidth(share)
        if w._relayout then
            w._relayout()
        end
        local h = f:GetHeight() or 22
        if h > rowH then
            rowH = h
        end
        x = x + share + gap
    end
    return rowH
end

function T:PlaceFull(parent, widget, yOffset, widthPx, opts)
    opts = opts or {}
    local padX = opts.padX or DEFAULT_ROW_PAD_X
    local f = widget.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", padX, -yOffset)
    f:SetWidth(math.max(0, widthPx - 2 * padX))
    if widget._relayout then
        widget._relayout()
    end
    return f:GetHeight() or 22
end

-- =============================================================================
-- T:PositionSection(parent, yOffset, widthPx, opts)
-- opts:
--   anchor              frame to reposition (optional — unlock disabled if nil)
--   label               shown on the MovableFrame ghost
--   headerText          overrides the default "Position" header
--   getPosition         function() -> { point, x, y }   (caller db)
--   setPosition         function({ point, x, y })       (caller db)
--   defaultPosition     { point, x, y } for the Reset button
--   onChanged           fires after setPosition; typically re-applies the
--                       anchor's SetPoint from db
--   onEditModeChanged   fires when the unlock toggles (bool)
--   isDisabled          function() -> bool
--
-- Returns (newY, handle). handle.Release() releases the MovableFrame, fires
-- onEditModeChanged(false), hides/unparents the section's own widgets.
-- =============================================================================
local POSITION_SECTION_HEADER_GAP = 10
local POSITION_SECTION_ROW_GAP = 6

-- =============================================================================
-- T:UnlockController(parent, yOffset, widthPx, opts)
-- opts:
--   tracker            outer tracker for refresh integration
--   isDisabled         function() -> bool. Grays out the toggle (module disabled).
--   label              shown on movable ghosts when no per-anchor label supplied
--   onEditModeChanged  function(bool) — fires when toggled
--
-- Returns (newY, controller). controller exposes:
--   :Attach(movable)       — register a MovableFrame handle to lock/unlock as a group
--   :IsUnlocked()
--   :SetUnlocked(bool)
--   :Refresh()             — reconciles state with isDisabled (auto-locks if disabled)
--   :Release()
-- =============================================================================
function T:UnlockController(parent, yOffset, widthPx, opts)
    opts = opts or {}

    local own = {}
    local outerTracker = opts.tracker
    local function trackOwn(w)
        own[#own + 1] = w
        if outerTracker and outerTracker.track then
            outerTracker.track(w)
        end
        return w
    end

    local isDisabled = opts.isDisabled or function()
        return false
    end

    local controller = {
        movables = {},
        unlocked = false
    }

    local unlockCheck

    function controller:Attach(movable)
        if not movable then
            return
        end
        self.movables[#self.movables + 1] = movable
        if self.unlocked then
            movable:SetUnlocked(true)
        end
    end

    function controller:IsUnlocked()
        return self.unlocked
    end

    function controller:SetUnlocked(v)
        v = v and true or false
        if v == self.unlocked then
            return
        end
        self.unlocked = v
        for _, m in ipairs(self.movables) do
            m:SetUnlocked(v)
        end
        if opts.onEditModeChanged then
            opts.onEditModeChanged(v)
        end
        if unlockCheck and unlockCheck.Refresh then
            unlockCheck.Refresh()
        end
    end

    function controller:Refresh()
        if isDisabled() and self.unlocked then
            self:SetUnlocked(false)
        end
    end

    function controller:Release()
        for _, m in ipairs(self.movables) do
            m:Release()
        end
        wipe(self.movables)
        if self.unlocked then
            self.unlocked = false
            if opts.onEditModeChanged then
                opts.onEditModeChanged(false)
            end
        end
        for _, w in ipairs(own) do
            if w.frame then
                w.frame:Hide()
                w.frame:SetParent(nil)
                w.frame:ClearAllPoints()
            end
        end
        wipe(own)
    end

    unlockCheck = trackOwn(T:Checkbox(parent, {
        text = L["BossMods_UnlockFrame"] or "Unlock Frame",
        labelTop = true,
        tooltip = {
            title = L["BossMods_UnlockFrame"] or "Unlock Frame",
            desc = L["BossMods_UnlockFrameDesc"] or ""
        },
        get = function()
            return controller.unlocked
        end,
        onChange = function(_, v)
            controller:SetUnlocked(v)
        end,
        disabled = isDisabled
    }))

    local origRefresh = unlockCheck.Refresh
    unlockCheck.Refresh = function()
        if isDisabled() and controller.unlocked then
            controller.unlocked = false
            for _, m in ipairs(controller.movables) do
                m:SetUnlocked(false)
            end
            if opts.onEditModeChanged then
                opts.onEditModeChanged(false)
            end
        end
        if origRefresh then
            origRefresh()
        end
    end

    local newY = yOffset + T:PlaceRow(parent, {unlockCheck}, yOffset, widthPx) + POSITION_SECTION_ROW_GAP

    return newY, controller
end

function T:PositionSection(parent, yOffset, widthPx, opts)
    opts = opts or {}
    assert(type(opts.getPosition) == "function", "PositionSection: getPosition required")
    assert(type(opts.setPosition) == "function", "PositionSection: setPosition required")

    local own = {}
    local outerTracker = opts.tracker
    local function trackOwn(w)
        own[#own + 1] = w
        if outerTracker and outerTracker.track then
            outerTracker.track(w)
        end
        return w
    end

    local isDisabled = opts.isDisabled or function()
        return false
    end

    local newY = yOffset

    local movable
    if opts.anchor then
        movable = T:MovableFrame(opts.anchor, {
            label = opts.label or "",
            getPosition = opts.getPosition,
            setPosition = opts.setPosition,
            onChanged = opts.onChanged
        })
    end

    local resetBtn = trackOwn(T:LabelAlignedButton(parent, {
        text = L["ResetPosition"] or "Reset Position",
        onClick = function()
            local def = opts.defaultPosition or {
                point = "CENTER",
                x = 0,
                y = 0
            }
            opts.setPosition({
                point = def.point or "CENTER",
                x = def.x or 0,
                y = def.y or 0
            })
            if opts.onChanged then
                opts.onChanged()
            end
        end,
        disabled = isDisabled
    }))

    if opts.unlockController then
        if movable then
            opts.unlockController:Attach(movable)
        end
        newY = newY + T:PlaceRow(parent, {resetBtn}, newY, widthPx) + POSITION_SECTION_ROW_GAP
    else
        local unlockCheck = trackOwn(T:Checkbox(parent, {
            text = L["BossMods_UnlockFrame"] or "Unlock Frame",
            labelTop = true,
            tooltip = {
                title = L["BossMods_UnlockFrame"] or "Unlock Frame",
                desc = L["BossMods_UnlockFrameDesc"] or ""
            },
            get = function()
                return movable and movable:IsUnlocked() or false
            end,
            onChange = function(_, v)
                if movable then
                    movable:SetUnlocked(v)
                end
                if opts.onEditModeChanged then
                    opts.onEditModeChanged(v)
                end
            end,
            disabled = function()
                return isDisabled() or not movable
            end
        }))

        local origUnlockRefresh = unlockCheck.Refresh
        unlockCheck.Refresh = function()
            if isDisabled() and movable and movable:IsUnlocked() then
                movable:SetUnlocked(false)
                if opts.onEditModeChanged then
                    opts.onEditModeChanged(false)
                end
            end
            if origUnlockRefresh then
                origUnlockRefresh()
            end
        end

        newY = newY + T:PlaceRow(parent, {unlockCheck, resetBtn}, newY, widthPx) + POSITION_SECTION_ROW_GAP
    end

    return newY, {
        movable = movable,
        widgets = own,
        Release = function()
            if movable and not opts.unlockController then
                movable:Release()
                movable = nil
            end
            if opts.onEditModeChanged and not opts.unlockController then
                opts.onEditModeChanged(false)
            end
            for _, w in ipairs(own) do
                if w.frame then
                    w.frame:Hide()
                    w.frame:SetParent(nil)
                    w.frame:ClearAllPoints()
                end
            end
            wipe(own)
        end
    }
end

-- =============================================================================
-- T:MovableFrame(anchor, opts)
--
-- opts:
--   getPosition  function() -> { point, x, y }
--   setPosition  function({ point, x, y })
--   onChanged    function()  -- fires after save so owner can reapply position
--
-- Returns {
--   frame       = anchor,
--   IsUnlocked  = function() -> bool,
--   SetUnlocked = function(bool),
--   Toggle      = function(),
--   Release     = function(),
-- }
-- =============================================================================
function T:MovableFrame(anchor, opts)
    assert(anchor and anchor.GetWidth, "MovableFrame: anchor must be a frame")
    assert(type(opts) == "table", "MovableFrame: opts required")
    assert(type(opts.getPosition) == "function", "MovableFrame: getPosition required")
    assert(type(opts.setPosition) == "function", "MovableFrame: setPosition required")

    local unlocked = false
    local armed = false
    local priorMovable, priorMouseEnabled
    local priorOnDragStart, priorOnDragStop

    local function onDragStart(self_)
        if not unlocked then
            return
        end
        self_:StartMoving()
    end

    local function onDragStop(self_)
        self_:StopMovingOrSizing()
        local point, _, _, x, y = self_:GetPoint(1)
        opts.setPosition({
            point = point or "CENTER",
            x = math.floor((x or 0) + 0.5),
            y = math.floor((y or 0) + 0.5)
        })
        if opts.onChanged then
            safeCall("MovableFrame.onChanged", opts.onChanged)
        end
    end

    local function arm()
        if armed then
            return
        end
        priorMovable = anchor:IsMovable()
        priorMouseEnabled = anchor:IsMouseEnabled()
        priorOnDragStart = anchor:GetScript("OnDragStart")
        priorOnDragStop = anchor:GetScript("OnDragStop")
        anchor:SetMovable(true)
        anchor:EnableMouse(true)
        anchor:RegisterForDrag("LeftButton")
        anchor:SetScript("OnDragStart", onDragStart)
        anchor:SetScript("OnDragStop", onDragStop)
        armed = true
    end

    local function disarm()
        if not armed then
            return
        end
        anchor:SetScript("OnDragStart", priorOnDragStart)
        anchor:SetScript("OnDragStop", priorOnDragStop)
        anchor:RegisterForDrag()
        if priorMovable == false then
            anchor:SetMovable(false)
        end
        if priorMouseEnabled == false then
            anchor:EnableMouse(false)
        end
        priorOnDragStart, priorOnDragStop = nil, nil
        priorMovable, priorMouseEnabled = nil, nil
        armed = false
    end

    local handle = {
        frame = anchor
    }

    function handle:IsUnlocked()
        return unlocked
    end

    function handle:SetUnlocked(v)
        local target = v and true or false
        if target == unlocked then
            return
        end
        unlocked = target
        if unlocked then
            arm()
        else
            disarm()
        end
    end

    function handle:Toggle()
        handle:SetUnlocked(not unlocked)
    end

    function handle:Release()
        disarm()
        unlocked = false
    end

    return handle
end

local function chooseStrata(parent, explicit)
    if explicit then
        return explicit
    end
    if parent and parent.GetFrameStrata then
        local ps = parent:GetFrameStrata()
        if STRATA_RANK[ps] and STRATA_RANK[ps] > STRATA_RANK[POPUP_DEFAULT_STRATA] then
            return ps
        end
    end
    return POPUP_DEFAULT_STRATA
end

local function nextLevel(parent)
    POPUP_LEVEL_CURSOR = POPUP_LEVEL_CURSOR + 10
    local base = POPUP_LEVEL_CURSOR
    if parent and parent.GetFrameLevel then
        local pl = parent:GetFrameLevel() or 0
        if pl + 10 > base then
            base = pl + 10
            POPUP_LEVEL_CURSOR = base
        end
    end
    return base
end

local BUTTON_PRESETS = {
    accept_cancel = function()
        return {{
            preset = "accept",
            text = loc("Accept", ACCEPT),
            isDefault = true
        }, {
            preset = "cancel",
            text = loc("Cancel", CANCEL)
        }}
    end,
    yes_no = function()
        return {{
            preset = "accept",
            text = loc("Yes", YES),
            isDefault = true
        }, {
            preset = "cancel",
            text = loc("No", NO)
        }}
    end,
    ok_cancel = function()
        return {{
            preset = "accept",
            text = loc("OK", OKAY),
            isDefault = true
        }, {
            preset = "cancel",
            text = loc("Cancel", CANCEL)
        }}
    end,
    done = function()
        return {{
            preset = "cancel",
            text = loc("Done", DONE)
        }}
    end,
    close = function()
        return {{
            preset = "cancel",
            text = loc("Close", CLOSE)
        }}
    end
}

local function normalizeButtons(buttons, opts)
    if type(buttons) == "string" then
        local factory = BUTTON_PRESETS[buttons]
        if factory then
            return factory()
        end
    end
    if type(buttons) == "table" and #buttons > 0 then
        return buttons
    end
    if opts.viewer then
        return BUTTON_PRESETS.close()
    elseif opts.input or opts.onAccept then
        return BUTTON_PRESETS.accept_cancel()
    else
        return BUTTON_PRESETS.ok_cancel()
    end
end

local function destroyPopup(popup)
    if not popup then
        return
    end
    if popup._key and POPUPS_ACTIVE[popup._key] == popup then
        POPUPS_ACTIVE[popup._key] = nil
    end
    safeCall("Popup.onHide", popup._onHide, popup)
    if popup._specialFrameName then
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == popup._specialFrameName then
                table.remove(UISpecialFrames, i)
                break
            end
        end
    end
    popup:Hide()
    OPAQUE_PAINT[popup] = nil
    popup:SetParent(nil)
    popup:ClearAllPoints()
end

-- =============================================================================
-- Template: Popup
-- -----------------------------------------------------------------------------
-- opts = {
--     -- IDENTITY & LIFECYCLE
--     key               = "unique-id",        -- refocuses if already shown
--     replace           = false,              -- true: close existing & reopen
--     hideOnEscape      = true,
--     showCloseButton   = true,
--     movable           = true,
--
--     -- PLACEMENT
--     parent            = frame,              -- strata/level resolved above
--     strata            = nil,                -- explicit override
--     anchor            = { point, relativeTo, relativePoint, x, y },
--     width             = 420,                -- clamped to [260, 900]
--     height            = nil,                -- nil = auto from body
--
--     -- CONTENT
--     title             = "Title",
--     icon              = "path/to/icon",     -- left of the title
--     text              = "Description above the body.",
--
--     -- BODY VARIANTS (mutually exclusive)
--     input = {
--         multiline     = false,              -- or number of lines
--         default       = "",
--         maxLetters    = nil,
--         numeric       = false,
--         autoFocus     = true,
--         highlight     = true,
--         commitOnEnter = false,              -- multiline only; Enter commits vs newline
--         validate      = function(text) return true/false, "err" end,
--         onChange      = function(text, popup) end,
--     },
--     viewer = {
--         text          = "...",              -- content to display
--         lines         = 10,
--         autoSelect    = true,
--     },
--
--     -- CUSTOM BODY EXTENSION (runs after standard input/viewer)
--     build = function(popup, body, info) return extraPixelsConsumed end,
--
--     -- BUTTONS (right-aligned footer)
--     buttons = "accept_cancel",              -- preset: accept_cancel|yes_no|ok_cancel|done|close
--     -- or a custom table:
--     buttons = {
--         { text="Save", preset="accept", isDefault=true,
--           onClick=function(popup, value) ... end },
--         { text="Extra", onClick=function(popup, value) return true end },
--         -- return true from onClick to keep popup open after click
--     },
--
--     -- CALLBACKS
--     onAccept = function(value, popup) end,  -- preset="accept" + default Enter
--     onCancel = function(popup) end,         -- preset="cancel" + Escape + X
--     onShow   = function(popup) end,
--     onHide   = function(popup) end,
-- }
--
-- Returns the popup frame (with methods):
--     popup:Close()            popup:Focus()            popup:IsShown()
--     popup:SetTitle(t)        popup:SetText(t)
--     popup:SetInputText(t)    popup:GetInputText()
-- =============================================================================
local function buildPopupFrame(opts)
    POPUP_NAME_SEQ = POPUP_NAME_SEQ + 1
    local name = "ARTPopup" .. POPUP_NAME_SEQ

    local parent = opts.parent
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:Hide()
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata(chooseStrata(parent, opts.strata))
    f:SetFrameLevel(nextLevel(parent))

    applyOpaqueTemplate(f, "backdrop")

    if opts.movable ~= false then
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
    end

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(POPUP_TITLE_H)
    titleBar:SetPoint("TOPLEFT", POPUP_PAD_X, -POPUP_PAD_Y)
    titleBar:SetPoint("TOPRIGHT", -POPUP_PAD_X, -POPUP_PAD_Y)
    titleBar:EnableMouse(true)
    if opts.movable ~= false then
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function()
            f:StartMoving()
        end)
        titleBar:SetScript("OnDragStop", function()
            f:StopMovingOrSizing()
        end)
    end

    local titleFS = newFont(titleBar, 2)
    titleFS:SetPoint("LEFT", 0, 0)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetText(tostring(evalMaybeFn(opts.title) or ""))
    E:RegisterAccentText(titleFS)
    f._titleText = titleFS

    if opts.icon then
        local icon = titleBar:CreateTexture(nil, "OVERLAY")
        icon:SetTexture(opts.icon)
        icon:SetSize(POPUP_TITLE_H - 4, POPUP_TITLE_H - 4)
        icon:SetPoint("LEFT", 0, 0)
        titleFS:ClearAllPoints()
        titleFS:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    end

    if opts.showCloseButton ~= false then
        local closeInst = T:CloseButton(titleBar, {
            size = H_CLOSE_BTN,
            opaque = true,
            tooltip = loc("Close", CLOSE),
            onClick = function()
                f:_RequestCancel()
            end
        })
        closeInst.frame:SetPoint("RIGHT", 0, 0)
        f._closeInst = closeInst
    end

    -- Title underline
    local sep = titleBar:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(unpack(c_border()))
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", -POPUP_PAD_X / 2, -1)
    sep:SetPoint("BOTTOMRIGHT", titleBar, "BOTTOMRIGHT", POPUP_PAD_X / 2, -1)
    E:RegisterBorderTexture(sep)

    -- Body
    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -POPUP_TITLE_GAP)
    body:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -POPUP_TITLE_GAP)
    f._body = body

    -- Footer
    local footer = CreateFrame("Frame", nil, f)
    footer:SetHeight(H_BUTTON)
    footer:SetPoint("BOTTOMLEFT", POPUP_PAD_X, POPUP_PAD_Y)
    footer:SetPoint("BOTTOMRIGHT", -POPUP_PAD_X, POPUP_PAD_Y)
    f._footer = footer

    f._onAccept = opts.onAccept
    f._onCancel = opts.onCancel
    f._onHide = opts.onHide
    f._inputInstance = nil
    f._viewerInstance = nil
    f._validate = nil

    function f:_RequestCancel()
        safeCall("Popup.onCancel", self._onCancel, self)
        self:Close()
    end

    function f:_RequestAccept()
        local value = self:GetInputText()
        if self._validate then
            local ok, err = self._validate(value, self)
            if ok == false then
                if err and err ~= "" then
                    E:Printf(err)
                end
                return
            end
        end
        if self._onAccept then
            local ok, result = pcall(self._onAccept, value, self)
            if not ok then
                E:ChannelWarn("Options", "Popup onAccept error: %s", result)
                return
            end
            -- onAccept can return false to close
            if result == false then
                return
            end
        end
        self:Close()
    end

    function f:Close()
        destroyPopup(self)
    end

    function f:GetInputText()
        if self._inputInstance then
            return self._inputInstance.GetText()
        end
        return nil
    end

    function f:SetInputText(t)
        if self._inputInstance then
            self._inputInstance.SetText(t)
        end
    end

    function f:SetTitle(t)
        self._titleText:SetText(tostring(evalMaybeFn(t) or ""))
    end

    function f:SetText(t)
        if self._desc then
            self._desc.SetText(tostring(evalMaybeFn(t) or ""))
        end
    end

    function f:Focus()
        self:Raise()
        if self._inputInstance and self._inputInstance.SetFocus then
            self._inputInstance.SetFocus()
        end
    end

    return f
end

local function layoutPopup(popup, opts)
    local width = math.max(POPUP_MIN_W, math.min(opts.width or POPUP_DEFAULT_W, POPUP_MAX_W))
    popup:SetWidth(width)
    local contentW = width - POPUP_PAD_X * 2

    local body = popup._body
    local footer = popup._footer

    -- Description
    local descInst, descH = nil, 0
    if opts.text and opts.text ~= "" then
        descInst = T:Description(body, {
            text = opts.text,
            sizeDelta = 0
        })
        descInst.frame:SetPoint("TOPLEFT", 0, 0)
        descInst.frame:SetPoint("TOPRIGHT", 0, 0)
        -- Now that the frame has a resolved width, re-measure
        descInst.Relayout()
        descH = descInst.frame:GetHeight()
        popup._desc = descInst
    end

    local cursorY = descH > 0 and -(descH + POPUP_DESC_GAP) or 0
    local bodyH = descH

    -- Input / viewer
    if opts.input then
        local cfg = opts.input
        local inst
        if cfg.multiline then
            inst = T:MultilineEditBox(body, {
                default = cfg.default or "",
                maxLetters = cfg.maxLetters,
                lines = (type(cfg.multiline) == "number") and cfg.multiline or MULTI_LINE_DEFAULT,
                autoFocus = cfg.autoFocus ~= false,
                highlight = cfg.highlight,
                template = "Opaque",
                onTextChanged = cfg.onChange and function(text)
                    safeCall("Popup.input.onChange", cfg.onChange, text, popup)
                end or nil,
                onEscape = function()
                    popup:_RequestCancel()
                end
            })
            -- Multiline
            if cfg.commitOnEnter then
                inst.editBox:SetScript("OnEnterPressed", function()
                    popup:_RequestAccept()
                end)
            end
        else
            inst = T:EditBox(body, {
                default = cfg.default or "",
                maxLetters = cfg.maxLetters,
                numeric = cfg.numeric,
                autoFocus = cfg.autoFocus ~= false,
                highlight = cfg.highlight ~= false,
                showCommitButton = false,
                template = "Opaque",
                commitOn = "focuslost",
                onEnter = function()
                    popup:_RequestAccept()
                end,
                onEscape = function()
                    popup:_RequestCancel()
                end,
                onChange = cfg.onChange and function(text)
                    safeCall("Popup.input.onChange", cfg.onChange, text, popup)
                end or nil
            })
        end
        inst.frame:SetPoint("TOPLEFT", 0, cursorY)
        inst.frame:SetPoint("TOPRIGHT", 0, cursorY)
        popup._inputInstance = inst
        popup._validate = cfg.validate
        bodyH = bodyH + (descH > 0 and POPUP_BODY_GAP or 0) + inst.frame:GetHeight()
    elseif opts.viewer then
        local cfg = opts.viewer
        local inst = T:TextViewer(body, {
            default = tostring(cfg.text or ""),
            lines = cfg.lines or MULTI_LINE_DEFAULT,
            autoSelect = cfg.autoSelect ~= false,
            template = "Opaque",
            onEscape = function()
                popup:_RequestCancel()
            end
        })
        inst.frame:SetPoint("TOPLEFT", 0, cursorY)
        inst.frame:SetPoint("TOPRIGHT", 0, cursorY)
        popup._viewerInstance = inst
        popup._inputInstance = inst -- so Focus() works
        bodyH = bodyH + (descH > 0 and POPUP_BODY_GAP or 0) + inst.frame:GetHeight()
    end

    -- Custom body build callback
    if type(opts.build) == "function" then
        local gap = bodyH > 0 and POPUP_BODY_GAP or 0
        local ok, extraH = pcall(opts.build, popup, body, {
            width = contentW,
            offsetY = -bodyH - gap
        })
        if ok then
            if type(extraH) == "number" and extraH > 0 then
                bodyH = bodyH + gap + extraH
            end
        else
            E:ChannelWarn("Options", "Popup build callback error: %s", extraH)
        end
    end

    body:SetHeight(math.max(bodyH, 1))

    -- Footer buttons
    local specs = normalizeButtons(opts.buttons, opts)
    local prev
    for i = #specs, 1, -1 do
        local spec = specs[i]
        local inst = T:Button(footer, {
            text = spec.text or ("Button " .. i),
            width = spec.width,
            height = H_BUTTON,
            emphasize = spec.isDefault,
            onClick = function(self)
                if spec.onClick then
                    local ok, result = pcall(spec.onClick, popup, popup:GetInputText())
                    if not ok then
                        E:ChannelWarn("Options", "Popup button error: %s", result)
                        return
                    end
                    if result == true then
                        return
                    end -- keep open
                elseif spec.preset == "accept" then
                    popup:_RequestAccept()
                    return
                elseif spec.preset == "cancel" then
                    popup:_RequestCancel()
                    return
                end
                if spec.closeOnClick ~= false then
                    popup:Close()
                end
            end
        })
        -- Swap backdrop to opaque so buttons read correctly on opaque
        applyOpaqueTemplate(inst.frame, "button")
        if i == #specs then
            inst.frame:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
        else
            inst.frame:SetPoint("RIGHT", prev, "LEFT", -POPUP_BTN_GAP, 0)
        end
        if spec.isDefault then
            popup._defaultBtn = inst
        end
        prev = inst.frame
    end

    -- Total height
    local frameH = POPUP_PAD_Y + POPUP_TITLE_H + POPUP_TITLE_GAP + body:GetHeight() + POPUP_FOOTER_GAP + H_BUTTON +
                       POPUP_PAD_Y
    if opts.height and opts.height > frameH then
        frameH = opts.height
    end
    popup:SetHeight(frameH)
end

local function positionPopup(popup, opts)
    popup:ClearAllPoints()
    local a = opts.anchor
    if a and a.point then
        popup:SetPoint(a.point, a.relativeTo or UIParent, a.relativePoint or a.point, a.x or 0, a.y or 0)
    elseif opts.parent and opts.parent.GetCenter then
        popup:SetPoint("CENTER", opts.parent, "CENTER", 0, 0)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function applyEscapeClose(popup, opts)
    if opts.hideOnEscape == false then
        return
    end
    local name = popup:GetName()
    if not name then
        return
    end
    popup._specialFrameName = name
    tinsert(UISpecialFrames, name)
end

function T:Popup(opts)
    opts = shallowCopy(opts) -- never mutate caller

    local key = opts.key
    if not key then
        POPUP_ANON_SEQ = POPUP_ANON_SEQ + 1
        key = "_anon_" .. POPUP_ANON_SEQ
    end

    -- Spam guard
    local existing = POPUPS_ACTIVE[key]
    if existing and existing:IsShown() then
        if opts.replace then
            existing:Close()
        else
            existing:Focus()
            if opts.onShow then
                safeCall("Popup.onShow(refocus)", opts.onShow, existing)
            end
            return existing
        end
    end

    local popup = buildPopupFrame(opts)
    popup._key = key
    POPUPS_ACTIVE[key] = popup

    layoutPopup(popup, opts)
    positionPopup(popup, opts)
    applyEscapeClose(popup, opts)

    popup:Show()

    if popup._inputInstance and popup._inputInstance.SetFocus and opts.input and opts.input.autoFocus ~= false then
        popup._inputInstance.SetFocus()
    end

    if opts.onShow then
        safeCall("Popup.onShow", opts.onShow, popup)
    end

    return popup
end

-- Popup shortcuts

-- Template: Confirm  
-- yes/no confirmation, no input
function T:Confirm(opts)
    opts = shallowCopy(opts)
    opts.buttons = opts.buttons or "yes_no"
    return self:Popup(opts)
end

-- Template: Prompt  
-- single-line text entry with Accept/Cancel
function T:Prompt(opts)
    opts = shallowCopy(opts)
    opts.input = shallowCopy(opts.input)
    opts.input.multiline = false
    opts.buttons = opts.buttons or "accept_cancel"
    return self:Popup(opts)
end

-- Template: PromptMultiline  
-- multi-line text entry with Accept/Cancel
function T:PromptMultiline(opts)
    opts = shallowCopy(opts)
    opts.input = shallowCopy(opts.input)
    if not opts.input.multiline then
        opts.input.multiline = MULTI_LINE_DEFAULT
    end
    opts.buttons = opts.buttons or "accept_cancel"
    return self:Popup(opts)
end

-- Template: ShowText  
-- read-only scrollable text display (copy-friendly)
-- Accepts either opts.viewer = {...}, opts.viewer = "string", or opts.text
-- Use opts.description for a small heading above
function T:ShowText(opts)
    opts = shallowCopy(opts)
    if type(opts.viewer) == "string" then
        opts.viewer = {
            text = opts.viewer
        }
    elseif opts.viewer == nil then
        opts.viewer = {
            text = opts.text or ""
        }
        opts.text = nil
    end
    if opts.description and not opts.text then
        opts.text = opts.description
    end
    opts.buttons = opts.buttons or "close"
    return self:Popup(opts)
end

function T:HidePopup(key)
    local p = POPUPS_ACTIVE[key]
    if p then
        p:Close()
    end
end
function T:GetPopup(key)
    return POPUPS_ACTIVE[key]
end
function T:IsPopupActive(key)
    local p = POPUPS_ACTIVE[key]
    return p and p:IsShown() or false
end

-- These let callers write `E:Confirm{ ... }` instead of `E.Templates:Confirm{...}`
function E:ShowPopup(opts)
    return T:Popup(opts)
end

function E:Confirm(opts)
    return T:Confirm(opts)
end

function E:Prompt(opts)
    return T:Prompt(opts)
end

function E:PromptMultiline(opts)
    return T:PromptMultiline(opts)
end

function E:ShowText(opts)
    return T:ShowText(opts)
end

function E:HidePopup(key)
    return T:HidePopup(key)
end

function E:GetPopup(key)
    return T:GetPopup(key)
end

function E:IsPopupActive(key)
    return T:IsPopupActive(key)
end

-- =============================================================================
-- Template: CheckerPanel
-- -----------------------------------------------------------------------------
-- opts = {
--     mod            = function() return checkerModule end,     -- required, lazy getter
--     ui             = { contextOverride, sortMode },           -- required; caller owns
--     orderBase      = 20,                                      -- runner widgets use order orderBase..orderBase+9
--
--     contexts       = { auto="...", RAID="...", PARTY="...", GUILD="..." },
--     contextOrder   = { "auto", "RAID", "PARTY", "GUILD" },
--
--     sortModes      = nil | { status="...", name="...", ... },
--     sortOrder      = { "status", "name", ... },
--
--     timeoutMin     = 3,
--     timeoutMax     = 30,
--
--     onStart        = function(mod, contextOverride) -> ok, err   (required)
--     startLabel     = function(mod) -> "Start"/"Stop"  (optional, default "Start Check"/"Stop Check")
--     reportStartError = function(mod, err)             (optional, default mod:ReportCheckError)
--
--     statusText     = function(mod) -> text            (required)
--
--     -- choose one of:
--     resultsText    = function(mod) -> text            -- uses ScrollingText
--     resultsRows    = { items = fn(mod), createRow = fn(parent), updateRow = fn(row, item) },
--     resultsHeight  = 320,
--
--     disabled       = nil | function() -> bool,        -- greys out the runner widgets
-- }
-- =============================================================================

local DEFAULT_CONTEXTS = {
    auto = "AutoDetect",
    RAID = "Raid",
    PARTY = "Party",
    GUILD = "Guild"
}
local DEFAULT_CONTEXT_ORDER = {"auto", "RAID", "PARTY", "GUILD"}

function T:CheckerPanel(opts)
    assert(type(opts) == "table", "CheckerPanel: opts required")
    assert(type(opts.mod) == "function", "CheckerPanel: opts.mod (getter) required")
    assert(type(opts.ui) == "table", "CheckerPanel: opts.ui required")
    assert(type(opts.onStart) == "function", "CheckerPanel: opts.onStart required")
    assert(type(opts.statusText) == "function", "CheckerPanel: opts.statusText required")

    local L = ART[2]
    local mod = opts.mod
    local ui = opts.ui
    local base = opts.orderBase or 20

    local contexts = opts.contexts or DEFAULT_CONTEXTS
    local contextOrder = opts.contextOrder or DEFAULT_CONTEXT_ORDER

    local resolvedContexts = {}
    for k, v in pairs(contexts) do
        resolvedContexts[k] = loc(v)
    end

    local disabled = opts.disabled or function()
        local m = opts.mod()
        return not (m and m:IsEnabled())
    end

    local args = {}

    -- Target dropdown
    local hasSort = type(opts.sortModes) == "table"
    local targetWidth = hasSort and "1/3" or "1/2"

    args.contextSel = {
        order = base,
        width = targetWidth,
        build = function(parent)
            return T:Dropdown(parent, {
                label = L["Target"],
                values = resolvedContexts,
                sorting = contextOrder,
                get = function()
                    return ui.contextOverride or "auto"
                end,
                onChange = function(v)
                    ui.contextOverride = v
                end,
                disabled = disabled
            })
        end
    }

    if hasSort then
        local resolvedSortModes = {}
        for k, v in pairs(opts.sortModes) do
            resolvedSortModes[k] = loc(v)
        end
        args.sortSel = {
            order = base + 1,
            width = "1/3",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["SortBy"],
                    values = resolvedSortModes,
                    sorting = opts.sortOrder,
                    get = function()
                        return ui.sortMode
                    end,
                    onChange = function(v)
                        ui.sortMode = v
                        if E.OptionsUI and E.OptionsUI.QueueRefresh then
                            E.OptionsUI:QueueRefresh("current")
                        end
                    end,
                    disabled = disabled
                })
            end
        }
    end

    args.timeout = {
        order = base + 2,
        width = hasSort and "1/3" or "1/2",
        build = function(parent)
            return T:Slider(parent, {
                label = L["Timeout"],
                tooltip = {
                    title = L["Timeout"],
                    desc = L["TimeoutDesc"]
                },
                min = opts.timeoutMin or 3,
                max = opts.timeoutMax or 30,
                step = 1,
                get = function()
                    local m = mod()
                    return m and m.db and m.db.timeoutSeconds or 5
                end,
                onChange = function(v)
                    local m = mod()
                    if m and m.db then
                        m.db.timeoutSeconds = v
                    end
                end,
                disabled = disabled
            })
        end
    }

    args.startBtn = {
        order = base + 3,
        width = "2/3",
        build = function(parent)
            return T:LabelAlignedButton(parent, {
                text = function()
                    local m = mod()
                    if opts.startLabel then
                        return opts.startLabel(m)
                    end
                    if m and m:IsInProgress() then
                        return L["StopCheck"]
                    end
                    return L["StartCheck"]
                end,
                emphasize = true,
                onClick = function()
                    local m = mod()
                    if not m then
                        return
                    end
                    if m:IsInProgress() then
                        m:CancelCheck()
                        return
                    end
                    local ok, err = opts.onStart(m, ui.contextOverride or "auto")
                    if not ok and err then
                        if opts.reportStartError then
                            opts.reportStartError(m, err)
                        elseif m.ReportCheckError then
                            m:ReportCheckError(err)
                        end
                    end
                end,
                disabled = disabled
            })
        end
    }

    args.exportBtn = {
        order = base + 4,
        width = "1/3",
        build = function(parent)
            return T:LabelAlignedButton(parent, {
                text = L["Export"],
                onClick = function()
                    local m = mod()
                    if not m then
                        return
                    end
                    local txt
                    if opts.exportResults then
                        txt = opts.exportResults(m)
                    elseif m.ExportResults then
                        txt = m:ExportResults()
                    end
                    if not txt or txt == "" then
                        E:Printf(L["NoResultsToExport"])
                        return
                    end
                    T:ShowText({
                        title = L["ExportResults"],
                        viewer = txt
                    })
                end,
                disabled = disabled
            })
        end
    }

    args.statusLine = {
        order = base + 5,
        width = "full",
        build = function(parent)
            return T:StatusLine(parent, {
                text = function()
                    local m = mod()
                    return m and opts.statusText(m) or ""
                end
            })
        end
    }

    if opts.resultsRows then
        local rows = opts.resultsRows
        args.results = {
            order = base + 6,
            width = "full",
            build = function(parent)
                return T:ScrollingPanel(parent, {
                    height = opts.resultsHeight or 320,
                    rowHeight = rows.rowHeight or 20,
                    template = "Transparent",
                    forwardWheelToOuter = true,
                    createRow = function(p)
                        local m = mod()
                        return m and rows.createRow(m, p)
                    end,
                    updateRow = function(row, item)
                        local m = mod()
                        if m then
                            rows.updateRow(m, row, item)
                        end
                    end,
                    items = function()
                        local m = mod()
                        return m and rows.items(m) or {}
                    end
                })
            end
        }
    elseif opts.resultsText then
        args.results = {
            order = base + 6,
            width = "full",
            build = function(parent)
                return T:ScrollingText(parent, {
                    height = opts.resultsHeight or 320,
                    template = "Transparent",
                    forwardWheelToOuter = true,
                    spacing = 2,
                    text = function()
                        local m = mod()
                        return m and opts.resultsText(m) or ""
                    end
                })
            end
        }
    end

    return args
end
