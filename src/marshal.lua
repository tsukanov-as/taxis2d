local marshal = {}

function marshal.Dump(x)
    local t = {}
    if type(x) == "table" then
        if #x > 0 then
            t[#t+1] = "["
            for _, v in ipairs(x) do
                t[#t+1] = marshal.Dump(v)
                t[#t+1] = ","
            end
            t[#t+1] = "]"
        elseif next(x) then
            t[#t+1] = "{"
            for k, v in pairs(x) do
                t[#t+1] = marshal.Dump(k)
                t[#t+1] = ":"
                t[#t+1] = marshal.Dump(v)
                t[#t+1] = ","
            end
            t[#t+1] = "}"
        else
            t[#t+1] = "null"
        end
    elseif type(x) == "string" then
        t[#t+1] = string.format("%q", x)
    elseif type(x) == "number" then
        t[#t+1] = tostring(x)
    elseif type(x) == "boolean" then
        t[#t+1] = '"'..tostring(x)..'"'
    elseif type(x) ~= "function" then
        error("unknown type")
    end
    return table.concat(t)
end

-- http://stackoverflow.com/questions/19961598/substitute-double-backslash-from-input-with-single-backslash-in-lua
local function unbackslashed(s)
    local ch = {
        ["\\a"] = '\\007', --'\a' alarm             Ctrl+G BEL
        ["\\b"] = '\\008', --'\b' backspace         Ctrl+H BS
        ["\\f"] = '\\012', --'\f' formfeed          Ctrl+L FF
        ["\\n"] = '\\010', --'\n' newline           Ctrl+J LF
        ["\\r"] = '\\013', --'\r' carriage return   Ctrl+M CR
        ["\\t"] = '\\009', --'\t' horizontal tab    Ctrl+I HT
        ["\\v"] = '\\011', --'\v' vertical tab      Ctrl+K VT
        ["\\\n"] = '\\010',--     newline
        ["\\\\"] = '\\092',--     backslash
        ["\\'"] = '\\039', --     apostrophe
        ['\\"'] = '\\034', --     quote
    }
    return s:gsub("(\\.)", ch)
        :gsub("\\(%d%d?%d?)", function(n)
            return string.char(tonumber(n))
        end)
end

function marshal.Load(s)

    local c, pos = nil, 0

    local function next(n)
        pos = pos + (n or 1)
        c = s:sub(pos, pos)
    end

    local function skip(x)
        assert(c == x)
        repeat next() until c == '' or c:find("%S")
    end

    next()

    local parse

    local function parse_table()
        local t = {}
        skip('{')
        repeat
            local k = parse()
            skip(':')
            local v = parse()
            skip(',')
            t[k] = v
        until c == '}' or c == ''
        skip('}')
        return t
    end

    local function parse_array()
        local a = {}
        local i = 1
        skip('[')
        repeat
            local v = parse()
            skip(',')
            a[i] = v
            i = i + 1
        until c == ']' or c == ''
        skip(']')
        return a
    end

    local function parse_string()
        skip('"')
        local start = pos
        while c ~= '"' and c ~= '' do
            next()
            if c == '\\' then
                next(2)
            end
        end
        local stop = pos-1
        skip('"')
        return unbackslashed(s:sub(start, stop))
    end

    local function parse_integer()
        repeat
            next()
        until c == '' or c < "0" or "9" < c
    end

    local function parse_number()
        local start = pos
        parse_integer()
        if c == '.' then
            parse_integer()
            if c == 'e' then
                parse_integer()
                if c == '-' then
                    parse_integer()
                end
            end
        end
        local stop = pos-1
        return tonumber(s:sub(start, stop))
    end

    parse = function()
        local res
        if c == '{' then
            res = parse_table()
        elseif c == '[' then
            res = parse_array()
        elseif c == '"' then
            res = parse_string()
        elseif ("0" <= c and c <= "9") or c == '-' then
            res = parse_number()
        elseif s:sub(pos, pos+3) == "true" then
            next(4)
            res = true
        elseif s:sub(pos, pos+4) == "false" then
            next(5)
            res = false
        elseif s:sub(pos, pos+3) == "null" then
            next(4)
            res = {}
        else
            error("unknown symbol")
        end
        return res
    end

    return parse()

end

return marshal