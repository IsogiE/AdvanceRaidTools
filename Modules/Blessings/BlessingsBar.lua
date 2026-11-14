local E, L = unpack(ART)
local CreateFrame, C_Timer = E:DiagnosticBindings("Modules/Blessings/BlessingsBar")
local Mod = E:GetModule("Blessings")

local CLASSES, BLESSINGS, AURAS = Mod.CLASSES, Mod.BLESSINGS, Mod.AURAS
local SLOTS = #CLASSES + 1
local WIDTH, ROW, GAP, HANDLE = 190, 22, 3, 16
local FILL, BACK, DURATION = 0.8, 0.22, 3600
local SCALE_MIN, SCALE_MAX = 0.6, 1.6
local SOON, SOON_SHARE = 300, 0.25
local REFRESH_DELAY, TICK, RESCAN_TICKS = 0.25, 2, 5
local MAX_AURAS, MAX_NAMES = 80, 10
local OOC_KEY = "Blessings:Bar"
local FRAME_NAME = "ART_BlessingsBar"
local RED, AMBER = {0.9, 0.25, 0.25}, {1, 0.75, 0.2}
local NEED, GOLD = {0.36, 0.07, 0.07}, {1, 0.82, 0}
local LOCK_FADE = 0.3
local DIM, WHITE = {0.6, 0.6, 0.6}, {1, 1, 1}
local ORDER = {missing = 1, soon = 2, ok = 5, away = 6}

Mod.CLASS_ICONS = {
    WARRIOR = "Interface\\Icons\\ClassIcon_Warrior", ROGUE = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST = "Interface\\Icons\\ClassIcon_Priest", DRUID = "Interface\\Icons\\ClassIcon_Druid",
    PALADIN = "Interface\\Icons\\ClassIcon_Paladin", HUNTER = "Interface\\Icons\\ClassIcon_Hunter",
    MAGE = "Interface\\Icons\\ClassIcon_Mage", WARLOCK = "Interface\\Icons\\ClassIcon_Warlock",
    SHAMAN = "Interface\\Icons\\ClassIcon_Shaman"
}

local STEP_BEFORE = [[return nil, "step"]]
local STEP_AFTER = [[
    if down then return end
    local count = self:GetAttribute("art-count") or 0
    if count < 2 then return end
    local index = (self:GetAttribute("art-index") or 1) % count + 1
    self:SetAttribute("art-index", index)
    self:SetAttribute("unit", self:GetAttribute("art-unit" .. index))
    self:SetAttribute("spell1", self:GetAttribute("art-left" .. index))
    self:SetAttribute("spell2", self:GetAttribute("art-right" .. index))
]]

local blessingBySpell, auraBySpell = {}, {}
for index, entry in pairs(BLESSINGS) do
    for _, id in ipairs(entry.ranks) do blessingBySpell[id] = index end
    for _, id in ipairs(entry.greater) do blessingBySpell[id] = index end
end
for index, entry in pairs(AURAS) do
    for _, id in ipairs(entry.ranks) do auraBySpell[id] = index end
end

local function safe(value)
    if E:IsSecret(value) then return nil end
    return value
end

local function ask(fn, default, ...)
    if not fn then return default end
    local ok, value = pcall(fn, ...)
    if not ok or value == nil or E:IsSecret(value) then return default end
    return value
end

local function spellName(id)
    local name = id and C_Spell and C_Spell.GetSpellName and ask(C_Spell.GetSpellName, nil, id)
    if type(name) == "string" and name ~= "" then return name end
    return id
end

local names
local function spellNames()
    if names then return names end
    names = {blessings = {}, auras = {}}
    for index, entry in pairs(BLESSINGS) do
        for _, id in ipairs({entry.ranks[1], entry.greater[1]}) do
            local name = spellName(id)
            if type(name) == "string" then names.blessings[name] = index end
        end
    end
    for index, entry in pairs(AURAS) do
        local name = spellName(entry.ranks[1])
        if type(name) == "string" then names.auras[name] = index end
    end
    return names
end

local function normalSpell(blessing)
    local entry = BLESSINGS[blessing]
    local rank = entry and Mod.KnownRank(entry)
    return rank and spellName(entry.ranks[rank]) or nil
end

local function greaterSpell(blessing)
    local entry = BLESSINGS[blessing]
    if not entry then return end
    for i = #entry.greater, 1, -1 do
        if Mod.Knows(entry.greater[i]) then return spellName(entry.greater[i]) end
    end
end

local function auraSpell(aura)
    local entry = AURAS[aura]
    local rank = entry and Mod.KnownRank(entry)
    return rank and spellName(entry.ranks[rank]) or nil
end

local function aurasHidden()
    return C_Secrets and ask(C_Secrets.ShouldAurasBeSecret, false) == true
end

local function readAuras(unit, bySpell, byName, mineOnly)
    if aurasHidden() or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local found, hidden = {}, false
    for index = 1, MAX_AURAS do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok or E:IsSecret(aura) then return end
        if not aura then break end
        local id, name = safe(aura.spellId), safe(aura.name)
        if not id and not name then
            hidden = true
        else
            local key = (id and bySpell[id]) or (name and byName[name])
            local source = safe(aura.sourceUnit)
            if key and not (mineOnly and source and source ~= "player") then
                found[key] = {
                    expires = tonumber(safe(aura.expirationTime)),
                    duration = tonumber(safe(aura.duration))
                }
            end
        end
    end
    return found, hidden
end

local function inRange(spell, unit)
    if not (spell and C_Spell and C_Spell.IsSpellInRange) then return nil end
    return ask(C_Spell.IsSpellInRange, nil, spell, unit)
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function Mod:BarSettings()
    self.db.bar = type(self.db.bar) == "table" and self.db.bar or {}
    local bar = self.db.bar
    if bar.enabled == nil then bar.enabled = true end
    bar.scale = clamp(tonumber(bar.scale) or 1, SCALE_MIN, SCALE_MAX)
    bar.locked = bar.locked == true
    bar.position = type(bar.position) == "table" and bar.position or {}
    bar.position.point = type(bar.position.point) == "string" and bar.position.point or "CENTER"
    bar.position.x = tonumber(bar.position.x) or 0
    bar.position.y = tonumber(bar.position.y) or -200
    return bar
end

function Mod:BarTarget(member, blessing, own, now)
    local unit = member.unit
    local target = {unit = unit, name = member.name, blessing = blessing, own = own, spell = normalSpell(blessing)}
    self.barMemory = self.barMemory or {}
    local memory = self.barMemory[member.name]
    if memory and memory.blessing ~= blessing then memory = nil end

    if ask(UnitIsDeadOrGhost, false, unit) or not ask(UnitIsConnected, true, unit) then
        target.state = "away"
        return target
    end

    local found, hidden
    if not InCombatLockdown() then
        self.barAuras = self.barAuras or {}
        local seen = self.barAuras[unit]
        if not seen then
            seen = {}
            seen.found, seen.hidden = readAuras(unit, blessingBySpell, spellNames().blessings)
            self.barAuras[unit] = seen
        end
        found, hidden = seen.found, seen.hidden
    end
    local hit = found and found[blessing]
    if hit then
        target.expires = hit.expires and hit.expires > 0 and hit.expires or nil
        target.duration = (hit.duration or 0) > 0 and hit.duration or nil
        local left = target.expires and target.expires - now
        local limit = math.min(SOON, (hit.duration or 0) > 0 and hit.duration * SOON_SHARE or SOON)
        target.state = left and left < limit and "soon" or "ok"
    elseif found and not hidden then
        target.state = "missing"
    elseif memory then
        target.expires, target.duration = memory.expires, memory.duration
        target.state = memory.expires and memory.expires <= now and "missing" or memory.state
    else
        target.state = "ok"
    end
    self.barMemory[member.name] = {
        blessing = blessing, state = target.state, expires = target.expires, duration = target.duration
    }

    if target.state ~= "ok" then target.far = inRange(target.spell, unit) == false end
    return target
end

local function byUrgency(a, b)
    local ra, rb = ORDER[a.state], ORDER[b.state]
    if a.far and ra < ORDER.ok then ra = ra + 2 end
    if b.far and rb < ORDER.ok then rb = rb + 2 end
    if ra ~= rb then return ra < rb end
    local ea, eb = a.expires or math.huge, b.expires or math.huge
    if ea ~= eb then return ea < eb end
    return a.name < b.name
end

function Mod:AuraActive(aura)
    local found, hidden
    if not InCombatLockdown() then
        found, hidden = readAuras("player", auraBySpell, spellNames().auras, true)
    end
    if found and (found[aura] or not hidden) then
        self.barAuraActive = found[aura] ~= nil
    end
    return self.barAuraActive ~= false
end

function Mod:BarRows()
    local rows = {}
    if not self:IsPaladin() then return rows end
    local plan = self:OwnPlan()
    local now = GetTime()

    for classIndex, class in ipairs(CLASSES) do
        local members = self:MembersOfClass(classIndex)
        local targets, shared = {}, true
        for _, member in ipairs(members) do
            local blessing, own = self:BlessingFor(plan, member)
            if own or not blessing then shared = false end
            if blessing then
                local target = self:BarTarget(member, blessing, own, now)
                if target.spell then targets[#targets + 1] = target end
            end
        end
        if #targets > 0 then
            table.sort(targets, byUrgency)
            local greater = shared and #targets == #members and greaterSpell(plan.classes[classIndex]) or nil
            local steps = {}
            for _, target in ipairs(targets) do
                if target.state ~= "away" then
                    steps[#steps + 1] = {
                        unit = target.unit, left = greater or target.spell,
                        right = target.spell, blessing = target.blessing
                    }
                end
            end
            rows[#rows + 1] = {kind = "class", class = class, targets = targets, greater = greater, steps = steps}
        end
    end

    local aura = auraSpell(plan.aura or 0)
    if aura then
        rows[#rows + 1] = {
            kind = "aura", aura = plan.aura, active = self:AuraActive(plan.aura),
            steps = {{unit = "player", left = aura, right = aura}}
        }
    end
    return rows
end

local function firstName(name)
    return name:match("^(%S+)") or name
end

local function className(class)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
end

local function timeLeft(seconds)
    if seconds >= 60 then return ("%dm"):format(math.ceil(seconds / 60)) end
    return ("%ds"):format(math.max(0, math.floor(seconds)))
end

local function summarize(row, now)
    if row.kind == "aura" then
        if row.active then return "ok", "", 1 end
        return "missing", L["BlessingsBarOff"], 0
    end
    local missing, state, first = 0, "ok", nil
    for _, target in ipairs(row.targets) do
        if target.state ~= "away" and target.expires and target.expires <= now then target.state = "missing" end
        if target.state == "missing" then
            missing = missing + 1
        elseif target.state ~= "away" then
            if target.state == "soon" then state = "soon" end
            if target.expires and (not first or target.expires < first.expires) then first = target end
        end
    end
    if missing > 0 then return "missing", L["BlessingsBarMissing"]:format(missing), 0 end
    if not first then return state, "", 1 end
    local left = first.expires - now
    return state, timeLeft(left), clamp(left / (first.duration or DURATION), 0, 1)
end

local function currentStep(button)
    local row = button.row
    local count = row and #row.steps or 0
    if count == 0 then return end
    return row.steps[clamp(tonumber(button:GetAttribute("art-index")) or 1, 1, count)]
end

local function showTooltip(button)
    local row = button.row
    if not row then return end
    local step = currentStep(button)
    local now = GetTime()
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(step and step.left or button.title:GetText(), 1, 1, 1)
    if row.kind == "class" then
        local shown = 0
        for _, target in ipairs(row.targets) do
            if target.state == "missing" or target.state == "soon" then
                shown = shown + 1
                if shown <= MAX_NAMES then
                    local color = target.state == "missing" and RED or AMBER
                    local left = target.state == "soon" and target.expires and timeLeft(target.expires - now) or ""
                    GameTooltip:AddDoubleLine(firstName(target.name), left, color[1], color[2], color[3], color[1], color[2], color[3])
                end
            end
        end
        if shown > MAX_NAMES then GameTooltip:AddLine("+" .. (shown - MAX_NAMES), DIM[1], DIM[2], DIM[3]) end
        if shown == 0 then GameTooltip:AddLine(L["BlessingsBarDone"], DIM[1], DIM[2], DIM[3]) end
        if row.greater then GameTooltip:AddLine(L["BlessingsBarClicks"], DIM[1], DIM[2], DIM[3]) end
    end
    GameTooltip:Show()
end

local function setGlow(button, enabled)
    if button.glowing == enabled then return end
    local glow = E.Libs and E.Libs.LibCustomGlow
    if not glow then return end
    button.glowing = enabled
    if enabled then
        glow.ButtonGlow_Start(button.spell)
    else
        glow.ButtonGlow_Stop(button.spell)
    end
end

local function paintRow(button)
    local row = button.row
    if not row then return end
    local state, text, fill = summarize(row, GetTime())
    local step = currentStep(button)
    local entry = row.kind == "aura" and AURAS[row.aura] or BLESSINGS[(step or row.targets[1]).blessing]
    local class = row.class or "PALADIN"
    local r, g, b = E:ClassColorRGB(class)

    button.crest:SetTexture(Mod.CLASS_ICONS[class])
    button.icon:SetTexture(Mod.SpellIcon(entry))
    button.title:SetText(row.kind == "aura" and Mod.SpellName(entry) or className(class))
    button.bar:SetStatusBarColor(r * FILL, g * FILL, b * FILL)
    button.bar:SetValue(fill)
    if state == "missing" then
        button.back:SetVertexColor(NEED[1], NEED[2], NEED[3])
    else
        button.back:SetVertexColor(r * BACK, g * BACK, b * BACK)
    end

    local color = state == "soon" and AMBER or WHITE
    button.status:SetText(text)
    button.status:SetTextColor(color[1], color[2], color[3])
    setGlow(button, state == "missing")
    if GameTooltip:IsOwned(button) then showTooltip(button) end
end

local function createButton(root, index)
    local button = CreateFrame("Button", FRAME_NAME .. "Row" .. index, root, "SecureActionButtonTemplate")
    button:SetSize(WIDTH, ROW)
    button:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -(index - 1) * (ROW + GAP))
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type1", "spell")
    button:SetAttribute("type2", "spell")

    local edge = button:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 1)

    button.crest = button:CreateTexture(nil, "ARTWORK")
    button.crest:SetPoint("TOPLEFT", 1, -1)
    button.crest:SetSize(ROW - 2, ROW - 2)
    button.crest:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.spell = CreateFrame("Frame", nil, button)
    button.spell:SetPoint("TOPRIGHT", -1, -1)
    button.spell:SetSize(ROW - 2, ROW - 2)
    button.spell:EnableMouse(false)
    button.icon = button.spell:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local texture = E:FetchStatusBar()
    local bar = CreateFrame("StatusBar", nil, button)
    bar:SetPoint("TOPLEFT", ROW, -1)
    bar:SetPoint("BOTTOMRIGHT", -ROW, 1)
    bar:SetStatusBarTexture(texture)
    bar:SetMinMaxValues(0, 1)
    bar:EnableMouse(false)
    button.bar = bar

    button.back = bar:CreateTexture(nil, "BACKGROUND")
    button.back:SetAllPoints()
    button.back:SetTexture(texture)

    button.hover = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    button.hover:SetAllPoints()
    button.hover:SetColorTexture(1, 1, 1, 0.12)
    button.hover:Hide()

    button.status = E:CreateFontString(bar, nil, "OVERLAY", 12)
    button.status:SetPoint("RIGHT", -5, 0)
    button.status:SetJustifyH("RIGHT")
    button.status:SetShadowOffset(1, -1)

    button.title = E:CreateFontString(bar, nil, "OVERLAY", 12)
    button.title:SetPoint("LEFT", 5, 0)
    button.title:SetPoint("RIGHT", button.status, "LEFT", -6, 0)
    button.title:SetJustifyH("LEFT")
    button.title:SetWordWrap(false)
    button.title:SetShadowOffset(1, -1)

    button:HookScript("OnEnter", function(self)
        self.hover:Show()
        showTooltip(self)
    end)
    button:HookScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    button:HookScript("PostClick", paintRow)
    SecureHandlerWrapScript(button, "OnClick", root, STEP_BEFORE, STEP_AFTER)
    button:Hide()
    return button
end

local function listHeight(count)
    return count * ROW + math.max(0, count - 1) * GAP
end

local function createHandle(root)
    local handle = CreateFrame("Frame", nil, root, "BackdropTemplate")
    handle:SetPoint("BOTTOMLEFT", root, "TOPLEFT", 0, GAP)
    handle:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", -(HANDLE + GAP), GAP)
    handle:SetHeight(HANDLE)
    E:SetTemplate(handle, "Default")
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() Mod:StartBarDrag() end)
    handle:SetScript("OnDragStop", function() Mod:StopBarDrag() end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L["DragToMove"], 1, 1, 1)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local label = E:CreateFontString(handle, nil, "OVERLAY", 11)
    label:SetPoint("LEFT", 5, 0)
    label:SetText(L["Blessings"])
    label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    handle:Hide()
    return handle
end

local function paintLock(lock)
    local locked = Mod:BarSettings().locked
    lock.glyph:SetText(locked and "U" or "L")
    lock:SetAlpha((locked and not lock.hovered) and LOCK_FADE or 1)
end

local function createLock(root, handle)
    local lock = CreateFrame("Button", nil, root, "BackdropTemplate")
    E:SetTemplate(lock, "Default")
    lock:SetSize(HANDLE, HANDLE)
    lock:SetPoint("BOTTOMRIGHT", root, "TOPRIGHT", 0, GAP)
    lock:SetFrameLevel(handle:GetFrameLevel() + 2)
    lock.glyph = E:CreateFontString(lock, nil, "OVERLAY", 11)
    lock.glyph:SetPoint("CENTER")
    lock:SetScript("OnClick", function() Mod:SetBarLocked(not Mod:BarSettings().locked) end)
    lock:SetScript("OnEnter", function(self)
        self.hovered = true
        paintLock(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(Mod:BarSettings().locked and L["BossMods_UnlockFrame"] or L["Notes_LockFrame"], 1, 1, 1)
        GameTooltip:Show()
    end)
    lock:SetScript("OnLeave", function(self)
        self.hovered = false
        paintLock(self)
        GameTooltip:Hide()
    end)
    lock:Hide()
    return lock
end

function Mod:EnsureBar()
    if self.bar then return self.bar end
    if InCombatLockdown() then return end
    local root = CreateFrame("Frame", FRAME_NAME, UIParent, "SecureHandlerBaseTemplate")
    root:SetFrameStrata("MEDIUM")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:SetSize(WIDTH, listHeight(SLOTS))
    root:EnableMouse(false)
    root:Hide()

    local bar = {frame = root, buttons = {}}
    for index = 1, SLOTS do
        bar.buttons[index] = createButton(root, index)
    end

    bar.handle = createHandle(root)
    bar.lock = createLock(root, bar.handle)

    self.bar = bar
    self:ApplyBarPosition()
    return bar
end

function Mod:GetBarPosition()
    return self:BarSettings().position
end

function Mod:ApplyBarPosition()
    if not self.bar then return end
    E:RunWhenOutOfCombat(OOC_KEY .. ":Position", function()
        self.bar.frame:SetScale(self:BarSettings().scale)
        E:ApplyFramePosition(self.bar.frame, self:GetBarPosition())
    end)
end

function Mod:SaveBarPosition(position)
    local saved = self:GetBarPosition()
    saved.point, saved.x, saved.y = position.point or "CENTER", tonumber(position.x) or 0, tonumber(position.y) or 0
    self:ApplyBarPosition()
end

function Mod:ResetBarPosition()
    self:SaveBarPosition({point = "CENTER", x = 0, y = -200})
end

function Mod:StartBarDrag()
    local bar = self.bar
    if not bar or InCombatLockdown() or self:BarSettings().locked then return end
    bar.dragging = true
    bar.frame:StartMoving()
end

function Mod:StopBarDrag()
    local bar = self.bar
    if not bar or not bar.dragging then return end
    bar.dragging = false
    bar.frame:StopMovingOrSizing()
    self:SaveBarPosition(E:GetFramePosition(bar.frame))
    E:SendMessage("ART_BLESSINGS_UPDATED")
end

function Mod:SetBarLocked(locked)
    local settings = self:BarSettings()
    locked = locked == true
    if settings.locked == locked then return end
    self:StopBarDrag()
    settings.locked = locked
    if self.bar then
        self.bar.handle:SetShown(not locked)
        paintLock(self.bar.lock)
        if GameTooltip:IsOwned(self.bar.lock) then self.bar.lock:GetScript("OnEnter")(self.bar.lock) end
    end
    self:RefreshBar()
    E:SendMessage("ART_BLESSINGS_UPDATED")
end

function Mod:SetBarPlacing(placing)
    placing = placing == true
    if placing == (self.barPlacing == true) then return end
    self.barPlacing = placing
    self:RefreshBar()
end

local function applySteps(button, steps)
    local parts = {}
    for i, step in ipairs(steps) do
        parts[i] = step.unit .. ":" .. step.left .. ":" .. step.right
    end
    local signature = table.concat(parts, "|")
    if button.signature == signature then return end
    button.signature = signature
    for i, step in ipairs(steps) do
        button:SetAttribute("art-unit" .. i, step.unit)
        button:SetAttribute("art-left" .. i, step.left)
        button:SetAttribute("art-right" .. i, step.right)
    end
    local first = steps[1]
    button:SetAttribute("art-count", #steps)
    button:SetAttribute("art-index", 1)
    button:SetAttribute("unit", first and first.unit or nil)
    button:SetAttribute("spell1", first and first.left or nil)
    button:SetAttribute("spell2", first and first.right or nil)
end

function Mod:RefreshBar()
    if not self:IsActive() then return end
    local settings = self:BarSettings()
    local wanted = settings.enabled and self:IsPaladin()
    if not self.bar and not wanted then return end
    local bar = self:EnsureBar()
    if not bar or InCombatLockdown() then
        if bar then
            for _, button in ipairs(bar.buttons) do paintRow(button) end
        end
        E:RunWhenOutOfCombat(OOC_KEY, function() self:RefreshBar() end)
        return
    end

    local rows = wanted and self:BarRows() or {}
    for index, button in ipairs(bar.buttons) do
        local row = rows[index]
        button.row = row
        applySteps(button, row and row.steps or {})
        button:SetShown(row ~= nil)
        if not row then setGlow(button, false) end
        paintRow(button)
    end
    local visible = wanted and (#rows > 0 or self.barPlacing == true)
    bar.handle:SetShown(visible and not settings.locked)
    bar.lock:SetShown(visible)
    paintLock(bar.lock)
    bar.frame:SetClampRectInsets(0, 0, HANDLE + GAP, listHeight(SLOTS) - listHeight(math.max(1, #rows)))
    bar.frame:SetScale(settings.scale)
    bar.frame:SetShown(visible)
end

function Mod:QueueBarRefresh()
    if self.barTimer or not self.barActive then return end
    self.barTimer = C_Timer.NewTimer(REFRESH_DELAY, function()
        self.barTimer = nil
        self:RefreshBar()
    end)
end

function Mod:OnBarAura(_, unit)
    unit = safe(unit)
    if type(unit) ~= "string" then return end
    if unit == "player" or unit:find("^party%d") or unit:find("^raid%d") then
        if self.barAuras then self.barAuras[unit] = nil end
        if not InCombatLockdown() then self:QueueBarRefresh() end
    end
end

function Mod:RescanBar()
    self.barAuras = nil
    self:QueueBarRefresh()
end

function Mod:OnBarCombatStart()
    self:StopBarDrag()
end

function Mod:EnableBar()
    self.barActive = true
    self:RegisterEvent("UNIT_AURA", "OnBarAura")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RescanBar")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnBarCombatStart")
    local ticks = 0
    self.barTicker = C_Timer.NewTicker(TICK, function()
        ticks = ticks + 1
        if ticks % RESCAN_TICKS == 0 then self.barAuras = nil end
        self:QueueBarRefresh()
    end)
    self:RefreshBar()
end

function Mod:DisableBar()
    self.barActive = false
    self:StopBarDrag()
    if self.barTicker then
        self.barTicker:Cancel()
        self.barTicker = nil
    end
    if self.barTimer then
        self.barTimer:Cancel()
        self.barTimer = nil
    end
    if self.bar then
        E:RunWhenOutOfCombat(OOC_KEY, function() self.bar.frame:Hide() end)
    end
end
