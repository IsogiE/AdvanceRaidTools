local E = unpack(ART)
local Data = E.ReadyCheckData

local MODULE_NAME = "QoL_ReadyCheckConsumables"
local FRAME_NAME = "ART_QoL_ReadyCheckConsumablesFrame"
local VISIBILITY_DRIVER = "[combat] hide; show"

local OOC_CREATE_KEY = MODULE_NAME .. ":CreateDisplay"
local OOC_REFRESH_KEY = MODULE_NAME .. ":Refresh"
local OOC_HIDE_KEY = MODULE_NAME .. ":HideDisplay"
local OOC_POSITION_KEY = MODULE_NAME .. ":ResetPosition"

local DEFAULT_POSITION = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = 160
}

E:RegisterModuleDefaults(MODULE_NAME, {
    enabled = true,
    scale = 1,
    iconSize = 44,
    fontName = "PT Sans Narrow",
    fontSize = 10,
    fontOutline = "OUTLINE",
    textColor = {
        r = 1,
        g = 1,
        b = 1,
        a = 1
    },
    customPosition = false,
    position = {
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 160
    }
})

local ReadyCheckConsumables = E:NewModule(MODULE_NAME, "AceEvent-3.0")

local STATE_READY = "ready"
local STATE_NOT_READY = "notready"

local STATUS_ATLASES = {
    [STATE_READY] = _G.READY_CHECK_READY_TEXTURE_RAID or
        "UI-LFG-ReadyMark-Raid",
    [STATE_NOT_READY] = _G.READY_CHECK_NOT_READY_TEXTURE_RAID or
        "UI-LFG-DeclineMark-Raid"
}

local ICON_ORDER = {
    "food",
    "flask",
    "gearEnchants",
    "mainHand",
    "offHand",
    "rune",
    "healthstone"
}

local ICON_INFO = {
    food = {
        labelKey = "QoL_ReadyCheckFood",
        texture = 136000,
        supportsAction = false
    },
    flask = {
        labelKey = "QoL_ReadyCheckFlask",
        texture = 3566840
    },
    gearEnchants = {
        labelKey = "QoL_ReadyCheckPermanentEnchants",
        texture = 4620672,
        supportsAction = false
    },
    mainHand = {
        labelKey = "QoL_ReadyCheckMainHandTemporaryEnhancement",
        texture = 7548987
    },
    offHand = {
        labelKey = "QoL_ReadyCheckOffHandTemporaryEnhancement",
        texture = 7548987
    },
    rune = {
        labelKey = "QoL_ReadyCheckAugmentRune",
        texture = 4549099
    },
    healthstone = {
        labelKey = "QoL_ReadyCheckHealthstone",
        texture = 538745,
        supportsAction = false
    }
}

local function clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, value))
end

local function safeNumber(value)
    if E:IsSecret(value) or type(value) ~= "number" then
        return nil
    end
    return value
end

local function itemLink(itemID)
    if not itemID then
        return nil
    end

    local link
    if C_Item and type(C_Item.GetItemInfo) == "function" then
        link = select(2, C_Item.GetItemInfo(itemID))
    elseif type(GetItemInfo) == "function" then
        link = select(2, GetItemInfo(itemID))
    end
    return link or ("item:" .. itemID)
end

local function setSecureButtonAction(button, itemID, targetSlot)
    if InCombatLockdown() then
        return false
    end

    if button.itemID == itemID and button.targetSlot == targetSlot then
        return true
    end

    button:SetAttribute("type1", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("target-slot", nil)

    if itemID then
        button:SetAttribute("type1", "item")
        button:SetAttribute("item1", "item:" .. itemID)
        if targetSlot then
            button:SetAttribute("target-slot", tostring(targetSlot))
        end
    end

    button.itemID = itemID
    button.targetSlot = targetSlot
    return true
end

local function setIconState(button, state, timeText, count, texture)
    button.state = state
    button.icon:SetTexture(texture or button.defaultTexture)
    button.icon:SetDesaturated(state == STATE_NOT_READY)
    button.status:SetShown(state ~= nil)
    if state then
        button.status:SetAtlas(STATUS_ATLASES[state], false)
    end
    button.time:SetText(timeText or "")

    count = safeNumber(count)
    button.count:SetText(count and count > 0 and tostring(count) or "")
end

local function auraState(available, present)
    if not available then
        return nil
    elseif present then
        return STATE_READY
    end
    return STATE_NOT_READY
end

local function weaponRemaining(milliseconds)
    milliseconds = safeNumber(milliseconds)
    if not milliseconds or milliseconds <= 0 then
        return ""
    end
    return Data:FormatRemaining(GetTime() + milliseconds / 1000)
end

local function getWeaponEnchantState()
    if type(GetWeaponEnchantInfo) ~= "function" then
        return false, nil, false, nil, false
    end

    local ok, hasMain, mainTime, _, _, hasOff, offTime =
        pcall(GetWeaponEnchantInfo)
    if not ok or E:IsSecret(hasMain) or E:IsSecret(hasOff) then
        return false, nil, false, nil, false
    end

    return hasMain and true or false,
        safeNumber(mainTime),
        hasOff and true or false,
        safeNumber(offTime),
        true
end

local function hasEnchantableOffHand()
    local ok, itemID = pcall(GetInventoryItemID, "player", 17)
    if not ok or not itemID or E:IsSecret(itemID) or not C_Item or
        type(C_Item.GetItemInfoInstant) ~= "function" then
        return false
    end

    local infoOK, _, _, _, _, _, classID =
        pcall(C_Item.GetItemInfoInstant, itemID)
    return infoOK and type(classID) == "number" and Enum and Enum.ItemClass and
        classID == Enum.ItemClass.Weapon
end

local function normalizeReadyCheckName(name)
    name = E:SafeString(name)
    if not name or name == "" then
        return nil
    end
    return name:gsub("%s+", ""):lower()
end

local function getPlayerShortName()
    if type(UnitNameUnmodified) == "function" then
        local ok, name = pcall(UnitNameUnmodified, "player")
        if ok and not E:IsSecret(name) then
            return name
        end
    end
    if type(UnitName) == "function" then
        local ok, name = pcall(UnitName, "player")
        if ok and not E:IsSecret(name) then
            return name
        end
    end
    return nil
end

local function isPlayerReadyCheckStarter(starter)
    if not starter or E:IsSecret(starter) then
        return false
    end

    if type(UnitIsUnit) == "function" then
        local ok, isPlayer = pcall(UnitIsUnit, starter, "player")
        if ok and not E:IsSecret(isPlayer) and isPlayer then
            return true
        end
    end

    local starterName = E:SafeString(starter)
    local normalizedStarter = normalizeReadyCheckName(starterName)
    if not normalizedStarter then
        return false
    end

    if type(E.GetUnitFullName) == "function" then
        local ok, playerFullName = pcall(E.GetUnitFullName, E, "player", true)
        if ok and normalizedStarter == normalizeReadyCheckName(playerFullName) then
            return true
        end
    end

    if starterName:find("-", 1, true) then
        return false
    end

    return normalizedStarter == normalizeReadyCheckName(getPlayerShortName())
end

local function showButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_CURSOR")

    if button.itemID then
        GameTooltip:SetHyperlink(itemLink(button.itemID))
        GameTooltip:AddLine(E:L(button.labelKey))
        GameTooltip:AddLine(E:L("QoL_ReadyCheckClickToUse"))
    else
        GameTooltip:SetText(E:L(button.labelKey))
        if button.state == STATE_NOT_READY and button.supportsAction ~= false then
            GameTooltip:AddLine(
                E:L(
                    button.actionUnavailableKey or
                        "QoL_ReadyCheckNoItemAvailable"
                ),
                nil,
                nil,
                nil,
                true
            )
        end
    end

    for _, line in ipairs(button.tooltipLines or {}) do
        if type(line) == "table" then
            GameTooltip:AddLine(
                line.text,
                line.r,
                line.g,
                line.b,
                line.wrap ~= false
            )
        else
            GameTooltip:AddLine(line, nil, nil, nil, true)
        end
    end
    GameTooltip:Show()
end

function ReadyCheckConsumables:CancelTimers()
    local timerFields = {
        "hideTimer",
        "delayedRefreshTimer",
        "refreshTicker"
    }
    for _, field in ipairs(timerFields) do
        local timer = self[field]
        if timer then
            timer:Cancel()
            self[field] = nil
        end
    end
end

function ReadyCheckConsumables:CancelDeferredWork()
    E:CancelRunWhenOutOfCombat(OOC_CREATE_KEY)
    E:CancelRunWhenOutOfCombat(OOC_REFRESH_KEY)
    E:CancelRunWhenOutOfCombat(OOC_HIDE_KEY)
    E:CancelRunWhenOutOfCombat(OOC_POSITION_KEY)
    self.clearActionsOnHide = nil
end

function ReadyCheckConsumables:QueueRefresh()
    E:RunWhenOutOfCombat(OOC_REFRESH_KEY, function()
        if self:IsEnabled() then
            self:Refresh()
        end
    end)
end

function ReadyCheckConsumables:QueueHide(clearActions)
    self.clearActionsOnHide = self.clearActionsOnHide or clearActions
    E:RunWhenOutOfCombat(OOC_HIDE_KEY, function()
        local shouldClear = self.clearActionsOnHide
        self.clearActionsOnHide = nil
        self:HideDisplayOutOfCombat(shouldClear)
    end)
end

function ReadyCheckConsumables:CreateDisplay()
    if self.frame then
        return self.frame
    end
    if InCombatLockdown() then
        E:RunWhenOutOfCombat(OOC_CREATE_KEY, function()
            if self:IsEnabled() then
                self:CreateDisplay()
                if E.RefreshOptions then
                    E:RefreshOptions()
                end
            end
        end)
        return nil
    end

    local frame =
        CreateFrame("Frame", FRAME_NAME, UIParent, "SecureHandlerStateTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame.buttons = {}
    self.frame = frame
    frame:SetScale(clamp(self.db.scale, 0.75, 1.5, 1))

    for _, key in ipairs(ICON_ORDER) do
        local info = ICON_INFO[key]
        local button =
            CreateFrame(
                "Button",
                FRAME_NAME .. "_" .. key,
                frame,
                "SecureActionButtonTemplate,BackdropTemplate"
            )
        button:RegisterForClicks("AnyUp", "AnyDown")
        button.defaultTexture = info.texture
        button.labelKey = info.labelKey
        button.supportsAction = info.supportsAction
        E:SetTemplate(button, "Transparent")

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.icon:SetTexture(info.texture)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        button.status = button:CreateTexture(nil, "OVERLAY")
        button.status:SetPoint("CENTER")
        button.status:Hide()

        button.time = E:CreateFontString(button, nil, "OVERLAY", 10)
        button.time:SetPoint("BOTTOM", button, "TOP", 0, 2)

        button.count = E:CreateFontString(button, nil, "OVERLAY", 10)
        button.count:SetPoint("BOTTOMRIGHT", -2, 2)

        button:SetScript("OnEnter", showButtonTooltip)
        button:SetScript("OnLeave", GameTooltip_Hide)

        frame.buttons[key] = button
    end

    frame.moveOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.moveOverlay:SetAllPoints()
    frame.moveOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    E:SetTemplate(frame.moveOverlay, "Transparent")

    frame.moveOverlay.text =
        E:CreateFontString(frame.moveOverlay, nil, "OVERLAY", 12)
    frame.moveOverlay.text:SetPoint("CENTER")
    frame.moveOverlay:Hide()

    self:ApplyTextAppearance()
    self:ApplyLayout()
    E:ApplyFramePosition(frame, DEFAULT_POSITION, UIParent)
    return frame
end

function ReadyCheckConsumables:IsUnlocked()
    return self.unlocked and true or false
end

function ReadyCheckConsumables:IsTesting()
    return self.displayMode == "test"
end

function ReadyCheckConsumables:SavePosition(position)
    if not self.frame or InCombatLockdown() then
        return
    end

    position =
        type(position) == "table" and position or
        E:GetFramePosition(self.frame, UIParent)
    local point = position.point or "CENTER"
    self.db.position = {
        point = point,
        relPoint = position.relPoint or point,
        x = tonumber(position.x) or 0,
        y = tonumber(position.y) or 0
    }
    self.db.customPosition = true
    self:ApplySavedPosition()
end

function ReadyCheckConsumables:ApplySavedPosition()
    if self.frame and not InCombatLockdown() then
        E:ApplyFramePosition(self.frame, self.db.position or DEFAULT_POSITION, UIParent)
    end
end

function ReadyCheckConsumables:SetUnlocked(value)
    value = value and true or false
    if InCombatLockdown() then
        self.unlocked = false
        return
    end
    if value and self:IsTesting() then
        return
    end
    self.unlocked = value

    if not self.unlocked then
        if self.frame then
            for _, key in ipairs(ICON_ORDER) do
                self.frame.buttons[key]:EnableMouse(true)
            end
        end
        self:HideDisplay(false)
        return
    end

    local frame = self:CreateDisplay()
    if not frame then
        return
    end

    self:CancelTimers()
    self.displaySerial = (self.displaySerial or 0) + 1
    self.displayMode = "unlock"
    self:ApplySavedPosition()
    self:UpdateDisplay()
    for _, key in ipairs(ICON_ORDER) do
        frame.buttons[key]:EnableMouse(false)
    end
    frame.moveOverlay:Show()
    self:ShowDisplayOutOfCombat()
    self:StartRefreshTimers(self.displaySerial)
end

function ReadyCheckConsumables:ResetPosition()
    self.db.customPosition = false
    self.db.position = {
        point = DEFAULT_POSITION.point,
        relPoint = DEFAULT_POSITION.relPoint,
        x = DEFAULT_POSITION.x,
        y = DEFAULT_POSITION.y
    }

    if not self.frame then
        return
    end
    if InCombatLockdown() then
        E:RunWhenOutOfCombat(OOC_POSITION_KEY, function()
            if self:IsEnabled() and self.frame and not self.db.customPosition then
                E:ApplyFramePosition(self.frame, DEFAULT_POSITION, UIParent)
            end
        end)
        return
    end

    E:CancelRunWhenOutOfCombat(OOC_POSITION_KEY)
    E:ApplyFramePosition(self.frame, DEFAULT_POSITION, UIParent)
end

function ReadyCheckConsumables:ApplyTextAppearance()
    local frame = self.frame
    if not frame then
        return
    end

    local font = E:FetchModuleFont(self.db.fontName)
    local size = clamp(self.db.fontSize, 8, 24, 10)
    local outline = self.db.fontOutline or "OUTLINE"
    if outline == "NONE" then
        outline = ""
    end

    local r, g, b, a = E:ColorTuple(self.db.textColor, 1, 1, 1, 1)
    for _, key in ipairs(ICON_ORDER) do
        local button = frame.buttons[key]
        E:ApplyFontString(button.time, font, size, outline)
        E:ApplyFontString(button.count, font, size, outline)
        button.time:SetTextColor(r, g, b, a)
        button.count:SetTextColor(r, g, b, a)
    end

    E:ApplyFontString(frame.moveOverlay.text, font, math.max(10, size + 2), outline)
    frame.moveOverlay.text:SetTextColor(r, g, b, a)
    frame.moveOverlay.text:SetText(
        E:L("QoL_ReadyCheckConsumables") ..
            "\n" .. E:L("QoL_ReadyCheckDragToMove")
    )
end

function ReadyCheckConsumables:ApplyLayout()
    local frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        self:QueueRefresh()
        return
    end

    local size = clamp(self.db.iconSize, 32, 64, 44)
    local gap = E:Scale(3, frame)
    local visible = {}

    for _, key in ipairs(ICON_ORDER) do
        local button = frame.buttons[key]
        if key ~= "offHand" or button.wantShown then
            visible[#visible + 1] = button
            button:Show()
        else
            button:Hide()
        end
    end

    for index, button in ipairs(visible) do
        button:ClearAllPoints()
        button:SetSize(size, size)
        button.status:SetSize(math.max(16, size * 0.5), math.max(16, size * 0.5))
        if index == 1 then
            button:SetPoint("LEFT", frame, "LEFT")
        else
            button:SetPoint("LEFT", visible[index - 1], "RIGHT", gap, 0)
        end
    end

    frame:SetSize(
        math.max(1, #visible * size + math.max(0, #visible - 1) * gap),
        size
    )
end

function ReadyCheckConsumables:AnchorDisplay(starter, forceCenter)
    local frame = self.frame
    if not frame or InCombatLockdown() then
        return
    end

    if self.db.customPosition or self.unlocked then
        self:ApplySavedPosition()
        return
    end

    if not forceCenter then
        local target = _G.ReadyCheckListenerFrame
        if isPlayerReadyCheckStarter(starter) and _G.ReadyCheckFrame then
            target = _G.ReadyCheckFrame
        end

        if target then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOM", target, "TOP", 0, E:Scale(8, frame))
            return
        end
    end

    E:ApplyFramePosition(frame, DEFAULT_POSITION, UIParent)
end

function ReadyCheckConsumables:UpdateDisplay()
    local frame = self.frame
    if not frame or InCombatLockdown() then
        return
    end

    local scan, available = Data:ScanUnit("player")
    scan = type(scan) == "table" and scan or {
        details = {}
    }
    available = not E:IsSecret(available) and available == true
    local details = type(scan.details) == "table" and scan.details or {}
    local foodDetail = details.food or {}
    local flaskDetail = details.flask or {}
    local runeDetail = details.rune or {}

    local flaskItem, flaskCount, flaskGroupCount =
        Data:FindOwnedItemGroup(Data.FLASK_ITEM_GROUPS)
    local runeItem = Data:FindOwnedItem(Data.RUNE_ITEMS)
    local runeCount = Data:GetTotalItemCount(Data.RUNE_ITEMS)
    local healthstoneItem = Data:FindOwnedItem(Data.HEALTHSTONE_ITEMS)
    local healthstoneCount = Data:GetTotalItemCount(Data.HEALTHSTONE_ITEMS)
    local mainItem, mainCount, mainGroupCount, mainItemDataAvailable =
        Data:FindOwnedWeaponEnhancement(16)
    local offItem, offCount, offGroupCount, offItemDataAvailable =
        Data:FindOwnedWeaponEnhancement(17)

    flaskCount = safeNumber(flaskCount) or 0
    runeCount = safeNumber(runeCount) or 0
    healthstoneCount = safeNumber(healthstoneCount) or 0
    mainCount = safeNumber(mainCount) or 0
    offCount = safeNumber(offCount) or 0

    local hasMain, mainTime, hasOff, offTime, weaponDataAvailable =
        getWeaponEnchantState()
    local showOffHand = hasEnchantableOffHand()
    frame.buttons.offHand.wantShown = showOffHand
    local permanentReady, permanentDataAvailable, missingEnchants =
        Data:GetPermanentEnchantState()

    local flaskAction =
        available and not scan.flask and flaskGroupCount == 1 and
            flaskItem or nil
    local runeAction = available and not scan.rune and runeItem or nil
    local mainAction =
        weaponDataAvailable and mainItemDataAvailable and not hasMain and
            mainGroupCount == 1 and mainItem or nil
    local offAction =
        showOffHand and weaponDataAvailable and offItemDataAvailable and
            not hasOff and offGroupCount == 1 and offItem or nil

    frame.buttons.flask.actionUnavailableKey =
        available and not scan.flask and flaskGroupCount > 1 and
            "QoL_ReadyCheckChooseItem" or nil
    frame.buttons.mainHand.actionUnavailableKey =
        weaponDataAvailable and mainItemDataAvailable and not hasMain and
            mainGroupCount > 1 and "QoL_ReadyCheckChooseItem" or nil
    frame.buttons.offHand.actionUnavailableKey =
        showOffHand and weaponDataAvailable and offItemDataAvailable and
            not hasOff and offGroupCount > 1 and "QoL_ReadyCheckChooseItem" or
            nil

    local enchantTooltipLines = {
        {
            text = E:L(
                permanentDataAvailable and permanentReady and
                    "QoL_ReadyCheckPermanentEnchantsReady" or
                    "QoL_ReadyCheckPermanentEnchantsDesc"
            ),
            r = 0.75,
            g = 0.75,
            b = 0.75
        }
    }
    if not permanentDataAvailable then
        enchantTooltipLines[#enchantTooltipLines + 1] = {
            text = E:L("QoL_ReadyCheckPermanentEnchantsUnavailable"),
            r = 0.6,
            g = 0.6,
            b = 0.6
        }
    elseif not permanentReady then
        enchantTooltipLines[#enchantTooltipLines + 1] = {
            text = E:L("QoL_ReadyCheckMissingPermanentEnchants"),
            r = 1,
            g = 0.3,
            b = 0.3
        }
        for _, slotName in ipairs(missingEnchants or {}) do
            enchantTooltipLines[#enchantTooltipLines + 1] = {
                text = "• " .. slotName,
                r = 1,
                g = 0.82,
                b = 0.2
            }
        end
    end
    frame.buttons.gearEnchants.tooltipLines = enchantTooltipLines

    setSecureButtonAction(frame.buttons.food, nil)
    setSecureButtonAction(frame.buttons.flask, flaskAction)
    setSecureButtonAction(frame.buttons.gearEnchants, nil)
    setSecureButtonAction(frame.buttons.rune, runeAction)
    setSecureButtonAction(frame.buttons.healthstone, nil)
    setSecureButtonAction(frame.buttons.mainHand, mainAction, mainAction and 16 or nil)
    setSecureButtonAction(frame.buttons.offHand, offAction, offAction and 17 or nil)

    setIconState(
        frame.buttons.food,
        auraState(available, scan.food),
        Data:FormatRemaining(foodDetail.expirationTime),
        nil,
        foodDetail.icon
    )
    setIconState(
        frame.buttons.flask,
        auraState(available, scan.flask),
        Data:FormatRemaining(flaskDetail.expirationTime),
        flaskCount,
        flaskDetail.icon or (flaskItem and Data:GetItemTexture(flaskItem))
    )
    setIconState(
        frame.buttons.gearEnchants,
        permanentDataAvailable and
            (permanentReady and STATE_READY or STATE_NOT_READY) or nil,
        "",
        nil
    )
    setIconState(
        frame.buttons.rune,
        auraState(available, scan.rune),
        Data:FormatRemaining(runeDetail.expirationTime),
        runeCount,
        runeDetail.icon or (runeItem and Data:GetItemTexture(runeItem))
    )
    setIconState(
        frame.buttons.healthstone,
        healthstoneCount > 0 and STATE_READY or STATE_NOT_READY,
        "",
        healthstoneCount,
        Data:GetItemTexture(healthstoneItem or Data.HEALTHSTONE_ITEM)
    )
    setIconState(
        frame.buttons.mainHand,
        weaponDataAvailable and
            (hasMain and STATE_READY or STATE_NOT_READY) or nil,
        hasMain and weaponRemaining(mainTime) or "",
        mainCount,
        mainItem and Data:GetItemTexture(mainItem)
    )
    setIconState(
        frame.buttons.offHand,
        weaponDataAvailable and
            (hasOff and STATE_READY or STATE_NOT_READY) or nil,
        hasOff and weaponRemaining(offTime) or "",
        offCount,
        offItem and Data:GetItemTexture(offItem)
    )

    self:ApplyLayout()
end

function ReadyCheckConsumables:ShowDisplayOutOfCombat()
    local frame = self.frame
    if not frame or InCombatLockdown() then
        return
    end

    if not self.visibilityDriverRegistered then
        RegisterStateDriver(frame, "visibility", VISIBILITY_DRIVER)
        self.visibilityDriverRegistered = true
    end
    frame:Show()
end

function ReadyCheckConsumables:HideDisplayOutOfCombat(clearActions)
    local frame = self.frame
    if not frame then
        return
    end
    if InCombatLockdown() then
        self:QueueHide(clearActions)
        return
    end

    self:CancelTimers()
    if self.visibilityDriverRegistered then
        UnregisterStateDriver(frame, "visibility")
        self.visibilityDriverRegistered = nil
    end

    frame.moveOverlay:Hide()
    for _, key in ipairs(ICON_ORDER) do
        frame.buttons[key]:EnableMouse(true)
    end
    frame:Hide()
    if clearActions then
        for _, key in ipairs(ICON_ORDER) do
            setSecureButtonAction(frame.buttons[key], nil)
        end
    end
    self.displayMode = nil
    if self.refreshOptionsOnHide then
        self.refreshOptionsOnHide = nil
        if E.RefreshOptions then
            E:RefreshOptions()
        end
    end
end

function ReadyCheckConsumables:HideDisplay(clearActions)
    local shouldClearActions = self.clearActionsOnHide or clearActions
    local wasTesting = self:IsTesting()
    self.refreshOptionsOnHide =
        self.refreshOptionsOnHide or self.unlocked or wasTesting
    self.displaySerial = (self.displaySerial or 0) + 1
    self.unlocked = false
    self.displayMode = nil
    self:CancelTimers()
    self:CancelDeferredWork()

    if InCombatLockdown() then
        if wasTesting and E.RefreshOptions then
            E:RefreshOptions()
        end
        self:QueueHide(shouldClearActions)
    else
        self:HideDisplayOutOfCombat(shouldClearActions)
    end
end

function ReadyCheckConsumables:StartRefreshTimers(serial)
    if not self.frame then
        return
    end

    self.delayedRefreshTimer = C_Timer.NewTimer(0.25, function()
        self.delayedRefreshTimer = nil
        if self.displaySerial == serial and self:IsEnabled() then
            self:UpdateDisplay()
        end
    end)

    self.refreshTicker = C_Timer.NewTicker(1, function()
        if self.displaySerial == serial and self:IsEnabled() then
            self:UpdateDisplay()
        end
    end)
end

function ReadyCheckConsumables:StartReadyCheckTimeout(timeout, serial)
    local duration = 62
    if not E:IsSecret(timeout) and type(timeout) == "number" then
        duration = clamp(timeout, 5, 60, 40) + 2
    end

    self.hideTimer = C_Timer.NewTimer(duration, function()
        self.hideTimer = nil
        if self.displaySerial == serial and not self.unlocked then
            self:HideDisplay(false)
        end
    end)
end

function ReadyCheckConsumables:ShowForReadyCheck(starter, timeout, forceCenter)
    if InCombatLockdown() or not self:IsEnabled() or self.unlocked or
        self:IsTesting() then
        return
    end

    self:CancelDeferredWork()
    self:CancelTimers()

    local frame = self:CreateDisplay()
    if not frame then
        return
    end

    self.displaySerial = (self.displaySerial or 0) + 1
    local serial = self.displaySerial
    self.displayMode = forceCenter and "test" or "readyCheck"

    frame.moveOverlay:Hide()
    self:AnchorDisplay(starter, forceCenter)
    self:UpdateDisplay()
    self:ShowDisplayOutOfCombat()
    self:StartRefreshTimers(serial)
    if not forceCenter then
        self:StartReadyCheckTimeout(timeout, serial)
    end
end

function ReadyCheckConsumables:OnReadyCheck(_, starter, timeout)
    if isPlayerReadyCheckStarter(starter) then
        if self.displayMode == "readyCheck" then
            self:HideDisplay(false)
        end
        return
    end

    self:ShowForReadyCheck(starter, timeout, false)
end

function ReadyCheckConsumables:OnReadyCheckFinished()
    if self.displayMode == "readyCheck" then
        self:HideDisplay(false)
    end
end

function ReadyCheckConsumables:OnReadyCheckConfirm(_, unit, ready)
    if self.displayMode ~= "readyCheck" or ready ~= true then
        return
    end
    if not unit then
        return
    end

    local ok, isPlayer = pcall(UnitIsUnit, unit, "player")
    if ok and isPlayer then
        self:HideDisplay(false)
    end
end

function ReadyCheckConsumables:OnUnitChanged(_, unit)
    if unit and (E:IsSecret(unit) or unit ~= "player") then
        return
    end
    self:UpdateDisplay()
end

function ReadyCheckConsumables:OnCombatStart()
    self:HideDisplay(true)
end

function ReadyCheckConsumables:Test()
    if self:IsTesting() then
        self:HideDisplay(false)
        return
    end

    self:ShowForReadyCheck(nil, nil, true)
    if self:IsTesting() and E.RefreshOptions then
        E:RefreshOptions()
    end
end

function ReadyCheckConsumables:Refresh()
    if not self:IsEnabled() then
        return
    end
    if InCombatLockdown() then
        self:QueueRefresh()
        return
    end

    local frame = self.frame
    if not frame then
        return
    end

    for _, key in ipairs(ICON_ORDER) do
        E:SetTemplate(frame.buttons[key], "Transparent")
    end
    E:SetTemplate(frame.moveOverlay, "Transparent")
    self:ApplyTextAppearance()
    frame:SetScale(clamp(self.db.scale, 0.75, 1.5, 1))

    if self.db.customPosition then
        self:ApplySavedPosition()
    elseif self.displayMode == "unlock" then
        E:ApplyFramePosition(frame, DEFAULT_POSITION, UIParent)
    end
    if self.displayMode or self.unlocked then
        self:UpdateDisplay()
    else
        self:ApplyLayout()
    end
end

function ReadyCheckConsumables:OnEnable()
    self:CancelDeferredWork()
    self.unlocked = false
    self.displayMode = nil

    self:RegisterEvent("READY_CHECK", "OnReadyCheck")
    self:RegisterEvent("READY_CHECK_CONFIRM", "OnReadyCheckConfirm")
    self:RegisterEvent("READY_CHECK_FINISHED", "OnReadyCheckFinished")
    self:RegisterEvent("UNIT_AURA", "OnUnitChanged")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnUnitChanged")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnUnitChanged")
    self:RegisterEvent("GROUP_LEFT", "OnReadyCheckFinished")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterMessage("ART_PROFILE_CHANGED", "Refresh")
    self:RegisterMessage("ART_MEDIA_UPDATED", "Refresh")

    if self.frame then
        if InCombatLockdown() then
            self:QueueHide(true)
        else
            self:HideDisplayOutOfCombat(true)
        end
    end
end

function ReadyCheckConsumables:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self:HideDisplay(true)
end

E:RegisterQoLFeature("ReadyCheckConsumables", {
    order = 50,
    labelKey = "QoL_ReadyCheckConsumables",
    descKey = "QoL_ReadyCheckConsumablesDesc",
    moduleName = MODULE_NAME
})
