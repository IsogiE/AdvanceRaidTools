local E, L, P = unpack(ART)

P.modules.BossMods_PalaDispel = {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 0
    },
    size = {
        w = 400,
        h = 80
    },
    font = {
        size = 28,
        outline = "OUTLINE"
    },
    colors = {
        action = {0, 1, 0, 1},
        dwarf = {1, 0.84, 0, 1},
        nameMode = "class",
        nameCustom = {1, 0.27, 1, 1}
    },
    glow = {
        glowType = "Pixel",
        color = {0.247, 0.988, 0.247, 1},
        lines = 10,
        thickness = 3,
        frequency = 3,
        scale = 10
    },
    audio = {
        type = "sound",
        sound = "None",
        channel = "Master",
        voice = 0
    }
}

local ENCOUNTER_ID = 3180
local GLOW_KEY = "ART_PalaDispel"
local DWARF_RACIAL_COOLDOWN = 121
local DWARF_RACE_IDS = {
    [3] = true,
    [34] = true
} -- Dwarf, Dark Iron Dwarf
local WARLOCK_CLASS_ID = 9
local ASSIGN_DEBOUNCE = 0.25
local AUTO_CLEAR_SECONDS = 9
local DWARF_RACIAL_SPELLS = {
    [20594] = true,
    [265221] = true
}
local MAX_AFFECTED = 15

local function isKnownGroupUnit(unit)
    if type(unit) ~= "string" then
        return false
    end
    if unit == "player" then
        return true
    end
    if unit:match("^raid%d+$") then
        return true
    end
    if unit:match("^party%d+$") then
        return true
    end
    return false
end

local function toHex(color)
    local r = (color[1] or color.r or 1) * 255
    local g = (color[2] or color.g or 1) * 255
    local b = (color[3] or color.b or 1) * 255
    return ("%02x%02x%02x"):format(r, g, b)
end

local PalaDispel = E:NewModule("BossMods_PalaDispel", "AceEvent-3.0", "AceTimer-3.0")

local BM

local function buildAlertConfig(mod)
    local db = mod.db
    return {
        parent = UIParent,
        strata = "MEDIUM",
        size = {
            w = db.size.w,
            h = db.size.h
        },
        font = {
            size = db.font.size,
            outline = db.font.outline,
            color = {1, 1, 1, 1}
        }
    }
end

function PalaDispel:EnsureAlert()
    if self.alert then
        return
    end
    self.alert = BM.Engines.TextAlert(buildAlertConfig(self))
    self.alert:Hide()
    self:ApplyPosition()
end

function PalaDispel:OnModuleInitialize()
    self.active = false
    self.affected = {}
    self.healers = {}
    self.dwarfs = {}
    self.myAssignedUnit = nil
    self.myAssignedAuraID = nil
    self.editMode = false

    BM = BM or E:GetModule("BossMods")
    self:EnsureAlert()
    self.alert:Apply(buildAlertConfig(self))
    self:ApplyPosition()
    self.alert:Hide()
end

function PalaDispel:OnEnable()
    if not self.alert then
        self:EnsureAlert()
    end
    self.alert:Apply(buildAlertConfig(self))
    self:ApplyPosition()

    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function PalaDispel:OnDisable()
    if self.editMode then
        self:RemoveGlow("player")
        self.alert.frame:SetBackdrop(nil)
        self.editMode = false
    end
    self:ClearAssignmentUI()
    self.alert:Hide()
    wipe(self.affected)
    wipe(self.healers)
    wipe(self.dwarfs)
    self.myAssignedUnit = nil
    self.myAssignedAuraID = nil
    self.active = false
end

function PalaDispel:ApplyPosition()
    local pos = self.db.position
    local f = self.alert.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function PalaDispel:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

function PalaDispel:Refresh()
    if not self:IsEnabled() then
        return
    end
    self.alert:Apply(buildAlertConfig(self))
    self:ApplyPosition()

    if self.editMode then
        self.alert:SetText(self:FormatAlertText("Dispel", false, "player"))
        self:ApplyGlow("player")
    elseif self.myAssignedUnit then
        self.alert:SetText(self:FormatAlertText("Dispel", false, self.myAssignedUnit))
        self:ApplyGlow(self.myAssignedUnit)
    end
end

-- Roster

function PalaDispel:BuildRoster()
    wipe(self.healers)
    wipe(self.dwarfs)

    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. i
        end
    else
        units[#units + 1] = "player"
        for i = 1, (GetNumGroupMembers() or 1) - 1 do
            units[#units + 1] = "party" .. i
        end
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            if UnitGroupRolesAssigned(unit) == "HEALER" then
                self.healers[#self.healers + 1] = unit
            end
            local _, _, raceID = UnitRace(unit)
            if raceID and DWARF_RACE_IDS[raceID] then
                self.dwarfs[unit] = self.dwarfs[unit] or 0
            end
        end
    end

    -- Warlocks added AFTER healers
    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local _, _, classID = UnitClass(unit)
            if classID == WARLOCK_CLASS_ID then
                self.healers[#self.healers + 1] = unit
            end
        end
    end
end

-- lifecycle

function PalaDispel:OnEncounterStart(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end

    if self.editMode then
        self:RemoveGlow("player")
        self.alert.frame:SetBackdrop(nil)
        self.editMode = false
    end

    self.active = true
    wipe(self.affected)
    self:ClearAssignmentUI()
    self:BuildRoster()

    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellcastSucceeded")
end

function PalaDispel:OnEncounterEnd(_, encounterID)
    if encounterID ~= ENCOUNTER_ID then
        return
    end
    self.active = false
    wipe(self.affected)
    self:ClearAssignmentUI()
    self:CancelAssignTimer()

    self:UnregisterEvent("UNIT_AURA")
    self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end

-- Aura

function PalaDispel:OnUnitAura(_, unit, info)
    if not self.active then
        return
    end
    if not isKnownGroupUnit(unit) then
        return
    end

    if info.addedAuras then
        local triggered = false
        for _, aura in ipairs(info.addedAuras) do
            local iid = aura.auraInstanceID
            local isDebuff = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, iid, "HARMFUL")
            if isDebuff and aura.dispelName ~= nil then
                local index = UnitInRaid(unit) or 999
                local isDwarf = self.dwarfs[unit] ~= nil

                local already = false
                for _, v in ipairs(self.affected) do
                    if v[3] == iid then
                        already = true
                        break
                    end
                end

                if not already then
                    self.affected[#self.affected + 1] = {unit, index, iid, false, isDwarf}
                    triggered = true
                end
            end
        end

        if triggered then
            self:CancelAssignTimer()
            self.assignTimer = self:ScheduleTimer("RunAssignment", ASSIGN_DEBOUNCE)
        end
    end

    if info.removedAuraInstanceIDs and self.myAssignedAuraID and self.myAssignedUnit and
        UnitIsUnit(unit, self.myAssignedUnit) then
        for _, id in ipairs(info.removedAuraInstanceIDs) do
            if id == self.myAssignedAuraID then
                self:ClearAssignmentUI()
                break
            end
        end
    end
end

function PalaDispel:OnSpellcastSucceeded(_, unit, _, spellID)
    if not isKnownGroupUnit(unit) then
        return
    end
    if not UnitIsUnit(unit, "player") then
        return
    end
    if DWARF_RACIAL_SPELLS[spellID] then
        self:ClearAssignmentUI()
    end
end

function PalaDispel:CancelAssignTimer()
    if self.assignTimer then
        self:CancelTimer(self.assignTimer)
        self.assignTimer = nil
    end
end

-- Assignment

function PalaDispel:RunAssignment()
    self.assignTimer = nil
    self:ClearAssignmentUI()

    if #self.affected > MAX_AFFECTED then
        wipe(self.affected)
        return
    end

    table.sort(self.affected, function(a, b)
        local aDwarf = a[5] and 1 or 0
        local bDwarf = b[5] and 1 or 0
        if aDwarf ~= bDwarf then
            return aDwarf < bDwarf
        end
        if a[2] == b[2] then
            return a[3] < b[3]
        end
        return (a[2] or 999) < (b[2] or 999)
    end)

    local available = {}
    for _, healer in ipairs(self.healers) do
        if not UnitIsDeadOrGhost(healer) then
            available[#available + 1] = healer
        end
    end

    local slotTaken = {}
    local healerUsed = {}

    -- any healer debuffed themselves self-dispels first
    for ai, healer in ipairs(available) do
        for si, entry in ipairs(self.affected) do
            if not slotTaken[si] and UnitIsUnit(entry[1], healer) then
                slotTaken[si] = true
                healerUsed[ai] = true
                if UnitIsUnit(healer, "player") then
                    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(entry[1], entry[3])
                    if aura then
                        self:ShowAssignment(entry[1], entry[3], "Dispel", false)
                    end
                end
                break
            end
        end
    end

    -- round-robin the remaining debuffs
    local nextSlot = 1
    for ai, healer in ipairs(available) do
        if not healerUsed[ai] then
            while nextSlot <= #self.affected and slotTaken[nextSlot] do
                nextSlot = nextSlot + 1
            end
            if nextSlot > #self.affected then
                break
            end

            local entry = self.affected[nextSlot]
            slotTaken[nextSlot] = true
            healerUsed[ai] = true
            nextSlot = nextSlot + 1

            if UnitIsUnit(healer, "player") then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(entry[1], entry[3])
                if aura then
                    self:ShowAssignment(entry[1], entry[3], "Dispel", false)
                end
            end
        end
    end

    -- Dwarf self-dispel: if I'm dwarf, debuffed, unassigned, and off cooldown
    local now = GetTime()
    for si, entry in ipairs(self.affected) do
        if entry[5] and not slotTaken[si] and UnitIsUnit(entry[1], "player") then
            if not self.dwarfs["player"] or now >= self.dwarfs["player"] then
                self.dwarfs["player"] = now + DWARF_RACIAL_COOLDOWN
                self:ShowAssignment("player", entry[3], "USE DWARF", true)
            end
            break
        end
    end

    wipe(self.affected)
end

-- UI

function PalaDispel:FormatAlertText(actionText, isDwarf, targetUnit)
    local actionColor = isDwarf and self.db.colors.dwarf or self.db.colors.action
    local actionHex = toHex(actionColor)

    if isDwarf then
        return ("|cff%s%s|r"):format(actionHex, actionText)
    end

    local name = "Unknown"
    if targetUnit then
        local raw = UnitName(targetUnit)
        if raw then
            name = BM.NoteBlock:GetDisplayName(raw) or raw
        end
    end

    local nameHex = "ffffffff"
    if self.db.colors.nameMode == "class" and targetUnit then
        local _, classFile = UnitClass(targetUnit)
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            nameHex = RAID_CLASS_COLORS[classFile].colorStr:sub(3)
        end
    else
        nameHex = toHex(self.db.colors.nameCustom)
    end

    return ("|cff%s%s|r |cff%s%s|r"):format(actionHex, actionText, nameHex, name)
end

function PalaDispel:ShowAssignment(unit, auraID, actionText, isDwarf)
    self:ClearAssignmentUI()

    if not isDwarf then
        self.myAssignedUnit = unit
        self.myAssignedAuraID = auraID
    end

    self.alert:SetText(self:FormatAlertText(actionText, isDwarf, unit))
    self.alert:Show()

    if self.myAssignedUnit then
        self:ApplyGlow(self.myAssignedUnit)
    end

    local ttsText
    if isDwarf then
        ttsText = "Use Dwarf"
    else
        local raw = UnitName(unit)
        local display = raw and BM.NoteBlock:GetDisplayName(raw) or "Unknown"
        ttsText = "Dispel " .. (display or "Unknown")
    end
    self:PlayAudio(ttsText)

    self:CancelClearTimer()
    self.clearTimer = self:ScheduleTimer("AutoClear", AUTO_CLEAR_SECONDS)
end

function PalaDispel:AutoClear()
    self:ClearAssignmentUI()
end

function PalaDispel:ClearAssignmentUI()
    if self.myAssignedUnit then
        self:RemoveGlow(self.myAssignedUnit)
    end
    self.myAssignedUnit = nil
    self.myAssignedAuraID = nil
    self:CancelClearTimer()
    if not self.editMode then
        self.alert:Hide()
    end
end

function PalaDispel:CancelClearTimer()
    if self.clearTimer then
        self:CancelTimer(self.clearTimer)
        self.clearTimer = nil
    end
end

-- Glow / audio

function PalaDispel:ApplyGlow(unit)
    local g = self.db.glow
    BM.Alerts:StartGlow({
        unit = unit,
        glowType = g.glowType,
        color = g.color,
        lines = g.lines,
        thickness = g.thickness,
        frequency = (g.frequency or 3) / 10,
        scale = (g.scale or 10) / 10,
        key = GLOW_KEY
    })
end

function PalaDispel:RemoveGlow(unit)
    BM.Alerts:StopGlow({
        unit = unit,
        key = GLOW_KEY
    })
end

function PalaDispel:PlayAudio(ttsText)
    local audio = self.db.audio
    if audio.type == "sound" then
        BM.Alerts:PlaySound({
            name = audio.sound,
            channel = audio.channel
        })
    else
        BM.Alerts:SpeakTTS({
            text = ttsText,
            voiceID = audio.voice
        })
    end
end

-- Edit

function PalaDispel:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false

    if self.editMode then
        self.alert.frame:SetBackdrop({
            bgFile = [[Interface\Buttons\WHITE8x8]],
            edgeFile = [[Interface\Buttons\WHITE8x8]],
            edgeSize = E:PixelSize(self.alert.frame)
        })
        E:DisablePixelSnap(self.alert.frame)
        self.alert.frame:SetBackdropColor(0, 0.2, 0.5, 0.5)
        self.alert.frame:SetBackdropBorderColor(0, 0.5, 1, 1)
        self.alert:SetText(self:FormatAlertText("Dispel", false, "player"))
        self.alert:Show()
        self:ApplyGlow("player")
    else
        self.alert.frame:SetBackdrop(nil)
        self:RemoveGlow("player")
        if self.myAssignedUnit then
            self.alert:SetText(self:FormatAlertText("Dispel", false, self.myAssignedUnit))
            self:ApplyGlow(self.myAssignedUnit)
        else
            self.alert:Hide()
        end
    end
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("PalaDispel", {
            tab = "Voidspire",
            order = 10,
            labelKey = "BossMods_PalaDispel",
            descKey = "BossMods_PalaDispelDesc",
            moduleName = "BossMods_PalaDispel"
        })
    end
end
