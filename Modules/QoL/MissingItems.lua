---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class MissingItems: AceModule, AceEvent-3.0
local MITEMS = NRSKNUI:NewModule("MissingItems", "AceEvent-3.0")

local AS = NRSKNUI.Libs.AS
local LD = NRSKNUI.Libs.LD

local pairs, ipairs = pairs, ipairs
local wipe = wipe
local table_insert = table.insert
local table_sort = table.sort
local tContains = tContains
local CreateFrame = CreateFrame
local UnitAffectingCombat = UnitAffectingCombat
local UnitLevel = UnitLevel
local GetMaxLevelForLatestExpansion = GetMaxLevelForLatestExpansion
local UIParent = UIParent
local C_Container = C_Container
local C_Item = C_Item
local time = time
local type = type
local CopyTable = CopyTable

local EXPORT_PREFIX = "!NRSKNITEMS1!"

local TRACK_MODES = {
    EXACT = "exact",
    AUTO = "auto",
    MANUAL = "manual",
}

local qualityAtlasPattern = "|A:(Professions%-ChatIcon%-Quality%-[^:]+):%d+:%d+"

local function GetQualityAtlasFromLink(link, itemID)
    if link then
        local atlas = link:match(qualityAtlasPattern)
        if atlas then return atlas end
    end
    if itemID then
        local _, itemLink = GetItemInfo(itemID)
        if itemLink then
            return itemLink:match(qualityAtlasPattern)
        end
    end
    return nil
end

local function GetTierFromLink(link)
    if not link then return nil end
    local tier = link:match("Tier(%d)")
    return tier and tonumber(tier)
end

local containerFrame = nil
local textPool = {}
local activeTexts = {}
local itemCountCache = {}
local itemLinkCache = {}
local pendingItemLoads = {}

local function ScanBags()
    wipe(itemCountCache)
    wipe(itemLinkCache)

    for bagIndex = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagIndex)
        for slotIndex = 1, numSlots do
            local itemInfo = C_Container.GetContainerItemInfo(bagIndex, slotIndex)
            if itemInfo and itemInfo.itemID then
                local itemID = itemInfo.itemID
                local count = itemInfo.stackCount or 1
                itemCountCache[itemID] = (itemCountCache[itemID] or 0) + count
                if not itemLinkCache[itemID] then
                    local itemLink = C_Container.GetContainerItemLink(bagIndex, slotIndex)
                    if itemLink then
                        itemLinkCache[itemID] = itemLink
                    elseif itemInfo.hyperlink then
                        itemLinkCache[itemID] = itemInfo.hyperlink
                    end
                end
            end
        end
    end

    return itemCountCache
end

local function GetItemCount(itemID)
    return itemCountCache[itemID] or 0
end

local function GetVariantCounts(itemID, itemSettings)
    local variants = itemSettings.variants or {}
    local trackMode = itemSettings.trackMode or TRACK_MODES.EXACT

    local totalCount = 0
    local breakdown = {}

    -- 1x ItemID tracked
    if trackMode == TRACK_MODES.EXACT then
        local count = GetItemCount(itemID)
        local link = itemLinkCache[itemID]
        local qualityAtlas = GetQualityAtlasFromLink(link, itemID)
        totalCount = count

        table_insert(breakdown, {
            itemID = itemID,
            rank = 1,
            qualityAtlas = qualityAtlas,
            count = count,
        })
        -- 1x ItemID tracked and all items with the same name
    elseif trackMode == TRACK_MODES.AUTO then
        local primaryName = C_Item.GetItemNameByID(itemID)
        if primaryName then
            local matchingIDs = {}
            for bagItemID in pairs(itemCountCache) do
                local bagItemName = C_Item.GetItemNameByID(bagItemID)
                if bagItemName and bagItemName == primaryName then
                    table_insert(matchingIDs, bagItemID)
                end
            end

            table_sort(matchingIDs)

            for rank, id in ipairs(matchingIDs) do
                local count = GetItemCount(id)
                local link = itemLinkCache[id]
                local qualityAtlas = GetQualityAtlasFromLink(link, id)

                totalCount = totalCount + count

                table_insert(breakdown, {
                    itemID = id,
                    rank = rank,
                    qualityAtlas = qualityAtlas,
                    count = count,
                })
            end

            if #breakdown == 0 then
                local qualityAtlas = GetQualityAtlasFromLink(nil, itemID)
                table_insert(breakdown, {
                    itemID = itemID,
                    rank = 1,
                    qualityAtlas = qualityAtlas,
                    count = 0,
                })
            end
        end
        -- Multiple ItemID's tracked
    else
        local allIDs = { itemID }
        for _, variantID in ipairs(variants) do
            table_insert(allIDs, variantID)
        end

        table_sort(allIDs)

        for rank, id in ipairs(allIDs) do
            local count = GetItemCount(id)
            local link = itemLinkCache[id]
            local qualityAtlas = GetQualityAtlasFromLink(link, id)

            totalCount = totalCount + count

            table_insert(breakdown, {
                itemID = id,
                rank = rank,
                qualityAtlas = qualityAtlas,
                count = count,
            })
        end
    end

    return totalCount, breakdown
end

local MAX_QUALITY_ICONS = 3

local function CreateQualityIcon(parent, size)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(size, size)

    local iconTexture = container:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints()
    iconTexture:SetZoom()
    container.icon = iconTexture

    local qualitySize = math.max(size * 0.7, 10)
    local qualityFrame = CreateFrame("Frame", nil, container)
    qualityFrame:SetFrameLevel(container:GetFrameLevel() + 10)
    qualityFrame:SetSize(qualitySize, qualitySize)
    qualityFrame:SetPoint("TOPLEFT", container, "TOPLEFT", -3, 3)

    local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
    qualityTexture:SetAllPoints()
    qualityTexture:Hide()

    container.qualityFrame = qualityFrame
    container.qualityTexture = qualityTexture

    container:Hide()
    return container
end

local function CreateTextLine()
    local db = MITEMS.db.Display
    local textFrame = CreateFrame("Frame", nil, containerFrame)
    textFrame:SetPixelSize(300, db.FontSize + 4)

    local text = textFrame:CreateFontString(nil, "OVERLAY")
    text:SetPixelPoint("CENTER", textFrame, "CENTER", 0, 0)
    text:SetPixelSnap()
    text:SetFontStyle(db)
    text:SetJustifyH("CENTER")

    textFrame.text = text

    textFrame.qualityIcons = {}
    for i = 1, MAX_QUALITY_ICONS do
        local iconContainer = CreateQualityIcon(textFrame, db.FontSize)
        textFrame.qualityIcons[i] = iconContainer
    end

    textFrame:Hide()
    return textFrame
end

local function SetupQualityIcons(textFrame, breakdown, db)
    for _, iconContainer in ipairs(textFrame.qualityIcons) do
        iconContainer:Hide()
        iconContainer:ClearAllPoints()
        if iconContainer.qualityTexture then
            iconContainer.qualityTexture:Hide()
        end
    end

    if not breakdown or #breakdown == 0 then return end

    local iconSize = db.FontSize
    local spacing = 2
    local xOffset = 4

    for i, data in ipairs(breakdown) do
        if i > MAX_QUALITY_ICONS then break end
        local iconContainer = textFrame.qualityIcons[i]

        local itemIcon = C_Item.GetItemIconByID(data.itemID)
        if itemIcon then
            iconContainer.icon:SetTexture(itemIcon)
        else
            iconContainer.icon:SetTexture(134400)
        end

        iconContainer:SetSize(iconSize, iconSize)
        iconContainer:SetPixelPoint("LEFT", textFrame.text, "RIGHT", xOffset, 0)

        if data.qualityAtlas and iconContainer.qualityTexture then
            iconContainer.qualityTexture:SetAtlas(data.qualityAtlas, false)
            iconContainer.qualityTexture:Show()
        end

        iconContainer:Show()
        xOffset = xOffset + iconSize + spacing
    end
end

local function AcquireText()
    for _, textFrame in ipairs(textPool) do
        if not textFrame.inUse then
            textFrame.inUse = true
            return textFrame
        end
    end

    local newText = CreateTextLine()
    newText.inUse = true
    textPool[#textPool + 1] = newText
    return newText
end

local function ReleaseText(textFrame)
    textFrame.inUse = false
    textFrame:Hide()
    textFrame:ClearAllPoints()
    if textFrame.qualityIcons then
        for _, iconContainer in ipairs(textFrame.qualityIcons) do
            iconContainer:Hide()
            if iconContainer.qualityTexture then
                iconContainer.qualityTexture:Hide()
            end
        end
    end
end

local function ReleaseAllTexts()
    for _, textFrame in ipairs(activeTexts) do ReleaseText(textFrame) end
    wipe(activeTexts)
end

local function CreateContainerFrame()
    if containerFrame then return end
    local db = MITEMS.db.Display
    containerFrame = CreateFrame("Frame", "NRSKNUI_MissingItemsContainer", UIParent)
    containerFrame:SetPixelSize(300, 200)
    NRSKNUI:ApplyFramePosition(containerFrame, db.Position, db)
    containerFrame:Hide()
end

local function ArrangeTexts()
    local db = MITEMS.db.Display
    local lineHeight = db.FontSize + db.LineSpacing

    for i, textFrame in ipairs(activeTexts) do
        textFrame:ClearAllPoints()
        local yOffset = -(i - 1) * lineHeight
        textFrame:SetPixelPoint("TOP", containerFrame, "TOP", 0, yOffset)
    end

    local totalHeight = #activeTexts * lineHeight
    if containerFrame then containerFrame:SetPixelHeight(math.max(totalHeight, 20)) end
end

local function UpdateDisplay()
    ReleaseAllTexts()

    local db = MITEMS.db
    if not db or not db.Enabled then
        if containerFrame then containerFrame:Hide() end
        return
    end

    if UnitAffectingCombat("player") then
        if containerFrame then containerFrame:Hide() end
        return
    end

    if UnitLevel("player") < GetMaxLevelForLatestExpansion() then
        if containerFrame then containerFrame:Hide() end
        return
    end

    local activeGroup = db.ActiveGroup
    local items = db.Items or {}

    ScanBags()

    -- Backfill link cache for tracked items not in bags
    for trackedID in pairs(items) do
        if not itemLinkCache[trackedID] and trackedID > 0 then
            local _, link = C_Item.GetItemInfo(trackedID)
            if link then itemLinkCache[trackedID] = link end
        end
    end

    local missingItems = {}
    local currentSpecID = NRSKNUI.MySpec and NRSKNUI.MySpec.id

    for itemID, itemSettings in pairs(items) do
        if itemSettings.enabled ~= false then
            local groups = itemSettings.groups or {}
            if tContains(groups, activeGroup) then
                local passesSpecFilter = true
                if itemSettings.loadSpecEnabled and itemSettings.loadSpecs then
                    if not currentSpecID or not itemSettings.loadSpecs[currentSpecID] then
                        passesSpecFilter = false
                    end
                end

                if passesSpecFilter then
                    local threshold = itemSettings.threshold
                    local trackMode = itemSettings.trackMode or TRACK_MODES.EXACT
                    local hasVariants = itemSettings.variants and #itemSettings.variants > 0
                    local count, breakdown

                    if hasVariants or trackMode == TRACK_MODES.AUTO then
                        count, breakdown = GetVariantCounts(itemID, itemSettings)
                    else
                        count = GetItemCount(itemID)
                        local link = itemLinkCache[itemID]
                        local qualityAtlas = GetQualityAtlasFromLink(link, itemID)
                        breakdown = { { itemID = itemID, rank = 1, qualityAtlas = qualityAtlas, count = count } }
                    end

                    if count <= threshold then
                        local itemName = C_Item.GetItemNameByID(itemID)
                        if not itemName and itemID > 0 then
                            if not pendingItemLoads[itemID] then
                                pendingItemLoads[itemID] = true
                                local item = Item:CreateFromItemID(itemID)
                                item:ContinueOnItemLoad(function()
                                    pendingItemLoads[itemID] = nil
                                    UpdateDisplay()
                                end)
                            end
                        elseif itemName then
                            table_insert(missingItems, {
                                itemID = itemID,
                                name = itemName,
                                count = count,
                                threshold = threshold,
                                color = itemSettings.color or db.Display.DefaultColor,
                                breakdown = breakdown,
                            })
                        end
                    end
                end
            end
        end
    end

    table_sort(missingItems, function(a, b) return a.name < b.name end)

    if #missingItems > 0 then
        if not containerFrame then CreateContainerFrame() end

        for _, item in ipairs(missingItems) do
            local textFrame = AcquireText()
            activeTexts[#activeTexts + 1] = textFrame

            local displayText = item.name .. ": " .. item.count
            textFrame.text:SetText(displayText)
            textFrame.text:SetTextColor(item.color[1], item.color[2], item.color[3], item.color[4] or 1)

            SetupQualityIcons(textFrame, item.breakdown, db.Display)

            textFrame:Show()
        end

        ArrangeTexts()
        if containerFrame then containerFrame:Show() end
    else
        if containerFrame then containerFrame:Hide() end
    end
end

function MITEMS:UpdateDB()
    self.db = NRSKNUI.db.profile.MissingItems
end

function MITEMS:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function PreCacheItems()
    local db = MITEMS.db
    if not db or not db.Items then return end

    for itemID in pairs(db.Items) do
        if itemID > 0 and not C_Item.GetItemNameByID(itemID) then
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function() end)
        end
    end
end

function MITEMS:OnEnable()
    self:UpdateDB()
    CreateContainerFrame()

    C_Timer.After(0.5, function() self:ApplySettings() end)

    self:RegisterEvent("BAG_UPDATE_DELAYED", UpdateDisplay)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", UpdateDisplay)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", UpdateDisplay)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", UpdateDisplay)
    self:RegisterEditModeElements()
    self:SetupAuctionatorHook()

    NRSKNUI.Libs.LS.RegisterPlayerSpecChange(self, UpdateDisplay)

    PreCacheItems()
    C_Timer.After(0.5, UpdateDisplay)
end

function MITEMS:RegisterEditModeElements()
    if not NRSKNUI.EditMode then return end

    if not containerFrame then CreateContainerFrame() end

    local displayDb = self.db.Display

    NRSKNUI.EditMode:RegisterElement({
        key = "MissingItems",
        displayName = "Missing Items",
        frame = containerFrame,
        getPosition = function()
            return displayDb.Position or {}
        end,
        setPosition = function(pos)
            displayDb.Position = displayDb.Position or {}
            displayDb.Position.AnchorFrom = pos.AnchorFrom
            displayDb.Position.AnchorTo = pos.AnchorTo
            displayDb.Position.XOffset = pos.XOffset
            displayDb.Position.YOffset = pos.YOffset
            if containerFrame then
                local anchorFrame = NRSKNUI:ResolveAnchorFrame(displayDb.anchorFrameType, displayDb.ParentFrame)
                containerFrame:ClearAllPoints()
                containerFrame:SetPixelPoint(pos.AnchorFrom, anchorFrame, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        guiPath = "missingItems",
    })
end

function MITEMS:OnDisable()
    self:UnregisterAllEvents()
    ReleaseAllTexts()
    if containerFrame then containerFrame:Hide() end
    if NRSKNUI.EditMode then NRSKNUI.EditMode:UnregisterElement("MissingItems") end
    self:HideAuctionatorButton()

    NRSKNUI.Libs.LS.UnregisterPlayerSpecChange(self)
end

local auctionatorButton = nil
local auctionatorHooked = false
local shoppingFrameHooked = false

local function GetItemsBelowThreshold()
    local db = MITEMS.db
    if not db or not db.Enabled then return {} end

    local activeGroup = db.ActiveGroup
    local items = db.Items or {}
    local result = {}
    local currentSpecID = NRSKNUI.MySpec and NRSKNUI.MySpec.id

    ScanBags()

    -- Backfill link cache for tracked items not in bags
    for trackedID in pairs(items) do
        if not itemLinkCache[trackedID] and trackedID > 0 then
            local _, link = C_Item.GetItemInfo(trackedID)
            if link then itemLinkCache[trackedID] = link end
        end
    end

    for itemID, itemSettings in pairs(items) do
        if itemSettings.enabled ~= false then
            local groups = itemSettings.groups or {}
            if tContains(groups, activeGroup) then
                local passesSpecFilter = true
                if itemSettings.loadSpecEnabled and itemSettings.loadSpecs then
                    if not currentSpecID or not itemSettings.loadSpecs[currentSpecID] then
                        passesSpecFilter = false
                    end
                end

                if passesSpecFilter then
                    local threshold = itemSettings.threshold or 0
                    local trackMode = itemSettings.trackMode or TRACK_MODES.EXACT
                    local hasVariants = itemSettings.variants and #itemSettings.variants > 0
                    local count

                    if hasVariants or trackMode == TRACK_MODES.AUTO then
                        count = GetVariantCounts(itemID, itemSettings)
                    else
                        count = GetItemCount(itemID)
                    end

                    local buyQty = itemSettings.buyQuantity or 0

                    if count <= threshold and buyQty > 0 then
                        local itemName = C_Item.GetItemNameByID(itemID)
                        if itemName then
                            local tier = nil
                            if trackMode == TRACK_MODES.EXACT then tier = GetTierFromLink(itemLinkCache[itemID]) end
                            table_insert(result, {
                                itemID = itemID,
                                name = itemName,
                                count = count,
                                threshold = threshold,
                                buyQuantity = buyQty,
                                tier = tier,
                            })
                        elseif itemID > 0 and not pendingItemLoads[itemID] then
                            pendingItemLoads[itemID] = true
                            local item = Item:CreateFromItemID(itemID)
                            item:ContinueOnItemLoad(function()
                                pendingItemLoads[itemID] = nil
                            end)
                        end
                    end
                end
            end
        end
    end

    table_sort(result, function(a, b) return a.name < b.name end)
    return result
end

local function CreateAuctionatorButton()
    if auctionatorButton then return auctionatorButton end

    local Theme = NRSKNUI.Theme
    local bgColor = Theme.bgMedium

    local btn = CreateFrame("Button", "NRSKNUI_AuctionatorShopButton", UIParent, "BackdropTemplate")
    btn:SetPixelSize(140, 24)
    btn._bgColor = bgColor

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], 1)
    btn:SetBackdropBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], 1)

    btn.bg = btn:CreateTexture("NRSKNUI_AuctionatorShopButtonBG", "BACKGROUND")
    btn.bg:SetPixelInside(btn)
    btn.bg:SetColorTexture(Theme.bgLight[1], Theme.bgLight[2], Theme.bgLight[3], 1)

    local hoverAnimGroup = btn:CreateAnimationGroup()
    hoverAnimGroup:CreateAnimation("Animation"):SetDuration(Theme.animDuration)

    local borderColorFrom = {}
    local borderColorTo = {}

    hoverAnimGroup:SetScript("OnUpdate", function(anim)
        local progress = anim:GetProgress() or 0
        local r = borderColorFrom.r + (borderColorTo.r - borderColorFrom.r) * progress
        local g = borderColorFrom.g + (borderColorTo.g - borderColorFrom.g) * progress
        local b = borderColorFrom.b + (borderColorTo.b - borderColorFrom.b) * progress
        btn:SetBackdropBorderColor(r, g, b, 1)
    end)

    hoverAnimGroup:SetScript("OnFinished", function()
        btn:SetBackdropBorderColor(borderColorTo.r, borderColorTo.g, borderColorTo.b, 1)
    end)

    local function AnimateBorderColor(toAccent)
        hoverAnimGroup:Stop()
        local currentR, currentG, currentB = btn:GetBackdropBorderColor()
        borderColorFrom.r, borderColorFrom.g, borderColorFrom.b = currentR, currentG, currentB

        if toAccent then
            borderColorTo.r, borderColorTo.g, borderColorTo.b = Theme.accent[1], Theme.accent[2], Theme.accent[3]
        else
            borderColorTo.r, borderColorTo.g, borderColorTo.b = Theme.border[1], Theme.border[2], Theme.border[3]
        end
        hoverAnimGroup:Play()
    end

    local textWidget = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    NRSKNUI:ApplyThemeFont(textWidget, "normal")
    textWidget:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    textWidget:SetText("Import Low Stock")
    textWidget:SetPixelPoint("CENTER")
    textWidget:SetPixelSnap()
    btn.text = textWidget

    btn:SetScript("OnEnter", function() AnimateBorderColor(true) end)

    btn:SetScript("OnLeave", function(self)
        AnimateBorderColor(false)
        self:SetBackdropColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 1)
    end)

    btn:SetScript("OnMouseDown",
        function(self)
            self:SetBackdropColor(Theme.selectedBg[1], Theme.selectedBg[2], Theme.selectedBg[3],
                Theme.selectedBg[4])
        end)
    btn:SetScript("OnMouseUp",
        function(self) self:SetBackdropColor(self._bgColor[1], self._bgColor[2], self._bgColor[3], 1) end)
    btn:SetScript("OnClick", function() MITEMS:GenerateAuctionatorList() end)

    btn:Hide()

    auctionatorButton = btn
    return btn
end

function MITEMS:GenerateAuctionatorList()
    if not Auctionator or not Auctionator.API or not Auctionator.API.v1 then
        NRSKNUI:Print("Auctionator API not available")
        return
    end

    local items = GetItemsBelowThreshold()
    if #items == 0 then
        NRSKNUI:Print("No items below threshold with buy quantity set")
        return
    end

    local searchStrings = {}
    for _, item in ipairs(items) do
        local searchTerm = Auctionator.API.v1.ConvertToSearchString("NorskenUI", {
            searchString = item.name,
            isExact = true,
            quantity = item.buyQuantity,
            tier = item.tier,
        })
        table_insert(searchStrings, searchTerm)
    end

    Auctionator.API.v1.CreateShoppingList("NorskenUI", "NorskenUI - Low Stock", searchStrings)
    NRSKNUI:Print("Created shopping list with " .. #items .. " item(s)")
end

function MITEMS:ShowAuctionatorButton()
    if not AuctionatorShoppingFrame then return end

    local btn = CreateAuctionatorButton()
    btn:ClearAllPoints()
    btn:SetPixelPoint("TOPRIGHT", AuctionatorShoppingFrame, "BOTTOMRIGHT", 4, -28)
    btn:SetParent(AuctionatorShoppingFrame)
    btn:SetFrameStrata("HIGH")
    btn:Show()
end

function MITEMS:HideAuctionatorButton()
    if auctionatorButton then
        auctionatorButton:Hide()
    end
end

function MITEMS:SetupAuctionatorHook()
    if auctionatorHooked then return end
    if not Auctionator then return end

    auctionatorHooked = true

    local function TryHookShoppingFrame()
        if shoppingFrameHooked then return true end
        if not AuctionatorShoppingFrame then return false end

        shoppingFrameHooked = true
        AuctionatorShoppingFrame:HookScript("OnShow", function()
            if MITEMS.db and MITEMS.db.Enabled then
                MITEMS:ShowAuctionatorButton()
            end
        end)
        AuctionatorShoppingFrame:HookScript("OnHide", function()
            MITEMS:HideAuctionatorButton()
        end)
        return true
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then
            C_Timer.After(0.2, function()
                TryHookShoppingFrame()
                if AuctionatorShoppingFrame and AuctionatorShoppingFrame:IsVisible() then
                    MITEMS:ShowAuctionatorButton()
                end
            end)
        elseif event == "AUCTION_HOUSE_CLOSED" then
            MITEMS:HideAuctionatorButton()
        end
    end)

    TryHookShoppingFrame()
end

function MITEMS:Refresh()
    if self.db and self.db.Enabled then
        self:OnEnable()
        UpdateDisplay()
    else
        self:OnDisable()
    end
end

function MITEMS:ApplySettings()
    self:UpdateDB()

    for _, textFrame in ipairs(textPool) do
        local db = self.db.Display
        textFrame.text:SetFontStyle(db)
        textFrame:SetPixelHeight(db.FontSize + 4)
    end

    if containerFrame and self.db then
        local db = self.db.Display
        NRSKNUI:ApplyFramePosition(containerFrame, db.Position, db)
    end

    UpdateDisplay()
end

function MITEMS:AddItem(itemID, threshold, groups)
    self.db.Items = self.db.Items or {}
    self.db.Items[itemID] = {
        threshold = threshold,
        enabled = true,
        groups = groups or { self.db.ActiveGroup },
    }
    UpdateDisplay()
end

function MITEMS:RemoveItem(itemID)
    if self.db.Items then
        self.db.Items[itemID] = nil
    end
    UpdateDisplay()
end

function MITEMS:CreateGroup(groupName)
    self.db.Groups = self.db.Groups or {}
    if not tContains(self.db.Groups, groupName) then
        table_insert(self.db.Groups, groupName)
    end
end

function MITEMS:DeleteGroup(groupName)
    local groups = self.db.Groups or {}
    for i, name in ipairs(groups) do
        if name == groupName then
            table.remove(groups, i)
            break
        end
    end

    for _, itemSettings in pairs(self.db.Items or {}) do
        local itemGroups = itemSettings.groups or {}
        for i, name in ipairs(itemGroups) do
            if name == groupName then
                table.remove(itemGroups, i)
                break
            end
        end
    end

    UpdateDisplay()
end

function MITEMS:SetActiveGroup(groupName)
    if tContains(self.db.Groups or {}, groupName) then
        self.db.ActiveGroup = groupName
        UpdateDisplay()
    end
end

function MITEMS:GetGroups()
    return self.db.Groups or {}
end

local function EncodeData(data)
    local serialized = AS:Serialize(data)
    if not serialized then return nil, "Serialization failed" end
    local compressed = LD:CompressDeflate(serialized, { level = 9 })
    if not compressed then return nil, "Compression failed" end
    local encoded = LD:EncodeForPrint(compressed)
    if not encoded then return nil, "Encoding failed" end
    return EXPORT_PREFIX .. encoded
end

local function DecodeData(importString)
    if not importString or importString == "" then return nil, "Import string is empty" end
    if importString:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then return nil, "Invalid format" end
    local compressed = LD:DecodeForPrint(importString:sub(#EXPORT_PREFIX + 1))
    if not compressed then return nil, "Decoding failed" end
    local serialized = LD:DecompressDeflate(compressed)
    if not serialized then return nil, "Decompression failed" end
    local success, data = AS:Deserialize(serialized)
    if not success or type(data) ~= "table" then return nil, "Deserialization failed" end
    return data
end

---@param groupName string
---@return string|nil exportString
---@return string|nil error
function MITEMS:ExportGroup(groupName)
    self:UpdateDB()
    if not self.db then return nil, "Database not initialized" end

    local groups = self.db.Groups or {}
    if not tContains(groups, groupName) then return nil, "Group not found" end

    local items = self.db.Items or {}
    local exportItems = {}

    for itemID, itemSettings in pairs(items) do
        local itemGroups = itemSettings.groups or {}
        if tContains(itemGroups, groupName) then
            exportItems[itemID] = {
                threshold = itemSettings.threshold,
                enabled = itemSettings.enabled,
                color = itemSettings.color and CopyTable(itemSettings.color) or nil,
            }
        end
    end

    return EncodeData({ _v = 1, _t = time(), groupName = groupName, items = exportItems, })
end

---@param importString string
---@param newGroupName? string
---@return boolean success
---@return string message
function MITEMS:ImportGroup(importString, newGroupName)
    self:UpdateDB()
    if not self.db then return false, "Database not initialized" end

    local data, err = DecodeData(importString)
    if not data then return false, err end

    if not data.groupName or not data.items then
        return false, "Invalid import data"
    end

    local groupName = newGroupName or data.groupName
    self.db.Groups = self.db.Groups or {}
    self.db.Items = self.db.Items or {}

    if not tContains(self.db.Groups, groupName) then
        table_insert(self.db.Groups, groupName)
    end

    local importCount, updateCount = 0, 0

    for itemID, itemSettings in pairs(data.items) do
        local numericID = tonumber(itemID)
        if numericID and type(itemSettings) == "table" then
            local existing = self.db.Items[numericID]

            if existing then
                local itemGroups = existing.groups or {}
                if not tContains(itemGroups, groupName) then
                    table_insert(itemGroups, groupName)
                    existing.groups = itemGroups
                    updateCount = updateCount + 1
                end
            else
                self.db.Items[numericID] = {
                    threshold = itemSettings.threshold or 0,
                    enabled = itemSettings.enabled ~= false,
                    color = itemSettings.color and CopyTable(itemSettings.color) or nil,
                    groups = { groupName },
                }
                importCount = importCount + 1
            end
        end
    end

    local result = importCount .. " item(s) imported"
    if updateCount > 0 then
        result = result .. ", " .. updateCount .. " existing item(s) added to group"
    end

    return true, result
end
