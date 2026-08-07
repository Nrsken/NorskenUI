---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AuctionHouseFilterModule
local AuctionHouseFilter = NRSKNUI:GetModule('AuctionHouseFilter')
function AuctionHouseFilter:UpdateDB() self.db = NRSKNUI.db.profile.Miscellaneous.AuctionHouseFilter end

local C_Timer = C_Timer
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
local auctioneerEnum = Enum and Enum.PlayerInteractionType.Auctioneer

local displayModeHooked = false
function AuctionHouseFilter:ApplyAuctionHouseFilter()
    if not self.db.Enabled then return end
    if not AuctionHouseFrame then return end

    -- Hook needed when using auctionator
    -- Otherwise when you click between blizzard tab and auctionator tab, filter is lost
    if not displayModeHooked and IsAddOnLoaded('Auctionator') then
        displayModeHooked = true
        if AuctionHouseFrame.BrowseResultsFrame then
            AuctionHouseFrame.BrowseResultsFrame:HookScript('OnShow', function()
                C_Timer.After(0.05, function()
                    self:ApplyFilter()
                end)
            end)
        end
    end
    self:ApplyFilter()
end

-- Applies the filter settings to the Auction House frame.
function AuctionHouseFilter:ApplyFilter()
    if not self.db.Enabled then return end

    C_Timer.After(0, function()
        if not AuctionHouseFrame then return end

        if self.db.AuctionHouse.CurrentExpansion then
            local filterButton = AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.FilterButton
            if filterButton and filterButton.filters then
                filterButton.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            end
        end

        if self.db.AuctionHouse.FocusSearchBar then
            local searchBox = AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.SearchBox
            if searchBox then searchBox:SetFocus() end
        end
    end)
end

-- Applies the filter settings to the Craft Orders frame.
function AuctionHouseFilter:ApplyCraftOrdersFilter()
    if not self.db.Enabled then return end

    C_Timer.After(0, function()
        local frame = _G.ProfessionsCustomerOrdersFrame

        if not frame or not frame.BrowseOrders or not frame.BrowseOrders.SearchBar then return end

        if self.db.CraftOrders.CurrentExpansion then
            local filterDropdown = frame.BrowseOrders.SearchBar.FilterDropdown

            if filterDropdown and filterDropdown.filters then
                filterDropdown.filters[Enum.AuctionHouseFilter.CurrentExpansionOnly] = true
            end
        end

        if self.db.CraftOrders.FocusSearchBar then
            local searchBox = frame.BrowseOrders.SearchBar.SearchBox

            if searchBox then searchBox:SetFocus() end
        end
    end)
end

-- Applies auto editbox focus settings to the Auctionator frame.
function AuctionHouseFilter:ApplyAuctionatorFilter()
    if not self.db.Enabled then return end
    if not self.db.Auctionator.FocusSearchBar then return end
    if not IsAddOnLoaded('Auctionator') then return end

    C_Timer.After(0, function()
        local frame = _G['AuctionatorShoppingFrame']
        if not frame then return end

        local searchBox = frame.SearchOptions and frame.SearchOptions.SearchString
        if searchBox and searchBox.SetFocus then
            searchBox:SetFocus()
        end
    end)
end

function AuctionHouseFilter:ApplySettings()
    if not self.db.Enabled then return end

    self:ApplyAuctionHouseFilter()
    self:ApplyCraftOrdersFilter()
    self:ApplyAuctionatorFilter()
end

function AuctionHouseFilter:OnEnable()
    self:RegisterEvent('AUCTION_HOUSE_SHOW', 'ApplyAuctionHouseFilter')
    self:RegisterEvent('CRAFTINGORDERS_SHOW_CUSTOMER', 'ApplyCraftOrdersFilter')
    self:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', function(_, interactionType)
        if interactionType == auctioneerEnum then
            C_Timer.After(0.1, function()
                self:ApplyAuctionatorFilter()
            end)
        end
    end)
end
