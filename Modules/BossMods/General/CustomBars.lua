local E, L = unpack(ART)

local MODULE_NAME = "BossMods_CustomBars"
local SHARE_TYPE = "customBar"
local SHARE_VERSION = "ART_CB1"
local TTS_MESSAGE_LEAD = 2

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    selectedBar = nil,
    bars = {}
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")
local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines

local function copyTable(src)
    if type(src) ~= "table" then return nil end
    if CopyTable then return CopyTable(src) end
    local out = {}
    for k, v in pairs(src) do out[k] = type(v) == "table" and copyTable(v) or v end
    return out
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    return math.max(low, math.min(high, value))
end

local function newID()
    local stamp = GetServerTime and GetServerTime() or time()
    return ("%s-%06d"):format(stamp, math.random(0, 999999))
end

local function safeText(value, fallback)
    value = strtrim(E:SafeString(value) or "")
    return value ~= "" and value or fallback
end

local function normalizeColor(value, fallback)
    value = type(value) == "table" and value or fallback
    return {
        clamp(value[1] or value.r or fallback[1], 0, 1),
        clamp(value[2] or value.g or fallback[2], 0, 1),
        clamp(value[3] or value.b or fallback[3], 0, 1),
        clamp(value[4] or value.a or fallback[4] or 1, 0, 1)
    }
end

local function normalizeMarkers(markers, duration)
    local out = {}
    for _, marker in ipairs(type(markers) == "table" and markers or {}) do
        local at = tonumber(marker.time)
        if at and at >= 0 and at <= duration then
            out[#out + 1] = {
                time = at,
                duration = clamp(marker.duration, 0, math.max(0, duration - at)),
                text = safeText(marker.text, "")
            }
        end
    end
    table.sort(out, function(a, b) return a.time < b.time end)
    while #out > 10 do table.remove(out) end
    return out
end

local function normalizeAudio(audio)
    audio = type(audio) == "table" and audio or {}
    local validChannels = {Master=true, SFX=true, Dialog=true, Music=true, Ambience=true}
    return {
        enabled = audio.enabled == true,
        secondsBefore = clamp(tonumber(audio.secondsBefore) or 3, 0, 300),
        delayBy = clamp(audio.delayBy, 0, 30),
        mode = audio.mode == "sound" and "sound" or "tts",
        sound = safeText(audio.sound, "None"),
        channel = validChannels[audio.channel] and audio.channel or "Master",
        ttsText = safeText(audio.ttsText, "{spell} in {time}"),
        voiceID = math.max(0, math.floor(tonumber(audio.voiceID) or 0)),
        countdown = audio.countdown == true
    }
end

local function normalizeDifficulties(value)
    value = type(value) == "table" and value or {}

    return {
        normal = value.normal ~= false,
        heroic = value.heroic ~= false,
        mythic = value.mythic ~= false
    }
end

local DIFFICULTY_KEYS = {
    [14] = "normal",
    [15] = "heroic",
    [16] = "mythic"
}

local function isDifficultyEnabled(bar)
    local _, _, difficultyID = GetInstanceInfo()
    local key = DIFFICULTY_KEYS[tonumber(difficultyID)]

    return key ~= nil
        and type(bar) == "table"
        and type(bar.difficulties) == "table"
        and bar.difficulties[key] == true
end

local function defaultAppearance()
    local defaults = E:GetModule("BossMods_AbilityAlertDefaults", true)
    local appearance = defaults and defaults:GetAppearance().bar or {}
    return {
        width = tonumber(appearance.width) or 300,
        height = tonumber(appearance.height) or 24,
        texture = appearance.texture or "Clean",
        fillColor = normalizeColor(appearance.fillColor, {0.2, 0.6, 1, 1}),
        backgroundColor = normalizeColor(appearance.backgroundColor, {0, 0, 0, 1}),
        font = {
            name = appearance.font and appearance.font.name or "Friz Quadrata TT",
            size = tonumber(appearance.font and appearance.font.size) or 14,
            outline = appearance.font and appearance.font.outline or "OUTLINE"
        }
    }
end

local function normalizeBar(data, freshID)
    data = type(data) == "table" and copyTable(data) or {}
    local duration = clamp(data.duration, 0.1, 300)
    local appearance = type(data.appearance) == "table" and data.appearance or defaultAppearance()
    local defaults = defaultAppearance()
    appearance.font = type(appearance.font) == "table" and appearance.font or {}

    return {
        id = freshID and newID() or safeText(data.id, newID()),
        name = safeText(data.name, "Custom Bar"),
        enabled = data.enabled ~= false,
        difficulties = normalizeDifficulties(data.difficulties),
        triggerSpellID = math.max(0, math.floor(tonumber(data.triggerSpellID) or 0)),
        triggerName = safeText(data.triggerName, "BigWigs ability"),
        startOffset = clamp(data.startOffset, -20, 20),
        duration = duration,
        text = safeText(data.text, data.name or "Custom Bar"),
        markers = normalizeMarkers(data.markers, duration),
        markerColor = normalizeColor(data.markerColor, {1, 1, 1, 1}),
        markerThickness = clamp(data.markerThickness, 1, 30),
        markerTextSize = clamp(data.markerTextSize, 8, 48),
        markerTextY = clamp(data.markerTextY, -100, 100),
        audio = normalizeAudio(data.audio),
        overrideAppearance = data.overrideAppearance == true,
        appearance = {
            width = clamp(appearance.width, 80, 1200),
            height = clamp(appearance.height, 8, 120),
            texture = safeText(appearance.texture, defaults.texture),
            fillColor = normalizeColor(appearance.fillColor, defaults.fillColor),
            backgroundColor = normalizeColor(appearance.backgroundColor, defaults.backgroundColor),
            font = {
                name = safeText(appearance.font.name, defaults.font.name),
                size = clamp(appearance.font.size, 8, 48),
                outline = appearance.font.outline or defaults.font.outline
            }
        }
    }
end

local function exportBar(bar)
    local out = normalizeBar(bar)
    out.id = nil
    return out
end

local function uniqueName(name, bars)
    local used = {}
    for _, bar in ipairs(bars) do used[bar.name] = true end
    if not used[name] then return name end
    local base, n = name .. " Copy", 2
    if not used[base] then return base end
    while used[("%s %d"):format(base, n)] do n = n + 1 end
    return ("%s %d"):format(base, n)
end

function Mod:GetBars()
    self.db.bars = self.db.bars or {}
    for i, bar in ipairs(self.db.bars) do self.db.bars[i] = normalizeBar(bar) end
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
        bar.name = "Custom Bar " .. (#bars + 1)
        bar.text = bar.name
    end
    bar.name = uniqueName(bar.name, bars)
    bars[#bars + 1] = bar
    self.db.selectedBar = #bars
    self:Changed(true)
    return #bars
end

function Mod:DeleteBar(index)
    local bars = self:GetBars()
    index = math.floor(tonumber(index or self.db.selectedBar) or 0)
    if not bars[index] then return false end
    self:StopBar(bars[index].id)
    table.remove(bars, index)
    self.db.selectedBar = #bars > 0 and math.min(index, #bars) or nil
    self:Changed(true)
    return true
end

function Mod:DuplicateBar(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    return bar and self:AddBar(exportBar(bar)) or nil
end

function Mod:ImportBarData(data)
    local bar = normalizeBar(data, true)
    local bars = self:GetBars()
    bar.name = uniqueName(bar.name, bars)
    bars[#bars + 1] = bar
    self.db.selectedBar = #bars
    self:Changed(true)
    return #bars
end

function Mod:ExportBarString(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    return bar and E:EncodeShareString(SHARE_TYPE, exportBar(bar)) or ""
end

function Mod:ImportBarString(text)
    local data, err = E:DecodeShareString(SHARE_TYPE, text)
    if not data then return nil, err or "Invalid Custom Bar string" end
    return self:ImportBarData(data)
end

function Mod:ShareBarToChat(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    if not bar then return false, "No Custom Bar selected" end
    return E:ShareDataToChat(SHARE_TYPE, exportBar(bar), ("ART Custom Bar: %s"):format(bar.name))
end

local function barAppearance(bar)
    if bar.overrideAppearance then return bar.appearance end
    return defaultAppearance()
end

function Mod:BuildConfig(bar)
    local a = barAppearance(bar)
    return {
        parent = UIParent,
        showFill = true,
        strata = "HIGH",
        textUpdateInterval = 0.1,
        size = {w = a.width, h = a.height},
        icon = {enabled = false},
        statusBar = {texture = a.texture, color = a.fillColor},
        label = {font = a.font.name, size = a.font.size, outline = a.font.outline, color = {1,1,1,1}, justify = "LEFT"},
        right = {font = a.font.name, size = a.font.size, outline = a.font.outline, color = {1,1,1,1}, justify = "RIGHT"},
        background = {color = a.backgroundColor, opacity = a.backgroundColor[4] or 1},
        border = {enabled = true, texture = "Pixel", size = 1, color = {0,0,0,1}}
    }
end

function Mod:EnsureHandle(bar)
    self.handles = self.handles or {}
    local handle = self.handles[bar.id]
    if not handle then
        handle = Engines.Bar(self:BuildConfig(bar))
        handle:SetMode("label")
        handle.customMarkers = {}
        self.handles[bar.id] = handle
    else
        handle:Apply(self:BuildConfig(bar))
    end
    return handle
end

local function clearMarkerWidgets(handle)
    for _, widget in ipairs(handle.customMarkers or {}) do
        widget.line:Hide()
        widget.label:Hide()
    end
end

function Mod:ApplyMarkers(handle, bar)
    clearMarkerWidgets(handle)
    handle.customMarkers = handle.customMarkers or {}
    local width = handle.frame:GetWidth()
    local a = barAppearance(bar)
    for i, marker in ipairs(bar.markers) do
        local widget = handle.customMarkers[i]
        if not widget then
            widget = {line = handle.frame:CreateTexture(nil, "OVERLAY", nil, 5), label = handle.frame:CreateFontString(nil, "OVERLAY")}
            handle.customMarkers[i] = widget
        end
        local markerDuration = clamp(marker.duration, 0, math.max(0, bar.duration - marker.time))
        local startRatio = (bar.duration - marker.time) / bar.duration
        local endRatio = (bar.duration - marker.time - markerDuration) / bar.duration
        local centerRatio = markerDuration > 0 and (startRatio + endRatio) / 2 or startRatio
        local markerWidth = markerDuration > 0
            and math.max(1, width * markerDuration / bar.duration)
            or bar.markerThickness
        local r, g, b, alpha = unpack(bar.markerColor)
        widget.line:SetColorTexture(r, g, b, alpha)
        widget.line:SetSize(markerWidth, a.height)
        widget.line:ClearAllPoints()
        widget.line:SetPoint("CENTER", handle.frame, "LEFT", width * centerRatio, 0)
        widget.line:Show()
        E:ApplyFontString(widget.label, E:FetchModuleFont(a.font.name), bar.markerTextSize, a.font.outline)
        widget.label:SetText(marker.text or "")
        widget.label:ClearAllPoints()
        if markerDuration > 0 then
            widget.label:SetPoint("CENTER", widget.line, "CENTER", 0, bar.markerTextY)
        else
            widget.label:SetPoint("BOTTOM", widget.line, "TOP", 0, bar.markerTextY)
        end
        widget.label:SetTextColor(r, g, b, 1)
        widget.label:SetShown(marker.text ~= "")
    end
end

function Mod:ApplyPositions()
    local defaults = E:GetModule("BossMods_AbilityAlertDefaults", true)
    local group = defaults and defaults:GetGroupSettings("bar") or {point="CENTER", x=-400, y=80, growth="DOWN", spacing=4}
    local visible = {}
    for _, bar in ipairs(self:GetBars()) do
        local h = self.handles and self.handles[bar.id]
        if h and h.frame:IsShown() then visible[#visible + 1] = {bar=bar, handle=h} end
    end
    for i, item in ipairs(visible) do
        local height = barAppearance(item.bar).height
        local direction = group.growth == "UP" and 1 or -1
        item.handle.frame:ClearAllPoints()
        item.handle.frame:SetPoint(group.point or "CENTER", UIParent, "CENTER", group.x or -400, (group.y or 80) + (i - 1) * (height + (group.spacing or 4)) * direction)
    end
end

local function replaceAudioVariables(text, bar, remaining)
    text = tostring(text or "")
    text = text:gsub("{spell}", bar.triggerName ~= "" and bar.triggerName or bar.name)
    text = text:gsub("{bar}", bar.name)
    text = text:gsub("{time}", tostring(remaining or 0))
    return text
end

function Mod:CancelAudioTimers(id)
    local timers = self.audioTimers and self.audioTimers[id]
    for _, timer in ipairs(timers or {}) do
        if timer and timer.Cancel then timer:Cancel() end
    end
    if self.audioTimers then self.audioTimers[id] = nil end
    self.audioGeneration = self.audioGeneration or {}
    self.audioGeneration[id] = (self.audioGeneration[id] or 0) + 1
end

function Mod:ScheduleAudioTimer(id, delay, generation, callback)
    if delay <= 0 then
        if self.audioGeneration[id] == generation then callback() end
        return
    end
    self.audioTimers = self.audioTimers or {}
    self.audioTimers[id] = self.audioTimers[id] or {}
    local timer = C_Timer.NewTimer(delay, function()
        if Mod:IsEnabled() and Mod.audioGeneration[id] == generation then callback() end
    end)
    self.audioTimers[id][#self.audioTimers[id] + 1] = timer
end

function Mod:PlayBarAudio(bar, remaining, numberOnly)
    local audio = bar.audio
    if not audio or not audio.enabled then return end
    if audio.mode == "sound" then
        BossMods.Alerts:PlaySound({name=audio.sound, channel=audio.channel or "Master"})
        return
    end

    local text
    if numberOnly then
        text = tostring(remaining)
    else
        text = audio.ttsText
        if audio.countdown or text:find("{time}", 1, true) then
            text = text:gsub("{time}", ""):gsub("%s+", " ")
            text = strtrim(text)
        end
        text = replaceAudioVariables(text, bar, remaining)
    end

    BossMods.Alerts:StopTTS()
    BossMods.Alerts:SpeakTTS({text=text, voiceID=audio.voiceID or 0})
end

function Mod:ScheduleBarAudio(bar)
    self:CancelAudioTimers(bar.id)
    local audio = bar.audio
    if not audio or not audio.enabled then return end

    local secondsBefore = math.min(bar.duration, math.max(0, tonumber(audio.secondsBefore) or 0))
    local countdownSeconds = math.floor(secondsBefore)
    local targetDelay = math.max(0, bar.duration - secondsBefore + (tonumber(audio.delayBy) or 0))
    local hasTime = audio.mode == "tts" and audio.ttsText:find("{time}", 1, true) ~= nil
    local needsNumbers = audio.mode == "tts" and (audio.countdown or hasTime)
    local lead = needsNumbers and math.min(TTS_MESSAGE_LEAD, targetDelay) or 0
    local generation = self.audioGeneration[bar.id]

    self:ScheduleAudioTimer(bar.id, targetDelay - lead, generation, function()
        self:PlayBarAudio(bar, countdownSeconds, false)
    end)

    if needsNumbers then
        if audio.countdown then
            for remaining = countdownSeconds, 1, -1 do
                local number = remaining
                self:ScheduleAudioTimer(bar.id, targetDelay + countdownSeconds - number, generation, function()
                    self:PlayBarAudio(bar, number, true)
                end)
            end
        elseif hasTime then
            self:ScheduleAudioTimer(bar.id, targetDelay, generation, function()
                self:PlayBarAudio(bar, countdownSeconds, true)
            end)
        end
    end
end

function Mod:StopBar(id)
    local timer = self.timers and self.timers[id]
    if timer and timer.Cancel then timer:Cancel() end
    if self.timers then self.timers[id] = nil end
    self:CancelAudioTimers(id)
    local handle = self.handles and self.handles[id]
    if handle then handle:Stop(); handle:Hide(); clearMarkerWidgets(handle) end
    self:ApplyPositions()
end

function Mod:StartBar(bar)
    if not bar then return end
    self:StopBar(bar.id)
    local handle = self:EnsureHandle(bar)
    handle:SetLabel(bar.text)
    handle:SetRight(("%.1f"):format(bar.duration))
    handle.onTick = function(elapsed, total)
        handle:SetRight(("%.1f"):format(math.max(0, total - elapsed)))
    end
    handle.onStop = function()
        handle:Hide()
        clearMarkerWidgets(handle)
        Mod:ApplyPositions()
    end
    handle:Start({total = bar.duration})
    self:ApplyMarkers(handle, bar)
    self:ApplyPositions()
    self:ScheduleBarAudio(bar)
end

function Mod:Preview(index)
    local bar = self:GetBar(index or self.db.selectedBar)
    if bar then self:StartBar(bar) end
end

function Mod:OnBigWigsStartBar(spellKey, _, duration)
    duration = tonumber(duration) or 0
    for _, bar in ipairs(self:GetBars()) do
        if bar.enabled
            and isDifficultyEnabled(bar)
            and bar.triggerSpellID > 0
            and bar.triggerSpellID == tonumber(spellKey)
        then
            local delay = duration + bar.startOffset
            if delay <= 0 then
                self:StartBar(bar)
            else
                self.timers = self.timers or {}
                local old = self.timers[bar.id]
                if old and old.Cancel then old:Cancel() end
                self.timers[bar.id] = C_Timer.NewTimer(delay, function()
                    self.timers[bar.id] = nil
                    if self:IsEnabled()
                        and bar.enabled
                        and isDifficultyEnabled(bar)
                    then
                        self:StartBar(bar)
                    end
                end)
            end
        end
    end
end

function Mod:RebuildSubscription()
    if self.bigWigsSubscription then self.bigWigsSubscription:Unsubscribe(); self.bigWigsSubscription = nil end
    local keys, seen = {}, {}
    for _, bar in ipairs(self:GetBars()) do
        if bar.enabled and bar.triggerSpellID > 0 and not seen[bar.triggerSpellID] then
            seen[bar.triggerSpellID] = true
            keys[#keys + 1] = bar.triggerSpellID
        end
    end
    if self:IsEnabled() and #keys > 0 then
        self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
            owner = MODULE_NAME,
            spellKeys = keys,
            onStartBar = function(...) self:OnBigWigsStartBar(...) end
        })
    end
end

function Mod:Refresh()
    for _, bar in ipairs(self:GetBars()) do
        local handle = self.handles and self.handles[bar.id]
        if handle then
            handle:Apply(self:BuildConfig(bar))
            if handle.frame:IsShown() then self:ApplyMarkers(handle, bar) end
        end
    end
    self:ApplyPositions()
end

function Mod:Changed(rebuild)
    if rebuild then self:RebuildSubscription() end
    self:Refresh()
    E:SendMessage("ART_CUSTOM_BARS_CHANGED", self.db.selectedBar)
end

function Mod:OnInitialize()
    E:RegisterShareType(SHARE_TYPE, {
        version = SHARE_VERSION,
        label = "Custom Bar",
        sanitize = normalizeBar,
        getImportName = function(data) return data and data.name or "Custom Bar" end,
        confirmTitle = "Import Custom Bar",
        confirmText = function(data, sender)
            return ("Import '%s'%s?"):format(data and data.name or "Custom Bar", sender and sender ~= "" and (" from " .. sender) or "")
        end,
        onImport = function(data)
            self:ImportBarData(data)
            E:Printf("Imported Custom Bar: %s", data.name or "Custom Bar")
        end
    })
end

function Mod:OnEnable()
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self:RebuildSubscription()
end

function Mod:OnDisable()
    if self.bigWigsSubscription then self.bigWigsSubscription:Unsubscribe(); self.bigWigsSubscription = nil end
    local ids = {}
    for id in pairs(self.timers or {}) do ids[#ids + 1] = id end
    for id in pairs(self.handles or {}) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do self:StopBar(id) end
end

E:RegisterBossModFeature("CustomBars", {
    tab = "General",
    order = 20,
    labelKey = "BossMods_CustomBars",
    descKey = "BossMods_CustomBarsDesc",
    moduleName = MODULE_NAME
})
