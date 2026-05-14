local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_PrivateAuraList", {
    enabled = false,
    position = {
        point = "CENTER",
        x = -360,
        y = 0
    },
    layout = {
        width = 150,
        rowHeight = 22,
        rowGap = 2,
        auraSlots = 3,
        previewRows = 5
    },
    privateAuras = {
        showDurationText = true,
        cooldownTextScale = 1,
        showBorder = true,
        customBorder = {
            enabled = true,
            texture = "Pixel",
            size = 1,
            color = {0, 0, 0, 1},
            opacity = 1
        }
    },
    style = {
        classColorAlpha = 0.62,
        font = {
            size = 12,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        },
        background = {
            enabled = false,
            color = {0, 0, 0},
            opacity = 0.45
        },
        border = {
            enabled = false,
            texture = "Pixel",
            size = 1,
            color = {0, 0, 0, 1},
            opacity = 1
        }
    },
    excluded = {}
})

local Mod = E:NewModule("BossMods_PrivateAuraList", "AceEvent-3.0")

local function addPlayerUnit(units, unit)
    if UnitInPartyIsAI and UnitInPartyIsAI(unit) then
        return
    end
    if UnitExists(unit) and UnitIsPlayer(unit) then
        units[#units + 1] = unit
    end
end

local function groupUnits()
    local units = {}
    local n = GetNumGroupMembers() or 0

    if IsInRaid() then
        for i = 1, n do
            addPlayerUnit(units, "raid" .. i)
        end
    elseif IsInGroup() then
        addPlayerUnit(units, "player")
        for i = 1, math.max(0, n - 1) do
            addPlayerUnit(units, "party" .. i)
        end
    else
        addPlayerUnit(units, "player")
    end

    return units
end

local function unitKey(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end
    return E:GetUnitFullName(unit, true)
end

local function unitDisplayName(unit)
    if E.GetNickname then
        local nick = E:GetNickname(unit)
        if nick and nick ~= "" then
            return nick
        end
    end
    local name = UnitNameUnmodified and UnitNameUnmodified(unit) or UnitName(unit)
    name = E:SafeString(name)
    if name and name ~= "" and name ~= UNKNOWN and name ~= UNKNOWNOBJECT then
        return name
    end
    local key = unitKey(unit)
    return key and E:BareName(key) or nil
end

local function unitClass(unit, key, displayName)
    local classFile = UnitClassBase and UnitClassBase(unit)
    if not classFile then
        local _, fallback = UnitClass(unit)
        classFile = fallback
    end
    classFile = E:SafeString(classFile)
    if classFile then
        return classFile
    end
    if E.GetClassByName then
        return E:GetClassByName(key) or E:GetClassByName(displayName)
    end
    return nil
end

local function buildEngineConfig(self)
    return {
        parent = UIParent,
        getUnits = groupUnits,
        isExcluded = function(unit)
            return self:IsUnitExcluded(unit)
        end,
        layout = self.db.layout,
        privateAuras = self.db.privateAuras,
        style = self.db.style
    }
end

function Mod:EnsureDisplay()
    local BossMods = E:GetModule("BossMods")
    if not (BossMods and BossMods.Engines and BossMods.Engines.PrivateAuraList) then
        return
    end
    if not self.display then
        self.display = BossMods.Engines.PrivateAuraList(buildEngineConfig(self))
    end
end

function Mod:OnEnable()
    self:EnsureDisplay()
    if self.display then
        self.display:Apply(buildEngineConfig(self))
        self:ApplyPosition()
        self.display:SetActive(true)
    end

    self:RegisterEvent("GROUP_LEFT", "OnGroupLeft")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function Mod:OnDisable()
    if self.display then
        self.display:SetEditMode(false)
        self.display:SetActive(false)
    end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

function Mod:ApplyPosition()
    if not self.display then
        return
    end
    E:ApplyFramePosition(self.display.frame, self.db.position)
end

function Mod:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:EnsureDisplay()
    if self.display then
        self.display:Apply(buildEngineConfig(self))
        self:ApplyPosition()
    end
end

function Mod:OnGroupLeft()
    if self.display then
        self.display:Clear()
    end
end

function Mod:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self:EnsureDisplay()
    if self.display then
        self.display:SetEditMode(v)
    end
end

function Mod:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

function Mod:IsUnitExcluded(unit)
    local key = unitKey(unit)
    return key and self.db.excluded[key] and true or false
end

function Mod:SetPlayerIncluded(key, included)
    if not key or key == "" then
        return
    end
    if included then
        self.db.excluded[key] = nil
    else
        self.db.excluded[key] = true
    end
    self:Refresh()
end

function Mod:ClearExclusions()
    wipe(self.db.excluded)
    self:Refresh()
end

function Mod:GetRosterEntries()
    local entries = {}
    local seen = {}

    for _, unit in ipairs(groupUnits()) do
        if UnitExists(unit) then
            local key = unitKey(unit)
            if key and not seen[key] then
                seen[key] = true
                local displayName = unitDisplayName(unit)
                local classFile = unitClass(unit, key, displayName)

                if displayName and classFile then
                    entries[#entries + 1] = {
                        unit = unit,
                        key = key,
                        displayName = displayName,
                        classFile = classFile,
                        included = not self.db.excluded[key]
                    }
                end
            end
        end
    end

    table.sort(entries, function(a, b)
        if IsInRaid() then
            local ai = UnitInRaid(a.unit) or 99
            local bi = UnitInRaid(b.unit) or 99
            if ai ~= bi then
                return ai < bi
            end
        end
        return (a.displayName or "") < (b.displayName or "")
    end)

    return entries
end

E:RegisterBossModFeature("PrivateAuraList", {
    tab = "General",
    order = 30,
    labelKey = "BossMods_PrivateAuraList",
    descKey = "BossMods_PrivateAuraListDesc",
    moduleName = "BossMods_PrivateAuraList"
})
