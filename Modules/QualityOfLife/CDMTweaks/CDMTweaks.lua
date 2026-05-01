local E, L, P = unpack(ART)

P.modules.QoL_CDMTweaks = {
    enabled = false,
    centerEssential = true,
    centerUtility = true,
    centerBuffIcon = true,
    centerBuffBar = true,
    auraOverride = false,
    stackFont = {
        EssentialCooldownViewer = {enabled = false, size = 14, color = {1, 1, 1, 1}},
        UtilityCooldownViewer = {enabled = false, size = 14, color = {1, 1, 1, 1}},
        BuffIconCooldownViewer = {enabled = false, size = 14, color = {1, 1, 1, 1}}
    }
}

local CDMTweaks = E:NewModule("QoL_CDMTweaks", "AceEvent-3.0")

local VIEWER_CONFIG = {
    EssentialCooldownViewer = {
        centerKey = "centerEssential",
        kind = "cooldown"
    },
    UtilityCooldownViewer = {
        centerKey = "centerUtility",
        kind = "cooldown"
    },
    BuffIconCooldownViewer = {
        centerKey = "centerBuffIcon",
        kind = "buffIcon"
    },
    BuffBarCooldownViewer = {
        centerKey = "centerBuffBar",
        kind = "buffBar"
    }
}

local hooksInstalled = false

local function viewer(name)
    return _G[name]
end

local function iterItems(v, fn)
    if not v then
        return
    end
    if v.itemFramePool and v.itemFramePool.EnumerateActive then
        for frame in v.itemFramePool:EnumerateActive() do
            fn(frame)
        end
        return
    end
    if v.GetChildren then
        for _, child in ipairs({v:GetChildren()}) do
            if child.cooldownInfo or child.layoutIndex then
                fn(child)
            end
        end
    end
end

local function collectStackFontStrings(item)
    local out = {}
    if item.ChargeCount and item.ChargeCount.Current then
        out[#out + 1] = item.ChargeCount.Current
    end
    if item.Applications and item.Applications.Applications then
        out[#out + 1] = item.Applications.Applications
    end
    if item.Icon and type(item.Icon) == "table" and item.Icon.Applications then
        out[#out + 1] = item.Icon.Applications
    end
    return out
end

-- Stack font override
local function saveOriginalFontState(fs)
    if fs.artSavedOnce then
        return
    end
    fs.artSavedOnce = true

    fs.artOrigFontObject = fs:GetFontObject()
    local font, size, flags = fs:GetFont()
    fs.artOrigFont = {font, size, flags}

    local r, g, b, a = fs:GetTextColor()
    fs.artOrigColor = {r, g, b, a}
end

local function restoreOriginalFontState(fs)
    if not fs.artSavedOnce then
        return
    end

    if fs.artOrigFont and fs.artOrigFont[1] then
        fs:SetFont(fs.artOrigFont[1], fs.artOrigFont[2], fs.artOrigFont[3] or "")
    elseif fs.artOrigFontObject then
        fs:SetFontObject(fs.artOrigFontObject)
    end

    if fs.artOrigColor then
        fs:SetTextColor(fs.artOrigColor[1], fs.artOrigColor[2], fs.artOrigColor[3], fs.artOrigColor[4] or 1)
    end
end

local function getStackConfig(self_, viewerName)
    local sf = self_.db and self_.db.stackFont
    if type(sf) ~= "table" or not viewerName then
        return nil
    end
    local cfg = sf[viewerName]
    if type(cfg) ~= "table" then
        return nil
    end
    return cfg
end

local function applyFontToItem(self_, item)
    local cfg = getStackConfig(self_, item.artCDMViewer)
    if not cfg then
        return
    end
    local font = E:FetchModuleFont()
    local r, g, b, a = E:ColorTuple(cfg.color, 1, 1, 1, 1)

    for _, fs in ipairs(collectStackFontStrings(item)) do
        saveOriginalFontState(fs)
        fs:SetFont(font, cfg.size or 14, "OUTLINE")
        fs:SetTextColor(r, g, b, a)
    end
end

local function restoreFontOnItem(item)
    for _, fs in ipairs(collectStackFontStrings(item)) do
        restoreOriginalFontState(fs)
    end
end

local function wantsFontOverride(self_, viewerName)
    local cfg = getStackConfig(self_, viewerName)
    return cfg and cfg.enabled or false
end

local function maybeApplyFontToItem(self_, item)
    if wantsFontOverride(self_, item.artCDMViewer) then
        applyFontToItem(self_, item)
    else
        restoreFontOnItem(item)
    end
end

-- Aura CD override
local function shouldOverrideAura(item)
    local info = item.cooldownInfo
    if not info then
        return false
    end
    -- Category 0 = Essential, 1 = Utility
    local cat = info.category
    return cat == 0 or cat == 1
end

local function getSpellDurationObject(spellID)
    if not spellID or not C_Spell then
        return nil
    end
    -- charge spells
    if C_Spell.GetSpellCharges then
        local ok, charges = pcall(C_Spell.GetSpellCharges, spellID)
        if ok and charges and type(charges.maxCharges) == "number" and charges.maxCharges > 1 and
            C_Spell.GetSpellChargeDuration then
            local ok2, obj = pcall(C_Spell.GetSpellChargeDuration, spellID)
            if ok2 and obj then
                return obj
            end
        end
    end
    if C_Spell.GetSpellCooldownDuration then
        local ok, obj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        if ok and obj then
            return obj
        end
    end
    return nil
end

-- cooldown swipe
local OVERRIDE_SWIPE_R, OVERRIDE_SWIPE_G, OVERRIDE_SWIPE_B, OVERRIDE_SWIPE_A = 0, 0, 0, 0.8

local function applyIconOverrideToItem(item)
    if not shouldOverrideAura(item) then
        return
    end
    local info = item.cooldownInfo
    local spellID = info and (info.overrideSpellID or info.spellID)
    if not spellID then
        return
    end

    local icon = item.Icon
    if not icon or type(icon.SetTexture) ~= "function" or icon.artUpdating then
        return
    end

    local tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if not tex then
        return
    end

    icon.artUpdating = true
    pcall(icon.SetTexture, icon, tex)
    icon.artUpdating = false
end

local function applyAuraOverrideToItem(item)
    if not shouldOverrideAura(item) then
        return
    end
    local info = item.cooldownInfo
    local spellID = info.overrideSpellID or info.spellID
    if not spellID then
        return
    end

    -- Force the icon back to the spell's own texture
    applyIconOverrideToItem(item)

    local cf = item.Cooldown
    if not cf or cf.artUpdating then
        return
    end

    cf.artUpdating = true
    pcall(function()
        if cf.SetSwipeColor then
            cf:SetSwipeColor(OVERRIDE_SWIPE_R, OVERRIDE_SWIPE_G, OVERRIDE_SWIPE_B, OVERRIDE_SWIPE_A)
        end
        if cf.SetUseAuraDisplayTime then
            cf:SetUseAuraDisplayTime(false)
        end
        local durationObj = getSpellDurationObject(spellID)
        if durationObj and cf.SetCooldownFromDurationObject then
            cf:SetCooldownFromDurationObject(durationObj)
        elseif cf.Clear then
            cf:Clear()
        end
    end)
    cf.artUpdating = false
end

-- Centering

local function isHorizontal(v)
    return v.IsHorizontal and v:IsHorizontal() or v.isHorizontal
end

local function centerViewer(self_, v, cfg)
    local shown, hidden = {}, {}
    iterItems(v, function(c)
        if c:IsShown() then
            shown[#shown + 1] = c
        else
            hidden[#hidden + 1] = c
        end
    end)
    if #shown == 0 and #hidden == 0 then
        return
    end

    local cmp = function(a, b)
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end
    table.sort(shown, cmp)
    table.sort(hidden, cmp)

    local ref = shown[1] or hidden[1]
    local w, h = ref:GetSize()
    if not w or w <= 0 or not h or h <= 0 then
        return
    end

    local padX = v.childXPadding or v.iconPadding or 0
    local padY = v.childYPadding or v.iconPadding or 0
    local horizontal = isHorizontal(v)

    if #shown == 0 then
        return
    end

    -- Shared centered layout
    local stride = v.stride
    if not stride or stride < 1 then
        stride = #shown
    end

    local rows = {}
    for i, c in ipairs(shown) do
        local rIdx = math.floor((i - 1) / stride) + 1
        rows[rIdx] = rows[rIdx] or {}
        rows[rIdx][#rows[rIdx] + 1] = c
    end

    for rIdx, row in ipairs(rows) do
        local count = #row
        if horizontal then
            local totalW = count * w + (count - 1) * padX
            local startX = -totalW / 2 + w / 2
            local yOff = -(rIdx - 1) * (h + padY) - h / 2
            for i, c in ipairs(row) do
                c:ClearAllPoints()
                c:SetPoint("CENTER", v, "TOP", startX + (i - 1) * (w + padX), yOff)
            end
        else
            local totalH = count * h + (count - 1) * padY
            local startY = totalH / 2 - h / 2
            local xOff = (rIdx - 1) * (w + padX) + w / 2
            for i, c in ipairs(row) do
                c:ClearAllPoints()
                c:SetPoint("CENTER", v, "LEFT", xOff, startY - (i - 1) * (h + padY))
            end
        end
    end
end

local function onItemRefreshData(item)
    if not CDMTweaks:IsEnabled() then
        return
    end
    maybeApplyFontToItem(CDMTweaks, item)
    if CDMTweaks.db.auraOverride then
        applyAuraOverrideToItem(item)
    end
end

local function onItemActiveStateChanged(item)
    if not CDMTweaks:IsEnabled() then
        return
    end
    local name = item.artCDMViewer
    local cfg = name and VIEWER_CONFIG[name]
    if not cfg or not cfg.centerKey then
        return
    end
    if not CDMTweaks.db[cfg.centerKey] then
        return
    end
    local v = item:GetParent()
    if v then
        centerViewer(CDMTweaks, v, cfg)
    end
end

local function hookItem(item, cfg, name)
    if item.artCDMHooked then
        return
    end
    item.artCDMHooked = true
    item.artCDMViewer = name

    if item.RefreshData then
        hooksecurefunc(item, "RefreshData", onItemRefreshData)
    end

    -- Aura override
    if cfg.kind == "cooldown" and item.Cooldown and item.Cooldown.SetCooldown then
        hooksecurefunc(item.Cooldown, "SetCooldown", function(cf)
            if cf.artUpdating then
                return
            end
            if not CDMTweaks:IsEnabled() then
                return
            end
            if not CDMTweaks.db.auraOverride then
                return
            end
            applyAuraOverrideToItem(item)
        end)
    end

    -- Icon texture override
    if cfg.kind == "cooldown" and item.Icon and type(item.Icon.SetTexture) == "function" then
        hooksecurefunc(item.Icon, "SetTexture", function(icon)
            if icon.artUpdating then
                return
            end
            if not CDMTweaks:IsEnabled() then
                return
            end
            if not CDMTweaks.db.auraOverride then
                return
            end
            applyIconOverrideToItem(item)
        end)
    end

    if (cfg.kind == "buffIcon" or cfg.kind == "buffBar") and item.OnActiveStateChanged then
        hooksecurefunc(item, "OnActiveStateChanged", onItemActiveStateChanged)
    end
end

local function scanViewer(self_, name, cfg, v)
    v = v or viewer(name)
    if not v then
        return
    end
    iterItems(v, function(item)
        hookItem(item, cfg, name)
        maybeApplyFontToItem(self_, item)
        if cfg.kind == "cooldown" and self_.db.auraOverride then
            applyAuraOverrideToItem(item)
        end
    end)
end

local function scanAll(self_)
    for name, cfg in pairs(VIEWER_CONFIG) do
        scanViewer(self_, name, cfg)
    end
end

local function restoreAll(self_)
    for name, cfg in pairs(VIEWER_CONFIG) do
        local v = viewer(name)
        if v then
            iterItems(v, function(item)
                restoreFontOnItem(item)
            end)
            if v.Layout then
                pcall(v.Layout, v)
            end
        end
    end
end

-- Hook

function CDMTweaks:InstallHooks()
    if hooksInstalled then
        return
    end
    local anyInstalled = false
    for name, cfg in pairs(VIEWER_CONFIG) do
        local v = viewer(name)
        if v then
            if cfg.centerKey and v.Layout then
                hooksecurefunc(v, "Layout", function(self_)
                    if not CDMTweaks:IsEnabled() then
                        return
                    end
                    if not CDMTweaks.db[cfg.centerKey] then
                        return
                    end
                    centerViewer(CDMTweaks, self_, cfg)
                end)
            end
            if v.RefreshLayout then
                hooksecurefunc(v, "RefreshLayout", function(self_)
                    if not CDMTweaks:IsEnabled() then
                        return
                    end
                    scanViewer(CDMTweaks, name, cfg, self_)
                end)
            end

            if v.OnAcquireItemFrame then
                hooksecurefunc(v, "OnAcquireItemFrame", function(_, itemFrame)
                    if not CDMTweaks:IsEnabled() then
                        return
                    end
                    hookItem(itemFrame, cfg, name)
                    maybeApplyFontToItem(CDMTweaks, itemFrame)
                    if cfg.kind == "cooldown" and CDMTweaks.db.auraOverride then
                        applyAuraOverrideToItem(itemFrame)
                    end
                end)
            end
            anyInstalled = true
        end
    end
    if anyInstalled then
        hooksInstalled = true
    end
end

-- Lifecycle

function CDMTweaks:Apply()
    if InCombatLockdown() then
        self._pendingApply = true
        return
    end
    self._pendingApply = nil

    if type(self.db.stackFont) ~= "table" then
        self.db.stackFont = {}
    end

    if not self:IsEnabled() then
        restoreAll(self)
        return
    end

    self:InstallHooks()
    scanAll(self)

    for name, cfg in pairs(VIEWER_CONFIG) do
        if cfg.centerKey then
            local v = viewer(name)
            if v and v.Layout then
                pcall(v.Layout, v)
            end
        end
    end
end

function CDMTweaks:Refresh()
    self:Apply()
end

function CDMTweaks:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Apply")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnRegenEnabled")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Apply")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Apply")
    self:Apply()
end

function CDMTweaks:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if InCombatLockdown() then
        self._pendingRevert = true
        return
    end
    restoreAll(self)
end

function CDMTweaks:OnRegenEnabled()
    if self._pendingApply then
        self:Apply()
    end
    if self._pendingRevert then
        self._pendingRevert = nil
        restoreAll(self)
    end
end

do
    local QoL = E:GetModule("QualityOfLife", true)
    if QoL and QoL.RegisterFeature then
        QoL:RegisterFeature("CDMTweaks", {
            order = 30,
            labelKey = "QoL_CDMTweaks",
            descKey = "QoL_CDMTweaksDesc",
            moduleName = "QoL_CDMTweaks"
        })
    end
end
