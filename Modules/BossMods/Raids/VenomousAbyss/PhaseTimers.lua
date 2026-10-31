local E = unpack(ART)

local PHASE_TIMER_DATA = {
    encounters = {
        [3470] = {
            name = "Nek'zali the Soulcoiler",
            difficulties = {
                Normal = {
                    phases = {[1] = 0, [1.5] = 87.8, [1.75] = 140.2, [2] = 182.7},
                    unitCast = {
                        [1.5] = {from = 1, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss1", afterCast = {unit = "boss1", duration = 1.5, durationTolerance = 0.2}},
                        [1.75] = {from = 1.5, debounce = 25, event = "UNIT_SPELLCAST_START", unit = "boss2", activeMax = 0},
                        [2] = {from = 1.75, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss1"}
                    }
                },
                Heroic = {
                    phases = {[1] = 0, [1.5] = 98.2, [1.75] = 147.8, [2] = 188.1},
                    unitCast = {
                        [1.5] = {from = 1, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss1", afterCast = {unit = "boss1", duration = 1.5, durationTolerance = 0.2}},
                        [1.75] = {from = 1.5, debounce = 25, event = "UNIT_SPELLCAST_START", unit = "boss2", activeMax = 0},
                        [2] = {from = 1.75, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss1"}
                    }
                },
                Mythic = {
                    phases = {[1] = 0, [1.5] = 87.8, [1.75] = 135.2, [2] = 172.7},
                    unitCast = {
                        [1.5] = {from = 1, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss1", afterCast = {unit = "boss1", duration = 1.5, durationTolerance = 0.2}},
                        [1.75] = {from = 1.5, debounce = 25, event = "UNIT_SPELLCAST_START", unit = "boss2", activeMax = 0},
                        [2] = {from = 1.75, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss1"}
                    }
                }
            }
        },
        [3445] = {
            name = "Entombed Sentinels",
            difficulties = {
                Normal = {
                    phases = {[1] = 0, [2] = 65.5, [3] = 167.5, [4] = 268.6},
                    maxPhase = 8,
                    timelineAdded = {next = {count = 8}}
                },
                Heroic = {
                    phases = {[1] = 0, [2] = 60, [3] = 163.9, [4] = 265.4},
                    maxPhase = 8,
                    timelineAdded = {next = {count = 8}}
                },
                Mythic = {
                    phases = {[1] = 0, [2] = 65.5, [3] = 167.5, [4] = 268.6},
                    maxPhase = 8,
                    timelineAdded = {next = {count = 8}}
                }
            }
        },
        [3455] = {
            name = "Vashnik the Malignant",
            difficulties = {
                Normal = {phases = {[1] = 0}},
                Heroic = {phases = {[1] = 0}},
                Mythic = {phases = {[1] = 0}}
            }
        },
        [3497] = {
            name = "The Lost Explorers",
            difficulties = {
                Normal = {
                    phases = {[1] = 0, [2] = 47.4, [3] = 169.3},
                    maxPhase = 8,
                    timelineAdded = {
                        [2] = {from = 1, count = 4, debounce = 40, match = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}},
                        next = {count = 4, debounce = 100, match = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}}
                    }
                },
                Heroic = {
                    phases = {[1] = 0, [2] = 54, [3] = 172.7},
                    maxPhase = 8,
                    timelineAdded = {
                        [2] = {from = 1, count = 4, debounce = 40, match = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}},
                        next = {count = 4, debounce = 100, match = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}}
                    }
                },
                Mythic = {
                    phases = {[1] = 0, [2] = 47.4, [3] = 169.3},
                    maxPhase = 8,
                    timelineAdded = {
                        [2] = {from = 1, count = 4, debounce = 40, match = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}},
                        next = {count = 4, debounce = 100, match = {durations = {16, 11, 13}, count = 1, durationTolerance = 0.2}}
                    }
                }
            }
        },
        [3420] = {
            name = "Sszorak",
            difficulties = {
                Normal = {phases = {[1] = 0}},
                Heroic = {phases = {[1] = 0}},
                Mythic = {phases = {[1] = 0}}
            }
        },
        [3421] = {
            name = "The Twin Fangs",
            difficulties = {
                Normal = {phases = {[1] = 0}},
                Heroic = {phases = {[1] = 0}},
                Mythic = {phases = {[1] = 0}}
            }
        },
        [3429] = {
            name = "The Coiled Altar",
            difficulties = {
                Normal = {
                    phases = {[1] = 0, [2] = 125.9, [2.5] = 314.1, [3] = 351.8},
                    timelineAdded = {
                        [2] = {from = 1, duration = 70, durationTolerance = 0.2},
                        [3] = {from = 2.5, count = 4}
                    },
                    unitCast = {
                        [2.5] = {from = 2, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss2", activeMax = 0}
                    }
                },
                Heroic = {
                    phases = {[1] = 0, [2] = 127.4, [2.5] = 292.7, [3] = 330.4},
                    timelineAdded = {
                        [2] = {from = 1, duration = 70, durationTolerance = 0.2},
                        [3] = {from = 2.5, count = 4}
                    },
                    unitCast = {
                        [2.5] = {from = 2, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss2", activeMax = 0}
                    }
                },
                Mythic = {
                    phases = {[1] = 0, [2] = 132.9, [2.5] = 311.1, [3] = 348.8},
                    timelineAdded = {
                        [2] = {from = 1, duration = 70, durationTolerance = 0.2},
                        [3] = {from = 2.5, count = 4}
                    },
                    unitCast = {
                        [2.5] = {from = 2, debounce = 0, event = "UNIT_SPELLCAST_CHANNEL_START", unit = "boss2", activeMax = 0}
                    }
                }
            }
        },
        [3492] = {
            name = "Ula'tek",
            difficulties = {
                Normal = {phases = {[1] = 0}},
                Heroic = {phases = {[1] = 0}},
                Mythic = {phases = {[1] = 0}}
            }
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA.encounters) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
