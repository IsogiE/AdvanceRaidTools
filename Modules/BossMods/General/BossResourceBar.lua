local E = unpack(ART)

local MODULE_NAME = "BossMods_BossResourceBar"
local SHARE_TYPE = "bossResourceBar"
local SHARE_VERSION = "ART_BRB1"
local issecretvalue = issecretvalue or function() return false end

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    selectedBar = nil,
    bars = {}
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local ENCOUNTER_VALUES = {
    [0] = "Any Encounter",
    [3379] = "Nymrissa Wavecaller",
    [3176] = "The Voidspire - Imperator Averzian",
    [3177] = "The Voidspire - Vorasius",
    [3179] = "The Voidspire - Fallen-King Salhadaar",
    [3178] = "The Voidspire - Vaelgor & Ezzorak",
    [3180] = "The Voidspire - Lightblinded Vanguard",
    [3181] = "The Voidspire - Crown of the Cosmos",
    [3306] = "The Dreamrift - Chimaerus the Undreamt God",
    [3182] = "March on Quel'Danas - Belo'ren, Child of Al'ar",
    [3183] = "March on Quel'Danas - Midnight Falls",
    [3470] = "The Venomous Abyss - Nek'zali the Soulcoiler",
    [3445] = "The Venomous Abyss - Entombed Sentinels",
    [3497] = "The Venomous Abyss - The Lost Explorers",
    [3455] = "The Venomous Abyss - Vashnik the Malignant",
    [3420] = "The Venomous Abyss - Sszorak",
    [3421] = "The Venomous Abyss - The Twin Fangs",
    [3429] = "The Venomous Abyss - The Coiled Alter",
    [3492] = "The Venomous Abyss - Ula'tek"
}

local ENCOUNTER_SORTING = {
    0, 3379, 3176, 3177, 3179, 3178, 3180, 3181, 3306, 3182, 3183,
    3470, 3445, 3497, 3455, 3420, 3421, 3429, 3492
}

local UNIT_VALUES = {}
local UNIT_SORTING = {}
for index = 1, 8 do
    local unit = "boss" .. index
    UNIT_VALUES[unit] = "Boss Frame " .. index
    UNIT_SORTING[index] = unit
end

local DIFFICULTY_VALUES = {
    any = "Any Difficulty",
    normal = "Normal",
    heroic = "Heroic",
    mythic = "Mythic"
}

local DIFFICULTY_SORTING = {"any", "normal", "heroic", "mythic"}

local POWER_VALUES = {
    auto = "Automatic",
    [0] = "Mana",
    [1] = "Rage",
    [2] = "Focus",
    [3] = "Energy",
    [6] = "Runic Power",
    [10] = "Alternate Power"
}

local POWER_SORTING = {"auto", 0, 1, 2, 3, 6, 10}

local DISPLAY_VALUES = {
    always = "Always",
    above = "Above threshold",
    below = "Below threshold"
}

local DISPLAY_SORTING = {"always", "above", "below"}

local function copyTable(source)
    if type(source) ~= "table" then
        return nil
    end
    if CopyTable then
        return CopyTable(source)
    end
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and copyTable(value) or value
    end
    return result
end

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then
        value = fallback or minimum
    end
    return math.max(minimum, math.min(maximum, value))
end

local function safeText(value, fallback)
    value = strtrim(E:SafeString(value) or "")
    return value ~= "" and value or fallback
end

local function color(value, fallback)
    value = type(value) == "table" and value or fallback
    return {
        clamp(value[1] or value.r, 0, 1, fallback[1]),
        clamp(value[2] or value.g, 0, 1, fallback[2]),
        clamp(value[3] or value.b, 0, 1, fallback[3]),
        clamp(value[4] or value.a, 0, 1, fallback[4] or 1)
    }
end

local function newID()
    local stamp = GetServerTime and GetServerTime() or time()
    return ("%s-%06d"):format(tostring(stamp), math.random(0, 999999))
end

local function normalizeBar(source, freshID)
    source = type(source) == "table" and copyTable(source) or {}
    local appearance = type(source.appearance) == "table" and source.appearance or {}
    local font = type(appearance.font) == "table" and appearance.font or {}
    local border = type(appearance.border) == "table" and appearance.border or {}
    local position = type(source.position) == "table" and source.position or {}
    local difficulty = DIFFICULTY_VALUES[source.difficulty] and source.difficulty or "any"
    local displayWhen = DISPLAY_VALUES[source.displayWhen] and source.displayWhen or "always"
    local powerType = source.powerType == "auto" and "auto" or tonumber(source.powerType)
    if powerType ~= "auto" and not POWER_VALUES[powerType] then
        powerType = "auto"
    end

    return {
        id = freshID and newID() or safeText(source.id, newID()),
        name = safeText(source.name, "Boss Resource Bar"),
        enabled = source.enabled ~= false,
        encounterID = math.max(0, math.floor(tonumber(source.encounterID) or 0)),
        difficulty = difficulty,
        bossUnit = UNIT_VALUES[source.bossUnit] and source.bossUnit or "boss1",
        powerType = powerType,
        displayWhen = displayWhen,
        displayThreshold = clamp(source.displayThreshold, 0, 100, 85),
        label = safeText(source.label, source.name or "Boss Resource"),
        showPercent = source.showPercent ~= false,
        position = {
            point = position.point or "CENTER",
            x = tonumber(position.x) or 0,
            y = tonumber(position.y) or 250
        },
        appearance = {
            width = clamp(appearance.width, 80, 1200, 360),
            height = clamp(appearance.height, 8, 120, 26),
            strata = safeText(appearance.strata, "HIGH"),
            texture = safeText(appearance.texture, "Clean"),
            fillColor = color(appearance.fillColor, {0.55, 0.15, 0.90, 1}),
            backgroundColor = color(appearance.backgroundColor, {0, 0, 0, 0.45}),
            font = {
                name = safeText(font.name, "Friz Quadrata TT"),
                size = clamp(font.size, 8, 48, 14),
                outline = font.outline or "OUTLINE",
                color = color(font.color, {1, 1, 1, 1})
            },
            border = {
                enabled = border.enabled ~= false,
                texture = safeText(border.texture, "Pixel"),
                size = clamp(border.size, 1, 16, 1),
                color = color(border.color, {0, 0, 0, 1})
            }
        }
    }
end

local function exportBar(bar)
    local result = normalizeBar(bar)
    result.id = nil
    return result
end

local function uniqueName(name, bars)
    local used = {}
    for _, bar in ipairs(bars) do
        used[bar.name] = true
    end
    if not used[name] then
        return name
    end
    local index = 2
    local candidate = name .. " Copy"
    while used[candidate] do
        candidate = name .. " Copy " .. index
        index = index + 1
    end
    return candidate
end

local function difficultyKey(difficultyID)
    difficultyID = tonumber(difficultyID)
    if difficultyID == 14 then
        return "normal"
    elseif difficultyID == 15 then
        return "heroic"
    elseif difficultyID == 16 or difficultyID == 233 then
        return "mythic"
    end
end

function Mod:GetEncounterValues() return ENCOUNTER_VALUES end
function Mod:GetEncounterSorting() return ENCOUNTER_SORTING end
function Mod:GetUnitValues() return UNIT_VALUES end
function Mod:GetUnitSorting() return UNIT_SORTING end
function Mod:GetDifficultyValues() return DIFFICULTY_VALUES end
function Mod:GetDifficultySorting() return DIFFICULTY_SORTING end
function Mod:GetPowerValues() return POWER_VALUES end
function Mod:GetPowerSorting() return POWER_SORTING end
function Mod:GetDisplayValues() return DISPLAY_VALUES end
function Mod:GetDisplaySorting() return DISPLAY_SORTING end

function Mod:GetBars()
    self.db.bars = type(self.db.bars) == "table" and self.db.bars or {}
    if self.db.barDataVersion ~= 2 then
        for index, bar in ipairs(self.db.bars) do
            self.db.bars[index] = normalizeBar(bar)
        end
        self.db.barDataVersion = 2
    end
    return self.db.bars
end

function Mod:GetBar(index)
    return self:GetBars()[math.floor(tonumber(index) or 0)]
end

function Mod:GetSelectedBar()
    return self:GetBar(self.db.selectedBar)
end

function Mod:AddBar(template)
    local bars = self:GetBars()
    local bar = normalizeBar(template or {}, true)
    if not template then
        bar.name = "Boss Resource Bar " .. (#bars + 1)
        bar.label = bar.name
    end
    bar.name = uniqueName(bar.name, bars)
    bars[#bars + 1] = bar
    self.db.selectedBar = #bars
    self:Refresh()
    return #bars
end

function Mod:DuplicateBar(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    return bar and self:AddBar(exportBar(bar)) or nil
end

function Mod:DeleteBar(index)
    local bars = self:GetBars()
    index = math.floor(tonumber(index or self.db.selectedBar) or 0)
    local bar = bars[index]
    if not bar then
        return false
    end
    local frame = self.frames and self.frames[bar.id]
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        self.frames[bar.id] = nil
    end
    table.remove(bars, index)
    self.db.selectedBar = #bars > 0 and math.min(index, #bars) or nil
    self:Refresh()
    return true
end

function Mod:ImportBarData(data)
    local bars = self:GetBars()
    local bar = normalizeBar(data, true)
    bar.name = uniqueName(bar.name, bars)
    bars[#bars + 1] = bar
    self.db.selectedBar = #bars
    self:Refresh()
    return #bars
end

function Mod:ExportBarString(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    return bar and E:EncodeShareString(SHARE_TYPE, exportBar(bar)) or ""
end

function Mod:ImportBarString(text)
    local data, err = E:DecodeShareString(SHARE_TYPE, text)
    if not data then
        return nil, err or "Invalid Boss Resource Bar string"
    end
    return self:ImportBarData(data)
end

function Mod:ShareBarToChat(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    if not bar then
        return false, "No Boss Resource Bar selected"
    end
    return E:ShareDataToChat(
        SHARE_TYPE,
        exportBar(bar),
        ("ART Boss Resource Bar: %s"):format(bar.name)
    )
end

function Mod:Matches(bar)
    if not bar.enabled or not self.currentEncounterID then
        return false
    end
    if bar.encounterID ~= 0 and bar.encounterID ~= self.currentEncounterID then
        return false
    end
    return bar.difficulty == "any" or bar.difficulty == self.currentDifficulty
end

function Mod:BuildFrame(bar)
    self.frames = self.frames or {}
    local frame = self.frames[bar.id]
    if frame then
        return frame
    end

    frame = CreateFrame("StatusBar", nil, UIParent, "BackdropTemplate")
    frame:SetMinMaxValues(0, 100)
    frame:SetValue(0)

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints(frame)

    frame.label = frame:CreateFontString(nil, "OVERLAY")
    frame.label:SetPoint("LEFT", 6, 0)
    frame.label:SetJustifyH("LEFT")

    frame.valueText = frame:CreateFontString(nil, "OVERLAY")
    frame.valueText:SetPoint("RIGHT", -6, 0)
    frame.valueText:SetJustifyH("RIGHT")

    frame:Hide()
    self.frames[bar.id] = frame
    return frame
end

function Mod:ApplyFrame(bar)
    local frame = self:BuildFrame(bar)
    local appearance = bar.appearance
    local fontPath = E:FetchFont(appearance.font.name)
    local texture = E:FetchStatusBar(appearance.texture)
    local fill = appearance.fillColor
    local background = appearance.backgroundColor
    local fontColor = appearance.font.color

    frame:SetSize(appearance.width, appearance.height)
    frame:SetFrameStrata(appearance.strata or "HIGH")
    frame:SetStatusBarTexture(texture)
    frame:SetStatusBarColor(fill[1], fill[2], fill[3], fill[4])
    frame.background:SetColorTexture(background[1], background[2], background[3], background[4])
    frame.label:SetFont(fontPath, appearance.font.size, appearance.font.outline)
    frame.valueText:SetFont(fontPath, appearance.font.size, appearance.font.outline)
    frame.label:SetTextColor(fontColor[1], fontColor[2], fontColor[3], fontColor[4])
    frame.valueText:SetTextColor(fontColor[1], fontColor[2], fontColor[3], fontColor[4])
    frame.label:SetText(bar.label)

    if appearance.border.enabled then
        local borderTexture = E:FetchBorder(appearance.border.texture)
        local edgeSize = appearance.border.size
        frame:SetBackdrop({edgeFile = borderTexture, edgeSize = edgeSize})
        local borderColor = appearance.border.color
        frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    else
        frame:SetBackdrop(nil)
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        bar.position.point or "CENTER",
        UIParent,
        "CENTER",
        bar.position.x or 0,
        bar.position.y or 250
    )
    return frame
end

function Mod:GetPowerPercent(bar)
    local powerType = bar.powerType == "auto" and nil or tonumber(bar.powerType)

    if UnitPowerPercent then
        local curve = CurveConstants and CurveConstants.ScaleTo100 or nil
        local ok, value = pcall(UnitPowerPercent, bar.bossUnit, powerType, false, curve)
        if ok then
            if issecretvalue(value) then
                return value
            elseif value ~= nil then
                return value
            end
        end
    end

    local okPower, power = pcall(UnitPower, bar.bossUnit, powerType)
    local okMax, maximum = pcall(UnitPowerMax, bar.bossUnit, powerType)
    if not okPower or not okMax or issecretvalue(power) or issecretvalue(maximum) then
        return nil
    end
    power = tonumber(power)
    maximum = tonumber(maximum)
    if not power or not maximum or maximum <= 0 then
        return nil
    end
    return power / maximum * 100
end

function Mod:SetBarValue(bar, frame, preview)
    if preview then
        frame:SetValue(65)
        frame.valueText:SetText(bar.showPercent and "65%" or "")
        frame:Show()
        return
    end

    if not self:Matches(bar) then
        frame:Hide()
        return
    end

    local value = self:GetPowerPercent(bar)
    if value == nil then
        frame:Hide()
        return
    end

    if issecretvalue(value) then
        local ok = pcall(frame.SetValue, frame, value)
        if not ok then
            frame:Hide()
            return
        end
        frame.valueText:SetText("")
    else
        value = clamp(value, 0, 100, 0)
        if (bar.displayWhen == "above" and value <= bar.displayThreshold)
            or (bar.displayWhen == "below" and value >= bar.displayThreshold)
        then
            frame:Hide()
            return
        end
        frame:SetValue(value)
        frame.valueText:SetText(bar.showPercent and (("%.0f%%"):format(value)) or "")
    end
    frame:Show()
end

function Mod:UpdateBar(bar, preview)
    local frame = self:ApplyFrame(bar)
    self:SetBarValue(bar, frame, preview)
end

function Mod:Refresh()
    local selected = self:GetSelectedBar()
    for _, bar in ipairs(self:GetBars()) do
        self:UpdateBar(bar, self.editMode and selected == bar)
    end
end

function Mod:SetEditMode(value)
    self.editMode = value and true or false
    self:Refresh()
end

function Mod:SaveSelectedPosition(position)
    local bar = self:GetSelectedBar()
    if not bar then
        return
    end
    bar.position.point = position.point or "CENTER"
    bar.position.x = tonumber(position.x) or 0
    bar.position.y = tonumber(position.y) or 250
    self:Refresh()
end

function Mod:OnEncounterStart(_, encounterID, _, difficultyID)
    self.currentEncounterID = tonumber(encounterID)
    self.currentDifficulty = difficultyKey(difficultyID)
    self:Refresh()
end

function Mod:OnEncounterEnd()
    self.currentEncounterID = nil
    self.currentDifficulty = nil
    self:Refresh()
end

function Mod:OnPowerEvent(_, unit)
    if type(unit) == "string" and unit:match("^boss[1-8]$") then
        local selected = self:GetSelectedBar()
        for _, bar in ipairs(self:GetBars()) do
            if bar.bossUnit == unit then
                local frame = self.frames and self.frames[bar.id]
                if not frame then
                    frame = self:ApplyFrame(bar)
                end
                self:SetBarValue(bar, frame, self.editMode and selected == bar)
            end
        end
    end
end

function Mod:OnInitialize()
    self.frames = {}
    self.editMode = false
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = "Boss Resource Bar",
        sanitize = normalizeBar,
        getImportName = function(data)
            return data and data.name or "Boss Resource Bar"
        end,
        confirmTitle = "Import Boss Resource Bar",
        confirmText = function(data, sender)
            local name = data and data.name or "Boss Resource Bar"
            return ("Import '%s'%s?"):format(
                name,
                sender and sender ~= "" and (" from " .. sender) or ""
            )
        end,
        onImport = function(data)
            self:ImportBarData(data)
            E:Printf("Imported Boss Resource Bar: %s", data.name or "Boss Resource Bar")
        end
    })
end

function Mod:OnEnable()
    self:RegisterEvent("ENCOUNTER_START", "OnEncounterStart")
    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterEvent("UNIT_POWER_UPDATE", "OnPowerEvent")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "OnPowerEvent")
    self:RegisterEvent("UNIT_MAXPOWER", "OnPowerEvent")
    self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "Refresh")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:Refresh()
end

function Mod:OnDisable()
    self.editMode = false
    self.currentEncounterID = nil
    self.currentDifficulty = nil
    for _, frame in pairs(self.frames or {}) do
        frame:Hide()
    end
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
end

E:RegisterBossModFeature("BossResourceBar", {
    tab = "General",
    order = 50,
    labelKey = "BossMods_BossResourceBar",
    descKey = "BossMods_BossResourceBarDesc",
    moduleName = MODULE_NAME
})
