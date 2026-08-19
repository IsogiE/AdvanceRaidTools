local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local WHITE = Shared.WHITE
local fetchStatusBar = Shared.FetchStatusBar
local fetchBorder = Shared.FetchBorder
local colorTuple = Shared.ColorTuple
local applyFontTo = Shared.ApplyFontTo

function Engines.Bar(config)
    assert(type(config) == "table", "Engines.Bar: config required")
    assert(config.parent, "Engines.Bar: config.parent required")

    local showFill = config.showFill ~= false
    local parent = config.parent

    local frameType = showFill and "StatusBar" or "Frame"
    local frame = CreateFrame(frameType, nil, parent, "BackdropTemplate")
    frame:SetFrameStrata(config.strata or "HIGH")
    frame:Hide()

    if showFill then
        frame:SetMinMaxValues(0, 1)
        frame:SetValue(0)
    end

    local labelFS = frame:CreateFontString(nil, "OVERLAY")
    local rightFS = frame:CreateFontString(nil, "OVERLAY")
    local centerFS = frame:CreateFontString(nil, "OVERLAY")
    local middleFS = frame:CreateFontString(nil, "OVERLAY")
    local icon = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:Hide()
    local marker = frame:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(1, 1, 1, 1)
    marker:SetWidth(2)
    marker:Hide()

    -- Active countdown state
    local running = false
    local startTime, totalDuration, safeDuration
    local mode, markerRatio
    local lastRightUpdate = 0
    local pendingRightText

    local handle = {
        frame = frame
    }

    local function applyMode()
        if mode == "center" then
            labelFS:Hide()
            rightFS:Hide()
            middleFS:Hide()
            marker:Hide()
            centerFS:Show()
        else
            centerFS:Hide()
            labelFS:Show()
            rightFS:Show()
            middleFS:Show()
            if markerRatio then
                marker:Show()
            else
                marker:Hide()
            end
        end
    end

    function handle:SetMode(m)
        if m ~= "center" and m ~= "label" then
            return
        end
        mode = m
        applyMode()
    end

    function handle:SetColor(r, g, b, a)
        if showFill then
            frame:SetStatusBarColor(r, g, b, a or 1)
        else
            labelFS:SetTextColor(r, g, b, a or 1)
            rightFS:SetTextColor(r, g, b, a or 1)
            centerFS:SetTextColor(r, g, b, a or 1)
            middleFS:SetTextColor(r, g, b, a or 1)
        end
    end

    function handle:SetLabel(text)
        labelFS:SetText(text or "")
    end

    local function applyRightText(text, now)
        rightFS:SetText(text or "")
        lastRightUpdate = now or GetTime()
        pendingRightText = nil
    end

    function handle:SetRight(text)
        local interval = math.max(0, tonumber(config.textUpdateInterval) or 0)
        local now = GetTime()
        if running and interval > 0 and now - lastRightUpdate < interval then
            pendingRightText = text or ""
            return
        end
        applyRightText(text, now)
    end

    function handle:SetMiddle(text)
        middleFS:SetText(text or "")
    end

    local function autoFitCenter()
        if not config.autoSize then
            return
        end
        local sw = centerFS:GetStringWidth() or 0
        if sw <= 0 then
            return
        end
        local fontSize = (config.center and config.center.size) or 12
        local pad = config.autoSizePad or 2
        local w = math.ceil(sw) + pad * 2
        local h = math.ceil(fontSize * 0.75) + pad * 2
        frame:SetSize(w, h)
        centerFS:ClearAllPoints()
        centerFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
        centerFS:SetJustifyH("CENTER")
        centerFS:SetJustifyV("MIDDLE")
    end

    function handle:SetCenter(text)
        centerFS:SetText(text or "")
        autoFitCenter()
    end

    function handle:SetValue(v)
        if showFill then
            frame:SetValue(v or 0)
        end
    end

    function handle:SetMarker(ratio)
        if not ratio or ratio < 0 or ratio > 1 then
            markerRatio = nil
            marker:Hide()
            return
        end
        markerRatio = ratio
        local w = frame:GetWidth()
        if not w or w <= 0 then
            marker:Hide()
            return
        end
        marker:ClearAllPoints()
        marker:SetPoint("CENTER", frame, "LEFT", w * ratio, 0)
        marker:SetHeight(frame:GetHeight())
        if mode ~= "center" then
            marker:Show()
        end
    end

    local function onUpdate()
        local now = GetTime()
        local t = now - startTime
        if t >= totalDuration then
            handle:Stop()
            return
        end

        if showFill then
            local remaining = totalDuration - t
            frame:SetValue(remaining / totalDuration)
        end

        if handle.onTick then
            -- Callers use this for countdown text, TTS, and phase changes.
            handle.onTick(t, totalDuration, safeDuration)
        end

        local textInterval = math.max(0, tonumber(config.textUpdateInterval) or 0)
        if pendingRightText ~= nil and (textInterval <= 0 or now - lastRightUpdate >= textInterval) then
            applyRightText(pendingRightText, now)
        end
    end

    function handle:Start(opts)
        opts = opts or {}
        totalDuration = opts.total or 0
        safeDuration = opts.safe
        startTime = GetTime() + (opts.lead or 0)
        running = true
        lastRightUpdate = -math.huge
        pendingRightText = nil
        if showFill then
            frame:SetValue(1)
        end
        if safeDuration and totalDuration > 0 then
            self:SetMarker((totalDuration - safeDuration) / totalDuration)
        end
        frame:SetScript("OnUpdate", onUpdate)
        onUpdate()
        frame:Show()
    end

    function handle:Stop()
        local wasRunning = running
        running = false
        frame:SetScript("OnUpdate", nil)
        pendingRightText = nil
        if showFill then
            frame:SetValue(0)
        end

        if wasRunning and handle.onStop then
            local ok, err = pcall(handle.onStop)
            if not ok then
                E:ChannelWarn("BossMods", "Bar.onStop failed: %s", tostring(err))
            end
        end
    end

    function handle:IsRunning()
        return running
    end

    function handle:Show()
        frame:Show()
    end

    function handle:Hide()
        frame:Hide()
    end

    -- Apply re-styles the frame from a new config table
    function handle:Apply(newConfig)
        if newConfig then
            for k, v in pairs(newConfig) do
                config[k] = v
            end
        end
        local c = config

        if c.size and not c.autoSize then
            frame:SetSize(c.size.w or 100, c.size.h or 24)
        end

        local iconConfig = c.icon or {}
        local iconSize = math.max(8, tonumber(iconConfig.size) or 24)

        if iconConfig.enabled ~= false and iconConfig.texture then
            icon:SetTexture(iconConfig.texture)
            icon:SetSize(iconSize, iconSize)
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", frame, "LEFT", -2, 0)
            icon:Show()
        else
            icon:Hide()
        end

        if showFill and c.statusBar then
            local tex = fetchStatusBar(c.statusBar.texture)
            if frame._artStatusBarTex ~= tex then
                frame:SetStatusBarTexture(tex)
                frame._artStatusBarTex = tex
            end
            if c.statusBar.color then
                local r, g, b, a = colorTuple(c.statusBar.color, 1, 1, 1, 1)
                frame:SetStatusBarColor(r, g, b, a)
            end
        end

        local bg = c.background or {}
        local border = c.border or {}
        local enabled = border.enabled ~= false
        local edgeFile = fetchBorder(border.texture)
        local edgeSize = math.min(border.size or 1, 16)
        local er, eg, eb, ea = colorTuple(border.color, 0, 0, 0, 1)

        if frame._artBdMode ~= "bg" then
            frame:SetBackdrop({
                bgFile = WHITE,
                insets = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            })
            E:DisablePixelSnap(frame)
            frame._artBdMode = "bg"
        end
        E:ApplyOuterBorder(frame, {
            enabled = enabled,
            edgeFile = edgeFile,
            edgeSize = edgeSize,
            r = er,
            g = eg,
            b = eb,
            a = ea
        })

        local br, bgG, bb, ba = colorTuple(bg.color, 0, 0, 0, 0.6)
        local backgroundOpacity = math.max(
            0,
            math.min(1, tonumber(bg.opacity) or 1)
        )

        frame:SetBackdropColor(
            br,
            bgG,
            bb,
            ba * backgroundOpacity
        )

        -- Style every font string whose config is present
        if c.label then
            applyFontTo(labelFS, c.label, frame, {
                justify = "LEFT"
            })
        end
        if c.right then
            applyFontTo(rightFS, c.right, frame, {
                justify = "RIGHT"
            })
        end
        if c.center then
            applyFontTo(centerFS, c.center, frame, {
                justify = c.center.justify or "CENTER"
            })
        end
        if c.middle then
            applyFontTo(middleFS, c.middle, frame, {
                justify = "CENTER"
            })
        end

        -- apply default
        if mode == nil then
            mode = (c.center and not (c.label or c.right)) and "center" or "label"
        end

        -- Re-apply the marker so a width change recomputes its x
        if markerRatio then
            handle:SetMarker(markerRatio)
        end

        applyMode()

        if c.strata then
            frame:SetFrameStrata(c.strata)
        end

        autoFitCenter()
    end

    function handle:Release()
        handle.onStop = nil
        handle:Stop()
        frame:Hide()
        frame:ClearAllPoints()
        frame:SetParent(nil)
        handle.onTick = nil
    end

    handle:Apply()
    return handle
end
