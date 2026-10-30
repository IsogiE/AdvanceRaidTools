local E = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Core/Utils/SoundPreload")

local LSM = E.Libs.LSM

local SOUND_CHANNEL = "Master"

local soundsToPlay = {}
local playedSounds = {}
local preloadPending = false
local enteredWorld = false
local lsmCallbackTarget = {}

local function preloadNextSound()
    if InCombatLockdown() then
        E:RunWhenOutOfCombat("SoundPreload:Drain", preloadNextSound)
        return
    end

    local path = next(soundsToPlay)
    if path then
        soundsToPlay[path] = nil
        if PlaySoundFile and StopSound then
            local ok, played, handle = pcall(PlaySoundFile, path, SOUND_CHANNEL)
            if ok and played and handle then
                playedSounds[path] = true
                pcall(StopSound, handle)
            end
        end
    end

    if next(soundsToPlay) then
        C_Timer.After(0, preloadNextSound)
    else
        preloadPending = false
    end
end

local function schedulePreload()
    if enteredWorld and not preloadPending and next(soundsToPlay) then
        preloadPending = true
        C_Timer.After(0, preloadNextSound)
    end
end

local function addSound(path)
    if type(path) ~= "string" or path == "" or playedSounds[path] then
        return
    end
    soundsToPlay[path] = true
end

local function addLSMSounds()
    local sounds = LSM and LSM.HashTable and LSM:HashTable("sound")
    if not sounds then
        return
    end

    for _, path in pairs(sounds) do
        addSound(path)
    end
end

local function preloadSounds()
    enteredWorld = true
    addLSMSounds()
    schedulePreload()
end

function E:RegisterSoundPreload(path, key)
    addSound(path)
    schedulePreload()
end

E:RegisterSoundPreload([[Interface\AddOns\AdvanceRaidTools\Media\Sounds\Whisper.mp3]])

if LSM and LSM.RegisterCallback then
    LSM.RegisterCallback(lsmCallbackTarget, "LibSharedMedia_Registered", function(_, mediaType, key)
        if mediaType == "sound" then
            local sounds = LSM:HashTable("sound")
            addSound(sounds and sounds[key])
            schedulePreload()
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", preloadSounds)
