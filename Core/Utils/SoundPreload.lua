local E = unpack(ART)

local LSM = E.Libs.LSM

local INITIAL_DELAY = 10
local SOUND_CHANNEL = "Master"

local soundsToPlay = {}
local playedSounds = {}
local cachedSounds = {}
local cachedSoundOrder = {}
local startScheduled = false
local running = false
local initialized = false
local loginReportPending = false
local eventFrame
local lsmCallbackTarget = {}

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

local function printLoginReport()
    loginReportPending = false
    E:Printf("Sound preload cached %d sound(s).", #cachedSoundOrder)
end

local function playNextSound()
    local key, path = next(soundsToPlay)
    if not key then
        running = false
        if loginReportPending then
            printLoginReport()
        end
        return
    end

    playedSounds[key] = true
    soundsToPlay[key] = nil

    local ok, played, handle = pcall(PlaySoundFile, path, SOUND_CHANNEL)
    if ok and played then
        if not cachedSounds[key] then
            cachedSoundOrder[#cachedSoundOrder + 1] = key
        end
        cachedSounds[key] = path

        if handle and StopSound then
            pcall(StopSound, handle)
        end
    end

    C_Timer.After(0, playNextSound)
end

local function startPreload()
    startScheduled = false

    addLSMSounds()

    if running then
        return
    end

    if not next(soundsToPlay) then
        if loginReportPending then
            printLoginReport()
        end
        return
    end

    running = true
    playNextSound()
end

local function schedulePreload(delay)
    if startScheduled then
        return
    end

    startScheduled = true
    C_Timer.After(delay or INITIAL_DELAY, startPreload)
end

local function onLSMRegistered(_, mediaType, key)
    if mediaType ~= "sound" or not (LSM and LSM.Fetch) then
        return
    end

    local ok, path = pcall(LSM.Fetch, LSM, "sound", key)
    if ok then
        addSound(key, path)
        schedulePreload(0)
    end
end

function E:RegisterSoundPreload(path, key)
    key = key or path
    addSound(key, path)

    if initialized then
        schedulePreload(0)
    end
end

local function initializeSoundPreload()
    if initialized then
        return
    end
    initialized = true

    if LSM and LSM.RegisterCallback then
        LSM.RegisterCallback(lsmCallbackTarget, "LibSharedMedia_Registered", onLSMRegistered)
    end

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("ENCOUNTER_END")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            loginReportPending = true
        end
        schedulePreload(INITIAL_DELAY)
    end)

    schedulePreload(INITIAL_DELAY)
end

E:RegisterSoundPreload([[Interface\AddOns\AdvanceRaidTools\Media\Sounds\Whisper.mp3]])
initializeSoundPreload()
