local E, L = unpack(ART)

local MODULE_NAME = "OmniumFolioReminder"
local TREE_ID = 1186
local MOTE_TRAIT_CURRENCY_ID = 4230
local TOTAL_MOTES = 5
local REQUIRED_LEVEL = 90

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true
})

local Reminder = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function isSecret(value)
    return type(issecretvalue) == "function"
        and issecretvalue(value)
end

local function readSpentMotes()
    if not C_Traits
        or type(C_Traits.GetConfigIDByTreeID) ~= "function"
        or type(C_Traits.GetTreeCurrencyInfo) ~= "function"
    then
        return nil
    end

    local configID = C_Traits.GetConfigIDByTreeID(TREE_ID)

    if configID == nil or isSecret(configID) then
        return nil
    end

    local currencies = C_Traits.GetTreeCurrencyInfo(
        configID,
        TREE_ID,
        true
    )

    if type(currencies) ~= "table" then
        return nil
    end

    for _, currency in ipairs(currencies) do
        local currencyID = currency and currency.traitCurrencyID

        if currencyID ~= nil
            and not isSecret(currencyID)
            and currencyID == MOTE_TRAIT_CURRENCY_ID
        then
            local spent = currency.spent

            if spent == nil or isSecret(spent) then
                return nil
            end

            spent = tonumber(spent)

            if spent then
                return math.max(0, math.floor(spent + 0.5))
            end
        end
    end

    return nil
end

function Reminder:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local BossMods = E:GetModule("BossMods", true)
    local Engines = BossMods and BossMods.Engines
    if not Engines or not Engines.TextAlert then
        return nil
    end

    self.alert = Engines.TextAlert({
        parent = UIParent,
        strata = "MEDIUM",
        size = {w = 760, h = 32},
        font = {
            size = 18,
            outline = "OUTLINE",
            color = {1, 0.32, 0.16, 1}
        }
    })
    self.frame = self.alert.frame
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOP", UIParent, "TOP", 0, -190)
    self.frame:EnableMouse(false)
    self.alert:Hide()
    return self.frame
end

function Reminder:Refresh()
    local frame = self:EnsureFrame()
    if not frame then
        return
    end
    local levelOK, level = pcall(UnitLevel, "player")

    if not levelOK
        or level == nil
        or isSecret(level)
        or level ~= REQUIRED_LEVEL
    then
        frame:Hide()
        return
    end

    local ok, spent = pcall(readSpentMotes)

    if not ok or spent == nil or spent >= TOTAL_MOTES then
        frame:Hide()
        return
    end

    local remaining = TOTAL_MOTES - spent
    local formatText = L["OmniumFolio_UnspentMotes"]
        or "Unspent Motes of Omnial Inquiry: %d (%d/5 used)"

    self.alert:SetText(formatText:format(remaining, spent))
    self.alert:Show()
end

function Reminder:ScheduleRefresh()
    if self.refreshTimer then
        return
    end

    self.refreshTimer = C_Timer.NewTimer(0.2, function()
        self.refreshTimer = nil

        if self:IsEnabled() then
            self:Refresh()
        end
    end)
end

function Reminder:PLAYER_ENTERING_WORLD()
    self:ScheduleRefresh()

    if self.worldTimer then
        self.worldTimer:Cancel()
    end
    self.worldTimer = C_Timer.NewTimer(3, function()
        self.worldTimer = nil
        if self:IsEnabled() then
            self:Refresh()
        end
    end)
end

function Reminder:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LEVEL_UP", "ScheduleRefresh")
    self:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED", "ScheduleRefresh")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "ScheduleRefresh")
    self:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED", "ScheduleRefresh")
    self:RegisterEvent("TRAIT_SYSTEM_INTERACTION_STARTED", "ScheduleRefresh")
    self:ScheduleRefresh()
end

function Reminder:OnDisable()
    if self.refreshTimer then
        self.refreshTimer:Cancel()
        self.refreshTimer = nil
    end
    if self.worldTimer then
        self.worldTimer:Cancel()
        self.worldTimer = nil
    end

    if self.frame then
        self.frame:Hide()
    end
end
