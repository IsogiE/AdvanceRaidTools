local E, L = unpack(ART)
local BossMods = E:GetModule("BossMods")
local NoteBlock = BossMods.NoteBlock
local Shared = BossMods.Engines.Shared
local MODULE_NAME = "BossMods_PullReminder"
local DISPLAY_DURATION = 5
local COUNTDOWN_LEAD = 3

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    position = {point = "CENTER", x = 0, y = 120, coordSpace = "UIParent"},
    font = {
        name = "Friz Quadrata TT", size = 48, outline = "OUTLINE",
        color = {1, 0.82, 0, 1}
    },
    audio = {enabled = false, voiceID = 0}
})

local Mod = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local function publicNumber(value)
    if E:IsSecret(value) then return end
    local number = tonumber(value)
    if number and number == number and math.abs(number) < math.huge then return number end
end

local function trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function baseSpellID(spellID)
    spellID = publicNumber(spellID)
    if not spellID or spellID <= 0 then return end
    if C_Spell and C_Spell.GetBaseSpell then
        return publicNumber(C_Spell.GetBaseSpell(spellID)) or spellID
    end
    return spellID
end

local function resolveSpellID(text)
    if not C_Spell or not C_Spell.GetSpellInfo then return end
    local info = C_Spell.GetSpellInfo(publicNumber(text) or text)
    return info and baseSpellID(info.spellID)
end

function Mod:ParseReminders(noteText)
    local reminders = {}
    noteText = E:SafeString(noteText)
    if not noteText then return reminders end
    local targets = E.NoteTargets:GetPlayerContext()
    for rawLine in noteText:gmatch("[^\r\n]+") do
        local line = E:StripColorCodes(rawLine)
        local seconds, audience, message = line:match(
            "^%s*[Pp][Uu][Ll][Ll]%s*:%s*([%d%.]+)%s*:%s*([^:]-)%s*:%s*(.-)%s*$"
        )
        seconds = publicNumber(seconds)
        audience, message = trim(audience), trim(message)
        if seconds and seconds >= 0 and audience ~= "" and message ~= ""
            and E.NoteTargets:MatchesPlayer(audience, targets)
        then
            reminders[#reminders + 1] = {
                secondsRemaining = seconds,
                text = message,
                spellID = resolveSpellID(message)
            }
        end
    end
    return reminders
end

function Mod:EnsureSettings()
    self.db.font = type(self.db.font) == "table" and self.db.font or {}
    local font = self.db.font
    font.name = type(font.name) == "string" and font.name or "Friz Quadrata TT"
    font.size = math.max(8, math.min(100, publicNumber(font.size) or 48))
    font.outline = type(font.outline) == "string" and font.outline or "OUTLINE"
    font.color = type(font.color) == "table" and font.color or {1, 0.82, 0, 1}
    self.db.audio = type(self.db.audio) == "table" and self.db.audio or {}
    self.db.audio.voiceID = publicNumber(self.db.audio.voiceID) or 0
    self:GetPosition()
end

function Mod:GetPosition()
    self.db.position = type(self.db.position) == "table" and self.db.position or {}
    local position = self.db.position
    position.point = Shared.NormalizeAnchorPoint(position.point)
    position.x = publicNumber(position.x) or 0
    position.y = publicNumber(position.y) or 120
    position.coordSpace = "UIParent"
    return position
end

function Mod:BuildDisplayConfig()
    self:EnsureSettings()
    return {
        parent = UIParent,
        strata = "HIGH",
        size = {w = math.min(700, UIParent:GetWidth() - 32), h = self.db.font.size + 16},
        font = self.db.font
    }
end

function Mod:EnsureDisplay()
    if self.display then return end
    self.display = BossMods.Engines.TextAlert(self:BuildDisplayConfig())
    local frame = self.display.frame
    frame:EnableMouse(false)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnUpdate", function(_, elapsed) self:OnDisplayUpdate(elapsed) end)
    local text = self.display:GetTextFontString()
    text:SetWordWrap(true)
    text:SetNonSpaceWrap(true)
    text:SetJustifyH("CENTER")
    self:ApplyPosition()
end

function Mod:GetAnchor()
    self:EnsureDisplay()
    return self.display.frame
end

function Mod:ApplyPosition()
    if self.display then E:ApplyFramePosition(self.display.frame, self:GetPosition()) end
end

function Mod:SavePosition(position)
    position = position or E:GetFramePosition(self:GetAnchor())
    self.db.position = {
        point = position.point, x = position.x, y = position.y, coordSpace = "UIParent"
    }
    self:ApplyPosition()
end

function Mod:ResetPosition()
    self:SavePosition({point = "CENTER", x = 0, y = 120})
end

function Mod:Refresh()
    self:EnsureSettings()
    if not self.display then return end
    self.display:Apply(self:BuildDisplayConfig())
    self:ApplyPosition()
    self:RefreshDisplay()
end

function Mod:SetEditMode(enabled)
    self.editMode = enabled == true and self:IsEnabled() and not InCombatLockdown()
    if self.editMode then self:EnsureDisplay() end
    self:RefreshDisplay()
end

function Mod:SetPreviewMode(enabled)
    self.previewMode = enabled == true and self:IsEnabled() and not InCombatLockdown()
    if self.previewMode then self:EnsureDisplay() end
    self:RefreshDisplay()
end

function Mod:RefreshDisplay()
    if not self.display then return end
    local lines = {}
    local now = GetTime()
    for _, reminder in ipairs(self.activeReminders or {}) do
        local countdown = math.max(0, math.ceil((reminder.targetAt or now) - now))
        lines[#lines + 1] = reminder.text .. " " .. countdown
    end
    if #lines == 0 and (self.editMode or self.previewMode) then
        lines[1] = L["BossMods_PullReminderPreview"]
    end
    local text = self.display:GetTextFontString()
    text:SetWidth(self.display.frame:GetWidth() - 16)
    self.display:SetText(table.concat(lines, "\n"))
    if #lines == 0 then
        self.display:Hide()
    else
        self.display.frame:SetHeight(math.max(self.db.font.size + 16, text:GetStringHeight() + 16))
        self.display:Show()
    end
end

function Mod:OnDisplayUpdate(elapsed)
    if not self.activeReminders or #self.activeReminders == 0 then return end
    self.displayElapsed = (self.displayElapsed or 0) + elapsed
    if self.displayElapsed < 0.05 then return end
    self.displayElapsed = 0
    local now, changed = GetTime(), false
    for index = #self.activeReminders, 1, -1 do
        if now >= self.activeReminders[index].expiresAt then
            table.remove(self.activeReminders, index)
            changed = true
        end
    end
    local countdownSignature = {}
    for _, reminder in ipairs(self.activeReminders) do
        countdownSignature[#countdownSignature + 1] = math.max(
            0,
            math.ceil((reminder.targetAt or now) - now)
        )
    end
    countdownSignature = table.concat(countdownSignature, ":")
    if changed or countdownSignature ~= self.countdownSignature then
        self.countdownSignature = countdownSignature
        self:RefreshDisplay()
    end
end

function Mod:CancelPullState()
    self.pullGeneration = (self.pullGeneration or 0) + 1
    for _, timer in ipairs(self.pendingTimers or {}) do timer:Cancel() end
    self.pendingTimers, self.activeReminders = {}, {}
    self.displayElapsed = 0
    self.countdownSignature = nil
    self:RefreshDisplay()
end

function Mod:ActivateReminder(reminder, generation)
    if generation ~= self.pullGeneration or not self:IsEnabled() or InCombatLockdown() then return end
    self:EnsureDisplay()
    self.activeReminders[#self.activeReminders + 1] = {
        text = reminder.text,
        spellID = reminder.spellID,
        targetAt = reminder.targetAt,
        expiresAt = GetTime() + DISPLAY_DURATION
    }
    self:RefreshDisplay()
    if self.db.audio.enabled == true then
        local text = reminder.text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        BossMods.Alerts:SpeakTTS({text = text, voiceID = self.db.audio.voiceID})
    end
end

function Mod:OnStartPull(duration)
    if not self:IsEnabled() then return end
    duration = publicNumber(duration)
    if not duration then return end
    self:CancelPullState()
    if duration <= 0 or InCombatLockdown() then return end
    local generation = self.pullGeneration
    for _, reminder in ipairs(self:ParseReminders(NoteBlock:GetMainNoteText())) do
        local timeUntilTarget = duration - reminder.secondsRemaining
        if timeUntilTarget >= 0 then
            reminder.targetAt = GetTime() + timeUntilTarget
            local delay = math.max(0, timeUntilTarget - COUNTDOWN_LEAD)
            if delay == 0 then
                self:ActivateReminder(reminder, generation)
            else
                local scheduled = reminder
                self.pendingTimers[#self.pendingTimers + 1] = C_Timer.NewTimer(delay, function()
                    self:ActivateReminder(scheduled, generation)
                end)
            end
        end
    end
end

function Mod:OnStopPull()
    self:CancelPullState()
end

function Mod:OnUnitSpellcastSucceeded(_, unit, _, spellID)
    if E:SafeString(unit) ~= "player" or E:IsSecret(spellID) then return end
    spellID = baseSpellID(spellID)
    if not spellID then return end
    local changed = false
    for index = #(self.activeReminders or {}), 1, -1 do
        if self.activeReminders[index].spellID == spellID then
            table.remove(self.activeReminders, index)
            changed = true
        end
    end
    if changed then self:RefreshDisplay() end
end

function Mod:OnCombatStart()
    self.editMode, self.previewMode = false, false
    self:CancelPullState()
end

function Mod:OnProfileChanged()
    self.editMode, self.previewMode = false, false
    self:CancelPullState()
    self:Refresh()
end

function Mod:OnInitialize()
    self.pendingTimers, self.activeReminders = {}, {}
    self.pullGeneration = 0
    self.editMode, self.previewMode = false, false
    self:EnsureSettings()
end

function Mod:OnEnable()
    self:CancelPullState()
    self:EnsureDisplay()
    self:Refresh()
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "OnUnitSpellcastSucceeded")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnStopPull")
    self:RegisterMessage("ART_PROFILE_CHANGED", "OnProfileChanged")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    self.bigWigsSubscription = BossMods.BigWigs:Subscribe({
        owner = MODULE_NAME,
        onStartPull = function(duration) self:OnStartPull(duration) end,
        onStopPull = function() self:OnStopPull() end
    })
end

function Mod:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end
    self.editMode, self.previewMode = false, false
    self:CancelPullState()
end

E:RegisterBossModNoteBlock("PullReminder", {
    blocks = {{
        tag = "Pull",
        template = ("Pull:10:%s1:%s\nPull:10:everyone:Check your consumables\nPull:2:dps:Pre-pot")
            :format(L["Player"], L["BossMods_PullReminderPreview"])
    }},
    moduleName = MODULE_NAME,
    tab = "Misc", order = 50,
    labelKey = "BossMods_PullReminder",
    itemLabelKey = "BossMods_PullReminder"
})

E:RegisterBossModFeature("PullReminder", {
    tab = "Misc", order = 50,
    labelKey = "BossMods_PullReminder",
    descKey = "BossMods_PullReminderDesc",
    moduleName = MODULE_NAME
})
