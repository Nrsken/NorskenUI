---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local math_rad = math.rad

local CONTROL_BUTTON_SIZE = 22

local PLUS_ATLAS = 'common-button-list-plus'
local MINUS_ATLAS = 'common-icon-minus'
local ARROW_ATLAS = 'CovenantSanctum-Renown-Arrow-Depressed'
local RESET_ATLAS = 'GM-raidMarker-reset'

local CONTROL_BUTTONS = {
    { buttonName = 'zoomInButton',      rotation = 0,   size = 0.5, atlasName = PLUS_ATLAS },
    { buttonName = 'zoomOutButton',     rotation = 0,   size = 0.5, atlasName = MINUS_ATLAS },
    { buttonName = 'rotateLeftButton',  rotation = 0,   size = 0.8, atlasName = ARROW_ATLAS },
    { buttonName = 'rotateRightButton', rotation = 180, size = 0.8, atlasName = ARROW_ATLAS },
    { buttonName = 'resetButton',       rotation = 0,   size = 0.8, atlasName = RESET_ATLAS },
}

-- Runs on every UpdateLayout: the per-button guard stops icons stacking up.
---@param frame Frame
local function StyleControlButtons(frame)
    local lastButton
    for _, v in ipairs(CONTROL_BUTTONS) do
        local button = frame[v.buttonName]
        if button then
            if not button.NUIControlSkinned then
                button.NUIControlSkinned = true
                Skinning:HandleButton(button)
                button:SetSize(CONTROL_BUTTON_SIZE, CONTROL_BUTTON_SIZE)

                local textureSize = CONTROL_BUTTON_SIZE * v.size
                local tex = button:CreateTexture(nil, 'ARTWORK')
                tex:SetPoint('CENTER')
                tex:SetSize(textureSize, textureSize)
                tex:SetAtlas(v.atlasName)
                tex:SetTexelSnappingBias(0)
                tex:SetSnapToPixelGrid(true)
                tex:SetDesaturated(true)

                if v.rotation > 0 then tex:SetRotation(math_rad(v.rotation)) end
                if button.Icon then Skinning:HandleIcon(button.Icon) end
            end

            if button:IsShown() then
                button:ClearAllPoints()

                if lastButton then
                    button:NUISetPixelPoint('LEFT', lastButton, 'RIGHT', 1, 0)
                else
                    button:NUISetPixelPoint('LEFT', 6, 0)
                end

                lastButton = button
            end
        end
    end
end

---@param frame Frame
function Skinning:HandleControlButtons(frame)
    if not frame.NUISkinned then
        frame.NUISkinned = true
        hooksecurefunc(frame, 'UpdateLayout', StyleControlButtons)
    end
end
