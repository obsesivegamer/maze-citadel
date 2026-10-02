# Releasing

Pushing a version tag builds the Mac .dmg on GitHub's macOS runners, verifies it, publishes it as a GitHub Release and refreshes the download site. Everything here runs from `.github/workflows/release-mac.yml` and `.github/workflows/site.yml`.

## Cut a release

1. Set the version in three places: `config/version` in `project.godot`, and `application/short_version` and `application/version` in `export_presets.cfg`. Verification fails if the app's version and `project.godot` disagree.
2. Merge to `main`.
3. Tag the merge and push the tag:
   ```sh
   git tag v0.2.0 && git push origin v0.2.0
   ```
   A tag with a suffix, like `v0.2.0-beta.1`, is published as a pre-release, and the site labels it "Early access".
4. Watch **Actions → Mac release**. When it's green, the release has `MazeCitadel-<version>.dmg`, its `.sha256` and `build-info.json`, and the **Download site** workflow has been started on `main`.

To build and verify without releasing, run **Actions → Mac release → Run workflow**. The .dmg is attached to the run for 14 days. Pull requests that change the pipeline do the same automatically.

On a Mac, the same checks run locally:

```sh
tools/export.sh && tools/verify_dmg.sh
```

## What the pipeline checks

| Stage | Where | Checks |
|---|---|---|
| Gate | Linux | `tools/check.sh`: import, asset licenses, lint, format, unit tests, headless smoke run |
| Export | macOS 15 | `tools/export.sh` with Godot 4.7.2 and its macOS template, checksummed against Godot's `SHA512-SUMS.txt` |
| Image | macOS 15 | `hdiutil verify`, compressed UDZO format, mounts read-only, `Maze Citadel.app` and the Applications shortcut at the root |
| Bundle | macOS 15 | bundle id, app version equals `project.godot`, arm64-only binary, minimum macOS |
| Signature | macOS 15 | `codesign --verify --deep --strict`; Gatekeeper and stapled ticket when notarized (required once notarization secrets exist) |
| Game | macOS 15 | the exported game runs 5400 frames headless with the autoplay bot, straight from the mounted image, with no script or engine errors |
| Window | your Mac only | `LAUNCH_CHECK=1 ALLOW_WINDOW=1 tools/verify_dmg.sh` opens the game in a real window and saves `dist/launch-full.png`. GitHub's virtual Macs lack GPU features the renderer needs, so CI skips this |

## Download site

`site/index.html` is the page. `tools/build_site.py` fills it from the newest release (version, size, date, checksum, minimum macOS, notarized or not) and writes `build/site/`. Preview it with:

```sh
python3 tools/build_site.py && open build/site/index.html
```

It deploys to GitHub Pages when the site changes on `main`, after each release, or from **Actions → Download site → Run workflow**. Until Pages is turned on, the workflow builds the site and skips the deploy.

**Turning on Pages:** repository **Settings → Pages → Build and deployment → Source: GitHub Actions**, then run the Download site workflow once. The address is `https://obsesivegamer.github.io/maze-citadel/` unless you add a custom domain on the same settings page.

**Private repo:** Pages on a private repository needs a paid GitHub plan (Pro or above). The site itself is public either way. Release files of a private repo need a GitHub login to download, so the build copies the .dmg into the site and serves it from there. On a public repo the button links to the release file instead.

## Signing and notarization (optional)

Without them, builds are ad-hoc signed. That works, but the first launch on macOS 15 or later shows "Apple could not verify Maze Citadel is free of malware", and players have to click **Open Anyway** in **System Settings → Privacy & Security**. The site explains this. Signed and notarized builds open with a double-click, and the site drops that step on its own.

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

- **Actions minutes:** the Mac job takes about 4 minutes and the Linux gate under 1. On a private repo macOS minutes count ten times against the plan's monthly Actions quota (GitHub Free includes 2,000), so one release costs about 40 of them. Public repos run free.
- **Git LFS bandwidth:** the runs cache LFS objects, so only new or changed assets are downloaded.
