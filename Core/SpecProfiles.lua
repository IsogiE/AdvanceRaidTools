local E, L = unpack(ART)

local function getSpecSlot()
    return GetSpecialization()
end

function E:ApplySpecProfile()
    if not self.db.char.specProfilesEnabled then
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
    SpecProfiles:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
        E:ApplySpecProfile()
    end)
    E:ApplySpecProfile()
end)
