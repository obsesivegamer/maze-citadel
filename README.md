# Maze Citadel

**Play it: [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/)**

The website has the downloads for Mac, Windows and Linux, a practice maze you can try in your browser, and the full tower roster.

[![A wave-24 battle in Maze Citadel: five rows of towers bend the creeps' road back and forth across the plateau](docs/screens/m3-wave24-full.jpg)](https://obsesivegamer.github.io/maze-citadel/)

## What it is

Maze Citadel is a single-player tower defense game for Mac, Windows and Linux, made in the spirit of the old Warcraft III custom maps: Element TD, Gem TD and Wintermaul One.

Demons come out of a red portal at the north end of a plateau and march for the blue town gate at the south end. There are no walls except the ones you build. Every tower blocks the tile it stands on, so where you put your towers decides how far the creeps have to walk, and a good maze doubles back on itself until every creep spends a long time under fire. The one thing you can't do is close the road completely. The game refuses any tower that would cut the portal off from the gate.

The maze is half the game. The other half is reading what's coming. Each wave has an armor class and an element, announced before it arrives. The right towers hit it for double damage and the wrong ones barely scratch it. Every tower reaches only the tiles around it, so the road has to run right past your towers.

You start with three towers that need no element, and you earn the rest. Eight element picks come over the game, one at the start and one every five waves, and each buys one level of an element. The first is yours at once. Every later pick summons a Guardian of that element, a boss that walks the maze and grants the level only when you kill it. Eight picks against eighteen element levels can never take all six elements to the top, so every game is built around a few. Hold the gate for forty waves, the last of them led by the Dreadlord, and the citadel is saved.

What's in it:

- **40 waves** of grunts, wolf riders, shield footmen, priestesses, harpies, ghouls, steam tanks and ogre bosses, ending with the Dreadlord.
- **10 towers and 4 Epics.** Every tower upgrades twice, and two fully upgraded towers of the same family fuse into that family's Epic.
- **Element picks and Guardians.** Six elements to earn a level at a time, with Interest as the other way to spend a pick.
- **3 maps.** Citadel Plateau is the open board. Fallen Rampart splits it with a broken wall that funnels every creep through one of three breaches. Winding Causeway lays a fixed road and leaves you to choose where to build beside it.
- **4 difficulties**, Easy, Normal, Hard and Very Hard, plus two extras you can switch on: **Infinite** keeps the waves coming after wave 40, and **Twists** gives later waves a random ability.
- **Classic rules** one click away: the game as it was in 0.3.1, with long tower ranges and every tower open from the start.
- **A tutorial and a Field Guide** that teach the counter system over the first ten waves.

The game is playable from the first wave to the last. It's still before version 1.0, and new builds go up on the website and the [Releases page](https://github.com/obsesivegamer/maze-citadel/releases) as they're ready. It was built with Godot 4.7.

## Install

Maze Citadel runs on Macs with Apple silicon, on 64-bit Windows 10 and 11, and on 64-bit x86 Linux. There is nothing else to install. The Windows and Linux builds are new in 0.3.0 and less tested than the Mac build. Releases up to 0.2.0 are Mac only.

### Mac

You need a Mac with Apple silicon running macOS 13 Ventura or later.

1. **Download the game.** Open [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/) and click **Download for Mac**. You get a disk image named `MazeCitadel-<version>.dmg`, a little over 100 MB. The same file is on the [Releases page](https://github.com/obsesivegamer/maze-citadel/releases/latest).
2. **Open the disk image** and drag **Maze Citadel** onto the **Applications** shortcut beside it. You can also run the game straight from the disk image.
3. **Allow it once.** Maze Citadel isn't notarized by Apple yet, so the first double-click shows "Apple could not verify Maze Citadel is free of malware". That's expected. Click **Done**, open **System Settings → Privacy & Security**, scroll down to **Security** and click **Open Anyway**, then confirm. After that it opens with a normal double-click. On macOS 13 or 14 you can instead Control-click the app and choose **Open**.
4. **Play.** The first launch spends about 20 seconds on the loading screen while the game prepares its graphics. Later launches take about 4 seconds. There's no title screen: the game opens on the citadel with a setup panel over it, where you pick the map, the rules, a difficulty and the tutorial, and the clock waits until you press **Start**. A welcome card explains the basics the first time, and then you have 400 gold, an element pick to spend and 45 seconds to build before wave 1.

### Windows

1. **Download the game.** On [the website](https://obsesivegamer.github.io/maze-citadel/), click **Download for Windows**. You get a zip named `MazeCitadel-<version>-windows-x86_64.zip`.
2. **Unzip it.** Right-click the zip and choose **Extract All**. The `MazeCitadel` folder inside holds a single file, `MazeCitadel.exe`, with the whole game in it. Keep the folder wherever you like.
3. **Allow it once.** The game isn't code-signed yet, so the first double-click on `MazeCitadel.exe` shows "Windows protected your PC". That's expected. Click **More info**, then **Run anyway**. After that it opens with a normal double-click.

### Linux

1. **Download the game.** On [the website](https://obsesivegamer.github.io/maze-citadel/), click **Download for Linux**. You get an archive named `MazeCitadel-<version>-linux-x86_64.tar.gz`.
2. **Extract it** with your file manager, or with `tar -xzf MazeCitadel-<version>-linux-x86_64.tar.gz`. The `MazeCitadel` folder inside holds a single file, `MazeCitadel.x86_64`, with the whole game in it.
3. **Run it.** Double-click `MazeCitadel.x86_64`, or run `./MazeCitadel.x86_64` from a terminal in that folder. If it doesn't start, update your distribution's graphics drivers: the game needs Vulkan.

[docs/INSTALL.md](docs/INSTALL.md) covers the rest: checking the download, updating, uninstalling, where the game keeps its files, and what to do if something goes wrong.

### System requirements

| | Mac | Windows | Linux |
|---|---|---|---|
| **System** | macOS 13 Ventura or later | Windows 10 or 11, 64-bit | A 64-bit x86 distribution with up-to-date graphics drivers |
| **Hardware** | Apple silicon, M1 or later. Intel Macs aren't supported. | A graphics card with Vulkan or Direct3D 12, roughly 2016 or newer | A graphics card with Vulkan, roughly 2016 or newer |
| **Free space** | About 200 MB | About 200 MB | About 200 MB |
| **Internet** | Only for the download. The game runs offline. | The same | The same |
| **Extra software** | None. Everything is inside the app. | None | None besides the graphics drivers |

Maze Citadel is tested on a MacBook Air 13-inch M3 with 16 GB of memory, where it runs at 60 fps on the default Balanced quality preset. That is the only computer it has been measured on so far, and the Windows and Linux builds haven't been measured yet. If it runs slowly on yours, the Performance preset in Settings is lighter.

It's the same game on all three systems, with the same saves. The game keeps its settings, best waves and a record of each game ([docs/playtests.md](docs/playtests.md)) in `~/Library/Application Support/Maze Citadel` on a Mac, `%APPDATA%\Maze Citadel` on Windows and `~/.local/share/Maze Citadel` on Linux.

## How to play

**Build a maze.** Pick a tower from the bar at the bottom of the screen, or press its number key, and click a tile. Hold `Shift` while clicking to keep placing the same tower. A glowing dotted line shows the road the creeps will take, and it redraws every time you build. If the ghost of the tower turns red, that spot would block the road completely and the game won't allow it.

**Pick your elements.** The Archer, the Cannon and the Bard need no element. Every other tower needs its element: one level to build it, and the second and third levels for its upgrades. When a pick is waiting, a pulsing chip on the top bar, or `E`, opens the pick panel, which says in plain words what each choice would do now (the towers it opens, or how many of yours it lets upgrade) and how each element fares against the next ten waves. Until you spend a pick, a reminder comes at every wave start, and a locked card names the pick that opens it. Your first pick is granted at once. Later ones summon a Guardian that has to die before the level is yours, and it costs 3 lives if it gets through. A pick can also go on Interest, which raises the interest you earn on unspent gold.

**Upgrade, sell and fuse.** Click a tower to see its plaque. Every tower has two upgrades. Selling returns 75% of everything you spent on it. Two level-3 towers from the same family fuse into that family's Epic: the Alliance's Sunfire Ballista, the Horde's Doom Cannon, the Elven Frost Wyrm and the Forsaken Plague Necropolis.

**Read the wave.** Every wave has an armor class and an element. The chip on the top bar shows what's next, and a banner repeats it three seconds before the wave arrives. Three rules cover armor: Pierce beats Light armor and flyers, Siege beats Armored, and Poison ignores armor altogether. Elements run in a ring, Light → Dark → Aqua → Flame → Verdant → Stone → Light, and each one deals double damage to the next and half to the one before it. Hover over a tower card and its tooltip rates that tower against the coming wave. Flying waves are tagged Flying: harpies ignore your maze and fly straight from the portal to the gate, along the pale blue arrows, so only towers with the wing icon that stand beside that line can hit them. Choose one to build and the tiles that reach the line light up, and under the wave preview the top bar rates your air cover for the next flying wave. On the three composite-armor waves elements don't matter: element towers deal 90%, and only the Archer and the Cannon keep their full damage.

**Hold the gate.** You have 20 lives. A creep that reaches the gate costs one life, a boss or a Bulky creep costs two, and it loops back to the portal for another run with no bounty for killing it. While a leaked creep is still alive, interest stops paying. Clear wave 40 to win.

**Set your own pace.** Waves start on a timer, 30 seconds apart, and `N` calls the next one early. `Space` pauses, and you can still build while paused. `F` cycles the speed between ×1, ×2 and ×3.

**Learn as you go.** On the first launch a tutorial walks you through waves 1 to 10. Before each wave, a counsel card names what counters it and lights up the towers worth building. `H` opens the Field Guide at any time, with the element ring, the attack and armor chart and advice for the next wave. You can turn the tutorial back on under **Settings → Help**.

**Pick a map, a difficulty and the rules.** The setup panel at the start of each game has all of them, with a line on what each difficulty does, and the clock waits until you press Start. Until wave 1 you can still change the map in the panel under the gold counter and the difficulty on the top bar. Easy takes 30% off the creeps' health. Hard adds 6% on wave 1, rising to 28% on wave 40, and Very Hard adds 10% rising to 55%, slowly at first and steeply after wave 25. Infinite keeps going after wave 40. Twists gives most waves from wave 11 a random ability, shown a full wave ahead. The RULES switch in the same panel turns on the classic rules, the game as it was in 0.3.1, with 220 gold, long tower ranges and every tower open. Your best wave is saved for each map, difficulty and rule set, and Play again and the next launch keep the map, rules, difficulty, Infinite and Twists you last picked. Play again starts straight away; **Change setup** on the end screen, or **New game setup** in the `Esc` menu, brings the setup panel back.

### Controls

| Key or gesture | What it does |
|---|---|
| `1` to `0` | Pick a tower, then click a tile to build it |
| `Shift` + click | Keep placing the same tower |
| `U` | Upgrade the selected tower |
| `X` or right-click | Sell the selected tower for 75% |
| `G` | Fuse two level-3 towers of one family into an Epic |
| `N` | Start the next wave now |
| `Space` | Pause or resume |
| `F` | Cycle the speed: ×1, ×2, ×3 |
| `E` | Open the element picks, while a pick is waiting |
| `H` | Open the Field Guide |
| `F10` | Open or close Settings |
| `Esc` | Close the open panel, or deselect or cancel. With nothing to cancel, open the menu: resume, restart, a new game setup, settings, the Field Guide or quit to the desktop |
| `W` `A` `S` `D`, arrow keys, or two-finger drag on a Mac trackpad | Move the camera |
| Mouse wheel, pinch, or two-finger swipe on a PC touchpad | Zoom |
| `Q` / `E`, middle-drag or `Option`-drag (`Alt`-drag on PC) | Rotate the camera (`E` opens the picks instead while one is waiting) |
| `R` | Reset the camera |
| `C` | Cycle the full-board, portal and gate views |
| `B` | Follow the boss |
| `F11` or `Alt`+`Enter` | Fullscreen on Windows and Linux. On a Mac, use the window's green button. |

## Build it from source

You only need this section if you want to change the game. To play, the download above is all you need.

### What you need

| Tool | Version | What it's for | How to get it |
|---|---|---|---|
| A Mac with Apple silicon | | Building the app. The export is arm64 only. | |
| Xcode Command Line Tools | | `git` and the tools the export script uses | `xcode-select --install` |
| [Godot](https://godotengine.org/) | 4.7.2 | The engine and editor | `brew install --cask godot` |
| Godot export templates | 4.7.2 | Building the `.app` and `.dmg` (macOS template), and the Windows and Linux builds | In Godot: **Editor → Manage Export Templates** |
| [Git LFS](https://git-lfs.com/) | | Models, textures, audio and fonts are stored in LFS | `brew install git-lfs`, then `git lfs install` |
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | 4.x | `gdlint` and `gdformat` for the code checks | `brew install pipx`, then `pipx install "gdtoolkit==4.*"` |
| Python 3 | | The asset license check and the website build | Comes with the Command Line Tools |

The project is pinned to Godot 4.7.2. Homebrew installs whatever is current, so if that has moved on, take 4.7.2 from the [Godot download archive](https://godotengine.org/download/archive/). The scripts call `godot` from your `PATH`. If yours lives somewhere else, set `GODOT` to the full path of the binary.

### Set up and run

```sh
git clone https://github.com/obsesivegamer/maze-citadel.git
cd maze-citadel
git lfs pull                        # only needed if LFS was installed after cloning
godot --headless --path . --import  # first import of the assets
godot --path .                      # run the game
```

Game options go after a `--`. For example, this starts on the second map with the lightest graphics preset, and the second line plays the classic rules on Hard:

```sh
godot --path . -- --map=rampart --quality=performance
godot --path . -- --rules=classic --difficulty=hard
```

### Everyday commands

| Command | What it does |
|---|---|
| `tools/check.sh` | The full check, run before every commit: import, asset licenses, lint, format, unit tests and a headless play-through by the bot |
| `tools/smoke.sh 18000` | The bot plays for five minutes at ×3 with no window, under the Element TD rules on the Citadel Plateau. Add `--rules=classic` or `--map=causeway` to smoke another rule set or map |
| `godot --headless --path . --script res://tests/bots/run_balance.gd` | Bots play full games under the Element TD rules and print the balance table ([docs/balance.md](docs/balance.md)). Add `-- --rules=classic` for the classic rules, or `-- --map=causeway` for another map |
| `godot --headless --path . --script res://tests/bots/replay.gd -- --file=<record.json>` | Replays a recorded game and prints what each wave did ([docs/playtests.md](docs/playtests.md)) |
| `tools/export.sh` | Builds `dist/MazeCitadel.app` and the `.dmg` |
| `tools/verify_dmg.sh` | Mounts the `.dmg`, checks the bundle, version, architecture and signature, and runs the game from it |
| `tools/export_pc.sh` | Builds the Windows `.zip` and Linux `.tar.gz` into `dist/`. Run it after `tools/export.sh`, which empties `dist/`. |
| `tools/verify_pc.sh windows` or `linux` | Checks a PC archive and runs the game from it. Run it on that system: Git Bash on Windows. |
| `python3 tools/build_site.py` | Builds the website into `build/site/`, filled in from the newest release |
| `git tag vX.Y.Z && git push origin vX.Y.Z` | Publishes a release and updates the website ([docs/RELEASING.md](docs/RELEASING.md)) |
| `ALLOW_WINDOW=1 tools/slot.sh` | Screenshots, benchmarks and a launch test. These open game windows and take over the screen for about 15 minutes. |

The full developer setup, including a way to install the export templates from the command line, is in [docs/INSTALL.md](docs/INSTALL.md#part-2-build-from-source).

## Documentation

| Document | What's in it |
|---|---|
| [docs/INSTALL.md](docs/INSTALL.md) | Installing, updating and uninstalling the game, system requirements, troubleshooting, and the full developer setup |
| [docs/GDD.md](docs/GDD.md) | The game design: every rule, tower, creep and wave, with the numbers, and how the classic rules differ |
| [docs/maps.md](docs/maps.md) | The three maps and how a map is defined |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the code is organised |
| [docs/RELEASING.md](docs/RELEASING.md) | How a release and the website get built and published |
| [docs/playtests.md](docs/playtests.md) | The record the game keeps of each game you play, and how to replay one |
| [docs/balance.md](docs/balance.md) | What the balance bots found, and why the numbers are what they are |
| [docs/perf.md](docs/perf.md) | Performance measurements and what was done about them |
| [docs/PLAN.md](docs/PLAN.md) | The original build plan, kept for the record |

## Credits

Models and textures are CC0, from Quaternius, KayKit, Kenney and OpenGameArt artists. Sound is CC0 and CC-BY. The fonts, Cinzel and Fira Sans, are under the Open Font License. The full list with attribution is in [assets/CREDITS.md](assets/CREDITS.md).
