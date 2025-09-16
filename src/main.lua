-- SPDX-License-Identifier: MIT
-- Copyright (c) 2025 Hadi Rana

-- main.lua
-- CLI arg -> dice.lua -> main.lua display

-- Accessible from root directory.
package.path = package.path .. ";./src/?.lua"
local Dice = require("dice")

-- Seed RNG
math.randomseed(os.time() % 2^31)

-- Input argument or default to standard. 
local expression = arg[1] or "2d6+1d20-3"

local total, parts, _ = Dice.roll(expression)
if not total then 
    io.stderr:write("Error: ", parts, "\n")
    os.exit(1)
end

print(("Roll %s = %d"):format(expression, total))
print("Parts: " .. table.concat(parts, " "))