local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_Bress", {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 350
    },
    iconSize = 64,
    border = {
        enabled = false,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    },
    cooldownSwipe = true,
    timeText = {
        size = 18,
        outline = "OUTLINE",
        anchor = "CENTER",
        offsetX = 0,
        offsetY = 0,
        color = {1, 1, 1, 1}
    },
    chargeText = {
        size = 16,
        outline = "OUTLINE",
        anchor = "BOTTOMRIGHT",
        offsetX = -2,
        offsetY = 2,
        color = {1, 1, 1, 1}
    }
})

local REBIRTH_SPELL = 20484
local TICK_INTERVAL = 0.1

local Bress = E:NewModule("BossMods_Bress", "AceEvent-3.0")

local function applyTextStyle(fs, cfg, parent)
    local font = E:FetchModuleFont()
    local size = cfg.size or 16
    local outline = cfg.outline or ""
    E:ApplyFontString(fs, font, size, outline)
    local r, g, b, a = E:ColorTuple(cfg.color, 1, 1, 1, 1)
    fs:SetTextColor(r, g, b, a)
    fs:ClearAllPoints()
    local anchor = cfg.anchor or "CENTER"
    fs:SetPoint(anchor, parent, anchor, cfg.offsetX or 0, cfg.offsetY or 0)
end

local function shouldShowInZone()
    local _, instanceType = GetInstanceInfo()
    if instanceType == "raid" or instanceType == "scenario" then
        return true
    end
    if C_ChallengeMode and (C_ChallengeMode.GetActiveKeystoneInfo() or 0) > 0 then
        return true
    end
    return false
end

function Bress:OnInitialize()
    self.editMode = false
    self:EnsureFrame()
    self:Apply()
    self.frame:Hide()
end

function Bress:OnEnable()
    self:Apply()

    self:RegisterEvent("SPELL_UPDATE_CHARGES", "OnRefreshEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRefreshEvent")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnRefreshEvent")
    self:RegisterEvent("CHALLENGE_MODE_START", "OnRefreshEvent")
    self:RegisterEvent("ENCOUNTER_START", "OnRefreshEvent")
    self:RegisterEvent("ENCOUNTER_END", "OnRefreshEvent")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnRefreshEvent")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    self:UpdateState()
end

function Bress:OnDisable()
    self.editMode = false
    self.frame:Hide()
end

function Bress:EnsureFrame()
    if self.frame then
        return
    end
    local f = CreateFrame("Frame", "ART_BossMods_Bress", UIParent, "BackdropTemplate")
    f:SetSize(self.db.iconSize, self.db.iconSize)
    f:SetFrameStrata("MEDIUM")
    f:Hide()

    f.icon = f:CreateTexture(nil, "BACKGROUND")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    f.cooldown:SetAllPoints()
    f.cooldown:SetHideCountdownNumbers(true)
    f.cooldown:SetDrawEdge(false)
    f.cooldown:SetFrameLevel(40)

    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints()
    f.textLayer:SetFrameLevel(50)

    f.timeText = f.textLayer:CreateFontString(nil, "ARTWORK")
    f.chargeText = f.textLayer:CreateFontString(nil, "ARTWORK")
    f.chargeText:SetShadowOffset(1, -1)

    f._cdStart = 0
    f._cdDuration = 0
    f._tickAcc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        if Bress.editMode then
            return
        end
        self._tickAcc = self._tickAcc + elapsed
        if self._tickAcc < TICK_INTERVAL then
            return
        end
        self._tickAcc = 0
        local remaining = (self._cdStart + self._cdDuration) - GetTime()
        self.timeText:SetFormattedText("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
        self.timeText:SetAlpha(remaining)
    end)

    self.frame = f
end

function Bress:ApplyBackdrop()
    local db = self.db
    local f = self.frame
    local border = db.border or {}

    local borderEnabled = border.enabled and true or false
    local edgeFile = E:FetchBorder(border.texture)
    local edgeSize = math.min(border.size or 1, 16)
    local er, eg, eb, ea = E:ColorTuple(border.color, 0, 0, 0, 1)

    E:ApplyOuterBorder(f, {
        enabled = borderEnabled,
        edgeFile = edgeFile,
        edgeSize = edgeSize,
        r = er,
        g = eg,
        b = eb,
        a = ea
    })
end

function Bress:Apply()
    local db = self.db
    local f = self.frame
    f:SetSize(db.iconSize, db.iconSize)
    E:ApplyFramePosition(f, db.position)

    f.icon:SetTexture(C_Spell.GetSpellTexture(REBIRTH_SPELL))

    self:ApplyBackdrop()
    applyTextStyle(f.timeText, db.timeText, f)
    applyTextStyle(f.chargeText, db.chargeText, f)
    f.cooldown:SetDrawSwipe(db.cooldownSwipe and true or false)
end

function Bress:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:Apply()
    if self.editMode then
        self:RenderEditPreview()
    else
        self:UpdateState()
    end
end

function Bress:OnRefreshEvent()
    self:UpdateState()
end

function Bress:UpdateState()
    if self.editMode or not self.frame then
        return
    end
    local f = self.frame

    if not shouldShowInZone() then
        f:Hide()
        return
    end

    local info = C_Spell.GetSpellCharges(REBIRTH_SPELL)
    if not info then
        f:Hide()
        return
    end

    local current = info.currentCharges or 0
    local maxCharges = info.maxCharges or 0
    local started = info.cooldownStartTime or 0
    local duration = info.cooldownDuration or 0

    if current == 0 and maxCharges == 0 then
        f:Hide()
        return
    end

    f.chargeText:SetFormattedText("%d", current)
    f.chargeText:SetAlpha(1)
    if current == 0 then
        f.chargeText:SetTextColor(1, 0, 0, 1)
    else
        local r, g, b, a = E:ColorTuple(self.db.chargeText.color, 1, 1, 1, 1)
        f.chargeText:SetTextColor(r, g, b, a)
    end

    f.cooldown:SetCooldown(started, duration)
    f._cdStart = started
    f._cdDuration = duration
    f._tickAcc = TICK_INTERVAL

    f:Show()
end

function Bress:RenderEditPreview()
    local f = self.frame
    f.icon:SetTexture(C_Spell.GetSpellTexture(REBIRTH_SPELL))
    f.timeText:SetText("1:23")
    f.timeText:SetAlpha(1)
    f.chargeText:SetText("3")
    f.chargeText:SetAlpha(1)
    f.cooldown:Hide()
    f._cdStart = 0
    f._cdDuration = 0
    f:Show()
end

function Bress:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false

    if self.editMode then
        self:RenderEditPreview()
    else
        self.frame.cooldown:Show()
        self:UpdateState()
    end
end

function Bress:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:Apply()
end

E:RegisterBossModFeature("Bress", {
    tab = "Misc",
    order = 30,
    labelKey = "BossMods_Bress",
    descKey = "BossMods_BressDesc",
    moduleName = "BossMods_Bress"
})
