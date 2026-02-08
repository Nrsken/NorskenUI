-- NorskenUI namespace
local _, NRSKNUI = ...

-- Credit to unhalted for the idea of this module

-- Check for addon object
if not NRSKNUI.Addon then
    error("DetailsBackdrop: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local DBG = NRSKNUI.Addon:NewModule("DetailsBackdrop", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local unpack = unpack
local pairs = pairs
local _G = _G
local C_AddOns = C_AddOns

-- Module locals
local backdropOneInitialized = false
local backdropTwoInitialized = false
local DetailsBase1 = _G["DetailsBaseFrame1"]
local DetailsWindow1 = _G["Details_WindowFrame1"]
local DetailsBase2 = _G["DetailsBaseFrame2"]
local DetailsWindow2 = _G["Details_WindowFrame2"]

-- Module init
function DBG:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.DetailsBackdrop
    self.backdropOne = nil
    self.bordersOne = {}
    self.backdropTwo = nil
    self.bordersTwo = {}
    self:SetEnabledState(false)
end

-- Module OnEnable
function DBG:OnEnable()
    if not C_AddOns.IsAddOnLoaded("Details") then return end -- Make sure we only enable this module if Details is enabled
    if not self.db.Enabled then return end
    if not backdropOneInitialized then
        DBG:CreateBackdropOne()
    else
        self.backdropOne:Show()
    end

    -- Define the registration config for backdrop one
    if self.backdropOne then
        local config = {
            key = "DetailsBackdropOne",
            displayName = "Details Backdrop: 1",
            frame = self.backdropOne,
            getPosition = function()
                -- When autoSize is ON, we always use BOTTOMRIGHT anchor
                local bgOneDB = self.db.backDropOne
                if bgOneDB.autoSize then
                    return {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = bgOneDB.Position.XOffset,
                        YOffset = bgOneDB.Position.YOffset,
                    }
                end
                return bgOneDB.Position
            end,
            setPosition = function(pos)
                local bgOneDB = self.db.backDropOne
                -- Only save X/Y offset - autoSize mode ignores anchor changes
                bgOneDB.Position.XOffset = pos.XOffset
                bgOneDB.Position.YOffset = pos.YOffset
                if not bgOneDB.autoSize then
                    bgOneDB.Position.AnchorFrom = pos.AnchorFrom
                    bgOneDB.Position.AnchorTo = pos.AnchorTo
                end
                -- Call update function to properly handle autoSize mode
                DBG:UpdateDetailsBackdropOne()
            end,
            getParentFrame = function()
                -- autoSize always anchors to UIParent
                return UIParent
            end,
            guiPath = "DetailsBackdrop",
            guiContext = "bgOne", -- Pass the backdrop key for granular navigation
        }
        NRSKNUI.EditMode:RegisterElement(config)
    end

    if not backdropTwoInitialized then
        DBG:CreateBackdropTwo()
    else
        self.backdropTwo:Show()
    end

    -- Define the registration config for backdrop two
    if self.backdropTwo then
        local config = {
            key = "DetailsBackdropTwo",
            displayName = "Details Backdrop: 2",
            frame = self.backdropTwo,
            getPosition = function()
                -- When autoSize is ON, we always use BOTTOMRIGHT anchor
                local bgTwoDB = self.db.backDropTwo
                if bgTwoDB.autoSize then
                    return {
                        AnchorFrom = "BOTTOMRIGHT",
                        AnchorTo = "BOTTOMRIGHT",
                        XOffset = bgTwoDB.Position.XOffset,
                        YOffset = bgTwoDB.Position.YOffset,
                    }
                end
                return bgTwoDB.Position
            end,
            setPosition = function(pos)
                local bgTwoDB = self.db.backDropTwo
                -- Only save X/Y offset - autoSize mode ignores anchor changes
                bgTwoDB.Position.XOffset = pos.XOffset
                bgTwoDB.Position.YOffset = pos.YOffset
                if not bgTwoDB.autoSize then
                    bgTwoDB.Position.AnchorFrom = pos.AnchorFrom
                    bgTwoDB.Position.AnchorTo = pos.AnchorTo
                end
                -- Call update function to properly handle autoSize mode
                DBG:UpdateDetailsBackdropTwo()
            end,
            getParentFrame = function()
                -- autoSize always anchors to UIParent
                return UIParent
            end,
            guiPath = "DetailsBackdrop",
            guiContext = "bgTwo", -- Pass the backdrop key for granular navigation
        }
        NRSKNUI.EditMode:RegisterElement(config)
    end
end

-- Create backdrop One
function DBG:CreateBackdropOne()
    if not self.db.Enabled then return end
    if not self.db.backDropOne.Enabled then return end
    if backdropOneInitialized then return end
    local bgOneDB = self.db.backDropOne

    -- Refresh Details frame references
    DetailsBase1 = _G["DetailsBaseFrame1"]
    DetailsWindow1 = _G["Details_WindowFrame1"]

    local backdrop = CreateFrame("Frame", "DetailsBgOne", UIParent, "BackdropTemplate")
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    backdrop:SetBackdropColor(unpack(bgOneDB.BackgroundColor))

    -- Create border container
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)

    -- Create top border
    local borderTop = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(unpack(bgOneDB.BorderColor))
    borderTop:SetTexelSnappingBias(0)
    borderTop:SetSnapToPixelGrid(false)

    -- Create bottom border
    local borderBottom = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(unpack(bgOneDB.BorderColor))
    borderBottom:SetTexelSnappingBias(0)
    borderBottom:SetSnapToPixelGrid(false)

    -- Create left border
    local borderLeft = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(unpack(bgOneDB.BorderColor))
    borderLeft:SetTexelSnappingBias(0)
    borderLeft:SetSnapToPixelGrid(false)

    -- Create right border
    local borderRight = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(unpack(bgOneDB.BorderColor))
    borderRight:SetTexelSnappingBias(0)
    borderRight:SetSnapToPixelGrid(false)

    -- Update Details stuff
    local detailsBars = bgOneDB.detailsBars or self.db.detailsBars or 7
    if bgOneDB.autoSize and DetailsBase1 and DetailsWindow1 then
        backdrop:SetFrameStrata("LOW")
        DetailsBase1:ClearAllPoints()
        DetailsWindow1:ClearAllPoints()

        local detailHeight = self.db.detailsTitelH + (self.db.detailsBarH * detailsBars) +
            (self.db.detailsSpacing * detailsBars) + 2
        backdrop:SetWidth(self.db.detailsWidth)
        backdrop:SetHeight(detailHeight)

        backdrop:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
            bgOneDB.Position.XOffset, bgOneDB.Position.YOffset)

        DetailsBase1:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - self.db.detailsTitelH)
        DetailsWindow1:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - self.db.detailsTitelH)
        DetailsBase1:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
        DetailsWindow1:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
    else
        backdrop:SetWidth(bgOneDB.width)
        backdrop:SetHeight(bgOneDB.height)
        backdrop:SetFrameStrata(bgOneDB.Strata)
        backdrop:SetPoint(bgOneDB.Position.AnchorFrom, UIParent, bgOneDB.Position.AnchorTo,
            bgOneDB.Position.XOffset, bgOneDB.Position.YOffset)
    end

    -- Store references
    self.backdropOne = backdrop
    self.bordersOne = {
        top = borderTop,
        bottom = borderBottom,
        left = borderLeft,
        right = borderRight
    }
    backdropOneInitialized = true
end

function DBG:UpdateDetailsBackdropOne()
    if not self.backdropOne then return end
    local bgOneDB = self.db.backDropOne

    -- Refresh Details frame references
    DetailsBase1 = _G["DetailsBaseFrame1"]
    DetailsWindow1 = _G["Details_WindowFrame1"]

    -- Update Details stuff
    local detailsBars = bgOneDB.detailsBars or self.db.detailsBars or 7
    if bgOneDB.autoSize and DetailsBase1 and DetailsWindow1 then
        DetailsBase1:ClearAllPoints()
        DetailsWindow1:ClearAllPoints()
        self.backdropOne:ClearAllPoints()

        local detailHeight = self.db.detailsTitelH + (self.db.detailsBarH * detailsBars) +
            (self.db.detailsSpacing * detailsBars) + 2
        self.backdropOne:SetWidth(self.db.detailsWidth)
        self.backdropOne:SetHeight(detailHeight)

        self.backdropOne:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
            bgOneDB.Position.XOffset, bgOneDB.Position.YOffset)
        self.backdropOne:SetFrameStrata("LOW")

        DetailsBase1:SetSize(self.backdropOne:GetWidth() - 2, self.backdropOne:GetHeight() - self.db.detailsTitelH)
        DetailsWindow1:SetSize(self.backdropOne:GetWidth() - 2, self.backdropOne:GetHeight() - self.db.detailsTitelH)
        DetailsBase1:SetPoint("BOTTOMRIGHT", self.backdropOne, "BOTTOMRIGHT", -1, -1)
        DetailsWindow1:SetPoint("BOTTOMRIGHT", self.backdropOne, "BOTTOMRIGHT", -1, -1)
    elseif not bgOneDB.autoSize then
        self.backdropOne:ClearAllPoints()
        self.backdropOne:SetWidth(bgOneDB.width)
        self.backdropOne:SetHeight(bgOneDB.height)
        self.backdropOne:SetFrameStrata(bgOneDB.Strata)
        self.backdropOne:SetPoint(bgOneDB.Position.AnchorFrom, UIParent, bgOneDB.Position.AnchorTo,
            bgOneDB.Position.XOffset, bgOneDB.Position.YOffset)
    end

    -- Update background color
    self.backdropOne:SetBackdropColor(unpack(bgOneDB.BackgroundColor))
    -- Update border colors
    for _, borderOne in pairs(self.bordersOne) do
        borderOne:SetColorTexture(unpack(bgOneDB.BorderColor))
    end
end

-- Create backdrop Two
function DBG:CreateBackdropTwo()
    if not self.db.Enabled then return end
    if not self.db.backDropTwo.Enabled then return end
    if backdropTwoInitialized then return end
    local bgTwoDB = self.db.backDropTwo

    -- Refresh Details frame references
    DetailsBase2 = _G["DetailsBaseFrame2"]
    DetailsWindow2 = _G["Details_WindowFrame2"]

    local backdrop = CreateFrame("Frame", "DetailsBgTwo", UIParent, "BackdropTemplate")
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    backdrop:SetBackdropColor(unpack(bgTwoDB.BackgroundColor))

    -- Create border container
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)

    -- Create top border
    local borderTop = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(unpack(bgTwoDB.BorderColor))
    borderTop:SetTexelSnappingBias(0)
    borderTop:SetSnapToPixelGrid(false)

    -- Create bottom border
    local borderBottom = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(unpack(bgTwoDB.BorderColor))
    borderBottom:SetTexelSnappingBias(0)
    borderBottom:SetSnapToPixelGrid(false)

    -- Create left border
    local borderLeft = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(unpack(bgTwoDB.BorderColor))
    borderLeft:SetTexelSnappingBias(0)
    borderLeft:SetSnapToPixelGrid(false)

    -- Create right border
    local borderRight = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(unpack(bgTwoDB.BorderColor))
    borderRight:SetTexelSnappingBias(0)
    borderRight:SetSnapToPixelGrid(false)

    -- Update Details stuff
    local detailsBars = bgTwoDB.detailsBars or self.db.detailsBars or 7
    if bgTwoDB.autoSize and DetailsBase2 and DetailsWindow2 then
        backdrop:SetFrameStrata("LOW")
        DetailsBase2:ClearAllPoints()
        DetailsWindow2:ClearAllPoints()

        local detailHeight = self.db.detailsTitelH + (self.db.detailsBarH * detailsBars) +
            (self.db.detailsSpacing * detailsBars) + 2
        backdrop:SetWidth(self.db.detailsWidth)
        backdrop:SetHeight(detailHeight)

        backdrop:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
            bgTwoDB.Position.XOffset, bgTwoDB.Position.YOffset)

        DetailsBase2:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - self.db.detailsTitelH)
        DetailsWindow2:SetSize(backdrop:GetWidth() - 2, backdrop:GetHeight() - self.db.detailsTitelH)
        DetailsBase2:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
        DetailsWindow2:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", -1, -1)
    else
        backdrop:ClearAllPoints()
        backdrop:SetWidth(bgTwoDB.width)
        backdrop:SetHeight(bgTwoDB.height)
        backdrop:SetFrameStrata(bgTwoDB.Strata)
        backdrop:SetPoint(bgTwoDB.Position.AnchorFrom, UIParent, bgTwoDB.Position.AnchorTo,
            bgTwoDB.Position.XOffset, bgTwoDB.Position.YOffset)
    end

    -- Store references
    self.backdropTwo = backdrop
    self.bordersTwo = {
        top = borderTop,
        bottom = borderBottom,
        left = borderLeft,
        right = borderRight
    }
    backdropTwoInitialized = true
end

function DBG:UpdateDetailsBackdropTwo()
    if not self.backdropTwo then return end
    local bgTwoDB = self.db.backDropTwo

    -- Refresh Details frame references
    DetailsBase2 = _G["DetailsBaseFrame2"]
    DetailsWindow2 = _G["Details_WindowFrame2"]

    -- Update Details stuff
    local detailsBars = bgTwoDB.detailsBars or self.db.detailsBars or 7
    if bgTwoDB.autoSize and DetailsBase2 and DetailsWindow2 then
        self.backdropTwo:SetFrameStrata("LOW")
        self.backdropTwo:ClearAllPoints()
        DetailsBase2:ClearAllPoints()
        DetailsWindow2:ClearAllPoints()

        local detailHeight = self.db.detailsTitelH + (self.db.detailsBarH * detailsBars) +
            (self.db.detailsSpacing * detailsBars) + 2
        self.backdropTwo:SetWidth(self.db.detailsWidth)
        self.backdropTwo:SetHeight(detailHeight)
        self.backdropTwo:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
            bgTwoDB.Position.XOffset, bgTwoDB.Position.YOffset)

        DetailsBase2:SetSize(self.backdropTwo:GetWidth() - 2, self.backdropTwo:GetHeight() - self.db.detailsTitelH)
        DetailsWindow2:SetSize(self.backdropTwo:GetWidth() - 2, self.backdropTwo:GetHeight() - self.db.detailsTitelH)
        DetailsBase2:SetPoint("BOTTOMRIGHT", self.backdropTwo, "BOTTOMRIGHT", -1, -1)
        DetailsWindow2:SetPoint("BOTTOMRIGHT", self.backdropTwo, "BOTTOMRIGHT", -1, -1)
    elseif not bgTwoDB.autoSize then
        self.backdropTwo:ClearAllPoints()
        self.backdropTwo:SetWidth(bgTwoDB.width)
        self.backdropTwo:SetHeight(bgTwoDB.height)
        self.backdropTwo:SetFrameStrata(bgTwoDB.Strata)
        self.backdropTwo:SetPoint(bgTwoDB.Position.AnchorFrom, UIParent, bgTwoDB.Position.AnchorTo,
            bgTwoDB.Position.XOffset, bgTwoDB.Position.YOffset)
    end

    -- Update background color
    self.backdropTwo:SetBackdropColor(unpack(bgTwoDB.BackgroundColor))
    -- Update border colors
    for _, borderTwo in pairs(self.bordersTwo) do
        borderTwo:SetColorTexture(unpack(bgTwoDB.BorderColor))
    end
end

-- Module OnDisable
function DBG:OnDisable()
    if self.backdropOne then
        self.backdropOne:Hide()
    end
    if self.backdropTwo then
        self.backdropTwo:Hide()
    end
end
