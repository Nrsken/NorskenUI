---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

local function BuildTab(page, db)
    local auctionatorLoaded = IsAddOnLoaded("Auctionator")
    page:SetCondition("auctionator", function() return auctionatorLoaded end)
    page:SetEnabled(function() return db.Enabled end)

    -- Card 1: Blizzard Auction House
    local blizzardAHCard = page:Card(L['Blizzard Auction House'], 'all')
    local blizzardCurrExpRow = blizzardAHCard:Row(rowH)
    blizzardCurrExpRow:Checkbox(L['Current Expansion Only'], {
        width = 1,
        value = db.AuctionHouse.CurrentExpansion,
        callback = function(checked)
            db.AuctionHouse.CurrentExpansion = checked
        end
    })

    blizzardAHCard:Separator()

    local blizzardFocusRow = blizzardAHCard:Row(rowHL, 0)
    blizzardFocusRow:Checkbox(L['Auto Focus Search Bar'], {
        width = 1,
        value = db.AuctionHouse.FocusSearchBar,
        callback = function(checked)
            db.AuctionHouse.FocusSearchBar = checked
        end
    })

    local craftOrdersCard = page:Card(L['Crafting Orders'], 'all')
    local craftOrdersCurrExpRow = craftOrdersCard:Row(rowH)
    craftOrdersCurrExpRow:Checkbox(L['Current Expansion Only'], {
        width = 1,
        value = db.CraftOrders.CurrentExpansion,
        callback = function(checked)
            db.CraftOrders.CurrentExpansion = checked
        end
    })

    craftOrdersCard:Separator()

    local craftOrdersFocusRow = craftOrdersCard:Row(rowHL, 0)
    craftOrdersFocusRow:Checkbox(L['Auto Focus Search Bar'], {
        width = 1,
        value = db.CraftOrders.FocusSearchBar,
        callback = function(checked)
            db.CraftOrders.FocusSearchBar = checked
        end
    })

    -- Card 2: Auctionator
    local addonName = L["Auctionator, "]
    local loadedText = L["|cff00FF00Loaded|r"]
    local notLoadedText = L["|cffFF0000Not Loaded|r"]
    local title = auctionatorLoaded and addonName .. loadedText or addonName .. notLoadedText

    local auctionatorCard = page:Card(title, 'all')
    local auctionatorFocusRow = auctionatorCard:Row(rowHL, 0)
    auctionatorFocusRow:Checkbox(L['Auto Focus Search Bar'], {
        width = 1,
        value = db.Auctionator.FocusSearchBar,
        conditions = { 'auctionator' },
        callback = function(checked)
            db.Auctionator.FocusSearchBar = checked
        end
    })
end

GUI:RegisterPage('auctionHouseFilter', {
    mode = 'clean',
    search = {},
    build = function(page)
        local db = NRSKNUI.AuctionHouseFilter.db
        if not db then return end

        BuildTab(page, db)
    end,
})
