---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class Gateway: AceModule, AceEvent-3.0
local Gateway = NRSKNUI:GetModule('Gateway')

local EM = NRSKNUI.EditMode

local IsInGroup = IsInGroup
local unpack = unpack
local CreateFrame = CreateFrame

local UIParent = UIParent

local IsUsableItem = C_Item and C_Item.IsUsableItem
local GetItemCount = C_Item and C_Item.GetItemCount
local GetItemInfo = C_Item and C_Item.GetItemInfo

local GATEWAY_ITEM_ID = 188152

function Gateway:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Gateway
end

function Gateway:OnInitialize()
    self:UpdateDB()
    self.wasUsable = nil
    self:SetEnabledState(false)
end

-- Check if the player is a warlock or if there is a warlock in the group/raid.
function Gateway:CheckGroupForWarlock()
    -- Player is a warlock.
    if NRSKNUI.MyClass == 'WARLOCK' then
        self.hasWarlockInGroup = true
        return true
    end

    -- Player is not a warlock and is not in a group.
    if not IsInGroup() then
        self.hasWarlockInGroup = false
        return false
    end

    -- Check if there is a warlock in the group/raid.
    if NRSKNUI:IsClassInGroup('WARLOCK') then
        self.hasWarlockInGroup = true
        return true
    end

    -- No warlocks found in the group.
    self.hasWarlockInGroup = false
    return false
end

function Gateway:FullUpdate()
    self:CheckGroupForWarlock()
    local count = GetItemCount(GATEWAY_ITEM_ID)
    self.hasItem = count and count > 0

    if self.hasItem then
        if not self.itemName then self.itemName = GetItemInfo(GATEWAY_ITEM_ID) end
        self:CheckUsable()
    else
        self:UpdateState(false)
    end
end

function Gateway:CheckUsable()
    -- Player does not have item.
    if not self.hasItem then
        self:UpdateState(false)
        return
    end

    -- No warlock in the group.
    if not self.hasWarlockInGroup then
        self:UpdateState(false)
        return
    end

    -- Update state based on item usability.
    local isUsable = IsUsableItem(GATEWAY_ITEM_ID)
    self:UpdateState((isUsable and true) or false)
end

function Gateway:UpdateState(isUsable)
    if self.isPreview or not self.alertFrame or isUsable == self.wasUsable then return end
    self.wasUsable = isUsable

    if isUsable then
        self.alertFrame:Show()
    else
        self.alertFrame:Hide()
    end
end

function Gateway:CreateAlertFrame()
    if self.alertFrame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_GatewayAlert', UIParent)
    frame:SetSize(300, 40)

    frame.text = frame:CreateFontString(nil, 'OVERLAY')
    frame.text:SetAllPoints(frame)

    -- Finalize the frame and register it with Anchors.
    self.alertFrame = frame
    EM:Register(self, 'GatewayAlert', self.alertFrame, 'gateway')
    frame:Hide()
end

function Gateway:ApplySettings()
    if not self.alertFrame then return end

    self.alertFrame:ApplyPosition(self.db)
    self.alertFrame.text:SetFontStyle(self.db)
    self.alertFrame.text:SetText(self.db.Text)
    self.alertFrame.text:SetTextColor(unpack(self.db.Color))
end

function Gateway:OnEnable()
    if not self.db.Enabled then return end

    self:CreateAlertFrame()
    self:ApplySettings()
    self:FullUpdate()

    -- Register events for checking usability and group changes.
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'FullUpdate')
    self:RegisterEvent('BAG_UPDATE', 'FullUpdate')
    self:RegisterEvent('SPELL_UPDATE_USABLE', 'CheckUsable')
    self:RegisterEvent('GROUP_ROSTER_UPDATE', function()
        self:CheckGroupForWarlock()
        self:CheckUsable()
    end)
end

function Gateway:OnDisable()
    self:UnregisterAllEvents()
    if self.alertFrame then
        self.alertFrame:Hide()
        EM:UnregisterModuleElement('GatewayAlert')
    end
    self.wasUsable = nil
    self.hasItem = false
    self.isPreview = false
    self.hasWarlockInGroup = false
end

function Gateway:ShowPreview()
    if not self.alertFrame then return end

    self.isPreview = true
    self.alertFrame:Show()
    self:ApplySettings()
end

function Gateway:HidePreview()
    self.isPreview = false

    if self.db.Enabled then
        self.wasUsable = nil
        self:CheckUsable()
    else
        if self.alertFrame then
            self.alertFrame:Hide()
        end
    end
end
