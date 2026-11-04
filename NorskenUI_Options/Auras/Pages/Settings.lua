---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Auras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local Shared = NRSKNUI.CDMOptions
local GENERAL, RefreshTree, Reopen, ScheduleAnchorUpdate = Shared.GENERAL, Shared.RefreshTree, Shared.Reopen, Shared.ScheduleAnchorUpdate

---The module's own settings, behind the New card's cog.
---@param page table
local function BuildSettingsPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    page:Card(L['Cooldown & Aura Manager']):HeaderButton({
        texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
        size = 20,
        rotation = math.pi, -- our right arrow, pointing back
        tooltip = L['Back'],
        onClick = function() Reopen(GENERAL) end,
    }):Row(rowHL, 0):Checkbox(L['Enable Cooldown & Aura Manager'], {
        width = 1,
        master = true,
        value = CDM.db.Enabled,
        callback = function(checked)
            CDM.db.Enabled = checked
            NRSKNUI:ToggleModule('CDM', checked)
            page:Refresh()
            RefreshTree()
        end,
    })

    local integration = page:Card(L['Integration'], 'all')
    integration:Row(rowH):Checkbox(L['Hide Blizzard Player Cast Bar'], {
        width = 1,
        value = CDM.db.HidePlayerCastBar,
        tooltip = L["For a cast bar of your own. Showing Blizzard's again takes a reload."],
        callback = function(checked)
            CDM.db.HidePlayerCastBar = checked
            if checked and CDM:IsEnabled() then
                CDM:HidePlayerCastBar()
            elseif not checked then
                NRSKNUI:CreatePrompt({
                    title = L['Reload UI'],
                    text = L["Blizzard's cast bar comes back after a reload. Reload now?"],
                    onAccept = ReloadUI,
                })
            end
        end,
    })
    integration:Separator()
    integration:Row(rowHL, 0):Slider(L['Unit Frame Anchor Minimum Width'], {
        width = 1,
        min = 0,
        max = 600,
        step = 1,
        value = CDM.db.AnchorMinWidth,
        tooltip = L['The unit frame anchor is never narrower than this, so frames beside it keep their distance from a short group.'],
        callback = function(value)
            CDM.db.AnchorMinWidth = value
            ScheduleAnchorUpdate()
        end,
    })
end

Shared.BuildSettingsPage = BuildSettingsPage
