local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local MODULE_NAME = "BossMods_FocusChannelTimer"
local DIVINE_HYMN_SPELL_ID = 64843

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = false,
    displayType = "icon",
    duration = 15,
    iconID = DIVINE_HYMN_SPELL_ID,
    position = {point = "CENTER", x = 0, y = 180, coordSpace = "UIParent"},
    icon = {
        size = 64,
        cooldownSwipe = true,
        font = {
            name = "Friz Quadrata TT",
            size = 24,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        },
        border = {
            enabled = true,
            texture = "Pixel",
            size = 1,
            color = {0, 0, 0, 1}
        }
    },
    bar = {
        width = 300,
        height = 24,
        texture = "Blizzard",
        color = {0.2, 0.65, 1, 1},
        background = {0, 0, 0, 0.7},
        font = {
            name = "Friz Quadrata TT",
            size = 14,
            outline = "OUTLINE",
            color = {1, 1, 1, 1}
        }
    }
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function number(value, fallback)
    if E:IsSecret(value) then return fallback end
    value = tonumber(value)
    if value and value == value and math.abs(value) < math.huge then
        return value
    end
    return fallback
end

local function copyColor(value, fallback)
    value = type(value) == "table" and value or fallback
    return {
        number(value[1] or value.r, fallback[1]),
        number(value[2] or value.g, fallback[2]),
        number(value[3] or value.b, fallback[3]),
        number(value[4] or value.a, fallback[4])
    }
end

function Mod:EnsureDefaults()
    self.db.displayType = self.db.displayType == "bar" and "bar" or "icon"
    self.db.duration = math.max(1, math.min(120, number(self.db.duration, 15)))
    self.db.iconID = math.max(1, math.floor(number(self.db.iconID, DIVINE_HYMN_SPELL_ID)))

    self.db.position = type(self.db.position) == "table" and self.db.position or {}
    self.db.position.point = BossMods.Engines.Shared.NormalizeAnchorPoint(self.db.position.point)
    self.db.position.x = number(self.db.position.x, 0)
    self.db.position.y = number(self.db.position.y, 180)
    self.db.position.coordSpace = "UIParent"

    self.db.icon = type(self.db.icon) == "table" and self.db.icon or {}
    self.db.icon.size = math.max(16, math.min(256, number(self.db.icon.size, 64)))
    self.db.icon.cooldownSwipe = self.db.icon.cooldownSwipe ~= false
    self.db.icon.font = type(self.db.icon.font) == "table" and self.db.icon.font or {}
    self.db.icon.font.name = type(self.db.icon.font.name) == "string" and self.db.icon.font.name or "Friz Quadrata TT"
    self.db.icon.font.size = math.max(8, math.min(72, number(self.db.icon.font.size, 24)))
    self.db.icon.font.outline = type(self.db.icon.font.outline) == "string" and self.db.icon.font.outline or "OUTLINE"
    self.db.icon.font.color = copyColor(self.db.icon.font.color, {1, 1, 1, 1})
    self.db.icon.border = type(self.db.icon.border) == "table" and self.db.icon.border or {}
    self.db.icon.border.enabled = self.db.icon.border.enabled ~= false
    self.db.icon.border.texture = type(self.db.icon.border.texture) == "string" and self.db.icon.border.texture or "Pixel"
    self.db.icon.border.size = math.max(1, math.min(16, number(self.db.icon.border.size, 1)))
    self.db.icon.border.color = copyColor(self.db.icon.border.color, {0, 0, 0, 1})

    self.db.bar = type(self.db.bar) == "table" and self.db.bar or {}
    self.db.bar.width = math.max(100, math.min(1000, number(self.db.bar.width, 300)))
    self.db.bar.height = math.max(10, math.min(100, number(self.db.bar.height, 24)))
    self.db.bar.texture = type(self.db.bar.texture) == "string" and self.db.bar.texture or "Blizzard"
    self.db.bar.color = copyColor(self.db.bar.color, {0.2, 0.65, 1, 1})
    self.db.bar.background = copyColor(self.db.bar.background, {0, 0, 0, 0.7})
    self.db.bar.font = type(self.db.bar.font) == "table" and self.db.bar.font or {}
    self.db.bar.font.name = type(self.db.bar.font.name) == "string" and self.db.bar.font.name or "Friz Quadrata TT"
    self.db.bar.font.size = math.max(8, math.min(60, number(self.db.bar.font.size, 14)))
    self.db.bar.font.outline = type(self.db.bar.font.outline) == "string" and self.db.bar.font.outline or "OUTLINE"
    self.db.bar.font.color = copyColor(self.db.bar.font.color, {1, 1, 1, 1})
end

function Mod:BuildBarConfig()
    local db = self.db.bar
    return {
        parent = self.anchor,
        showFill = true,
        strata = "HIGH",
        size = {w = db.width, h = db.height},
        icon = {enabled = false},
        statusBar = {texture = db.texture, color = db.color},
        label = {font = db.font.name, size = db.font.size, outline = db.font.outline, color = db.font.color},
        right = {font = db.font.name, size = db.font.size, outline = db.font.outline, color = db.font.color},
        background = {color = db.background, opacity = db.background[4] or 0.7},
        border = {enabled = true, texture = "Pixel", size = 1, color = {0, 0, 0, 1}}
    }
end

function Mod:EnsureFrames()
    if self.anchor then return end

    self.anchor = CreateFrame("Frame", "ART_FocusChannelTimerAnchor", UIParent)
    self.anchor:SetFrameStrata("HIGH")
    self.anchor:SetClampedToScreen(true)

    local icon = CreateFrame("Frame", nil, self.anchor, "BackdropTemplate")
    icon:SetPoint("CENTER", self.anchor, "CENTER")
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetHideCountdownNumbers(true)
    icon.cooldown:SetDrawEdge(false)
    icon.text = icon:CreateFontString(nil, "OVERLAY")
    icon.text:SetPoint("CENTER")
    icon:SetScript("OnUpdate", function(_, elapsed) self:OnIconUpdate(elapsed) end)
    icon:Hide()
    self.iconFrame = icon

    self.bar = BossMods.Engines.Bar(self:BuildBarConfig())
    self.bar.frame:ClearAllPoints()
    self.bar.frame:SetPoint("CENTER", self.anchor, "CENTER")
    self.bar:SetMode("label")
    self.bar:Hide()

    self:ApplyPosition()
end

function Mod:GetIconTexture()
    local iconID = math.floor(number(self.db.iconID, DIVINE_HYMN_SPELL_ID))
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(iconID) or iconID
    end
    return iconID
end

function Mod:ApplyIconAppearance()
    local db, frame = self.db.icon, self.iconFrame
    frame:SetSize(db.size, db.size)
    frame.texture:SetTexture(self:GetIconTexture())
    frame.cooldown:SetDrawSwipe(db.cooldownSwipe)
    E:ApplyFontString(frame.text, E:FetchModuleFont(db.font.name), db.font.size, db.font.outline)
    local r, g, b, a = E:ColorTuple(db.font.color, 1, 1, 1, 1)
    frame.text:SetTextColor(r, g, b, a)
    local border = db.border
    local br, bg, bb, ba = E:ColorTuple(border.color, 0, 0, 0, 1)
    E:ApplyOuterBorder(frame, {
        enabled = border.enabled,
        edgeFile = E:FetchBorder(border.texture),
        edgeSize = border.size,
        r = br, g = bg, b = bb, a = ba
    })
end

function Mod:ApplyPosition()
    if not self.anchor then return end
    local width = self.db.displayType == "bar" and self.db.bar.width or self.db.icon.size
    local height = self.db.displayType == "bar" and self.db.bar.height or self.db.icon.size
    self.anchor:SetSize(width, height)
    E:ApplyFramePosition(self.anchor, self.db.position)
end

function Mod:Refresh()
    self:EnsureDefaults()
    self:EnsureFrames()
    self:ApplyIconAppearance()
    self.bar:Apply(self:BuildBarConfig())
    self.bar.frame:ClearAllPoints()
    self.bar.frame:SetPoint("CENTER", self.anchor, "CENTER")
    self:ApplyPosition()

    if self.editMode or self.previewMode then
        self:RenderPreview()
    elseif self.timerEndsAt and self.timerEndsAt > GetTime() then
        self:ShowRunningTimer(self.timerEndsAt - GetTime())
    else
        self:HideDisplays()
    end
end

function Mod:HideDisplays()
    if self.iconFrame then
        self.iconFrame:Hide()
        self.iconFrame.cooldown:Clear()
    end
    if self.bar then
        self.bar.onStop = nil
        self.bar:Stop()
        self.bar:Hide()
    end
end

function Mod:RenderPreview()
    self:HideDisplays()
    local duration = self.db.duration
    if self.db.displayType == "bar" then
        self.bar:SetLabel(L["BossMods_FocusChannelTimer"])
        self.bar:SetRight(("%.0f"):format(duration))
        self.bar:SetValue(1)
        self.bar:Show()
    else
        self.iconFrame.text:SetText(("%.0f"):format(duration))
        self.iconFrame.cooldown:Hide()
        self.iconFrame:Show()
    end
end

function Mod:ShowRunningTimer(remaining)
    self:HideDisplays()
    remaining = math.max(0.01, remaining)
    if self.db.displayType == "bar" then
        local bar = self.bar
        bar:SetLabel(L["BossMods_FocusChannelTimer"])
        bar:SetRight(("%.1f"):format(remaining))
        bar.onTick = function(elapsed, total)
            bar:SetRight(("%.1f"):format(math.max(0, total - elapsed)))
        end
        bar.onStop = function()
            bar:Hide()
            if not self.editMode and not self.previewMode then self.timerEndsAt = nil end
        end
        bar:Start({total = remaining})
    else
        local now = GetTime()
        self.iconFrame.cooldown:Show()
        self.iconFrame.cooldown:SetCooldown(now, remaining)
        self.iconFrame._tick = 1
        self.iconFrame.text:SetText(("%.0f"):format(math.ceil(remaining)))
        self.iconFrame:Show()
    end
end

function Mod:OnIconUpdate(elapsed)
    if not self.iconFrame:IsShown() or self.editMode or self.previewMode then return end
    self.iconFrame._tick = (self.iconFrame._tick or 0) + elapsed
    if self.iconFrame._tick < 0.05 then return end
    self.iconFrame._tick = 0
    local remaining = (self.timerEndsAt or 0) - GetTime()
    if remaining <= 0 then
        self.timerEndsAt = nil
        self.iconFrame:Hide()
        self.iconFrame.cooldown:Clear()
        return
    end
    self.iconFrame.text:SetText(("%.0f"):format(math.ceil(remaining)))
end

function Mod:StartTimer()
    if not self:IsEnabled() then return end
    self.editMode, self.previewMode = false, false
    self.timerEndsAt = GetTime() + self.db.duration
    self:ShowRunningTimer(self.db.duration)
end

function Mod:SetEditMode(enabled)
    self.editMode = enabled == true and self:IsEnabled() and not InCombatLockdown()
    if self.editMode then self.previewMode = false end
    self:Refresh()
end

function Mod:SetPreviewMode(enabled)
    self.previewMode = enabled == true and self:IsEnabled() and not InCombatLockdown()
    if self.previewMode then self.editMode = false end
    self:Refresh()
end

function Mod:GetAnchor()
    self:EnsureFrames()
    return self.anchor
end

function Mod:SavePosition(position)
    position = position or E:GetFramePosition(self:GetAnchor())
    self.db.position = {
        point = position.point,
        x = position.x,
        y = position.y,
        coordSpace = "UIParent"
    }
    self:ApplyPosition()
end

function Mod:ResetPosition()
    self:SavePosition({point = "CENTER", x = 0, y = 180})
end

local function eventUnitIsFocus(unit)
    if E:IsSecret(unit) or not UnitExists("focus") then return false end
    if unit == "focus" then return true end
    return UnitExists(unit) and UnitIsUnit(unit, "focus") == true
end

function Mod:UNIT_SPELLCAST_CHANNEL_START(_, unit)
    if not eventUnitIsFocus(unit) then return end
    if UnitExists("focus") and UnitCanAssist("player", "focus") then
        self.focusChannelActive = true
    end
end

function Mod:UNIT_SPELLCAST_CHANNEL_STOP(_, unit)
    if not eventUnitIsFocus(unit) or not self.focusChannelActive then return end
    self.focusChannelActive = false
    self:StartTimer()
end

function Mod:PLAYER_FOCUS_CHANGED()
    self.focusChannelActive = false
end

function Mod:OnInitialize()
    self.editMode, self.previewMode = false, false
    self:EnsureDefaults()
end

function Mod:OnEnable()
    self:EnsureDefaults()
    self:EnsureFrames()
    self:Refresh()
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.focusChannelActive = false
    self.timerEndsAt = nil
    self.editMode, self.previewMode = false, false
    self:HideDisplays()
end

E:RegisterBossModFeature("FocusChannelTimer", {
    tab = "Misc",
    order = 55,
    labelKey = "BossMods_FocusChannelTimer",
    descKey = "BossMods_FocusChannelTimerDesc",
    moduleName = MODULE_NAME
})
