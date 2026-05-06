local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_BreakTimer", {
    enabled = false,
    fontSize = 48,
    strata = "DIALOG",
    scale = 1.0,
    position = {
        point = "CENTER",
        x = 0,
        y = 0,
        coordSpace = "UIParent"
    }
})

local Mod = E:NewModule("BossMods_BreakTimer", "AceEvent-3.0")

local IMAGE_POOL = "Dreams"
local TIMER_GAP = 8
local TICK_INTERVAL = 0.1
local PREVIEW_DURATION = 300
local LISTENER_TOKEN = "AdvanceRaidTools_BossMods_BreakTimer"
local POSITION_COORD_SPACE = "UIParent"

local function formatTime(seconds)
    if seconds < 0 then
        seconds = 0
    end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

local function getBigWigsBreakBarText()
    if type(BigWigsAPI) ~= "table" or type(BigWigsAPI.GetLocale) ~= "function" then
        return nil
    end
    local locale = BigWigsAPI:GetLocale("BigWigs")
    if type(locale) ~= "table" then
        return nil
    end
    local text = locale.breakBar
    if type(text) ~= "string" or text == "" then
        return nil
    end
    return text
end

local function isBreakText(text)
    text = E:SafeString(text)
    if not text then
        return false
    end
    local breakText = getBigWigsBreakBarText()
    return breakText ~= nil and text == breakText
end

function Mod:OnInitialize()
    self.editMode = false
    self:EnsureFrame()
end

function Mod:EnsureFrame()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "ART_BreakTimerFrame", UIParent)
    f:SetFrameStrata(self.db.strata or "DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(false)
    f:EnableMouse(false)
    f:Hide()

    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetJustifyH("CENTER")
    f.label:SetJustifyV("MIDDLE")

    f.image = f:CreateTexture(nil, "ARTWORK")

    f.timer = f:CreateFontString(nil, "OVERLAY")
    f.timer:SetJustifyH("CENTER")
    f.timer:SetJustifyV("MIDDLE")

    f._tickAcc = 0
    f:SetScript("OnUpdate", function(self, elapsed)
        if not Mod.endTime then
            return
        end
        self._tickAcc = self._tickAcc + elapsed
        if self._tickAcc < TICK_INTERVAL then
            return
        end
        self._tickAcc = 0
        local remaining = Mod.endTime - GetTime()
        if remaining <= 0 then
            Mod:Stop()
            return
        end
        self.timer:SetText(formatTime(remaining))
    end)

    self.frame = f
end

function Mod:OnEnable()
    if BigWigsLoader and BigWigsLoader.RegisterMessage then
        BigWigsLoader.RegisterMessage(LISTENER_TOKEN, "BigWigs_StartBar", function(_, _, key, text, time)
            Mod:OnStartBar(key, text, time)
        end)
        BigWigsLoader.RegisterMessage(LISTENER_TOKEN, "BigWigs_StopBar", function(_, _, text)
            Mod:OnStopBar(text)
        end)
    end
end

function Mod:OnDisable()
    self.editMode = false
    if BigWigsLoader and BigWigsLoader.UnregisterMessage then
        BigWigsLoader.UnregisterMessage(LISTENER_TOKEN, "BigWigs_StartBar")
        BigWigsLoader.UnregisterMessage(LISTENER_TOKEN, "BigWigs_StopBar")
    end
    self:Stop()
end

function Mod:OnStartBar(key, text, time)
    if InCombatLockdown() then
        return
    end
    if not isBreakText(text) then
        return
    end
    self:Start(key, time)
end

function Mod:OnStopBar(text)
    if not self.endTime then
        return
    end
    if InCombatLockdown() then
        return
    end
    if isBreakText(text) then
        self:Stop()
    end
end

function Mod:Start(_, duration)
    duration = tonumber(duration)
    if not duration or duration <= 0 then
        return
    end
    if not self:Show() then
        return
    end
    self.endTime = GetTime() + duration
    self.frame._tickAcc = 0
    self.frame.timer:SetText(formatTime(duration))
    E:SendMessage("ART_BREAKTIMER_STATE", true)
end

function Mod:Stop()
    local wasRunning = self.endTime ~= nil
    self.endTime = nil
    self.frame:Hide()
    if wasRunning then
        E:SendMessage("ART_BREAKTIMER_STATE", false)
    end
end

function Mod:Show()
    local imgPath, imgW, imgH = E:PickRandomImage(IMAGE_POOL)
    if not imgPath or not imgW or not imgH or imgW <= 0 or imgH <= 0 then
        return false
    end

    local f = self.frame
    local fontSize = self.db.fontSize or 48
    local fontPath = E:FetchModuleFont() or [[Fonts\FRIZQT__.TTF]]
    local outline = E.media.normFontOutline or "OUTLINE"

    local labelH = fontSize + 4
    local timerH = fontSize + 4

    f.label:SetFont(fontPath, fontSize, outline)
    f.label:SetText(L["BossMods_BreakTimer_Label"])
    f.label:ClearAllPoints()
    f.label:SetPoint("TOP", f, "TOP", 0, 0)
    f.label:SetWidth(imgW)
    f.label:SetHeight(labelH)

    f.image:SetTexture(imgPath)
    f.image:SetSize(imgW, imgH)
    f.image:ClearAllPoints()
    f.image:SetPoint("TOP", f.label, "BOTTOM", 0, -TIMER_GAP)

    f.timer:SetFont(fontPath, fontSize, outline)
    f.timer:SetText("")
    f.timer:ClearAllPoints()
    f.timer:SetPoint("TOP", f.image, "BOTTOM", 0, -TIMER_GAP)
    f.timer:SetWidth(imgW)
    f.timer:SetHeight(timerH)

    f:SetSize(imgW, labelH + TIMER_GAP + imgH + TIMER_GAP + timerH)
    self:ApplyScale()
    self:ApplyPosition()
    f:Show()
    return true
end

function Mod:ApplyPosition()
    self.db.position = self.db.position or {
        point = "CENTER",
        x = 0,
        y = 0,
        coordSpace = POSITION_COORD_SPACE
    }
    local pos = self.db.position
    if pos.coordSpace ~= POSITION_COORD_SPACE then
        local ratio = (self.frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
        pos.x = (pos.x or 0) * ratio
        pos.y = (pos.y or 0) * ratio
        pos.coordSpace = POSITION_COORD_SPACE
    end
    E:ApplyFramePosition(self.frame, pos)
end

function Mod:ApplyStrata()
    if not self.frame then
        return
    end
    self.frame:SetFrameStrata(self.db.strata or "DIALOG")
end

function Mod:ApplyScale()
    if not self.frame then
        return
    end
    local scale = tonumber(self.db.scale) or 1.0
    if scale < 0.1 then
        scale = 0.1
    end
    if self.db.position and self.db.position.coordSpace ~= POSITION_COORD_SPACE then
        self:ApplyPosition()
    end
    self.frame:SetScale(scale)
    self:ApplyPosition()
end

function Mod:ResetPosition()
    self.db.position = {
        point = "CENTER",
        x = 0,
        y = 0,
        coordSpace = POSITION_COORD_SPACE
    }
    if self.frame then
        self:ApplyPosition()
    end
end

function Mod:SavePosition(pos)
    if pos then
        self.db.position = {
            point = pos.point or "CENTER",
            x = pos.x or 0,
            y = pos.y or 0,
            coordSpace = POSITION_COORD_SPACE
        }
        if self.frame then
            self:ApplyPosition()
        end
        return
    end

    self.db.position = E:GetFramePosition(self.frame)
    self.db.position.coordSpace = POSITION_COORD_SPACE
end

function Mod:IsRunning()
    return self.endTime ~= nil
end

function Mod:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false

    if self.editMode then
        if self:IsRunning() then
            self.frame:Show()
            return
        end
        if self:Show() then
            self.frame._tickAcc = 0
            self.frame.timer:SetText(formatTime(PREVIEW_DURATION))
        end
    else
        if not self:IsRunning() then
            self.frame:Hide()
        end
    end
end

E:RegisterBossModFeature("BreakTimer", {
    tab = "Misc",
    order = 40,
    labelKey = "BossMods_BreakTimer",
    descKey = "BossMods_BreakTimerDesc",
    moduleName = "BossMods_BreakTimer"
})
