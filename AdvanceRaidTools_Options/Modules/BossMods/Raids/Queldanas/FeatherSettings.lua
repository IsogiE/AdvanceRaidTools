local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local function buildFeatherBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local refreshPanel = tracker.refresh

    local function refreshLive()
        mod:CallIfEnabled("Apply")
        refreshPanel()
    end

    local y = 0

    local header = track(T:Header(rightPanel, {
        text = L["BossMods_Feather"]
    }))
    y = y + T:PlaceFull(rightPanel, header, y, widthPx) + HEADER_GAP

    local desc = track(T:Description(rightPanel, {
        text = L["BossMods_FeatherDesc"],
        sizeDelta = 1
    }))
    y = y + T:PlaceFull(rightPanel, desc, y, widthPx) + ROW_GAP

    local iconSize = track(T:Slider(rightPanel, {
        label = L["BossMods_IconSize"],
        min = 16,
        max = 256,
        step = 1,
        value = mod.db.iconSize,
        get = function()
            return mod.db.iconSize
        end,
        onChange = function(v)
            mod.db.iconSize = math.floor(v)
            refreshLive()
        end,
        disabled = isDisabled
    }))
    y = y + T:PlaceRow(rightPanel, {iconSize}, y, widthPx) + ROW_GAP

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.frame,
        label = L["BossMods_Feather"],
        tracker = tracker,
        getPosition = function()
            return {
                point = mod.db.position.point,
                x = mod.db.position.x,
                y = mod.db.position.y
            }
        end,
        setPosition = function(pos)
            mod:SavePosition(pos)
        end,
        defaultPosition = {
            point = "CENTER",
            x = 0,
            y = 400
        },
        onChanged = refreshLive,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end,
        isDisabled = isDisabled
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            posHandle.Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("Feather", buildFeatherBody)
    end
end
