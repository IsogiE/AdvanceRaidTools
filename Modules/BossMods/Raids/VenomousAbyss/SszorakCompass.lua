local E, L = unpack(ART)

E:RegisterModuleDefaults("BossMods_SszorakCompass", {
    enabled = true,
    position = {
        point = "CENTER",
        x = 0,
        y = 0
    },
    iconSize = 22,
    ringRadius = 46,
    opacity = 1
})

local TWO_PI = math.pi * 2
local UPDATE_INTERVAL = 0.05
local RAID_MARKER_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcon_%d]]
local COMPASS_RING_TEXTURE = [[Interface\AddOns\AdvanceRaidTools\Media\SszorakCompassRing.tga]]
local NOTE_TAG = "#sszcompass"
local VENOMOUS_ABYSS_INSTANCE_ID = 3004

-- Fixed room orientation: north, north-east, east, south-east, south,
-- south-west, west and north-west.
local MARKERS = {
    {id = 8, angle = 0},
    {id = 5, angle = math.pi * 0.25},
    {id = 6, angle = math.pi * 0.50},
    {id = 7, angle = math.pi * 0.75},
    {id = 4, angle = math.pi},
    {id = 1, angle = math.pi * 1.25},
    {id = 2, angle = math.pi * 1.50},
    {id = 3, angle = math.pi * 1.75}
}

local SszorakCompass = E:NewModule("BossMods_SszorakCompass", "AceEvent-3.0")

local function isSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function normalizeAngle(value)
    if type(value) ~= "number" or isSecret(value) then
        return nil
    end
    local ok, normalized = pcall(function()
        return value % TWO_PI
    end)
    if not ok or type(normalized) ~= "number" or isSecret(normalized) then
        return nil
    end
    return normalized
end

local function getDirectPlayerFacing()
    if type(GetPlayerFacing) ~= "function" then
        return nil
    end
    local ok, facing = pcall(GetPlayerFacing)
    if ok then
        return normalizeAngle(facing)
    end
    return nil
end

local function getCompassFacing()
    if GetCVar("rotateMinimap") ~= "1" then
        return nil
    end
    if MinimapCompassTexture and MinimapCompassTexture.GetRotation then
        local ok, rotation = pcall(
            MinimapCompassTexture.GetRotation,
            MinimapCompassTexture
        )
        if ok then
            local facing = normalizeAngle(rotation)
            if facing then
                return normalizeAngle(-facing)
            end
        end
    end
    return nil
end

local function showRegion(region)
    local metatable = getmetatable(region)
    local methods = metatable and type(metatable.__index) == "table" and metatable.__index
    local show = methods and methods.Show or region.Show
    if show then
        pcall(show, region)
    end
end

local function roundPixel(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function SszorakCompass:EnsureFrame()
    if self.frame then
        return true
    end

    local frame = CreateFrame("Frame", "ART_SszorakCompass", UIParent)
    frame:SetSize(120, 120)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(false)

    local rotatingRing = frame:CreateTexture(nil, "ARTWORK")
    rotatingRing:SetAllPoints(frame)
    rotatingRing:SetTexture(COMPASS_RING_TEXTURE)
    rotatingRing:Hide()

    local icons = {}
    for index, marker in ipairs(MARKERS) do
        local texture = frame:CreateTexture(nil, "ARTWORK")
        texture:SetTexture(RAID_MARKER_TEXTURE:format(marker.id))
        texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        icons[index] = texture
    end

    self.frame = frame
    self.rotatingRing = rotatingRing
    self.icons = icons
    return true
end

function SszorakCompass:EnsureCompassFacingSource()
    if not MinimapCompassTexture then
        return
    end

    if self.originalRotateMinimap == nil then
        self.originalRotateMinimap = GetCVar("rotateMinimap")
    end
    if GetCVar("rotateMinimap") ~= "1" and C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "rotateMinimap", "1")
    end

    self.compassLoans = self.compassLoans or {}
    local region = MinimapCompassTexture
    while region and region ~= UIParent do
        if not region:IsShown() then
            if not self.compassLoans[region] then
                self.compassLoans[region] = {
                    alpha = region:GetAlpha()
                }
                region:SetAlpha(0)
            end
            showRegion(region)
        end
        region = region:GetParent()
    end
end

function SszorakCompass:ReleaseCompassFacingSource()
    for region, state in pairs(self.compassLoans or {}) do
        if region and region.Hide then
            region:Hide()
            region:SetAlpha(state.alpha or 1)
        end
    end
    wipe(self.compassLoans or {})

    if self.originalRotateMinimap ~= nil then
        if GetCVar("rotateMinimap") ~= self.originalRotateMinimap
            and C_CVar
            and C_CVar.SetCVar
        then
            pcall(C_CVar.SetCVar, "rotateMinimap", self.originalRotateMinimap)
        end
        self.originalRotateMinimap = nil
    end
end

function SszorakCompass:ApplySecretCompassRotation()
    if not (
        self.rotatingRing
        and MinimapCompassTexture
        and MinimapCompassTexture.GetRotation
    ) then
        return false
    end

    -- The rotation value is secret on current clients. It cannot be inspected
    -- or used in arithmetic, but WoW permits passing it directly to a texture.
    local ok = pcall(function()
        self.rotatingRing:SetRotation(MinimapCompassTexture:GetRotation())
    end)
    if not ok then
        return false
    end

    self.rotatingRing:Show()
    for _, icon in ipairs(self.icons) do
        icon:Hide()
    end
    return true
end

function SszorakCompass:ShowStaticMarkers()
    if self.rotatingRing then
        self.rotatingRing:Hide()
    end
    for _, icon in ipairs(self.icons or {}) do
        icon:Show()
    end
end

function SszorakCompass:UpdateLayout(force)
    if not self.frame then
        return
    end

    local radius = self.db.ringRadius or 46
    local iconSize = self.db.iconSize or 22
    local extent = (radius + iconSize * 0.5 + 4) * 2
    if force or self.lastExtent ~= extent then
        self.frame:SetSize(extent, extent)
        self.lastExtent = extent
    end

    local facing
    if self.editMode or self.noteActive then
        self:EnsureCompassFacingSource()
        if self:ApplySecretCompassRotation() then
            self.lastFacing = nil
            return
        end
        facing = getCompassFacing()
        if not facing then
            facing = getDirectPlayerFacing()
        end
    end
    self:ShowStaticMarkers()
    facing = facing or 0
    if not force and self.lastFacing and math.abs(facing - self.lastFacing) < 0.0005 then
        return
    end
    self.lastFacing = facing

    for index, marker in ipairs(MARKERS) do
        local relativeAngle = marker.angle - facing
        local x = roundPixel(radius * math.sin(relativeAngle))
        local y = roundPixel(radius * math.cos(relativeAngle))
        local icon = self.icons[index]
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", self.frame, "CENTER", x, y)
        icon:SetSize(iconSize, iconSize)
    end
end

function SszorakCompass:ApplySettings()
    if not self:EnsureFrame() then
        return
    end

    E:ApplyFramePosition(self.frame, self.db.position)
    self.frame:SetAlpha(self.db.opacity or 1)
    self.lastFacing = nil
    self:UpdateLayout(true)
end

function SszorakCompass:NoteContainsCompassTag()
    local noteText = ""
    if _G.ART and ART.GetRawNote then
        noteText = ART:GetRawNote() or ""
    end
    if type(noteText) ~= "string" or noteText == "" then
        return false
    end

    return noteText:lower():find(NOTE_TAG .. "%f[%W]") ~= nil
end

function SszorakCompass:IsInVenomousAbyssRaid()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "raid" then
        return false
    end

    local instanceID = select(8, GetInstanceInfo())
    if isSecret(instanceID) then
        return false
    end

    return tonumber(instanceID) == VENOMOUS_ABYSS_INSTANCE_ID
end

function SszorakCompass:ApplyVisibility()
    if not self.frame or not self:IsEnabled() then
        return
    end

    if self.editMode
        or (self.noteActive and self:IsInVenomousAbyssRaid())
    then
        self.frame:Show()
    else
        self.frame:Hide()
        self:ReleaseCompassFacingSource()
    end
end

function SszorakCompass:UpdateNoteVisibility()
    self.noteActive = self:NoteContainsCompassTag()
    self:ApplyVisibility()
end

function SszorakCompass:OnNoteChanged(_, slot)
    local mainSlot = (_G.ART and ART.GetMainNoteSlot and ART:GetMainNoteSlot()) or 1
    if slot == nil or slot == mainSlot then
        self:UpdateNoteVisibility()
    end
end

function SszorakCompass:OnZoneChanged()
    self:ApplyVisibility()
end

function SszorakCompass:SavePosition(position)
    local saved = self.db.position
    saved.point = position.point
    saved.x = position.x
    saved.y = position.y
    self:ApplySettings()
end

function SszorakCompass:SetEditMode(value)
    self.editMode = value and true or false
    self:ApplyVisibility()
end

function SszorakCompass:StartUpdates()
    if self.updateTicker then
        return
    end
    self.updateTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
        if self:IsEnabled() then
            self:UpdateLayout(false)
        end
    end)
end

function SszorakCompass:StopUpdates()
    if self.updateTicker then
        self.updateTicker:Cancel()
        self.updateTicker = nil
    end
end

function SszorakCompass:Refresh()
    if not self:IsEnabled() then
        return
    end
    self:ApplySettings()
    self:UpdateNoteVisibility()
end

function SszorakCompass:OnInitialize()
    self.editMode = false
    self.noteActive = false
    self:EnsureFrame()
    self:ApplySettings()
    self.frame:Hide()
end

function SszorakCompass:OnEnable()
    self:EnsureFrame()
    self:ApplySettings()
    self:RegisterMessage("ART_NOTE_CHANGED", "OnNoteChanged")
    self:RegisterMessage("ART_PROFILE_CHANGED", "UpdateNoteVisibility")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnZoneChanged")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnZoneChanged")
    self:UpdateNoteVisibility()
    self:StartUpdates()
end

function SszorakCompass:OnDisable()
    self:StopUpdates()
    self:UnregisterAllMessages()
    self:UnregisterAllEvents()
    self:ReleaseCompassFacingSource()
    self.editMode = false
    self.noteActive = false
    if self.frame then
        self.frame:Hide()
    end
end

E:RegisterBossModFeature("SszorakCompass", {
    tab = "AbyssCustom",
    order = 60,
    bossKey = "Sszorak",
    bossLabelKey = "BossMods_Sszorak",
    bossOrder = 50,
    labelKey = "BossMods_SszorakCompass",
    navLabelKey = "BossMods_SszorakCompassNav",
    descKey = "BossMods_SszorakCompassDesc",
    moduleName = "BossMods_SszorakCompass"
})
