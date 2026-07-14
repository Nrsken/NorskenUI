---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class Durability: AceModule, AceEvent-3.0
local DUR = NRSKNUI:NewModule("Durability", "AceEvent-3.0")

local CreateFrame = CreateFrame
local wipe = wipe
local math_floor = math.floor
local math_max = math.max
local unpack = unpack
local GetInventoryItemDurability = GetInventoryItemDurability
local ipairs = ipairs

local GRADIENT_COLORS = { 1, 0, 0, 1, 0.42, 0, 1, 0.82, 0, 0, 1, 0 }
local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local FRAME_PADDING = 10
local InvDurability = {}

function DUR:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Durability
end

function DUR:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function DUR:GetLowestDurability()
    local lowest = 100
    wipe(InvDurability)

    for _, slot in ipairs(SLOTS) do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then
            local perc = math_floor((cur / max) * 100)
            InvDurability[slot] = perc
            if perc < lowest then
                lowest = perc
            end
        end
    end

    return lowest
end

function DUR:OnEvent()
    if self.isPreview then return end
    if not self.db or not self.db.WarningText or not self.db.Text then return end

    local durability = self:GetLowestDurability()

    if self.warningFrame and self.db.WarningText.Enabled then
        local threshold = self.inCombat and self.db.WarningText.CombatShowPercent or self.db.WarningText.ShowPercent
        self.warningFrame:SetShown(durability <= threshold)
    end

    if self.text and self.db.Text.Enabled then
        local r, g, b
        if self.db.Text.UseStatusColor then
            r, g, b = NRSKNUI:ColorGradient(durability, 100, unpack(GRADIENT_COLORS))
        else
            r, g, b = unpack(self.db.Text.Color)
        end
        local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
        self.text:SetText((durText .. "%d%%"):format(durability))
        self.text:SetTextColor(r, g, b, 1)
    end
end

function DUR:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame("Frame", "NRSKNUI_DurabilityDataText", UIParent)
    frame:SetSize(160, 14)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFontStyle(self.db, self.db.Text.FontSize)
    text:SetPoint("LEFT")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText("100%")

    self.frame = frame
    self.text = text
end

function DUR:CreateWarningFrame()
    if self.warningFrame then return end

    local frame = CreateFrame("Frame", "NRSKNUI_DurabilityWarning", UIParent)
    frame:SetSize(180, 28)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetFontStyle(self.db, self.db.WarningText.FontSize)
    text:SetPoint("CENTER")
    text:SetText("LOW DURABILITY")

    self.warningFrame = frame
    self.warningText = text
end

function DUR:UpdateFrameSize()
    if self.warningText and self.warningFrame then
        local w = math_max(self.warningText:GetStringWidth(), 170)
        local h = math_max(self.warningText:GetStringHeight(), 18)
        self.warningFrame:SetSize(w + FRAME_PADDING, h + FRAME_PADDING)
    end

    if self.text and self.frame then
        local w = self.text:GetStringWidth()
        local h = self.text:GetStringHeight()
        self.frame:SetSize(w + FRAME_PADDING, h)
    end
end

function DUR:ApplySettings()
    if not self.db then return end

    if self.text then
        NRSKNUI:ApplyFramePosition(self.frame, self.db.Text.Position, self.db.Text)
        self.text:SetFontStyle(self.db, self.db.Text.FontSize)

        if self.db.Text.Enabled or self.isPreview then
            self.frame:Show()
        else
            self.frame:Hide()
        end

        if self.isPreview then
            local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
            self.text:SetText(durText .. "75%")
            if self.db.Text.UseStatusColor then
                self.text:SetTextColor(1, 0.82, 0, 1)
            else
                self.text:SetTextColor(unpack(self.db.Text.Color))
            end
        end
    end

    if self.warningText then
        self.warningText:SetFontStyle(self.db, self.db.WarningText.FontSize)
        NRSKNUI:ApplyFramePosition(self.warningFrame, self.db.WarningText.Position, { anchorFrameType = "UIPARENT" })

        local color = self.db.WarningText.WarningColor
        self.warningText:SetText(self.db.WarningText.WarningText)
        self.warningText:SetTextColor(unpack(color))

        if self.isPreview then
            self.warningFrame:Show()
        end
    end

    self:UpdateFrameSize()
    self:OnEvent()
end

function DUR:RegisterEvents()
    self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "OnEvent")
    self:RegisterEvent("MERCHANT_SHOW", "OnEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")

    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        DUR.inCombat = true
        DUR:OnEvent()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        DUR.inCombat = false
        DUR:OnEvent()
    end)
end

function DUR:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:CreateWarningFrame()
    self:RegisterEvents()
    C_Timer.After(0.5, function() self:ApplySettings() end)

    NRSKNUI.EditMode:RegisterElement({
        key = "DurabilityWarning",
        displayName = "Low Durability Warning",
        frame = self.warningFrame,
        getPosition = function()
            return self.db.WarningText.Position
        end,
        setPosition = function(pos)
            self.db.WarningText.Position.AnchorFrom = pos.AnchorFrom
            self.db.WarningText.Position.AnchorTo = pos.AnchorTo
            self.db.WarningText.Position.XOffset = pos.XOffset
            self.db.WarningText.Position.YOffset = pos.YOffset
            if self.warningFrame then
                self.warningFrame:ClearAllPoints()
                self.warningFrame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "Durability",
    })

    NRSKNUI.EditMode:RegisterElement({
        key = "DurabilityText",
        displayName = "Durability Text",
        frame = self.frame,
        getPosition = function()
            return self.db.Text.Position
        end,
        setPosition = function(pos)
            self.db.Text.Position.AnchorFrom = pos.AnchorFrom
            self.db.Text.Position.AnchorTo = pos.AnchorTo
            self.db.Text.Position.XOffset = pos.XOffset
            self.db.Text.Position.YOffset = pos.YOffset
            if self.frame then
                local parent = NRSKNUI:ResolveAnchorFrame(self.db.Text.anchorFrameType, self.db.Text.ParentFrame)
                self.frame:ClearAllPoints()
                self.frame:SetPoint(pos.AnchorFrom, parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.Text.anchorFrameType, self.db.Text.ParentFrame)
        end,
        guiPath = "Durability",
    })
end

function DUR:OnDisable()
    if self.warningFrame then self.warningFrame:Hide() end
    if self.frame then self.frame:Hide() end
    self:UnregisterAllEvents()
end

function DUR:ShowPreview()
    if not self.db then return end

    if not self.frame then self:CreateFrame() end
    if not self.warningFrame then self:CreateWarningFrame() end

    self.isPreview = true
    --self:ApplySettings()
    --C_Timer.After(0.5, function() self:ApplySettings() end)

    if self.frame and self.text then
        self.frame:Show()
        local durText = NRSKNUI:ColorText(self.db.Text.DurText, self.db.Text.DurColor)
        self.text:SetText(durText .. "75%")
        self.text:SetTextColor(1, 0.82, 0, 1)
    end

    if self.warningFrame then self.warningFrame:Show() end
end

function DUR:HidePreview()
    self.isPreview = false
    if not self.db then return end

    if not self.db.Enabled then
        if self.frame then self.frame:Hide() end
        if self.warningFrame then self.warningFrame:Hide() end
        return
    end

    if self.frame and (not self.db.Text or not self.db.Text.Enabled) then
        self.frame:Hide()
    end

    if self.warningFrame then
        if not self.db.WarningText or not self.db.WarningText.Enabled then
            self.warningFrame:Hide()
        else
            self:OnEvent()
        end
    end
end
