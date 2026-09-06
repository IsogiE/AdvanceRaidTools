local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_UlatekWrongTarget", {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 160
    },
    width = 760,
    height = 90,
    fontSize = 48,
    scale = 1,
    opacity = 1
})

local ENCOUNTER_ID = 3492
local INSTANCE_ID = 3004
local HEART_UNIT = "boss2"
local SPELL_RAGE_OF_THE_SHACKLED = 1286860
local HEART_WINDOW_DURATION = 20
local UPDATE_INTERVAL = 0.1
local WRONG_TARGET_TIMERS = {
    [15] = {135.4, 284.5, 573.5},
    [16] = {145.4, 294.5, 583.6}
}

local issecretvalue = issecretvalue or function()
    return false
end

local UlatekWrongTarget = E:NewModule(
    "BossMods_UlatekWrongTarget",
    "AceEvent-3.0",
    "AceTimer-3.0"
)

local function publicBool(value)
    if issecretvalue(value) then
        return nil
    end

    return value and true or false
end

local function currentLocationIsSupported()
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    return mapID == INSTANCE_ID
end

local function createWarningFrame(name)
    local frame = CreateFrame(
        "Frame",
        name,
        UIParent,
        "DisableUntrustedLayoutScriptsTemplate"
    )
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    return frame, text
end

local function applyWarningAppearance(frame, text, db)
    local width = math.max(260, tonumber(db.width) or 760)
    local height = math.max(40, tonumber(db.height) or 90)
    local fontSize = math.max(12, tonumber(db.fontSize) or 48)

    frame:SetSize(width, height)
    frame:SetScale(tonumber(db.scale) or 1)
    frame:SetAlpha(tonumber(db.opacity) or 1)

    text:SetFont(
        E:FetchModuleFont() or [[Fonts\FRIZQT__.TTF]],
        fontSize,
        "THICKOUTLINE"
    )
    text:SetText(L["BossMods_UlatekWrongTargetText"])
    text:SetTextColor(1, 0, 0, 1)
end

function UlatekWrongTarget:EnsureFrame()
    if self.frame then return true end
    self.frame, self.text = createWarningFrame("ART_UlatekWrongTarget")
    self:ApplySettings()
    return true
end

function UlatekWrongTarget:ApplySettings()
    if not self.frame then return end
    applyWarningAppearance(self.frame, self.text, self.db)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "position", self.frame)
end

function UlatekWrongTarget:CreateAnchorPreview()
    local owner = self
    local frame, text = createWarningFrame()
    local handle = {frame = frame}
    function handle:Refresh()
        applyWarningAppearance(frame, text, owner.db)
    end
    function handle:Show()
        self:Refresh()
        frame:Show()
    end
    function handle:Hide()
        frame:Hide()
    end
    handle:Refresh()
    return handle
end

function UlatekWrongTarget:IsHeartActive()
    local exists = publicBool(UnitExists(HEART_UNIT))
    if not exists then
        return false
    end

    if UnitIsDeadOrGhost then
        local dead = publicBool(UnitIsDeadOrGhost(HEART_UNIT))
        if dead then
            return false
        end
    elseif UnitIsDead then
        local dead = publicBool(UnitIsDead(HEART_UNIT))
        if dead then
            return false
        end
    end

    if UnitCanAttack then
        local canAttack = publicBool(UnitCanAttack("player", HEART_UNIT))
        if canAttack == false then
            return false
        end
    end

    return true
end

function UlatekWrongTarget:IsTargetWrong()
    if not self.windowActive or not self:IsHeartActive() then
        return false
    end

    local targetExists = publicBool(UnitExists("target"))
    if not targetExists then
        return false
    end

    local isHeartTarget = publicBool(UnitIsUnit("target", HEART_UNIT))
    if isHeartTarget == nil then
        return false
    end

    return not isHeartTarget
end

function UlatekWrongTarget:UpdateAlert()
    if not self.frame then
        return
    end

    if self.editMode then
        self.frame:Show()
        return
    end

    local shouldShow = self:IsEnabled()
        and self.encounterActive
        and self:IsTargetWrong()

    self.frame:SetShown(shouldShow == true)
end

function UlatekWrongTarget:StartUpdateTicker()
    if self.updateTicker then
        return
    end

    self.updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        if self:IsEnabled() then
            self:UpdateAlert()
        end
    end)
end

function UlatekWrongTarget:StopUpdateTicker()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
end

function UlatekWrongTarget:StopWindow()
    self.windowGeneration = (self.windowGeneration or 0) + 1

    if self.hideTimer then
        self:CancelTimer(self.hideTimer)
        self.hideTimer = nil
    end

    self.windowActive = false
    self.windowEndsAt = nil
    self:StopUpdateTicker()
    self:UpdateAlert()
end

function UlatekWrongTarget:StartWindow(duration)
    if not self.encounterActive then
        return
    end

    duration = math.max(0, tonumber(duration) or HEART_WINDOW_DURATION)
    if duration <= 0 then
        self:StopWindow()
        return
    end

    self.windowGeneration = (self.windowGeneration or 0) + 1
    local generation = self.windowGeneration

    if self.hideTimer then
        self:CancelTimer(self.hideTimer)
        self.hideTimer = nil
    end

    self.windowActive = true
    self.windowEndsAt = GetTime() + duration
    self:StartUpdateTicker()
    self:UpdateAlert()

    self.hideTimer = self:ScheduleTimer(function()
        if self.windowGeneration == generation then
            self:StopWindow()
        end
    end, duration)
end

function UlatekWrongTarget:CancelEncounterTimers()
    for _, timer in ipairs(self.encounterTimers or {}) do
        self:CancelTimer(timer)
    end
    self.encounterTimers = {}
    self:CancelPendingRage()
    self:StopWindow()
end

function UlatekWrongTarget:CancelPendingRage()
    if self.pendingRage then
        self:CancelTimer(self.pendingRage.timer)
        self.pendingRage = nil
    end
end

function UlatekWrongTarget:OnBigWigsStartBar(key, text, duration, moduleInfo)
    if not self.encounterActive
        or tonumber(key) ~= SPELL_RAGE_OF_THE_SHACKLED
        or not moduleInfo or moduleInfo.moduleName ~= "Ula'tek"
    then
        return
    end

    duration = tonumber(duration)
    if not duration or duration < HEART_WINDOW_DURATION - 0.05 then
        return
    end

    for _, timer in ipairs(self.encounterTimers or {}) do
        self:CancelTimer(timer)
    end
    self.encounterTimers = {}
    self:CancelPendingRage()

    if math.abs(duration - HEART_WINDOW_DURATION) < 0.05 then
        self:StartWindow(HEART_WINDOW_DURATION)
        return
    end

    local pending = {text = text}
    self.pendingRage = pending
    pending.timer = self:ScheduleTimer(function()
        if self.encounterActive and self.pendingRage == pending then
            self.pendingRage = nil
            self:StartWindow(HEART_WINDOW_DURATION)
        end
    end, duration)
end

function UlatekWrongTarget:HookBigWigs()
    if self.bigWigsSubscription then return end
    self.bigWigsSubscription = E:GetModule("BossMods").BigWigs:Subscribe({
        owner = "UlatekWrongTarget",
        spellKeys = {SPELL_RAGE_OF_THE_SHACKLED},
        onStartBar = function(key, text, duration, moduleInfo)
            self:OnBigWigsStartBar(key, text, duration, moduleInfo)
        end,
        onStopBar = function(text, moduleInfo)
            if moduleInfo and moduleInfo.moduleName == "Ula'tek"
                and self.pendingRage and self.pendingRage.text == text
            then
                self:CancelPendingRage()
            end
        end
    })
end

function UlatekWrongTarget:ScheduleWindows(difficultyID)
    self:CancelEncounterTimers()

    local timers = WRONG_TARGET_TIMERS[tonumber(difficultyID)]
    if not timers then
        return
    end

    self.encounterTimers = {}
    local encounterStart = self.encounterStartTime or GetTime()
    local elapsed = GetTime() - encounterStart

    for _, startTime in ipairs(timers) do
        local remaining = startTime + HEART_WINDOW_DURATION - elapsed

        if elapsed >= startTime and remaining > 0 then
            self:StartWindow(remaining)
        elseif elapsed < startTime then
            self.encounterTimers[#self.encounterTimers + 1] =
                self:ScheduleTimer(function()
                    if self.encounterActive then
                        self:StartWindow(HEART_WINDOW_DURATION)
                    end
                end, startTime - elapsed)
        end
    end
end

function UlatekWrongTarget:SetEditMode(value)
    self.editMode = value and true or false
    self:EnsureFrame()
    self:ApplySettings()
    self:UpdateAlert()
end

function UlatekWrongTarget:SavePosition(position)
    local saved = self.db.position
    saved.point = position.point
    saved.x = position.x
    saved.y = position.y
    self:ApplySettings()
end

function UlatekWrongTarget:Refresh()
    if not self:IsEnabled() then
        return
    end

    self:EnsureFrame()
    self:ApplySettings()
    self:UpdateAlert()
end

function UlatekWrongTarget:OnPlayerTargetChanged()
    self:UpdateAlert()
end

function UlatekWrongTarget:OnEncounterStart(_, encounterID, _, difficultyID)
    if encounterID ~= ENCOUNTER_ID or not currentLocationIsSupported() then
        return
    end

    self.encounterActive = true
    self.difficultyID = difficultyID
    self.encounterStartTime = GetTime()
    self:ScheduleWindows(difficultyID)
end

function UlatekWrongTarget:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end

    self.encounterActive = false
    self.difficultyID = nil
    self.encounterStartTime = nil
    self:CancelEncounterTimers()
end

function UlatekWrongTarget:OnInitialize()
    self.editMode = false
    self.encounterActive = false
    self.windowActive = false
    self.windowGeneration = 0
    self.encounterTimers = {}
    self:EnsureFrame()
    if self.frame then
        self.frame:Hide()
    end
end

function UlatekWrongTarget:OnEnable()
    self:EnsureFrame()
    self:ApplySettings()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnPlayerTargetChanged")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "Refresh")
    self:RegisterEvent("UI_SCALE_CHANGED", "Refresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:HookBigWigs()
    self:UpdateAlert()
end

function UlatekWrongTarget:OnDisable()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.editMode = false
    self:CancelEncounterTimers()
    if self.frame then
        self.frame:Hide()
    end
end

E:RegisterBossModFeature("UlatekWrongTarget", {
    tab = "VenomousAbyss",
    order = 66,
    bossKey = "Ulatek",
    bossLabelKey = "BossMods_Ulatek",
    bossOrder = 80,
    labelKey = "BossMods_UlatekWrongTarget",
    navLabelKey = "BossMods_UlatekWrongTargetNav",
    descKey = "BossMods_UlatekWrongTargetDesc",
    moduleName = "BossMods_UlatekWrongTarget"
})
