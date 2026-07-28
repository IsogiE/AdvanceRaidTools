local E = unpack(ART)

local MODULE_NAME = "BossMods_VoidspireAbilityAlerts"
local TTS_COUNTDOWN_MESSAGE_LEAD = 2

local function hasTTSTimeVariable(settings)
    return settings
        and settings.mode ~= "sound"
        and type(settings.ttsText) == "string"
        and settings.ttsText:find("{time}", 1, true) ~= nil
end

local function getTTSCountdownMessageLead(settings)
    if not settings or settings.mode == "sound"
        or not settings.countdown and not hasTTSTimeVariable(settings)
    then
        return 0
    end

    return TTS_COUNTDOWN_MESSAGE_LEAD
end

local Shared = E:GetModule("BossMods").Engines.Shared
local normalizeAnchorPoint = Shared.NormalizeAnchorPoint
local getCenterRelativePosition = Shared.GetCenterRelativePosition
local updateAnchorPointMarker = Shared.UpdateAnchorPointMarker

-------------------------------------------------------------------------------
-- Default settings
-------------------------------------------------------------------------------

local defaults = {
    enabled = true,

    barPositions = {},
    textPositions = {},

    barPosition = {
        point = "CENTER",
        x = 0,
        y = 220
    },

    textPosition = {
        point = "CENTER",
        x = 0,
        y = 120
    },

    bossDefaults = {},

    abilities = {
        [1249262] = {
            enabled = true,

bar = {
    enabled = false,
    unattached = false,
    secondsBefore = 5,
    delayBy = 0,
    text = "{spell}",

    width = 300,
    height = 24,

    fillColor = {
        0.20,
        0.60,
        1.00,
        1.00
    },

    backgroundColor = {
        0.00,
        0.00,
        0.00,
        1.00
    },

    backgroundOpacity = 0.30,

    font = {
        name = "Friz Quadrata TT",
        size = 14,
        outline = "OUTLINE"
    }
},

text = {
    enabled = false,
    unattached = false,
    secondsBefore = 7,
    delayBy = 0,
    message = "{spell} in {time}",
    countdown = true,

    font = {
        name = "Friz Quadrata TT",
        size = 34,
        outline = "THICKOUTLINE"
    }
},

            audio = {
                enabled = false,
                secondsBefore = 3,
                delayBy = 0,
                mode = "tts",
                sound = "None",
                channel = "Master",
            ttsText = "{spell} in {time}",
            voiceID = 0,
            countdown = false
            }
        }
    }
}

E:RegisterModuleDefaults(MODULE_NAME, defaults)

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

local AbilityAlerts = E:NewModule(MODULE_NAME, "AceEvent-3.0")

E:SetModuleParent(MODULE_NAME, "BossMods")

local BossMods

AbilityAlerts.abilitiesBySpellID = {}
AbilityAlerts.triggeredAbilitiesBySpellID = {}
AbilityAlerts.alertTokens = {}
AbilityAlerts.postHitLifecycleToken = 0
AbilityAlerts.bars = {}
AbilityAlerts.textAlerts = {}

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------

local function replaceVariables(message, ability, remaining, timeText)
    message = tostring(message or "")

    message = message:gsub(
        "{spell}",
        ability.shortName or ability.name or ""
    )
    message = message:gsub(
        "{time}",
        timeText or tostring(math.max(0, math.ceil(remaining or 0)))
    )

    return message
end

local function getSeconds(value, fallback)
    value = tonumber(value)

    if not value then
        return fallback
    end

    return math.max(0, value)
end

local function colorFromHex(value)
    value = type(value) == "string"
        and value:gsub("#", "")
        or ""

    if #value ~= 6 then
        return nil
    end

    local r = tonumber(value:sub(1, 2), 16)
    local g = tonumber(value:sub(3, 4), 16)
    local b = tonumber(value:sub(5, 6), 16)

    if not r or not g or not b then
        return nil
    end

    return {r / 255, g / 255, b / 255, 1}
end

local DIFFICULTY_KEYS = {
    [14] = "normal",
    [15] = "heroic",
    [16] = "mythic"
}

local STARSPLINTER_TRIGGER_SPELL_ID = 1282441
local STARSPLINTER_PHASE_FOUR_SPELL_ID = 1285510

local function isStarsplinterPhaseFour(duration)
    local bigWigs = _G.BigWigs

    if bigWigs and type(bigWigs.GetBossModule) == "function" then
        local okModule, module = pcall(
            bigWigs.GetBossModule,
            bigWigs,
            "Midnight Falls",
            true
        )

        if okModule and module and type(module.GetStage) == "function" then
            local okStage, stage = pcall(module.GetStage, module)
            stage = okStage and tonumber(stage) or nil

            if stage == 4 then
                return true
            elseif stage == 2 then
                return false
            end
        end
    end

    -- BigWigs currently starts the intermission bar at 38 seconds and the
    -- Phase 4 bars at 12.7/20 seconds. This keeps the split working if the
    -- BigWigs stage cannot be read, such as during certain reload states.
    duration = tonumber(duration)
    return duration ~= nil and duration <= 25
end

local function ensureDifficultySettings(settings)
    if type(settings) ~= "table" then
        return nil
    end

    settings.difficulties = type(settings.difficulties) == "table"
        and settings.difficulties
        or {}

    for _, key in pairs(DIFFICULTY_KEYS) do
        if settings.difficulties[key] == nil then
            settings.difficulties[key] = true
        end
    end

    return settings.difficulties
end

local function isDifficultyEnabled(settings, ability)
    local difficulties = ensureDifficultySettings(settings)
    local _, _, difficultyID = GetInstanceInfo()
    difficultyID = tonumber(difficultyID)

    local key = DIFFICULTY_KEYS[difficultyID]

    if difficultyID == 233
        and ability
        and ability.bossKey == "Rotmire"
    then
        key = "mythic"
    end

    return difficulties ~= nil
        and key ~= nil
        and difficulties[key] == true
end

-------------------------------------------------------------------------------
-- Ability data
-------------------------------------------------------------------------------

function AbilityAlerts:BuildAbilityLookup()
    wipe(self.abilitiesBySpellID)
    wipe(self.triggeredAbilitiesBySpellID)

    for _, boss in ipairs(E.VoidspireAbilityData or {}) do
        for _, ability in ipairs(boss.abilities or {}) do
            local spellID = tonumber(ability.spellID)

            if spellID then
                local fullName =
                    ability.name or tostring(spellID)

                local shortName =
                    ability.shortName
                    or fullName:gsub("%s*%b()%s*$", "")

                local entry = {
                    spellID = spellID,
                    name = fullName,
                    shortName = shortName,
                    order = ability.order or 100,
                    kind = ability.kind,
                    triggerSpellID = tonumber(ability.triggerSpellID),
                    castTimeAdjustment = tonumber(ability.castTimeAdjustment),
                    postHitStages = ability.postHitStages,
                    defaultBarColor = ability.defaultBarColor,
                    defaultBarEnabled = ability.defaultBarEnabled,

                    bossKey = boss.bossKey,
                    bossName = boss.bossName,
                    bossOrder = boss.bossOrder or 100
                }

                self.abilitiesBySpellID[spellID] = entry

                if entry.triggerSpellID then
                    local triggered =
                        self.triggeredAbilitiesBySpellID[entry.triggerSpellID]

                    if not triggered then
                        triggered = {}
                        self.triggeredAbilitiesBySpellID[entry.triggerSpellID] = triggered
                    end

                    triggered[#triggered + 1] = entry
                end
            end
        end
    end
end

function AbilityAlerts:EnsureCustomBarDefaults()
    if not self.db then
        return
    end

    self.db.abilities = self.db.abilities or {}

    for spellID, ability in pairs(self.abilitiesBySpellID) do
        local settings =
            self.db.abilities[spellID]
            or self.db.abilities[tostring(spellID)]

        if not settings then
            settings = {}
            self.db.abilities[spellID] = settings
        end

        settings.enabled = true
        settings.bar = settings.bar or {}

        if settings.voidspireBarPresetVersion ~= 1 then
            local presetColor = colorFromHex(ability.defaultBarColor)

            if presetColor then
                settings.bar.fillColor = presetColor
                settings.bar.individualFillColorInitialized = true
            end

            if ability.defaultBarEnabled ~= nil then
                settings.bar.enabled = ability.defaultBarEnabled == true
            elseif ability.kind and settings.bar.enabled == nil then
                settings.bar.enabled = true
            end

            settings.voidspireBarPresetVersion = 1
        elseif ability.kind and settings.bar.enabled == nil then
            settings.bar.enabled = true
        end

        if settings.bar.text == nil then
            settings.bar.text = "{spell}"
        end
    end
end

function AbilityAlerts:GetAbility(spellID)
    return self.abilitiesBySpellID[tonumber(spellID)]
end

function AbilityAlerts:GetAbilitySettings(spellID)
    if not self.db or not self.db.abilities then
        return nil
    end

    spellID = tonumber(spellID)

    local settings = self.db.abilities[spellID]
        or self.db.abilities[tostring(spellID)]

    ensureDifficultySettings(settings)
    return settings
end

function AbilityAlerts:GetBossDefaults(bossKey)
    local defaultsMod =
        E:GetModule("BossMods_AbilityAlertDefaults", true)

    if defaultsMod and defaultsMod.GetAppearance then
        return defaultsMod:GetAppearance()
    end

    return {
        bar = {
            width = 300,
            height = 24,
            iconEnabled = true,
            iconSize = 24,
            texture = "Clean",
            fillColor = {0.20, 0.60, 1.00, 1.00},
            backgroundColor = {0.00, 0.00, 0.00, 1.00},
            backgroundOpacity = 0.30,
            font = {
                name = "Friz Quadrata TT",
                size = 14,
                outline = "OUTLINE"
            }
        },
        text = {
            font = {
                name = "Friz Quadrata TT",
                size = 34,
                outline = "THICKOUTLINE"
            }
        }
    }
end

function AbilityAlerts:GetBarAppearance(spellID)
    local ability = self:GetAbility(spellID)
    local settings = self:GetAbilitySettings(spellID) or {}
    local bar = settings.bar or {}
    local defaults = self:GetBossDefaults(ability and ability.bossKey or "Unknown").bar

    if bar.individualFillColorInitialized ~= true then
        local source = bar.overrideAppearance and bar.fillColor
            or defaults.fillColor

        if source then
            bar.fillColor = {
                source[1] or source.r or 0.20,
                source[2] or source.g or 0.60,
                source[3] or source.b or 1.00,
                source[4] or source.a or 1.00
            }
        end

        bar.individualFillColorInitialized = true
    end

    if bar.overrideAppearance then
        return bar
    end

    local appearance = {}

    for key, value in pairs(defaults) do
        appearance[key] = value
    end

    appearance.fillColor = bar.fillColor or defaults.fillColor
    return appearance
end

function AbilityAlerts:GetTextAppearance(spellID)
    local ability = self:GetAbility(spellID)
    local settings = self:GetAbilitySettings(spellID) or {}
    local text = settings.text or {}
    local defaults = self:GetBossDefaults(ability and ability.bossKey or "Unknown").text

    if text.overrideAppearance then
        return text
    end

    return defaults
end

-------------------------------------------------------------------------------
-- Cancellation and scheduling
-------------------------------------------------------------------------------

function AbilityAlerts:InvalidateAbility(spellID)
    spellID = tonumber(spellID)

    if not spellID then
        return 0
    end

    -- A new timer for the same ability invalidates the old countdown.
    -- Hide its existing text immediately so an old "1" cannot remain
    -- visible after the old scheduled Hide callback is rejected by token checks.
    local alert = self.textAlerts[spellID]

    if alert then
        alert:Hide()
        self:ApplyPositions()
    end

    self.alertTokens[spellID] =
        (self.alertTokens[spellID] or 0) + 1

    return self.alertTokens[spellID]
end

function AbilityAlerts:GetToken(spellID)
    return self.alertTokens[tonumber(spellID)] or 0
end

function AbilityAlerts:Schedule(spellID, delay, token, callback)
    delay = math.max(0, tonumber(delay) or 0)

    if delay == 0 then
        if self:GetToken(spellID) == token then
            callback()
        end

        return
    end

    C_Timer.After(delay, function()
        if not self:IsEnabled() then
            return
        end

        if self:GetToken(spellID) ~= token then
            return
        end

        callback()
    end)
end

function AbilityAlerts:SchedulePostHit(delay, token, callback)
    delay = math.max(0, tonumber(delay) or 0)

    local function run()
        if not self:IsEnabled()
            or self.postHitLifecycleToken ~= token
        then
            return
        end

        callback()
    end

    if delay == 0 then
        run()
        return
    end

    C_Timer.After(delay, run)
end

-------------------------------------------------------------------------------
-- Bar
-------------------------------------------------------------------------------

local function getSpellIcon(spellID)
    spellID = math.abs(tonumber(spellID) or 0)

    if C_Spell and C_Spell.GetSpellTexture then
        local texture = C_Spell.GetSpellTexture(spellID)

        if texture then
            return texture
        end
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)

        if info and info.iconID then
            return info.iconID
        end
    end

    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end

    return nil
end

local function buildBarConfig(settings, ability)
    settings = settings or {}

    local font = settings.font or {}

    local fillColor =
        settings.fillColor
        or {
            0.20,
            0.60,
            1.00,
            1.00
        }

    local backgroundColor =
        settings.backgroundColor
        or {
            0.00,
            0.00,
            0.00,
            1.00
        }

    return {
        parent = UIParent,
        showFill = true,
        strata = "HIGH",
        textUpdateInterval = 0.1,

        size = {
            w = tonumber(settings.width) or 300,
            h = tonumber(settings.height) or 24
        },

        icon = {
            enabled = ability ~= nil
                and ability.kind == nil
                and settings.iconEnabled ~= false,
            size = tonumber(settings.iconSize) or 24,
            texture = ability and getSpellIcon(ability.spellID) or nil
        },

        statusBar = {
            texture = settings.texture or "Clean",

            color = {
                fillColor[1] or fillColor.r or 0.20,
                fillColor[2] or fillColor.g or 0.60,
                fillColor[3] or fillColor.b or 1.00,
                fillColor[4] or fillColor.a or 1.00
            }
        },

        label = {
            font = font.name or "Friz Quadrata TT",
            size = tonumber(font.size) or 14,
            outline = font.outline or "OUTLINE",
            color = {1, 1, 1, 1},
            justify = "LEFT"
        },

        right = {
            font = font.name or "Friz Quadrata TT",
            size = tonumber(font.size) or 14,
            outline = font.outline or "OUTLINE",
            color = {1, 1, 1, 1},
            justify = "RIGHT"
        },

        background = {
            color = {
                backgroundColor[1]
                    or backgroundColor.r
                    or 0,

                backgroundColor[2]
                    or backgroundColor.g
                    or 0,

                backgroundColor[3]
                    or backgroundColor.b
                    or 0,

                backgroundColor[4]
                    or backgroundColor.a
                    or 1
            },

            opacity =
                tonumber(settings.backgroundOpacity)
                or 0.30
        },

        border = {
            enabled = true,
            texture = "Pixel",
            size = 1,
            color = {0, 0, 0, 1}
        }
    }
end

function AbilityAlerts:EnsureBar(spellID)
    spellID = tonumber(spellID)

    if self.bars[spellID] then
        return self.bars[spellID]
    end

local abilitySettings =
    self:GetAbilitySettings(spellID)

local barSettings =
    abilitySettings and abilitySettings.bar or {}

local barAppearance = self:GetBarAppearance(spellID)

local bar =
    BossMods.Engines.Bar(
        buildBarConfig(barAppearance, self:GetAbility(spellID))
    )

    local index = 0

    for existingSpellID in pairs(self.bars) do
        if existingSpellID ~= spellID then
            index = index + 1
        end
    end

    bar.frame:ClearAllPoints()

local position = self.db.barPosition or {}

bar.frame:SetPoint(
    normalizeAnchorPoint(position.point),
    UIParent,
    "CENTER",
    position.x or 0,
    (position.y or 220) - index * 30
)

    bar:Hide()

    bar.onTick = function(elapsed, total)
        local remaining = math.max(0, total - elapsed)

        bar:SetRight(("%.1f"):format(remaining))

        if bar.postHitStageActive then
            bar:SetValue(math.max(0, math.min(1, elapsed / total)))
            bar:SetRight(("%.1f"):format(math.min(total, elapsed)))
        end
    end

    bar.onStop = function()
        bar.postHitStageActive = false
        bar:Hide()
        self:ApplyPositions()
    end

    self.bars[spellID] = bar

    return bar
end

function AbilityAlerts:StartBar(ability, settings, durationOverride)
    local duration = durationOverride ~= nil
        and getSeconds(durationOverride, 0)
        or getSeconds(settings.secondsBefore, 5)

    if duration <= 0 then
        return
    end

    local bar = self:EnsureBar(ability.spellID)

    if bar:IsRunning() then
        bar:Stop()
    end

    bar:SetMode("label")
    bar:SetLabel(
        replaceVariables(settings.text, ability, duration)
    )
    bar:SetRight(("%.1f"):format(duration))

    bar:Start({
        total = duration
    })

    self:ApplyPositions()
end

-------------------------------------------------------------------------------
-- Text
-------------------------------------------------------------------------------

local function buildTextConfig(settings)
    settings = settings or {}

    local font = settings.font or {}

    return {
        parent = UIParent,
        strata = "HIGH",

        size = {
            w = 600,
            h = 80
        },

        font = {
            name = font.name or "Friz Quadrata TT",
            size = tonumber(font.size) or 34,
            outline = font.outline or "THICKOUTLINE",
            color = {1, 1, 1, 1}
        }
    }
end

function AbilityAlerts:EnsureTextAlert(spellID)
    spellID = tonumber(spellID)

    if self.textAlerts[spellID] then
        return self.textAlerts[spellID]
    end

local abilitySettings =
    self:GetAbilitySettings(spellID)

local textSettings =
    abilitySettings and abilitySettings.text or {}

local textAppearance = self:GetTextAppearance(spellID)

local alert =
    BossMods.Engines.TextAlert(
        buildTextConfig(textAppearance)
    )

alert.frame:ClearAllPoints()

local position = self.db.textPosition or {}

alert.frame:SetPoint(
    normalizeAnchorPoint(position.point),
    UIParent,
    "CENTER",
    position.x or 0,
    position.y or 120
)
alert:Hide()

self.textAlerts[spellID] = alert

self:ApplyPositions()

return alert
end

function AbilityAlerts:ShowText(
    ability,
    settings,
    remaining,
    token
)
    if self:GetToken(ability.spellID) ~= token then
        return
    end

    local alert = self:EnsureTextAlert(ability.spellID)

    local timeText = settings.showOneDecimal ~= false
        and ("%.1f"):format(math.max(0, remaining or 0))
        or tostring(math.max(0, math.ceil(remaining or 0)))

    alert:SetText(
        replaceVariables(
            settings.message,
            ability,
            remaining,
            timeText
        )
    )

    alert:Show()
    self:ApplyPositions()
end

function AbilityAlerts:StartTextCountdown(
    ability,
    settings,
    token
)
    local seconds = getSeconds(settings.secondsBefore, 7)

    if seconds <= 0 then
        return
    end

    local alert = self:EnsureTextAlert(ability.spellID)

    if settings.showOneDecimal ~= false then
        local startedAt = GetTime()
        local ticker

        self:ShowText(ability, settings, seconds, token)

        ticker = C_Timer.NewTicker(0.1, function()
            if not self:IsEnabled()
                or self:GetToken(ability.spellID) ~= token
            then
                ticker:Cancel()
                return
            end

            local remaining = seconds - (GetTime() - startedAt)

            if remaining <= 0 then
                alert:Hide()
                ticker:Cancel()
                return
            end

            self:ShowText(ability, settings, remaining, token)
        end)

        return
    end

    seconds = math.floor(seconds)

    for remaining = seconds, 1, -1 do
        local delay = seconds - remaining

        self:Schedule(
            ability.spellID,
            delay,
            token,
            function()
                self:ShowText(
                    ability,
                    settings,
                    remaining,
                    token
                )
            end
        )
    end

    self:Schedule(
        ability.spellID,
        seconds,
        token,
        function()
            alert:Hide()
        end
    )
end

-------------------------------------------------------------------------------
-- Audio and TTS
-------------------------------------------------------------------------------

function AbilityAlerts:PlayAudio(
    ability,
    settings,
    remaining,
    countdownNumberOnly
)
    if settings.mode == "sound" then
        BossMods.Alerts:PlaySound({
            name = settings.sound,
            channel = settings.channel or "Master"
        })

        return
    end

local ttsText = settings.ttsText

if hasTTSTimeVariable(settings) and not countdownNumberOnly then
    ttsText = tostring(ttsText or ""):gsub("{time}", "")
    ttsText = ttsText:gsub("%s+", " ")
    ttsText = ttsText:match("^%s*(.-)%s*$")
end

BossMods.Alerts:StopTTS()

BossMods.Alerts:SpeakTTS({
    text = countdownNumberOnly
        and tostring(remaining)
        or replaceVariables(
            ttsText,
            ability,
            remaining
        ),

    voiceID = tonumber(settings.voiceID) or 0
})
end

function AbilityAlerts:StartAudio(
    ability,
    settings,
    token
)
    local seconds = math.floor(
        getSeconds(settings.secondsBefore, 3)
    )

    local hasTimeVariable = hasTTSTimeVariable(settings)

    if settings.mode == "sound"
        or not settings.countdown and not hasTimeVariable
    then
        self:PlayAudio(ability, settings, seconds)
        return
    end

    self:PlayAudio(ability, settings, seconds)

    if not settings.countdown then
        self:Schedule(
            ability.spellID,
            getTTSCountdownMessageLead(settings),
            token,
            function()
                self:PlayAudio(
                    ability,
                    settings,
                    seconds,
                    true
                )
            end
        )

        return
    end

    for remaining = seconds, 1, -1 do
        local delay = getTTSCountdownMessageLead(settings)
            + seconds - remaining

        self:Schedule(
            ability.spellID,
            delay,
            token,
            function()
                self:PlayAudio(
                    ability,
                    settings,
                    remaining,
                    true
                )
            end
        )
    end
end

-------------------------------------------------------------------------------
-- BigWigs
-------------------------------------------------------------------------------

local function getCastTimeAdjustment(ability, settings)
    if not ability or not settings
        or settings.removeCastTimeAdjustment == true
    then
        return 0
    end

    return getSeconds(ability.castTimeAdjustment, 0)
end

function AbilityAlerts:StartPostHitStageTextCountdown(
    ability,
    settings,
    token,
    displayText,
    duration
)
    duration = getSeconds(duration, 0)

    if duration <= 0 then
        return
    end

    local alert = self:EnsureTextAlert(ability.spellID)
    local startedAt = GetTime()
    local interval = settings.showOneDecimal ~= false and 0.1 or 1
    local ticker

    local function updateText()
        if not self:IsEnabled()
            or self.postHitLifecycleToken ~= token
        then
            if ticker then
                ticker:Cancel()
            end
            return
        end

        local remaining = duration - (GetTime() - startedAt)

        if remaining <= 0 then
            alert:Hide()
            self:ApplyPositions()

            if ticker then
                ticker:Cancel()
            end
            return
        end

        local countdownText = settings.showOneDecimal ~= false
            and ("%.1f"):format(remaining)
            or tostring(math.ceil(remaining))

        alert:SetText(tostring(displayText) .. " " .. countdownText)
        alert:Show()
        self:ApplyPositions()
    end

    updateText()
    ticker = C_Timer.NewTicker(interval, updateText)
end

function AbilityAlerts:SchedulePostHitStages(ability, settings, token, hitDelay)
    local postHitStages = ability and ability.postHitStages

    if not postHitStages then
        return
    end

    local barEnabled = settings.bar and settings.bar.enabled
    local textEnabled = settings.text and settings.text.enabled

    if not barEnabled and not textEnabled then
        return
    end

    local postHitToken = self.postHitLifecycleToken
    local elapsed = 0

    for _, stage in ipairs(postHitStages.stages or {}) do
        local stageDuration = getSeconds(stage.duration, 0)

        if stageDuration > 0 then
            local stageDelay = getSeconds(hitDelay, 0) + elapsed
            local stageText = stage.text

            if barEnabled then
                self:SchedulePostHit(stageDelay, postHitToken, function()
                    self:StartBar(ability, settings.bar, stageDuration)

                    local bar = self:EnsureBar(ability.spellID)
                    bar.postHitStageActive = true
                    bar:SetValue(0)
                    bar:SetRight("0.0")
                    bar:SetLabel(stageText or ability.shortName or ability.name)
                end)
            end

            if textEnabled then
                local displayText = stageText or ability.shortName or ability.name
                local firstUpdateDelay = stageDelay + 0.05

                self:SchedulePostHit(firstUpdateDelay, postHitToken, function()
                    self:StartPostHitStageTextCountdown(
                        ability,
                        settings.text,
                        postHitToken,
                        displayText,
                        math.max(0, stageDuration - 0.05)
                    )
                end)
            end

            elapsed = elapsed + stageDuration
        end
    end
end

function AbilityAlerts:OnBigWigsStartBar(
    spellKey,
    bigWigsText,
    duration
)
    local spellID = tonumber(spellKey)
    duration = tonumber(duration)

    if not duration or duration <= 0 then
        return
    end

    local ability = self:GetAbility(spellID)

    if spellID == STARSPLINTER_TRIGGER_SPELL_ID
        and isStarsplinterPhaseFour(duration)
    then
        local triggered =
            self.triggeredAbilitiesBySpellID[STARSPLINTER_TRIGGER_SPELL_ID]

        for _, candidate in ipairs(triggered or {}) do
            if candidate.spellID == STARSPLINTER_PHASE_FOUR_SPELL_ID then
                ability = candidate
                spellID = candidate.spellID
                break
            end
        end
    end

    if not ability then
        return
    end

    if BossMods and BossMods.IsFeatureEnabled
        and not BossMods:IsFeatureEnabled("Voidspire" .. ability.bossKey)
    then
        return
    end

    local settings = self:GetAbilitySettings(spellID)

    if not settings then
        return
    end

    if not isDifficultyEnabled(settings, ability) then
        return
    end

    local token = self:InvalidateAbility(spellID)
    local castTimeAdjustment = getCastTimeAdjustment(ability, settings)
    local adjustedDuration = duration + castTimeAdjustment

    if settings.bar and settings.bar.enabled then
local secondsBefore = getSeconds(
    settings.bar.secondsBefore,
    5
)

local delayBy = getSeconds(
    settings.bar.delayBy,
    0
)

self:Schedule(
    spellID,
    adjustedDuration - secondsBefore + delayBy,
            token,
            function()
                self:StartBar(
                    ability,
                    settings.bar
                )
            end
        )
    end

    if settings.text and settings.text.enabled then
local secondsBefore = getSeconds(
    settings.text.secondsBefore,
    7
)

local delayBy = getSeconds(
    settings.text.delayBy,
    0
)

self:Schedule(
    spellID,
    adjustedDuration - secondsBefore + delayBy,
            token,
            function()
                self:StartTextCountdown(
                    ability,
                    settings.text,
                    token
                )
            end
        )
    end

    if settings.audio and settings.audio.enabled then
        local secondsBefore = getSeconds(
            settings.audio.secondsBefore,
            3
        )

        local delayBy = getSeconds(
            settings.audio.delayBy,
            0
        )

        self:Schedule(
            spellID,
            adjustedDuration - secondsBefore + delayBy
                - getTTSCountdownMessageLead(settings.audio),
            token,
            function()
                self:StartAudio(
                    ability,
                    settings.audio,
                    token
                )
            end
        )
    end

    self:SchedulePostHitStages(
        ability,
        settings,
        token,
        adjustedDuration
    )

end


-------------------------------------------------------------------------------
-- Position, testing, and edit mode
-------------------------------------------------------------------------------

function AbilityAlerts:GetBarPosition(spellID)
    spellID = tonumber(spellID)

    self.db.barPositions =
        self.db.barPositions or {}

    local position =
        self.db.barPositions[spellID]
        or self.db.barPositions[tostring(spellID)]

    if not position then
        local fallback = self.db.barPosition or {}

        position = {
            point = normalizeAnchorPoint(fallback.point),
            x = fallback.x or 0,
            y = fallback.y or 220
        }

        self.db.barPositions[spellID] = position
    end

    position.point = normalizeAnchorPoint(position.point)
    position.x = tonumber(position.x) or 0
    position.y = tonumber(position.y) or 220

    return position
end

function AbilityAlerts:GetTextPosition(spellID)
    spellID = tonumber(spellID)

    self.db.textPositions =
        self.db.textPositions or {}

    local position =
        self.db.textPositions[spellID]
        or self.db.textPositions[tostring(spellID)]

    if not position then
        local fallback = self.db.textPosition or {}

        position = {
            point = normalizeAnchorPoint(fallback.point),
            x = fallback.x or 0,
            y = fallback.y or 120
        }

        self.db.textPositions[spellID] = position
    end

    position.point = normalizeAnchorPoint(position.point)
    position.x = tonumber(position.x) or 0
    position.y = tonumber(position.y) or 120

    return position
end

function AbilityAlerts:ApplyPositions()
    local defaultsMod =
        E:GetModule(
            "BossMods_AbilityAlertDefaults",
            true
        )

    local barGroup =
        defaultsMod
        and defaultsMod:GetGroupSettings("bar")
        or {
            point = "CENTER",
            x = -400,
            y = 80,
            growth = "DOWN",
            spacing = 4
        }

    local textGroup =
        defaultsMod
        and defaultsMod:GetGroupSettings("text")
        or {
            point = "CENTER",
            x = 0,
            y = 200,
            growth = "DOWN",
            spacing = 8
        }

    local function sortedAttachedSpellIDs(
        collection,
        kind
    )
        local attached = {}

        for spellID in pairs(collection) do
            local settings =
                self:GetAbilitySettings(spellID)

            local typeSettings =
                settings and settings[kind]

            local object = collection[spellID]
            local isActive = false

            if kind == "bar" then
                isActive =
                    object
                    and object.IsRunning
                    and object:IsRunning()
            else
                isActive =
                    object
                    and object.frame
                    and object.frame:IsShown()
            end

            if isActive
                and not (
                    typeSettings
                    and typeSettings.unattached
                )
            then
                attached[#attached + 1] = spellID
            end
        end

        table.sort(attached, function(a, b)
            local abilityA = self:GetAbility(a)
            local abilityB = self:GetAbility(b)

            local bossOrderA =
                abilityA and abilityA.bossOrder or 100
            local bossOrderB =
                abilityB and abilityB.bossOrder or 100

            if bossOrderA ~= bossOrderB then
                return bossOrderA < bossOrderB
            end

            local orderA =
                abilityA and abilityA.order or 100
            local orderB =
                abilityB and abilityB.order or 100

            if orderA ~= orderB then
                return orderA < orderB
            end

            return tonumber(a) < tonumber(b)
        end)

        return attached
    end

    local attachedBars =
        sortedAttachedSpellIDs(
            self.bars,
            "bar"
        )

    local barDirection =
        barGroup.growth == "UP" and 1 or -1

    local barOffset = 0

    for _, spellID in ipairs(attachedBars) do
        local bar = self.bars[spellID]

        bar.frame:ClearAllPoints()
        bar.frame:SetPoint(
            normalizeAnchorPoint(barGroup.point),
            UIParent,
            "CENTER",
            barGroup.x or 0,
            (barGroup.y or 80)
                + barOffset * barDirection
        )
        updateAnchorPointMarker(
            bar.frame,
            barGroup.point
        )

        local appearance =
            self:GetBarAppearance(spellID)

        local barHeight =
            tonumber(
                appearance and appearance.height
            ) or 24

        barOffset =
            barOffset
            + barHeight
            + (barGroup.spacing or 4)
    end

    for spellID, bar in pairs(self.bars) do
        local settings =
            self:GetAbilitySettings(spellID)

        if settings
            and settings.bar
            and settings.bar.unattached
        then
            local position =
                self:GetBarPosition(spellID)

            bar.frame:ClearAllPoints()
            bar.frame:SetPoint(
                normalizeAnchorPoint(position.point),
                UIParent,
                "CENTER",
                position.x or 0,
                position.y or 220
            )
            updateAnchorPointMarker(
                bar.frame,
                position.point
            )
        end
    end

    local attachedTexts =
        sortedAttachedSpellIDs(
            self.textAlerts,
            "text"
        )

    local textDirection =
        textGroup.growth == "UP" and 1 or -1

    local textOffset = 0

    for _, spellID in ipairs(attachedTexts) do
        local alert = self.textAlerts[spellID]

        alert.frame:ClearAllPoints()
        alert.frame:SetPoint(
            normalizeAnchorPoint(textGroup.point),
            UIParent,
            "CENTER",
            textGroup.x or 0,
            (textGroup.y or 20)
                + textOffset * textDirection
        )
        updateAnchorPointMarker(
            alert.frame,
            textGroup.point
        )

        local appearance =
            self:GetTextAppearance(spellID)

        local fontSize =
            tonumber(
                appearance
                and appearance.font
                and appearance.font.size
            ) or 34

        local rowHeight =
            math.max(fontSize + 8, 24)

        textOffset =
            textOffset
            + rowHeight
            + (textGroup.spacing or 8)
    end

    for spellID, alert in pairs(self.textAlerts) do
        local settings =
            self:GetAbilitySettings(spellID)

        if settings
            and settings.text
            and settings.text.unattached
        then
            local position =
                self:GetTextPosition(spellID)

            alert.frame:ClearAllPoints()
            alert.frame:SetPoint(
                normalizeAnchorPoint(position.point),
                UIParent,
                "CENTER",
                position.x or 0,
                position.y or 120
            )
            updateAnchorPointMarker(
                alert.frame,
                position.point
            )
        end
    end
end

function AbilityAlerts:SaveBarPosition(
    spellID,
    position
)
    spellID = tonumber(spellID)

    if not spellID then
        return
    end

    self.db.barPositions =
        self.db.barPositions or {}

    self.db.barPositions[spellID] = {
        point =
            normalizeAnchorPoint(position and position.point),

        x =
            position and position.x
            or 0,

        y =
            position and position.y
            or 220
    }

    self:ApplyPositions()

    if self.positionChangedCallback then
        self.positionChangedCallback("bar", spellID)
    end
end

function AbilityAlerts:SaveTextPosition(
    spellID,
    position
)
    spellID = tonumber(spellID)

    if not spellID then
        return
    end

    self.db.textPositions =
        self.db.textPositions or {}

    self.db.textPositions[spellID] = {
        point =
            normalizeAnchorPoint(position and position.point),

        x =
            position and position.x
            or 0,

        y =
            position and position.y
            or 120
    }

    self:ApplyPositions()

    if self.positionChangedCallback then
        self.positionChangedCallback("text", spellID)
    end
end

function AbilityAlerts:EnsurePreviewFrames(spellID)
    local ability = self:GetAbility(spellID)

    if not ability then
        return
    end

    self:EnsureBar(spellID)
    self:EnsureTextAlert(spellID)
    self:ApplyPositions()
end

function AbilityAlerts:SetEditMode(enabled, bossKey)
    self.editMode = enabled and true or false

    if bossKey ~= nil then
        self.editModeBossKey = bossKey
    elseif not self.editMode then
        self.editModeBossKey = nil
    end

    local activeBossKey = self.editModeBossKey

    local function enableDragging(
        frame,
        spellID,
        saveFunction,
        getPositionFunction
    )
        frame:SetFrameStrata("MEDIUM")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")

        frame:SetScript(
            "OnDragStart",
            function(currentFrame)
                currentFrame:StartMoving()
            end
        )

        frame:SetScript(
            "OnDragStop",
            function(currentFrame)
                currentFrame:StopMovingOrSizing()

                local savedPosition =
                    getPositionFunction(self, spellID)
                local draggedPosition =
                    getCenterRelativePosition(
                        currentFrame,
                        savedPosition and savedPosition.point
                    )

                saveFunction(
                    self,
                    spellID,
                    draggedPosition
                )
            end
        )

        local position =
            getPositionFunction(self, spellID)
        updateAnchorPointMarker(
            frame,
            position and position.point,
            true
        )
    end

    local function disableDragging(frame)
        frame:SetFrameStrata("HIGH")
        frame:RegisterForDrag()
        frame:EnableMouse(false)
        frame:SetMovable(false)

        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
        updateAnchorPointMarker(frame, "CENTER", false)
    end

    ---------------------------------------------------------------------------
    -- Only create previews for enabled bars and text alerts
    ---------------------------------------------------------------------------
    for spellID in pairs(self.abilitiesBySpellID) do
        local settings =
            self:GetAbilitySettings(spellID)

        local ability = self:GetAbility(spellID)
        local belongsToBoss =
            not activeBossKey
            or (ability and ability.bossKey == activeBossKey)

        if belongsToBoss
            and settings
        then
            if settings.bar and settings.bar.enabled then
                self:EnsureBar(spellID)
            end

            if settings.text and settings.text.enabled then
                self:EnsureTextAlert(spellID)
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Bars
    ---------------------------------------------------------------------------
    for spellID, bar in pairs(self.bars) do
        local ability = self:GetAbility(spellID)
        local settings =
            self:GetAbilitySettings(spellID)

        local shouldShow =
            ability
            and (not activeBossKey or ability.bossKey == activeBossKey)
            and settings
            and settings.bar
            and settings.bar.enabled
            and settings.bar.unattached == true

        if self.editMode and shouldShow then
            bar:SetMode("label")
            bar:SetLabel(
                (ability and (ability.shortName or ability.name) or tostring(spellID))
                .. " bar — drag to move"
            )
            bar:SetRight("5.0")
            bar.frame:Show()

            enableDragging(
                bar.frame,
                spellID,
                self.SaveBarPosition,
                self.GetBarPosition
            )
        else
            disableDragging(bar.frame)

            if not bar:IsRunning() then
                bar:Hide()
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Text alerts
    ---------------------------------------------------------------------------
    for spellID, alert in pairs(self.textAlerts) do
        local ability = self:GetAbility(spellID)
        local settings =
            self:GetAbilitySettings(spellID)

        local shouldShow =
            ability
            and (not activeBossKey or ability.bossKey == activeBossKey)
            and settings
            and settings.text
            and settings.text.enabled
            and settings.text.unattached == true

        if self.editMode and shouldShow then
            alert:SetText(
                (ability and (ability.shortName or ability.name) or tostring(spellID))
                .. " text — drag to move"
            )

            alert.frame:Show()

            enableDragging(
                alert.frame,
                spellID,
                self.SaveTextPosition,
                self.GetTextPosition
            )
        else
            disableDragging(alert.frame)
            alert:Hide()
        end
    end

    self:ApplyPositions()
end

function AbilityAlerts:TestAbility(spellID)
    local ability = self:GetAbility(spellID)
    local settings = self:GetAbilitySettings(spellID)

    if not ability or not settings then
        return
    end

    local token = self:InvalidateAbility(spellID)
    local castTimeAdjustment = getCastTimeAdjustment(ability, settings)

    local simulatedBigWigsDuration = 0

    if settings.bar and settings.bar.enabled then
        local barStart =
            getSeconds(settings.bar.secondsBefore, 5)
            - getSeconds(settings.bar.delayBy, 0)
            - castTimeAdjustment

        simulatedBigWigsDuration =
            math.max(
                simulatedBigWigsDuration,
                barStart
            )
    end

    if settings.text and settings.text.enabled then
        local textStart =
            getSeconds(settings.text.secondsBefore, 7)
            - getSeconds(settings.text.delayBy, 0)
            - castTimeAdjustment

        simulatedBigWigsDuration =
            math.max(
                simulatedBigWigsDuration,
                textStart
            )
    end

    if settings.audio and settings.audio.enabled then
        local audioStart =
            getSeconds(settings.audio.secondsBefore, 3)
            - getSeconds(settings.audio.delayBy, 0)
            + getTTSCountdownMessageLead(settings.audio)
            - castTimeAdjustment

        simulatedBigWigsDuration =
            math.max(
                simulatedBigWigsDuration,
                audioStart
            )
    end

    simulatedBigWigsDuration =
        math.max(0, simulatedBigWigsDuration)

    if settings.bar and settings.bar.enabled then
        local secondsBefore =
            getSeconds(
                settings.bar.secondsBefore,
                5
            )

        local delayBy =
            getSeconds(
                settings.bar.delayBy,
                0
            )

        self:Schedule(
            spellID,
            simulatedBigWigsDuration
                + castTimeAdjustment
                - secondsBefore
                + delayBy,
            token,
            function()
                self:StartBar(
                    ability,
                    settings.bar
                )
            end
        )
    end

    if settings.text and settings.text.enabled then
        local secondsBefore =
            getSeconds(
                settings.text.secondsBefore,
                7
            )

        local delayBy =
            getSeconds(
                settings.text.delayBy,
                0
            )

        self:Schedule(
            spellID,
            simulatedBigWigsDuration
                + castTimeAdjustment
                - secondsBefore
                + delayBy,
            token,
            function()
                self:StartTextCountdown(
                    ability,
                    settings.text,
                    token
                )
            end
        )
    end

    if settings.audio and settings.audio.enabled then
        local secondsBefore =
            getSeconds(
                settings.audio.secondsBefore,
                3
            )

        local delayBy =
            getSeconds(
                settings.audio.delayBy,
                0
            )

        self:Schedule(
            spellID,
            simulatedBigWigsDuration
                + castTimeAdjustment
                - secondsBefore
                + delayBy
                - getTTSCountdownMessageLead(settings.audio),
            token,
            function()
                self:StartAudio(
                    ability,
                    settings.audio,
                    token
                )
            end
        )
    end

    self:SchedulePostHitStages(
        ability,
        settings,
        token,
        simulatedBigWigsDuration + castTimeAdjustment
    )
end

-------------------------------------------------------------------------------
-- Reset
-------------------------------------------------------------------------------

function AbilityAlerts:ResetAlerts()
    self.postHitLifecycleToken =
        self.postHitLifecycleToken + 1

    for spellID in pairs(self.abilitiesBySpellID) do
        self:InvalidateAbility(spellID)
    end

    for _, bar in pairs(self.bars) do
        if bar:IsRunning() then
            bar:Stop()
        end

        bar:Hide()
    end

    for _, alert in pairs(self.textAlerts) do
        alert:Hide()
    end

    if BossMods and BossMods.Alerts then
        BossMods.Alerts:StopTTS()
    end
end

function AbilityAlerts:ENCOUNTER_END()
    self:ResetAlerts()
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

function AbilityAlerts:OnInitialize()
    BossMods = E:GetModule("BossMods")

    self:BuildAbilityLookup()
end

function AbilityAlerts:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")

    self:BuildAbilityLookup()
    self:EnsureCustomBarDefaults()

    local spellKeySet = {}

    for spellID, ability in pairs(self.abilitiesBySpellID) do
        if not ability.triggerSpellID then
            spellKeySet[spellID] = true
        end
    end

    for triggerSpellID in pairs(self.triggeredAbilitiesBySpellID) do
        spellKeySet[triggerSpellID] = true
    end

    local spellKeys = {}

    for spellID in pairs(spellKeySet) do
        spellKeys[#spellKeys + 1] = spellID
    end

    self.bigWigsSubscription =
        BossMods.BigWigs:Subscribe({
            owner = MODULE_NAME,
            spellKeys = spellKeys,

            onStartBar = function(
                spellKey,
                text,
                duration
            )
                self:OnBigWigsStartBar(
                    spellKey,
                    text,
                    duration
                )
            end
        })

    self:RegisterEvent("ENCOUNTER_END")
end

function AbilityAlerts:OnDisable()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end

    self:UnregisterAllEvents()
    self:ResetAlerts()
end

function AbilityAlerts:Refresh()
for spellID, bar in pairs(self.bars) do
    local ability = self:GetAbility(spellID)

    local barAppearance =
        self:GetBarAppearance(spellID)

    bar:Apply(
        buildBarConfig(barAppearance, ability)
    )

end

    for spellID, alert in pairs(self.textAlerts) do
        local abilitySettings =
            self:GetAbilitySettings(spellID)

        local textAppearance =
            self:GetTextAppearance(spellID)

        alert:Apply(
            buildTextConfig(textAppearance)
        )
    end

    self:ApplyPositions()

    if self.editMode then
        self:SetEditMode(true, self.editModeBossKey)
    end
end

function AbilityAlerts:GetAbilityData()
    return E.VoidspireAbilityData or {}
end
