-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("Durabilityt: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local DUR = NRSKNUI.Addon:NewModule("Durability", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local wipe = wipe
local floor = math.floor
local unpack = unpack
local GetInventoryItemDurability = GetInventoryItemDurability
local ipairs = ipairs
local _G = _G

-- Module init bruv
function DUR:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.Durability
    self:SetEnabledState(false)
end

-- Create a gradient color palet that shows each stage of durability
local GradientColorPalet = {
    1, 0, 0,    -- Red
    1, 0.42, 0, -- Orange
    1, 0.82, 0, -- Yellow
    0, 1, 0     -- Green
}
local InvDurability = {}
local Slots = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local offset = 10

-- Helper: Get parent frame based on anchor type
local function GetParentFrame()
    if DUR.db.Text.anchorFrameType == "SCREEN" or DUR.db.Text.anchorFrameType == "UIPARENT" then
        return UIParent
    else
        local parentName = DUR.db.Text.ParentFrame or "UIParent"
        return _G[parentName] or UIParent
    end
end

-- Durability status update
function DUR:OnEvent()
    -- Skip real updates when in preview mode
    if self.isPreview then return end

    local TotalDurability = 100
    wipe(InvDurability)

    -- Iterate through inventory slots and check durability status
    for _, slot in ipairs(Slots) do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local perc = floor((cur / max) * 100)
            InvDurability[slot] = perc
            if perc < TotalDurability then
                TotalDurability = perc
            end
        end
    end

    -- Dont show warning text unless specific min durability is met
    if self.WarningText and self.db.WarningText.Enabled then
        if TotalDurability > self.db.WarningText.ShowPercent then
            self.WarningText:Hide()
        else
            self.WarningText:Show()
        end
    end

    -- Color and update minimap text with current durability state
    if self.Text and self.db.Text.Enabled then
        local r, g, b
        if self.db.Text.UseStatusColor then
            r, g, b = NRSKNUI:ColorGradient(TotalDurability, 100, unpack(GradientColorPalet))
        else
            r, g, b = unpack(self.db.Text.Color)
        end
        local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
        self.Text:SetText((durText .. "%d%%"):format(TotalDurability))
        self.Text:SetTextColor(r, g, b, 1)
    end
end

-- Create minimap durability text
function DUR:Create()
    if self.Frame then return end
    local posDB = self.db.Text.Position
    local anchorFrame = GetParentFrame()
    local fontOutline = self.db.FontOutline or "OUTLINE"
    if fontOutline == "NONE" then fontOutline = "" end
    local font = NRSKNUI:GetFontPath(self.db.FontFace)

    local Frame = CreateFrame("Frame", nil, UIParent)
    Frame:SetSize(160, 14)
    Frame:SetPoint(posDB.AnchorFrom, anchorFrame, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)

    local Text = Frame:CreateFontString(nil, "OVERLAY")
    Text:SetPoint("LEFT")
    Text:SetFont(font, self.db.Text.FontSize, fontOutline)
    Text:SetShadowOffset(0, 0)
    Text:SetShadowColor(0, 0, 0, 0)
    Text:SetJustifyH("LEFT")
    Text:SetWordWrap(false)
    Text:SetIndentedWordWrap(false)

    self.Frame = Frame
    self.Text = Text
end

-- Update text, called from GUI
function DUR:UpdateText()
    if not self.db.Text.Enabled and self.Text then
        self.Text:Hide()
        return
    else
        self.Text:Show()
    end
    if not self.Frame then return end
    local posDB = self.db.Text.Position
    local anchorFrame = GetParentFrame()
    self.Frame:ClearAllPoints()
    self.Frame:SetPoint(posDB.AnchorFrom, anchorFrame, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)

    -- Only update text color if status color is disabled
    if not self.db.Text.UseStatusColor then
        local r, g, b = unpack(self.db.Text.Color)
        self.Text:SetTextColor(r, g, b, 1)
    end
end

-- Create low durability warning text
function DUR:CreateWarning()
    if self.WarningFrame then return end
    local posDB = self.db.WarningText.Position
    local color = self.db.WarningText.WarningColor
    local fontOutline = self.db.FontOutline or "OUTLINE"
    if fontOutline == "NONE" then fontOutline = "" end
    local font = NRSKNUI:GetFontPath(self.db.FontFace)

    local WarningFrame = CreateFrame("Frame", nil, UIParent)
    WarningFrame:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)

    local WarningText = WarningFrame:CreateFontString(nil, "OVERLAY")
    WarningText:SetPoint("CENTER")
    WarningText:SetFont(font, self.db.WarningText.FontSize, fontOutline)
    WarningText:SetTextColor(unpack(color))
    WarningText:SetText(self.db.WarningText.WarningText)
    WarningText:SetShadowOffset(0, 0)
    WarningText:SetShadowColor(0, 0, 0, 0)
    WarningText:Hide()

    local width, height = math.max(WarningText:GetWidth(), 170), math.max(WarningText:GetHeight(), 18)
    WarningFrame:SetSize(width + offset, height + offset)

    self.WarningFrame = WarningFrame
    self.WarningText = WarningText
end

-- Update warning text, called from GUI
function DUR:UpdateWarning()
    if not self.db.WarningText.Enabled and self.WarningText then
        self.WarningText:Hide()
        return
    else
        DUR:OnEvent()
    end
    if not self.WarningFrame then return end
    local posDB = self.db.WarningText.Position
    local color = self.db.WarningText.WarningColor
    self.WarningFrame:ClearAllPoints()
    self.WarningFrame:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)
    self.WarningText:SetText(self.db.WarningText.WarningText)
    self.WarningText:SetTextColor(unpack(color))
    DUR:OnEvent()
end

-- Update font stuf, called from GUI
function DUR:UpdateFonts()
    local fontOutline = self.db.FontOutline or "OUTLINE"
    if fontOutline == "NONE" then fontOutline = "" end
    local font = NRSKNUI:GetFontPath(self.db.FontFace)

    self.WarningText:SetFont(font, self.db.WarningText.FontSize, fontOutline)
    self.Text:SetFont(font, self.db.Text.FontSize, fontOutline)

    local WTwidth, WTheight = self.WarningText:GetWidth(), self.WarningText:GetHeight()
    self.WarningFrame:SetSize(WTwidth + offset, WTheight + offset)

    local DTwidth, DTheight = self.Text:GetWidth(), self.Text:GetHeight()
    self.Frame:SetSize(DTwidth + offset, DTheight)

    C_Timer.After(0.1, function()
        DUR:OnEvent()
    end)
end

-- Register events
function DUR:EventReg()
    local events = {
        "UPDATE_INVENTORY_DURABILITY",
        "MERCHANT_SHOW",
        "PLAYER_ENTERING_WORLD"
    }
    for _, event in ipairs(events) do
        self:RegisterEvent(event, function() DUR:OnEvent() end)
    end
end

-- Module OnEnable
function DUR:OnEnable()
    if not self.db.Enabled then return end
    self:Create()
    self:CreateWarning()
    self:EventReg()

    -- Register warning text with my custom edit mode
    local config = {
        key = "DurabilityWarning",
        displayName = "Low Durability Warning",
        frame = self.WarningFrame,
        getPosition = function()
            return self.db.WarningText.Position
        end,
        setPosition = function(pos)
            self.db.WarningText.Position.AnchorFrom = pos.AnchorFrom
            self.db.WarningText.Position.AnchorTo = pos.AnchorTo
            self.db.WarningText.Position.XOffset = pos.XOffset
            self.db.WarningText.Position.YOffset = pos.YOffset
            if self.WarningFrame then
                self.WarningFrame:ClearAllPoints()
                self.WarningFrame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "Durability",
    }
    NRSKNUI.EditMode:RegisterElement(config)

    -- Register text with my custom edit mode
    local configText = {
        key = "DurabilityText",
        displayName = "Durability Text",
        frame = self.Frame,
        getPosition = function()
            return self.db.Text.Position
        end,
        setPosition = function(pos)
            self.db.Text.Position.AnchorFrom = pos.AnchorFrom
            self.db.Text.Position.AnchorTo = pos.AnchorTo
            self.db.Text.Position.XOffset = pos.XOffset
            self.db.Text.Position.YOffset = pos.YOffset
            if self.Frame then
                local parent = GetParentFrame()
                self.Frame:ClearAllPoints()
                self.Frame:SetPoint(pos.AnchorFrom, parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        getParentFrame = function()
            return GetParentFrame()
        end,
        guiPath = "Durability",
    }
    NRSKNUI.EditMode:RegisterElement(configText)

    C_Timer.After(0.1, function()
        DUR:UpdateWarning()
        DUR:UpdateText()
    end)
end

-- Module OnDisable
function DUR:OnDisable()
    if self.WarningText then
        self.WarningText:Hide()
    end
    if self.Text then
        self.Text:Hide()
    end
    self:UnregisterAllEvents()
end

-- Show preview for edit mode/GUI
function DUR:ShowPreview()
    if not self.Frame then
        self:Create()
    end
    if not self.WarningFrame then
        self:CreateWarning()
    end
    self.isPreview = true
    if self.Text then
        self.Text:Show()
        -- Show sample text for preview
        local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
        self.Text:SetText((durText .. "75%%"))
        self.Text:SetTextColor(1, 0.82, 0, 1) -- Yellow for 75%
    end
    if self.WarningText then
        self.WarningText:Show()
    end
end

-- Hide preview
function DUR:HidePreview()
    self.isPreview = false
    -- Restore normal state based on db settings
    if self.Text then
        if not self.db.Text.Enabled then
            self.Text:Hide()
        end
    end
    if self.WarningText then
        -- Warning text is controlled by durability percentage, trigger update
        self:OnEvent()
    end
end
