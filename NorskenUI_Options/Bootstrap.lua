local CreateFrame = CreateFrame
local GetLocale = GetLocale
local tostring = tostring
local _G = _G

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local DoesAddOnExist = C_AddOns.DoesAddOnExist
local IsAddOnLoadable = C_AddOns.IsAddOnLoadable
local EnableAddOn = C_AddOns.EnableAddOn
local Reload = C_UI.Reload

local CORE = 'NorskenCore'
local STRINGS = {
    enUS = {
        missing = 'NorskenCore is missing. Install it to use the Norsken addons.',
        disabled = 'NorskenCore is turned off, so the Norsken addons can\'t load.',
        failed = 'NorskenCore couldn\'t load: %s',
        enable = 'Turn on and reload',
    },
    deDE = {
        missing = 'NorskenCore fehlt. Installiere es, um die Norsken-Addons zu nutzen.',
        disabled = 'NorskenCore ist ausgeschaltet, daher können die Norsken-Addons nicht laden.',
        failed = 'NorskenCore konnte nicht laden: %s',
        enable = 'Einschalten und neu laden',
    },
}

local bootstrapFrame = CreateFrame('Frame')
bootstrapFrame:RegisterEvent('PLAYER_LOGIN')
bootstrapFrame:SetScript('OnEvent', function(self)
    self:UnregisterAllEvents()
    if IsAddOnLoaded(CORE) or _G.NorskenCoreBootstrapShown then return end
    _G.NorskenCoreBootstrapShown = true

    local text = STRINGS[GetLocale()] or STRINGS.enUS
    local _, reason = IsAddOnLoadable(CORE)
    local dialog = {
        button1 = OKAY,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    if not DoesAddOnExist(CORE) then
        dialog.text = text.missing
    elseif reason == 'DISABLED' then
        dialog.text = text.disabled
        dialog.button1 = text.enable
        dialog.button2 = CANCEL
        dialog.OnAccept = function()
            EnableAddOn(CORE)
            Reload()
        end
    else
        dialog.text = text.failed:format(_G['ADDON_' .. tostring(reason)] or tostring(reason))
    end

    StaticPopupDialogs.NORSKENCORE_BOOTSTRAP = dialog
    StaticPopup_Show('NORSKENCORE_BOOTSTRAP')
end)
