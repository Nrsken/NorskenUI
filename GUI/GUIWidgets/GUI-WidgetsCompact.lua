-- NorskenUI namespace
local _, NRSKNUI = ...

function NRSKNUI.GUIFrame:CreateSpacer(parent, height)
    height = height or 16
    local spacer = CreateFrame("Frame", nil, parent)
    spacer:SetHeight(height)
    return spacer
end


