# Releasing

This page explains how a new version of Maze Citadel gets built, checked and published, and how the website at [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/) is kept up to date.

## Overview

Releasing takes one action: pushing a version tag. GitHub then builds the Mac `.dmg` on a macOS runner and the Windows `.zip` and Linux `.tar.gz` on a Linux runner, verifies each build on its own operating system, publishes all three as a GitHub Release, and refreshes the website so the download buttons point at the new builds. Nothing is built or uploaded by hand. Two workflows do the work, `.github/workflows/release.yml` and `.github/workflows/site.yml`.

## Cut a release

1. Set the version in three places: `config/version` in `project.godot`, and `application/short_version` and `application/version` in `export_presets.cfg`. Verification fails if the app's version and `project.godot` disagree.
2. Merge to `main`.
3. Tag the merge and push the tag:
   ```sh
   git tag v0.2.0 && git push origin v0.2.0
   ```
   A tag with a suffix, like `v0.2.0-beta.1`, is published as a pre-release, and the site labels it "Early access".
4. Watch **Actions → Release**. When it's green, the release has nine files: `MazeCitadel-<version>.dmg`, `MazeCitadel-<version>-windows-x86_64.zip` and `MazeCitadel-<version>-linux-x86_64.tar.gz`, a `.sha256` for each, and `build-info.json`, `build-info-windows.json` and `build-info-linux.json`. The **Download site** workflow has been started on `main`.

To build and verify without releasing, run **Actions → Release → Run workflow**. The builds are attached to the run for 14 days. Pull requests that change the pipeline do the same automatically.

On a Mac, the same builds and the Mac checks run locally. The Windows and Linux exports need Godot's `windows_release_x86_64.exe` and `linux_release.x86_64` templates next to the macOS one, and their checks run the game, so they only pass on Windows (Git Bash) or Linux:

```sh
tools/export.sh && tools/verify_dmg.sh
tools/export_pc.sh            # after export.sh, which empties dist/
tools/verify_pc.sh linux      # on Linux; tools/verify_pc.sh windows on Windows
```

## What the pipeline checks

| Stage | Where | Checks |
|---|---|---|
| Gate | Linux | `tools/check.sh`: import, asset licenses, lint, format, unit tests, headless smoke runs of both maps under both rule sets |
| Export | macOS 15 | `tools/export.sh` with Godot 4.7.2 and its macOS template, checksummed against Godot's `SHA512-SUMS.txt` |
| Image | macOS 15 | `hdiutil verify`, compressed UDZO format, mounts read-only, `Maze Citadel.app` and the Applications shortcut at the root |
| Bundle | macOS 15 | bundle id, app version equals `project.godot`, arm64-only binary, minimum macOS |
| Signature | macOS 15 | `codesign --verify --deep --strict`; Gatekeeper and stapled ticket when notarized (required once notarization secrets exist) |
| Game | macOS 15 | the exported game runs 5400 frames headless with the autoplay bot, straight from the mounted image, with no script or engine errors |
| Window | your Mac only | `LAUNCH_CHECK=1 ALLOW_WINDOW=1 tools/verify_dmg.sh` opens the game in a real window and saves `dist/launch-full.png`. GitHub's virtual Macs lack GPU features the renderer needs, so CI skips this |
| PC export | Linux | `tools/export_pc.sh` with the same Godot and its Windows and Linux templates: x86_64, the game data embedded in the executable, one folder with one file in each archive |
| PC archives | Linux, Windows Server 2025 | `tools/verify_pc.sh`: the archive holds only `MazeCitadel/<executable>`, the executable is x86_64 with the game data inside, and on Windows its version matches `project.godot` |
| PC game | Linux, Windows Server 2025 | each build runs 5400 frames headless with the autoplay bot from its unpacked folder, with no script or engine errors |
| PC window | Linux | the Linux build opens a window on a virtual display and renders with Mesa's software Vulkan driver, saving `launch-linux-full.png` to the run's artifacts. It's slow and only warns on failure. Nothing in CI renders on a real PC graphics card, so test a new PC build on real hardware before announcing it |

## The website

The website is live at **[obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/)**, served by GitHub Pages.

`site/index.html` is the page. `tools/build_site.py` fills it in from the newest release (version, size, date, checksum, minimum macOS, and whether the build is notarized) and writes the result to `build/site/`. The tower roster and the tower, Epic, wave and map counts come from the game's own data (`src/data/tower_defs.gd`, `src/data/wave_defs.gd`, `src/data/map_defs.gd` and `src/ui/tower_info.gd`), so a balance change shows up on the website at the next deploy. Preview it with:

```sh
python3 tools/build_site.py && open build/site/index.html
```

The website deploys when the site or the game data it shows changes on `main`, after each release, or when you run **Actions → Download site → Run workflow**.

**If Pages is off**, as it would be on a fork, the workflow still builds the site and skips the deploy. To turn Pages on, go to the repository's **Settings → Pages → Build and deployment → Source: GitHub Actions**, then run the Download site workflow once. The address is `https://<owner>.github.io/<repository>/` unless you add a custom domain on the same settings page.

**If the repository is private**, Pages needs a paid GitHub plan (Pro or above). The website itself is public either way. Release files of a private repository need a GitHub login to download, so the build copies the downloads into the site and serves them from there. On a public repository, which this one is, the download button links to the release file instead.

## Signing and notarization (optional)

The Windows build is unsigned, so the first launch shows Microsoft Defender SmartScreen's "Windows protected your PC". Players click **More info → Run anyway** once, and the website says so. Signing it would need a paid code-signing certificate, which the pipeline doesn't support yet. Linux builds aren't signed.

On the Mac, builds without signing and notarization are ad-hoc signed. That works, but the first launch on macOS 15 or later shows "Apple could not verify Maze Citadel is free of malware", and players have to click **Open Anyway** in **System Settings → Privacy & Security**. The site explains this. Signed and notarized builds open with a double-click, and the site drops that step on its own.

You need an [Apple Developer Program](https://developer.apple.com/programs/) membership. Then add these as repository secrets under **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | What it is |
|---|---|
| `MACOS_CERTIFICATE_P12_BASE64` | Your **Developer ID Application** certificate and its private key, exported as a .p12 and base64-encoded |
| `MACOS_CERTIFICATE_PASSWORD` | The password you set when exporting the .p12 |
| `APPLE_ID` | The Apple Account email of your developer account |
| `APPLE_TEAM_ID` | Your 10-character Team ID, from Membership details at developer.apple.com |
| `APPLE_APP_PASSWORD` | An app-specific password for the notary service, made at account.apple.com under Sign-In and Security |

Getting the certificate into a secret:

1. In Xcode: **Settings → Accounts → Manage Certificates → + → Developer ID Application** (only the team's Account Holder can create one).
2. In Keychain Access, under **My Certificates**, right-click **Developer ID Application: …** → **Export**, save as .p12 with a password.
3. `base64 -i Certificates.p12 | pbcopy` and paste it as `MACOS_CERTIFICATE_P12_BASE64`. Delete the .p12 file afterwards.

With the two certificate secrets the build is signed with your Developer ID and hardened runtime. With all five it is also notarized and stapled, and verification then fails any build Gatekeeper wouldn't accept. Never paste these values into chat, issues or commits.

## Costs

- **Actions minutes:** the Mac job takes about 4 minutes and the Linux gate under 1. The Windows and Linux builds add a Linux job and a Windows job. On a private repo macOS minutes count ten times and Windows minutes twice against the plan's monthly Actions quota (GitHub Free includes 2,000). Public repos run free.
- **Git LFS bandwidth:** the runs cache LFS objects, so only new or changed assets are downloaded.
