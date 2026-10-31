local E = unpack(ART)

-- Phase timer data for March on Quel'Danas. See Core/PhaseTimers.lua for the trigger keys.
-- Phase numbers must match the NSRT-style notes (time:X;ph:N) written for it.
local PHASE_TIMER_DATA = {
    [3182] = {
        name = "Belo'ren",
        difficulties = {
            Normal = {
                phases = {[1] = 0, [2] = 101, [3] = 254.2, [4] = 407.4},
                timelineAdded = {next = {duration = 6, debounce = 3, afterLastAdded = 3}}
            },
            Heroic = {
                phases = {[1] = 0, [2] = 101, [3] = 254.2, [4] = 407.4},
                timelineAdded = {next = {duration = 6, debounce = 3, afterLastAdded = 3}}
            },
            Mythic = {
                phases = {[1] = 0, [2] = 110.1, [3] = 281.3, [4] = 434.5},
                timelineAdded = {next = {duration = 6, debounce = 3, afterLastAdded = 3}}
            }
        }
    },
    [3183] = {
        name = "Midnight Falls",
        difficulties = {
            Normal = {
                phases = {[1] = 0, [2] = 180, [3] = 225.1, [4] = 330.1},
                timelineAdded = {
                    [2] = {duration = 45},
                    [3] = {duration = 97},
                    [4] = {duration = 180}
                }
            },
            Heroic = {
                phases = {[1] = 0, [2] = 180, [3] = 225.1, [4] = 330.1},
                timelineAdded = {
                    [2] = {duration = 45},
                    [3] = {duration = 97},
                    [4] = {duration = 180}
                }
            },
            Mythic = {
                phases = {[1] = 0, [2] = 180, [3] = 225.1, [4] = 330.2, [5] = 515.5},
                timelineAdded = {
                    [2] = {duration = 45},
                    [3] = {duration = 97},
                    [4] = {duration = 180}
                },
                engageUnit = {
                    [5] = {debounce = 20, unitMissing = "boss2"}
                }
            }
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
