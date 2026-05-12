local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_BossPush", {
    enabled = false,
    selectedBar = 1,
    position = {
        point = "CENTER",
        x = 0,
        y = 260
    },
    strata = "HIGH",
    bar = {
        width = 360,
        height = 24,
        color = {0.90, 0.12, 0.12, 1},
        lineColor = {0.08, 0.52, 1.00, 1},
        ghostWidth = 2
    },
    font = {
        size = 12,
        outline = "OUTLINE",
        color = {1, 1, 1, 1}
    },
    background = {
        enabled = true,
        color = {0, 0, 0},
        opacity = 0.65
    },
    border = {
        enabled = true,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    },
    bars = {}
})

local Mod = E:NewModule("BossMods_BossPush", "AceEvent-3.0")

local SHARE_TYPE = "bossPush"
local SHARE_VERSION = "ART_BP1"
local TICK_INTERVAL = 0.05
local MAX_POINTS = 8

local UNIT_VALUES = {
    boss1 = "Boss 1",
    boss2 = "Boss 2",
    boss3 = "Boss 3",
    boss4 = "Boss 4",
    boss5 = "Boss 5",
    boss6 = "Boss 6",
    boss7 = "Boss 7",
    boss8 = "Boss 8",
    target = "Target",
    focus = "Focus"
}

local UNIT_SORTING = {"boss1", "boss2", "boss3", "boss4", "boss5", "boss6", "boss7", "boss8", "target", "focus"}

local TRIGGER_VALUES = {
    encounter = "Encounter",
    combat = "Combat"
}

local TRIGGER_SORTING = {"encounter", "combat"}

local CUSTOM_ENCOUNTER = "custom"
local ENCOUNTER_VALUES = {
    [0] = "Any Encounter",
    [3176] = "The Voidspire - Imperator Averzian",
    [3177] = "The Voidspire - Vorasius",
    [3179] = "The Voidspire - Fallen-King Salhadaar",
    [3178] = "The Voidspire - Vaelgor & Ezzorak",
    [3180] = "The Voidspire - Lightblinded Vanguard",
    [3181] = "The Voidspire - Crown of the Cosmos",
    [3306] = "The Dreamrift - Chimaerus the Undreamt God",
    [3182] = "March on Quel'Danas - Belo'ren, Child of Al'ar",
    [3183] = "March on Quel'Danas - Midnight Falls",
    [CUSTOM_ENCOUNTER] = L["Custom"] or "Custom"
}

local ENCOUNTER_SORTING = {0, 3176, 3177, 3179, 3178, 3180, 3181, 3306, 3182, 3183, CUSTOM_ENCOUNTER}

local function copyTable(src)
    if type(src) ~= "table" then
        return nil
    end
    if CopyTable then
        return CopyTable(src)
    end
    local out = {}
    for k, v in pairs(src) do
        out[k] = type(v) == "table" and copyTable(v) or v
    end
    return out
end

local function clamp(v, lo, hi)
    v = tonumber(v)
    if not v then
        return lo
    end
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

local function safeName(name, fallback)
    name = E:SafeString(name) or fallback or L["BossMods_BossPushDefaultName"] or "Boss Push"
    name = strtrim(name)
    if name == "" then
        name = fallback or L["BossMods_BossPushDefaultName"] or "Boss Push"
    end
    return name
end

local function newID()
    local stamp = GetServerTime and GetServerTime() or time()
    return ("%s-%06d"):format(tostring(stamp), math.random(0, 999999))
end

local function formatTime(seconds)
    seconds = tonumber(seconds) or 0
    local prefix = ""
    if seconds < 0 then
        prefix = "+"
        seconds = -seconds
    end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return ("%s%d:%02d"):format(prefix, m, s)
end

local function normalizePoints(src, targetTime, targetPercent)
    local points = {}
    if type(src) == "table" then
        for _, p in ipairs(src) do
            if type(p) == "table" then
                local t = tonumber(p.time)
                local hp = tonumber(p.hp)
                if t and t > 0 and hp then
                    points[#points + 1] = {
                        time = clamp(t, 0.1, 7200),
                        hp = clamp(hp, 0, 100)
                    }
                    if #points >= MAX_POINTS then
                        break
                    end
                end
            end
        end
    end
    if #points == 0 then
        points[1] = {
            time = targetTime,
            hp = targetPercent
        }
    end
    table.sort(points, function(a, b)
        return a.time < b.time
    end)
    return points
end

local function normalizeBar(src, forceNewID)
    src = type(src) == "table" and src or {}
    local targetTime = clamp(src.targetTime or 120, 1, 7200)
    local showOffset = clamp(src.showOffset or ((src.showAt or (targetTime - 10)) - targetTime), -7200, 0)
    local showAt = clamp(targetTime + showOffset, 0, 7200)
    local targetPercent = clamp(src.targetPercent or 70, 0, 100)
    local encounterID = math.floor(clamp(src.encounterID or 0, 0, 999999))
    local customEncounterID = math.floor(clamp(src.customEncounterID or encounterID, 0, 999999))
    local encounterMode = (src.encounterMode == CUSTOM_ENCOUNTER or not ENCOUNTER_VALUES[encounterID]) and CUSTOM_ENCOUNTER or "preset"
    if encounterMode == CUSTOM_ENCOUNTER then
        encounterID = customEncounterID
    end
    local trigger = src.trigger == "combat" and "combat" or "encounter"
    local bossUnit = UNIT_VALUES[src.bossUnit] and src.bossUnit or "boss1"

    return {
        id = forceNewID and newID() or safeName(src.id, newID()),
        enabled = src.enabled ~= false,
        name = safeName(src.name),
        trigger = trigger,
        encounterMode = encounterMode,
        encounterID = encounterID,
        customEncounterID = customEncounterID,
        bossUnit = bossUnit,
        showOffset = showOffset,
        showAt = showAt,
        targetTime = targetTime,
        targetPercent = targetPercent,
        points = normalizePoints(src.points, targetTime, targetPercent)
    }
end

local function exportBar(bar)
    bar = normalizeBar(bar)
    return {
        id = bar.id,
        enabled = bar.enabled,
        name = bar.name,
        trigger = bar.trigger,
        encounterMode = bar.encounterMode,
        encounterID = bar.encounterID,
        customEncounterID = bar.customEncounterID,
        bossUnit = bar.bossUnit,
        showOffset = bar.showOffset,
        targetTime = bar.targetTime,
        targetPercent = bar.targetPercent,
        points = copyTable(bar.points)
    }
end

local function paintUnitHealth(row, unit)
    local healthBar = row and row.healthBar
    if not healthBar then
        return
    end
    if not unit or not UnitExists(unit) then
        healthBar:SetMinMaxValues(0, 1)
        healthBar:SetValue(0)
        return
    end

    healthBar:SetMinMaxValues(0, UnitHealthMax(unit))
    healthBar:SetValue(UnitHealth(unit))
end

local function targetPercentForBar(bar)
    return clamp(bar and bar.targetPercent or 70, 0, 100)
end

local function setProgressText(text, unit, targetPercent, remainingText)
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if unit and UnitExists(unit) and UnitHealthPercent and curve then
        local actualPercent = UnitHealthPercent(unit, true, curve)
        if actualPercent then
            text:SetFormattedText("%.0f%% / %.1f%%  %s", actualPercent, targetPercent, remainingText)
            return
        end
    end
    text:SetFormattedText("-- / %.1f%%  %s", targetPercent, remainingText)
end

local function colorTuple(c, fr, fg, fb, fa)
    return E:ColorTuple(c, fr, fg, fb, fa)
end

local function bossDisplayName(bar)
    local unit = bar and bar.bossUnit or "boss1"
    local name = unit and UnitExists(unit) and UnitName(unit)
    if name then
        return name
    end
    return UNIT_VALUES[unit] or L["BossMods_BossPush"]
end

local function linkLabel(name)
    name = safeName(name)
    name = name:gsub("[|%[%]]", "")
    if #name > 32 then
        name = strsub(name, 1, 29) .. "..."
    end
    return name
end

function Mod:GetUnitValues()
    return UNIT_VALUES
end

function Mod:GetUnitSorting()
    return UNIT_SORTING
end

function Mod:GetTriggerValues()
    return TRIGGER_VALUES
end

function Mod:GetTriggerSorting()
    return TRIGGER_SORTING
end

function Mod:GetEncounterValues()
    return ENCOUNTER_VALUES
end

function Mod:GetEncounterSorting()
    return ENCOUNTER_SORTING
end

function Mod:GetCustomEncounterKey()
    return CUSTOM_ENCOUNTER
end

function Mod:GetBars()
    if type(self.db.bars) ~= "table" then
        self.db.bars = {}
    end
    for i, bar in ipairs(self.db.bars) do
        self.db.bars[i] = normalizeBar(bar)
    end
    return self.db.bars
end

function Mod:GetBar(index)
    index = tonumber(index)
    if not index then
        return nil
    end
    return self:GetBars()[index]
end

function Mod:GetSelectedBar()
    local bars = self:GetBars()
    if #bars == 0 then
        self.db.selectedBar = nil
        return nil, nil
    end
    local idx = math.floor(tonumber(self.db.selectedBar) or 1)
    if idx < 1 then
        idx = 1
    elseif idx > #bars then
        idx = #bars
    end
    self.db.selectedBar = idx
    return bars[idx], idx
end

local function uniqueBarName(name, bars)
    name = safeName(name)
    local names = {}
    for _, bar in ipairs(bars or {}) do
        names[safeName(bar and bar.name)] = true
    end
    if not names[name] then
        return name
    end

    local copyName = ("%s Copy"):format(name)
    if not names[copyName] then
        return copyName
    end

    local n = 2
    while names[("%s Copy %d"):format(name, n)] do
        n = n + 1
    end
    return ("%s Copy %d"):format(name, n)
end

function Mod:AddBar(template)
    local bars = self:GetBars()
    local bar = normalizeBar(template or {}, true)
    if not template or not template.name then
        bar.name = ("%s %d"):format(L["BossMods_BossPushDefaultName"] or "Boss Push", #bars + 1)
    end
    bars[#bars + 1] = bar
    self.db.selectedBar = #bars
    E:SendMessage("ART_BOSSPUSH_BARS_CHANGED", self.db.selectedBar)
    self:Refresh()
    return self.db.selectedBar
end

function Mod:DeleteBar(index)
    local bars = self:GetBars()
    index = math.floor(tonumber(index or self.db.selectedBar) or 0)
    if index < 1 or index > #bars then
        return false
    end
    table.remove(bars, index)
    if #bars == 0 then
        self.db.selectedBar = nil
    else
        self.db.selectedBar = math.min(index, #bars)
    end
    E:SendMessage("ART_BOSSPUSH_BARS_CHANGED", self.db.selectedBar)
    self:Refresh()
    return true
end

function Mod:DuplicateBar(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    if not bar then
        return nil
    end
    local copy = exportBar(bar)
    copy.id = newID()
    copy.name = uniqueBarName(copy.name, self:GetBars())
    return self:AddBar(copy)
end

function Mod:ImportBarData(data)
    local bar = normalizeBar(data, true)
    local bars = self:GetBars()
    bar.name = uniqueBarName(bar.name, bars)

    bars[#bars + 1] = bar
    self.db.selectedBar = #bars
    E:SendMessage("ART_BOSSPUSH_BARS_CHANGED", self.db.selectedBar)
    self:Refresh()
    return self.db.selectedBar, false
end

function Mod:ExportBarString(indexOrBar)
    local bar = type(indexOrBar) == "table" and indexOrBar or self:GetBar(indexOrBar or self.db.selectedBar)
    if not bar then
        return ""
    end
    return E:EncodeShareString(SHARE_TYPE, exportBar(bar))
end

function Mod:DecodeBarString(text)
    local data, err = E:DecodeShareString(SHARE_TYPE, text)
    if not data then
        return nil, err or (L["BossMods_BossPushInvalidImport"] or "Invalid Boss Push string")
    end
    return normalizeBar(data)
end

function Mod:ImportBarString(text)
    local bar, err = self:DecodeBarString(text)
    if not bar then
        return nil, err
    end
    return self:ImportBarData(bar)
end

function Mod:GetExportText(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    if not bar then
        return ""
    end
    return self:ExportBarString(bar)
end

function Mod:ShareBarToChat(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    if not bar then
        return false, L["BossMods_BossPushNoBarSelected"]
    end
    return E:ShareDataToChat(SHARE_TYPE, exportBar(bar), ("ART Boss Push: %s"):format(linkLabel(bar.name)))
end

function Mod:EnsureFrame()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "ART_BossMods_BossPush", UIParent)
    f:SetFrameStrata(self.db.strata or "HIGH")
    f:Hide()
    f._tickAcc = 0
    f:SetScript("OnUpdate", function(frame, elapsed)
        frame._tickAcc = frame._tickAcc + elapsed
        if frame._tickAcc < TICK_INTERVAL then
            return
        end
        frame._tickAcc = 0
        Mod:UpdateActive()
    end)
    self.frame = f
    self.rows = {}
end

function Mod:EnsureRow(index)
    self:EnsureFrame()
    if self.rows[index] then
        return self.rows[index]
    end

    local row = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    row:Hide()

    row.healthBar = CreateFrame("StatusBar", nil, row)
    row.healthBar:SetAllPoints(row)
    row.healthBar:SetMinMaxValues(0, 1)
    row.healthBar:SetValue(0)

    row.overlay = CreateFrame("Frame", nil, row)
    row.overlay:SetAllPoints(row)
    row.overlay:SetFrameLevel(row.healthBar:GetFrameLevel() + 1)

    row.label = row.overlay:CreateFontString(nil, "OVERLAY")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.right = row.overlay:CreateFontString(nil, "OVERLAY")
    row.right:SetJustifyH("RIGHT")
    row.right:SetWordWrap(false)

    row.ghost = row.overlay:CreateTexture(nil, "OVERLAY")
    row.ghost:SetColorTexture(0.08, 0.52, 1, 1)
    row.ghost:Hide()

    self.rows[index] = row
    self:ApplyRowStyle(row)
    return row
end

function Mod:ApplyRowStyle(row)
    local db = self.db
    local tex = E:FetchStatusBar()
    row.healthBar:SetStatusBarTexture(tex)
    row:SetSize(db.bar.width, db.bar.height)
    row.ghost:SetWidth(db.bar.ghostWidth or 2)

    local bg = db.background or {}
    local bgColor = bg.color or {}
    local bgA = bg.enabled and (bg.opacity or 0.65) or 0
    row:SetBackdrop({
        bgFile = E.media.blankTex,
        insets = {
            left = 0,
            right = 0,
            top = 0,
            bottom = 0
        }
    })
    E:DisablePixelSnap(row)
    E:DisablePixelSnap(row.overlay)
    if not (row.healthBar.HasSecretValues and row.healthBar:HasSecretValues()) then
        E:DisablePixelSnap(row.healthBar)
    end
    row:SetBackdropColor(bgColor[1] or 0, bgColor[2] or 0, bgColor[3] or 0, bgA)

    local border = db.border or {}
    local er, eg, eb, ea = colorTuple(border.color, 0, 0, 0, 1)
    E:ApplyOuterBorder(row, {
        enabled = border.enabled and true or false,
        edgeFile = E:FetchBorder(border.texture),
        edgeSize = math.min(border.size or 1, 16),
        r = er,
        g = eg,
        b = eb,
        a = ea
    })

    local font = E:FetchModuleFont()
    E:ApplyFontString(row.label, font, db.font.size or 12, db.font.outline or "")
    E:ApplyFontString(row.right, font, db.font.size or 12, db.font.outline or "")
    local r, g, b, a = colorTuple(db.font.color, 1, 1, 1, 1)
    row.label:SetTextColor(r, g, b, a)
    row.right:SetTextColor(r, g, b, a)

    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.label:SetPoint("RIGHT", row.right, "LEFT", -6, 0)

    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.right:SetWidth(math.max(120, (db.bar.width or 360) * 0.55))

    local gr, gg, gb, ga = colorTuple(db.bar.lineColor, 0.08, 0.52, 1, 1)
    row.ghost:SetColorTexture(gr, gg, gb, ga)
end

function Mod:Apply()
    self:EnsureFrame()
    self.frame:SetFrameStrata(self.db.strata or "HIGH")
    for _, row in ipairs(self.rows or {}) do
        self:ApplyRowStyle(row)
    end
    self:ApplyPosition()
    self:LayoutRows()
end

function Mod:ApplyPosition()
    if not self.frame then
        return
    end
    E:ApplyFramePosition(self.frame, self.db.position)
end

function Mod:LayoutRows()
    if not self.frame then
        return
    end
    local width = self.db.bar.width or 360
    local height = self.db.bar.height or 24
    local visible = 0

    for _, row in ipairs(self.rows or {}) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, 0)
            visible = visible + 1
        end
    end

    self.frame:SetSize(width, height)
end

function Mod:RenderRow(row, bar, elapsed)
    local targetPercent = targetPercentForBar(bar)
    local targetRatio = targetPercent / 100

    local r, g, b, a = colorTuple(self.db.bar.color, 0.9, 0.12, 0.12, 1)
    row.healthBar:SetStatusBarColor(r, g, b, a)
    paintUnitHealth(row, bar.bossUnit)

    local w = self.db.bar.width or 360
    local h = self.db.bar.height or 24
    local markerX = math.max(1, math.min(w - 1, w * targetRatio))
    row.ghost:ClearAllPoints()
    row.ghost:SetPoint("CENTER", row, "LEFT", markerX, 0)
    row.ghost:SetHeight(h)
    row.ghost:Show()

    row.label:SetText(bossDisplayName(bar))

    setProgressText(row.right, bar.bossUnit, targetPercent, formatTime((bar.targetTime or 0) - elapsed))
end

function Mod:UpdateActive(force)
    if not self.startTime or self.editMode then
        return
    end

    local elapsed = GetTime() - self.startTime
    local visible = 0
    local maxHide = 0

    for _, active in ipairs(self.activeBars or {}) do
        local bar = active.bar
        local pushTime = bar.targetTime or 0
        maxHide = math.max(maxHide, pushTime)
        if elapsed >= (bar.showAt or 0) and elapsed <= pushTime then
            self:RenderRow(active.row, bar, elapsed)
            active.row:Show()
            visible = visible + 1
        else
            active.row:Hide()
        end
    end

    self:LayoutRows()
    if visible > 0 then
        self.frame:Show()
    else
        self.frame:Hide()
    end

    if maxHide > 0 and elapsed > maxHide then
        self:Stop()
    end
end

function Mod:MatchesBar(bar, trigger, encounterID)
    if not bar.enabled then
        return false
    end
    if bar.trigger ~= trigger then
        return false
    end
    if trigger == "encounter" then
        local wanted = tonumber(bar.encounterID) or 0
        return wanted == 0 or wanted == encounterID
    end
    return true
end

function Mod:Start(trigger, encounterID)
    if self.editMode then
        return
    end
    local matches = {}
    for _, bar in ipairs(self:GetBars()) do
        if self:MatchesBar(bar, trigger, encounterID) then
            matches[#matches + 1] = bar
        end
    end
    if #matches == 0 then
        return
    end

    table.sort(matches, function(a, b)
        local aSpecific = trigger ~= "encounter" or (tonumber(a.encounterID) or 0) ~= 0
        local bSpecific = trigger ~= "encounter" or (tonumber(b.encounterID) or 0) ~= 0
        if aSpecific ~= bSpecific then
            return aSpecific
        end
        if a.showAt == b.showAt then
            return a.name < b.name
        end
        return a.showAt < b.showAt
    end)

    matches = {matches[1]}

    self:Stop()
    self.activeTrigger = trigger
    self.startTime = GetTime()
    self.activeBars = {}

    for i, bar in ipairs(matches) do
        local row = self:EnsureRow(i)
        row:Hide()
        self.activeBars[i] = {
            bar = bar,
            row = row
        }
    end

    for i = #matches + 1, #(self.rows or {}) do
        self.rows[i]:Hide()
    end

    self.frame._tickAcc = TICK_INTERVAL
    self.frame:SetScript("OnUpdate", function(frame, elapsed)
        frame._tickAcc = frame._tickAcc + elapsed
        if frame._tickAcc < TICK_INTERVAL then
            return
        end
        frame._tickAcc = 0
        Mod:UpdateActive()
    end)
    self:UpdateActive(true)
end

function Mod:Stop()
    self.startTime = nil
    self.activeTrigger = nil
    self.activeBars = nil
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    for _, row in ipairs(self.rows or {}) do
        row:Hide()
    end
end

function Mod:RenderEditPreview()
    self:EnsureFrame()
    self:Stop()
    local bar = self:GetSelectedBar() or normalizeBar({
        name = L["BossMods_BossPushDefaultName"] or "Boss Push",
        showAt = 0,
        targetTime = 120,
        targetPercent = 70
    }, true)
    local row = self:EnsureRow(1)
    for i = 2, #(self.rows or {}) do
        self.rows[i]:Hide()
    end
    row:Show()
    self:ApplyRowStyle(row)

    local elapsed = math.min(bar.targetTime or 120, math.max(bar.showAt or 0, (bar.targetTime or 120) * 0.65))
    local targetPercent = targetPercentForBar(bar)
    local actual = math.min(100, targetPercent + 7)
    local actualRatio = actual / 100
    local r, g, b, a = colorTuple(self.db.bar.color, 0.9, 0.12, 0.12, 1)
    row.healthBar:SetStatusBarColor(r, g, b, a)
    row.healthBar:SetMinMaxValues(0, 1)
    row.healthBar:SetValue(actualRatio)

    local w = self.db.bar.width or 360
    row.ghost:ClearAllPoints()
    row.ghost:SetPoint("CENTER", row, "LEFT", math.max(1, math.min(w - 1, w * targetPercent / 100)), 0)
    row.ghost:SetHeight(self.db.bar.height or 24)
    row.ghost:Show()
    row.label:SetText(bossDisplayName(bar))
    row.right:SetText(("%.1f%% / %.1f%%  %s"):format(actual, targetPercent, formatTime((bar.targetTime or 0) - elapsed)))

    self:LayoutRows()
    self.frame:Show()
end

function Mod:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false
    if self.editMode then
        self:RenderEditPreview()
    else
        self:Stop()
    end
end

function Mod:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:Apply()
    if self.editMode then
        self:RenderEditPreview()
    elseif self.startTime then
        self:UpdateActive(true)
    end
end

function Mod:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

function Mod:OnEncounterStart(_, encounterID)
    self:Start("encounter", encounterID)
end

function Mod:OnEncounterEnd()
    if self.activeTrigger == "encounter" then
        self:Stop()
    end
end

function Mod:OnCombatStart()
    self:Start("combat")
end

function Mod:OnCombatEnd()
    if self.activeTrigger == "combat" then
        self:Stop()
    end
end

function Mod:OnInitialize()
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = L["BossMods_BossPush"],
        sanitize = normalizeBar,
        getImportName = function(data)
            return data and data.name or L["BossMods_BossPush"]
        end,
        confirmTitle = L["BossMods_BossPushImport"],
        confirmText = function(data, sender)
            local name = data and data.name or L["BossMods_BossPush"]
            if sender and sender ~= "" then
                return L["BossMods_BossPushImportFromSender"]:format(name, sender)
            end
            return L["BossMods_BossPushImportConfirm"]:format(name)
        end,
        onImport = function(data)
            local idx = self:ImportBarData(data)
            if idx then
                E:Printf(L["BossMods_BossPushImported"]:format(data.name))
            end
        end
    })

    self:EnsureFrame()
    self:Apply()
    self.frame:Hide()
end

function Mod:OnEnable()
    self:EnsureFrame()
    self:Apply()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    if UnitAffectingCombat("player") then
        self:OnCombatStart()
    end
end

function Mod:OnDisable()
    self.editMode = false
    self:Stop()
end

E:RegisterBossModFeature("BossPush", {
    tab = "General",
    order = 10,
    labelKey = "BossMods_BossPush",
    descKey = "BossMods_BossPushDesc",
    moduleName = "BossMods_BossPush"
})
