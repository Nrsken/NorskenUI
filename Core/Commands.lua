---@class NRSKNUI
local NRSKNUI = select(2, ...)

local string_gsub = string.gsub
local ReloadUI = ReloadUI
local canaccessvalue = canaccessvalue
local GetMouseFocus = GetMouseFocus
local GetMouseFoci = GetMouseFoci
local pcall = pcall
local ipairs = ipairs
local type = type
local floor = math.floor
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

    -- /rl instead of /reload shortcut :)
    SLASH_NRSKNUI_RL1 = "/rl"
    SlashCmdList["NRSKNUI_RL"] = function() ReloadUI() end

    -- /fs instead of /fstack shortcut :)
    SLASH_NRSKNUI_FS1 = "/fs"
    SlashCmdList["NRSKNUI_FS"] = function()
        loadAddOn("Blizzard_DebugTools")
        FrameStackTooltip_Toggle()
    end

    local function CanRead(ok, val)
        return ok and (not canaccessvalue or canaccessvalue(val))
    end

    local function MouseFocus()
        if GetMouseFocus then
            return GetMouseFocus()
        end
        local foci = GetMouseFoci and GetMouseFoci()
        return foci and foci[1]
    end

    local function FrameName(f)
        if not f then
            return "nil"
        end
        if f.GetDebugName then
            return f:GetDebugName()
        end
        if f.GetName then
            return f:GetName() or "Anonymous"
        end
        return "Anonymous"
    end

    -- /getpoint, print the anchor of a named frame or the one under the cursor
    SLASH_NRSKNUI_GETPOINT1 = "/getpoint"
    SlashCmdList["NRSKNUI_GETPOINT"] = function(arg)
        arg = string_gsub(arg or "", "%s", "")
        local frame = (arg ~= "" and _G[arg]) or MouseFocus()
        if not frame or not frame.GetPoint then return end
        local point, relativeTo, relativePoint, x, y = frame:GetPoint()
        print("|cffe51039NUI|r", FrameName(frame), point, FrameName(relativeTo), relativePoint, x, y)
    end

    -- /frame, set _G.INSPECTFRAME to a named frame or the one under the cursor
    SLASH_NRSKNUI_FRAME1 = "/frame"
    SlashCmdList["NRSKNUI_FRAME"] = function(arg)
        arg = string_gsub(arg or "", "%s", "")
        local frame = (arg ~= "" and _G[arg]) or MouseFocus()
        if not frame then return end
        _G.INSPECTFRAME = frame
        print("|cffe51039NUI|r _G.INSPECTFRAME set to:", FrameName(frame))
    end

    -- /texlist, list textures on a frame's regions
    SLASH_NRSKNUI_TEXLIST1 = "/texlist"
    SlashCmdList["NRSKNUI_TEXLIST"] = function(arg)
        arg = string_gsub(arg or "", "%s", "")
        local frame = (arg ~= "" and _G[arg]) or _G.INSPECTFRAME
        if not frame or not frame.GetRegions then return end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                print(region:GetTexture(), region:GetName() or region:GetDebugName(), region:GetDrawLayer())
            end
        end
    end

    -- /fontlist, prints the font objects behind a frame's text
    SLASH_NRSKNUI_FONTLIST1 = "/fontlist"
    SlashCmdList["NRSKNUI_FONTLIST"] = function(arg)
        arg = string_gsub(arg or "", "%s", "")
        local frame = (arg ~= "" and _G[arg]) or _G.INSPECTFRAME or MouseFocus()
        if not frame or not frame.GetRegions then
            print("|cffe51039NUI|r no frame, use /frame first, or hover a frame")
            return
        end

        local seenObj, found = {}, 0
        local function Walk(f, depth)
            if depth > 8 then return end
            local okR, regions = pcall(function() return { f:GetRegions() } end)
            if okR then
                for _, r in ipairs(regions) do
                    local okT, isFS = pcall(r.IsObjectType, r, "FontString")
                    if CanRead(okT, isFS) and isFS then
                        local obj = r.GetFontObject and r:GetFontObject()
                        local objName = obj and obj.GetName and obj:GetName() or "(direct SetFont)"
                        local objText = r.GetText and r:GetText() or "(no text)"
                        if not seenObj[objName] then
                            seenObj[objName] = true
                            local okF, _, size, flags = pcall(r.GetFont, r)
                            local sz = (CanRead(okF, size) and type(size) == "number") and floor(size + 0.5) or "?"
                            local fl = (CanRead(okF, flags) and (flags ~= "" and flags or "|cffff0000no outline|r")) or "?"
                            print(objText .. ("  |cffffffff%s|r  %s, |cff00ff00%s|r"):format(objName, sz, fl))
                            found = found + 1
                        end
                    end
                end
            end
            local okC, children = pcall(function() return { f:GetChildren() } end)
            if okC then
                for _, c in ipairs(children) do Walk(c, depth + 1) end
            end
        end

        print("|cffe51039NUI|r fonts in " .. FrameName(frame) .. ":")
        Walk(frame, 0)
        if found == 0 then print("  (none found)") end
    end
end
