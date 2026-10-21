---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs
local hooksecurefunc = hooksecurefunc
local RunNextFrame = RunNextFrame
local UIParent = UIParent
local PortraitFrameMixin = PortraitFrameMixin

local ADDON_NAME = 'BigWigs'

---@param frame PortraitFrameTemplate|Frame
---@return boolean
local function IsPopup(frame)
    if frame:IsForbidden() then return false end

    local container = frame.TitleContainer
    local title = container and container.TitleText
    return title ~= nil and title:GetText() == ADDON_NAME
end

---@param S SkinningModule
---@param frame PortraitFrameTemplate
local function SkinShell(S, frame)
    S:HandlePortraitFrame(frame)
    S:HandleAccentText(frame.TitleContainer.TitleText)
end

---@param S SkinningModule
---@param frame Frame
local function SkinButtons(S, frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType('Button') then
            S:HandleButton(child --[[@as Button]])
        end
    end
end

Skinning:RegisterSkin(ADDON_NAME, 'BigWigsPopups', function(S)
    -- Warnings raised while the loader runs beat this skin, so sweep for them before hooking.
    for _, child in ipairs({ UIParent:GetChildren() }) do
        if IsPopup(child) then
            SkinShell(S, child --[[@as PortraitFrameTemplate]])
            SkinButtons(S, child)
        end
    end

    -- BigWigs exposes no popup API, so the portrait call its templates share is the way in.
    hooksecurefunc(PortraitFrameMixin, 'SetPortraitTextureRaw', function(frame)
        if not IsPopup(frame) then return end

        SkinShell(S, frame)
        -- The buttons are created after the portrait, so they only exist on the next frame.
        RunNextFrame(function() SkinButtons(S, frame) end)
    end)
end)
