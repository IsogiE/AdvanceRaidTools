local E = unpack(ART)

-- Phase timer data for Sporefall. See Core/PhaseTimers.lua for the trigger keys.
-- Phase numbers must match the NSRT-style notes (time:X;ph:N) written for it.
local PHASE_TIMER_DATA = {
    [3159] = {
        name = "Rotmire",
        difficulties = {
            Normal = {phases = {[1] = 0}},
            Heroic = {phases = {[1] = 0}},
            Mythic = {phases = {[1] = 0}}
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
