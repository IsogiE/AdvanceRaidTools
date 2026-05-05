local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local WHITE = Shared.WHITE
local fetchFont = Shared.FetchFont
local fetchBorder = Shared.FetchBorder
local colorTuple = Shared.ColorTuple
local applyFontIfChanged = Shared.ApplyFontIfChanged
local isSecret = Shared.IsSecret
local isKnownUnitToken = Shared.IsKnownUnitToken
local getPlayerSpecID = Shared.GetPlayerSpecID
local defaultGroupUnits = Shared.DefaultGroupUnits

local ICON_TEX_COORD = {0.08, 0.92, 0.08, 0.92}
local FALLBACK_ICON = 134400
local TICKER_INTERVAL = 0.1
local COMBAT_RESYNC_INTERVAL = 5

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
            E:ApplyOuterBorder(ic, {
                enabled = false
            })
            ic.border:Hide()
            ic.borderApplied = false
            return
        end
        local edgeTex = fetchBorder(borderCfg.texture)
        local edgeSize = math.min(borderCfg.size or 12, 16)
        if edgeSize <= 0 then
            E:ApplyOuterBorder(ic, {
                enabled = false
            })
            ic.border:Hide()
            ic.borderApplied = false
            return
        end
        ic.border:Hide()
        local r, g, b, a = colorTuple(borderCfg.color, 0, 0, 0, 1)
        E:ApplyOuterBorder(ic, {
            enabled = true,
            edgeFile = edgeTex,
            edgeSize = edgeSize,
            r = r,
            g = g,
            b = b,
            a = a * (borderCfg.opacity or 1)
        })
        ic.borderApplied = true
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
