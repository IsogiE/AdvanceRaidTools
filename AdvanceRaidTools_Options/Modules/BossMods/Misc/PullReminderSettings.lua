local E, L = unpack(ART)
local T = E.Templates

local OUTLINE_VALUES = {
    [""] = L["None"],
    OUTLINE = L["Outline"],
    THICKOUTLINE = L["ThickOutline"],
    OUTLINE_SLUG = L["BossMods_AAOptions_SlugOutline"]
}
local OUTLINE_ORDER = {"", "OUTLINE", "THICKOUTLINE", "OUTLINE_SLUG"}

local function buildPullReminderBody(parent, mod, isDisabled)
    local width = parent:GetWidth() or 0
    if width <= 0 then
        return {}
    end
    mod:EnsureSettings()

    local tracker = T:MakeTracker()
    local track = tracker.track
    local y = 0
    local gap = 8

    local function refresh()
        mod:Refresh()
        tracker.refresh()
    end

    local function full(widget)
        y = y + T:PlaceFull(parent, widget, y, width) + gap
    end

    local function row(widgets)
        y = y + T:PlaceRow(parent, widgets, y, width) + gap
    end

    local header = track(T:Header(parent, {
        text = L["BossMods_PullReminder"]
    }))
    full(header)

    local description = track(T:Description(parent, {
        text = L["BossMods_PullReminderDesc"],
        sizeDelta = 1
    }))
    full(description)

    local unlockY, unlockController = T:UnlockController(parent, y, width, {
        tracker = tracker,
        isDisabled = isDisabled,
        onEditModeChanged = function(value)
            mod:SetEditMode(value)
        end
    })
    y = unlockY
    full(T:PreviewToggle(parent, {
        module = mod,
        tracker = tracker,
        disabled = isDisabled
    }))

    full(track(T:Header(parent, {text = L["BossMods_RFSCTextAppearance"]})))

    local fontDropdown = track(T:Dropdown(parent, {
        label = L["Font"],
        values = function() return E:MediaList("font") end,
        get = function() return mod.db.font.name end,
        onChange = function(value)
            mod.db.font.name = value
            refresh()
        end,
        disabled = isDisabled
    }))
    local sizeSlider = track(T:Slider(parent, {
        label = L["BossMods_AAOptions_FontSize"],
        min = 8,
        max = 100,
        step = 1,
        value = mod.db.font.size or 48,
        get = function() return mod.db.font.size or 48 end,
        onChange = function(value)
            mod.db.font.size = math.floor(value + 0.5)
            refresh()
        end,
        disabled = isDisabled
    }))
    local outlineDropdown = track(T:Dropdown(parent, {
        label = L["Outline"],
        values = OUTLINE_VALUES,
        sorting = OUTLINE_ORDER,
        get = function() return mod.db.font.outline or "" end,
        onChange = function(value)
            mod.db.font.outline = value or ""
            refresh()
        end,
        disabled = isDisabled
    }))
    row({fontDropdown, sizeSlider, outlineDropdown})

    local color = mod.db.font.color or {1, 0.82, 0, 1}
    full(track(T:ColorSwatch(parent, {
        label = L["BossMods_RFSCTextColor"],
        labelTop = true,
        hasAlpha = true,
        r = color[1] or 1,
        g = color[2] or 0.82,
        b = color[3] or 0,
        a = color[4] or 1,
        onChange = function(r, g, b, a)
            mod.db.font.color = {r, g, b, a}
            refresh()
        end,
        disabled = isDisabled
    })))

    local positionY, positionHandle = T:PositionSection(parent, y, width, {
        anchor = mod:GetAnchor(),
        label = L["BossMods_PullReminder"],
        headerText = L["Position"],
        tracker = tracker,
        getPosition = function()
            local position = mod:GetPosition()
            return {point = position.point, x = position.x, y = position.y}
        end,
        setPosition = function(position)
            mod:SavePosition(position)
        end,
        resetPosition = function() mod:ResetPosition() end,
        resetConfirm = L["BossMods_ResetAnchorPositionConfirm"]:format(L["BossMods_PullReminder"]),
        resetConfirmTitle = L["ResetPosition"],
        onChanged = refresh,
        isDisabled = isDisabled,
        unlockController = unlockController,
        showOffsets = true
    })
    y = positionY

    full(track(T:Header(parent, {text = L["Audio"]})))
    local audioEnabled = track(T:Checkbox(parent, {
        text = L["TextToSpeech"],
        labelTop = true,
        get = function() return mod.db.audio.enabled == true end,
        onChange = function(_, value)
            mod.db.audio.enabled = value and true or false
            tracker.refresh()
        end,
        disabled = isDisabled
    }))
    full(audioEnabled)

    local function audioDisabled()
        return isDisabled() or mod.db.audio.enabled ~= true
    end
    local voiceDropdown = track(T:Dropdown(parent, {
        label = L["BossMods_AAOptions_TTSVoice"],
        values = function()
            return E:GetModule("BossMods").Alerts:GetTTSVoices()
        end,
        get = function() return mod.db.audio.voiceID or 0 end,
        onChange = function(value)
            mod.db.audio.voiceID = value
        end,
        disabled = audioDisabled
    }))
    local testButton = track(T:LabelAlignedButton(parent, {
        text = L["BossMods_AAOptions_VoiceTest"],
        onClick = function()
            E:GetModule("BossMods").Alerts:SpeakTTS({
                text = L["BossMods_PullReminderPreview"],
                voiceID = mod.db.audio.voiceID or 0
            })
        end,
        disabled = audioDisabled
    }))
    row({voiceDropdown, testButton})

    local totalHeight = math.max(y + 10, 1)
    parent:SetHeight(totalHeight)
    return {
        height = totalHeight,
        Refresh = tracker.refresh,
        Release = function()
            mod:SetEditMode(false)
            positionHandle.Release()
            unlockController:Release()
            tracker.release()
        end
    }
end

do
    local BossMods = E:GetModule("BossMods", true)
    if BossMods and BossMods.RegisterBossSettingsBuilder then
        BossMods:RegisterBossSettingsBuilder("PullReminder", buildPullReminderBody)
    end
end
