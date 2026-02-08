-- NorskenUI namespace
local _, NRSKNUI = ...
local LSM = NRSKNUI.LSM

-- Check for addon object if available
local error = error
if not NRSKNUI.Addon then
    error("CombatMessage: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local TT = NRSKNUI.Addon:NewModule("Tooltips", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc
local issecretvalue = issecretvalue
local pcall = pcall
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitIsConnected = UnitIsConnected
local UnitIsTapDenied = UnitIsTapDenied
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local GetGuildInfo = GetGuildInfo
local UnitRace = UnitRace
local UnitLevel = UnitLevel
local IsInInstance = IsInInstance
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local GetCoinTextureString = GetCoinTextureString
local AddTooltipPostCall = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE
local _G = _G
local TooltipDataType = Enum.TooltipDataType

-- Small fix for ToolTipMoney frame errors
-- Credit to MoneyFrameFix by FootTapper for this snippet
function SetTooltipMoney(frame, money, type, prefixText, suffixText)
    frame:AddLine((prefixText or "") .. "  " .. GetCoinTextureString(money) .. " " .. (suffixText or ""), 0, 1, 1)
end

-- Module State tracking
local isInitialized = false
local hookedTooltips = {}
local tooltipBackdrops = {}
local hookedStatusBars = {}

-- List of common tooltips to skin
local TOOLTIPS_TO_SKIN = {
    "GameTooltip",
    "ItemRefTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "EmbeddedItemTooltip",
    "FriendsTooltip",
    "GameSmallHeaderTooltip",
    "QuickKeybindTooltip",
    "ReputationParagonTooltip",
    "WarCampaignTooltip",
}

-- Spec icon table for spec and class matching
local SPEC_ICONS = {
    -- Death Knight
    ["Blood Death Knight"]     = 135770,
    ["Frost Death Knight"]     = 135773,
    ["Unholy Death Knight"]    = 135775,
    -- Demon Hunter
    ["Havoc Demon Hunter"]     = 1247264,
    ["Vengeance Demon Hunter"] = 1247265,
    ["Devourer Demon Hunter"]  = 7455385,
    -- Druid
    ["Balance Druid"]          = 136096,
    ["Feral Druid"]            = 132115,
    ["Guardian Druid"]         = 132276,
    ["Restoration Druid"]      = 136041,
    -- Evoker
    ["Devastation Evoker"]     = 451165,
    ["Preservation Evoker"]    = 451164,
    ["Augmentation Evoker"]    = 5198700,
    -- Hunter
    ["Beast Mastery Hunter"]   = 461112,
    ["Marksmanship Hunter"]    = 236179,
    ["Survival Hunter"]        = 461113,
    -- Mage
    ["Arcane Mage"]            = 135932,
    ["Fire Mage"]              = 135810,
    ["Frost Mage"]             = 135846,
    -- Monk
    ["Brewmaster Monk"]        = 608951,
    ["Windwalker Monk"]        = 608953,
    ["Mistweaver Monk"]        = 608952,
    -- Paladin
    ["Holy Paladin"]           = 135920,
    ["Protection Paladin"]     = 236264,
    ["Retribution Paladin"]    = 135873,
    -- Priest
    ["Discipline Priest"]      = 135940,
    ["Holy Priest"]            = 135920,
    ["Shadow Priest"]          = 136207,
    -- Rogue
    ["Assassination Rogue"]    = 236270,
    ["Outlaw Rogue"]           = 236286,
    ["Subtlety Rogue"]         = 132320,
    -- Shaman
    ["Elemental Shaman"]       = 136048,
    ["Enhancement Shaman"]     = 136051,
    ["Restoration Shaman"]     = 136052,
    -- Warlock
    ["Affliction Warlock"]     = 136145,
    ["Demonology Warlock"]     = 136172,
    ["Destruction Warlock"]    = 136186,
    -- Warrior
    ["Arms Warrior"]           = 132355,
    ["Fury Warrior"]           = 132347,
    ["Protection Warrior"]     = 132341,
}

-- Some for fun guild logo stuff
local logo = "Interface\\AddOns\\NorskenUI\\Media\\ELp4.tga"
local echoLogo = "|T" .. logo .. ":16:16:0:0:64:64:5:59:7:57|t"
local logoPaja = "Interface\\AddOns\\NorskenUI\\Media\\Pajala_Logo_trans.png"
local PajaLogo = "|T" .. logoPaja .. ":16:16:0:0:64:64:5:59:7:57|t"

-- Module init
function TT:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.Tooltips
    self:SetEnabledState(false)
end

-- Get or create custom backdrop for a tooltip
function TT:GetOrCreateBackdrop(tooltip)
    if tooltipBackdrops[tooltip] then
        return tooltipBackdrops[tooltip]
    end
    -- Create a new backdrop frame
    local backdrop = CreateFrame("Frame", nil, tooltip, "BackdropTemplate")
    backdrop:SetFrameLevel(tooltip:GetFrameLevel() - 1)
    backdrop:SetAllPoints(tooltip)
    tooltipBackdrops[tooltip] = backdrop
    return backdrop
end

-- Update backdrop settings
function TT:UpdateBackdrop(backdrop)
    -- Apply backdrop settings
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = self.db.BorderSize,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    backdrop:SetBackdropColor(self.db.BackgroundColor[1], self.db.BackgroundColor[2], self.db.BackgroundColor[3],
        self.db.BackgroundColor[4] or 0.8)
    backdrop:SetBackdropBorderColor(self.db.BorderColor[1], self.db.BorderColor[2], self.db.BorderColor[3],
        self.db.BorderColor[4] or 1)
end

-- Fetch color info from unit if unit is a player
-- Since Safe/Unsafe unit handling is done in processor
-- pcall might not be needed but kept anyway
function TT:FetchUnitColour(unit)
    local success, _ = pcall(UnitIsPlayer, unit)
    if not success then return end
    if not unit then return 1, 1, 1, 1 end
    if success then
        local online = UnitIsConnected(unit)
        local tapDenied = UnitIsTapDenied(unit)
        local deadOrGhost = UnitIsDeadOrGhost(unit)
        if tapDenied then return 0.5, 0.5, 0.5, 1 end
        if not online then return 0.5, 0.5, 0.5, 1 end
        if deadOrGhost then return 0.5, 0.5, 0.5, 1 end
        local _, class = UnitClass(unit)
        if class then
            local classColor = RAID_CLASS_COLORS[class]
            if classColor then
                return classColor.r, classColor.g, classColor.b, 1
            end
        end
    end
    return 1, 1, 1, 1
end

-- Fetch guild info from unit if unit is a player
-- Since Safe/Unsafe unit handling is done in processor
-- pcall might not be needed but kept anyway
function TT:FetchUnitGuild(unit)
    local success, _ = pcall(UnitIsPlayer, unit)
    if not success then return end
    if not unit then return end
    if success then
        local guildName, guildRank = GetGuildInfo(unit)
        local playerGuildName = GetGuildInfo("player")
        if not guildName then return end
        if guildName == "Echo" then
            guildName = guildName
            guildRank = "|cffe51039" .. guildRank .. "|r"
        elseif guildName == "Pajala Sunrise" then
            guildName = guildName
            guildRank = "|cffffad00" .. guildRank .. "|r"
        elseif guildName == playerGuildName then
            guildName = "|cffe51039" .. guildName .. "|r"
            guildRank = "|cffe51039" .. guildRank .. "|r"
        else
            guildName = "|cff41ff00" .. guildName .. "|r"
            guildRank = "|cff41ff00" .. guildRank .. "|r"
        end
        return guildName, guildRank
    end
end

-- Fetch units level and race type
function TT:FetchUnitLevelRace(unit)
    if not unit then return end
    local race = UnitRace(unit)
    local level = UnitLevel(unit)
    if race then
        race = "|cffFFFFFF" .. race .. "|r"
    end
    local levelOut
    if level then
        levelOut = "|cffffad00" .. level .. "|r"
    end
    return race, levelOut
end

-- Fetch units classname only if its from a player
function TT:FetchUnitClassInfo(unit)
    if not unit then return end
    local unitIsPlayer = UnitIsPlayer(unit)
    if unitIsPlayer then
        local className = UnitClass(unit)
        if not className then return end
        return className
    end
end

-- Check Class and Spec string, match it to correct icon, return it
function TT:fetchUnitSpecInfoMan(text)
    if not text then return text, nil end
    local matchedSpec
    local matchedIcon

    -- Check all keys in SPEC_ICONS
    for specName, icon in pairs(SPEC_ICONS) do
        if text:find(specName) then
            matchedSpec = specName
            matchedIcon = icon
            break
        end
    end

    -- Return the original text for display, plus matched icon if any
    return matchedSpec, matchedIcon
end

-- Hide the default Blizzard NineSlice border
function TT:HideNineSlice(tooltip)
    -- Try to hide NineSlice pieces completely
    if tooltip.NineSlice then
        tooltip.NineSlice:SetAlpha(0)
        tooltip.NineSlice:Hide()
    end

    -- Also try these common backdrop elements
    local elements = {
        "BottomEdge",
        "BottomLeftCorner",
        "BottomRightCorner",
        "Center",
        "LeftEdge",
        "RightEdge",
        "TopEdge",
        "TopLeftCorner",
        "TopRightCorner",
    }

    -- Iterate through elements and hide them
    for _, element in ipairs(elements) do
        if tooltip[element] then
            if tooltip[element].SetAlpha then
                tooltip[element]:SetAlpha(0)
            end
            if tooltip[element].Hide then
                tooltip[element]:Hide()
            end
        end
    end

    -- Also try to clear any backdrop the tooltip itself might have
    if tooltip.SetBackdrop then
        tooltip:SetBackdrop(nil)
    end
    if tooltip.SetBackdropColor then
        tooltip:SetBackdropColor(0, 0, 0, 0)
    end
    if tooltip.SetBackdropBorderColor then
        tooltip:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

-- Permanently hide a status bar by hooking its Show method
function TT:PermanentlyHideStatusBar(statusBar)
    if not statusBar then return end
    if hookedStatusBars[statusBar] then return end
    statusBar:Hide()
    statusBar:SetAlpha(0)
    -- Hook Show to immediately hide it again
    hooksecurefunc(statusBar, "Show", function(self)
        self:Hide()
    end)
    hookedStatusBars[statusBar] = true
end

-- Perma hide health bars for a tooltip
function TT:HideHealthBars(tooltip)
    if not self.db.HideHealthBar then return end

    -- GameTooltip uses GameTooltipStatusBar
    if tooltip.StatusBar then
        TT:PermanentlyHideStatusBar(tooltip.StatusBar)
    end

    -- Also check for the named global
    local statusBarName = tooltip:GetName() and (tooltip:GetName() .. "StatusBar")
    if statusBarName and _G[statusBarName] then
        TT:PermanentlyHideStatusBar(_G[statusBarName])
    end
end

-- Tooltip Styling
function TT:StyleTooltip(tooltip, unit)
    if not self.db.Enabled then return end
    if not tooltip then return end

    -- Hide default NineSlice
    TT:HideNineSlice(tooltip)

    -- Secret-value safety check
    -- If secret value exists and returns true for this tooltip width, skip styling, info source ElvUI
    -- Blizzard_SharedXML/Backdrop.lua: secrets cause backdrop system to crash out
    -- Blizzard_MoneyFrame/Mainline/MoneyFrame.lua: secrets cause `MoneyFrame_Update` to crash out via `GameTooltip:SetLootItem(id)`
    -- Blizzard_SharedXML/Tooltip/TooltipComparisonManager.lua: secrets cause comparison system to crash out.  use `alwaysCompareItems 0`
    local safeToStyle = true
    if issecretvalue then
        if issecretvalue(tooltip:GetWidth()) then
            safeToStyle = false
        end
    end
    if safeToStyle then
        -- Get or create our custom backdrop
        local backdrop = TT:GetOrCreateBackdrop(tooltip)
        -- Update backdrop with current settings
        TT:UpdateBackdrop(backdrop)
        -- Apply unit-based coloring if unit is provided
        if unit then
            local r, g, b, a = TT:FetchUnitColour(unit)
            -- Name line
            local nameLine = _G["GameTooltipTextLeft1"]
            if nameLine then
                nameLine:SetTextColor(r, g, b, a)
            end
        else
            -- Reset name line to white for items/spells
            local nameLine = _G["GameTooltipTextLeft1"]
            if nameLine then
                nameLine:SetTextColor(1, 1, 1, 1)
            end
        end
        -- Show the backdrop
        backdrop:Show()
    end
    -- Permanently hide health bars if enabled
    TT:HideHealthBars(tooltip)
end

-- Helper function to apply coloring
function TT:ColorText(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

-- Add tooltip processor for unit tooltips
local tooltipProcessorRegistered = false
function TT:InitializeTooltipProcessor()
    if tooltipProcessorRegistered then return end
    tooltipProcessorRegistered = true
    AddTooltipPostCall(TooltipDataType.Unit, function(tooltip)
        local db = TT.db
        if not db or not db.Enabled then return end
        local NameFontSize = db.NameFontSize
        local GuildFontSize = db.GuildFontSize
        local RaceLevelFontSize = db.RaceLevelFontSize
        local SpecFontSize = db.SpecFontSize
        local FactionFontSize = db.FactionFontSize
        local fontPath = LSM:Fetch("font", db.Font)
        if not fontPath or fontPath == "" then -- Backup if LSM fails
            fontPath = STANDARD_TEXT_FONT
        end
        local outline = db.FontOutline
        local _, unit = tooltip:GetUnit()
        local success, _ = pcall(UnitIsPlayer, unit)
        local inInstance, instanceType = IsInInstance()

        -- Kinda scuffed way of getting secret/non secret environment, prob better ones exist
        local secretEnv = success and unit ~= "mouseover" and inInstance == true and instanceType ~= "none" and
            instanceType ~= "nil"
        local nonSecretEnv = success and inInstance ~= true

        -- In secretEnv, mouseover on nameplates triggers secret errors, but its fine to check mouseover unit in non secretEnv
        if (secretEnv and not nonSecretEnv) or (not secretEnv and nonSecretEnv) then
            local r, g, b, a = TT:FetchUnitColour(unit)

            -- Name skin
            local className = TT:FetchUnitClassInfo(unit)
            if className then
                local nameLine = _G["GameTooltipTextLeft1"]
                if nameLine then
                    nameLine:SetFont(fontPath, NameFontSize, outline)
                    nameLine:SetTextColor(r, g, b, a)
                    nameLine:SetShadowColor(0, 0, 0, 0)
                end
            end

            -- Guild skin
            local guildName, guildRank = TT:FetchUnitGuild(unit)
            local guildLine = _G["GameTooltipTextLeft2"]
            if guildLine then
                if guildName then
                    if guildName == "Echo" then
                        guildLine:SetFont(fontPath, GuildFontSize, outline)
                        guildLine:SetText(echoLogo ..
                            " <" .. "|cffe51039" .. guildName .. "|r" .. ">" .. " " .. "[" .. guildRank .. "]")
                        guildLine:SetShadowColor(0, 0, 0, 0)
                    elseif guildName == "Pajala Sunrise" then
                        guildLine:SetFont(fontPath, GuildFontSize, outline)
                        guildLine:SetText(PajaLogo ..
                            " <" .. "|cffffad00" .. guildName .. "|r" .. ">" .. " " .. "[" .. guildRank .. "]")
                        guildLine:SetShadowColor(0, 0, 0, 0)
                    else
                        guildLine:SetFont(fontPath, GuildFontSize, outline)
                        guildLine:SetText("<" .. guildName .. "|r" .. ">" .. " " .. "[" .. guildRank .. "]")
                        guildLine:SetShadowColor(0, 0, 0, 0)
                    end
                end
            end

            -- Race and Level skin
            local lineOffset = guildName and 0 or -1
            local race, level = TT:FetchUnitLevelRace(unit)
            local raceLevelLine = _G["GameTooltipTextLeft" .. (3 + lineOffset)]
            if raceLevelLine then
                raceLevelLine:SetFont(fontPath, RaceLevelFontSize, outline)
                raceLevelLine:SetShadowColor(0, 0, 0, 0)
                if race and not level then
                    raceLevelLine:SetText(race)
                end
                if race and level then
                    raceLevelLine:SetText(level .. " " .. race)
                end
                if level and not race then
                    raceLevelLine:SetText(level)
                end
                if not level and not race then return end
            end

            -- Spec and Class skin
            if className then
                local classLine = _G["GameTooltipTextLeft" .. (4 + lineOffset)]
                if classLine then
                    local specText = classLine:GetText()
                    local spec, iconID = TT:fetchUnitSpecInfoMan(specText)
                    classLine:SetFont(fontPath, SpecFontSize, outline)
                    classLine:SetShadowColor(0, 0, 0, 0)
                    -- Build the text based on what's available
                    local text = ""
                    if iconID then
                        local iconExport = "|T" .. iconID .. ":16:16:0:0:64:64:5:59:7:57|t"
                        text = text .. iconExport .. " "
                    end
                    if spec then
                        local specHex = TT:ColorText(spec, r, g, b)
                        text = text .. specHex .. " "
                    end
                    text = text
                    classLine:SetText(text)
                end
            end

            -- Faction Skin
            for i = 2, tooltip:NumLines() do
                local line = _G["GameTooltipTextLeft" .. i]
                if line then
                    local text = line:GetText()
                    if text == FACTION_HORDE then
                        line:SetTextColor(1, 0, 0)
                        line:SetFont(fontPath, FactionFontSize, outline)
                        line:SetShadowColor(0, 0, 0, 0)
                    elseif text == FACTION_ALLIANCE then
                        line:SetTextColor(0, 0.5, 1)
                        line:SetFont(fontPath, FactionFontSize, outline)
                        line:SetShadowColor(0, 0, 0, 0)
                    end
                end
            end
        end
    end)
end

-- Hook a tooltip to apply styling
function TT:HookTooltip(tooltip)
    if not tooltip then return end
    if hookedTooltips[tooltip] then return end
    if not self.db.Enabled then return end
    -- Hook OnShow for backdrop setup
    tooltip:HookScript("OnShow", function(self)
        -- Hide default elements
        TT:HideNineSlice(self)
        TT:HideHealthBars(self)

        -- Setup backdrop
        local backdrop = TT:GetOrCreateBackdrop(self)
        TT:UpdateBackdrop(backdrop)
        backdrop:Show()
    end)

    -- Hook OnHide to hide our backdrop
    tooltip:HookScript("OnHide", function(self)
        local backdrop = tooltipBackdrops[self]
        if backdrop then
            backdrop:Hide()
        end
    end)
    hookedTooltips[tooltip] = true
end

-- Refresh styling on all hooked tooltips
function TT:Refresh()
    TT:InitializeTooltipProcessor()

    -- Hook main tooltips
    for _, tooltipName in ipairs(TOOLTIPS_TO_SKIN) do
        local tooltip = _G[tooltipName]
        if tooltip then
            TT:HookTooltip(tooltip)
        end
    end

    -- Force refresh styling on visible tooltips
    for tooltip in pairs(hookedTooltips) do
        if tooltip:IsShown() then
            TT:StyleTooltip(tooltip)
        end
        -- Also update hidden tooltips backdrops so they are ready
        local backdrop = tooltipBackdrops[tooltip]
        if backdrop then
            TT:UpdateBackdrop(backdrop)
        end
    end
end

-- Create our own anchor frame that we later use to anchor tooltip to
function TT:CreateTooltipAnchorFrame()
    local TTAnchor = CreateFrame("Frame", "TT_AnchorFrame", UIParent)
    TTAnchor:SetSize(170, 60)
    TTAnchor:ClearAllPoints()
    TTAnchor:SetPoint(self.db.Position.AnchorFrom, UIParent, self.db.Position.AnchorTo, self.db.Position.XOffset,
        self.db.Position.YOffset)
    TTAnchor:SetClampedToScreen(true)

    self.TTAnchor = TTAnchor
    return TTAnchor
end

-- Remove tooltip anchoring Edit Mode UI since we do position changes in our my custom Edit mode
local function DisableTooltipEditMode()
    if GameTooltipDefaultContainer then
        GameTooltipDefaultContainer.SetIsInEditMode = nop
        GameTooltipDefaultContainer.OnEditModeEnter = nop
        GameTooltipDefaultContainer.OnEditModeExit = nop
        GameTooltipDefaultContainer.HasActiveChanges = nop
        GameTooltipDefaultContainer.HighlightSystem = nop
        GameTooltipDefaultContainer.SelectSystem = nop
        -- Unregister from Edit Mode system
        GameTooltipDefaultContainer.system = nil
    end
end

function TT:AnchorTooltip(tooltip)
    if not tooltip or tooltip:IsForbidden() then return end
    tooltip:ClearAllPoints()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", self.TTAnchor, "BOTTOMRIGHT", 0, 0)
end

local function tooltipAnchorReg()
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(self)
        TT:AnchorTooltip(self)
    end)
end

-- Initialize tooltip skinning
function TT:OnEnable()
    if not self.db.Enabled then return end
    if isInitialized then return end
    TT:CreateTooltipAnchorFrame()
    TT:Refresh()
    isInitialized = true
    tooltipAnchorReg()

    C_Timer.After(0.5, function()
        DisableTooltipEditMode()
    end)

    -- Register with my custom edit mode
    local config = {
        key = "TooltipModule",
        displayName = "Tooltip Anchor",
        frame = self.TTAnchor,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset

            self.TTAnchor:ClearAllPoints()
            self.TTAnchor:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
        end,
        getParentFrame = function()
            return UIParent
        end,
        guiPath = "tooltips",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end
