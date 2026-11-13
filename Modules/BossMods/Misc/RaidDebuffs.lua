local E, L = unpack(ART)
local CreateFrame = E:DiagnosticBindings("Modules/BossMods/Misc/RaidDebuffs")
local MODULE_NAME = "BossMods_RaidDebuffs"

local UNIT = "target"
local FILTER = "HARMFUL"
local ICON_CROP = 0.08
local MISSING_ALPHA = 0.35
local PRESENT_DIM = 0.45
local RED = {1, 0.15, 0.15, 1}
local BLACK = {0, 0, 0, 1}

local DEBUFFS = {
    {key = "sunderArmor", class = "WARRIOR", spell = 7386, label = "Sunder Armor", ids = {
        7386, 7405, 8380, 11596, 11597, 11971, 13444, 15502, 15572, 16145, 21081, 24317,
        25051, 27991, 365663
    }},
    {key = "demoralizingShout", class = "WARRIOR", spell = 1160, label = "Demoralizing Shout", ids = {
        1160, 6190, 11554, 11555, 11556, 13730, 16244, 19778, 23511, 27579
    }},
    {key = "thunderClap", class = "WARRIOR", spell = 6343, label = "Thunder Clap", ids = {
        6343, 8198, 8204, 8205, 11580, 11581, 11582, 13532, 413589, 461810, 461826, 461827,
        461828, 461829, 461830
    }},
    {key = "exposeArmor", class = "ROGUE", spell = 8647, label = "Expose Armor", ids = {
        8647, 8648, 8649, 8650, 8651, 8652, 11197, 11198
    }},
    {key = "faerieFire", class = "DRUID", spell = 770, label = "Faerie Fire", ids = {
        770, 778, 784, 1070, 6950, 9749, 9907, 13424, 13752, 16498, 20656, 21670,
        1286041, 1288561, 1289452
    }},
    {key = "demoralizingRoar", class = "DRUID", spell = 99, label = "Demoralizing Roar", ids = {
        99, 1735, 9490, 9747, 9898, 10968, 15727, 15971, 20753, 27551
    }},
    {key = "curseOfRecklessness", class = "WARLOCK", spell = 704, label = "Curse of Recklessness", ids = {
        704, 7658, 7659, 11717, 16231, 1225841
    }},
    {key = "curseOfElements", class = "WARLOCK", spell = 402792, label = "Curse of the Elements", ids = {
        11723, 11724, 402792, 440892, 1311676, 1311677, 1311680
    }},
    {key = "curseOfShadow", class = "WARLOCK", spell = 402791, label = "Curse of Shadow", ids = {
        402791
    }},
    {key = "shadowVulnerability", class = "WARLOCK", spell = 17794, label = "Shadow Vulnerability", ids = {
        17794
    }},
    {key = "huntersMark", class = "HUNTER", spell = 1130, label = "Hunter's Mark", ids = {
        1130, 14323, 14324, 14325, 1213268
    }},
    {key = "judgementOfWisdom", class = "PALADIN", spell = 20186, label = "Judgement of Wisdom", ids = {
        20186, 20268, 20352, 20353, 20354, 20355, 25757, 25758
    }},
    {key = "judgementOfLight", class = "PALADIN", spell = 20185, label = "Judgement of Light", ids = {
        20185, 20267, 20341, 20342, 20343, 20344, 20345, 20346, 25752, 25753, 28775
    }},
    {key = "judgementOfTheCrusader", class = "PALADIN", spell = 20188, label = "Judgement of the Crusader", ids = {
        20188, 20300, 20301, 20302, 20303, 21183, 25942, 25943, 456496
    }},
    {key = "shadowWeaving", class = "PRIEST", spell = 15257, label = "Shadow Weaving", ids = {
        15257, 15258
    }},
    {key = "wintersChill", class = "MAGE", spell = 11180, label = "Winter's Chill", ids = {
        11180, 12579
    }},
    {key = "fireVulnerability", class = "MAGE", spell = 22959, label = "Fire Vulnerability", ids = {
        22959
    }}
}

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = false,
    position = {point = "CENTER", x = 0, y = -120},
    iconSize = 32,
    iconPad = 3,
    perRow = 17,
    showWhen = "always",
    highlightMissing = false,
    debuffs = {
        sunderArmor = true,
        demoralizingShout = true,
        thunderClap = true,
        faerieFire = true,
        curseOfRecklessness = true,
        curseOfElements = true,
        curseOfShadow = true
    }
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")
Mod.DEBUFFS = DEBUFFS

local function aurasSecret()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or secret == true
end

local function canConfigure()
    return not InCombatLockdown() and not aurasSecret()
end

local function loadAuraContainer()
    if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
end

function Mod.SpellIcon(entry)
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry.spell)
    if E:IsSecret(icon) then return 134400 end
    return icon or 134400
end

function Mod.SpellName(entry)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry.spell)
    return E:SafeString(name) or entry.label
end

function Mod:IsPicked(entry)
    return self.db.debuffs[entry.key] == true
end

local function setBorder(frame, color)
    for _, edge in ipairs(frame.edges) do
        edge:SetColorTexture(color[1], color[2], color[3], color[4])
    end
end

local function addBorder(frame)
    frame.edges = {}
    local function edge(a, b, horizontal)
        local t = frame:CreateTexture(nil, "OVERLAY")
        t:SetPoint(a)
        t:SetPoint(b)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        frame.edges[#frame.edges + 1] = t
    end
    edge("TOPLEFT", "TOPRIGHT", true)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false)
    edge("TOPRIGHT", "BOTTOMRIGHT", false)
    setBorder(frame, BLACK)
end

local function newCell(parent, entry)
    local cell = CreateFrame("Frame", nil, parent)
    local ground = cell:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(0, 0, 0, 1)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 1, -1)
    cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    cell.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    cell.icon:SetTexture(Mod.SpellIcon(entry))
    addBorder(cell)
    return cell
end

local function initButton(button)
    button:EnableMouse(false)
    local ground = button:CreateTexture(nil, "BACKGROUND")
    ground:SetAllPoints()
    ground:SetColorTexture(0, 0, 0, 1)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", 1, -1)
    cooldown:SetPoint("BOTTOMRIGHT", -1, 1)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetReverse(true)
    local overlay = CreateFrame("Frame", nil, button)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", -1, 2)
    button.artIcon, button.artCooldown, button.artCount = icon, cooldown, count
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetApplicationCount(count)
end

function Mod:Build()
    if self.holder then return true end
    loadAuraContainer()
    local holder = CreateFrame("Frame", "ARTRaidDebuffs", UIParent)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetSize(32, 32)
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder,
        "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
    if not ok or not container then
        holder:Hide()
        self.holder, self.failed = holder, true
        return false
    end
    container:SetAllPoints(holder)
    container:SetFrameLevel(holder:GetFrameLevel() + 5)
    container:SetUnit(UNIT)
    container:SetEnabled(false)
    holder:Hide()
    self.cells, self.slots = {}, {}
    for _, entry in ipairs(DEBUFFS) do
        local ids = {}
        for _, id in ipairs(entry.ids) do ids[id] = true end
        self.cells[entry.key] = newCell(holder, entry)
        self.slots[entry.key] = container:AddAuraSlot(entry.key, FILTER, {
            candidateFilters = {includeSpellIDs = ids},
            initializeFrame = initButton
        })
    end
    self.holder, self.container = holder, container
    return true
end

function Mod:Layout()
    local size, pad = self.db.iconSize, self.db.iconPad
    local perRow = math.max(1, self.db.perRow or #DEBUFFS)
    local lit = self.db.highlightMissing == true
    local n = 0
    for _, entry in ipairs(DEBUFFS) do
        local on = self:IsPicked(entry)
        local cell, slot = self.cells[entry.key], self.slots[entry.key]
        if self.container.SetAuraSlotEnabled then
            self.container:SetAuraSlotEnabled(entry.key, on)
        end
        cell:SetShown(on)
        if on then
            local x = (n % perRow) * (size + pad)
            local y = -math.floor(n / perRow) * (size + pad)
            cell:SetSize(size, size)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", self.holder, "TOPLEFT", x, y)
            cell.icon:SetDesaturated(not lit)
            cell.icon:SetAlpha(lit and 1 or MISSING_ALPHA)
            setBorder(cell, lit and RED or BLACK)
            if slot then
                slot:ClearAllPoints()
                slot:SetAllPoints(cell)
                if slot.artIcon then
                    slot.artIcon:SetDesaturated(lit)
                    slot.artIcon:SetAlpha(lit and PRESENT_DIM or 1)
                end
            end
            n = n + 1
        end
    end
    n = math.max(n, 1)
    local cols = math.min(n, perRow)
    local rows = math.ceil(n / perRow)
    self.holder:SetSize(cols * size + (cols - 1) * pad, rows * size + (rows - 1) * pad)
end

function Mod:Wanted()
    if self.editMode then return true end
    local show = self.db.showWhen
    if show == "raid" and not IsInRaid() then return false end
    if show == "group" and not IsInGroup() then return false end
    if not UnitExists(UNIT) then return false end
    local hostile = UnitCanAttack("player", UNIT)
    if E:IsSecret(hostile) then return true end
    return hostile == true
end

function Mod:Fade()
    if self.holder and not self.failed then
        self.holder:SetAlpha(self:Wanted() and 1 or 0)
    end
end

function Mod:Refresh()
    if not self:IsEnabled() then return end
    if not canConfigure() then
        self.pending = true
        return
    end
    self.pending = false
    if not self:Build() then return end
    self:Layout()
    E:ApplyFramePosition(self.holder, self.db.position)
    self.container:SetEnabled(true)
    self.holder:Show()
    self:Fade()
end

function Mod:OnTargetChanged()
    if self.container and self.container.UpdateAllAuras then
        self.container:UpdateAllAuras()
    end
    self:Fade()
end

function Mod:OnUnitChanged(_, unit)
    if unit == UNIT then self:Fade() end
end

function Mod:OnRestrictionsLifted()
    if self.pending then self:Refresh() end
end

function Mod:SetEditMode(value)
    self.editMode = value == true
    self:Fade()
end

function Mod:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    if self.holder then E:ApplyFramePosition(self.holder, self.db.position) end
end

function Mod:OnInitialize()
    if E:IsForeverClient() and canConfigure() then self:Build() end
end

function Mod:OnEnable()
    if not E:IsForeverClient() then return end
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "Fade")
    self:RegisterEvent("UNIT_FACTION", "OnUnitChanged")
    self:RegisterEvent("UNIT_FLAGS", "OnUnitChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRestrictionsLifted")
    self:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionsLifted")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:Refresh()
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.editMode = false
    self.pending = false
    if not self.holder then return end
    self.holder:SetAlpha(0)
    self.holder:Hide()
    if self.container and canConfigure() then
        self.container:SetEnabled(false)
    end
end

if E:IsForeverClient() then
    E:RegisterBossModFeature("RaidDebuffs", {
        tab = "Misc", order = 75,
        labelKey = "BossMods_RaidDebuffs",
        descKey = "BossMods_RaidDebuffsDesc",
        moduleName = MODULE_NAME
    })
end
