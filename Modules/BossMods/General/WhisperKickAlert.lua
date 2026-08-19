local E = unpack(ART)

local MODULE_NAME = "BossMods_WhisperKickAlert"
local SHARE_TYPE = "kickAlertSetup"
local SHARE_VERSION = "ART_KA1"
local ALERT_TEXT = "Your kick Next"

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = false,
    selectedSetup = nil,
    setups = {},
    trigger = {
        encounterID = 3421,
        spellID = 1308356,
        secondsBefore = 2,
        windowDuration = 17
    },
    duration = 3,
    position = {point = "CENTER", x = 0, y = 200},
    size = {w = 500, h = 90},
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

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local ENCOUNTER_VALUES = {
    [3379] = "Nymrissa Wavecaller",
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
    3379, 3176, 3177, 3179, 3178, 3180, 3181, 3306, 3182, 3183,
    3470, 3445, 3497, 3455, 3420, 3421, 3429, 3492
}

local DIFFICULTY_VALUES = {
    any = "Any Difficulty",
    normal = "Normal",
    heroic = "Heroic",
    mythic = "Mythic"
}

local DIFFICULTY_SORTING = {"any", "normal", "heroic", "mythic"}

local function difficultyKey(difficultyID)
    difficultyID = tonumber(difficultyID)
    if difficultyID == 14 then
        return "normal"
    elseif difficultyID == 15 then
        return "heroic"
    elseif difficultyID == 16 or difficultyID == 233 then
        return "mythic"
    end
end

local function copyTable(source)
    if type(source) ~= "table" then
        return nil
    end
    if CopyTable then
        return CopyTable(source)
    end
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

local function safeText(value, fallback)
    value = strtrim(E:SafeString(value) or "")
    return value ~= "" and value or fallback
end

local function normalizeColor(value)
    value = type(value) == "table" and value or {1, 1, 1, 1}
    return {
        clamp(value[1] or value.r, 0, 1, 1),
        clamp(value[2] or value.g, 0, 1, 1),
        clamp(value[3] or value.b, 0, 1, 1),
        clamp(value[4] or value.a, 0, 1, 1)
    }
end

local function newID()
    local stamp = GetServerTime and GetServerTime() or time()
    return ("%s-%06d"):format(tostring(stamp), math.random(0, 999999))
end

local function normalizeSetup(source, freshID)
    source = type(source) == "table" and copyTable(source) or {}
    local trigger = type(source.trigger) == "table" and source.trigger or {}
    local position = type(source.position) == "table" and source.position or {}
    local size = type(source.size) == "table" and source.size or {}
    local font = type(source.font) == "table" and source.font or {}
    local audio = type(source.audio) == "table" and source.audio or {}
    local difficulty = DIFFICULTY_VALUES[trigger.difficulty] and trigger.difficulty or "any"

    return {
        id = freshID and newID() or safeText(source.id, newID()),
        name = safeText(source.name, "Kick Alert"),
        enabled = source.enabled ~= false,
        trigger = {
            encounterID = math.max(0, math.floor(tonumber(trigger.encounterID) or 3421)),
            difficulty = difficulty,
            spellID = math.max(0, math.floor(tonumber(trigger.spellID) or 1308356)),
            secondsBefore = clamp(trigger.secondsBefore, 0, 60, 2),
            windowDuration = clamp(trigger.windowDuration, 0.1, 60, 17)
        },
        duration = clamp(source.duration, 1, 5, 3),
        position = {
            point = position.point or "CENTER",
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 200
        },
        size = {
            w = clamp(size.w, 100, 1200, 500),
            h = clamp(size.h, 30, 300, 90)
        },
        font = {
            name = safeText(font.name, "Friz Quadrata TT"),
            size = clamp(font.size, 8, 72, 34),
            outline = font.outline or "THICKOUTLINE",
            color = normalizeColor(font.color)
        },
        audio = {
            enabled = audio.enabled == true,
            mode = audio.mode == "sound" and "sound" or "tts",
            ttsText = safeText(audio.ttsText, "Your kick next"),
            voiceID = math.max(0, math.floor(tonumber(audio.voiceID) or 0)),
            sound = safeText(audio.sound, "None"),
            channel = safeText(audio.channel, "Master")
        }
    }
end

local function exportSetup(setup)
    local result = normalizeSetup(setup)
    result.id = nil
    return result
end

local function uniqueName(name, setups)
    local used = {}
    for _, setup in ipairs(setups) do
        used[setup.name] = true
    end
    if not used[name] then
        return name
    end
    local index = 2
    local candidate = name .. " Copy"
    while used[candidate] do
        candidate = name .. " Copy " .. index
        index = index + 1
    end
    return candidate
end

function Mod:GetEncounterValues() return ENCOUNTER_VALUES end
function Mod:GetEncounterSorting() return ENCOUNTER_SORTING end
function Mod:GetDifficultyValues() return DIFFICULTY_VALUES end
function Mod:GetDifficultySorting() return DIFFICULTY_SORTING end

function Mod:EnsureSetups()
    self.db.setups = type(self.db.setups) == "table" and self.db.setups or {}

    if #self.db.setups == 0 then
        self.db.setups[1] = normalizeSetup({
            name = "Kick Alert 1",
            enabled = true,
            trigger = self.db.trigger,
            duration = self.db.duration,
            position = self.db.position,
            size = self.db.size,
            font = self.db.font,
            audio = self.db.audio
        }, true)
        self.db.selectedSetup = 1
        self.db.setupDataVersion = 2
    elseif self.db.setupDataVersion ~= 2 then
        for index, setup in ipairs(self.db.setups) do
            self.db.setups[index] = normalizeSetup(setup)
        end
        self.db.setupDataVersion = 2
    end

    if not self.db.setups[tonumber(self.db.selectedSetup)] then
        self.db.selectedSetup = #self.db.setups > 0 and 1 or nil
    end
    return self.db.setups
end

function Mod:GetSetups()
    return self:EnsureSetups()
end

function Mod:GetSetup(index)
    return self:GetSetups()[math.floor(tonumber(index) or 0)]
end

function Mod:GetSelectedSetup()
    return self:GetSetup(self.db.selectedSetup)
end

function Mod:AddSetup(template)
    local setups = self:GetSetups()
    local setup = normalizeSetup(template or {}, true)
    if not template then
        setup.name = "Kick Alert " .. (#setups + 1)
    end
    setup.name = uniqueName(setup.name, setups)
    setups[#setups + 1] = setup
    self.db.selectedSetup = #setups
    self:Refresh()
    return #setups
end

function Mod:DuplicateSetup(index)
    local setup = self:GetSetup(index or self.db.selectedSetup)
    return setup and self:AddSetup(exportSetup(setup)) or nil
end

function Mod:DeleteSetup(index)
    local setups = self:GetSetups()
    index = math.floor(tonumber(index or self.db.selectedSetup) or 0)
    local setup = setups[index]
    if not setup then
        return false
    end
    self:CancelWindow(setup.id)
    self:HideSetup(setup.id)
    local alert = self.alerts and self.alerts[setup.id]
    if alert then
        alert.frame:SetParent(nil)
        self.alerts[setup.id] = nil
    end
    table.remove(setups, index)
    self.db.selectedSetup = #setups > 0 and math.min(index, #setups) or nil
    self:Refresh()
    return true
end

function Mod:ImportSetupData(data)
    local setups = self:GetSetups()
    local setup = normalizeSetup(data, true)
    setup.name = uniqueName(setup.name, setups)
    setups[#setups + 1] = setup
    self.db.selectedSetup = #setups
    self:Refresh()
    return #setups
end

function Mod:ExportSetupString(index)
    local setup = self:GetSetup(index or self.db.selectedSetup)
    return setup and E:EncodeShareString(SHARE_TYPE, exportSetup(setup)) or ""
end

function Mod:ImportSetupString(text)
    local data, err = E:DecodeShareString(SHARE_TYPE, text)
    if not data then
        return nil, err or "Invalid Kick Alert setup string"
    end
    return self:ImportSetupData(data)
end

function Mod:ShareSetupToChat(index)
    local setup = self:GetSetup(index or self.db.selectedSetup)
    if not setup then
        return false, "No Kick Alert setup selected"
    end
    return E:ShareDataToChat(
        SHARE_TYPE,
        exportSetup(setup),
        ("ART Kick Alert: %s"):format(setup.name)
    )
end

local function alertConfig(setup)
    return {
        parent = UIParent,
        strata = "HIGH",
        size = {w = setup.size.w, h = setup.size.h},
        font = {
            name = setup.font.name,
            size = setup.font.size,
            outline = setup.font.outline,
            color = setup.font.color
        }
    }
end

function Mod:EnsureAlert(setup)
    self.alerts = self.alerts or {}
    local alert = self.alerts[setup.id]
    if not alert then
        alert = E:GetModule("BossMods").Engines.TextAlert(alertConfig(setup))
        alert:SetText(ALERT_TEXT)
        alert:Hide()
        self.alerts[setup.id] = alert
    else
        alert:Apply(alertConfig(setup))
    end
    E:ApplyFramePosition(alert.frame, setup.position)
    return alert
end

function Mod:GetSelectedFrame()
    local setup = self:GetSelectedSetup()
    return setup and self:EnsureAlert(setup).frame or nil
end

function Mod:CancelWindow(id)
    self.windows = self.windows or {}
    local state = self.windows[id]
    if not state then
        return
    end
    state.generation = (state.generation or 0) + 1
    state.active = false
    if state.openTimer then state.openTimer:Cancel(); state.openTimer = nil end
    if state.closeTimer then state.closeTimer:Cancel(); state.closeTimer = nil end
end

function Mod:OpenWindow(setup, generation)
    local state = self.windows[setup.id]
    if not state or state.generation ~= generation or not setup.enabled then
        return
    end
    state.openTimer = nil
    state.active = true
    state.closeTimer = C_Timer.NewTimer(setup.trigger.windowDuration, function()
        if state.generation == generation then
            state.active = false
            state.closeTimer = nil
        end
    end)
end

function Mod:ScheduleWindow(setup, timeRemaining)
    self.windows = self.windows or {}
    self:CancelWindow(setup.id)
    local state = self.windows[setup.id] or {generation = 0}
    self.windows[setup.id] = state
    state.generation = (state.generation or 0) + 1
    local generation = state.generation
    local delay = math.max(0, (tonumber(timeRemaining) or 0) - setup.trigger.secondsBefore)
    if delay <= 0 then
        self:OpenWindow(setup, generation)
    else
        state.openTimer = C_Timer.NewTimer(delay, function()
            self:OpenWindow(setup, generation)
        end)
    end
end

function Mod:PlayAudio(setup)
    if not setup.audio.enabled then
        return
    end
    local alerts = E:GetModule("BossMods").Alerts
    if setup.audio.mode == "sound" then
        alerts:PlaySound({name = setup.audio.sound, channel = setup.audio.channel})
    else
        alerts:SpeakTTS({text = setup.audio.ttsText, voiceID = setup.audio.voiceID})
    end
end

function Mod:HideSetup(id)
    self.hideTimers = self.hideTimers or {}
    local timer = self.hideTimers[id]
    if timer then
        timer:Cancel()
        self.hideTimers[id] = nil
    end
    local alert = self.alerts and self.alerts[id]
    if alert then
        alert:Hide()
    end
end

function Mod:ShowSetup(setup, playAudio)
    local alert = self:EnsureAlert(setup)
    self:HideSetup(setup.id)
    alert:SetText(ALERT_TEXT)
    alert:Show()
    if playAudio then
        self:PlayAudio(setup)
    end
    self.hideTimers = self.hideTimers or {}
    self.hideTimers[setup.id] = C_Timer.NewTimer(setup.duration, function()
        self.hideTimers[setup.id] = nil
        if not self.editMode or self:GetSelectedSetup() ~= setup then
            alert:Hide()
        end
    end)
end

function Mod:ShowTriggeredAlert(playAudio)
    local setup = self:GetSelectedSetup()
    if setup then
        self:ShowSetup(setup, playAudio)
    end
end

function Mod:OnWhisper()
    for _, setup in ipairs(self:GetSetups()) do
        local state = self.windows and self.windows[setup.id]
        if setup.enabled and state and state.active then
            self:ShowSetup(setup, true)
        end
    end
end

function Mod:OnBigWigsStartBar(spellKey, _, time)
    spellKey = tonumber(spellKey)
    for _, setup in ipairs(self:GetSetups()) do
        if setup.enabled
            and setup.trigger.encounterID == self.currentEncounterID
            and (setup.trigger.difficulty == "any" or setup.trigger.difficulty == self.currentDifficulty)
            and setup.trigger.spellID == spellKey
        then
            self:ScheduleWindow(setup, time)
        end
    end
end

function Mod:RebuildSubscription()
    if self.bwHandle then
        self.bwHandle:Unsubscribe()
        self.bwHandle = nil
    end
    local keys, seen = {}, {}
    for _, setup in ipairs(self:GetSetups()) do
        local spellID = setup.enabled and setup.trigger.spellID or 0
        if spellID > 0 and not seen[spellID] then
            seen[spellID] = true
            keys[#keys + 1] = spellID
        end
    end
    if #keys > 0 then
        self.bwHandle = E:GetModule("BossMods").BigWigs:Subscribe({
            owner = MODULE_NAME,
            spellKeys = keys,
            onStartBar = function(...)
                self:OnBigWigsStartBar(...)
            end
        })
    end
end

function Mod:OnEncounterStart(_, encounterID, _, difficultyID)
    self.currentEncounterID = tonumber(encounterID)
    self.currentDifficulty = difficultyKey(difficultyID)
    for _, setup in ipairs(self:GetSetups()) do
        self:CancelWindow(setup.id)
    end
end

function Mod:OnEncounterEnd()
    self.currentEncounterID = nil
    self.currentDifficulty = nil
    for _, setup in ipairs(self:GetSetups()) do
        self:CancelWindow(setup.id)
        self:HideSetup(setup.id)
    end
end

function Mod:Refresh()
    self:EnsureSetups()
    self:RebuildSubscription()
    local selected = self:GetSelectedSetup()
    for _, setup in ipairs(self:GetSetups()) do
        local alert = self:EnsureAlert(setup)
        if self.editMode and setup == selected then
            alert:SetText(ALERT_TEXT)
            alert:Show()
        elseif not (self.hideTimers and self.hideTimers[setup.id]) then
            alert:Hide()
        end
    end
end

function Mod:SetEditMode(value)
    self.editMode = value and true or false
    self:Refresh()
end

function Mod:SavePosition(position)
    local setup = self:GetSelectedSetup()
    if not setup then
        return
    end
    setup.position.point = position.point or "CENTER"
    setup.position.x = tonumber(position.x) or 0
    setup.position.y = tonumber(position.y) or 200
    self:Refresh()
end

function Mod:OnInitialize()
    self.alerts = {}
    self.windows = {}
    self.hideTimers = {}
    self.editMode = false
    self:EnsureSetups()
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = "Kick Alert Setup",
        sanitize = normalizeSetup,
        getImportName = function(data)
            return data and data.name or "Kick Alert"
        end,
        confirmTitle = "Import Kick Alert Setup",
        confirmText = function(data, sender)
            local name = data and data.name or "Kick Alert"
            return ("Import '%s'%s?"):format(
                name,
                sender and sender ~= "" and (" from " .. sender) or ""
            )
        end,
        onImport = function(data)
            self:ImportSetupData(data)
            E:Printf("Imported Kick Alert setup: %s", data.name or "Kick Alert")
        end
    })
end

function Mod:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:Refresh()
end

function Mod:OnDisable()
    if self.bwHandle then
        self.bwHandle:Unsubscribe()
        self.bwHandle = nil
    end
    for _, setup in ipairs(self:GetSetups()) do
        self:CancelWindow(setup.id)
        self:HideSetup(setup.id)
    end
    self.editMode = false
    self.currentEncounterID = nil
    self.currentDifficulty = nil
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

E:RegisterBossModFeature("WhisperKickAlert", {
    tab = "General",
    order = 40,
    labelKey = "BossMods_WhisperKickAlert",
    descKey = "BossMods_WhisperKickAlertDesc",
    moduleName = MODULE_NAME
})
