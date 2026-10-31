local E = unpack(ART)

-- Phase timer data for The Unbinding of Kith'ix. See Core/PhaseTimers.lua for the trigger keys.
-- Mirrors NorthernSkyRaidTools: P2 starts when 3+ timeline bars are canceled at once.
-- Static starts are NSRT's reference timelines; Normal reuses Heroic.
local kithixCanceled = {[2] = {from = 1, count = 3}}

local PHASE_TIMER_DATA = {
    [3513] = {
        name = "Kith'ix",
        difficulties = {
            Normal = {phases = {[1] = 0, [2] = 210}, timelineCanceled = kithixCanceled},
            Heroic = {phases = {[1] = 0, [2] = 210}, timelineCanceled = kithixCanceled},
            Mythic = {phases = {[1] = 0, [2] = 300}, timelineCanceled = kithixCanceled}
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
