local E = unpack(ART)
local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local BASE_SIZE = 26
local SLOT_KEY = "raidFrameAura"
local countdownFormatter

function Engines.CanConfigureUnitFrameAuras()
    return not InCombatLockdown()
        and not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

local function loadAuraContainer()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        local ok = pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
        if not ok then return false end
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") == true
end

local function getCountdownFormatter()
    if not countdownFormatter then
        countdownFormatter = C_StringUtil.CreateNumericRuleFormatter()
        countdownFormatter:SetBreakpoints({{
            threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%d"
        }})
    end
    return countdownFormatter
end

function Engines.UnitFrameAura(config)
    local definition = assert(config.definition)
    local slots = {}
    local shown, previewEnabled = false, false
    local preview, previewTimer
    local handle = {}

    local function initializeButton(slot, button)
        button:SetSize(BASE_SIZE, BASE_SIZE)
        button:SetPoint("CENTER", slot.container, "CENTER")
        button:EnableMouse(false)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints()
        cooldown:SetDrawSwipe(true)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetReverse(true)
        cooldown:SetHideCountdownNumbers(true)
        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints()
        overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)
        local text = overlay:CreateFontString(nil, "OVERLAY")
        text:SetFont(Engines.Shared.FetchFont("PT Sans Narrow"), 14, "OUTLINE")
        text:SetPoint("CENTER")
        slot.icon, slot.cooldown, slot.countdown = icon, cooldown, text
    end

    local function applyAppearance(slot, settings)
        slot.cooldown:SetAlpha(settings.showCooldown and 1 or 0)
        slot.countdown:SetAlpha(settings.showCountdown and 1 or 0)
    end

    local function createSlot()
        local container = CreateFrame("AuraContainer", nil, UIParent,
            "CustomAuraContainerTemplate,DisableUntrustedLayoutScriptsTemplate")
        container:SetSize(BASE_SIZE, BASE_SIZE)
        container:SetUnit("none")
        container:SetEnabled(false)
        container:Hide()
        container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
        local slot = {container = container}
        slot.button = container:AddAuraSlot(SLOT_KEY, table.concat(definition.aura.filters, "|"), {
            candidateFilters = CopyTable(definition.aura.candidateFilters or {}),
            sortMethod = definition.aura.sortMethod,
            sortDirection = definition.aura.sortDirection,
            initializeFrame = function(button)
                initializeButton(slot, button)
                button:SetIcon(slot.icon)
                button:SetDurationCooldown(slot.cooldown)
                button:SetDurationText(slot.countdown, {textFormatter = getCountdownFormatter()})
            end
        })
        return slot
    end

    local function place(frame, unitFrame, settings)
        frame:SetParent(unitFrame)
        frame:SetFrameLevel(unitFrame:GetFrameLevel() + 100)
        frame:SetScale(settings.size / BASE_SIZE)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", unitFrame, "CENTER", settings.x, settings.y)
    end

    local function stopPreview()
        if previewTimer then previewTimer:Cancel(); previewTimer = nil end
        if preview then
            preview.container:Hide()
            preview.binding:SetEnabled(false)
            preview.index = nil
        end
    end

    local function getPreviewDuration(spellID)
        local _, _, difficultyID = GetInstanceInfo()
        local difficulty = difficultyID == 14 and "normal" or difficultyID == 15 and "heroic" or "mythic"
        for _, category in ipairs(BossMods.AuraSoundPresets or {}) do
            for _, aura in ipairs(category.auras) do
                if aura.spellID == spellID then
                    return aura.durations and aura.durations[difficulty] or 0
                end
            end
        end
        return 0
    end

    local function advancePreview()
        previewTimer = nil
        if not previewEnabled or not Engines.CanConfigureUnitFrameAuras() then
            stopPreview()
            return
        end
        local spells = definition.previewSpellIDs or {}
        preview.index = #spells > 0 and ((preview.index or 0) % #spells + 1) or 1
        local spellID = spells[preview.index]
        local duration = spellID and getPreviewDuration(spellID) or 0
        preview.icon:SetTexture((spellID and C_Spell.GetSpellTexture(spellID)) or definition.icon or 134400)
        preview.duration:SetTimeFromStart(GetTime(), duration)
        preview.cooldown:SetCooldownFromDurationObject(preview.duration, true)
        preview.binding:SetDuration(preview.duration)
        preview.binding:SetEnabled(duration > 0)
        if duration == 0 then preview.countdown:SetText("") end
        previewTimer = C_Timer.NewTimer(duration > 0 and duration or 5, advancePreview)
    end

    local function refreshPreview()
        if not previewEnabled or not Engines.CanConfigureUnitFrameAuras() then
            stopPreview()
            return
        end
        local unitFrame
        for _, slot in ipairs(slots) do
            if slot.unitFrame then unitFrame = slot.unitFrame; break end
        end
        if not unitFrame then
            stopPreview()
            return
        end
        if not preview then
            preview = {container = CreateFrame("Frame", nil, UIParent)}
            preview.container:SetSize(BASE_SIZE, BASE_SIZE)
            preview.container:EnableMouse(false)
            preview.button = CreateFrame("Frame", nil, preview.container)
            initializeButton(preview, preview.button)
            preview.duration = C_DurationUtil.CreateDuration()
            preview.binding = C_DurationUtil.CreateDurationTextBinding()
            preview.binding:SetToDefaults()
            preview.binding:SetFontString(preview.countdown)
            preview.binding:SetFormatter(getCountdownFormatter())
        end
        local settings = config.getSettings()
        place(preview.container, unitFrame, settings)
        applyAppearance(preview, settings)
        if not previewTimer then advancePreview() end
        preview.container:Show()
    end

    function handle:SetShown(value)
        shown = value == true
        for _, slot in ipairs(slots) do
            slot.container:SetShown(shown and slot.unitFrame ~= nil)
        end
    end

    function handle:Prepare(units, frames)
        if not Engines.CanConfigureUnitFrameAuras() or not loadAuraContainer() then return false end
        local settings = config.getSettings()
        for index = 1, 40 do
            local slot = slots[index]
            if not slot then slot = createSlot(); slots[index] = slot end
            local unit = units[index]
            local unitFrame = unit and frames[unit]
            if slot.unitFrame ~= unitFrame or slot.unit ~= unit then
                slot.container:Hide()
                slot.container:SetEnabled(false)
                slot.container:SetUnit("none")
                slot.container:ClearAllPoints()
                slot.container:SetParent(UIParent)
                slot.unitFrame, slot.unit = unitFrame, unit
                if unitFrame then
                    place(slot.container, unitFrame, settings)
                    slot.container:SetUnit(unit)
                    slot.container:SetEnabled(true)
                end
            elseif unitFrame then
                place(slot.container, unitFrame, settings)
            end
            applyAppearance(slot, settings)
        end
        self:SetShown(shown)
        refreshPreview()
        return true
    end

    function handle:SetPreview(value)
        previewEnabled = value == true
        refreshPreview()
    end

    function handle:Release()
        self:SetShown(false)
        self:SetPreview(false)
        if not Engines.CanConfigureUnitFrameAuras() then return end
        for _, slot in ipairs(slots) do
            slot.container:SetEnabled(false)
            slot.container:SetUnit("none")
            slot.container:ClearAllPoints()
            slot.container:SetParent(UIParent)
            slot.unitFrame, slot.unit = nil, nil
        end
        if preview then preview.container:SetParent(UIParent) end
    end

    return handle
end
