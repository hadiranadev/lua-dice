## Dice Simulator
A Lua dice expression parser and simulator. It'll take common tabletop notation like `2d6+1d20-3` and make it work in your terminal.
> Built for Lua 5.4. Should run anywhere you can run Lua.

This started out as a regular dice roller (think rolling one regular six-sided die), and has now evolved into a slightly more serious parser that supports larger expressions, and extra options you could use for other applications (like DnD and similar).

---

## Run
```bash
lua src/main.lua "<expression>" [flags]
```

You can skip the flags if you just want a roll for a regular expression.

---

## Features

* Roll multiple dice with multiple modifiers. (ex. `2d6+1d20-3`)
* Percentile shorthand with just writing `d%` which means `1d100`
* Handles spaces, capitalization, and handles returns helpful errors.

## New Features

* Dropping highest/lowest roll inline (`4d6dl1`), or using flags (`--dh` OR `--dl`)
* Rerolling if "anything <= X once per die" where you input X.
* Exploding dice where if you roll max (or a threshold) you keep rolling. Can add a cap to stop chain.
* Advantage/Disadvantage where you roll a die X number of times and take the best/worst value.

---

## Installation

Clone this:
```bash
git clone https://github.com/hadiranadev/lua-dice.git
cd lua-dice
```

---

## Example Usage

```bash
lua src/main.lua "2d6+1d20+3"
lua src/main.lua "d%+10"
lua src/main.lua "4D6-2"
lua src/main.lua "4d6dl1" --dl=1 --dh=1 --rrlte=1 --explode=6
lua src/main.lua "d20+5" --adv=20,2
```

Output Example:
```bash
Roll 2d6+1d20+3 = 24
Parts: +2d6 [4,6]=10 +1d20 [11]=11 +3
```

Output Example (with flags):
```bash
Roll 4d6+1d8-2 = 22
Parts: +4d6 DL1 DH1 rr<=1 x1 explode@6 x3 [(1),(6),4,6,6,3,5]=24 +1d8 DL1 DH1 explode@6 x1 [(6),(5)]=0 -2
```

---

## Flags

* `--seed=<number>`: Fix the RNG seed. 
* `--dl=<n>`: Drop lowest n dice.
* `--dh=<n>`: Drop highest n dice.
* `--rrlte=<x>`: Reroll dice <= x (once per die).
* `--explode=<v>[,cap]`: Exploding dice. `max` means explode on maximum value, or use a number like 6 for threshold. Optional cap limits explosion chains.
* `--adv=<m,times>`: Advantage. Works only on single-die terms of size m. Rolls times times and keeps the highest.
* `--dis=<m,times>`: Disadvantage. Same as advantage but keeps the lowest.
* `--help`: Print usage and flags.

---

## Notes

* Parentheses in the Parts output mean a die was dropped.
* Exploding dice chains keeps spitting out numbers in sequence (that’s intended).

---

## Future Directions

This was all originally meant to be a simple dice roller but it's now a lot more detailed than I'd initially expected it to be. Made me think of a couple ideas of where to go next, which include: 
* Damage calculator: Use this in a simple combat engine and let modifiers (was thinking buffs/debuffs or accessories) toggle options automatically.
* More options: Maybe more features/flags – something like `kh`/`kl` for keep highest/lowest (this example might be slightly redundant but same idea applies). 
* Output formatting: Not terminal and maybe using JSON exports.
* Simulations: A way to simulate X rolls and see distribution (for experiments, formulae testing, RNG).

Kept lots of documentation packed in the files, so picking it up in the future should be (hopefully) straightforward with options functionality the only thing to navigate short-term. 

---

## License

MIT (see `LICENSE`).

---

## Credits

Designed and written by Hadi Rana