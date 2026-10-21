---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs
local hooksecurefunc = hooksecurefunc

local SLOT_NAMES = {
    'Head', 'Neck',
    'Shoulder', 'Back',
    'Chest', 'Shirt',
    'Tabard', 'Wrist',
    'Hands', 'Waist',
    'Legs', 'Feet',
    'Finger0', 'Finger1',
    'Trinket0', 'Trinket1',
    'MainHand', 'SecondaryHand',
}

local function SkinModelScene(S)
    local scene = CharacterModelScene
    if not scene then return end

    scene:NUIStripTextures()
    local model = InspectModelFrame
    if model then
        model:NUIStripTextures()

        for _, corner in ipairs({ 'TopLeft', 'TopRight', 'BotLeft', 'BotRight' }) do
            local bg = _G['InspectModelFrameBackground' .. corner]
            if bg then bg:SetAlpha(0.2) end
        end
    end
end

-- Skin and re-position the bottom tabs.
local function SkinTabs(S)
    local i = 1
    local tab, prev = _G.InspectFrameTab1, nil
    while tab do
        S:HandleTab(tab, true)

        tab:ClearAllPoints()
        if prev then
            tab:SetPoint('TOPLEFT', prev, 'TOPRIGHT', -1, 0)
        else
            tab:SetPoint('TOPLEFT', _G.InspectFrame, 'BOTTOMLEFT', 0, 1)
        end
        prev = tab

        i = i + 1
        tab = _G['InspectFrameTab' .. i]
    end
end

Skinning:RegisterSkin('Blizzard_InspectUI', 'InspectFrame', function(S)
    if not InspectFrame then return end
    local db = Skinning.db

    S:HandlePortraitFrame(InspectFrame)
    S:HandleButton(_G.InspectPaperDollFrame.ViewButton, 'Transparent')

    SkinModelScene(S)
    SkinTabs(S)

    hooksecurefunc('InspectPaperDollItemSlotButton_Update', function()
        S:HandleButton(_G.InspectPaperDollItemsFrame.InspectTalents)
        _G.InspectPaperDollItemsFrame.InspectTalents:ClearAllPoints()
        _G.InspectPaperDollItemsFrame.InspectTalents:SetPoint('TOPRIGHT', _G.InspectFrame, 'BOTTOMRIGHT', 0, 1)
        _G.InspectPaperDollItemsFrameText:SetFontStyle(db, db.FontTabSize, nil, nil, nil, true)
    end)

    for i = 1, (InspectFrame.numTabs or 5) do
        local tab = _G['InspectFrameTab' .. i]
        if tab then S:HandleTab(tab, true) end
    end

    for _, name in ipairs(SLOT_NAMES) do
        local slot = _G['Inspect' .. name .. 'Slot']
        if slot then S:HandleItemButton(slot) end
    end

    if InspectPaperDollFrame then
        InspectPaperDollFrame:NUIStripTextures()
    end

    if InspectPVPFrame then InspectPVPFrame:NUIStripTextures() end
    if InspectTalentFrame then InspectTalentFrame:NUIStripTextures() end
end)
