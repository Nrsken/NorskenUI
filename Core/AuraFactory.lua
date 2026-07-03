---@class NRSKNUI
local NRSKNUI = select(2, ...)

local Mixin = Mixin
local ipairs = ipairs
local floor = math.floor
local max = math.max
local ceil = math.ceil

---@class AuraStyleMixin
local AuraStyleMixin = {}

---@class AuraStyledFrame : Frame, AuraStyleMixin

---@param self AuraStyledFrame
---@param auraButton Frame
function AuraStyleMixin:SetBorderMix(auraButton)
    if not auraButton then return end
    NRSKNUI:AddBorders(auraButton, { 0, 0, 0, 1 }, auraButton, 1)
end

---@param auraButton Frame
---@param overlayTexture Texture
function AuraStyleMixin:SetOverlayMix(auraButton, overlayTexture)
    if not auraButton or not overlayTexture then return end
    overlayTexture:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\AuraOverlay.png")
    overlayTexture:SetPoint("TOPLEFT", auraButton, "TOPLEFT", 1, -1)
    overlayTexture:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -1, 1)
end

---@param auraButtonTexture Texture
function AuraStyleMixin:SetZoomMix(auraButtonTexture)
    if not auraButtonTexture then return end
    NRSKNUI:ApplyZoom(auraButtonTexture, NRSKNUI.GlobalZoom)
end

---@param textObj FontString
---@param db table
---@param fontSize number
function AuraStyleMixin:SetTextStyleMix(textObj, db, fontSize)
    if not textObj or not db or not fontSize then return end
    textObj:SetTextColor(1, 1, 1, 1)
    NRSKNUI:ApplyFont(textObj, NRSKNUI:GetEffectiveFont(db), fontSize, db.FontOutline)
    textObj:SetShadowColor(0, 0, 0, 0)
end

---@param self AuraStyledFrame
---@param cooldown Cooldown
---@param db table
function AuraStyleMixin:SetCooldownTextStyleMix(cooldown, db)
    if not cooldown or not db then return end
    local countdownText = cooldown:GetCountdownFontString()
    if countdownText then
        local DurPos = db.TimerPosition
        countdownText:ClearAllPoints()
        countdownText:SetPoint(DurPos.AnchorFrom, self, DurPos.AnchorTo, DurPos.XOffset, DurPos.YOffset)
        self:SetTextStyleMix(countdownText, db, db.TimerFontSize)
        return
    end

    -- Find FontString manually if GetCountdownFontString fails
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            ---@cast region FontString
            local DurPos = db.TimerPosition
            region:ClearAllPoints()
            region:SetPoint(DurPos.AnchorFrom, self, DurPos.AnchorTo, DurPos.XOffset, DurPos.YOffset)
            self:SetTextStyleMix(region, db, db.TimerFontSize)
            return
        end
    end
end

---@param auraButton Frame
---@param cooldown Cooldown
---@param db table
function AuraStyleMixin:SetCooldownStyleMix(auraButton, cooldown, db)
    if not auraButton or not cooldown or not db then return end
    auraButton:SetDurationCooldown(cooldown)
    cooldown:SetPoint("TOPLEFT", auraButton, "TOPLEFT", 1, -1)
    cooldown:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", -1, 1)
    cooldown:SetDrawEdge(false)
    cooldown:SetReverse(db.Reverse)
    cooldown:SetDrawSwipe(db.Swipe)
    cooldown:SetDrawBling(false)
    cooldown:SetCountdownFormatter(NRSKNUI.timeFormatter)
    cooldown:SetHideCountdownNumbers(false)
end

---@param db AuraLayoutDB
---@return number width, number height
function AuraStyleMixin:GetContainerSizeMix(db)
    local perRow = max(db.IconsPerRow or db.MaxIcons, 1)
    local rows = ceil(db.MaxIcons / perRow)
    local spacing = db.IconSpacing or 0
    local width = perRow * db.IconSize + (perRow - 1) * spacing
    local height = rows * db.IconSize + (rows - 1) * spacing
    return max(width, 1), max(height, 1)
end

---@param self AuraStyledFrame
---@param container Frame
---@param db AuraLayoutDB
---@param index number
function AuraStyleMixin:SetButtonPositionMix(container, db, index)
    local perRow = max(db.IconsPerRow or db.MaxIcons, 1)
    local stride = db.IconSize + (db.IconSpacing or 0)
    local row = floor((index - 1) / perRow)
    local column = (index - 1) % perRow

    local x = column * stride
    local y = row * stride

    if db.GrowthDirection == "LEFT" then x = -x end
    if db.WrapDirection == "DOWN" then y = -y end

    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", container, "TOPLEFT", x, y)
end

local function GetAnchorPoint(db)
    local h, v = db.GrowthDirection or "LEFT", db.WrapDirection or "DOWN"
    if h == "LEFT" and v == "DOWN" then
        return "TOPRIGHT"
    elseif h == "LEFT" and v == "UP" then
        return "BOTTOMRIGHT"
    elseif h == "RIGHT" and v == "DOWN" then
        return "TOPLEFT"
    else
        return "BOTTOMLEFT"
    end
end

---@param container Frame
---@param db AuraLayoutDB
function AuraStyleMixin:ApplyContainerPositionMix(container, db)
    if not container then return end
    local posDB = db.Position
    local anchorPoint = GetAnchorPoint(db)
    container:ClearAllPoints()
    container:SetPoint(anchorPoint, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)
    NRSKNUI:SnapFrameToPixels(container)
end

---@generic T : Frame
---@param auraButton T
---@return T|AuraStyledFrame
function NRSKNUI:ApplyAuraMixin(auraButton)
    Mixin(auraButton, AuraStyleMixin)
    return auraButton
end