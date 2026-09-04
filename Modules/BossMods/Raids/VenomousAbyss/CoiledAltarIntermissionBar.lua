local E, L = unpack(ART)

local MODULE_NAME = "BossMods_CoiledAltarIntermissionBar"
local SHARE_TYPE = "CoiledAltarIntermissionBarLayout"
local SHARE_VERSION = "1"
local ENCOUNTER_ID = 3429
local INSTANCE_ID = 3004
local BIGWIGS_MODULE_NAME = "The Coiled Altar"
local INTERMISSION_STAGE = 2.5
local DURATION = 34
local MARKER_COUNT = 7
local WHITE = [[Interface\Buttons\WHITE8x8]]
local DEFAULT_POSITION = {point = "CENTER", x = 0, y = 220}
local DEFAULT_MARKERS = {
    {time = 4.25, text = "4", side = "ABOVE"},
    {time = 8.50, text = "8", side = "BELOW"},
    {time = 12.75, text = "4", side = "ABOVE"},
    {time = 17.00, text = "8", side = "BELOW"},
    {time = 21.25, text = "4", side = "ABOVE"},
    {time = 25.50, text = "8", side = "BELOW"},
    {time = 29.75, text = "4", side = "ABOVE"}
}

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    position = DEFAULT_POSITION,
    width = 460,
    height = 28,
    scale = 1,
    opacity = 1,
    texture = "Blizzard",
    color = {0.30, 0.55, 0.92, 1},
    backgroundColor = {0, 0, 0, 0.72},
    markerColor = {1, 0.82, 0.10, 1},
    markerWidth = 3,
    markerTextOffset = 5,
    font = {
        name = "Friz Quadrata TT",
        size = 14,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    markerFont = {
        name = "Friz Quadrata TT",
        size = 14,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    markers = DEFAULT_MARKERS
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")
local BossMods

local function clamp(value, low, high, fallback)
    value = tonumber(value) or fallback or low
    return math.max(low, math.min(high, value))
end

local function copyColor(value, fallback)
    value = type(value) == "table" and value or fallback
    return {
        tonumber(value[1] or value.r) or fallback[1],
        tonumber(value[2] or value.g) or fallback[2],
        tonumber(value[3] or value.b) or fallback[3],
        tonumber(value[4] or value.a) or fallback[4]
    }
end

local function copyPosition(value)
    value = type(value) == "table" and value or DEFAULT_POSITION
    return {
        point = value.point or "CENTER",
        relPoint = value.relPoint,
        x = tonumber(value.x) or 0,
        y = tonumber(value.y) or 220
    }
end

local function copyFont(value, defaultSize)
    value = type(value) == "table" and value or {}
    return {
        name = value.name or "Friz Quadrata TT",
        size = math.floor(clamp(value.size, 8, 60, defaultSize) + 0.5),
        outline = value.outline or "OUTLINE",
        color = copyColor(value.color, {1, 1, 1, 1})
    }
end

local function copyMarkers(markers)
    local result = {}
    markers = type(markers) == "table" and markers or DEFAULT_MARKERS
    for index = 1, MARKER_COUNT do
        local source = type(markers[index]) == "table" and markers[index]
            or DEFAULT_MARKERS[index]
        local side = source.side == "BELOW" and "BELOW" or "ABOVE"
        result[index] = {
            time = clamp(source.time, 0, DURATION, DEFAULT_MARKERS[index].time),
            text = tostring(source.text or DEFAULT_MARKERS[index].text),
            side = side
        }
    end
    return result
end

local function normalizeLayout(data)
    if type(data) ~= "table" then
        return nil
    end
    return {
        position = copyPosition(data.position),
        width = clamp(data.width, 180, 1000, 460),
        height = clamp(data.height, 10, 100, 28),
        scale = clamp(data.scale, 0.5, 2, 1),
        opacity = clamp(data.opacity, 0.1, 1, 1),
        texture = type(data.texture) == "string" and data.texture or "Blizzard",
        color = copyColor(data.color, {0.30, 0.55, 0.92, 1}),
        backgroundColor = copyColor(data.backgroundColor, {0, 0, 0, 0.72}),
        markerColor = copyColor(data.markerColor, {1, 0.82, 0.10, 1}),
        markerWidth = clamp(data.markerWidth, 1, 14, 3),
        markerTextOffset = clamp(data.markerTextOffset, 0, 30, 5),
        font = copyFont(data.font, 14),
        markerFont = copyFont(data.markerFont, 14),
        markers = copyMarkers(data.markers)
    }
end

local function moduleMatches(moduleInfo)
    return type(moduleInfo) == "table"
        and moduleInfo.moduleName == BIGWIGS_MODULE_NAME
end

local function supportedLocation()
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    return mapID == INSTANCE_ID
end

function Mod:EnsureDefaults()
    local normalized = normalizeLayout(self.db) or normalizeLayout({})
    for _, key in ipairs({
        "position", "width", "height", "scale", "opacity", "texture",
        "color", "backgroundColor", "markerColor", "markerWidth",
        "markerTextOffset"
    }) do
        self.db[key] = normalized[key]
    end
    self.db.font = type(self.db.font) == "table" and self.db.font or {}
    self.db.markerFont = type(self.db.markerFont) == "table" and self.db.markerFont or {}
    for key, value in pairs(normalized.font) do
        self.db.font[key] = value
    end
    for key, value in pairs(normalized.markerFont) do
        self.db.markerFont[key] = value
    end
    self.db.markers = type(self.db.markers) == "table" and self.db.markers or {}
    for index = 1, MARKER_COUNT do
        local target = type(self.db.markers[index]) == "table"
            and self.db.markers[index] or {}
        self.db.markers[index] = target
        for key, value in pairs(normalized.markers[index]) do
            target[key] = value
        end
    end
end

function Mod:ExportLayoutData()
    self:EnsureDefaults()
    return normalizeLayout(self.db)
end

function Mod:ExportLayoutString()
    return E:EncodeShareString(SHARE_TYPE, self:ExportLayoutData())
end

function Mod:ImportLayoutData(data)
    data = normalizeLayout(data)
    if not data then
        return false, L["ImportInvalid"] or "Invalid layout"
    end
    local enabled = self.db.enabled
    for key, value in pairs(data) do self.db[key] = value end
    self.db.enabled = enabled
    self:Refresh()
    E:SendMessage("ART_COILED_ALTAR_INTERMISSION_BAR_CHANGED")
    if E.OptionsUI and E.OptionsUI.QueueRefresh then
        E.OptionsUI:QueueRefresh("current")
    end
    return true
end

function Mod:ImportLayoutString(text)
    local data, err = E:DecodeShareString(SHARE_TYPE, text)
    if not data then
        return false, err
    end
    return self:ImportLayoutData(data)
end

function Mod:ShareLayoutToChat()
    return E:ShareDataToChat(
        SHARE_TYPE,
        self:ExportLayoutData(),
        "Coiled Altar Intermission Bar"
    )
end

function Mod:EnsureFrame()
    if self.frame then
        return true
    end
    if InCombatLockdown() then
        return false
    end

    local anchor = CreateFrame(
        "Frame",
        "ART_CoiledAltarIntermissionBar",
        UIParent,
        "DisableUntrustedLayoutScriptsTemplate"
    )
    anchor:SetClampedToScreen(true)
    anchor:SetFrameStrata("HIGH")
    anchor:EnableMouse(false)
    anchor:Hide()

    local bar = CreateFrame("StatusBar", nil, anchor, "BackdropTemplate")
    bar:SetAllPoints()
    bar:SetMinMaxValues(0, DURATION)
    bar:SetValue(DURATION)
    bar:SetBackdrop({bgFile = E.media.blankTex or WHITE})

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", bar, "LEFT", 6, 0)
    label:SetJustifyH("LEFT")
    label:SetText("Intermission")

    local countdown = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    countdown:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    countdown:SetJustifyH("RIGHT")

    local markers = {}
    for index = 1, MARKER_COUNT do
        local line = bar:CreateTexture(nil, "OVERLAY", nil, 7)
        line:SetTexture(WHITE)
        E:DisableSharpening(line)
        local text = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetJustifyH("CENTER")
        markers[index] = {line = line, text = text}
    end

    anchor:SetScript("OnUpdate", function()
        self:UpdateDisplay()
    end)

    self.frame = anchor
    self.bar = bar
    self.label = label
    self.countdown = countdown
    self.markerFrames = markers
    self:ApplySettings()
    return true
end

function Mod:ApplySettings()
    if not self.frame then
        return
    end
    self:EnsureDefaults()
    local db = self.db
    local width = db.width
    local height = db.height

    self.frame:SetSize(width, height)
    self.frame:SetScale(db.scale)
    self.frame:SetAlpha(db.opacity)
    E:ApplyFramePosition(self.frame, db.position)

    local r, g, b, a = E:ColorTuple(db.color, 1, 1, 1, 1)
    self.bar:SetStatusBarTexture(E:FetchStatusBar(db.texture))
    self.bar:SetStatusBarColor(r, g, b, a)
    local br, bg, bb, ba = E:ColorTuple(db.backgroundColor, 0, 0, 0, 0.72)
    self.bar:SetBackdropColor(br, bg, bb, ba)

    local font = E:FetchFont(db.font.name)
    E:ApplyFontString(self.label, font, db.font.size, db.font.outline)
    E:ApplyFontString(self.countdown, font, db.font.size, db.font.outline)
    local fr, fg, fb, fa = E:ColorTuple(db.font.color, 1, 1, 1, 1)
    self.label:SetTextColor(fr, fg, fb, fa)
    self.countdown:SetTextColor(fr, fg, fb, fa)

    local markerFont = E:FetchFont(db.markerFont.name)
    local mr, mg, mb, ma = E:ColorTuple(db.markerColor, 1, 0.82, 0.1, 1)
    local tr, tg, tb, ta = E:ColorTuple(db.markerFont.color, 1, 1, 1, 1)
    for index, markerData in ipairs(db.markers) do
        local marker = self.markerFrames[index]
        local remainingAtMarker = DURATION - markerData.time
        local x = width * remainingAtMarker / DURATION
        x = math.max(db.markerWidth / 2, math.min(width - db.markerWidth / 2, x))

        marker.line:ClearAllPoints()
        marker.line:SetPoint("CENTER", self.bar, "LEFT", x, 0)
        marker.line:SetSize(db.markerWidth, height)
        marker.line:SetVertexColor(mr, mg, mb, ma)

        E:ApplyFontString(marker.text, markerFont, db.markerFont.size, db.markerFont.outline)
        marker.text:SetTextColor(tr, tg, tb, ta)
        marker.text:SetText(markerData.text)
        marker.text:ClearAllPoints()
        if markerData.side == "BELOW" then
            marker.text:SetPoint("TOP", marker.line, "BOTTOM", 0, -db.markerTextOffset)
        else
            marker.text:SetPoint("BOTTOM", marker.line, "TOP", 0, db.markerTextOffset)
        end
    end
end

function Mod:UpdateDisplay()
    if not self.frame then
        return
    end
    local now = GetTime()
    local elapsed
    if self.editMode then
        elapsed = 0
    elseif self.previewStartedAt then
        elapsed = (now - self.previewStartedAt) % DURATION
    elseif self.activeStartedAt then
        elapsed = now - self.activeStartedAt
    end

    if not elapsed or elapsed < 0 or elapsed > DURATION then
        if self.activeStartedAt and elapsed and elapsed > DURATION then
            self.activeStartedAt = nil
        end
        self.frame:Hide()
        return
    end

    local remaining = math.max(0, DURATION - elapsed)
    self.bar:SetValue(remaining)
    self.countdown:SetText(remaining < 10 and ("%.1f"):format(remaining) or tostring(math.ceil(remaining)))
    self.frame:Show()
end

function Mod:StartIntermissionBar(startedAt)
    if not self.encounterActive or self.currentStage ~= INTERMISSION_STAGE
        or self.startedThisIntermission
    then
        return
    end
    if not self:EnsureFrame() then
        return
    end
    self.startedThisIntermission = true
    self.activeStartedAt = tonumber(startedAt) or GetTime()
    self:UpdateDisplay()
end

function Mod:TryStartFromBossTwo()
    if not self.encounterActive or self.currentStage ~= INTERMISSION_STAGE
        or self.startedThisIntermission
    then
        return
    end
    local now = GetTime()
    if self.lastBossTwoChannelAt and now - self.lastBossTwoChannelAt <= 2 then
        self:StartIntermissionBar(self.lastBossTwoChannelAt)
        return
    end
end

function Mod:UNIT_SPELLCAST_CHANNEL_START(_, unit)
    if unit ~= "boss2" or not self.encounterActive then
        return
    end
    self.lastBossTwoChannelAt = GetTime()
    self:TryStartFromBossTwo()
    C_Timer.After(0, function()
        if self:IsEnabled() then
            self:TryStartFromBossTwo()
        end
    end)
end

function Mod:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
    if unit ~= "boss2" or not self.encounterActive
        or self.currentStage ~= INTERMISSION_STAGE
    then
        return
    end
    self.activeStartedAt = nil
    self:UpdateDisplay()
end

function Mod:OnBigWigsStage(moduleInfo, stage)
    if not self.encounterActive or not moduleMatches(moduleInfo) then
        return
    end
    stage = tonumber(stage)
    if stage == INTERMISSION_STAGE then
        if self.currentStage ~= INTERMISSION_STAGE then
            self.startedThisIntermission = false
        end
        self.currentStage = stage
        self:TryStartFromBossTwo()
    else
        self.currentStage = stage
        self.activeStartedAt = nil
        self.lastBossTwoChannelAt = nil
        self:UpdateDisplay()
    end
end

function Mod:SetEditMode(value)
    if not self:IsEnabled() then
        return
    end
    if value and not self:EnsureFrame() then
        return
    end
    self.editMode = value and true or false
    if self.editMode then
        self.previewStartedAt = nil
    end
    self:UpdateDisplay()
end

function Mod:Preview()
    if not self:IsEnabled() or not self:EnsureFrame() then
        return
    end
    self.editMode = false
    self.previewStartedAt = GetTime()
    self:UpdateDisplay()
end

function Mod:StopPreview()
    self.previewStartedAt = nil
    self:UpdateDisplay()
end

function Mod:SavePosition(position)
    self.db.position = copyPosition(position)
    self:ApplySettings()
end

function Mod:Refresh()
    self:EnsureDefaults()
    if not self:EnsureFrame() then
        return
    end
    self:ApplySettings()
    self:UpdateDisplay()
end

function Mod:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end
    BossMods = BossMods or E:GetModule("BossMods", true)
    if not (BossMods and BossMods.BigWigs and BossMods.BigWigs.Subscribe) then
        return
    end
    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "CoiledAltarIntermissionBar",
        onStage = function(moduleInfo, stage)
            self:OnBigWigsStage(moduleInfo, stage)
        end
    })
end

function Mod:OnEncounterStart(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID or not supportedLocation() then
        return
    end
    self.encounterActive = true
    self.currentStage = 1
    self.startedThisIntermission = false
    self.lastBossTwoChannelAt = nil
    self.activeStartedAt = nil
    self.previewStartedAt = nil
    self.editMode = false
    self:UpdateDisplay()
end

function Mod:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = false
    self.currentStage = nil
    self.startedThisIntermission = false
    self.lastBossTwoChannelAt = nil
    self.activeStartedAt = nil
    self:UpdateDisplay()
end

function Mod:OnInitialize()
    BossMods = E:GetModule("BossMods", true)
    self:EnsureDefaults()
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = "Coiled Altar Intermission Bar",
        sanitize = normalizeLayout,
        getImportName = function()
            return "Coiled Altar Intermission Bar"
        end,
        confirmTitle = "Import Intermission Bar layout",
        confirmText = function(_, sender)
            return ("Import Coiled Altar Intermission Bar layout%s?"):format(
                sender and sender ~= "" and (" from " .. sender) or ""
            )
        end,
        onImport = function(data)
            local ok = self:ImportLayoutData(data)
            if ok then
                E:Printf("Imported Coiled Altar Intermission Bar layout")
            end
        end
    })
    if not InCombatLockdown() then
        self:EnsureFrame()
        self.frame:Hide()
    end
end

function Mod:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:HookBigWigs()
    self:Refresh()
end

function Mod:OnDisable()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.currentStage = nil
    self.activeStartedAt = nil
    self.previewStartedAt = nil
    self.editMode = false
    if self.frame then
        self.frame:Hide()
    end
end

E:RegisterBossModFeature("CoiledAltarIntermissionBar", {
    tab = "AbyssCustom",
    order = 86,
    bossKey = "CoiledAltar",
    bossLabelKey = "BossMods_CoiledAltar",
    bossOrder = 70,
    labelKey = "BossMods_CoiledAltarIntermissionBar",
    descKey = "BossMods_CoiledAltarIntermissionBarDesc",
    moduleName = MODULE_NAME
})
