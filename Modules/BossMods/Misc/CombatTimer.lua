local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_CombatTimer", {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 0
    },
    font = {
        size = 20,
        outline = "OUTLINE",
        justify = "CENTER",
        color = {1, 1, 1, 1}
    },
    background = {
        enabled = false,
        color = {0, 0, 0},
        opacity = 0.5
    },
    border = {
        enabled = false,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    }
})

local CombatTimer = E:NewModule("BossMods_CombatTimer", "AceEvent-3.0")

local BM

local function buildBarConfig(db)
    local bg = db.background
    local bgC = bg.color or {}
    local bgR = bgC[1] or bgC.r or 0
    local bgG = bgC[2] or bgC.g or 0
    local bgB = bgC[3] or bgC.b or 0
    local bgA = bg.enabled and (bg.opacity or 0.5) or 0
    return {
        parent = UIParent,
        showFill = false,
        strata = "HIGH",
        autoSize = true,
        center = {
            size = db.font.size,
            outline = db.font.outline,
            justify = "CENTER",
            color = db.font.color
        },
        background = {
            color = {bgR, bgG, bgB, bgA}
        },
        border = db.border
    }
end

function CombatTimer:EnsureBar()
    if self.bar then
        return
    end
    self.bar = BM.Engines.Bar(buildBarConfig(self.db))
    self.bar.onTick = function(t)
        local second = math.floor(math.max(0, t))
        if second == self.lastSecond then
            return
        end
        self.lastSecond = second
        self.bar:SetCenter(("%d:%02d"):format(math.floor(second / 60), second % 60))
    end
    self:ApplyPosition()
    self.bar:Hide()
end

function CombatTimer:OnInitialize()
    BM = BM or E:GetModule("BossMods")
    self:EnsureBar()
    if self.bar then
        self.bar:Apply(buildBarConfig(self.db))
        self:ApplyPosition()
        self.bar:Hide()
    end
end

function CombatTimer:OnEnable()
    if not self.bar then
        self:EnsureBar()
    end
    if self.bar then
        self.bar:Apply(buildBarConfig(self.db))
        self:ApplyPosition()
    end

    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    local phaseTimers = E:GetModule("PhaseTimers", true)
    self.encounterStartTime = phaseTimers and phaseTimers.encounterStartTime or nil
    if self.encounterStartTime then
        self:UpdateTimer()
    elseif UnitAffectingCombat("player") then
        self:OnCombatStart()
    end
end

function CombatTimer:OnDisable()
    self.editMode = false
    self.encounterStartTime = nil
    self.combatStartTime = nil
    if self.bar then
        self.bar:Stop()
        self.bar:Hide()
    end
end

function CombatTimer:SetEditMode(v)
    if not self:IsEnabled() or not self.bar then
        return
    end
    self.editMode = v and true or false
    self:UpdateTimer()
end

function CombatTimer:UpdateTimer()
    if not self.bar then
        return
    end

    self.lastSecond = nil
    if self.editMode then
        self.bar:Stop()
        self.bar:SetCenter("0:00")
        self.bar:Show()
        return
    end

    local startTime = self.encounterStartTime or self.combatStartTime
    if startTime then
        self.bar:Start({
            total = 86400,
            lead = startTime - GetTime()
        })
    else
        self.bar:Stop()
        self.bar:Hide()
    end
end

function CombatTimer:ApplyPosition()
    if not self.bar then
        return
    end
    local pos = self.db.position
    local f = self.bar.frame
    E:ApplyFramePosition(f, pos)
end

function CombatTimer:Refresh()
    if not self:IsEnabled() then
        return
    end
    if not self.bar then
        return
    end
    self.bar:Apply(buildBarConfig(self.db))
    self:ApplyPosition()
end

function CombatTimer:OnCombatStart()
    if self.encounterStartTime then
        return
    end
    self.combatStartTime = self.combatStartTime or GetTime()
    self:UpdateTimer()
end

function CombatTimer:OnCombatEnd()
    self.combatStartTime = nil
    if self.encounterStartTime then
        return
    end
    self:UpdateTimer()
end

function CombatTimer:OnEncounterStart()
    self.encounterStartTime = GetTime()
    self.combatStartTime = nil
    self:UpdateTimer()
end

function CombatTimer:OnEncounterEnd()
    self.encounterStartTime = nil
    self.combatStartTime = nil
    self:UpdateTimer()
end

function CombatTimer:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

E:RegisterBossModFeature("CombatTimer", {
    tab = "Misc",
    order = 10,
    labelKey = "BossMods_CombatTimer",
    descKey = "BossMods_CombatTimerDesc",
    moduleName = "BossMods_CombatTimer"
})
