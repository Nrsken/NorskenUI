-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Modules built based on a WeakAura that i do not know who created oiginally, can msg me if you are the OG goat creator

-- Safety check
if not NorskenUI then
    error("AuctionHouseFilter: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class AuctionHouseFilter: AceModule, AceEvent-3.0
local AHF = NorskenUI:NewModule("AuctionHouseFilter", "AceEvent-3.0")

-- Localization
local GetExpansionLevel = GetExpansionLevel
local C_Timer = C_Timer
local C_AddOns = C_AddOns

-- Hook state tracking
local hooksInstalled = false

-- Update db, used for profile changes
function AHF:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.AuctionHouseFilter
end

-- Module init
function AHF:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Apply Current Expansion filter to Blizzard Auction House
function AHF:ApplyAuctionHouseFilter()
    if not self.db.Enabled then return end
    C_Timer.After(0, function()
        if self.db.AuctionHouse.CurrentExpansion then
            local frame = AuctionHouseFrame
            if frame and frame.SearchBar and frame.SearchBar.FilterButton then
                local filterButton = frame.SearchBar.FilterButton
                if filterButton.filters then
                    filterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                end
            end
        end

        -- Focus search bar
        if self.db.AuctionHouse.FocusSearchBar then
            local frame = AuctionHouseFrame
            if frame and frame.SearchBar and frame.SearchBar.SearchBox then
                frame.SearchBar.SearchBox:SetFocus()
            end
        end
    end)
end

-- Apply Current Expansion filter to Craft Orders
function AHF:ApplyCraftOrdersFilter()
    if not self.db.Enabled then return end
    C_Timer.After(0, function()
        if self.db.CraftOrders.CurrentExpansion then
            local frame = ProfessionsCustomerOrdersFrame
            if frame and frame.BrowseOrders and frame.BrowseOrders.SearchBar then
                local filterDropdown = frame.BrowseOrders.SearchBar.FilterDropdown
                if filterDropdown and filterDropdown.filters then
                    filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
                end
            end
        end

        -- Focus search bar
        if self.db.CraftOrders.FocusSearchBar then
            local frame = ProfessionsCustomerOrdersFrame
            if frame and frame.BrowseOrders and frame.BrowseOrders.SearchBar and frame.BrowseOrders.SearchBar.SearchBox then
                frame.BrowseOrders.SearchBar.SearchBox:SetFocus()
            end
        end
    end)
end

-- Apply Current Expansion filter to Auctionator
function AHF:ApplyAuctionatorFilter()
    if not self.db.Enabled then return end

    -- Check if Auctionator is loaded
    if not C_AddOns.IsAddOnLoaded("Auctionator") then return end
    C_Timer.After(0, function()
        if self.db.Auctionator.CurrentExpansion then
            local frame = _G["AuctionatorShoppingTabItemFrame"]
            if frame and frame.ExpansionContainer and frame.ExpansionContainer.DropDown then
                local dropdown = frame.ExpansionContainer.DropDown
                if dropdown.SetValue then
                    local currentExpansion = GetExpansionLevel and GetExpansionLevel() or LE_EXPANSION_MIDNIGHT or 12
                    dropdown:SetValue(currentExpansion)
                end
            end
        end

        -- Focus search bar
        if self.db.Auctionator.FocusSearchBar then
            local frame = _G["AuctionatorShoppingTabItemFrame"]
            if frame then
                local searchBox = frame.SearchBox or (frame.SearchContainer and frame.SearchContainer.SearchBox)
                if searchBox and searchBox.SetFocus then
                    searchBox:SetFocus()
                end
            end
        end
    end)
end

-- Setup hooks
function AHF:SetupHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    -- Reg events
    self:RegisterEvent("AUCTION_HOUSE_SHOW", "ApplyAuctionHouseFilter")
    self:RegisterEvent("CRAFTINGORDERS_SHOW_CUSTOMER", "ApplyCraftOrdersFilter")
    self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(_, interactionType)
        if interactionType == Enum.PlayerInteractionType.Auctioneer then
            C_Timer.After(0.1, function()
                self:ApplyAuctionatorFilter()
            end)
        end
    end)
end

-- Settings application, called when profile changes
function AHF:ApplySettings()
    if not self.db.Enabled then return end
    self:ApplyAuctionHouseFilter()
    self:ApplyCraftOrdersFilter()
    self:ApplyAuctionatorFilter()
end

-- Module OnEnable
function AHF:OnEnable()
    if not self.db.Enabled then return end
    self:SetupHooks()
end

-- Module OnDisable
function AHF:OnDisable()
    self:UnregisterAllEvents()
    hooksInstalled = false
end
