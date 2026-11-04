---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL

local ReloadUI = ReloadUI

---@class PromptOptions : KajiPromptOptions

---@param timer number
---@param text string
---@param fontSize number
---@param parentFrame? Frame
---@param xOffset? number
---@param yOffset? number
function NRSKNUI:CreateMessagePopup(timer, text, fontSize, parentFrame, xOffset, yOffset)
    return NRSKNUI.GUI:FlashMessage(text, {
        duration = timer,
        size = fontSize,
        parent = parentFrame,
        x = xOffset,
        y = yOffset,
    })
end

---@param opts PromptOptions
function NRSKNUI:CreatePrompt(opts)
    return NRSKNUI.GUI:Prompt(opts)
end

---@param title string
---@param text string
---@param label? string
function NRSKNUI:CreateCopyDialog(title, text, label)
    return NRSKNUI.GUI:CopyDialog(title, text, label)
end

---@param reason? string
function NRSKNUI:CreateReloadPrompt(reason)
    return NRSKNUI.GUI:Prompt({
        title = L["Reload Required"],
        text = reason or L["Would you like to reload your UI now?"],
        width = 340,
        onAccept = function() ReloadUI() end,
        acceptText = L["Reload Now"],
        cancelText = L["Later"],
    })
end
