-- NorskenUI namespace
local _, NRSKNUI = ...

-- Module from p3lim

local assert = assert
local type = type
local select = select
local debugstack = debugstack
local error = error
local next = next
local CreateFromMixins = CreateFromMixins
local getmetatable, setmetatable = getmetatable, setmetatable
local rawset = rawset
local strlenutf8 = strlenutf8

function NRSKNUI:ArgCheck(arg, argIndex, ...)
    assert(type(argIndex) == 'number', 'Bad argument #2 to \'ArgCheck\' (number expected, got ' .. type(argIndex) .. ')')

    for index = 1, select('#', ...) do
        if type(arg) == select(index, ...) then
            return
        end
    end

    local types = string.join(', ', ...)
    local name = debugstack(2, 2, 0):match(': in function [`<](.-)[\'>]')
    error(string.format('Bad argument #%d to \'%s\' (%s expected, got %s)', argIndex, name, types, type(arg)), 3)
end

function NRSKNUI:tsize(tbl)
    -- would really like Lua 5.2 for this
    local size = 0
    if tbl then
        for _ in next, tbl do
            size = size + 1
        end
    end
    return size
end

function NRSKNUI:startswith(str, contents)
    return str:sub(1, contents:len()) == contents
end

do
    local tableMethods = CreateFromMixins(table)
    function tableMethods:size()
        return NRSKNUI:tsize(self)
    end

    function tableMethods:merge(tbl)
        NRSKNUI:ArgCheck(tbl, 1, 'table')

        for k, v in next, tbl do
            if type(self[k] or false) == 'table' then
                tableMethods.merge(self[k], tbl[k])
            else
                self[k] = v
            end
        end

        return self
    end

    function tableMethods:contains(value)
        for _, v in next, self do
            if value == v then
                return true
            end
        end

        return false
    end

    function tableMethods:random()
        local size = self:size()
        if size > 0 then
            return self[math.random(size)]
        end
    end

    function tableMethods:copy(shallow)
        local tbl = NRSKNUI:T()
        for k, v in next, self do
            if type(v) == 'table' and not shallow then
                tbl[k] = tableMethods.copy(v)
            else
                tbl[k] = v
            end
        end
        return tbl
    end

    -- remove obsolete and deprecated methods present in the table library
    -- https://warcraft.wiki.gg/wiki/Lua_functions#Deprecated_functions
    tableMethods.foreach = nil
    tableMethods.foreachi = nil
    tableMethods.getn = nil
    tableMethods.setn = nil

    local function newIndex(self, key, value)
        -- turn child tables into this metatable too
        if type(value) == 'table' and not getmetatable(value) then
            rawset(self, key, NRSKNUI:T(value))
        else
            rawset(self, key, value)
        end
    end

    function NRSKNUI:T(tbl)
        NRSKNUI:ArgCheck(tbl, 1, 'table', 'nil')

        return setmetatable(tbl or {}, {
            __index = tableMethods,
            __newindex = newIndex,
            __add = tableMethods.merge,
        })
    end
end

do
    -- cherry-picked from Phanx's implementation back in 2007, I'm sure
    -- they'd be fine with me borrowing it like this after all these years
    local function utf8bytes(str, pos)
        -- count the number of bytes based on the character
        if not pos then
            pos = 1
        end

        local byte1 = str:byte(pos)
        if byte1 > 0 and byte1 <= 127 then
            -- ASCII
            return 1
        elseif byte1 >= 194 and byte1 <= 223 then
            local byte2 = str:byte(pos + 1)
            if not byte2 then
                error('UTF-8 string terminated early')
            elseif byte2 < 128 or byte2 > 191 then
                error('Invalid UTF-8 character')
            end

            return 2
        elseif byte1 >= 224 and byte1 <= 239 then
            local byte2 = str:byte(pos + 1)
            local byte3 = str:byte(pos + 2)
            if not byte2 or not byte3 then
                error('UTF-8 string terminated early')
            elseif byte1 == 224 and (byte2 < 160 or byte2 > 191) then
                error('Invalid UTF-8 character')
            elseif byte1 == 237 and (byte2 < 128 or byte2 > 159) then
                error('Invalid UTF-8 character')
            elseif byte2 < 128 or byte2 > 191 then
                error('Invalid UTF-8 character')
            elseif byte3 < 128 or byte3 > 191 then
                error('Invalid UTF-8 character')
            end

            return 3
        elseif byte1 >= 240 and byte1 <= 244 then
            local byte2 = str:byte(pos + 1)
            local byte3 = str:byte(pos + 2)
            local byte4 = str:byte(pos + 3)

            if not byte2 or not byte3 or not byte4 then
                error('UTF-8 string terminated early')
            elseif byte1 == 240 and (byte2 < 144 or byte2 > 191) then
                error('Invalid UTF-8 character')
            elseif byte1 == 244 and (byte2 < 128 or byte2 > 143) then
                error('Invalid UTF-8 character')
            elseif byte2 < 128 or byte2 > 191 then
                error('Invalid UTF-8 character')
            elseif byte3 < 128 or byte3 > 191 then
                error('Invalid UTF-8 character')
            elseif byte4 < 128 or byte4 > 191 then
                error('Invalid UTF-8 character')
            end

            return 4
        end

        error('Invalid UTF-8 character')
    end

    function NRSKNUI:sub(str, start, stop)
        NRSKNUI:ArgCheck(str, 1, 'string')
        NRSKNUI:ArgCheck(start, 2, 'number')
        NRSKNUI:ArgCheck(stop, 3, 'number', 'nil')

        if not stop then
            -- default to stop at the end of the string
            stop = -1
        end

        local offset = (start >= 0 and stop >= 0) or strlenutf8(str)
        local startChar = (start >= 0) and start or (offset + start + 1)
        local stopChar = (stop >= 0) and stop or (offset + stop + 1)

        if startChar > stopChar then
            -- can't start before the stop
            return ''
        end

        local bytes = str:len()
        local startByte, stopByte = 1, str:len()
        local pos, len = 1, 0

        while pos <= bytes do
            len = len + 1

            if len == startChar then
                startByte = pos
            end

            pos = pos + utf8bytes(str, pos)

            if len == stopChar then
                stopByte = pos - 1
                break
            end
        end

        return str:sub(startByte, stopByte)
    end
end
