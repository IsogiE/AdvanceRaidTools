local E = unpack(ART)

local PHASE_TIMER_DATA = {
    encounters = {
        [3159] = {
            name = "Rotmire",
            difficulties = {
                Normal = {phases = {[1] = 0}},
                Heroic = {phases = {[1] = 0}},
                Mythic = {phases = {[1] = 0}}
            }
        },
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
        },
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
        },
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
