local E, L = unpack(ART)
local CreateFrame, C_Timer, hooksecurefunc = E:DiagnosticBindings("Core/GameMenu")
local callbacks = E:NewCallbackHandle()
local button, layoutTimer, skinned

local function wanted()
    return E.db.profile.general.showGameMenuButton ~= false
end

local function skinElvUI()
    local elv = type(_G.ElvUI) == "table" and _G.ElvUI[1]
    local skins = elv and elv.GetModule and elv:GetModule("Skins", true)
    if not skins or type(skins.HandleButton) ~= "function" then return false end
    local blizzard = elv.private and elv.private.skins and elv.private.skins.blizzard
    if blizzard and (blizzard.enable == false or blizzard.misc == false) then return false end
    skins:HandleButton(button, nil, nil, nil, true)
    if button.backdrop and button.backdrop.SetInside then button.backdrop:SetInside(nil, 1, 1) end
    return true
end

local function skinEllesmere()
    local ellesmere, db = _G.EllesmereUI, _G.EllesmereUIDB
    if not ellesmere or not C_AddOns.IsAddOnLoaded("EllesmereUIBlizzardSkin") or (db and db.reskinGameMenu == false) then return false end
    for index = 1, select("#", button:GetRegions()) do
        local region = select(index, button:GetRegions())
        if region:IsObjectType("Texture") then
            region:SetAlpha(0)
            hooksecurefunc(region, "SetAlpha", function(self, alpha)
                if alpha > 0 then self:SetAlpha(0) end
            end)
        end
    end
    local inset = CreateFrame("Frame", nil, button)
    inset:SetPoint("TOPLEFT", 2, -2)
    inset:SetPoint("BOTTOMRIGHT", -2, 2)
    inset:SetFrameLevel(button:GetFrameLevel())
    local background = inset:CreateTexture(nil, "BACKGROUND", nil, -6)
    background:SetAllPoints()
    local color = db and db.popupMenuButtonBackgroundColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
    background:SetColorTexture(color.r, color.g, color.b, color.a or 0.8)
    if type(ellesmere._applyBlizzardConfiguredBorder) == "function" then
        ellesmere._applyBlizzardConfiguredBorder(inset, "popupMenuButton", 1)
    end
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(inset)
    highlight:SetColorTexture(1, 1, 1, 0.1)
    local fontString = button:GetFontString()
    local fontPath = type(ellesmere.GetFontPath) == "function" and ellesmere.GetFontPath("blizzardSkin")
    if fontString and fontPath then fontString:SetFont(fontPath, 13, "") end
    return true
end

local function applySkin()
    if skinned then return end
    skinned = skinElvUI() or skinEllesmere()
end

function E:InitializeGameMenuButton()
    if button then return end
    if InCombatLockdown() then
        self:RunWhenOutOfCombat("GameMenuButton", function() self:InitializeGameMenuButton() end)
        return
    end
    local menu = _G.GameMenuFrame
    if not menu or not menu.buttonPool or not menu.Layout then
        callbacks:RegisterEvent("ADDON_LOADED", function(_, addonName)
            if addonName == "Blizzard_GameMenu" then self:InitializeGameMenuButton() end
        end)
        return
    end
    callbacks:UnregisterEvent("ADDON_LOADED")
    button = CreateFrame("Button", "AdvanceRaidTools_GameMenuButton", menu, "MainMenuFrameButtonTemplate")
    button.ignoreInLayout = true
    button:SetSize(200, 36)
    button:SetText(C_AddOns.GetAddOnMetadata(self.addonName, "Title") or L["AdvanceRaidTools"])
    button:Hide()
    button:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        HideUIPanel(menu)
        self:OpenOptions()
    end)

    local function placeButton()
        layoutTimer = nil
        if not menu:IsShown() or InCombatLockdown() or not wanted() then return end
        applySkin()
        local logoutText = menu.GetLogoutText and menu:GetLogoutText() or LOG_OUT
        local anchor, exitButton
        for entry in menu.buttonPool:EnumerateActive() do
            if entry:GetText() == logoutText then anchor = entry end
            if entry:GetText() == EXIT_GAME then exitButton = entry end
        end
        anchor = anchor or exitButton
        if not anchor or not anchor.layoutIndex then return end
        local point, relativeTo, relativePoint, x, y = anchor:GetPoint(1)
        if not point then return end
        button:SetSize(anchor:GetSize())
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x, y)
        local addedHeight = button:GetHeight() + 12
        for entry in menu.buttonPool:EnumerateActive() do
            if entry.layoutIndex and entry.layoutIndex >= anchor.layoutIndex then
                local p, relative, rp, offsetX, offsetY = entry:GetPoint(1)
                if p then
                    entry:ClearAllPoints()
                    entry:SetPoint(p, relative, rp, offsetX, offsetY - addedHeight)
                end
            end
        end
        menu:SetHeight(menu:GetHeight() + addedHeight)
        button:SetEnabled(true)
        button:Show()
    end

    hooksecurefunc(menu, "Layout", function()
        button:Hide()
        if not layoutTimer then layoutTimer = C_Timer.NewTimer(0, placeButton) end
    end)
    menu:HookScript("OnHide", function()
        if layoutTimer then layoutTimer:Cancel(); layoutTimer = nil end
        button:Hide()
    end)
    callbacks:RegisterEvent("PLAYER_REGEN_DISABLED", function() button:SetEnabled(false) end)
    callbacks:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if menu:IsShown() then menu:MarkDirty() end
    end)
    if menu:IsShown() then menu:MarkDirty() end
end

function E:UpdateGameMenuButton()
    local menu = _G.GameMenuFrame
    if button and menu and menu:IsShown() then menu:MarkDirty() end
end
