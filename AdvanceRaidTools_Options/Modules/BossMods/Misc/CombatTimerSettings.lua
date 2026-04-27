local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local JUSTIFY_VALUES = {
    LEFT = L["Left"],
    CENTER = L["Center"],
    RIGHT = L["Right"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local function buildFontValues()
    return E:MediaList("font")
end

local function buildCombatTimerBody(rightPanel, mod, isDisabled)
    local widthPx = rightPanel:GetWidth() or 0
    if widthPx <= 0 then
        return {}
    end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local refreshPanel = tracker.refresh

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        refreshPanel()
    end

    local y = 0

    local header = track(T:Header(rightPanel, {
        text = L["BossMods_CombatTimer"]
    }))
    y = y + T:PlaceFull(rightPanel, header, y, widthPx) + HEADER_GAP

    local desc = track(T:Description(rightPanel, {
        text = L["BossMods_CombatTimerDesc"],
        sizeDelta = 1
    }))
    y = y + T:PlaceFull(rightPanel, desc, y, widthPx) + ROW_GAP

    -- Font row
    local fontFace = track(T:Dropdown(rightPanel, {
        label = L["Font"],
        values = buildFontValues,
        get = function()
            return mod.db.font.face
        end,
        onChange = function(v)
            mod.db.font.face = v;
            refreshLive()
        end,
        disabled = isDisabled
    }))
    local fontSize = track(T:Slider(rightPanel, {
        label = L["FontSize"],
        min = 8,
        max = 48,
        step = 1,
        value = mod.db.font.size,
        get = function()
            return mod.db.font.size
        end,
        onChange = function(v)
            mod.db.font.size = math.floor(v);
            refreshLive()
        end,
        disabled = isDisabled
    }))
    y = y + T:PlaceRow(rightPanel, {fontFace, fontSize}, y, widthPx) + ROW_GAP

    local fontOutline = track(T:Dropdown(rightPanel, {
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.font.outline
        end,
        onChange = function(v)
            mod.db.font.outline = v;
            refreshLive()
        end,
        disabled = isDisabled
    }))
    local fontJustify = track(T:Dropdown(rightPanel, {
        label = L["BossMods_Justify"],
        values = JUSTIFY_VALUES,
        get = function()
            return mod.db.font.justify
        end,
        onChange = function(v)
            mod.db.font.justify = v;
            refreshLive()
        end,
        disabled = isDisabled
    }))
    y = y + T:PlaceRow(rightPanel, {fontOutline, fontJustify}, y, widthPx) + ROW_GAP

    local fontColor = track(T:ColorSwatch(rightPanel, {
        label = L["BossMods_FontColor"],
        labelTop = true,
        hasAlpha = true,
        r = mod.db.font.color[1],
        g = mod.db.font.color[2],
        b = mod.db.font.color[3],
        a = mod.db.font.color[4] or 1,
        onChange = function(r, g, b, a)
            mod.db.font.color = {r, g, b, a}
            refreshLive()
        end,
        disabled = isDisabled
    }))
    y = y + T:PlaceRow(rightPanel, {fontColor}, y, widthPx) + ROW_GAP

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.bar and mod.bar.frame,
        label = L["BossMods_CombatTimer"],
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
            y = 0
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
        BossMods:RegisterBossSettingsBuilder("CombatTimer", buildCombatTimerBody)
    end
end
