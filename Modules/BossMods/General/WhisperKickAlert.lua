local E = unpack(ART)

E:RegisterModuleDefaults("BossMods_WhisperKickAlert", {
    enabled = false,
    trigger = {
        encounterID = 3421,
        spellID = 1308356,
        secondsBefore = 2,
        windowDuration = 17
    },
    duration = 3,
    position = {
        point = "CENTER",
        x = 0,
        y = 200
    },
    size = {
        w = 500,
        h = 90
    },
    font = {
        name = "Friz Quadrata TT",
        size = 34,
        outline = "THICKOUTLINE",
        color = {1, 1, 1, 1}
    },
    audio = {
        enabled = false,
        mode = "tts",
        ttsText = "Your kick next",
        voiceID = 0,
        sound = "None",
        channel = "Master"
    }
})

local Mod = E:NewModule("BossMods_WhisperKickAlert", "AceEvent-3.0")

local ALERT_TEXT = "Your kick Next"

local ENCOUNTER_VALUES = {
    [3176] = "The Voidspire - Imperator Averzian",
    [3177] = "The Voidspire - Vorasius",
    [3179] = "The Voidspire - Fallen-King Salhadaar",
    [3178] = "The Voidspire - Vaelgor & Ezzorak",
    [3180] = "The Voidspire - Lightblinded Vanguard",
    [3181] = "The Voidspire - Crown of the Cosmos",
    [3306] = "The Dreamrift - Chimaerus the Undreamt God",
    [3182] = "March on Quel'Danas - Belo'ren, Child of Al'ar",
    [3183] = "March on Quel'Danas - Midnight Falls",
    [3470] = "The Venomous Abyss - Nek'zali the Soulcoiler",
    [3445] = "The Venomous Abyss - Entombed Sentinels",
    [3497] = "The Venomous Abyss - The Lost Explorers",
    [3455] = "The Venomous Abyss - Vashnik the Malignant",
    [3420] = "The Venomous Abyss - Sszorak",
    [3421] = "The Venomous Abyss - The Twin Fangs",
    [3429] = "The Venomous Abyss - The Coiled Alter",
    [3492] = "The Venomous Abyss - Ula'tek"
}

local ENCOUNTER_SORTING = {
    3176,
    3177,
    3179,
    3178,
    3180,
    3181,
    3306,
    3182,
    3183,
    3470,
    3445,
    3497,
    3455,
    3420,
    3421,
    3429,
    3492
}

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

local function buildAlertConfig(self)
    return {
        parent = UIParent,
        strata = "HIGH",
        size = {
            w = self.db.size.w,
            h = self.db.size.h
        },
        font = {
            name = self.db.font.name,
            size = self.db.font.size,
            outline = self.db.font.outline,
            color = self.db.font.color
        }
    }
end

function Mod:GetEncounterValues()
    return ENCOUNTER_VALUES
end

function Mod:GetEncounterSorting()
    return ENCOUNTER_SORTING
end

function Mod:EnsureDefaults()
    self.db.trigger = self.db.trigger or {}
    self.db.trigger.encounterID =
        tonumber(self.db.trigger.encounterID) or 3421
    self.db.trigger.spellID =
        math.max(
            0,
            math.floor(tonumber(self.db.trigger.spellID) or 1308356)
        )
    self.db.trigger.secondsBefore =
        clamp(self.db.trigger.secondsBefore, 0, 60, 2)
    self.db.trigger.windowDuration =
        clamp(self.db.trigger.windowDuration, 0.1, 60, 17)

    self.db.size = self.db.size or {w = 500, h = 90}
    self.db.font = self.db.font or {}
    self.db.font.name = self.db.font.name or "Friz Quadrata TT"
    self.db.font.size = clamp(self.db.font.size, 8, 72, 34)
    self.db.font.outline = self.db.font.outline or "THICKOUTLINE"
    self.db.font.color = self.db.font.color or {1, 1, 1, 1}

    self.db.audio = self.db.audio or {}
    self.db.audio.mode =
        self.db.audio.mode == "sound" and "sound" or "tts"
    self.db.audio.ttsText =
        self.db.audio.ttsText or "Your kick next"
    self.db.audio.voiceID = tonumber(self.db.audio.voiceID) or 0
    self.db.audio.sound = self.db.audio.sound or "None"
    self.db.audio.channel = self.db.audio.channel or "Master"

    self.db.duration = clamp(self.db.duration, 1, 5, 3)
end

function Mod:EnsureAlert()
    if self.alert then
        return
    end

    local BossMods = E:GetModule("BossMods")
    self.alert = BossMods.Engines.TextAlert(buildAlertConfig(self))
    self.frame = self.alert.frame
    self.alert:SetText(ALERT_TEXT)
    self.alert:Hide()
end

function Mod:ApplyPosition()
    if self.alert then
        E:ApplyFramePosition(self.alert.frame, self.db.position)
    end
end

function Mod:ApplyAppearance()
    self:EnsureDefaults()
    self:EnsureAlert()
    self.alert:Apply(buildAlertConfig(self))
    self.alert:SetText(ALERT_TEXT)
end

function Mod:CancelListeningWindow()
    self.windowGeneration = (self.windowGeneration or 0) + 1
    self.windowActive = false
    self.activeWindowCount = 0

    if self.windowTimers then
        for i = 1, #self.windowTimers do
            local timer = self.windowTimers[i]
            if timer and timer.Cancel then
                timer:Cancel()
            end
        end
    end
    self.windowTimers = {}
end

function Mod:TrackWindowTimer(timer)
    self.windowTimers = self.windowTimers or {}
    self.windowTimers[#self.windowTimers + 1] = timer
    return timer
end

function Mod:OpenListeningWindow(generation, window)
    if not self:IsEnabled()
        or self.windowGeneration ~= generation
        or window.active
    then
        return
    end

    window.active = true
    self.activeWindowCount = (self.activeWindowCount or 0) + 1
    self.windowActive = true

    local windowDuration =
        clamp(self.db.trigger.windowDuration, 0.1, 60, 17)

    self:TrackWindowTimer(C_Timer.NewTimer(
        windowDuration,
        function()
            if self.windowGeneration ~= generation or not window.active then
                return
            end
            window.active = false
            self.activeWindowCount = math.max(
                0,
                (self.activeWindowCount or 1) - 1
            )
            self.windowActive = self.activeWindowCount > 0
        end
    ))
end

function Mod:ScheduleListeningWindow(timeRemaining)
    timeRemaining = tonumber(timeRemaining)
    if not timeRemaining or timeRemaining < 0 then
        return
    end

    local generation = self.windowGeneration
    local secondsBefore =
        clamp(self.db.trigger.secondsBefore, 0, 60, 2)
    local delay = math.max(0, timeRemaining - secondsBefore)
    local window = {active = false}

    if delay <= 0 then
        self:OpenListeningWindow(generation, window)
    else
        self:TrackWindowTimer(C_Timer.NewTimer(
            delay,
            function()
                self:OpenListeningWindow(generation, window)
            end
        ))
    end
end

function Mod:HookBigWigs()
    if self.bwHandle then
        self.bwHandle:Unsubscribe()
        self.bwHandle = nil
    end

    local spellID = math.max(
        0,
        math.floor(tonumber(self.db.trigger.spellID) or 0)
    )
    if spellID <= 0 then
        return
    end

    local BossMods = E:GetModule("BossMods")
    self.bwHandle = BossMods.BigWigs:Subscribe({
        owner = "WhisperKickAlert",
        spellKeys = {spellID},
        onTimer = function(_, _, time)
            self:OnBigWigsStartBar(time)
        end
    })
end

function Mod:UnhookBigWigs()
    if self.bwHandle then
        self.bwHandle:Unsubscribe()
        self.bwHandle = nil
    end
end

function Mod:OnBigWigsStartBar(time)
    local selectedEncounterID =
        tonumber(self.db.trigger.encounterID)

    if not self.currentEncounterID
        or self.currentEncounterID ~= selectedEncounterID
    then
        return
    end

    self:ScheduleListeningWindow(time)
end

function Mod:OnEncounterStart(_, encounterID)
    self.currentEncounterID = tonumber(encounterID)
    self:CancelListeningWindow()
end

function Mod:OnEncounterEnd(_, encounterID)
    encounterID = tonumber(encounterID)
    if not encounterID or encounterID == self.currentEncounterID then
        self.currentEncounterID = nil
        self:CancelListeningWindow()
    end
end

function Mod:PlayConfiguredAudio()
    local audio = self.db.audio
    if not audio or not audio.enabled then
        return
    end

    local BossMods = E:GetModule("BossMods")
    if audio.mode == "sound" then
        BossMods.Alerts:PlaySound({
            name = audio.sound,
            channel = audio.channel or "Master"
        })
    else
        BossMods.Alerts:SpeakTTS({
            text = audio.ttsText or "Your kick next",
            voiceID = audio.voiceID or 0
        })
    end
end

function Mod:ShowTriggeredAlert(playAudio)
    self:EnsureAlert()
    self.alertGeneration = (self.alertGeneration or 0) + 1
    local generation = self.alertGeneration

    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end

    self.alert:SetText(ALERT_TEXT)
    self.alert:Show()

    if playAudio then
        self:PlayConfiguredAudio()
    end

    local duration = clamp(self.db.duration, 1, 5, 3)
    self.hideTimer = C_Timer.NewTimer(duration, function()
        if self.alertGeneration ~= generation or self.editMode then
            return
        end
        self.hideTimer = nil
        self.alert:Hide()
    end)
end

function Mod:OnWhisper()
    if self.windowActive then
        self:ShowTriggeredAlert(true)
    end
end

function Mod:OnInitialize()
    self.editMode = false
    self.alertGeneration = 0
    self.windowGeneration = 0
    self.windowActive = false
    self.activeWindowCount = 0
    self.windowTimers = {}
    self:EnsureDefaults()
    self:EnsureAlert()
    self:ApplyAppearance()
    self:ApplyPosition()
end

function Mod:OnEnable()
    self:EnsureDefaults()
    self:EnsureAlert()
    self:ApplyAppearance()
    self:ApplyPosition()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:HookBigWigs()
end

function Mod:OnDisable()
    self:CancelListeningWindow()
    self:UnhookBigWigs()
    self.alertGeneration = (self.alertGeneration or 0) + 1

    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    if self.alert then
        self.alert:Hide()
    end

    self.currentEncounterID = nil
    self.editMode = false
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

function Mod:Refresh()
    if not self:IsEnabled() then
        return
    end

    self:EnsureDefaults()
    self:CancelListeningWindow()
    self:HookBigWigs()
    self:ApplyAppearance()
    self:ApplyPosition()

    if self.editMode then
        self.alert:SetText(ALERT_TEXT)
        self.alert:Show()
    end
end

function Mod:SetEditMode(value)
    if not self:IsEnabled() then
        return
    end

    self.editMode = value and true or false
    self.alertGeneration = (self.alertGeneration or 0) + 1

    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end

    if self.editMode then
        self:ApplyAppearance()
        self:ApplyPosition()
        self.alert:SetText(ALERT_TEXT)
        self.alert:Show()
    else
        self.alert:Hide()
    end
end

function Mod:SavePosition(position)
    self.db.position.point = position.point or "CENTER"
    self.db.position.x = tonumber(position.x) or 0
    self.db.position.y = tonumber(position.y) or 0
    self:ApplyPosition()
end

E:RegisterBossModFeature("WhisperKickAlert", {
    tab = "General",
    order = 40,
    labelKey = "BossMods_WhisperKickAlert",
    descKey = "BossMods_WhisperKickAlertDesc",
    moduleName = "BossMods_WhisperKickAlert"
})

