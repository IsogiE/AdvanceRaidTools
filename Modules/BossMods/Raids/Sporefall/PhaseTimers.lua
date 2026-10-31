local E = unpack(ART)

local PHASE_TIMER_DATA = {
    encounters = {
        [3159] = {
            name = "Rotmire",
            difficulties = {
                Normal = {phases = {[1] = 0}},
                Heroic = {phases = {[1] = 0}},
                Mythic = {phases = {[1] = 0}}
            }
        }
    }
}

for encounterID, data in pairs(PHASE_TIMER_DATA.encounters) do
    E:RegisterEncounterPhaseTimers(encounterID, data)
end
