local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_VashnikWaveCross", {
    enabled = false,
    color = {1, 0.82, 0, 0.55},
    thickness = 2,
    displayMode = "before",
    secondsBefore = 7
})

local VASHNIK_ENCOUNTER_ID = 3455
local PLAGUE_FROTH_SPELL_ID = 1281907
local UPDATE_INTERVAL = 0.05
local CROSS_TEXTURE_SIZE = 2048
local CROSS_TEXTURE = [[Interface\AddOns\AdvanceRaidTools\Media\VashnikWaveCross.tga]]

local VashnikWaveCross = E:NewModule("BossMods_VashnikWaveCross", "AceEvent-3.0")
local BossMods = E:GetModule("BossMods")

local function showRegion(region)
    local metatable = getmetatable(region)
    local methods = metatable and type(metatable.__index) == "table" and metatable.__index
    local show = methods and methods.Show or region.Show
    if show then
        pcall(show, region)
    end
end

function VashnikWaveCross:EnsureFrame()
    if self.frame then
        return true
    end

    local frame = CreateFrame("Frame", "ART_VashnikWaveCross", UIParent)
    frame:SetSize(80, 80)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)

    local cross = frame:CreateTexture(nil, "ARTWORK")
    cross:SetPoint("CENTER", frame, "CENTER", 0, 0)
    cross:SetTexture(CROSS_TEXTURE)

    self.frame = frame
    self.cross = cross
    return true
end

function VashnikWaveCross:EnsureCompassFacingSource()
    if not MinimapCompassTexture then
        return
    end

    if self.originalRotateMinimap == nil then
        self.originalRotateMinimap = GetCVar("rotateMinimap")
    end
    if GetCVar("rotateMinimap") ~= "1" and C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "rotateMinimap", "1")
    end

    self.compassLoans = self.compassLoans or {}
    local region = MinimapCompassTexture
    while region and region ~= UIParent do
        if not region:IsShown() then
            if not self.compassLoans[region] then
                self.compassLoans[region] = {
                    alpha = region:GetAlpha()
                }
                region:SetAlpha(0)
            end
            showRegion(region)
        end
        region = region:GetParent()
    end
end

function VashnikWaveCross:ReleaseCompassFacingSource()
    for region, state in pairs(self.compassLoans or {}) do
        if region and region.Hide then
            region:Hide()
            region:SetAlpha(state.alpha or 1)
        end
    end
    wipe(self.compassLoans or {})

    if self.originalRotateMinimap ~= nil then
        if GetCVar("rotateMinimap") ~= self.originalRotateMinimap
            and C_CVar
            and C_CVar.SetCVar
        then
            pcall(C_CVar.SetCVar, "rotateMinimap", self.originalRotateMinimap)
        end
        self.originalRotateMinimap = nil
    end
end

function VashnikWaveCross:ApplySecretCompassRotation()
    if not (
        self.cross
        and MinimapCompassTexture
        and MinimapCompassTexture.GetRotation
    ) then
        return false
    end

    local ok = pcall(function()
        self.cross:SetRotation(MinimapCompassTexture:GetRotation())
    end)
    return ok
end

function VashnikWaveCross:ApplyAppearance()
    if not self:EnsureFrame() then
        return
    end

    local width = UIParent:GetWidth() or 1920
    local height = UIParent:GetHeight() or 1080
    local minimumExtent = math.sqrt(width * width + height * height) * 1.10
    local thickness = math.max(1, tonumber(self.db.thickness) or 2)
    local extent = math.max(minimumExtent, CROSS_TEXTURE_SIZE * thickness)
    local color = type(self.db.color) == "table" and self.db.color or {}
    local r = color[1] or color.r or 1
    local g = color[2] or color.g or 0.82
    local b = color[3] or color.b or 0
    local a = color[4] or color.a or 0.55

    self.cross:SetSize(extent, extent)
    self.cross:SetVertexColor(r, g, b, a)
end

function VashnikWaveCross:ApplyVisibility()
    if not self.frame or not self:IsEnabled() then
        return
    end

    local shouldShow = self.previewMode
        or (
            self.encounterActive
            and (
                self.db.displayMode == "always"
                or self.timedWindowActive
            )
        )

    if shouldShow then
        self.frame:Show()
        self:EnsureCompassFacingSource()
        self:ApplySecretCompassRotation()
    else
        self.frame:Hide()
        self:ReleaseCompassFacingSource()
    end
end

function VashnikWaveCross:CancelTriggerTimers(clearBar)
    self.triggerGeneration = (self.triggerGeneration or 0) + 1
    if self.showTimer then
        self.showTimer:Cancel()
        self.showTimer = nil
    end
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self.timedWindowActive = false
    if clearBar then
        self.plagueFrothEndsAt = nil
    end
end

function VashnikWaveCross:SchedulePlagueFrothWindow(timeRemaining)
    timeRemaining = tonumber(timeRemaining)
    if not timeRemaining or timeRemaining < 0 then
        return
    end

    self:CancelTriggerTimers(false)
    local generation = self.triggerGeneration
    local secondsBefore = math.max(
        0,
        math.min(30, tonumber(self.db.secondsBefore) or 7)
    )
    local showDelay = math.max(0, timeRemaining - secondsBefore)

    local function showCross()
        if generation ~= self.triggerGeneration or not self.encounterActive then
            return
        end
        self.showTimer = nil
        self.timedWindowActive = true
        self:ApplyVisibility()
    end

    if showDelay <= 0 then
        showCross()
    else
        self.showTimer = C_Timer.NewTimer(showDelay, showCross)
    end

    self.hideTimer = C_Timer.NewTimer(timeRemaining, function()
        if generation ~= self.triggerGeneration then
            return
        end
        self.hideTimer = nil
        self.plagueFrothEndsAt = nil
        self.timedWindowActive = false
        self:ApplyVisibility()
    end)
end

function VashnikWaveCross:OnBigWigsStartBar(_, _, time)
    if not self.encounterActive then
        return
    end
    time = tonumber(time)
    if not time or time <= 0 then
        return
    end

    self.plagueFrothEndsAt = GetTime() + time
    if self.db.displayMode ~= "always" then
        self:SchedulePlagueFrothWindow(time)
    end
end

function VashnikWaveCross:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end
    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "VashnikWaveCross",
        spellKeys = {PLAGUE_FROTH_SPELL_ID},
        onStartBar = function(key, text, time)
            self:OnBigWigsStartBar(key, text, time)
        end
    })
end

function VashnikWaveCross:UnhookBigWigs()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
end

function VashnikWaveCross:UpdateRotation()
    if not self.frame or not self.frame:IsShown() then
        return
    end
    self:EnsureCompassFacingSource()
    self:ApplySecretCompassRotation()
end

function VashnikWaveCross:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == VASHNIK_ENCOUNTER_ID
    self:CancelTriggerTimers(true)
    self:ApplyVisibility()
end

function VashnikWaveCross:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) == VASHNIK_ENCOUNTER_ID then
        self.encounterActive = false
        self:CancelTriggerTimers(true)
        self:ApplyVisibility()
    end
end

function VashnikWaveCross:SetPreviewMode(value)
    self.previewMode = value and true or false
    self:ApplyVisibility()
end

function VashnikWaveCross:StartUpdates()
    if self.updateTicker then
        return
    end
    self.updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        self:UpdateRotation()
    end)
end

function VashnikWaveCross:StopUpdates()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
end

function VashnikWaveCross:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplyAppearance()
    if self.db.displayMode == "always" then
        self:CancelTriggerTimers(false)
    elseif self.encounterActive
        and self.plagueFrothEndsAt
        and self.plagueFrothEndsAt > GetTime()
    then
        self:SchedulePlagueFrothWindow(self.plagueFrothEndsAt - GetTime())
    end
    self:ApplyVisibility()
end

function VashnikWaveCross:OnInitialize()
    self.previewMode = false
    self.encounterActive = false
    self.timedWindowActive = false
    self.triggerGeneration = 0
    self:EnsureFrame()
    self:ApplyAppearance()
    self.frame:Hide()
end

function VashnikWaveCross:OnEnable()
    self:EnsureFrame()
    self:ApplyAppearance()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "Refresh")
    self:RegisterEvent("UI_SCALE_CHANGED", "Refresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:HookBigWigs()
    self:StartUpdates()
    self:ApplyVisibility()
end

function VashnikWaveCross:OnDisable()
    self:StopUpdates()
    self:CancelTriggerTimers(true)
    self:UnhookBigWigs()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:ReleaseCompassFacingSource()
    self.previewMode = false
    self.encounterActive = false
    if self.frame then
        self.frame:Hide()
    end
end

E:RegisterBossModFeature("VashnikWaveCross", {
    tab = "AbyssCustom",
    order = 70,
    labelKey = "BossMods_VashnikWaveCross",
    descKey = "BossMods_VashnikWaveCrossDesc",
    moduleName = "BossMods_VashnikWaveCross"
})
