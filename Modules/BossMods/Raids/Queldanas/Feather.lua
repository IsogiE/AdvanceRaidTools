local E, L, P = unpack(ART)

P.modules.BossMods_Feather = {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 400
    },
    iconSize = 64,
    border = {
        enabled = false,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    }
}

local ENCOUNTER_ID = 3182
local PLACEHOLDER_SPELL = 1241162
local FALLBACK_ICON = 132136

local Feather = E:NewModule("BossMods_Feather", "AceEvent-3.0")

function Feather:OnModuleInitialize()
    self.editMode = false
    self.active = false
    self.currentAura = nil
    self:EnsureFrame()
    self:Apply()
    self.frame:Hide()
end

function Feather:OnEnable()
    if not self.frame then
        self:EnsureFrame()
    end
    self:Apply()

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function Feather:OnDisable()
    self.editMode = false
    self.active = false
    self.currentAura = nil
    self.frame:Hide()
end

function Feather:EnsureFrame()
    if self.frame then
        return
    end
    local f = CreateFrame("Frame", "ART_BossMods_Feather", UIParent, "BackdropTemplate")
    f:SetSize(self.db.iconSize, self.db.iconSize)
    f:SetFrameStrata("MEDIUM")
    f:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    self.frame = f
end

function Feather:ApplyBackdrop()
    local db = self.db
    local f = self.frame
    local border = db.border or {}

    local borderEnabled = border.enabled and true or false
    local edgeFile = E:FetchBorder(border.texture)
    local edgeSize = math.min(border.size or 1, 16)
    local er, eg, eb, ea = E:ColorTuple(border.color, 0, 0, 0, 1)

    E:ApplyOuterBorder(f, {
        enabled = borderEnabled,
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        r = er,
        g = eg,
        b = eb,
        a = ea
    })
end

function Feather:Apply()
    local db = self.db
    local f = self.frame
    f:SetSize(db.iconSize, db.iconSize)
    f:ClearAllPoints()
    f:SetPoint(db.position.point or "CENTER", UIParent, db.position.point or "CENTER", db.position.x or 0,
        db.position.y or 0)
    self:ApplyBackdrop()
end

function Feather:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:Apply()
end

function Feather:OnEncounterStart(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end
    self.active = true
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:CheckPlayerAuras()
end

function Feather:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end
    self.active = false
    self:UnregisterEvent("UNIT_AURA")
    self.currentAura = nil
    if not self.editMode then
        self.frame:Hide()
    end
end

function Feather:OnUnitAura(_, unit, info)
    if unit ~= "player" then
        return
    end
    if info.isFullUpdate or info.addedAuras or info.removedAuraInstanceIDs then
        self:CheckPlayerAuras()
    end
end

function Feather:CheckPlayerAuras()
    self.currentAura = nil
    self.frame:Hide()

    local playerCastSet = {}
    local playerCastIDs = C_UnitAuras.GetUnitAuraInstanceIDs("player", "HARMFUL|PLAYER")
    if playerCastIDs then
        for _, iid in ipairs(playerCastIDs) do
            playerCastSet[iid] = true
        end
    end

    local auras = C_UnitAuras.GetUnitAuras("player", "HARMFUL", 10, Enum.UnitAuraSortRule.ExpirationOnly,
        Enum.UnitAuraSortDirection.Reverse)

    if auras then
        for _, aura in ipairs(auras) do
            if not playerCastSet[aura.auraInstanceID] then
                self.currentAura = aura.auraInstanceID
                self.frame.icon:SetTexture(aura.icon)
                self.frame:Show()
                return
            end
        end
    end
end

function Feather:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false

    if self.editMode then
        local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(PLACEHOLDER_SPELL) or FALLBACK_ICON
        self.frame.icon:SetTexture(tex)
        self.frame:Show()
    else
        if self.currentAura then
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", self.currentAura)
            if aura then
                self.frame.icon:SetTexture(aura.icon)
            else
                self.frame:Hide()
                self.currentAura = nil
            end
        else
            self.frame:Hide()
        end
    end
end

function Feather:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:Apply()
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("Feather", {
            tab = "Queldanas",
            order = 10,
            labelKey = "BossMods_Feather",
            descKey = "BossMods_FeatherDesc",
            moduleName = "BossMods_Feather"
        })
    end
end
