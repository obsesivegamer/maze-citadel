# Installing Maze Citadel

**Website and download: [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/)**

This guide has two parts. [Part 1](#part-1-install-and-play) is for playing the game, and it's all most people need. [Part 2](#part-2-build-from-source) is for building the game from its source code.

## Overview

Maze Citadel runs on Mac, Windows and Linux. On a Mac it's a single app that comes in a disk image: you drag it to Applications, allow it once in System Settings, and play. On Windows and Linux it's a single program in a zip or tar.gz archive: you unpack it anywhere and run it. There is no installer, no account, no launcher and nothing extra to download, and the game never goes online.

The Mac version runs on Macs with Apple silicon and macOS 13 Ventura or later, not on Intel Macs. The Windows version runs on 64-bit Windows 10 and 11, and the Linux version on 64-bit x86 distributions. Windows needs a graphics card with Vulkan or Direct3D 12 support, and Linux one with Vulkan support. It's the same game on all three, with the same saves.

The Windows and Linux builds are new in 0.3.0 and less tested than the Mac build. The Windows build has been measured on one PC so far, and the Linux build's frame rate hasn't been measured yet. Releases up to 0.2.0 are Mac only.

## Part 1: Install and play

Pick the section for your computer: [Mac](#on-a-mac), [Windows](#on-windows) or [Linux](#on-linux). The sections after those, from checking the download to troubleshooting, cover all three.

### On a Mac

#### What you need

| | |
|---|---|
| **Mac** | Apple silicon, M1 or later. Intel Macs aren't supported. |
| **macOS** | 13 Ventura or later |
| **Free space** | About 200 MB. The download is a little over 100 MB and the app is about 160 MB once copied. |
| **Internet** | Only for the download. The game runs offline. |
| **Extra software** | None. Everything is inside the app. |

Maze Citadel is tested on a MacBook Air 13-inch M3 with an 8-core GPU and 16 GB of memory, on macOS 26.6.2. On that Mac the default Balanced preset runs at 60 fps. It is the only Mac the game has been measured on so far, so treat other models as untested rather than unsupported.

#### Step by step

1. **Download the game.** Open [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/) and click **Download for Mac**. The file is named `MazeCitadel-<version>.dmg`, for example `MazeCitadel-0.2.0.dmg`, and lands in your Downloads folder. The [Releases page](https://github.com/obsesivegamer/maze-citadel/releases/latest) has the same file.

2. **Open the disk image.** Double-click the `.dmg`. A window opens with the **Maze Citadel** app and a shortcut to your **Applications** folder.

3. **Drag Maze Citadel onto Applications.** If you'd rather not install it, skip this and run the app from the disk image window.

4. **Open it and expect a warning.** Double-click Maze Citadel. macOS says "Apple could not verify Maze Citadel is free of malware". This appears because the app isn't notarized by Apple yet, which takes a paid Apple developer membership. It doesn't mean something is wrong with your download. Click **Done**.

5. **Allow it in System Settings.** Open **System Settings → Privacy & Security** and scroll down to **Security**. You'll see a note about Maze Citadel with an **Open Anyway** button. Click it and confirm when macOS asks, which may include typing your login password. The button only shows up after step 4, and it stays for about an hour.

   On macOS 13 or 14 there's a shorter route: Control-click the app, choose **Open**, then **Open** again.

6. **Play.** macOS remembers your choice, so from now on the game opens with a normal double-click. The first launch stays on the loading screen for about 20 seconds while the game prepares its graphics for your Mac. Later launches take about 4 seconds.

Once the app is in Applications, you can eject the disk image and delete the `.dmg`.

### On Windows

#### What you need

| | |
|---|---|
| **Windows** | Windows 10 or 11, 64-bit |
| **Graphics** | A graphics card with Vulkan or Direct3D 12 support, roughly 2016 or newer |
| **Internet** | Only for the download. The game runs offline. |
| **Extra software** | None. Everything is inside `MazeCitadel.exe`. |

The Windows build is new and less tested than the Mac build. It has been measured on one PC so far, with a Radeon RX 6950 XT at 3440 × 1440, where the default Balanced preset runs well above 60 fps ([perf.md](perf.md#windows-check-2026-10-03)). Slower graphics cards haven't been measured. If it runs slowly, the Performance preset in Settings is the lightest.

#### Step by step

1. **Download the game.** Open [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/) and click **Download for Windows**. The file is named `MazeCitadel-<version>-windows-x86_64.zip` and lands in your Downloads folder. The [Releases page](https://github.com/obsesivegamer/maze-citadel/releases/latest) has the same file.

2. **Unzip it.** Right-click the zip and choose **Extract All**. You get a `MazeCitadel` folder with one file in it, `MazeCitadel.exe`, which holds the whole game. Put the folder wherever you like.

3. **Run it and expect a warning.** Double-click `MazeCitadel.exe`. Windows shows "Windows protected your PC". This appears because the game isn't code-signed yet, which takes a paid certificate. It doesn't mean something is wrong with your download. Click **More info**, then **Run anyway**.

4. **Play.** Windows remembers your choice, so from now on the game opens with a normal double-click. The first launch stays on the loading screen longer than later ones while the game prepares its graphics for your computer.

### On Linux

#### What you need

| | |
|---|---|
| **Linux** | A 64-bit x86 distribution with up-to-date graphics drivers |
| **Graphics** | A graphics card with Vulkan support, roughly 2016 or newer |
| **Internet** | Only for the download. The game runs offline. |
| **Extra software** | None besides the graphics drivers. Everything is inside `MazeCitadel.x86_64`. |

The Linux build is new and less tested than the Mac build, and its frame rate hasn't been measured yet. If it runs slowly, the Performance preset in Settings is the lightest.

#### Step by step

1. **Download the game.** Open [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/) and click **Download for Linux**. The file is named `MazeCitadel-<version>-linux-x86_64.tar.gz`. The [Releases page](https://github.com/obsesivegamer/maze-citadel/releases/latest) has the same file.

2. **Extract it.** Use your file manager's extract option, or a terminal:

   ```sh
   tar -xzf MazeCitadel-<version>-linux-x86_64.tar.gz
   ```

   You get a `MazeCitadel` folder with one file in it, `MazeCitadel.x86_64`, which holds the whole game. Put the folder wherever you like.

3. **Run it.** Double-click `MazeCitadel.x86_64` in your file manager, or start it from a terminal in that folder:

   ```sh
   ./MazeCitadel.x86_64
   ```

4. **Play.** The first launch stays on the loading screen longer than later ones while the game prepares its graphics for your computer.

### Check the download (optional)

Each release comes with a SHA-256 checksum for every download, a fingerprint of the file. If the fingerprint of your download matches, the file is exactly the one that was published.

On a Mac, in Terminal:

```sh
shasum -a 256 ~/Downloads/MazeCitadel-0.2.0.dmg
```

On Windows, in PowerShell:

```powershell
Get-FileHash ~\Downloads\MazeCitadel-<version>-windows-x86_64.zip
```

Or in Command Prompt:

```bat
certutil -hashfile %USERPROFILE%\Downloads\MazeCitadel-<version>-windows-x86_64.zip SHA256
```

PowerShell prints the checksum in capital letters. The case doesn't matter.

On Linux, in a terminal:

```sh
sha256sum ~/Downloads/MazeCitadel-<version>-linux-x86_64.tar.gz
```

Compare the result with the checksum in the Install section of the website, or with the `.sha256` file next to the download on the Releases page.

### Update

The game doesn't check for updates, because it never goes online. Your settings and best waves are kept across updates, since they live outside the game.

- **Mac:** download the newest `.dmg` from the website and drag the app to Applications again, choosing **Replace**. macOS treats the new download as a new app, so expect the **Open Anyway** step once more.
- **Windows and Linux:** download the newest archive, extract it, and replace your old `MazeCitadel` folder with the new one. On Windows, expect the SmartScreen step once more.

### Uninstall

On a Mac, drag **Maze Citadel** from Applications to the Trash. On Windows or Linux, delete the `MazeCitadel` folder. To remove your settings and scores as well, delete the game's data folder:

| | |
|---|---|
| **Mac** | `~/Library/Application Support/Maze Citadel/` |
| **Windows** | `%APPDATA%\Maze Citadel\` |
| **Linux** | `~/.local/share/Maze Citadel/`, or `$XDG_DATA_HOME/Maze Citadel/` if you've set `XDG_DATA_HOME` |

### Where the game keeps its files

Everything the game writes goes into its data folder, the one in the table above for your system. Godot, the engine the game is built with, picks these folders; they're the ones its [file paths guide](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html) lists for a game with its own data folder name.

| File or folder | What it holds |
|---|---|
| `save.cfg` | Your best wave and score for each map and mode, the quality preset, the volume sliders and the other settings |
| `shader_cache/` | Graphics programs the game compiled for your computer. It's safe to delete. The next launch rebuilds it and takes the longer first-launch time again. |
| `playtests/` | A record of each game you play: your moves and what each wave did. They help tune the difficulty and are never sent anywhere ([playtests.md](playtests.md)). Turn them off under **Settings → Playtest → Game records**; deleting them is safe. |
| `logs/` | Text logs from recent runs, which help when tracking down a problem |

### If something goes wrong

**"Apple could not verify Maze Citadel is free of malware."** This is the expected first-launch warning on a Mac. Follow steps 4 and 5 of the Mac steps above.

**There's no Open Anyway button.** It only appears after you've tried to open the app, and it goes away after about an hour. Double-click the app again, click **Done**, and go back to **Privacy & Security**.

**The Mac app won't open at all.** Check **Apple menu → About This Mac**. The chip has to be an Apple M-series chip and macOS has to be 13 or later. The app has no Intel version.

**"Windows protected your PC" with only a Don't run button.** Click **More info** first. The **Run anyway** button appears below the app's name.

**The game doesn't start on Windows or Linux.** Update your graphics drivers, from your graphics card maker on Windows or from your distribution on Linux. The game needs a graphics card with Vulkan support, or on Windows one with Direct3D 12. On Linux, starting the game from a terminal shows its messages, which say what went wrong. Graphics cards with neither still run the game through Godot's simpler OpenGL renderer, which looks softer and has no fog or ambient shading.

**"Smart App Control blocked an app that may be unsafe."** Windows 11's stricter Smart App Control mode is on, and it blocks unsigned programs with no **Run anyway** option. The Windows build can't run while that mode is on; a code-signed build would fix this.

**"Permission denied" on Linux.** The archive marks `MazeCitadel.x86_64` as a program, but some extract tools drop that mark. Restore it with `chmod +x MazeCitadel.x86_64`.

**The first launch seems stuck on the loading screen.** Give it half a minute. The first launch compiles every graphics effect up front so the game doesn't stutter later, and that takes about 20 seconds on an M3 MacBook Air.

**The game stutters or runs slowly.** Open Settings with the gear on the top bar and switch the quality preset to **Performance**. Quitting other apps that use the graphics chip heavily also helps. On a MacBook Air, which has no fan, a long session of late waves warms the machine up, and Balanced can drop from 60 to about 57 fps. Performance holds 60 there.

**You want the tutorial back.** Turn it on under **Settings → Help → Tutorial**.

**You want to start fresh.** Quit the game and delete `save.cfg` from the folder above. This resets your settings and best waves.

### Technical details

On a Mac:

| | |
|---|---|
| **Engine** | Godot 4.7.2, using its Forward+ renderer on Metal |
| **App** | `Maze Citadel.app`, built for Apple silicon only (arm64), bundle identifier `com.obsesivegamer.mazecitadel` |
| **Minimum macOS** | 13.0 |
| **Signing** | Ad-hoc signed and not notarized, which is why the first launch needs **Open Anyway** |
| **Size** | A little over 100 MB as a `.dmg`, about 160 MB installed |
| **Window** | Opens maximized and draws at Retina resolution |
| **Network** | None. The game makes no connections. |
| **Video memory** | About 1 GB on the Balanced preset on the test Mac |

On Windows and Linux:

| | |
|---|---|
| **Engine** | Godot 4.7.2, using its Forward+ renderer on Vulkan. On Windows, Direct3D 12 takes over if Vulkan fails to start. Upscaling is AMD FSR instead of MetalFX. |
| **Size** | About 110 MB to download; the program is about 180 MB on Windows and 150 MB on Linux |
| **Program** | `MazeCitadel.exe` on Windows and `MazeCitadel.x86_64` on Linux, built for 64-bit x86 only, with the game data inside the program |
| **Signing** | The Windows program isn't code-signed, which is why the first run needs **Run anyway** |
| **Network** | None. The game makes no connections. |

The game has three quality presets. They only change how the game looks, never the rules, the maze or the waves.

| Preset | What it does |
|---|---|
| **Cinematic** | Renders the 3D scene at 70% resolution and upscales it with MetalFX (AMD FSR 2 on Windows and Linux), with the best shadows, fog and ambient shading |
| **Balanced** (default) | Renders at 50% resolution with MetalFX upscaling and lighter shadows, fog and shading. This is the preset tuned to hold 60 fps on the M3 MacBook Air. On Windows and Linux it uses FSR 2 and keeps at least 720 pixels of height, so a 1080p screen renders at about 70%. |
| **Performance** | Renders at 50% resolution with a simpler upscaler, low shadows, no fog or ambient shading, and fewer particles, villagers and plants |

The exact settings are in [GDD.md](GDD.md#14-quality-presets), and the measurements behind them are in [perf.md](perf.md).

## Part 2: Build from source

You only need this part if you want to change the game or build the app yourself.

### What you need

| Tool | Version | What it's for |
|---|---|---|
| A Mac with Apple silicon | | Building the app. The export script produces an arm64 app and uses macOS tools to sign and package it. |
| Xcode Command Line Tools | | `git`, Python 3 and `lipo` |
| [Homebrew](https://brew.sh/) | | The easiest way to install the rest |
| [Godot](https://godotengine.org/) | 4.7.2 | The engine and editor |
| Godot export templates | 4.7.2 | Turning the project into a `.app` (macOS template, for `tools/export.sh`) or Windows and Linux builds (for `tools/export_pc.sh`) |
| [Git LFS](https://git-lfs.com/) | | Every model, texture, sound and font is stored in LFS |
| [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) | 4.x | `gdlint` and `gdformat`, which the checks run |
| Python 3 | | The asset license check and the website build. They use only the standard library. |

The code checks also run on Linux, which is where the release workflow runs them. Building the app needs a Mac.

### 1. Install the tools

```sh
xcode-select --install             # skip if the Command Line Tools are already installed
brew install --cask godot
brew install git-lfs pipx
git lfs install
pipx install "gdtoolkit==4.*"
```

Check that you have the right Godot:

```sh
godot --version                    # should start with 4.7.2
```

The project is pinned to Godot 4.7.2. Homebrew installs whatever is current, so if that has moved on, download 4.7.2 from the [Godot archive](https://godotengine.org/download/archive/) instead. Every script calls `godot` from your `PATH`. If your copy lives somewhere else, point the scripts at it:

```sh
export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
```

### 2. Get the code and assets

```sh
git clone https://github.com/obsesivegamer/maze-citadel.git
cd maze-citadel
```

With Git LFS installed, the clone brings the real assets with it. If you installed LFS after cloning, the models and textures are still small placeholder files, and this fetches the real ones:

```sh
git lfs pull
```

### 3. Import and run

Godot has to import the assets once before the project runs:

```sh
godot --headless --path . --import
```

Then start the game:

```sh
godot --path .
```

To open the project in the Godot editor instead, add `-e`. Options for the game itself go after a `--`:

| Option | What it does |
|---|---|
| `--map=rampart` | Start on Fallen Rampart. `--map=causeway` starts on the Winding Causeway, which needs the Element TD rules, and `--map=citadel` is the default board. |
| `--quality=performance` | Start on a quality preset: `cinematic`, `balanced` or `performance` |
| `--twists --seed=7` | Play Twists mode with a fixed schedule of twists |
| `--rules=classic` | Play the classic rules, the game as it was in 0.3.1. `--rules=eletd` plays the Element TD rules. Without either the game plays the rules you last picked, and on a first launch the Element TD rules |
| `--difficulty=hard` | Start on a difficulty: `easy`, `normal`, `hard` or `very_hard`. The classic rules offer only `normal` and `hard` |
| `--picks=aqua,dark,dark,interest` | Under the Element TD rules, start with these element levels and Interest picks already taken, with no Guardians to kill. They come on top of the picks the game hands out. Meant for tests, screenshots and experiments. |
| `--autoplay` | Let the bot play |
| `--tutorial` | Show the tutorial even if it has been turned off |
| `--no-tutorial` | Skip the tutorial and the setup panel, and start the opening countdown at once on Normal, or what the other options say |
| `--warp-wave=24` | Fast-forward to the start of a wave; `--warp-into=10` goes on that many seconds into it |
| `--select=archer` | Select a tower, by tile (`--select=9,14`) or the first of a kind |
| `--open=pick` | Open the pick panel, the Field Guide (`guide`), its Elements and picks page (`elements`), Settings (`settings`), the pause menu (`menu`) or the setup panel (`setup`). Any panel but `setup` keeps the setup panel away, so it doesn't cover the one asked for |
| `--shot=build/shots/m3 --views=full,portal,gate` | Save one screenshot per camera preset and quit, as `build/shots/m3-full.png` and so on. `--shot-frames=n` saves n frames per view and `--shot-freeze` stops game time while it does. `tools/capture.sh` runs a set of these |

For example:

```sh
godot --path . -- --map=rampart --quality=performance
```

A game run from source uses the same save folder as the installed app.

### 4. Run the checks

```sh
tools/check.sh
```

This is the one command to run before committing. It imports the project, checks that every asset has a listed license, tests the benchmark scripts, lints and format-checks the code, runs the unit tests, and has the bot play the Citadel and the Rampart under both rule sets, and the Causeway under Element TD, with no window. It finishes with `check: OK`.

### 5. Build the app

Building needs Godot 4.7.2's export templates: the macOS one for the app, and the Windows and Linux ones for the PC builds. The simple way is from the editor: **Editor → Manage Export Templates → Download and Install**. That keeps templates for every platform, which is over 1 GB. The release workflow keeps only the templates each build needs, and you can do the same from the command line:

```sh
base="https://github.com/godotengine/godot/releases/download/4.7.2-stable"
curl -fsSLO "$base/Godot_v4.7.2-stable_export_templates.tpz"
dest="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
mkdir -p "$dest"
unzip -q -j -o Godot_v4.7.2-stable_export_templates.tpz templates/macos.zip templates/version.txt -d "$dest"
# Only for the Windows and Linux builds:
unzip -q -j -o Godot_v4.7.2-stable_export_templates.tpz templates/windows_release_x86_64.exe \
  templates/linux_release.x86_64 -d "$dest"
rm Godot_v4.7.2-stable_export_templates.tpz
```

Then build and verify:

```sh
tools/export.sh        # writes dist/MazeCitadel.app and dist/MazeCitadel-<version>.dmg
tools/verify_dmg.sh    # mounts the .dmg, checks it, and runs the game from it
tools/export_pc.sh     # writes the Windows .zip and Linux .tar.gz; run it after export.sh
```

The Windows and Linux builds can be made on a Mac. Checking them with `tools/verify_pc.sh windows` or `tools/verify_pc.sh linux` runs the game, so that only works on Windows (in Git Bash) or Linux; the release workflow does it for every release.

The build is ad-hoc signed, the same as the published download. A copy you build yourself opens with a double-click on the Mac that built it.

### Tools that open windows

A few tools open real game windows and take over the screen while they run: `tools/capture.sh` for screenshots, `tools/bench.sh` for benchmarks, and `tools/slot.sh`, which runs both and then a launch test. They refuse to start unless you set `ALLOW_WINDOW=1`, so they never surprise you in the middle of other work:

```sh
ALLOW_WINDOW=1 tools/slot.sh
```

### Where to go next

- [ARCHITECTURE.md](ARCHITECTURE.md) explains how the code is organised.
- [RELEASING.md](RELEASING.md) explains how a version tag becomes a release and a website update.
- [GDD.md](GDD.md) is the reference for every rule and number in the game.
