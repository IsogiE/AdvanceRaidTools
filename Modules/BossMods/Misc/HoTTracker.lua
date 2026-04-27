local E, L, P = unpack(ART)

P.modules.BossMods_HoTTracker = {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 150
    },
    layout = {
        iconSize = 36,
        iconPad = 4,
        anchorSize = {
            w = 200,
            h = 44
        }
    },
    visibility = {
        showWhen = "always"
    },
    enabledKeys = {},
    style = {
        iconOpacity = 1.0,
        background = {
            enabled = false,
            color = {0, 0, 0},
            opacity = 0.5
        },
        border = {
            enabled = false,
            texture = "Pixel",
            size = 1,
            color = {0, 0, 0, 1},
            opacity = 1.0
        },
        count = {
            enabled = true,
            anchor = "TOPLEFT",
            offsetX = 1,
            offsetY = -1,
            size = 11,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        },
        timer = {
            enabled = true,
            anchor = "BOTTOMRIGHT",
            offsetX = -1,
            offsetY = 1,
            size = 10,
            outline = "OUTLINE",
            color = {1, 0.8, 0, 1},
            decimals = 1
        }
    }
}

local CLASS_SPELLS = {
    EVOKER = {{
        id = 364343,
        key = "echo",
        name = "Echo",
        color = {0.4, 0.8, 1},
        specIDs = {1468}
    }, {
        id = 366155,
        key = "reversion",
        name = "Reversion",
        color = {0.2, 1, 0.6},
        specIDs = {1468}
    }, {
        id = 367364,
        key = "reversion",
        name = "Echo Reversion",
        color = {0.2, 1, 0.6},
        specIDs = {1468},
        hidden = true
    }},
    DRUID = {{
        id = 774,
        key = "rejuv",
        name = "Rejuvenation",
        color = {0.2, 1, 0.3},
        specIDs = {105}
    }, {
        id = 155777,
        key = "rejuv",
        name = "Germination",
        color = {0.1, 0.9, 0.2},
        specIDs = {105},
        hidden = true
    }},
    MONK = {{
        id = 119611,
        key = "renewingmist",
        name = "Renewing Mist",
        color = {0.4, 0.9, 1},
        specIDs = {270}
    }},
    SHAMAN = {{
        id = 61295,
        key = "riptide",
        name = "Riptide",
        color = {0.2, 0.6, 1},
        specIDs = {264}
    }},
    PRIEST = {{
        id = 194384,
        key = "atonement",
        name = "Atonement",
        color = {0.9, 0.5, 1},
        specIDs = {256}
    }},
    PALADIN = {{
        id = 156322,
        key = "eternalflame",
        name = "Eternal Flame",
        color = {1, 0.8, 0.2},
        specIDs = {65}
    }, {
        id = 1244893,
        key = "bsavior",
        name = "Beacon of the Savior",
        color = {1, 0.8, 0.2},
        specIDs = {65}
    }}
}

local HoTTracker = E:NewModule("BossMods_HoTTracker", "AceEvent-3.0")

local BM

local CLASS_ORDER = {"DRUID", "EVOKER", "MONK", "PALADIN", "PRIEST", "SHAMAN"}

function HoTTracker:GetAvailableSpells()
    local seen = {}
    local out = {}
    for _, class in ipairs(CLASS_ORDER) do
        local spells = CLASS_SPELLS[class]
        if spells then
            for _, sp in ipairs(spells) do
                if not sp.hidden and not seen[sp.key] then
                    seen[sp.key] = true
                    out[#out + 1] = {
                        key = sp.key,
                        name = sp.name,
                        color = sp.color,
                        class = class
                    }
                end
            end
        end
    end
    return out
end

local function buildEngineConfig(mod)
    local _, class = UnitClass("player")
    local db = mod.db
    return {
        parent = UIParent,
        spec = {
            spells = CLASS_SPELLS[class] or {},
            filter = "HELPFUL|PLAYER",
            combatFilter = "HELPFUL"
        },
        layout = db.layout,
        visibility = {
            showWhen = db.visibility.showWhen,
            enabledKeys = db.enabledKeys
        },
        style = db.style
    }
end

function HoTTracker:EnsureDisplay()
    if self.display then
        return
    end
    self.display = BM.Engines.AuraDisplay(buildEngineConfig(self))
    self:ApplyPosition()
end

function HoTTracker:OnModuleInitialize()
    BM = BM or E:GetModule("BossMods")
    self:EnsureDisplay()
    if self.display then
        self.display:Apply(buildEngineConfig(self))
        self:ApplyPosition()
        self.display:SetActive(false)
    end
end

function HoTTracker:OnEnable()
    if not self.display then
        self:EnsureDisplay()
    end
    if self.display then
        self.display:Apply(buildEngineConfig(self))
        self:ApplyPosition()
        self.display:SetActive(true)
    end

    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function HoTTracker:OnDisable()
    if self.display then
        self.display:SetEditMode(false)
        self.display:SetActive(false)
    end
end

function HoTTracker:ApplyPosition()
    if not self.display then
        return
    end
    local pos = self.db.position
    local f = self.display.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function HoTTracker:Refresh()
    if not self:IsEnabled() or not self.display then
        return
    end
    self.display:Apply(buildEngineConfig(self))
    self:ApplyPosition()
end

function HoTTracker:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    if self.display then
        self.display:SetEditMode(v)
    end
end

function HoTTracker:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("HoTTracker", {
            tab = "Misc",
            order = 20,
            labelKey = "BossMods_HoTTracker",
            descKey = "BossMods_HoTTrackerDesc",
            moduleName = "BossMods_HoTTracker"
        })
    end
end
