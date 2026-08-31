local E, L = unpack(ART)
local T = E.Templates

local ROW_GAP = 6
local HEADER_GAP = 10

local function clampInt(value, fallback)
    return math.floor((tonumber(value) or fallback or 0) + 0.5)
end

local function buildHealerAurasBody(rightPanel, mod, isDisabled)
    local width = rightPanel:GetWidth() or 0
    if width <= 0 then return {} end

    local tracker = T:MakeTracker()
    local track = tracker.track

    local function auraSettings()
        return mod:GetGloombombSettings()
    end

    local function refreshLive()
        mod:CallIfEnabled("Refresh")
        tracker.refresh()
    end

    local function full(y, widget)
        return y + T:PlaceFull(rightPanel, widget, y, width) + ROW_GAP
    end

    local function row(y, widgets)
        return y + T:PlaceRow(rightPanel, widgets, y, width) + ROW_GAP
    end

    local function section(y, key)
        local header = track(T:Header(rightPanel, {
            text = L[key] or key
        }))
        return y + T:PlaceFull(rightPanel, header, y, width) + HEADER_GAP
    end

    local y = 0
    y = full(y, track(T:Header(rightPanel, {
        text = L["BossMods_HealerAuras"]
    })))
    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_HealerAurasDesc"],
        sizeDelta = 1
    })))

    y = full(y, track(T:Dropdown(rightPanel, {
        label = L["BossMods_HealerAurasDebuff"],
        values = {gloombomb = L["BossMods_HealerAurasGloombomb"]},
        sorting = {"gloombomb"},
        get = function() return mod.db.selectedAura or "gloombomb" end,
        onChange = function(value)
            mod.db.selectedAura = value
            tracker.refresh()
        end,
        disabled = isDisabled
    })))

    y = full(y, track(T:Description(rightPanel, {
        text = L["BossMods_HealerAurasGloombombDesc"]
    })))

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_HealerAurasPreview"],
        get = function() return mod.previewMode and true or false end,
        onChange = function(_, value)
            mod:SetPreviewMode(value)
            tracker.refresh()
        end,
        disabled = isDisabled
    })))

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_HealerAurasEnableTracking"],
        get = function() return auraSettings().enabled ~= false end,
        onChange = function(_, value)
            auraSettings().enabled = value and true or false
            refreshLive()
        end,
        disabled = isDisabled
    })))

    local function auraDisabled()
        return isDisabled() or auraSettings().enabled == false
    end

    local showIcon = track(T:Checkbox(rightPanel, {
        text = L["BossMods_HealerAurasShowIcon"],
        get = function() return auraSettings().showIcon ~= false end,
        onChange = function(_, value)
            auraSettings().showIcon = value and true or false
            refreshLive()
        end,
        disabled = auraDisabled
    }))
    local iconSize = track(T:Slider(rightPanel, {
        label = L["BossMods_HealerAurasIconSize"],
        min = 12,
        max = 100,
        step = 1,
        value = auraSettings().iconSize or 36,
        get = function() return auraSettings().iconSize or 36 end,
        onChange = function(value)
            auraSettings().iconSize = value
            refreshLive()
        end,
        disabled = function()
            return auraDisabled() or auraSettings().showIcon == false
        end
    }))
    y = row(y, {showIcon, iconSize})

    y = section(y, "BossMods_HealerAurasPositionSection")

    y = T:XYOffsetControls(rightPanel, y, width, {
        tracker = tracker,
        getPosition = function()
            return auraSettings().iconPosition
        end,
        setPosition = function(position)
            auraSettings().iconPosition = position
        end,
        onChanged = refreshLive,
        disabled = function()
            return auraDisabled() or auraSettings().showIcon == false
        end,
        anchorLabel = L["BossMods_HealerAurasIconAnchor"],
        descriptionText = L["BossMods_HealerAurasIconPositionDesc"],
        xInputLabel = L["BossMods_HealerAurasIconX"],
        yInputLabel = L["BossMods_HealerAurasIconY"]
    })

    y = full(y, track(T:Checkbox(rightPanel, {
        text = L["BossMods_HealerAurasShowGlow"],
        get = function() return auraSettings().showGlow == true end,
        onChange = function(_, value)
            auraSettings().showGlow = value and true or false
            refreshLive()
        end,
        disabled = auraDisabled
    })))

    local function glowDisabled()
        return auraDisabled() or auraSettings().showGlow ~= true
    end

    local glowType = track(T:Dropdown(rightPanel, {
        label = L["BossMods_HealerAurasGlowType"],
        values = E:GetModule("BossMods").Alerts:GetGlowTypes(),
        get = function() return auraSettings().glowType or "Pixel" end,
        onChange = function(value)
            auraSettings().glowType = value
            refreshLive()
        end,
        disabled = glowDisabled
    }))
    local current = auraSettings().glowColor or {}
    local glowColor = track(T:ColorSwatch(rightPanel, {
        label = L["BossMods_HealerAurasGlowColor"],
        labelTop = true,
        hasAlpha = true,
        r = current[1] or current.r or 0.55,
        g = current[2] or current.g or 0.20,
        b = current[3] or current.b or 1,
        a = current[4] or current.a or 1,
        get = function()
            local color = auraSettings().glowColor or {}
            return color[1] or color.r or 0.55,
                color[2] or color.g or 0.20,
                color[3] or color.b or 1,
                color[4] or color.a or 1
        end,
        onChange = function(r, g, b, a)
            auraSettings().glowColor = {r, g, b, a}
            refreshLive()
        end,
        disabled = glowDisabled
    }))
    y = row(y, {glowType, glowColor})

    local glowLines = track(T:Slider(rightPanel, {
        label = L["BossMods_HealerAurasGlowLines"],
        min = 1,
        max = 20,
        step = 1,
        value = auraSettings().glowLines or 8,
        get = function() return auraSettings().glowLines or 8 end,
        onChange = function(value)
            auraSettings().glowLines = clampInt(value, 8)
            refreshLive()
        end,
        disabled = function()
            if glowDisabled() then return true end
            local glowType = auraSettings().glowType or "Pixel"
            return glowType ~= "Pixel" and glowType ~= "Autocast"
        end
    }))
    local glowThickness = track(T:Slider(rightPanel, {
        label = L["BossMods_HealerAurasGlowThickness"],
        min = 1,
        max = 10,
        step = 1,
        value = auraSettings().glowThickness or 2,
        get = function() return auraSettings().glowThickness or 2 end,
        onChange = function(value)
            auraSettings().glowThickness = clampInt(value, 2)
            refreshLive()
        end,
        disabled = function()
            return glowDisabled() or (auraSettings().glowType or "Pixel") ~= "Pixel"
        end
    }))
    y = row(y, {glowLines, glowThickness})

    local glowFrequency = track(T:Slider(rightPanel, {
        label = L["BossMods_HealerAurasGlowFrequency"],
        min = 0,
        max = 20,
        step = 1,
        value = auraSettings().glowFrequency or 3,
        get = function() return auraSettings().glowFrequency or 3 end,
        onChange = function(value)
            auraSettings().glowFrequency = clampInt(value, 3)
            refreshLive()
        end,
        disabled = glowDisabled
    }))
    local glowScale = track(T:Slider(rightPanel, {
        label = L["BossMods_HealerAurasGlowScale"],
        min = 5,
        max = 30,
        step = 1,
        value = auraSettings().glowScale or 10,
        get = function() return auraSettings().glowScale or 10 end,
        onChange = function(value)
            auraSettings().glowScale = clampInt(value, 10)
            refreshLive()
        end,
        disabled = function()
            return glowDisabled() or (auraSettings().glowType or "Pixel") ~= "Autocast"
        end
    }))
    y = row(y, {glowFrequency, glowScale})

    local totalHeight = math.max(y + 10, 1)
    rightPanel:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetPreviewMode(false)
            tracker.release()
        end
    }
end

local BossMods = E:GetModule("BossMods", true)
if BossMods then
    BossMods:RegisterBossSettingsBuilder("HealerAuras", buildHealerAurasBody)
end
