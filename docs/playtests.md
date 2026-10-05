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

The game writes the file again when a wave starts, when a wave is cleared, when the game ends and when you quit or restart, so a game you leave halfway keeps its record up to that point. A game in which you did nothing and no wave started leaves no file. Games the autoplay bot plays aren't recorded.

To stop the files, turn off **Settings → Playtest → Game records**. Files already written stay until you delete them, and deleting them is always safe.

## Sending a playtest

Play a game the way you normally would, then attach its file to a GitHub issue or send it along with a line about how the game felt. One game on Normal and one on Very Hard cover most questions. The file holds game moves only: no name, no computer details beyond the game's version.

## What a record holds

The file is JSON with four parts.

| Part | What it holds |
|---|---|
| `setup` | Map, rule set, difficulty, Infinite and Twists modes, the Twists seed, and any `--picks` given on the command line |
| `actions` | Every build, upgrade, sale, fusion, element pick and early wave call, in order. Each has the sim step it happened on (`step`, 30 per second of game time), the game time `t`, the wave at that moment and the gold left afterwards. Moves the game refused aren't listed |
| `waves` | One row per wave started: the time, gold, lives, tower count and gold invested when it began; `walked`, how far along the route its furthest creep got (0 at the portal, 1 at the gate); `died_at`, the average of that for the creeps that died; kills, leaks and lives lost; and when the wave was cleared. A Guardian's leaks count toward the wave it walked in, but it isn't part of `walked` |
| `result` | How it ended (`victory`, `defeat` or `unfinished`), the step and time, wave, lives, gold, kills, score, and every tower left on the board |

`walked` and `died_at` are the numbers that show whether creeps die at the portal. They are measured the way the balance tool measures its "Walked" columns.

## Replaying a record

The game's rules run on a fixed 30 steps per second and use no randomness outside the seeded Twists schedule, so the same moves on the same steps give the same game. `Replayer` (`src/bots/replayer.gd`) builds a fresh game from a record's setup, makes each move on its step and records the result in the same shape. The replay tool does that from the command line and prints a row per wave:

```sh
godot --headless --path . --script res://tests/bots/replay.gd -- --file=path/to/record.json
```

Give several files separated by commas to replay them in turn. Under the numbers the game was recorded with, the tool ends with "Same game as recorded." Under changed numbers it shows how the same player's choices would have fared: the first place the two games part, and how many of the recorded moves the game turned down (for example an upgrade the player could no longer afford). `--difficulty=very_hard` replays the same moves on another difficulty.

A replay stops at the step the record ends on. A record made by a different version of the game can part from its replay for the plain reason that the numbers changed in between; the `game_version` in the file says which version made it.

The unit tests in `tests/unit/test_play_log.gd` hold the promise: a bot's game under each rule set, and a player's game sent through the same calls the HUD makes, replay to the same waves, the same end and the same board.
