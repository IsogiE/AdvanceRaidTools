local E, L, P = unpack(ART)

P.modules.BossMods_GeneralPack = {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 200
    },
    size = {
        w = 420,
        h = 56
    },
    transientDuration = 6,
    durabilityThreshold = 0.30,
    summonGlowSeconds = 10,
    font = {
        size = 18,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    background = {
        enabled = false,
        color = {0, 0, 0},
        opacity = 0.55
    },
    border = {
        enabled = false,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    },
    alerts = {
        summonPet = true,
        petPassive = true,
        repairGear = true,
        consumableRepair = true,
        consumableSoulwell = true,
        applySoulstone = true,
        consumableFeast = true,
        consumableCauldron = true,
        gateway = true,
        gatewayShardMissing = true,
        chatHealthstone = true,
        chatSummonStone = true
    }
}

local Mod = E:NewModule("BossMods_GeneralPack", "AceEvent-3.0")

local BM

local COMM_PREFIX = "ART_GenPack"

local SPELL_FEAST = 19705
local SPELL_CAULDRON = 448001
local SPELL_REPAIR_BOT = 67826
local SPELL_HEALTHSTONE_USE = 6262
local SPELL_SOULWELL = 29893
local SPELL_RITUAL_OF_SUMMONING = 698
local SPELL_SOULSTONE = 20707
local SPELL_GATEWAY_USE = 111771
local SPELL_REPAIR_GEAR = 126462
local SPELL_PET_GENERIC = 136
local SPELL_GRIMOIRE_OF_SACRIFICE = 196099

local ITEM_HEALTHSTONE = 5512
local ITEM_DEMONIC_HEALTHSTONE = 224464
local ITEM_DEMONIC_GATEWAY = 188152
local ICON_GATEWAY_SHARD = 607513

local CONSUMABLE_SPELL_TYPES = {
    [1259657] = "FEAST",
    [1278915] = "FEAST",
    [1259658] = "FEAST",
    [1278929] = "FEAST",
    [1237104] = "FEAST",
    [1278909] = "FEAST",
    [1259659] = "FEAST",
    [1278895] = "FEAST",
    [1240267] = "CAULDRON",
    [1240195] = "CAULDRON",
    [29893] = "SOULWELL",
    [199109] = "REPAIR",
    [67826] = "REPAIR"
}

local CONSUMABLES = {
    FEAST = {
        spellID = SPELL_FEAST,
        alertKey = "consumableFeast"
    },
    CAULDRON = {
        spellID = SPELL_CAULDRON,
        alertKey = "consumableCauldron"
    },
    SOULWELL = {
        spellID = SPELL_HEALTHSTONE_USE,
        alertKey = "consumableSoulwell"
    },
    REPAIR = {
        spellID = SPELL_REPAIR_BOT,
        alertKey = "consumableRepair"
    }
}

local PRIORITY = {
    SUMMON_PET = 90,
    PET_PASSIVE = 88,
    CHAT_REQUEST = 80,
    REPAIR_GEAR = 70,
    APPLY_SS = 65,
    CONSUMABLE = 50,
    GATEWAY_MISSING = 38,
    GATEWAY = 35
}

local issecretvalue = _G.issecretvalue or function()
    return false
end

local function bareName(name)
    if not name or issecretvalue(name) then
        return ""
    end
    name = tostring(name)
    return name:match("^([^%-]+)") or name
end

local function tex(path, size)
    if not path then
        return ""
    end
    size = size or 16
    return ("|T%s:%d:%d:0:0:64:64:4:60:4:60|t"):format(path, size, size)
end

local function spellTex(id, size)
    return tex(C_Spell.GetSpellTexture(id), size)
end

local function colorize(hex, text)
    return ("|cff%s%s|r"):format(hex, text)
end

local function loc(key)
    return (L and L[key]) or key
end

local function locFmt(key, ...)
    local s = (L and L[key]) or key
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, s, ...)
        if ok then
            return formatted
        end
    end
    return s
end

local function inEncounter()
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress then
        return C_InstanceEncounter.IsEncounterInProgress()
    end
    return false
end

local function instanceType()
    local _, t = GetInstanceInfo()
    return t
end

local function isInsideInstance()
    local t = instanceType()
    return t == "raid" or t == "party" or t == "scenario"
end

local function inRestrictedAuraState()
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        return C_ChatInfo.InChatMessagingLockdown()
    end
    return false
end

local function hasWellFedBuff(minRemaining)
    if inRestrictedAuraState() then
        return false
    end
    minRemaining = minRemaining or 600
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then
            break
        end
        if aura.name and not E:IsSecret(aura.name) and aura.name:find("Well Fed") then
            local remaining = (aura.expirationTime or 0) - GetTime()
            if remaining > minRemaining then
                return true
            end
        end
    end
    return false
end

local function hasFullHealthstone()
    local normal = C_Item.GetItemCount(ITEM_HEALTHSTONE, false, true) or 0
    local demonic = C_Item.GetItemCount(ITEM_DEMONIC_HEALTHSTONE, false, true) or 0
    return normal >= 3 or demonic >= 3
end

local function lowestDurabilityRatio()
    local lowest = 1
    for slot = 1, 18 do
        local current, max = GetInventoryItemDurability(slot)
        if current and max and max > 0 then
            local ratio = current / max
            if ratio < lowest then
                lowest = ratio
            end
        end
    end
    return lowest
end

local function playerSpecID()
    local idx = GetSpecialization and GetSpecialization()
    if not idx then
        return nil
    end
    return GetSpecializationInfo and GetSpecializationInfo(idx) or nil
end

local function classNeedsPet()
    local _, class = UnitClass("player")
    if class == "WARLOCK" then
        if inRestrictedAuraState() then
            return false
        end
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_GRIMOIRE_OF_SACRIFICE)
        return aura == nil
    elseif class == "HUNTER" then
        local specID = playerSpecID()
        if not specID then
            return false
        end
        if specID == 253 or specID == 255 then
            return true
        end
        if specID == 254 and IsPlayerSpell and IsPlayerSpell(1223323) then
            return true
        end
        return false
    elseif class == "DEATHKNIGHT" then
        local specID = playerSpecID()
        return specID == 252
    end
    return false
end

local function isPetPassive()
    if not UnitExists("pet") then
        return false
    end
    for i = 1, NUM_PET_ACTION_SLOTS do
        local name, _, _, isActive = GetPetActionInfo(i)
        if name and isActive and (name == "PET_MODE_PASSIVE" or name == "PET_ACTION_MODE_PASSIVE") then
            return true
        end
    end
    return false
end

local function isSpellReady(spellID)
    if not IsPlayerSpell(spellID) then
        return false
    end
    local cd = C_Spell.GetSpellCooldown(spellID)
    if cd and cd.duration and cd.duration > 1.5 then
        return false
    end
    return true
end

local function isSpellOnCooldown(spellID)
    local cd = C_Spell.GetSpellCooldown(spellID)
    return cd and cd.duration and cd.duration > 1.5
end

local function groupHasSoulstone()
    if inRestrictedAuraState() then
        return false
    end
    local function unitHas(unit)
        if not unit or not UnitExists(unit) then
            return false
        end
        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
            if not aura then
                break
            end
            if aura.spellId == SPELL_SOULSTONE and not E:IsSecret(aura.spellId) then
                return true
            end
        end
        return false
    end
    if unitHas("player") then
        return true
    end
    if IsInRaid() then
        for i = 1, 40 do
            if unitHas("raid" .. i) then
                return true
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if unitHas("party" .. i) then
                return true
            end
        end
    end
    return false
end

local function resolveSenderUnit(sender)
    if not sender or sender == "" then
        return nil
    end
    local bare = bareName(sender)
    if bare == "" then
        return nil
    end
    if bareName(UnitName("player") or "") == bare then
        return "player"
    end
    if IsInRaid() then
        local n = GetNumGroupMembers() or 0
        for i = 1, n do
            local unit = "raid" .. i
            if UnitExists(unit) and bareName(UnitName(unit) or "") == bare then
                return unit
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and bareName(UnitName(unit) or "") == bare then
                return unit
            end
        end
    end
    return nil
end

local ANCHOR_FACTORS = {
    TOPLEFT = {-0.5, 0.5},
    TOP = {0.0, 0.5},
    TOPRIGHT = {0.5, 0.5},
    LEFT = {-0.5, 0.0},
    CENTER = {0.0, 0.0},
    RIGHT = {0.5, 0.0},
    BOTTOMLEFT = {-0.5, -0.5},
    BOTTOM = {0.0, -0.5},
    BOTTOMRIGHT = {0.5, -0.5}
}

local function anchorOffset(anchor, w, h)
    local f = ANCHOR_FACTORS[anchor] or ANCHOR_FACTORS.CENTER
    return f[1] * w, f[2] * h
end

local function findRaidFrame(unit)
    if not unit then
        return nil
    end
    local LGF = E.Libs and E.Libs.LibGetFrame
    if LGF and LGF.GetUnitFrame then
        local f = LGF.GetUnitFrame(unit)
        if f and f.IsVisible and f:IsVisible() then
            return f
        end
    end
    if _G.DandersFrames_GetFrameForUnit then
        local f = _G.DandersFrames_GetFrameForUnit(unit)
        if f and f.IsVisible and f:IsVisible() then
            return f
        end
    end
    for i = 1, 40 do
        local f = _G["CompactRaidFrame" .. i]
        if f and f.IsVisible and f:IsVisible() and f.unit and UnitIsUnit(f.unit, unit) then
            return f
        end
    end
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f and f.IsVisible and f:IsVisible() and f.unit and UnitIsUnit(f.unit, unit) then
            return f
        end
    end
    if UnitIsUnit("player", unit) and _G.PlayerFrame and PlayerFrame:IsVisible() then
        return PlayerFrame
    end
    return nil
end

local function buildAlertConfig(mod)
    return {
        parent = UIParent,
        strata = "HIGH",
        size = {
            w = mod.db.size.w,
            h = mod.db.size.h
        },
        font = {
            size = mod.db.font.size,
            outline = mod.db.font.outline,
            color = mod.db.font.color
        }
    }
end

function Mod:OnModuleInitialize()
    BM = BM or E:GetModule("BossMods")
    self.alerts = {}
    self.timers = {}
    self.editMode = false
    self:EnsureAlert()
    self:ApplyVisuals()
    self:ApplyPosition()
    self.alert:Hide()
end

function Mod:EnsureAlert()
    if self.alert then
        return
    end
    self.alert = BM.Engines.TextAlert(buildAlertConfig(self))
    self.alert:Hide()
    self.frame = self.alert.frame
end

function Mod:ApplyVisuals()
    self.alert:Apply(buildAlertConfig(self))

    local f = self.alert.frame
    local bg = self.db.background
    if bg.enabled then
        f:SetBackdrop({
            bgFile = E.media.blankTex,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0
            }
        })
        local r, g, b = E:ColorTuple(bg.color, 0, 0, 0)
        f:SetBackdropColor(r, g, b, bg.opacity or 0.55)
    else
        f:SetBackdrop(nil)
        f:SetBackdropColor(0, 0, 0, 0)
    end

    local border = self.db.border
    E:ApplyOuterBorder(f, {
        enabled = border.enabled,
        edgeFile = E:FetchBorder(border.texture),
        edgeSize = math.min(border.size or 1, 16),
        r = (border.color and border.color[1]) or 0,
        g = (border.color and border.color[2]) or 0,
        b = (border.color and border.color[3]) or 0,
        a = (border.color and border.color[4]) or 1
    })
end

function Mod:ApplyPosition()
    local pos = self.db.position
    local f = self.alert.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Mod:SavePosition(pos)
    local f = self.alert and self.alert.frame
    if not f then
        return
    end
    local point = (pos and pos.point) or "CENTER"
    local x = (pos and pos.x) or 0
    local y = (pos and pos.y) or 0

    local fw, fh = f:GetWidth(), f:GetHeight()
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    local pox, poy = anchorOffset(point, pw, ph)
    local fox, foy = anchorOffset(point, fw, fh)

    local p = self.db.position
    p.point = "CENTER"
    p.x = math.floor((pox + x - fox) + 0.5)
    p.y = math.floor((poy + y - foy) + 0.5)
    self:ApplyPosition()
end

function Mod:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplyVisuals()
    self:ApplyPosition()
    if self.editMode then
        self:RenderEditPreview()
    elseif not InCombatLockdown() then
        self:Recheck()
    end
end

function Mod:SetEditMode(v)
    self.editMode = v and true or false
    if self.editMode then
        self:RenderEditPreview()
    else
        self:Render()
    end
end

function Mod:RenderEditPreview()
    local fontSize = self.db.font.size or 18
    local iconSize = fontSize + 2
    self.alert:SetText(spellTex(SPELL_HEALTHSTONE_USE, iconSize) .. " " ..
                           colorize("ffe066", loc("BossMods_GP_TextPreview")))
    self.alert.frame:SetHeight(fontSize + 16)
    self.alert:Show()
end

function Mod:Render()
    if self.editMode then
        return
    end

    local list = {}
    local now = GetTime()
    for key, entry in pairs(self.alerts) do
        if entry.expires and entry.expires <= now then
            self.alerts[key] = nil
        else
            list[#list + 1] = entry
        end
    end

    if #list == 0 then
        self.alert:Hide()
        return
    end

    table.sort(list, function(a, b)
        if a.priority == b.priority then
            return (a.created or 0) < (b.created or 0)
        end
        return a.priority > b.priority
    end)

    local lines = {}
    for i, entry in ipairs(list) do
        lines[i] = entry.text
    end
    self.alert:SetText(table.concat(lines, "\n"))

    local fontSize = self.db.font.size or 18
    local lineH = fontSize + 4
    self.alert.frame:SetHeight(#list * lineH + 12)
    self.alert:Show()
end

function Mod:Set(key, text, priority, holdSeconds)
    if not key or not text then
        return
    end
    local now = GetTime()
    local entry = self.alerts[key] or {
        created = now
    }
    entry.text = text
    entry.priority = priority or 50
    if holdSeconds and holdSeconds > 0 then
        entry.expires = now + holdSeconds
    else
        entry.expires = nil
    end
    self.alerts[key] = entry

    self:CancelTimer(key)
    if entry.expires then
        self.timers[key] = C_Timer.NewTimer(holdSeconds + 0.05, function()
            self.timers[key] = nil
            if InCombatLockdown() then
                return
            end
            local current = self.alerts[key]
            if current and current.expires and current.expires <= GetTime() + 0.01 then
                self.alerts[key] = nil
                if self:IsEnabled() then
                    self:Render()
                end
            end
        end)
    end

    if self:IsEnabled() then
        self:Render()
    end
end

function Mod:Clear(key)
    self.alerts[key] = nil
    self:CancelTimer(key)
    if self:IsEnabled() then
        self:Render()
    end
end

function Mod:CancelTimer(key)
    local t = self.timers[key]
    if t then
        if t.Cancel then
            t:Cancel()
        end
        self.timers[key] = nil
    end
end

function Mod:ClearAll()
    for key, t in pairs(self.timers) do
        if t and t.Cancel then
            t:Cancel()
        end
        self.timers[key] = nil
    end
    wipe(self.alerts)
    if self.alert then
        self.alert:Hide()
    end
end

function Mod:WantAlert(key)
    local a = self.db.alerts
    return a and a[key] ~= false
end

function Mod:Recheck()
    if InCombatLockdown() then
        return
    end
    self:CheckPet()
    self:CheckRepair()
    self:CheckGateway()
    self:CheckGatewayShard()
    if self:IsEnabled() and not self.editMode and self.alert then
        self:Render()
    end
end

function Mod:CheckPet()
    if InCombatLockdown() then
        return
    end
    if not self:WantAlert("summonPet") or not isInsideInstance() then
        self:Clear("summonPet")
        return
    end
    if UnitIsDeadOrGhost("player") or UnitInVehicle("player") then
        self:Clear("summonPet")
        return
    end
    if not classNeedsPet() then
        self:Clear("summonPet")
        return
    end
    if UnitExists("pet") and not UnitIsDead("pet") then
        self:Clear("summonPet")
        return
    end
    local size = (self.db.font.size or 18) + 2
    self:Set("summonPet",
        spellTex(SPELL_PET_GENERIC, size) .. " " .. colorize("ff4040", loc("BossMods_GP_TextSummonPet")),
        PRIORITY.SUMMON_PET)
end

function Mod:CheckRepair()
    if InCombatLockdown() then
        return
    end
    if not self:WantAlert("repairGear") then
        self:Clear("repairGear")
        return
    end
    local threshold = self.db.durabilityThreshold or 0.30
    if lowestDurabilityRatio() >= threshold then
        self:Clear("repairGear")
        return
    end
    local size = (self.db.font.size or 18) + 2
    self:Set("repairGear",
        spellTex(SPELL_REPAIR_GEAR, size) .. " " .. colorize("ffd055", loc("BossMods_GP_TextRepairGear")),
        PRIORITY.REPAIR_GEAR)
end

function Mod:CheckGateway()
    if not self:WantAlert("gateway") then
        self:Clear("gateway")
        return
    end
    if not isInsideInstance() then
        self:Clear("gateway")
        return
    end
    if not C_Item.IsUsableItem(ITEM_DEMONIC_GATEWAY) then
        self:Clear("gateway")
        return
    end
    local size = (self.db.font.size or 18) + 2
    self:Set("gateway", spellTex(SPELL_GATEWAY_USE, size) .. " " .. colorize("9d6cff", loc("BossMods_GP_Gateway")),
        PRIORITY.GATEWAY)
end

function Mod:CheckGatewayShard()
    if InCombatLockdown() then
        return
    end
    if not self:WantAlert("gatewayShardMissing") then
        self:Clear("gatewayShardMissing")
        return
    end
    if not isInsideInstance() then
        self:Clear("gatewayShardMissing")
        return
    end
    local count = C_Item.GetItemCount(ITEM_DEMONIC_GATEWAY) or 0
    if count > 0 then
        self:Clear("gatewayShardMissing")
        return
    end
    local size = (self.db.font.size or 18) + 2
    self:Set("gatewayShardMissing", tex(ICON_GATEWAY_SHARD, size) .. " " ..
        colorize("ff7777", loc("BossMods_GP_TextGatewayShardMissing")), PRIORITY.GATEWAY_MISSING)
end

function Mod:OnReadyCheck()
    if InCombatLockdown() then
        return
    end
    if self:WantAlert("petPassive") and isPetPassive() then
        local size = (self.db.font.size or 18) + 2
        self:Set("petPassive",
            spellTex(SPELL_PET_GENERIC, size) .. " " .. colorize("ff4040", loc("BossMods_GP_TextPetPassive")),
            PRIORITY.PET_PASSIVE, self.db.transientDuration or 6)
    end

    if self:WantAlert("applySoulstone") then
        local _, class = UnitClass("player")
        if class == "WARLOCK" and isSpellReady(SPELL_SOULSTONE) and not groupHasSoulstone() then
            local size = (self.db.font.size or 18) + 2
            self:Set("applySoulstone", spellTex(SPELL_SOULSTONE, size) .. " " ..
                colorize("aa66ff", loc("BossMods_GP_ApplySoulstone")), PRIORITY.APPLY_SS,
                self.db.transientDuration or 6)
        end
    end
end

function Mod:Glow123(sender)
    if InCombatLockdown() then
        return
    end
    local LCG = E.Libs and E.Libs.LibCustomGlow
    if not LCG then
        return
    end
    local unit = resolveSenderUnit(sender)
    if not unit then
        return
    end
    local frame = findRaidFrame(unit)
    if not frame then
        return
    end

    self:StopGlow123()

    LCG.PixelGlow_Start(frame, {0.2, 1, 0.4, 1}, 8, 0.25, nil, 2, 0, 0, false, "ART_GP_123")

    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont(E:FetchModuleFont() or [[Fonts\FRIZQT__.TTF]], 22, "OUTLINE")
    label:SetTextColor(0.2, 1, 0.4, 1)
    label:SetText("123")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)

    self.glow123Frame = frame
    self.glow123Label = label
    self.glow123Timer = C_Timer.NewTimer(self.db.summonGlowSeconds or 10, function()
        Mod:StopGlow123()
    end)
end

function Mod:StopGlow123()
    local LCG = E.Libs and E.Libs.LibCustomGlow
    if self.glow123Frame and LCG then
        LCG.PixelGlow_Stop(self.glow123Frame, "ART_GP_123")
    end
    if self.glow123Label then
        self.glow123Label:Hide()
        self.glow123Label:SetParent(nil)
    end
    if self.glow123Timer then
        self.glow123Timer:Cancel()
    end
    self.glow123Frame = nil
    self.glow123Label = nil
    self.glow123Timer = nil
end

function Mod:OnEnterCombat()
    self:StopGlow123()
    for key, t in pairs(self.timers) do
        if key ~= "gateway" then
            if t and t.Cancel then
                t:Cancel()
            end
            self.timers[key] = nil
        end
    end
    for key in pairs(self.alerts) do
        if key ~= "gateway" then
            self.alerts[key] = nil
        end
    end
    self:CheckGateway()
end

function Mod:HandleChatTrigger(msg, sender)
    if InCombatLockdown() then
        return
    end
    if not msg or not sender or issecretvalue(msg) or issecretvalue(sender) then
        return
    end
    msg = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg ~= "hs" and msg ~= "123" then
        return
    end
    if UnitIsUnit(sender, "player") then
        return
    end

    local _, class = UnitClass("player")
    local size = (self.db.font.size or 18) + 2
    local hold = self.db.transientDuration or 6

    if msg == "hs" then
        if class == "WARLOCK" and self:WantAlert("chatHealthstone") and not isSpellOnCooldown(SPELL_SOULWELL) then
            self:Set("chatHealthstone", spellTex(SPELL_HEALTHSTONE_USE, size) .. " " ..
                colorize("aa66ff", loc("BossMods_GP_TextChatHealthstone")), PRIORITY.CHAT_REQUEST, hold)
        end
        return
    end

    if msg == "123" and self:WantAlert("chatSummonStone") then
        self:Glow123(sender)
        if class == "WARLOCK" and not isSpellOnCooldown(SPELL_RITUAL_OF_SUMMONING) then
            self:Set("chatSummonStone", spellTex(SPELL_RITUAL_OF_SUMMONING, size) .. " " ..
                colorize("aa66ff", loc("BossMods_GP_TextChatSummonStone")), PRIORITY.CHAT_REQUEST, hold)
        end
    end
end

function Mod:OnBagUpdate()
    if InCombatLockdown() then
        return
    end
    self:CheckGatewayShard()
end

function Mod:HandleConsumable(kind, sender)
    if InCombatLockdown() then
        return
    end
    local meta = CONSUMABLES[kind]
    if not meta then
        return
    end
    if not self:WantAlert(meta.alertKey) then
        return
    end
    if inEncounter() then
        return
    end

    local unit = resolveSenderUnit(sender)
    local senderName
    if unit and E.GetNickname then
        senderName = E:GetNickname(unit)
    end
    if not senderName or senderName == "" then
        senderName = bareName(sender)
    end
    if senderName == "" then
        senderName = "?"
    end
    local size = (self.db.font.size or 18) + 2

    if kind == "FEAST" then
        if inRestrictedAuraState() then
            return
        end
        if hasWellFedBuff(600) then
            return
        end
    elseif kind == "REPAIR" then
        if lowestDurabilityRatio() >= 0.9 then
            return
        end
    elseif kind == "SOULWELL" then
        if hasFullHealthstone() then
            return
        end
    end

    local label
    if kind == "FEAST" then
        label = colorize("66ff99", locFmt("BossMods_GP_TextFeastDropped", senderName))
    elseif kind == "CAULDRON" then
        label = colorize("66ff99", locFmt("BossMods_GP_TextCauldronDropped", senderName))
    elseif kind == "SOULWELL" then
        label = colorize("aa66ff", locFmt("BossMods_GP_TextSoulwellDropped", senderName))
    elseif kind == "REPAIR" then
        label = colorize("ffd055", locFmt("BossMods_GP_TextRepairBotDropped", senderName))
    end

    self:Set("consumable_" .. kind, spellTex(meta.spellID, size) .. " " .. label, PRIORITY.CONSUMABLE,
        self.db.transientDuration or 6)
end

function Mod:OnConsumableComm(_, message, _, sender)
    if InCombatLockdown() then
        return
    end
    if not message or not sender then
        return
    end
    if UnitIsUnit(sender, "player") then
        return
    end
    if not E:SafeString(message) then
        return
    end
    if not UnitIsVisible(sender) then
        return
    end
    self:HandleConsumable(message, sender)
end

function Mod:BroadcastConsumable(kind)
    local Comms = E:GetEnabledModule("Comms")
    if not Comms then
        return
    end
    if not IsInGroup() then
        return
    end
    local channel = IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or (IsInRaid() and "RAID" or "PARTY")
    Comms:Broadcast(COMM_PREFIX, kind, channel)
end

function Mod:OnSpellcast(_, unit, _, spellID)
    if InCombatLockdown() then
        return
    end
    if unit ~= "player" then
        return
    end
    local kind = CONSUMABLE_SPELL_TYPES[spellID]
    if kind then
        self:BroadcastConsumable(kind)
    end
end

function Mod:OnZoneChanged()
    if InCombatLockdown() then
        return
    end
    self:Recheck()
end

function Mod:OnChat(_, msg, sender)
    if InCombatLockdown() then
        return
    end
    self:HandleChatTrigger(msg, sender)
end

function Mod:OnEnable()
    BM = BM or E:GetModule("BossMods")
    self.alerts = self.alerts or {}
    self.timers = self.timers or {}
    self.editMode = false

    if not self.alert then
        self:EnsureAlert()
    end
    self:ApplyVisuals()
    self:ApplyPosition()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Recheck")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "CheckRepair")
    self:RegisterEvent("UNIT_PET", "CheckPet")
    self:RegisterEvent("BAG_UPDATE", "OnBagUpdate")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnSpellcast")
    self:RegisterEvent("READY_CHECK", "OnReadyCheck")
    self:RegisterEvent("ACTIONBAR_UPDATE_USABLE", "CheckGateway")
    self:RegisterEvent("CHAT_MSG_RAID", "OnChat")
    self:RegisterEvent("CHAT_MSG_PARTY", "OnChat")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnChat")
    self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "OnChat")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    E:CallModule("Comms", "RegisterProtocol", COMM_PREFIX, function(p, msg, dist, sender)
        Mod:OnConsumableComm(p, msg, dist, sender)
    end)

    if not InCombatLockdown() then
        self:Recheck()
    end
end

function Mod:OnDisable()
    self.editMode = false
    self:StopGlow123()
    self:ClearAll()
    if self.alert then
        self.alert:Hide()
    end
    E:CallModule("Comms", "UnregisterProtocol", COMM_PREFIX)
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("GeneralPack", {
            tab = "Misc",
            order = 50,
            labelKey = "BossMods_GeneralPack",
            descKey = "BossMods_GeneralPackDesc",
            moduleName = "BossMods_GeneralPack"
        })
    end
end
