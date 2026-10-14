local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_KithixOrbPickup"
local ENCOUNTER_ID = 3513
local EXTINGUISH = 1304424
local WINDOW_DURATION = 8
local COUNTDOWN_DURATION = WINDOW_DURATION - 1

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    position = {point = "CENTER", x = 0, y = 120},
    font = {name = "Friz Quadrata TT", size = 48, outline = "OUTLINE"}
})
local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

BossMods.DisplayTemplates:Register(MODULE_NAME, "position", {
    category = "text", label = L["BossMods_PickUpOrb"],
    defaultPosition = {point = "CENTER", x = 0, y = 120}
})

function Mod:EnsureDisplay()
    if self.display then return end
    self.display = BossMods.Engines.TextAlert({
        parent = UIParent, strata = "HIGH", font = self.db.font
    })
    self.display:GetTextFontString():SetTextColor(1, 0.08, 0.08, 1)
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

function Mod:UpdateText()
    local preview = self.editMode or self.previewMode
    local now = GetTime()
    if not preview then
        local nextText, nextTime
        for text, deadline in pairs(self.pendingBars or {}) do
            if deadline <= now then
                self.pendingBars[text] = nil
            elseif not nextTime or deadline < nextTime then
                nextText, nextTime = text, deadline
            end
        end
        self.barText, self.extinguishTime = nextText, nextTime
    end
    local remaining = self.extinguishTime and self.extinguishTime - now
    if not preview and (not remaining or remaining <= 0) then
        self:StopCountdown()
        return
    end
    local visible = preview or remaining <= WINDOW_DURATION
    if visible then
        local countdown = preview and ((self.previewEndsAt or now) - now) or (remaining - 1)
        countdown = math.ceil(math.max(0, countdown) * 10) / 10
        local text = ("%s (%.1f)"):format(L["BossMods_PickUpOrb"], countdown)
        if text ~= self.lastText then
            self.lastText = text
            self.display:SetText(text)
        end
    end
    self.display.frame:SetShown(visible)
    self.updateFrame:Show()
end

function Mod:Refresh()
    self:EnsureDisplay()
    self.display:Apply({parent = UIParent, strata = "HIGH", font = self.db.font})
    BossMods.DisplayTemplates:Place(self, "position", self.display.frame)
    if self.editMode or self.previewMode then
        self.previewEndsAt = GetTime() + COUNTDOWN_DURATION
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
    self.previewEndsAt = nil
    self.lastText = nil
    if self.updateFrame then self.updateFrame:Hide() end
    if self.display then
        self.display:SetText("")
        self.display:Hide()
    end
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
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self.subscription = BossMods.BigWigs:Subscribe({
        owner = MODULE_NAME, spellKeys = {EXTINGUISH},
        onStartBar = function(_, text, duration)
            duration = tonumber(duration)
            if not self.encounterActive or not duration or duration <= 0 then return end
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
    labelKey = "BossMods_PickUpOrb", moduleName = MODULE_NAME
})
