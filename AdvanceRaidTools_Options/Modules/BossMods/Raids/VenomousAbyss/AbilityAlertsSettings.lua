local E, L = unpack(ART)
local T = E.Templates

local BossMods = E:GetModule("BossMods", true)

if not BossMods then
    return
end

local MODULE_NAME = "BossMods_VenomousAbyssAbilityAlerts"

local BOSS_FEATURES = {
    { featureKey = "VenomousAbyssNekzali", bossKey = "Nekzali" },
    { featureKey = "VenomousAbyssEntombedSentinels", bossKey = "EntombedSentinels" },
    { featureKey = "VenomousAbyssLostExplorers", bossKey = "LostExplorers" },
    { featureKey = "VenomousAbyssVashnik", bossKey = "Vashnik" },
    { featureKey = "VenomousAbyssSszorak", bossKey = "Sszorak" },
    { featureKey = "VenomousAbyssTwinFangs", bossKey = "TwinFangs" },
    { featureKey = "VenomousAbyssCoiledAltar", bossKey = "CoiledAltar" },
    { featureKey = "VenomousAbyssUlatek", bossKey = "Ulatek" }
}

local ROW_GAP = 6
local HEADER_GAP = 10
local OUTLINE_VALUES = {
    [""] = L["BossMods_AAOptions_None"],
    OUTLINE = L["BossMods_AAOptions_Outline"],
    THICKOUTLINE = L["BossMods_AAOptions_ThickOutline"],
    OUTLINE_SLUG = L["BossMods_AAOptions_SlugOutline"]
}

local OUTLINE_SORTING = {
    "",
    "OUTLINE",
    "THICKOUTLINE",
    "OUTLINE_SLUG"
}

local function fontValues()
    return E:MediaList("font")
end

local function statusBarValues()
    return E:MediaList("statusbar")
end

local AUDIO_MODE_VALUES = {
    tts = L["BossMods_AAOptions_TextToSpeech"],
    sound = L["BossMods_AAOptions_SoundFile"]
}

local AUDIO_MODE_SORTING = {
    "tts",
    "sound"
}

local COUNTDOWN_TARGET_VALUES = {
    hit = L["BossMods_AAOptions_CountdownToHit"],
    cast = L["BossMods_AAOptions_CountdownToStartCast"]
}

local COUNTDOWN_TARGET_SORTING = {
    "hit",
    "cast"
}

local SOUND_CHANNEL_VALUES = {
    Master = L["BossMods_AAOptions_Master"],
    SFX = L["BossMods_AAOptions_SoundEffects"],
    Music = L["BossMods_AAOptions_Music"],
    Ambience = L["BossMods_AAOptions_Ambience"],
    Dialog = L["BossMods_AAOptions_Dialog"]
}

local SOUND_CHANNEL_SORTING = {
    "Master",
    "SFX",
    "Music",
    "Ambience",
    "Dialog"
}

-------------------------------------------------------------------------------
-- Data
-------------------------------------------------------------------------------

local function getBossData(bossKey)
    for _, boss in ipairs(E.VenomousAbyssAbilityData or {}) do
        if boss.bossKey == bossKey then
            return boss
        end
    end
end

local function ensureAppearanceOverrideMigration(mod)
    if mod.db.appearanceOverrideMigration == 1 then
        return
    end

    mod.db.abilities = mod.db.abilities or {}

    for _, settings in pairs(mod.db.abilities) do
        if type(settings) == "table" then
            settings.bar = settings.bar or {}
            settings.text = settings.text or {}
            settings.bar.overrideAppearance = false
            settings.text.overrideAppearance = false
        end
    end

    mod.db.appearanceOverrideMigration = 1
end

local function ensureAbilitySettings(mod, spellID)
    mod.db.abilities = mod.db.abilities or {}

    local settings = mod:GetAbilitySettings(spellID)

    if not settings then
        local storageKey = mod:GetAbilityStorageKey(spellID)

        if not storageKey then
            return nil
        end

        settings = {}
        mod.db.abilities[storageKey] = settings
    end

    local ability = mod.GetAbility and mod:GetAbility(spellID)

    -- The individual bar, text and audio toggles are the alert switches.
    -- Keep legacy profiles from retaining the removed ability-wide gate.
    settings.enabled = true

    if settings.removeCastTimeAdjustment == nil then
        settings.removeCastTimeAdjustment = false
    end

    settings.difficulties = type(settings.difficulties) == "table"
        and settings.difficulties
        or {}

    if settings.difficulties.normal == nil then
        settings.difficulties.normal = true
    end

    if settings.difficulties.heroic == nil then
        settings.difficulties.heroic = true
    end

    if settings.difficulties.mythic == nil then
        settings.difficulties.mythic = true
    end

    settings.bar = settings.bar or {}

    if settings.bar.overrideAppearance == nil then
        settings.bar.overrideAppearance = false
    end

    if settings.bar.overrideAppearance
        and settings.bar.overrideAppearanceInitialized == nil
    then
        settings.bar.overrideAppearanceInitialized = true
    end

    if settings.bar.enabled == nil then
        if ability and ability.defaultBarEnabled ~= nil then
            settings.bar.enabled = ability.defaultBarEnabled == true
        else
            settings.bar.enabled = true
        end
    end

    if settings.bar.unattached == nil then
        settings.bar.unattached = false
    end

    settings.bar.secondsBefore =
        tonumber(settings.bar.secondsBefore) or 5

    settings.bar.delayBy =
        tonumber(settings.bar.delayBy) or 0

    if settings.bar.text == nil or settings.bar.text == "{spell}" then
        settings.bar.text = ""
    end
settings.bar.width =
    tonumber(settings.bar.width) or 300

settings.bar.height =
    tonumber(settings.bar.height) or 24

if settings.bar.iconEnabled == nil then
    settings.bar.iconEnabled = true
end

settings.bar.iconSize =
    tonumber(settings.bar.iconSize) or 24

settings.bar.texture =
    settings.bar.texture or "Clean"

settings.bar.fillColor =
    settings.bar.fillColor
    or {
        0.20,
        0.60,
        1.00,
        1.00
    }

if settings.bar.individualFillColorInitialized ~= true then
    local ability = mod.GetAbility and mod:GetAbility(spellID)
    local defaults = mod.GetBossDefaults
        and mod:GetBossDefaults(ability and ability.bossKey or "Unknown")
    local defaultColor = defaults
        and defaults.bar
        and defaults.bar.fillColor

    if settings.bar.overrideAppearance ~= true and defaultColor then
        settings.bar.fillColor = {
            defaultColor[1] or defaultColor.r or 0.20,
            defaultColor[2] or defaultColor.g or 0.60,
            defaultColor[3] or defaultColor.b or 1.00,
            defaultColor[4] or defaultColor.a or 1.00
        }
    end

    settings.bar.individualFillColorInitialized = true
end

settings.bar.backgroundColor =
    settings.bar.backgroundColor
    or {
        0.00,
        0.00,
        0.00,
        1.00
    }

settings.bar.backgroundOpacity =
    tonumber(settings.bar.backgroundOpacity) or 0.30
settings.bar.font =
    settings.bar.font or {}

settings.bar.font.name =
    settings.bar.font.name or "Friz Quadrata TT"

settings.bar.font.size =
    tonumber(settings.bar.font.size) or 14

settings.bar.font.outline =
    settings.bar.font.outline or "OUTLINE"

    settings.text = settings.text or {}

    if settings.text.overrideAppearance == nil then
        settings.text.overrideAppearance = false
    end

    if settings.text.overrideAppearance
        and settings.text.overrideAppearanceInitialized == nil
    then
        settings.text.overrideAppearanceInitialized = true
    end

    if settings.text.enabled == nil then
        settings.text.enabled = ability
            and ability.defaultTextEnabled == true
            or false
    end

    if settings.text.unattached == nil then
        settings.text.unattached = ability
            and ability.defaultTextUnattached == true
            or false
    end

    settings.text.secondsBefore =
        tonumber(settings.text.secondsBefore)
        or ability and ability.defaultTextSecondsBefore
        or 7

    settings.text.delayBy =
        tonumber(settings.text.delayBy) or 0

    settings.text.message =
        settings.text.message
        or L["BossMods_AAOptions_DefaultCountdownMessage"]
settings.text.font =
    settings.text.font or {}

settings.text.font.name =
    settings.text.font.name or "Friz Quadrata TT"

settings.text.font.size =
    tonumber(settings.text.font.size) or 34

settings.text.font.outline =
    settings.text.font.outline or "THICKOUTLINE"

    settings.text.countdown = true

    if settings.text.showOneDecimal == nil then
        settings.text.showOneDecimal = true
    end

    settings.audio = settings.audio or {}

    if settings.audio.enabled == nil then
        settings.audio.enabled = false
    end

    settings.audio.secondsBefore =
        tonumber(settings.audio.secondsBefore)
        or ability and ability.defaultAudioSecondsBefore
        or 3

    settings.audio.delayBy =
        tonumber(settings.audio.delayBy) or 0

    settings.audio.mode =
        settings.audio.mode or "tts"

    settings.audio.sound =
        settings.audio.sound or "None"

    settings.audio.channel =
        settings.audio.channel or "Master"

    settings.audio.ttsText =
        settings.audio.ttsText
        or ability and ability.defaultAudioTTSText
        or L["BossMods_AAOptions_DefaultCountdownMessage"]

    settings.audio.voiceID =
        tonumber(settings.audio.voiceID) or 0

    if settings.audio.countdown == nil then
        settings.audio.countdown = false
    end

    return settings
end

local function copyColor(value, fallback)
    value = value or fallback or {}

    return {
        value[1] or value.r or 1,
        value[2] or value.g or 1,
        value[3] or value.b or 1,
        value[4] or value.a or 1
    }
end

local function copyDefaultBarAppearance(mod, bossKey, settings)
    local appearance = mod:GetBossDefaults(bossKey) or {}
    local defaults = appearance.bar or {}
    local font = defaults.font or {}

    settings.width = tonumber(defaults.width) or settings.width
    settings.height = tonumber(defaults.height) or settings.height
    settings.iconEnabled = defaults.iconEnabled ~= false
    settings.iconSize = tonumber(defaults.iconSize) or settings.iconSize or 24
    settings.texture = defaults.texture or settings.texture or "Clean"
    settings.backgroundColor =
        copyColor(defaults.backgroundColor, settings.backgroundColor)
    settings.backgroundOpacity =
        tonumber(defaults.backgroundOpacity) or settings.backgroundOpacity
    settings.font = settings.font or {}
    settings.font.name = font.name or settings.font.name
    settings.font.size = tonumber(font.size) or settings.font.size
    settings.font.outline = font.outline or settings.font.outline
end

local function copyDefaultTextAppearance(mod, bossKey, settings)
    local appearance = mod:GetBossDefaults(bossKey) or {}
    local defaults = appearance.text or {}
    local font = defaults.font or {}

    settings.font = settings.font or {}
    settings.font.name = font.name or settings.font.name
    settings.font.size = tonumber(font.size) or settings.font.size
    settings.font.outline = font.outline or settings.font.outline
end

local function ensureBossDefaults(mod, bossKey)
    return mod:GetBossDefaults(bossKey)
end

-------------------------------------------------------------------------------
-- Ability Alerts UI
-------------------------------------------------------------------------------

local function buildAbilityAlertsBody(
    rightPanel,
    abilityMod,
    isDisabled,
    startY,
    rebuildCurrentPage,
    bossKey
)
    local widthPx = rightPanel:GetWidth() or 0

    if widthPx <= 0 then
        return {
            height = startY or 1
        }
    end

    local bossData = getBossData(bossKey)

    ensureAppearanceOverrideMigration(abilityMod)

    if not bossData then
        return {
            height = startY or 1
        }
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local positionChangedCallback = function()
        tracker.refresh()
    end

    abilityMod.positionChangedCallback = positionChangedCallback

    local function refreshLive()
        if abilityMod.CallIfEnabled then
            abilityMod:CallIfEnabled("Refresh")
        end

        tracker.refresh()
    end

local function checkbox(opts)
    local control = track(T:Checkbox(rightPanel, {
        text = opts.text,
        labelTop = opts.labelTop,

        checked =
            type(opts.get) == "function"
            and opts.get()
            or false,

        get = opts.get,

        onChange = function(_, value)
            opts.onChange(value)
            refreshLive()
        end,

        disabled = opts.disabled or isDisabled
    }))

    if control.Refresh then
        control.Refresh()
    end

    return control
end

local function rebuildCheckbox(opts)
    local control = track(T:Checkbox(rightPanel, {
        text = opts.text,
        labelTop = opts.labelTop,
        checked = type(opts.get) == "function" and opts.get() or false,
        get = opts.get,
        onChange = function(_, value)
            opts.onChange(value)
            refreshLive()

            if rebuildCurrentPage then
                C_Timer.After(0, rebuildCurrentPage)
            end
        end,
        disabled = opts.disabled or isDisabled
    }))

    if control.Refresh then
        control.Refresh()
    end

    return control
end

local function color(opts)
    local current = opts.get()

    return track(T:ColorSwatch(rightPanel, {
        label = opts.label,
        labelTop = true,
        hasAlpha = opts.hasAlpha ~= false,

        r = current[1] or current.r or 1,
        g = current[2] or current.g or 1,
        b = current[3] or current.b or 1,
        a = current[4] or current.a or 1,

        onChange = function(r, g, b, a)
            opts.onChange(r, g, b, a)
            refreshLive()
        end,

        disabled = opts.disabled or isDisabled
    }))
end

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,

            value = opts.get(),
            get = opts.get,

            onChange = function(value)
                opts.onChange(value)
                refreshLive()
            end,

            disabled = opts.disabled or isDisabled
        }))
    end

    local function editBox(opts)
        return track(T:EditBox(rightPanel, {
            label = opts.label,
            get = opts.get,

            onCommit = function(value)
                opts.onChange(value)
                refreshLive()
                return value
            end,

            commitOn = "enter",
            highlight = true,

            disabled = opts.disabled or isDisabled
        }))
    end

local function dropdown(opts)
    return track(T:Dropdown(rightPanel, {
        label = opts.label,
        values = opts.values,
        sorting = opts.sorting,

        get = opts.get,

        onChange = function(value)
            opts.onChange(value)
            if opts.playSample then
                opts.playSample(value)
            end
            refreshLive()
        end,

        disabled = opts.disabled or isDisabled
    }))
end


    local function button(opts)
        return track(T:Button(rightPanel, {
            text = opts.text,
            tooltip = opts.tooltip,
            onClick = opts.onClick,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function row(y, widgets)
        return y
            + T:PlaceRow(
                rightPanel,
                widgets,
                y,
                widthPx
            )
            + ROW_GAP
    end

    local function full(y, widget)
        return y
            + T:PlaceFull(
                rightPanel,
                widget,
                y,
                widthPx
            )
            + ROW_GAP
    end

    local function section(y, text)
        local header = track(T:Header(rightPanel, {
            text = text
        }))

        return y
            + T:PlaceFull(
                rightPanel,
                header,
                y,
                widthPx
            )
            + HEADER_GAP
    end

    local function markerAppearanceControls(
        y,
        markerSettings,
        thicknessOptions,
        disabled
    )
        thicknessOptions = thicknessOptions or {}

        local markerThickness = slider({
            label = thicknessOptions.label
                or L["BossMods_AAOptions_MarkerThickness"],
            min = thicknessOptions.min or 1,
            max = thicknessOptions.max or 30,
            step = thicknessOptions.step or 1,
            get = function()
                return markerSettings.markerThickness
            end,
            onChange = function(value)
                local step = thicknessOptions.step or 1
                markerSettings.markerThickness =
                    math.floor(value / step + 0.5) * step
            end,
            disabled = disabled
        })

        local markerColor = color({
            label = L["BossMods_AAOptions_MarkerColor"],
            get = function()
                return markerSettings.markerColor
            end,
            onChange = function(r, g, b, a)
                markerSettings.markerColor = {r, g, b, a}
            end,
            disabled = disabled
        })

        return row(y, {markerThickness, markerColor})
    end

    local y = startY or 0
    local positionHandles = {}
    local unlockCtrl

    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_AAOptions_Title"]
    })))

    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_AAOptions_Description"],
        sizeDelta = 1
    })))
    local abilityValues = {}
    local abilitySorting = {}

    for _, ability in ipairs(bossData.abilities or {}) do
        local spellID = tonumber(ability.spellID)

        if spellID then
            abilityValues[spellID] =
                ability.name or tostring(spellID)

            abilitySorting[#abilitySorting + 1] = spellID
        end
    end

    table.sort(abilitySorting, function(a, b)
        local abilityA
        local abilityB

        for _, ability in ipairs(bossData.abilities or {}) do
            if tonumber(ability.spellID) == a then
                abilityA = ability
            elseif tonumber(ability.spellID) == b then
                abilityB = ability
            end
        end

        local orderA = abilityA and abilityA.order or 100
        local orderB = abilityB and abilityB.order or 100

        if orderA ~= orderB then
            return orderA < orderB
        end

        return a < b
    end)

    local firstAbility = bossData.abilities
        and bossData.abilities[1]

    abilityMod.db.selectedAbilitySpellIDs =
        abilityMod.db.selectedAbilitySpellIDs or {}

    local selectedSpellID =
        tonumber(
            abilityMod.db.selectedAbilitySpellIDs[bossKey]
        )

    if not selectedSpellID
        or not abilityValues[selectedSpellID]
    then
        selectedSpellID =
            firstAbility and tonumber(firstAbility.spellID)

        abilityMod.db.selectedAbilitySpellIDs[bossKey] =
            selectedSpellID
    end

local abilityPicker = track(T:Dropdown(rightPanel, {
    label = L["BossMods_AAOptions_SelectAbility"],
    values = abilityValues,
    sorting = abilitySorting,

    get = function()
        return tonumber(
            abilityMod.db.selectedAbilitySpellIDs[bossKey]
        ) or selectedSpellID
    end,

    onChange = function(value)
        abilityMod.db.selectedAbilitySpellIDs[bossKey] =
            tonumber(value)

        if rebuildCurrentPage then
            C_Timer.After(0, rebuildCurrentPage)
        end
    end,

    disabled = isDisabled
}))

    y = full(y, abilityPicker)

    y = section(y, L["BossMods_AAOptions_Position"])

    if bossKey == "EntombedSentinels" then
        if abilityMod.db.entombedAssignmentFilteringEnabled == nil then
            abilityMod.db.entombedAssignmentFilteringEnabled = true
        end

        local assignmentFiltering = checkbox({
            text = L["BossMods_AAOptions_HideAssignmentAlerts"],
            tooltip = L["BossMods_AAOptions_HideAssignmentAlertsTooltip"],
            labelTop = true,
            get = function()
                return abilityMod.db.entombedAssignmentFilteringEnabled
                    ~= false
            end,
            onChange = function(value)
                abilityMod.db.entombedAssignmentFilteringEnabled = value
            end,
            disabled = function()
                return isDisabled()
            end
        })

        y = full(y, assignmentFiltering)
    end

    local testAllAlerts = button({
        text = L["BossMods_AAOptions_TestAllAlerts"],

        tooltip = L["BossMods_AAOptions_TestAllAlertsTooltip"],

        onClick = function()
            for _, ability in ipairs(bossData.abilities or {}) do
                local spellID = tonumber(ability.spellID)
                local settings =
                    spellID and ensureAbilitySettings(
                        abilityMod,
                        spellID
                    )

                if settings then
                    abilityMod:TestAbility(spellID)
                end
            end

            abilityMod:TestEncounterBars(bossKey)
        end,

        disabled = function()
            return isDisabled()
        end
    })

    y = full(y, testAllAlerts)

    if bossKey == "CoiledAltar" then
        if abilityMod and abilityMod.db then
            y = section(
                y,
                L["BossMods_CoiledAltarNightfallBar"]
            )

            y = full(y, checkbox({
                text = L["BossMods_CoiledAltarNightfallBarEnable"],
                labelTop = true,
                get = function()
                    return abilityMod.db.coiledAltarNightfallBarEnabled ~= false
                end,
                onChange = function(value)
                    abilityMod.db.coiledAltarNightfallBarEnabled = value
                    abilityMod:Refresh()
                end
            }))

            y = full(y, track(T:Description(rightPanel, {
                text = L["BossMods_CoiledAltarNightfallBarDesc"],
                sizeDelta = 0
            })))
        end
    end

    if bossKey == "Ulatek" then
        if abilityMod and abilityMod.db then
            y = section(
                y,
                L["BossMods_UlatekBrightscaleShrieker"]
            )

            y = full(y, checkbox({
                text = L["BossMods_UlatekShriekerBarEnable"],
                labelTop = true,
                get = function()
                    return abilityMod.db.ulatekShriekerBarEnabled ~= false
                end,
                onChange = function(value)
                    abilityMod.db.ulatekShriekerBarEnabled = value
                    abilityMod:Refresh()
                end
            }))

            y = full(y, track(T:Description(rightPanel, {
                text = L["BossMods_UlatekShriekerBarDesc"],
                sizeDelta = 0
            })))
        end
    end

    ---------------------------------------------------------------------------
    -- Abilities
    ---------------------------------------------------------------------------

    local selectedAbility

    for _, ability in ipairs(bossData.abilities or {}) do
        if tonumber(ability.spellID) == selectedSpellID then
            selectedAbility = ability
            break
        end
    end

    if selectedAbility then
        local ability = selectedAbility
        local spellID = ability.spellID
        local settings =
            ensureAbilitySettings(abilityMod, spellID)

        if ability.kind == "mightyThudHits" then
            settings.sequence = settings.sequence or {}
            settings.mightyThud = settings.mightyThud or {}
            settings.sequence.castTime =
                tonumber(settings.sequence.castTime) or 10
            settings.sequence.firstHitDelay =
                tonumber(settings.sequence.firstHitDelay) or 0.4
            settings.sequence.hitInterval =
                tonumber(settings.sequence.hitInterval) or 2
            settings.mightyThud.soakTextSize =
                tonumber(settings.mightyThud.soakTextSize) or 12
            settings.mightyThud.soakTextOffsetY =
                tonumber(settings.mightyThud.soakTextOffsetY) or 0
            local mightyThudThickness =
                tonumber(settings.mightyThud.markerThickness)

            if not settings.mightyThud.defaultThickness5Migrated then
                if mightyThudThickness == nil or mightyThudThickness == 2 then
                    mightyThudThickness = 5
                end

                settings.mightyThud.defaultThickness5Migrated = true
            end

            settings.mightyThud.markerThickness = mightyThudThickness or 5
            settings.mightyThud.markerColor = copyColor(
                settings.mightyThud.markerColor,
                {1, 1, 1, 1}
            )

            if not settings.mightyThudHitsInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.mightyThudHitsInitialized = true
            end

            if not settings.mightyThudContinuousBarInitialized then
                if settings.bar.text == "{spell} {hit}" then
                    settings.bar.text = ""
                end

                settings.mightyThudContinuousBarInitialized = true
            end
        end

        if ability.kind == "ravenousFeastHits" then
            settings.ravenousFeast = settings.ravenousFeast or {}
            settings.ravenousFeast.soakTextSize =
                tonumber(settings.ravenousFeast.soakTextSize) or 12
            settings.ravenousFeast.soakTextOffsetY =
                tonumber(settings.ravenousFeast.soakTextOffsetY) or 0
            local ravenousFeastThickness =
                tonumber(settings.ravenousFeast.markerThickness)

            if not settings.ravenousFeast.defaultThickness5Migrated then
                if ravenousFeastThickness == nil or ravenousFeastThickness == 2 then
                    ravenousFeastThickness = 5
                end

                settings.ravenousFeast.defaultThickness5Migrated = true
            end

            settings.ravenousFeast.markerThickness =
                ravenousFeastThickness or 5
            settings.ravenousFeast.markerColor = copyColor(
                settings.ravenousFeast.markerColor,
                {1, 1, 1, 1}
            )

            if not settings.ravenousFeastHitsInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.ravenousFeastHitsInitialized = true
            end
        end

        if ability.kind == "mushroomTossJump" then
            settings.mushroomToss = settings.mushroomToss or {}

            if settings.mushroomToss.ttsEnabled == nil then
                settings.mushroomToss.ttsEnabled = false
            end

            if settings.mushroomToss.baitEnabled == nil then
                settings.mushroomToss.baitEnabled = true
            end

            if settings.mushroomToss.jumpEnabled == nil then
                settings.mushroomToss.jumpEnabled = true
            end

            settings.mushroomToss.voiceID =
                tonumber(settings.mushroomToss.voiceID) or 0
            settings.mushroomToss.markerThickness =
                tonumber(settings.mushroomToss.markerThickness) or 1
            settings.mushroomToss.markerColor = copyColor(
                settings.mushroomToss.markerColor,
                {0.10, 0.90, 0.20, 0.90}
            )

            if not settings.mushroomTossJumpInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.mushroomTossJumpInitialized = true
            end
        end

        if ability.kind == "latestPickup" then
            settings.latestPickup = settings.latestPickup or {}
            settings.latestPickup.markerOffset =
                tonumber(settings.latestPickup.markerOffset) or 0
            local latestPickupThickness =
                tonumber(settings.latestPickup.markerThickness)

            if not settings.latestPickup.defaultThickness5Migrated then
                if latestPickupThickness == nil or latestPickupThickness == 2 then
                    latestPickupThickness = 5
                end

                settings.latestPickup.defaultThickness5Migrated = true
            end

            settings.latestPickup.markerThickness = latestPickupThickness or 5
            settings.latestPickup.markerColor = copyColor(
                settings.latestPickup.markerColor,
                {1, 1, 1, 1}
            )

            if not settings.latestPickupInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.latestPickupInitialized = true
            end

            if not settings.latestPickupAudioInitialized then
                settings.audio.secondsBefore = 0
                settings.audio.delayBy = 0
                settings.audio.countdown = false
                settings.audio.ttsText =
                    L["BossMods_AAOptions_NotSafeToPickupTTS"]
                settings.latestPickupAudioInitialized = true
            end
        end

        if ability.kind == "howlingMaelstromWinds" then
            settings.howlingMaelstrom = settings.howlingMaelstrom or {}
            settings.howlingMaelstrom.markerColor = copyColor(
                settings.howlingMaelstrom.markerColor,
                {1, 1, 1, 0.35}
            )

            if not settings.howlingMaelstromInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.howlingMaelstromInitialized = true
            end
        end

        if ability.kind == "guillotineSequence" then
            settings.guillotineSequence = settings.guillotineSequence or {}
            local guillotineThickness =
                tonumber(settings.guillotineSequence.markerThickness)

            if not settings.guillotineSequence.defaultThickness5Migrated then
                if guillotineThickness == nil or guillotineThickness == 2 then
                    guillotineThickness = 5
                end

                settings.guillotineSequence.defaultThickness5Migrated = true
            end

            settings.guillotineSequence.markerThickness =
                guillotineThickness or 5
            settings.guillotineSequence.textOffsetY =
                tonumber(settings.guillotineSequence.textOffsetY) or 0
            settings.guillotineSequence.markerColor = copyColor(
                settings.guillotineSequence.markerColor,
                {1, 1, 1, 1}
            )

            if not settings.guillotineSequenceInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.guillotineSequenceInitialized = true
            end
        end

        if ability.kind == "beamBar" then
            if not settings.beamBarInitialized then
                settings.bar.text = ""
                settings.text.enabled = false
                settings.audio.enabled = false
                settings.beamBarInitialized = true
            end
        end

        if ability.kind == "markerSequence" then
            settings.timelineMarkers = settings.timelineMarkers or {}
            settings.timelineMarkers.markerThickness =
                tonumber(settings.timelineMarkers.markerThickness) or 5
            settings.timelineMarkers.markerColor = copyColor(
                settings.timelineMarkers.markerColor,
                {1, 1, 1, 1}
            )
            settings.timelineMarkers.textOffsetY =
                tonumber(settings.timelineMarkers.textOffsetY) or 0
        end

        if ability.castWindowBar then
            settings.castWindow = settings.castWindow or {}
            settings.castWindow.markerThickness =
                tonumber(settings.castWindow.markerThickness) or 5
            settings.castWindow.markerColor = copyColor(
                settings.castWindow.markerColor,
                {1, 1, 1, 1}
            )
            settings.castWindow.textOffsetY =
                tonumber(settings.castWindow.textOffsetY) or 0
        end

        y = section(y, ability.name or tostring(spellID))

        y = section(y, L["BossMods_AAOptions_ActiveDifficulties"])

        y = row(y, {
            checkbox({
                text = L["BossMods_AAOptions_Normal"],
                labelTop = true,
                get = function() return settings.difficulties.normal end,
                onChange = function(value)
                    settings.difficulties.normal = value
                end
            }),
            checkbox({
                text = L["BossMods_AAOptions_Heroic"],
                labelTop = true,
                get = function() return settings.difficulties.heroic end,
                onChange = function(value)
                    settings.difficulties.heroic = value
                end
            }),
            checkbox({
                text = L["BossMods_AAOptions_Mythic"],
                labelTop = true,
                get = function() return settings.difficulties.mythic end,
                onChange = function(value)
                    settings.difficulties.mythic = value
                end
            })
        })

        local hasUnattachedFrame =
            (
                (
                    settings.bar
                    and settings.bar.enabled
                    and settings.bar.unattached == true
                )
                or
                (
                    settings.text
                    and settings.text.enabled
                    and settings.text.unattached == true
                )
            )

        if hasUnattachedFrame then
            local unlockY

            unlockY, unlockCtrl =
                T:UnlockController(
                    rightPanel,
                    y,
                    widthPx,
                    {
                        tracker = tracker,
                        isDisabled = isDisabled,
                        onEditModeChanged = function(value)
                            abilityMod:SetEditMode(value, bossKey)
                        end
                    }
                )

            y = unlockY
        end

        local testAlert = button({
            text = L["BossMods_AAOptions_TestAlert"],

            tooltip = ability.kind == "mightyThudHits"
                and L["BossMods_AAOptions_TestMightyThudTooltip"]
                or ability.kind == "ravenousFeastHits"
                and L["BossMods_AAOptions_TestRavenousFeastTooltip"]
                or ability.kind == "mushroomTossJump"
                and L["BossMods_AAOptions_TestMushroomTossTooltip"]
                or ability.kind == "latestPickup"
                and L["BossMods_AAOptions_TestLatestPickupTooltip"]
                or ability.kind == "howlingMaelstromWinds"
                and L["BossMods_AAOptions_TestHowlingMaelstromTooltip"]
                or ability.kind == "guillotineSequence"
                and L["BossMods_AAOptions_TestGuillotineTooltip"]
                or ability.kind == "beamBar"
                and L["BossMods_AAOptions_TestBeamTooltip"]
                or L["BossMods_AAOptions_TestAlertTooltip"],

            onClick = function()
                abilityMod:TestAbility(spellID)
            end,

            disabled = function()
                return isDisabled()
            end
        })

        y = full(y, testAlert)

        if tonumber(ability.castTimeAdjustment)
            and tonumber(ability.castTimeAdjustment) > 0
        then
            y = section(y, L["BossMods_AAOptions_Timing"])

            if ability.countdownTargetChoice then
                local countdownTarget = dropdown({
                    label = L["BossMods_AAOptions_CountdownTarget"],
                    values = COUNTDOWN_TARGET_VALUES,
                    sorting = COUNTDOWN_TARGET_SORTING,
                    get = function()
                        return settings.removeCastTimeAdjustment
                            and "cast" or "hit"
                    end,
                    onChange = function(value)
                        settings.removeCastTimeAdjustment = value == "cast"
                    end,
                    disabled = function()
                        return isDisabled()
                    end
                })

                y = full(y, countdownTarget)
            else
                local removeCastAdjustment = checkbox({
                    text = L["BossMods_AAOptions_RemoveCastTimeAdjustments"],
                    labelTop = true,
                    get = function()
                        return settings.removeCastTimeAdjustment == true
                    end,
                    onChange = function(value)
                        settings.removeCastTimeAdjustment = value
                    end,
                    disabled = function()
                        return isDisabled()
                    end
                })

                y = full(y, removeCastAdjustment)
            end

            y = full(y, track(T:Description(rightPanel, {
                text = L["BossMods_AAOptions_CastTimeAdjustmentDescription"]
                    :format(tostring(ability.castTimeAdjustment)),
                sizeDelta = 0
            })))
        end

        -----------------------------------------------------------------------
        -- Bar
        -----------------------------------------------------------------------

        if not ability.textOnly then
        y = section(y, L["BossMods_AAOptions_Bar"])

        local enableBar = rebuildCheckbox({
            text = L["BossMods_AAOptions_EnableBar"],
            labelTop = true,
            get = function() return settings.bar.enabled end,
            onChange = function(value) settings.bar.enabled = value end,
            disabled = function()
                return isDisabled() or not settings.enabled
            end
        })

        y = full(y, enableBar)

        if settings.bar.enabled then
            local barFillColor = color({
                label = L["BossMods_AAOptions_BarColor"],
                get = function() return settings.bar.fillColor end,
                onChange = function(r, g, b, a)
                    settings.bar.fillColor = {r, g, b, a}

                    if abilityMod.Refresh then
                        abilityMod:Refresh()
                    end
                end,
                disabled = function()
                    return isDisabled() or not settings.enabled
                end
            })

            y = full(y, barFillColor)

            local unattachBar = rebuildCheckbox({
                text = L["BossMods_AAOptions_UnattachBar"],
                labelTop = true,

                get = function()
                    return settings.bar.unattached == true
                end,

                onChange = function(value)
                    settings.bar.unattached = value
                    abilityMod:ApplyPositions()
                end,

                disabled = function()
                    return isDisabled()
                        or not settings.enabled
                end
            })

            y = full(y, unattachBar)

            if settings.bar.unattached then
                y = T:XYOffsetControls(rightPanel, y, widthPx, {
                    tracker = tracker,
                    getPosition = function()
                        return abilityMod:GetBarPosition(spellID)
                    end,
                    setPosition = function(position)
                        abilityMod:SaveBarPosition(spellID, position)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end,
                    xInputLabel = L["BossMods_AAOptions_BarXValue"],
                    yInputLabel = L["BossMods_AAOptions_BarYValue"]
                })
            end

            if ability.kind == "mightyThudHits" then
                local castTime = slider({
                    label = L["BossMods_AAOptions_CastTime"],
                    min = 0, max = 20, step = 0.1,
                    get = function() return settings.sequence.castTime end,
                    onChange = function(value)
                        settings.sequence.castTime =
                            math.floor(value * 10 + 0.5) / 10
                    end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local firstHitDelay = slider({
                    label = L["BossMods_AAOptions_FirstHitDelay"],
                    min = 0.1, max = 5, step = 0.1,
                    get = function() return settings.sequence.firstHitDelay end,
                    onChange = function(value)
                        settings.sequence.firstHitDelay =
                            math.floor(value * 10 + 0.5) / 10
                    end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { castTime, firstHitDelay })

                local hitInterval = slider({
                    label = L["BossMods_AAOptions_TimeBetweenHits"],
                    min = 0.1, max = 5, step = 0.1,
                    get = function() return settings.sequence.hitInterval end,
                    onChange = function(value)
                        settings.sequence.hitInterval =
                            math.floor(value * 10 + 0.5) / 10
                    end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })
                y = full(y, hitInterval)

                y = markerAppearanceControls(
                    y,
                    settings.mightyThud,
                    {
                        label = L["BossMods_AAOptions_MarkerThicknessPixels"],
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                local soakTextSize = slider({
                    label = L["BossMods_AAOptions_SoakTextSize"],
                    min = 8, max = 40,
                    get = function()
                        return settings.mightyThud.soakTextSize
                    end,
                    onChange = function(value)
                        settings.mightyThud.soakTextSize =
                            math.floor(value)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                local soakTextOffsetY = slider({
                    label = L["BossMods_AAOptions_SoakTextVerticalOffset"],
                    min = -30,
                    max = 30,
                    get = function()
                        return settings.mightyThud.soakTextOffsetY
                    end,
                    onChange = function(value)
                        settings.mightyThud.soakTextOffsetY =
                            math.floor(value)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                y = row(y, { soakTextSize, soakTextOffsetY })
            elseif ability.kind == "ravenousFeastHits" then
                y = markerAppearanceControls(
                    y,
                    settings.ravenousFeast,
                    {
                        label = L["BossMods_AAOptions_MarkerThicknessPixels"],
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                local soakTextSize = slider({
                    label = L["BossMods_AAOptions_SoakTextSize"],
                    min = 8, max = 40,
                    get = function()
                        return settings.ravenousFeast.soakTextSize
                    end,
                    onChange = function(value)
                        settings.ravenousFeast.soakTextSize =
                            math.floor(value)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                local soakTextOffsetY = slider({
                    label = L["BossMods_AAOptions_SoakTextVerticalOffset"],
                    min = -30,
                    max = 30,
                    get = function()
                        return settings.ravenousFeast.soakTextOffsetY
                    end,
                    onChange = function(value)
                        settings.ravenousFeast.soakTextOffsetY =
                            math.floor(value)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                y = row(y, { soakTextSize, soakTextOffsetY })

                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_RavenousFeastDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "mushroomTossJump" then
                local enableBaitBar = checkbox({
                    text = L["BossMods_AAOptions_EnableBaitBar"],
                    labelTop = true,
                    get = function()
                        return settings.mushroomToss.baitEnabled
                    end,
                    onChange = function(value)
                        settings.mushroomToss.baitEnabled = value
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                local enableJumpBar = checkbox({
                    text = L["BossMods_AAOptions_EnableJumpBar"],
                    labelTop = true,
                    get = function()
                        return settings.mushroomToss.jumpEnabled
                    end,
                    onChange = function(value)
                        settings.mushroomToss.jumpEnabled = value
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                y = row(y, { enableBaitBar, enableJumpBar })

                y = markerAppearanceControls(
                    y,
                    settings.mushroomToss,
                    {
                        label = L["BossMods_AAOptions_MarkerThicknessSeconds"],
                        min = 0.1,
                        max = 3,
                        step = 0.1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_MushroomTossDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "latestPickup" then
                local markerOffset = slider({
                    label = L["BossMods_AAOptions_MarkerOffset"],
                    min = -0.9,
                    max = 0.9,
                    step = 0.1,
                    get = function()
                        return settings.latestPickup.markerOffset
                    end,
                    onChange = function(value)
                        settings.latestPickup.markerOffset =
                            math.floor(value * 10 + 0.5) / 10
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                y = full(y, markerOffset)

                y = markerAppearanceControls(
                    y,
                    settings.latestPickup,
                    {
                        label = L["BossMods_AAOptions_MarkerThicknessPixels"],
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_LatestPickupDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "howlingMaelstromWinds" then
                local windMarkerColor = color({
                    label = L["BossMods_AAOptions_WindMarkerColor"],
                    get = function()
                        return settings.howlingMaelstrom.markerColor
                    end,
                    onChange = function(r, g, b, a)
                        settings.howlingMaelstrom.markerColor = {r, g, b, a}
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                y = full(y, windMarkerColor)

                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_HowlingMaelstromDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "guillotineSequence" then
                y = markerAppearanceControls(
                    y,
                    settings.guillotineSequence,
                    {
                        label = L["BossMods_AAOptions_MarkerThicknessPixels"],
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                local markerTextOffsetY = slider({
                    label = L["BossMods_AAOptions_HitExplodeTextVerticalOffset"],
                    min = -30,
                    max = 30,
                    step = 1,
                    get = function()
                        return settings.guillotineSequence.textOffsetY
                    end,
                    onChange = function(value)
                        settings.guillotineSequence.textOffsetY =
                            math.floor(value)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end
                })

                y = full(y, markerTextOffsetY)

                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_GuillotineDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "beamBar" then
                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_BeamDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "followupBar" then
                local mechanic = ability.mechanic or {}
                local startOffset = tonumber(mechanic.startOffset) or 0

                y = full(y, track(T:Description(rightPanel, {
                    text = startOffset > 0
                        and L["BossMods_AAOptions_FollowupBarAfterDescription"]
                            :format(
                                tostring(startOffset),
                                tostring(mechanic.duration or 0)
                            )
                        or L["BossMods_AAOptions_FollowupBarWhenDescription"]
                            :format(tostring(mechanic.duration or 0)),
                    sizeDelta = 0
                })))
            elseif ability.kind == "stagedFollowupBars" then
                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_StagedFollowupDescription"],
                    sizeDelta = 0
                })))
            elseif ability.kind == "markerSequence" then
                y = markerAppearanceControls(
                    y,
                    settings.timelineMarkers,
                    {
                        label = L["BossMods_AAOptions_MarkerThicknessPixels"],
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                y = full(y, track(T:Description(rightPanel, {
                    text = L["BossMods_AAOptions_MarkerSequenceDescription"],
                    sizeDelta = 0
                })))
            else
                local barSeconds = slider({
                    label = L["BossMods_AAOptions_SecondsBefore"],
                    min = 1, max = 30,
                    get = function() return settings.bar.secondsBefore end,
                    onChange = function(value) settings.bar.secondsBefore = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barDelay = slider({
                    label = L["BossMods_AAOptions_DelayBy"],
                    min = 0, max = 30,
                    get = function() return settings.bar.delayBy end,
                    onChange = function(value) settings.bar.delayBy = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { barSeconds, barDelay })

                if ability.castWindowBar then
                    y = markerAppearanceControls(
                        y,
                        settings.castWindow,
                        {
                            label = L["BossMods_AAOptions_CastMarkerThicknessPixels"],
                            min = 1,
                            max = 30,
                            step = 1
                        },
                        function()
                            return isDisabled() or not settings.enabled
                        end
                    )
                end

                if ability.postHitStages then
                    local stageDescriptions = {}

                    for _, stage in ipairs(
                        ability.postHitStages.stages or {}
                    ) do
                        stageDescriptions[#stageDescriptions + 1] =
                            L["BossMods_AAOptions_StageDuration"]:format(
                                tostring(
                                    stage.text
                                    or L["BossMods_AAOptions_Stage"]
                                ),
                                tostring(stage.duration or 0)
                            )
                    end

                    y = full(y, track(T:Description(rightPanel, {
                        text = L["BossMods_AAOptions_PostHitStagesDescription"]
                            :format(
                                table.concat(
                                    stageDescriptions,
                                    L["BossMods_AAOptions_AndThen"]
                                )
                            ),
                        sizeDelta = 0
                    })))
                end
            end

            if ability.kind ~= "mushroomTossJump"
                and ability.kind ~= "latestPickup"
                and ability.kind ~= "howlingMaelstromWinds"
                and ability.kind ~= "guillotineSequence"
                and ability.kind ~= "beamBar"
            then
                local barText = editBox({
                    label = L["BossMods_AAOptions_CustomBarName"],
                    get = function() return settings.bar.text end,
                    onChange = function(value) settings.bar.text = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = full(y, barText)

                if ability.kind == "mightyThudHits" then
                    y = full(y, track(T:Description(rightPanel, {
                        text = L["BossMods_AAOptions_MightyThudDescription"],
                        sizeDelta = 0
                    })))
                end
            end

            local overrideBarAppearance = rebuildCheckbox({
                text = L["BossMods_AAOptions_OverrideBarAppearance"],
                labelTop = true,
                get = function() return settings.bar.overrideAppearance end,
                onChange = function(value)
                    if value
                        and not settings.bar.overrideAppearanceInitialized
                    then
                        copyDefaultBarAppearance(
                            abilityMod,
                            bossKey,
                            settings.bar
                        )
                        settings.bar.overrideAppearanceInitialized = true
                    end

                    settings.bar.overrideAppearance = value
                end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            y = full(y, overrideBarAppearance)

            if settings.bar.overrideAppearance then
                local barWidth = slider({
                    label = L["BossMods_AAOptions_BarWidth"],
                    min = 100, max = 800, step = 5,
                    get = function() return settings.bar.width end,
                    onChange = function(value) settings.bar.width = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barHeight = slider({
                    label = L["BossMods_AAOptions_BarHeight"],
                    min = 10, max = 80,
                    get = function() return settings.bar.height end,
                    onChange = function(value) settings.bar.height = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barTexture = dropdown({
                    label = L["BossMods_AAOptions_BarTexture"],
                    values = statusBarValues,
                    get = function() return settings.bar.texture end,
                    onChange = function(value) settings.bar.texture = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { barWidth, barHeight, barTexture })

                if ability.kind == nil then
                    local barIconEnabled = checkbox({
                        text = L["BossMods_AAOptions_EnableAbilityIcon"],
                        labelTop = true,
                        get = function() return settings.bar.iconEnabled ~= false end,
                        onChange = function(value) settings.bar.iconEnabled = value end,
                        disabled = function() return isDisabled() or not settings.enabled end
                    })

                    local barIconSize = slider({
                        label = L["BossMods_AAOptions_IconSize"],
                        min = 8, max = 80,
                        get = function() return settings.bar.iconSize end,
                        onChange = function(value) settings.bar.iconSize = math.floor(value) end,
                        disabled = function()
                            return isDisabled()
                                or not settings.enabled
                                or settings.bar.iconEnabled == false
                        end
                    })

                    y = row(y, { barIconEnabled, barIconSize })
                end

                local barBackgroundColor = color({
                    label = L["BossMods_AAOptions_BackgroundColor"],
                    get = function() return settings.bar.backgroundColor end,
                    onChange = function(r, g, b, a) settings.bar.backgroundColor = {r, g, b, a} end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = full(y, barBackgroundColor)

                local barFont = dropdown({
                    label = L["BossMods_AAOptions_Font"], values = fontValues,
                    get = function() return settings.bar.font.name end,
                    onChange = function(value) settings.bar.font.name = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barFontSize = slider({
                    label = L["BossMods_AAOptions_FontSize"],
                    min = 8, max = 40,
                    get = function() return settings.bar.font.size end,
                    onChange = function(value) settings.bar.font.size = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barFontOutline = dropdown({
                    label = L["BossMods_AAOptions_FontOutline"],
                    values = OUTLINE_VALUES,
                    sorting = OUTLINE_SORTING,
                    get = function() return settings.bar.font.outline end,
                    onChange = function(value) settings.bar.font.outline = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { barFont, barFontSize, barFontOutline })
            end
        end

        if ability.kind == "mushroomTossJump" then
            y = section(y, L["BossMods_AAOptions_Audio"])

            local enableMushroomTTS = checkbox({
                text = L["BossMods_AAOptions_EnableBaitJumpTTS"],
                labelTop = true,
                get = function()
                    return settings.mushroomToss.ttsEnabled
                end,
                onChange = function(value)
                    settings.mushroomToss.ttsEnabled = value
                end,
                disabled = function()
                    return isDisabled()
                        or not settings.enabled
                        or not settings.bar.enabled
                        or (
                            not settings.mushroomToss.baitEnabled
                            and not settings.mushroomToss.jumpEnabled
                        )
                end
            })

            y = full(y, enableMushroomTTS)

            if settings.mushroomToss.ttsEnabled then
                local mushroomVoice = dropdown({
                    label = L["BossMods_AAOptions_TTSVoice"],
                    values = function()
                        return E:GetModule("BossMods")
                            .Alerts:GetTTSVoices()
                    end,
                    get = function()
                        return settings.mushroomToss.voiceID or 0
                    end,
                    onChange = function(value)
                        settings.mushroomToss.voiceID =
                            tonumber(value) or 0

                        E:GetModule("BossMods")
                            .Alerts:SpeakTTS({
                                text = L["BossMods_AAOptions_JumpVoiceSample"],
                                voiceID = settings.mushroomToss.voiceID
                            })
                    end,
                    disabled = function()
                        return isDisabled()
                            or not settings.enabled
                            or not settings.bar.enabled
                            or (
                                not settings.mushroomToss.baitEnabled
                                and not settings.mushroomToss.jumpEnabled
                            )
                    end
                })

                y = full(y, mushroomVoice)
            end
        end

        end

        if ability.kind ~= "mightyThudHits"
            and ability.kind ~= "ravenousFeastHits"
            and ability.kind ~= "mushroomTossJump"
            and ability.kind ~= "latestPickup"
        then
            -------------------------------------------------------------------
            -- Text
            -------------------------------------------------------------------

        y = section(y, L["BossMods_AAOptions_Text"])

        local enableText = rebuildCheckbox({
            text = L["BossMods_AAOptions_EnableText"],
            labelTop = true,
            get = function() return settings.text.enabled end,
            onChange = function(value) settings.text.enabled = value end,
            disabled = function()
                return isDisabled() or not settings.enabled
            end
        })

        y = full(y, enableText)

        if settings.text.enabled then
            local unattachText = rebuildCheckbox({
                text = L["BossMods_AAOptions_UnattachText"],
                labelTop = true,

                get = function()
                    return settings.text.unattached == true
                end,

                onChange = function(value)
                    settings.text.unattached = value
                    abilityMod:ApplyPositions()
                end,

                disabled = function()
                    return isDisabled()
                        or not settings.enabled
                end
            })

            y = full(y, unattachText)

            if settings.text.unattached then
                y = T:XYOffsetControls(rightPanel, y, widthPx, {
                    tracker = tracker,
                    getPosition = function()
                        return abilityMod:GetTextPosition(spellID)
                    end,
                    setPosition = function(position)
                        abilityMod:SaveTextPosition(spellID, position)
                    end,
                    disabled = function()
                        return isDisabled() or not settings.enabled
                    end,
                    xInputLabel = L["BossMods_AAOptions_TextXValue"],
                    yInputLabel = L["BossMods_AAOptions_TextYValue"]
                })
            end

            local textSeconds = slider({
                label = L["BossMods_AAOptions_SecondsBefore"],
                min = 1, max = 30,
                get = function() return settings.text.secondsBefore end,
                onChange = function(value) settings.text.secondsBefore = math.floor(value) end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            local textDelay = slider({
                label = L["BossMods_AAOptions_DelayBy"],
                min = 0, max = 30,
                get = function() return settings.text.delayBy end,
                onChange = function(value) settings.text.delayBy = math.floor(value) end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            y = row(y, { textSeconds, textDelay })

            local showOneDecimal = checkbox({
                text = L["BossMods_AAOptions_ShowOneDecimal"],
                labelTop = true,
                get = function()
                    return settings.text.showOneDecimal ~= false
                end,
                onChange = function(value)
                    settings.text.showOneDecimal = value
                end,
                disabled = function()
                    return isDisabled() or not settings.enabled
                end
            })

            y = full(y, showOneDecimal)

            if ability.kind ~= "assignmentText" then
                local textMessage = editBox({
                    label = L["BossMods_AAOptions_TextMessage"],
                    get = function() return settings.text.message end,
                    onChange = function(value) settings.text.message = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = full(y, textMessage)
            end

            local overrideTextAppearance = rebuildCheckbox({
                text = L["BossMods_AAOptions_OverrideTextAppearance"],
                labelTop = true,
                get = function() return settings.text.overrideAppearance end,
                onChange = function(value)
                    if value
                        and not settings.text.overrideAppearanceInitialized
                    then
                        copyDefaultTextAppearance(
                            abilityMod,
                            bossKey,
                            settings.text
                        )
                        settings.text.overrideAppearanceInitialized = true
                    end

                    settings.text.overrideAppearance = value
                end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            y = full(y, overrideTextAppearance)

            if settings.text.overrideAppearance then
                local textFont = dropdown({
                    label = L["BossMods_AAOptions_Font"], values = fontValues,
                    get = function() return settings.text.font.name end,
                    onChange = function(value) settings.text.font.name = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local textFontSize = slider({
                    label = L["BossMods_AAOptions_FontSize"],
                    min = 8, max = 72,
                    get = function() return settings.text.font.size end,
                    onChange = function(value) settings.text.font.size = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local textFontOutline = dropdown({
                    label = L["BossMods_AAOptions_FontOutline"],
                    values = OUTLINE_VALUES,
                    sorting = OUTLINE_SORTING,
                    get = function() return settings.text.font.outline end,
                    onChange = function(value) settings.text.font.outline = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { textFont, textFontSize, textFontOutline })
            end
        end

        end

        if ability.kind ~= "mightyThudHits"
            and ability.kind ~= "ravenousFeastHits"
            and ability.kind ~= "mushroomTossJump"
            and (not ability.textOnly or ability.assignmentAudio)
        then

        -----------------------------------------------------------------------
        -- Audio
        -----------------------------------------------------------------------

        y = section(y, L["BossMods_AAOptions_Audio"])

        local enableAudio = rebuildCheckbox({
            text = L["BossMods_AAOptions_EnableAudio"],
            labelTop = true,

            get = function()
                return settings.audio.enabled
            end,

            onChange = function(value)
                settings.audio.enabled = value
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
            end
        })

        y = full(y, enableAudio)

        if settings.audio.enabled then
        local audioSeconds = slider({
            label = ability.kind == "latestPickup"
                and L["BossMods_AAOptions_SecondsBeforeMarker"]
                or L["BossMods_AAOptions_SecondsBefore"],
            min = ability.assignmentAudio and 0
                or ability.kind == "latestPickup" and 0 or 1,
            max = ability.assignmentAudio and 7
                or ability.kind == "latestPickup" and 3 or 30,
            step = ability.kind == "latestPickup" and 0.1 or 1,

            get = function()
                return settings.audio.secondsBefore
            end,

            onChange = function(value)
                if ability.kind == "latestPickup" then
                    settings.audio.secondsBefore =
                        math.floor(value * 10 + 0.5) / 10
                else
                    settings.audio.secondsBefore =
                        math.floor(value)
                end
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
                    or not settings.audio.enabled
            end
        })

        local audioDelay = not ability.assignmentAudio and slider({
            label = ability.kind == "latestPickup"
                and L["BossMods_AAOptions_DelayAfterMarker"]
                or L["BossMods_AAOptions_DelayBy"],
            min = 0,
            max = ability.kind == "latestPickup" and 3 or 30,
            step = ability.kind == "latestPickup" and 0.1 or 1,

            get = function()
                return settings.audio.delayBy
            end,

            onChange = function(value)
                if ability.kind == "latestPickup" then
                    settings.audio.delayBy =
                        math.floor(value * 10 + 0.5) / 10
                else
                    settings.audio.delayBy =
                        math.floor(value)
                end
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
                    or not settings.audio.enabled
            end
        }) or nil

        if ability.assignmentAudio then
            settings.audio.delayBy = 0
            settings.audio.countdown = false
            y = full(y, audioSeconds)
        else
            y = row(y, {
                audioSeconds,
                audioDelay
            })
        end

        local audioMode = dropdown({
            label = L["BossMods_AAOptions_AudioType"],
            values = AUDIO_MODE_VALUES,
            sorting = AUDIO_MODE_SORTING,

            get = function()
                return settings.audio.mode
            end,

            onChange = function(value)
                settings.audio.mode = value
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
                    or not settings.audio.enabled
            end
        })

        local audioCountdown = not ability.assignmentAudio and checkbox({
            text = L["BossMods_AAOptions_CountdownEverySecond"],
            labelTop = true,

            get = function()
                return settings.audio.countdown
            end,

            onChange = function(value)
                settings.audio.countdown = value
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
                    or not settings.audio.enabled
                    or settings.audio.mode ~= "tts"
            end
        }) or nil

        if ability.assignmentAudio then
            y = full(y, audioMode)
        else
            y = row(y, {
                audioMode,
                audioCountdown
            })
        end

        local ttsText = editBox({
            label = L["BossMods_AAOptions_TextToSpeechMessage"],

            get = function()
                return settings.audio.ttsText
            end,

            onChange = function(value)
                settings.audio.ttsText = value
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
                    or not settings.audio.enabled
                    or settings.audio.mode ~= "tts"
            end
        })

        local voiceID = dropdown({
    label = L["BossMods_AAOptions_TTSVoice"],

    values = function()
        return E:GetModule("BossMods")
            .Alerts:GetTTSVoices()
    end,

    get = function()
        return settings.audio.voiceID or 0
    end,

    onChange = function(value)
        settings.audio.voiceID =
            tonumber(value) or 0

        E:GetModule("BossMods")
            .Alerts:SpeakTTS({
                text = L["BossMods_AAOptions_VoiceTest"],
                voiceID = settings.audio.voiceID
            })
    end,

    disabled = function()
        return isDisabled()
            or not settings.enabled
            or not settings.audio.enabled
            or settings.audio.mode ~= "tts"
    end
})

        y = row(y, {
            ttsText,
            voiceID
        })

        local soundName = dropdown({
    label = L["BossMods_AAOptions_SoundFile"],

    values = function()
        return E:GetModule("BossMods")
            .Alerts:GetSoundOptions()
    end,

    get = function()
        return settings.audio.sound
    end,

    onChange = function(value)
        settings.audio.sound = value
    end,

    playSample = function(value)
        E:GetModule("BossMods")
            .Alerts:PlaySound({
                name = value,
                channel =
                    settings.audio.channel
                    or "Master"
            })
    end,

    disabled = function()
        return isDisabled()
            or not settings.enabled
            or not settings.audio.enabled
            or settings.audio.mode ~= "sound"
    end
})

        local soundChannel = dropdown({
            label = L["BossMods_AAOptions_SoundChannel"],
            values = SOUND_CHANNEL_VALUES,
            sorting = SOUND_CHANNEL_SORTING,

            get = function()
                return settings.audio.channel
            end,

            onChange = function(value)
                settings.audio.channel = value
            end,

            disabled = function()
                return isDisabled()
                    or not settings.enabled
                    or not settings.audio.enabled
                    or settings.audio.mode ~= "sound"
            end
        })

        y = row(y, {
            soundName,
            soundChannel
        })

        y = full(y, track(T:Description(rightPanel, {
            text = ability.kind == "latestPickup"
                and L["BossMods_AAOptions_LatestPickupAudioDescription"]
                or L["BossMods_AAOptions_VariablesDescription"],
            sizeDelta = 0
        })))
        end
        end
    end

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,

        Refresh = tracker.refresh,

        SetUnlocked = function(value)
            if unlockCtrl then
                unlockCtrl:SetUnlocked(value)
            end
        end,

        Release = function()
            if abilityMod.positionChangedCallback
                == positionChangedCallback
            then
                abilityMod.positionChangedCallback = nil
            end

            for _, handle in ipairs(positionHandles) do
                if handle and handle.Release then
                    handle.Release()
                end
            end

            if unlockCtrl then
                unlockCtrl:Release()
            end

            tracker.release()
        end
    }
end

-------------------------------------------------------------------------------
-- Register Ability Alerts for every Venomous Abyss boss
-------------------------------------------------------------------------------

local function createBossBuilder(bossKey)
    return function(rightPanel, assignmentMod, isDisabled)
        local abilityMod =
            E:GetModule(MODULE_NAME, true)

        if not abilityMod then
            return {}
        end

        local currentBody
        local released = false

        local proxy = {
            height = 1
        }

        local function refreshScrollRange()
            if released then
                return
            end

            local content = rightPanel:GetParent()

            if content then
                content:SetHeight(proxy.height)
            end

            local scroll = content and content:GetParent()

            if scroll and scroll.UpdateScrollChildRect then
                scroll:UpdateScrollChildRect()
            end
        end

        local function rebuildCurrentPage()
            if released then
                return
            end

            local keepUnlocked =
                abilityMod.editMode
                and abilityMod.editModeBossKey == bossKey

            if currentBody and currentBody.Release then
                currentBody.Release()
            end

            currentBody = buildAbilityAlertsBody(
                rightPanel,
                abilityMod,
                isDisabled,
                0,
                rebuildCurrentPage,
                bossKey
            )

            proxy.height =
                currentBody and currentBody.height or 1

            if keepUnlocked
                and currentBody
                and currentBody.SetUnlocked
            then
                currentBody.SetUnlocked(true)
            end

            rightPanel:SetHeight(proxy.height)
            refreshScrollRange()
            C_Timer.After(0, refreshScrollRange)
        end

        rebuildCurrentPage()

        proxy.Refresh = function()
            if currentBody
                and currentBody.Refresh
            then
                return currentBody.Refresh()
            end
        end

        proxy.Release = function()
            released = true

            if currentBody
                and currentBody.Release
            then
                currentBody.Release()
            end

            currentBody = nil
        end

        return proxy
    end
end

for _, bossFeature in ipairs(BOSS_FEATURES) do
    BossMods.settingsBuilders[bossFeature.featureKey] =
        createBossBuilder(bossFeature.bossKey)
end
