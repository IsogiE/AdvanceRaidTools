local E = unpack(ART)

local PHASE_TIMER_DATA = {
    encounters = {
        [3513] = {
            name = "Kith'ix",
            difficulties = {
                Normal = {
                    phases = {[1] = 0},
                    maxPhase = 2,
                    timelineCanceled = {[2] = {from = 1, count = 3}}
                },
                Heroic = {
                    phases = {[1] = 0},
                    maxPhase = 2,
                    timelineCanceled = {[2] = {from = 1, count = 3}}
                },
                Mythic = {
                    phases = {[1] = 0},
                    maxPhase = 2,
                    timelineCanceled = {[2] = {from = 1, count = 3}}
                }
            }
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA.encounters) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
