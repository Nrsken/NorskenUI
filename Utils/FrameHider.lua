local _, NRSKNUI = ...

-- Module used to hide frames

local CreateFrame = CreateFrame
local type = type
local select = select
local pcall = pcall
local _G = _G

-- hidden dummy frame we anchor stuff we want to hide to
local hidden = CreateFrame('Frame')
hidden:Hide()
function NRSKNUI:Hide(object, ...)
    if type(object) == 'string' then
        object = _G[object]
    end

    if ... then
        -- iterate through arguments, they're children referenced by key
        for index = 1, select('#', ...) do
            object = object[select(index, ...)]
        end
    end

    if object then
        if object.HideBase then
            object:HideBase(true) -- edit mode adds this fallback when it overrides Hide
        else
            object:Hide(true)
        end

        if object.EnableMouse then
            object:EnableMouse(false)
        end

        if object.UnregisterAllEvents then
            object:UnregisterAllEvents()
            object:SetAttribute('statehidden', true) -- useful for hiding secure template based objects
        end

        if object.SetUserPlaced then
            -- useful for hiding blizzard objects that respect user placement
            pcall(object.SetUserPlaced, object, true)
            pcall(object.SetDontSavePosition, object, true)
        end

        object:SetParent(hidden)
    end
end
