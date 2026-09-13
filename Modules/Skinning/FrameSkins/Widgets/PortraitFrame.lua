---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

---Skin a ButtonFrameTemplate/PortraitFrameTemplate window shell
---@param frame Frame
function Skinning:HandlePortraitFrame(frame)
    if not frame or frame.NUISkinned then return end
    frame.NUISkinned = true

    frame:NUIStripTextures('Keyed')

    self:CreatePanelBackdrop(frame)
    if frame.CloseButton then self:HandleCloseButton(frame.CloseButton, frame) end

    return frame
end
