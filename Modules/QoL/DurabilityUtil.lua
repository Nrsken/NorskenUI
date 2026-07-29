---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DurabilityModule
local Durability = NRSKNUI:GetModule('Durability')
local Anchors = NRSKNUI.Anchors

local GetInventoryItemDurability = GetInventoryItemDurability
local CreateFrame = CreateFrame
local math_floor = math.floor
local ipairs = ipairs
local unpack = unpack
local wipe = wipe

function Durability:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Durability
end

function Durability:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Returns the lowest durability percentage of the player's equipped gear.
local InvDurability = {}
local SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }
local function GetLowestDurability()
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

function Durability:CreateFrame()
    if self.coreFrame then return end

    local coreFrame = CreateFrame('Frame', 'NRSKNUI_DurabilityFrame', UIParent)
    coreFrame:SetPixelSize(180, 28)
    coreFrame:ApplyPosition(self.db)

    coreFrame.text = coreFrame:CreateFontString(nil, 'OVERLAY')

    self.coreFrame = coreFrame
    coreFrame:Hide()
end

function Durability:ApplySettings()
    if not self.coreFrame then return end

    local tR, tG, tB, tA = unpack(self.db.TextColorLow)
    local bR, bG, bB, bA = unpack(self.db.TextColorBroken)

    -- Store and cache colors for later use.
    Durability.Colors = {
        TextLow = { tR, tG, tB, tA },
        TextBroken = { bR, bG, bB, bA },
    }

    self.coreFrame.text:SetFontStyle(self.db)
    self.coreFrame.text:SetTextColor(tR, tG, tB, tA)
    self.coreFrame.text:SetFontJustify('CENTER', self.coreFrame, 0, 0)
    self.coreFrame.text:SetText(self.db.TextLow)

    self.coreFrame:SetPixelSize(self.coreFrame.text:GetStringWidth(), self.coreFrame.text:GetStringHeight())
    self.coreFrame:ApplyPosition(self.db)
end

function Durability:OnEvent()
    if self.isPreview then return end

    local durability = GetLowestDurability()
    local threshold = (NRSKNUI:InCombat() and self.db.CombatShowPercent) or self.db.ShowPercent

    -- Gear is broken, show broken text and color
    if durability == 0 then
        self.coreFrame.text:SetText(self.db.TextBroken)
        self.coreFrame.text:SetTextColor(unpack(Durability.Colors.TextBroken))
        self.coreFrame:SetShown(true)
    else
        -- If gear is below threshold, show low text and color
        self.coreFrame.text:SetText(self.db.TextLow)
        self.coreFrame.text:SetTextColor(unpack(Durability.Colors.TextLow))
        self.coreFrame:SetShown(durability <= threshold)
    end
end

function Durability:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:ApplySettings()

    self:RegisterEvent('UPDATE_INVENTORY_DURABILITY', 'OnEvent')
    self:RegisterEvent('MERCHANT_SHOW', 'OnEvent')
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'OnEvent')

    Anchors:Register(self, 'DurabilityLow', self.coreFrame, 'durabilityUtil')

    -- If the module is enabled and the preview is active, show the frame.
    -- Without this a showpreview re trigger is needed, e.g reopen GUI.
    if self.coreFrame and self.isPreview then
        self.coreFrame:Show()
    end
end

function Durability:OnDisable()
    if self.coreFrame then
        self.coreFrame:Hide()
        Anchors:Unregister('DurabilityLow')
    end
end

function Durability:ShowPreview()
    if not self.coreFrame then return end
    self.isPreview = true
    self.coreFrame:Show()
end

function Durability:HidePreview()
    self.isPreview = false
    if not self.coreFrame then return end

    if not self.db.Enabled then
        self.coreFrame:Hide()
        return
    else
        self:OnEvent()
    end
end
