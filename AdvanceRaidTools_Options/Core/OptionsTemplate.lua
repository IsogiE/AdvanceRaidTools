local E, L = unpack(ART)

E:RegisterDebugChannel("Options")

-- =============================================================================
-- Templates
-- =============================================================================
-- Public API:
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
--   E.Templates:Popup/Confirm/Prompt/PromptMultiline/ShowText(opts)
--   E.Templates:MergeArgs(...)
-- =============================================================================

E.Templates = E.Templates or {}
E.TemplatePrivate = E.TemplatePrivate or {}

local P = E.TemplatePrivate
local OH = E.OptionsHelpers

-- Constants
P.PIXEL = 1
P.H_HEADER = 30
P.H_CHECKBOX = 18
P.H_BUTTON = 24
P.H_EDITBOX = 22
P.H_SLIDER = 20
P.H_COLOR = 18
P.H_CLOSE_BTN = 20

-- Button sizing
P.BUTTON_MIN_W = 60
P.BUTTON_PAD_X = 16
P.BUTTON_PAD_X_INNER = 4

-- Popup chrome
P.POPUP_DEFAULT_W = 420
P.POPUP_MIN_W = 260
P.POPUP_MAX_W = 900
P.POPUP_PAD_X = 14
P.POPUP_PAD_Y = 12
P.POPUP_TITLE_H = 24
P.POPUP_TITLE_GAP = 8
P.POPUP_DESC_GAP = 8
P.POPUP_BODY_GAP = 10
P.POPUP_FOOTER_GAP = 12
P.POPUP_BTN_GAP = 6
P.POPUP_BTN_MIN_W = 86
P.POPUP_BTN_PAD_X = 14

-- Multiline defaults
P.MULTI_LINE_DEFAULT = 8

-- Strata ordering
P.STRATA_RANK = P.STRATA_RANK or {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8
}
P.POPUP_DEFAULT_STRATA = "FULLSCREEN_DIALOG"

-- Shared state
P.POPUPS_ACTIVE = P.POPUPS_ACTIVE or {}
P.POPUP_ANON_SEQ = P.POPUP_ANON_SEQ or 0
P.POPUP_NAME_SEQ = P.POPUP_NAME_SEQ or 0
P.POPUP_LEVEL_CURSOR = P.POPUP_LEVEL_CURSOR or 10
P.OPAQUE_PAINT = P.OPAQUE_PAINT or setmetatable({}, {
    __mode = "k"
})

-- Palette & font
P.C_TEXT_DIM_RGB = P.C_TEXT_DIM_RGB or {0.55, 0.55, 0.55}

function P.c_textDim()
    return P.C_TEXT_DIM_RGB
end

P.c_text = OH.c_text
P.c_border = OH.c_border
P.c_accent = OH.c_accent
P.c_backdrop = OH.c_backdrop

P.fontPath = OH.fontPath
P.fontSize = OH.fontSize
P.fontOutline = OH.fontOutline
P.newFont = OH.newFont
P.measureStringWidth = OH.measureStringWidth

function P.shallowCopy(t)
    if not t then
        return {}
    end
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

function P.applyTextColor(fs, color)
    if type(color) ~= "table" then
        return
    end
    fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function P.safeCall(label, fn, ...)
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

function P.evalMaybeFn(v, ...)
    if type(v) == "function" then
        local ok, result = pcall(v, ...)
        if ok then
            return result
        end
        return nil
    end
    return v
end

function P.loc(key, fallback)
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
P.setTemplate = OH.setTemplate
P.newBackdropFrame = OH.newBackdropFrame

function P.paintOpaque(frame, kind)
    local bg = P.c_backdrop()
    local br = P.c_border()
    if frame.SetBackdropColor and bg then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], 1.0)
    end
    if frame.SetBackdropBorderColor and br then
        if kind == "button" and frame._artHovered then
            local ac = P.c_accent()
            if ac then
                frame:SetBackdropBorderColor(ac[1], ac[2], ac[3], 1.0)
            end
        else
            frame:SetBackdropBorderColor(br[1], br[2], br[3], 1.0)
        end
    end
end

function P.applyOpaqueTemplate(frame, kind)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    frame:SetBackdrop(nil)
    frame:SetBackdrop({
        bgFile = E.media.blankTex,
        edgeFile = E.media.blankTex,
        edgeSize = P.PIXEL,
        insets = {
            left = P.PIXEL,
            right = P.PIXEL,
            top = P.PIXEL,
            bottom = P.PIXEL
        }
    })
    E:DisablePixelSnap(frame)
    P.OPAQUE_PAINT[frame] = kind or "backdrop"
    P.paintOpaque(frame, kind)
end

P.TemplateEvents = P.TemplateEvents or E:NewCallbackHandle()
if not P.TemplateEventsRegistered then
    P.TemplateEvents:RegisterMessage("ART_MEDIA_UPDATED", function()
        for frame, kind in pairs(P.OPAQUE_PAINT) do
            if frame and frame.SetBackdropColor then
                P.paintOpaque(frame, kind)
            end
        end
    end)
    P.TemplateEventsRegistered = true
end

function P.attachTooltip(frame, tooltip, anchor)
    local function resolve()
        local t = P.evalMaybeFn(tooltip, frame)
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
