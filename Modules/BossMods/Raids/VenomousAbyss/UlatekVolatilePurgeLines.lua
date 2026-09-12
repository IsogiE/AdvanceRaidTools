local E = unpack(ART)

E:RegisterModuleDefaults("BossMods_UlatekVolatilePurgeLines", {
    enabled = false,
    color = {0.08, 0.52, 1},
    thickness = 2,
    opacity = 0.7,
    strata = "MEDIUM"
})

local ENCOUNTER_ID = 3492
local SERPENTS_BITE_SPELL_ID = 1295905
local SHOW_DELAY_AFTER_ZERO = 18
local DISPLAY_DURATION = 9
local UPDATE_INTERVAL = 0.05
local TEXTURE_SIZE = 2048
local LINES_TEXTURE =
    [[Interface\AddOns\AdvanceRaidTools\Media\UlatekVolatilePurgeLines.tga]]
local COMPASS_TOKEN = "UlatekVolatilePurgeLines"
local VALID_STRATA = {
    BACKGROUND = true,
    LOW = true,
    MEDIUM = true,
    HIGH = true,
    DIALOG = true
}

local VolatilePurgeLines = E:NewModule(
    "BossMods_UlatekVolatilePurgeLines",
    "AceEvent-3.0"
)
local BossMods = E:GetModule("BossMods")

function VolatilePurgeLines:EnsureFrame()
    if self.frame then
        return true
    end

    local frame = CreateFrame(
        "Frame",
        "ART_UlatekVolatilePurgeLines",
        UIParent
    )
    frame:SetSize(1, 1)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(false)
    frame:Hide()

    local lines = frame:CreateTexture(nil, "ARTWORK")
    lines:SetPoint("CENTER", frame, "CENTER", 0, 0)
    lines:SetTexture(LINES_TEXTURE)

    self.frame = frame
    self.lines = lines
    return true
end

function VolatilePurgeLines:ApplyAppearance()
    if not self:EnsureFrame() then
        return
    end

    local screenWidth = UIParent:GetWidth() or 1920
    local screenHeight = UIParent:GetHeight() or 1080
    local minimumExtent = math.sqrt(
        screenWidth * screenWidth + screenHeight * screenHeight
    ) * 1.1
    local thickness = math.max(1, tonumber(self.db.thickness) or 2)
    local extent = math.max(minimumExtent, TEXTURE_SIZE * thickness)
    local color = type(self.db.color) == "table" and self.db.color or {}

    self.lines:SetSize(extent, extent)
    self.lines:SetVertexColor(
        color[1] or color.r or 0.08,
        color[2] or color.g or 0.52,
        color[3] or color.b or 1,
        1
    )
    self.frame:SetAlpha(math.max(0, math.min(1, tonumber(self.db.opacity) or 0.7)))
    self.frame:SetFrameStrata(
        VALID_STRATA[self.db.strata] and self.db.strata or "MEDIUM"
    )
end

function VolatilePurgeLines:ApplyRotation()
    if not self.lines then
        return false
    end

    if not self.rotationAcquired then
        local ok, acquired = pcall(E.AcquireCompassFacingSource, E, self, COMPASS_TOKEN)
        if not ok or not acquired then
            return false
        end
        self.rotationAcquired = true
    end

    return E:ApplySecretCompassRotation(self.lines)
end

function VolatilePurgeLines:ReleaseRotation()
    self.rotationAcquired = false
    E:ReleaseCompassFacingSource(self, COMPASS_TOKEN)
end

function VolatilePurgeLines:IsDisplayEnabled()
    return self:IsEnabled() and self.db.enabled ~= false
        and BossMods:IsEnabled() and BossMods:IsFeatureEnabled(COMPASS_TOKEN)
end

function VolatilePurgeLines:HideLines()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
    if self.lines then
        self.lines:SetAlpha(0)
        self.lines:Hide()
    end
    if self.frame then
        self.frame:Hide()
    end
    self:ReleaseRotation()
end

function VolatilePurgeLines:ApplyVisibility()
    if not self.frame then
        return
    end

    local shouldShow = self:IsDisplayEnabled()
        and (self.previewMode or (self.encounterActive and self.stage == 3 and self.windowActive))

    if shouldShow and self:ApplyRotation() then
        self.lines:SetAlpha(1)
        self.lines:Show()
        self.frame:Show()
        if not self.updateTicker then
            self.updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
                self:UpdateRotation()
            end)
        end
    else
        self:HideLines()
    end
end

function VolatilePurgeLines:UpdateRotation()
    if self.windowActive and self.windowEndsAt and GetTime() >= self.windowEndsAt then
        self:StopWindow()
    else
        self:ApplyVisibility()
    end
end

function VolatilePurgeLines:CancelPendingWindow(text)
    for window in pairs(self.pendingWindows or {}) do
        if text == nil or window.text == text then
            window.timer:Cancel()
            self.pendingWindows[window] = nil
        end
    end
end

function VolatilePurgeLines:StopWindow()
    self.windowGeneration = (self.windowGeneration or 0) + 1
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self.windowActive = false
    self.windowEndsAt = nil
    self:ApplyVisibility()
end

function VolatilePurgeLines:StartWindow(endsAt)
    if not self:IsDisplayEnabled() or not self.encounterActive or self.stage ~= 3 then
        return
    end

    self:StopWindow()
    local generation = self.windowGeneration
    self.windowEndsAt = endsAt or (GetTime() + DISPLAY_DURATION)
    local remaining = self.windowEndsAt - GetTime()
    if remaining <= 0 then
        self.windowEndsAt = nil
        return
    end
    self.windowActive = true

    self.hideTimer = C_Timer.NewTimer(remaining, function()
        if generation ~= self.windowGeneration then
            return
        end
        self.hideTimer = nil
        self:StopWindow()
    end)
    self:ApplyVisibility()
end

function VolatilePurgeLines:ScheduleWindow(duration, text)
    duration = tonumber(duration)
    if not self:IsDisplayEnabled() or not self.encounterActive or self.stage ~= 3
        or not duration or duration <= 0
    then
        return
    end

    self:CancelPendingWindow(text)
    self.pendingWindows = self.pendingWindows or {}
    local window = {
        text = text,
        serpentsBiteEndsAt = GetTime() + duration
    }
    self.pendingWindows[window] = true
    local endsAt = window.serpentsBiteEndsAt + SHOW_DELAY_AFTER_ZERO + DISPLAY_DURATION
    window.timer = C_Timer.NewTimer(
        duration + SHOW_DELAY_AFTER_ZERO,
        function()
            if not self.pendingWindows[window] then
                return
            end

            self.pendingWindows[window] = nil
            self:StartWindow(endsAt)
        end
    )
end

function VolatilePurgeLines:OnBigWigsTimer(key, duration, text, moduleInfo)
    if not self.encounterActive
        or self.stage ~= 3
        or tonumber(key) ~= SERPENTS_BITE_SPELL_ID
        or not moduleInfo
        or moduleInfo.moduleName ~= "Ula'tek"
    then
        return
    end

    self:ScheduleWindow(duration, text)
end

function VolatilePurgeLines:OnBigWigsStage(moduleInfo, stage)
    if not self.encounterActive or not moduleInfo or moduleInfo.moduleName ~= "Ula'tek" then
        return
    end
    stage = tonumber(stage)
    if not stage or stage == self.stage then
        return
    end
    self.stage = stage
    self:CancelPendingWindow()
    self:StopWindow()
end

function VolatilePurgeLines:OnBigWigsStopBar(text, moduleInfo)
    if not self.encounterActive
        or not text
        or not moduleInfo
        or moduleInfo.moduleName ~= "Ula'tek"
    then
        return
    end

    -- A natural stop happens at zero. Only cancel when BigWigs removes the
    -- countdown early (for example because the encounter or stage ended).
    for window in pairs(self.pendingWindows or {}) do
        if window.text == text and window.serpentsBiteEndsAt - GetTime() > 0.5 then
            self:CancelPendingWindow(text)
            return
        end
    end
end

function VolatilePurgeLines:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end

    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "UlatekVolatilePurgeLines",
        spellKeys = {SERPENTS_BITE_SPELL_ID},
        onTimer = function(key, text, duration, _, _, _, _, _, moduleInfo)
            self:OnBigWigsTimer(key, duration, text, moduleInfo)
        end,
        onStopBar = function(text, moduleInfo)
            self:OnBigWigsStopBar(text, moduleInfo)
        end,
        onStage = function(moduleInfo, stage)
            self:OnBigWigsStage(moduleInfo, stage)
        end
    })
end

function VolatilePurgeLines:UnhookBigWigs()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
end

function VolatilePurgeLines:SetPreviewMode(value)
    self.previewMode = value == true and self:IsDisplayEnabled()
    self:ApplyVisibility()
end

function VolatilePurgeLines:OnFeatureEnabledChanged(_, key, enabled)
    if key == COMPASS_TOKEN and not enabled then
        self.previewMode = false
        self:CancelPendingWindow()
        self:StopWindow()
    end
end

function VolatilePurgeLines:Refresh()
    if not self:IsDisplayEnabled() then
        self.previewMode = false
        self:CancelPendingWindow()
        self:StopWindow()
        return
    end
    self:ApplyAppearance()
    self:ApplyVisibility()
end

function VolatilePurgeLines:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == ENCOUNTER_ID
    self.stage = self.encounterActive and 1 or nil
    self.previewMode = false
    self:CancelPendingWindow()
    self:StopWindow()
end

function VolatilePurgeLines:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = false
    self.stage = nil
    self:CancelPendingWindow()
    self:StopWindow()
end

function VolatilePurgeLines:OnInitialize()
    self.previewMode = false
    self.encounterActive = false
    self.windowActive = false
    self.pendingWindows = {}
    self.windowGeneration = 0
    self:EnsureFrame()
    self:ApplyAppearance()
end

function VolatilePurgeLines:OnEnable()
    self:EnsureFrame()
    self:ApplyAppearance()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "Refresh")
    self:RegisterEvent("UI_SCALE_CHANGED", "Refresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_BOSSMODS_FEATURE_ENABLED_CHANGED", "OnFeatureEnabledChanged")
    self:HookBigWigs()
    self:ApplyVisibility()
end

function VolatilePurgeLines:OnDisable()
    self.previewMode = false
    self.encounterActive = false
    self.stage = nil
    self:CancelPendingWindow()
    self:StopWindow()
    self:UnhookBigWigs()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

E:RegisterBossModFeature("UlatekVolatilePurgeLines", {
    tab = "VenomousAbyss",
    order = 72,
    bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek",
    bossOrder = 80,
    labelKey = "BossMods_UlatekVolatilePurgeLines",
    navLabelKey = "BossMods_UlatekVolatilePurgeLinesNav",
    descKey = "BossMods_UlatekVolatilePurgeLinesDesc",
    moduleName = "BossMods_UlatekVolatilePurgeLines"
})
