local E, L, P = unpack(ART)

P.modules.QoL_Resources = {
    enabled = false,

    roles = {
        TANK = true,
        HEALER = true,
        DAMAGER = true
    },

    -- Visibility
    showHealthBar = true,
    showPowerBar = true,
    showClassFrame = true,

    -- Health bar
    healthWidth = 200,
    healthHeight = 15,
    healthTexture = "Blizzard",
    showHealthBorder = true,
    healthBorderColor = {0, 0, 0, 1},
    healthTextMode = "off",
    healthFontSize = 12,

    -- Power bar
    powerWidth = 200,
    powerHeight = 20,
    texture = "Blizzard",
    showPowerBorder = true,
    powerBorderColor = {0, 0, 0, 1},
    powerTextMode = "off",
    fontSize = 12
}

local Resources = E:NewModule("QoL_Resources", "AceEvent-3.0")

local PRD_CVAR = "nameplateShowSelf"

local hooksInstalled = false

local function prd()
    return _G.PersonalResourceDisplayFrame
end

local function roleActive(db)
    local role = E:GetPlayerRole()
    if not role then
        -- Before spec is known, err on the side of active
        return true
    end
    return db.roles[role] and true or false
end

function Resources:IsActive()
    return self:IsEnabled() and roleActive(self.db)
end

-- Visuals

local WHITE = E.media.blankTex

local function ensureCustomBorder(bar)
    if bar.artBorder then
        return bar.artBorder
    end

    local borders = {}
    for _, key in ipairs({"top", "bottom", "left", "right"}) do
        local t = bar:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        borders[key] = t
    end

    borders.top:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    borders.top:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
    borders.top:SetHeight(1)

    borders.bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
    borders.bottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    borders.bottom:SetHeight(1)

    borders.left:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    borders.left:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -1, -1)
    borders.left:SetWidth(1)

    borders.right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 1, 1)
    borders.right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    borders.right:SetWidth(1)

    bar.artBorder = borders
    return borders
end

local function applyCustomBorder(bar, show, color)
    local borders = ensureCustomBorder(bar)
    for _, t in pairs(borders) do
        if show then
            t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
            t:Show()
        else
            t:Hide()
        end
    end
end

local function hideCustomBorder(bar)
    if not bar.artBorder then
        return
    end
    for _, t in pairs(bar.artBorder) do
        t:Hide()
    end
end

local function applyPowerBar(self_, frame)
    local db = self_.db
    local bar = frame.PowerBar
    if not bar then
        return
    end

    if db.showPowerBar then
        bar:SetSize(db.powerWidth, db.powerHeight)
        bar:Show()
    else
        bar:Hide()
        return
    end

    local tex = E:FetchStatusBar(db.texture)
    if tex then
        bar:SetStatusBarTexture(tex)
        if bar.Texture then
            bar.Texture:SetTexture(tex)
        end
    end

    -- Hide Blizzard's border and draw our own
    if bar.Border then
        bar.Border:Hide()
    end
    applyCustomBorder(bar, db.showPowerBorder, db.powerBorderColor)

    self_:UpdatePowerText(bar)
end

local HEALTH_TEXT_TICK = 0.1

local function attachHealthTextTicker(bar)
    if bar.artHealthTickerAttached then
        return
    end
    bar.artHealthTickerAttached = true
    local elapsed = 0
    bar:HookScript("OnUpdate", function(self_, dt)
        elapsed = elapsed + dt
        if elapsed < HEALTH_TEXT_TICK then
            return
        end
        elapsed = 0
        if not Resources:IsActive() then
            return
        end
        local db = Resources.db
        if not db.showHealthBar or db.healthTextMode == "off" then
            return
        end
        Resources:UpdateHealthText(self_)
    end)
end

local function applyHealthBar(self_, frame)
    local db = self_.db
    local container = frame.HealthBarsContainer
    if not container then
        return
    end

    container:SetShown(db.showHealthBar)
    if not db.showHealthBar then
        if container.healthBar and container.healthBar.artHealthText then
            container.healthBar.artHealthText:Hide()
        end
        return
    end

    container:ClearAllPoints()
    container:SetPoint("TOP", frame, "TOP", 0, 0)
    container:SetSize(db.healthWidth, db.healthHeight)

    local tex = E:FetchStatusBar(db.healthTexture)
    if tex and container.healthBar and container.healthBar.barTexture then
        container.healthBar.barTexture:SetTexture(tex)
    end

    if container.border then
        container.border:Hide()
    end
    if container.healthBar then
        applyCustomBorder(container.healthBar, db.showHealthBorder, db.healthBorderColor)
        attachHealthTextTicker(container.healthBar)
    end

    self_:UpdateHealthText(container.healthBar)
end

local function applyClassFrame(self_, frame)
    local db = self_.db
    local cfc = frame.ClassFrameContainer
    if cfc then
        cfc:SetShown(db.showClassFrame)
    end
end

function Resources:UpdatePowerText(bar)
    bar = bar or (prd() and prd().PowerBar)
    if not bar then
        return
    end

    local db = self.db
    local mode = db.powerTextMode or "off"

    if mode == "off" or not self:IsActive() then
        if bar.artPowerText then
            bar.artPowerText:Hide()
        end
        return
    end

    if not bar.artPowerText then
        bar.artPowerText = bar:CreateFontString(nil, "OVERLAY")
        bar.artPowerText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    end
    local fs = bar.artPowerText
    fs:SetFont(E:FetchModuleFont(), db.fontSize or 12, "OUTLINE")
    fs:Show()

    if mode == "percent" then
        local pct = UnitPowerPercent("player", nil, false, CurveConstants and CurveConstants.ScaleTo100 or nil)
        if pct ~= nil then
            fs:SetFormattedText("%.0f%%", pct)
        else
            fs:SetText("")
        end
    elseif mode == "numeric" then
        fs:SetFormattedText("%d", UnitPower("player"))
    end
end

function Resources:UpdateHealthText(bar)
    if not bar then
        local frame = prd()
        if frame and frame.HealthBarsContainer then
            bar = frame.HealthBarsContainer.healthBar
        end
    end
    if not bar then
        return
    end

    local db = self.db
    local mode = db.healthTextMode or "off"

    if mode == "off" or not self:IsActive() or not db.showHealthBar then
        if bar.artHealthText then
            bar.artHealthText:Hide()
        end
        return
    end

    if not bar.artHealthText then
        bar.artHealthText = bar:CreateFontString(nil, "OVERLAY")
        bar.artHealthText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    end
    local fs = bar.artHealthText
    fs:SetFont(E:FetchModuleFont(), db.healthFontSize or 12, "OUTLINE")
    fs:Show()

    if mode == "percent" then
        local pct = UnitHealthPercent("player", false, CurveConstants and CurveConstants.ScaleTo100 or nil)
        if pct ~= nil then
            fs:SetFormattedText("%.0f%%", pct)
        else
            fs:SetText("")
        end
    elseif mode == "numeric" then
        fs:SetFormattedText("%d", UnitHealth("player"))
    end
end

-- Restore Blizzard defaults for anything we changed
local function revert(self_)
    local frame = prd()
    if not frame then
        return
    end

    if frame.HealthBarsContainer then
        local c = frame.HealthBarsContainer
        c:Show()
        c:ClearAllPoints()
        c:SetPoint("LEFT", frame, "LEFT", 0, 0)
        c:SetPoint("TOP", frame, "TOP", 0, 0)
        c:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        c:SetHeight(15)
        if c.border then
            c.border:Show()
            c.border:SetVertexColor(0, 0, 0)
            c.border:SetAlpha(0.5)
        end
        if c.healthBar then
            hideCustomBorder(c.healthBar)
            if c.healthBar.barTexture then
                c.healthBar.barTexture:SetTexture("Interface/TargetingFrame/UI-TargetingFrame-BarFill")
            end
            if c.healthBar.artHealthText then
                c.healthBar.artHealthText:Hide()
            end
        end
    end

    if frame.PowerBar then
        frame.PowerBar:Show()
        frame.PowerBar:SetSize(200, 15)
        hideCustomBorder(frame.PowerBar)
        if frame.PowerBar.Border then
            frame.PowerBar.Border:Show()
            frame.PowerBar.Border:SetAlpha(0.5)
            frame.PowerBar.Border:SetVertexColor(0, 0, 0)
        end
        if frame.PowerBar.Texture then
            frame.PowerBar.Texture:SetTexture("Interface/TargetingFrame/UI-TargetingFrame-BarFill")
        end
        if frame.PowerBar.artPowerText then
            frame.PowerBar.artPowerText:Hide()
        end
    end

    if frame.ClassFrameContainer then
        frame.ClassFrameContainer:Show()
    end
end

-- Pushes current db state onto PRD
function Resources:Apply()
    if InCombatLockdown() then
        self._pendingApply = true
        return
    end
    self._pendingApply = nil

    if not self:IsActive() then
        revert(self)
        return
    end

    if GetCVar(PRD_CVAR) == "0" then
        SetCVar(PRD_CVAR, "1")
    end

    self:InstallHooks()

    local frame = prd()
    if not frame then
        return -- will apply on next PLAYER_ENTERING_WORLD once Blizzard creates it
    end

    applyHealthBar(self, frame)
    applyPowerBar(self, frame)
    applyClassFrame(self, frame)
end

-- rely on self:IsActive() inside to no-op when disabled
function Resources:InstallHooks()
    if hooksInstalled then
        return
    end
    local frame = prd()
    if not frame then
        return
    end

    hooksecurefunc(frame, "SetupHealthBar", function(self_)
        if Resources:IsActive() then
            applyHealthBar(Resources, self_)
        end
    end)

    hooksecurefunc(frame, "SetupPowerBar", function(self_)
        if Resources:IsActive() then
            applyPowerBar(Resources, self_)
        end
    end)

    hooksecurefunc(frame, "UpdatePower", function(self_)
        if Resources:IsActive() then
            Resources:UpdatePowerText(self_.PowerBar)
        end
    end)

    hooksecurefunc(frame, "UpdateHealth", function(self_)
        if Resources:IsActive() then
            local hb = self_.HealthBarsContainer and self_.HealthBarsContainer.healthBar
            Resources:UpdateHealthText(hb)
        end
    end)

    hooksecurefunc(frame, "SetupClassBar", function(self_)
        if Resources:IsActive() then
            applyClassFrame(Resources, self_)
        end
    end)

    hooksInstalled = true
end

-- Lifecycle

function Resources:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Apply")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Apply")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Apply")
    self:Apply()
end

function Resources:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if InCombatLockdown() then
        self._pendingRevert = true
        return
    end
    revert(self)
end

function Resources:OnSpecChanged()
    self:Apply()
end

function Resources:OnRegenEnabled()
    if self._pendingApply then
        self:Apply()
    end
    if self._pendingRevert then
        self._pendingRevert = nil
        revert(self)
    end
end

-- Called by settings live-preview
function Resources:Refresh()
    self:Apply()
end

do
    local QoL = E:GetModule("QualityOfLife", true)
    if QoL and QoL.RegisterFeature then
        QoL:RegisterFeature("Resources", {
            order = 20,
            labelKey = "QoL_Resources",
            descKey = "QoL_ResourcesDesc",
            moduleName = "QoL_Resources"
        })
    end
end
