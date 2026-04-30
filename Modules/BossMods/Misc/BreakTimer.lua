local E, L, P = unpack(ART)

P.modules.BossMods_BreakTimer = {
    enabled = false,
    defaultDuration = 60,
    fontSize = 48,
    strata = "DIALOG",
    scale = 1.0,
    position = {
        point = "CENTER",
        x = 0,
        y = 0
    }
}

local Mod = E:NewModule("BossMods_BreakTimer", "AceEvent-3.0")

local IMAGE_POOL = "Dreams"
local TIMER_GAP = 8
local TICK_INTERVAL = 0.1
local LISTENER_TOKEN = "AdvanceRaidTools_BossMods_BreakTimer"

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
    if type(text) ~= "string" or text == "" then
        return false
    end
    local breakText = getBigWigsBreakBarText()
    return breakText ~= nil and text == breakText
end

function Mod:OnModuleInitialize()
    self:EnsureFrame()
end

function Mod:EnsureFrame()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "ART_BreakTimerFrame", UIParent)
    f:SetFrameStrata(self.db.strata or "DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        Mod:SavePosition()
    end)
    f:Hide()

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
    if BigWigsLoader and BigWigsLoader.UnregisterMessage then
        BigWigsLoader.UnregisterMessage(LISTENER_TOKEN, "BigWigs_StartBar")
        BigWigsLoader.UnregisterMessage(LISTENER_TOKEN, "BigWigs_StopBar")
    end
    self:Stop()
end

function Mod:OnStartBar(key, text, time)
    if not isBreakText(text) then
        return
    end
    self:Start(key, time)
end

function Mod:OnStopBar(text)
    if not self.endTime then
        return
    end
    if self:IsTest() then
        return
    end
    if isBreakText(text) then
        self:Stop()
    end
end

function Mod:Start(key, duration)
    duration = tonumber(duration)
    if not duration or duration <= 0 then
        return
    end
    if not self:Show() then
        return
    end
    self.breakKey = key
    self.endTime = GetTime() + duration
    self.frame._tickAcc = 0
    self.frame.timer:SetText(formatTime(duration))
    E:SendMessage("ART_BREAKTIMER_STATE", true)
end

function Mod:Stop()
    local wasRunning = self.endTime ~= nil
    self.endTime = nil
    self.breakKey = nil
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

    f.image:SetTexture(imgPath)
    f.image:SetSize(imgW, imgH)
    f.image:ClearAllPoints()
    f.image:SetPoint("TOP", f, "TOP", 0, 0)

    f.timer:SetFont(fontPath, fontSize, outline)
    f.timer:SetText("")
    f.timer:ClearAllPoints()
    f.timer:SetPoint("TOP", f.image, "BOTTOM", 0, -TIMER_GAP)
    f.timer:SetWidth(imgW)
    f.timer:SetHeight(fontSize + 4)

    f:SetSize(imgW, imgH + TIMER_GAP + fontSize + 4)
    self:ApplyScale()
    self:ApplyPosition()
    f:Show()
    return true
end

function Mod:ApplyPosition()
    local pos = self.db.position or {}
    local point = pos.point or "CENTER"
    local x = pos.x or 0
    local y = pos.y or 0
    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, point, x, y)
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
    self.frame:SetScale(scale)
end

function Mod:ResetPosition()
    self.db.position = {
        point = "CENTER",
        x = 0,
        y = 0
    }
    if self.frame then
        self:ApplyPosition()
    end
end

function Mod:SavePosition()
    local point, _, _, x, y = self.frame:GetPoint(1)
    self.db.position = {
        point = point or "CENTER",
        x = math.floor((x or 0) + 0.5),
        y = math.floor((y or 0) + 0.5)
    }
end

function Mod:IsRunning()
    return self.endTime ~= nil
end

function Mod:IsTest()
    return self.breakKey == "ART_TEST_BREAK"
end

function Mod:Test(seconds)
    self:Start("ART_TEST_BREAK", tonumber(seconds) or self.db.defaultDuration or 60)
end

function Mod:Toggle(seconds)
    if self:IsRunning() then
        self:Stop()
    else
        self:Test(seconds)
    end
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("BreakTimer", {
            tab = "Misc",
            order = 40,
            labelKey = "BossMods_BreakTimer",
            descKey = "BossMods_BreakTimerDesc",
            moduleName = "BossMods_BreakTimer"
        })
    end
end
