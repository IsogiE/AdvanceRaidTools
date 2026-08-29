local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_RavenousFeastSoakCircle", {
    enabled = false,
    font = {
        name = "Friz Quadrata TT",
        size = 13,
        outline = "",
        color = {0, 0, 0, 1},
        offsetX = 0,
        offsetY = 0
    },
    audio = {
        enabled = false,
        mode = "sound",
        sound = "None",
        channel = "Master",
        ttsText = "GO",
        voiceID = 0
    }
})

local TWIN_FANGS_ENCOUNTER_ID = 3421
local RAVENOUS_FEAST_SPELL_ID = 1290516
local SEQUENCE_DURATION = 8
local UPDATE_INTERVAL = 0.05
local CIRCLE_SIZE = 52
local CIRCLE_MASK = [[Interface\Masks\CircleMaskScalable]]

local HIT_WINDOWS = {
    {startTime = 0, endTime = 4.5},
    {startTime = 4.5, endTime = 6.5},
    {startTime = 6.5, endTime = 8}
}

local RavenousFeastSoakCircle = E:NewModule(
    "BossMods_RavenousFeastSoakCircle",
    "AceEvent-3.0"
)
local BossMods = E:GetModule("BossMods")

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

function RavenousFeastSoakCircle:EnsureDefaults()
    self.db.font = self.db.font or {}
    self.db.font.name = self.db.font.name or "Friz Quadrata TT"
    self.db.font.size = clamp(self.db.font.size, 8, 32, 13)
    if self.db.font.outline == nil then
        self.db.font.outline = ""
    end
    self.db.font.color = self.db.font.color or {0, 0, 0, 1}
    self.db.font.offsetX = clamp(self.db.font.offsetX, -100, 100, 0)
    self.db.font.offsetY = clamp(self.db.font.offsetY, -100, 100, 0)

    self.db.audio = self.db.audio or {}
    self.db.audio.enabled = self.db.audio.enabled == true
    self.db.audio.mode = self.db.audio.mode == "tts" and "tts" or "sound"
    self.db.audio.sound = self.db.audio.sound or "None"
    self.db.audio.channel = self.db.audio.channel or "Master"
    self.db.audio.ttsText = self.db.audio.ttsText or "GO"
    self.db.audio.voiceID = tonumber(self.db.audio.voiceID) or 0
end

function RavenousFeastSoakCircle:EnsureFrame()
    if self.frame then
        return
    end

    local frame = CreateFrame(
        "Frame",
        "ART_RavenousFeastSoakCircle",
        UIParent
    )
    frame:SetSize(CIRCLE_SIZE, CIRCLE_SIZE)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    frame:EnableMouse(false)

    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints(frame)
    border:SetColorTexture(0, 0, 0, 0.9)

    local borderMask = frame:CreateMaskTexture()
    borderMask:SetAllPoints(border)
    borderMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    border:AddMaskTexture(borderMask)

    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(1, 0.82, 0, 1)

    local fillMask = frame:CreateMaskTexture()
    fillMask:SetAllPoints(fill)
    fillMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fill:AddMaskTexture(fillMask)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    label:SetTextColor(0, 0, 0, 1)
    label:SetShadowColor(1, 1, 1, 0.35)
    label:SetShadowOffset(1, -1)

    self.frame = frame
    self.fill = fill
    self.label = label
    frame:Hide()
end

function RavenousFeastSoakCircle:ApplyAppearance()
    self:EnsureDefaults()
    self:EnsureFrame()

    E:ApplyFontString(
        self.label,
        E:FetchFont(self.db.font.name),
        self.db.font.size,
        self.db.font.outline
    )
    local color = self.db.font.color
    self.label:SetTextColor(
        color[1] or color.r or 0,
        color[2] or color.g or 0,
        color[3] or color.b or 0,
        color[4] or color.a or 1
    )
    self.label:ClearAllPoints()
    self.label:SetPoint(
        "CENTER",
        self.frame,
        "CENTER",
        self.db.font.offsetX,
        self.db.font.offsetY
    )
end

function RavenousFeastSoakCircle:PlayConfiguredAudio()
    local audio = self.db.audio
    if not audio or not audio.enabled then
        return
    end

    if audio.mode == "tts" then
        BossMods.Alerts:SpeakTTS({
            text = audio.ttsText or "GO",
            voiceID = audio.voiceID or 0
        })
    else
        BossMods.Alerts:PlaySound({
            name = audio.sound,
            channel = audio.channel or "Master"
        })
    end
end

function RavenousFeastSoakCircle:SetState(state)
    local changed = state ~= self.currentState
    self.currentState = state

    if state == "go" then
        self.fill:SetColorTexture(0.10, 0.90, 0.20, 1)
        self.label:SetText(L["BossMods_RFSCGo"] or "GO")
        self.frame:Show()
        if changed then
            self:PlayConfiguredAudio()
        end
    elseif state == "wait" then
        self.fill:SetColorTexture(1, 0.82, 0, 1)
        self.label:SetText(L["BossMods_RFSCWait"] or "WAIT")
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function RavenousFeastSoakCircle:StopSequence()
    if self.sequenceTicker then
        self.sequenceTicker:Cancel()
        self.sequenceTicker = nil
    end
    self.sequenceStartedAt = nil
    self.sequenceIsPreview = false
    self.assignedHits = nil
    self.hasBeenGreen = false
    self.currentState = nil
    if self.frame then
        self.frame:Hide()
    end
end

function RavenousFeastSoakCircle:UpdateSequence()
    if not self.sequenceStartedAt
        or (not self.encounterActive and not self.sequenceIsPreview)
    then
        self:StopSequence()
        return
    end

    local elapsed = GetTime() - self.sequenceStartedAt
    if elapsed >= SEQUENCE_DURATION then
        local repeatPreview = self.previewMode and self.sequenceIsPreview
        self:StopSequence()
        if repeatPreview then
            self:StartSequence(true)
        end
        return
    end

    local currentHit
    local hasFutureAssignment = false

    for hit, window in ipairs(HIT_WINDOWS) do
        if elapsed >= window.startTime and elapsed < window.endTime then
            currentHit = hit
        elseif elapsed < window.startTime
            and self.assignedHits
            and self.assignedHits[hit]
        then
            hasFutureAssignment = true
        end
    end

    if currentHit
        and self.assignedHits
        and self.assignedHits[currentHit]
    then
        self.hasBeenGreen = true
        self:SetState("go")
    elseif not self.hasBeenGreen then
        self:SetState("wait")
    elseif hasFutureAssignment then
        self:SetState(nil)
    else
        self:SetState(nil)
    end
end

function RavenousFeastSoakCircle:StartSequence(preview)
    preview = preview == true
    if not self.encounterActive and not preview then
        return
    end

    self:StopSequence()
    self.assignedHits = E.VenomousAbyssGetAssignedHits
        and E.VenomousAbyssGetAssignedHits("ravenousFeast")
        or nil
    if preview and not self.assignedHits then
        self.assignedHits = {[2] = true}
    end
    self.hasBeenGreen = false
    self.sequenceIsPreview = preview
    self.sequenceStartedAt = GetTime()
    self:UpdateSequence()
    self.sequenceTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        self:UpdateSequence()
    end)
end

function RavenousFeastSoakCircle:SetPreviewMode(value)
    self.previewMode = value and true or false
    self:StopSequence()
    if self.previewMode then
        self:StartSequence(true)
    end
end

function RavenousFeastSoakCircle:Refresh()
    self:ApplyAppearance()
end

function RavenousFeastSoakCircle:ScheduleSequence(duration)
    duration = tonumber(duration)
    if not duration or duration < 0 then
        return
    end

    local timer
    timer = C_Timer.NewTimer(duration, function()
        self.startTimers[timer] = nil
        self:StartSequence()
    end)
    self.startTimers[timer] = true
end

function RavenousFeastSoakCircle:CancelStartTimers()
    for timer in pairs(self.startTimers or {}) do
        timer:Cancel()
    end
    wipe(self.startTimers or {})
end

function RavenousFeastSoakCircle:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end

    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "RavenousFeastSoakCircle",
        spellKeys = {RAVENOUS_FEAST_SPELL_ID},
        onStartBar = function(_, _, duration)
            if self.encounterActive then
                self:ScheduleSequence(duration)
            end
        end
    })
end

function RavenousFeastSoakCircle:UnhookBigWigs()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
end

function RavenousFeastSoakCircle:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == TWIN_FANGS_ENCOUNTER_ID
    self:CancelStartTimers()
    self:StopSequence()
end

function RavenousFeastSoakCircle:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) == TWIN_FANGS_ENCOUNTER_ID then
        self.encounterActive = false
        self:CancelStartTimers()
        self:StopSequence()
    end
end

function RavenousFeastSoakCircle:OnInitialize()
    self.encounterActive = false
    self.previewMode = false
    self.startTimers = {}
    self:EnsureFrame()
    self:ApplyAppearance()
end

function RavenousFeastSoakCircle:OnEnable()
    self:EnsureFrame()
    self:ApplyAppearance()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:HookBigWigs()
end

function RavenousFeastSoakCircle:OnDisable()
    self.encounterActive = false
    self.previewMode = false
    self:CancelStartTimers()
    self:StopSequence()
    self:UnhookBigWigs()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

E:RegisterBossModFeature("RavenousFeastSoakCircle", {
    tab = "AbyssCustom",
    order = 80,
    labelKey = "BossMods_RavenousFeastSoakCircle",
    descKey = "BossMods_RavenousFeastSoakCircleDesc",
    moduleName = "BossMods_RavenousFeastSoakCircle"
})
