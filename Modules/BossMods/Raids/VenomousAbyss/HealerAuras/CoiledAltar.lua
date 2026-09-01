local E = unpack(ART)

local MODULE_NAME = "BossMods_HealerAuras"
local ENCOUNTER_ID = 3429
local GLOOMBOMB_TIMER_SPELL_ID = 1286895
local GLOOMBOMB_DEBUFF_SPELL_ID = 1310881
local GLOOMBOMB_DURATION = 5
local LISTEN_DURATION = 0.1
local GLOW_KEY = "ART_HealerAuras_GloombombGlow"

local HealerAuras = E:GetModule(MODULE_NAME)
local BossMods = E:GetModule("BossMods")

local function getGloombombIcon()
    local info = C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(GLOOMBOMB_DEBUFF_SPELL_ID)
    return info and info.iconID or 136214
end

local function getFrameForUnit(unit)
    local alerts = BossMods and BossMods.Alerts
    return alerts and alerts.ResolveFrame and alerts:ResolveFrame(unit) or nil
end

local function getPlayerRaidUnit()
    for index = 1, math.max(1, GetNumGroupMembers() or 0) do
        local unit = "raid" .. index
        if UnitExists(unit) and UnitIsUnit(unit, "player") then return unit end
    end
end

function HealerAuras:GetGloombombSettings()
    self.db.auras = self.db.auras or {}
    self.db.auras.gloombomb = self.db.auras.gloombomb or {}
    local settings = self.db.auras.gloombomb
    if type(settings.iconPosition) ~= "table" then
        settings.iconPosition = {
            point = "CENTER",
            x = tonumber(settings.iconX) or 0,
            y = tonumber(settings.iconY) or 0
        }
    end
    settings.iconPosition.point = settings.iconPosition.point or "CENTER"
    settings.iconPosition.x = tonumber(settings.iconPosition.x) or 0
    settings.iconPosition.y = tonumber(settings.iconPosition.y) or 0
    settings.iconX, settings.iconY = nil, nil

    settings.glowType = settings.glowType or "Pixel"
    settings.glowColor = settings.glowColor or {0.55, 0.20, 1, 1}
    settings.glowLines = math.max(1, math.floor(tonumber(settings.glowLines) or 8))
    settings.glowThickness = math.max(1, tonumber(settings.glowThickness) or 2)
    if settings.glowFrequency == nil then
        settings.glowFrequency = math.floor(((tonumber(settings.glowSpeed) or 0.25) * 10) + 0.5)
    end
    settings.glowFrequency = math.max(0, math.floor(tonumber(settings.glowFrequency) or 3))
    settings.glowScale = math.max(1, math.floor(tonumber(settings.glowScale) or 10))
    settings.glowSpeed = nil

    return settings
end

function HealerAuras:ApplyRaidFrameGlow(frame, enabled)
    if not (BossMods and BossMods.Alerts and frame) then return end
    BossMods.Alerts:StopGlow({frame = frame, key = GLOW_KEY})
    if not enabled then return end
    local settings = self:GetGloombombSettings()
    BossMods.Alerts:StartGlow({
        frame = frame,
        glowType = settings.glowType,
        color = settings.glowColor,
        lines = settings.glowLines,
        frequency = (settings.glowFrequency or 3) / 10,
        thickness = settings.glowThickness,
        scale = (settings.glowScale or 10) / 10,
        key = GLOW_KEY
    })
end

function HealerAuras:ApplyOverlayStyle(state)
    local settings = self:GetGloombombSettings()
    local position = settings.iconPosition or {}
    local point = position.point or "CENTER"
    local size = math.max(12, math.min(100, tonumber(settings.iconSize) or 36))
    state.icon:ClearAllPoints()
    state.icon:SetPoint(
        point, state.frame, point,
        tonumber(position.x) or 0,
        tonumber(position.y) or 0
    )
    state.icon:SetSize(size, size)
    state.icon:SetTexture(getGloombombIcon())
    state.icon:SetShown(state.active and settings.showIcon ~= false)
    if state.cooldown then
        state.cooldown:ClearAllPoints()
        state.cooldown:SetPoint(
            point, state.frame, point,
            tonumber(position.x) or 0,
            tonumber(position.y) or 0
        )
        state.cooldown:SetSize(size, size)
        state.cooldown:SetShown(state.active and settings.showIcon ~= false)
    end
    self:ApplyRaidFrameGlow(
        state.frame,
        state.active and settings.showGlow == true
    )
end

function HealerAuras:EnsureOverlays()
    if self.overlays then return end
    self.overlays, self.overlaysByUnit = {}, {}
    for index = 1, 40 do
        local unit = "raid" .. index
        local frame = CreateFrame("Frame", nil, UIParent)
        if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
        frame:SetMouseMotionEnabled(false)
        frame:Hide()
        local icon = frame:CreateTexture(nil, "OVERLAY")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(getGloombombIcon())
        local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetReverse(false)
        cooldown:SetHideCountdownNumbers(false)
        cooldown:Hide()
        local state = {
            unit = unit,
            frame = frame,
            icon = icon,
            cooldown = cooldown,
            active = false,
            displayGeneration = 0
        }
        self.overlays[index] = state
        self.overlaysByUnit[unit] = state
    end
    self:RefreshOverlayAnchors()
end

function HealerAuras:RefreshOverlayAnchors()
    if not self.overlays then return end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingAnchorRefresh = true
        return
    end
    self.pendingAnchorRefresh = false
    for _, state in ipairs(self.overlays) do
        local target = getFrameForUnit(state.unit)
        state.target = target
        state.frame:ClearAllPoints()
        if target then
            state.frame:SetFrameStrata(target:GetFrameStrata() or "MEDIUM")
            state.frame:SetFrameLevel((target:GetFrameLevel() or 1) + 20)
            state.cooldown:SetFrameLevel(state.frame:GetFrameLevel() + 5)
            state.frame:SetPoint("CENTER", target, "CENTER", 0, 0)
            state.frame:SetSize(
                math.max(1, target:GetWidth() or 80),
                math.max(1, target:GetHeight() or 40)
            )
        else
            state.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -200, -200)
            state.frame:SetSize(80, 40)
        end
        self:ApplyOverlayStyle(state)
    end
end

function HealerAuras:HideOverlay(state)
    if not state then return end
    state.displayGeneration = (state.displayGeneration or 0) + 1
    if state.hideTimer then state.hideTimer:Cancel(); state.hideTimer = nil end
    state.active = false
    if state.cooldown and state.cooldown.Clear then state.cooldown:Clear() end
    self:ApplyOverlayStyle(state)
    state.frame:Hide()
end

function HealerAuras:ShowOverlayForUnit(unit)
    local state = self.overlaysByUnit and self.overlaysByUnit[unit]
    if not state or not state.target then return false end
    state.displayGeneration = (state.displayGeneration or 0) + 1
    local generation = state.displayGeneration
    if state.hideTimer then state.hideTimer:Cancel() end
    state.active = true
    state.frame:Show()
    state.cooldown:SetCooldown(GetTime(), GLOOMBOMB_DURATION)
    self:ApplyOverlayStyle(state)
    state.hideTimer = C_Timer.NewTimer(GLOOMBOMB_DURATION, function()
        if generation ~= state.displayGeneration then return end
        state.hideTimer = nil
        state.active = false
        if state.cooldown and state.cooldown.Clear then state.cooldown:Clear() end
        self:ApplyOverlayStyle(state)
        state.frame:Hide()
    end)
    return true
end

function HealerAuras:HideAllOverlays()
    for _, state in ipairs(self.overlays or {}) do self:HideOverlay(state) end
end

function HealerAuras:EnsurePreview()
    if self.preview then return self.preview end
    local frame = CreateFrame("Frame", "ART_HealerAurasGloombombPreview", UIParent)
    if frame.SetMouseClickEnabled then frame:SetMouseClickEnabled(false) end
    frame:SetMouseMotionEnabled(false)
    frame:Hide()
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(getGloombombIcon())
    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawSwipe(true)
    cooldown:SetReverse(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:Hide()
    self.preview = {frame = frame, icon = icon, cooldown = cooldown}
    return self.preview
end

function HealerAuras:RefreshPreview()
    local preview = self:EnsurePreview()
    local settings = self:GetGloombombSettings()
    local unit = self.previewMode and getPlayerRaidUnit() or nil
    local target = unit and getFrameForUnit(unit) or nil
    self:ApplyRaidFrameGlow(preview.frame, false)
    if not target then preview.frame:Hide(); return end
    preview.frame:SetFrameStrata(target:GetFrameStrata() or "HIGH")
    preview.frame:SetFrameLevel((target:GetFrameLevel() or 1) + 20)
    preview.cooldown:SetFrameLevel(preview.frame:GetFrameLevel() + 5)
    preview.frame:ClearAllPoints()
    preview.frame:SetPoint("CENTER", target, "CENTER", 0, 0)
    preview.frame:SetSize(
        math.max(1, target:GetWidth() or 80),
        math.max(1, target:GetHeight() or 40)
    )
    local position = settings.iconPosition or {}
    local point = position.point or "CENTER"
    local size = math.max(12, math.min(100, tonumber(settings.iconSize) or 36))
    preview.icon:ClearAllPoints()
    preview.icon:SetPoint(
        point, preview.frame, point,
        tonumber(position.x) or 0,
        tonumber(position.y) or 0
    )
    preview.icon:SetSize(size, size)
    preview.icon:SetTexture(getGloombombIcon())
    preview.icon:SetShown(settings.showIcon ~= false)
    preview.cooldown:ClearAllPoints()
    preview.cooldown:SetPoint(
        point, preview.frame, point,
        tonumber(position.x) or 0,
        tonumber(position.y) or 0
    )
    preview.cooldown:SetSize(size, size)
    preview.cooldown:SetCooldown(GetTime(), GLOOMBOMB_DURATION)
    preview.cooldown:SetShown(settings.showIcon ~= false)
    preview.frame:Show()
    self:ApplyRaidFrameGlow(preview.frame, settings.showGlow == true)
end

function HealerAuras:SetPreviewMode(value)
    self.previewMode = value and true or false
    self:RefreshPreview()
end

function HealerAuras:RemoveWindowRecord(record)
    for index, candidate in ipairs(self.windowRecords or {}) do
        if candidate == record then table.remove(self.windowRecords, index); return end
    end
end

function HealerAuras:CancelWindowRecord(record)
    if not record or record.cancelled then return end
    record.cancelled, record.listening = true, false
    if record.showTimer then record.showTimer:Cancel() end
    if record.stopTimer then record.stopTimer:Cancel() end
    self:RemoveWindowRecord(record)
end

function HealerAuras:CancelAllWindows()
    for _, record in ipairs(self.windowRecords or {}) do
        record.cancelled = true
        if record.showTimer then record.showTimer:Cancel() end
        if record.stopTimer then record.stopTimer:Cancel() end
    end
    self.windowRecords = {}
end

function HealerAuras:ScheduleGloombombWindow(text, timeUntilCast)
    local delay = math.max(0, tonumber(timeUntilCast) or 0)
    self.windowRecords = self.windowRecords or {}
    local record = {
        text = text,
        listenStartsAt = GetTime() + delay,
        listening = false,
        cancelled = false,
        targets = {}
    }
    table.insert(self.windowRecords, record)
    record.showTimer = C_Timer.NewTimer(delay, function()
        record.showTimer = nil
        if record.cancelled or not self.encounterActive then
            self:CancelWindowRecord(record)
            return
        end
        record.listening = true
        record.stopTimer = C_Timer.NewTimer(LISTEN_DURATION, function()
            record.stopTimer = nil
            if record.cancelled then return end
            record.listening = false
            self:RemoveWindowRecord(record)
        end)
    end)
end

function HealerAuras:GetListeningRecord()
    for index = #(self.windowRecords or {}), 1, -1 do
        local record = self.windowRecords[index]
        if record.listening and not record.cancelled then return record end
    end
end

function HealerAuras:OnUnitAura(_, unit)
    if not self.encounterActive then return end
    local record = self:GetListeningRecord()
    if not record then return end
    if unit == "player" then unit = getPlayerRaidUnit() end
    if type(unit) ~= "string" or not unit:match("^raid%d+$") then return end
    if record.targets[unit] then return end

    record.targets[unit] = true
    self:ShowOverlayForUnit(unit)
end

function HealerAuras:OnBigWigsStartBar(_, text, time)
    if self.encounterActive and self:GetGloombombSettings().enabled ~= false then
        self:ScheduleGloombombWindow(text, time)
    end
end

function HealerAuras:OnBigWigsStopBar(text)
    for _, record in ipairs(self.windowRecords or {}) do
        if record.text == text then
            if (record.listenStartsAt or 0) - GetTime() > 0.5 then
                self:CancelWindowRecord(record)
            end
            return
        end
    end
end

function HealerAuras:HookBigWigs()
    if self.bigWigsSubscription then return end
    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = "HealerAuras",
        spellKeys = {GLOOMBOMB_TIMER_SPELL_ID},
        onStartBar = function(key, text, time)
            self:OnBigWigsStartBar(key, text, time)
        end,
        onStopBar = function(text) self:OnBigWigsStopBar(text) end
    })
end

function HealerAuras:UnhookBigWigs()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
end

function HealerAuras:OnEncounterStart(_, encounterID)
    self.encounterActive = tonumber(encounterID) == ENCOUNTER_ID
    self:CancelAllWindows()
    self:HideAllOverlays()
end

function HealerAuras:OnEncounterEnd(_, encounterID)
    if tonumber(encounterID) == ENCOUNTER_ID then
        self.encounterActive = false
        self:CancelAllWindows()
        self:HideAllOverlays()
    end
end

function HealerAuras:Refresh()
    self:RefreshOverlayAnchors()
    self:RefreshPreview()
end

function HealerAuras:OnPlayerRegenEnabled()
    if self.pendingAnchorRefresh then self:RefreshOverlayAnchors() end
end

function HealerAuras:OnEnable()
    self.encounterActive = false
    self:EnsureOverlays()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("UNIT_AURA", "OnUnitAura")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "Refresh")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Refresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:HookBigWigs()
end

function HealerAuras:OnDisable()
    self:SetPreviewMode(false)
    self:CancelAllWindows()
    self:HideAllOverlays()
    self:UnhookBigWigs()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.encounterActive = false
end
