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

-- Nameplate anchors

local NAMEPLATE_ANCHOR_POINTS = {
    TOP = {"BOTTOM", "TOP"},
    BOTTOM = {"TOP", "BOTTOM"},
    LEFT = {"RIGHT", "LEFT"},
    RIGHT = {"LEFT", "RIGHT"},
    CENTER = {"CENTER", "CENTER"}
}

local NAMEPLATE_ANCHOR_VALUES = {
    TOP = "Top",
    BOTTOM = "Bottom",
    LEFT = "Left",
    RIGHT = "Right",
    CENTER = "Center"
}

local NAMEPLATE_ANCHOR_SORTING = {
    "TOP",
    "CENTER",
    "LEFT",
    "RIGHT",
    "BOTTOM"
}

local function safeNameplateToken(unit)
    if E.SafeString then
        return E:SafeString(unit)
    end
    if type(unit) ~= "string" then
        return nil
    end
    if E.IsSecret and E:IsSecret(unit) then
        return nil
    end
    return unit
end

local function nameplatePoolFrameName(prefix, key)
    key = tostring(key or ""):gsub("[^%w_]", "_")
    if key == "" then
        key = "Frame"
    end
    return (prefix or "ART_BossMods_Nameplate_") .. key
end

function Alerts:GetNameplateAnchorValues()
    return NAMEPLATE_ANCHOR_VALUES
end

function Alerts:GetNameplateAnchorSorting()
    return NAMEPLATE_ANCHOR_SORTING
end

function Alerts:ResolveNameplateFrame(unit)
    unit = safeNameplateToken(unit)
    if not unit then
        return nil
    end

    if C_NamePlate
        and C_NamePlate.GetNamePlateForUnit
    then
        local secure = issecure and issecure()
        return C_NamePlate.GetNamePlateForUnit(unit, secure)
    end
    return nil
end

function Alerts:AnchorToNameplate(frame, unit, opts)
    if not frame then
        return nil
    end

    opts = opts or {}
    unit = safeNameplateToken(unit)
    local target = opts.target or (unit and self:ResolveNameplateFrame(unit))
    if not target then
        frame:Hide()
        return nil
    end

    local points = NAMEPLATE_ANCHOR_POINTS[opts.anchor or "TOP"]
        or NAMEPLATE_ANCHOR_POINTS.TOP
    frame:ClearAllPoints()
    frame:SetPoint(
        points[1],
        target,
        points[2],
        opts.offsetX or 0,
        opts.offsetY or 0
    )
    return target
end

function Alerts:CreateNameplateAnchorPool(config)
    config = config or {}
    local pool = {
        frames = {},
        config = config,
        alerts = self
    }

    function pool:GetFrame(key)
        key = safeNameplateToken(key)
        if not key then
            return nil
        end

        local frame = self.frames[key]
        if frame then
            return frame
        end

        local name = nameplatePoolFrameName(self.config.prefix, key)
        local parent = self.config.parent or UIParent
        if self.config.createFrame then
            frame = self.config.createFrame(key, parent, name)
        else
            frame = CreateFrame("Frame", name, parent)
        end

        if frame then
            self.frames[key] = frame
        end
        return frame
    end

    function pool:Update(key, unit, opts)
        key = safeNameplateToken(key)
        unit = safeNameplateToken(unit)
        if not key or not unit then
            return nil
        end

        opts = opts or {}
        local target = opts.target
            or (
                self.config.resolveFrame
                and self.config.resolveFrame(unit, key, opts)
            )
            or self.alerts:ResolveNameplateFrame(unit)
        if not target then
            local existing = self.frames[key]
            if existing then
                existing:Hide()
            end
            return nil
        end

        local frame = self:GetFrame(key)
        if not frame then
            return nil
        end

        local updateFrame = opts.updateFrame or self.config.updateFrame
        if updateFrame then
            updateFrame(frame, opts, key, unit, target)
        end

        self.alerts:AnchorToNameplate(frame, unit, {
            target = target,
            anchor = opts.anchor or self.config.anchor,
            offsetX = opts.offsetX or self.config.offsetX,
            offsetY = opts.offsetY or self.config.offsetY
        })
        frame:Show()
        return frame, target
    end

    function pool:Hide(key)
        key = safeNameplateToken(key)
        local frame = key and self.frames[key]
        if frame then
            frame:Hide()
        end
    end

    function pool:HideInactive(activeKeys)
        activeKeys = activeKeys or {}
        for key, frame in pairs(self.frames) do
            if not activeKeys[key] then
                frame:Hide()
            end
        end
    end

    function pool:HideAll()
        for _, frame in pairs(self.frames) do
            frame:Hide()
        end
    end

    function pool:Release()
        for key, frame in pairs(self.frames) do
            frame:Hide()
            frame:ClearAllPoints()
            if frame.SetParent then
                frame:SetParent(nil)
            end
            self.frames[key] = nil
        end
    end

    return pool
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
