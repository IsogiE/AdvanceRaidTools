local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Modules/LootCoin/LootCoin")
local BossMods = E:GetModule("BossMods")
local Shared = BossMods.Engines.Shared
local MODULE_NAME = "LootCoin"

local NPC_ID_FIELD = 6

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    duration = 10,
    position = {point = "CENTER", x = 0, y = 200, coordSpace = "UIParent"},
    font = {
        name = "Friz Quadrata TT", size = 48, outline = "OUTLINE",
        color = {1, 0.82, 0, 1}
    }
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")
Mod.sources = {}

local function publicNumber(value)
    if E:IsSecret(value) then return end
    local number = tonumber(value)
    if number and number == number and math.abs(number) < math.huge then return number end
end

local lookups
local function getLookups()
    if lookups then return lookups end
    lookups = {instances = {}, byEncounter = {}, byNPC = {}, noCoin = {}}
    for _, source in ipairs(Mod.sources) do
        if source.enabled ~= false and source.instanceID then
            lookups.instances[source.instanceID] = true
            for _, boss in ipairs(source.bosses or {}) do
                if boss.coin == false then
                    lookups.noCoin[boss.encounter] = true
                else
                    lookups.byEncounter[boss.encounter] = boss
                    if boss.npc then lookups.byNPC[boss.npc] = boss end
                end
            end
        end
    end
    return lookups
end

local function currentInstanceID()
    return publicNumber((select(8, GetInstanceInfo())))
end

local function npcIDFromGUID(guid)
    if type(guid) ~= "string" or E:IsSecret(guid) then return end
    return tonumber((select(NPC_ID_FIELD, strsplit("-", guid))))
end

function Mod:GetDaily(key)
    local char = E.db and E.db.char
    if not char then return {} end
    char[key] = type(char[key]) == "table" and char[key] or {}
    local records, now = char[key], time()
    for encounterID, expires in pairs(records) do
        if type(expires) ~= "number" or expires <= now then records[encounterID] = nil end
    end
    return records
end

local function nextDailyReset()
    local untilReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
        and publicNumber(C_DateAndTime.GetSecondsUntilDailyReset())
    return time() + (untilReset or 86400)
end

function Mod:CountKill(encounterID)
    local kills = self:GetDaily("lootCoinKills")
    if kills[encounterID] then return false end
    kills[encounterID] = nextDailyReset()
    return true
end

function Mod:MarkLooted(encounterID)
    self:GetDaily("lootCoinLooted")[encounterID] = nextDailyReset()
    E:SendMessage("ART_LOOTCOIN_UPDATED")
end

function Mod:IsLootedToday(encounterID)
    return self:GetDaily("lootCoinLooted")[encounterID] ~= nil
end

function Mod:GetCoinList()
    local looted, out = self:GetDaily("lootCoinLooted"), {}
    for _, source in ipairs(self.sources) do
        if source.enabled ~= false then
            local bosses = {}
            for _, boss in ipairs(source.bosses or {}) do
                if boss.coin ~= false then
                    bosses[#bosses + 1] = {name = boss.name, looted = looted[boss.encounter] ~= nil}
                end
            end
            out[#out + 1] = {name = source.name, instanceID = source.instanceID, bosses = bosses}
        end
    end
    return out
end

local COIN_CURRENCY_ID, COIN_ITEM_ID = 3469, 226404

function Mod:GetCoinIcon()
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(COIN_CURRENCY_ID)
    local icon = info and publicNumber(info.iconFileID)
    if not icon and C_Item and C_Item.GetItemIconByID then icon = publicNumber(C_Item.GetItemIconByID(COIN_ITEM_ID)) end
    return icon or "Interface\\Icons\\INV_Misc_Coin_01"
end

local function isCoinSlot(slot)
    local currencyID = publicNumber((select(4, GetLootSlotInfo(slot))))
    if currencyID == COIN_CURRENCY_ID then return true end
    local link = GetLootSlotLink(slot)
    if type(link) ~= "string" or E:IsSecret(link) then return false end
    return link:find("currency:" .. COIN_CURRENCY_ID .. "[:|]") ~= nil
        or link:find("item:" .. COIN_ITEM_ID .. "[:|]") ~= nil
end

function Mod:EnsureSettings()
    self.db.font = type(self.db.font) == "table" and self.db.font or {}
    local font = self.db.font
    font.name = type(font.name) == "string" and font.name or "Friz Quadrata TT"
    font.size = math.max(8, math.min(100, publicNumber(font.size) or 48))
    font.outline = type(font.outline) == "string" and font.outline or "OUTLINE"
    font.color = type(font.color) == "table" and font.color or {1, 0.82, 0, 1}
    self.db.duration = math.max(3, math.min(60, publicNumber(self.db.duration) or 10))
    self:GetPosition()
end

function Mod:GetPosition()
    self.db.position = type(self.db.position) == "table" and self.db.position or {}
    local position = self.db.position
    position.point = Shared.NormalizeAnchorPoint(position.point)
    position.x = publicNumber(position.x) or 0
    position.y = publicNumber(position.y) or 200
    position.coordSpace = "UIParent"
    return position
end

function Mod:BuildDisplayConfig()
    self:EnsureSettings()
    return {
        parent = UIParent,
        strata = "HIGH",
        size = {w = math.min(700, UIParent:GetWidth() - 32), h = self.db.font.size + 16},
        font = self.db.font
    }
end

function Mod:EnsureDisplay()
    if self.display then return end
    self.display = BossMods.Engines.TextAlert(self:BuildDisplayConfig())
    local frame = self.display.frame
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)
    local text = self.display:GetTextFontString()
    text:SetJustifyH("CENTER")
    self:ApplyPosition()
end

function Mod:GetAnchor()
    self:EnsureDisplay()
    return self.display.frame
end

function Mod:ApplyPosition()
    if self.display then E:ApplyFramePosition(self.display.frame, self:GetPosition()) end
end

function Mod:SavePosition(position)
    position = position or E:GetFramePosition(self:GetAnchor())
    self.db.position = {
        point = position.point, x = position.x, y = position.y, coordSpace = "UIParent"
    }
    self:ApplyPosition()
end

function Mod:ResetPosition()
    self:SavePosition({point = "CENTER", x = 0, y = 200})
end

function Mod:Refresh()
    self:EnsureSettings()
    if not self.display then return end
    self.display:Apply(self:BuildDisplayConfig())
    self:ApplyPosition()
    self:RefreshDisplay()
end

function Mod:SetEditMode(enabled)
    self.editMode = enabled == true and self:IsEnabled() and not InCombatLockdown()
    if self.editMode then self:EnsureDisplay() end
    self:RefreshDisplay()
end

function Mod:SetPreviewMode(enabled)
    self.previewMode = enabled == true and self:IsEnabled() and not InCombatLockdown()
    if self.previewMode then self:EnsureDisplay() end
    self:RefreshDisplay()
end

function Mod:RefreshDisplay()
    if not self.display then return end
    if self.pending or self.editMode or self.previewMode then
        self.display:SetText(L["LootCoinText"])
        self.display:Show()
    else
        self.display:Hide()
    end
end

function Mod:Clear()
    if self.hideTimer then
        self.hideTimer:Cancel()
        self.hideTimer = nil
    end
    self.pending = nil
    self:RefreshDisplay()
end

local function coinCount()
    local total = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(COIN_CURRENCY_ID)
        if info then
            local quantity = publicNumber(info.quantity)
            if not quantity then return end
            total = total + quantity
        end
    end
    if C_Item and C_Item.GetItemCount then
        total = total + (publicNumber(C_Item.GetItemCount(COIN_ITEM_ID)) or 0)
    end
    return total
end

function Mod:CoinLooted()
    local awaiting = self.awaiting
    self.awaiting = nil
    self:MarkLooted(awaiting.encounterID)
    if self.pending and self.pending.encounterID == awaiting.encounterID then self:Clear() end
end

function Mod:OnCurrencyUpdate(_, currencyType, _, quantityChange)
    if not self.awaiting then return end
    if publicNumber(currencyType) == COIN_CURRENCY_ID and (publicNumber(quantityChange) or 0) > 0 then
        return self:CoinLooted()
    end
    self:CheckCoinCount()
end

function Mod:CheckCoinCount()
    local awaiting = self.awaiting
    if not awaiting then return end
    local count = coinCount()
    if not count then return end
    if not awaiting.coins then
        awaiting.coins = count
    elseif count > awaiting.coins then
        self:CoinLooted()
    end
end

function Mod:Remind(encounterID, npcID)
    self:Clear()
    self:EnsureDisplay()
    self.pending = {encounterID = encounterID, npcID = npcID}
    self.awaiting = {encounterID = encounterID, coins = coinCount() or self.preFightCoins}
    self.hideTimer = C_Timer.NewTimer(self.db.duration, function()
        self.hideTimer = nil
        self:Clear()
    end)
    self:RefreshDisplay()
end

function Mod:OnEncounterEnd(_, encounterID, _, _, _, success)
    encounterID, success = publicNumber(encounterID), publicNumber(success)
    if success ~= 1 or not encounterID or not E:IsForeverClient() then return end
    local known = getLookups()
    if known.noCoin[encounterID] or not known.instances[currentInstanceID()] then return end
    if not self:CountKill(encounterID) then return end
    local boss = known.byEncounter[encounterID]
    self:Remind(encounterID, boss and boss.npc)
end

function Mod:OnLootOpened()
    local pending, known = self.pending, getLookups()
    local opensPending = false
    self.coinSlots = {}
    for slot = 1, (publicNumber(GetNumLootItems()) or 0) do
        local npcID = npcIDFromGUID(GetLootSourceInfo(slot))
        if pending and pending.npcID and npcID == pending.npcID then opensPending = true end
        if isCoinSlot(slot) then
            local boss = npcID and known.byNPC[npcID]
            self.coinSlots[slot] = boss and boss.encounter or nil
        end
    end
    if opensPending then self:Clear() end
end

function Mod:OnLootSlotCleared(_, slot)
    slot = publicNumber(slot)
    local encounterID = slot and self.coinSlots and self.coinSlots[slot]
    if not encounterID then return end
    self.coinSlots[slot] = nil
    if self.awaiting and self.awaiting.encounterID == encounterID then self.awaiting = nil end
    self:MarkLooted(encounterID)
    if self.pending and self.pending.encounterID == encounterID then self:Clear() end
end

function Mod:OnLootClosed()
    self.coinSlots = nil
end

function Mod:OnEnteringWorld()
    if not IsInInstance() then
        self.awaiting = nil
        self:Clear()
    end
end

function Mod:NotePreFightCoins()
    self.preFightCoins = coinCount() or self.preFightCoins
end

function Mod:OnCombatStart()
    self:NotePreFightCoins()
    self.editMode, self.previewMode = false, false
    self:RefreshDisplay()
end

function Mod:OnProfileChanged()
    self.editMode, self.previewMode = false, false
    self:Refresh()
end

function Mod:OnInitialize()
    self.editMode, self.previewMode = false, false
    self:EnsureSettings()
end

function Mod:OnEnable()
    if not E:IsForeverClient() then return end
    self:EnsureDisplay()
    self:Refresh()
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("LOOT_OPENED", "OnLootOpened")
    self:RegisterEvent("LOOT_SLOT_CLEARED", "OnLootSlotCleared")
    self:RegisterEvent("LOOT_CLOSED", "OnLootClosed")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("ENCOUNTER_START", "NotePreFightCoins")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "CheckCoinCount")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnCurrencyUpdate")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "CheckCoinCount")
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.editMode, self.previewMode = false, false
    self.awaiting = nil
    self:Clear()
end
