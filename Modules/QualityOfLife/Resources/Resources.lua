local E, L = unpack(ART)

E:RegisterModuleDefaults("QoL_Resources", {
    enabled = false,

    roles = {
        TANK = true,
        HEALER = true,
        DAMAGER = true
    },

    hideBlizzardPRD = false,

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
})

local Resources = E:NewModule("QoL_Resources", "AceEvent-3.0")

local PRD_CVAR = "nameplateShowSelf"
local PRD_STATUS_BAR_BACKGROUND_ATLAS = "UI-HUD-CoolDownManager-Bar-BG"

local hooksInstalled = false

local function prd()
    return _G.PersonalResourceDisplayFrame
end

local function ensurePRDSetup(frame)
    if frame and frame.Setup and not frame.hasBeenSetup then
        frame:Setup()
    end
end

local function updatePRDLayout(frame)
    if frame.UpdatePowerBarAnchor then
        frame:UpdatePowerBarAnchor()
    end
    if frame.UpdateAdditionalBarAnchors then
        frame:UpdateAdditionalBarAnchors()
    end
    if frame.UpdateFrameHeight then
        frame:UpdateFrameHeight()
    end
end

local function hasClassFrame(frame)
    if not frame then
        return false
    end
    if frame.HasClassInfo then
        return frame:HasClassInfo()
    end
    if frame.classFrame or _G.prdClassFrame then
        return true
    end
    return frame.ClassFrameContainer and frame.ClassFrameContainer.yOffset ~= nil
end

local function setHealthShown(frame, shown)
    if frame.SetHideHealth then
        frame:SetHideHealth(not shown)
    elseif frame.HealthBarsContainer then
        frame.HealthBarsContainer:SetShown(shown)
    end
end

local function setPowerShown(frame, shown)
    if frame.SetHidePower then
        frame:SetHidePower(not shown)
    elseif frame.PowerBar then
        frame.PowerBar:SetShown(shown)
    end
end

local function setClassFrameShown(frame, shown)
    if frame.SetHideClassInfo then
        frame:SetHideClassInfo(not shown)
    elseif frame.ClassFrameContainer then
        frame.ClassFrameContainer:SetShown(shown and hasClassFrame(frame))
    end
end

local function setAltPowerShown(frame, shown)
    if frame.SetHideAltPower then
        frame:SetHideAltPower(not shown)
    elseif frame.AlternatePowerBar then
        frame.AlternatePowerBar:SetShown(shown and frame.AlternatePowerBar.alternatePowerRequirementsMet)
    end
end

local function enablePRDForART(self_)
    if GetCVar(PRD_CVAR) == "1" then
        return
    end
    if self_._artOriginalPRDCVar == nil then
        self_._artOriginalPRDCVar = GetCVar(PRD_CVAR)
    end
    SetCVar(PRD_CVAR, "1")
end

local function restorePRDCVar(self_)
    local original = self_._artOriginalPRDCVar
    if original == nil then
        return
    end
    self_._artOriginalPRDCVar = nil
    if GetCVar(PRD_CVAR) ~= original then
        SetCVar(PRD_CVAR, original)
    end
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

local function setRegionShown(region, shown)
    if region.SetShown then
        region:SetShown(shown)
    elseif shown and region.Show then
        region:Show()
    elseif not shown and region.Hide then
        region:Hide()
    end
end

local function hideBlizzardStatusBarBackground(bar)
    if not bar or not bar.GetRegions then
        return false
    end

    local hiddenRegions = bar._artPRDHiddenRegions
    if not hiddenRegions then
        hiddenRegions = {}
        bar._artPRDHiddenRegions = hiddenRegions
    end

    local foundNewPRDArt = false
    for _, region in ipairs({bar:GetRegions()}) do
        if region.GetAtlas and region:GetAtlas() == PRD_STATUS_BAR_BACKGROUND_ATLAS then
            hiddenRegions[region] = true
            setRegionShown(region, false)
            foundNewPRDArt = true
        end
    end

    if foundNewPRDArt then
        local bg = bar._artPRDBackground
        if not bg then
            bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetAllPoints(bar)
            bar._artPRDBackground = bg
        end
        bg:SetTexture(E.media.blankTex)
        bg:SetVertexColor(0.2, 0.2, 0.2, 0.65)
        bg:Show()
    end

    return foundNewPRDArt
end

local function restoreBlizzardStatusBarBackground(bar)
    if not bar then
        return
    end

    if bar._artPRDHiddenRegions then
        for region in pairs(bar._artPRDHiddenRegions) do
            setRegionShown(region, true)
        end
    end
    if bar._artPRDBackground then
        bar._artPRDBackground:Hide()
    end
end

local function applyCustomBorder(bar, show, color)
    hideBlizzardStatusBarBackground(bar)

    if not show then
        E:ApplyOuterBorder(bar, {
            enabled = false
        })
        return
    end
    local border = E:ApplyOuterBorder(bar, {
        enabled = true,
        edgeFile = E.media.blankTex,
        edgeSize = 1,
        r = color[1],
        g = color[2],
        b = color[3],
        a = color[4] or 1
    })
    if border and border.SetFrameLevel then
        border:SetFrameLevel((bar:GetFrameLevel() or 0) + 10)
    end
end

local function hideCustomBorder(bar)
    restoreBlizzardStatusBarBackground(bar)
    E:ApplyOuterBorder(bar, {
        enabled = false
    })
end

local function applyPowerBar(self_, frame)
    local db = self_.db
    local bar = frame.PowerBar
    if not bar then
        return
    end

    setPowerShown(frame, db.showPowerBar)
    if db.showPowerBar then
        bar:SetSize(db.powerWidth, db.powerHeight)
    else
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
    updatePRDLayout(frame)
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

    setHealthShown(frame, db.showHealthBar)
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
    if tex and container.healthBar then
        if container.healthBar.SetStatusBarTexture then
            container.healthBar:SetStatusBarTexture(tex)
        end
        if container.healthBar.barTexture then
            container.healthBar.barTexture:SetTexture(tex)
        end
    end

    if container.border then
        container.border:Hide()
    end
    if container.healthBar then
        applyCustomBorder(container.healthBar, db.showHealthBorder, db.healthBorderColor)
        attachHealthTextTicker(container.healthBar)
    end

    self_:UpdateHealthText(container.healthBar)
    updatePRDLayout(frame)
end

local function applyClassFrame(self_, frame)
    local db = self_.db
    setClassFrameShown(frame, db.showClassFrame and hasClassFrame(frame))
    updatePRDLayout(frame)
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

local function hidePRDChildren(frame)
    ensurePRDSetup(frame)
    setClassFrameShown(frame, false)
    setAltPowerShown(frame, false)
    setPowerShown(frame, false)
    setHealthShown(frame, false)
end

-- Restore Blizzard defaults for anything we changed
local function revert(self_)
    local frame = prd()
    if not frame then
        return
    end

    if frame.HealthBarsContainer then
        local c = frame.HealthBarsContainer
        setHealthShown(frame, true)
        c:ClearAllPoints()
        c:SetPoint("TOP", frame, "TOP", 0, 0)
        if not frame.UpdateBarWidth then
            c:SetPoint("LEFT", frame, "LEFT", 0, 0)
            c:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        end
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
        setPowerShown(frame, true)
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
        setAltPowerShown(frame, true)
        setClassFrameShown(frame, hasClassFrame(frame))
    end
    updatePRDLayout(frame)
end

-- Pushes current db state onto PRD
function Resources:Apply()
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("QoL_Resources:Apply", function()
            if self:IsEnabled() then
                self:Apply()
            end
        end)
        return
    end

    if not self:IsEnabled() then
        restorePRDCVar(self)
        revert(self)
        return
    end

    if roleActive(self.db) then
        enablePRDForART(self)

        self:InstallHooks()

        local frame = prd()
        if not frame then
            return -- will apply on next PLAYER_ENTERING_WORLD once Blizzard creates it
        end

        ensurePRDSetup(frame)
        applyHealthBar(self, frame)
        applyPowerBar(self, frame)
        applyClassFrame(self, frame)
        return
    end

    if not self.db.hideBlizzardPRD then
        restorePRDCVar(self)
        revert(self)
        return
    end

    self:InstallHooks()
    local frame = prd()
    if frame then
        hidePRDChildren(frame)
    end
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
        if not Resources:IsEnabled() then
            return
        end
        if Resources:IsActive() then
            applyHealthBar(Resources, self_)
        elseif Resources.db.hideBlizzardPRD then
            if self_.HealthBarsContainer then
                self_.HealthBarsContainer:Hide()
            end
        end
    end)

    hooksecurefunc(frame, "SetupPowerBar", function(self_)
        if not Resources:IsEnabled() then
            return
        end
        if Resources:IsActive() then
            applyPowerBar(Resources, self_)
        elseif Resources.db.hideBlizzardPRD then
            if self_.PowerBar then
                self_.PowerBar:Hide()
            end
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
        if not Resources:IsEnabled() then
            return
        end
        if Resources:IsActive() then
            applyClassFrame(Resources, self_)
        elseif Resources.db.hideBlizzardPRD then
            if self_.ClassFrameContainer then
                self_.ClassFrameContainer:Hide()
            end
        end
    end)

    hooksInstalled = true
end

-- Lifecycle

function Resources:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Apply")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Apply")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Apply")
    self:Apply()
end

function Resources:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("QoL_Resources:Revert", function()
            if not self:IsEnabled() then
                restorePRDCVar(self)
                revert(self)
            end
        end)
        return
    end
    restorePRDCVar(self)
    revert(self)
end

function Resources:OnSpecChanged()
    self:Apply()
end

-- Called by settings live-preview
function Resources:Refresh()
    self:Apply()
end

E:RegisterQoLFeature("Resources", {
    order = 20,
    labelKey = "QoL_Resources",
    descKey = "QoL_ResourcesDesc",
    moduleName = "QoL_Resources"
})
