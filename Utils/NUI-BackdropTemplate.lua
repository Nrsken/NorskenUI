-- NorskenUI Backdrop Utility
local _, NRSKNUI = ...

-- Module used to create backdrops

local CreateFrame = CreateFrame
local unpack = unpack
local pairs = pairs

local WHITE = "Interface\\Buttons\\WHITE8x8"
NRSKNUI.Media = {
    Background = { 0, 0, 0, 0.8 },
    Border     = { 0, 0, 0, 1 },
}

function NRSKNUI:CreateStandardBackdrop(parent, name, frameLevel, bgColor, borderColor)
    local backdrop = CreateFrame("Frame", name, parent, "BackdropTemplate")
    backdrop:SetBackdrop({ bgFile = WHITE })
    backdrop:SetBackdropColor(unpack(bgColor))

    if frameLevel then
        backdrop:SetFrameLevel(frameLevel)
    end

    -- Border container
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameLevel(backdrop:GetFrameLevel() + 1)

    backdrop.Border = borderFrame
    backdrop.Borders = {}

    -- Helper
    local function CreateBorderPoint(point, w, h, ...)
        local tex = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetSize(w, h)
        tex:SetPoint(point, ...)
        tex:SetColorTexture(unpack(borderColor))
        tex:SetTexelSnappingBias(0)
        tex:SetSnapToPixelGrid(false)
        return tex
    end

    -- Create borders
    backdrop.Borders.Top = CreateBorderPoint("TOPLEFT", 0, 1, backdrop, "TOPLEFT", 0, 0)
    backdrop.Borders.Top:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    backdrop.Borders.Bottom = CreateBorderPoint("BOTTOMLEFT", 0, 1, backdrop, "BOTTOMLEFT", 0, 0)
    backdrop.Borders.Bottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    backdrop.Borders.Left = CreateBorderPoint("TOPLEFT", 1, 0, backdrop, "TOPLEFT", 0, 0)
    backdrop.Borders.Left:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    backdrop.Borders.Right = CreateBorderPoint("TOPRIGHT", 1, 0, backdrop, "TOPRIGHT", 0, 0)
    backdrop.Borders.Right:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)

    -- Quality-of-life setters
    function backdrop:SetBackgroundColor(r, g, b, a)
        self:SetBackdropColor(r, g, b, a)
    end
    function backdrop:SetBorderColor(r, g, b, a)
        for _, tex in pairs(self.Borders) do
            tex:SetColorTexture(r, g, b, a or 1)
        end
    end

    return backdrop
end
