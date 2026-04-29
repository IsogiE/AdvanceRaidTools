local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
BossMods.Engines = BossMods.Engines or {}
local Engines = BossMods.Engines

local WHITE = E.media.blankTex

local function fetchFont()
    return E:FetchModuleFont()
end
local function fetchStatusBar(tex)
    return E:FetchStatusBar(tex)
end
local function fetchBorder(tex)
    return E:FetchBorder(tex)
end
local function colorTuple(c, fr, fg, fb, fa)
    return E:ColorTuple(c, fr, fg, fb, fa)
end

local function applyFontIfChanged(fs, font, size, outline)
    if fs._artFont == font and fs._artSize == size and fs._artOutline == outline then
        return
    end
    fs:SetFont(font, size, outline)
    fs._artFont, fs._artSize, fs._artOutline = font, size, outline
end

local function applyFontTo(fs, style, parent, anchor)
    applyFontIfChanged(fs, fetchFont(), style.size or 12, style.outline or "")
    fs:ClearAllPoints()
    local justify = style.justify or anchor.justify
    if justify == "CENTER" then
        fs:SetPoint("CENTER", parent, "CENTER", 0, 0)
    elseif justify == "RIGHT" then
        fs:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    else
        fs:SetPoint("LEFT", parent, "LEFT", 6, 0)
    end
    fs:SetJustifyH(justify or "LEFT")
    local r, g, b, a = colorTuple(style.color, 1, 1, 1, 1)
    fs:SetTextColor(r, g, b, a)
end

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
    local marker = frame:CreateTexture(nil, "OVERLAY")
    marker:SetColorTexture(1, 1, 1, 1)
    marker:SetWidth(2)
    marker:Hide()

    -- Active countdown state
    local running = false
    local startTime, totalDuration, safeDuration
    local mode, markerRatio

    local handle = {
        frame = frame
    }

    local function applyMode()
        if mode == "center" then
            labelFS:Hide()
            rightFS:Hide()
            marker:Hide()
            centerFS:Show()
        else
            centerFS:Hide()
            labelFS:Show()
            rightFS:Show()
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
        end
    end

    function handle:SetLabel(text)
        labelFS:SetText(text or "")
    end

    function handle:SetRight(text)
        rightFS:SetText(text or "")
    end

    local function autoFitCenter()
        if not config.autoSize then
            return
        end
        local pad = config.autoSizePad or 4
        local sw = centerFS:GetStringWidth() or 0
        local sh = centerFS:GetStringHeight() or 0
        if sw <= 0 or sh <= 0 then
            return
        end
        frame:SetSize(sw + pad * 2, sh + pad * 2)
        centerFS:ClearAllPoints()
        if config.centerVisualBias then
            local bias = math.max(0, math.floor(sh * 0.12) - 2)
            centerFS:SetPoint("CENTER", frame, "CENTER", 0, -bias)
        else
            centerFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
        end
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

    local function onUpdate(_, _)
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
            -- Allow callers to react per-frame (e.g. TTS, phase swaps)
            handle.onTick(t, totalDuration, safeDuration)
        end
    end

    function handle:Start(opts)
        opts = opts or {}
        totalDuration = opts.total or 0
        safeDuration = opts.safe
        startTime = GetTime() + (opts.lead or 0)
        running = true
        if showFill then
            frame:SetValue(1)
        end
        if safeDuration and totalDuration > 0 then
            self:SetMarker((totalDuration - safeDuration) / totalDuration)
        end
        frame:SetScript("OnUpdate", onUpdate)
        frame:Show()
    end

    function handle:Stop()
        local wasRunning = running
        running = false
        frame:SetScript("OnUpdate", nil)
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
        local isPixel = (edgeFile == E.media.blankTex)
        local er, eg, eb, ea = colorTuple(border.color, 0, 0, 0, 1)

        if enabled and not isPixel then
            if frame._artBdMode ~= "edge" or frame._artBdEdgeFile ~= edgeFile or frame._artBdEdgeSize ~= edgeSize then
                frame:SetBackdrop({
                    bgFile = WHITE,
                    edgeFile = edgeFile,
                    edgeSize = edgeSize,
                    insets = {
                        left = 1,
                        right = 1,
                        top = 1,
                        bottom = 1
                    }
                })
                frame._artBdMode = "edge"
                frame._artBdEdgeFile = edgeFile
                frame._artBdEdgeSize = edgeSize
            end
            frame:SetBackdropBorderColor(er, eg, eb, ea)
            E:ApplyOuterBorder(frame, {
                enabled = false
            })
        else
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
                frame._artBdMode = "bg"
                frame._artBdEdgeFile = nil
                frame._artBdEdgeSize = nil
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
        end

        local br, bgG, bb, ba = colorTuple(bg.color, 0, 0, 0, 0.6)
        frame:SetBackdropColor(br, bgG, bb, ba)

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
        frame:SetScript("OnUpdate", nil)
        frame:ClearAllPoints()
        frame:SetParent(nil)
        handle.onTick = nil
    end

    handle:Apply()
    return handle
end

local ICON_TEX_COORD = {0.08, 0.92, 0.08, 0.92}
local FALLBACK_ICON = 134400
local TICKER_INTERVAL = 0.1
local COMBAT_RESYNC_INTERVAL = 5

local function isSecret(v)
    return E:IsSecret(v)
end

local function isKnownUnitToken(unit)
    if type(unit) ~= "string" then
        return false
    end
    if unit == "player" or unit == "pet" or unit == "target" or unit == "focus" then
        return true
    end
    if unit:match("^raid%d+$") or unit:match("^party%d+$") or unit:match("^raidpet%d+$") or unit:match("^partypet%d+$") then
        return true
    end
    return false
end

local function getPlayerSpecID()
    local idx = GetSpecialization and GetSpecialization()
    if not idx then
        return nil
    end
    return GetSpecializationInfo and GetSpecializationInfo(idx) or nil
end

local function defaultGroupUnits()
    local units = {"player"}
    local n = GetNumGroupMembers() or 0
    if IsInRaid() then
        for i = 1, n do
            local u = "raid" .. i
            if not UnitIsUnit(u, "player") then
                units[#units + 1] = u
            end
        end
    else
        for i = 1, n - 1 do
            units[#units + 1] = "party" .. i
        end
    end
    return units
end

function Engines.AuraDisplay(config)
    assert(type(config) == "table", "Engines.AuraDisplay: config required")
    assert(config.parent, "Engines.AuraDisplay: config.parent required")
    assert(type(config.spec) == "table", "Engines.AuraDisplay: config.spec required")

    local state = {
        active = false,
        editMode = false,
        inCombat = false,
        lastResync = 0,
        auraData = {},
        displayEntries = {},
        entriesByKey = {},
        unitAuraCache = {},
        ticker = nil,
        config = config,
        lastSpellsRef = nil,
        bgApplied = false,
        layoutDirty = true,
        shownCount = 0
    }

    local callbacks = E:NewCallbackHandle()

    local layoutCfg = config.layout or {}
    local anchorSize = layoutCfg.anchorSize or {
        w = 200,
        h = 44
    }

    local anchor = CreateFrame("Frame", nil, config.parent)
    anchor:SetSize(anchorSize.w, anchorSize.h)
    anchor:SetFrameStrata("MEDIUM")

    local display = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    display:SetAllPoints(anchor)
    display:SetFrameStrata("MEDIUM")
    display:Hide()

    local icons = {}

    local function getUnits()
        if type(config.getUnits) == "function" then
            local ok, result = pcall(config.getUnits)
            if ok and type(result) == "table" then
                return result
            end
        end
        return defaultGroupUnits()
    end

    local function shouldShow()
        if state.editMode then
            return true
        end
        local v = state.config.visibility or {}
        local sw = v.showWhen or "always"
        if sw == "never" then
            return false
        end
        if sw == "combat" then
            return state.inCombat
        end
        if sw == "nocombat" then
            return not state.inCombat
        end
        return true
    end

    local function isKeyEnabled(key)
        local v = state.config.visibility
        if not v or not v.enabledKeys then
            return true
        end
        local ek = v.enabledKeys[key]
        if ek == nil then
            return true
        end
        return ek and true or false
    end

    -- Aura payload is filtered to our tracked spells
    local function extractAura(aura)
        if not aura then
            return
        end
        local iid = aura.auraInstanceID
        if type(iid) ~= "number" then
            return
        end

        local fromPlayer = aura.isFromPlayerOrPlayerPet
        if isSecret(fromPlayer) or not fromPlayer then
            return
        end

        local source = aura.sourceUnit
        if source and not isSecret(source) then
            if not isKnownUnitToken(source) or not UnitIsUnit(source, "player") then
                return
            end
        end

        local sid = aura.spellId
        if isSecret(sid) or type(sid) ~= "number" then
            return
        end
        if not state.auraData[sid] then
            return
        end

        local expiry = aura.expirationTime
        if isSecret(expiry) or type(expiry) ~= "number" then
            expiry = 0
        end
        if expiry ~= 0 and expiry < GetTime() then
            return
        end

        local duration = aura.duration
        if isSecret(duration) or type(duration) ~= "number" then
            duration = 0
        end

        return iid, sid, expiry, duration
    end

    local function resyncUnit(unit, combatSafe)
        state.unitAuraCache[unit] = {}
        if not UnitExists(unit) then
            return
        end

        if combatSafe then
            local combatFilter = (state.config.spec and state.config.spec.combatFilter) or "HELPFUL"
            local ids = C_UnitAuras.GetUnitAuraInstanceIDs and C_UnitAuras.GetUnitAuraInstanceIDs(unit, combatFilter)
            if not ids then
                return
            end
            for _, iid in ipairs(ids) do
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, iid)
                if aura then
                    local aiid, sid, expiry, duration = extractAura(aura)
                    if aiid then
                        state.unitAuraCache[unit][aiid] = {
                            spellId = sid,
                            expirationTime = expiry,
                            duration = duration
                        }
                    end
                end
            end
        else
            local filter = (state.config.spec and state.config.spec.filter) or "HELPFUL|PLAYER"
            local auras = C_UnitAuras.GetUnitAuras and C_UnitAuras.GetUnitAuras(unit, filter)
            if not auras then
                return
            end
            for _, aura in ipairs(auras) do
                local aiid, sid, expiry, duration = extractAura(aura)
                if aiid then
                    state.unitAuraCache[unit][aiid] = {
                        spellId = sid,
                        expirationTime = expiry,
                        duration = duration
                    }
                end
            end
        end
    end

    local function resyncAll()
        wipe(state.unitAuraCache)
        for _, unit in ipairs(getUnits()) do
            resyncUnit(unit, state.inCombat)
        end
    end

    local function handleUnitAuraEvent(unit, info)
        if info == nil or info.isFullUpdate then
            resyncUnit(unit, state.inCombat)
            return
        end
        local cache = state.unitAuraCache[unit]
        if not cache then
            return
        end

        if info.removedAuraInstanceIDs then
            for _, iid in ipairs(info.removedAuraInstanceIDs) do
                cache[iid] = nil
            end
        end
        if info.addedAuras then
            for _, aura in ipairs(info.addedAuras) do
                local iid = aura.auraInstanceID
                if type(iid) == "number" then
                    local fresh = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, iid)
                    if fresh then
                        local aiid, sid, expiry, duration = extractAura(fresh)
                        if aiid then
                            cache[iid] = {
                                spellId = sid,
                                expirationTime = expiry,
                                duration = duration
                            }
                        end
                    end
                end
            end
        end
        if info.updatedAuraInstanceIDs then
            for _, iid in ipairs(info.updatedAuraInstanceIDs) do
                local fresh = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, iid)
                if fresh then
                    local _, sid, expiry, duration = extractAura(fresh)
                    if sid then
                        cache[iid] = {
                            spellId = sid,
                            expirationTime = expiry,
                            duration = duration
                        }
                    else
                        cache[iid] = nil
                    end
                else
                    cache[iid] = nil
                end
            end
        end
    end

    local function scanGroupAuras()
        for sid in pairs(state.auraData) do
            local d = state.auraData[sid]
            d.count, d.minExpiry, d.maxExpiry, d.minDuration = 0, math.huge, 0, 0
        end

        local now = GetTime()
        for _, cache in pairs(state.unitAuraCache) do
            local toRemove
            for iid, e in pairs(cache) do
                local sid = e.spellId
                local expiry = e.expirationTime or 0
                if expiry == 0 or expiry < now or not state.auraData[sid] then
                    toRemove = toRemove or {}
                    toRemove[#toRemove + 1] = iid
                else
                    local d = state.auraData[sid]
                    d.count = d.count + 1
                    if expiry < d.minExpiry then
                        d.minExpiry = expiry
                        d.minDuration = e.duration or 0
                    end
                    if expiry > d.maxExpiry then
                        d.maxExpiry = expiry
                    end
                end
            end
            if toRemove then
                for _, iid in ipairs(toRemove) do
                    cache[iid] = nil
                end
            end
        end
    end

    local function rebuildTrackedSpells()
        wipe(state.auraData)
        wipe(state.displayEntries)
        wipe(state.entriesByKey)
        wipe(state.unitAuraCache)
        state.layoutDirty = true

        local spells = state.config.spec and state.config.spec.spells or {}
        local spec = getPlayerSpecID()

        for _, spell in ipairs(spells) do
            local validSpec = not spell.specIDs
            if not validSpec and spec then
                for _, sid in ipairs(spell.specIDs) do
                    if sid == spec then
                        validSpec = true;
                        break
                    end
                end
            end

            if validSpec then
                state.auraData[spell.id] = {
                    count = 0,
                    minExpiry = math.huge,
                    maxExpiry = 0,
                    minDuration = 0
                }

                if spell.hidden then
                    local entry = state.entriesByKey[spell.key]
                    if entry then
                        entry.spellIDs[#entry.spellIDs + 1] = spell.id
                    end
                else
                    local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell.id)
                    local entry = {
                        key = spell.key,
                        label = spell.name,
                        color = spell.color,
                        texID = info and info.iconID or FALLBACK_ICON,
                        spellIDs = {spell.id}
                    }
                    state.displayEntries[#state.displayEntries + 1] = entry
                    state.entriesByKey[spell.key] = entry
                end
            end
        end
    end

    local function formatTime(remaining, decimals)
        if remaining <= 0 or remaining == math.huge then
            return ""
        end
        if remaining >= 60 then
            return ("%dm"):format(math.ceil(remaining / 60))
        end
        if decimals == 0 then
            return ("%d"):format(math.floor(remaining))
        end
        if decimals == 2 then
            return ("%.2f"):format(remaining)
        end
        return ("%.1f"):format(remaining)
    end

    local function getOrCreateIcon(index)
        if icons[index] then
            return icons[index]
        end

        local f = CreateFrame("Frame", nil, display, "BackdropTemplate")
        f:SetFrameStrata("MEDIUM")

        f.texture = f:CreateTexture(nil, "ARTWORK")
        f.texture:SetAllPoints()
        f.texture:SetTexCoord(unpack(ICON_TEX_COORD))

        f.cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        f.cooldown:SetAllPoints(f)
        f.cooldown:SetFrameLevel(f:GetFrameLevel() + 1)
        f.cooldown:SetDrawBling(false)
        f.cooldown:SetDrawEdge(false)
        f.cooldown:SetHideCountdownNumbers(true)
        if f.cooldown.SetSwipeColor then
            f.cooldown:SetSwipeColor(0, 0, 0, 0.55)
        end

        local textHolder = CreateFrame("Frame", nil, f)
        textHolder:SetAllPoints(f)
        textHolder:SetFrameLevel(f:GetFrameLevel() + 10)

        f.count = textHolder:CreateFontString(nil, "OVERLAY")
        f.count:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.timer = textHolder:CreateFontString(nil, "OVERLAY")
        f.timer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

        f.border = CreateFrame("Frame", nil, display, "BackdropTemplate")
        f.border:SetFrameStrata("MEDIUM")
        f.border:SetFrameLevel(f:GetFrameLevel())
        f.border:Hide()
        f.borderApplied = false

        icons[index] = f
        return f
    end

    local function applyLabelStyle(fs, style)
        applyFontIfChanged(fs, fetchFont(), style.size or 11, style.outline or "OUTLINE")
        local r, g, b, a = colorTuple(style.color, 1, 1, 1, 1)
        fs:SetTextColor(r, g, b, a)
        fs:ClearAllPoints()
        fs:SetPoint(style.anchor or "TOPLEFT", fs:GetParent(), style.anchor or "TOPLEFT", style.offsetX or 0,
            style.offsetY or 0)
    end

    local function updateIconBorder(ic, borderCfg)
        if not borderCfg or not borderCfg.enabled then
            ic.border:Hide()
            ic.borderApplied = false
            return
        end
        local edgeTex = fetchBorder(borderCfg.texture)
        local edgeSize = math.min(borderCfg.size or 12, 16)
        if edgeSize <= 0 then
            ic.border:Hide()
            ic.borderApplied = false
            return
        end
        local isPixel = (edgeTex == E.media.blankTex)

        if not ic.borderApplied or ic.lastBorderTex ~= edgeTex or ic.lastBorderSize ~= edgeSize or ic.lastBorderPixel ~=
            isPixel then
            ic.border:ClearAllPoints()
            if isPixel then
                ic.border:SetPoint("TOPLEFT", ic, "TOPLEFT", -edgeSize, edgeSize)
                ic.border:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", edgeSize, -edgeSize)
                ic.border:SetFrameLevel(ic:GetFrameLevel())
            else
                ic.border:SetAllPoints(ic)
                ic.border:SetFrameLevel(ic:GetFrameLevel() + 5)
            end
            ic.border:SetBackdrop({
                edgeFile = edgeTex,
                edgeSize = edgeSize,
                insets = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            })
            ic.lastBorderTex = edgeTex
            ic.lastBorderSize = edgeSize
            ic.lastBorderPixel = isPixel
            ic.borderApplied = true
        end
        local r, g, b, a = colorTuple(borderCfg.color, 0, 0, 0, 1)
        ic.border:SetBackdropBorderColor(r, g, b, a * (borderCfg.opacity or 1))
        ic.border:Show()
    end

    local function updateDisplayBackdrop(styleCfg)
        local bg = styleCfg and styleCfg.background

        if not bg or not bg.enabled then
            if state.bgApplied then
                display:SetBackdrop(nil)
                state.bgApplied = false
            end
            return
        end
        if not state.bgApplied then
            display:SetBackdrop({
                bgFile = WHITE,
                insets = {
                    left = 0,
                    right = 0,
                    top = 0,
                    bottom = 0
                }
            })
            state.bgApplied = true
        end
        local r, g, b = colorTuple(bg.color, 0, 0, 0, 1)
        display:SetBackdropColor(r, g, b, bg.opacity or 0.5)
    end

    -- Applies static icon layout
    local function applyLayout()
        local styleCfg = state.config.style or {}
        local layout = state.config.layout or {}
        local iconSize = layout.iconSize or 36
        local iconPad = layout.iconPad or 4
        local opacity = styleCfg.iconOpacity or 1
        local borderCfg = styleCfg.border
        local countCfg = styleCfg.count or {}
        local timerCfg = styleCfg.timer or {}

        updateDisplayBackdrop(styleCfg)

        local shown = 0
        for _, entry in ipairs(state.displayEntries) do
            if isKeyEnabled(entry.key) then
                shown = shown + 1
                local ic = getOrCreateIcon(shown)
                ic._entry = entry

                ic:SetSize(iconSize, iconSize)
                ic:ClearAllPoints()
                if shown == 1 then
                    ic:SetPoint("TOPLEFT", display, "TOPLEFT", 0, 0)
                else
                    ic:SetPoint("LEFT", icons[shown - 1], "RIGHT", iconPad, 0)
                end

                ic.texture:SetTexture(entry.texID)
                ic.texture:SetAlpha(opacity)
                ic.texture:SetVertexColor(1, 1, 1)

                if countCfg.enabled ~= false then
                    applyLabelStyle(ic.count, countCfg)
                end
                if timerCfg.enabled ~= false then
                    applyLabelStyle(ic.timer, timerCfg)
                end
                updateIconBorder(ic, borderCfg)
            end
        end

        for i = shown + 1, #icons do
            icons[i]:Hide()
            if icons[i].border then
                icons[i].border:Hide()
            end
            icons[i]._entry = nil
        end

        state.shownCount = shown

        if shown > 0 or state.editMode then
            local visible = math.max(shown, state.editMode and 1 or 0)
            local targetW = visible * iconSize + math.max(0, visible - 1) * iconPad
            local targetH = iconSize
            anchor:SetSize(targetW, targetH)
            display:SetAllPoints(anchor)
        end
    end

    local function updateIcons()
        if not state.active or not shouldShow() then
            for i = 1, state.shownCount do
                local ic = icons[i]
                if ic then
                    ic:Hide()
                    if ic.border then
                        ic.border:Hide()
                    end
                end
            end
            if not state.editMode then
                display:Hide()
            end
            return
        end

        if state.inCombat then
            local now = GetTime()
            if now - state.lastResync >= COMBAT_RESYNC_INTERVAL then
                state.lastResync = now
                resyncAll()
            end
        end

        scanGroupAuras()

        if state.layoutDirty then
            applyLayout()
            state.layoutDirty = false
        end

        local styleCfg = state.config.style or {}
        local countEnabled = (styleCfg.count or {}).enabled ~= false
        local timerCfg = styleCfg.timer or {}
        local timerEnabled = timerCfg.enabled ~= false
        local decimals = timerCfg.decimals or 1
        local now = GetTime()
        local shown = state.shownCount

        for i = 1, shown do
            local ic = icons[i]
            local entry = ic and ic._entry
            if entry then
                local totalCount, minExpiry, minDuration = 0, math.huge, 0
                for _, sid in ipairs(entry.spellIDs) do
                    local d = state.auraData[sid]
                    if d then
                        totalCount = totalCount + d.count
                        if d.minExpiry < minExpiry then
                            minExpiry = d.minExpiry
                            minDuration = d.minDuration
                        end
                    end
                end

                local desat = totalCount == 0 and not state.editMode
                if ic._desat ~= desat then
                    ic.texture:SetDesaturated(desat)
                    ic._desat = desat
                end

                if countEnabled then
                    local txt = tostring(state.editMode and 1 or totalCount)
                    if ic._countText ~= txt then
                        ic.count:SetText(txt)
                        ic._countText = txt
                    end
                    if not ic.count:IsShown() then
                        ic.count:Show()
                    end
                elseif ic.count:IsShown() then
                    ic.count:Hide()
                end

                if timerEnabled and (totalCount > 0 or state.editMode) then
                    local txt = state.editMode and "9.9" or formatTime(minExpiry - now, decimals)
                    if ic._timerText ~= txt then
                        ic.timer:SetText(txt)
                        ic._timerText = txt
                    end
                    if not ic.timer:IsShown() then
                        ic.timer:Show()
                    end
                elseif ic.timer:IsShown() then
                    ic.timer:Hide()
                end

                local cdStart, cdDur = 0, 0
                if totalCount > 0 and minExpiry ~= math.huge and minDuration > 0 then
                    cdStart, cdDur = minExpiry - minDuration, minDuration
                elseif state.editMode then
                    cdStart, cdDur = now - 5, 10
                end
                if ic._cdStart ~= cdStart or ic._cdDur ~= cdDur then
                    ic.cooldown:SetCooldown(cdStart, cdDur)
                    ic._cdStart, ic._cdDur = cdStart, cdDur
                end
                if cdDur > 0 then
                    if not ic.cooldown:IsShown() then
                        ic.cooldown:Show()
                    end
                elseif ic.cooldown:IsShown() then
                    ic.cooldown:Hide()
                end

                if not ic:IsShown() then
                    ic:Show()
                end
            end
        end

        if shown > 0 or state.editMode then
            if not display:IsShown() then
                display:Show()
            end
        elseif display:IsShown() then
            display:Hide()
        end
    end

    local function startTicker()
        if state.ticker then
            state.ticker:Cancel()
        end
        state.ticker = C_Timer.NewTicker(TICKER_INTERVAL, function()
            -- gate on state.active so a stale tick after SetActive(false) is a no-op
            if state.active then
                updateIcons()
            end
        end)
    end

    local function stopTicker()
        if state.ticker then
            state.ticker:Cancel()
            state.ticker = nil
        end
    end

    -- event handlers

    callbacks:RegisterEvent("UNIT_AURA", function(_, unit, info)
        if not state.active then
            return
        end
        if isKnownUnitToken(unit) and UnitIsUnit(unit, "player") then
            unit = "player"
        end
        if state.unitAuraCache[unit] or info == nil or info.isFullUpdate then
            handleUnitAuraEvent(unit, info)
        end
    end)

    callbacks:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        state.inCombat = true
        state.lastResync = GetTime()
    end)

    callbacks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        state.inCombat = false
    end)

    local function onSpecOrWorld()
        if not state.active then
            return
        end
        rebuildTrackedSpells()
        resyncAll()
    end

    callbacks:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", onSpecOrWorld)
    callbacks:RegisterEvent("PLAYER_ENTERING_WORLD", onSpecOrWorld)

    callbacks:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        if not state.active then
            return
        end
        local current = {}
        for _, unit in ipairs(getUnits()) do
            current[unit] = true
            if not state.unitAuraCache[unit] then
                resyncUnit(unit, state.inCombat)
            end
        end
        for unit in pairs(state.unitAuraCache) do
            if not current[unit] then
                state.unitAuraCache[unit] = nil
            end
        end
    end)

    -- handle said events

    local handle = {
        frame = anchor
    }

    function handle:SetActive(v)
        v = v and true or false
        if state.active == v then
            return
        end
        state.active = v
        if v then
            state.inCombat = UnitAffectingCombat and UnitAffectingCombat("player") or false
            state.lastResync = GetTime()
            state.layoutDirty = true
            rebuildTrackedSpells()
            resyncAll()
            startTicker()
        else
            stopTicker()
            for _, ic in ipairs(icons) do
                ic:Hide()
                if ic.border then
                    ic.border:Hide()
                end
            end
            display:Hide()
            wipe(state.unitAuraCache)
        end
    end

    function handle:SetEditMode(v)
        state.editMode = v and true or false
        state.layoutDirty = true
        if state.active then
            updateIcons()
        end
    end

    -- Apply replaces the stored config
    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end

        local specCfg = state.config.spec or {}
        local rebuildNeeded = state.lastSpellsRef ~= specCfg.spells
        state.lastSpellsRef = specCfg.spells

        if rebuildNeeded and state.active then
            rebuildTrackedSpells()
            resyncAll()
        end

        state.layoutDirty = true
        if state.active then
            updateIcons()
        end
    end

    function handle:Release()
        stopTicker()
        callbacks:UnregisterAllEvents()
        for _, ic in ipairs(icons) do
            ic:Hide()
            ic:SetParent(nil)
        end
        wipe(icons)
        display:Hide()
        display:SetParent(nil)
        anchor:Hide()
        anchor:ClearAllPoints()
        anchor:SetParent(nil)
        wipe(state.auraData)
        wipe(state.displayEntries)
        wipe(state.entriesByKey)
        wipe(state.unitAuraCache)
        state.active = false
    end

    handle:Apply()
    return handle
end

local ASSIGN_DEFAULT_UPCOMING = "|cFFAAAAAA"
local ASSIGN_DEFAULT_ACTIVE = "|cFF00FF00"
local ASSIGN_DEFAULT_DONE = "|cFF707070"
local ASSIGN_TITLE_OFFSET_Y = -7
local ASSIGN_ROWS_START_Y = 22
local ASSIGN_ROWS_PAD_X = 8

function Engines.AssignmentList(config)
    assert(type(config) == "table", "Engines.AssignmentList: config required")
    assert(config.parent, "Engines.AssignmentList: config.parent required")

    local state = {
        config = config,
        rows = {},
        title = "",
        highlight = false
    }

    local sizeCfg = config.size or {
        w = 155,
        h = 50
    }

    local anchor = CreateFrame("Frame", nil, config.parent)
    anchor:SetSize(sizeCfg.w, sizeCfg.h)
    anchor:SetFrameStrata("MEDIUM")

    local display = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    display:SetAllPoints(anchor)
    display:Hide()

    local titleFS = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    titleFS:SetPoint("TOP", display, "TOP", 0, ASSIGN_TITLE_OFFSET_Y)

    local rowFS = {}

    local function rowHeight()
        local font = state.config.style and state.config.style.font or {}
        return math.max(20, (font.size or 12) + 4)
    end

    local function applyBackdrop()
        local style = state.config.style or {}
        local border = style.border or {}
        local bg = style.bg or {}
        local enabled = state.highlight or (border.enabled ~= false)
        local edgeFile = fetchBorder(border.texture)
        local edgeSize = math.min(border.size or 16, 16)
        local isPixel = (edgeFile == E.media.blankTex)

        local r, g, b, a
        if state.highlight then
            r, g, b, a = 0, 1, 0.1, 1
        else
            r, g, b, a = colorTuple(border.color, 0.3, 0.3, 0.3, 1)
        end

        if enabled and not isPixel then
            if display._artBdMode ~= "edge" or display._artBdEdgeFile ~= edgeFile or display._artBdEdgeSize ~= edgeSize then
                display:SetBackdrop({
                    bgFile = WHITE,
                    edgeFile = edgeFile,
                    edgeSize = edgeSize,
                    insets = {
                        left = 1,
                        right = 1,
                        top = 1,
                        bottom = 1
                    }
                })
                display._artBdMode = "edge"
                display._artBdEdgeFile = edgeFile
                display._artBdEdgeSize = edgeSize
            end
            display:SetBackdropBorderColor(r, g, b, a)
            E:ApplyOuterBorder(display, {
                enabled = false
            })
        else
            if display._artBdMode ~= "bg" then
                display:SetBackdrop({
                    bgFile = WHITE,
                    insets = {
                        left = 0,
                        right = 0,
                        top = 0,
                        bottom = 0
                    }
                })
                display._artBdMode = "bg"
                display._artBdEdgeFile = nil
                display._artBdEdgeSize = nil
            end
            E:ApplyOuterBorder(display, {
                enabled = enabled,
                edgeFile = edgeFile,
                edgeSize = edgeSize,
                r = r,
                g = g,
                b = b,
                a = a
            })
        end

        display:SetBackdropColor(0.1, 0.1, 0.1, bg.opacity or 1)
    end

    local function applyFonts()
        local style = state.config.style or {}
        local font = style.font or {}
        local fontPath = fetchFont()
        local size = font.size or 12
        local outline = font.outline or "OUTLINE"

        applyFontIfChanged(titleFS, fontPath, size + 2, outline)
        local justify = font.justify or "LEFT"

        local maxRows = state.config.maxRows or 6
        for i = 1, maxRows do
            if not rowFS[i] then
                rowFS[i] = display:CreateFontString(nil, "OVERLAY")
            end
            local fs = rowFS[i]
            applyFontIfChanged(fs, fontPath, size, outline)
            fs:SetJustifyH(justify)
            fs:ClearAllPoints()
            local yOffset = -(ASSIGN_ROWS_START_Y + (i - 1) * rowHeight())
            if justify == "RIGHT" then
                fs:SetPoint("TOPRIGHT", display, "TOPRIGHT", -ASSIGN_ROWS_PAD_X, yOffset)
            elseif justify == "CENTER" then
                fs:SetPoint("TOP", display, "TOP", 0, yOffset)
            else
                fs:SetPoint("TOPLEFT", display, "TOPLEFT", ASSIGN_ROWS_PAD_X, yOffset)
            end
        end
    end

    local function renderRows()
        local maxRows = state.config.maxRows or 6
        local style = state.config.style or {}
        local colors = style.colors or {}
        local upcoming = colors.upcoming or ASSIGN_DEFAULT_UPCOMING
        local active = colors.active or ASSIGN_DEFAULT_ACTIVE
        local done = colors.done or ASSIGN_DEFAULT_DONE

        local rows = state.rows
        local n = math.min(#rows, maxRows)

        for i = 1, maxRows do
            local fs = rowFS[i]
            if not fs then
                -- First Apply hasn't run yet
                break
            end
            if i <= n then
                local row = rows[i]
                local colorStr, prefix
                if row.state == "active" then
                    colorStr, prefix = active, "-> "
                elseif row.state == "done" then
                    colorStr, prefix = done, "  "
                else
                    colorStr, prefix = upcoming, "  "
                end
                fs:SetText(("%s%s%d. %s|r"):format(colorStr, prefix, i, row.text or ""))
                fs:Show()
            else
                fs:SetText("")
                fs:Hide()
            end
        end

        -- Resize anchor to fit the current row count
        local titleH = 26
        local h = titleH + n * rowHeight()
        if h < sizeCfg.h then
            h = sizeCfg.h
        end
        anchor:SetHeight(h)
    end

    local handle = {
        frame = anchor
    }

    function handle:SetTitle(text)
        state.title = text or ""
        titleFS:SetText(state.title)
    end

    function handle:SetRows(rows)
        state.rows = rows or {}
        renderRows()
    end

    function handle:Clear()
        wipe(state.rows)
        renderRows()
    end

    function handle:SetHighlight(v)
        local target = v and true or false
        if state.highlight == target then
            return
        end
        state.highlight = target
        applyBackdrop()
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end
        sizeCfg = state.config.size or sizeCfg
        applyFonts()
        applyBackdrop()
        renderRows()
    end

    function handle:Show()
        display:Show()
    end

    function handle:Hide()
        display:Hide()
    end

    function handle:Release()
        display:Hide()
        for _, fs in ipairs(rowFS) do
            fs:Hide()
            fs:SetText("")
        end
        wipe(rowFS)
        display:SetParent(nil)
        anchor:Hide()
        anchor:ClearAllPoints()
        anchor:SetParent(nil)
        wipe(state.rows)
    end

    handle:Apply()
    return handle
end

function Engines.TextAlert(config)
    assert(type(config) == "table", "Engines.TextAlert: config required")
    assert(config.parent, "Engines.TextAlert: config.parent required")

    local sizeCfg = config.size or {
        w = 400,
        h = 80
    }

    local frame = CreateFrame("Frame", nil, config.parent, "BackdropTemplate")
    frame:SetSize(sizeCfg.w, sizeCfg.h)
    frame:SetFrameStrata(config.strata or "MEDIUM")
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")

    local state = {
        config = config
    }

    local handle = {
        frame = frame
    }

    function handle:SetText(t)
        text:SetText(t or "")
    end

    function handle:Show()
        frame:Show()
    end
    function handle:Hide()
        frame:Hide()
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end
        local c = state.config
        if c.size then
            frame:SetSize(c.size.w or 400, c.size.h or 80)
        end
        local font = c.font or {}
        applyFontIfChanged(text, fetchFont(), font.size or 28, font.outline or "OUTLINE")
        if font.color then
            local r, g, b, a = colorTuple(font.color, 1, 1, 1, 1)
            text:SetTextColor(r, g, b, a)
        end
        if c.strata then
            frame:SetFrameStrata(c.strata)
        end
    end

    function handle:Release()
        frame:Hide()
        frame:SetBackdrop(nil)
        frame:ClearAllPoints()
        frame:SetParent(nil)
    end

    handle:Apply()
    return handle
end

local DEFAULT_NODE_SIZE = 32
local DEFAULT_NODE_ICON = [[Interface\TargetingFrame\UI-Classes-Circles]]
local DEFAULT_MASK_TEX = [[Interface\CharacterFrame\TempPortraitAlphaMask]]
local DEFAULT_GLOW_COLOR = {0.247, 0.988, 0.247, 0.8}
local DEFAULT_PLAYER_NODE = 17 -- used as edit-mode fallback perspective
local DUMMY_CLASSES = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
                       "MONK", "DRUID", "DEMONHUNTER", "EVOKER"}

local function groupIterator()
    local num = GetNumGroupMembers() or 0
    local inRaid = IsInRaid()
    local i = 0
    return function()
        i = i + 1
        if i > num then
            return
        end
        local unit = inRaid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        return i, unit
    end
end

local function findPlayerRaidIndex()
    for i, unit in groupIterator() do
        if UnitExists(unit) and UnitIsUnit("player", unit) then
            return i
        end
    end
    return nil
end

local function normalizePositions(layout)
    local out = {}
    local kind = layout.kind or "manual"
    for idx, pos in pairs(layout.positions or {}) do
        if kind == "radial" then
            local angle = math.rad(pos.a or 0)
            out[idx] = {
                x = math.sin(angle) * (pos.r or 0),
                y = math.cos(angle) * (pos.r or 0)
            }
        else
            out[idx] = {
                x = pos.x or 0,
                y = pos.y or 0
            }
        end
    end
    return out
end

local function allNodesSet(n)
    local t = {}
    for i = 1, n do
        t[i] = true
    end
    return t
end

local function resolveVisibleSet(layout, playerNode, totalNodes)
    if not layout.visibility then
        return allNodesSet(totalNodes)
    end
    local group = layout.visibility[playerNode]
    if not group then
        -- Fall back to all nodes when the perspective has no explicit group
        return allNodesSet(totalNodes)
    end
    local out = {}
    for _, n in ipairs(group) do
        out[n] = true
    end
    return out
end

-- Node pool (per anchor)

local function createNode(parent, nodeSize)
    local node = CreateFrame("Frame", nil, parent)
    node:SetSize(nodeSize or DEFAULT_NODE_SIZE, nodeSize or DEFAULT_NODE_SIZE)

    node.glow = node:CreateTexture(nil, "BACKGROUND", nil, -1)
    node.glow:SetPoint("TOPLEFT", -6, 6)
    node.glow:SetPoint("BOTTOMRIGHT", 6, -6)
    node.glow:SetColorTexture(unpack(DEFAULT_GLOW_COLOR))
    local glowMask = node:CreateMaskTexture()
    glowMask:SetTexture(DEFAULT_MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    glowMask:SetAllPoints(node.glow)
    node.glow:AddMaskTexture(glowMask)
    node.glow:Hide()

    node.icon = node:CreateTexture(nil, "ARTWORK", nil, 1)
    node.icon:SetAllPoints()
    node.icon:SetTexture(DEFAULT_NODE_ICON)

    node.name = node:CreateFontString(nil, "OVERLAY")
    node.name:SetPoint("TOP", node, "BOTTOM", 0, -2)

    node:Hide()
    return node
end

-- Wedge + markers (per anchor)

local function createSliceAssets(parent, center)
    local wedge = parent:CreateTexture(nil, "BACKGROUND", nil, -7)
    wedge:SetTexture(WHITE)
    local wedgeMask = parent:CreateMaskTexture()
    wedgeMask:SetTexture(DEFAULT_MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    wedgeMask:SetSize(500, 500)
    wedgeMask:SetPoint("CENTER", center, "CENTER")
    wedge:AddMaskTexture(wedgeMask)
    wedge:Hide()

    local lines = {}
    for i = 1, 2 do
        local line = parent:CreateLine(nil, "BACKGROUND", nil, -6)
        line:SetTexture([[Interface\ChatFrame\ChatFrameBackground]])
        line:SetThickness(2.5)
        line:Hide()
        lines[i] = line
    end

    return {
        wedge = wedge,
        wedgeMask = wedgeMask,
        lines = lines,
        markers = {}
    }
end

local function ensureMarker(assets, parent, center, markerID)
    if assets.markers[markerID] then
        return assets.markers[markerID]
    end
    local tex = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    tex:SetSize(45, 45)
    tex:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcon_]] .. markerID)
    tex:Hide()
    assets.markers[markerID] = tex
    return tex
end

local function hideAllMarkers(assets)
    for _, m in pairs(assets.markers) do
        m:Hide()
    end
end

function Engines.RaidMap(spec)
    assert(type(spec) == "table", "Engines.RaidMap: spec required")
    assert(type(spec.anchors) == "table", "Engines.RaidMap: spec.anchors required")
    assert(type(spec.layouts) == "table", "Engines.RaidMap: spec.layouts required")
    local nodeCount = spec.nodes or 20

    local state = {
        spec = spec,
        anchors = {}, -- [key] = { frame, center, nodes[], bgTex, sliceAssets }
        layoutState = {}, -- [layoutKey] = { visible = bool }
        editMode = false,
        editPerspective = nil
    }

    local parent = spec.parent or UIParent
    local nodeSize = (spec.style and spec.style.nodeSize) or DEFAULT_NODE_SIZE

    -- Build one physical frame per anchor, plus its node pool and slice assets
    for anchorKey, anchorSpec in pairs(spec.anchors) do
        local size = anchorSpec.defaultSize or {
            w = 260,
            h = 260
        }
        local frame = CreateFrame("Frame", nil, parent)
        frame:SetSize(size.w, size.h)
        frame:SetFrameStrata("MEDIUM")
        frame:Hide()

        -- Center anchor
        local center = CreateFrame("Frame", nil, frame)
        center:SetSize(1, 1)
        center:ClearAllPoints()
        center:SetPoint("CENTER", frame, "CENTER")

        local bgTex
        if anchorSpec.textureBackground then
            bgTex = frame:CreateTexture(nil, "BACKGROUND")
            bgTex:SetAllPoints(frame)
            bgTex:SetTexture(anchorSpec.textureBackground)
            if anchorSpec.textureMasked then
                local mask = frame:CreateMaskTexture()
                mask:SetTexture(DEFAULT_MASK_TEX, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(bgTex)
                bgTex:AddMaskTexture(mask)
            end
        end

        local nodes = {}
        for i = 1, nodeCount do
            nodes[i] = createNode(frame, nodeSize)
        end

        local sliceAssets = createSliceAssets(frame, center)

        state.anchors[anchorKey] = {
            frame = frame,
            center = center,
            nodes = nodes,
            bgTex = bgTex,
            sliceAssets = sliceAssets,
            defaultSize = size,
            currentLayout = nil
        }
    end

    -- Render help

    -- Returns character name for the raid member at raid slot `raidIdx`
    local function unitAtSlot(raidIdx)
        if IsInRaid() then
            local u = "raid" .. raidIdx
            return UnitExists(u) and u or nil
        end
        -- In party: slot 1 = player, slots 2+ = party1..N-1
        if raidIdx == 1 then
            return "player"
        end
        local u = "party" .. (raidIdx - 1)
        return UnitExists(u) and u or nil
    end

    -- Builds the active raid-to-node mapping for a layout
    local function buildRaidToNodeMap(layout, editMode)
        local base
        if layout.raidToNodeMap then
            base = {}
            for k, v in pairs(layout.raidToNodeMap) do
                base[k] = v
            end
        else
            base = {}
            for i = 1, nodeCount do
                base[i] = i
            end
        end

        if layout.noteBlock and not editMode then
            local NoteBlock = BossMods.NoteBlock
            if NoteBlock then
                local noteText = NoteBlock:GetMainNoteText()
                local noteMap = NoteBlock:ParseNodeMapping(noteText, layout.noteBlock, nodeCount)
                if noteMap then
                    -- Start from identity then overlay note
                    base = {}
                    for i = 1, nodeCount do
                        base[i] = i
                    end
                    for raidIdx, nodeIdx in pairs(noteMap) do
                        base[raidIdx] = nodeIdx
                    end
                end
            end
        end

        return base
    end

    local function resolvePlayerNode(layout, raidToNode, editPerspective)
        if editPerspective and editPerspective > 0 then
            return editPerspective
        end
        local raidIdx = findPlayerRaidIndex()
        if not raidIdx then
            return DEFAULT_PLAYER_NODE
        end
        return raidToNode[raidIdx] or raidIdx
    end

    local function paintNode(node, unit, isPlayer, classFile, displayName)
        if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
            node.icon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[classFile]))
        else
            node.icon:SetTexCoord(0, 1, 0, 1)
        end

        if displayName and displayName ~= "" then
            local colorStr
            if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
                colorStr = RAID_CLASS_COLORS[classFile].colorStr
            end
            if colorStr then
                node.name:SetText(("|c%s%s|r"):format(colorStr, displayName))
            else
                node.name:SetText(displayName)
            end
        else
            node.name:SetText("")
        end

        if isPlayer then
            node.glow:Show()
        else
            node.glow:Hide()
        end
    end

    local function applyFontToNodes(anchorData)
        local font = (state.spec.style and state.spec.style.font) or {}
        local fontPath = fetchFont()
        local size = font.size or 10
        local outline = font.outline or "OUTLINE"
        for _, node in ipairs(anchorData.nodes) do
            applyFontIfChanged(node.name, fontPath, size, outline)
        end
    end

    local function renderSlice(anchorData, layout, playerNode)
        local assets = anchorData.sliceAssets
        local slices = layout.slices
        assets.wedge:Hide()
        assets.lines[1]:Hide()
        assets.lines[2]:Hide()
        hideAllMarkers(assets)

        if not slices then
            -- center is the frame's middle; reset to defaultSize
            anchorData.frame:SetSize(anchorData.defaultSize.w, anchorData.defaultSize.h)
            anchorData.center:ClearAllPoints()
            anchorData.center:SetPoint("CENTER", anchorData.frame, "CENTER")
            return
        end

        local slice = slices[playerNode] or slices[DEFAULT_PLAYER_NODE]
        if not slice then
            anchorData.frame:SetSize(anchorData.defaultSize.w, anchorData.defaultSize.h)
            anchorData.center:ClearAllPoints()
            anchorData.center:SetPoint("CENTER", anchorData.frame, "CENTER")
            return
        end

        anchorData.frame:SetSize(slice.w or anchorData.defaultSize.w, slice.h or anchorData.defaultSize.h)
        anchorData.center:ClearAllPoints()
        anchorData.center:SetPoint(slice.anchor or "CENTER", anchorData.frame, slice.anchor or "CENTER", slice.bx or 0,
            slice.by or 0)

        local a1 = math.rad(slice.sweepStart or 0)
        local a2 = math.rad((slice.sweepStart or 0) + (slice.sweepCount or 0))
        local R = 400

        assets.wedge:ClearAllPoints()
        assets.wedge:SetPoint("CENTER", anchorData.center, "CENTER")
        assets.wedge:SetSize(1, 1)
        assets.wedge:SetVertexOffset(1, math.sin(a1) * R, math.cos(a1) * R)
        assets.wedge:SetVertexOffset(2, math.sin(a2) * R, math.cos(a2) * R)
        assets.wedge:SetVertexOffset(3, 0, 0)
        assets.wedge:SetVertexOffset(4, 0, 0)

        local anchorStyle = state.spec.anchors[layout.anchor].style or {}
        if anchorStyle.showBg ~= false then
            local r = (anchorStyle.bgColor and (anchorStyle.bgColor.r or anchorStyle.bgColor[1])) or 1
            local g = (anchorStyle.bgColor and (anchorStyle.bgColor.g or anchorStyle.bgColor[2])) or 1
            local b = (anchorStyle.bgColor and (anchorStyle.bgColor.b or anchorStyle.bgColor[3])) or 1
            local a = anchorStyle.bgOpacity or 0.6
            assets.wedge:SetVertexColor(r, g, b, a)
            assets.wedge:Show()
        end

        -- Boundary lines from center to sweep endpoints
        local br = (anchorStyle.borderColor and (anchorStyle.borderColor.r or anchorStyle.borderColor[1])) or 1
        local bg = (anchorStyle.borderColor and (anchorStyle.borderColor.g or anchorStyle.borderColor[2])) or 1
        local bb = (anchorStyle.borderColor and (anchorStyle.borderColor.b or anchorStyle.borderColor[3])) or 1
        local ba = anchorStyle.borderOpacity or 0.6
        assets.lines[1]:SetStartPoint("CENTER", anchorData.center, 0, 0)
        assets.lines[1]:SetEndPoint("CENTER", anchorData.center, math.sin(a1) * 250, math.cos(a1) * 250)
        assets.lines[1]:SetVertexColor(br, bg, bb, ba)
        assets.lines[1]:Show()
        assets.lines[2]:SetStartPoint("CENTER", anchorData.center, 0, 0)
        assets.lines[2]:SetEndPoint("CENTER", anchorData.center, math.sin(a2) * 250, math.cos(a2) * 250)
        assets.lines[2]:SetVertexColor(br, bg, bb, ba)
        assets.lines[2]:Show()

        -- Markers listed by the slice (positions come from layout.markers)
        if slice.markers and layout.markers then
            for _, markerID in ipairs(slice.markers) do
                local md = layout.markers[markerID]
                if md then
                    local m = ensureMarker(assets, anchorData.frame, anchorData.center, md.iconID or markerID)
                    m:ClearAllPoints()
                    m:SetPoint("CENTER", anchorData.center, "CENTER", md.x or 0, md.y or 0)
                    m:Show()
                end
            end
        end
    end

    local function renderLayout(layoutKey, opts)
        opts = opts or {}
        local layout = state.spec.layouts[layoutKey]
        if not layout then
            return
        end
        local anchorData = state.anchors[layout.anchor]
        if not anchorData then
            return
        end

        local editMode = opts.editMode or state.editMode
        local positions = normalizePositions(layout)
        local raidToNode = buildRaidToNodeMap(layout, editMode)
        local playerNode = resolvePlayerNode(layout, raidToNode, opts.perspective or state.editPerspective)

        -- Slice (also sets frame size + center-anchor position)
        renderSlice(anchorData, layout, playerNode)

        local visible = resolveVisibleSet(layout, playerNode, nodeCount)

        for i = 1, nodeCount do
            local node = anchorData.nodes[i]
            node:Hide()
            node.glow:Hide()
            local pos = positions[i]
            if pos then
                node:ClearAllPoints()
                node:SetPoint("CENTER", anchorData.center, "CENTER", pos.x, pos.y)
            end
        end

        applyFontToNodes(anchorData)

        -- Populate nodes with actual raid members
        local filled = {}
        for raidIdx, unit in groupIterator() do
            local targetNode = raidToNode[raidIdx] or raidIdx
            if layout.visibility == nil or visible[targetNode] then
                local node = anchorData.nodes[targetNode]
                if node and positions[targetNode] then
                    local _, classFile = UnitClass(unit)
                    local raw = UnitName(unit)
                    local display = raw
                    if raw and BossMods.NoteBlock then
                        display = BossMods.NoteBlock:GetDisplayName(raw) or raw
                    end
                    local isPlayerNode = UnitIsUnit("player", unit) or (targetNode == playerNode)
                    paintNode(node, unit, isPlayerNode, classFile, display)
                    node:Show()
                    filled[targetNode] = true
                end
            end
        end

        -- fill unfilled visible nodes with dummy classes
        if editMode then
            local iter
            if layout.visibility then
                iter = {}
                for n in pairs(visible) do
                    iter[#iter + 1] = n
                end
            else
                iter = {}
                for i = 1, nodeCount do
                    iter[i] = i
                end
            end
            for _, n in ipairs(iter) do
                if not filled[n] and positions[n] then
                    local node = anchorData.nodes[n]
                    local cls = DUMMY_CLASSES[(n % #DUMMY_CLASSES) + 1]
                    local label = ("Raid %d"):format(n)
                    paintNode(node, nil, n == playerNode, cls, label)
                    node:Show()
                end
            end
        end

        anchorData.currentLayout = layoutKey
    end

    local function applyAnchorStyle(anchorKey)
        local anchorData = state.anchors[anchorKey]
        local anchorSpec = state.spec.anchors[anchorKey]
        local style = anchorSpec.style or {}
        if anchorData.frame.SetScale then
            anchorData.frame:SetScale(style.scale or 1.0)
        end
        anchorData.frame:SetAlpha(style.opacity or 1.0)
    end

    -- Handle

    local handle = {
        anchors = {}
    }
    for k, data in pairs(state.anchors) do
        handle.anchors[k] = data.frame
    end

    function handle:Show(layoutKey, opts)
        local layout = state.spec.layouts[layoutKey]
        if not layout then
            return
        end
        local anchorData = state.anchors[layout.anchor]
        if not anchorData then
            return
        end
        renderLayout(layoutKey, opts)
        anchorData.frame:Show()
    end

    function handle:Hide(layoutKey)
        local layout = state.spec.layouts[layoutKey]
        if not layout then
            return
        end
        local anchorData = state.anchors[layout.anchor]
        if not anchorData then
            return
        end
        if anchorData.currentLayout == layoutKey then
            anchorData.frame:Hide()
            anchorData.currentLayout = nil
        end
    end

    function handle:HideAll()
        for _, data in pairs(state.anchors) do
            data.frame:Hide()
            data.currentLayout = nil
        end
    end

    function handle:SetEditMode(v)
        state.editMode = v and true or false
        if not v then
            state.editPerspective = nil
        end
        -- Re-render any currently-visible layout to refresh dummy data
        for anchorKey, data in pairs(state.anchors) do
            if data.frame:IsShown() and data.currentLayout then
                renderLayout(data.currentLayout, {
                    editMode = v
                })
            end
        end
    end

    function handle:SetEditPerspective(nodeIdx)
        state.editPerspective = nodeIdx
        for anchorKey, data in pairs(state.anchors) do
            if data.frame:IsShown() and data.currentLayout then
                renderLayout(data.currentLayout, {
                    editMode = state.editMode
                })
            end
        end
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.spec = newConfig
        end
        for anchorKey, data in pairs(state.anchors) do
            applyAnchorStyle(anchorKey)
            applyFontToNodes(data)
            if data.frame:IsShown() and data.currentLayout then
                renderLayout(data.currentLayout)
            end
        end
    end

    function handle:Release()
        for _, data in pairs(state.anchors) do
            data.frame:Hide()
            for _, node in ipairs(data.nodes) do
                node:Hide()
                node:SetParent(nil)
            end
            wipe(data.nodes)
            data.frame:ClearAllPoints()
            data.frame:SetParent(nil)
        end
        wipe(state.anchors)
    end

    handle:Apply()
    return handle
end
