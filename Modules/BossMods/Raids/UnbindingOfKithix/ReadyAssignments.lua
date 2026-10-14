local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Text = BossMods and BossMods.ReadyAssignmentText

if Text and Text.Register then
    local RAID_META = {
        raidKey = "UnbindingOfKithix",
        raidLabelKey = "BossMods_UnbindingOfKithix",
        tab = "UnbindingOfKithix"
    }
    local BOSS_META = {
        bossKey = "Kithix",
        bossLabelKey = "BossMods_Kithix",
        bossOrder = 10
    }

    local function withMeta(opts)
        for key, value in pairs(RAID_META) do
            opts[key] = opts[key] or value
        end
        for key, value in pairs(BOSS_META) do
            opts[key] = opts[key] or value
        end
        return opts
    end

    local REMINDERS = {
        {key = "kithixSoakOrange", tag = "SoakOrange", textKey = "BossMods_AR_KithixSoakOrange"},
        {key = "kithixSoakMoon", tag = "SoakMoon", textKey = "BossMods_AR_KithixSoakMoon"},
        {key = "kithixBackupOrange", tag = "BackupOrange", textKey = "BossMods_AR_KithixBackupOrange"},
        {key = "kithixBackupMoon", tag = "BackupMoon", textKey = "BossMods_AR_KithixBackupMoon"},
        {key = "kithixDispellCross", tag = "DispellCross", textKey = "BossMods_AR_KithixDispellCross"},
        {key = "kithixDispellStar", tag = "DispellStar", textKey = "BossMods_AR_KithixDispellStar"},
        {key = "kithixDispellSkull", tag = "DispellSkull", textKey = "BossMods_AR_KithixDispellSkull"},
        {key = "kithixCCBeetle", tag = "CCBeetle", textKey = "BossMods_AR_KithixCCBeetle"},
    }

    for index, def in ipairs(REMINDERS) do
        def.sheet = "KithixAssignments"
        def.labelKey = "BossMods_Kithix"
        def.itemLabelKey = "BossMods_NoteFull"
        def.source = "hashtag"
        def.type = def.key
        def.order = 10
        def.priority = 80 - index
        def.hashtagMultiline = true
        def.noteBlockSeparator = "\n"
        def.note = {tag = def.tag, template = "#" .. def.tag .. "\nPlayer1\nPlayer2\nPlayer3"}
        Text:Register(def.key, withMeta(def))
    end
end
