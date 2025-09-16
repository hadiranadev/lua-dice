-- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 Hadi Rana

-- dice.lua
-- All dice functionality.

--[[
    n = number of dice.
    m = number of sides. 
    k = flat modifier (add/subtract to roll)
    d% = percentile dice
]]

local Dice = {}

-- Helper function
-- Trim, parse sign, detect ndm/dm/k/d%
local function parse_single_term(s)

    -- Remove spaces and lowercase
    s = (s:gsub("%s+", ""))
    if s == "" then return nil, "Empty term" end
    s = s:lower()

    -- Grab sign (+/-)
    local sign = 1
    local first = s:sub(1,1)
    if first == "-" then -- Negative
        sign = -1
        s = s:sub(2) -- Chop off sign.
    elseif first == "+" then -- Positive
        s = s:sub(2) -- Chop off sign.
    end

    -- Percentile shorthand matching (%d = d100 )
    if s:match("^d(%%)$") then 
        return {kind = "dice", n = 1, m = 100, sign = sign} 
    end

    -- ndm matching
    local n, m = s:match("^(%d+)d(%d+)$") -- capture n, m.
    if n and m then 
        n, m = tonumber(n), tonumber(m) -- String -> int
        -- Logic errors.
        if n < 1 then return nil, "Dice count must be >= 1." end
        if m < 2 then return nil, "Die sides must be >= 2." end
        return {kind = "dice", n = n, m = m, sign = sign}
    end

    -- dm matching (1 die, m sides)
    local only_m = s:match("^d(%d+)$") -- Capture m
    if only_m then
        local m2 = tonumber(only_m)
        if m2 < 2 then return nil, "Die sides must be >= 2." end
        return {kind = "dice", n = 1, m = m2, sign = sign}
    end

    -- flat modifier match.
    local k = s:match("^(%d+)$")
    if k then 
        return {kind = "flat", k = tonumber(k), sign = sign}
    end

    -- bad expression.
    return nil, "Bad term: " .. s
end

-- Take full expression -> break into single terms -> send to parse_single_term
-- ex.2d6+1d20-3
local function tokenize(expression)
    local tokens, buffer = {}, ""

    -- Iterate and flushes through signs.
    for i = 1, #expression do 
        local c = expression:sub(i, i)
        if c == "+" or c == "-" then
            if #buffer > 0 then -- Buffer increment > 0
                table.insert(tokens, buffer)
                buffer = "" -- Reset buffer.
            end
            table.insert(tokens, c) -- Sign added to tokens.
        elseif not c:match("%s") then
            buffer = buffer .. c -- Concat every value to buffer string before sign. 
        end
    end
    -- Extra buffer after final operation (ex. ...+1d20 – 1d20 added to tokens)
    if #buffer > 0 then 
        table.insert(tokens, buffer)
    end
    return tokens
end

-- Roll an expression
-- Tokenize -> Parse -> Roll -> Sum -> Return total
function Dice.roll(expression)
    if (type(expression) ~= "string") or expression == "" then return nil, "Invalid Expression." end
    
    -- Tokenize expression
    local tokens = tokenize(expression)
    if #tokens == 0 then return nil, "Empty expression." end
    -- Last index sign check.
    if tokens[#tokens] == "+" or tokens[#tokens] == "-" then 
        return nil, "Expression cannot end with a sign"
    end
    -- Consecutive signs ('--', '++')
    for i = 2, #tokens do
        local a, b = tokens[i-1], tokens[i]
        if (a == "+" or a == "-") and (b == "+" or b == "-") then
            return nil, "Expression has consecutive signs at position " .. (i - 1)
        end
    end

    local total, parts, pending_sign = 0, {}, 1

    -- Function to roll – can be called multiple times.
    local function roll_once(sides) return math.random(1, sides) end

    -- Token -> Sign
    for _, token in ipairs(tokens) do
        if token == "+" then 
            pending_sign = 1
        elseif token == "-" then
            pending_sign = -1
        else
            -- Default negative (ternary-like) 
            -- If not negative, then positive appended to unparsed term.
            local signed_chunk = (pending_sign == -1 and "-" or "+") .. token
            -- Parsing
            local term, err = parse_single_term(signed_chunk)
            if not term then return nil, err end

            -- Rolling & Sum
            -- If ndm/dm
            if term.kind == "dice" then 
                local rolls, sum = {}, 0
                for i = 1, term.n do 
                    local roll = roll_once(term.m)
                    sum = sum + roll
                    table.insert(rolls, roll)
                end
                total = total + term.sign * sum
                -- Dice rolls add to parts table formatted as equation.
                table.insert(parts, string.format(
                    "%s%dd%d [%s]=%d",
                    term.sign < 0 and "-" or "+",
                    term.n, term.m,
                    table.concat(rolls, ","),
                    sum
                ))
            -- If k (flat modifier)
            else
                total = total + term.sign * term.k
                table.insert(parts, string.format(
                -- flat modifier with respective sign.
                    "%s%d",
                    term.sign < 0 and "-" or "+", 
                    term.k
                ))
            end
            -- Set pending_sign to positive for chunk and ternary functionality.
            pending_sign = 1
        end
    end

    -- Return total sum and equation table (parts)
    return total, parts
end

return Dice