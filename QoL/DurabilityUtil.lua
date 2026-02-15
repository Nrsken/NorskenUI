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
    if self.WarningFrame and self.db.WarningText.Enabled then
        if self.inCombat then
            if TotalDurability > self.db.WarningText.CombatShowPercent then
                self.WarningFrame:Hide()
            else
                self.WarningFrame:Show()
            end
        else
            if TotalDurability > self.db.WarningText.ShowPercent then
                self.WarningFrame:Hide()
            else
                self.WarningFrame:Show()
            end
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

    local Frame = CreateFrame("Frame", nil, UIParent)
    Frame:SetSize(160, 14)

    local Text = Frame:CreateFontString(nil, "OVERLAY")
    Text:SetPoint("LEFT")
    Text:SetJustifyH("LEFT")
    Text:SetWordWrap(false)
    Text:SetIndentedWordWrap(false)

    self.Frame = Frame
    self.Frame.text = Text
    self.Text = Text

    -- Hide initially, causes weird first login issues otherwise
    Frame:Hide()

    -- Apply position and font settings
    NRSKNUI:ApplyFramePosition(self.Frame, self.db.Text.Position, self.db.Text)
    NRSKNUI:ApplyFontToText(self.Text, self.db.FontFace, self.db.Text.FontSize, self.db.FontOutline)
end

-- Update text, called from GUI
function DUR:UpdateText()
    if not self.Frame then return end
    if not self.db.Text.Enabled and not self.isPreview then
        self.Frame:Hide()
        return
    else
        self.Frame:Show()
    end

    -- Apply position settings
    NRSKNUI:ApplyFramePosition(self.Frame, self.db.Text.Position, self.db.Text)

    -- Update preview text with current settings
    if self.isPreview then
        local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
        self.Text:SetText((durText .. "75%"))
        self.Text:SetTextColor(1, 0.82, 0, 1)
    elseif not self.db.Text.UseStatusColor then
        -- Only update text color if status color is disabled
        local r, g, b = unpack(self.db.Text.Color)
        self.Text:SetTextColor(r, g, b, 1)
    end
end

-- Create low durability warning text
function DUR:CreateWarning()
    if self.WarningFrame then return end
    local color = self.db.WarningText.WarningColor

    local WarningFrame = CreateFrame("Frame", nil, UIParent)
    local WarningText = WarningFrame:CreateFontString(nil, "OVERLAY")
    WarningText:SetPoint("CENTER")

    self.WarningFrame = WarningFrame
    self.WarningText = WarningText

    -- Apply position settings
    NRSKNUI:ApplyFramePosition(self.WarningFrame, self.db.WarningText.Position, { anchorFrameType = "UIPARENT" })

    -- Apply font settings
    NRSKNUI:ApplyFontToText(WarningText, self.db.FontFace, self.db.WarningText.FontSize, self.db.FontOutline)

    -- Set text and color
    WarningText:SetTextColor(unpack(color))
    WarningText:SetText(self.db.WarningText.WarningText)

    local width, height = math.max(WarningText:GetWidth(), 170), math.max(WarningText:GetHeight(), 18)
    WarningFrame:SetSize(width + offset, height + offset)

    -- Hide after soft outline is created so it hides too
    WarningFrame:Hide()
end

-- Update warning text, called from GUI
function DUR:UpdateWarning()
    if not self.WarningFrame then return end
    if not self.db.WarningText.Enabled then
        self.WarningFrame:Hide()
        return
    end

    local color = self.db.WarningText.WarningColor

    -- Apply position settings
    NRSKNUI:ApplyFramePosition(self.WarningFrame, self.db.WarningText.Position, { anchorFrameType = "UIPARENT" })

    self.WarningText:SetText(self.db.WarningText.WarningText)
    self.WarningText:SetTextColor(unpack(color))
    DUR:OnEvent()
end

-- Update font settings, called from GUI
function DUR:UpdateFonts()
    NRSKNUI:ApplyFontToText(self.WarningText, self.db.FontFace, self.db.WarningText.FontSize, self.db.FontOutline)
    NRSKNUI:ApplyFontToText(self.Text, self.db.FontFace, self.db.Text.FontSize, self.db.FontOutline)

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
        "PLAYER_ENTERING_WORLD",
    }
    for _, event in ipairs(events) do
        self:RegisterEvent(event, function() DUR:OnEvent() end)
    end

    -- Special handling for combat stuff
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        DUR.inCombat = true
        DUR:OnEvent()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        DUR.inCombat = false
        DUR:OnEvent()
    end)
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
                local parent = NRSKNUI:ResolveAnchorFrame(self.db.Text.anchorFrameType, self.db.Text.ParentFrame)
                self.Frame:ClearAllPoints()
                self.Frame:SetPoint(pos.AnchorFrom, parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.Text.anchorFrameType, self.db.Text.ParentFrame)
        end,
        guiPath = "Durability",
    }
    NRSKNUI.EditMode:RegisterElement(configText)

    C_Timer.After(0.5, function()
        DUR:UpdateWarning()
        DUR:UpdateText()
    end)
end

-- Module OnDisable
function DUR:OnDisable()
    if self.WarningFrame then
        self.WarningFrame:Hide()
    end
    if self.Frame then
        self.Frame:Hide()
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
    if self.Frame and self.Text then
        self.Frame:Show()
        local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
        self.Text:SetText((durText .. "75%"))
        self.Text:SetTextColor(1, 0.82, 0, 1)
    end
    if self.WarningFrame then
        self.WarningFrame:Show()
    end
end

-- Hide preview
function DUR:HidePreview()
    self.isPreview = false
    if self.Frame then
        if not self.db.Text.Enabled then
            self.Frame:Hide()
        end
    end
    if self.WarningFrame then
        self:OnEvent()
    end
end
