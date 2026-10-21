---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local pairs, ipairs = pairs, ipairs
local tostring = tostring
local format = string.format
local tonumber = tonumber

local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetItemNameByID = C_Item and C_Item.GetItemNameByID

local Shared = NRSKNUI.CDMOptions
local QUESTION_MARK, Reopen = Shared.QUESTION_MARK, Shared.Reopen

---The trinket blacklist, its own page so the main page stays short; Back returns to the trigger it came from.
---@param page table
local function BuildTrinketPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    local blacklist = page:Card(L['Trinket Blacklist'], 'all')
    if Shared.trinketReturnKey and CDM:Get(Shared.trinketReturnKey) then
        blacklist:HeaderButton({
            texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
            size = 20,
            rotation = math.pi, -- our right arrow, pointing back
            tooltip = format(L['Back to %s'], CDM:GetName(Shared.trinketReturnKey)),
            onClick = function() Reopen(Shared.trinketReturnKey) end,
        })
    end
    blacklist:Rebuild(function(card)
        card:Row(rowH):EditBox(L['Add Trinket'], {
            width = 1,
            tooltip = L["An item ID. Trinkets on this list are never tracked, for on-use effects that only switch the trinket's mode."],
            callback = function(text)
                local itemID = tonumber(text)
                if not itemID then return end
                CDM.db.TrinketBlacklist[itemID] = true
                CDM:ApplySettings()
                card:Rebuild()
            end,
        })

        card:Separator()

        local ids = {}
        for itemID in pairs(CDM.db.TrinketBlacklist) do ids[#ids + 1] = itemID end
        table.sort(ids)
        for _, itemID in ipairs(ids) do
            card:Row(28):Icon({
                width = 1,
                size = 24,
                texture = GetItemIconByID(itemID) or QUESTION_MARK,
                text = { text = GetItemNameByID(itemID) or tostring(itemID), description = tostring(itemID) },
                tooltip = function(tooltip)
                    tooltip:SetItemByID(itemID)
                    tooltip:AddLine(L['Click to remove it from the blacklist.'], Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], true)
                end,
                onClick = function(button)
                    if button ~= 'LeftButton' then return end
                    CDM.db.TrinketBlacklist[itemID] = nil
                    CDM:ApplySettings()
                    card:Rebuild()
                end,
            })
        end
    end)
end

Shared.BuildTrinketPage = BuildTrinketPage
