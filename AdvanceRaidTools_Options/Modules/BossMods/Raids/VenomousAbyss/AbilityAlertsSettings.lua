local E = unpack(ART)
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
    [""] = "None",
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    OUTLINE_SLUG = "Slug Outline"
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
    tts = "Text to Speech",
    sound = "Sound file"
}

local AUDIO_MODE_SORTING = {
    "tts",
    "sound"
}

local COUNTDOWN_TARGET_VALUES = {
    hit = "Countdown to hit",
    cast = "Countdown to start cast"
}

local COUNTDOWN_TARGET_SORTING = {
    "hit",
    "cast"
}

local SOUND_CHANNEL_VALUES = {
    Master = "Master",
    SFX = "Sound Effects",
    Music = "Music",
    Ambience = "Ambience",
    Dialog = "Dialog"
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
        settings.bar.enabled = true
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
        settings.text.enabled = false
    end

    if settings.text.unattached == nil then
        settings.text.unattached = false
    end

    settings.text.secondsBefore =
        tonumber(settings.text.secondsBefore) or 7

    settings.text.delayBy =
        tonumber(settings.text.delayBy) or 0

    settings.text.message =
        settings.text.message or "{spell} in {time}"
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
        tonumber(settings.audio.secondsBefore) or 3

    settings.audio.delayBy =
        tonumber(settings.audio.delayBy) or 0

    settings.audio.mode =
        settings.audio.mode or "tts"

    settings.audio.sound =
        settings.audio.sound or "None"

    settings.audio.channel =
        settings.audio.channel or "Master"

    settings.audio.ttsText =
        settings.audio.ttsText or "{spell} in {time}"

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
            label = thicknessOptions.label or "Marker thickness",
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
            label = "Marker color",
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
        text = "Ability Alerts"
    })))

    y = full(y, track(T:Description(rightPanel, {
        text =
            "Create configurable alerts based on BigWigs boss timers. "
            .. "Seconds before controls the countdown length. "
            .. "Delay by moves the entire alert later.",
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
    label = "Select ability",
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

    y = section(y, "Position")

    if bossKey == "EntombedSentinels" then
        if abilityMod.db.entombedAssignmentFilteringEnabled == nil then
            abilityMod.db.entombedAssignmentFilteringEnabled = true
        end

        local assignmentFiltering = checkbox({
            text = "Hide alerts using assignments",
            tooltip = "Mythic uses raid groups 1-2 as Green and groups 3-4 as Red. Normal and Heroic use #ESGreen/#ESRed from the note.",
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
        text = "Test all alerts",

        tooltip =
            "Tests all enabled alerts for every ability on this boss at the same time.",

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
        end,

        disabled = function()
            return isDisabled()
        end
    })

    y = full(y, testAllAlerts)

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
                settings.audio.ttsText = "Not safe to pickup"
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

        y = section(y, "Active difficulties")

        y = row(y, {
            checkbox({
                text = "Normal",
                labelTop = true,
                get = function() return settings.difficulties.normal end,
                onChange = function(value)
                    settings.difficulties.normal = value
                end
            }),
            checkbox({
                text = "Heroic",
                labelTop = true,
                get = function() return settings.difficulties.heroic end,
                onChange = function(value)
                    settings.difficulties.heroic = value
                end
            }),
            checkbox({
                text = "Mythic",
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
            text = "Test alert",

            tooltip = ability.kind == "mightyThudHits"
                and "Starts the full Mighty Thud bar immediately, including all three hit markers."
                or ability.kind == "ravenousFeastHits"
                and "Starts the full Ravenous Feast bar immediately, including your note-assignment highlight."
                or ability.kind == "mushroomTossJump"
                and "Tests the enabled BAIT and JUMP bars, skipping the 20-second gap."
                or ability.kind == "latestPickup"
                and "Tests the Latest Pickup bar and any enabled marker-relative audio immediately."
                or ability.kind == "howlingMaelstromWinds"
                and "Starts the complete 31.5-second WIND bar immediately."
                or ability.kind == "guillotineSequence"
                and "Starts the complete 11-second Hit/Explode bar immediately."
                or ability.kind == "beamBar"
                and "Starts the complete 18-second Beam bar immediately."
                or "Tests the currently enabled bar, text and audio settings.",

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
            y = section(y, "Timing")

            if ability.countdownTargetChoice then
                local countdownTarget = dropdown({
                    label = "Countdown target",
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
                    text = "Remove Cast Time Adjustments",
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
                text = "By default, the alert includes the "
                    .. tostring(ability.castTimeAdjustment)
                    .. " second cast time after the BigWigs event. "
                    .. "Removing the adjustment makes it count down to the BigWigs event instead.",
                sizeDelta = 0
            })))
        end

        -----------------------------------------------------------------------
        -- Bar
        -----------------------------------------------------------------------

        y = section(y, "Bar")

        local enableBar = rebuildCheckbox({
            text = "Enable bar",
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
                label = "Bar color",
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
                text = "Unattach from bar group anchor",
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
                    xInputLabel = "Bar X value",
                    yInputLabel = "Bar Y value"
                })
            end

            if ability.kind == "mightyThudHits" then
                local castTime = slider({
                    label = "Cast time", min = 0, max = 20, step = 0.1,
                    get = function() return settings.sequence.castTime end,
                    onChange = function(value)
                        settings.sequence.castTime =
                            math.floor(value * 10 + 0.5) / 10
                    end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local firstHitDelay = slider({
                    label = "First hit delay", min = 0.1, max = 5, step = 0.1,
                    get = function() return settings.sequence.firstHitDelay end,
                    onChange = function(value)
                        settings.sequence.firstHitDelay =
                            math.floor(value * 10 + 0.5) / 10
                    end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { castTime, firstHitDelay })

                local hitInterval = slider({
                    label = "Time between hits", min = 0.1, max = 5, step = 0.1,
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
                        label = "Marker thickness (pixels)",
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                local soakTextSize = slider({
                    label = "SOAK text size", min = 8, max = 40,
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
                    label = "SOAK text vertical offset",
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
                        label = "Marker thickness (pixels)",
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                local soakTextSize = slider({
                    label = "SOAK text size", min = 8, max = 40,
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
                    label = "SOAK text vertical offset",
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
                    text =
                        "The bar lasts 7 seconds. Markers show hits at 4, 5.5 and 7 seconds. "
                        .. "Your #TFFeast1, #TFFeast2 or #TFFeast3 assignment is highlighted in green with SOAK text.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "mushroomTossJump" then
                local enableBaitBar = checkbox({
                    text = "Enable BAIT bar",
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
                    text = "Enable JUMP bar",
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
                        label = "Marker thickness (seconds)",
                        min = 0.1,
                        max = 3,
                        step = 0.1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                y = full(y, track(T:Description(rightPanel, {
                    text =
                        "The BAIT bar lasts 7 seconds. After a 20-second gap, "
                        .. "the JUMP bar lasts 5 seconds. It is red for 3 seconds, "
                        .. "then shows a full-height marker centered on the fourth second. "
                        .. "The default marker thickness is 1 second and its default color is green.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "latestPickup" then
                local markerOffset = slider({
                    label = "Marker offset",
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
                        label = "Marker thickness (pixels)",
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                y = full(y, track(T:Description(rightPanel, {
                    text =
                        "Default is 6 second before sever hitting being marked as not same. "
                        .. "If you want it to be less than 6 seconds, you can adjust it by dragging the slider to the right. "
                        .. "If you want it to be more than 6 seconds you can slide the bar to the left",
                    sizeDelta = 0
                })))
            elseif ability.kind == "howlingMaelstromWinds" then
                local windMarkerColor = color({
                    label = "WIND marker color",
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
                    text =
                        "The bar starts with 4 seconds remaining on the BigWigs timer and lasts 31.5 seconds. "
                        .. "WIND 1 covers 5.5-13.5 seconds, WIND 2 covers 14.5-22.5 seconds, "
                        .. "and WIND 3 covers 23.5-31.5 seconds. The number always counts down to the next WIND.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "guillotineSequence" then
                y = markerAppearanceControls(
                    y,
                    settings.guillotineSequence,
                    {
                        label = "Marker thickness (pixels)",
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                local markerTextOffsetY = slider({
                    label = "Hit/Explode text vertical offset",
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
                    text =
                        "The bar starts when the Guillotine or Grim Guillotine BigWigs timer reaches 0. "
                        .. "It counts down 5 seconds to Hit, then resets and counts down 6 seconds to Explode at the end of the bar.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "beamBar" then
                y = full(y, track(T:Description(rightPanel, {
                    text =
                        "The bar starts when the Vile Flood BigWigs timer reaches 0. "
                        .. "It fills while the timer counts from 0 to 4, then empties while counting from 14 to 0. "
                        .. "The bar displays Beam throughout both phases.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "followupBar" then
                local mechanic = ability.mechanic or {}
                local startOffset = tonumber(mechanic.startOffset) or 0

                y = full(y, track(T:Description(rightPanel, {
                    text = "This bar starts "
                        .. (startOffset > 0
                            and (startOffset .. " seconds after ")
                            or "when ")
                        .. "the BigWigs timer reaches 0 and lasts "
                        .. tostring(mechanic.duration or 0)
                        .. " seconds.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "stagedFollowupBars" then
                y = full(y, track(T:Description(rightPanel, {
                    text = "After the adjusted Unstable Miasma hit, an 8-second Soak bar is followed by a 6-second Pool drop bar.",
                    sizeDelta = 0
                })))
            elseif ability.kind == "markerSequence" then
                y = markerAppearanceControls(
                    y,
                    settings.timelineMarkers,
                    {
                        label = "Marker thickness (pixels)",
                        min = 1,
                        max = 30,
                        step = 1
                    },
                    function()
                        return isDisabled() or not settings.enabled
                    end
                )

                y = full(y, track(T:Description(rightPanel, {
                    text = "The 6-second bar starts when Stir The Depths reaches 0 and has markers at 0, 2, 4 and 6 seconds.",
                    sizeDelta = 0
                })))
            else
                local barSeconds = slider({
                    label = "Seconds before", min = 1, max = 30,
                    get = function() return settings.bar.secondsBefore end,
                    onChange = function(value) settings.bar.secondsBefore = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barDelay = slider({
                    label = "Delay by", min = 0, max = 30,
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
                            label = "Cast marker thickness (pixels)",
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
                            tostring(stage.text or "Stage")
                            .. " for "
                            .. tostring(stage.duration or 0)
                            .. " seconds"
                    end

                    y = full(y, track(T:Description(rightPanel, {
                        text = "When the countdown reaches 0, the same bar continues with "
                            .. table.concat(stageDescriptions, " and then ")
                            .. ". Each follow-up bar counts up from 0, while its text alert counts down.",
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
                    label = "Custom bar name (blank uses ability name)",
                    get = function() return settings.bar.text end,
                    onChange = function(value) settings.bar.text = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = full(y, barText)

                if ability.kind == "mightyThudHits" then
                    y = full(y, track(T:Description(rightPanel, {
                        text =
                            "The bar duration is the cast time, first hit delay and two hit intervals combined. "
                            .. "Three markers show hit 1, hit 2 and hit 3. "
                            .. "Your #LEThud1, #LEThud2 or #LEThud3 note assignment highlights the matching marker in green with SOAK text. "
                            .. "Test alert starts the full bar immediately.",
                        sizeDelta = 0
                    })))
                end
            end

            local overrideBarAppearance = rebuildCheckbox({
                text = "Override default bar appearance",
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
                    label = "Bar width", min = 100, max = 800, step = 5,
                    get = function() return settings.bar.width end,
                    onChange = function(value) settings.bar.width = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barHeight = slider({
                    label = "Bar height", min = 10, max = 80,
                    get = function() return settings.bar.height end,
                    onChange = function(value) settings.bar.height = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barTexture = dropdown({
                    label = "Bar texture",
                    values = statusBarValues,
                    get = function() return settings.bar.texture end,
                    onChange = function(value) settings.bar.texture = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = row(y, { barWidth, barHeight, barTexture })

                if ability.kind == nil then
                    local barIconEnabled = checkbox({
                        text = "Enable ability icon",
                        labelTop = true,
                        get = function() return settings.bar.iconEnabled ~= false end,
                        onChange = function(value) settings.bar.iconEnabled = value end,
                        disabled = function() return isDisabled() or not settings.enabled end
                    })

                    local barIconSize = slider({
                        label = "Icon size", min = 8, max = 80,
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
                    label = "Background color",
                    get = function() return settings.bar.backgroundColor end,
                    onChange = function(r, g, b, a) settings.bar.backgroundColor = {r, g, b, a} end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                y = full(y, barBackgroundColor)

                local barFont = dropdown({
                    label = "Font", values = fontValues,
                    get = function() return settings.bar.font.name end,
                    onChange = function(value) settings.bar.font.name = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barFontSize = slider({
                    label = "Font size", min = 8, max = 40,
                    get = function() return settings.bar.font.size end,
                    onChange = function(value) settings.bar.font.size = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local barFontOutline = dropdown({
                    label = "Font outline",
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
            y = section(y, "Audio")

            local enableMushroomTTS = checkbox({
                text = "Enable BAIT/JUMP TTS",
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
                    label = "TTS voice",
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
                                text = "Jump",
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

        if ability.kind ~= "mightyThudHits"
            and ability.kind ~= "ravenousFeastHits"
            and ability.kind ~= "mushroomTossJump"
            and ability.kind ~= "latestPickup"
        then
            -------------------------------------------------------------------
            -- Text
            -------------------------------------------------------------------

        y = section(y, "Text")

        local enableText = rebuildCheckbox({
            text = "Enable text",
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
                text = "Unattach from text group anchor",
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
                    xInputLabel = "Text X value",
                    yInputLabel = "Text Y value"
                })
            end

            local textSeconds = slider({
                label = "Seconds before", min = 1, max = 30,
                get = function() return settings.text.secondsBefore end,
                onChange = function(value) settings.text.secondsBefore = math.floor(value) end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            local textDelay = slider({
                label = "Delay by", min = 0, max = 30,
                get = function() return settings.text.delayBy end,
                onChange = function(value) settings.text.delayBy = math.floor(value) end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            y = row(y, { textSeconds, textDelay })

            local showOneDecimal = checkbox({
                text = "Show one decimal",
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

            local textMessage = editBox({
                label = "Text message",
                get = function() return settings.text.message end,
                onChange = function(value) settings.text.message = value end,
                disabled = function() return isDisabled() or not settings.enabled end
            })

            y = full(y, textMessage)

            local overrideTextAppearance = rebuildCheckbox({
                text = "Override default text appearance",
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
                    label = "Font", values = fontValues,
                    get = function() return settings.text.font.name end,
                    onChange = function(value) settings.text.font.name = value end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local textFontSize = slider({
                    label = "Font size", min = 8, max = 72,
                    get = function() return settings.text.font.size end,
                    onChange = function(value) settings.text.font.size = math.floor(value) end,
                    disabled = function() return isDisabled() or not settings.enabled end
                })

                local textFontOutline = dropdown({
                    label = "Font outline",
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
        then

        -----------------------------------------------------------------------
        -- Audio
        -----------------------------------------------------------------------

        y = section(y, "Audio")

        local enableAudio = rebuildCheckbox({
            text = "Enable audio",
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
                and "Seconds before marker"
                or "Seconds before",
            min = ability.kind == "latestPickup" and 0 or 1,
            max = ability.kind == "latestPickup" and 3 or 30,
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

        local audioDelay = slider({
            label = ability.kind == "latestPickup"
                and "Delay after marker"
                or "Delay by",
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
        })

        y = row(y, {
            audioSeconds,
            audioDelay
        })

        local audioMode = dropdown({
            label = "Audio type",
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

        local audioCountdown = checkbox({
            text = "Countdown every second",
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
        })

        y = row(y, {
            audioMode,
            audioCountdown
        })

        local ttsText = editBox({
            label = "Text to Speech message",

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
    label = "TTS voice",

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
                text = "Voice test",
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
    label = "Sound file",

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
            label = "Sound channel",
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
                and "The default audio timing is exactly on the marker. Seconds before marker plays it earlier; Delay after marker plays it later."
                or "Variables: {spell} is replaced by the ability name. "
                    .. "{time} is replaced by the current countdown number.",
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
