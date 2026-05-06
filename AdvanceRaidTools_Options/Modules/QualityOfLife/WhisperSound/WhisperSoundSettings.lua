local E, L = unpack(ART)
local T = E.Templates

local FALLBACK_SOUND_CHANNELS = {
    Master = "Master",
    SFX = "SFX",
    Dialog = "Dialog",
    Music = "Music",
    Ambience = "Ambience"
}

local function soundChannelValues()
    local BossMods = E:GetModule("BossMods", true)
    local Alerts = BossMods and BossMods.Alerts
    return (Alerts and Alerts.SOUND_CHANNELS) or FALLBACK_SOUND_CHANNELS
end

local function formatSeconds(value)
    value = tonumber(value) or 0
    if value == 1 then
        return "1s"
    end
    return ("%gs"):format(value)
end

local function buildWhisperSoundTab(mod, isDisabled)
    return {
        soundChannel = {
            order = 10,
            width = "1/2",
            build = function(parent)
                return T:Dropdown(parent, {
                    label = L["BossMods_LKSoundChannel"],
                    values = soundChannelValues,
                    get = function()
                        return mod:GetSoundChannel()
                    end,
                    onChange = function(v)
                        mod:SetSoundChannel(v)
                    end,
                    disabled = isDisabled
                })
            end
        },

        throttleSeconds = {
            order = 11,
            width = "1/2",
            build = function(parent)
                return T:Slider(parent, {
                    label = L["QoL_WhisperSoundThrottle"],
                    min = 0,
                    max = 10,
                    step = 0.5,
                    value = mod:GetThrottleSeconds(),
                    get = function()
                        return mod:GetThrottleSeconds()
                    end,
                    onChange = function(v)
                        mod:SetThrottleSeconds(v)
                    end,
                    format = formatSeconds,
                    disabled = isDisabled,
                    tooltip = {
                        title = L["QoL_WhisperSoundThrottle"],
                        desc = L["QoL_WhisperSoundThrottleDesc"]
                    }
                })
            end
        }
    }
end

E:RegisterQoLFeatureSettings("WhisperSound", buildWhisperSoundTab)
