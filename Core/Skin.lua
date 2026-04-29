local E = unpack(ART)

do
    local function recompute()
        local _, physicalHeight = GetPhysicalScreenSize()
        E.physicalHeight = physicalHeight or 768
        E.perfect = 768 / E.physicalHeight
        local uiScale = UIParent and UIParent:GetEffectiveScale() or 1
        E.mult = E.perfect / (uiScale > 0 and uiScale or 1)
    end
    recompute()
    E._recomputePixelPerfect = recompute
end

function E:PixelSize(frame)
    local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or
                      (UIParent and UIParent:GetEffectiveScale()) or 1
    if scale <= 0 then
        scale = 1
    end
    return E.perfect / scale
end

function E:Scale(value, frame)
    if not value or value == 0 then
        return value or 0
    end
    local m = E:PixelSize(frame)
    if m == 0 then
        return value
    end
    local step = m > 1 and m or -m
    return value - value % (value < 0 and step or -step)
end

E.skinnedFrames = setmetatable({}, {
    __mode = "k"
}) -- frame -> template
E.skinnedFontStrings = setmetatable({}, {
    __mode = "k"
}) -- fs -> sizeDelta
E.skinnedAccentTexts = setmetatable({}, {
    __mode = "k"
}) -- fs -> true
E.skinnedAccentTextures = setmetatable({}, {
    __mode = "k"
}) -- tex -> true
E.skinnedBorderTextures = setmetatable({}, {
    __mode = "k"
}) -- tex -> true

local function ensureBackdrop(frame)
    if not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
        if frame.OnBackdropSizeChanged then
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
    end
end

local function disablePixelSnap(obj)
    if not obj or obj:IsForbidden() then
        return
    end
    if obj.SetSnapToPixelGrid then
        obj:SetSnapToPixelGrid(false)
        if obj.SetTexelSnappingBias then
            obj:SetTexelSnappingBias(0)
        end
    end
end

function E:DisablePixelSnap(frame)
    if not frame or not frame.GetRegions or frame:IsForbidden() then
        return
    end
    disablePixelSnap(frame)
    for _, region in ipairs({frame:GetRegions()}) do
        disablePixelSnap(region)
    end
end

function E:SetTemplate(frame, template)
    if not frame or not frame.GetObjectType then
        return
    end

    ensureBackdrop(frame)

    -- clear anything previously set so a re-skin doesn't double-up edges
    frame:SetBackdrop(nil)

    local pixel = E:PixelSize(frame)
    frame:SetBackdrop({
        bgFile = E.media.blankTex,
        edgeFile = E.media.blankTex,
        edgeSize = pixel,
        insets = {
            left = pixel,
            right = pixel,
            top = pixel,
            bottom = pixel
        }
    })
    E:DisablePixelSnap(frame)

    if template == "Transparent" then
        frame:SetBackdropColor(unpack(E.media.backdropFadeColor))
    else
        frame:SetBackdropColor(unpack(E.media.backdropColor))
    end
    frame:SetBackdropBorderColor(unpack(E.media.borderColor))

    frame.artTemplate = template or "Default"
    E.skinnedFrames[frame] = frame.artTemplate
end

function E:ApplyOuterBorder(target, opts)
    if not target or not target.GetObjectType then
        return nil
    end
    opts = opts or {}

    local border = target._artOuterBorder
    if not border then
        border = CreateFrame("Frame", nil, target, "BackdropTemplate")
        border:SetFrameLevel((target:GetFrameLevel() or 0) + 1)
        border:Hide()
        target._artOuterBorder = border
    end

    local edgeSize = tonumber(opts.edgeSize) or 0
    if opts.enabled == false or not opts.edgeFile or edgeSize <= 0 then
        border:Hide()
        return border
    end

    if border._artEdgeFile ~= opts.edgeFile or border._artEdgeSize ~= edgeSize then
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", target, "TOPLEFT", -edgeSize, edgeSize)
        border:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", edgeSize, -edgeSize)
        border:SetBackdrop({
            edgeFile = opts.edgeFile,
            edgeSize = edgeSize,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0
            }
        })
        border._artEdgeFile = opts.edgeFile
        border._artEdgeSize = edgeSize
    end

    border:SetBackdropBorderColor(opts.r or 0, opts.g or 0, opts.b or 0, opts.a or 1)
    border:Show()
    return border
end

function E:UntrackFrame(frame)
    if frame then
        E.skinnedFrames[frame] = nil
    end
end

function E:RegisterFontString(fs, sizeDelta)
    if not fs or not fs.SetFont then
        return fs
    end
    local base = E.media.normFontSize or 12
    local outline = E.media.normFontOutline
    if outline == "NONE" then
        outline = ""
    else
        outline = outline or "OUTLINE"
    end
    local font = E.media.normFont
    local targetSize = base + (sizeDelta or 0)
    E.skinnedFontStrings[fs] = sizeDelta or 0
    if fs:SetFont(font, targetSize, outline) then
        fs._artFont, fs._artSize, fs._artOutline = font, targetSize, outline
    end
    return fs
end

function E:RegisterAccentText(fs)
    if not fs then
        return fs
    end
    E.skinnedAccentTexts[fs] = true
    if fs.SetTextColor and E.media.valueColor then
        fs:SetTextColor(unpack(E.media.valueColor))
    end
    return fs
end

function E:RegisterAccentTexture(tex)
    if not tex then
        return tex
    end
    E.skinnedAccentTextures[tex] = true
    if tex.SetVertexColor and E.media.valueColor then
        tex:SetVertexColor(unpack(E.media.valueColor))
    end
    return tex
end

function E:RegisterBorderTexture(tex)
    if not tex then
        return tex
    end
    E.skinnedBorderTextures[tex] = true
    if tex.SetVertexColor and E.media.borderColor then
        tex:SetVertexColor(unpack(E.media.borderColor))
    end
    return tex
end

local function resolveOutline()
    local o = E.media.normFontOutline
    if o == "NONE" then
        return ""
    end
    return o or "OUTLINE"
end

function E:UpdateMediaBackdropColors()
    local bg, bgFade = E.media.backdropColor, E.media.backdropFadeColor
    local border = E.media.borderColor
    for frame, template in pairs(E.skinnedFrames) do
        if frame.SetBackdropColor then
            local src = (template == "Transparent") and bgFade or bg
            if frame.artSolidBackdrop then
                frame:SetBackdropColor(src[1], src[2], src[3], 1)
            else
                frame:SetBackdropColor(unpack(src))
            end
            if not frame.artSkipAutoBorder and border then
                frame:SetBackdropBorderColor(unpack(border))
            end
        end
        if frame.artOnMediaUpdate then
            local ok, err = pcall(frame.artOnMediaUpdate, frame)
            if not ok then
                geterrorhandler()(err)
            end
        end
    end
end

-- Mark a frame so its backdrop always renders at alpha=1
function E:SetSolidBackdrop(frame)
    if not frame or not frame.SetBackdropColor then
        return
    end
    frame.artSolidBackdrop = true
    local src = (frame.artTemplate == "Transparent") and E.media.backdropFadeColor or E.media.backdropColor
    frame:SetBackdropColor(src[1], src[2], src[3], 1)
end

function E:UpdateMediaFonts()
    local font = E.media.normFont
    local baseSize = E.media.normFontSize or 12
    local outline = resolveOutline()
    for fs, delta in pairs(E.skinnedFontStrings) do
        if fs.SetFont then
            local targetSize = baseSize + (delta or 0)
            if fs._artFont ~= font or fs._artSize ~= targetSize or fs._artOutline ~= outline then
                if fs:SetFont(font, targetSize, outline) then
                    fs._artFont, fs._artSize, fs._artOutline = font, targetSize, outline
                end
            end
        end
    end
end

function E:UpdateMediaAccent()
    local accent = E.media.valueColor
    if not accent then
        return
    end
    for fs in pairs(E.skinnedAccentTexts) do
        if fs.SetTextColor then
            fs:SetTextColor(unpack(accent))
        end
    end
    for tex in pairs(E.skinnedAccentTextures) do
        if tex.SetVertexColor then
            tex:SetVertexColor(unpack(accent))
        end
    end
end

function E:UpdateMediaBorder()
    local border = E.media.borderColor
    if not border then
        return
    end
    for tex in pairs(E.skinnedBorderTextures) do
        if tex.SetVertexColor then
            tex:SetVertexColor(unpack(border))
        end
    end
end

function E:UpdateMedia()
    E:UpdateMediaBackdropColors()
    E:UpdateMediaFonts()
    E:UpdateMediaAccent()
    E:UpdateMediaBorder()

    if self.SendMessage then
        self:SendMessage("ART_MEDIA_UPDATED")
    end
end

function E:RefreshPixelScale()
    E._recomputePixelPerfect()
    for frame, template in pairs(E.skinnedFrames) do
        if frame and frame.SetBackdrop and not frame:IsForbidden() then
            E:SetTemplate(frame, template)
        end
    end
    E:UpdateMediaBackdropColors()
end

function E:InitializePixelPerfect()
    E._recomputePixelPerfect()
    if self.RegisterEvent then
        self:RegisterEvent("UI_SCALE_CHANGED", "RefreshPixelScale")
        self:RegisterEvent("DISPLAY_SIZE_CHANGED", "RefreshPixelScale")
    end
end

function E:CreateBackdropShadow(frame, size, alpha)
    if frame.artShadow then
        return
    end
    local s = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    s:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    local off = size or 3
    s:SetPoint("TOPLEFT", frame, "TOPLEFT", -off, off)
    s:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", off, -off)
    s:SetBackdrop({
        edgeFile = [[Interface\AddOns\AdvanceRaidTools\Media\Textures\glowTex]],
        edgeSize = off
    })
    s:SetBackdropBorderColor(0, 0, 0, alpha or 0.5)
    frame.artShadow = s
end

function E:CreateFontString(parent, localeKey, layer, fontSize)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    local size = fontSize or E.media.normFontSize or 12
    local outline = E.media.normFontOutline or "OUTLINE"
    local font = E:Fetch("font", "PT Sans Narrow") or E.media.normFont
    local delta = fontSize and (fontSize - (E.media.normFontSize or 12)) or 0
    E.skinnedFontStrings[fs] = delta
    if fs:SetFont(font, size, outline) then
        fs._artFont, fs._artSize, fs._artOutline = font, size, outline
    end

    if localeKey then
        fs:SetText(E:L(localeKey))
        fs.artLocaleKey = localeKey
    end
    return fs
end

function E:RetranslateFontStrings(root)
    if not root then
        return
    end
    if root.artLocaleKey and root.SetText then
        root:SetText(E:L(root.artLocaleKey))
    end
    if root.GetRegions then
        for _, region in ipairs({root:GetRegions()}) do
            self:RetranslateFontStrings(region)
        end
    end
    if root.GetChildren then
        for _, child in ipairs({root:GetChildren()}) do
            self:RetranslateFontStrings(child)
        end
    end
end
