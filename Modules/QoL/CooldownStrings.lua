---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

---@class CooldownStrings: AceModule, AceEvent-3.0
local CS = NRSKNUI:NewModule("CooldownStrings", "AceEvent-3.0")

local CreateFrame = CreateFrame
local _G = _G
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local table_insert = table.insert
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local GetSpecializationInfoByID = GetSpecializationInfoByID

CS.attachedFrame = nil
CS.isShown = false
CS.selectedProfile = nil

local CARD_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local function GetCurrentSpecID()
    local specIndex = GetSpecialization()
    if specIndex then
        local specID = GetSpecializationInfo(specIndex)
        return specID
    end
    return nil
end

function CS.GetSpecInfoByID(specID)
    if not specID then return nil end
    local id, name, _, icon, _, classFile = GetSpecializationInfoByID(specID)
    if id then
        return { id = id, name = name, icon = icon, class = classFile }
    end
    return nil
end

function CS.ApplyProfileToCDM(profileString, profileKey, callbacks)
    if NRSKNUI:InCombat() then
        NRSKNUI:Print("Cannot apply CDM profile while in combat.")
        return false
    end

    if not profileString or profileString == "" then
        NRSKNUI:Print("Profile string is empty.")
        return false
    end

    if not CooldownViewerSettings then
        NRSKNUI:Print("Cooldown Manager is not available.")
        return false
    end

    local layoutManager = CooldownViewerSettings:GetLayoutManager()
    if not layoutManager then
        NRSKNUI:Print("Could not get CDM layout manager.")
        return false
    end

    if layoutManager.AreLayoutsFullyMaxed and layoutManager:AreLayoutsFullyMaxed() then
        if callbacks and callbacks.onLayoutsFull then
            callbacks.onLayoutsFull()
        else
            NRSKNUI:Print("CDM layout limit reached. Delete a layout first.")
        end
        return false
    end

    local function DoImport()
        local success, layoutIDs = pcall(function()
            return layoutManager:CreateLayoutsFromSerializedData(profileString)
        end)

        if not success or not layoutIDs or #layoutIDs == 0 then
            NRSKNUI:Print("Failed to import CDM profile. Invalid profile string?")
            return false
        end

        layoutManager:SetActiveLayoutByID(layoutIDs[1])
        layoutManager:SaveLayouts()

        -- Auto-dismiss taint warning if present (like WagoUI does)
        C_Timer.After(0.1, function()
            if StaticPopup1Button2Text and StaticPopup1Button2Text:GetText() == "Ignore" then
                StaticPopup1Button2:Click()
            end
        end)

        NRSKNUI:CreatePrompt({
            title = "CDM Profile Imported",
            text = "Successfully applied CDM profile: " .. profileKey .. "\n\nA UI reload is recommended to avoid taint issues.",
            onAccept = function() ReloadUI() end,
            acceptText = "Reload Now",
            cancelText = "Later",
        })
        return true
    end

    local existingLayouts = layoutManager.GetLayouts and layoutManager:GetLayouts() or {}
    for _, layout in pairs(existingLayouts) do
        if layout.layoutName == profileKey or layout.name == profileKey then
            if callbacks and callbacks.onConflict then
                callbacks.onConflict(function()
                    if layoutManager.RemoveLayout then
                        layoutManager:RemoveLayout(layout.layoutID or layout.id)
                    end
                    DoImport()
                end)
                return false
            end
        end
    end

    return DoImport()
end

function CS:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.CooldownStrings
end

function CS:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function CS:GetCurrentSpecProfiles()
    local profiles = {}
    local currentSpecID = GetCurrentSpecID()
    if not self.db or not self.db.Profiles then return profiles end

    for name, data in pairs(self.db.Profiles) do
        if data.SpecID == currentSpecID then
            table_insert(profiles, { name = name, data = data })
        end
    end

    table.sort(profiles, function(a, b) return a.name < b.name end)
    return profiles
end

function CS:CreateFrame()
    if self.attachedFrame then return end
    local headerHeight = Theme.headerHeight

    local frame = CreateFrame("Frame", "NRSKNUI_CooldownStringsPanel", UIParent, "BackdropTemplate")
    frame:SetSize(240, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)

    frame:SetBackdrop(CARD_BACKDROP)
    frame:SetBackdropColor(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 0.9)
    frame:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    header:SetHeight(headerHeight)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 1)

    local bottomBorder = header:CreateTexture(nil, "BORDER")
    bottomBorder:SetHeight(1)
    bottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    bottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    bottomBorder:SetColorTexture(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("LEFT", header, "LEFT", Theme.paddingMedium, 0)
    NRSKNUI:ApplyThemeFont(title, "large")
    title:SetText("CDM Profiles")
    title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    frame.titleText = title

    local openBtn = CreateFrame("Button", nil, header)
    openBtn:SetSize(14, 14)
    openBtn:SetPoint("RIGHT", header, "RIGHT", -Theme.paddingMedium, 0)
    local openTex = openBtn:CreateTexture(nil, "ARTWORK")
    openTex:SetAllPoints()
    openTex:SetTexture("Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png")
    openTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    openTex:SetTexelSnappingBias(0)
    openTex:SetSnapToPixelGrid(true)
    openBtn:SetNormalTexture(openTex)

    openBtn:SetScript("OnEnter", function(btn)
        openTex:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        GameTooltip:SetText("Open Profile Manager", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    openBtn:SetScript("OnLeave", function()
        openTex:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        GameTooltip:Hide()
    end)
    openBtn:SetScript("OnClick", function()
        NRSKNUI.GUIFrame.sidebarExpanded["qol_section"] = true
        NRSKNUI.GUIFrame:Show()
        NRSKNUI.GUIFrame:SelectSidebarItem("CooldownStrings")
    end)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", Theme.paddingMedium, -headerHeight - Theme.paddingMedium)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -Theme.paddingMedium, Theme.paddingMedium)

    frame.header = header
    frame.content = content
    frame.openBtn = openBtn
    frame:Hide()

    self.attachedFrame = frame
end

function CS:BuildUI()
    if not self.attachedFrame then return end
    local content = self.attachedFrame.content
    local db = self.db

    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    local profiles = self:GetCurrentSpecProfiles()

    local profileOptions = {}
    for _, profile in ipairs(profiles) do table_insert(profileOptions, { key = profile.name, text = profile.name }) end

    if not self.selectedProfile then self.selectedProfile = profiles[1] and profiles[1].name or nil end
    local foundSelected = false
    for _, opt in ipairs(profileOptions) do
        if opt.key == self.selectedProfile then
            foundSelected = true
            break
        end
    end
    if not foundSelected then
        self.selectedProfile = profiles[1] and profiles[1].name or nil
    end

    local currentSpecID = GetCurrentSpecID()
    local specInfo = currentSpecID and CS.GetSpecInfoByID(currentSpecID)

    if specInfo then
        self.attachedFrame.titleText:SetText(specInfo.name .. " Profiles")
    else
        self.attachedFrame.titleText:SetText("CDM Profiles")
    end

    if #profiles == 0 then
        local noProfileLabel = content:CreateFontString(nil, "OVERLAY")
        noProfileLabel:SetPoint("CENTER", content, "CENTER", 0, 0)
        NRSKNUI:ApplyThemeFont(noProfileLabel, "small")
        noProfileLabel:SetText("No profiles for this spec.\nCreate one in the main GUI.")
        noProfileLabel:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.7)
        noProfileLabel:SetJustifyH("CENTER")
        return
    end

    local importBtn = NRSKNUI.GUIFrame:CreateButton(content, "Import to CDM", {
        height = 26,
        callback = function()
            if not self.selectedProfile then
                NRSKNUI:Print("No profile selected.")
                return
            end

            local profileData = db.Profiles[self.selectedProfile]
            if not profileData or not profileData.String or profileData.String == "" then
                NRSKNUI:Print("Selected profile has no string data.")
                return
            end

            CS.ApplyProfileToCDM(profileData.String, self.selectedProfile, {
                onConflict = function(proceed)
                    NRSKNUI:CreatePrompt({
                        title = "Replace CDM Profile",
                        text = "A profile named '" .. self.selectedProfile .. "' already exists in CDM.\n\nReplace it?",
                        onAccept = proceed,
                        acceptText = "Replace",
                        cancelText = "Cancel",
                    })
                end,
                onLayoutsFull = function()
                    NRSKNUI:Print("CDM layout limit reached. Delete a layout in CDM settings first.")
                end,
            })
        end,
    })
    importBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    importBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)

    local dropdown = NRSKNUI.GUIFrame:CreateDropdown(content, "Select Profile", {
        options = profileOptions,
        value = self.selectedProfile,
        callback = function(value)
            self.selectedProfile = value
        end
    })
    dropdown:SetPoint("TOPLEFT", importBtn, "BOTTOMLEFT", 0, -Theme.paddingSmall)
    dropdown:SetPoint("TOPRIGHT", importBtn, "BOTTOMRIGHT", 0, -Theme.paddingSmall)
    self.dropdown = dropdown
end

function CS:PositionFrame()
    if not self.attachedFrame then return end

    local cdmFrame = _G["CooldownViewerSettings"]
    if cdmFrame and cdmFrame:IsShown() then
        self.attachedFrame:ClearAllPoints()
        self.attachedFrame:SetPoint("TOPLEFT", cdmFrame, "BOTTOMLEFT", 1, -2)
    end
end

function CS:HookCDMFrame()
    local cdmFrame = _G["CooldownViewerSettings"]
    if not cdmFrame then
        C_Timer.After(1, function() self:HookCDMFrame() end)
        return
    end

    cdmFrame:HookScript("OnShow", function() if CS.db.Enabled then CS:ShowFrame() end end)
    cdmFrame:HookScript("OnHide", function() if CS.attachedFrame then CS.attachedFrame:Hide() end end)
end

function CS:ShowFrame()
    if not self.attachedFrame then self:CreateFrame() end

    self:BuildUI()
    self:PositionFrame()
    self.attachedFrame:Show()
    self.isShown = true
end

function CS:HideFrame()
    if self.attachedFrame then self.attachedFrame:Hide() end
    self.isShown = false
end

function CS:RefreshPanel()
    if not self.attachedFrame or not self.attachedFrame:IsShown() then return end

    local profiles = self:GetCurrentSpecProfiles()
    if self.selectedProfile then
        local found = false
        for _, profile in ipairs(profiles) do
            if profile.name == self.selectedProfile then
                found = true
                break
            end
        end
        if not found then self.selectedProfile = profiles[1] and profiles[1].name or nil end
    end
    self:BuildUI()
end

function CS:ApplySettings() CS:UpdateDB() end

function CS:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:HookCDMFrame()

    local cdmFrame = _G["CooldownViewerSettings"]
    if cdmFrame and cdmFrame:IsShown() then self:ShowFrame() end
end

function CS:OnDisable() self:HideFrame() end
