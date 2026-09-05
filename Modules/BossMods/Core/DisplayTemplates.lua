local E, L, P = unpack(ART)
local BossMods = E:GetModule("BossMods")
local Shared = BossMods.Engines.Shared

local Displays = {templates = {}, templateOrder = {}, definitions = {}, entries = {}, movers = {}}
BossMods.DisplayTemplates = Displays

local function copyPosition(pos)
    pos = pos or {}
    return {point = pos.point or "CENTER", relPoint = pos.relPoint, x = pos.x or 0, y = pos.y or 0}
end

local function pathValue(root, path)
    for part in (path or "position"):gmatch("[^.]+") do
        root = type(root) == "table" and root[part] or nil
    end
    return root
end

local function writePath(root, path, value)
    local parts = {}
    for part in (path or "position"):gmatch("[^.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        root[parts[i]] = root[parts[i]] or {}
        root = root[parts[i]]
    end
    root[parts[#parts]] = value
end

local function samePosition(a, b)
    a, b = a or {}, b or {}
    return (a.point or "CENTER") == (b.point or "CENTER")
        and (a.relPoint or a.point or "CENTER") == (b.relPoint or b.point or "CENTER")
        and math.abs((tonumber(a.x) or 0) - (tonumber(b.x) or 0)) < 0.01
        and math.abs((tonumber(a.y) or 0) - (tonumber(b.y) or 0)) < 0.01
end

function Displays:RegisterTemplate(key, definition)
    assert(not self.templates[key], "Display template already registered: " .. key)
    self.templates[key] = definition
    self.templateOrder[#self.templateOrder + 1] = key
end

Displays:RegisterTemplate("bar", {label = L["BossMods_RaidAnchorBar"], x = -400, y = 80, spacing = 4, stack = true, width = 300, height = 24, previewCount = 2})
Displays:RegisterTemplate("text", {label = L["BossMods_RaidAnchorText"], x = 0, y = 200, spacing = 8, stack = true, width = 400, height = 48, previewCount = 2})
Displays:RegisterTemplate("buttons", {label = L["BossMods_RaidAnchorButtons"], x = 0, y = -150, spacing = 8, width = 270, height = 40})
Displays:RegisterTemplate("panel", {label = L["BossMods_RaidAnchorPanel"], x = 350, y = 100, spacing = 16, stack = true, width = 300, height = 100})
Displays:RegisterTemplate("indicator", {label = L["BossMods_RaidAnchorIndicator"], x = 0, y = 0, spacing = 8, width = 120, height = 120})
Displays:RegisterTemplate("icon", {label = L["BossMods_RaidAnchorIcon"], x = -250, y = -80, spacing = 8, width = 64, height = 64})
Displays:RegisterTemplate("aura", {label = L["BossMods_RaidAnchorAura"], x = 350, y = -150, spacing = 12, width = 260, height = 100})
Displays:RegisterTemplate("map", {label = L["BossMods_RaidAnchorMap"], x = -450, y = -180, spacing = 12, width = 280, height = 180})

function Displays:GetSettings(category)
    local template = assert(self.templates[category], "Unknown display template: " .. tostring(category))
    local defaults = E:GetModule("BossMods_AbilityAlertDefaults")
    defaults.db = defaults.db or E:GetDB(defaults.moduleName)
    defaults.db.raidAnchors = defaults.db.raidAnchors or {}
    local settings = defaults.db.raidAnchors[category]
    if not settings then
        settings = {}
        for key, value in pairs(defaults.db.groupAnchors and defaults.db.groupAnchors[category] or {}) do
            settings[key] = value
        end
        defaults.db.raidAnchors[category] = settings
    end
    settings.point = Shared.NormalizeAnchorPoint(settings.point)
    settings.x = tonumber(settings.x) or template.x
    settings.y = tonumber(settings.y) or template.y
    settings.spacing = math.max(0, tonumber(settings.spacing) or template.spacing)
    local growth = settings.growth
    settings.growth = (growth == "UP" or growth == "DOWN" or growth == "LEFT" or growth == "RIGHT")
        and growth or template.growth or "DOWN"
    return settings
end

function Displays:Register(moduleName, key, definition)
    assert(self.templates[definition.category], "Display category required")
    local definitions = self.definitions[moduleName] or {}
    self.definitions[moduleName] = definitions
    definition.key = key
    definitions[key] = definition
    local entry = self.entries[moduleName .. ":" .. key]
    if entry then entry.definition = definition end
end

function Displays:GetEntry(mod, key)
    local id = mod.moduleName .. ":" .. key
    local entry = self.entries[id]
    if not entry then
        local definition = self.definitions[mod.moduleName] and self.definitions[mod.moduleName][key]
        if not definition then return end
        entry = {id = id, mod = mod, definition = definition}
        self.entries[id] = entry
    end
    return entry
end

function Displays:GetModuleEntries(mod)
    local entries = {}
    for key, definition in pairs(self.definitions[mod.moduleName] or {}) do
        if not definition.hidden then entries[#entries + 1] = self:GetEntry(mod, key) end
    end
    table.sort(entries, function(a, b)
        local ao, bo = a.definition.order or 100, b.definition.order or 100
        return ao < bo or ao == bo and a.id < b.id
    end)
    return entries
end

function Displays:GetIndividualPosition(entry)
    local def = entry.definition
    return copyPosition(def.getPosition and def.getPosition(entry.mod)
        or pathValue(entry.mod.db, def.path) or def.defaultPosition)
end

function Displays:IsIndependent(entry)
    local def, mod = entry.definition, entry.mod
    if def.getIndependent then return def.getIndependent(mod) == true end
    mod.db.displayOverrides = mod.db.displayOverrides or {}
    if mod.db.displayOverrides[def.key] == nil then
        local original = def.defaultPosition or pathValue(P.modules[mod.moduleName], def.path)
        mod.db.displayOverrides[def.key] = def.independentByDefault == true
            or not samePosition(self:GetIndividualPosition(entry), original)
    end
    return mod.db.displayOverrides[def.key] == true
end

function Displays:SetIndependent(entry, independent)
    local def = entry.definition
    if def.setIndependent then
        def.setIndependent(entry.mod, independent == true)
    else
        entry.mod.db.displayOverrides = entry.mod.db.displayOverrides or {}
        entry.mod.db.displayOverrides[def.key] = independent == true
    end
    if not independent and self.movers[entry.id] then self.movers[entry.id]:Hide() end
    self:Layout(def.category)
    self:RefreshMovers()
    E:SendMessage("ART_DISPLAY_POSITION_CHANGED")
end

function Displays:GetPosition(entry)
    if self:IsIndependent(entry) then return self:GetIndividualPosition(entry) end
    local pos = copyPosition(self:GetSettings(entry.definition.category))
    pos.relPoint = "CENTER"
    return pos
end

function Displays:Forget(mod, key)
    local id = mod.moduleName .. ":" .. key
    local entry = self.entries[id]
    if entry and entry.frame then entry.frame.artDisplayEntry = nil end
    self.entries[id] = nil
    if self.definitions[mod.moduleName] then self.definitions[mod.moduleName][key] = nil end
    if self.movers[id] then self.movers[id]:Hide() end
    if entry then self:Layout(entry.definition.category) end
end

function Displays:SetPosition(entry, position)
    local def = entry.definition
    if def.setPosition then
        def.setPosition(entry.mod, copyPosition(position))
    else
        local saved = pathValue(entry.mod.db, def.path)
        local pos = copyPosition(position)
        if saved and saved.coordSpace then pos.coordSpace = saved.coordSpace end
        writePath(entry.mod.db, def.path, pos)
    end
    self:SetIndependent(entry, true)
end

function Displays:SetGroupPosition(category, position)
    local settings = self:GetSettings(category)
    settings.point = Shared.NormalizeAnchorPoint(position.point)
    settings.x, settings.y = position.x or 0, position.y or 0
    self:Layout(category)
    self:RefreshMovers()
    E:SendMessage("ART_DISPLAY_POSITION_CHANGED")
end

function Displays:ResetGroupPosition(category)
    if InCombatLockdown() then return end
    local template = self.templates[category]
    self:SetGroupPosition(category, {point = "CENTER", x = template.x, y = template.y})
end

function Displays:ResetPositions()
    if InCombatLockdown() then return end
    self:BeginUpdate()
    for _, category in ipairs(self.templateOrder) do
        local settings, template = self:GetSettings(category), self.templates[category]
        settings.point, settings.x, settings.y = "CENTER", template.x, template.y
    end
    for moduleName, definitions in pairs(self.definitions) do
        local mod = E:GetModule(moduleName, true)
        if mod and mod.db then
            for key, def in pairs(definitions) do
                if not def.getPosition then
                    local original = def.defaultPosition or pathValue(P.modules[moduleName], def.path)
                    local position = copyPosition(original)
                    if original then position.coordSpace = original.coordSpace end
                    writePath(mod.db, def.path, position)
                end
                if def.setIndependent then def.setIndependent(mod, false)
                else
                    mod.db.displayOverrides = mod.db.displayOverrides or {}
                    mod.db.displayOverrides[key] = false
                end
            end
        end
    end
    for _, mod in E:IterateModules() do
        if mod.db and mod.ResetDisplayPositions then mod:ResetDisplayPositions() end
    end
    self:EndUpdate()
    self:Refresh()
    E:SendMessage("ART_DISPLAY_POSITION_CHANGED")
end

function Displays:Place(mod, key, frame)
    if not frame then return end
    local entry = assert(self:GetEntry(mod, key), "Unregistered module display: " .. mod.moduleName .. ":" .. key)
    entry.frame = frame
    frame.artDisplayEntry = entry
    if not frame.artDisplayHooks then
        local function changed()
            local current = frame.artDisplayEntry
            if current then self:Layout(current.definition.category) end
        end
        frame:HookScript("OnShow", changed)
        frame:HookScript("OnHide", changed)
        frame:HookScript("OnSizeChanged", changed)
        frame.artDisplayHooks = true
    end
    self:Layout(entry.definition.category)
end

function Displays:BeginUpdate()
    self.updateDepth = (self.updateDepth or 0) + 1
end

function Displays:EndUpdate()
    self.updateDepth = math.max(0, (self.updateDepth or 0) - 1)
    if self.updateDepth > 0 then return end
    local dirty = self.dirtyCategories or {}
    self.dirtyCategories = {}
    for category in pairs(dirty) do self:Layout(category) end
end

function Displays:Layout(category)
    if (self.updateDepth or 0) > 0 then
        self.dirtyCategories = self.dirtyCategories or {}
        self.dirtyCategories[category] = true
        return
    end
    if self.layoutActive then return end
    self.layoutActive = true
    local settings, template = self:GetSettings(category), self.templates[category]
    local entries = {}
    for _, entry in pairs(self.entries) do
        if entry.frame and entry.mod.db and entry.definition.category == category then
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b)
        local ao, bo = a.definition.order or 100, b.definition.order or 100
        return ao < bo or ao == bo and a.id < b.id
    end)
    local edge
    local horizontal = settings.growth == "LEFT" or settings.growth == "RIGHT"
    local positive = settings.growth == "RIGHT" or settings.growth == "UP"
    for _, entry in ipairs(entries) do
        local frame = entry.frame
        local independent = self:IsIndependent(entry)
        local position = self:GetPosition(entry)
        if not independent and template.stack and frame:IsShown() then
            local height = entry.definition.getHeight and entry.definition.getHeight(entry.mod) or frame:GetHeight()
            local size = horizontal and frame:GetWidth() or height
            local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
            size = math.max(1, size or 1) * scale
            local point = position.point
            local low, high = horizontal and "LEFT" or "BOTTOM", horizontal and "RIGHT" or "TOP"
            local fraction = point:find(low, 1, true) and 0 or point:find(high, 1, true) and 1 or 0.5
            local before = size * (positive and fraction or 1 - fraction)
            local after = size - before
            local offset = edge and edge + settings.spacing + before or 0
            local axis = horizontal and "x" or "y"
            position[axis] = position[axis] + offset * (positive and 1 or -1)
            edge = offset + after
        end
        if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
            E:RunWhenOutOfCombat("BossMods:DisplayTemplates:" .. category, function() self:Layout(category) end)
        else
            E:ApplyFramePosition(frame, position)
        end
    end
    self.layoutActive = false
    if self.LayoutPreviews then self:LayoutPreviews(category) end
end

function Displays:Refresh()
    for _, category in ipairs(self.templateOrder) do self:Layout(category) end
    self:RefreshMovers()
end

function Displays:RefreshMovers()
    for _, mover in pairs(self.movers) do
        if mover:IsShown() and not mover.dragging then
            local pos = mover.entry and self:GetPosition(mover.entry) or copyPosition(self:GetSettings(mover.category))
            if not mover.entry then pos.relPoint = "CENTER" end
            E:ApplyFramePosition(mover, pos)
        end
    end
end

function Displays:ShowMover(category, entry)
    if InCombatLockdown() then return end
    if entry and not self:IsIndependent(entry) then entry = nil end
    local id = entry and entry.id or category
    local mover = self.movers[id]
    if not mover then
        mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        mover:SetFrameStrata("DIALOG")
        mover:SetClampedToScreen(true)
        mover:SetMovable(true)
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        mover:SetBackdrop({bgFile = E.media.blankTex, edgeFile = E.media.blankTex, edgeSize = 1})
        mover:SetBackdropColor(0.05, 0.12, 0.18, 0.9)
        mover:SetBackdropBorderColor(0.2, 0.7, 1, 1)
        local label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("CENTER")
        label:SetJustifyH("CENTER")
        label:SetWordWrap(true)
        label:SetNonSpaceWrap(true)
        mover.label = label
        mover:SetScript("OnDragStart", function(frame)
            if InCombatLockdown() then return end
            frame.dragging = true
            frame:StartMoving()
        end)
        mover:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            frame.dragging = false
            local pos = E:GetFramePosition(frame)
            if frame.entry then self:SetPosition(frame.entry, pos)
            else self:SetGroupPosition(frame.category, pos) end
        end)
        self.movers[id] = mover
    end
    local template = self.templates[category]
    mover.category, mover.entry = category, entry
    mover:SetSize(math.max(160, template.width), math.max(36, template.height))
    mover.label:SetWidth(mover:GetWidth() - 16)
    mover.label:SetText((entry and entry.definition.label or template.label) .. "\n" .. L["BossMods_AnchorMoveHint"])
    mover:SetHeight(math.max(mover:GetHeight(), mover.label:GetStringHeight() + 16))
    mover:Show()
    self:RefreshMovers()
    return mover
end

function Displays:AreMoversShown()
    for _, mover in pairs(self.movers) do if mover:IsShown() then return true end end
    return false
end

function Displays:HideMovers()
    for _, mover in pairs(self.movers) do
        mover:StopMovingOrSizing()
        mover.dragging = false
        mover:Hide()
    end
    E:SendMessage("ART_DISPLAY_ANCHORS_CHANGED")
end

local callbacks = E:NewCallbackHandle()
callbacks:RegisterMessage("ART_PROFILE_CHANGED", function() Displays:HideMovers(); Displays:Refresh() end)
callbacks:RegisterEvent("PLAYER_REGEN_DISABLED", function() Displays:HideMovers() end)
