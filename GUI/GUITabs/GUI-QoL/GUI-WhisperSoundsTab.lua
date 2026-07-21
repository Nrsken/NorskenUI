---@class NRSKNUI
local NRSKNUI = select(2, ...)
local GUIFrame = NRSKNUI.GUIFrame
local LSM = NRSKNUI.Libs.LSM
local Theme = NRSKNUI.Theme

local pairs = pairs

GUIFrame:RegisterContent("whisperSounds", function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Miscellaneous.WhisperSounds
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    ---@type Misc?
    local MISC = NRSKNUI:GetModule("Misc", true)
    local manager = GUIFrame:CreateWidgetStateManager()

    local function UpdateAllWidgetStates()
        manager:UpdateAll(db.Enabled)
    end

    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, "Whisper Sound Alerts", yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, "Enable Whisper Sounds", {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if MISC then
                if checked then NRSKNUI:EnableModule("Misc") else NRSKNUI:DisableModule("Misc") end
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = "Whisper Sounds",
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 2
    local card2 = GUIFrame:CreateCard(scrollChild, "Sound Selection", yOffset)
    manager:Register(card2, "all")

    local soundList = { ["None"] = "None" }
    if LSM then
        for name in pairs(LSM:HashTable("sound")) do
            soundList[name] = name
        end
    end

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local whisperDropdown = GUIFrame:CreateDropdown(row2a, "Whisper Sound", {
        options = soundList,
        value = db.WhisperSound,
        labelWidth = 60,
        callback = function(key)
            db.WhisperSound = key
        end
    })
    row2a:AddWidget(whisperDropdown, 0.6)
    manager:Register(whisperDropdown, "all")

    local testWhisperBtn = GUIFrame:CreateButton(row2a, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.WhisperSound
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySafeSound(soundName)
            end
        end,
    })
    row2a:AddWidget(testWhisperBtn, 0.4, nil, 0, -14)
    manager:Register(testWhisperBtn, "all")
    card2:AddRow(row2a, Theme.rowHeight)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeightLast)
    local bnetDropdown = GUIFrame:CreateDropdown(row2b, "Battle.net Whisper Sound", {
        options = soundList,
        value = db.BNetWhisperSound,
        labelWidth = 60,
        callback = function(key)
            db.BNetWhisperSound = key
        end
    })
    row2b:AddWidget(bnetDropdown, 0.6)
    manager:Register(bnetDropdown, "all")

    local testBnetBtn = GUIFrame:CreateButton(row2b, "Test", {
        width = 60,
        height = 24,
        callback = function()
            local soundName = db.BNetWhisperSound
            if soundName and soundName ~= "None" and LSM then
                NRSKNUI:PlaySafeSound(soundName)
            end
        end,
    })
    row2b:AddWidget(testBnetBtn, 0.4, nil, 0, -14)
    manager:Register(testBnetBtn, "all")
    card2:AddRow(row2b, Theme.rowHeightLast, 0)

    yOffset = card2:GetNextOffset()

    UpdateAllWidgetStates()

    return yOffset
end)
