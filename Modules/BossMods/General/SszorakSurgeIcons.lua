local E = unpack(ART)

local MODULE_NAME = "BossMods_SszorakSurgeIcons"
local ENCOUNTER_ID = 3420
local HOWLING_MAELSTROM_ID = 1285732
local CLEAR_AFTER_TIMER_ZERO = 20
local MAX_SEQUENCE = 4
local CHAT_CHANNEL = "/raid "
local WHITE = [[Interface\Buttons\WHITE8x8]]
local RAID_TARGET_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = false,
    buttons = {
        position = {point = "CENTER", x = 0, y = -150},
        scale = 1,
        opacity = 1,
        clickthrough = false,
        keybindLabelPos = "below"
    },
    display = {
        position = {point = "CENTER", x = 0, y = 50},
        scale = 1,
        background = {opacity = 0.8},
        border = {
            enabled = true,
            texture = "Pixel",
            size = 1,
            color = {1, 1, 1, 1}
        }
    }
})

local MARKERS = {
    {name = "Star", index = 1, token = "{rt1}"},
    {name = "Circle", index = 2, token = "{rt2}"},
    {name = "Diamond", index = 3, token = "{rt3}"},
    {name = "Moon", index = 5, token = "{rt5}"},
    {name = "Square", index = 6, token = "{rt6}"},
    {name = "Cross", index = 7, token = "{rt7}"}
}

local TOKEN_TO_MARKER = {
    ["{rt1}"] = 1,
    ["{star}"] = 1,
    ["{rt2}"] = 2,
    ["{circle}"] = 2,
    ["{rt3}"] = 3,
    ["{diamond}"] = 3,
    ["{rt5}"] = 5,
    ["{moon}"] = 5,
    ["{rt6}"] = 6,
    ["{square}"] = 6,
    ["{rt7}"] = 7,
    ["{cross}"] = 7,
    ["{x}"] = 7
}

local KEYBIND_NAMES = {}
BINDING_HEADER_ART_SURGE_ICONS = "ART"
for index, marker in ipairs(MARKERS) do
    local binding = "CLICK ART_SurgeIcon_Btn" .. index .. ":LeftButton"
    KEYBIND_NAMES[index] = binding
    _G["BINDING_NAME_" .. binding] = "Surge Icon: " .. marker.name
end

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0", "AceTimer-3.0")
local BossMods

local function setRaidMarkerTexture(texture, markerIndex)
    texture:SetTexture(RAID_TARGET_TEXTURE)
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(texture, markerIndex)
        return
    end
    local column = (markerIndex - 1) % 4
    local row = math.floor((markerIndex - 1) / 4)
    texture:SetTexCoord(column / 4, (column + 1) / 4, row / 4, (row + 1) / 4)
end

local function applyBackdrop(frame, opacity, border)
    if not frame._background then
        frame._background = frame:CreateTexture(nil, "BACKGROUND")
        frame._background:SetTexture(WHITE)
        frame._background:SetAllPoints(frame)
        E:DisableSharpening(frame._background)
    end
    frame._background:SetVertexColor(0, 0, 0, opacity or 0.8)

    local r, g, b, a = E:ColorTuple(border.color, 1, 1, 1, 1)
    E:ApplyOuterBorder(frame, {
        enabled = border.enabled == true,
        edgeFile = E:FetchBorder(border.texture),
        edgeSize = math.min(tonumber(border.size) or 1, 16),
        r = r,
        g = g,
        b = b,
        a = a
    })
end

local function markerFromMessage(message)
    if type(message) ~= "string" then
        return nil
    end
    local value = strtrim(message):lower()
    local marker = TOKEN_TO_MARKER[value]
    if marker then
        return marker
    end

    local textureMarker = value:match("^|t.-ui%-raidtargetingicon_([123567]).-|t$")
    return tonumber(textureMarker)
end

function Mod:EnsureFrames()
    if self.frames or InCombatLockdown() then
        return self.frames ~= nil
    end

    local buttonAnchor = CreateFrame("Frame", "ART_SurgeIcon_ButtonBar", UIParent, "SecureHandlerStateTemplate")
    buttonAnchor:SetSize(265, 40)
    buttonAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    buttonAnchor:Hide()

    local buttons, keybindTexts = {}, {}
    for index, marker in ipairs(MARKERS) do
        local button = CreateFrame("Button", "ART_SurgeIcon_Btn" .. index, buttonAnchor, "SecureActionButtonTemplate")
        button:SetSize(40, 40)
        button:SetPoint("LEFT", buttonAnchor, "LEFT", (index - 1) * 45, 0)
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", CHAT_CHANNEL .. marker.token)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(5)

        local outer = button:CreateTexture(nil, "BACKGROUND")
        outer:SetAllPoints(button)
        outer:SetColorTexture(0.3, 0.3, 0.3, 1)

        local inner = button:CreateTexture(nil, "BORDER")
        inner:SetPoint("TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", -1, 1)
        inner:SetColorTexture(0, 0, 0, 1)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        setRaidMarkerTexture(icon, marker.index)

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetColorTexture(1, 1, 1, 0.3)
        highlight:SetBlendMode("ADD")

        local keybind = button:CreateFontString(nil, "OVERLAY")
        keybind:SetFont([[Fonts\FRIZQT__.TTF]], 9, "OUTLINE")
        keybind:SetTextColor(1, 1, 1, 1)
        keybind:SetText("")

        buttons[index] = button
        keybindTexts[index] = keybind
    end

    local displayAnchor = CreateFrame("Frame", "ART_SurgeIcon_DisplayAnchor", UIParent)
    displayAnchor:SetSize(200, 64)
    displayAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 50)

    local displayFrame = CreateFrame("Frame", nil, displayAnchor, "BackdropTemplate")
    displayFrame:SetAllPoints(displayAnchor)
    displayFrame:Hide()

    local displayIcons = {}
    for index = 1, MAX_SEQUENCE do
        local icon = displayFrame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", displayFrame, "LEFT", 20 + (index - 1) * 42, 0)
        icon:Hide()

        displayIcons[index] = icon
    end

    self.frames = {
        buttonAnchor = buttonAnchor,
        buttons = buttons,
        keybindTexts = keybindTexts,
        displayAnchor = displayAnchor,
        displayFrame = displayFrame,
        displayIcons = displayIcons
    }
    return true
end

function Mod:ApplySettings()
    if not self.frames then
        return
    end
    local frames = self.frames

    if not InCombatLockdown() then
        frames.buttonAnchor:SetScale(self.db.buttons.scale or 1)
        frames.buttonAnchor:SetAlpha(self.db.buttons.opacity or 1)
        E:ApplyFramePosition(frames.buttonAnchor, self.db.buttons.position)
        self:ApplyClickthrough()
    end

    frames.displayAnchor:SetScale(self.db.display.scale or 1)
    E:ApplyFramePosition(frames.displayAnchor, self.db.display.position)
    applyBackdrop(frames.displayFrame, self.db.display.background.opacity, self.db.display.border)
end

function Mod:ApplyClickthrough()
    if not self.frames or InCombatLockdown() then
        return
    end
    local clickthrough = self.editVisibleButtons or self.db.buttons.clickthrough
    for _, button in ipairs(self.frames.buttons) do
        button:EnableMouse(not clickthrough)
    end
end

function Mod:UpdateKeybindLabels()
    if not self.frames then
        return
    end
    local position = self.db.buttons.keybindLabelPos or "below"
    for index, button in ipairs(self.frames.buttons) do
        local key = GetBindingKey(KEYBIND_NAMES[index]) or ""
        key = key:gsub("ALT%-", "A-"):gsub("CTRL%-", "C-"):gsub("SHIFT%-", "S-")
        local label = self.frames.keybindTexts[index]
        label:ClearAllPoints()
        if key ~= "" and position ~= "hidden" then
            label:SetText(key)
            if position == "above" then
                label:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
            else
                label:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
            end
            label:Show()
        else
            label:SetText("")
            label:Hide()
        end
    end
end

function Mod:CheckAuthorization()
    local noteBlock = BossMods and BossMods.NoteBlock
    if not noteBlock then
        return false
    end
    local block = noteBlock:ExtractBlock(noteBlock:GetMainNoteText(), "surge")
    if not block then
        return false
    end
    local identifiers = noteBlock:GetPlayerIdentifiers()
    for _, word in ipairs(noteBlock:Words(block)) do
        if noteBlock:IsPlayerToken(word, identifiers) then
            return true
        end
    end
    return false
end

function Mod:UpdateAuthorization()
    self.isAuthorized = self:CheckAuthorization()
    self:ApplyVisibility()
end

function Mod:OnNoteChanged(_, slot)
    local mainSlot = E:CallModule("Notes", "GetMainNoteSlot") or 1
    if slot ~= mainSlot or self.noteTimer then
        return
    end
    self.noteTimer = self:ScheduleTimer(function()
        self.noteTimer = nil
        self:UpdateAuthorization()
    end, 1)
end

function Mod:ClearSequence()
    self.sequence = {}
    self.accepting = true
    if not self.frames then
        return
    end
    for index = 1, MAX_SEQUENCE do
        self.frames.displayIcons[index]:Hide()
    end
    self.frames.displayFrame:Hide()
    if self.editMode then
        self:ShowEditPreview()
    end
end

function Mod:ShowEditPreview()
    if not self.frames then
        return
    end
    local previewMarkers = {1, 2, 3, 5}
    for index, markerIndex in ipairs(previewMarkers) do
        setRaidMarkerTexture(self.frames.displayIcons[index], markerIndex)
        self.frames.displayIcons[index]:Show()
    end
    self.frames.displayFrame:Show()
end

function Mod:AddMarker(markerIndex)
    if not self.accepting or #self.sequence >= MAX_SEQUENCE or not self.frames then
        return
    end
    self.sequence[#self.sequence + 1] = markerIndex
    local position = #self.sequence
    local icon = self.frames.displayIcons[position]
    setRaidMarkerTexture(icon, markerIndex)
    icon:Show()
    self.frames.displayFrame:Show()
    if position >= MAX_SEQUENCE then
        self.accepting = false
    end
end

function Mod:OnChatMessage(_, message)
    if not self.inEncounter then
        return
    end
    local markerIndex = markerFromMessage(message)
    if markerIndex then
        self:AddMarker(markerIndex)
    end
end

function Mod:OnBigWigsStartBar(key, _, time)
    if not self.inEncounter or tonumber(key) ~= HOWLING_MAELSTROM_ID or type(time) ~= "number" then
        return
    end
    if self.clearTimer then
        self.clearTimer:Cancel()
    end
    self.clearTimer = C_Timer.NewTimer(math.max(0, time + CLEAR_AFTER_TIMER_ZERO), function()
        self.clearTimer = nil
        self:ClearSequence()
    end)
end

function Mod:HookBigWigs()
    if self.bwHandle then
        return
    end
    self.bwHandle = BossMods.BigWigs:Subscribe({
        owner = "SszorakSurgeIcons",
        spellKeys = {HOWLING_MAELSTROM_ID},
        onStartBar = function(...)
            self:OnBigWigsStartBar(...)
        end
    })
end

function Mod:UnhookBigWigs()
    if self.bwHandle then
        self.bwHandle:Unsubscribe()
        self.bwHandle = nil
    end
end

function Mod:OnEncounterStart(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.inEncounter = true
    self:RegisterEvent("CHAT_MSG_RAID", "OnChatMessage")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMessage")
    self:ClearSequence()
end

function Mod:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) ~= ENCOUNTER_ID then
        return
    end
    self.inEncounter = false
    self:UnregisterEvent("CHAT_MSG_RAID")
    self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    if self.clearTimer then
        self.clearTimer:Cancel()
        self.clearTimer = nil
    end
    self:ClearSequence()
end

function Mod:ApplyVisibility()
    if not self.frames then
        return
    end
    local showButtons = self.editVisibleButtons or self.isAuthorized
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("SszorakSurgeIcons:Visibility", function()
            if self:IsEnabled() then
                self:ApplyVisibility()
            end
        end)
    elseif showButtons then
        self.frames.buttonAnchor:Show()
    else
        self.frames.buttonAnchor:Hide()
    end
end

function Mod:SetEditMode(value)
    self.editMode = value and true or false
    self.editVisibleButtons = self.editMode
    if not self.frames then
        return
    end
    if self.editMode then
        self:ShowEditPreview()
    elseif #self.sequence == 0 then
        self.frames.displayFrame:Hide()
        for index = 1, MAX_SEQUENCE do
            self.frames.displayIcons[index]:Hide()
        end
    else
        for index = 1, MAX_SEQUENCE do
            if self.sequence[index] then
                setRaidMarkerTexture(self.frames.displayIcons[index], self.sequence[index])
                self.frames.displayIcons[index]:Show()
            else
                self.frames.displayIcons[index]:Hide()
            end
        end
        self.frames.displayFrame:Show()
    end
    self:ApplyVisibility()
    self:ApplyClickthrough()
end

function Mod:SavePosition(section, position)
    local settings = self.db[section]
    if not settings then
        return
    end
    settings.position.point = position.point or "CENTER"
    settings.position.x = tonumber(position.x) or 0
    settings.position.y = tonumber(position.y) or 0
    self:ApplySettings()
end

function Mod:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplySettings()
    self:UpdateKeybindLabels()
    self:UpdateAuthorization()
end

function Mod:OnInitialize()
    BossMods = E:GetModule("BossMods")
    self.sequence = {}
    self.accepting = true
    self.inEncounter = false
    self.isAuthorized = false
    self.editMode = false
    self.editVisibleButtons = false
    self:EnsureFrames()
    if self.frames then
        self:ApplySettings()
        self:UpdateKeybindLabels()
        self.frames.buttonAnchor:Hide()
        self.frames.displayFrame:Hide()
    end
end

function Mod:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")
    if not self.frames and not self:EnsureFrames() then
        E:RunWhenOutOfCombat("SszorakSurgeIcons:Initialize", function()
            if self:IsEnabled() then
                self:OnEnable()
            end
        end)
        return
    end

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("UPDATE_BINDINGS", "UpdateKeybindLabels")
    self:RegisterMessage("ART_NOTE_CHANGED", "OnNoteChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:HookBigWigs()
    self:Refresh()
end

function Mod:OnDisable()
    self:UnhookBigWigs()
    if self.clearTimer then
        self.clearTimer:Cancel()
        self.clearTimer = nil
    end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.inEncounter = false
    self.editMode = false
    self.editVisibleButtons = false
    self.sequence = {}
    self.accepting = true
    if not self.frames then
        return
    end
    self.frames.displayFrame:Hide()
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("SszorakSurgeIcons:Disable", function()
            if not self:IsEnabled() and self.frames then
                self.frames.buttonAnchor:Hide()
            end
        end)
    else
        self.frames.buttonAnchor:Hide()
    end
end

E:RegisterBossModFeature("SszorakSurgeIcons", {
    tab = "General",
    order = 60,
    labelKey = "BossMods_SszorakSurgeIcons",
    descKey = "BossMods_SszorakSurgeIconsDesc",
    moduleName = MODULE_NAME
})
