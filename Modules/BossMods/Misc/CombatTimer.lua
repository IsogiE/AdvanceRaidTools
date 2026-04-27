local E, L, P = unpack(ART)

P.modules.BossMods_CombatTimer = {
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
        color = {0, 0, 0, 0}
    },
    border = {
        enabled = false,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    }
}

local CombatTimer = E:NewModule("BossMods_CombatTimer", "AceEvent-3.0")

local BM

local function buildBarConfig(db)
    return {
        parent = UIParent,
        showFill = false,
        strata = "HIGH",
        autoSize = true,
        autoSizePad = 6,
        center = {
            size = db.font.size,
            outline = db.font.outline,
            justify = db.font.justify,
            color = db.font.color
        },
        background = db.background,
        border = db.border
    }
end

function CombatTimer:EnsureBar()
    if self.bar then
        return
    end
    self.bar = BM.Engines.Bar(buildBarConfig(self.db))
    self.bar.onTick = function(t)
        self.bar:SetCenter(("%d:%02d"):format(math.floor(t / 60), math.floor(t % 60)))
    end
    self:ApplyPosition()
    self.bar:Hide()
end

function CombatTimer:OnModuleInitialize()
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
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    if UnitAffectingCombat("player") then
        self:OnCombatStart()
    end
end

function CombatTimer:OnDisable()
    self.editMode = false
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

    if self.editMode then
        if self.bar:IsRunning() then
            self.bar:Stop()
        end
        self.bar:SetCenter("0:00")
        self.bar:Show()
    else
        if UnitAffectingCombat("player") then
            self:OnCombatStart()
        else
            self.bar:Stop()
            self.bar:Hide()
        end
    end
end

function CombatTimer:ApplyPosition()
    if not self.bar then
        return
    end
    local pos = self.db.position
    local f = self.bar.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
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
    if not self.bar then
        return
    end

    self.bar:Start({
        total = 86400
    })
    self.bar:SetCenter("0:00")
end

function CombatTimer:OnCombatEnd()
    if not self.bar then
        return
    end
    self.bar:Stop()
    self.bar:Hide()
end

function CombatTimer:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("CombatTimer", {
            tab = "Misc",
            order = 10,
            labelKey = "BossMods_CombatTimer",
            descKey = "BossMods_CombatTimerDesc",
            moduleName = "BossMods_CombatTimer"
        })
    end
end
