# Game records and replays

Every game you play is written down as it happens: the setup, each move you make and what each wave did. The record is a small text file on your own computer, and nothing is sent anywhere. It exists so that the game's difficulty can be tuned against real games as well as against the bots in [balance.md](balance.md). The first use is [issue #33](https://github.com/obsesivegamer/maze-citadel/issues/33), which found version 0.4.0 far too easy for a person.

## Where the files are

Each game gets one file in the `playtests` folder inside the game's data folder:

| | |
|---|---|
| **Mac** | `~/Library/Application Support/Maze Citadel/playtests/` |
| **Windows** | `%APPDATA%\Maze Citadel\playtests\` |
| **Linux** | `~/.local/share/Maze Citadel/playtests/` |

**Settings → Playtest → Open the records folder** opens it for you. A file is named after the moment the game began, the map and the difficulty, for example `2026-10-05T21-14-03_citadel_very_hard.json`.

The game writes the file again when a wave starts, when a wave is cleared, when the game ends and when you quit or restart, so a game you leave halfway keeps its record up to that point. A game in which you did nothing and no wave started leaves no file. Games the autoplay bot plays aren't recorded, and neither are scripted runs: a launch with `--shot`, `--bench`, `--first-frame-out` or `--warp-wave` (captures, benchmarks and launch probes) writes no file.

To stop the files, turn off **Settings → Playtest → Game records**. Files already written stay until you delete them, and deleting them is always safe.

## Sending a playtest

Play a game the way you normally would, then attach its file to a GitHub issue or send it along with a line about how the game felt. One game on Normal and one on Very Hard cover most questions. The file holds game moves only: no name, no computer details beyond the game's version.

## What a record holds

The file is JSON with four parts.

| Part | What it holds |
|---|---|
| `setup` | Map, rule set, difficulty, Infinite and Twists modes, the Twists seed, and any `--picks` given on the command line |
| `actions` | Every build, upgrade, sale, fusion, element pick and early wave call, in order. Each has the sim step it happened on (`step`, 30 per second of game time), the game time `t`, the wave at that moment and the gold left afterwards. Moves the game refused aren't listed |
| `waves` | One row per wave started: the time, gold, lives, tower count and gold invested when it began; `earned_before`, the gold earned in the game up to then; `walked`, how far along the route its furthest creep got (0 at the portal, 1 at the gate); `deaths`, its creeps killed before reaching the gate, and `died_at`, the average of how far those had walked; `leaks`, one each time a creep reached the gate, and `lives_lost`; and `cleared_t`, when the field next stood empty, which for a wave called early or with a Guardian still walking is later than its own last creep. A creep that leaks walks again and is counted as a leak, not a death, when it is finally killed. A Guardian's leaks count toward the wave it walked in, but it is no part of `walked` or `deaths` |
| `result` | How it ended (`victory`, `defeat` or `unfinished`), the step and time, wave, lives, gold, kills, score, and every tower left on the board |

`walked` and `died_at` are the numbers that show whether creeps die at the portal. Both are measured against the whole route from the portal as it stood when the creep was first seen, so a Felhound a Dreadlord summons halfway along starts at one half.

## Replaying a record

The game's rules run on a fixed 30 steps per second and use no randomness outside the seeded Twists schedule, so the same moves on the same steps give the same game. `Replayer` (`src/bots/replayer.gd`) builds a fresh game from a record's setup, makes each move on its step and records the result in the same shape. The replay tool does that from the command line and prints a row per wave:

```sh
godot --headless --path . --script res://tests/bots/replay.gd -- --file=path/to/record.json
```

Give several files separated by commas to replay them in turn. Under the numbers the game was recorded with, the tool ends with "Same game as recorded." Under changed numbers it shows how the same player's choices would have fared: the first place the two games part, and how many of the recorded moves it came to were turned down (for example an upgrade the player could no longer afford). When the replay ends sooner than the recorded game, say on a loss, the tool also says how many moves it never came to; those were not refused, just never tried. `--difficulty=very_hard` replays the same moves on another difficulty.

A replay stops at the step the record ends on, or sooner if its game ends first. Records are expected to replay the same on another operating system; if one ever parts from its replay under unchanged numbers, the tool names the first wave where it does. A record made by a different version of the game can part from its replay for the plain reason that the numbers changed in between; the `game_version` in the file says which version made it.

The unit tests in `tests/unit/test_play_log.gd` hold the promise: a bot's game under each rule set, and a player's game sent through the same calls the HUD makes, replay to the same waves, the same end and the same board.
