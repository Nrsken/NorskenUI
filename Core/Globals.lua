-- NorskenUI namespace
local addonName, NRSKNUI = ...
_G.NRSKNUI = NRSKNUI

-- Localization
local ReloadUI = ReloadUI
local print = print
local pcall = pcall
local LibStub = LibStub
local string_gsub = string.gsub
local C_AddOns = C_AddOns
local EditModeManagerFrame = EditModeManagerFrame

-- Libraries (with error handling)
local function SafeLibStub(name)
    local success, lib = pcall(LibStub, name)
    return success and lib or nil
end
NRSKNUI.LSM = SafeLibStub("LibSharedMedia-3.0")
NRSKNUI.AG = SafeLibStub("AceGUI-3.0")
NRSKNUI.LDB = SafeLibStub("LibDataBroker-1.1")
NRSKNUI.LDBIcon = SafeLibStub("LibDBIcon-1.0")
NRSKNUI.LDS = SafeLibStub("LibDualSpec-1.0")

-- Standard addon font
NRSKNUI.PATH = ([[Interface\AddOns\%s\Media\]]):format(addonName)
NRSKNUI.FONT = NRSKNUI.PATH .. [[Fonts\]] .. 'Expressway.TTF'
NRSKNUI.SB = NRSKNUI.PATH .. [[Statusbars\]] .. 'NorskenUI.blp'

-- Register font with LSM
if NRSKNUI.LSM then
    NRSKNUI.LSM:Register('font', 'Expressway', NRSKNUI.FONT)
    NRSKNUI.LSM:Register('statusbar', 'NorskenUI', NRSKNUI.SB)
end

-- Helper to get Font Path from Name
function NRSKNUI:GetFontPath(fontName)
    if NRSKNUI.LSM and fontName then
        local path = NRSKNUI.LSM:Fetch("font", fontName)
        if path then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- Helper to get statusbar Path from Name
function NRSKNUI:GetStatusbarPath(barName)
    if NRSKNUI.LSM and barName then
        local path = NRSKNUI.LSM:Fetch("statusbar", barName)
        if path then return path end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

-- Addon information (cached metadata calls)
local function GetAddonMetadata()
    if not C_AddOns then return end
    local name = "NorskenUI"
    NRSKNUI.AddOnName = C_AddOns.GetAddOnMetadata(name, "Title")
    NRSKNUI.Version = C_AddOns.GetAddOnMetadata(name, "Version")
    NRSKNUI.Author = C_AddOns.GetAddOnMetadata(name, "Author")
end
GetAddonMetadata()

-- IsEditModeActive: Check if Edit Mode is currently active
function NRSKNUI:IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame:IsShown()
end

-- Print: Print message to chat with addon prefix
function NRSKNUI:Print(msg)
    print(self:ColorTextByTheme("Norsken") .. "UI:|r " .. msg)
end

-- Setup slash commands
local function SetupSlashCommands()
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
        elseif msg == "lock" then
            if NRSKNUI.EditMode and NRSKNUI.EditMode:IsActive() then
                NRSKNUI.EditMode:Exit()
            end
        end
    end
    NRSKNUI:Print(NRSKNUI:ColorTextByTheme("/nui") .. " to open the configuration window.")

    -- /rl instead of /reload shortcut :)
    SLASH_NRSKNUI_RL1 = "/rl"
    SlashCmdList["NRSKNUI_RL"] = function() ReloadUI() end

    -- /fs instead of /fstack shortcut :)
    SLASH_NRSKNUI_FS1 = "/fs"
    SlashCmdList["NRSKNUI_FS"] = function()
        UIParentLoadAddOn("Blizzard_DebugTools")
        FrameStackTooltip_Toggle()
    end
end

-- Initialization
function NRSKNUI:Init()
    SetupSlashCommands()
end

-- Resolve anchor frame from db settings (SCREEN, UIPARENT, SELECTFRAME)
function NRSKNUI:ResolveAnchorFrame(anchorFrameType, parentFrameName)
    if anchorFrameType == "SCREEN" or anchorFrameType == "UIPARENT" then
        return UIParent
    elseif anchorFrameType == "SELECTFRAME" and parentFrameName then
        local frame = _G[parentFrameName]
        return frame or UIParent
    end
    return UIParent
end

-- Convert font outline value for SetFont API (NONE -> "")
function NRSKNUI:GetFontOutline(outline)
    if not outline or outline == "NONE" or outline == "" then
        return ""
    end
    return outline
end

-- Safely apply font settings to a FontString
function NRSKNUI:ApplyFont(fontString, fontName, fontSize, fontOutline)
    local fontPath = self:GetFontPath(fontName)
    local outline = self:GetFontOutline(fontOutline)
    local success = fontString:SetFont(fontPath, fontSize or 12, outline)
    if not success then
        -- Fallback to default font
        fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 12, outline)
    end
    return success
end

-- Get text justification based on anchor point
function NRSKNUI:GetTextJustifyFromAnchor(anchorPoint)
    if not anchorPoint then return "CENTER" end

    -- Right-side anchors → right-align text
    if anchorPoint == "RIGHT" or anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        return "RIGHT"
    -- Left-side anchors → left-align text
    elseif anchorPoint == "LEFT" or anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
        return "LEFT"
    end
    -- CENTER, TOP, BOTTOM → center text
    return "CENTER"
end

-- Get text point based on anchor
function NRSKNUI:GetTextPointFromAnchor(anchorPoint)
    local justify = self:GetTextJustifyFromAnchor(anchorPoint)
    if justify == "RIGHT" then
        return "RIGHT"
    elseif justify == "LEFT" then
        return "LEFT"
    end
    return "CENTER"
end

-- Preview Manager
local PreviewManager = {}
NRSKNUI.PreviewManager = PreviewManager

-- State tracking
PreviewManager.guiOpen = false
PreviewManager.editModeActive = false
PreviewManager.previewsActive = false

-- Update preview state based on GUI and EditMode
function PreviewManager:UpdatePreviewState()
    local shouldShowPreviews = self.guiOpen or self.editModeActive

    if shouldShowPreviews and not self.previewsActive then
        -- Start previews
        self:StartAllPreviews()
        self.previewsActive = true
    elseif not shouldShowPreviews and self.previewsActive then
        -- Stop previews (only when BOTH are inactive)
        self:StopAllPreviews()
        self.previewsActive = false
    end
end

-- Called when GUI opens/closes
function PreviewManager:SetGUIOpen(open)
    self.guiOpen = open
    self:UpdatePreviewState()
end

-- Called when EditMode activates/deactivates
function PreviewManager:SetEditModeActive(active)
    self.editModeActive = active
    self:UpdatePreviewState()
end

-- Start all module previews
function PreviewManager:StartAllPreviews()
    local Addon = NRSKNUI.Addon
    if not Addon then return end

    -- Missing Buffs
    local MissingBuffs = Addon:GetModule("MissingBuffs", true)
    if MissingBuffs and MissingBuffs.ShowPreview then
        MissingBuffs:ShowPreview()
    end

    -- Combat Cross
    local CombatCross = Addon:GetModule("CombatCross", true)
    if CombatCross and CombatCross.ShowPreview then
        CombatCross:ShowPreview()
    end

    -- Combat Message
    local CombatMessage = Addon:GetModule("CombatMessage", true)
    if CombatMessage and CombatMessage.ShowPreview then
        CombatMessage:ShowPreview()
    end

    -- Combat Res
    local CombatRes = Addon:GetModule("CombatRes", true)
    if CombatRes and CombatRes.ShowPreview then
        CombatRes:ShowPreview()
    end

    -- Combat Timer
    local CombatTimer = Addon:GetModule("CombatTimer", true)
    if CombatTimer and CombatTimer.ShowPreview then
        CombatTimer:ShowPreview()
    end

    -- Cursor Circle
    local CursorCircle = Addon:GetModule("CursorCircle", true)
    if CursorCircle and CursorCircle.ApplySettings then
        CursorCircle:ApplySettings()
    end

    -- Pet Texts
    local PetTexts = Addon:GetModule("PetTexts", true)
    if PetTexts and PetTexts.ShowPreview then
        PetTexts:ShowPreview()
    end

    -- XP Bar
    local XPBar = Addon:GetModule("XPBar", true)
    if XPBar and XPBar.ShowPreview then
        XPBar:ShowPreview()
    end

    -- Durability
    local Durability = Addon:GetModule("Durability", true)
    if Durability and Durability.ShowPreview then
        Durability:ShowPreview()
    end

    -- Dragon Riding
    local DragonRiding = Addon:GetModule("DragonRiding", true)
    if DragonRiding and DragonRiding.ShowPreview then
        DragonRiding:ShowPreview()
    end
end

-- Stop all module previews
function PreviewManager:StopAllPreviews()
    local Addon = NRSKNUI.Addon
    if not Addon then return end

    -- Missing Buffs
    local MissingBuffs = Addon:GetModule("MissingBuffs", true)
    if MissingBuffs and MissingBuffs.HidePreview then
        MissingBuffs:HidePreview()
    end

    -- Combat Cross
    local CombatCross = Addon:GetModule("CombatCross", true)
    if CombatCross and CombatCross.HidePreview then
        CombatCross:HidePreview()
    end

    -- Combat Message
    local CombatMessage = Addon:GetModule("CombatMessage", true)
    if CombatMessage and CombatMessage.HidePreview then
        CombatMessage:HidePreview()
    end

    -- Combat Res
    local CombatRes = Addon:GetModule("CombatRes", true)
    if CombatRes and CombatRes.HidePreview then
        CombatRes:HidePreview()
    end

    -- Combat Timer
    local CombatTimer = Addon:GetModule("CombatTimer", true)
    if CombatTimer and CombatTimer.HidePreview then
        CombatTimer:HidePreview()
    end

    -- Pet Texts
    local PetTexts = Addon:GetModule("PetTexts", true)
    if PetTexts and PetTexts.HidePreview then
        PetTexts:HidePreview()
    end

    -- XP Bar
    local XPBar = Addon:GetModule("XPBar", true)
    if XPBar and XPBar.HidePreview then
        XPBar:HidePreview()
    end

    -- Durability
    local Durability = Addon:GetModule("Durability", true)
    if Durability and Durability.HidePreview then
        Durability:HidePreview()
    end

    -- Dragon Riding
    local DragonRiding = Addon:GetModule("DragonRiding", true)
    if DragonRiding and DragonRiding.HidePreview then
        DragonRiding:HidePreview()
    end
end

-- Check if previews are currently active
function PreviewManager:IsPreviewActive()
    return self.previewsActive
end

