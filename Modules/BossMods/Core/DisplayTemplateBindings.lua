local E, L = unpack(ART)
local Displays = E:GetModule("BossMods").DisplayTemplates

local function display(module, key, category, labelKey, path, order, sharedAnchor)
    Displays:Register("BossMods_" .. module, key, {
        category = category, label = L[labelKey], path = path or key, order = order,
        sharedAnchor = sharedAnchor
    })
end

display("SszorakMarkers", "buttons", "buttons", "BossMods_DisplayMarkerButtons", "buttons.position", 10)
display("SszorakMarkers", "bar", "panel", "BossMods_DisplayMarkerSelections", "bar.position", 20)
display("SszorakCompass", "position", "indicator", "BossMods_DisplayCompass")
display("UlatekFangs", "position", "aura", "BossMods_DisplayFangsPlayerList")
display("UlatekWrongTarget", "position", "text", "BossMods_DisplayWrongTargetReminder")
display("UlatekKicker", "position", "icon", "BossMods_DisplayKickIndicator", nil, 10)
display("UlatekKicker", "nextTextPosition", "text", "BossMods_DisplayNextKickReminder", nil, 20)
display("UlatekIntermission", "bar", "bar", "BossMods_DisplayIntermissionTimer", "bar.position", 10)
display("UlatekIntermission", "assignment", "panel", "BossMods_DisplayIntermissionAssignments", "assignment.position", 20)
display("UlatekIntermission", "clicker", "buttons", "BossMods_DisplayIntermissionButtons", "clicker.position", 30)
display("UlatekIntermission", "reminder", "panel", "BossMods_UlatekMovementReminder", "reminder.position", 40, "assignment")
display("TwinFangsDelugeBar", "position", "bar", "BossMods_DisplayPersonalDelugeBar")
display("TwinFangsDelugeList", "position", "aura", "BossMods_DisplayDelugePlayerList")
display("CoiledAltarIntermissionBar", "position", "bar", "BossMods_DisplayIntermissionTimer")
display("CoiledAltarKicker", "position", "icon", "BossMods_DisplayKickIndicator", nil, 10)
display("CoiledAltarKicker", "nextTextPosition", "text", "BossMods_DisplayNextKickReminder", nil, 20)
display("RavenousFeastSoakCircle", "position", "indicator", "BossMods_DisplaySoakCircle")

display("Feather", "position", "icon", "BossMods_DisplayFeatherIndicator")
display("DarkQuasar", "position", "bar", "BossMods_DisplayQuasarTimer")
display("Lurakick", "position", "panel", "BossMods_DisplayInterruptAssignments")
display("Dirge", "buttons", "buttons", "BossMods_DisplayMarkerButtons", "buttons.position", 10)
display("Dirge", "squad", "panel", "BossMods_DisplaySquadAssignments", "squad.position", 20)
display("Dirge", "bar", "panel", "BossMods_DisplayMarkerSequence", "bar.position", 30)
display("LuraMap", "intermission", "map", "BossMods_DisplayIntermissionMap", "anchors.intermission.position", 10)
display("LuraMap", "main", "map", "BossMods_DisplayMainMap", "anchors.main.position", 20)
