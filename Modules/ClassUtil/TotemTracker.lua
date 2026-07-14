---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class TotemTracker: AceModule, AceEvent-3.0
local TT = NRSKNUI:NewModule("TotemTracker", "AceEvent-3.0")

local CreateFrame = CreateFrame
local ipairs = ipairs
local GetTotemInfo = GetTotemInfo
local GetTime = GetTime
local GetTotemDuration = GetTotemDuration
local InCombatLockdown = InCombatLockdown

local UIParent = UIParent
local MAX_TOTEMS = MAX_TOTEMS
local TOTEM_PRIORITIES = STANDARD_TOTEM_PRIORITIES

local containerFrame = nil
local totemButtons = {}
local isPreviewActive = false
local destroyButtons = {}

local PREVIEW_ICONS = {
    [1] = 136098, -- Healing Stream Totem
    [2] = 136024, -- Capacitor Totem
    [3] = 136114, -- Tremor Totem
    [4] = 136013, -- Earthbind Totem
}

function TT:UpdateDB()
    self.db = NRSKNUI.db.profile.TotemTracker
end

function TT:CreateDestroyButtons()
    if destroyButtons[1] then return end

    if InCombatLockdown() then
        NRSKNUI:DeferUntilUnrestricted(0, function() TT:CreateDestroyButtons() end)
        return
    end

    for slot = 1, MAX_TOTEMS do
        local btn = CreateFrame("Button", "NRSKNUI_DestroyTotem" .. slot, UIParent, "SecureActionButtonTemplate")
        btn:SetAttribute("type", "destroytotem")
        btn:SetAttribute("typerelease", "destroytotem")
        btn:SetAttribute("totem-slot", slot)
        btn:SetAttribute("pressAndHoldAction", 1)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        destroyButtons[slot] = btn
    end
end

function TT:OnInitialize()
    self:UpdateDB()
    self:CreateDestroyButtons()
    self:SetEnabledState(false)
end

local function ApplyCooldownTextStyle(cooldown, db)
    if not cooldown then return end

    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            region:SetFontStyle(db, db.TimerFontSize)
            region:ClearAllPoints()
            region:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
        end
    end
end

function TT:CreateTotemButton(slot)
    local db = self.db

    local btn = CreateFrame("Button", "NRSKNUI_TotemButton" .. slot, containerFrame)
    btn:SetSize(db.IconSize, db.IconSize)
    btn:SetID(slot)

    btn:SetScript("OnEnter", function(frame)
        if GameTooltip:IsForbidden() or not frame:IsVisible() then return end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetTotem(frame:GetID())
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        if GameTooltip:IsForbidden() then return end
        GameTooltip:Hide()
    end)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetZoom()

    btn:AddBorders()

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    btn.highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    btn.highlight:SetColorTexture(1, 1, 1, 0.2)
    btn.highlight:SetBlendMode("ADD")

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn)
    btn.cooldown:SetDrawEdge(false)
    btn.cooldown:SetDrawSwipe(db.Swipe)
    btn.cooldown:SetReverse(db.Reverse)
    btn.cooldown:SetDrawBling(false)
    btn.cooldown:SetHideCountdownNumbers(false)

    btn:Hide()

    return btn
end

function TT:CreateContainer()
    if containerFrame then return end

    containerFrame = CreateFrame("Frame", "NRSKNUI_TotemTracker", UIParent)
    containerFrame:SetSize(200, 50)
    containerFrame:SetClampedToScreen(true)

    for slot = 1, MAX_TOTEMS do totemButtons[slot] = self:CreateTotemButton(slot) end
end

function TT:UpdateContainerPosition()
    if not containerFrame then return end

    local db = self.db
    local position = db.Position
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)

    containerFrame:ClearAllPoints()

    local direction = db.GrowDirection
    if direction == "RIGHT" then
        containerFrame:SetPoint("LEFT", parent, position.AnchorTo, position.XOffset, position.YOffset)
    elseif direction == "LEFT" then
        containerFrame:SetPoint("RIGHT", parent, position.AnchorTo, position.XOffset, position.YOffset)
    elseif direction == "UP" then
        containerFrame:SetPoint("BOTTOM", parent, position.AnchorTo, position.XOffset, position.YOffset)
    elseif direction == "DOWN" then
        containerFrame:SetPoint("TOP", parent, position.AnchorTo, position.XOffset, position.YOffset)
    else
        containerFrame:SetPoint(position.AnchorFrom, parent, position.AnchorTo, position.XOffset, position.YOffset)
    end

    containerFrame:SetFrameStrata(db.Strata)
    containerFrame:SetParent(parent)
end

function TT:UpdateButtonSettings(btn)
    local db = self.db

    btn:SetSize(db.IconSize, db.IconSize)
    btn.cooldown:SetDrawSwipe(db.Swipe)
    btn.cooldown:SetReverse(db.Reverse)
    btn.cooldown:SetHideCountdownNumbers(not db.ShowTimer)
    ApplyCooldownTextStyle(btn.cooldown, db)
end

function TT:LayoutButtons(visibleButtons)
    if not containerFrame then return end

    local db = self.db
    local direction = db.GrowDirection
    local spacing = db.IconSpacing
    local size = db.IconSize

    local numVisible = visibleButtons and #visibleButtons or MAX_TOTEMS
    if numVisible == 0 then numVisible = 1 end

    local totalWidth, totalHeight
    if direction == "RIGHT" or direction == "LEFT" then
        totalWidth = (size * numVisible) + (spacing * (numVisible - 1))
        totalHeight = size
    else
        totalWidth = size
        totalHeight = (size * numVisible) + (spacing * (numVisible - 1))
    end
    containerFrame:SetSize(totalWidth, totalHeight)

    local buttonsToLayout = visibleButtons or totemButtons
    for i, btn in ipairs(buttonsToLayout) do
        btn:ClearAllPoints()

        if direction == "RIGHT" then
            local xOffset = (i - 1) * (size + spacing)
            btn:SetPoint("LEFT", containerFrame, "LEFT", xOffset, 0)
        elseif direction == "LEFT" then
            local xOffset = -((i - 1) * (size + spacing))
            btn:SetPoint("RIGHT", containerFrame, "RIGHT", xOffset, 0)
        elseif direction == "UP" then
            local yOffset = (i - 1) * (size + spacing)
            btn:SetPoint("BOTTOM", containerFrame, "BOTTOM", 0, yOffset)
        elseif direction == "DOWN" then
            local yOffset = -((i - 1) * (size + spacing))
            btn:SetPoint("TOP", containerFrame, "TOP", 0, yOffset)
        end
    end
end

---@param btn table
---@param totem table
function TT:UpdateButton(btn, totem)
    if not (btn and totem) then return end

    local slot = totem.slot
    local _, _, startTime, _, icon = GetTotemInfo(slot)

    if startTime then
        btn.icon:SetTexture(icon)
        btn.cooldown:SetCooldownFromDurationObject(GetTotemDuration(slot))
        btn:Show()
    else
        btn.cooldown:Clear()
        btn:Hide()
    end
end

function TT:UpdateTotems()
    if not self.db or not self.db.Enabled then return end

    if isPreviewActive then
        local currentTime = GetTime()
        local visibleButtons = {}
        for slot = 1, MAX_TOTEMS do
            local btn = totemButtons[slot]
            if btn then
                btn.icon:SetTexture(PREVIEW_ICONS[slot] or PREVIEW_ICONS[1])
                btn.cooldown:SetCooldown(currentTime - (slot * 10), 120)
                btn:Show()
                visibleButtons[#visibleButtons + 1] = btn
            end
        end
        self:LayoutButtons(visibleButtons)
        return
    end

    for i = 1, MAX_TOTEMS do
        local btn = totemButtons[i]
        if btn then btn:Hide() end
    end

    local visibleButtons = {}
    if TotemFrame and TotemFrame.totemPool then
        for totem in TotemFrame.totemPool:EnumerateActive() do
            local priorityIndex = TOTEM_PRIORITIES[totem.layoutIndex]
            if priorityIndex then
                local btn = totemButtons[priorityIndex]
                self:UpdateButton(btn, totem)
                if btn and btn:IsShown() then visibleButtons[#visibleButtons + 1] = btn end
            end
        end
    end

    self:LayoutButtons(visibleButtons)
end

function TT:OnTotemUpdate()
    if self.db and self.db.Enabled then self:UpdateTotems() end
end

function TT:ApplySettings()
    self:UpdateDB()
    self:UpdateContainerPosition()
    self:LayoutButtons()

    for slot = 1, MAX_TOTEMS do
        if totemButtons[slot] then self:UpdateButtonSettings(totemButtons[slot]) end
    end

    self:UpdateTotems()
end

function TT:ShowPreview()
    if not containerFrame then self:CreateContainer() end
    if not containerFrame then return end
    isPreviewActive = true

    for slot = 1, MAX_TOTEMS do
        local btn = totemButtons[slot]
        if btn then
            btn:Show()
            btn:SetAlpha(1)
        end
    end

    containerFrame:Show()
    self:ApplySettings()
end

function TT:HidePreview()
    isPreviewActive = false

    if not self.db.Enabled then
        if containerFrame then containerFrame:Hide() end
    else
        self:UpdateTotems()
    end
end

function TT:TogglePreview()
    if isPreviewActive then
        self:HidePreview()
    else
        self:ShowPreview()
    end
    return isPreviewActive
end

function TT:IsPreviewActive()
    return isPreviewActive
end

function TT:OnEnable()
    if not self.db or not self.db.Enabled then return end

    self:CreateContainer()
    self:UpdateContainerPosition()
    self:LayoutButtons()

    for slot = 1, MAX_TOTEMS do
        if totemButtons[slot] then self:UpdateButtonSettings(totemButtons[slot]) end
    end

    if containerFrame then containerFrame:Show() end

    self:RegisterEvent("PLAYER_TOTEM_UPDATE", "OnTotemUpdate")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnTotemUpdate")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "OnTotemUpdate")
    C_Timer.After(0.1, function() self:UpdateTotems() end)

    if NRSKNUI.EditMode then
        NRSKNUI.EditMode:RegisterElement({
            key = "TotemTracker",
            displayName = "Totem Tracker",
            frame = containerFrame,
            getPosition = function()
                return self.db.Position
            end,
            setPosition = function(pos)
                self.db.Position.AnchorFrom = pos.AnchorFrom
                self.db.Position.AnchorTo = pos.AnchorTo
                self.db.Position.XOffset = pos.XOffset
                self.db.Position.YOffset = pos.YOffset
                self:ApplySettings()
            end,
            getParentFrame = function()
                return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
            end,
            guiPath = "TotemTracker",
        })
    end
end

function TT:OnDisable()
    isPreviewActive = false

    self:UnregisterAllEvents()

    for slot = 1, MAX_TOTEMS do
        local btn = totemButtons[slot]
        if btn then
            btn:SetAlpha(0)
            btn:Hide()
        end
    end

    if containerFrame then containerFrame:Hide() end
    if NRSKNUI.EditMode then NRSKNUI.EditMode:UnregisterElement("TotemTracker") end
end
