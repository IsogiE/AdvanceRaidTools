local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local SHOW_WHEN_VALUES = {
    always = L["Always"],
    group = L["BossMods_RaidDebuffsInGroup"],
    raid = L["InRaid"]
}
local SHOW_WHEN_ORDER = {"always", "group", "raid"}

local function debuffText(mod, entry)
    return ("|T%s:16:16:0:0:64:64:5:59:5:59|t %s%s|r"):format(
        mod.SpellIcon(entry), E:ClassColorCode(entry.class), mod.SpellName(entry))
end

local function buildRaidDebuffsBody(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then return {} end

    local tracker = T:MakeTracker()
    local track = tracker.track
    local y = 0

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
    end

    local function full(widget)
        y = y + T:PlaceFull(parent, widget, y, width) + ROW_GAP
    end

    local function row(widgets)
        y = y + T:PlaceRow(parent, widgets, y, width) + ROW_GAP
    end

    local function section(textKey)
        local h = track(T:Header(parent, {text = L[textKey] or textKey}))
        y = y + T:PlaceFull(parent, h, y, width) + HEADER_GAP
    end

    local function checkbox(text, get, set)
        return track(T:Checkbox(parent, {
            text = text,
            labelTop = false,
            get = get,
            onChange = function(_, v)
                set(v)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local function slider(label, min, max, key)
        return track(T:Slider(parent, {
            label = label,
            min = min,
            max = max,
            step = 1,
            value = mod.db[key],
            get = function() return mod.db[key] end,
            onChange = function(v)
                mod.db[key] = math.floor(v)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    full(track(T:Header(parent, {text = L["BossMods_RaidDebuffs"]})))
    full(track(T:Description(parent, {text = L["BossMods_RaidDebuffsDesc"], sizeDelta = 1})))

    local unlockY, unlockCtrl = T:UnlockController(parent, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(v) mod:SetEditMode(v) end
    })
    y = unlockY

    section("Visibility")
    local showWhen = track(T:Dropdown(parent, {
        label = L["BossMods_ShowWhen"],
        values = SHOW_WHEN_VALUES,
        sorting = SHOW_WHEN_ORDER,
        get = function() return mod.db.showWhen end,
        onChange = function(v)
            mod.db.showWhen = v
            refreshLive()
        end,
        disabled = isDisabled
    }))
    local highlight = track(T:Checkbox(parent, {
        text = L["BossMods_RaidDebuffsHighlight"],
        labelTop = true,
        tooltip = {title = L["BossMods_RaidDebuffsHighlight"], desc = L["BossMods_RaidDebuffsHighlightDesc"]},
        get = function() return mod.db.highlightMissing == true end,
        onChange = function(_, v)
            mod.db.highlightMissing = v and true or false
            refreshLive()
        end,
        disabled = isDisabled
    }))
    row({showWhen, highlight})

    section("Icon")
    row({slider(L["Icon"] .. " " .. L["Size"], 16, 64, "iconSize"), slider(L["BossMods_IconSpacing"], 0, 20, "iconPad")})
    row({slider(L["BossMods_RaidDebuffsPerRow"], 1, #mod.DEBUFFS, "perRow")})

    section("BossMods_RaidDebuffsList")
    local pair = {}
    for i, entry in ipairs(mod.DEBUFFS) do
        local key = entry.key
        pair[#pair + 1] = checkbox(debuffText(mod, entry),
            function() return mod.db.debuffs[key] == true end,
            function(v) mod.db.debuffs[key] = v and true or false end)
        if #pair == 2 or i == #mod.DEBUFFS then
            row(pair)
            pair = {}
        end
    end

    local posY, posHandle = T:PositionSection(parent, y, width, {
        anchor = function() return mod.holder end,
        label = L["BossMods_RaidDebuffs"],
        tracker = tracker,
        getPosition = function()
            return {point = mod.db.position.point, x = mod.db.position.x, y = mod.db.position.y}
        end,
        setPosition = function(pos) mod:SavePosition(pos) end,
        defaultPosition = {point = "CENTER", x = 0, y = -120},
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = posY

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            posHandle.Release()
            unlockCtrl:Release()
            tracker.release()
        end
    }
end

if E:IsForeverClient() then
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("RaidDebuffs", buildRaidDebuffsBody)
    end
end
