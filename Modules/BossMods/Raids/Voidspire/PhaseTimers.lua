local E = unpack(ART)

-- Phase timer data for The Voidspire. See Core/PhaseTimers.lua for the trigger keys.
-- Phase numbers must match the NSRT-style notes (time:X;ph:N) written for it.
local PHASE_TIMER_DATA = {
    [3176] = {
        name = "Imperator Averzian",
        difficulties = {
            Normal = {phases = {[1] = 0}},
            Heroic = {phases = {[1] = 0}},
            Mythic = {phases = {[1] = 0}}
        }
    },
    [3177] = {
        name = "Vorasius",
        difficulties = {
            Normal = {phases = {[1] = 0}},
            Heroic = {phases = {[1] = 0}},
            Mythic = {phases = {[1] = 0}}
        }
    },
    [3178] = {
        name = "Vaelgor & Ezzorak",
        difficulties = {
            Normal = {
                phases = {[1] = 0, [2] = 113.3},
                timelineFinished = {[2] = {duration = 8}}
            },
            Heroic = {
                phases = {[1] = 0, [2] = 113.3},
                timelineFinished = {[2] = {duration = 8}}
            },
            Mythic = {
                phases = {[1] = 0}
            }
        }
    },
    [3179] = {
        name = "Fallen King Salhadaar",
        difficulties = {
            Normal = {phases = {[1] = 0}},
            Heroic = {phases = {[1] = 0}},
            Mythic = {phases = {[1] = 0}}
        }
    },
    [3180] = {
        name = "Lightblinded Vanguard",
        difficulties = {
            Normal = {phases = {[1] = 0}},
            Heroic = {phases = {[1] = 0}},
            Mythic = {phases = {[1] = 0}}
        }
    },
    [3181] = {
        name = "Crown of the Cosmos",
        difficulties = {
            Normal = {
                phases = {[1] = 0, [2] = 133.6, [3] = 166.6, [4] = 380.7, [5] = 403.8},
                timelineAdded = {
                    [2] = {match = {durations = {1.5, 25}, count = 2}},
                    [3] = {count = 5},
                    [4] = {from = 3, match = {durations = {1.5, 20}, count = 2}},
                    [5] = {count = 4}
                }
            },
            Heroic = {
                phases = {[1] = 0, [2] = 133.6, [3] = 166.6, [4] = 380.7, [5] = 403.8},
                timelineAdded = {
                    [2] = {match = {durations = {1.5, 25}, count = 2}},
                    [3] = {count = 5},
                    [4] = {from = 3, match = {durations = {1.5, 20}, count = 2}},
                    [5] = {count = 4}
                }
            },
            Mythic = {
                phases = {[1] = 0, [2] = 137.5, [3] = 170.8, [4] = 348.6, [5] = 364.6},
                timelineAdded = {
                    [2] = {match = {durations = {1.5, 25}, count = 2}},
                    [3] = {count = 5},
                    [5] = {{from = 3, count = 8}, {from = 4, count = 8}}
                },
                timelineRemoved = {
                    [4] = {{count = 3}, {count = 2, addedMax = 3}}
                }
            }
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
