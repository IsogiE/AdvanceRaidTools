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

    if not E:AcquireCompassFacingSource(self, COMPASS_TOKEN) then
        return false
    end

    return E:ApplySecretCompassRotation(self.lines)
end

function VolatilePurgeLines:ReleaseRotation()
    E:ReleaseCompassFacingSource(self, COMPASS_TOKEN)
end

function VolatilePurgeLines:ApplyVisibility()
    if not self.frame then
        return
    end

    local shouldShow = self:IsEnabled()
        and (self.previewMode or (self.encounterActive and self.windowActive))

    if shouldShow then
        self.frame:Show()
        self:ApplyRotation()
    else
        self.frame:Hide()
        self:ReleaseRotation()
    end
end

function VolatilePurgeLines:UpdateRotation()
    if self.frame and self.frame:IsShown() then
        self:ApplyRotation()
    end
end

function VolatilePurgeLines:CancelPendingWindow()
    self.scheduleGeneration = (self.scheduleGeneration or 0) + 1
    if self.showTimer then
        self.showTimer:Cancel()
        self.showTimer = nil
    end
    self.serpentsBiteEndsAt = nil
    self.serpentsBiteBarText = nil
end

function VolatilePurgeLines:StopWindow()
    self.windowGeneration = (self.windowGeneration or 0) + 1
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self.windowActive = false
    self:ApplyVisibility()
end

function VolatilePurgeLines:StartWindow()
    if not self.encounterActive then
        return
    end

    self:StopWindow()
    local generation = self.windowGeneration
    self.windowActive = true
    self:ApplyVisibility()

    self.hideTimer = C_Timer.NewTimer(DISPLAY_DURATION, function()
        if generation ~= self.windowGeneration then
            return
        end
        self.hideTimer = nil
        self.windowActive = false
        self:ApplyVisibility()
    end)
end

function VolatilePurgeLines:ScheduleWindow(duration, text)
    duration = tonumber(duration)
    if not duration or duration <= 0 then
        return
    end

    self:CancelPendingWindow()
    local generation = self.scheduleGeneration
    self.serpentsBiteEndsAt = GetTime() + duration
    self.serpentsBiteBarText = text
    self.showTimer = C_Timer.NewTimer(
        duration + SHOW_DELAY_AFTER_ZERO,
        function()
            if generation ~= self.scheduleGeneration
                or not self.encounterActive
            then
                return
            end

            self.showTimer = nil
            self.serpentsBiteEndsAt = nil
            self.serpentsBiteBarText = nil
            self:StartWindow()
        end
    )
end

function VolatilePurgeLines:OnBigWigsStartBar(key, text, duration, moduleInfo)
    if not self.encounterActive
        or tonumber(key) ~= SERPENTS_BITE_SPELL_ID
        or not moduleInfo
        or moduleInfo.moduleName ~= "Ula'tek"
    then
        return
    end

    self:ScheduleWindow(duration, text)
end

function VolatilePurgeLines:OnBigWigsStopBar(text, moduleInfo)
    if not self.encounterActive
        or not self.serpentsBiteBarText
        or text ~= self.serpentsBiteBarText
        or not moduleInfo
        or moduleInfo.moduleName ~= "Ula'tek"
    then
        return
    end

    -- A natural stop happens at zero. Only cancel when BigWigs removes the
    -- countdown early (for example because the encounter or stage ended).
    if self.serpentsBiteEndsAt
        and self.serpentsBiteEndsAt - GetTime() > 0.5
    then
        self:CancelPendingWindow()
    end
end

function VolatilePurgeLines:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end

    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "UlatekVolatilePurgeLines",
        spellKeys = {SERPENTS_BITE_SPELL_ID},
        onStartBar = function(key, text, duration, moduleInfo)
            self:OnBigWigsStartBar(key, text, duration, moduleInfo)
        end,
        onStopBar = function(text, moduleInfo)
            self:OnBigWigsStopBar(text, moduleInfo)
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
    self.previewMode = value and true or false
    self:ApplyVisibility()
end

function VolatilePurgeLines:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplyAppearance()
    self:ApplyVisibility()
end

function VolatilePurgeLines:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == ENCOUNTER_ID
    self:CancelPendingWindow()
    self:StopWindow()
end

function VolatilePurgeLines:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = false
    self:CancelPendingWindow()
    self:StopWindow()
end

function VolatilePurgeLines:OnInitialize()
    self.previewMode = false
    self.encounterActive = false
    self.windowActive = false
    self.scheduleGeneration = 0
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
    self:HookBigWigs()
    self.updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        self:UpdateRotation()
    end)
    self:ApplyVisibility()
end

function VolatilePurgeLines:OnDisable()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
    self:CancelPendingWindow()
    self:StopWindow()
    self:UnhookBigWigs()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:ReleaseRotation()
    self.previewMode = false
    self.encounterActive = false
    if self.frame then
        self.frame:Hide()
    end
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
