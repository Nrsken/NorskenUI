---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local ipairs = ipairs
local RunNextFrame = RunNextFrame
local hooksecurefunc = hooksecurefunc

local ADDON_NAME = 'TeleportMenu'

local COLUMNS = {
    { name = 'TeleportMeButtonsFrameLeft',  x = 0, y = -3 },
    { name = 'TeleportMeButtonsFrameRight', x = 0, y = -3 },
}

---@param frame Frame
---@param offsetX number
---@param offsetY number
local function OffsetColumn(frame, offsetX, offsetY)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if not point then return end

    if x == frame.NUIOffsetX and y == frame.NUIOffsetY then return end

    x, y = x + offsetX, y + offsetY
    frame:SetPoint(point, relativeTo, relativePoint, x, y)
    frame.NUIOffsetX, frame.NUIOffsetY = x, y
end

---A column child. Flyout frames sit alongside the buttons and carry no icon.
---@class TeleportMenuButton : Frame
---@field icon Texture?

---@param frame Frame
local function SkinColumn(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        ---@cast child TeleportMenuButton
        local icon = child.icon
        if icon then
            local atlas = icon:GetAtlas()
            if atlas then
                icon:SetAtlas(atlas)
                Skinning:HandleIcon(icon, true, true)
            else
                Skinning:HandleIcon(icon, true)
            end
        end
    end
end

local function SkinTeleportMenu()
    local menu = _G.GameMenuFrame
    if not menu or not menu:IsShown() then return end

    for _, column in ipairs(COLUMNS) do
        local frame = _G[column.name]
        if frame then
            OffsetColumn(frame, column.x, column.y)
            SkinColumn(frame)
        end
    end
end

Skinning:RegisterSkin(ADDON_NAME, 'TeleportMenu', function()
    hooksecurefunc('ToggleGameMenu', function()
        RunNextFrame(function()
            NRSKNUI:RunWhenSafe(SkinTeleportMenu)
        end)
    end)
end)
