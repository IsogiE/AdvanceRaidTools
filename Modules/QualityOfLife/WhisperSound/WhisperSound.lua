local E, L = unpack(ART)

local DEFAULT_THROTTLE_SECONDS = 2

E:RegisterModuleDefaults("QoL_WhisperSound", {
    enabled = false,
    soundChannel = "Master",
    throttleSeconds = DEFAULT_THROTTLE_SECONDS
})

local WhisperSound = E:NewModule("QoL_WhisperSound", "AceEvent-3.0")

local SOUND_PATH = "Interface\\AddOns\\" .. E.addonName .. "\\Media\\Sounds\\Whisper.mp3"
local DEFAULT_SOUND_CHANNEL = "Master"
local VALID_SOUND_CHANNELS = {
    Master = true,
    SFX = true,
    Dialog = true,
    Music = true,
    Ambience = true
}

local lastSoundTime

local function clampThrottleSeconds(value, fallback)
    if value == nil then
        return fallback or 0
    end

    value = tonumber(value)
    if not value then
        return fallback or 0
    end

    if value < 0 then
        return 0
    elseif value > 10 then
        return 10
    end
    return value
end

function WhisperSound:GetSoundChannel()
    local channel = self.db and self.db.soundChannel
    return VALID_SOUND_CHANNELS[channel] and channel or DEFAULT_SOUND_CHANNEL
end

function WhisperSound:SetSoundChannel(channel)
    self.db.soundChannel = VALID_SOUND_CHANNELS[channel] and channel or DEFAULT_SOUND_CHANNEL
end

function WhisperSound:GetThrottleSeconds()
    return clampThrottleSeconds(self.db and self.db.throttleSeconds, DEFAULT_THROTTLE_SECONDS)
end

function WhisperSound:SetThrottleSeconds(seconds)
    self.db.throttleSeconds = clampThrottleSeconds(seconds, DEFAULT_THROTTLE_SECONDS)
end

function WhisperSound:PlayNotificationSound()
    PlaySoundFile(SOUND_PATH, self:GetSoundChannel())
end

function WhisperSound:OnWhisper()
    local currentTime = GetTime()
    local throttleSeconds = self:GetThrottleSeconds()

    if not lastSoundTime or throttleSeconds <= 0 or (currentTime - lastSoundTime) >= throttleSeconds then
        self:PlayNotificationSound()
        lastSoundTime = currentTime
    end
end

function WhisperSound:OnEnable()
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER", "OnWhisper")
end

function WhisperSound:OnDisable()
    self:UnregisterAllEvents()
end

E:RegisterQoLFeature("WhisperSound", {
    order = 40,
    labelKey = "QoL_WhisperSound",
    descKey = "QoL_WhisperSoundDesc",
    moduleName = "QoL_WhisperSound"
})
