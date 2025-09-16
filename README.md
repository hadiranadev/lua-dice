## Dice Simulator
A simple Lua dice expression parser and simulator. Supports common tabletop notation like 2d6+1d20-3.
> Built for Lua 5.4. Runs in any terminal.

---

## Run
```bash
lua src/main.lua
```

---

## Features

* Roll multiple dice and apply modifiers (2d6+3)
* Support for mixed expressions (2d6+1d20-4)
* Percentile shorthand (d% -> 1d100)
* Handles whitespace, uppercase D, and input validation

---

## Installation

Clone this:
```bash
git clone https://github.com/hadiranadev/lua-dice.git
cd lua-dice
```

---

## Example Usage

Run from the project root:
```bash
lua src/main.lua <expression>
```

Examples:
```bash
lua src/main.lua "2d6+1d20+3"
lua src/main.lua "d%+10"
lua src/main.lua "4D6-2"
```

Output Example:
```bash
Roll 2d6+1d20+3 = 24
Parts: +2d6 [4,6]=10 +1d20 [11]=11 +3
```

---

## License

MIT (see `LICENSE`).

---

## Credits

Designed and written by Hadi Rana