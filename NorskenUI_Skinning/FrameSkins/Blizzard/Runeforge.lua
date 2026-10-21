---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc

---@param list NUIRuneforgePowerList
local function SkinPowerList(list)
    if not list.elements then return end

    for i = 1, list:GetNumElementFrames() do
        local button = list.elements[i]
        if button and not button.NUISkinned then
            button.NUISkinned = true

            if button.Border then button.Border:SetAlpha(0) end
            if button.CircleMask then button.CircleMask:Hide() end

            Skinning:HandleIcon(button.Icon, true)
        end
    end
end

Skinning:RegisterSkin('Blizzard_RuneforgeUI', 'Runeforge', function(S)
    local RuneforgeFrame = _G.RuneforgeFrame --[[@as NUIRuneforgeFrame]]
    if not RuneforgeFrame then return end

    -- The runecarving art is the frame, so it keeps its backdrop and only the controls change.
    S:HandleOutlineFont(RuneforgeFrame.Title)
    S:HandleCloseButton(RuneforgeFrame.CloseButton)

    local createFrame = RuneforgeFrame.CreateFrame
    if createFrame then S:HandleButton(createFrame.CraftItemButton) end

    local powerFrame = RuneforgeFrame.CraftingFrame and RuneforgeFrame.CraftingFrame.PowerFrame
    if not powerFrame then return end

    local pageControl = powerFrame.PageControl
    if pageControl then
        S:HandleOutlineFont(pageControl.PageText)
        S:HandleNextPrevButton(pageControl.BackwardButton, 'left')
        S:HandleNextPrevButton(pageControl.ForwardButton, 'right')
    end

    local powerList = powerFrame.PowerList
    if powerList then
        SkinPowerList(powerList)
        hooksecurefunc(powerList, 'RefreshListDisplay', SkinPowerList)
    end
end)
