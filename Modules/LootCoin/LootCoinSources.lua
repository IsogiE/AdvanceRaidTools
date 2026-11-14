local E = unpack(ART)
local LootCoin = E:GetModule("LootCoin")

LootCoin.sources = {
    {
        name = "Blackrock Depths",
        instanceID = 230,
        bosses = {
            {encounter = 227, npc = 9018, name = "High Interrogator Gerstahn"},
            {encounter = 228, npc = 9025, name = "Lord Roccor", coin = false},
            {encounter = 229, npc = 9319, name = "Houndmaster Grebmar", coin = false},
            {encounter = 230, name = "Ring of Law", coin = false},
            {encounter = 231, npc = 9024, name = "Pyromancer Loregrain"},
            {encounter = 232, npc = 9017, name = "Lord Incendius"},
            {encounter = 233, npc = 9041, name = "Warder Stilgiss"},
            {encounter = 234, npc = 9056, name = "Fineous Darkvire"},
            {encounter = 235, npc = 9016, name = "Bael'Gar"},
            {encounter = 236, npc = 9033, name = "General Angerforge"},
            {encounter = 237, npc = 8983, name = "Golem Lord Argelmach"},
            {encounter = 238, npc = 9537, name = "Hurley Blackbreath"},
            {encounter = 239, npc = 9502, name = "Phalanx"},
            {encounter = 240, npc = 9543, name = "Ribbly Screwspigot"},
            {encounter = 241, npc = 9499, name = "Plugger Spazzring"},
            {encounter = 242, npc = 9156, name = "Ambassador Flamelash"},
            {encounter = 244, npc = 9938, name = "Magmus"},
            {encounter = 2790, npc = 9019, name = "Emperor Dagran Thaurissan"},
            {encounter = 2789, npc = 8929, name = "Princess Moira Bronzebeard"},
        }
    },
    {
        name = "Dire Maul",
        instanceID = 429,
        bosses = {
            {encounter = 2792, npc = 14354, name = "Pusillin", coin = false},
            {encounter = 343, npc = 11490, name = "Zevrim Thornhoof"},
            {encounter = 344, npc = 13280, name = "Hydrospawn"},
            {encounter = 345, npc = 14327, name = "Lethtendris"},
            {encounter = 346, npc = 11492, name = "Alzzin the Wildshaper"},
            {encounter = 350, npc = 11489, name = "Tendris Warpwood"},
            {encounter = 347, npc = 11488, name = "Illyanna Ravenoak"},
            {encounter = 348, npc = 11487, name = "Magister Kalendris"},
            {encounter = 349, npc = 11496, name = "Immol'thar"},
            {encounter = 361, npc = 11486, name = "Prince Tortheldrin"},
            {encounter = 2793, npc = 14506, name = "Lord Hel'nurath"},
            {encounter = 362, npc = 14326, name = "Guard Mol'dar"},
            {encounter = 363, npc = 14322, name = "Stomper Kreeg"},
            {encounter = 364, npc = 14321, name = "Guard Fengus"},
            {encounter = 365, npc = 14323, name = "Guard Slip'kik"},
            {encounter = 366, npc = 14325, name = "Captain Kromcrush"},
            {encounter = 368, npc = 11501, name = "King Gordok"},
            {encounter = 367, npc = 14324, name = "Cho'Rush the Observer"},
        }
    },
    {
        name = "Blackmaw Hold",
        instanceID = 2974,
        bosses = {
            {encounter = 3315, npc = 247195, name = "Withermaw"},
            {encounter = 3316, npc = 247206, name = "Impaan the Imprisoner"},
            {encounter = 3327, npc = 247209, name = "Elder Shaman Bloodmane"},
            {encounter = 3322, npc = 247198, name = "Bonesnout the Unbroken"},
            {encounter = 3334, npc = 247234, name = "Varrox Bleakhoof"},
            {encounter = 3323, npc = 247207, name = "Blackmaw Behemoth"},
            {encounter = 3336, npc = 247231, name = "Unbound Spirit"},
        }
    },
    {
        name = "Lower Blackrock Spire",
        instanceID = 229,
        bosses = {
            {encounter = 267, npc = 9196, name = "Highlord Omokk"},
            {encounter = 268, npc = 9236, name = "Shadow Hunter Vosh'gajin"},
            {encounter = 269, npc = 9237, name = "War Master Voone"},
            {encounter = 270, npc = 10596, name = "Mother Smolderweb"},
            {encounter = 271, npc = 10584, name = "Urok Doomhowl"},
            {encounter = 272, npc = 9736, name = "Quartermaster Zigris"},
            {encounter = 273, npc = 10268, name = "Gizrul the Slavener"},
            {encounter = 274, npc = 10220, name = "Halycon"},
            {encounter = 275, npc = 9568, name = "Overlord Wyrmthalak"},
        }
    },
    {
        name = "Upper Blackrock Spire",
        instanceID = 229,
        bosses = {
            {encounter = 3062, npc = 9816, name = "Pyroguard Emberseer"},
            {encounter = 3063, npc = 10429, name = "Warchief Rend Blackhand"},
            {encounter = 3068, npc = 10430, name = "The Beast"},
            {encounter = 3069, npc = 10363, name = "General Drakkisath"},
            {encounter = 3070, npc = 16042, name = "Lord Valthalak"},
        }
    },
    {
        name = "Scholomance",
        instanceID = 289,
        bosses = {
            {encounter = 2805, npc = 10506, name = "Kirtonos the Herald"},
            {encounter = 2804, npc = 10503, name = "Jandice Barov"},
            {encounter = 2811, npc = 11622, name = "Rattlegore"},
            {encounter = 2809, npc = 10433, name = "Marduk Blackpool"},
            {encounter = 2813, npc = 10432, name = "Vectus"},
            {encounter = 2810, npc = 10508, name = "Ras Frostwhisper"},
            {encounter = 2803, npc = 10505, name = "Instructor Malicia"},
            {encounter = 2802, npc = 11261, name = "Doctor Theolen Krastinov"},
            {encounter = 2808, npc = 10901, name = "Lorekeeper Polkelt"},
            {encounter = 2812, npc = 10507, name = "The Ravenian"},
            {encounter = 2807, npc = 10504, name = "Lord Alexei Barov"},
            {encounter = 2806, npc = 10502, name = "Lady Illucia Barov"},
            {encounter = 2801, npc = 1853, name = "Darkmaster Gandling"},
            {encounter = 3055, npc = 16118, name = "Kormok"},
        }
    },
    {
        name = "Shaper's Terrace",
        instanceID = 3001,
        bosses = {
            {encounter = 3502, npc = 261809, name = "Nanaya"},
            {encounter = 3597, npc = 262297, name = "Snowtalon"},
            {encounter = 3503, npc = 261974, name = "Cinder"},
            {encounter = 3505, npc = 262081, name = "Bolt"},
        }
    },
    {
        name = "Stratholme",
        instanceID = 329,
        bosses = {
            {encounter = 474, npc = 10808, name = "Timmy the Cruel"},
            {encounter = 472, npc = 10516, name = "The Unforgiven"},
            {encounter = 473, npc = 10558, name = "Hearthsinger Forresten"},
            {encounter = 475, npc = 10997, name = "Cannon Master Willey"},
            {encounter = 477, npc = 10811, name = "Archivist Galford"},
            {encounter = 478, npc = 10813, name = "Balnazzar"},
            {encounter = 2798, npc = 11143, name = "Postmaster Malown"},
            {encounter = 482, npc = 10435, name = "Magistrate Barthilas"},
            {encounter = 479, npc = 10436, name = "Baroness Anastari"},
            {encounter = 480, npc = 10437, name = "Nerub'enkan"},
            {encounter = 481, npc = 10438, name = "Maleki the Pallid"},
            {encounter = 483, npc = 10439, name = "Ramstein the Gorger"},
            {encounter = 484, npc = 10440, name = "Baron Rivendare"},
        }
    },
    {
        name = "Onyxia's Lair",
        instanceID = 249,
        raid = true,
        enabled = false,
        bosses = {
            {encounter = 1084, npc = 10184, name = "Onyxia"},
        }
    }
}
