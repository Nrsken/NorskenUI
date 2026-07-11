---@class NRSKNUI
local NRSKNUI = select(2, ...)

local string_gsub = string.gsub
local ReloadUI = ReloadUI

local FrameStackTooltip_Toggle = FrameStackTooltip_Toggle

local loadAddOn = LoadAddOnWithErrorHandling or UIParentLoadAddOn -- UIParentLoadAddOn is renamed to: LoadAddOnWithErrorHandling in 12.1.X+

-- Setup slash commands
function NRSKNUI:SetupSlashCommands()
    SLASH_NRSKNUI1 = "/nui"
    SLASH_NRSKNUI2 = "/norskenui"
    SlashCmdList["NRSKNUI"] = function(msg)
        msg = (msg or ""):lower()
        msg = string_gsub(msg, "^%s+", "")
        msg = string_gsub(msg, "%s+$", "")
        if msg == "" or msg == "gui" then
            if NRSKNUI.GUIFrame then
                NRSKNUI.GUIFrame:Toggle()
            end
        elseif msg == "edit" or msg == "unlock" then
            if NRSKNUI.EditMode then
                NRSKNUI.EditMode:Toggle()
            end
        end
    end

    -- TODO: Add these into gui so user can toggle
    -- /rl instead of /reload shortcut :)
    SLASH_NRSKNUI_RL1 = "/rl"
    SlashCmdList["NRSKNUI_RL"] = function() ReloadUI() end

    -- /fs instead of /fstack shortcut :)
    SLASH_NRSKNUI_FS1 = "/fs"
    SlashCmdList["NRSKNUI_FS"] = function()
        loadAddOn("Blizzard_DebugTools")
        FrameStackTooltip_Toggle()
    end
end
