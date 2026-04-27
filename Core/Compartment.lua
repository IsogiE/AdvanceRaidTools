local E, L = unpack(ART)

local LDB = E.Libs.LDB
local LDBIcon = E.Libs.LDBIcon

local function showMinimapMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        E:OpenOptions()
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L["AdvanceRaidTools"])
        root:CreateButton(L["MenuOpenOptions"], function()
            E:OpenOptions()
        end)
        root:CreateButton(L["MenuOpenRaidGroups"], function()
            E:OpenRaidGroups()
        end)
        root:CreateDivider()
        root:CreateButton(L["MenuHideMinimap"], function()
            E.db.profile.general.minimapIcon.hide = true
            E:CallModule("HomeSettings", "UpdateMinimap")
        end)
    end)
end

function E:InitializeMinimapIcon()
    if not (LDB and LDBIcon) then
        return
    end

    local dataObject = LDB:NewDataObject("AdvanceRaidTools", {
        type = "launcher",
        label = L["AdvanceRaidTools"],
        icon = [[Interface\AddOns\AdvanceRaidTools\Media\Textures\Logo]],
        OnClick = function(frame, button)
            if button == "LeftButton" then
                E:OpenOptions()
            elseif button == "RightButton" then
                showMinimapMenu(frame)
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine(L["AdvanceRaidTools"], 23 / 255, 132 / 255, 209 / 255)
            tt:AddLine(" ")
            tt:AddLine(L["MenuOpenOpt"])
            tt:AddLine(L["MenuRightClickOpt"])
            tt:AddLine(L["SlashCommandOpt"])
        end
    })

    if not LDBIcon:IsRegistered("AdvanceRaidTools") then
        LDBIcon:Register("AdvanceRaidTools", dataObject, self.db.profile.general.minimapIcon)
    end
end

function ART_OnAddonCompartmentClick(addonName, buttonName)
    if _G.ART and _G.ART[1] and _G.ART[1].OpenOptions then
        _G.ART[1]:OpenOptions()
    end
end
