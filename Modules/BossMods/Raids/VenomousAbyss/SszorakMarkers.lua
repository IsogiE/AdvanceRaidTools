local E = unpack(ART)

E:RegisterModuleDefaults("BossMods_SszorakMarkers", {
    enabled = true,
    buttons = {
        position = {
            point = "CENTER",
            x = 0,
            y = -150
        },
        scale = 1.0,
        opacity = 1.0,
        clickthrough = false,
        keybindLabelPos = "below"
    },
    bar = {
        position = {
            point = "CENTER",
            x = 0,
            y = 50
        },
        scale = 1.0,
        background = {
            opacity = 0.8
        },
        border = {
            enabled = true,
            texture = "Pixel",
            size = 1,
            color = {1, 1, 1, 1}
        }
    }
})

local ENCOUNTER_ID = 3420
local INSTANCE_ID = 3004
local SPELL_HOWLING_MAELSTROM = 1285732
local NOTE_TAG = "sszwinds"
local MAX_SELECTIONS = 3
local RESET_FALLBACK_OFFSET = 0.25

-- Star, Circle, Diamond, Moon, Square, Cross.
local MARKERS = {
    {id = 1, fileID = 137001, name = "Star"},
    {id = 2, fileID = 137002, name = "Circle"},
    {id = 3, fileID = 137003, name = "Diamond"},
    {id = 5, fileID = 137005, name = "Moon"},
    {id = 6, fileID = 137006, name = "Square"},
    {id = 7, fileID = 137007, name = "Cross"}
}

local KEYBIND_NAMES = {}
for i, marker in ipairs(MARKERS) do
    KEYBIND_NAMES[i] = "CLICK ART_SszorakMarkers_Btn" .. i .. ":LeftButton"
    _G["BINDING_NAME_" .. KEYBIND_NAMES[i]] = "Sszorak " .. marker.name .. " Marker"
end

local RAID_MARKER_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcon_%d]]
local WHITE = [[Interface\Buttons\WHITE8x8]]

local SszorakMarkers = E:NewModule("BossMods_SszorakMarkers", "AceEvent-3.0", "AceTimer-3.0")
local BossMods

local function applyBackdrop(frame, bgAlpha, border)
    local edgeFile = E:FetchBorder(border.texture)
    local edgeSize = math.min(border.size or 16, 16)
    local r, g, b, a = E:ColorTuple(border.color, 1, 1, 1, 1)

    if not frame._bgTex then
        frame._bgTex = frame:CreateTexture(nil, "BACKGROUND")
        frame._bgTex:SetTexture(WHITE)
        frame._bgTex:SetAllPoints(frame)
        E:DisableSharpening(frame._bgTex)
    end
    frame._bgTex:SetVertexColor(0, 0, 0, bgAlpha or 0)

    E:ApplyOuterBorder(frame, {
        enabled = border.enabled and true or false,
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        r = r,
        g = g,
        b = b,
        a = a
    })
end

local function currentLocationIsSupported()
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    return mapID == INSTANCE_ID
end

function SszorakMarkers:EnsureFrames()
    if self.frames or InCombatLockdown() then
        return self.frames ~= nil
    end

    local buttonWidth = #MARKERS * 40 + (#MARKERS - 1) * 5
    local buttonAnchor = CreateFrame(
        "Frame",
        "ART_SszorakMarkers_ButtonBar",
        UIParent,
        "SecureHandlerStateTemplate"
    )
    buttonAnchor:SetSize(buttonWidth, 40)
    buttonAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    buttonAnchor:Hide()

    local buttons = {}
    local keybindTexts = {}
    for i, marker in ipairs(MARKERS) do
        local markerID = marker.id
        local button = CreateFrame(
            "Button",
            "ART_SszorakMarkers_Btn" .. i,
            buttonAnchor,
            "SecureActionButtonTemplate"
        )
        button:SetSize(40, 40)
        button:SetPoint("LEFT", buttonAnchor, "LEFT", (i - 1) * 45, 0)
        button:SetAttribute("type1", "macro")
        button:SetAttribute("macrotext1", "/raid " .. marker.fileID)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(5)

        local outer = button:CreateTexture(nil, "BACKGROUND")
        outer:SetAllPoints()
        outer:SetColorTexture(0.3, 0.3, 0.3, 1)

        local inner = button:CreateTexture(nil, "BORDER")
        inner:SetPoint("TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", -1, 1)
        inner:SetColorTexture(0, 0, 0, 1)

        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
        icon:SetTexture(RAID_MARKER_TEXTURE:format(markerID))

        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.3)
        highlight:SetBlendMode("ADD")

        local keybind = button:CreateFontString(nil, "OVERLAY")
        keybind:SetFont([[Fonts\FRIZQT__.TTF]], 9, "OUTLINE")
        keybind:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
        keybind:SetTextColor(1, 1, 1, 1)
        keybind:SetText("")

        buttons[i] = button
        keybindTexts[i] = keybind
    end

    local barAnchor = CreateFrame("Frame", "ART_SszorakMarkers_BarAnchor", UIParent)
    barAnchor:SetSize(180, 76)
    barAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 50)

    local barFrame = CreateFrame("Frame", nil, barAnchor, "BackdropTemplate")
    barFrame:SetAllPoints()
    barFrame:Hide()

    local barDisplays = {}
    local barLabels = {}
    for i = 1, MAX_SELECTIONS do
        local display = barFrame:CreateFontString(nil, "ARTWORK")
        display:SetFont([[Fonts\FRIZQT__.TTF]], 12)
        display:SetSize(36, 36)
        display:SetPoint("TOP", barFrame, "TOP", (i - 2) * 52, -11)
        display:Hide()
        barDisplays[i] = display

        local label = barFrame:CreateFontString(nil, "OVERLAY")
        label:SetFont([[Fonts\FRIZQT__.TTF]], 14, "OUTLINE")
        label:SetPoint("TOP", display, "BOTTOM", 0, -4)
        label:SetText(tostring(i))
        label:Hide()
        barLabels[i] = label
    end

    self.frames = {
        buttonAnchor = buttonAnchor,
        buttons = buttons,
        keybindTexts = keybindTexts,
        barAnchor = barAnchor,
        barFrame = barFrame,
        barDisplays = barDisplays,
        barLabels = barLabels
    }
    return true
end

function SszorakMarkers:ApplySettings()
    if not self.frames then
        return
    end

    local f = self.frames
    if not InCombatLockdown() then
        f.buttonAnchor:SetScale(self.db.buttons.scale or 1)
        f.buttonAnchor:SetAlpha(self.db.buttons.opacity or 1)
        E:ApplyFramePosition(f.buttonAnchor, self.db.buttons.position)
        self:ApplyClickthrough()
    end

    f.barAnchor:SetScale(self.db.bar.scale or 1)
    E:ApplyFramePosition(f.barAnchor, self.db.bar.position)
    applyBackdrop(f.barFrame, self.db.bar.background.opacity, self.db.bar.border)
end

function SszorakMarkers:ApplyClickthrough()
    if not self.frames or InCombatLockdown() then
        return
    end
    local disabled = (self.editVisible and self.editVisible.buttons) or self.db.buttons.clickthrough
    for _, button in ipairs(self.frames.buttons) do
        button:EnableMouse(not disabled)
    end
end

function SszorakMarkers:UpdateKeybindLabels()
    if not self.frames then
        return
    end

    local labelPosition = self.db.buttons.keybindLabelPos or "below"
    for i, keybindName in ipairs(KEYBIND_NAMES) do
        local display = GetBindingKey(keybindName) or ""
        display = display:gsub("ALT%-", "A-")
        display = display:gsub("CTRL%-", "C-")
        display = display:gsub("SHIFT%-", "S-")

        local label = self.frames.keybindTexts[i]
        local button = self.frames.buttons[i]
        if display ~= "" and labelPosition ~= "hidden" then
            label:SetText(display)
            label:ClearAllPoints()
            if labelPosition == "above" then
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

function SszorakMarkers:UpdateDisplay()
    if not self.frames then
        return
    end

    local f = self.frames
    local preview = self.editVisible and self.editVisible.bar

    for i = 1, MAX_SELECTIONS do
        if preview then
            f.barDisplays[i]:SetFormattedText("|T%d:36:36|t", MARKERS[i].fileID)
            f.barDisplays[i]:Show()
            f.barLabels[i]:SetText("|cFF00FF00" .. i .. "|r")
        elseif i <= self.totalFilled then
            f.barDisplays[i]:Show()
            f.barLabels[i]:SetText("|cFF00FF00" .. i .. "|r")
        else
            f.barDisplays[i]:SetText("")
            f.barDisplays[i]:Hide()
            f.barLabels[i]:SetText("|cFFFFFFFF" .. i .. "|r")
        end
    end

    if preview or self.totalFilled > 0 then
        for i = 1, MAX_SELECTIONS do
            f.barLabels[i]:Show()
        end
        f.barFrame:Show()
    else
        for i = 1, MAX_SELECTIONS do
            f.barLabels[i]:Hide()
        end
        f.barFrame:Hide()
    end
end

function SszorakMarkers:CancelResetTimer()
    if self.resetTimer then
        self:CancelTimer(self.resetTimer)
        self.resetTimer = nil
    end
end

function SszorakMarkers:ResetSelection()
    self:CancelResetTimer()
    self.totalFilled = 0
    self.selectionGeneration = self.selectionGeneration + 1
    self.activeMaelstromBarText = nil
    self:UpdateDisplay()
end

function SszorakMarkers:CheckNoteAuthorization()
    local Ready = BossMods and BossMods.ReadyAssignments
    if not (Ready and Ready.BuildContext and Ready.FindPlayerInHashTag) then
        return false
    end

    local Nicknames = E:GetModule("Nicknames", true)
    if Nicknames and Nicknames.SyncSelfNickname then
        Nicknames:SyncSelfNickname()
    end

    local context = Ready:BuildContext()
    return Ready:FindPlayerInHashTag(context, NOTE_TAG, {
        hashtagMultiline = false
    }) ~= nil
end

function SszorakMarkers:OnChatMsg(_, msg)
    if not self.encounterActive or self.totalFilled >= MAX_SELECTIONS then
        return
    end

    self.totalFilled = self.totalFilled + 1
    local pos = self.totalFilled
    local generation = self.selectionGeneration
    self:UpdateDisplay()

    C_Timer.After(0, function()
        if not self.encounterActive or self.selectionGeneration ~= generation then
            return
        end
        self.frames.barDisplays[pos]:SetFormattedText("|T%s:36:36|t", msg)
        self.frames.barDisplays[pos]:Show()
    end)
end

function SszorakMarkers:StartChatListener()
    self:RegisterEvent("CHAT_MSG_RAID", "OnChatMsg")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMsg")
end

function SszorakMarkers:StopChatListener()
    self:UnregisterEvent("CHAT_MSG_RAID")
    self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
end

function SszorakMarkers:OnBigWigsStartBar(key, text, time)
    if not self.encounterActive or key ~= SPELL_HOWLING_MAELSTROM then
        return
    end
    if type(time) ~= "number" or time <= 0 then
        return
    end

    self:CancelResetTimer()
    self.activeMaelstromBarText = text
    local expectedText = text
    self.resetTimer = self:ScheduleTimer(function()
        self.resetTimer = nil
        if self.encounterActive and self.activeMaelstromBarText == expectedText then
            self:ResetSelection()
        end
    end, time + RESET_FALLBACK_OFFSET)
end

function SszorakMarkers:OnBigWigsStopBar(text)
    if not self.encounterActive or not self.activeMaelstromBarText then
        return
    end
    if text == self.activeMaelstromBarText then
        self:ResetSelection()
    end
end

function SszorakMarkers:HookBigWigs()
    if self.bigWigsSubscription then
        return
    end
    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "SszorakMarkers",
        spellKeys = {SPELL_HOWLING_MAELSTROM},
        onStartBar = function(key, text, time)
            self:OnBigWigsStartBar(key, text, time)
        end,
        onStopBar = function(text)
            self:OnBigWigsStopBar(text)
        end
    })
end

function SszorakMarkers:UnhookBigWigs()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
end

function SszorakMarkers:OnEncounterStart(_, encounterID)
    if encounterID ~= ENCOUNTER_ID or not currentLocationIsSupported() then
        return
    end
    self.encounterActive = true
    self:StartChatListener()
    self:ResetSelection()
    self:ApplyVisibility()
end

function SszorakMarkers:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end
    self.encounterActive = false
    self:StopChatListener()
    self:ResetSelection()
    self:ApplyVisibility()
end

function SszorakMarkers:UpdateAuthorization()
    if not self:IsEnabled() then
        return
    end
    self.isAuthorized = self:CheckNoteAuthorization()
    self:ApplyVisibility()
end

function SszorakMarkers:OnNoteChanged(_, slot)
    local mainSlot = E:CallModule("Notes", "GetMainNoteSlot") or 1
    if slot ~= mainSlot or self.noteParseTimer then
        return
    end
    self.noteParseTimer = self:ScheduleTimer(function()
        self.noteParseTimer = nil
        self:UpdateAuthorization()
    end, 1)
end

function SszorakMarkers:ApplyVisibility()
    if not self.frames or not self:IsEnabled() then
        return
    end

    local supported = currentLocationIsSupported()
    local editVisible = self.editVisible or {}
    local normalAvailable = supported or self.encounterActive
    local buttonsActive = editVisible.buttons or (normalAvailable and self.isAuthorized)
    local barActive = editVisible.bar or normalAvailable

    if barActive then
        self.frames.barAnchor:Show()
    else
        self.frames.barAnchor:Hide()
        self.frames.barFrame:Hide()
    end

    if InCombatLockdown() then
        if buttonsActive ~= self.frames.buttonAnchor:IsShown() then
            E:RunWhenOutOfCombat("SszorakMarkers:UpdateState", function()
                if self:IsEnabled() then
                    self:UpdateState()
                end
            end)
        end
        return
    end

    if buttonsActive then
        self.frames.buttonAnchor:Show()
    else
        self.frames.buttonAnchor:Hide()
    end
end

function SszorakMarkers:UpdateState()
    if not self:IsEnabled() then
        return
    end
    if not self.frames then
        if InCombatLockdown() then
            E:RunWhenOutOfCombat("SszorakMarkers:UpdateState", function()
                if self:IsEnabled() then
                    self:UpdateState()
                end
            end)
            return
        end
        if not self:EnsureFrames() then
            return
        end
        self:ApplySettings()
        self:UpdateKeybindLabels()
    end

    self.isAuthorized = self:CheckNoteAuthorization()
    self:ApplyVisibility()
end

function SszorakMarkers:OnZoneOrLogin()
    self:UpdateState()
end

function SszorakMarkers:SetEditMode(value, visibleKeys)
    if not self:IsEnabled() then
        return
    end
    self.editMode = value and true or false
    if visibleKeys == nil and self.editMode then
        visibleKeys = {buttons = true, bar = true}
    end
    self.editVisible = self.editMode and visibleKeys or {}
    self:UpdateDisplay()
    self:ApplyVisibility()
    self:ApplyClickthrough()
end

function SszorakMarkers:SavePosition(anchorKey, position)
    if not self.db[anchorKey] then
        return
    end
    local saved = self.db[anchorKey].position
    saved.point = position.point
    saved.x = position.x
    saved.y = position.y
    self:ApplySettings()
end

function SszorakMarkers:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplySettings()
    self:UpdateKeybindLabels()
    self:UpdateDisplay()
    self:UpdateAuthorization()
end

function SszorakMarkers:OnInitialize()
    BossMods = E:GetModule("BossMods")
    self.encounterActive = false
    self.isAuthorized = false
    self.editMode = false
    self.editVisible = {}
    self.totalFilled = 0
    self.selectionGeneration = 0

    if not InCombatLockdown() then
        self:EnsureFrames()
        if self.frames then
            self:ApplySettings()
            self:UpdateKeybindLabels()
            self.frames.buttonAnchor:Hide()
            self.frames.barAnchor:Hide()
        end
    end
end

function SszorakMarkers:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")
    self:EnsureFrames()
    if self.frames then
        self:ApplySettings()
        self:UpdateKeybindLabels()
    end

    self:RegisterEvent("UPDATE_BINDINGS", "UpdateKeybindLabels")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneOrLogin")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_NOTE_CHANGED", "OnNoteChanged")
    self:RegisterMessage("ART_NICKNAME_CHANGED", "UpdateAuthorization")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:HookBigWigs()
    self:UpdateState()
end

function SszorakMarkers:OnDisable()
    self:UnhookBigWigs()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.editMode = false
    self.editVisible = {}
    self:ResetSelection()

    if self.noteParseTimer then
        self:CancelTimer(self.noteParseTimer)
        self.noteParseTimer = nil
    end

    if not self.frames then
        return
    end
    self.frames.barAnchor:Hide()
    self.frames.barFrame:Hide()

    if not InCombatLockdown() then
        self.frames.buttonAnchor:Hide()
    else
        E:RunWhenOutOfCombat("SszorakMarkers:HideButtonBar", function()
            if not self:IsEnabled() and self.frames then
                self.frames.buttonAnchor:Hide()
            end
        end)
    end
end

E:RegisterBossModFeature("SszorakMarkers", {
    tab = "AbyssCustom",
    order = 55,
    labelKey = "BossMods_SszorakMarkers",
    descKey = "BossMods_SszorakMarkersDesc",
    moduleName = "BossMods_SszorakMarkers"
})
