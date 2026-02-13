-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("Gateway: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local GATE = NRSKNUI.Addon:NewModule("Gateway", "AceEvent-3.0")

-- Localization Setup
local C_Item = C_Item
local C_Timer = C_Timer
local IsUsableItem = C_Item.IsUsableItem
local GetItemCount = C_Item.GetItemCount
local GetItemInfo = C_Item.GetItemInfo

-- Shared EditMode config helper
local function CreateEditModeConfig(self)
    return {
        key = "GatewayAlert",
        displayName = "Gateway Alert",
        frame = self.alertFrame,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            NRSKNUI:ApplyFramePosition(self.alertFrame, self.db.Position, self.db)
        end,
        guiPath = "gateway",
    }
end

-- Constants
local GATEWAY_ITEM_ID = 188152

-- Module state
GATE.isPreview = false

-- Module init
function GATE:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.Gateway
    self.wasUsable = false
    self.hasItem = false
    self.itemName = nil
    self:SetEnabledState(false)
end

-- Module OnEnable
function GATE:OnEnable()
    if not self.db.Enabled then return end
    self:CreateAlertFrame()
    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "FullUpdate")
    self:RegisterEvent("BAG_UPDATE", "FullUpdate")
    self:RegisterEvent("SPELL_UPDATE_USABLE", "CheckUsable")
    self:FullUpdate()

    -- Register with EditMode
    if NRSKNUI.EditMode and not self.editModeRegistered then
        NRSKNUI.EditMode:RegisterElement(CreateEditModeConfig(self))
        self.editModeRegistered = true
    end
end

-- Module OnDisable
function GATE:OnDisable()
    self:UnregisterAllEvents()
    self:HideAlert()
    self.wasUsable = false
    self.hasItem = false
    self.isPreview = false
end

-- Full update
function GATE:FullUpdate()
    C_Timer.After(0.5, function()
        local count = GetItemCount(GATEWAY_ITEM_ID)
        self.hasItem = count and count > 0
        if self.hasItem then
            if not self.itemName then self.itemName = GetItemInfo(GATEWAY_ITEM_ID) end
            self:CheckUsable()
        else
            self:UpdateState(false)
        end
    end)
end

-- Only check usability
function GATE:CheckUsable()
    if not self.hasItem then
        self:UpdateState(false)
        return
    end
    self:UpdateState(IsUsableItem(GATEWAY_ITEM_ID) and true or false)
end

-- Handle state changes
function GATE:UpdateState(isUsable)
    if self.isPreview then return end
    if isUsable == self.wasUsable then return end
    self.wasUsable = isUsable

    if isUsable then
        self.alertFrame.text:SetText("GATE USABLE")
        self.alertFrame:SetAlpha(1)
        self.alertFrame:Show()
    else
        if self.alertFrame then
            self.alertFrame:Hide()
        end
    end
    self:SendMessage("NRSKNUI_GATEWAY_STATE_CHANGED", isUsable)
end

-- Create alert frame
function GATE:CreateAlertFrame()
    if self.alertFrame then return end

    local frame = NRSKNUI:CreateTextFrame(UIParent, 300, 40)
    frame:Hide()

    self.alertFrame = frame
    self:ApplySettings()
    return frame
end

-- Update function for the GUI
function GATE:ApplySettings()
    if not self.alertFrame then return end
    NRSKNUI:ApplyFramePosition(self.alertFrame, self.db.Position, self.db)
    NRSKNUI:ApplyFontSettings(self.alertFrame, self.db, true)

    -- Update frame strata
    if self.db.Strata then
        self.alertFrame:SetFrameStrata(self.db.Strata)
    end
end

-- Preview mode support for GUI and Edit Mode
function GATE:ShowPreview()
    if not self.alertFrame then
        self:CreateAlertFrame()
    end

    -- Register with EditMode if not already registered
    if NRSKNUI.EditMode and not self.editModeRegistered then
        NRSKNUI.EditMode:RegisterElement(CreateEditModeConfig(self))
        self.editModeRegistered = true
    end

    self.isPreview = true
    self.alertFrame.text:SetText("GATE USABLE")
    self.alertFrame:SetAlpha(1)
    self.alertFrame:Show()
    self:ApplySettings()
end

function GATE:HidePreview()
    self.isPreview = false
    -- If module is enabled, check real state; otherwise hide
    if self.db.Enabled then
        self.wasUsable = nil -- Force state update
        self:CheckUsable()
    else
        if self.alertFrame then
            self.alertFrame:Hide()
        end
    end
end

-- Hide alert
function GATE:HideAlert()
    if self.alertFrame then
        self.alertFrame:Hide()
    end
end
