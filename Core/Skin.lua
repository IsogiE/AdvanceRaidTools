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
    local px = E:PixelSize(frame)
    if px == 0 then
        return value
    end
    return math.floor(value / px + 0.5) * px
end

E.skinnedFrames = setmetatable({}, {
    __mode = "k"
})
E.skinnedFontStrings = setmetatable({}, {
    __mode = "k"
})
E.skinnedAccentTexts = setmetatable({}, {
    __mode = "k"
})
E.skinnedAccentTextures = setmetatable({}, {
    __mode = "k"
})
E.skinnedBorderTextures = setmetatable({}, {
    __mode = "k"
})
E.pixelBorderedFrames = setmetatable({}, {
    __mode = "k"
})

local function snapToPixel(value, pixel)
    if not value or not pixel or pixel <= 0 then
        return value or 0
    end
    return math.floor(value / pixel + 0.5) * pixel
end

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

function E:DisableSharpening(tex)
    disablePixelSnap(tex)
end

local SIDES = {"left", "right", "top", "bottom"}

local function buildPixelBorder(frame, layer, sublevel)
    layer = layer or "OVERLAY"
    sublevel = sublevel or 7
    local b = frame.artPixelBorder
    if b then
        if b._layer ~= layer or b._sublevel ~= sublevel then
            for i = 1, #SIDES do
                local t = b[SIDES[i]]
                if t and t.SetDrawLayer then
                    t:SetDrawLayer(layer, sublevel)
                end
            end
            b._layer, b._sublevel = layer, sublevel
        end
        return b
    end
    b = {
        _layer = layer,
        _sublevel = sublevel
    }
    for i = 1, #SIDES do
        local t = frame:CreateTexture(nil, layer, nil, sublevel)
        t:SetColorTexture(1, 1, 1, 1)
        disablePixelSnap(t)
        b[SIDES[i]] = t
    end
    frame.artPixelBorder = b
    E.pixelBorderedFrames[frame] = true
    return b
end

local function layoutPixelBorder(frame, inset, thickness)
    local b = frame.artPixelBorder
    if not b then
        return
    end
    local i = inset or 0
    local t = thickness or E:PixelSize(frame)
    if t <= 0 then
        t = E:PixelSize(frame)
    end
    b._inset, b._thickness = i, t

    local leftOffset, rightOffset, topOffset, bottomOffset = i, -i, -i, i
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local pixel = E:PixelSize(frame)
    if pixel > 0 then
        if left then
            leftOffset = i + (snapToPixel(left + i, pixel) - (left + i))
        end
        if right then
            rightOffset = -i + (snapToPixel(right - i, pixel) - (right - i))
        end
        if top then
            topOffset = -i + (snapToPixel(top - i, pixel) - (top - i))
        end
        if bottom then
            bottomOffset = i + (snapToPixel(bottom + i, pixel) - (bottom + i))
        end
    end

    b.left:ClearAllPoints()
    b.left:SetPoint("TOPLEFT", frame, "TOPLEFT", leftOffset, topOffset)
    b.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", leftOffset, bottomOffset)
    b.left:SetWidth(t)

    b.right:ClearAllPoints()
    b.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightOffset, topOffset)
    b.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", rightOffset, bottomOffset)
    b.right:SetWidth(t)

    b.top:ClearAllPoints()
    b.top:SetPoint("TOPLEFT", b.left, "TOPRIGHT", 0, 0)
    b.top:SetPoint("TOPRIGHT", b.right, "TOPLEFT", 0, 0)
    b.top:SetHeight(t)

    b.bottom:ClearAllPoints()
    b.bottom:SetPoint("BOTTOMLEFT", b.left, "BOTTOMRIGHT", 0, 0)
    b.bottom:SetPoint("BOTTOMRIGHT", b.right, "BOTTOMLEFT", 0, 0)
    b.bottom:SetHeight(t)
end

local function paintPixelBorder(frame, r, g, b, a)
    local px = frame.artPixelBorder
    if not px then
        return
    end
    a = a or 1
    px.left:SetVertexColor(r, g, b, a)
    px.right:SetVertexColor(r, g, b, a)
    px.top:SetVertexColor(r, g, b, a)
    px.bottom:SetVertexColor(r, g, b, a)
    px._color = {r, g, b, a}
end

local function showPixelBorder(frame, show)
    local px = frame.artPixelBorder
    if not px then
        return
    end
    if show then
        px.left:Show()
        px.right:Show()
        px.top:Show()
        px.bottom:Show()
    else
        px.left:Hide()
        px.right:Hide()
        px.top:Hide()
        px.bottom:Hide()
    end
    px._shown = show and true or false
end

function E:CreatePixelBorder(frame, opts)
    if not frame or not frame.CreateTexture or frame:IsForbidden() then
        return nil
    end
    opts = opts or {}
    local b = buildPixelBorder(frame, opts.layer, opts.sublevel)
    local pixelMul = opts.pixelMul or 1
    if pixelMul <= 0 then
        pixelMul = 1
    end
    local inset = opts.inset or 0
    layoutPixelBorder(frame, inset, E:PixelSize(frame) * pixelMul)
    if opts.color then
        paintPixelBorder(frame, opts.color[1], opts.color[2], opts.color[3], opts.color[4] or 1)
    end
    b._pixelMul = pixelMul
    b._refresh = function()
        layoutPixelBorder(frame, b._inset or 0, E:PixelSize(frame) * (b._pixelMul or 1))
    end
    return b
end

function E:LayoutPixelBorder(frame, inset, thickness)
    layoutPixelBorder(frame, inset, thickness)
    local px = frame.artPixelBorder
    if px then
        local pp = E:PixelSize(frame)
        if pp > 0 and thickness and thickness > 0 then
            px._pixelMul = math.max(1, math.floor((thickness / pp) + 0.5))
        end
    end
end

function E:SetPixelBorderColor(frame, r, g, b, a)
    paintPixelBorder(frame, r or 0, g or 0, b or 0, a or 1)
end

function E:HidePixelBorder(frame)
    showPixelBorder(frame, false)
end

function E:ShowPixelBorder(frame)
    showPixelBorder(frame, true)
end

function E:SetTemplate(frame, template)
    if not frame or not frame.GetObjectType then
        return
    end

    ensureBackdrop(frame)

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

local PIXEL_EDGE_FILES = {
    ["Interface\\Buttons\\WHITE8x8"] = true,
    ["Interface\\Buttons\\WHITE8X8"] = true
}

local function isPixelEdge(edgeFile)
    if not edgeFile then
        return false
    end
    if edgeFile == E.media.blankTex then
        return true
    end
    return PIXEL_EDGE_FILES[edgeFile] == true
end

function E:ApplyOuterBorder(target, opts)
    if not target or not target.GetObjectType then
        return nil
    end
    opts = opts or {}

    local container = target._artOuterBorder
    if not container then
        container = CreateFrame("Frame", nil, target, "BackdropTemplate")
        container:SetFrameLevel((target:GetFrameLevel() or 0) + 1)
        container:Hide()
        target._artOuterBorder = container
    end

    local edgeFile = opts.edgeFile
    local edgeSize = tonumber(opts.edgeSize) or 0
    if opts.enabled == false or not edgeFile or edgeSize <= 0 then
        showPixelBorder(container, false)
        if container.SetBackdrop then
            container:SetBackdrop(nil)
        end
        container._artMode = nil
        container._artEdgeFile = nil
        container._artEdgeSize = nil
        container:Hide()
        return container
    end

    local r = opts.r or 0
    local g = opts.g or 0
    local b = opts.b or 0
    local a = opts.a or 1

    if isPixelEdge(edgeFile) then
        if container._artMode ~= "pixel" and container.SetBackdrop then
            container:SetBackdrop(nil)
        end
        container._artMode = "pixel"
        local pixelMul = math.max(1, math.floor(edgeSize + 0.5))
        local thickness = E:PixelSize(target) * pixelMul
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", target, "TOPLEFT", -thickness, thickness)
        container:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", thickness, -thickness)

        local px = buildPixelBorder(container, "OVERLAY", 7)
        px._pixelMul = pixelMul
        layoutPixelBorder(container, 0, thickness)
        paintPixelBorder(container, r, g, b, a)
        showPixelBorder(container, true)

        local boundTarget = target
        local boundMul = pixelMul
        px._refresh = function()
            local t = E:PixelSize(boundTarget) * boundMul
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", boundTarget, "TOPLEFT", -t, t)
            container:SetPoint("BOTTOMRIGHT", boundTarget, "BOTTOMRIGHT", t, -t)
            px._pixelMul = boundMul
            layoutPixelBorder(container, 0, t)
        end

        container._artEdgeFile = edgeFile
        container._artEdgeSize = edgeSize
        container:Show()
    else
        showPixelBorder(container, false)
        if container._artEdgeFile ~= edgeFile or container._artEdgeSize ~= edgeSize or container._artMode ~= "edge" then
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", target, "TOPLEFT", -edgeSize, edgeSize)
            container:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", edgeSize, -edgeSize)
            container:SetBackdrop({
                edgeFile = edgeFile,
                edgeSize = edgeSize,
                insets = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            })
            container._artEdgeFile = edgeFile
            container._artEdgeSize = edgeSize
            container._artMode = "edge"
        end
        container:SetBackdropBorderColor(r, g, b, a)
        container:Show()
    end
    return container
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
    self:ApplyFontString(fs, font, targetSize, outline)
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
            self:ApplyFontString(fs, font, baseSize + (delta or 0), outline)
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
    for frame in pairs(E.pixelBorderedFrames) do
        if frame and frame.GetObjectType and not frame:IsForbidden() then
            local px = frame.artPixelBorder
            if px and px._refresh then
                local ok, err = pcall(px._refresh)
                if not ok then
                    geterrorhandler()(err)
                end
            end
        end
    end
    E:UpdateMediaBackdropColors()
end

function E:InitializePixelPerfect()
    E._recomputePixelPerfect()
    if self.RegisterEvent then
        self:RegisterEvent("UI_SCALE_CHANGED", "RefreshPixelScale")
        self:RegisterEvent("DISPLAY_SIZE_CHANGED", "RefreshPixelScale")
        self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshPixelScale")
    end
    if UIParent and UIParent.SetScale and hooksecurefunc and not E._uiParentScaleHooked then
        E._uiParentScaleHooked = true
        local ok = pcall(hooksecurefunc, UIParent, "SetScale", function()
            if E.RefreshPixelScale then
                E:RefreshPixelScale()
            end
        end)
        if not ok then
            E._uiParentScaleHooked = nil
        end
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
    self:ApplyFontString(fs, font, size, outline)

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
