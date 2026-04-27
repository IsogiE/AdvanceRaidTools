local E, L, P = unpack(ART)

P.modules.BossMods_Dirge = {
    enabled = false,
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
    squad = {
        position = {
            point = "CENTER",
            x = -200,
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
    },
    tts = {
        enabled = false,
        voice = 0
    }
}

local DEBUG_MODE = false
local ENCOUNTER_ID = 3183
local INSTANCE_ID = 2913
local PHASE_SWAP_DEBOUNCE = 5
local CHAT_LISTENER_WINDOW = 15
local LEAD_TIME_OFFSET = 2
local TTS_TICK_INTERVAL = 1.5
local TTS_EXTRA_TICKS = 3

local RUNE_ICON_IDS = {1392912, -- 1: 70_inscription_deck_dominion_2
1392913, -- 2: 70_inscription_deck_dominion_3
1392914, -- 3: 70_inscription_deck_dominion_4
1392915, -- 4: 70_inscription_deck_dominion_5
1392916, -- 5: 70_inscription_deck_dominion_6
1392917 -- 6: 70_inscription_deck_dominion_7
}

local SQUAD_POSITIONS = {{
    point = "CENTER",
    x = 36,
    y = 52
}, -- #1 Top Right
{
    point = "CENTER",
    x = 56,
    y = -4
}, -- #2 3pm
{
    point = "CENTER",
    x = 0,
    y = -52
}, -- #3 6pm
{
    point = "CENTER",
    x = -56,
    y = -4
}, -- #4 9pm
{
    point = "CENTER",
    x = -36,
    y = 52
} -- #5 Top Left
}

local SHAPE_NAMES = {"4", "6", "7", "2", "3", "5"}

local CHAT_MSGS = {
    ["2"] = "1392915",
    ["3"] = "1392916",
    ["4"] = "1392912",
    ["5"] = "1392917",
    ["6"] = "1392913",
    ["7"] = "1392914"
}

local KEYBIND_NAMES = {"CLICK ART_Dirge_Btn1:LeftButton", "CLICK ART_Dirge_Btn2:LeftButton",
                       "CLICK ART_Dirge_Btn3:LeftButton", "CLICK ART_Dirge_Btn4:LeftButton",
                       "CLICK ART_Dirge_Btn5:LeftButton", "CLICK ART_Dirge_Btn6:LeftButton"}

local PHASE_TRANSITIONS = {
    [15] = {
        [1] = {
            duration = 45,
            next = 2
        },
        [2] = {
            duration = 97,
            next = 3
        }
    },
    [16] = {
        [1] = {
            duration = 45,
            next = 2
        },
        [2] = {
            duration = 97,
            next = 3
        },
        [3] = {
            duration = 180,
            next = 4
        }
    }
}

local MYTHIC_DIFFICULTY = 16
local MYTHIC_SET_SIZES = {3, 3, 3, 3, 4, 4}
local MAX_BAR_DISPLAY = math.max(unpack(MYTHIC_SET_SIZES))
local REQUIEM_GROUP_MAP = {1, 2, 2, 1, 1, 2}

local BW_KEY_NON_MYTHIC = {
    [1249620] = true,
    [1284980] = true
}
local BW_KEY_MYTHIC = 1273158

local CHAT_CHANNEL = "/raid "

BINDING_HEADER_ART_DIRGE = "ART"
for i = 1, 6 do
    _G["BINDING_NAME_CLICK ART_Dirge_Btn" .. i .. ":LeftButton"] = "Dirge Button " .. i
end

local Dirge = E:NewModule("BossMods_Dirge", "AceEvent-3.0", "AceTimer-3.0")

local BossMods

local WHITE = [[Interface\Buttons\WHITE8x8]]

local function applyBackdrop(frame, bgAlpha, border)
    local enabled = border.enabled and true or false
    local edgeFile = E:FetchBorder(border.texture)
    local edgeSize = math.min(border.size or 16, 16)
    local isPixel = (edgeFile == E.media.blankTex)
    local r, g, b, a = E:ColorTuple(border.color, 1, 1, 1, 1)

    if not frame._bgTex then
        frame._bgTex = frame:CreateTexture(nil, "BACKGROUND")
        frame._bgTex:SetTexture(WHITE)
        frame._bgTex:SetAllPoints(frame)
    end
    frame._bgTex:SetVertexColor(0, 0, 0, bgAlpha)

    if enabled and not isPixel then
        if frame._artBdMode ~= "edge" or frame._artBdEdgeFile ~= edgeFile or frame._artBdEdgeSize ~= edgeSize then
            frame:SetBackdrop({
                edgeFile = edgeFile,
                edgeSize = edgeSize,
                insets = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            })
            frame._artBdMode = "edge"
            frame._artBdEdgeFile = edgeFile
            frame._artBdEdgeSize = edgeSize
        end
        frame:SetBackdropBorderColor(r, g, b, a)
        E:ApplyOuterBorder(frame, {
            enabled = false
        })
    else
        if frame._artBdMode ~= "none" then
            frame:SetBackdrop(nil)
            frame._artBdMode = "none"
            frame._artBdEdgeFile = nil
            frame._artBdEdgeSize = nil
        end
        E:ApplyOuterBorder(frame, {
            enabled = enabled,
            edgeFile = edgeFile,
            edgeSize = edgeSize,
            r = r,
            g = g,
            b = b,
            a = a
        })
    end
end

-- Frame construction

function Dirge:EnsureFrames()
    if self.frames or InCombatLockdown() then
        return self.frames ~= nil
    end

    local barAnchor = CreateFrame("Frame", "ART_Dirge_ButtonBar", UIParent, "SecureHandlerStateTemplate")
    barAnchor:SetSize(265, 40)
    barAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    barAnchor:Hide()

    local secureButtons = {}
    local keybindTexts = {}
    local buttonIcons = {}

    for i = 1, 6 do
        local btn = CreateFrame("Button", "ART_Dirge_Btn" .. i, barAnchor, "SecureActionButtonTemplate")
        btn:SetSize(40, 40)
        btn:SetPoint("LEFT", barAnchor, "LEFT", (i - 1) * 45, 0)
        btn:SetAttribute("type1", "macro")
        btn:SetAttribute("macrotext1", CHAT_CHANNEL .. CHAT_MSGS[SHAPE_NAMES[i]])
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetFrameStrata("MEDIUM")
        btn:SetFrameLevel(5)

        local outer = btn:CreateTexture(nil, "BACKGROUND")
        outer:SetAllPoints()
        outer:SetColorTexture(0.3, 0.3, 0.3, 1)

        local inner = btn:CreateTexture(nil, "BORDER")
        inner:SetPoint("TOPLEFT", 1, -1)
        inner:SetPoint("BOTTOMRIGHT", -1, 1)
        inner:SetColorTexture(0, 0, 0, 1)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(RUNE_ICON_IDS[i])
        buttonIcons[i] = icon

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.3)
        hl:SetBlendMode("ADD")

        local kb = btn:CreateFontString(nil, "OVERLAY")
        kb:SetFont([[Fonts\FRIZQT__.TTF]], 9, "OUTLINE")
        kb:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
        kb:SetTextColor(1, 1, 1, 1)
        kb:SetText("")
        keybindTexts[i] = kb

        secureButtons[i] = btn
    end

    local squadAnchor = CreateFrame("Frame", "ART_Dirge_SquadAnchor", UIParent)
    squadAnchor:SetSize(170, 170)
    squadAnchor:SetPoint("CENTER", UIParent, "CENTER", -200, 50)

    local squadFrame = CreateFrame("Frame", nil, squadAnchor, "BackdropTemplate")
    squadFrame:SetAllPoints()
    squadFrame:Hide()

    local redCircle = squadFrame:CreateTexture(nil, "ARTWORK")
    redCircle:SetColorTexture(0.9, 0, 0, 1)
    redCircle:SetSize(40, 40)
    redCircle:SetPoint("CENTER", squadFrame, "CENTER", 0, -4)

    local mask = squadFrame:CreateMaskTexture()
    mask:SetTexture([[Interface\CharacterFrame\TempPortraitAlphaMask]], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(redCircle)
    redCircle:AddMaskTexture(mask)

    local tankIcon = squadFrame:CreateTexture(nil, "OVERLAY")
    tankIcon:SetAtlas("groupfinder-icon-role-large-tank")
    tankIcon:SetSize(30, 30)
    tankIcon:SetPoint("CENTER", redCircle, "TOP", 0, 0)

    local squadDisplay, squadBaseline = {}, {}
    for i = 1, 5 do
        local fs = squadFrame:CreateFontString(nil, "OVERLAY")
        fs:SetFont([[Fonts\FRIZQT__.TTF]], 12)
        fs:SetPoint(SQUAD_POSITIONS[i].point, squadFrame, SQUAD_POSITIONS[i].point, SQUAD_POSITIONS[i].x,
            SQUAD_POSITIONS[i].y - 12)
        fs:SetSize(32, 32)
        fs:Hide()
        squadDisplay[i] = fs

        local bfs = squadFrame:CreateFontString(nil, "OVERLAY")
        bfs:SetFont([[Fonts\FRIZQT__.TTF]], 14, "OUTLINE")
        bfs:SetPoint(SQUAD_POSITIONS[i].point, squadFrame, SQUAD_POSITIONS[i].point, SQUAD_POSITIONS[i].x,
            SQUAD_POSITIONS[i].y + 12)
        bfs:Hide()
        squadBaseline[i] = bfs
    end

    local seqBarAnchor = CreateFrame("Frame", "ART_Dirge_BarAnchor", UIParent)
    seqBarAnchor:SetSize(200, 64)
    seqBarAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 50)

    local barFrame = CreateFrame("Frame", nil, seqBarAnchor, "BackdropTemplate")
    barFrame:SetAllPoints()
    barFrame:Hide()

    local barDisplay, barBaseline = {}, {}
    for i = 1, 5 do
        local fs = barFrame:CreateFontString(nil, "OVERLAY")
        fs:SetFont([[Fonts\FRIZQT__.TTF]], 12)
        fs:SetPoint("LEFT", barFrame, "LEFT", 10 + (i - 1) * 36, 6)
        fs:SetSize(32, 32)
        fs:Hide()
        barDisplay[i] = fs

        local bfs = barFrame:CreateFontString(nil, "OVERLAY")
        bfs:SetFont([[Fonts\FRIZQT__.TTF]], 14, "OUTLINE")
        bfs:SetPoint("TOP", fs, "BOTTOM", 0, 2)
        bfs:Hide()
        barBaseline[i] = bfs
    end

    self.frames = {
        barAnchor = barAnchor,
        secureButtons = secureButtons,
        keybindTexts = keybindTexts,
        buttonIcons = buttonIcons,
        squadAnchor = squadAnchor,
        squadFrame = squadFrame,
        squadDisplay = squadDisplay,
        squadBaseline = squadBaseline,
        seqBarAnchor = seqBarAnchor,
        barFrame = barFrame,
        barDisplay = barDisplay,
        barBaseline = barBaseline
    }
    return true
end

-- Apply settings

function Dirge:ApplySettings()
    if not self.frames then
        return
    end
    local db = self.db
    local f = self.frames

    if not InCombatLockdown() then
        f.barAnchor:SetScale(db.buttons.scale or 1)
        f.barAnchor:SetAlpha(db.buttons.opacity or 1)

        local pb = db.buttons.position
        f.barAnchor:ClearAllPoints()
        f.barAnchor:SetPoint(pb.point or "CENTER", UIParent, pb.point or "CENTER", pb.x or 0, pb.y or 0)

        for j = 1, 6 do
            f.secureButtons[j]:ClearAllPoints()
            f.secureButtons[j]:SetPoint("LEFT", f.barAnchor, "LEFT", (j - 1) * 45, 0)
        end

        self:ApplyClickthrough()
    end

    f.squadAnchor:SetScale(db.squad.scale or 1)
    local ps = db.squad.position
    f.squadAnchor:ClearAllPoints()
    f.squadAnchor:SetPoint(ps.point or "CENTER", UIParent, ps.point or "CENTER", ps.x or 0, ps.y or 0)
    applyBackdrop(f.squadFrame, db.squad.background.opacity, db.squad.border)

    f.seqBarAnchor:SetScale(db.bar.scale or 1)
    local pBar = db.bar.position
    f.seqBarAnchor:ClearAllPoints()
    f.seqBarAnchor:SetPoint(pBar.point or "CENTER", UIParent, pBar.point or "CENTER", pBar.x or 0, pBar.y or 0)
    applyBackdrop(f.barFrame, db.bar.background.opacity, db.bar.border)
end

function Dirge:ApplyClickthrough()
    if not self.frames or InCombatLockdown() then
        return
    end
    local enabled = (self.editVisible and self.editVisible.buttons) or self.db.buttons.clickthrough
    for i = 1, 6 do
        self.frames.secureButtons[i]:EnableMouse(not enabled)
    end
end

function Dirge:UpdateKeybindLabels()
    if not self.frames then
        return
    end
    local pos = self.db.buttons.keybindLabelPos or "below"
    for i = 1, 6 do
        local key1 = GetBindingKey(KEYBIND_NAMES[i])
        local display = key1 or ""
        display = display:gsub("ALT%-", "A-")
        display = display:gsub("CTRL%-", "C-")
        display = display:gsub("SHIFT%-", "S-")

        local fs = self.frames.keybindTexts[i]
        local btn = self.frames.secureButtons[i]
        if display ~= "" and pos ~= "hidden" then
            fs:SetText(display)
            fs:ClearAllPoints()
            if pos == "above" then
                fs:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
            else
                fs:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
            end
            fs:Show()
        else
            fs:SetText("")
            fs:Hide()
        end
    end
end

-- TTS sequence

function Dirge:StopTTS()
    if self.ttsTicker then
        self.ttsTicker:Cancel()
        self.ttsTicker = nil
    end
end

function Dirge:StartTTSSequence()
    self:StopTTS()
    if not self.db.tts.enabled then
        return
    end

    local Alerts = BossMods.Alerts
    local voice = self.db.tts.voice or 0
    Alerts:SpeakTTS({
        text = "2",
        voiceID = voice
    })

    local step = 3
    self.ttsTicker = C_Timer.NewTicker(TTS_TICK_INTERVAL, function()
        Alerts:SpeakTTS({
            text = tostring(step),
            voiceID = voice
        })
        step = step + 1
    end, TTS_EXTRA_TICKS)
end

-- Rune display

function Dirge:HideRuneDisplays()
    if not self.frames then
        return
    end
    local f = self.frames
    for i = 1, 5 do
        f.squadDisplay[i]:Hide()
        f.barDisplay[i]:Hide()
        f.barBaseline[i]:Hide()
        f.squadBaseline[i]:Hide()
    end
    f.squadFrame:Hide()
    f.barFrame:Hide()
end

function Dirge:WipeCurrentMarks(startFix)
    self.totalFilled = 0
    self.filledRunes = {false, false, false, false, false}
    self.isFixing = startFix or false
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self:StopTTS()
    self:HideRuneDisplays()
end

function Dirge:HideAllRunes()
    if self.totalFilled > 0 and self.inEncounter then
        if self.inMythicPhase then
            self.mythicSetIndex = self.mythicSetIndex + 1
        elseif DEBUG_MODE then
            self.mythicSetIndex = (self.mythicSetIndex + 1) % #MYTHIC_SET_SIZES
        end
    end
    self.totalFilled = 0
    self.filledRunes = {false, false, false, false, false}
    self.isFixing = false
    self:StopTTS()
    self:HideRuneDisplays()
end

--  Note

function Dirge:CheckNoteAuthorization()
    local NoteBlock = BossMods.NoteBlock
    local block = NoteBlock:ExtractBlock(NoteBlock:GetMainNoteText(), "dirge")
    if not block then
        return false
    end
    local ids = NoteBlock:GetPlayerIdentifiers()
    for _, word in ipairs(NoteBlock:Words(block)) do
        if NoteBlock:IsPlayerToken(word, ids) then
            return true
        end
    end
    return false
end

function Dirge:GetRequiemGroup()
    local NoteBlock = BossMods.NoteBlock
    local mainText = NoteBlock:GetMainNoteText()
    local block1 = NoteBlock:ExtractBlock(mainText, "requimg1")
    local block2 = NoteBlock:ExtractBlock(mainText, "requimg2")
    if not (block1 or block2) then
        return nil, false
    end

    local ids = NoteBlock:GetPlayerIdentifiers()
    local function inBlock(block)
        if not block then
            return false
        end
        for _, word in ipairs(NoteBlock:Words(block)) do
            if NoteBlock:IsPlayerToken(word, ids) then
                return true
            end
        end
        return false
    end

    if inBlock(block1) then
        return 1, true
    end
    if inBlock(block2) then
        return 2, true
    end
    return nil, true
end

-- BigWigs window scheduling

function Dirge:ScheduleDirgeListener(time, syncSetIndex)
    if type(time) ~= "number" or time <= 0 then
        return
    end

    if self.enableTimer then
        self.enableTimer:Cancel()
        self.enableTimer = nil
    end
    if self.disableTimer then
        self.disableTimer:Cancel()
        self.disableTimer = nil
    end

    local function enable()
        self.enableTimer = nil
        if not self.inEncounter then
            return
        end

        if self.inMythicPhase and syncSetIndex then
            local myGroup, hasBlocks = self:GetRequiemGroup()
            self.isMySetCached = not hasBlocks or myGroup ~= nil
            self.mythicSetIndex = syncSetIndex - 1
            self.totalFilled = 0
            self.filledRunes = {false, false, false, false, false}
            self.isFixing = false
            if self.hideTimer then
                self.hideTimer:Cancel()
                self.hideTimer = nil
            end
        end

        self:RegisterEvent("CHAT_MSG_RAID", "OnChatMsg")
        self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMsg")

        self.disableTimer = C_Timer.NewTimer(CHAT_LISTENER_WINDOW, function()
            self.disableTimer = nil
            if self.inEncounter then
                self:UnregisterEvent("CHAT_MSG_RAID")
                self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
            end
        end)
    end

    local leadTime = time - LEAD_TIME_OFFSET
    if leadTime > 0 then
        self.enableTimer = C_Timer.NewTimer(leadTime, enable)
    else
        enable()
    end
end

function Dirge:OnBigWigsStartBar(key, text, time)
    if not self.db.enabled then
        return
    end
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= MYTHIC_DIFFICULTY and not DEBUG_MODE then
        return
    end

    if BW_KEY_NON_MYTHIC[key] and not self.inMythicPhase then
        self:ScheduleDirgeListener(time)
        return
    end

    if key == BW_KEY_MYTHIC then
        if not self.inMythicPhase then
            self.inMythicPhase = true
        end
        local count = tonumber(type(text) == "string" and text:match("%((%d+)%)"))
        if not count then
            return
        end

        local myGroup = self:GetRequiemGroup()
        if myGroup and REQUIEM_GROUP_MAP[count] ~= myGroup then
            return
        end

        self:ScheduleDirgeListener(time, count)
    end
end

-- Encounter events

function Dirge:OnEncounterStart(_, encounterID)
    if encounterID ~= ENCOUNTER_ID and not DEBUG_MODE then
        return
    end
    local _, _, difficultyID = GetInstanceInfo()

    self.inEncounter = true
    self.inMythicPhase = false
    self.currentPhase = 1
    self.phaseSwapTime = GetTime()
    self.mythicSetIndex = 0
    self.totalFilled = 0
    self.filledRunes = {false, false, false, false, false}
    self.isFixing = false
    self.isMySetCached = true
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self:StopTTS()

    if difficultyID == MYTHIC_DIFFICULTY and not DEBUG_MODE then
        self:UnregisterEvent("CHAT_MSG_RAID")
        self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    else
        self:RegisterEvent("CHAT_MSG_RAID", "OnChatMsg")
        self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMsg")
    end

    if not DEBUG_MODE then
        self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", "OnTimelineEvent")
    end

    C_Timer.After(0, function()
        self:HideRuneDisplays()
    end)
end

function Dirge:OnTimelineEvent(_, info)
    if not info then
        return
    end
    if Enum and Enum.EncounterTimelineEventSource and info.source ~= Enum.EncounterTimelineEventSource.Encounter then
        return
    end

    local now = GetTime()
    if now < self.phaseSwapTime + PHASE_SWAP_DEBOUNCE then
        return
    end

    local _, _, difficultyID = GetInstanceInfo()
    local transitions = PHASE_TRANSITIONS[difficultyID]
    if not transitions then
        return
    end

    local expected = transitions[self.currentPhase]
    if not expected then
        return
    end
    if info.duration ~= expected.duration then
        return
    end
    if expected.next <= self.currentPhase then
        return
    end
    self.currentPhase = expected.next
    self.phaseSwapTime = now

    if difficultyID == MYTHIC_DIFFICULTY and self.currentPhase == 4 then
        if not self.inMythicPhase then
            self.inMythicPhase = true
            self.mythicSetIndex = 0
            self.isMySetCached = true
            self:UnregisterEvent("CHAT_MSG_RAID")
            self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
        end
        self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    elseif difficultyID ~= MYTHIC_DIFFICULTY and self.currentPhase == transitions[#transitions].next then
        self:HideAllRunes()
        self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    end
end

function Dirge:OnEncounterEnd()
    if DEBUG_MODE then
        return
    end
    self.inEncounter = false
    self.inMythicPhase = false
    self.mythicSetIndex = 0
    self.isMySetCached = true
    self:StopTTS()

    C_Timer.After(0, function()
        self:HideAllRunes()
    end)
end

-- Chat handler

function Dirge:OnChatMsg(event, msg)
    if not self.inEncounter then
        return
    end

    local maxForCounting, maxForBar, isMySet

    if self.inMythicPhase then
        local setIdx = self.mythicSetIndex + 1
        maxForCounting = MYTHIC_SET_SIZES[setIdx] or 4
        maxForBar = maxForCounting
        isMySet = self.isMySetCached
    elseif DEBUG_MODE then
        local setIdx = self.mythicSetIndex + 1
        maxForCounting = 5
        maxForBar = MYTHIC_SET_SIZES[setIdx] or 4
        if self.totalFilled == 0 then
            local myGroup, hasBlocks = self:GetRequiemGroup()
            self.isMySetCached = not hasBlocks or (myGroup ~= nil and REQUIEM_GROUP_MAP[setIdx] == myGroup)
        end
        isMySet = self.isMySetCached
    else
        maxForCounting = 5
        maxForBar = 0
        isMySet = false
    end

    if self.totalFilled >= maxForCounting then
        if not self.inMythicPhase then
            if event == "CHAT_MSG_RAID_LEADER" or DEBUG_MODE then
                self:WipeCurrentMarks(true)
            else
                return
            end
        else
            return
        end
    end

    local pos = 0
    if DEBUG_MODE or self.inMythicPhase then
        for i = 1, maxForCounting do
            if not self.filledRunes[i] then
                pos = i;
                break
            end
        end
    elseif self.isFixing and event == "CHAT_MSG_RAID_LEADER" then
        for i = 1, maxForCounting do
            if not self.filledRunes[i] then
                pos = i;
                break
            end
        end
    elseif event == "CHAT_MSG_RAID_LEADER" then
        if not self.filledRunes[1] then
            pos = 1
        elseif maxForCounting >= 4 and not self.filledRunes[4] then
            pos = 4
        else
            self:WipeCurrentMarks(false)
            return
        end
    else
        local allowed = {2, 3, 5}
        for _, p in ipairs(allowed) do
            if p <= maxForCounting and not self.filledRunes[p] then
                pos = p;
                break
            end
        end
        if pos == 0 then
            return
        end
    end

    if pos == 0 then
        return
    end

    self.filledRunes[pos] = true
    self.totalFilled = self.totalFilled + 1

    local isFirstMessage = (self.totalFilled == 1)
    local f = self.frames

    if isFirstMessage then
        if not self.inMythicPhase then
            self:StartTTSSequence()
        end

        if maxForBar > 0 then
            local startX = 102 - maxForBar * 18
            for i = 1, maxForBar do
                f.barDisplay[i]:ClearAllPoints()
                f.barDisplay[i]:SetPoint("LEFT", f.barFrame, "LEFT", startX + (i - 1) * 36, 6)
                f.barBaseline[i]:ClearAllPoints()
                f.barBaseline[i]:SetPoint("TOP", f.barDisplay[i], "BOTTOM", 0, 2)
                f.barBaseline[i]:SetText("|cFFFFFFFF" .. i .. "|r")
            end
        end

        if not self.inMythicPhase then
            for i = 1, 5 do
                f.squadBaseline[i]:SetText("|cFFFFFFFF" .. i .. "|r")
                f.squadBaseline[i]:Show()
            end
        end

        if self.hideTimer then
            self.hideTimer:Cancel()
        end

        local hideDuration = 15
        if self.inMythicPhase and not DEBUG_MODE then
            hideDuration = (maxForCounting == 4) and 16 or 12
        end

        self.hideTimer = C_Timer.NewTimer(hideDuration, function()
            self:HideAllRunes()
        end)
    end

    C_Timer.After(0, function()
        if not self.inMythicPhase then
            f.squadDisplay[pos]:SetFormattedText("|T%s:28:28|t", msg)
            f.squadDisplay[pos]:Show()
            f.squadBaseline[pos]:SetText("|cFF00FF00" .. pos .. "|r")
            f.squadFrame:Show()

            if DEBUG_MODE and isMySet and pos <= maxForBar then
                if isFirstMessage then
                    for i = 1, maxForBar do
                        f.barBaseline[i]:Show()
                    end
                end
                f.barDisplay[pos]:SetFormattedText("|T%s:24:24|t", msg)
                f.barDisplay[pos]:Show()
                f.barBaseline[pos]:SetText("|cFF00FF00" .. pos .. "|r")
                f.barBaseline[pos]:Show()
                f.barFrame:Show()
            end
        else
            if isMySet then
                if isFirstMessage then
                    for i = 1, maxForBar do
                        f.barBaseline[i]:Show()
                    end
                end
                f.barDisplay[pos]:SetFormattedText("|T%s:24:24|t", msg)
                f.barDisplay[pos]:Show()
                f.barBaseline[pos]:SetText("|cFF00FF00" .. pos .. "|r")
                f.barBaseline[pos]:Show()
                f.barFrame:Show()
            end
        end
    end)
end

-- Authorization + UpdateState

function Dirge:UpdateAuthorization()
    if not self:IsEnabled() then
        return
    end
    local auth = self:CheckNoteAuthorization()
    if self.isAuthorized ~= auth then
        self.isAuthorized = auth
        self:UpdateState()
    end
end

function Dirge:OnNoteChanged(_, slot)
    local mainSlot = E:CallModule("Notes", "GetMainNoteSlot") or 1
    if slot ~= mainSlot then
        return
    end
    if self.noteParseTimer then
        return
    end
    self.noteParseTimer = self:ScheduleTimer(function()
        self.noteParseTimer = nil
        self:UpdateAuthorization()
    end, 1)
end

function Dirge:HookBigWigs()
    if self.bwHandle then
        return
    end
    self.bwHandle = BossMods.BigWigs:Subscribe({
        owner = "Dirge",
        spellKeys = {1249620, 1284980, 1273158},
        onStartBar = function(key, text, time)
            self:OnBigWigsStartBar(key, text, time)
        end
    })
end

function Dirge:UnhookBigWigs()
    if not self.bwHandle then
        return
    end
    self.bwHandle:Unsubscribe()
    self.bwHandle = nil
end

function Dirge:UpdateState()
    if not self:IsEnabled() then
        return
    end
    if not self.frames then
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
            return
        end
        if not self:EnsureFrames() then
            return
        end
        self:ApplySettings()
        self:UpdateKeybindLabels()
    end

    self:UnregisterEvent("CHAT_MSG_RAID")
    self:UnregisterEvent("CHAT_MSG_RAID_LEADER")
    self:UnregisterEvent("ENCOUNTER_START")
    self:UnregisterEvent("ENCOUNTER_END")
    self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    self:UnhookBigWigs()

    if self.enableTimer then
        self.enableTimer:Cancel()
        self.enableTimer = nil
    end
    if self.disableTimer then
        self.disableTimer:Cancel()
        self.disableTimer = nil
    end
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end

    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local inCorrectInstance = (mapID == INSTANCE_ID) or DEBUG_MODE

    if inCorrectInstance then
        self:RegisterEvent("CHAT_MSG_RAID", "OnChatMsg")
        self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChatMsg")
        self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
        self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
        self:HookBigWigs()
        self.isAuthorized = self:CheckNoteAuthorization()

        if DEBUG_MODE then
            self.inEncounter = true
            self.isMySetCached = true
            self.totalFilled = 0
            self.filledRunes = {false, false, false, false, false}
        end
    else
        self.inEncounter = false
        self:StopTTS()
    end

    self:ApplyVisibility()
end

function Dirge:ApplyVisibility()
    if not self.frames or not self:IsEnabled() then
        return
    end
    local f = self.frames

    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local inCorrectInstance = (mapID == INSTANCE_ID) or DEBUG_MODE
    local editVisible = self.editVisible or {}
    local squadActive = inCorrectInstance or editVisible.squad
    local barActive = inCorrectInstance or editVisible.bar
    local buttonsActive = editVisible.buttons or (inCorrectInstance and self.isAuthorized)

    if squadActive then
        f.squadAnchor:Show()
    else
        f.squadAnchor:Hide()
    end
    if barActive then
        f.seqBarAnchor:Show()
    else
        f.seqBarAnchor:Hide()
    end
    if not squadActive and not barActive then
        self:HideRuneDisplays()
    end

    if InCombatLockdown() then
        if (buttonsActive and not f.barAnchor:IsShown()) or (not buttonsActive and f.barAnchor:IsShown()) then
            self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
        end
        return
    end

    if buttonsActive then
        f.barAnchor:Show()
    else
        f.barAnchor:Hide()
    end
end

function Dirge:OnRegenEnabled()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UpdateState()
end

function Dirge:OnZoneOrLogin()
    self:UpdateState()
end

-- Edit

function Dirge:SetEditMode(v, visibleKeys)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false
    if visibleKeys == nil and self.editMode then
        visibleKeys = {
            buttons = true,
            squad = true,
            bar = true
        }
    end
    self.editVisible = (self.editMode and visibleKeys) or {}
    if not self.frames then
        return
    end
    local f = self.frames

    if self.editVisible.squad then
        f.squadFrame:Show()
        for i = 1, 5 do
            f.squadDisplay[i]:SetFormattedText("|T%s:28:28|t", CHAT_MSGS[SHAPE_NAMES[i]])
            f.squadDisplay[i]:Show()
            f.squadBaseline[i]:SetText("|cFF00FF00" .. i .. "|r")
            f.squadBaseline[i]:Show()
        end
    elseif self.inEncounter and self.totalFilled > 0 then
        for i = 1, 5 do
            if not self.filledRunes[i] then
                f.squadDisplay[i]:Hide()
                f.squadBaseline[i]:SetText("|cFFFFFFFF" .. i .. "|r")
                f.squadBaseline[i]:Show()
            end
        end
    else
        f.squadFrame:Hide()
        for i = 1, 5 do
            f.squadDisplay[i]:Hide()
            f.squadBaseline[i]:Hide()
        end
    end

    if self.editVisible.bar then
        f.barFrame:Show()
        local startX = 102 - MAX_BAR_DISPLAY * 18
        for i = 1, MAX_BAR_DISPLAY do
            f.barDisplay[i]:ClearAllPoints()
            f.barDisplay[i]:SetPoint("LEFT", f.barFrame, "LEFT", startX + (i - 1) * 36, 6)
            f.barDisplay[i]:SetFormattedText("|T%s:24:24|t", CHAT_MSGS[SHAPE_NAMES[i]])
            f.barDisplay[i]:Show()
            f.barBaseline[i]:ClearAllPoints()
            f.barBaseline[i]:SetPoint("TOP", f.barDisplay[i], "BOTTOM", 0, 2)
            f.barBaseline[i]:SetText("|cFF00FF00" .. i .. "|r")
            f.barBaseline[i]:Show()
        end
    elseif self.inEncounter and self.totalFilled > 0 then
        for i = 1, 5 do
            if not self.filledRunes[i] then
                f.barDisplay[i]:Hide()
                f.barBaseline[i]:Hide()
            end
        end
    else
        f.barFrame:Hide()
        for i = 1, 5 do
            f.barDisplay[i]:Hide()
            f.barBaseline[i]:Hide()
        end
    end

    if not InCombatLockdown() then
        f.barAnchor:SetAlpha(self.editVisible.buttons and 1 or (self.db.buttons.opacity or 1))
    end

    self:ApplyVisibility()
    self:ApplyClickthrough()
end

function Dirge:SavePosition(anchorKey, pos)
    if not self.db[anchorKey] then
        return
    end
    local p = self.db[anchorKey].position
    p.point = pos.point
    p.x = pos.x
    p.y = pos.y
    self:ApplySettings()
end

function Dirge:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplySettings()
    self:UpdateKeybindLabels()
end

-- Lifecycle

function Dirge:OnModuleInitialize()
    BossMods = E:GetModule("BossMods")
    self.inEncounter = false
    self.inMythicPhase = false
    self.currentPhase = 1
    self.phaseSwapTime = 0
    self.mythicSetIndex = 0
    self.totalFilled = 0
    self.filledRunes = {false, false, false, false, false}
    self.isFixing = false
    self.isMySetCached = true
    self.isAuthorized = false
    self.editMode = false
    self.editVisible = {}

    if not InCombatLockdown() then
        self:EnsureFrames()
        if self.frames then
            self:ApplySettings()
            self:UpdateKeybindLabels()
            self.frames.barAnchor:Hide()
            self.frames.squadAnchor:Hide()
            self.frames.seqBarAnchor:Hide()
        end
    end
end

function Dirge:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")

    if not self.frames then
        self:EnsureFrames()
    end
    if self.frames then
        self:ApplySettings()
        self:UpdateKeybindLabels()
    end

    self:RegisterEvent("UPDATE_BINDINGS", "UpdateKeybindLabels")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneOrLogin")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneOrLogin")
    self:RegisterMessage("ART_NOTE_CHANGED", "OnNoteChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    self:UpdateState()
end

function Dirge:OnDisable()
    self:UnhookBigWigs()
    self:StopTTS()
    self.inEncounter = false
    self.editMode = false
    self.editVisible = {}

    if not self.frames then
        return
    end
    local f = self.frames
    f.squadAnchor:Hide()
    f.seqBarAnchor:Hide()
    self:HideRuneDisplays()

    if not InCombatLockdown() then
        f.barAnchor:Hide()
        return
    end

    local mod = self
    local waiter = CreateFrame("Frame")
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    waiter:SetScript("OnEvent", function(w)
        w:UnregisterAllEvents()
        w:SetScript("OnEvent", nil)
        if not mod:IsEnabled() and mod.frames then
            mod.frames.barAnchor:Hide()
        end
    end)
end

-- Feature registration

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("Dirge", {
            tab = "Queldanas",
            order = 50,
            labelKey = "BossMods_Dirge",
            descKey = "BossMods_DirgeDesc",
            moduleName = "BossMods_Dirge"
        })
    end
    local NoteBlock = parent and parent.NoteBlock or nil
    if NoteBlock and NoteBlock.RegisterNoteBlock then
        NoteBlock:RegisterNoteBlock("Dirge", {
            blocks = {{
                tag = "dirge",
                template = "dirgeStart\nPlayer1 Player2 Player3\ndirgeEnd"
            }, {
                tag = "requimg1",
                template = "requimg1Start\nPlayer1 Player2 Player3\nrequimg1End"
            }, {
                tag = "requimg2",
                template = "requimg2Start\nPlayer1 Player2 Player3\nrequimg2End"
            }},
            moduleName = "BossMods_Dirge",
            tab = "Queldanas",
            order = 50,
            labelKey = "BossMods_Dirge"
        })
    end
end
