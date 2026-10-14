local E, L = unpack(ART)
local CL = BigWigsAPI:GetLocale("BigWigs: Common")

E.UnbindingOfKithixAbilityData = {
    {
        bossKey = "Kithix",
        bossName = L["BossMods_Kithix"],
        bossOrder = 10,
        abilities = {
            { spellID = 1301511, settingsKey = "Voidswarm", shortName = CL.adds, defaultBarColor = "00FFC3", defaultBarEnabled = true, defaultTextEnabled = false, order = 10 },
            { spellID = 1304424, settingsKey = "Extinguish", defaultBarColor = "FF0011", defaultBarEnabled = false, defaultTextEnabled = false, order = 20 },
            { spellID = 1304508, settingsKey = "Light's Embrace", shortName = CL.orbs, defaultBarColor = "F7FF00", defaultBarEnabled = false, defaultTextEnabled = false, order = 30 },
            { spellID = 1304045, settingsKey = "Unspeakable Horrors", shortName = CL.dispels, postHitStages = { countDown = true, stages = {{ duration = 6, text = CL.dispels }} }, defaultBarColor = "FF7400", defaultBarEnabled = true, defaultTextEnabled = false, order = 40 },
            { spellID = 1303681, settingsKey = "Twisted Appendage", shortName = L["BossMods_VA_Ability_GoreRattle"], postHitStages = { countDown = true, stages = {{ duration = 6.5, text = L["BossMods_VA_Ability_MephiticThrash"] }} }, defaultBarColor = "F7FF00", defaultBarEnabled = true, defaultTextEnabled = false, order = 50 },
            { spellID = 1304930, settingsKey = "Dark Devastation", shortName = CL.tank_bomb, defaultBarColor = "A335EE", defaultBarEnabled = false, defaultTextEnabled = false, order = 60 },
            { spellID = 1302951, settingsKey = "Suffocating Darkness", shortName = CL.intermission, defaultTextSecondsBefore = 5, defaultBarColor = "00FFC3", defaultBarEnabled = false, defaultTextEnabled = true, order = 70 },
            { spellID = 1303406, settingsKey = "Abyssal Grasp", shortName = CL.heal_absorbs, defaultTextSecondsBefore = 5, defaultBarColor = "F7FF00", defaultBarEnabled = false, defaultTextEnabled = true, order = 80 },
            { spellID = 1303169, settingsKey = "Divine Radiance", defaultBarColor = "00FFC3", defaultBarEnabled = false, defaultTextEnabled = false, order = 90 },
            { spellID = 1308873, settingsKey = "Null Gate", defaultBarColor = "F7FF00", defaultBarEnabled = false, defaultTextEnabled = false, order = 100 },
            { spellID = 1318467, settingsKey = "Negation", shortName = CL.tank_debuff, defaultBarColor = "A335EE", defaultBarEnabled = false, defaultTextEnabled = false, order = 110 },
            { spellID = 1301479, settingsKey = "Eightfold Eclipse", defaultBarColor = "FF0011", defaultBarEnabled = false, defaultTextEnabled = false, order = 120 },
        },
    },
}

local boss = E.UnbindingOfKithixAbilityData[1]
for _, ability in ipairs(boss.abilities) do
    ability.name = C_Spell.GetSpellName(ability.spellID) or tostring(ability.spellID)
end
boss.raidKey = "UnbindingOfKithix"
boss.featureKey = "UnbindingOfKithixKithix"
E:RegisterBossModFeature(boss.featureKey, {
    tab = "UnbindingOfKithix",
    order = 1,
    bossKey = "Kithix",
    bossLabelKey = "BossMods_Kithix",
    bossOrder = 10,
    navLabelKey = "BossMods_BossGeneral",
    labelKey = "BossMods_Kithix",
    moduleName = "BossMods_KithixAbilityAlerts"
})
