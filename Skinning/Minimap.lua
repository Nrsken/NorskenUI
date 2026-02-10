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
local ipairs = ipairs
local CreateFrame = CreateFrame
local unpack = unpack
local LibStub = LibStub
local _G = _G
local expBtn = ExpansionLandingPageMinimapButton
local mailBtn = MiniMapMailIcon
local qBtn = QueueStatusButton

-- Flags to prevent hook stacking
local hooked = {
    border = false,
    queuePosition = false,
    queueOnShow = false,
    addonCompEnter = false,
    bugSackDisplay = false,
    bugSackButton = nil,
}

-- Module init
function MAP:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.Minimap
    self:SetEnabledState(false)
end

-- Remove Minimap Edit Mode UI since we do position changes in our custom Edit mode
local function DisableMinimapEditMode()
    if not MinimapCluster then return end
    MinimapCluster.SetIsInEditMode = nop
    MinimapCluster.OnEditModeEnter = nop
    MinimapCluster.OnEditModeExit = nop
    MinimapCluster.HasActiveChanges = nop
    MinimapCluster.HighlightSystem = nop
    MinimapCluster.SelectSystem = nop
    MinimapCluster.system = nil
end

-- Module OnEnable
function MAP:OnEnable()
    if not self.db.Enabled then return end

    MAP:StripBlizzMap()
    MAP:ApplyPosSize()
    MAP:UpdateMinimapBorder()
    MAP:UpdateSettings()
    MAP:CreateBugSackButton()

    -- One-time hooks for refresh triggers
    Minimap:HookScript("OnShow", function() C_Timer.After(1, function() MAP:RefreshAll() end) end)
    MinimapCluster:HookScript("OnShow", function() C_Timer.After(1, function() MAP:RefreshAll() end) end)
    MinimapCluster:HookScript("OnEvent", function() C_Timer.After(1, function() MAP:RefreshAll() end) end)
    if not hooked.queuePosition then
        hooksecurefunc(QueueStatusButton, "UpdatePosition", function()
            local queueBtnDB = self.db.QueueStatus
            QueueStatusButton:SetParent(Minimap)
            QueueStatusButton:ClearAllPoints()
            QueueStatusButton:SetPoint(queueBtnDB.Anchor, Minimap, queueBtnDB.Anchor, queueBtnDB.X, queueBtnDB.Y)
            QueueStatusButton:SetFrameLevel(10)
        end)
        hooked.queuePosition = true
    end
    if qBtn and not hooked.queueOnShow then
        qBtn:HookScript("OnShow", function()
            local queueBtnDB = self.db.QueueStatus
            qBtn:SetParent(Minimap)
            qBtn:ClearAllPoints()
            qBtn:SetPoint(queueBtnDB.Anchor, Minimap, queueBtnDB.Anchor, queueBtnDB.X, queueBtnDB.Y)
            qBtn:SetScale(queueBtnDB.Scale)
        end)
        hooked.queueOnShow = true
    end

    C_Timer.After(0.5, DisableMinimapEditMode)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function() C_Timer.After(0.1, function() MAP:RefreshAll() end) end)

    -- Register with custom edit mode
    NRSKNUI.EditMode:RegisterElement({
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
    })
end

-- Strip minimap textures
function MAP:StripBlizzMap()
    Minimap:SetParent(UIParent)
    if not Minimap.Layout then Minimap.Layout = nop end

    -- Reparent elements we still need before hiding the cluster
    MinimapCluster.Tracking:SetParent(Minimap)
    MinimapCluster.IndicatorFrame.MailFrame:SetParent(Minimap)
    MinimapCluster.InstanceDifficulty:SetParent(Minimap)

    Minimap:SetMaskTexture("Interface\\BUTTONS\\WHITE8X8")
    MinimapCompassTexture:SetTexture(nil)

    -- Hide the cluster and its unwanted children
    NRSKNUI:Hide("MinimapCluster")
    NRSKNUI:Hide("MinimapCompassTexture")
    NRSKNUI:Hide("MinimapCluster", "BorderTop")
    NRSKNUI:Hide("MinimapCluster", "ZoneTextButton")
    NRSKNUI:Hide("Minimap", "ZoomIn")
    NRSKNUI:Hide("Minimap", "ZoomOut")
    NRSKNUI:Hide("Minimap", "ZoomHitArea")
    NRSKNUI:Hide("GameTimeFrame")

    -- Reanchor tracking for direct menu access
    MinimapCluster.Tracking:ClearAllPoints()
    MinimapCluster.Tracking.Button:SetMenuAnchor(AnchorUtil.CreateAnchor("TOPRIGHT", Minimap, "BOTTOMLEFT"))

    -- Addon compartment skinning
    MAP:SkinAddonCompartment()
end

-- Skin the AddonCompartmentFrame
function MAP:SkinAddonCompartment()
    if not AddonCompartmentFrame then return end

    if self.db.HideAddOnComp then
        AddonCompartmentFrame:ClearAllPoints()
        AddonCompartmentFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 9999, 9999)
        return
    end

    -- Hide original textures
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
    bg:SetAllPoints(AddonCompartmentFrame)

    -- One-time hover hooks
    if not hooked.addonCompEnter then
        AddonCompartmentFrame:HookScript("OnEnter", function()
            bg:SetBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        end)
        AddonCompartmentFrame:HookScript("OnLeave", function()
            bg:SetBorderColor(0, 0, 0, 1)
        end)
        hooked.addonCompEnter = true
    end

    AddonCompartmentFrame:ClearAllPoints()
    AddonCompartmentFrame:SetSize(20, 20)
    AddonCompartmentFrame:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -2, 2)
    AddonCompartmentFrame:SetFrameLevel(Minimap:GetFrameLevel() + 1)
    AddonCompartmentFrame.Text:SetFont("Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    AddonCompartmentFrame.Text:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    AddonCompartmentFrame.Text:SetShadowColor(0, 0, 0, 0)
    AddonCompartmentFrame.Text:SetShadowOffset(0, 0)
end

-- Apply/Update border to the minimap
function MAP:UpdateMinimapBorder()
    if not hooked.border then
        Minimap.Border = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
        Minimap.Border:SetAllPoints(Minimap)
        Minimap.Border:SetFrameLevel(Minimap:GetFrameLevel() + 1)
        hooked.border = true
    end

    Minimap.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = self.db.Border.Thickness,
    })
    Minimap.Border:SetBackdropBorderColor(unpack(self.db.Border.Color))
end

-- Apply/Update Expansion Button position and visibility
function MAP:UpdateExpansionBtn()
    if not expBtn then return end

    local expBtnDB = self.db.ExpansionButton
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

-- Apply/Update Mail Button position
function MAP:UpdateMailBtn()
    if not mailBtn then return end

    local mailBtnDB = self.db.Mail
    local mailFrame = MinimapCluster.IndicatorFrame.MailFrame
    mailBtn:ClearAllPoints()
    mailBtn:SetPoint("CENTER", mailFrame, "CENTER", 0, 0)
    mailFrame:SetScale(mailBtnDB.Scale)
    mailFrame:ClearAllPoints()
    mailFrame:SetPoint(mailBtnDB.Anchor, Minimap, mailBtnDB.Anchor, mailBtnDB.X, mailBtnDB.Y)
end

-- Apply/Update Instance Difficulty Button position
function MAP:UpdateInstanceBtn()
    local instanceBtnDB = self.db.InstanceDifficulty
    local instanceFrame = MinimapCluster.InstanceDifficulty

    instanceFrame:SetScale(instanceBtnDB.Scale)
    instanceFrame:ClearAllPoints()
    instanceFrame:SetPoint(instanceBtnDB.Anchor, Minimap, instanceBtnDB.Anchor, instanceBtnDB.X, instanceBtnDB.Y)

    -- Center all difficulty sub-frames
    for _, child in ipairs({ instanceFrame.ChallengeMode, instanceFrame.Default, instanceFrame.Guild }) do
        child:ClearAllPoints()
        child:SetPoint("CENTER", instanceFrame, "CENTER", 0, 0)
    end
end

-- Apply/Update Queue Status Button position
function MAP:UpdateQueueBtn()
    if not qBtn then return end

    local queueBtnDB = self.db.QueueStatus
    qBtn:SetParent(Minimap)
    qBtn:ClearAllPoints()
    qBtn:SetPoint(queueBtnDB.Anchor, Minimap, queueBtnDB.Anchor, queueBtnDB.X, queueBtnDB.Y)
    qBtn:SetScale(queueBtnDB.Scale)
end

-- Apply/Update position and size settings
function MAP:ApplyPosSize()
    Minimap:ClearAllPoints()
    Minimap:SetPoint(
        self.db.Position.AnchorFrom, UIParent, self.db.Position.AnchorTo,
        self.db.Position.X, self.db.Position.Y
    )
    Minimap:SetSize(self.db.Size, self.db.Size)

    -- Force minimap redraw
    Minimap:SetZoom(1)
    Minimap:SetZoom(0)
end

-- Create or update BugSack button on Minimap
function MAP:CreateBugSackButton()
    if not self.db.BugSack.Enabled then
        if hooked.bugSackButton then
            hooked.bugSackButton:Hide()
        end
        return
    end

    -- Check dependencies
    if not C_AddOns.IsAddOnLoaded("BugSack") then return end
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not ldb then return end
    local bugSackLDB = ldb:GetDataObjectByName("BugSack")
    if not bugSackLDB then return end
    local bugAddon = _G["BugSack"]
    if not bugAddon or not bugAddon.UpdateDisplay or not bugAddon.GetErrors then return end

    -- Create button once
    if not hooked.bugSackButton then
        local btn = CreateFrame("Button", "NRSKNABugSackButton", Minimap, "BackdropTemplate")
        btn.Text = btn:CreateFontString(nil, "OVERLAY")
        btn.Text:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        btn.Text:SetPoint("CENTER", btn, "CENTER", 1, 0)
        btn.Text:SetTextColor(1, 1, 1)
        btn.Text:SetText("|cFF40FF400|r")

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            tileSize = 0,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        btn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        btn:SetBackdropBorderColor(0, 0, 0, 1)

        btn:SetScript("OnClick", function(self, mouseButton)
            if bugSackLDB.OnClick then
                bugSackLDB.OnClick(self, mouseButton)
            end
        end)

        btn:SetScript("OnEnter", function(self)
            btn:SetBackdropBorderColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
            if bugSackLDB.OnTooltipShow then
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", -2, -1)
                bugSackLDB.OnTooltipShow(GameTooltip)
                GameTooltip:Show()
            end
        end)

        btn:SetScript("OnLeave", function()
            btn:SetBackdropBorderColor(0, 0, 0, 1)
            GameTooltip:Hide()
        end)

        -- One-time hook for error count updates
        hooksecurefunc(bugAddon, "UpdateDisplay", function()
            local count = #bugAddon:GetErrors(BugGrabber:GetSessionId())
            if count == 0 then
                btn.Text:SetText("|cFF40FF40" .. count .. "|r")
            else
                btn.Text:SetText("|cFFFF4040" .. count .. "|r")
            end
        end)

        hooked.bugSackButton = btn
    end

    -- Apply position and size
    local btn = hooked.bugSackButton
    local db = self.db.BugSack
    if btn then
        btn:SetSize(db.Size, db.Size)
        btn:ClearAllPoints()
        btn:SetPoint(db.Anchor, Minimap, db.Anchor, db.X, db.Y)
        btn:Show()
    end
end

-- Apply/Update all dynamic settings
function MAP:UpdateSettings()
    C_Timer.After(0.25, function()
        if not self.db.Enabled then return end
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
