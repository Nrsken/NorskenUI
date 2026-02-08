-- NorskenUI namespace
local _, NRSKNUI = ...
local Theme = NRSKNUI.Theme

-- Check for addon object
if not NRSKNUI.Addon then
    error("Minimap: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local MAP = NRSKNUI.Addon:NewModule("Minimap", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local unpack = unpack
local LibStub = LibStub
local UnitClass = UnitClass
local _G = _G
local expBtn = ExpansionLandingPageMinimapButton
local mailBtn = MiniMapMailIcon
local qBtn = QueueStatusButton

-- Module init
function MAP:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.Minimap
end

-- Remove Minimap Edit Mode UI since we do position changes in our my custom Edit mode
local function DisableMinimapEditMode()
    if MinimapCluster then
        MinimapCluster.SetIsInEditMode = nop
        MinimapCluster.OnEditModeEnter = nop
        MinimapCluster.OnEditModeExit = nop
        MinimapCluster.HasActiveChanges = nop
        MinimapCluster.HighlightSystem = nop
        MinimapCluster.SelectSystem = nop
        -- Unregister from Edit Mode system
        MinimapCluster.system = nil
    end
end

-- Module OnEnable
function MAP:OnEnable()
    if not self.db.Enabled then return end
    MAP:StripBlizzMap()
    MAP:ApplyPosSize()
    MAP:UpdateMinimapBorder()
    MAP:UpdateSettings()
    MAP:CreateBugSackButton()

    Minimap:HookScript("OnShow", function()
        C_Timer.After(1, function()
            MAP:RefreshAll()
        end)
    end)
    MinimapCluster:HookScript("OnShow", function()
        C_Timer.After(1, function()
            MAP:RefreshAll()
        end)
    end)

    MinimapCluster:HookScript("OnEvent", function()
        C_Timer.After(1, function()
            MAP:RefreshAll()
        end)
    end)

    C_Timer.After(0.5, function()
        DisableMinimapEditMode()
    end)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.1, function()
            MAP:RefreshAll()
        end)
    end)

    -- Register with my custom edit mode
    local config = {
        key = "Minimap",
        displayName = "Minimap",
        frame = Minimap,
        getPosition = function()
            local pos = self.db.Position
            return {
                AnchorFrom = pos.AnchorFrom,
                AnchorTo = pos.AnchorTo,
                XOffset = pos.X,
                YOffset = pos.Y,
            }
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.X = pos.XOffset
            self.db.Position.Y = pos.YOffset

            Minimap:ClearAllPoints()
            Minimap:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
        end,
        guiPath = "Minimap",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Strip minimap textures
function MAP:StripBlizzMap()
    if not self.db.Enabled then return end
    Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
    MinimapCompassTexture:SetTexture(nil)
    -- Minimap Elements to strip
    local MinimapElements = {
        MinimapCluster.BorderTop,
        MinimapCluster.Tracking,
        MinimapCluster.ZoneTextButton,
        TimeManagerClockButton,
        GameTimeFrame,
        Minimap.ZoomIn,
        Minimap.ZoomOut,
        MinimapZoneText,
    }

    -- Go through all tracked elements and hide them
    for _, element in pairs(MinimapElements) do
        element:Hide()
        element:SetAlpha(0)
    end

    -- Doing anything with this one seems buggy, makes game not clickable if you exit tradingpost for example
    if AddonCompartmentFrame then
        if self.db.HideAddOnComp then
            AddonCompartmentFrame:ClearAllPoints()
            AddonCompartmentFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 9999, 9999)
        else
            -- Hide the original textures
            for _, region in ipairs({ AddonCompartmentFrame:GetRegions() }) do
                if region:GetObjectType() == "Texture" then
                    local layer = region:GetDrawLayer()
                    if layer == "ARTWORK" or layer == "HIGHLIGHT" then
                        region:Hide()
                        region:SetAlpha(0)
                    end
                end
            end
            local bg = NRSKNUI:CreateStandardBackdrop(
                AddonCompartmentFrame,
                "AddonCompartmentFrame_BG",
                AddonCompartmentFrame:GetFrameLevel() - 1,
                NRSKNUI.Media.Background,
                NRSKNUI.Media.Border
            )
            AddonCompartmentFrame:HookScript("OnEnter", function()
                bg:SetBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            end)

            AddonCompartmentFrame:HookScript("OnLeave", function()
                bg:SetBorderColor(0, 0, 0, 1)
            end)
            AddonCompartmentFrame:ClearAllPoints()
            AddonCompartmentFrame:SetSize(20, 20)
            AddonCompartmentFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)
            AddonCompartmentFrame:SetFrameLevel(Minimap:GetFrameLevel() + 1)
            AddonCompartmentFrame.Text:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
            AddonCompartmentFrame.Text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            AddonCompartmentFrame.Text:SetShadowColor(0, 0, 0, 0)
            AddonCompartmentFrame.Text:SetShadowOffset(0, 0)
            bg:SetAllPoints(AddonCompartmentFrame)
        end
    end
end

-- Apply/Update border to the minimap
local borderExist = false
function MAP:UpdateMinimapBorder()
    if not self.db.Enabled then return end
    if not borderExist then
        Minimap.Border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
        Minimap.Border:SetAllPoints(Minimap)
        Minimap.Border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = self.db.Border.Thickness,
        })
        Minimap.Border:SetBackdropBorderColor(unpack(self.db.Border.Color))
        Minimap.Border:SetFrameLevel(Minimap:GetFrameLevel() + 1)
        borderExist = true
    else
        Minimap.Border:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = self.db.Border.Thickness,
        })
        Minimap.Border:SetBackdropBorderColor(unpack(self.db.Border.Color))
    end
end

-- Apply/Update Expansion Button Skinning
function MAP:UpdateExpansionBtn()
    if not self.db.Enabled then return end
    local expBtnDB = self.db.ExpansionButton
    if expBtn then
        expBtn:ClearAllPoints()
        expBtn:SetPoint(expBtnDB.Anchor, Minimap, expBtnDB.Anchor, expBtnDB.X, expBtnDB.Y)
        expBtn:SetScale(expBtnDB.Scale)
        if expBtnDB.Hide then
            expBtn:Hide()
            expBtn:SetAlpha(0)
        else
            expBtn:Show()
            expBtn:SetAlpha(1)
        end
    end
    hooksecurefunc(QueueStatusButton, 'UpdatePosition', function()
        QueueStatusButton:SetParent(UIParent)
        QueueStatusButton:ClearAllPoints()
        QueueStatusButton:SetPoint('TOPRIGHT', Minimap, -10, -10)
        QueueStatusButton:SetFrameLevel(10)
    end)
end

-- Apply/Update Mail Button Skinning
function MAP:UpdateMailBtn()
    if not self.db.Enabled then return end
    local mailBtnDB = self.db.Mail
    if mailBtn then
        local mailFrame = MinimapCluster.IndicatorFrame.MailFrame
        mailBtn:ClearAllPoints()
        mailBtn:SetPoint("CENTER", mailFrame, "CENTER", 0, 0)
        mailFrame:SetScale(mailBtnDB.Scale)
        mailFrame:ClearAllPoints()
        mailFrame:SetPoint(mailBtnDB.Anchor, Minimap, mailBtnDB.Anchor, mailBtnDB.X, mailBtnDB.Y)
    end
end

-- Apply/Update Instance Difficulty Button Skinning
function MAP:UpdateInstanceBtn()
    if not self.db.Enabled then return end
    local instanceBtnDB = self.db.InstanceDifficulty
    local instanceFrame = MinimapCluster.InstanceDifficulty
    instanceFrame:SetScale(instanceBtnDB.Scale)
    instanceFrame:ClearAllPoints()
    instanceFrame:SetPoint(instanceBtnDB.Anchor, Minimap, instanceBtnDB.Anchor, instanceBtnDB.X, instanceBtnDB.Y)
    instanceFrame.ChallengeMode:ClearAllPoints()
    instanceFrame.ChallengeMode:SetPoint("CENTER", instanceFrame, "CENTER", 0, 0)
    instanceFrame.Default:ClearAllPoints()
    instanceFrame.Default:SetPoint("CENTER", instanceFrame, "CENTER", 0, 0)
    instanceFrame.Guild:ClearAllPoints()
    instanceFrame.Guild:SetPoint("CENTER", instanceFrame, "CENTER", 0, 0)
end

-- Apply/Update Queue Status Button Skinning
function MAP:UpdateQueueBtn()
    if not self.db.Enabled then return end
    local queueBtnDB = self.db.QueueStatus
    if qBtn then
        qBtn:SetParent(Minimap)
        qBtn:ClearAllPoints()
        qBtn:SetPoint(queueBtnDB.Anchor, Minimap, queueBtnDB.Anchor, queueBtnDB.X, queueBtnDB.Y)
        qBtn:SetScale(queueBtnDB.Scale)
        qBtn:HookScript("OnShow", function()
            qBtn:SetParent(Minimap)
            qBtn:ClearAllPoints()
            qBtn:SetPoint(queueBtnDB.Anchor, Minimap, queueBtnDB.Anchor, queueBtnDB.X, queueBtnDB.Y)
            qBtn:SetScale(queueBtnDB.Scale)
        end)
    end
end

-- Apply/Update position and size settings
function MAP:ApplyPosSize()
    Minimap:ClearAllPoints()
    Minimap:SetPoint(self.db.Position.AnchorFrom, UIParent, self.db.Position.AnchorTo, self.db.Position.X,
        self.db.Position.Y)
    Minimap:SetSize(self.db.Size, self.db.Size)
    Minimap:SetZoom(1)
    Minimap:SetZoom(0)
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
    MinimapCluster:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
end

-- BugSack Button skinning, based on unhalted's old implementation for FragUI
-- Create or update BugSack button on Minimap
local bugSackButton = nil
function MAP:CreateBugSackButton()
    if not self.db.BugSack.Enabled then
        if bugSackButton then
            bugSackButton:Hide()
        end
        return
    end
    -- Check if BugSack is loaded
    if not C_AddOns.IsAddOnLoaded("BugSack") then return end
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not ldb then return end
    local bugSackLDB = ldb:GetDataObjectByName("BugSack")
    if not bugSackLDB then return end
    local bugAddon = _G["BugSack"]
    if not bugAddon or not bugAddon.UpdateDisplay or not bugAddon.GetErrors then return end
    -- Get player class color
    local _, playerClass = UnitClass("player")
    local classColor = RAID_CLASS_COLORS[playerClass]

    -- Create button if it doesn't exist
    if not bugSackButton then
        bugSackButton = CreateFrame("Button", "NRSKNABugSackButton", Minimap, "BackdropTemplate")
        bugSackButton.Text = bugSackButton:CreateFontString(nil, "OVERLAY")
        bugSackButton.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        bugSackButton.Text:SetPoint("CENTER", bugSackButton, "CENTER", 1, 0)
        bugSackButton.Text:SetTextColor(1, 1, 1)
        bugSackButton.Text:SetText("|cFF40FF400|r")
        bugSackButton:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        bugSackButton:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        bugSackButton:SetBackdropBorderColor(0, 0, 0, 1)
        bugSackButton:SetScript("OnClick", function(self, mouseButton)
            if bugSackLDB.OnClick then
                bugSackLDB.OnClick(self, mouseButton)
            end
        end)
        bugSackButton:SetScript("OnEnter", function(self)
            if bugSackLDB.OnTooltipShow then
                bugSackButton:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -2, -1)
                bugSackLDB.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            end
        end)
        bugSackButton:SetScript("OnLeave", function()
            bugSackButton:SetBackdropBorderColor(0, 0, 0, 1)
            GameTooltip:Hide()
        end)
        -- Hook BugSack to update error count
        hooksecurefunc(bugAddon, "UpdateDisplay", function()
            local count = #bugAddon:GetErrors(BugGrabber:GetSessionId())
            if count == 0 then
                bugSackButton.Text:SetText("|cFF40FF40" .. count .. "|r")
            else
                bugSackButton.Text:SetText("|cFFFF4040" .. count .. "|r")
            end
        end)
    else
        -- Position and size
        bugSackButton:SetSize(self.db.BugSack.Size, self.db.BugSack.Size)
        bugSackButton:ClearAllPoints()
        bugSackButton:SetPoint(self.db.BugSack.Anchor, Minimap, self.db.BugSack.Anchor, self.db.BugSack.X,
            self.db.BugSack.Y)
        bugSackButton:Show()
        return
    end

    -- Position and size
    bugSackButton:SetSize(self.db.BugSack.Size, self.db.BugSack.Size)
    bugSackButton:ClearAllPoints()
    bugSackButton:SetPoint(self.db.BugSack.Anchor, Minimap, self.db.BugSack.Anchor, self.db.BugSack.X, self.db.BugSack.Y)
    bugSackButton:Show()
end

-- Apply/Update settings
function MAP:UpdateSettings()
    if not self.db.Enabled then return end
    C_Timer.After(0.25, function()
        MAP:UpdateExpansionBtn()
        MAP:UpdateMailBtn()
        MAP:UpdateInstanceBtn()
        MAP:UpdateQueueBtn()
        MAP:CreateBugSackButton()
    end)
end

-- Complete refresh
function MAP:RefreshAll()
    if not self.db.Enabled then return end
    MAP:ApplyPosSize()
    MAP:UpdateMinimapBorder()
    MAP:UpdateSettings()
end

-- Module OnDisable
function MAP:OnDisable()
end
