local E = unpack(ART)

E:CreateAbilityAlertsModule({
    moduleName = "BossMods_KithixAbilityAlerts",
    featurePrefix = "UnbindingOfKithix",
    getAbilityData = function()
        return E.UnbindingOfKithixAbilityData
    end,
    difficultyKeyResolver = function(_, difficultyID)
        if difficultyID == 233 then
            return "mythic"
        end
    end
})
