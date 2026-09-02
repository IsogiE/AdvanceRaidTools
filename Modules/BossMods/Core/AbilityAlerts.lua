local E, L = unpack(ART)

function E:RegisterAbilityAlertData(raidKey, moduleName, data, tabKey)
    assert(type(raidKey) == "string" and raidKey ~= "", "raidKey required")
    assert(type(moduleName) == "string" and moduleName ~= "", "moduleName required")

    for _, boss in ipairs(data or {}) do
        boss.raidKey = raidKey
        boss.featureKey = raidKey .. boss.bossKey

        E:RegisterBossModFeature(boss.featureKey, {
            tab = tabKey or raidKey,
            order = boss.bossOrder or 100,
            labelKey = boss.bossName or boss.bossKey,
            moduleName = moduleName
        })
    end
end

function E:CreateAbilityAlertsModule(config)
assert(type(config) == "table", "CreateAbilityAlertsModule: config required")
assert(
    type(config.moduleName) == "string" and config.moduleName ~= "",
    "CreateAbilityAlertsModule: moduleName required"
)

local MODULE_NAME = config.moduleName
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

local function markerColor(value, fallback)
    value = type(value) == "table" and value or {}
    fallback = fallback or {1, 1, 1, 1}

    return {
        tonumber(value[1] or value.r) or fallback[1] or 1,
        tonumber(value[2] or value.g) or fallback[2] or 1,
        tonumber(value[3] or value.b) or fallback[3] or 1,
        tonumber(value[4] or value.a) or fallback[4] or 1
    }
end

local DIFFICULTY_KEYS = {
    [14] = "normal",
    [15] = "heroic",
    [16] = "mythic"
}

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

    local key = config.difficultyKeyResolver
        and config.difficultyKeyResolver(ability, difficultyID)
        or DIFFICULTY_KEYS[difficultyID]

    return difficulties ~= nil
        and key ~= nil
        and difficulties[key] == true
end

-------------------------------------------------------------------------------
-- Default settings
-------------------------------------------------------------------------------

local defaults = config.defaults or {
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

    -- Ability settings are created from the registered ability data. Keeping
    -- a spell ID in the defaults would reintroduce a spell-keyed entry through
    -- AceDB even after the profile has migrated to stable ability keys.
    abilities = {}
}

for key, value in pairs(config.extraDefaults or {}) do
    defaults[key] = value
end

E:RegisterModuleDefaults(MODULE_NAME, defaults)

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

local AbilityAlerts = E:NewModule(MODULE_NAME, "AceEvent-3.0")

E:SetModuleParent(MODULE_NAME, "BossMods")

local BossMods

AbilityAlerts.abilitiesBySpellID = {}
AbilityAlerts.abilitiesBySettingsKey = {}
AbilityAlerts.triggeredAbilitiesBySpellID = {}
AbilityAlerts.alertTokens = {}
AbilityAlerts.postHitLifecycleToken = 0
AbilityAlerts.bars = {}
AbilityAlerts.textAlerts = {}
AbilityAlerts.managedBars = {}

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
    message = message:gsub(
        "{hit}",
        tostring(ability.hitNumber or "")
    )

    return message
end

local function getBarText(settings)
    local text = settings and settings.text

    if type(text) ~= "string" or text:match("^%s*$") then
        return "{spell}"
    end

    return text
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

-------------------------------------------------------------------------------
-- Ability data
-------------------------------------------------------------------------------

function AbilityAlerts:BuildAbilityLookup()
    wipe(self.abilitiesBySpellID)
    wipe(self.abilitiesBySettingsKey)
    wipe(self.triggeredAbilitiesBySpellID)

    for _, boss in ipairs(config.getAbilityData() or {}) do
        for _, ability in ipairs(boss.abilities or {}) do
            local spellID = tonumber(ability.spellID)

            if spellID then
                local fullName =
                    ability.name or tostring(spellID)

                local shortName =
                    ability.shortName
                    or fullName:gsub("%s*%b()%s*$", "")

                local triggerSpellIDs = {}
                local seenTriggerSpellIDs = {}

                if ability.triggerSpellID then
                    local triggerSpellID = tonumber(ability.triggerSpellID)

                    if triggerSpellID then
                        triggerSpellIDs[#triggerSpellIDs + 1] = triggerSpellID
                        seenTriggerSpellIDs[triggerSpellID] = true
                    end
                end

                for _, value in ipairs(ability.triggerSpellIDs or {}) do
                    local triggerSpellID = tonumber(value)

                    if triggerSpellID
                        and not seenTriggerSpellIDs[triggerSpellID]
                    then
                        triggerSpellIDs[#triggerSpellIDs + 1] = triggerSpellID
                        seenTriggerSpellIDs[triggerSpellID] = true
                    end
                end

                local featureKey = boss.featureKey
                    or (boss.raidKey or config.featurePrefix or "")
                        .. boss.bossKey
                -- The short name is the logical alert identity; display-only
                -- parentheticals and spell ID corrections must not reset it.
                -- Set settingsKey explicitly when one boss has two alerts with
                -- the same short name or when the logical name itself changes.
                local abilitySettingsKey = ability.settingsKey or shortName

                assert(
                    type(abilitySettingsKey) == "string"
                        and abilitySettingsKey ~= "",
                    "Ability settingsKey must be a non-empty string"
                )

                local settingsKey = featureKey .. "/" .. abilitySettingsKey

                assert(
                    not self.abilitiesBySettingsKey[settingsKey],
                    "Duplicate ability settings key: " .. settingsKey
                )

                local entry = {
                    spellID = spellID,
                    settingsKey = settingsKey,
                    name = fullName,
                    shortName = shortName,
                    barName = ability.barName,
                    order = ability.order or 100,
                    kind = ability.kind,
                    textOnly = ability.textOnly == true,
                    assignmentType = ability.assignmentType,
                    assignmentAudio = ability.assignmentAudio == true,
                    triggerSpellID = tonumber(ability.triggerSpellID),
                    triggerSpellIDs = triggerSpellIDs,
                    castTimeAdjustment = tonumber(
                        ability.castTimeAdjustment
                    ),
                    castWindowBar = ability.castWindowBar == true,
                    countdownTargetChoice =
                        ability.countdownTargetChoice == true,
                    embeddedMechanicDefaultEnabled =
                        ability.embeddedMechanicDefaultEnabled == true,
                    postHitStages = ability.postHitStages,
                    mechanic = ability.mechanic,
                    ignoreTriggerDuration = tonumber(
                        ability.ignoreTriggerDuration
                    ),
                    defaultBarColor = ability.defaultBarColor,
                    defaultBarEnabled = ability.defaultBarEnabled,
                    defaultTextEnabled = ability.defaultTextEnabled,
                    defaultTextUnattached = ability.defaultTextUnattached,
                    defaultTextSecondsBefore = tonumber(
                        ability.defaultTextSecondsBefore
                    ),
                    defaultTextPosition = ability.defaultTextPosition,
                    defaultTextPositionVersion = tonumber(
                        ability.defaultTextPositionVersion
                    ),
                    previousDefaultTextPosition =
                        ability.previousDefaultTextPosition,
                    defaultAudioSecondsBefore = tonumber(
                        ability.defaultAudioSecondsBefore
                    ),
                    defaultAudioTTSText = ability.defaultAudioTTSText,

                    bossKey = boss.bossKey,
                    bossName = boss.bossName,
                    bossOrder = boss.bossOrder or 100,
                    raidKey = boss.raidKey or config.featurePrefix,
                    featureKey = featureKey
                }

                self.abilitiesBySpellID[spellID] = entry
                self.abilitiesBySettingsKey[settingsKey] = entry

                for _, triggerSpellID in ipairs(entry.triggerSpellIDs) do
                    local triggered = self.triggeredAbilitiesBySpellID[triggerSpellID]
                    if not triggered then
                        triggered = {}
                        self.triggeredAbilitiesBySpellID[triggerSpellID] = triggered
                    end
                    triggered[#triggered + 1] = entry
                end
            end
        end
    end
end

local function storedValue(store, key)
    if type(store) ~= "table" then
        return nil
    end

    return rawget(store, key) or rawget(store, tostring(key))
end

local function moveStoredValue(store, oldKey, newKey)
    if type(store) ~= "table" then
        return
    end

    local value = storedValue(store, oldKey)

    if rawget(store, newKey) == nil and value ~= nil then
        store[newKey] = value
    end

    store[oldKey] = nil
    store[tostring(oldKey)] = nil
end

function AbilityAlerts:MigrateAbilitySettingsStorage()
    if not self.db or self.db.abilitySettingsStorageVersion == 1 then
        return
    end

    self.db.abilities = self.db.abilities or {}
    self.db.barPositions = self.db.barPositions or {}
    self.db.textPositions = self.db.textPositions or {}

    local stores = {
        self.db.abilities,
        self.db.barPositions,
        self.db.textPositions
    }

    -- Every current spell-keyed value can be moved without an alias. Spell IDs
    -- remain runtime trigger identifiers and are never used as storage keys
    -- after this migration.
    for spellID, ability in pairs(self.abilitiesBySpellID) do
        for _, store in ipairs(stores) do
            moveStoredValue(store, spellID, ability.settingsKey)
        end
    end

    local migration = config.abilitySettingsMigration or {}

    -- These aliases only read profiles created before stable ability keys.
    -- They are not registered as spell triggers, so they cannot cause alerts.
    for oldSpellID, currentSpellID in pairs(migration.aliases or {}) do
        local ability = self:GetAbility(currentSpellID)

        if ability then
            for _, store in ipairs(stores) do
                moveStoredValue(store, oldSpellID, ability.settingsKey)
            end
        end
    end

    -- Some old versions stored an embedded follow-up mechanic as a separate
    -- synthetic ability. Preserve only its enabled state in the owning ability.
    for oldSpellID, currentSpellID in pairs(migration.merged or {}) do
        local ability = self:GetAbility(currentSpellID)
        local oldSettings = storedValue(self.db.abilities, oldSpellID)

        if ability and oldSettings then
            local settings = self.db.abilities[ability.settingsKey]

            if not settings then
                settings = {}
                self.db.abilities[ability.settingsKey] = settings
            end

            if oldSettings.bar and oldSettings.bar.enabled == true then
                settings.bar = settings.bar or {}
                settings.bar.enabled = true
            end
        end

        for _, store in ipairs(stores) do
            store[oldSpellID] = nil
            store[tostring(oldSpellID)] = nil
        end
    end

    self.db.abilitySettingsStorageVersion = 1
end

function AbilityAlerts:EnsureCustomBarDefaults()
    if not self.db then
        return
    end

    self:MigrateAbilitySettingsStorage()
    self.db.abilities = self.db.abilities or {}
    local enableAllBarsMigration =
        config.enableAllBarsMigrationField ~= nil
        and self.db[config.enableAllBarsMigrationField] ~= 1
    local presetVersionField = config.presetVersionField
        or "abilityAlertBarPresetVersion"

    for _, ability in pairs(self.abilitiesBySpellID) do
        do
            local settings = self.db.abilities[ability.settingsKey]

            if not settings then
                settings = {}
                self.db.abilities[ability.settingsKey] = settings
            end

            settings.enabled = true
            settings.bar = settings.bar or {}
            settings.text = settings.text or {}

            if enableAllBarsMigration then
                settings.bar.enabled = true
            elseif config.defaultBarEnabledWhenUnset
                and settings.bar.enabled == nil
            then
                settings.bar.enabled = true
            end

            if settings[presetVersionField] ~= 1 then
                local presetColor = colorFromHex(ability.defaultBarColor)

                if presetColor then
                    settings.bar.fillColor = presetColor
                    settings.bar.individualFillColorInitialized = true
                end

                if ability.defaultBarEnabled ~= nil then
                    settings.bar.enabled = ability.defaultBarEnabled == true
                end

                if ability.defaultTextEnabled ~= nil then
                    settings.text.enabled = ability.defaultTextEnabled == true
                end

                if ability.defaultTextSecondsBefore ~= nil then
                    settings.text.secondsBefore = ability.defaultTextSecondsBefore
                end

                if ability.defaultTextUnattached ~= nil then
                    settings.text.unattached = ability.defaultTextUnattached == true
                end

                settings[presetVersionField] = 1
            elseif config.enableKindBarsWhenUnset
                and ability.kind
                and settings.bar.enabled == nil
            then
                settings.bar.enabled = true
            end

            if settings.bar.text == nil
                or settings.bar.text == "{spell}"
            then
                settings.bar.text = ""
            end
        end
    end

    if config.enableAllBarsMigrationField then
        self.db[config.enableAllBarsMigrationField] = 1
    end
end

function AbilityAlerts:GetAbility(spellID)
    return self.abilitiesBySpellID[tonumber(spellID)]
end

function AbilityAlerts:GetAbilitySettings(spellID)
    if not self.db then
        return nil
    end

    self:MigrateAbilitySettingsStorage()

    if not self.db.abilities then
        return nil
    end

    local ability = self:GetAbility(spellID)

    if not ability then
        return nil
    end

    local settings = self.db.abilities[ability.settingsKey]

    ensureDifficultySettings(settings)
    return settings
end

function AbilityAlerts:GetAbilityStorageKey(spellID)
    local ability = self:GetAbility(spellID)
    return ability and ability.settingsKey or nil
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

function AbilityAlerts:CreateCustomTriggerToken()
    return {
        customTrigger = true,
        lifecycle = self.postHitLifecycleToken
    }
end

function AbilityAlerts:IsTokenValid(spellID, token)
    if type(token) == "table" and token.customTrigger then
        return self.postHitLifecycleToken == token.lifecycle
    end

    return self:GetToken(spellID) == token
end

function AbilityAlerts:Schedule(spellID, delay, token, callback)
    delay = math.max(0, tonumber(delay) or 0)

    if delay == 0 then
        if self:IsTokenValid(spellID, token) then
            callback()
        end

        return
    end

    C_Timer.After(delay, function()
        if not self:IsEnabled() then
            return
        end

        if not self:IsTokenValid(spellID, token) then
            return
        end

        callback()
    end)
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

        middle = {
            font = font.name or "Friz Quadrata TT",
            size = tonumber(font.size) or 14,
            outline = font.outline or "OUTLINE",
            color = {1, 1, 1, 1},
            justify = "CENTER"
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

-- Encounter-specific bars can share the normal ability-bar renderer and group
-- without pretending to be a spell-triggered ability.
function AbilityAlerts:EnsureManagedBar(key, bossKey, order, overrides)
    assert(type(key) == "string" and key ~= "", "managed bar key required")

    local entry = self.managedBars[key]
    local appearance = self:GetBossDefaults(bossKey or "Unknown").bar
    local barConfig = buildBarConfig(appearance, nil)

    for option, value in pairs(overrides or {}) do
        barConfig[option] = value
    end

    if not entry then
        entry = {
            key = key,
            bar = BossMods.Engines.Bar(barConfig)
        }
        self.managedBars[key] = entry
    else
        entry.bar:Apply(barConfig)
    end

    entry.bossKey = bossKey
    entry.order = tonumber(order) or 100
    entry.height = tonumber(appearance and appearance.height) or 24
    entry.overrides = overrides

    return entry.bar
end

function AbilityAlerts:RefreshManagedBars()
    for key, entry in pairs(self.managedBars) do
        self:EnsureManagedBar(
            key,
            entry.bossKey,
            entry.order,
            entry.overrides
        )
    end
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

    bar.onFrame = function(elapsed, total)
        if bar.postHitStageActive then
            if bar.postHitStageCountDown then
                return math.max(0, total - elapsed) / total
            end

            return elapsed / total
        elseif bar.beamBarActive then
            if elapsed < 4 then
                return elapsed / 4
            end

            return math.max(0, 18 - elapsed) / 14
        end
    end

    bar.onTick = function(elapsed, total)
        local remaining = math.max(0, total - elapsed)

        bar:SetRight(("%.1f"):format(remaining))

        if bar.postHitStageActive and not bar.postHitStageCountDown then
            bar:SetRight(("%.1f"):format(math.min(total, elapsed)))
        end

        if bar.mightyThudActive then
            local nextAssignedHit

            for hit, hitTime in ipairs(bar.mightyThudHitTimes or {}) do
                if bar.mightyThudAssignedHits
                    and bar.mightyThudAssignedHits[hit]
                    and elapsed < hitTime
                then
                    nextAssignedHit = hitTime
                    break
                end
            end

            if nextAssignedHit then
                bar:SetRight(
                    ("%.1f"):format(
                        math.max(0, nextAssignedHit - elapsed)
                    )
                )
            else
                bar:SetRight("")
            end
        end

        if bar.mushroomTossJumpActive then
            if elapsed >= 3 and elapsed < 4 then
                bar:SetColor(0.10, 0.90, 0.20, 1)
            else
                bar:SetColor(0.90, 0.10, 0.10, 1)
            end
        end

        if bar.latestPickupActive then
            local markerTime = bar.latestPickupMarkerTime or 4
            local timeToMarker = math.max(0, markerTime - elapsed)

            if elapsed < markerTime then
                bar:SetRight(("%.1f"):format(timeToMarker))
                bar:SetColor(0.10, 0.90, 0.20, 1)
                bar:SetLabel(L["BossMods_AA_SafeToPickup"])
            else
                bar:SetRight("")
                bar:SetColor(0.90, 0.10, 0.10, 1)
                bar:SetLabel(L["BossMods_AA_NotSafeToPickup"])
            end
        end

        if bar.howlingMaelstromActive then
            local nextWind

            if elapsed < 5.5 then
                nextWind = 5.5
            elseif elapsed < 14.5 then
                nextWind = 14.5
            elseif elapsed < 23.5 then
                nextWind = 23.5
            else
                nextWind = 31.5
            end

            bar:SetRight(
                ("%.1f"):format(math.max(0, nextWind - elapsed))
            )
        end

        if bar.guillotineSequenceActive then
            local nextEvent = elapsed < 5 and 5 or 11

            bar:SetRight(
                ("%.1f"):format(math.max(0, nextEvent - elapsed))
            )
        end

        if bar.beamBarActive then
            if elapsed < 4 then
                bar:SetRight(("%.1f"):format(elapsed))
            else
                local beamRemaining = math.max(0, 18 - elapsed)

                bar:SetRight(("%.1f"):format(beamRemaining))
            end
        end
    end

    bar.onStop = function()
        for _, marker in ipairs(bar.mightyThudMarkers or {}) do
            marker:Hide()
        end

        bar.mightyThudActive = false
        bar.mightyThudHitTimes = nil

        if bar.mightyThudSoakText then
            bar.mightyThudSoakText:Hide()
        end

        for _, text in pairs(bar.mightyThudSoakTexts or {}) do
            text:Hide()
        end

        for _, marker in ipairs(bar.ravenousFeastMarkers or {}) do
            marker:Hide()
        end

        if bar.ravenousFeastSoakText then
            bar.ravenousFeastSoakText:Hide()
        end

        for _, text in pairs(bar.ravenousFeastSoakTexts or {}) do
            text:Hide()
        end

        if bar.mushroomTossJumpMarker then
            bar.mushroomTossJumpMarker:Hide()
        end

        if bar.latestPickupMarker then
            bar.latestPickupMarker:Hide()
        end

        for _, marker in ipairs(bar.howlingMaelstromMarkers or {}) do
            marker:Hide()
        end

        for _, label in ipairs(bar.howlingMaelstromLabels or {}) do
            label:Hide()
        end

        for _, marker in ipairs(bar.guillotineSequenceMarkers or {}) do
            marker:Hide()
        end

        for _, label in ipairs(bar.guillotineSequenceLabels or {}) do
            label:Hide()
        end

        for _, marker in ipairs(bar.timelineMarkers or {}) do
            marker:Hide()
        end

        for _, label in ipairs(bar.timelineMarkerLabels or {}) do
            label:Hide()
        end

        bar.mushroomTossJumpActive = false
        bar.latestPickupActive = false
        bar.howlingMaelstromActive = false
        bar.guillotineSequenceActive = false
        bar.beamBarActive = false
        bar.postHitStageActive = false
        bar.postHitStageCountDown = false
        bar.timelineMarkerData = nil
        bar:Hide()
        self:ApplyPositions()
    end

    self.bars[spellID] = bar

    return bar
end

function AbilityAlerts:StartBar(ability, settings, durationOverride, hitNumber)
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
    local barSpellName = ability.barName or ability.shortName or ability.name
    bar:SetLabel(
        replaceVariables(getBarText(settings), {
            name = barSpellName,
            shortName = barSpellName,
            hitNumber = hitNumber
        }, duration)
    )
    bar:SetRight(("%.1f"):format(duration))
    bar:SetMiddle(
        config.getAbilityAssignment
        and config.getAbilityAssignment(ability)
        or ""
    )

    bar:Start({
        total = duration
    })

    self:ApplyPositions()
end

function AbilityAlerts:PositionAssignedSoakTexts(
    bar,
    prefix,
    assignedXs,
    spellID,
    soakTextSize,
    soakTextOffsetY
)
    local frameKey = prefix .. "SoakTextFrame"
    local textsKey = prefix .. "SoakTexts"
    local oldTextKey = prefix .. "SoakText"

    if bar[oldTextKey] then
        bar[oldTextKey]:Hide()
    end

    bar[textsKey] = bar[textsKey] or {}

    for _, text in pairs(bar[textsKey]) do
        text:Hide()
    end

    if not next(assignedXs or {}) then
        return
    end

    if not bar[frameKey] then
        bar[frameKey] = CreateFrame("Frame", nil, bar.frame)
        bar[frameKey]:SetAllPoints(bar.frame)
        bar[frameKey]:SetFrameLevel(bar.frame:GetFrameLevel() + 10)
    end

    local appearance = self:GetBarAppearance(spellID)
    local font = appearance and appearance.font or {}
    local shared = BossMods and BossMods.Engines
        and BossMods.Engines.Shared
    local size = tonumber(soakTextSize) or 12
    for index, assignedX in pairs(assignedXs) do
        local text = bar[textsKey][index]

        if not text then
            text = bar[frameKey]:CreateFontString(nil, "OVERLAY", nil, 7)
            text:SetFontObject(GameFontNormal)
            text:SetTextColor(0.10, 0.90, 0.20, 1)
            text:SetJustifyH("CENTER")
            text:SetJustifyV("MIDDLE")
            bar[textsKey][index] = text
        end

        if shared and shared.ApplyFontIfChanged and shared.FetchFont then
            shared.ApplyFontIfChanged(
                text,
                shared.FetchFont(font.name or "Friz Quadrata TT"),
                size,
                font.outline or "OUTLINE"
            )
        end

        text:SetText(L["BossMods_AA_Soak"])
        text:SetSize(80, size + 8)
        text:ClearAllPoints()
        text:SetPoint(
            "CENTER",
            bar.frame,
            "LEFT",
            assignedX,
            tonumber(soakTextOffsetY) or 0
        )
        text:Show()
    end
end

function AbilityAlerts:PositionMightyThudMarkers(bar)
    local ratios = bar and bar.mightyThudMarkerRatios

    if not ratios then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0

    if width <= 0 or height <= 0 then
        return
    end

    local assignedHits = type(bar.mightyThudAssignedHits) == "table"
        and bar.mightyThudAssignedHits
        or {}
    local assignedXs = {}
    local color = markerColor(bar.mightyThudMarkerColor)
    local thickness = math.max(
        1,
        math.min(30, tonumber(bar.mightyThudMarkerThickness) or 5)
    )

    bar.mightyThudMarkers = bar.mightyThudMarkers or {}

    for index, ratio in ipairs(ratios) do
        local marker = bar.mightyThudMarkers[index]

        if not marker then
            marker = bar.frame:CreateTexture(nil, "OVERLAY")
            bar.mightyThudMarkers[index] = marker
        end

        local assigned = assignedHits[index] == true
        local x = math.max(
            1,
            math.min(width - 1, width * ratio)
        )

        marker:SetColorTexture(
            assigned and 0.10 or color[1],
            assigned and 0.90 or color[2],
            assigned and 0.20 or color[3],
            assigned and 1 or color[4]
        )
        marker:SetWidth(thickness)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", bar.frame, "LEFT", x, 0)
        marker:SetHeight(height)
        marker:Show()

        if assigned then
            assignedXs[index] = x
        end
    end

    self:PositionAssignedSoakTexts(
        bar,
        "mightyThud",
        assignedXs,
        bar.mightyThudSpellID,
        bar.mightyThudSoakTextSize,
        bar.mightyThudSoakTextOffsetY
    )
end

function AbilityAlerts:SetMightyThudMarkers(
    bar,
    hitTimes,
    totalDuration,
    assignedHits,
    spellID,
    soakTextSize,
    soakTextOffsetY,
    markerThickness,
    customMarkerColor
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.mightyThudMarkerRatios = {}
    bar.mightyThudAssignedHits = assignedHits
    bar.mightyThudHitTimes = hitTimes
    bar.mightyThudActive = type(assignedHits) == "table"
        and next(assignedHits) ~= nil
    bar.mightyThudSpellID = spellID
    bar.mightyThudSoakTextSize = soakTextSize
    bar.mightyThudSoakTextOffsetY = soakTextOffsetY
    bar.mightyThudMarkerThickness = markerThickness
    bar.mightyThudMarkerColor = markerColor(customMarkerColor)

    for index, hitTime in ipairs(hitTimes) do
        -- Ability bars count down, so elapsed times are converted to the
        -- remaining-time position where the fill reaches each hit.
        bar.mightyThudMarkerRatios[index] =
            math.max(0, totalDuration - hitTime) / totalDuration
    end

    self:PositionMightyThudMarkers(bar)
end

function AbilityAlerts:PositionRavenousFeastMarkers(bar)
    local ratios = bar and bar.ravenousFeastMarkerRatios

    if not ratios then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0

    if width <= 0 or height <= 0 then
        return
    end

    local assignedHits = type(bar.ravenousFeastAssignedHits) == "table"
        and bar.ravenousFeastAssignedHits
        or {}
    local assignedXs = {}
    local color = markerColor(bar.ravenousFeastMarkerColor)
    local thickness = math.max(
        1,
        math.min(30, tonumber(bar.ravenousFeastMarkerThickness) or 5)
    )

    bar.ravenousFeastMarkers = bar.ravenousFeastMarkers or {}

    for index, ratio in ipairs(ratios) do
        local marker = bar.ravenousFeastMarkers[index]

        if not marker then
            marker = bar.frame:CreateTexture(nil, "OVERLAY")
            bar.ravenousFeastMarkers[index] = marker
        end

        local assigned = assignedHits[index] == true
        local x = math.max(
            1,
            math.min(width - 1, width * ratio)
        )

        marker:SetColorTexture(
            assigned and 0.10 or color[1],
            assigned and 0.90 or color[2],
            assigned and 0.20 or color[3],
            assigned and 1 or color[4]
        )
        marker:SetWidth(thickness)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", bar.frame, "LEFT", x, 0)
        marker:SetHeight(height)
        marker:Show()

        if assigned then
            assignedXs[index] = x
        end
    end

    self:PositionAssignedSoakTexts(
        bar,
        "ravenousFeast",
        assignedXs,
        bar.ravenousFeastSpellID,
        bar.ravenousFeastSoakTextSize,
        bar.ravenousFeastSoakTextOffsetY
    )
end

function AbilityAlerts:SetRavenousFeastMarkers(
    bar,
    hitTimes,
    totalDuration,
    assignedHits,
    spellID,
    soakTextSize,
    soakTextOffsetY,
    markerThickness,
    customMarkerColor
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.ravenousFeastMarkerRatios = {}
    bar.ravenousFeastAssignedHits = assignedHits
    bar.ravenousFeastSpellID = spellID
    bar.ravenousFeastSoakTextSize = soakTextSize
    bar.ravenousFeastSoakTextOffsetY = soakTextOffsetY
    bar.ravenousFeastMarkerThickness = markerThickness
    bar.ravenousFeastMarkerColor = markerColor(customMarkerColor)

    for index, hitTime in ipairs(hitTimes) do
        bar.ravenousFeastMarkerRatios[index] =
            math.max(0, totalDuration - hitTime) / totalDuration
    end

    self:PositionRavenousFeastMarkers(bar)
end

function AbilityAlerts:PositionMushroomTossJumpMarker(bar)
    local markerData = bar and bar.mushroomTossJumpMarkerData

    if not markerData then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0
    local totalDuration = markerData.totalDuration or 0

    if width <= 0 or height <= 0 or totalDuration <= 0 then
        return
    end

    if not bar.mushroomTossJumpMarker then
        bar.mushroomTossJumpMarker =
            bar.frame:CreateTexture(nil, "ARTWORK", nil, 7)
    end

    local color = markerColor(
        bar.mushroomTossJumpMarkerColor,
        {0.10, 0.90, 0.20, 0.90}
    )
    bar.mushroomTossJumpMarker:SetColorTexture(
        color[1],
        color[2],
        color[3],
        color[4]
    )

    local windowStart = markerData.windowStart or 0
    local windowEnd = windowStart + (markerData.windowDuration or 0)
    local leftRatio = math.max(
        0,
        math.min(1, (totalDuration - windowEnd) / totalDuration)
    )
    local rightRatio = math.max(
        0,
        math.min(1, (totalDuration - windowStart) / totalDuration)
    )
    local left = width * leftRatio
    local markerWidth = math.max(1, width * (rightRatio - leftRatio))

    bar.mushroomTossJumpMarker:ClearAllPoints()
    bar.mushroomTossJumpMarker:SetPoint(
        "LEFT",
        bar.frame,
        "LEFT",
        left,
        0
    )
    bar.mushroomTossJumpMarker:SetSize(markerWidth, height)
    bar.mushroomTossJumpMarker:Show()
end

function AbilityAlerts:SetMushroomTossJumpMarker(
    bar,
    windowStart,
    windowDuration,
    totalDuration,
    customMarkerColor
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.mushroomTossJumpMarkerData = {
        windowStart = windowStart,
        windowDuration = windowDuration,
        totalDuration = totalDuration
    }
    bar.mushroomTossJumpMarkerColor = markerColor(
        customMarkerColor,
        {0.10, 0.90, 0.20, 0.90}
    )

    self:PositionMushroomTossJumpMarker(bar)
end

function AbilityAlerts:PositionHowlingMaelstromMarkers(bar)
    local windows = bar and bar.howlingMaelstromWindows
    local totalDuration = tonumber(bar and bar.howlingMaelstromDuration) or 0

    if not windows or totalDuration <= 0 then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0

    if width <= 0 or height <= 0 then
        return
    end

    local color = markerColor(
        bar.howlingMaelstromMarkerColor,
        {1, 1, 1, 0.35}
    )
    local appearance = self:GetBarAppearance(bar.howlingMaelstromSpellID)
    local font = appearance and appearance.font or {}
    local shared = BossMods and BossMods.Engines
        and BossMods.Engines.Shared

    bar.howlingMaelstromMarkers = bar.howlingMaelstromMarkers or {}
    bar.howlingMaelstromLabels = bar.howlingMaelstromLabels or {}

    for index, window in ipairs(windows) do
        local marker = bar.howlingMaelstromMarkers[index]

        if not marker then
            marker = bar.frame:CreateTexture(nil, "ARTWORK", nil, 7)
            bar.howlingMaelstromMarkers[index] = marker
        end

        local windowStart = tonumber(window.start) or 0
        local windowEnd = tonumber(window.finish) or windowStart
        local leftRatio = math.max(
            0,
            math.min(1, (totalDuration - windowEnd) / totalDuration)
        )
        local rightRatio = math.max(
            0,
            math.min(1, (totalDuration - windowStart) / totalDuration)
        )
        local left = width * leftRatio
        local markerWidth = math.max(1, width * (rightRatio - leftRatio))
        local center = left + markerWidth / 2

        marker:SetColorTexture(color[1], color[2], color[3], color[4])
        marker:ClearAllPoints()
        marker:SetPoint("LEFT", bar.frame, "LEFT", left, 0)
        marker:SetSize(markerWidth, height)
        marker:Show()

        local label = bar.howlingMaelstromLabels[index]

        if not label then
            label = bar.frame:CreateFontString(nil, "OVERLAY", nil, 7)
            label:SetJustifyH("CENTER")
            label:SetJustifyV("MIDDLE")
            bar.howlingMaelstromLabels[index] = label
        end

        if shared and shared.ApplyFontIfChanged and shared.FetchFont then
            shared.ApplyFontIfChanged(
                label,
                shared.FetchFont(font.name or "Friz Quadrata TT"),
                tonumber(font.size) or 14,
                font.outline or "OUTLINE"
            )
        end

        label:SetText(
            window.text or L["BossMods_AA_Wind"]:format(index)
        )
        label:SetTextColor(1, 1, 1, 1)
        label:SetSize(markerWidth, height)
        label:ClearAllPoints()
        label:SetPoint("CENTER", bar.frame, "LEFT", center, 0)
        label:Show()
    end
end

function AbilityAlerts:SetHowlingMaelstromMarkers(
    bar,
    windows,
    totalDuration,
    spellID,
    customMarkerColor
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.howlingMaelstromWindows = windows
    bar.howlingMaelstromDuration = totalDuration
    bar.howlingMaelstromSpellID = spellID
    bar.howlingMaelstromMarkerColor = markerColor(
        customMarkerColor,
        {1, 1, 1, 0.35}
    )

    self:PositionHowlingMaelstromMarkers(bar)
end

function AbilityAlerts:PositionGuillotineSequenceMarkers(bar)
    local markerTimes = bar and bar.guillotineSequenceMarkerTimes
    local totalDuration = tonumber(bar and bar.guillotineSequenceDuration) or 0

    if not markerTimes or totalDuration <= 0 then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0

    if width <= 0 or height <= 0 then
        return
    end

    local color = markerColor(bar.guillotineSequenceMarkerColor)
    local thickness = math.max(
        1,
        math.min(30, tonumber(bar.guillotineSequenceMarkerThickness) or 5)
    )
    local appearance = self:GetBarAppearance(bar.guillotineSequenceSpellID)
    local font = appearance and appearance.font or {}
    local shared = BossMods and BossMods.Engines
        and BossMods.Engines.Shared
    local labelWidth = math.max(50, math.min(100, width / 3))

    bar.guillotineSequenceMarkers = bar.guillotineSequenceMarkers or {}
    bar.guillotineSequenceLabels = bar.guillotineSequenceLabels or {}

    for index, markerData in ipairs(markerTimes) do
        local marker = bar.guillotineSequenceMarkers[index]

        if not marker then
            marker = bar.frame:CreateTexture(nil, "OVERLAY", nil, 7)
            bar.guillotineSequenceMarkers[index] = marker
        end

        local markerTime = math.max(
            0,
            math.min(totalDuration, tonumber(markerData.time) or 0)
        )
        local ratio = (totalDuration - markerTime) / totalDuration
        local x = math.max(1, math.min(width - 1, width * ratio))

        local currentColor = data.color
            and markerColor(data.color, color)
            or color
        local currentThickness = math.max(
            1,
            math.min(30, tonumber(data.thickness) or thickness)
        )

        marker:SetColorTexture(
            currentColor[1],
            currentColor[2],
            currentColor[3],
            currentColor[4]
        )
        marker:SetSize(currentThickness, height)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", bar.frame, "LEFT", x, 0)
        marker:Show()

        local label = bar.guillotineSequenceLabels[index]

        if not label then
            label = bar.frame:CreateFontString(nil, "OVERLAY", nil, 7)
            label:SetJustifyH("CENTER")
            label:SetJustifyV("MIDDLE")
            bar.guillotineSequenceLabels[index] = label
        end

        if shared and shared.ApplyFontIfChanged and shared.FetchFont then
            shared.ApplyFontIfChanged(
                label,
                shared.FetchFont(font.name or "Friz Quadrata TT"),
                tonumber(font.size) or 14,
                font.outline or "OUTLINE"
            )
        end

        label:SetText(markerData.text or "")
        label:SetTextColor(1, 1, 1, 1)
        label:SetSize(labelWidth, height)
        label:ClearAllPoints()
        label:SetPoint(
            "CENTER",
            bar.frame,
            "LEFT",
            x,
            tonumber(bar.guillotineSequenceTextOffsetY) or 0
        )
        label:Show()
    end
end

function AbilityAlerts:SetGuillotineSequenceMarkers(
    bar,
    markerTimes,
    totalDuration,
    spellID,
    markerThickness,
    customMarkerColor,
    textOffsetY
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.guillotineSequenceMarkerTimes = markerTimes
    bar.guillotineSequenceDuration = totalDuration
    bar.guillotineSequenceSpellID = spellID
    bar.guillotineSequenceMarkerThickness = markerThickness
    bar.guillotineSequenceMarkerColor = markerColor(customMarkerColor)
    bar.guillotineSequenceTextOffsetY = textOffsetY

    self:PositionGuillotineSequenceMarkers(bar)
end

function AbilityAlerts:PositionTimelineMarkers(bar)
    local markerData = bar and bar.timelineMarkerData
    local totalDuration = tonumber(bar and bar.timelineMarkerDuration) or 0

    if not markerData or totalDuration <= 0 then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0

    if width <= 0 or height <= 0 then
        return
    end

    local color = markerColor(bar.timelineMarkerColor)
    local thickness = math.max(
        1,
        math.min(30, tonumber(bar.timelineMarkerThickness) or 5)
    )
    local appearance = self:GetBarAppearance(bar.timelineMarkerSpellID)
    local font = appearance and appearance.font or {}
    local shared = BossMods and BossMods.Engines
        and BossMods.Engines.Shared

    bar.timelineMarkers = bar.timelineMarkers or {}
    bar.timelineMarkerLabels = bar.timelineMarkerLabels or {}

    for index, data in ipairs(markerData) do
        local marker = bar.timelineMarkers[index]

        if not marker then
            marker = bar.frame:CreateTexture(nil, "OVERLAY", nil, 7)
            bar.timelineMarkers[index] = marker
        end

        local markerTime = math.max(
            0,
            math.min(totalDuration, tonumber(data.time) or 0)
        )
        local ratio = (totalDuration - markerTime) / totalDuration
        local x = math.max(1, math.min(width - 1, width * ratio))

        marker:SetColorTexture(color[1], color[2], color[3], color[4])
        marker:SetSize(thickness, height)
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", bar.frame, "LEFT", x, 0)
        marker:Show()

        local label = bar.timelineMarkerLabels[index]

        if not label then
            label = bar.frame:CreateFontString(nil, "OVERLAY", nil, 7)
            label:SetJustifyH("CENTER")
            label:SetJustifyV("MIDDLE")
            bar.timelineMarkerLabels[index] = label
        end

        if shared and shared.ApplyFontIfChanged and shared.FetchFont then
            shared.ApplyFontIfChanged(
                label,
                shared.FetchFont(font.name or "Friz Quadrata TT"),
                tonumber(font.size) or 14,
                font.outline or "OUTLINE"
            )
        end

        label:SetText(data.text or "")
        label:SetTextColor(1, 1, 1, 1)
        label:SetSize(math.max(50, math.min(100, width / 3)), height)
        label:ClearAllPoints()
        label:SetPoint(
            "CENTER",
            bar.frame,
            "LEFT",
            x,
            tonumber(bar.timelineMarkerTextOffsetY) or 0
        )
        label:SetShown(data.text ~= nil and data.text ~= "")
    end

    for index = #markerData + 1, #bar.timelineMarkers do
        bar.timelineMarkers[index]:Hide()
    end

    for index = #markerData + 1, #bar.timelineMarkerLabels do
        bar.timelineMarkerLabels[index]:Hide()
    end
end

function AbilityAlerts:SetTimelineMarkers(
    bar,
    markerData,
    totalDuration,
    spellID,
    markerThickness,
    customMarkerColor,
    textOffsetY
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.timelineMarkerData = markerData
    bar.timelineMarkerDuration = totalDuration
    bar.timelineMarkerSpellID = spellID
    bar.timelineMarkerThickness = markerThickness
    bar.timelineMarkerColor = markerColor(customMarkerColor)
    bar.timelineMarkerTextOffsetY = textOffsetY

    self:PositionTimelineMarkers(bar)
end

function AbilityAlerts:PositionLatestPickupMarker(bar)
    local markerData = bar and bar.latestPickupMarkerData

    if not markerData then
        return
    end

    local width = bar.frame:GetWidth() or 0
    local height = bar.frame:GetHeight() or 0
    local totalDuration = tonumber(markerData.totalDuration) or 0

    if width <= 0 or height <= 0 or totalDuration <= 0 then
        return
    end

    if not bar.latestPickupMarker then
        bar.latestPickupMarker =
            bar.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    end


    local color = markerColor(bar.latestPickupMarkerColor)
    local thickness = math.max(
        1,
        math.min(30, tonumber(bar.latestPickupMarkerThickness) or 5)
    )
    bar.latestPickupMarker:SetColorTexture(
        color[1],
        color[2],
        color[3],
        color[4]
    )

    local markerTime = math.max(
        0,
        math.min(
            totalDuration,
            tonumber(markerData.markerTime) or 4
        )
    )
    local ratio = (totalDuration - markerTime) / totalDuration
    local x = math.max(1, math.min(width - 1, width * ratio))

    bar.latestPickupMarker:ClearAllPoints()
    bar.latestPickupMarker:SetPoint(
        "CENTER",
        bar.frame,
        "LEFT",
        x,
        0
    )
    bar.latestPickupMarker:SetSize(thickness, height)
    bar.latestPickupMarker:Show()
end

function AbilityAlerts:SetLatestPickupMarker(
    bar,
    markerTime,
    totalDuration,
    markerThickness,
    customMarkerColor
)
    if not bar or totalDuration <= 0 then
        return
    end

    bar.latestPickupMarkerData = {
        markerTime = markerTime,
        totalDuration = totalDuration
    }
    bar.latestPickupMarkerThickness = markerThickness
    bar.latestPickupMarkerColor = markerColor(customMarkerColor)

    self:PositionLatestPickupMarker(bar)
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
    if not self:IsTokenValid(ability.spellID, token) then
        return
    end

    local alert = self:EnsureTextAlert(ability.spellID)

    local timeText = settings.showOneDecimal ~= false
        and ("%.1f"):format(math.max(0, remaining or 0))
        or tostring(math.max(0, math.ceil(remaining or 0)))

    local message = replaceVariables(
        settings.message,
        ability,
        remaining,
        timeText
    )
    local assignment = config.getAbilityAssignment
        and config.getAbilityAssignment(ability)

    if assignment then
        message = message .. "\n" .. assignment
    end

    alert:SetText(message)

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
                or not self:IsTokenValid(ability.spellID, token)
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

function AbilityAlerts:StartAssignmentTextAlert(
    ability,
    duration,
    testMode,
    bigWigsText,
    triggerSpellID
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or (not testMode and not isDifficultyEnabled(settings, ability))
    then
        return
    end

    local textEnabled = settings.text and settings.text.enabled == true
    local audioEnabled = ability.assignmentAudio
        and settings.audio
        and settings.audio.enabled == true

    if not textEnabled and not audioEnabled then
        return
    end

    local state = config.getAssignmentTextState
        and config.getAssignmentTextState(
            self,
            ability,
            testMode,
            bigWigsText,
            triggerSpellID
        )

    if not state or type(state.message) ~= "string" then
        return
    end

    local seconds = textEnabled
        and getSeconds(settings.text.secondsBefore, 5)
        or 0

    local token = ability.assignmentType == "guillotine"
        and self:CreateCustomTriggerToken()
        or self:InvalidateAbility(ability.spellID)

    if audioEnabled then
        local audioSecond = math.max(
            0,
            math.min(7, math.floor(
                getSeconds(settings.audio.secondsBefore, 3)
            ))
        )
        local audioDelay = math.max(
            0,
            getSeconds(duration, testMode and 5 or 0) - audioSecond
        )

        self:Schedule(
            ability.spellID,
            audioDelay,
            token,
            function()
                self:PlayAudio(ability, settings.audio, audioSecond)
            end
        )
    end

    if seconds <= 0 then
        return
    end

    local delayBy = getSeconds(settings.text.delayBy, 0)
    local startDelay = testMode and 0
        or math.max(0, getSeconds(duration, 0) - seconds + delayBy)

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            local alert = self:EnsureTextAlert(ability.spellID)
            local startedAt = GetTime()
            local interval = settings.text.showOneDecimal ~= false and 0.1 or 1
            local ticker

            local function updateText()
                if not self:IsEnabled()
                    or not self:IsTokenValid(ability.spellID, token)
                then
                    if ticker then
                        ticker:Cancel()
                    end
                    return
                end

                local remaining = seconds - (GetTime() - startedAt)

                if remaining <= 0 then
                    alert:Hide()
                    self:ApplyPositions()

                    if ticker then
                        ticker:Cancel()
                    end
                    return
                end

                local timeText = settings.text.showOneDecimal ~= false
                    and ("%.1f"):format(remaining)
                    or tostring(math.ceil(remaining))

                alert:SetText(state.message .. " " .. timeText)
                alert:Show()
                self:ApplyPositions()

                local fontString = alert:GetTextFontString()
                local color = state.color or {1, 1, 1, 1}
                fontString:SetTextColor(
                    color[1] or color.r or 1,
                    color[2] or color.g or 1,
                    color[3] or color.b or 1,
                    color[4] or color.a or 1
                )
            end

            updateText()
            ticker = C_Timer.NewTicker(interval, updateText)
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

function AbilityAlerts:IsAbilityFeatureEnabled(ability)
    if BossMods and BossMods.IsFeatureEnabled then
        if not BossMods:IsFeatureEnabled(ability.featureKey) then
            return false
        end

        local legacyFeatureKey = config.legacyFeatureKeys
            and config.legacyFeatureKeys[ability.featureKey]
        local featureSettings = BossMods.db
            and BossMods.db.featureEnabled

        -- Moved bosses keep honoring an explicitly disabled legacy feature
        -- until the user changes the toggle under its corrected raid tab.
        if legacyFeatureKey
            and featureSettings
            and featureSettings[ability.featureKey] == nil
            and featureSettings[legacyFeatureKey] == false
        then
            return false
        end
    end

    return true
end

function AbilityAlerts:ResetEncounterTracking()
    if config.resetEncounterTracking then
        config.resetEncounterTracking(self)
    end
end

function AbilityAlerts:ShouldSuppressCast(spellID)
    return config.shouldSuppressCast
        and config.shouldSuppressCast(self, spellID) == true
        or false
end

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
            or not self:IsTokenValid(ability.spellID, token)
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

        alert:SetText(
            tostring(displayText)
            .. " "
            .. countdownText
        )
        alert:Show()
        self:ApplyPositions()
    end

    updateText()
    ticker = C_Timer.NewTicker(interval, updateText)
end

function AbilityAlerts:SchedulePostHitStages(
    ability,
    settings,
    token,
    hitDelay
)
    local postHitStages = ability and ability.postHitStages

    if not postHitStages then
        return
    end

    local barEnabled = settings.bar and settings.bar.enabled
    local textEnabled = settings.text and settings.text.enabled

    if not barEnabled and not textEnabled then
        return
    end

    -- Follow-up bars belong to the completed cast. A new BigWigs timer for
    -- the next cast must not invalidate them; encounter/stage resets still do.
    token = self:CreateCustomTriggerToken()

    local elapsed = 0

    for _, stage in ipairs(postHitStages.stages or {}) do
        local stageDuration = getSeconds(stage.duration, 0)

        if stageDuration > 0 then
            local stageDelay = getSeconds(hitDelay, 0) + elapsed
            local stageText = stage.text
            local stageBarText = stage.barText or stageText

            if barEnabled then
                self:Schedule(
                    ability.spellID,
                    stageDelay,
                    token,
                    function()
                        self:StartBar(ability, settings.bar, stageDuration)

                        local bar = self:EnsureBar(ability.spellID)
                        bar.postHitStageActive = true
                        bar.postHitStageCountDown =
                            postHitStages.countDown == true
                        bar:SetValue(bar.postHitStageCountDown and 1 or 0)
                        bar:SetRight(
                            ("%.1f"):format(
                                bar.postHitStageCountDown and stageDuration or 0
                            )
                        )
                        bar:SetLabel(
                            stageBarText or ability.shortName or ability.name
                        )

                        local stageMarkers = stage.markers

                        if stageMarkers and config.getPostHitStageMarkers then
                            stageMarkers = config.getPostHitStageMarkers(
                                self,
                                ability,
                                stage,
                                stageMarkers
                            ) or stageMarkers
                        end

                        if stageMarkers then
                            local markerSettings =
                                settings.timelineMarkers or {}

                            self:SetTimelineMarkers(
                                bar,
                                stageMarkers,
                                stageDuration,
                                ability.spellID,
                                tonumber(markerSettings.markerThickness) or 5,
                                markerSettings.markerColor,
                                tonumber(markerSettings.textOffsetY) or 0
                            )
                        end
                    end
                )
            end

            if textEnabled and stage.showText ~= false then
                local displayText =
                    stageText or ability.shortName or ability.name
                local firstUpdateDelay = stageDelay + 0.05

                self:Schedule(
                    ability.spellID,
                    firstUpdateDelay,
                    token,
                    function()
                        self:StartPostHitStageTextCountdown(
                            ability,
                            settings.text,
                            token,
                            displayText,
                            math.max(0, stageDuration - 0.05)
                        )
                    end
                )
            end

            elapsed = elapsed + stageDuration
        end
    end
end

function AbilityAlerts:HandleStandardAbility(ability, duration)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local spellID = ability.spellID
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
        local secondsBefore = getSeconds(settings.bar.secondsBefore, 5)
        local delayBy = getSeconds(settings.bar.delayBy, 0)

        if ability.castWindowBar and castTimeAdjustment > 0 then
            self:Schedule(
                spellID,
                duration - secondsBefore + delayBy,
                token,
                function()
                    local totalDuration = secondsBefore
                        + castTimeAdjustment

                    self:StartBar(
                        ability,
                        settings.bar,
                        totalDuration
                    )

                    local bar = self:EnsureBar(spellID)
                    local markerSettings = settings.castWindow or {}

                    self:SetTimelineMarkers(
                        bar,
                        {
                            {
                                time = secondsBefore,
                                text = L["BossMods_AA_Cast"]
                            },
                        },
                        totalDuration,
                        spellID,
                        tonumber(markerSettings.markerThickness) or 5,
                        markerSettings.markerColor,
                        tonumber(markerSettings.textOffsetY) or 0
                    )
                end
            )
        else
            self:Schedule(
                spellID,
                adjustedDuration - secondsBefore + delayBy,
                token,
                function()
                    self:StartBar(ability, settings.bar)
                end
            )
        end
    end

    if settings.text and settings.text.enabled then
        local secondsBefore = getSeconds(settings.text.secondsBefore, 7)
        local delayBy = getSeconds(settings.text.delayBy, 0)

        self:Schedule(
            spellID,
            adjustedDuration - secondsBefore + delayBy,
            token,
            function()
                self:StartTextCountdown(ability, settings.text, token)
            end
        )
    end

    if settings.audio and settings.audio.enabled then
        local secondsBefore = getSeconds(settings.audio.secondsBefore, 3)
        local delayBy = getSeconds(settings.audio.delayBy, 0)

        self:Schedule(
            spellID,
            adjustedDuration - secondsBefore + delayBy
                - getTTSCountdownMessageLead(settings.audio),
            token,
            function()
                self:StartAudio(ability, settings.audio, token)
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

function AbilityAlerts:StartMightyThudHitBar(ability, duration, testMode)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or not settings.bar or not settings.bar.enabled
    then
        return
    end

    local sequence = settings.sequence or {}
    local mightyThudSettings = settings.mightyThud or {}
    local castTime = getSeconds(sequence.castTime, 10)
    local firstHitDelay = getSeconds(sequence.firstHitDelay, 0.4)
    local hitInterval = getSeconds(sequence.hitInterval, 2)
    local firstHit = castTime + firstHitDelay
    local secondHit = firstHit + hitInterval
    local thirdHit = secondHit + hitInterval
    local totalDuration = thirdHit
    local startDelay = testMode and 0 or duration
    local token = self:CreateCustomTriggerToken()

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(
                ability,
                settings.bar,
                totalDuration
            )

            local bar = self:EnsureBar(ability.spellID)

            self:SetMightyThudMarkers(
                bar,
                { firstHit, secondHit, thirdHit },
                totalDuration,
                config.getAssignedHits
                    and config.getAssignedHits("mightyThud")
                    or (testMode and {[1] = true} or nil),
                ability.spellID,
                tonumber(mightyThudSettings.soakTextSize) or 12,
                tonumber(mightyThudSettings.soakTextOffsetY) or 0,
                tonumber(mightyThudSettings.markerThickness) or 5,
                mightyThudSettings.markerColor
            )
        end
    )
end

function AbilityAlerts:StartRavenousFeastHitBar(
    ability,
    duration,
    testMode
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or not settings.bar or not settings.bar.enabled
    then
        return
    end

    local totalDuration = 8
    local firstHit = 4.5
    local secondHit = 6.5
    local thirdHit = 8
    local startDelay = testMode and 0 or duration
    local feastSettings = settings.ravenousFeast or {}
    local token = self:CreateCustomTriggerToken()

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(
                ability,
                settings.bar,
                totalDuration
            )

            local bar = self:EnsureBar(ability.spellID)

            self:SetRavenousFeastMarkers(
                bar,
                { firstHit, secondHit, thirdHit },
                totalDuration,
                config.getAssignedHits
                    and config.getAssignedHits("ravenousFeast")
                    or (testMode and {[1] = true} or nil),
                ability.spellID,
                tonumber(feastSettings.soakTextSize) or 12,
                tonumber(feastSettings.soakTextOffsetY) or 0,
                tonumber(feastSettings.markerThickness) or 5,
                feastSettings.markerColor
            )
        end
    )
end

function AbilityAlerts:StartLatestPickupBar(
    ability,
    duration,
    testMode
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings then
        return
    end

    local barEnabled = settings.bar and settings.bar.enabled
    local audioEnabled = settings.audio and settings.audio.enabled

    if not barEnabled and not audioEnabled then
        return
    end

    local totalDuration = 6
    local latestPickupSettings = settings.latestPickup or {}
    local markerOffset = tonumber(latestPickupSettings.markerOffset) or 0
    markerOffset = math.max(-0.9, math.min(0.9, markerOffset))

    local markerTime = 4 + markerOffset
    local startDelay = testMode and 0 or math.max(0, duration - 7)
    local token = self:CreateCustomTriggerToken()

    if barEnabled then
        self:Schedule(
            ability.spellID,
            startDelay,
            token,
            function()
                self:StartBar(
                    ability,
                    settings.bar,
                    totalDuration
                )

                local bar = self:EnsureBar(ability.spellID)

                bar.latestPickupActive = true
                bar.latestPickupMarkerTime = markerTime
                bar:SetRight(("%.1f"):format(markerTime))
                bar:SetLabel(L["BossMods_AA_SafeToPickup"])
                bar:SetColor(0.10, 0.90, 0.20, 1)

                self:SetLatestPickupMarker(
                    bar,
                    markerTime,
                    totalDuration,
                    tonumber(latestPickupSettings.markerThickness) or 5,
                    latestPickupSettings.markerColor
                )
            end
        )
    end

    if audioEnabled then
        local audioSettings = settings.audio
        local secondsBefore =
            getSeconds(audioSettings.secondsBefore, 0)
        local delayBy = getSeconds(audioSettings.delayBy, 0)
        local cueDelay = math.max(
            0,
            startDelay + markerTime - secondsBefore + delayBy
                - getTTSCountdownMessageLead(audioSettings)
        )

        self:Schedule(
            ability.spellID,
            cueDelay,
            token,
            function()
                if audioSettings.countdown and secondsBefore > 0 then
                    self:StartAudio(ability, audioSettings, token)
                else
                    self:PlayAudio(
                        ability,
                        audioSettings,
                        secondsBefore
                    )
                end
            end
        )
    end
end

function AbilityAlerts:PlayMushroomTossCue(settings, text)
    local mushroomSettings = settings.mushroomToss or {}

    if not mushroomSettings.ttsEnabled then
        return
    end

    BossMods.Alerts:StopTTS()
    BossMods.Alerts:SpeakTTS({
        text = text,
        voiceID = tonumber(mushroomSettings.voiceID) or 0
    })
end

function AbilityAlerts:StartMushroomTossJumpBar(ability, duration, testMode)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or not settings.bar or not settings.bar.enabled
    then
        return
    end

    local baitDuration = 7
    local gapDuration = testMode and 0 or 20
    local jumpDuration = 5
    local jumpWindowStart = 3
    local mushroomSettings = settings.mushroomToss or {}
    local markerThickness = math.max(
        0.1,
        math.min(3, tonumber(mushroomSettings.markerThickness) or 1)
    )
    local markerCenter = jumpWindowStart + 0.5
    local baitEnabled = mushroomSettings.baitEnabled ~= false
    local jumpEnabled = mushroomSettings.jumpEnabled ~= false
    local startDelay = testMode and 0 or duration
    local jumpStart

    if testMode then
        jumpStart = baitEnabled and baitDuration or 0
    else
        jumpStart = startDelay + baitDuration + gapDuration
    end

    local token = self:CreateCustomTriggerToken()

    if baitEnabled then
        self:Schedule(
            ability.spellID,
            startDelay,
            token,
            function()
                local bar = self:EnsureBar(ability.spellID)

                bar.mushroomTossJumpActive = false

                if bar.mushroomTossJumpMarker then
                    bar.mushroomTossJumpMarker:Hide()
                end

                bar:Apply(
                    buildBarConfig(
                        self:GetBarAppearance(ability.spellID),
                        ability
                    )
                )

                self:StartBar(
                    ability,
                    settings.bar,
                    baitDuration
                )

                bar:SetLabel(L["BossMods_AA_Bait"])
                self:PlayMushroomTossCue(
                    settings,
                    L["BossMods_AA_Bait"]
                )
            end
        )
    end

    if jumpEnabled then
        self:Schedule(
            ability.spellID,
            jumpStart,
            token,
            function()
                local bar = self:EnsureBar(ability.spellID)

                bar:Apply(
                    buildBarConfig(
                        self:GetBarAppearance(ability.spellID),
                        ability
                    )
                )

                self:StartBar(
                    ability,
                    settings.bar,
                    jumpDuration
                )

                bar.mushroomTossJumpActive = true
                bar:SetLabel(L["BossMods_AA_Jump"])
                bar:SetColor(0.90, 0.10, 0.10, 1)

                self:SetMushroomTossJumpMarker(
                    bar,
                    markerCenter - markerThickness / 2,
                    markerThickness,
                    jumpDuration,
                    mushroomSettings.markerColor
                )
            end
        )

        self:Schedule(
            ability.spellID,
            jumpStart + jumpWindowStart,
            token,
            function()
                self:PlayMushroomTossCue(
                    settings,
                    L["BossMods_AA_Jump"]
                )
            end
        )
    end
end

function AbilityAlerts:StartHowlingMaelstromWindBar(
    ability,
    duration,
    testMode
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or not settings.bar or not settings.bar.enabled
    then
        return
    end

    local totalDuration = 31.5
    local startDelay = testMode and 0 or math.max(0, duration - 4)
    local windSettings = settings.howlingMaelstrom or {}
    local token = self:CreateCustomTriggerToken()

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(ability, settings.bar, totalDuration)

            local bar = self:EnsureBar(ability.spellID)

            bar.howlingMaelstromActive = true
            bar:SetLabel("")
            bar:SetRight("5.5")

            self:SetHowlingMaelstromMarkers(
                bar,
                {
                    {
                        start = 5.5,
                        finish = 13.5,
                        text = L["BossMods_AA_Wind"]:format(1)
                    },
                    {
                        start = 14.5,
                        finish = 22.5,
                        text = L["BossMods_AA_Wind"]:format(2)
                    },
                    {
                        start = 23.5,
                        finish = 31.5,
                        text = L["BossMods_AA_Wind"]:format(3)
                    }
                },
                totalDuration,
                ability.spellID,
                windSettings.markerColor
            )
        end
    )
end

function AbilityAlerts:StartGuillotineSequenceBar(
    ability,
    duration,
    testMode
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or not settings.bar or not settings.bar.enabled
    then
        return
    end

    local totalDuration = 12
    local startDelay = testMode and 0 or duration
    local markerSettings = settings.guillotineSequence or {}
    local token = self:CreateCustomTriggerToken()

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(ability, settings.bar, totalDuration)

            local bar = self:EnsureBar(ability.spellID)

            bar.guillotineSequenceActive = true
            bar:SetLabel("")
            bar:SetRight("5.0")

            self:SetGuillotineSequenceMarkers(
                bar,
                {
                    { time = 5, text = L["BossMods_AA_Hit"] },
                    { time = 12, text = L["BossMods_AA_Explode"] }
                },
                totalDuration,
                ability.spellID,
                tonumber(markerSettings.markerThickness) or 5,
                markerSettings.markerColor,
                tonumber(markerSettings.textOffsetY) or 0
            )
        end
    )
end

function AbilityAlerts:StartBeamBar(ability, duration, testMode)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings
        or not settings.bar or not settings.bar.enabled
    then
        return
    end

    local ignoredDuration = tonumber(ability.ignoreTriggerDuration)
    local triggerDuration = tonumber(duration)

    if not testMode
        and ignoredDuration
        and triggerDuration
        and math.abs(triggerDuration - ignoredDuration) < 0.05
    then
        return
    end

    local totalDuration = 18
    local startDelay = testMode and 0 or duration
    local token = self:CreateCustomTriggerToken()

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(ability, settings.bar, totalDuration)

            local bar = self:EnsureBar(ability.spellID)

            bar.beamBarActive = true
            bar:SetLabel(L["BossMods_AA_Beam"])
            bar:SetRight("0.0")
            bar:SetValue(0)
        end
    )
end

function AbilityAlerts:ScheduleMechanicTextAndAudio(
    ability,
    settings,
    token,
    eventDelay
)
    eventDelay = getSeconds(eventDelay, 0)

    if settings.text and settings.text.enabled then
        local secondsBefore = getSeconds(settings.text.secondsBefore, 7)
        local delayBy = getSeconds(settings.text.delayBy, 0)

        self:Schedule(
            ability.spellID,
            eventDelay - secondsBefore + delayBy,
            token,
            function()
                self:StartTextCountdown(ability, settings.text, token)
            end
        )
    end

    if settings.audio and settings.audio.enabled then
        local secondsBefore = getSeconds(settings.audio.secondsBefore, 3)
        local delayBy = getSeconds(settings.audio.delayBy, 0)

        self:Schedule(
            ability.spellID,
            eventDelay - secondsBefore + delayBy
                - getTTSCountdownMessageLead(settings.audio),
            token,
            function()
                self:StartAudio(ability, settings.audio, token)
            end
        )
    end
end

function AbilityAlerts:StartFollowupBar(ability, duration, testMode)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings then
        return
    end

    local mechanic = ability.mechanic or {}
    local barDuration = getSeconds(mechanic.duration, 0)

    if barDuration <= 0 then
        return
    end

    local startDelay = testMode and 0
        or duration + getSeconds(mechanic.startOffset, 0)
    local token = self:CreateCustomTriggerToken()

    self:ScheduleMechanicTextAndAudio(
        ability,
        settings,
        token,
        startDelay + barDuration
    )

    if not settings.bar or not settings.bar.enabled then
        return
    end

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(ability, settings.bar, barDuration)
            local bar = self:EnsureBar(ability.spellID)
            bar:SetLabel(replaceVariables(
                getBarText(settings.bar),
                ability,
                barDuration
            ))
        end
    )
end

function AbilityAlerts:StartStagedFollowupBars(
    ability,
    duration,
    testMode
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings then
        return
    end

    local mechanic = ability.mechanic or {}
    local startDelay = testMode and 0
        or duration + getSeconds(mechanic.startOffset, 0)
    local token = self:CreateCustomTriggerToken()
    local elapsed = 0

    for _, stage in ipairs(mechanic.stages or {}) do
        local stageDuration = getSeconds(stage.duration, 0)

        if stageDuration > 0 then
            local stageDelay = startDelay + elapsed

            if settings.bar and settings.bar.enabled then
                self:Schedule(
                    ability.spellID,
                    stageDelay,
                    token,
                    function()
                        self:StartBar(ability, settings.bar, stageDuration)
                        local bar = self:EnsureBar(ability.spellID)
                        bar:SetLabel(
                            stage.text or ability.shortName or ability.name
                        )
                    end
                )
            end

            elapsed = elapsed + stageDuration
        end
    end


    self:ScheduleMechanicTextAndAudio(
        ability,
        settings,
        token,
        startDelay + elapsed
    )
end

function AbilityAlerts:StartMarkerSequenceBar(
    ability,
    duration,
    testMode
)
    if not self:IsAbilityFeatureEnabled(ability) then
        return
    end

    local settings = self:GetAbilitySettings(ability.spellID)

    if not settings then
        return
    end

    local mechanic = ability.mechanic or {}
    local barDuration = getSeconds(mechanic.duration, 0)

    if barDuration <= 0 then
        return
    end

    local startDelay = testMode and 0
        or duration + getSeconds(mechanic.startOffset, 0)
    local token = self:CreateCustomTriggerToken()
    local markerSettings = settings.timelineMarkers or {}

    self:ScheduleMechanicTextAndAudio(
        ability,
        settings,
        token,
        startDelay + barDuration
    )

    if not settings.bar or not settings.bar.enabled then
        return
    end

    self:Schedule(
        ability.spellID,
        startDelay,
        token,
        function()
            self:StartBar(ability, settings.bar, barDuration)

            local bar = self:EnsureBar(ability.spellID)
            bar:SetLabel(replaceVariables(
                getBarText(settings.bar),
                ability,
                barDuration
            ))

            self:SetTimelineMarkers(
                bar,
                mechanic.markers or {},
                barDuration,
                ability.spellID,
                tonumber(markerSettings.markerThickness) or 5,
                markerSettings.markerColor,
                tonumber(markerSettings.textOffsetY) or 0
            )
        end
    )
end

function AbilityAlerts:OnBigWigsStartBar(spellKey, bigWigsText, duration)
    local spellID = tonumber(spellKey)

    duration = tonumber(duration)

    if not duration or duration <= 0 then
        return
    end

    local ability = self:GetAbility(spellID)

    if config.resolveAbility then
        ability, spellID = config.resolveAbility(
            self,
            ability,
            spellID,
            duration,
            bigWigsText
        )
    end
    local suppressCast = self:ShouldSuppressCast(spellID)
    local ignoredDuration = ability
        and tonumber(ability.ignoreTriggerDuration)

    if ignoredDuration
        and math.abs(duration - ignoredDuration) < 0.05
    then
        suppressCast = true
    end

    if ability then
        if not suppressCast then
            self:HandleStandardAbility(ability, duration)
        end
    end

    if suppressCast then
        return
    end

    if config.onBigWigsStartBar then
        config.onBigWigsStartBar(
            self,
            spellID,
            bigWigsText,
            duration,
            ability,
            spellKey
        )
    end

    for _, triggeredAbility in ipairs(
        self.triggeredAbilitiesBySpellID[spellID] or {}
    ) do
        local settings = self:GetAbilitySettings(triggeredAbility.spellID)
        local difficultyEnabled = isDifficultyEnabled(
            settings,
            triggeredAbility
        )

        if difficultyEnabled
            and triggeredAbility.kind == "mightyThudHits"
        then
            self:StartMightyThudHitBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "ravenousFeastHits"
        then
            self:StartRavenousFeastHitBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "mushroomTossJump"
        then
            self:StartMushroomTossJumpBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "latestPickup"
        then
            self:StartLatestPickupBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "howlingMaelstromWinds"
        then
            self:StartHowlingMaelstromWindBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "guillotineSequence"
        then
            self:StartGuillotineSequenceBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "beamBar"
        then
            self:StartBeamBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "followupBar"
        then
            self:StartFollowupBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "stagedFollowupBars"
        then
            self:StartStagedFollowupBars(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "markerSequence"
        then
            self:StartMarkerSequenceBar(
                triggeredAbility,
                duration,
                false
            )
        elseif difficultyEnabled
            and triggeredAbility.kind == "assignmentText"
        then
            self:StartAssignmentTextAlert(
                triggeredAbility,
                duration,
                false,
                bigWigsText,
                spellID
            )
        end
    end
end

function AbilityAlerts:OnBigWigsStage(module, stage)
    -- A new BigWigs stage invalidates timers from the previous encounter
    -- phase. Clear ART's delayed work at the same boundary so a stopped
    -- phase-one timer cannot create an alert during a later phase.
    self:ResetAlerts()

    if config.onBigWigsStage then
        config.onBigWigsStage(self, module, stage)
    end
end


-------------------------------------------------------------------------------
-- Position, testing, and edit mode
-------------------------------------------------------------------------------

function AbilityAlerts:GetBarPosition(spellID)
    self:MigrateAbilitySettingsStorage()
    local settingsKey = self:GetAbilityStorageKey(spellID)

    if not settingsKey then
        return nil
    end

    self.db.barPositions =
        self.db.barPositions or {}

    local position = self.db.barPositions[settingsKey]

    if not position then
        local fallback = self.db.barPosition or {}

        position = {
            point = normalizeAnchorPoint(fallback.point),
            x = fallback.x or 0,
            y = fallback.y or 220
        }

        self.db.barPositions[settingsKey] = position
    end

    position.point = normalizeAnchorPoint(position.point)
    position.x = tonumber(position.x) or 0
    position.y = tonumber(position.y) or 220

    return position
end

function AbilityAlerts:GetTextPosition(spellID)
    self:MigrateAbilitySettingsStorage()
    local settingsKey = self:GetAbilityStorageKey(spellID)

    if not settingsKey then
        return nil
    end

    self.db.textPositions =
        self.db.textPositions or {}

    local position = self.db.textPositions[settingsKey]
    local ability = self:GetAbility(spellID)

    if not position then
        local fallback = self.db.textPosition or {}
        local defaultPosition = ability and ability.defaultTextPosition or {}

        position = {
            point = normalizeAnchorPoint(
                defaultPosition.point or fallback.point
            ),
            x = defaultPosition.x ~= nil and defaultPosition.x
                or fallback.x or 0,
            y = defaultPosition.y ~= nil and defaultPosition.y
                or fallback.y or 120,
            defaultPositionVersion = ability
                and ability.defaultTextPositionVersion
                or nil
        }

        self.db.textPositions[settingsKey] = position
    end

    local defaultVersion = ability
        and tonumber(ability.defaultTextPositionVersion)
    local storedVersion = tonumber(position.defaultPositionVersion) or 0

    if defaultVersion and storedVersion < defaultVersion then
        local previous = ability.previousDefaultTextPosition
        local replacement = ability.defaultTextPosition

        if previous and replacement
            and normalizeAnchorPoint(position.point)
                == normalizeAnchorPoint(previous.point)
            and (tonumber(position.x) or 0) == (tonumber(previous.x) or 0)
            and (tonumber(position.y) or 120) == (tonumber(previous.y) or 120)
        then
            position.point = normalizeAnchorPoint(replacement.point)
            position.x = tonumber(replacement.x) or 0
            position.y = tonumber(replacement.y) or 120
        end

        position.defaultPositionVersion = defaultVersion
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

    local managedBars = {}

    for _, entry in pairs(self.managedBars) do
        if entry.bar and entry.bar:IsRunning() then
            managedBars[#managedBars + 1] = entry
        end
    end

    table.sort(managedBars, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end

        return a.key < b.key
    end)

    for _, entry in ipairs(managedBars) do
        local bar = entry.bar

        bar.frame:ClearAllPoints()
        bar.frame:SetPoint(
            normalizeAnchorPoint(barGroup.point),
            UIParent,
            "CENTER",
            barGroup.x or 0,
            (barGroup.y or 80) + barOffset * barDirection
        )
        updateAnchorPointMarker(bar.frame, barGroup.point)

        barOffset = barOffset
            + (entry.height or 24)
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
    self:MigrateAbilitySettingsStorage()
    spellID = tonumber(spellID)
    local settingsKey = self:GetAbilityStorageKey(spellID)

    if not spellID or not settingsKey then
        return
    end

    self.db.barPositions =
        self.db.barPositions or {}

    self.db.barPositions[settingsKey] = {
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
    self:MigrateAbilitySettingsStorage()
    spellID = tonumber(spellID)
    local settingsKey = self:GetAbilityStorageKey(spellID)

    if not spellID or not settingsKey then
        return
    end

    self.db.textPositions =
        self.db.textPositions or {}

    local ability = self:GetAbility(spellID)

    self.db.textPositions[settingsKey] = {
        point =
            normalizeAnchorPoint(position and position.point),

        x =
            position and position.x
            or 0,

        y =
            position and position.y
            or 120,

        defaultPositionVersion = ability
            and ability.defaultTextPositionVersion
            or nil
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

    if ability.kind == "mightyThudHits" then
        self:StartMightyThudHitBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "ravenousFeastHits" then
        self:StartRavenousFeastHitBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "mushroomTossJump" then
        self:StartMushroomTossJumpBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "latestPickup" then
        self:StartLatestPickupBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "howlingMaelstromWinds" then
        self:StartHowlingMaelstromWindBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "guillotineSequence" then
        self:StartGuillotineSequenceBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "beamBar" then
        self:StartBeamBar(
            ability,
            0,
            true
        )
        return
    end

    if ability.kind == "followupBar" then
        self:StartFollowupBar(ability, 0, true)
        return
    end

    if ability.kind == "stagedFollowupBars" then
        self:StartStagedFollowupBars(ability, 0, true)
        return
    end

    if ability.kind == "markerSequence" then
        self:StartMarkerSequenceBar(ability, 0, true)
        return
    end

    if ability.kind == "assignmentText" then
        self:StartAssignmentTextAlert(ability, 5, true)
        return
    end

    local token = self:InvalidateAbility(spellID)
    local castTimeAdjustment = getCastTimeAdjustment(ability, settings)

    local simulatedBigWigsDuration = 0

    if settings.bar and settings.bar.enabled then
        local barStart =
            getSeconds(settings.bar.secondsBefore, 5)
            - getSeconds(settings.bar.delayBy, 0)

        if not ability.castWindowBar or castTimeAdjustment <= 0 then
            barStart = barStart - castTimeAdjustment
        end

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

        if ability.castWindowBar and castTimeAdjustment > 0 then
            self:Schedule(
                spellID,
                simulatedBigWigsDuration - secondsBefore + delayBy,
                token,
                function()
                    local totalDuration = secondsBefore
                        + castTimeAdjustment

                    self:StartBar(ability, settings.bar, totalDuration)

                    local bar = self:EnsureBar(spellID)
                    local markerSettings = settings.castWindow or {}

                    self:SetTimelineMarkers(
                        bar,
                        {{
                            time = secondsBefore,
                            text = L["BossMods_AA_Cast"]
                        }},
                        totalDuration,
                        spellID,
                        tonumber(markerSettings.markerThickness) or 5,
                        markerSettings.markerColor,
                        tonumber(markerSettings.textOffsetY) or 0
                    )
                end
            )
        else
            self:Schedule(
                spellID,
                simulatedBigWigsDuration
                    + castTimeAdjustment
                    - secondsBefore
                    + delayBy,
                token,
                function()
                    self:StartBar(ability, settings.bar)
                end
            )
        end
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

function AbilityAlerts:TestEncounterBars(bossKey)
    if config.testEncounterBars then
        config.testEncounterBars(self, bossKey)
    end
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

function AbilityAlerts:OnConfiguredEvent(event, ...)
    local handler = config.events and config.events[event]

    if handler then
        handler(self, event, ...)
    end
end

function AbilityAlerts:OnConfiguredFeatureEnabledChanged(message, ...)
    if config.onFeatureEnabledChanged then
        config.onFeatureEnabledChanged(self, message, ...)
    end
end

function AbilityAlerts:ENCOUNTER_END()
    self:ResetEncounterTracking()
    self:ResetAlerts()
end

function AbilityAlerts:ENCOUNTER_START(_, encounterID, ...)
    self:ResetEncounterTracking()

    if config.onEncounterStart then
        config.onEncounterStart(self, encounterID, ...)
    end
end

-------------------------------------------------------------------------------
-- Module
-------------------------------------------------------------------------------

function AbilityAlerts:OnInitialize()
    BossMods = E:GetModule("BossMods")

    if config.initialize then
        config.initialize(self, BossMods)
    end

    self:BuildAbilityLookup()
    self:MigrateAbilitySettingsStorage()
end

function AbilityAlerts:OnEnable()
    BossMods = BossMods or E:GetModule("BossMods")

    self:BuildAbilityLookup()
    self:MigrateAbilitySettingsStorage()
    self:EnsureCustomBarDefaults()

    local spellKeySet = {}

    for spellID, ability in pairs(self.abilitiesBySpellID) do
        if not ability.triggerSpellID
            and #(ability.triggerSpellIDs or {}) == 0
        then
            spellKeySet[spellID] = true
        end
    end

    for triggerSpellID in pairs(self.triggeredAbilitiesBySpellID) do
        spellKeySet[triggerSpellID] = true
    end

    for _, spellKey in ipairs(config.extraSpellKeys or {}) do
        spellKeySet[spellKey] = true
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
            end,

            onStage = function(module, stage)
                self:OnBigWigsStage(module, stage)
            end,
        })

    self:RegisterEvent("ENCOUNTER_START")
    self:RegisterEvent("ENCOUNTER_END")

    for event in pairs(config.events or {}) do
        if event ~= "ENCOUNTER_START" and event ~= "ENCOUNTER_END" then
            self:RegisterEvent(event, "OnConfiguredEvent")
        end
    end

    if config.refresh then
        self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
        self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")
    end

    if config.onFeatureEnabledChanged then
        self:RegisterMessage(
            "ART_BOSSMODS_FEATURE_ENABLED_CHANGED",
            "OnConfiguredFeatureEnabledChanged"
        )
    end
end

function AbilityAlerts:OnDisable()
    if self.bigWigsSubscription then
        self.bigWigsSubscription:Unsubscribe()
        self.bigWigsSubscription = nil
    end

    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:ResetEncounterTracking()
    self:ResetAlerts()
end

function AbilityAlerts:Refresh()
    self:RefreshManagedBars()

for spellID, bar in pairs(self.bars) do
    local abilitySettings =
        self:GetAbilitySettings(spellID)

    local ability = self:GetAbility(spellID)

    if abilitySettings and ability then
        if ability.kind == "mightyThudHits" then
            local markerSettings = abilitySettings.mightyThud or {}
            bar.mightyThudMarkerThickness =
                tonumber(markerSettings.markerThickness) or 5
            bar.mightyThudMarkerColor =
                markerColor(markerSettings.markerColor)
        elseif ability.kind == "ravenousFeastHits" then
            local markerSettings = abilitySettings.ravenousFeast or {}
            bar.ravenousFeastMarkerThickness =
                tonumber(markerSettings.markerThickness) or 5
            bar.ravenousFeastMarkerColor =
                markerColor(markerSettings.markerColor)
        elseif ability.kind == "mushroomTossJump" then
            local markerSettings = abilitySettings.mushroomToss or {}
            local thickness = math.max(
                0.1,
                math.min(3, tonumber(markerSettings.markerThickness) or 1)
            )
            bar.mushroomTossJumpMarkerColor = markerColor(
                markerSettings.markerColor,
                {0.10, 0.90, 0.20, 0.90}
            )

            if bar.mushroomTossJumpMarkerData then
                bar.mushroomTossJumpMarkerData.windowStart =
                    3.5 - thickness / 2
                bar.mushroomTossJumpMarkerData.windowDuration = thickness
            end
        elseif ability.kind == "latestPickup" then
            local markerSettings = abilitySettings.latestPickup or {}
            bar.latestPickupMarkerThickness =
                tonumber(markerSettings.markerThickness) or 5
            bar.latestPickupMarkerColor =
                markerColor(markerSettings.markerColor)
        elseif ability.kind == "howlingMaelstromWinds" then
            local markerSettings = abilitySettings.howlingMaelstrom or {}
            bar.howlingMaelstromMarkerColor = markerColor(
                markerSettings.markerColor,
                {1, 1, 1, 0.35}
            )
        elseif ability.kind == "guillotineSequence" then
            local markerSettings = abilitySettings.guillotineSequence or {}
            bar.guillotineSequenceMarkerThickness =
                tonumber(markerSettings.markerThickness) or 5
            bar.guillotineSequenceMarkerColor =
                markerColor(markerSettings.markerColor)
            bar.guillotineSequenceTextOffsetY =
                tonumber(markerSettings.textOffsetY) or 0
        elseif ability.kind == "markerSequence" then
            local markerSettings = abilitySettings.timelineMarkers or {}
            bar.timelineMarkerThickness =
                tonumber(markerSettings.markerThickness) or 5
            bar.timelineMarkerColor =
                markerColor(markerSettings.markerColor)
        end

        if ability.castWindowBar then
            local markerSettings = abilitySettings.castWindow or {}
            bar.timelineMarkerThickness =
                tonumber(markerSettings.markerThickness) or 5
            bar.timelineMarkerColor =
                markerColor(markerSettings.markerColor)
            bar.timelineMarkerTextOffsetY =
                tonumber(markerSettings.textOffsetY) or 0
        end
    end

    local barAppearance =
        self:GetBarAppearance(spellID)

    bar:Apply(
        buildBarConfig(barAppearance, ability)
    )

    if bar:IsRunning() and bar.mightyThudMarkerRatios then
        self:PositionMightyThudMarkers(bar)
    end

    if bar:IsRunning() and bar.ravenousFeastMarkerRatios then
        self:PositionRavenousFeastMarkers(bar)
    end

    if bar:IsRunning() and bar.mushroomTossJumpActive then
        self:PositionMushroomTossJumpMarker(bar)
    end

    if bar:IsRunning() and bar.latestPickupActive then
        self:PositionLatestPickupMarker(bar)
    end

    if bar:IsRunning() and bar.howlingMaelstromActive then
        self:PositionHowlingMaelstromMarkers(bar)
    end

    if bar:IsRunning() and bar.guillotineSequenceActive then
        self:PositionGuillotineSequenceMarkers(bar)
    end

    if bar:IsRunning() and bar.timelineMarkerData then
        self:PositionTimelineMarkers(bar)
    end
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

    if config.refresh then
        config.refresh(self)
    end

    self:ApplyPositions()

    if self.editMode then
        self:SetEditMode(true, self.editModeBossKey)
    end
end

function AbilityAlerts:GetAbilityData()
    return config.getAbilityData() or {}
end

return AbilityAlerts
end
