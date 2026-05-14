local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local WHITE = Shared.WHITE
local fetchFont = Shared.FetchFont
local fetchBorder = Shared.FetchBorder
local colorTuple = Shared.ColorTuple
local applyFontIfChanged = Shared.ApplyFontIfChanged
local defaultGroupUnits = Shared.DefaultGroupUnits

local DEFAULT_CLASS_ALPHA = 0.62
local DEFAULT_ROW_COLOR = {0.18, 0.18, 0.18}
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local API_WARN_INTERVAL = 10
local ROSTER_REBUILD_DELAY = 0.2
local DEFAULT_AURA_SLOTS = 3
local DEFAULT_COOLDOWN_TEXT_SCALE = 1
local HIDDEN_PRIVATE_AURA_BORDER_SCALE = -10000
local ROLE_ORDER = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3
}
local PREVIEW_CLASSES = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
                         "MONK", "DRUID", "DEMONHUNTER", "EVOKER"}
local PREVIEW_ROLES = {"TANK", "HEALER", "DAMAGER", "DAMAGER", "HEALER", "TANK", "HEALER", "DAMAGER"}

local function clampInt(v, minV, maxV, fallback)
    v = tonumber(v) or fallback or minV
    v = math.floor(v + 0.5)
    if v < minV then
        return minV
    end
    if v > maxV then
        return maxV
    end
    return v
end

local function clampNumber(v, minV, maxV, fallback)
    v = tonumber(v) or fallback or minV
    if v < minV then
        return minV
    end
    if v > maxV then
        return maxV
    end
    return v
end

local function scaledAuraSize(rowHeight)
    return math.max(8, rowHeight - 2)
end

local function scaledRoleSize(rowHeight)
    return math.max(0, math.min(18, rowHeight - 6))
end

local function scaledPrivateAuraBorder(iconSize)
    return iconSize / 32 * 2
end

local function scaledInset(rowHeight)
    return math.max(2, math.min(8, math.floor(rowHeight * 0.18 + 0.5)))
end

local function validUnitName(name)
    name = E:SafeString(name)
    if not name or name == "" or name == UNKNOWN or name == UNKNOWNOBJECT then
        return nil
    end
    return name
end

local function unitNameRealm(unit)
    local name, realm
    if UnitNameUnmodified then
        name, realm = UnitNameUnmodified(unit)
        name = validUnitName(name)
        realm = E:SafeString(realm)
    end
    if not name and UnitFullName then
        name, realm = UnitFullName(unit)
        name = validUnitName(name)
        realm = E:SafeString(realm)
    end
    if not name then
        name, realm = UnitName(unit)
        name = validUnitName(name)
        realm = E:SafeString(realm)
    end
    return name, realm
end

local function unitFullName(unit)
    local name, realm = unitNameRealm(unit)
    if not name then
        return nil
    end
    if not realm or realm == "" then
        realm = GetRealmName()
    end
    realm = E:SafeString(realm)
    if not realm or realm == "" then
        return name
    end
    return name .. "-" .. realm:gsub("%s+", "")
end

local function unitDisplayName(unit)
    if E.GetNickname then
        local nick = E:GetNickname(unit)
        if nick and nick ~= "" then
            return nick
        end
    end
    return unitNameRealm(unit)
end

local function unitClass(unit, key, displayName)
    local classFile = UnitClassBase and UnitClassBase(unit)
    if not classFile then
        local _, fallback = UnitClass(unit)
        classFile = fallback
    end
    classFile = E:SafeString(classFile)
    if classFile then
        return classFile
    end
    if E.GetClassByName then
        return E:GetClassByName(key) or E:GetClassByName(displayName)
    end
    return nil
end

local function getUnits(config)
    if type(config.getUnits) == "function" then
        local ok, result = pcall(config.getUnits)
        if ok and type(result) == "table" then
            return result
        end
    end
    return defaultGroupUnits()
end

local function isUnitExcluded(config, unit)
    if type(config.isExcluded) == "function" then
        local ok, result = pcall(config.isExcluded, unit)
        return ok and result and true or false
    end

    local excluded = config.excluded
    if type(excluded) ~= "table" then
        return false
    end
    local key = unitFullName(unit)
    return key and excluded[key] and true or false
end

function Engines.PrivateAuraList(config)
    assert(type(config) == "table", "Engines.PrivateAuraList: config required")
    assert(config.parent, "Engines.PrivateAuraList: config.parent required")

    local state = {
        active = false,
        editMode = false,
        config = config,
        rows = {},
        rowData = {},
        privateAnchorIDs = {},
        rowSignature = nil,
        rebuildTimer = nil,
        rebuildToken = 0,
        pendingForce = false,
        lastWarn = 0
    }

    local callbacks = E:NewCallbackHandle()

    local anchor = CreateFrame("Frame", nil, config.parent)
    anchor:SetFrameStrata("MEDIUM")
    anchor:Hide()

    local display = CreateFrame("Frame", nil, anchor, "BackdropTemplate")
    display:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    display:SetFrameLevel(anchor:GetFrameLevel())
    display:Hide()

    local function setVisible(v)
        if v then
            anchor:Show()
            display:Show()
        else
            display:Hide()
            anchor:Hide()
        end
    end

    local function privateAuraConfig()
        return state.config.privateAuras or {}
    end

    local function cooldownTextScale()
        return clampNumber(privateAuraConfig().cooldownTextScale, 0.1, 4, DEFAULT_COOLDOWN_TEXT_SCALE)
    end

    local function showDurationText()
        return privateAuraConfig().showDurationText ~= false
    end

    local function showPrivateAuraBorder()
        return privateAuraConfig().showBorder ~= false
    end

    local function clearPrivateAuraAnchors()
        if C_UnitAuras and C_UnitAuras.RemovePrivateAuraAnchor then
            for _, anchorID in ipairs(state.privateAnchorIDs) do
                pcall(C_UnitAuras.RemovePrivateAuraAnchor, anchorID)
            end
        end
        wipe(state.privateAnchorIDs)
    end

    local function roleOrder(role)
        return ROLE_ORDER[role] or 4
    end

    local function sortRows(rows)
        table.sort(rows, function(a, b)
            local ar = roleOrder(a.role)
            local br = roleOrder(b.role)
            if ar ~= br then
                return ar < br
            end

            local an = strlower(a.displayName or "")
            local bn = strlower(b.displayName or "")
            if an ~= bn then
                return an < bn
            end

            return (a.key or a.unit or "") < (b.key or b.unit or "")
        end)
    end

    local function buildRowSignature(rows)
        local parts = {}
        for i, data in ipairs(rows) do
            parts[i] = table.concat({
                data.unit or "",
                data.key or "",
                data.displayName or "",
                data.classFile or "",
                data.role or "",
                data.roleAtlas or ""
            }, "\002")
        end
        return table.concat(parts, "\001")
    end

    local function getOrCreateRow(index)
        if state.rows[index] then
            return state.rows[index]
        end

        local row = CreateFrame("Frame", nil, display)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.role = row:CreateTexture(nil, "OVERLAY")

        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("MIDDLE")
        row.name:SetWordWrap(false)

        row.auraHosts = {}

        state.rows[index] = row
        return row
    end

    local function getOrCreateAuraHost(row, index)
        if row.auraHosts[index] then
            return row.auraHosts[index]
        end

        local host = CreateFrame("Frame", nil, row)
        host:SetFrameLevel(row:GetFrameLevel() + 2)

        host.privateAuraAnchor = CreateFrame("Frame", nil, host)
        host.privateAuraAnchor:SetFrameLevel(host:GetFrameLevel() + 1)

        host.preview = host:CreateTexture(nil, "ARTWORK")
        host.preview:SetAllPoints()
        host.preview:SetTexture(QUESTION_MARK_ICON)
        host.preview:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.auraHosts[index] = host
        return host
    end

    local function setHostPreview(host, shown)
        host.preview:SetAlpha(shown and 1 or 0)
    end

    local function applyBackdrop(width, height)
        local style = state.config.style or {}
        local bg = style.background or {}
        local border = style.border or {}

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
            E:DisablePixelSnap(display)
            display._artBdMode = "bg"
        end

        local br, bgc, bb = colorTuple(bg.color, 0, 0, 0, 1)
        display:SetBackdropColor(br, bgc, bb, bg.enabled and (bg.opacity or 0.45) or 0)

        local er, eg, eb, ea = colorTuple(border.color, 0, 0, 0, 1)
        E:ApplyOuterBorder(display, {
            enabled = border.enabled and true or false,
            edgeFile = fetchBorder(border.texture),
            edgeSize = math.min(border.size or 1, 16),
            r = er,
            g = eg,
            b = eb,
            a = ea * (border.opacity or 1)
        })

        display:SetSize(width, height)
    end

    local function applyIconBorder(host)
        local auraConfig = privateAuraConfig()
        local border = auraConfig.customBorder or {}
        local enabled = not showPrivateAuraBorder() and border.enabled ~= false
        local er, eg, eb, ea = colorTuple(border.color, 0, 0, 0, 1)
        local container = E:ApplyOuterBorder(host, {
            enabled = enabled,
            edgeFile = fetchBorder(border.texture or "Pixel"),
            edgeSize = math.min(border.size or 1, 16),
            r = er,
            g = eg,
            b = eb,
            a = ea * (border.opacity or 1)
        })

        if container then
            container:SetFrameLevel((host:GetFrameLevel() or 0) + 20)
        end
    end

    local function applyRow(row, data, index, rowCount)
        local layout = state.config.layout or {}
        local style = state.config.style or {}
        local font = style.font or {}

        local width = clampInt(layout.width, 80, 500, 150)
        local rowHeight = clampInt(layout.rowHeight, 12, 60, 22)
        local rowGap = clampInt(layout.rowGap, 0, 20, 2)
        local inset = scaledInset(rowHeight)
        local iconSize = scaledAuraSize(rowHeight)
        local iconGap = math.max(1, math.min(6, math.floor(rowHeight * 0.12 + 0.5)))
        local roleSize = scaledRoleSize(rowHeight)
        local auraSlots = clampInt(layout.auraSlots, 1, 10, DEFAULT_AURA_SLOTS)

        row:SetSize(width, rowHeight)
        row:ClearAllPoints()
        local yOffset = -((index - 1) * (rowHeight + rowGap))
        row:SetPoint("TOPLEFT", display, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", display, "TOPRIGHT", 0, yOffset)

        local r, g, b = DEFAULT_ROW_COLOR[1], DEFAULT_ROW_COLOR[2], DEFAULT_ROW_COLOR[3]
        if data.classFile then
            r, g, b = E:ClassColorRGB(data.classFile)
        end
        row.bg:SetColorTexture(r, g, b, style.classColorAlpha or DEFAULT_CLASS_ALPHA)

        applyFontIfChanged(row.name, fetchFont(), font.size or 12, font.outline or "OUTLINE")
        local tr, tg, tb, ta = colorTuple(font.color, 1, 1, 1, 1)
        row.name:SetTextColor(tr, tg, tb, ta)
        row.name:SetText(data.displayName or "")

        row.role:ClearAllPoints()
        if roleSize > 0 and data.roleAtlas then
            row.role:SetTexCoord(0, 1, 0, 1)
            row.role:SetVertexColor(1, 1, 1, 1)
            row.role:SetAlpha(1)
            row.role:SetAtlas(data.roleAtlas, false)
            row.role:SetSize(roleSize, roleSize)
            row.role:SetPoint("LEFT", row, "LEFT", inset, 0)
            row.role:Show()
        else
            row.role:Hide()
        end

        for slot = 1, auraSlots do
            local host = getOrCreateAuraHost(row, slot)
            local scale = cooldownTextScale()
            local anchorSize = iconSize / scale
            host:SetSize(iconSize, iconSize)
            host:ClearAllPoints()
            host:SetPoint("LEFT", row, "RIGHT", iconGap + (slot - 1) * (iconSize + iconGap), 0)
            host.privateAuraAnchor:SetSize(anchorSize, anchorSize)
            host.privateAuraAnchor:SetScale(scale)
            host.privateAuraAnchor:ClearAllPoints()
            host.privateAuraAnchor:SetPoint("CENTER", host, "CENTER", 0, 0)
            host.privateAuraAnchor:Show()
            applyIconBorder(host)
            setHostPreview(host, state.editMode)
            host:Show()
        end

        for slot = auraSlots + 1, #row.auraHosts do
            row.auraHosts[slot]:Hide()
        end

        row.name:ClearAllPoints()
        if roleSize > 0 and row.role:IsShown() then
            row.name:SetPoint("LEFT", row.role, "RIGHT", 4, 0)
        else
            row.name:SetPoint("LEFT", row, "LEFT", inset, 0)
        end
        row.name:SetPoint("RIGHT", row, "RIGHT", -inset, 0)

        row:SetShown(index <= rowCount)
    end

    local function registerPrivateAuraAnchor(unit, host, auraIndex)
        if not (C_UnitAuras and C_UnitAuras.AddPrivateAuraAnchor) then
            return
        end

        local layout = state.config.layout or {}
        local rowHeight = clampInt(layout.rowHeight, 12, 60, 22)
        local iconSize = scaledAuraSize(rowHeight)
        local scale = cooldownTextScale()
        local anchorSize = iconSize / scale
        local anchorFrame = host.privateAuraAnchor or host
        local borderScale = showPrivateAuraBorder() and scaledPrivateAuraBorder(anchorSize) or
                                HIDDEN_PRIVATE_AURA_BORDER_SCALE

        local ok, anchorID = pcall(C_UnitAuras.AddPrivateAuraAnchor, {
            unitToken = unit,
            auraIndex = auraIndex,
            parent = anchorFrame,
            isContainer = false,
            showCountdownFrame = true,
            showCountdownNumbers = showDurationText(),
            iconInfo = {
                iconWidth = anchorSize,
                iconHeight = anchorSize,
                borderScale = borderScale,
                iconAnchor = {
                    point = "CENTER",
                    relativeTo = anchorFrame,
                    relativePoint = "CENTER",
                    offsetX = 0,
                    offsetY = 0
                }
            }
        })

        if ok and anchorID then
            state.privateAnchorIDs[#state.privateAnchorIDs + 1] = anchorID
            return
        end

        local now = GetTime()
        if now - (state.lastWarn or 0) > API_WARN_INTERVAL then
            state.lastWarn = now
            E:ChannelWarn("BossMods", "Private aura anchor failed: %s", tostring(anchorID))
        end
    end

    local function addPreviewRows()
        local layout = state.config.layout or {}
        local count = clampInt(layout.previewRows, 1, 40, 5)

        for i = 1, count do
            local role = PREVIEW_ROLES[((i - 1) % #PREVIEW_ROLES) + 1]
            state.rowData[#state.rowData + 1] = {
                unit = "player",
                displayName = ("Player %d"):format(i),
                classFile = PREVIEW_CLASSES[((i - 1) % #PREVIEW_CLASSES) + 1],
                role = role,
                roleAtlas = E.GetRoleIconAtlas and E:GetRoleIconAtlas(role) or nil,
                preview = true
            }
        end
        sortRows(state.rowData)
    end

    local function rebuildRows(force)
        wipe(state.rowData)

        if state.editMode then
            addPreviewRows()
        else
            local units = getUnits(state.config)
            for _, unit in ipairs(units) do
                if UnitExists(unit) and not isUnitExcluded(state.config, unit) then
                    local key = unitFullName(unit)
                    local displayName = unitDisplayName(unit)
                    local classFile = unitClass(unit, key, displayName)
                    local role = E.GetUnitRole and E:GetUnitRole(unit) or nil
                    if key and displayName and classFile then
                        state.rowData[#state.rowData + 1] = {
                            unit = unit,
                            key = key,
                            displayName = displayName,
                            classFile = classFile,
                            role = role,
                            roleAtlas = E.GetRoleIconAtlas and E:GetRoleIconAtlas(role) or nil
                        }
                    end
                end
            end
            sortRows(state.rowData)
        end

        local rowSignature = buildRowSignature(state.rowData)
        if not force and rowSignature == state.rowSignature then
            setVisible(state.active and (#state.rowData > 0 or state.editMode))
            return
        end
        state.rowSignature = rowSignature

        clearPrivateAuraAnchors()

        local layout = state.config.layout or {}
        local width = clampInt(layout.width, 80, 500, 150)
        local rowHeight = clampInt(layout.rowHeight, 12, 60, 22)
        local rowGap = clampInt(layout.rowGap, 0, 20, 2)
        local auraSlots = clampInt(layout.auraSlots, 1, 10, DEFAULT_AURA_SLOTS)
        local count = #state.rowData
        local height = count > 0 and (count * rowHeight + math.max(0, count - 1) * rowGap) or rowHeight

        anchor:SetSize(width, rowHeight)
        applyBackdrop(width, height)

        for i, data in ipairs(state.rowData) do
            local row = getOrCreateRow(i)
            applyRow(row, data, i, count)

            if not state.editMode and not data.preview then
                for slot = 1, auraSlots do
                    registerPrivateAuraAnchor(data.unit, row.auraHosts[slot], slot)
                end
            end
        end

        for i = count + 1, #state.rows do
            state.rows[i]:Hide()
        end

        if state.active and (count > 0 or state.editMode) then
            setVisible(true)
        else
            setVisible(false)
        end
    end

    local function clearRows()
        if state.rebuildTimer and state.rebuildTimer.Cancel then
            state.rebuildTimer:Cancel()
            state.rebuildTimer = nil
        end
        state.pendingForce = false
        state.rowSignature = ""
        clearPrivateAuraAnchors()
        wipe(state.rowData)
        for _, row in ipairs(state.rows) do
            row:Hide()
        end
        setVisible(false)
    end

    local function queueRebuild(force)
        if not state.active then
            return
        end

        state.pendingForce = state.pendingForce or force
        state.rebuildToken = state.rebuildToken + 1
        local token = state.rebuildToken

        if state.rebuildTimer and state.rebuildTimer.Cancel then
            state.rebuildTimer:Cancel()
            state.rebuildTimer = nil
        end

        if not (C_Timer and (C_Timer.NewTimer or C_Timer.After)) then
            local pendingForce = state.pendingForce
            state.pendingForce = false
            rebuildRows(pendingForce)
            return
        end

        local function run()
            if token ~= state.rebuildToken or not state.active then
                return
            end
            state.rebuildTimer = nil
            local pendingForce = state.pendingForce
            state.pendingForce = false
            rebuildRows(pendingForce)
        end

        if C_Timer.NewTimer then
            state.rebuildTimer = C_Timer.NewTimer(ROSTER_REBUILD_DELAY, run)
        else
            C_Timer.After(ROSTER_REBUILD_DELAY, run)
        end
    end

    callbacks:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        queueRebuild(false)
    end)
    callbacks:RegisterEvent("UNIT_NAME_UPDATE", function()
        queueRebuild(false)
    end)
    callbacks:RegisterEvent("PLAYER_ROLES_ASSIGNED", function()
        queueRebuild(false)
    end)
    callbacks:RegisterEvent("ROLE_CHANGED_INFORM", function()
        queueRebuild(false)
    end)
    callbacks:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if state.active then
            queueRebuild(true)
        end
    end)
    callbacks:RegisterMessage("ART_NICKNAME_CHANGED", function()
        queueRebuild(false)
    end)
    callbacks:RegisterMessage("ART_ROSTER_INVALIDATED", function()
        queueRebuild(false)
    end)

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
            rebuildRows(true)
        else
            clearRows()
        end
    end

    function handle:SetEditMode(v)
        state.editMode = v and true or false
        rebuildRows(true)
    end

    function handle:Apply(newConfig)
        if type(newConfig) == "table" then
            state.config = newConfig
        end
        if state.active then
            rebuildRows(true)
        end
    end

    function handle:Clear()
        if state.editMode then
            rebuildRows(true)
        else
            clearRows()
        end
    end

    function handle:Release()
        clearRows()
        callbacks:UnregisterAllEvents()
        callbacks:UnregisterAllMessages()
        for _, row in ipairs(state.rows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(state.rows)
        wipe(state.rowData)
        setVisible(false)
        display:ClearAllPoints()
        display:SetParent(nil)
        anchor:ClearAllPoints()
        anchor:SetParent(nil)
        state.active = false
    end

    handle:Apply()
    return handle
end
