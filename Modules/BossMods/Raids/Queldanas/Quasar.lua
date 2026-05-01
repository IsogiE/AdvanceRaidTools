local E, L, P = unpack(ART)

P.modules.BossMods_DarkQuasar = {
    enabled = false,
    position = {
        point = "CENTER",
        x = 0,
        y = 300
    },
    showIntermission = true,
    bar = {
        width = 300,
        height = 24,
        safeColor = {0.10, 0.80, 0.15, 1},
        dangerColor = {0.90, 0.10, 0.10, 1}
    },
    font = {
        size = 12,
        outline = ""
    },
    background = {
        opacity = 0.6
    },
    border = {
        enabled = true,
        texture = "Pixel",
        size = 1,
        color = {0, 0, 0, 1}
    },
    tts = {
        enabled = false,
        voice = 0,
        beamSoon = false,
        unsafeSoon = false,
        dangerCountdown = false
    }
}

local DARK_QUASAR_KEY = 1279420
local ENCOUNTER_ID = 3183
local MYTHIC_DIFFICULTY = 16

local NORMAL_TOTAL, NORMAL_SAFE = 7.5, 1.5
local INTERMISSION_TOTAL, INTERMISSION_SAFE = 5.0, 3.0
local INTERMISSION_TIME_HEURISTIC = 10.5

local Quasar = E:NewModule("BossMods_DarkQuasar", "AceEvent-3.0")

local BM

local function buildBarConfig(mod)
    local db = mod.db
    return {
        parent = UIParent,
        showFill = true,
        strata = "HIGH",
        size = {
            w = db.bar.width,
            h = db.bar.height
        },
        statusBar = {
            color = db.bar.safeColor
        },
        label = {
            size = db.font.size,
            outline = db.font.outline,
            color = {1, 1, 1, 1},
            justify = "LEFT"
        },
        right = {
            size = db.font.size,
            outline = db.font.outline,
            color = {1, 1, 1, 1},
            justify = "RIGHT"
        },
        center = {
            size = db.font.size,
            outline = db.font.outline,
            color = {1, 1, 1, 1},
            justify = "CENTER"
        },
        background = {
            color = {0, 0, 0, 1},
            opacity = db.background.opacity
        },
        border = {
            enabled = db.border.enabled,
            texture = db.border.texture,
            size = db.border.size,
            color = db.border.color
        }
    }
end

function Quasar:EnsureBar()
    if self.bar then
        return
    end
    self.bar = BM.Engines.Bar(buildBarConfig(self))
    self.bar:Hide()
    self.bar.onTick = function(t, total, safe)
        self:OnBarTick(t, total, safe)
    end
    self.bar.onStop = function()
        self:OnBarStop()
    end
    self:ApplyPosition()
end

function Quasar:OnModuleInitialize()
    self.scheduleToken = 0
    BM = BM or E:GetModule("BossMods")
    self:EnsureBar()
    self.bar:Apply(buildBarConfig(self))
    self:ApplyPosition()
    self.bar:Hide()
end

function Quasar:OnEnable()
    if not self.bar then
        self:EnsureBar()
    end
    self.bar:Apply(buildBarConfig(self))
    self:ApplyPosition()

    self.bwHandle = BM.BigWigs:Subscribe({
        owner = "DarkQuasar",
        spellKeys = {DARK_QUASAR_KEY},
        onStartBar = function(key, text, time)
            self:OnBigWigsStartBar(key, text, time)
        end
    })

    self:RegisterEvent("ENCOUNTER_END", "OnEncounterEnd")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
end

function Quasar:OnDisable()
    if self.bwHandle then
        self.bwHandle:Unsubscribe()
        self.bwHandle = nil
    end
    self.scheduleToken = (self.scheduleToken or 0) + 1
    self.editMode = false
    self.hasSpokenBeamSoon = false
    self.hasSpokenUnsafeSoon = false
    self.lastSpokenDanger = -1
    self.bar:Stop()
    if not self.editMode then
        self.bar:Hide()
    end
    BM.Alerts:StopTTS()
end

function Quasar:ApplyPosition()
    local pos = self.db.position
    local f = self.bar.frame
    f:ClearAllPoints()
    f:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Quasar:Refresh()
    if not self:IsEnabled() then
        return
    end
    self.bar:Apply(buildBarConfig(self))
    self:ApplyPosition()
end

function Quasar:SavePosition(pos)
    self.db.position.point = pos.point
    self.db.position.x = pos.x
    self.db.position.y = pos.y
    self:ApplyPosition()
end

function Quasar:OnBigWigsStartBar(key, text, time)
    if key ~= DARK_QUASAR_KEY then
        return
    end
    if type(time) ~= "number" or time <= 0 then
        return
    end

    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID ~= MYTHIC_DIFFICULTY then
        return
    end

    local countText = type(text) == "string" and text:match("%((%d+/?%d*)%)") or nil
    local label = countText and (L["BossMods_DQBarLabel"] .. " (" .. countText .. ")") or L["BossMods_DQBarLabel"]

    local isFirst = countText == "1/6" or countText == "1"
    local isIntermission = (type(text) == "string" and text:find("/") ~= nil) or
                               math.abs(time - INTERMISSION_TIME_HEURISTIC) < 0.2

    local total = isIntermission and INTERMISSION_TOTAL or NORMAL_TOTAL
    local safe = isIntermission and INTERMISSION_SAFE or NORMAL_SAFE

    if not (isIntermission and not isFirst) then
        self.scheduleToken = self.scheduleToken + 1
    end

    if isIntermission and not self.db.showIntermission then
        return
    end

    local capturedToken = self.scheduleToken

    if isIntermission and not isFirst then
        self:ScheduleStart(time, capturedToken, function()
            self:StartBar({
                total = total,
                safe = safe,
                lead = 0,
                label = label,
                suppressBeamSoon = true
            })
        end)
    elseif time > 4 then
        self:ScheduleStart(time - 4, capturedToken, function()
            self:StartBar({
                total = total,
                safe = safe,
                lead = 4,
                label = label,
                suppressBeamSoon = false
            })
        end)
    else
        self:StartBar({
            total = total,
            safe = safe,
            lead = time,
            label = label,
            suppressBeamSoon = false
        })
    end
end

function Quasar:ScheduleStart(delay, token, fn)
    C_Timer.After(delay, function()
        if self.scheduleToken ~= token then
            return
        end
        fn()
    end)
end

function Quasar:StartBar(opts)
    local db = self.db

    self.hasSpokenBeamSoon = opts.suppressBeamSoon and true or false
    self.hasSpokenUnsafeSoon = false
    self.lastSpokenDanger = -1

    -- Stop any running bar before starting a new one
    if self.bar:IsRunning() then
        self.bar:Stop()
    end

    self.bar:SetLabel(opts.label)
    self.bar:SetColor(db.bar.safeColor[1], db.bar.safeColor[2], db.bar.safeColor[3], db.bar.safeColor[4] or 1)

    if opts.lead > 0 then
        self.bar:SetMode("center")
        self.bar:SetCenter(("BEAM COMING %.1f"):format(opts.lead))
    else
        self.bar:SetMode("label")
        self.bar:SetRight(("SAFE %.1f"):format(opts.safe))
    end

    self.bar:Start({
        total = opts.total,
        safe = opts.safe,
        lead = opts.lead
    })
end

function Quasar:OnBarTick(t, total, safe)
    local db = self.db

    if t < 0 then
        self.bar:SetMode("center")
        self.bar:SetCenter(("BEAM COMING %.1f"):format(-t))
        if not self.hasSpokenBeamSoon and db.tts.enabled and db.tts.beamSoon then
            BM.Alerts:SpeakTTS({
                text = L["BossMods_DQTTSBeamSoon"],
                voiceID = db.tts.voice
            })
            self.hasSpokenBeamSoon = true
        end
    elseif t < safe then
        self.bar:SetMode("label")
        self.bar:SetColor(db.bar.safeColor[1], db.bar.safeColor[2], db.bar.safeColor[3], db.bar.safeColor[4] or 1)
        self.bar:SetRight(("SAFE %.1f"):format(safe - t))
        if not self.hasSpokenUnsafeSoon and db.tts.enabled and db.tts.unsafeSoon then
            BM.Alerts:SpeakTTS({
                text = L["BossMods_DQTTSUnsafeSoon"],
                voiceID = db.tts.voice
            })
            self.hasSpokenUnsafeSoon = true
        end
    else
        self.bar:SetMode("label")
        self.bar:SetColor(db.bar.dangerColor[1], db.bar.dangerColor[2], db.bar.dangerColor[3],
            db.bar.dangerColor[4] or 1)
        self.bar:SetRight(("%.1f"):format(total - t))
        if db.tts.enabled and db.tts.dangerCountdown then
            local remaining = total - t
            local r = math.ceil(remaining)
            if r <= 5 and r > 0 and r ~= self.lastSpokenDanger then
                BM.Alerts:SpeakTTS({
                    text = tostring(r),
                    voiceID = db.tts.voice
                })
                self.lastSpokenDanger = r
            end
        end
    end
end

function Quasar:OnBarStop()
    if not self.editMode then
        self.bar:Hide()
    end
end

function Quasar:OnEncounterEnd()
    self.scheduleToken = self.scheduleToken + 1
    self.bar:Stop()
    if not self.editMode then
        self.bar:Hide()
    end
    BM.Alerts:StopTTS()
end

function Quasar:SetEditMode(v)
    if not self:IsEnabled() then
        return
    end
    self.editMode = v and true or false

    if self.editMode then
        if self.bar:IsRunning() then
            self.bar:Stop()
        end
        local db = self.db
        self.bar:SetLabel(L["BossMods_DQBarLabel"])
        self.bar:SetMode("label")
        self.bar:SetColor(db.bar.dangerColor[1], db.bar.dangerColor[2], db.bar.dangerColor[3],
            db.bar.dangerColor[4] or 1)
        self.bar:SetRight("2.5")
        self.bar:SetValue(0.5)
        self.bar:SetMarker((NORMAL_TOTAL - NORMAL_SAFE) / NORMAL_TOTAL)
        self.bar:Show()
    else
        if self.bar and not self.bar:IsRunning() then
            self.bar:Hide()
        end
    end
end

do
    local parent = E:GetModule("BossMods", true)
    if parent and parent.RegisterFeature then
        parent:RegisterFeature("DarkQuasar", {
            tab = "Queldanas",
            order = 20,
            labelKey = "BossMods_DarkQuasar",
            descKey = "BossMods_DarkQuasarDesc",
            moduleName = "BossMods_DarkQuasar"
        })
    end
end
