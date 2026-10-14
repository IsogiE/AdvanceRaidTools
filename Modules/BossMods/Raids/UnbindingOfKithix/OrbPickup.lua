local E = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_KithixOrbPickup"
local ENCOUNTER_ID = 3513
local EXTINGUISH = 1304424
local WINDOW_DURATION = 8
local COUNTDOWN_DURATION = WINDOW_DURATION - 1

local function bindCountdown(text, duration)
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({{
        threshold = 0, format = "%.1f", step = 0.1,
        rounding = Enum.NumericRuleFormatRounding.Up
    }})
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetFontString(text)
    binding:SetDuration(duration)
    binding:SetTextFormat("Pick up orb ({})", {{
        property = Enum.DurationTextBindingProperty.RemainingDuration,
        formatter = formatter
    }})
    binding:SetExpiredText("Pick up orb (0.0)")
    binding:SetZeroDurationText("")
    binding:Disable()
    return binding
end

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    position = {point = "CENTER", x = 0, y = 120},
    font = {name = "Friz Quadrata TT", size = 48, outline = "OUTLINE"}
})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

BossMods.DisplayTemplates:Register(MODULE_NAME, "position", {
    category = "text", label = "Orb Pickup",
    defaultPosition = {point = "CENTER", x = 0, y = 120}
})

function Mod:EnsureDisplay()
    if not self.db.fontSize48Migration then
        if self.db.font.size == 34 then self.db.font.size = 48 end
        self.db.fontSize48Migration = true
    end
    if self.display then return end
    self.display = BossMods.Engines.TextAlert({
        parent = UIParent, strata = "HIGH", font = self.db.font
    })
    self.display:GetTextFontString():SetTextColor(1, 0.08, 0.08, 1)
    self.duration = C_DurationUtil.CreateDuration()
    self.redBinding = bindCountdown(self.display:GetTextFontString(), self.duration)
    self.updateFrame = CreateFrame("Frame")
    self.updateFrame:Hide()
    local elapsed = 0
    self.updateFrame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.05 then return end
        elapsed = 0
        self:UpdateText()
    end)
    BossMods.DisplayTemplates:Place(self, "position", self.display.frame)
end

function Mod:EnsureAuraContainer()
    if self.container then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret() then return end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        C_AddOns.LoadAddOn("Blizzard_AuraContainer")
    end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then return end
    local container = CreateFrame("AuraContainer", nil, self.display.frame,
        "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
    container:SetEnabled(false)
    container:Hide()
    container:SetAllPoints(self.display.frame)
    container:SetFrameLevel(self.display.frame:GetFrameLevel() + 1)
    container:SetUnit("player")
    container:AddAuraSlot("ARTKithixOrbPickup", "HARMFUL", {
        candidateFilters = {maxDuration = 8},
        sortMethod = AuraContainerSortMethod.Expiration,
        sortDirection = AuraContainerSortDirection.Normal,
        initializeFrame = function(button)
            button:SetSize(400, 80)
            button:SetFrameLevel(container:GetFrameLevel() + 1)
            button:SetPoint("CENTER", self.display.frame, "CENTER")
            local text = button:CreateFontString(nil, "OVERLAY")
            text:SetPoint("CENTER")
            local font = self.db.font
            text:SetFont(BossMods.Engines.Shared.FetchFont(font.name), font.size, font.outline)
            text:SetTextColor(0.1, 1, 0.2, 1)
            -- The native slot controls the green overlay. Neither its visibility
            -- nor protected aura data is read by addon Lua. Both text layers use
            -- the same public BigWigs deadline via native countdown bindings.
            self.greenText = text
            self.greenBinding = bindCountdown(text, self.duration)
        end
    })
    self.container = container
    -- A deferred creation must not inherit a cached listening state.
    self.listening = nil
end

function Mod:SetListening(value)
    if self.listening == value then return end
    self.listening = value
    if self.container then
        self.container:SetShown(value)
        self.container:SetEnabled(value)
    end
end

function Mod:UpdateText()
    local preview = self.editMode or self.previewMode
    if not preview then
        local nextText, nextTime
        for text, deadline in pairs(self.pendingBars or {}) do
            if deadline <= GetTime() then
                self.pendingBars[text] = nil
            elseif not nextTime or deadline < nextTime then
                nextText, nextTime = text, deadline
            end
        end
        if nextText ~= self.barText or nextTime ~= self.extinguishTime then
            self.barText, self.extinguishTime = nextText, nextTime
            if nextTime then
                self.duration:SetTimeFromEnd(nextTime - 1, COUNTDOWN_DURATION)
                self.redBinding:SetDuration(self.duration)
                if self.greenBinding then self.greenBinding:SetDuration(self.duration) end
            end
        end
    end
    local remaining = self.extinguishTime and self.extinguishTime - GetTime()
    if not preview and (not remaining or remaining <= 0) then
        self:StopCountdown()
        return
    end
    local visible = preview or remaining <= WINDOW_DURATION
    self:SetListening(not preview and visible)
    self.redBinding:SetEnabled(visible)
    if self.greenBinding then self.greenBinding:SetEnabled(not preview and visible) end
    self.display.frame:SetShown(visible)
    self.updateFrame:Show()
end

function Mod:Refresh()
    self:EnsureDisplay()
    self:EnsureAuraContainer()
    self.display:Apply({parent = UIParent, strata = "HIGH", font = self.db.font})
    if self.greenText and not (C_Secrets and C_Secrets.ShouldAurasBeSecret()) then
        local font = self.db.font
        self.greenText:SetFont(BossMods.Engines.Shared.FetchFont(font.name), font.size, font.outline)
    end
    BossMods.DisplayTemplates:Place(self, "position", self.display.frame)
    if self.editMode or self.previewMode then
        self.duration:SetTimeFromStart(GetTime(), COUNTDOWN_DURATION)
        self.redBinding:SetDuration(self.duration)
    end
    self:UpdateText()
end

function Mod:GetAnchor()
    self:EnsureDisplay()
    return self.display.frame
end

function Mod:SavePosition(position)
    self.db.position = position
    self:Refresh()
end

function Mod:SetEditMode(value)
    self.editMode = value == true
    if not self.editMode then self.barText = nil end
    self:Refresh()
end

function Mod:SetPreviewMode(value)
    self.previewMode = value == true
    if not self.previewMode then self.barText = nil end
    self:Refresh()
end

function Mod:StopCountdown()
    self.pendingBars = {}
    self.extinguishTime = nil
    self.barText = nil
    self:SetListening(false)
    if self.updateFrame then self.updateFrame:Hide() end
    if self.redBinding then self.redBinding:Disable() end
    if self.greenBinding then self.greenBinding:Disable() end
    if self.display then self.display:Hide() end
end

function Mod:OnEncounterStart(_, encounterID)
    self.editMode = false
    self.previewMode = false
    self:StopCountdown()
    self.encounterActive = encounterID == ENCOUNTER_ID
end

function Mod:OnEncounterEnd()
    self.encounterActive = false
    self:StopCountdown()
end

function Mod:OnEnable()
    self:Refresh()
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "Refresh")
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self.subscription = BossMods.BigWigs:Subscribe({
        owner = MODULE_NAME, spellKeys = {EXTINGUISH},
        onStartBar = function(_, text, duration)
            duration = tonumber(duration)
            if not self.encounterActive or not duration or duration <= 0 then return end
            -- BigWigs already includes the eight-second Extinguish cast.
            self.pendingBars = self.pendingBars or {}
            self.pendingBars[text] = GetTime() + duration
            self:Refresh()
        end,
        onStopBar = function(text)
            if self.pendingBars then self.pendingBars[text] = nil end
            if self.display then self:Refresh() end
        end,
        onStage = function(module, stage)
            if self.encounterActive and module and module.moduleName == "Kith'ix"
                and tonumber(stage) == 2 then self:StopCountdown() end
        end
    })
end

function Mod:OnDisable()
    if self.subscription then self.subscription:Unsubscribe(); self.subscription = nil end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
    self.editMode = false
    self.previewMode = false
    self:StopCountdown()
end

E:RegisterBossModFeature("KithixOrbPickup", {
    tab = "UnbindingOfKithix", order = 20,
    bossKey = "Kithix", bossLabelKey = "BossMods_Kithix", bossOrder = 10,
    labelKey = "Orb Pickup", moduleName = MODULE_NAME
})
