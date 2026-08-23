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

local barVisualState = setmetatable({}, {__mode = "k"})
local prdVisibilityState = setmetatable({}, {__mode = "k"})

local function prd()
    return _G.PersonalResourceDisplayFrame
end

local function secureCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end
    if securecallfunction then
        return securecallfunction(func, ...)
    end
    return func(...)
end

local function callBlizzardMethod(frame, methodName, ...)
    if not frame then
        return nil
    end
    if securecallmethod then
        return securecallmethod(frame, methodName, ...)
    end

    local method = frame[methodName]
    if type(method) ~= "function" then
        return nil
    end
    return secureCall(method, frame, ...)
end

local function updatePRDLayout(frame)
    callBlizzardMethod(frame, "UpdatePowerBarAnchor")
    callBlizzardMethod(frame, "UpdateAdditionalBarAnchors")
    callBlizzardMethod(frame, "UpdateFrameHeight")
end

local function setHealthShown(frame, shown)
    local hidden = not shown
    if (frame.hideHealth == true) ~= hidden then
        callBlizzardMethod(frame, "SetHideHealth", hidden)
    end
end

local function setPowerShown(frame, shown)
    local hidden = not shown
    if (frame.hidePower == true) ~= hidden then
        callBlizzardMethod(frame, "SetHidePower", hidden)
    end
end

local function setClassFrameShown(frame, shown)
    local hidden = not shown
    if (frame.hideClassInfo == true) ~= hidden then
        callBlizzardMethod(frame, "SetHideClassInfo", hidden)
    end
end

local function setAltPowerShown(frame, shown)
    local hidden = not shown
    if (frame.hideAltPower == true) ~= hidden then
        callBlizzardMethod(frame, "SetHideAltPower", hidden)
    end
end

local function capturePRDVisibility(frame)
    local state = prdVisibilityState[frame]
    if not state then
        state = {
            hideHealth = frame.hideHealth == true,
            hidePower = frame.hidePower == true,
            hideClassInfo = frame.hideClassInfo == true,
            hideAltPower = frame.hideAltPower == true
        }
        prdVisibilityState[frame] = state
    end
    return state
end

local function originalVisibility(state, key)
    return not state[key]
end

local function enablePRDForART(self_)
    if GetCVar(PRD_CVAR) == "1" then
        return
    end
    if self_._artOriginalPRDCVar == nil then
        self_._artOriginalPRDCVar = GetCVar(PRD_CVAR)
    end
    secureCall(SetCVar, PRD_CVAR, "1")
end

local function restorePRDCVar(self_)
    local original = self_._artOriginalPRDCVar
    if original == nil then
        return
    end
    self_._artOriginalPRDCVar = nil
    if GetCVar(PRD_CVAR) ~= original then
        secureCall(SetCVar, PRD_CVAR, original)
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

local function setFormattedNumberText(fontString, format, value)
    local ok = pcall(fontString.SetFormattedText, fontString, format, value)
    if not ok then
        fontString:SetText("")
    end
end

local function getBarVisualState(bar, create)
    local state = barVisualState[bar]
    if not state and create ~= false then
        state = {}
        barVisualState[bar] = state
    end
    return state
end

local function ensureBarOverlay(bar)
    local state = getBarVisualState(bar)
    if not state.overlay then
        -- The intermediate Frame isolates the FontString from the Blizzard
        -- StatusBar's secret BarValue/Text aspects in 12.1.
        state.overlay = CreateFrame("Frame", nil, bar)
        state.overlay:SetAllPoints(bar)
        state.overlay:SetFrameLevel((bar:GetFrameLevel() or 0) + 5)
    end
    return state.overlay, state
end

local function ensureBarText(bar)
    local overlay, state = ensureBarOverlay(bar)
    if not state.text then
        state.text = overlay:CreateFontString(nil, "OVERLAY")
        state.text:SetPoint("CENTER", overlay, "CENTER", 0, 0)
    end
    return state.text
end

local function hideBarText(bar)
    local state = getBarVisualState(bar, false)
    if state and state.text then
        state.text:Hide()
    end
end

local function prepareBarText(bar, fontSize)
    local fontString = ensureBarText(bar)
    fontString:SetFont(E:FetchModuleFont(), fontSize, "OUTLINE")
    return fontString
end

local function hideBlizzardStatusBarBackground(bar)
    if not bar or not bar.GetRegions then
        return false
    end

    local state = getBarVisualState(bar)
    state.hiddenRegions = state.hiddenRegions or {}

    local foundNewPRDArt = false
    if not state.backgroundScanned then
        for _, region in ipairs({bar:GetRegions()}) do
            if region.GetAtlas and region:GetAtlas() == PRD_STATUS_BAR_BACKGROUND_ATLAS then
                state.hiddenRegions[region] = true
            end
        end
        state.backgroundScanned = true
    end

    for region in pairs(state.hiddenRegions) do
        if region then
            setRegionShown(region, false)
            foundNewPRDArt = true
        end
    end

    if foundNewPRDArt then
        if not state.background then
            state.background = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
            state.background:SetAllPoints(bar)
        end
        state.background:SetTexture(E.media.blankTex)
        state.background:SetVertexColor(0.2, 0.2, 0.2, 0.65)
        state.background:Show()
    end

    return foundNewPRDArt
end

local function restoreBlizzardStatusBarBackground(bar)
    if not bar then
        return
    end

    local state = getBarVisualState(bar, false)
    if not state then
        return
    end

    if state.hiddenRegions then
        for region in pairs(state.hiddenRegions) do
            setRegionShown(region, true)
        end
    end
    if state.background then
        state.background:Hide()
    end
end

local function applyCustomBorder(bar, show, color)
    hideBlizzardStatusBarBackground(bar)

    local overlay = ensureBarOverlay(bar)
    if not show then
        E:ApplyOuterBorder(overlay, {
            enabled = false
        })
        return
    end
    local border = E:ApplyOuterBorder(overlay, {
        enabled = true,
        edgeFile = E.media.blankTex,
        edgeSize = 1,
        r = color[1],
        g = color[2],
        b = color[3],
        a = color[4] or 1
    })
    if border and border.SetFrameLevel then
        border:SetFrameLevel((overlay:GetFrameLevel() or 0) + 5)
    end
end

local function hideCustomBorder(bar)
    restoreBlizzardStatusBarBackground(bar)
    local state = getBarVisualState(bar, false)
    if state and state.overlay then
        E:ApplyOuterBorder(state.overlay, {
            enabled = false
        })
    end
end

local RESOURCE_TEXT_TICK = 0.1

local function stopResourceTextTicker()
    if Resources.textTicker then
        Resources.textTicker:Cancel()
        Resources.textTicker = nil
    end
end

local function ensureResourceTextTicker()
    if Resources.textTicker then
        return
    end
    Resources.textTicker = C_Timer.NewTicker(RESOURCE_TEXT_TICK, function()
        if not Resources:IsActive() then
            return
        end
        local db = Resources.db
        local frame = prd()
        if not frame then
            return
        end
        if db.showPowerBar and db.powerTextMode ~= "off" then
            Resources:UpdatePowerText(frame.PowerBar)
        end
        if db.showHealthBar and db.healthTextMode ~= "off" then
            local container = frame.HealthBarsContainer
            Resources:UpdateHealthText(container and container.healthBar)
        end
    end)
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
        hideBarText(bar)
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

    prepareBarText(bar, db.fontSize or 12)
    ensureResourceTextTicker()
    self_:UpdatePowerText(bar)
    updatePRDLayout(frame)
end

local function attachHealthTextTicker(bar)
    ensureResourceTextTicker()
end

local function applyHealthBar(self_, frame)
    local db = self_.db
    local container = frame.HealthBarsContainer
    if not container then
        return
    end

    setHealthShown(frame, db.showHealthBar)
    if not db.showHealthBar then
        if container.healthBar then
            hideBarText(container.healthBar)
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
        prepareBarText(container.healthBar, db.healthFontSize or 12)
        attachHealthTextTicker(container.healthBar)
    end

    self_:UpdateHealthText(container.healthBar)
    updatePRDLayout(frame)
end

local function applyClassFrame(self_, frame)
    local db = self_.db
    -- Blizzard will decide whether this class actually has a class frame.
    -- Avoid calling HasClassInfo before PRD's own OnShow/Setup has run.
    setClassFrameShown(frame, db.showClassFrame)
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
        hideBarText(bar)
        return
    end

    local state = getBarVisualState(bar, false)
    if (not state or not state.text) and InCombatLockdown() then
        return
    end
    local fs = ensureBarText(bar)
    fs:Show()

    if mode == "percent" then
        local ok, pct = pcall(UnitPowerPercent, "player", nil, false, CurveConstants and CurveConstants.ScaleTo100 or nil)
        if ok then
            setFormattedNumberText(fs, "%.0f%%", pct)
        else
            fs:SetText("")
        end
    elseif mode == "numeric" then
        local ok, power = pcall(UnitPower, "player")
        if ok then
            setFormattedNumberText(fs, "%d", power)
        else
            fs:SetText("")
        end
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
        hideBarText(bar)
        return
    end

    local state = getBarVisualState(bar, false)
    if (not state or not state.text) and InCombatLockdown() then
        return
    end
    local fs = ensureBarText(bar)
    fs:Show()

    if mode == "percent" then
        local ok, pct = pcall(UnitHealthPercent, "player", false, CurveConstants and CurveConstants.ScaleTo100 or nil)
        if ok then
            setFormattedNumberText(fs, "%.0f%%", pct)
        else
            fs:SetText("")
        end
    elseif mode == "numeric" then
        local ok, health = pcall(UnitHealth, "player")
        if ok then
            setFormattedNumberText(fs, "%d", health)
        else
            fs:SetText("")
        end
    end
end

local function hidePRDChildren(frame)
    capturePRDVisibility(frame)
    setClassFrameShown(frame, false)
    setAltPowerShown(frame, false)
    setPowerShown(frame, false)
    setHealthShown(frame, false)
    updatePRDLayout(frame)
end

-- Restore Blizzard defaults for anything we changed
local function revert(self_)
    local frame = prd()
    if not frame then
        return
    end
    local visibility = prdVisibilityState[frame]

    if frame.HealthBarsContainer then
        local c = frame.HealthBarsContainer
        if visibility then
            setHealthShown(frame, originalVisibility(visibility, "hideHealth"))
        end
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
            hideBarText(c.healthBar)
        end
    end

    if frame.PowerBar then
        if visibility then
            setPowerShown(frame, originalVisibility(visibility, "hidePower"))
        end
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
        hideBarText(frame.PowerBar)
    end

    if frame.ClassFrameContainer and visibility then
        setAltPowerShown(frame, originalVisibility(visibility, "hideAltPower"))
        setClassFrameShown(frame, originalVisibility(visibility, "hideClassInfo"))
    end
    updatePRDLayout(frame)
    prdVisibilityState[frame] = nil
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
        stopResourceTextTicker()
        restorePRDCVar(self)
        revert(self)
        return
    end

    if roleActive(self.db) then
        enablePRDForART(self)

        local frame = prd()
        if not frame then
            return -- will apply on next PLAYER_ENTERING_WORLD once Blizzard creates it
        end

        local visibility = capturePRDVisibility(frame)
        applyHealthBar(self, frame)
        applyPowerBar(self, frame)
        setAltPowerShown(frame, originalVisibility(visibility, "hideAltPower"))
        applyClassFrame(self, frame)
        return
    end

    if not self.db.hideBlizzardPRD then
        stopResourceTextTicker()
        restorePRDCVar(self)
        revert(self)
        return
    end

    stopResourceTextTicker()
    local frame = prd()
    if frame then
        hidePRDChildren(frame)
    end
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
    stopResourceTextTicker()
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
