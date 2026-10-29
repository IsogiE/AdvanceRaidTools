local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local Displays = BossMods.DisplayTemplates
local MODULE_NAME = "BossMods_SentinelsRange"
local ENCOUNTER_ID = 3445
local DURATIONS = {[14] = 5, [15] = 5, [16] = 5}
local SPECS = {[265] = true, [266] = true, [267] = true}
local RANGE_THRESHOLD = 40
local UPDATE_INTERVAL = 0.1
local MIN_RESET_CHANNEL_DURATION = 2
local CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true, height = 96, showDurationText = false, allClasses = false,
    position = {point = "CENTER", x = -175, y = 175}
})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function publicNumber(value)
    if E:IsSecret(value) then return end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

local function createVisual()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)
    frame:SetBackdrop({bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1})
    local visual = {frame = frame}
    visual.circle = frame:CreateTexture(nil, "BACKGROUND")
    visual.circle:SetTexture(CIRCLE_TEXTURE)
    visual.circle:SetVertexColor(0.08, 0.08, 0.08, 1)
    visual.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    visual.cooldown:SetAllPoints(visual.circle)
    visual.cooldown:SetDrawSwipe(true)
    visual.cooldown:SetDrawEdge(false)
    visual.cooldown:SetDrawBling(false)
    visual.cooldown:SetHideCountdownNumbers(true)
    visual.cooldown:SetSwipeTexture(CIRCLE_TEXTURE, 0.09, 0.52, 0.82, 1)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(visual.circle)
    overlay:SetFrameLevel(visual.cooldown:GetFrameLevel() + 1)
    visual.duration = overlay:CreateFontString(nil, "OVERLAY")
    visual.duration:SetPoint("CENTER")
    visual.ranges = {frame:CreateFontString(nil, "OVERLAY"), frame:CreateFontString(nil, "OVERLAY")}
    frame:Hide()
    return visual
end

function Mod:ApplyVisual(visual)
    local scale = math.max(48, math.min(192, publicNumber(self.db.height) or 96)) / 96
    local font = E:FetchModuleFont()
    visual.frame:SetSize(80 * scale, 96 * scale)
    visual.frame:SetBackdropColor(unpack(E.media.backdropColor or {0, 0, 0, 0.95}))
    visual.frame:SetBackdropBorderColor(unpack(E.media.borderColor or {0.09, 0.52, 0.82, 1}))
    visual.circle:SetSize(70 * scale, 70 * scale)
    visual.circle:ClearAllPoints()
    visual.circle:SetPoint("TOP", 0, -4 * scale)
    visual.duration:SetFont(font, 22 * scale, "OUTLINE")
    visual.duration:SetShown(self.db.showDurationText == true)
    for index, text in ipairs(visual.ranges) do
        text:SetFont(font, 17 * scale, "OUTLINE")
        text:ClearAllPoints()
        text:SetPoint(index == 1 and "BOTTOMLEFT" or "BOTTOMRIGHT", (index == 1 and 6 or -6) * scale, 4 * scale)
    end
end

local function setRange(text, minimum, maximum)
    minimum, maximum = publicNumber(minimum), publicNumber(maximum)
    if not minimum then text:SetText("--"); text:SetTextColor(0.6, 0.6, 0.6); return end
    local range = maximum or minimum
    text:SetText(tostring(range) .. (maximum and "" or "+"))
    if range > RANGE_THRESHOLD then text:SetTextColor(0, 1, 0)
    else text:SetTextColor(1, 0, 0) end
end

local function updateCycle(visual, nextAt, duration, now)
    if not nextAt or now >= nextAt then
        local startedAt = nextAt and nextAt + math.floor((now - nextAt) / duration) * duration or now
        visual.cooldown:SetCooldown(startedAt, duration)
        nextAt = startedAt + duration
    end
    local remaining = math.max(0, nextAt - now)
    visual.duration:SetText(remaining < 3 and string.format("%.1f", remaining) or tostring(math.ceil(remaining)))
    return nextAt
end

function Mod:IsEligible()
    if not self:IsEnabled() or not BossMods:IsEnabled() or not BossMods:IsFeatureEnabled("SentinelsRange")
        or not self.encounterActive or not self.duration then return false end
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    return self.db.allClasses == true or SPECS[specID] == true
end

function Mod:Update()
    if not self.visual then return end
    if not self:IsEligible() or self.channelStartedAt then self.visual.frame:Hide(); return end
    self.nextAt = updateCycle(self.visual, self.nextAt, self.duration, GetTime())
    local library = E.Libs.LibRangeCheck
    for index, text in ipairs(self.visual.ranges) do
        local ok, minimum, maximum
        if library then ok, minimum, maximum = pcall(library.GetRange, library, "boss" .. index, true) end
        if not ok then minimum, maximum = nil, nil end
        setRange(text, minimum, maximum)
    end
    self.visual.frame:Show()
end

function Mod:EnsureFrame()
    if self.visual or InCombatLockdown() then return end
    self.visual = createVisual()
    self.frame = self.visual.frame
    self.visual.frame:SetScript("OnUpdate", function(_, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed >= UPDATE_INTERVAL then self.elapsed = 0; self:Update() end
    end)
    self:ApplyVisual(self.visual)
    Displays:Place(self, "position", self.frame)
end

function Mod:CreateAnchorPreview()
    if InCombatLockdown() then return end
    local visual = createVisual()
    local owner = self
    local handle = {frame = visual.frame}
    function handle:Refresh() owner:ApplyVisual(visual) end
    function handle:Show()
        self:Refresh()
        local nextAt = updateCycle(visual, nil, 5, GetTime())
        local elapsed = 0
        setRange(visual.ranges[1], 40, 60)
        setRange(visual.ranges[2], 10, 15)
        visual.frame:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed >= UPDATE_INTERVAL then elapsed = 0; nextAt = updateCycle(visual, nextAt, 5, GetTime()) end
        end)
        visual.frame:Show()
    end
    function handle:Hide() visual.frame:SetScript("OnUpdate", nil); visual.frame:Hide() end
    handle:Refresh()
    return handle
end

function Mod:Refresh()
    self:EnsureFrame()
    if self.visual then self:ApplyVisual(self.visual); Displays:Place(self, "position", self.frame) end
    self:Update()
end

function Mod:Reset()
    self.encounterActive, self.duration, self.nextAt, self.channelStartedAt, self.elapsed = nil, nil, nil, nil, 0
    if self.frame then self.frame:Hide() end
end

function Mod:OnEncounterStart(_, encounterID, _, difficulty)
    self:Reset()
    if E:IsSecret(encounterID) or E:IsSecret(difficulty) or encounterID ~= ENCOUNTER_ID then return end
    if difficulty == 233 then difficulty = 16 end
    self.encounterActive, self.duration = true, DURATIONS[difficulty]
    self:Update()
end

function Mod:OnChannelStart(_, unit)
    if E:SafeString(unit) ~= "boss1" or not self.encounterActive then return end
    self.channelStartedAt = GetTime()
    if self.frame then self.frame:Hide() end
end

function Mod:OnChannelStop(_, unit)
    if E:SafeString(unit) ~= "boss1" or not self.encounterActive or not self.channelStartedAt then return end
    if GetTime() - self.channelStartedAt > MIN_RESET_CHANNEL_DURATION then self.nextAt = nil end
    self.channelStartedAt = nil
    self:Update()
end

function Mod:OnEnable()
    self:Reset()
    E:RunWhenOutOfCombat(MODULE_NAME .. ":Prepare", function() if self:IsEnabled() then self:Refresh() end end)
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "Reset")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Reset")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "OnChannelStart")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "OnChannelStop")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "Refresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    E:CancelRunWhenOutOfCombat(MODULE_NAME .. ":Prepare")
    Displays:SetModulePreview(self, false)
    self:Reset()
end

E:RegisterBossModFeature("SentinelsRange", {
    tab = "VenomousAbyss", order = 15, moduleName = MODULE_NAME,
    bossKey = "EntombedSentinels", bossLabelKey = "BossMods_VA_Boss_EntombedSentinels", bossOrder = 20,
    labelKey = "BossMods_SentinelsRange", descKey = "BossMods_SentinelsRangeDesc"
})
