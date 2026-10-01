local E = unpack(ART)

local LSM = E.Libs.LSM

local SOUND_CHANNEL = "Master"

local soundsToPlay = {}
local playedSounds = {}

local function addSound(key, path)
    if type(key) ~= "string" or key == "" or type(path) ~= "string" or path == "" then
        return
    end
    if playedSounds[key] or soundsToPlay[key] then
        return
    end
    soundsToPlay[key] = path
end

local function addLSMSounds()
    if not (LSM and LSM.List and LSM.Fetch) then
        return
    end

    for _, key in ipairs(LSM:List("sound")) do
        if not playedSounds[key] then
            local ok, path = pcall(LSM.Fetch, LSM, "sound", key)
            if ok then
                addSound(key, path)
            end
        end
    end
end

local function preloadSounds()
    addLSMSounds()

    for key, path in pairs(soundsToPlay) do
        playedSounds[key] = true
        soundsToPlay[key] = nil

        local ok, played, handle = pcall(PlaySoundFile, path, SOUND_CHANNEL)
        if ok and played and handle and StopSound then
            pcall(StopSound, handle)
        end
    end
end

function E:RegisterSoundPreload(path, key)
    key = key or path
    addSound(key, path)
end

E:RegisterSoundPreload([[Interface\AddOns\AdvanceRaidTools\Media\Sounds\Whisper.mp3]])

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", preloadSounds)
