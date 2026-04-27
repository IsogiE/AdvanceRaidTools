local E, L, P = unpack(ART)

P.modules.QoL_Circle = {
    enabled = false,
    shape = "circle",
    size = 60,
    alpha = 0.5,
    color = {1, 0, 0, 1},
    showBorder = false,
    borderWidth = 2,
    borderColor = {0, 0, 0, 1},
    crosshairThickness = 2,
    strata = "MEDIUM",
    position = {
        point = "CENTER",
        x = 0,
        y = 0
    }
}

local Circle = E:NewModule("QoL_Circle", "AceEvent-3.0")

local CIRCLE_MASK = [[Interface\Masks\CircleMaskScalable]]
local WHITE = E.media.blankTex
local STRATA_VALUES = {"BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG"}

local function clampStrata(s)
    for _, v in ipairs(STRATA_VALUES) do
        if v == s then
            return s
        end
    end
    return "MEDIUM"
end

function Circle:OnEnable()
    self:EnsureFrame()
    self:RegisterMessage("ART_PROFILE_CHANGED", "Apply")
    self:RegisterEvent("PLAYER_LOGIN", "Apply")
    self:Apply()
end

function Circle:OnDisable()
    if self.frame then
        self.frame:Hide()
    end
    self:UnregisterAllMessages()
    self:UnregisterAllEvents()
end

function Circle:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local f = CreateFrame("Frame", "ART_QoL_CircleFrame", UIParent)
    f:SetIgnoreParentScale(true)
    f:SetFrameStrata("MEDIUM")
    f:EnableMouse(false)

    f.fill = f:CreateTexture(nil, "ARTWORK")
    f.fill:SetAllPoints()

    f.border = f:CreateTexture(nil, "BACKGROUND")

    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints()
    f.mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    f.borderMask = f:CreateMaskTexture()
    f.borderMask:SetAllPoints(f.border)
    f.borderMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    f.crosshairH = f:CreateTexture(nil, "ARTWORK")
    f.crosshairH:SetTexture(WHITE)
    f.crosshairV = f:CreateTexture(nil, "ARTWORK")
    f.crosshairV:SetTexture(WHITE)

    self.frame = f
    return f
end

function Circle:Apply()
    if not self:IsEnabled() then
        if self.frame then
            self.frame:Hide()
        end
        return
    end

    local db = self.db
    local f = self:EnsureFrame()

    f:SetSize(db.size, db.size)
    f:SetAlpha(db.alpha)
    f:SetFrameStrata(clampStrata(db.strata))

    local pos = db.position
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)

    self:ApplyShape()
    f:Show()
end

function Circle:ApplyShape()
    local f = self.frame
    local db = self.db
    local r, g, b, a = unpack(db.color)

    -- Reset all visual pieces
    f.fill:Hide()
    f.border:Hide()
    f.crosshairH:Hide()
    f.crosshairV:Hide()
    f.fill:RemoveMaskTexture(f.mask)
    f.border:RemoveMaskTexture(f.borderMask)

    if db.shape == "crosshair" then
        local thick = db.crosshairThickness or 2
        f.crosshairH:SetSize(db.size, thick)
        f.crosshairV:SetSize(thick, db.size)
        f.crosshairH:ClearAllPoints()
        f.crosshairH:SetPoint("CENTER", f, "CENTER")
        f.crosshairV:ClearAllPoints()
        f.crosshairV:SetPoint("CENTER", f, "CENTER")
        f.crosshairH:SetVertexColor(r, g, b, a)
        f.crosshairV:SetVertexColor(r, g, b, a)
        f.crosshairH:Show()
        f.crosshairV:Show()
        return
    end

    -- Circle / Square share the same fill + optional border
    f.fill:SetTexture(WHITE)
    f.fill:SetVertexColor(r, g, b, a)
    f.fill:Show()

    if db.shape == "circle" then
        f.fill:AddMaskTexture(f.mask)
    end

    if db.showBorder then
        local br, bg, bb, ba = unpack(db.borderColor)
        local bw = db.borderWidth or 2
        local borderSize = db.size + bw * 2
        f.border:SetTexture(WHITE)
        f.border:SetVertexColor(br, bg, bb, ba)
        f.border:SetSize(borderSize, borderSize)
        f.border:ClearAllPoints()
        f.border:SetPoint("CENTER", f, "CENTER")
        if db.shape == "circle" then
            f.border:AddMaskTexture(f.borderMask)
        end
        f.border:Show()
    end
end

-- Called by settings so sliders/color-swatches update the live frame
function Circle:Refresh()
    if self:IsEnabled() then
        self:Apply()
    elseif self.frame then
        self.frame:Hide()
    end
end

-- Self-register with the parent at file-scope so the options panel picks it up
do
    local QoL = E:GetModule("QualityOfLife", true)
    if QoL and QoL.RegisterFeature then
        QoL:RegisterFeature("Circle", {
            order = 10,
            labelKey = "QoL_Circle",
            descKey = "QoL_CircleDesc",
            moduleName = "QoL_Circle"
        })
    end
end
