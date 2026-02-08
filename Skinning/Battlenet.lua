-- NorskenUI namespace
local _, NRSKNUI = ...

-- Safety check
if not NRSKNUI.Addon then
    error("Battlenet: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local BNET = NRSKNUI.Addon:NewModule("Battlenet", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local ipairs = ipairs
local _G = _G
local UIParent = UIParent
local hooksecurefunc = hooksecurefunc

-- Module locals
local anchorFrame = nil
local isRepositioning = false

-- Frames to skin
local skins = {
    _G.BNToastFrame,
    _G.TimeAlertFrame,
    _G.TicketStatusFrameButton and _G.TicketStatusFrameButton.NineSlice,
}

-- Skin frames
local function SkinFrame(frame)
    if not frame or frame.__NRSKNSkinned then return end

    -- Strip Blizzard textures
    if frame.StripTextures then
        frame:StripTextures(true)
    elseif frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end

    -- NineSlice support
    if frame.NineSlice then
        frame.NineSlice:Hide()
    end

    -- Skin backdrop
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
        })
        frame:SetBackdropColor(0, 0, 0, 0.8)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end
    frame.__NRSKNSkinned = true
end

-- Create anchor frame for BNToastFrame
local function CreateAnchorFrame()
    if anchorFrame then return anchorFrame end

    anchorFrame = CreateFrame("Frame", "NRSKNUI_BNToastAnchor", UIParent)
    anchorFrame:SetSize(300, 50)
    anchorFrame:SetFrameStrata("DIALOG")

    return anchorFrame
end

-- Position the anchor frame from saved variables
local function PositionAnchorFrame()
    if not anchorFrame then return end

    local posDB = BNET.db.Position
    anchorFrame:ClearAllPoints()
    anchorFrame:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)
end

-- Force BNToastFrame to anchor to our custom anchor frame
-- This is called whenever we need to enforce our positioning
local function AttachToastToAnchor()
    if not anchorFrame or not _G.BNToastFrame then return end
    if isRepositioning then return end

    isRepositioning = true

    -- Clear and re-anchor toast to our anchor frame
    _G.BNToastFrame:ClearAllPoints()
    _G.BNToastFrame:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMLEFT", 0, 0)

    -- Update anchor size to match toast dimensions
    local width = _G.BNToastFrame:GetWidth()
    local height = _G.BNToastFrame:GetHeight()
    if width and width > 0 and height and height > 0 then
        anchorFrame:SetSize(width, height)
    end

    isRepositioning = false
end

-- Hook Blizzard's positioning attempts
local function SetupPositionHooks()
    if not _G.BNToastFrame then return end
    hooksecurefunc(_G.BNToastFrame, "SetPoint", function()
        AttachToastToAnchor()
    end)

    -- Also hook OnShow in case Blizzard does positioning there
    _G.BNToastFrame:HookScript("OnShow", function()
        C_Timer.After(0, AttachToastToAnchor)
    end)
end

-- Module init
function BNET:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.Battlenet
    self:SetEnabledState(false)
end

-- Module OnEnable
function BNET:OnEnable()
    if not self.db.Enabled then return end

    -- Skin frames
    for _, frame in ipairs(skins) do
        SkinFrame(frame)
    end
    -- Create and position our custom anchor frame
    CreateAnchorFrame()
    PositionAnchorFrame()
    -- Setup hooks to intercept Blizzard positioning
    SetupPositionHooks()
    -- Initial attachment of toast to our anchor
    AttachToastToAnchor()

    -- Register anchor with EditMode
    local config = {
        key = "BNETModule",
        displayName = "BNet Popup",
        frame = anchorFrame,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            PositionAnchorFrame()
        end,
        getParentFrame = function()
            return UIParent
        end,
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Refresh position (called from GUI)
function BNET:ApplySettings()
    PositionAnchorFrame()
end
