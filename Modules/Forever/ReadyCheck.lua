local E = unpack(ART)
if not E:IsForeverClient() then
    return
end

local RC = {}
E.Forever.ReadyCheck = RC

RC.FOOD_SPELLS = {
    [19705] = true,
    [19706] = true,
    [19708] = true,
    [19709] = true,
    [19710] = true,
    [19711] = true,
    [24799] = true,
    [24870] = true,
    [25694] = true,
    [25941] = true,
    [1225778] = true,
    [1225779] = true,
    [1225780] = true,
    [1225782] = true,
    [1248406] = true,
    [1248420] = true,
    [1248421] = true,
    [1248422] = true,
    [1248688] = true,
    [1249519] = true,
    [1249520] = true,
    [1249521] = true,
    [1249523] = true,
    [1249907] = true,
    [1249926] = true,
    [1249927] = true,
    [1283082] = true,
    [1294007] = true,
    [1302064] = true,
    [1319310] = true
}

RC.FLASK_SPELLS = {
    [17626] = true,
    [17627] = true,
    [17628] = true,
    [17629] = true,
    [17635] = true,
    [17636] = true,
    [17637] = true,
    [17638] = true,
    [1293559] = true,
    [1293560] = true,
    [1293561] = true,
    [1293562] = true,
    [1293740] = true,
    [1293741] = true,
    [1293742] = true,
    [1293743] = true
}

RC.RUNE_SPELLS = {}

RC.RAID_BUFF_SPELLS = {
    intellect = {
        [1459] = true,
        [1460] = true,
        [1461] = true,
        [10156] = true,
        [10157] = true,
        [13326] = true,
        [16876] = true,
        [364161] = true,
        [23028] = true
    },
    stamina = {
        [1243] = true,
        [1244] = true,
        [1245] = true,
        [2791] = true,
        [10937] = true,
        [10938] = true,
        [10939] = true,
        [10940] = true,
        [13864] = true,
        [23947] = true,
        [23948] = true,
        [21562] = true,
        [21564] = true,
        [450086] = true
    },
    attackPower = {
        [6673] = true,
        [5242] = true,
        [6192] = true,
        [11549] = true,
        [11550] = true,
        [11551] = true,
        [25289] = true,
        [9128] = true,
        [24438] = true,
        [25101] = true,
        [26043] = true,
        [26099] = true,
        [27578] = true
    },
    versatility = {
        [1126] = true,
        [5232] = true,
        [5234] = true,
        [5286] = true,
        [5287] = true,
        [6756] = true,
        [8907] = true,
        [8908] = true,
        [9884] = true,
        [9885] = true,
        [16878] = true,
        [24752] = true,
        [364163] = true,
        [1291335] = true,
        [1310503] = true,
        [21849] = true,
        [21850] = true
    },
    mastery = {},
    movement = {}
}

RC.FLASK_ITEM_GROUPS = {
    {13510}, -- Flask of the Titans
    {13511}, -- Flask of Distilled Wisdom
    {13512}, -- Flask of Supreme Power
    {13513}, -- Flask of Chromatic Resistance
    {274273}, -- Flask of Natural Accuracy
    {274274}, -- Flask of Natural Aggression
    {274275}, -- Flask of Natural Precision
    {274276} -- Flask of Natural Swiftness
}

RC.RUNE_ITEMS = {}

local SHARP_WEAPON_SUBCLASSES = {
    [0] = true, -- One-handed axe
    [1] = true, -- Two-handed axe
    [6] = true, -- Polearm
    [7] = true, -- One-handed sword
    [8] = true, -- Two-handed sword
    [13] = true, -- Fist weapon
    [15] = true -- Dagger
}
local BLUNT_WEAPON_SUBCLASSES = {
    [4] = true, -- One-handed mace
    [5] = true, -- Two-handed mace
    [10] = true, -- Staff
    [13] = true -- Fist weapon
}
local MELEE_WEAPON_SUBCLASSES = {}
for subclass in pairs(SHARP_WEAPON_SUBCLASSES) do MELEE_WEAPON_SUBCLASSES[subclass] = true end
for subclass in pairs(BLUNT_WEAPON_SUBCLASSES) do MELEE_WEAPON_SUBCLASSES[subclass] = true end

RC.WEAPON_ENCHANT_ITEM_GROUPS = {
    {items = {18262, 287980}, subclasses = SHARP_WEAPON_SUBCLASSES}, -- Elemental Sharpening Stone
    {items = {12404, 7964, 2871, 2863, 2862, 287978}, subclasses = SHARP_WEAPON_SUBCLASSES}, -- Sharpening Stones
    {items = {12643, 7965, 3241, 3240, 3239}, subclasses = BLUNT_WEAPON_SUBCLASSES}, -- Weightstones
    {items = {20749, 20750, 20746, 287979, 20744}, subclasses = MELEE_WEAPON_SUBCLASSES}, -- Wizard Oils
    {items = {20748, 20747, 20745}, subclasses = MELEE_WEAPON_SUBCLASSES}, -- Mana Oils
    {items = {23123}, subclasses = MELEE_WEAPON_SUBCLASSES}, -- Blessed Wizard Oil
    {items = {23122}, subclasses = SHARP_WEAPON_SUBCLASSES} -- Consecrated Sharpening Stone
}

RC.PERMANENT_ENCHANT_SLOTS = {
    {slot = 2, label = "NECKSLOT", fallback = "Neck"},
    {slot = 5, label = "CHESTSLOT", fallback = "Chest"},
    {slot = 8, label = "FEETSLOT", fallback = "Feet"},
    {slot = 9, label = "WRISTSLOT", fallback = "Wrist"},
    {slot = 10, label = "HANDSSLOT", fallback = "Hands"},
    {slot = 15, label = "BACKSLOT", fallback = "Back"},
    {slot = 16, label = "MAINHANDSLOT", fallback = "Main Hand"},
    {slot = 17, label = "SECONDARYHANDSLOT", fallback = "Off Hand"}
}

RC.HEALTHSTONE_ITEMS = {
    9421, 19012, 19013,
    5510, 19010, 19011,
    5509, 19008, 19009,
    5511, 19006, 19007,
    5512, 19004, 19005
}
RC.HEALTHSTONE_ITEM = 5512

E.Forever.RaidSupplies = {
    potions = {
        13446, 223913, 3928, 288896, 1710, 223914, 287977, 929, 858, 287967, 118, 287966,
        18839, 282011, 4596, 247239, 247240, 247241, 247242, 241650, 241655, 241656,
        268881, 268882, 268883
    }
}
