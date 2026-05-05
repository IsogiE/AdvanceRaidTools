local E = unpack(ART)

local BossMods = E:GetModule("BossMods")
local Engines = BossMods.Engines
local Shared = Engines.Shared

local WHITE = Shared.WHITE
local fetchFont = Shared.FetchFont
local applyFontIfChanged = Shared.ApplyFontIfChanged

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
