local E = unpack(ART)
local T = E.Templates
local P = E.TemplatePrivate

local H_BUTTON = P.H_BUTTON
local H_CLOSE_BTN = P.H_CLOSE_BTN
local MULTI_LINE_DEFAULT = P.MULTI_LINE_DEFAULT
local POPUP_DEFAULT_W = P.POPUP_DEFAULT_W
local POPUP_MIN_W = P.POPUP_MIN_W
local POPUP_MAX_W = P.POPUP_MAX_W
local POPUP_PAD_X = P.POPUP_PAD_X
local POPUP_PAD_Y = P.POPUP_PAD_Y
local POPUP_TITLE_H = P.POPUP_TITLE_H
local POPUP_TITLE_GAP = P.POPUP_TITLE_GAP
local POPUP_DESC_GAP = P.POPUP_DESC_GAP
local POPUP_BODY_GAP = P.POPUP_BODY_GAP
local POPUP_FOOTER_GAP = P.POPUP_FOOTER_GAP
local POPUP_BTN_GAP = P.POPUP_BTN_GAP
local STRATA_RANK = P.STRATA_RANK
local POPUP_DEFAULT_STRATA = P.POPUP_DEFAULT_STRATA
local POPUPS_ACTIVE = P.POPUPS_ACTIVE
local POPUP_ANON_SEQ = P.POPUP_ANON_SEQ
local POPUP_NAME_SEQ = P.POPUP_NAME_SEQ
local POPUP_LEVEL_CURSOR = P.POPUP_LEVEL_CURSOR
local OPAQUE_PAINT = P.OPAQUE_PAINT
local c_border = P.c_border
local newFont = P.newFont
local shallowCopy = P.shallowCopy
local safeCall = P.safeCall
local evalMaybeFn = P.evalMaybeFn
local loc = P.loc
local applyOpaqueTemplate = P.applyOpaqueTemplate

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
    local minW = opts.minWidth or POPUP_MIN_W
    local width = math.max(minW, math.min(opts.width or POPUP_DEFAULT_W, POPUP_MAX_W))
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
