---@class NRSKNUI
local NRSKNUI = select(2, ...)

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
        title = "Reload Required",
        text = reason or "Would you like to reload your UI now?",
        width = 340,
        onAccept = function() ReloadUI() end,
        acceptText = "Reload Now",
        cancelText = "Later",
    })
end

---@param modulePath string ProfileManager module path (e.g., "Skinning.BuffTracking")
---@param moduleName string Display name for the module
---@param promptText? string Custom prompt text
function NRSKNUI:CreateResetModulePrompt(modulePath, moduleName, promptText)
    return NRSKNUI.GUI:Prompt({
        title = "Reset Module",
        text = promptText or ("Reset " .. moduleName .. " settings to defaults?"),
        width = 320,
        onAccept = function()
            local success, err = NRSKNUI.ProfileManager:ResetModuleSettings(modulePath, moduleName)
            if success then
                NRSKNUI:CreateReloadPrompt("Settings reset. Reload to apply all changes.")
            else
                NRSKNUI:Print("Reset failed: " .. (err or "unknown error"))
            end
        end,
        acceptText = "Reset",
        cancelText = "Cancel",
    })
end
