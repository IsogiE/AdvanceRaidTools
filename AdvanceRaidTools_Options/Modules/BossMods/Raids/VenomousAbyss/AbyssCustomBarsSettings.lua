local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6

local definitions = {
    {
        key = "CoiledAltarNightfallBar",
        labelKey = "BossMods_CoiledAltarNightfallBar",
        descKey = "BossMods_CoiledAltarNightfallBarDesc"
    },
    {
        key = "UlatekShriekerBar",
        labelKey = "BossMods_UlatekBrightscaleShrieker",
        descKey = "BossMods_UlatekShriekerBarDesc"
    }
}

local function createBuilder(definition)
    return function(rightPanel)
        local width = rightPanel:GetWidth() or 0
        if width <= 0 then
            return {}
        end

        local tracker = T:MakeTracker()
        local track = tracker.track
        local y = 0

        local function full(widget)
            y = y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
        end

        full(track(T:Header(rightPanel, {
            text = L[definition.labelKey]
        })))
        full(track(T:Description(rightPanel, {
            text = L[definition.descKey],
            sizeDelta = 1
        })))
        full(track(T:Description(rightPanel, {
            text = L["BossMods_AbyssCustomToggleHint"],
            sizeDelta = 0
        })))

        local totalHeight = math.max(y + 10, 1)
        rightPanel:SetHeight(totalHeight)
        return {
            height = totalHeight,
            Refresh = tracker.refresh,
            Release = tracker.release
        }
    end
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    for _, definition in ipairs(definitions) do
        BossMods:RegisterBossSettingsBuilder(
            definition.key,
            createBuilder(definition)
        )
    end
end
