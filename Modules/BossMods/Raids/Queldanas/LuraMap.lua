-- This entire way of doing it was a mistake, I am too lazy to change it. Luml wanted it done like day of raid while the roster kept changing
-- Promise future ones will be nicer
local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_LuraMap", {
    enabled = false,
    anchors = {
        intermission = {
            enabled = true,
            position = {
                point = "CENTER",
                x = -200,
                y = 0
            },
            scale = 0.70,
            opacity = 1.0
        },
        main = {
            enabled = true,
            position = {
                point = "CENTER",
                x = 200,
                y = 0
            },
            scale = 1.0,
            opacity = 1.0,
            bgColor = {
                r = 1,
                g = 1,
                b = 1
            },
            bgOpacity = 0.60,
            borderColor = {
                r = 1,
                g = 1,
                b = 1
            },
            borderOpacity = 0.60
        }
    },
    font = {
        size = 10,
        outline = "OUTLINE"
    }
})

local ENCOUNTER_ID = 3183
local MYTHIC_DIFFICULTY = 16
local SPELL_GALVANIZE = 1284525
local SPELL_CORE_HARVEST = 1282412
local PHASE_1_DURATION = 45
local INTERMISSION_HIDE = 5
local MAIN_HIDE = 7.8
local MAIN_ALT_HIDE = 12.1

-- Position tables

local INNER, OUTER = 110, 210

local POS_INTERMISSION = {
    -- Tanks
    [11] = {
        r = INNER,
        a = 355
    },
    [1] = {
        r = INNER,
        a = 35
    },
    -- Circle anchors
    [14] = {
        r = OUTER,
        a = 180
    },
    [19] = {
        r = INNER,
        a = 180
    },
    -- Right outer wing
    [12] = {
        r = OUTER,
        a = 157.5
    },
    [4] = {
        r = OUTER,
        a = 135
    },
    [6] = {
        r = OUTER,
        a = 112.5
    },
    [13] = {
        r = OUTER,
        a = 90
    },
    -- Left outer wing
    [8] = {
        r = OUTER,
        a = 202.5
    },
    [17] = {
        r = OUTER,
        a = 225
    },
    [2] = {
        r = OUTER,
        a = 247.5
    },
    [3] = {
        r = OUTER,
        a = 270
    },
    -- Right inner wing
    [18] = {
        r = INNER,
        a = 155
    },
    [20] = {
        r = INNER,
        a = 125
    },
    [7] = {
        r = INNER,
        a = 95
    },
    [16] = {
        r = INNER,
        a = 75
    },
    -- Left inner wing
    [15] = {
        r = INNER,
        a = 310
    },
    [5] = {
        r = INNER,
        a = 285
    },
    [10] = {
        r = INNER,
        a = 250
    },
    [9] = {
        r = INNER,
        a = 215
    }
}

local POS_MAIN = {
    -- Bottom Left
    [1] = {
        x = -155,
        y = -110
    },
    [3] = {
        x = -70,
        y = -45
    },
    [6] = {
        x = -65,
        y = -170
    },
    [11] = {
        x = -155,
        y = -110
    },
    [17] = {
        x = -190,
        y = -20
    },
    -- Bottom Right
    [10] = {
        x = 65,
        y = -170
    },
    [12] = {
        x = 70,
        y = -45
    },
    [19] = {
        x = 190,
        y = -20
    },
    [20] = {
        x = 155,
        y = -110
    },
    -- Top Left
    [4] = {
        x = -70,
        y = 75
    },
    [7] = {
        x = -155,
        y = 150
    },
    [8] = {
        x = -190,
        y = 60
    },
    -- Top Right
    [2] = {
        x = 70,
        y = 75
    },
    [9] = {
        x = 190,
        y = 60
    },
    [16] = {
        x = 155,
        y = 150
    },
    -- Top Triangle
    [5] = {
        x = -55,
        y = 210
    },
    [14] = {
        x = 0,
        y = 90
    },
    [15] = {
        x = 55,
        y = 210
    },
    -- Bottom Triangle
    [13] = {
        x = 0,
        y = -90
    },
    [18] = {
        x = 0,
        y = -220
    }
}

local POS_MAIN_ALT = {
    -- Bottom Right
    [1] = {
        x = 25,
        y = -40
    },
    [12] = {
        x = 95,
        y = -20
    },
    [14] = {
        x = 90,
        y = -95
    },
    [15] = {
        x = 40,
        y = -200
    },
    [16] = {
        x = 200,
        y = -80
    },
    [20] = {
        x = 140,
        y = -160
    },
    -- Bottom Left
    [2] = {
        x = -90,
        y = -95
    },
    [4] = {
        x = -95,
        y = -20
    },
    [7] = {
        x = -140,
        y = -160
    },
    [9] = {
        x = -40,
        y = -200
    },
    [10] = {
        x = -200,
        y = -80
    },
    [11] = {
        x = -25,
        y = -40
    },
    -- Top Left
    [3] = {
        x = -60,
        y = 70
    },
    [5] = {
        x = -80,
        y = 190
    },
    [6] = {
        x = -180,
        y = 50
    },
    [8] = {
        x = -140,
        y = 125
    },
    -- Top Right
    [13] = {
        x = 60,
        y = 70
    },
    [17] = {
        x = 140,
        y = 125
    },
    [18] = {
        x = 80,
        y = 190
    },
    [19] = {
        x = 180,
        y = 50
    }
}

-- Shared raid-to-node swaps for both main-phase layouts.
local RAID_TO_NODE = {
    [1] = 11,
    [11] = 1,
    [2] = 7,
    [7] = 2,
    [13] = 14,
    [14] = 13,
    [3] = 8,
    [8] = 4,
    [4] = 9,
    [9] = 3,
    [5] = 10,
    [10] = 5
}

local VIS_MAIN = {
    [1] = {1, 3, 6, 11, 17},
    [2] = {2, 9, 15, 16},
    [3] = {1, 3, 6, 11, 17},
    [4] = {4, 5, 7, 8},
    [5] = {5, 14, 15},
    [6] = {1, 3, 6, 11, 17},
    [7] = {4, 5, 7, 8},
    [8] = {4, 5, 7, 8},
    [9] = {2, 9, 15, 16},
    [10] = {10, 12, 19, 20},
    [11] = {1, 3, 6, 11, 17},
    [12] = {10, 12, 19, 20},
    [13] = {6, 10, 13, 18},
    [14] = {5, 14, 15},
    [15] = {5, 14, 15},
    [16] = {2, 9, 15, 16},
    [17] = {1, 3, 6, 11, 17},
    [18] = {6, 10, 13, 18},
    [19] = {10, 12, 19, 20},
    [20] = {10, 12, 19, 20}
}

local VIS_MAIN_ALT = {
    [1] = {1, 12, 14, 15, 16, 20},
    [2] = {2, 4, 7, 9, 10, 11},
    [3] = {3, 5, 6, 8},
    [4] = {2, 4, 7, 9, 10, 11},
    [5] = {3, 5, 6, 8},
    [6] = {3, 5, 6, 8},
    [7] = {2, 4, 7, 9, 10, 11},
    [8] = {3, 5, 6, 8},
    [9] = {2, 4, 7, 9, 10, 11},
    [10] = {2, 4, 7, 9, 10, 11},
    [11] = {2, 4, 7, 9, 10, 11},
    [12] = {1, 12, 14, 15, 16, 20},
    [13] = {13, 17, 18, 19},
    [14] = {1, 12, 14, 15, 16, 20},
    [15] = {1, 12, 14, 15, 16, 20},
    [16] = {1, 12, 14, 15, 16, 20},
    [17] = {13, 17, 18, 19},
    [18] = {13, 17, 18, 19},
    [19] = {13, 17, 18, 19},
    [20] = {1, 12, 14, 15, 16, 20}
}

local W, H, PAD = 260, 260, 10

local TR = {
    anchor = "BOTTOMLEFT",
    bx = PAD,
    by = PAD,
    w = W,
    h = H,
    sweepStart = 0,
    sweepCount = 90,
    markers = {8, 2}
}
local BR = {
    anchor = "TOPLEFT",
    bx = PAD,
    by = -PAD,
    w = W,
    h = H,
    sweepStart = 90,
    sweepCount = 90,
    markers = {2, 1}
}
local BL = {
    anchor = "TOPRIGHT",
    bx = -PAD,
    by = -PAD,
    w = W,
    h = H,
    sweepStart = 180,
    sweepCount = 90,
    markers = {1, 7}
}
local TL = {
    anchor = "BOTTOMRIGHT",
    bx = -PAD,
    by = PAD,
    w = W,
    h = H,
    sweepStart = 270,
    sweepCount = 90,
    markers = {7, 8}
}
local T = {
    anchor = "BOTTOM",
    bx = 0,
    by = PAD,
    w = W,
    h = H,
    sweepStart = 330,
    sweepCount = 60,
    markers = {8}
}
local B = {
    anchor = "TOP",
    bx = 0,
    by = -PAD,
    w = W,
    h = H,
    sweepStart = 150,
    sweepCount = 60,
    markers = {1}
}

local SLICES_MAIN = {
    [1] = BL,
    [2] = TR,
    [3] = BL,
    [4] = TL,
    [5] = T,
    [6] = BL,
    [7] = TL,
    [8] = TL,
    [9] = TR,
    [10] = BR,
    [11] = BL,
    [12] = BR,
    [13] = B,
    [14] = T,
    [15] = T,
    [16] = TR,
    [17] = BL,
    [18] = B,
    [19] = BR,
    [20] = BR
}

local SLICES_MAIN_ALT = {
    [1] = BR,
    [2] = BL,
    [3] = TL,
    [4] = BL,
    [5] = TL,
    [6] = TL,
    [7] = BL,
    [8] = TL,
    [9] = BL,
    [10] = BL,
    [11] = BL,
    [12] = BR,
    [13] = TR,
    [14] = BR,
    [15] = BR,
    [16] = BR,
    [17] = TR,
    [18] = TR,
    [19] = TR,
    [20] = BR
}

local MARKERS = {
    [1] = {
        iconID = 1,
        x = 0,
        y = -135
    }, -- Skull
    [2] = {
        iconID = 2,
        x = 125,
        y = 0
    }, -- Cross
    [7] = {
        iconID = 7,
        x = -125,
        y = 0
    }, -- X
    [8] = {
        iconID = 8,
        x = 0,
        y = 135
    } -- Moon
}

-- Module

local LuraMap = E:NewModule("BossMods_LuraMap", "AceEvent-3.0", "AceTimer-3.0")

local BM

local function buildSpec(mod)
    local db = mod.db
    return {
        parent = UIParent,
        nodes = 20,
        anchors = {
            intermission = {
                defaultSize = {
                    w = 512,
                    h = 512
                },
                textureBackground = [[Interface\AddOns\AdvanceRaidTools\Media\Textures\LuraIntMap.png]],
                textureMasked = true,
                style = {
                    scale = db.anchors.intermission.scale,
                    opacity = db.anchors.intermission.opacity,
                    showBg = false
                }
            },
            main = {
                defaultSize = {
                    w = 260,
                    h = 260
                },
                style = {
                    scale = db.anchors.main.scale,
                    opacity = db.anchors.main.opacity,
                    showBg = true,
                    bgColor = db.anchors.main.bgColor,
                    bgOpacity = db.anchors.main.bgOpacity,
                    borderColor = db.anchors.main.borderColor,
                    borderOpacity = db.anchors.main.borderOpacity
                }
            }
        },
        layouts = {
            intermission = {
                anchor = "intermission",
                kind = "radial",
                positions = POS_INTERMISSION,
                raidToNodeMap = RAID_TO_NODE,
                noteBlock = "pos1"
            },
            main = {
                anchor = "main",
                kind = "manual",
                positions = POS_MAIN,
                raidToNodeMap = RAID_TO_NODE,
                noteBlock = "pos2",
                visibility = VIS_MAIN,
                slices = SLICES_MAIN,
                markers = MARKERS
            },
            mainAlt = {
                anchor = "main",
                kind = "manual",
                positions = POS_MAIN_ALT,
                raidToNodeMap = RAID_TO_NODE,
                noteBlock = "pos2",
                visibility = VIS_MAIN_ALT,
                slices = SLICES_MAIN_ALT,
                markers = MARKERS
            }
        },
        style = {
            nodeSize = 32,
            font = db.font
        }
    }
end

function LuraMap:EnsureMap()
    if self.map then
        return
    end
    self.map = BM.Engines.RaidMap(buildSpec(self))
    self:ApplyPositions()
    self.map:HideAll()
end

function LuraMap:OnInitialize()
    self.active = false
    self.scheduleTokens = {}
    self.editMode = false

    BM = BM or E:GetModule("BossMods")
    self:EnsureMap()
    self.map:Apply(buildSpec(self))
    self:ApplyPositions()
    self.map:HideAll()
end

function LuraMap:OnEnable()
    if not self.map then
        self:EnsureMap()
    end
    self.map:Apply(buildSpec(self))
    self:ApplyPositions()

    self.active = false

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function LuraMap:OnDisable()
    self:UnhookBigWigs()
    self.editMode = false
    self.active = false
    self.map:SetEditMode(false)
    self.map:HideAll()
end

function LuraMap:HookBigWigs()
    if self.bwHandle then
        return
    end
    self.bwHandle = BM.BigWigs:Subscribe({
        owner = "LuraMap",
        spellKeys = {SPELL_GALVANIZE, SPELL_CORE_HARVEST},
        onStartBar = function(key, text, time)
            self:OnBigWigsStartBar(key, text, time)
        end
    })
end

function LuraMap:UnhookBigWigs()
    if not self.bwHandle then
        return
    end
    self.bwHandle:Unsubscribe()
    self.bwHandle = nil
end

function LuraMap:ApplyPositions()
    for key, anchor in pairs(self.map.anchors) do
        local pos = self.db.anchors[key] and self.db.anchors[key].position
        if pos then
            E:ApplyFramePosition(anchor, pos)
        end
    end
end

function LuraMap:SavePosition(anchorKey, pos)
    self.db.anchors[anchorKey].position.point = pos.point
    self.db.anchors[anchorKey].position.x = pos.x
    self.db.anchors[anchorKey].position.y = pos.y
    self:ApplyPositions()
end

function LuraMap:Refresh()
    if not self:IsEnabled() then
        return
    end
    self.map:Apply(buildSpec(self))
    self:ApplyPositions()
end

-- Triggers

function LuraMap:OnEncounterStart(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= MYTHIC_DIFFICULTY then
        return
    end

    self.active = true
    self.scheduleTokens = {}
    self.map:HideAll()

    self:HookBigWigs()
    self:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED", "OnTimelineEvent")
end

function LuraMap:OnEncounterEnd()
    if not self.active then
        return
    end
    self.active = false
    self.scheduleTokens = {}
    self:UnhookBigWigs()
    self:UnregisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
    self.map:HideAll()
end

function LuraMap:OnTimelineEvent(_, info)
    if not self.active or not info then
        return
    end
    if Enum and Enum.EncounterTimelineEventSource and info.source ~= Enum.EncounterTimelineEventSource.Encounter then
        return
    end
    if info.duration == PHASE_1_DURATION and self.db.anchors.intermission.enabled then
        self:ShowMapTimed("intermission", 0, INTERMISSION_HIDE)
    end
end

function LuraMap:OnBigWigsStartBar(key, text, time)
    if not self.active then
        return
    end
    if not self.db.anchors.main.enabled then
        return
    end
    if type(time) ~= "number" or time <= 0 then
        return
    end

    local countStr = type(text) == "string" and text:match("%((%d+)%)") or nil
    local count = tonumber(countStr) or 1

    if key == SPELL_GALVANIZE and count <= 3 then
        self:ShowMapTimed("main", time + 6, MAIN_HIDE)
    elseif key == SPELL_CORE_HARVEST and count == 3 then
        self:ShowMapTimed("mainAlt", time, MAIN_ALT_HIDE)
    end
end

function LuraMap:ShowMapTimed(layoutKey, delay, duration)
    local t = (self.scheduleTokens[layoutKey] or 0) + 1
    self.scheduleTokens[layoutKey] = t

    local function show()
        if self.scheduleTokens[layoutKey] ~= t or not self.active then
            return
        end
        self.map:Show(layoutKey)
        local hideT = self.scheduleTokens[layoutKey]
        self:ScheduleTimer(function()
            if self.scheduleTokens[layoutKey] ~= hideT then
                return
            end
            self.map:Hide(layoutKey)
        end, duration)
    end

    if delay <= 0 then
        show()
    else
        self:ScheduleTimer(show, delay)
    end
end

-- Edit

function LuraMap:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false
    if self.editMode then
        self.map:SetEditMode(true)
        if not self.active then
            self.map:HideAll()
        end
        for key in pairs(self.db.anchors) do
            self.map:Show(key)
        end
    else
        self.map:SetEditMode(false)
        if not self.active then
            self.map:HideAll()
        end
    end
end

E:RegisterBossModFeature("LuraMap", {
    tab = "Queldanas",
    order = 40,
    labelKey = "BossMods_LuraMap",
    descKey = "BossMods_LuraMapDesc",
    moduleName = "BossMods_LuraMap"
})
