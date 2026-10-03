# Installing Maze Citadel

**Website and download: [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/)**

This guide has two parts. [Part 1](#part-1-install-and-play) is for playing the game, and it's all most people need. [Part 2](#part-2-build-from-source) is for building the game from its source code.

## Overview

Maze Citadel is a single Mac app that comes in a disk image. There is no installer, no account, no launcher and nothing extra to download. You drag the app to Applications, allow it once in System Settings, and play. The game never goes online.

It runs on Macs with Apple silicon and macOS 13 Ventura or later. It doesn't run on Intel Macs, and there's no Windows or Linux build.

## Part 1: Install and play

### What you need

| | |
|---|---|
| **Mac** | Apple silicon, M1 or later. Intel Macs aren't supported. |
| **macOS** | 13 Ventura or later |
| **Free space** | About 200 MB. The download is a little over 100 MB and the app is about 160 MB once copied. |
| **Internet** | Only for the download. The game runs offline. |
| **Extra software** | None. Everything is inside the app. |

Maze Citadel is tested on a MacBook Air 13-inch M3 with an 8-core GPU and 16 GB of memory, on macOS 26.6.2. On that Mac the default Balanced preset runs at 60 fps. It is the only Mac the game has been measured on so far, so treat other models as untested rather than unsupported.

### Step by step

1. **Download the game.** Open [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/) and click **Download for Mac**. The file is named `MazeCitadel-<version>.dmg`, for example `MazeCitadel-0.2.0.dmg`, and lands in your Downloads folder. The [Releases page](https://github.com/obsesivegamer/maze-citadel/releases/latest) has the same file.

2. **Open the disk image.** Double-click the `.dmg`. A window opens with the **Maze Citadel** app and a shortcut to your **Applications** folder.

3. **Drag Maze Citadel onto Applications.** If you'd rather not install it, skip this and run the app from the disk image window.

4. **Open it and expect a warning.** Double-click Maze Citadel. macOS says "Apple could not verify Maze Citadel is free of malware". This appears because the app isn't notarized by Apple yet, which takes a paid Apple developer membership. It doesn't mean something is wrong with your download. Click **Done**.

5. **Allow it in System Settings.** Open **System Settings → Privacy & Security** and scroll down to **Security**. You'll see a note about Maze Citadel with an **Open Anyway** button. Click it and confirm when macOS asks, which may include typing your login password. The button only shows up after step 4, and it stays for about an hour.

   On macOS 13 or 14 there's a shorter route: Control-click the app, choose **Open**, then **Open** again.

6. **Play.** macOS remembers your choice, so from now on the game opens with a normal double-click. The first launch stays on the loading screen for about 20 seconds while the game prepares its graphics for your Mac. Later launches take about 4 seconds.

Once the app is in Applications, you can eject the disk image and delete the `.dmg`.

### Check the download (optional)

Each release comes with a SHA-256 checksum, a fingerprint of the file. If the fingerprint of your download matches, the file is exactly the one that was published. In Terminal:

```sh
shasum -a 256 ~/Downloads/MazeCitadel-0.2.0.dmg
```

Compare the result with the checksum in the Install section of the website, or with the `.sha256` file next to the `.dmg` on the Releases page.

### Update

The game doesn't check for updates, because it never goes online. To update, download the newest `.dmg` from the website and drag the app to Applications again, choosing **Replace**. Your settings and best waves are kept, since they live outside the app. macOS treats the new download as a new app, so expect the **Open Anyway** step once more.

### Uninstall

Drag **Maze Citadel** from Applications to the Trash. To remove your settings and scores as well, delete this folder:

```
~/Library/Application Support/Maze Citadel/
```

### Where the game keeps its files

Everything the game writes goes into `~/Library/Application Support/Maze Citadel/`.

| File or folder | What it holds |
|---|---|
| `save.cfg` | Your best wave and score for each map and mode, the quality preset, the volume sliders and the other settings |
| `shader_cache/` | Graphics programs the game compiled for your Mac. It's safe to delete. The next launch rebuilds it and takes the longer first-launch time again. |
| `logs/` | Text logs from recent runs, which help when tracking down a problem |

### If something goes wrong

**"Apple could not verify Maze Citadel is free of malware."** This is the expected first-launch warning. Follow steps 4 and 5 above.

**There's no Open Anyway button.** It only appears after you've tried to open the app, and it goes away after about an hour. Double-click the app again, click **Done**, and go back to **Privacy & Security**.

**The app won't open at all.** Check **Apple menu → About This Mac**. The chip has to be an Apple M-series chip and macOS has to be 13 or later. The app has no Intel version.

**The first launch seems stuck on the loading screen.** Give it half a minute. The first launch compiles every graphics effect up front so the game doesn't stutter later, and that takes about 20 seconds on an M3 MacBook Air.

**The game stutters or runs slowly.** Open Settings with the gear on the top bar and switch the quality preset to **Performance**. Quitting other apps that use the graphics chip heavily also helps. On a MacBook Air, which has no fan, a long session of late waves warms the machine up, and Balanced can drop from 60 to about 57 fps. Performance holds 60 there.

**You want the tutorial back.** Turn it on under **Settings → Help → Tutorial**.

**You want to start fresh.** Quit the game and delete `save.cfg` from the folder above. This resets your settings and best waves.

### Technical details

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

The game has three quality presets. They only change how the game looks, never the rules, the maze or the waves.

| Preset | What it does |
|---|---|
| **Cinematic** | Renders the 3D scene at 70% resolution and upscales it with MetalFX, with the best shadows, fog and ambient shading |
| **Balanced** (default) | Renders at 50% resolution with MetalFX upscaling and lighter shadows, fog and shading. This is the preset tuned to hold 60 fps on the M3 MacBook Air. |
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
| Godot macOS export templates | 4.7.2 | Turning the project into a `.app`. Only needed for `tools/export.sh`. |
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
| `--map=rampart` | Start on Fallen Rampart. `--map=citadel` is the default board. |
| `--quality=performance` | Start on a quality preset: `cinematic`, `balanced` or `performance` |
| `--twists --seed=7` | Play Twists mode with a fixed schedule of twists |
| `--autoplay` | Let the bot play |
| `--tutorial` | Show the tutorial even if it has been turned off |

For example:

```sh
godot --path . -- --map=rampart --quality=performance
```

A game run from source uses the same save folder as the installed app.

### 4. Run the checks

```sh
tools/check.sh
```

This is the one command to run before committing. It imports the project, checks that every asset has a listed license, tests the benchmark scripts, lints and format-checks the code, runs the unit tests, and has the bot play both maps with no window. It finishes with `check: OK`.

### 5. Build the app

Building needs the macOS export templates for Godot 4.7.2. The simple way is from the editor: **Editor → Manage Export Templates → Download and Install**. That keeps templates for every platform, which is over 1 GB. The release workflow keeps only the macOS one, and you can do the same from the command line:

```sh
base="https://github.com/godotengine/godot/releases/download/4.7.2-stable"
curl -fsSLO "$base/Godot_v4.7.2-stable_export_templates.tpz"
dest="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable"
mkdir -p "$dest"
unzip -q -j -o Godot_v4.7.2-stable_export_templates.tpz templates/macos.zip templates/version.txt -d "$dest"
rm Godot_v4.7.2-stable_export_templates.tpz
```

Then build and verify:

```sh
tools/export.sh        # writes dist/MazeCitadel.app and dist/MazeCitadel-<version>.dmg
tools/verify_dmg.sh    # mounts the .dmg, checks it, and runs the game from it
```

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
