local E = unpack(ART)

local OH = {}
E.OptionsHelpers = OH

OH.C_TEXT_RGB = {1, 0.82, 0}

OH.CHECKER_PALETTE = {
    ok = "|cff40ff40", -- positive / up-to-date
    zero = "|cffff8040", -- responded but value == 0 (Currency)
    pending = "|cffaaaaaa",
    offline = "|cffc0c0c0",
    noAddon = "|cff808080", -- "doesn't have ART" / "not installed"
    outdated = "|cffffcc00", -- has it, just behind
    missing = "|cffff4040", -- has nothing
    self = "|cff1784d1",
    muted = "|cff888888",
    dim = "|cff666666",
    noResponse = "|cff666666"
}

function OH.c_text()
    return OH.C_TEXT_RGB
end
function OH.c_border()
    return E.media.borderColor
end
function OH.c_accent()
    return E.media.valueColor
end
function OH.c_backdrop()
    return E.media.backdropColor
end
function OH.c_bgFade()
    return E.media.backdropFadeColor
end

function OH.fontPath()
    return E.media.normFont
end
function OH.fontSize()
    return E.media.normFontSize or 12
end
function OH.fontOutline()
    local o = E.media.normFontOutline
    if o == "NONE" then
        return ""
    end
    return o or "OUTLINE"
end

function OH.newFont(parent, sizeDelta, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    local size = OH.fontSize() + (sizeDelta or 0)
    local font = OH.fontPath()
    local outline = OH.fontOutline()
    E.skinnedFontStrings[fs] = sizeDelta or 0
    E:ApplyFontString(fs, font, size, outline)
    return fs
end

function OH.measureStringWidth(fs)
    if not fs then
        return 0
    end
    local w = fs:GetStringWidth() or 0
    if w > 0 then
        return w
    end
    if fs.GetUnboundedStringWidth then
        local uw = fs:GetUnboundedStringWidth() or 0
        if uw > 0 then
            return uw
        end
    end
    local t = fs.GetText and fs:GetText() or nil
    return t and t ~= "" and (#t * 7) or 0
end

local function reinforceBorder(frame)
    if not frame then
        return
    end
    local px = E:PixelSize(frame)
    if px <= 0 then
        return
    end
    if frame.TopEdge and frame.TopEdge.SetHeight then
        frame.TopEdge:SetHeight(px)
        E:DisableSharpening(frame.TopEdge)
    end
    if frame.BottomEdge and frame.BottomEdge.SetHeight then
        frame.BottomEdge:SetHeight(px)
        E:DisableSharpening(frame.BottomEdge)
    end
    if frame.LeftEdge and frame.LeftEdge.SetWidth then
        frame.LeftEdge:SetWidth(px)
        E:DisableSharpening(frame.LeftEdge)
    end
    if frame.RightEdge and frame.RightEdge.SetWidth then
        frame.RightEdge:SetWidth(px)
        E:DisableSharpening(frame.RightEdge)
    end
    if frame.TopLeftCorner and frame.TopLeftCorner.SetSize then
        frame.TopLeftCorner:SetSize(px, px)
        E:DisableSharpening(frame.TopLeftCorner)
    end
    if frame.TopRightCorner and frame.TopRightCorner.SetSize then
        frame.TopRightCorner:SetSize(px, px)
        E:DisableSharpening(frame.TopRightCorner)
    end
    if frame.BottomLeftCorner and frame.BottomLeftCorner.SetSize then
        frame.BottomLeftCorner:SetSize(px, px)
        E:DisableSharpening(frame.BottomLeftCorner)
    end
    if frame.BottomRightCorner and frame.BottomRightCorner.SetSize then
        frame.BottomRightCorner:SetSize(px, px)
        E:DisableSharpening(frame.BottomRightCorner)
    end
end
OH.reinforceBorder = reinforceBorder

function OH.setTemplate(frame, template)
    E:SetTemplate(frame, template or "Default")
    reinforceBorder(frame)
end

function OH.newBackdropFrame(parent, template)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    OH.setTemplate(f, template)
    return f
end
