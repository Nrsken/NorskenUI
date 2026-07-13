---@class NRSKNUI
local NRSKNUI = select(2, ...)

function NRSKNUI:TestEnv()
    local frame = CreateFrame('Frame', 'NRSKNUI_TestenvFrame', UIParent)
    frame:SetPixelSize(300, 300)
    frame:SetPixelPoint('CENTER', UIParent, 'CENTER', 0, 0)
    frame:Show()
end
