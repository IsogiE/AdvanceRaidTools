local E, L = unpack(ART)

local function getSpecSlot()
    if not GetSpecialization then
        return nil
    end
    return GetSpecialization()
end

local function applySpecProfile()
    E:ApplySpecProfile()
end

local function applySpecProfileSoon(delay)
    if C_Timer and C_Timer.After and delay and delay > 0 then
        C_Timer.After(delay, applySpecProfile)
    else
        applySpecProfile()
    end
end

local function applySpecProfileWithLoginSettling()
    applySpecProfile()
    applySpecProfileSoon(0.5)
end

function E:ApplySpecProfile()
    if not (self.db and self.db.char and self.db.char.specProfilesEnabled) then
        return
    end
    local slot = getSpecSlot()
    if not slot then
        return
    end
    local wanted = (self.db.char.specProfiles or {})[slot]
    if wanted and wanted ~= self.db:GetCurrentProfile() then
        self.db:SetProfile(wanted)
    end
end

local SpecProfiles = E:NewCallbackHandle()
SpecProfiles:RegisterMessage("ART_CORE_INITIALIZED", function()
    SpecProfiles:RegisterEvent("PLAYER_LOGIN", function()
        applySpecProfileWithLoginSettling()
    end)
    SpecProfiles:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        applySpecProfileWithLoginSettling()
    end)
    SpecProfiles:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
        if unit == nil or unit == "player" then
            applySpecProfileSoon(0)
        end
    end)
    if IsLoggedIn and IsLoggedIn() then
        applySpecProfileWithLoginSettling()
    end
end)
