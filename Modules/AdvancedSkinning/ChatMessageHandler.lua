---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class ChatMessageHandler
local CMH = {}
NRSKNUI.ChatMessageHandler = CMH

local _G = _G
local format = format
local strsub = strsub
local strlower = strlower
local strupper = strupper
local tostring = tostring
local strlen = strlen
local gsub = gsub
local pairs = pairs
local next = next
local pcall = pcall
local GetCVar = GetCVar
local GetCVarBool = C_CVar and C_CVar.GetCVarBool or GetCVarBool
local Ambiguate = Ambiguate
local GetPlayerInfoByGUID = GetPlayerInfoByGUID
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local FlashClientIcon = FlashClientIcon
local BNGetNumFriendInvites = BNGetNumFriendInvites
local wipe = wipe
local gmatch = gmatch
local tonumber = tonumber
local GetChannelShortcutForChannelID = GetChannelShortcutForChannelID
local IsChannelRegionalForChannelID = IsChannelRegionalForChannelID
local GetChatCategory = Chat_GetChatCategory or ChatFrame_GetChatCategory or GetChatCategory
local RemoveExtraSpaces = RemoveExtraSpaces
local RemoveNewlines = RemoveNewlines
local GMChatFrame_IsGM = GMChatFrame_IsGM
local C_ClassColor_GetClassColor = C_ClassColor and C_ClassColor.GetClassColor
local IsChatLineCensored = C_ChatInfo and C_ChatInfo.IsChatLineCensored
local SafePack = SafePack

local ChatEditSetLastTellTarget = (ChatFrameUtil and ChatFrameUtil.SetLastTellTarget) or ChatEdit_SetLastTellTarget
local ShouldColorChatByClass = (ChatFrameUtil and ChatFrameUtil.ShouldColorChatByClass) or Chat_ShouldColorChatByClass or function(info) return info and info.colorNameByClass end
local ResolvePrefixedChannelName = (ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName) or
    ChatFrame_ResolvePrefixedChannelName
local GetMobileEmbeddedTexture = (ChatFrameUtil and ChatFrameUtil.GetMobileEmbeddedTexture) or
    ChatFrame_GetMobileEmbeddedTexture

local UNKNOWN = UNKNOWN

local accessIndex = 1
local accessInfo = {}
local accessType = {}
local accessTarget = {}
local accessSender = {}

local function GetToken(chatType, chatTarget, chanSender)
    return format('%s;;%s;;%s', strlower(chatType), chatTarget or '', chanSender or '')
end

function CMH:GetAccessID(chatType, chatTarget, chanSender)
    local token = GetToken(chatType, chatTarget, chanSender)

    if NRSKNUI:IsSecretValue(token) then return end

    if not accessInfo[token] then
        accessInfo[token] = accessIndex
        accessType[accessIndex] = chatType
        accessTarget[accessIndex] = chatTarget
        accessSender[accessIndex] = chanSender
        accessIndex = accessIndex + 1
    end

    return accessInfo[token]
end

function CMH:GetAccessType(accessID)
    return accessType[accessID], accessTarget[accessID], accessSender[accessID]
end

function CMH:GetAllAccessIDsByChanSender(chanSender)
    local senders = {}
    local chanSenderLower = strlower(chanSender)
    for accessID, sender in next, accessSender do
        if strlower(sender) == chanSenderLower then
            senders[#senders + 1] = accessID
        end
    end
    return senders
end

-- Player link functions
local function GetLink(linkType, displayText, ...)
    local text = ''
    for i, value in next, { ... } do text = text .. (i == 1 and format('|H%s:', linkType) or ':') .. value end
    return text .. (displayText and format('|h%s|h', displayText) or '|h')
end

function CMH:GetPlayerLink(characterName, displayText, lineID, chatType, chatTarget)
    if lineID or chatType or chatTarget then
        return GetLink('player', displayText, characterName, lineID or 0, chatType or 0,
            NRSKNUI:NotSecretValue(chatTarget) and chatTarget or '')
    else
        return GetLink('player', displayText, characterName)
    end
end

function CMH:GetBNPlayerLink(name, displayText, bnetIDAccount, lineID, chatType, chatTarget)
    return GetLink('BNplayer', displayText, name, bnetIDAccount, lineID or 0, chatType, chatTarget)
end

-- Secret-safe chat target
function CMH:FCFManager_GetChatTarget(chatGroup, playerTarget, channelTarget)
    local chatTarget
    if chatGroup == 'CHANNEL' then
        chatTarget = tostring(channelTarget)
    elseif chatGroup == 'WHISPER' or chatGroup == 'BN_WHISPER' then
        chatTarget = NRSKNUI:NotSecretValue(playerTarget) and strsub(playerTarget, 1, 2) ~= '|K' and
            strupper(playerTarget) or playerTarget
    end
    return chatTarget
end

-- Flash tab for new messages
local function FlashTabIfNotShown(frame, info, chatType, chatGroup, chatTarget)
    if frame:IsShown() then return end

    local allowAlerts = ((frame ~= _G.DEFAULT_CHAT_FRAME and info.flashTab) or (frame == _G.DEFAULT_CHAT_FRAME and info.flashTabOnGeneral)) and
        ((chatType == 'WHISPER' or chatType == 'BN_WHISPER') or (_G.CHAT_OPTIONS and not _G.CHAT_OPTIONS.HIDE_FRAME_ALERTS))
    if allowAlerts and NRSKNUI:NotSecretValue(chatTarget) and not _G.FCFManager_ShouldSuppressMessageFlash(frame, chatGroup, chatTarget) then
        _G.FCF_StartAlertFlash(frame)
    end
end

-- Get class-colored name
function CMH:GetColoredName(event, _, arg2, _, _, _, _, _, arg8, _, _, _, arg12)
    if NRSKNUI:IsSecretValue(arg12) then
        local _, englishClass = GetPlayerInfoByGUID(arg12)
        if englishClass and C_ClassColor_GetClassColor then
            local classColor = C_ClassColor_GetClassColor(englishClass)
            return (classColor and classColor:WrapTextInColorCode(arg2)) or arg2
        end
        return arg2
    elseif NRSKNUI:IsSecretValue(arg2) then
        return arg2
    end

    if not arg2 then return end

    local chatType = strsub(event, 10)
    local subType = strsub(chatType, 1, 7)
    if subType == 'WHISPER' then
        chatType = 'WHISPER'
    elseif subType == 'CHANNEL' then
        chatType = 'CHANNEL' .. arg8
    end

    local name = Ambiguate(arg2, (chatType == 'GUILD' and 'guild') or 'none')

    local info = name and arg12 and _G.ChatTypeInfo[chatType]
    if info and ShouldColorChatByClass and ShouldColorChatByClass(info) then
        local _, englishClass = GetPlayerInfoByGUID(arg12)
        if englishClass then
            local classColor = C_ClassColor_GetClassColor and C_ClassColor_GetClassColor(englishClass)
            if classColor then
                return classColor:WrapTextInColorCode(name)
            end
        end
    end

    return name
end

-- Get player flags
function CMH:GetPFlag(specialFlag, zoneChannelID, unitGUID)
    local flag = ''

    if specialFlag and specialFlag ~= '' then
        if specialFlag == 'GM' or specialFlag == 'DEV' then
            flag = '|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:12:20:0:0:32:16:4:28:0:16|t '
        elseif specialFlag == 'GUIDE' then
            flag = '|TInterface\\ChatFrame\\UI-ChatIcon-Guide:12:12:0:0|t '
        elseif specialFlag == 'NEWCOMER' then
            flag = '|TInterface\\ChatFrame\\UI-ChatIcon-Newcomer:12:12:0:0|t '
        end
    end

    return flag
end

-- Check if channel should be added
local function ChatFrame_CheckAddChannel(frame, eventType, channelID)
    if frame ~= _G.DEFAULT_CHAT_FRAME then return false end
    if NRSKNUI:IsSecretValue(eventType) then return false end
    if eventType ~= "YOU_CHANGED" then return false end
    if not IsChannelRegionalForChannelID or not IsChannelRegionalForChannelID(channelID) then return false end

    if frame.AddChannel then
        return frame:AddChannel(GetChannelShortcutForChannelID(channelID)) ~= nil
    elseif _G.ChatFrame_AddChannel then
        return _G.ChatFrame_AddChannel(frame, GetChannelShortcutForChannelID(channelID)) ~= nil
    end
    return false
end

-- Safe zone channel access
function CMH:ChatFrame_GetZoneChannel(frame, index)
    return frame.zoneChannelList and frame.zoneChannelList[index]
end

-- Icon replacement
local seenGroups = {}
function CMH:ChatFrame_ReplaceIconAndGroupExpressions(message, noIconReplacement, noGroupReplacement)
    if not message then return message end

    local ICON_LIST = _G.ICON_LIST
    local ICON_TAG_LIST = _G.ICON_TAG_LIST
    local GROUP_TAG_LIST = _G.GROUP_TAG_LIST

    if not ICON_LIST or not ICON_TAG_LIST then return message end

    wipe(seenGroups)

    for tag in gmatch(message, '%b{}') do
        local term = strlower(gsub(tag, '[{}]', ''))
        if not noIconReplacement and ICON_TAG_LIST[term] and ICON_LIST[ICON_TAG_LIST[term]] then
            message = gsub(message, tag, ICON_LIST[ICON_TAG_LIST[term]] .. '0|t')
        elseif not noGroupReplacement and GROUP_TAG_LIST and GROUP_TAG_LIST[term] then
            local groupIndex = GROUP_TAG_LIST[term]
            if not seenGroups[groupIndex] then
                seenGroups[groupIndex] = true
                local groupList = '['
                for i = 1, GetNumGroupMembers() do
                    local name, _, subgroup, _, _, classFilename = GetRaidRosterInfo(i)
                    if name and subgroup == groupIndex then
                        local classColor = C_ClassColor_GetClassColor and C_ClassColor_GetClassColor(classFilename)
                        if classColor then
                            name = classColor:WrapTextInColorCode(name)
                        end
                        groupList = groupList .. (groupList == '[' and '' or _G.PLAYER_LIST_DELIMITER) .. name
                    end
                end
                if groupList ~= '[' then
                    groupList = groupList .. ']'
                    message = gsub(message, tag, groupList, 1)
                end
            end
        end
    end

    return message
end

-- Message formatter, formats the message body
function CMH:MessageFormatter(frame, info, chatType, chatGroup, chatTarget, channelLength, coloredName, arg1, arg2, arg3,
                              arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17)
    local body

    -- Only return early if message itself is nil
    if not arg1 then return end

    if chatType == 'WHISPER_INFORM' and GMChatFrame_IsGM and GMChatFrame_IsGM(arg2) then return end

    -- Check if message content is protected
    local isProtected = NRSKNUI:IsSecretValue(arg1)
    local bossMonster = strsub(chatType, 1, 9) == 'RAID_BOSS' or strsub(chatType, 1, 7) == 'MONSTER'

    -- Protected boss messages can't be safely formatted, skip custom formatting
    if isProtected and bossMonster then return end

    if bossMonster and not isProtected then
        arg1 = gsub(arg1, '(%d%s?%%)([^%%%a])', '%1%%%2')
        arg1 = gsub(arg1, '(%d%s?%%)$', '%1%%')
    end

    if not isProtected then
        if RemoveExtraSpaces then arg1 = RemoveExtraSpaces(arg1) end

        if _G.ChatFrameUtil and _G.ChatFrameUtil.CanChatGroupPerformExpressionExpansion then
            arg1 = self:ChatFrame_ReplaceIconAndGroupExpressions(arg1, arg17,
                not _G.ChatFrameUtil.CanChatGroupPerformExpressionExpansion(chatGroup))
        elseif _G.ChatFrame_CanChatGroupPerformExpressionExpansion then
            arg1 = self:ChatFrame_ReplaceIconAndGroupExpressions(arg1, arg17,
                not _G.ChatFrame_CanChatGroupPerformExpressionExpansion(chatGroup))
        end
    end

    -- Player link, use fallbacks for nil values
    coloredName = coloredName or arg2 or UNKNOWN
    local playerLink
    local playerLinkDisplayText = coloredName
    local relevantDefaultLanguage = frame.defaultLanguage
    if chatType == 'SAY' or chatType == 'YELL' then relevantDefaultLanguage = frame.alternativeDefaultLanguage end
    local usingDifferentLanguage = (arg3 and arg3 ~= '') and (arg3 ~= relevantDefaultLanguage)
    local usingEmote = (chatType == 'EMOTE') or (chatType == 'TEXT_EMOTE')

    if usingDifferentLanguage or not usingEmote then playerLinkDisplayText = format('[%s]', coloredName) end

    local playerName = arg2 or UNKNOWN
    if chatType == 'BN_WHISPER' or chatType == 'BN_WHISPER_INFORM' then
        playerLink = self:GetBNPlayerLink(playerName, playerLinkDisplayText, arg13, arg11, chatGroup, chatTarget)
    elseif not bossMonster then
        playerLink = self:GetPlayerLink(playerName, playerLinkDisplayText, arg11, chatGroup, chatTarget)
    end

    -- Ensure we have valid values for formatting
    local sender = (not bossMonster and playerLink) or arg2 or UNKNOWN
    local isMobile = arg14 and GetMobileEmbeddedTexture and GetMobileEmbeddedTexture(info.r, info.g, info.b)
    local message = format('%s%s', isMobile or '', arg1 or '')

    local pflag = self:GetPFlag(arg6, arg7, arg12) or ''

    local chatFormat = _G['CHAT_' .. chatType .. '_GET']
    if not chatFormat then return message end

    if usingDifferentLanguage then
        body = format(chatFormat .. '[%s] %s', pflag .. sender, arg3 or '', message)
    elseif chatType == 'TEXT_EMOTE' then
        body = message
    elseif bossMonster then
        body = format(chatFormat .. message, pflag .. sender, sender)
    else
        body = format(chatFormat .. '%s', pflag .. sender, message)
    end

    if channelLength and channelLength > 0 and arg8 and arg4 then
        body = '|Hchannel:channel:' .. arg8 .. '|h[' .. ResolvePrefixedChannelName(arg4) .. ']|h ' .. body
    end

    return body
end

-- Main message event handler
function CMH:ChatFrame_MessageEventHandler(frame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10,
                                           arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18)
    if not event then return true end

    local isProtected = NRSKNUI:IsSecretValue(arg2)

    -- Text to speech
    if _G.TextToSpeechFrame_MessageEventHandler then
        _G.TextToSpeechFrame_MessageEventHandler(frame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9,
            arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18)
    end

    if strsub(event, 1, 8) == 'CHAT_MSG' then
        if arg16 then return true end -- hiding sender in letterbox

        local chatType = strsub(event, 10)
        local info = _G.ChatTypeInfo[chatType]
        if not info then return end
        if arg6 == 'GM' and chatType == 'WHISPER' then return end

        -- Process message filters
        if _G.ChatFrameUtil and _G.ChatFrameUtil.ProcessMessageEventFilters then
            local filtered, new1, new2, new3, new4, new5, new6, new7, new8, new9, new10, new11, new12, new13, new14, new15, new16, new17 =
                _G.ChatFrameUtil.ProcessMessageEventFilters(frame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8,
                    arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17)
            if filtered then
                return true
            else
                arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17 =
                    new1, new2, new3, new4, new5, new6, new7, new8, new9, new10, new11, new12, new13, new14, new15, new16,
                    new17
            end
        elseif _G.ChatFrame_GetMessageEventFilters then
            local chatFilters = _G.ChatFrame_GetMessageEventFilters(event)
            if chatFilters then
                for _, filterFunc in next, chatFilters do
                    local filtered, new1, new2, new3, new4, new5, new6, new7, new8, new9, new10, new11, new12, new13, new14, new15, new16, new17 =
                        filterFunc(frame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11,
                            arg12,
                            arg13, arg14, arg15, arg16, arg17)
                    if filtered then
                        return true
                    elseif new1 then
                        arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17 =
                            new1, new2, new3, new4, new5, new6, new7, new8, new9, new10, new11, new12, new13, new14,
                            new15,
                            new16, new17
                    end
                end
            end
        end

        local coloredName = self:GetColoredName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11,
            arg12, arg13, arg14)
        local channelLength = strlen(arg4 or '')
        local infoType = chatType

        -- Voice text check
        if chatType == 'VOICE_TEXT' and not GetCVarBool('speechToText') then return true end

        -- Channel handling
        if chatType == 'COMMUNITIES_CHANNEL' or ((strsub(chatType, 1, 7) == 'CHANNEL') and (chatType ~= 'CHANNEL_LIST') and ((NRSKNUI:NotSecretValue(arg1) and arg1 ~= 'INVITE') or (chatType ~= 'CHANNEL_NOTICE_USER'))) then
            if NRSKNUI:NotSecretValue(arg1) and arg1 == 'WRONG_PASSWORD' then
                local _, popup = _G.StaticPopup_Visible('CHAT_CHANNEL_PASSWORD')
                if popup and strupper(popup.data) == strupper(arg9) then
                    return true
                end
            end

            local found = false
            if frame.channelList and NRSKNUI:NotSecretValue(arg9) then
                for index, value in pairs(frame.channelList) do
                    if channelLength > strlen(value) then
                        local match = strupper(value) == strupper(arg9)
                        if not match then
                            local success, zoneChannel = pcall(self.ChatFrame_GetZoneChannel, self, frame, index)
                            match = success and arg7 and arg7 > 0 and arg7 == zoneChannel
                        end

                        if match then
                            found = true
                            infoType = 'CHANNEL' .. arg8
                            info = _G.ChatTypeInfo[infoType]

                            if chatType == 'CHANNEL_NOTICE' and NRSKNUI:NotSecretValue(arg1) and arg1 == 'YOU_LEFT' then
                                frame.channelList[index] = nil
                                if frame.zoneChannelList then frame.zoneChannelList[index] = nil end
                            end

                            break
                        end
                    end
                end
            end

            if not found or not info then
                local eventType, channelID = arg1, arg7
                if not ChatFrame_CheckAddChannel(frame, eventType, channelID) then return true end
            end
        end

        local chatGroup = GetChatCategory and GetChatCategory(chatType) or chatType
        local chatTarget = self:FCFManager_GetChatTarget(chatGroup, arg2, arg8)

        if chatTarget and NRSKNUI:NotSecretValue(chatTarget) and _G.FCFManager_ShouldSuppressMessage then
            local success, shouldSuppress = pcall(_G.FCFManager_ShouldSuppressMessage, frame, chatGroup, chatTarget)
            if success and shouldSuppress then
                return true
            end
        end

        -- Whisper filtering
        if not isProtected and (chatGroup == 'WHISPER' or chatGroup == 'BN_WHISPER') and NRSKNUI:NotSecretValue(arg2) then
            local nameLower = strlower(arg2)
            if frame.privateMessageList and not frame.privateMessageList[nameLower] then
                return true
            elseif frame.excludePrivateMessageList and frame.excludePrivateMessageList[nameLower] then
                if GetCVar('whisperMode') ~= 'popout_and_inline' then return true end
            end
        end

        -- System messages for dedicated whisper windows
        if frame.privateMessageList then
            if chatGroup == 'SYSTEM' then
                local msg = NRSKNUI:NotSecretValue(arg1) and strlower(arg1)
                local found = false
                if msg then
                    for playerName in pairs(frame.privateMessageList) do
                        local notFound = strlower(format(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, playerName))
                        local charOnline = strlower(format(_G.ERR_FRIEND_ONLINE_SS, playerName, playerName))
                        local charOffline = strlower(format(_G.ERR_FRIEND_OFFLINE_S, playerName))
                        if msg == notFound or msg == charOnline or msg == charOffline then
                            found = true
                            break
                        end
                    end
                end

                if not found then return true end
            elseif not isProtected and (chatGroup == 'BN_INLINE_TOAST_ALERT' or chatGroup == 'BN_WHISPER_PLAYER_OFFLINE') and NRSKNUI:NotSecretValue(arg2) then
                local nameLower = strlower(arg2)
                if not frame.privateMessageList[nameLower] then return true end
            end
        end

        -- Handle different message types
        if (chatType == 'SYSTEM' or chatType == 'SKILL' or chatType == 'CURRENCY' or chatType == 'MONEY' or
                chatType == 'OPENING' or chatType == 'TRADESKILLS' or chatType == 'PET_INFO' or chatType == 'TARGETICONS' or chatType == 'BN_WHISPER_PLAYER_OFFLINE') then
            frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
        elseif chatType == 'LOOT' then
            frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
        elseif strsub(chatType, 1, 7) == 'COMBAT_' then
            frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
        elseif strsub(chatType, 1, 6) == 'SPELL_' then
            frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
        elseif strsub(chatType, 1, 10) == 'BG_SYSTEM_' then
            frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
        elseif strsub(chatType, 1, 11) == 'ACHIEVEMENT' then
            if NRSKNUI:NotSecretValue(arg1) and NRSKNUI:NotSecretValue(arg2) then
                frame:AddMessage(format(arg1, self:GetPlayerLink(arg2, format('[%s]', coloredName or arg2))), info.r,
                    info.g, info.b, info.id)
            end
        elseif strsub(chatType, 1, 18) == 'GUILD_ACHIEVEMENT' then
            if NRSKNUI:NotSecretValue(arg1) and NRSKNUI:NotSecretValue(arg2) then
                frame:AddMessage(format(arg1, self:GetPlayerLink(arg2, format('[%s]', coloredName or arg2))), info.r,
                    info.g, info.b, info.id)
            end
        elseif chatType == 'PING' then
            frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
        elseif chatType == 'IGNORED' then
            if NRSKNUI:NotSecretValue(arg2) then
                frame:AddMessage(format(_G.CHAT_IGNORED, arg2), info.r, info.g, info.b, info.id)
            end
        elseif chatType == 'FILTERED' then
            if NRSKNUI:NotSecretValue(arg2) then
                frame:AddMessage(format(_G.CHAT_FILTERED, arg2), info.r, info.g, info.b, info.id)
            end
        elseif chatType == 'RESTRICTED' then
            frame:AddMessage(_G.CHAT_RESTRICTED_TRIAL, info.r, info.g, info.b, info.id)
        elseif chatType == 'CHANNEL_LIST' then
            if channelLength > 0 then
                frame:AddMessage(format(_G['CHAT_' .. chatType .. '_GET'] .. arg1, tonumber(arg8), arg4), info.r, info.g,
                    info.b, info.id)
            else
                frame:AddMessage(arg1, info.r, info.g, info.b, info.id)
            end
        elseif chatType == 'CHANNEL_NOTICE_USER' then
            local globalstring = NRSKNUI:NotSecretValue(arg1) and
                (_G['CHAT_' .. arg1 .. '_NOTICE_BN'] or _G['CHAT_' .. arg1 .. '_NOTICE'])
            if not globalstring then return true end

            if arg5 ~= '' then
                frame:AddMessage(format(globalstring, arg8, arg4, arg2, arg5), info.r, info.g, info.b, info.id)
            elseif arg1 == 'INVITE' then
                frame:AddMessage(format(globalstring, arg4, arg2), info.r, info.g, info.b, info.id)
            else
                frame:AddMessage(format(globalstring, arg8, arg4, arg2), info.r, info.g, info.b, info.id)
            end

            if arg1 == 'INVITE' and GetCVarBool('blockChannelInvites') then
                frame:AddMessage(_G.CHAT_MSG_BLOCK_CHAT_CHANNEL_INVITE, info.r, info.g, info.b, info.id)
            end
        elseif chatType == 'CHANNEL_NOTICE' then
            if NRSKNUI:IsSecretValue(arg1) then
                return true
            else
                local globalstring = _G['CHAT_' .. arg1 .. '_NOTICE_TRIAL'] or _G['CHAT_' .. arg1 .. '_NOTICE_BN'] or
                    _G['CHAT_' .. arg1 .. '_NOTICE']
                if not globalstring then return true end

                local accessID = self:GetAccessID(chatGroup, arg8)
                local typeID = self:GetAccessID(infoType, arg8, arg12)
                frame:AddMessage(format(globalstring, arg8, ResolvePrefixedChannelName(arg4)), info.r, info.g, info.b,
                    info.id, accessID, typeID)
            end
        elseif chatType == 'BN_INLINE_TOAST_ALERT' then
            local globalstring = NRSKNUI:NotSecretValue(arg1) and _G['BN_INLINE_TOAST_' .. arg1]
            if not globalstring then return true end

            local message
            local arg2Safe = NRSKNUI:NotSecretValue(arg2) and arg2 or UNKNOWN
            if arg1 == 'FRIEND_REQUEST' then
                message = globalstring
            elseif arg1 == 'FRIEND_PENDING' then
                message = format(_G.BN_INLINE_TOAST_FRIEND_PENDING, BNGetNumFriendInvites())
            elseif arg1 == 'FRIEND_REMOVED' or arg1 == 'BATTLETAG_FRIEND_REMOVED' then
                message = format(globalstring, arg2Safe)
            elseif arg1 == 'FRIEND_ONLINE' or arg1 == 'FRIEND_OFFLINE' then
                local linkDisplayText = format('[%s]', arg2Safe)
                local playerLink = self:GetBNPlayerLink(arg2Safe, linkDisplayText, arg13, arg11, chatGroup, 0)
                message = format(globalstring, playerLink)
            else
                local linkDisplayText = format('[%s]', arg2Safe)
                local playerLink = self:GetBNPlayerLink(arg2Safe, linkDisplayText, arg13, arg11, chatGroup, 0)
                message = format(globalstring, playerLink)
            end

            frame:AddMessage(message, info.r, info.g, info.b, info.id)
        elseif chatType == 'BN_INLINE_TOAST_BROADCAST' then
            if NRSKNUI:NotSecretValue(arg1) and arg1 ~= '' then
                if RemoveNewlines then arg1 = RemoveNewlines(RemoveExtraSpaces(arg1)) end

                local arg2Safe = NRSKNUI:NotSecretValue(arg2) and arg2 or UNKNOWN
                local linkDisplayText = format('[%s]', arg2Safe)
                local playerLink = self:GetBNPlayerLink(arg2Safe, linkDisplayText, arg13, arg11, chatGroup, 0)
                frame:AddMessage(format(_G.BN_INLINE_TOAST_BROADCAST, playerLink, arg1), info.r, info.g, info.b, info.id)
            end
        elseif chatType == 'BN_INLINE_TOAST_BROADCAST_INFORM' then
            if NRSKNUI:NotSecretValue(arg1) and arg1 ~= '' then
                frame:AddMessage(_G.BN_INLINE_TOAST_BROADCAST_INFORM,
                    info.r, info.g, info.b, info.id)
            end
        else
            -- Default case, regular chat messages including whispers
            -- Check if this message is censored and prepare formatter for "Show Message" click
            local isChatLineCensored, eventArgs, msgFormatter = IsChatLineCensored and IsChatLineCensored(arg11)
            if isChatLineCensored then
                eventArgs = SafePack(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18)

                msgFormatter = function(msg)
                    return self:MessageFormatter(frame, info, chatType, chatGroup, chatTarget, channelLength, coloredName,
                        msg, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17)
                end
            end

            local accessID = self:GetAccessID(chatGroup, chatTarget)
            local typeID = self:GetAccessID(infoType, chatTarget, arg12 or arg13)
            local body = isChatLineCensored and arg1 or self:MessageFormatter(frame, info, chatType, chatGroup, chatTarget, channelLength, coloredName,
                arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16,
                arg17)

            if body then frame:AddMessage(body, info.r, info.g, info.b, info.id, accessID, typeID, event, eventArgs, msgFormatter) end
        end

        -- Whisper-specific handling
        if (chatType == 'WHISPER' or chatType == 'BN_WHISPER') then
            if not isProtected then ChatEditSetLastTellTarget(arg2, chatType) end
            if FlashClientIcon then FlashClientIcon() end
        end

        FlashTabIfNotShown(frame, info, chatType, chatGroup, chatTarget)

        return true
    elseif event == 'VOICE_CHAT_CHANNEL_TRANSCRIBING_CHANGED' then
        if not frame.isTranscribing and arg2 then
            local info = _G.ChatTypeInfo.SYSTEM
            frame:AddMessage(_G.SPEECH_TO_TEXT_STARTED, info.r, info.g, info.b, info.id)
        end
        frame.isTranscribing = arg2
        return true
    end
end

-- Config event handler
function CMH:ChatFrame_ConfigEventHandler(frame, event, ...)
    local ConfigEventHandler = _G.ChatFrameMixin and _G.ChatFrameMixin.ConfigEventHandler or
        _G.ChatFrame_ConfigEventHandler
    if ConfigEventHandler then return ConfigEventHandler(frame, event, ...) end
end

-- System event handler
function CMH:ChatFrame_SystemEventHandler(frame, event, ...)
    local SystemEventHandler = _G.ChatFrameMixin and _G.ChatFrameMixin.SystemEventHandler or
        _G.ChatFrame_SystemEventHandler
    if SystemEventHandler then return SystemEventHandler(frame, event, ...) end
end

-- Main OnEvent handler
function CMH:ChatFrame_OnEvent(frame, event, ...)
    if frame.customEventHandler and frame:customEventHandler(event, ...) then return true end
    if self:ChatFrame_ConfigEventHandler(frame, event, ...) then return true end
    if self:ChatFrame_SystemEventHandler(frame, event, ...) then return true end
    if self:ChatFrame_MessageEventHandler(frame, event, ...) then return true end
    return false
end

-- Floating chat frame OnEvent
function CMH:FloatingChatFrame_OnEvent(...)
    self:ChatFrame_OnEvent(...)
end
