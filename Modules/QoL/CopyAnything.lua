---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CopyAnything
local CopyAnything = NRSKNUI:GetModule('CopyAnything')

local IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown = IsControlKeyDown, IsShiftKeyDown, IsAltKeyDown
local GetMacroIndexByName, GetMacroSpell, GetMacroItem = GetMacroIndexByName, GetMacroSpell, GetMacroItem
local tonumber, tostring = tonumber, tostring
local select = select
local strupper = strupper
local issecretvalue = issecretvalue
local CreateFrame = CreateFrame
local type = type
local InCombatLockdown = InCombatLockdown
local GetTime = GetTime
local GetMouseFoci = GetMouseFoci
local format = string.format

local GetActionText = C_ActionBar and C_ActionBar.GetActionText
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
local GetSpellInfo = C_Spell and C_Spell.GetSpellInfo
local GetItemIDForItemInfo = C_Item and C_Item.GetItemIDForItemInfo
local GetItemInfo = C_Item and C_Item.GetItemInfo

local lastCopyTime = 0

function CopyAnything:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.CopyAnything
end

function CopyAnything:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function CheckModifiers(modifier)
    if not modifier then return true end

    if type(modifier) == 'string' then
        local t = {}
        modifier = modifier:lower()

        if modifier:find('ctrl') then t.ctrl = true end
        if modifier:find('shift') then t.shift = true end
        if modifier:find('alt') then t.alt = true end

        modifier = t
    end

    if modifier.shift and not IsShiftKeyDown() then return false end
    if modifier.ctrl and not IsControlKeyDown() then return false end
    if modifier.alt and not IsAltKeyDown() then return false end

    return true
end

function CopyAnything:CreateKeyboardFrame()
    if not self.frame then
        self.frame = CreateFrame('Frame', 'NRSKNUI_CopyFrame')
        self.frame:SetScript('OnKeyDown', function(frame, key)
            if InCombatLockdown() then return end
            frame:SetPropagateKeyboardInput(not self:TryCopy(key))
        end)
    end
    self.frame:EnableKeyboard(true)
end

function CopyAnything:TryCopy(key)
    if NRSKNUI:IsFullyRestricted() then return false end
    if not self.db or not self.db.key or not self.db.modifier then return false end
    if key ~= strupper(self.db.key) then return false end
    if not CheckModifiers(self.db.modifier) then return false end

    local now = GetTime()
    if now - lastCopyTime < 0.1 then return true end

    local copyId, copyName

    -- SpellID
    if not issecretvalue(GameTooltip:GetSpell()) then
        local spellData = GameTooltip:GetSpell()

        if spellData then
            if spellData.spellID then
                copyId = spellData.spellID
                copyName = spellData.spellName
            end
        end
    end

    -- ItemID
    if not issecretvalue(GameTooltip:GetItem()) then
        local itemData = GameTooltip:GetItem()

        if not copyId and itemData then
            local itemID = GetItemIDForItemInfo(itemData.ItemLink)
            if itemID then
                copyId = itemID
                copyName = itemData.itemName
            end
        end
    end

    -- Copy player names, other units are secret most of the time.
    if not issecretvalue(GameTooltip:GetUnit()) then
        local unitData = GameTooltip:GetUnit()

        if not copyId and unitData then
            if unitData.name then
                copyId = unitData.name
                copyName = 'Player Name'
            end
        end
    end

    -- Aura / Other tooltip data
    if not issecretvalue(GameTooltip:GetTooltipData()) then
        local tooltipData = GameTooltip:GetTooltipData()

        if not copyId and tooltipData then
            if GameTooltip:IsTooltipType(7) then -- Aura
                local spellInfo = GetSpellInfo(tooltipData.id)
                if spellInfo then
                    copyId = tooltipData.id
                    copyName = spellInfo.name
                end
            else
                copyId = tooltipData.id
                copyName = 'Other'
            end
        end
    end

    -- ElvUI SpellBook Tooltip
    if IsAddOnLoaded('ElvUI') and not issecretvalue(ElvUI_SpellBookTooltip) then
        local E = ElvUI_SpellBookTooltip
        local elvuiData = E:GetTooltipData()

        if not copyId and elvuiData then
            if elvuiData and E:IsTooltipType(1) then
                copyId = elvuiData.id
                copyName = E.TextLeft1:GetText()
            end
        end
    end

    -- Macro handling
    if not issecretvalue(GameTooltip:IsTooltipType()) then
        if not copyId and GameTooltip:IsTooltipType(25) then
            local info = GameTooltip:GetPrimaryTooltipInfo()

            if info and info.getterArgs then
                local actionID = info.getterArgs[1]
                local macroName = GetActionText(actionID)

                if macroName then
                    local macroSlot = GetMacroIndexByName(macroName)
                    local id = GetMacroSpell(macroSlot)
                    local itemLink = select(2, GetMacroItem(macroSlot))

                    -- Check if the macro has a spell or item associated with it
                    if id then
                        local spellInfo = GetSpellInfo(id)
                        if spellInfo then
                            copyId = id
                            copyName = spellInfo.name
                        end
                        -- If the macro has an item link, extract the item ID and name
                    elseif itemLink then
                        local itemId = tonumber(itemLink:match('item:(%d+)'))
                        if itemId then
                            local itemName = GetItemInfo(itemId)
                            if itemName then
                                copyId = itemId
                                copyName = itemName
                            end
                        end
                    end
                end
            end
        end
    end

    -- NUI Color Picker, shows the RGBA (0-1) of the colorpicker under mousecursor.
    if not copyId then
        local frames = GetMouseFoci()
        local focus = frames and frames[1]
        if focus and focus.isNUIColorPicker and focus.colorPickerRow then
            local r, g, b, a = focus.colorPickerRow:GetColor()
            local function fmtNum(n)
                local s = format('%.2f', n)
                s = s:gsub('%.?0+$', '')
                return s
            end
            copyId = fmtNum(r) .. ', ' .. fmtNum(g) .. ', ' .. fmtNum(b) .. ', ' .. fmtNum(a)
            copyName = 'Color'
        end
    end

    if copyId then
        lastCopyTime = GetTime()
        NRSKNUI:CreateCopyDialog(copyName, tostring(copyId))
        return true
    end
    return false
end

function CopyAnything:PLAYER_REGEN_DISABLED()
    if self.frame then
        self.frame:EnableKeyboard(false)
    end
end

function CopyAnything:PLAYER_REGEN_ENABLED()
    if self.db.Enabled then
        self:CreateKeyboardFrame()
    end
end

function CopyAnything:ApplySettings()
    CopyAnything:UpdateDB()
end

function CopyAnything:OnEnable()
    if not self.db.Enabled then return end

    self:RegisterEvent('PLAYER_REGEN_DISABLED')
    self:RegisterEvent('PLAYER_REGEN_ENABLED')

    NRSKNUI:RunWhenSafe(function() self:CreateKeyboardFrame() end)
end

function CopyAnything:OnDisable()
    if not self.frame then return end
    if not InCombatLockdown() then
        self.frame:EnableKeyboard(false)
    end
end
