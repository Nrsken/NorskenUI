-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("Automation: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local AUTO = NRSKNUI.Addon:NewModule("Automation", "AceEvent-3.0", "AceHook-3.0")

-- Localization Setup
local pcall = pcall
local CinematicFrame_CancelCinematic = CinematicFrame_CancelCinematic
local RepairAllItems = RepairAllItems
local hooksecurefunc = hooksecurefunc
local select = select
local CanMerchantRepair = CanMerchantRepair
local GetRepairAllCost = GetRepairAllCost
local CanGuildBankRepair = CanGuildBankRepair
local GetMoney = GetMoney
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local CreateFrame = CreateFrame
local C_Container = C_Container
local GameMovieFinished = GameMovieFinished
local LFGListApplicationDialog = LFGListApplicationDialog
local C_Item = C_Item
local LFDRoleCheckPopup = LFDRoleCheckPopup
local LFDRoleCheckPopupAcceptButton = LFDRoleCheckPopupAcceptButton
local StaticPopupDialogs = StaticPopupDialogs
local C_CVar = C_CVar
local _G = _G

-- Module init
function AUTO:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.Automation
    self:SetEnabledState(false)
end

-- Setup cinematic skip
local cinematicFrame = nil
local function SetupSkipCinematics()
    if not AUTO.db.SkipCinematics then return end

    -- Hook cinematic start event
    if not cinematicFrame then
        cinematicFrame = CreateFrame("Frame")
        cinematicFrame:RegisterEvent("CINEMATIC_START")
        cinematicFrame:RegisterEvent("PLAY_MOVIE")
        cinematicFrame:SetScript("OnEvent", function(self, event, movieId)
            if event == "CINEMATIC_START" then
                CinematicFrame_CancelCinematic()
            elseif event == "PLAY_MOVIE" then
                -- Stop the movie via GameMovieFinished
                pcall(GameMovieFinished)
            end
        end)
    end
end

function AUTO:HideTalkingHeadFrame(frame)
    if frame and AUTO.db.HideTalkingHead then
        frame:Hide()
    end
end

function AUTO:HookTalkingHeadPlayCurrent()
    self:SecureHook(_G.TalkingHeadFrame, "PlayCurrent", "HideTalkingHeadFrame")
    self:SecureHook(_G.TalkingHeadFrame, "Reset", "HideTalkingHeadFrame")
end

function AUTO:DisableTalkingHead()
    if _G.TalkingHeadFrame then
        self:HookTalkingHeadPlayCurrent()
    else
        self:SecureHook("TalkingHead_LoadUI", "HookTalkingHeadPlayCurrent")
    end
end

-- Setup talking head hider
local function SetupHideTalkingHead()
    if not AUTO.db.HideTalkingHead then return end
    AUTO:DisableTalkingHead()
end

-- Sell all grey items in bags
local merchantFrame = nil
local function SellJunkItems()
    if not AUTO.db.AutoSellJunk then return end
    for bagID = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bagID) do
            local itemLink = C_Container.GetContainerItemLink(bagID, slot)

            -- Check if item is grey quality
            if itemLink then
                local itemQuality = select(3, C_Item.GetItemInfo(itemLink))
                local itemSellPrice = select(11, C_Item.GetItemInfo(itemLink))

                -- Quality 0 = Poor (grey items)
                if itemQuality == 0 and itemSellPrice and itemSellPrice > 0 then
                    C_Container.UseContainerItem(bagID, slot)
                end
            end
        end
    end
end

-- Setup auto sell grey items and auto repair
local function SetupAutoSellRepair()
    if merchantFrame then return end

    -- Hook merchant show event
    merchantFrame = CreateFrame("Frame")
    merchantFrame:RegisterEvent("MERCHANT_SHOW")
    merchantFrame:SetScript("OnEvent", function(self, event)
        if event ~= "MERCHANT_SHOW" then return end

        -- Auto sell grey items
        if AUTO.db.AutoSellJunk then
            SellJunkItems()
        end

        -- Auto repair
        if AUTO.db.AutoRepair and CanMerchantRepair() then
            local repairCost, canRepair = GetRepairAllCost()
            if repairCost and canRepair and repairCost > 0 then
                local playerMoney = GetMoney()

                -- Try guild funds first if enabled
                if AUTO.db.UseGuildFunds and CanGuildBankRepair() then
                    local guildBankMoney = GetGuildBankWithdrawMoney()
                    if guildBankMoney >= repairCost then
                        RepairAllItems(true) -- true = use guild funds
                        return
                    end
                end

                -- Fall back to personal funds
                if playerMoney >= repairCost then
                    RepairAllItems(false)
                end
            end
        end
    end)
end

-- Auto role on signup
local function SetupAutoRoleCheck()
    if not AUTO.db.AutoRoleCheck then return end
    -- LFG Application dialog
    if LFGListApplicationDialog and not AUTO._lfgHooked then
        AUTO._lfgHooked = true
        LFGListApplicationDialog:HookScript("OnShow", function()
            if LFGListApplicationDialog.SignUpButton then
                LFGListApplicationDialog.SignUpButton:Click()
            end
        end)
    end

    -- LFD Role Check popup
    if LFDRoleCheckPopup and not AUTO._lfdHooked then
        AUTO._lfdHooked = true
        LFDRoleCheckPopup:HookScript("OnShow", function()
            if LFDRoleCheckPopupAcceptButton then
                LFDRoleCheckPopupAcceptButton:Click()
            end
        end)
    end
end

-- Auto fill delete text
local function SetupAutoFillDelete()
    if not AUTO.db.AutoFillDelete then return end
    if AUTO._deleteHooked then return end
    AUTO._deleteHooked = true

    -- Hook directly into the StaticPopupDialogs OnShow function
    hooksecurefunc(StaticPopupDialogs["DELETE_GOOD_ITEM"], "OnShow", function(self)
        if self.EditBox then
            self.EditBox:SetText("DELETE")
        end
    end)
end

-- Setup auto loot CVar
local function ApplyAutoLoot()
    if not AUTO.db.AutoLoot then return end
    local value = AUTO.db.AutoLoot and "1" or "0"
    C_CVar.SetCVar("autoLootDefault", value)
end

-- Apply automation settings
function AUTO:Apply()
    if not self.db.Enabled then return end
    SetupSkipCinematics()
    SetupHideTalkingHead()
    SetupAutoSellRepair()
    SetupAutoRoleCheck()
    SetupAutoFillDelete()
    ApplyAutoLoot()
end

-- Module OnEnable
function AUTO:OnEnable()
    if not self.db.Enabled then return end
    C_Timer.After(1.0, function() -- Wait for frames to be ready
        AUTO:Apply()
    end)
end