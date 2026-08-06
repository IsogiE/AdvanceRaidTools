local E = unpack(ART)

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

    -- BigWigs starts the intermission bar at 38 seconds and the Phase 4
    -- bars at 12.7/20 seconds. Keep the split working during reload states
    -- where the BigWigs stage is temporarily unavailable.
    duration = tonumber(duration)
    return duration ~= nil and duration <= 25
end

local function getSeasonAbilityData()
    local data = {}

    for _, source in ipairs({
        E.VoidspireAbilityData,
        E.DreamriftAbilityData,
        E.QueldanasAbilityData,
        E.SporefallAbilityData
    }) do
        for _, boss in ipairs(source or {}) do
            data[#data + 1] = boss
        end
    end

    return data
end

local LEGACY_FEATURE_KEYS = {
    DreamriftChimaerus = "VoidspireChimaerus",
    QueldanasBeloren = "VoidspireBeloren",
    QueldanasLura = "VoidspireLura",
    SporefallRotmire = "VoidspireRotmire"
}

local function migrateFeatureSettings(self, bossMods)
    local settings = bossMods
        and bossMods.db
        and bossMods.db.featureEnabled

    if not settings then
        return
    end

    for featureKey, legacyFeatureKey in pairs(LEGACY_FEATURE_KEYS) do
        if settings[featureKey] == nil
            and settings[legacyFeatureKey] ~= nil
        then
            settings[featureKey] = settings[legacyFeatureKey]
        end
    end
end

E:CreateAbilityAlertsModule({
    -- Kept for saved-variable and options compatibility. The data itself is
    -- now owned by its actual raid and each boss has the correct feature tab.
    moduleName = "BossMods_VoidspireAbilityAlerts",
    featurePrefix = "Voidspire",
    getAbilityData = getSeasonAbilityData,
    defaultAbilitySpellID = 1249262,
    presetVersionField = "voidspireBarPresetVersion",
    enableKindBarsWhenUnset = true,
    legacyFeatureKeys = LEGACY_FEATURE_KEYS,
    initialize = migrateFeatureSettings,
    difficultyKeyResolver = function(ability, difficultyID)
        if difficultyID == 233
            and ability
            and ability.raidKey == "Sporefall"
        then
            return "mythic"
        end
    end,
    resolveAbility = function(self, ability, spellID, duration)
        if spellID ~= STARSPLINTER_TRIGGER_SPELL_ID
            or not isStarsplinterPhaseFour(duration)
        then
            return ability, spellID
        end

        local triggered =
            self.triggeredAbilitiesBySpellID[STARSPLINTER_TRIGGER_SPELL_ID]

        for _, candidate in ipairs(triggered or {}) do
            if candidate.spellID == STARSPLINTER_PHASE_FOUR_SPELL_ID then
                return candidate, candidate.spellID
            end
        end

        return ability, spellID
    end
})
