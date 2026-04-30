local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"]
}

local ROW_GAP = 6
local HEADER_GAP = 10

local ALERT_TOGGLES = {{
    key = "summonPet",
    label = "BossMods_GP_SummonPet"
}, {
    key = "petPassive",
    label = "BossMods_GP_PetPassive"
}, {
    key = "repairGear",
    label = "BossMods_GP_RepairGear"
}, {
    key = "consumableRepair",
    label = "BossMods_GP_RepairBot"
}, {
    key = "healthstoneMissing",
    label = "BossMods_GP_HealthstoneMissing"
}, {
    key = "consumableSoulwell",
    label = "BossMods_GP_Soulwell"
}, {
    key = "applySoulstone",
    label = "BossMods_GP_ApplySoulstone"
}, {
    key = "consumableFeast",
    label = "BossMods_GP_Feast"
}, {
    key = "consumableCauldron",
    label = "BossMods_GP_Cauldron"
}, {
    key = "gateway",
    label = "BossMods_GP_Gateway"
}, {
    key = "chatHealthstone",
    label = "BossMods_GP_ChatHealthstone"
}, {
    key = "chatSummonStone",
    label = "BossMods_GP_ChatSummonStone"
}}

local function borderValues()
    local t = E:MediaList("border")
    t["None"] = nil
    return t
end

local function buildGeneralPackBody(rightPanel, mod, isDisabled)
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

    local function slider(opts)
        return track(T:Slider(rightPanel, {
            label = opts.label,
            min = opts.min,
            max = opts.max,
            step = opts.step or 1,
            value = opts.get(),
            get = opts.get,
            isPercent = opts.isPercent,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function checkbox(opts)
        return track(T:Checkbox(rightPanel, {
            text = opts.text,
            labelTop = opts.labelTop,
            tooltip = opts.tooltip,
            get = opts.get,
            onChange = function(_, v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function dropdown(opts)
        return track(T:Dropdown(rightPanel, {
            label = opts.label,
            values = opts.values,
            get = opts.get,
            onChange = function(v)
                opts.onChange(v)
                refreshLive()
            end,
            disabled = opts.disabled or isDisabled
        }))
    end

    local function color(opts)
        local c = opts.get()
        return track(T:ColorSwatch(rightPanel, {
            label = opts.label,
            labelTop = true,
            hasAlpha = opts.hasAlpha ~= false,
            r = c[1] or c.r or 1,
            g = c[2] or c.g or 1,
            b = c[3] or c.b or 1,
            a = c[4] or c.a or 1,
            onChange = function(r, g, b, a)
                opts.onChange(r, g, b, a)
                refreshLive()
            end,
            disabled = isDisabled
        }))
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, widthPx) + ROW_GAP
    end
    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, widthPx) + ROW_GAP
    end
    local function section(y, key)
        local h = track(T:Header(rightPanel, {
            text = L[key] or key
        }))
        return y + T:PlaceFull(rightPanel, h, y, widthPx) + HEADER_GAP
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_GeneralPack"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_GeneralPackDesc"],
        sizeDelta = 1
    })))

    local unlockY, unlockCtrl = T:UnlockController(rightPanel, y, widthPx, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(v)
            mod:SetEditMode(v)
        end
    })
    y = unlockY

    local enableBg = checkbox({
        text = L["BossMods_BgEnable"],
        labelTop = true,
        get = function()
            return mod.db.background.enabled
        end,
        onChange = function(v)
            mod.db.background.enabled = v
        end
    })
    local enableBorder = checkbox({
        text = L["BossMods_BorderEnable"],
        labelTop = true,
        get = function()
            return mod.db.border.enabled
        end,
        onChange = function(v)
            mod.db.border.enabled = v
        end
    })
    y = row(y, {enableBg, enableBorder})

    y = section(y, "Font")
    local fontSize = slider({
        label = L["FontSize"],
        min = 10,
        max = 36,
        get = function()
            return mod.db.font.size
        end,
        onChange = function(v)
            mod.db.font.size = math.floor(v)
        end
    })
    local fontOutline = dropdown({
        label = L["Outline"],
        values = OUTLINE_VALUES,
        get = function()
            return mod.db.font.outline
        end,
        onChange = function(v)
            mod.db.font.outline = v
        end
    })
    y = row(y, {fontSize, fontOutline})

    local fontColor = color({
        label = L["BossMods_FontColor"],
        hasAlpha = true,
        get = function()
            return mod.db.font.color
        end,
        onChange = function(r, g, b, a)
            mod.db.font.color = {r, g, b, a}
        end
    })
    y = row(y, {fontColor})

    y = section(y, "Background")
    local bgOpacity = slider({
        label = L["BackgroundOpacity"],
        min = 0,
        max = 1,
        step = 0.05,
        get = function()
            return mod.db.background.opacity
        end,
        onChange = function(v)
            mod.db.background.opacity = v
        end
    })
    local bgColor = color({
        label = L["BossMods_BgColor"],
        hasAlpha = false,
        get = function()
            return mod.db.background.color
        end,
        onChange = function(r, g, b)
            mod.db.background.color = {r, g, b}
        end
    })
    y = row(y, {bgOpacity, bgColor})

    y = section(y, "Border")
    local borderTex = dropdown({
        label = L["BossMods_BorderTexture"],
        values = borderValues,
        get = function()
            return mod.db.border.texture
        end,
        onChange = function(v)
            mod.db.border.texture = v
        end
    })
    y = row(y, {borderTex})

    local borderSize = slider({
        label = L["BossMods_BorderSize"],
        min = 1,
        max = 16,
        get = function()
            return mod.db.border.size
        end,
        onChange = function(v)
            mod.db.border.size = math.floor(v)
        end
    })
    local borderColor = color({
        label = L["BorderColor"],
        hasAlpha = true,
        get = function()
            return mod.db.border.color
        end,
        onChange = function(r, g, b, a)
            mod.db.border.color = {r, g, b, a}
        end
    })
    y = row(y, {borderSize, borderColor})

    y = section(y, "BossMods_GP_Tuning")
    local durSlider = slider({
        label = L["BossMods_GP_DurabilityThreshold"],
        min = 0.05,
        max = 0.95,
        step = 0.05,
        isPercent = true,
        get = function()
            return mod.db.durabilityThreshold or 0.30
        end,
        onChange = function(v)
            mod.db.durabilityThreshold = v
        end
    })
    local holdSlider = slider({
        label = L["BossMods_GP_TransientDuration"],
        min = 2,
        max = 20,
        get = function()
            return mod.db.transientDuration or 6
        end,
        onChange = function(v)
            mod.db.transientDuration = math.floor(v)
        end
    })
    y = row(y, {durSlider, holdSlider})

    y = section(y, "BossMods_GP_AlertsSection")
    local rowWidgets = {}
    for i, def in ipairs(ALERT_TOGGLES) do
        local key = def.key
        local cb = checkbox({
            text = L[def.label] or def.label,
            labelTop = false,
            get = function()
                local v = mod.db.alerts[key]
                return v ~= false
            end,
            onChange = function(v)
                mod.db.alerts[key] = v and true or false
            end
        })
        rowWidgets[#rowWidgets + 1] = cb
        if #rowWidgets == 2 or i == #ALERT_TOGGLES then
            y = row(y, rowWidgets)
            rowWidgets = {}
        end
    end

    local posNewY, posHandle = T:PositionSection(rightPanel, y, widthPx, {
        anchor = mod.frame,
        label = L["BossMods_GeneralPack"],
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
            y = 200
        },
        onChanged = refreshLive,
        isDisabled = isDisabled,
        unlockController = unlockCtrl,
        showOffsets = true
    })
    y = posNewY

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)

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

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("GeneralPack", buildGeneralPackBody)
    end
end
