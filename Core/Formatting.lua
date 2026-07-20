---@class NRSKNUI
local NRSKNUI = select(2, ...)

local math_floor = math.floor
local string_format = string.format
local tostring = tostring
local tconcat = table.concat

local enumUp = Enum.NumericRuleFormatRounding.Up
local enumNearest = Enum.NumericRuleFormatRounding.Nearest

local TOKEN_NORMAL, TOKEN_PERCENT, TOKEN_PLACEHOLDER = 0, 1, 2

---Format a duration in seconds into one of the NRSKNUI.TimeFormats styles.
---@param seconds number
---@param format? string A key from NRSKNUI.TimeFormats (defaults to "MM:SS")
---@return string
function NRSKNUI:FormatTime(seconds, format)
    seconds = seconds or 0
    if seconds < 0 then seconds = 0 end

    if format == 'MM:SS.f' then
        -- Sub-second display, so keep the fraction instead of rounding to whole seconds.
        local whole = math_floor(seconds)
        local tenths = math_floor((seconds - whole) * 10)
        return string_format('%02d:%02d.%d', math_floor(whole / 60), whole % 60, tenths)
    end

    local total = math_floor(seconds + 0.5)
    local mins = math_floor(total / 60)
    local secs = total % 60

    if format == 'M:SS' then
        return string_format('%d:%02d', mins, secs)
    elseif format == 'MmSs' then
        return string_format('%02dm %02ds', mins, secs)
    elseif format == 'MmSs_c' then
        if mins > 0 then return string_format('%dm %ds', mins, secs) end
        return string_format('%ds', secs)
    elseif format == 'Ss' then
        return string_format('%ds', total)
    elseif format == 'S' then
        return tostring(total)
    elseif format == 'Smart' then
        if total >= 60 then return string_format('%dm', mins) end
        return string_format('%ds', total)
    end

    return string_format('%02d:%02d', mins, secs)
end

---Turn tokens in a format string into their replacements, idea based on WA patterns where %p becomes a timer.
---@param formatStr string
---@param replacements table<string, string> Token name without the leading "%" -> replacement text, may already contain color codes.
---@param wrapLiteral? fun(text: string): string Wrap each literal run, e.g. to color it, omit to leave literals untouched.
---@return string
function NRSKNUI:FormatTokens(formatStr, replacements, wrapLiteral)
    if not formatStr or formatStr == "" then return "" end

    local result = {}
    local state = TOKEN_NORMAL
    local pos, len = 1, #formatStr
    local literalStart = 1 -- First char of the pending literal run
    local percentStart     -- Position of the '%' that opened the current token attempt
    local nameStart        -- First char of the current token name
    local braced = false

    -- Emit sub(literalStart, endExclusive - 1) as one literal run, color-wrapped if requested.
    local function FlushLiteral(endExclusive)
        if endExclusive > literalStart then
            local text = formatStr:sub(literalStart, endExclusive - 1)
            result[#result + 1] = wrapLiteral and wrapLiteral(text) or text
        end
    end

    while pos <= len do
        local byte = formatStr:byte(pos)

        if state == TOKEN_NORMAL then
            if byte == 37 then -- %
                state = TOKEN_PERCENT
                percentStart = pos
            end
        elseif state == TOKEN_PERCENT then
            if byte == 37 then             -- %% -> a single literal %
                FlushLiteral(percentStart) -- Text before the first %
                literalStart = pos         -- Keep the second % as the start of the next run
                state = TOKEN_NORMAL
            elseif byte == 123 then        -- %{  braced token
                nameStart = pos + 1
                braced = true
                state = TOKEN_PLACEHOLDER
            elseif (byte >= 97 and byte <= 122) or (byte >= 65 and byte <= 90) or (byte >= 48 and byte <= 57) then
                nameStart = pos
                braced = false
                state = TOKEN_PLACEHOLDER
            else
                -- % followed by punctuation/space, the % stays part of the literal run.
                state = TOKEN_NORMAL
            end
        elseif state == TOKEN_PLACEHOLDER then
            local finished, nameEnd, consumeTerminator
            if braced then
                if byte == 125 then -- } closes the braced token
                    finished, nameEnd, consumeTerminator = true, pos - 1, true
                end
            elseif not ((byte >= 97 and byte <= 122) or (byte >= 65 and byte <= 90) or (byte >= 48 and byte <= 57)) then
                finished, nameEnd, consumeTerminator = true, pos - 1, false
            end

            if finished then
                local seg = replacements[formatStr:sub(nameStart, nameEnd)]
                if seg then
                    FlushLiteral(percentStart) -- Text before the token
                    result[#result + 1] = seg
                    literalStart = consumeTerminator and pos + 1 or pos
                end
                -- Unknown token, leave literalStart put so the whole "%name" stays literal

                if not consumeTerminator and byte == 37 then
                    -- The terminator is itself the start of another token
                    state = TOKEN_PERCENT
                    percentStart = pos
                else
                    state = TOKEN_NORMAL
                end
            end
        end

        pos = pos + 1
    end

    -- An unbraced token can run to the end of the string, no terminating char.
    if state == TOKEN_PLACEHOLDER and not braced then
        local seg = replacements[formatStr:sub(nameStart, len)]
        if seg then
            FlushLiteral(percentStart)
            result[#result + 1] = seg
            literalStart = len + 1
        end
    end

    -- Flush any remaining literal run at the end of the string.
    FlushLiteral(len + 1)

    return tconcat(result)
end

-- Aura duration text --

local auraDurationFormatter

---Formatter for aura duration text, tenths + red under 3s, whole seconds under a minute, then m / h.
---@return table formatter A NumericFormatter usable as SetDurationText's `formatter` option.
function NRSKNUI:GetAuraDurationFormatter()
    if auraDurationFormatter then return auraDurationFormatter end

    auraDurationFormatter = C_StringUtil.CreateNumericRuleFormatter()
    auraDurationFormatter:SetBreakpoints({
        {
            threshold = 0,
            format = '|cffff4d4d%0.1f|r',
            components = {
                {
                    step = 0.1,
                    rounding = enumUp,
                },
            },
        },
        {
            threshold = 3,
            format = '%d',
            components = {
                {
                    step = 1,
                    rounding = enumUp
                },
            }
        },
        {
            threshold = 60,
            format = '%dm',
            components = {
                {
                    div = 60,
                    step = 1,
                    rounding = enumNearest
                },
            }
        },
        {
            threshold = 3600,
            format = '%dh',
            components = {
                {
                    div = 3600,
                    step = 1,
                    rounding = enumNearest
                }
            }
        },
    })

    return auraDurationFormatter
end
