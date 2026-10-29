local E, L = unpack(ART)
local callbacks = E:NewCallbackHandle()
local button, layoutTimer

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
    local host = CreateFrame("Frame", nil, menu)
    host.ignoreInLayout = true
    host:SetAllPoints(menu)
    button = CreateFrame("Button", "AdvanceRaidTools_GameMenuButton", host, "MainMenuFrameButtonTemplate")
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
        if not menu:IsShown() or InCombatLockdown() then return end
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
