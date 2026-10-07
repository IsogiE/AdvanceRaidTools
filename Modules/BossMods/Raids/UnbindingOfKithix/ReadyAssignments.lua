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
        -- Add Kith'ix assignment definitions here with key, sheet, labelKey,
        -- source, tag or noteBlock, and textKey.
    }

    for _, def in ipairs(REMINDERS) do
        Text:Register(def.key, withMeta(def))
    end
end
