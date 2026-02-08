-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("Blizzard Mouseover: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local BMO = NRSKNUI.Addon:NewModule("BlizzardMouseover", "AceEvent-3.0")

-- Localization
local UIFrameFadeOut = UIFrameFadeOut
local UIFrameFadeIn = UIFrameFadeIn
local ipairs = ipairs
local pairs = pairs
local BagsBar = BagsBar

-- Track which hooks are applied
local appliedHooks = {
    bags = false,
}

-- Module init
function BMO:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardMouseover
    self:SetEnabledState(false)
end

-- Module OnEnable
function BMO:OnEnable()
    if not self.db.Enabled then return end
    C_Timer.After(0.5, function() -- Slight delay just to make sure Blizzard Elements Exist
        self:SetupAllHooks()
        self:UpdateAllAlpha()
    end)
end

-- Setup all element hooks
function BMO:SetupAllHooks()
    self:SetupBagHooks()
end

-- Setup BagBar hooks
function BMO:SetupBagHooks()
    if appliedHooks.bags or not BagsBar then return end
    if not self.db.BagMouseover.Enabled then return end

    for _, child in ipairs({ BagsBar:GetChildren() }) do
        if child:IsObjectType("Button") then
            child:HookScript("OnEnter", function()
                -- Only fade in if both master and element are enabled
                if self.db.Enabled and self.db.BagMouseover.Enabled then
                    UIFrameFadeIn(BagsBar, self.db.FadeInDuration, BagsBar:GetAlpha(), 1.0)
                end
            end)
            child:HookScript("OnLeave", function()
                -- Only fade out if both master and element are enabled
                if self.db.Enabled and self.db.BagMouseover.Enabled then
                    C_Timer.After(self.db.FadeOutDuration, function()
                        UIFrameFadeOut(BagsBar, self.db.FadeOutDuration, BagsBar:GetAlpha(), self.db.Alpha)
                    end)
                end
            end)
        end
    end
    appliedHooks.bags = true
end

-- Update all element alphas, currently only bagsBar, might add more in the future
function BMO:UpdateAllAlpha()
    self:UpdateBagAlpha()
end

-- Update bag alpha
function BMO:UpdateBagAlpha()
    if not BagsBar then return end

    -- If master is disabled OR bag element is disabled, reset to normal alpha
    if not self.db.Enabled or not self.db.BagMouseover.Enabled then
        BagsBar:SetAlpha(1.0)
    else
        BagsBar:SetAlpha(self.db.Alpha)
    end
end

-- Toggle individual element
function BMO:ToggleElement(elementName, enabled)
    if elementName == "bags" then
        self.db.BagMouseover.Enabled = enabled
        if enabled and not appliedHooks.bags then
            -- If enabling and hooks not applied, apply them
            self:SetupBagHooks()
        end
        self:UpdateBagAlpha()
    end
end

-- Mouseover application
-- called from GUI sliders
function BMO:Apply()
    if self.db.Enabled then
        self:UpdateAllAlpha()
    end
end

-- Reset all elements
function BMO:Reset()
    if BagsBar then BagsBar:SetAlpha(1.0) end
end

-- Module OnDisable
function BMO:OnDisable()
    self:Reset()
    -- Reset hook flags so they can be reapplied on enable
    for key in pairs(appliedHooks) do
        appliedHooks[key] = false
    end
end
