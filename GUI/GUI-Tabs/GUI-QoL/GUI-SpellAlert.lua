---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SpellAlertModule
local SpellAlert = NRSKNUI:GetModule('SpellAlert')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local format = string.format

local function ApplySettings() SpellAlert:ApplySettings() end

---@param name string
---@param icon number|string
---@param size number font size of the text the label is going into
---@return string
local function SpecLabel(name, icon, size)
    return format('|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s', icon, size, size, NRSKNUI:ColorTextByClass(name))
end

local function BuildTab(page, db)
    page:SetEnabled(function() return db.Enabled end)

    -- Card 1: Enable
    local enableCard = page:Card(L['Spell Alerts'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Spell Alerts'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Spell Alerts'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('SpellAlert', checked)
            page:Refresh()
        end,
    })

    enableCard:Separator()

    local infoRowSize = 50
    local infoRow = enableCard:Row(infoRowSize)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Functionality Info']), {
        autoHeight = true,
        width = 1,
        height = infoRowSize,
        bgMode = 'hide',
        text = {
            L['Scales and fades the spell activation overlays, the glow that frames your screen when a proc lights up.'],
            L['While enabled it takes over the Blizzard overlay CVars, your own values are stored and put back when you turn it off.'],
        },
    })

    -- Card 2: Alert Settings
    local settingsCard = page:Card(L['Alert Settings'], 'all')
    settingsCard:Rebuild(function(card)
        local specID, specName, specIcon = SpellAlert:GetSpecInfo()
        local specOption = specID and SpecLabel(specName, specIcon, Theme.fontSizeNormal) or nil
        local specText = specID and NRSKNUI:ColorTextByClass(specName) or nil
        local useGlobal = db.UseGlobal or not specID
        local scopeDesc

        local scopeOptions = { {
            value = 'global',
            text = L['Global'],
            tooltip = L['One set of values, shared by every specialization.'],
        } }

        if specOption then
            scopeOptions[2] = {
                value = 'spec',
                text = specOption,
                tooltip = L['A separate set of values for this specialization only.']
            }
        end

        if useGlobal then
            local tOne = format(L['Every specialization uses these values baseline. Pick %s to give it a set of its own.'], specText)
            local tTwo = L['One set of values, shared by every specialization.']

            scopeDesc = specText and tOne or tTwo
        else
            local tSpec = format(L['Only %s uses these values. Your other specializations keep their own.'], specText)

            scopeDesc = tSpec
        end

        local bannerSize = 26
        local bannerRow = card:Row(bannerSize)
        bannerRow:Text(NRSKNUI:ColorTextByTheme(L['Settings Scope']), {
            autoHeight = true,
            width = 0.5,
            height = bannerSize,
            bgMode = 'hide',
            text = scopeDesc,
        })

        bannerRow:Dropdown(L['Select Scope'], {
            width = 0.5,
            options = scopeOptions,
            value = useGlobal and 'global' or 'spec',
            callback = function(key)
                db.UseGlobal = key == 'global'
                ApplySettings()
                card:Rebuild()
            end,
        })

        card:Separator()

        local settings = SpellAlert:GetCurrentSettings()
        local sizeRow = card:Row(rowHL, 0)
        sizeRow:Slider(L['Alert Scale'], {
            width = 0.5,
            min = 0.25,
            max = 3,
            step = 0.05,
            value = settings.Scale,
            callback = function(val)
                SpellAlert:GetCurrentSettings().Scale = val
                ApplySettings()
            end,
        })

        sizeRow:Slider(L['Alert Opacity'], {
            width = 0.5,
            min = 0,
            max = 1,
            step = 0.05,
            value = settings.Alpha,
            callback = function(val)
                SpellAlert:GetCurrentSettings().Alpha = val
                ApplySettings()
            end,
        })
    end)
end

GUI:RegisterPage('spellAlert', {
    mode = 'clean',
    search = {},
    build = function(page)
        local db = NRSKNUI.db.profile.Miscellaneous.SpellAlert
        if not db then return end

        BuildTab(page, db)
    end,
})
