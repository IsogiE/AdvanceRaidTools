local E = unpack(ART)
if not E:IsForeverClient() then
    return
end

E.Forever.GeneralPack = {
    repairGearIcon = 22700,
    repairBotIcon = 22700,

    soulstoneItems = {16896, 16895, 16893, 16892, 5232},
    soulstoneAuras = {20762, 20763, 20764, 20765},

    consumableSpells = {
        [1225906] = "FEAST", -- Specklefin Feast
        [1307257] = "FEAST", -- Cookie's Feast
        [1307385] = "REPAIR", -- Repair Bot
        [1324661] = "REPAIR" -- Portable Repair Bot
    },

    unavailableAlerts = {
        gateway = true,
        gatewayShardMissing = true,
        unspentMotes = true,
        consumableCauldron = true,
        consumableSoulwell = true,
        chatHealthstone = true
    }
}
