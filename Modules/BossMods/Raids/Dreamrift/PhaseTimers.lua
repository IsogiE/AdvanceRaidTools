local E = unpack(ART)

local PHASE_TIMER_DATA = {
    encounters = {
        [3306] = {
            name = "Chimaerus",
            difficulties = {
                Normal = {
                    phases = {[1] = 0, [2] = 241, [3] = 482, [4] = 723},
                    timelineAdded = {next = {count = 6, debounce = 30}}
                },
                Heroic = {
                    phases = {[1] = 0, [2] = 241, [3] = 482, [4] = 723},
                    timelineAdded = {next = {count = 6, debounce = 30}}
                },
                Mythic = {
                    phases = {[1] = 0, [2] = 255.1, [3] = 506.7},
                    timelineAdded = {next = {count = 6, debounce = 30}}
                }
            }
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA.encounters) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
