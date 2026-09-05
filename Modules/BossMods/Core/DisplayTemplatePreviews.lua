local E = unpack(ART)
local Displays = E:GetModule("BossMods").DisplayTemplates

local samples = {
    bar = {{"VenomousAbyssAbilityAlerts", "bar", 1300751}, {"VenomousAbyssAbilityAlerts", "bar", 1292188}},
    text = {{"UlatekWrongTarget"}, {"CoiledAltarKicker", "nextTextPosition"}},
    buttons = {{"UlatekIntermission", "buttons"}},
    panel = {{"UlatekIntermission", "assignment"}},
    indicator = {{"SszorakCompass"}},
    icon = {{"CoiledAltarKicker"}},
    aura = {{"UlatekFangs"}},
    map = {{"LuraMap", "intermission"}}
}

local function hideHandle(handle)
    if handle.Hide then handle:Hide() end
    handle.frame:Hide()
end

local function showHandle(handle)
    if handle.previewSuppressed then handle.frame:SetAlpha(handle.previewAlpha or 1) end
    handle.previewSuppressed = false
    if handle.Show then handle:Show() else handle.frame:Show() end
    handle.frame:SetFrameStrata("DIALOG")
    handle.frame:EnableMouse(false)
    handle.previewAlpha = handle.frame:GetAlpha()
end

local function refreshHandle(handle, hidden)
    if handle.previewSuppressed then handle.frame:SetAlpha(handle.previewAlpha or 1) end
    if handle.Refresh then handle:Refresh() end
    handle.previewAlpha = handle.frame:GetAlpha()
    handle.previewSuppressed = hidden == true
    if hidden then handle.frame:SetAlpha(0) end
end

local function layoutHandles(handles, getPosition, isIndependent)
    local groups = {}
    for _, handle in ipairs(handles) do
        local frame = handle.frame
        local category = handle.category
        local settings = Displays:GetSettings(category)
        local pos = getPosition(handle)
        if frame:IsShown() and Displays.templates[category].stack and not isIndependent(handle) then
            local horizontal = settings.growth == "LEFT" or settings.growth == "RIGHT"
            local sign = (settings.growth == "LEFT" or settings.growth == "DOWN") and -1 or 1
            local size = (horizontal and frame:GetWidth() or frame:GetHeight())
                * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local low, high = horizontal and "LEFT" or "BOTTOM", horizontal and "RIGHT" or "TOP"
            local point = pos.point or "CENTER"
            local fraction = point:find(low, 1, true) and 0 or point:find(high, 1, true) and 1 or 0.5
            local before = size * (sign > 0 and fraction or 1 - fraction)
            local offset = groups[category] and groups[category] + settings.spacing + before or 0
            groups[category] = offset + size - before
            pos = {point = pos.point, relPoint = pos.relPoint,
                x = pos.x + (horizontal and offset * sign or 0),
                y = pos.y + (horizontal and 0 or offset * sign)}
        end
        E:ApplyFramePosition(frame, pos)
    end
end

function Displays:CreatePreview(category, index)
    local sample = samples[category] and samples[category][index or 1]
    local mod = sample and E:GetModule("BossMods_" .. sample[1], true)
    if not mod or not mod.CreateAnchorPreview then return end
    local handle = mod:CreateAnchorPreview(sample[2], sample[3])
    if handle then
        handle.category = category
        handle.frame:Hide()
    end
    return handle
end

function Displays:LayoutPreviews(category)
    if not self.previewActive then return end
    layoutHandles(self.previews[category] or {}, function()
        local pos = self:GetSettings(category)
        return {point = pos.point, relPoint = "CENTER", x = pos.x, y = pos.y}
    end, function() return false end)
end

function Displays:UpdatePreviewDriver()
    if not self.previewDriver then return end
    if self.previewActive or next(self.modulePreviews or {}) then
        self.previewDriver:Show()
    else
        self.previewDriver:Hide()
    end
end

function Displays:HidePreviews()
    self.previewActive = false
    for _, previews in pairs(self.previews or {}) do
        for _, handle in ipairs(previews) do hideHandle(handle) end
    end
    self:UpdatePreviewDriver()
    E:SendMessage("ART_DISPLAY_ANCHORS_CHANGED")
end

function Displays:ShowPreviews()
    if InCombatLockdown() then return end
    self:HideMovers()
    self:HideModulePreviews()
    self:HidePreviews()
    self.previews = self.previews or {}
    self.previewActive = true
    for _, category in ipairs(self.templateOrder) do
        local previews = self.previews[category] or {}
        self.previews[category] = previews
        for index = 1, (self.templates[category].previewCount or 1) do
            previews[index] = previews[index] or self:CreatePreview(category, index)
            if previews[index] then showHandle(previews[index]) end
        end
        self:LayoutPreviews(category)
    end
    self:UpdatePreviewDriver()
    E:SendMessage("ART_DISPLAY_ANCHORS_CHANGED")
end

local function previewKey(mod, bossKey)
    return mod.moduleName .. ":" .. (bossKey or "module")
end

function Displays:IsModulePreviewing(mod, bossKey)
    return self.modulePreviews and self.modulePreviews[previewKey(mod, bossKey)] ~= nil or false
end

function Displays:LayoutModulePreview(record)
    layoutHandles(record.handles or {}, function(handle)
        if handle.getPosition then return handle.getPosition() end
        return self:GetPosition(handle.entry)
    end, function(handle)
        if handle.independent then return handle.independent() end
        return self:IsIndependent(handle.entry)
    end)
end

function Displays:SetModulePreview(mod, enabled, bossKey)
    self.modulePreviews = self.modulePreviews or {}
    local key = previewKey(mod, bossKey)
    local record = self.modulePreviews[key]
    if not enabled then
        if not record then return end
        self.modulePreviews[key] = nil
        if record.native then mod:SetPreviewMode(record.previousPreview) end
        for _, handle in ipairs(record.handles or {}) do hideHandle(handle) end
        self:UpdatePreviewDriver()
        E:SendMessage("ART_DISPLAY_PREVIEW_CHANGED")
        return
    end
    if record or InCombatLockdown() then return end
    self:HidePreviews()
    self:HideModulePreviews()
    record = {mod = mod, bossKey = bossKey}
    self.modulePreviewCache = self.modulePreviewCache or {}
    if mod.CreateModulePreviews then
        record.createHandles = function() return mod:CreateModulePreviews(bossKey) end
        record.handles = record.createHandles()
    elseif mod.moduleName == "BossMods_UlatekStageTwoAssignment" then
        local abilityMod = mod:GetAbilityModule()
        record.createHandles = function()
            return abilityMod and abilityMod:CreateModulePreviews("Ulatek", -3492006) or {}
        end
        record.handles = record.createHandles()
        record.editOwner = abilityMod
    elseif mod.SetPreviewMode then
        record.native = true
        record.previousPreview = mod.previewMode == true
        mod:SetPreviewMode(true)
    elseif mod.CreateAnchorPreview then
        record.handles = self.modulePreviewCache[key] or {}
        self.modulePreviewCache[key] = record.handles
        if #record.handles == 0 then
            if mod.moduleName == "BossMods_LuraMap" then
                local handle = mod:CreateAnchorPreview("module")
                handle.category = "map"
                handle.getPosition = function()
                    local layout = handle.positionKey or "intermission"
                    return self:GetPosition(self:GetEntry(mod, layout))
                end
                handle.independent = function() return true end
                record.handles[1] = handle
            else
                for _, entry in ipairs(self:GetModuleEntries(mod)) do
                    local kind = entry.definition.key
                    if mod.moduleName == "BossMods_UlatekIntermission" and kind == "clicker" then kind = "buttons" end
                    local handle = mod:CreateAnchorPreview(kind)
                    if handle then
                        handle.entry = entry
                        handle.category = entry.definition.category
                        record.handles[#record.handles + 1] = handle
                    end
                end
            end
        end
    end
    self.modulePreviews[key] = record
    for _, handle in ipairs(record.handles or {}) do showHandle(handle) end
    self:LayoutModulePreview(record)
    self:UpdatePreviewDriver()
    E:SendMessage("ART_DISPLAY_PREVIEW_CHANGED")
end

function Displays:HideModulePreviews()
    local records = {}
    for _, record in pairs(self.modulePreviews or {}) do records[#records + 1] = record end
    for _, record in ipairs(records) do self:SetModulePreview(record.mod, false, record.bossKey) end
end

local refresh = CreateFrame("Frame")
Displays.previewDriver = refresh
refresh:Hide()
local elapsed = 0
refresh:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    if Displays.previewActive then
        for category, previews in pairs(Displays.previews or {}) do
            for _, handle in ipairs(previews) do
                refreshHandle(handle, false)
            end
            Displays:LayoutPreviews(category)
        end
    end
    for _, record in pairs(Displays.modulePreviews or {}) do
        if record.createHandles then
            local previous, current = {}, {}
            for _, handle in ipairs(record.handles) do previous[handle] = true end
            record.handles = record.createHandles()
            for _, handle in ipairs(record.handles) do
                current[handle] = true
                if not previous[handle] then showHandle(handle) end
            end
            for handle in pairs(previous) do
                if not current[handle] then hideHandle(handle) end
            end
        end
        for _, handle in ipairs(record.handles or {}) do
            refreshHandle(handle, (record.editOwner or record.mod).editMode == true)
        end
        Displays:LayoutModulePreview(record)
    end
end)

local callbacks = E:NewCallbackHandle()
local function hideAll()
    Displays:HidePreviews()
    Displays:HideModulePreviews()
end
callbacks:RegisterMessage("ART_PROFILE_CHANGED", hideAll)
callbacks:RegisterEvent("PLAYER_REGEN_DISABLED", hideAll)
