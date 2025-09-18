-- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 Hadi Rana

-- dice.lua
-- All dice functionality - parsing, rolling, optional 'effects'.

--[[
    n = number of dice.
    m = number of sides per die.
    k = flat modifier (add/subtract after dice.)
    d% = percentile shorthand ex. 1...100 (same as d100)

    Examples
    -- "2d6+1d20-3" -- mix n d m terms with +/- and a flat
    -- "4d6dl1"     -- drop the lowest 1 die from 4d6 (classic stat roll)
    -- "d%+10"      -- percentile die plus flat bonus

    Dice.roll(expression, options) -> total, parts
    -- expression: string like "2d6+4" or "4d6dl1+d8"
    -- options: (all optional) a table of toggles modifying roll behaviour.

    -- options table (if any added as flags - enter src/main --help for flags.)
    drop_lowest    = {count = N} -- drop lowest roll.
    drop_highest   = {count = N} -- drop highest roll.
    -- drops lowest/highest rolls through shallow copy sorting through rolls

    reroll         = {lte = X}
    -- reroll die values <= X - *once* per die (so no infinite loops)
    
    explode        = { on_explode = "max" | number, cap = N } 
    -- if a die meets the threshold then roll extra die and add it.
    -- on_explode = "max" then threshold is the max side (value == m)
    -- on_explode = "number" then threshold is that number (value >= threshold)
    -- cap = max extra explosions per original die (0 = no cap)

    advantage      = { target_m = M, times = T }
    disadvantage   = { target_m = M, times = T }
    -- only applies to terms with n = 1 and m = target_m
    -- rolls T times and keeps best/worst values (adv = best; dis = worst)

    Returns:
    total = final int after sign/flat/drops/options...
    parts = array of chunks to show what happened
    -- ex. "4d6 dl1 [3,5,(1),3]=11 +3", where parenthesis show value dropped (dl)

]]

local Dice = {}

-- Helper function
-- Trim, parse sign, detect NdM[dlN]/dM/K/d%
local function parse_single_term(s)

    -- Remove spaces and lowercase
    s = (s:gsub("%s+", ""))
    if s == "" then return nil, "Invalid: Empty term." end
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

    -- Percentile shorthand matching (%d == d100 )
    if s:match("^d(%%)$") then 
        return {kind = "dice", n = 1, m = 100, sign = sign} 
    end

    -- NdM[dlN] matching 
    local n, m, dl = s:match("^(%d+)d(%d+)dl(%d+)$") -- capture n, m, dl
    if n and m then 
        n, m, dl = tonumber(n), tonumber(m), tonumber(dl) -- String -> int
        -- Logic errors.
        if n < 1 then return nil, "Dice count must be >= 1." end
        if m < 2 then return nil, "Die sides must be >= 2." end
        if dl < 0 then return nil, "dl must be >= 0." end
        if dl >= n then return nil, "dl must be less than the number of dice." end
        return {kind = "dice", n = n, m = m, sign = sign, drop_lowest = dl}
    end

    -- NdM (no dl)
    n, m = s:match("^(%d+)d(%d+)$")
    if n and m then
        n, m = tonumber(n), tonumber(m)
        if n < 1 then return nil, "Dice count must be >= 1." end
        if m < 2 then return nil, "Die sides must be >= 2." end
        return { kind = "dice", n = n, m = m, sign = sign, drop_lowest = 0 }
    end

    -- dM matching (1 die, m sides)
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
-- ex.2d6+1d20-3 -> {"2d6", "+", "1d20"...}
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

-- Helper Utility
-- shallow copy to preserve original table
local function copy_table(tble)
    local output = {}
    for i = 1, #tble do output[i] = tble[i] end
    return output
end

-- Drop Lowest Values (dlN)
-- Values = rolled values; Count = Number of values to drop
local function drop_lowest_values(values, count)
    -- No values to drop then end
    if not count or count <= 0 then return copy_table(values), {} end
    -- preserve original order in values by using sorted.
    local sorted = copy_table(values)
    table.sort(sorted, function(a, b) return a < b end)

    -- dropped = Lowest values; to_drop = handle duplicate rolls; 
    -- keep = values not in to_drop
    local dropped, to_drop, keep = {}, {}, {}
    for i = 1, math.min(count, #sorted) do table.insert(dropped, sorted[i]) end
    -- to_drop acts like a key – iterates through dropped and increments
    -- to know how many of a value to drop.
    for _, v in ipairs(dropped) do to_drop[v] = (to_drop[v] or 0) + 1 end
    for _, v in ipairs(values) do
        if to_drop[v] and to_drop[v] > 0 then 
            to_drop[v] = to_drop[v] - 1
        else
            table.insert(keep, v)
        end
    end
    return keep, dropped
end

-- Similar to dlN – sorts from highest to lowest instead.
local function drop_highest_values(values, count)
    -- No values to drop then end
    if not count or count <= 0 then return copy_table(values), {} end
    -- preserve original order in values by using sorted.
    local sorted = copy_table(values)
    table.sort(sorted, function(a, b) return a > b end)

    -- dropped = Lowest values; to_drop = handle duplicate rolls; 
    -- keep = values not in to_drop
    local dropped, to_drop, keep = {}, {}, {}
    for i = 1, math.min(count, #sorted) do table.insert(dropped, sorted[i]) end
    -- to_drop acts like a key – iterates through dropped and increments
    -- to know how many of a value to drop.
    for _, v in ipairs(dropped) do to_drop[v] = (to_drop[v] or 0) + 1 end
    for _, v in ipairs(values) do
        if to_drop[v] and to_drop[v] > 0 then 
            to_drop[v] = to_drop[v] - 1
        else
            table.insert(keep, v)
        end
    end
    return keep, dropped
end

-- Reroll once per die for values <= (lte) threshold (safe - no infinite loops)
-- returns new rolls table and info {count = number_of_rerolls}
local function apply_rerolls(rolls, m, options)
    -- options DNE or options.lte not set
    if not options or not options.lte then return copy_table(rolls), {count = 0} end
    local lte = tonumber(options.lte) or 0
    -- nothing to reroll return shallow copy
    if lte <= 0 then return copy_table(rolls), {count = 0} end
    -- rerolling.
    local output, count = {}, 0
    for _, v in ipairs(rolls) do
        if v <= lte then
            count = count + 1
            local rand = math.random(1, m)
            table.insert(output, rand)
        else
            table.insert(output, v)
        end
    end
    return output, {count = count}
end

-- Exploding dice
-- options.on_explode = "max" explodes (val = m) or a number threshold (val >= threshold)
-- options.cap = max extra explosions per original die (0 = unlimited)
local function apply_exploding(rolls, m, options)
    if not options then return copy_table(rolls), {explosions = 0} end
    local threshold
    if options.on_explode == "max" then 
        threshold = m
    elseif type(options.on_explode) == "number" then 
        threshold = options.on_explode
    else 
        return copy_table(rolls), {explosions = 0} 
    end

    local cap, output, explosions = tonumber(options.cap) or 0, {}, 0

    for _, v in ipairs(rolls) do
        table.insert(output, v)
        local chains = 0
        -- explosion triggers if roll is >= threshold (lower threshold = more explosions)
        local trigger = (v >= threshold)
        while trigger do
            if cap > 0 and chains >= cap then break end
            -- rolling
            local next_roll = math.random(1, m)
            table.insert(output, next_roll)
            explosions = explosions + 1
            chains = chains + 1
            trigger = (next_roll >= threshold) -- escape case
        end
    end
    return output, {explosions = explosions}
end

-- Advantage/Disadvantage for single die (n = 1) of sides m
-- Takes highest/lowest roll after times number of rolls.
-- kind = "adv" or "disadv"; times is >= 2
local function apply_adv_dis_single(m, roll_once, kind, times)
    local chosen = roll_once(m)
    for _ = 2, times do 
        local sample = roll_once(m)
        if kind == "adv" then
            if sample > chosen then chosen = sample end
        else -- dis – sets to lowest if possible, else defaults.
            if sample < chosen then chosen = sample end
        end
    end
    return chosen
end

-- Helper Utility
-- Iterates through dropped to get value frequencies.
local function add_drops(accumlator, tble)
    for _, v in ipairs(tble) do
        accumlator[v] = (accumlator[v] or 0) + 1
    end
end

-- Roll an expression with optional transforms
-- 1. Tokenize -> 2. Parse -> 3. Roll (w or w/o adv/dis) -> 4. transforms (drop_lowest/drop_highest, reroll, explode)
-- 5. Sum -> 6. Append -> 7. return total.
function Dice.roll(expression, options)
    if (type(expression) ~= "string") or expression == "" then return nil, "Invalid Expression." end
    
    -- 1. Tokenize expression
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
    local function roll_once(m) return math.random(1, m) end

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
            -- 2. Parsing
            local term, err = parse_single_term(signed_chunk)
            if not term then return nil, err end

            -- 3. Rolling (with adv/dis if configured)
            if term.kind == "dice" then 
                local rolls, used_adv_dis = {}, false 

                if term.n == 1 and options then
                    if options.advantage and options.advantage.target_m == term.m and (tonumber(options.advantage.times) or 0) >= 2 then
                        table.insert(rolls, apply_adv_dis_single(term.m, roll_once, "adv", tonumber(options.advantage.times)))
                        used_adv_dis = true
                    elseif options.disadvantage and options.disadvantage.target_m == term.m and (tonumber(options.disadvantage.times) or 0) >= 2 then
                        table.insert(rolls, apply_adv_dis_single(term.m, roll_once, "dis", tonumber(options.disadvantage.times)))
                        used_adv_dis = true
                    end
                end 

                -- no adv/dis
                if #rolls == 0 then 
                    for _ = 1, term.n do 
                        table.insert(rolls, roll_once(term.m))
                    end
                end

                -- 4. Transforms (Rerolls/Explosions/Drops)
                -- Rerolls (once per die)
                local rerolled_info = { count = 0 }
                if options and options.reroll then
                    local new_rolls
                    new_rolls, rerolled_info = apply_rerolls(rolls, term.m, options.reroll)
                    rolls = new_rolls
                end

                -- Explosions
                local exploded_info = { explosions = 0 }
                if options and options.explode then
                    local new_rolls
                    new_rolls, exploded_info = apply_exploding(rolls, term.m, options.explode)
                    rolls = new_rolls
                end 

                -- Drops: built-in dlN first then global drops
                local kept, dropped = drop_lowest_values(rolls, term.drop_lowest or 0)

                -- Get all dropped dice to annotate them all with ()
                local dropped_all = {}
                add_drops(dropped_all, dropped)

                if options and options.drop_lowest and (tonumber(options.drop_lowest.count) or 0) > 0 then
                    local dropped2
                    kept, dropped2 = drop_lowest_values(kept, tonumber(options.drop_lowest.count))
                    add_drops(dropped_all, dropped2) -- dropped_all gets all dropped from dl
                end
                if options and options.drop_highest and (tonumber(options.drop_highest.count) or 0) > 0 then
                    local dropped3
                    kept, dropped3 = drop_highest_values(kept, tonumber(options.drop_highest.count))
                    add_drops(dropped_all, dropped3) -- dropped_all gets all dropped from dh
                end

                -- 5. Sum (kept values not dropped)
                local kept_sum = 0
                for _, v in ipairs(kept) do kept_sum = kept_sum + v end
                total = total + term.sign * kept_sum

                -- 6. Append
                -- like kept logic but with formatting when added to list for printing later.
               local dropCount = {}
               -- comparing frequencies
                for v, c in pairs(dropped_all) do dropCount[v] = c end
                local annotated = {}
                for _, v in ipairs(rolls) do
                    if dropCount[v] and dropCount[v] > 0 then
                        table.insert(annotated, "(" .. v .. ")")
                        dropCount[v] = dropCount[v] - 1
                    else
                        table.insert(annotated, tostring(v))
                    end
                end

                local append_parts = {}
                -- dropping lowest/highest appending
                if (term.drop_lowest or 0) > 0 then table.insert(append_parts, ("dl%d"):format(term.drop_lowest)) end
                if options and options.drop_lowest and (tonumber(options.drop_lowest.count) or 0) > 0 then
                    table.insert(append_parts, ("DL%d"):format(tonumber(options.drop_lowest.count)))
                end
                if options and options.drop_highest and (tonumber(options.drop_highest.count) or 0) > 0 then
                    table.insert(append_parts, ("DH%d"):format(tonumber(options.drop_highest.count)))
                end
                -- reroll append
                if options and options.reroll and (tonumber(options.reroll.lte) or 0) > 0 and (rerolled_info.count or 0) > 0 then
                    table.insert(append_parts, ("rr<=%d x%d"):format(tonumber(options.reroll.lte), rerolled_info.count))
                end
                -- explode append
                if options and options.explode then
                    local trig = (options.explode.on_explode == "max") and "max" or tostring(options.explode.on_explode)
                    if (exploded_info.explosions or 0) > 0 then
                        table.insert(append_parts, ("explode@%s x%d"):format(trig, exploded_info.explosions))
                    end
                end
                -- adv/dis append
                if used_adv_dis then table.insert(append_parts, "adv/dis") end

                local appended = (#append_parts > 0) and (" " .. table.concat(append_parts, " ")) or ""
                table.insert(parts, string.format(
                    "%s%dd%d%s [%s]=%d",
                    term.sign < 0 and "-" or "+",
                    term.n, term.m,
                    appended,
                    table.concat(annotated, ","),
                    kept_sum
                ))
            else
            -- If k (flat modifier)
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