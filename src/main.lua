-- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 Hadi Rana

-- main.lua
-- CLI arg -> dice.lua -> main.lua display

-- Accessible from root directory.
package.path = package.path .. ";./src/?.lua"
local Dice = require("dice")

-- help
local function print_help()
    print([[
Usage:
    lua src/main.lua "<expression>" [flags]

Expression examples:
    "2d6+1d20+3"
    "4d6dl1"
    "d%+10"

Flags: 
    --seed=<number>         - Set custom RNG seed.
    --dl=<n>                - Drop lowest n 
    --dh=<n>                - Drop highest n
    --rrlte=<x>             - Reroll values <= x once per die
    --explode=<v>[,cap]     - Explode on "max" or v with optional cap per die.
    --adv=<m,times>         - Advantage on single-die terms with sides m, roll 'times' and keep best.
    --dis=<m,times>         - Disadvantage (keeps worst)
    --help                  - Show this help.

    Examples:
    lua src/main.lua "2d6+1d20+3" --seed=123
    lua src/main.lua "4d6dl1" --dl=1
    lua src/main.lua "3d6" --rrlte=1 --explode=max,2
    lua src/main.lua "d20+5" --adv=20,2 
]])
end

-- parse arguments
local expression = nil
local options = {}
local args = {...} -- variadic to do multiple operations.

-- Parse CLI args for help or flags.
for _, argument in ipairs(args) do
    if argument == "--help" or argument == "-h" or argument == "--h" then
        print_help()
        os.exit(0)
    elseif argument:match("^%-%-") then
        -- Matches flags.
        local k, v = argument:match("^%-%-(%w+)=(.+)$")
        if not k then
            io.stderr:write("Bad flag: ", argument, "\n")
            os.exit(1)
        end
        
        -- Seed flag.
        if k == "seed" then
            local seed = tonumber(v)
            if not seed then 
                io.stderr:write("Bad seed: ", v, "\n")
                os.exit(1)
            end
            math.randomseed(seed % 2^31)
            options._seeded = true -- so fallback doesn't reseed custom seed.

        -- highest/lowest
        elseif k == "dl" then
            options.drop_lowest = {count = tonumber(v) or 0}
        elseif k == "dh" then
            options.drop_highest = {count = tonumber(v) or 0}

        -- Reroll
        elseif k == "rrlte" then 
            options.reroll = {lte = tonumber(v) or 0}

        -- Explode
        -- 2 options: max -> N OR max,cap -> N,cap
        elseif k == "explode" then
            local v1, v2 = v:match("^([^,]+),?(.*)$")
            local on_explode
            if v1 == "max" then
                on_explode = "max"
            else
                on_explode = tonumber(v1)
                if not on_explode then io.stderr:write("Bad explode value: ", v1, "\n")
                os.exit(1)
                end
            end
            local cap = tonumber(v2) or 0
            options.explode = {on_explode = on_explode, cap = cap}

        -- Advantage/Disadvantage
        elseif k == "adv" or k == "dis" then
            local m_str, times_str = v:match("^([^,]+),([^,]+)$")
            local m, times = tonumber(m_str), tonumber(times_str)
            if not m or not times then 
                io.stderr:write("Bad ", k, " value: ", v, " (expected m,times)\n")
                os.exit(1)
            end
            local tble = {target_m = m, times = times}
            if k == "adv" then options.advantage = tble else options.disadvantage = tble end
            -- Syntactical Failure
        else
            io.stderr:write("Unknown flag: --", k, "\n")
            os.exit(1)
        end
        
    else
    -- first non-flag is the expression
    expression = expression or argument
    end
end

if not expression then 
    io.stderr:write("Missing expression. Use --help for usage tips.\n")
    os.exit(1)
end

-- seeded flag unset then fallback sets random seed.
if not options._seeded then 
    local seed = os.time() % 2^31
    math.randomseed(seed)
    print(("seed=%d"):format(seed))
end

-- Sending to Dice.roll, getting results.
local total, parts, _ = Dice.roll(expression, options)
if not total then 
    io.stderr:write("Error: ", parts, "\n")
    os.exit(1)
end

print(("Roll %s = %d"):format(expression, total))
print("Parts: " .. table.concat(parts, " "))