local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.Alerts = BossMods.Alerts or {}
local Alerts = BossMods.Alerts

function Alerts:SpeakTTS(opts)
    opts = opts or {}
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then
        return
    end

    local text = opts.text
    if type(text) ~= "string" or text == "" then
        return
    end

    local voiceID = tonumber(opts.voiceID) or 0
    local voices = C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices()
    local valid = false
    if voices then
        for _, v in ipairs(voices) do
            if v.voiceID == voiceID then
                valid = true
                break
            end
        end
    end
    if not valid then
        voiceID = 0
    end

    local rate = (C_TTSSettings and C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate()) or 0
    C_VoiceChat.SpeakText(voiceID, text, rate, 100, false)
end

function Alerts:StopTTS()
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then
        C_VoiceChat.StopSpeakingText()
    end
end

function Alerts:GetTTSVoices()
    local t = {}
    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local voices = C_VoiceChat.GetTtsVoices()
        if voices then
            for _, v in ipairs(voices) do
                t[v.voiceID] = v.name
            end
        end
    end
    if not next(t) then
        t[0] = "Default System Voice"
    end
    return t
end

-- Sound

Alerts.SOUND_CHANNELS = {
    Master = "Master",
    SFX = "SFX",
    Dialog = "Dialog",
    Music = "Music",
    Ambience = "Ambience"
}

function Alerts:PlaySound(opts)
    opts = opts or {}
    local name = opts.name
    if type(name) ~= "string" or name == "" or name == "None" then
        return
    end

    local LSM = E.Libs.LSM
    local path = (LSM and LSM:Fetch("sound", name)) or name
    if not path or path == "" then
        return
    end
    PlaySoundFile(path, opts.channel or "Master")
end

function Alerts:GetSoundOptions()
    local t = E:MediaList("sound")
    t["None"] = "None"
    return t
end

--  Glow

function Alerts:ResolveFrame(unit)
    if not unit then
        return nil
    end
    local LGF = E.Libs.LibGetFrame
    if LGF and LGF.GetUnitFrame then
        local f = LGF.GetUnitFrame(unit)
        if f then
            return f
        end
    end
    if DandersFrames_GetFrameForUnit then
        return DandersFrames_GetFrameForUnit(unit)
    end
    return nil
end

-- opts:
--  unit
--  frame
--  glowType
--  color
--  lines
--  thickness
--  frequency
--  scale
--  key
function Alerts:StartGlow(opts)
    opts = opts or {}
    local LCG = E.Libs.LibCustomGlow
    if not LCG then
        return
    end

    local frame = opts.frame or self:ResolveFrame(opts.unit)
    if not frame then
        return
    end

    local color = opts.color or {0.247, 0.988, 0.247, 1}
    local gType = opts.glowType or "Pixel"
    local lines = opts.lines or 10
    local thickness = opts.thickness or 3
    local freq = opts.frequency or 0.3
    local scale = opts.scale or 1.0
    local key = opts.key or "ART_BossMods_Glow"

    -- Stop any prior glow under this key regardless of type so switching glow styles mid-assignment doesn't leave ghosts
    self:StopGlow({
        frame = frame,
        key = key
    })

    if gType == "Pixel" then
        LCG.PixelGlow_Start(frame, color, lines, freq, nil, thickness, 0, 0, true, key)
    elseif gType == "Autocast" then
        LCG.AutoCastGlow_Start(frame, color, lines, freq, scale, 0, 0, key)
    elseif gType == "Button" then
        LCG.ButtonGlow_Start(frame, color, freq)
    elseif gType == "Proc" then
        local duration = (freq ~= 0) and math.abs(1 / freq) or 1
        LCG.ProcGlow_Start(frame, {
            color = color,
            duration = duration,
            key = key
        })
    end
end

-- opts:
--  unit | frame
--  key
function Alerts:StopGlow(opts)
    opts = opts or {}
    local LCG = E.Libs.LibCustomGlow
    if not LCG then
        return
    end

    local frame = opts.frame or self:ResolveFrame(opts.unit)
    if not frame then
        return
    end

    local key = opts.key or "ART_BossMods_Glow"
    LCG.PixelGlow_Stop(frame, key)
    LCG.AutoCastGlow_Stop(frame, key)
    LCG.ButtonGlow_Stop(frame)
    LCG.ProcGlow_Stop(frame, key)
end

-- Returns a glowType -> label map for settings dropdowns
function Alerts:GetGlowTypes()
    local Lart = ART[2]
    return {
        Pixel = Lart["BossMods_GlowPixel"] or "Pixel Glow",
        Autocast = Lart["BossMods_GlowAutocast"] or "Autocast Shine",
        Button = Lart["BossMods_GlowButton"] or "Action Button Glow",
        Proc = Lart["BossMods_GlowProc"] or "Proc Glow"
    }
end
