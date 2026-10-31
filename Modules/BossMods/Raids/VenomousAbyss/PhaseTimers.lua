local E = unpack(ART)

-- Phase timer data for The Venomous Abyss. See Core/PhaseTimers.lua for the trigger keys.
-- Phase numbers and phase-change detection mirror NorthernSkyRaidTools so NSRT-style
-- notes (time:X;ph:N) count down from the same moment NSRT starts that phase.
-- Static starts are NSRT's reference timelines and are only used until the live
-- trigger fires. NSRT has no Normal timelines, so Normal reuses Heroic.

-- Nek'zali: 1 -> 1.5 when boss1 channels after a cast that completed ~1.5s after
-- it started; 1.5 -> 1.75 on a boss2 cast 25s+ into 1.5 with no timeline bars up;
-- 1.75 -> 2 on the next boss1 channel.
local nekzaliCasts = {
    [1.5] = {from = 1, unit = "boss1", cast = "channelStart", castSequence = {gap = 1.5, tolerance = 0.2}, debounce = 0},
    [1.75] = {from = 1.5, unit = "boss2", cast = "start", activeTimelineMax = 0, debounce = 25},
    [2] = {from = 1.75, unit = "boss1", cast = "channelStart", debounce = 0}
}

-- Entombed Sentinels: each new phase starts with a burst of 8+ timeline bars.
local sentinelsAdded = {next = {count = 8}}

-- Lost Explorers: each new boss starts with a burst of 4+ bars including a 16s,
-- 11s or 13s bar; 40s after the pull for the first swap, 100s between later ones.
local explorersMatch = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}
local explorersAdded = {
    next = {
        {from = 1, count = 4, debounce = 40, match = explorersMatch},
        {count = 4, debounce = 100, match = explorersMatch}
    }
}

-- Coiled Altar: P2 on a 70s bar; intermission (2.5) when boss2 channels with no
-- timeline bars up; P3 on a burst of 4+ bars.
local coiledAdded = {
    [2] = {from = 1, duration = 70, durationTolerance = 0.2},
    [3] = {from = 2.5, count = 4}
}
local coiledCasts = {
    [2.5] = {from = 2, unit = "boss2", cast = "channelStart", activeTimelineMax = 0, debounce = 0}
}

local function singlePhase(name)
    return {
        name = name,
        difficulties = {
            Normal = {phases = {[1] = 0}},
            Heroic = {phases = {[1] = 0}},
            Mythic = {phases = {[1] = 0}}
        }
    }
end

local PHASE_TIMER_DATA = {
    [3470] = {
        name = "Nek'zali the Soulcoiler",
        difficulties = {
            Normal = {phases = {[1] = 0, [1.5] = 133.95, [1.75] = 214.21, [2] = 276.53}, unitCast = nekzaliCasts},
            Heroic = {phases = {[1] = 0, [1.5] = 133.95, [1.75] = 214.21, [2] = 276.53}, unitCast = nekzaliCasts},
            Mythic = {phases = {[1] = 0, [1.5] = 197.89, [1.75] = 281.9, [2] = 368.28}, unitCast = nekzaliCasts}
        }
    },
    [3445] = {
        name = "Entombed Sentinels",
        difficulties = {
            Normal = {phases = {[1] = 0, [2] = 57, [3] = 160, [4] = 273, [5] = 378, [6] = 484}, timelineAdded = sentinelsAdded},
            Heroic = {phases = {[1] = 0, [2] = 57, [3] = 160, [4] = 273, [5] = 378, [6] = 484}, timelineAdded = sentinelsAdded},
            Mythic = {phases = {[1] = 0, [2] = 56, [3] = 157, [4] = 258, [5] = 359}, timelineAdded = sentinelsAdded}
        }
    },
    [3497] = {
        name = "The Lost Explorers",
        difficulties = {
            Normal = {phases = {[1] = 0, [2] = 61, [3] = 179.23, [4] = 297.65, [5] = 436}, timelineAdded = explorersAdded},
            Heroic = {phases = {[1] = 0, [2] = 61, [3] = 179.23, [4] = 297.65, [5] = 436}, timelineAdded = explorersAdded},
            Mythic = {phases = {[1] = 0, [2] = 64, [3] = 183, [4] = 306, [5] = 434}, timelineAdded = explorersAdded}
        }
    },
    [3429] = {
        name = "The Coiled Altar",
        difficulties = {
            Normal = {phases = {[1] = 0, [2] = 167, [2.5] = 293, [3] = 331}, timelineAdded = coiledAdded, unitCast = coiledCasts},
            Heroic = {phases = {[1] = 0, [2] = 167, [2.5] = 293, [3] = 331}, timelineAdded = coiledAdded, unitCast = coiledCasts},
            Mythic = {phases = {[1] = 0, [2] = 175, [2.5] = 382, [3] = 420}, timelineAdded = coiledAdded, unitCast = coiledCasts}
        }
    },
    [3455] = singlePhase("Vashnik the Malignant"),
    [3420] = singlePhase("Sszorak"),
    [3421] = singlePhase("The Twin Fangs"),
    [3492] = singlePhase("Ula'tek")
}

for encounterID, data in pairs(PHASE_TIMER_DATA) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
