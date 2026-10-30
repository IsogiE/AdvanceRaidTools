local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/BossMods/Raids/VenomousAbyss/CoiledAltarWrongTarget")

E:RegisterModuleDefaults("BossMods_CoiledAltarWrongTarget", {
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

local ENCOUNTER_ID = 3429
local INSTANCE_ID = 3004
local BOSS_MODULE_NAME = "The Coiled Altar"
local NIGHTFALL_UNIT = "boss2"
local SPELL_ETERNAL_NIGHTFALL = 1286918
local NIGHTFALL_WINDOW_DURATION = 17
local ACTIVE_STAGE = 3
local UPDATE_INTERVAL = 0.1
local SUPPORTED_DIFFICULTIES = {
    [15] = true,
    [16] = true
}

local issecretvalue = issecretvalue or function()
    return false
end

local CoiledAltarWrongTarget = E:NewModule(
    "BossMods_CoiledAltarWrongTarget",
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
    text:SetText(L["BossMods_CoiledAltarWrongTargetText"])
    text:SetTextColor(1, 0, 0, 1)
end

function CoiledAltarWrongTarget:EnsureFrame()
    if self.frame then return true end
    self.frame, self.text = createWarningFrame("ART_CoiledAltarWrongTarget")
    self:ApplySettings()
    return true
end

function CoiledAltarWrongTarget:ApplySettings()
    if not self.frame then return end
    applyWarningAppearance(self.frame, self.text, self.db)
    E:GetModule("BossMods").DisplayTemplates:Place(self, "position", self.frame)
end

function CoiledAltarWrongTarget:CreateAnchorPreview()
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

function CoiledAltarWrongTarget:IsBossActive()
    local exists = publicBool(UnitExists(NIGHTFALL_UNIT))
    if not exists then
        return false
    end

    if UnitIsDeadOrGhost then
        local dead = publicBool(UnitIsDeadOrGhost(NIGHTFALL_UNIT))
        if dead then
            return false
        end
    elseif UnitIsDead then
        local dead = publicBool(UnitIsDead(NIGHTFALL_UNIT))
        if dead then
            return false
        end
    end

    if UnitCanAttack then
        local canAttack = publicBool(UnitCanAttack("player", NIGHTFALL_UNIT))
        if canAttack == false then
            return false
        end
    end

    return true
end

function CoiledAltarWrongTarget:IsTargetWrong()
    if not self.windowActive or not self:IsBossActive() then
        return false
    end

    local targetExists = publicBool(UnitExists("target"))
    if not targetExists then
        return false
    end

    local isBossTarget = publicBool(UnitIsUnit("target", NIGHTFALL_UNIT))
    if isBossTarget == nil then
        return false
    end

    return not isBossTarget
end

function CoiledAltarWrongTarget:UpdateAlert()
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

function CoiledAltarWrongTarget:StartUpdateTicker()
    if self.updateTicker then
        return
    end

    self.updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        if self:IsEnabled() then
            self:UpdateAlert()
        end
    end)
end

function CoiledAltarWrongTarget:StopUpdateTicker()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
end

function CoiledAltarWrongTarget:StopWindow()
    self.windowGeneration = (self.windowGeneration or 0) + 1

    if self.hideTimer then
        self:CancelTimer(self.hideTimer)
        self.hideTimer = nil
    end

    self.windowActive = false
    self:UnregisterEvent("UNIT_SPELLCAST_STOP")
    self:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:StopUpdateTicker()
    self:UpdateAlert()
end

function CoiledAltarWrongTarget:StartWindow(duration)
    if not self.encounterActive or self.stage ~= ACTIVE_STAGE then
        return
    end

    duration = math.max(0, tonumber(duration) or NIGHTFALL_WINDOW_DURATION)
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
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "OnBossSpellcastEnd")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "OnBossSpellcastEnd")
    self:StartUpdateTicker()
    self:UpdateAlert()

    self.hideTimer = self:ScheduleTimer(function()
        if self.windowGeneration == generation then
            self:StopWindow()
        end
    end, duration)
end

function CoiledAltarWrongTarget:OnBossSpellcastEnd(_, unit)
    if unit ~= NIGHTFALL_UNIT or not self.windowActive then
        return
    end

    self:StopWindow()
end

function CoiledAltarWrongTarget:CancelPendingNightfall()
    if self.pendingNightfall then
        self:CancelTimer(self.pendingNightfall.timer)
        self.pendingNightfall = nil
    end
end

function CoiledAltarWrongTarget:ResetWindows()
    self:CancelPendingNightfall()
    self:StopWindow()
end

function CoiledAltarWrongTarget:OnBigWigsStartBar(key, text, duration, moduleInfo)
    if not self.encounterActive
        or self.stage ~= ACTIVE_STAGE
        or tonumber(key) ~= SPELL_ETERNAL_NIGHTFALL
        or not moduleInfo or moduleInfo.moduleName ~= BOSS_MODULE_NAME
    then
        return
    end

    duration = tonumber(duration)
    if not duration then
        return
    end

    self:CancelPendingNightfall()

    if duration <= 0.05 then
        self:StartWindow(NIGHTFALL_WINDOW_DURATION)
        return
    end

    local pending = {text = text}
    self.pendingNightfall = pending
    pending.timer = self:ScheduleTimer(function()
        if self.encounterActive and self.pendingNightfall == pending then
            self.pendingNightfall = nil
            self:StartWindow(NIGHTFALL_WINDOW_DURATION)
        end
    end, duration)
end

function CoiledAltarWrongTarget:OnBigWigsStage(moduleInfo, stage)
    if not self.encounterActive
        or not moduleInfo or moduleInfo.moduleName ~= BOSS_MODULE_NAME
    then
        return
    end

    self.stage = tonumber(stage)
    if self.stage ~= ACTIVE_STAGE then
        self:ResetWindows()
    end
end

function CoiledAltarWrongTarget:HookBigWigs()
    if self.bigWigsSubscription then return end
    self.bigWigsSubscription = E:GetModule("BossMods").BigWigs:Subscribe({
        owner = "CoiledAltarWrongTarget",
        spellKeys = {SPELL_ETERNAL_NIGHTFALL},
        onStartBar = function(key, text, duration, moduleInfo)
            self:OnBigWigsStartBar(key, text, duration, moduleInfo)
        end,
        onStopBar = function(text, moduleInfo)
            if moduleInfo and moduleInfo.moduleName == BOSS_MODULE_NAME
                and self.pendingNightfall and self.pendingNightfall.text == text
            then
                self:CancelPendingNightfall()
            end
        end,
        onStage = function(moduleInfo, stage)
            self:OnBigWigsStage(moduleInfo, stage)
        end
    })
end

function CoiledAltarWrongTarget:SetEditMode(value)
    self.editMode = value and true or false
    self:EnsureFrame()
    self:ApplySettings()
    self:UpdateAlert()
end

function CoiledAltarWrongTarget:SavePosition(position)
    local saved = self.db.position
    saved.point = position.point
    saved.x = position.x
    saved.y = position.y
    self:ApplySettings()
end

function CoiledAltarWrongTarget:Refresh()
    if not self:IsEnabled() then
        return
    end

    self:EnsureFrame()
    self:ApplySettings()
    self:UpdateAlert()
end

function CoiledAltarWrongTarget:OnPlayerTargetChanged()
    self:UpdateAlert()
end

function CoiledAltarWrongTarget:OnEncounterStart(_, encounterID, _, difficultyID)
    if encounterID ~= ENCOUNTER_ID
        or not SUPPORTED_DIFFICULTIES[tonumber(difficultyID)]
        or not currentLocationIsSupported()
    then
        return
    end

    self.encounterActive = true
    self.stage = 1
    self:ResetWindows()
end

function CoiledAltarWrongTarget:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end

    self.encounterActive = false
    self.stage = nil
    self:ResetWindows()
end

function CoiledAltarWrongTarget:OnInitialize()
    self.editMode = false
    self.encounterActive = false
    self.windowActive = false
    self.windowGeneration = 0
    self:EnsureFrame()
    if self.frame then
        self.frame:Hide()
    end
end

function CoiledAltarWrongTarget:OnEnable()
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

function CoiledAltarWrongTarget:OnDisable()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
    self:ResetWindows()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.stage = nil
    self.editMode = false
    if self.frame then
        self.frame:Hide()
    end
end

E:RegisterBossModFeature("CoiledAltarWrongTarget", {
    tab = "VenomousAbyss",
    order = 87,
    bossKey = "CoiledAltar",
    bossLabelKey = "BossMods_CoiledAltar",
    bossOrder = 70,
    labelKey = "BossMods_CoiledAltarWrongTarget",
    navLabelKey = "BossMods_CoiledAltarWrongTargetNav",
    descKey = "BossMods_CoiledAltarWrongTargetDesc",
    moduleName = "BossMods_CoiledAltarWrongTarget"
})
