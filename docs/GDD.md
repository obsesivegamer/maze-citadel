# Maze Citadel — Game Design

The numbers below are **starting values**. The balance sim in M6 tunes them; when it does, this file gets updated in the same commit.

Inspirations: Element TD (element counters, leaks that loop), Gem TD (fusion), Wintermaul One (open mazing, anti-block), Poker TD / Cube Defense (cheap filler + tech towers). Not a clone: no Blizzard names, models or sounds ship.

---

## 1. Board and first frame

| Item | Value |
|---|---|
| Buildable plateau | 20 × 28 tiles, 1 tile = 2 m (40 × 56 m) |
| Tower footprint | 1 tile |
| Portal | Red demon portal, north edge, 2 tiles wide, unbuildable |
| Gate | Blue town gate, south edge, 2 tiles wide, unbuildable |
| Straight path | 28 tiles (≈19 s for a Grunt) |
| Camera at launch | 3/4 top-down, whole plateau in view, builder selected |
| HUD at launch | Gold 220 · Lives 20 · Wave 1 preview: 10 Grunts · 45 s build countdown |

Around the plateau: cliffs, outer walls with banners, pine forest, a river with a watermill, a village of huts, sheep fields, drifting clouds.

The first frame is the game. No title screen, no menu, no empty scene.

## 2. Pathing rules

- **Ground creeps** follow a flow field computed from the gate (Dijkstra over the tile grid, 8-way moves, diagonal cost 1.41).
- **No corner squeezing:** a diagonal move is allowed only if both side tiles are open.
- **Live updates:** every build or sell recomputes the field (560 tiles, well under 1 ms). Creeps already on the board re-route at once.
- **Anti-block (mandatory):** a placement is refused if, with the new tower in place:
  1. the portal can no longer reach the gate, or
  2. any ground creep's current tile can no longer reach the gate, or
  3. a creep is standing on that tile.
- **Refusal feedback:** red ghost, "thunk" sound, short shake of the ghost. Nothing is spent.
- **Dotted path:** glowing dots trace the current portal-to-gate route and flow toward the gate. It starts as a straight line and redraws on every change.
- **Air creeps** (Harpies) ignore the maze and fly the straight portal-to-gate line at 4 m altitude.

## 3. Rules: lives, leaks, waves, speed

| Rule | Value |
|---|---|
| Lives | 20 |
| Leak cost | Normal creep −1, boss −2 |
| Leak feedback | Gate flashes blue-white, war horn, lives counter pulses |
| After a leak | Creep teleports back to the portal with its current HP and runs again. It no longer pays bounty. Each pass costs lives again. |
| Defeat | Lives reach 0. Screen shows wave reached, kills, time, gold earned, best wave. |
| Victory | Clear wave 40. Screen shows score and stats; gryphons circle the citadel. |
| Score | 10 × kills + 500 × lives left + gold on hand; × 1.3 on Hard |
| Opening build phase | 45 s countdown. `N` starts wave 1 now. |
| Wave announcement | 3 s before spawn: banner with creep icons, count, armor class, element, boss skull |
| Spawn interval | 0.9 s (Wolf Riders 0.5 s; bosses enter alone after escorts) |
| Between waves | Wave cleared → 5 s breather → next wave auto-queues. `N` calls the next wave early (waves may overlap). |
| Speed | ×1 / ×2 / ×3 (`F` cycles). `Space` pauses. Building is allowed while paused. |

Simulation runs on a fixed 30 Hz step; ×2 and ×3 run 2 or 3 steps per frame. The same sim runs headless for tests and balance bots.

## 4. Economy

| Item | Value |
|---|---|
| Starting gold | 220 |
| Kill bounty | `round(6 + 16 × (wave − 1) / 39)` → 6 gold at wave 1, 22 at wave 40 |
| Boss bounty | Ogre ×10, Dreadlord ×25 |
| Interest | Every 15 s of game time: +2% of unspent gold, max +20 per tick. Pauses with the game. HUD shows a countdown ring and the next payout. |
| Sell | 75% of everything invested in that tower (build + upgrades + fusion) |
| Opener check | 220 gold = 8 Archer Towers (25 g) with 20 g left, or 6 Archers + 1 Frost Spire |

**Cost curve:** buildable towers cost 25–120 g; upgrades cost 15–120 g. Together they span the requested 15–120 g. The cheapest *tower* is 25 g, not 15 g: at 15 g, 220 gold would buy 14 towers, which breaks the "6–8 cheap towers" opener.

## 5. Modes

| Mode | Change |
|---|---|
| Normal | Base values |
| Hard | Creep HP +30%, bounty +20% |
| Infinite | After wave 40, waves continue from mixed templates. HP × 1.08 per wave past 40, on top of the curve. |

Mode is picked from a chip in the top bar during the opening build phase and locks when wave 1 spawns.

## 6. Damage model

```
damage = base
       × attack_vs_class[attack][class]
       × element_mult[tower_element][creep_element]
       × armor_factor(armor − shred)        // skipped for Poison
       × (1 + bard_aura)
```

`armor_factor(A) = 1 − 0.06A / (1 + 0.06A)` for A ≥ 0, and `2 − 0.94^(−A)` for A < 0 (shredded armor below zero amplifies damage).

### 6.1 Attack type vs armor class

| Attack ↓ / Class → | Light | Armored | Air | Boss |
|---|---|---|---|---|
| Pierce (Alliance) | **150%** | 50% | **175%** | 70% |
| Siege (Horde) | 100% | **175%** | cannot hit | 100% |
| Magic (Elven) | 100% | 125% | 100% | 75% |
| Poison (Forsaken) | 100% | 100% | 100% | 100%, ignores armor |
| Rune (Runesmith) | 100% | 100% | 100% | 100% |

### 6.2 Element wheel (Element TD style)

`Light → Dark → Aqua → Flame → Verdant → Stone → Light`

Each element deals **200%** to the element it points at, **50%** to the element that points at it, **100%** to the rest.

| Tower element | Strong vs (200%) | Weak vs (50%) | Towers |
|---|---|---|---|
| Light | Dark | Stone | Archer, Ballista |
| Dark | Aqua | Light | Plague Cauldron, Shadow Obelisk |
| Aqua | Flame | Dark | Frost Spire, Epic Frost Wyrm |
| Flame | Verdant | Aqua | Cannon, Demolisher, Epic Doom Cannon |
| Verdant | Stone | Flame | Ancient of Roots |
| Stone | Light | Verdant | Runesmith Forge |

Every creep element has exactly one counter family. Each wave announces its element 3 s before it spawns.

### 6.3 Damage numbers

| Result | Look |
|---|---|
| Strong counter | Gold, large, with "!" |
| Weak counter | Grey-blue, small |
| Neutral | White |
| Poison tick | Green, small |
| Immune | Steel "IMMUNE" |

### 6.4 Status rules

- **Slow:** strongest slow applies; slows don't stack. Bosses take half duration.
- **Root:** stops movement. Never applies to bosses.
- **Poison:** stacks up to 5. Halves healing received.
- **Armor shred:** −2 per Runesmith hit, up to −10, lasts 6 s, refreshes on hit.

## 7. Towers (12)

10 buildable cards plus 2 Epic fusion cards. Upgrades: L1 → L2 → L3 (two upgrade levels).

| Key | Tower | Family | Cost L1 / +L2 / +L3 | Attack · Element | Air? | L1 stats | Signature |
|---|---|---|---|---|---|---|---|
| 1 | Archer Tower | Alliance | 25 / +15 / +35 | Pierce · Light | ✓ | 9 dmg, 0.6 s, 9 m (L2 15, L3 24) | Cheap maze filler. L3 fires 2 arrows. |
| 2 | Cannon Tower | Horde | 60 / +45 / +80 | Siege · Flame | — | 30 splash r2.2, 1.5 s, 10 m (L2 60, L3 110) | Arcing shells, craters (6 s), small shake |
| 3 | Frost Spire | Elven | 50 / +40 / +70 | Magic · Aqua | ✓ | 8 dmg, 1.0 s, 9 m | 35% slow for 2 s. L2 splash slow r1.5. L3 frost ring every 3rd shot. |
| 4 | Plague Cauldron | Forsaken | 45 / +35 / +65 | Poison · Dark | ✓ | 6 dps × 5 s per stack, 1.2 s, 8.5 m | Stacks ×5, ignores armor, halves healing |
| 5 | Bard's Pavilion | Support | 80 / +60 / +90 | — | — | Aura r7 m | +15% damage (L2 +20%, L3 +25% and +10% attack speed). Highest aura wins. |
| 6 | Runesmith Forge | Support | 75 / +55 / +90 | Rune · Stone | ✓ | 14 dmg, 1.2 s, 9 m | Shreds 2 armor per hit |
| 7 | Ballista | Alliance | 70 / +60 / +100 | Pierce · Light | ✓ | 55 dmg, 1.6 s, 12 m | Bolt pierces 3 creeps in a line |
| 8 | Demolisher | Horde | 120 / +90 / +120 | Siege · Flame | — | 110 splash r3, 3.0 s, 15 m (min 4 m) | Burning crater 3 s at 10 dps, big shake |
| 9 | Ancient of Roots | Elven | 90 / +70 / +110 | Magic · Verdant | — | Nova every 3 s, r5 m, 20 dmg | 35% slow 2 s + 0.4 s root |
| 0 | Shadow Obelisk | Forsaken | 100 / +80 / +110 | Poison · Dark | — | Cloud r2.5 m for 4 s, 18 dps | Up to 3 clouds overlap, ignores armor |
| G | **Epic Frost Wyrm** | Elven | Fuse 2 × L3 Elven + 100 g | Magic · Aqua | ✓ | Breath cone 7 m, 60 dmg, 1.2 s | 50% slow 3 s; every 5th breath freezes 1 s. Wyrm coils the spire, 1.4× scale. |
| G | **Epic Doom Cannon** | Horde | Fuse 2 × L3 Horde + 120 g | Siege · Flame | — | 300 splash r4, 3.5 s, 16 m | Molten crater 5 s at 25 dps, heavy shake, 1.4× scale |

**Fusion:** select an L3 tower, press `G`, click a second L3 tower of the same family. The Epic appears on the first tile. The second tile is freed and the path updates (freeing a tile can only open the maze, never block it).

**Stretch (only after M9):** Alliance and Forsaken Epics (Sunfire Ballista, Plague Necropolis).

## 8. Creeps

`HP(wave) = 60 × 1.105^(wave − 1) × type multiplier × mode multiplier` → about 147 at wave 10, 400 at 20, 1086 at 30, 2950 at 40 (before type multiplier). Tuned by the balance bots; see [balance.md](balance.md).

| Creep | Class | Armor | Speed m/s | HP × | Mechanic |
|---|---|---|---|---|---|
| Grunt | Light | 1 | 3.0 | 1.0 | Baseline |
| Wolf Rider | Light | 0 | 5.0 | 0.65 | Fast |
| Shield Footman | Armored | 4 | 2.6 | 1.3 | High armor; raises shield when hit |
| Priestess | Light | 0 | 2.8 | 0.9 | Heals allies within 5 m for 4% max HP every 2 s |
| Harpy | Air | 1 | 3.4 | 0.8 | Flies straight, ignores maze; air-capable towers only |
| Ghoul | Light | 2 | 3.2 | 1.0 | Revives once after 1.5 s at ⅓ HP; bounty on final death |
| Steam Tank | Armored | 10 | 2.2 | 2.1 | Every 6 s: immune for 1.5 s (steam shroud) |
| Ogre Boss | Boss | 8 | 2.0 | 12 | Aura r6 m: escorts +3 armor, +10% speed. Leak −2. |
| Dreadlord | Boss | 12 | 1.8 | 32 | Summons 3 Felhounds every 10 s. Leak −2. |
| Felhound (summon) | Light | 2 | 4.0 | 0.6 | Dreadlord summon, Dark element |

Every creep has an HP bar, a team-color rim so its silhouette reads at full zoom-out, and walk / hit / death animations.

## 9. Wave pacing (40 waves, 8–24 creeps each)

| Waves | Theme |
|---|---|
| 1–9 | One new mechanic per wave (table below) |
| 10 | **Boss:** Ogre Chieftain + 8 Grunts |
| 11–19 | Air, heal and revive: Harpy flocks with Priestess ground escorts, Ghoul packs with healers, split air + ground waves |
| 20 | **Boss:** Ogre Warlord + Harpy escort |
| 21–29 | Armor and immunity combos: Steam Tanks + Footmen + Priestesses, Tanks + Ghouls |
| 30 | **Boss:** Twin Ogres + Steam Tank escort |
| 31–39 | Mixed pressure, 18–24 creeps, two elements per wave |
| 40 | **Final:** Dreadlord + Felhound summons + Ghoul escort (Dark) |

| Wave | Creeps | Element | Teaches |
|---|---|---|---|
| 1 | 10 Grunts | Flame | Mazing basics |
| 2 | 14 Wolf Riders | Dark | Speed |
| 3 | 8 Shield Footmen | Verdant | Armor, Siege bonus |
| 4 | 10 Grunts + 3 Priestesses | Aqua | Healers, Poison counter |
| 5 | 12 Harpies | Light | Air, anti-air towers |
| 6 | 14 Ghouls | Dark | Revive |
| 7 | 4 Grunts + 6 Steam Tanks | Flame | Immunity windows |
| 8 | 12 Wolf Riders + 8 Grunts | Flame | Mixed speeds |
| 9 | 12 Footmen + 4 Priestesses | Aqua | Armor + heal |
| 10 | Ogre Chieftain + 8 Grunts | Flame | Boss aura, −2 leak |

The full 40-row table lives in `data/waves` (M6). Elements rotate so each one appears 6–7 times.

## 10. Controls and camera

| Input | Action |
|---|---|
| Left-click | Place tower (snaps to tile) / select tower |
| Shift + left-click | Keep placing the same tower |
| Right-click | Cancel the build ghost; on a selected tower, sell |
| `1`–`0` | Pick a tower card (spec's `1`–`6` cover Archer, Cannon, Frost, Poison, Bard, Runesmith) |
| `U` / `X` / `G` | Upgrade / sell / fuse the selected tower |
| `Esc` | Deselect or cancel |
| `Space` / `F` | Pause / cycle speed ×1 ×2 ×3 |
| `N` | Start or call the next wave |
| `R` | Hero view (reset to the default 3/4 camera) |
| `C` / `B` | Cycle camera presets (full board, portal close-up, gate defense) / toggle boss tracking |
| Camera | WASD or edge pan, scroll zoom, middle-drag or Option-drag orbit, `Q`/`E` rotate, trackpad two-finger pan and pinch zoom. All damped. |

The range ring shows only for the hovered or selected tower (and for the ghost while placing).

## 11. HUD

- **Top bar:** gold · lives · wave n/40 with next-wave chip (icons, element, class, skull) · interest ring + next payout · speed · pause · mode · quality · camera presets.
- **Bottom bar:** 12 cards. Each shows icon, name, cost, hotkey, attack and element pips, air icon. Cards dim when unaffordable. Epic cards light up when a fusion is possible.
- **Selected tower:** a small plaque floating above the tower (upgrade, sell, fuse, stats, kills). No side panels.
- **World-space:** damage numbers, gold popups, HP bars.

## 12. World life and juice (checklist)

**Living backdrop:** pines sway · clouds drift and cast moving shadows · watermill wheel turns in the river · banners flap · sheep graze · village huts cheer when a wave is cleared · peasants flee when a boss leaks · gryphons circle on victory · torches flicker at the gate · the portal swirls with red volumetric fog and sparks.

**Combat juice:** arrow tracers · shell arcs with smoke trails · frost rings · poison puffs and clouds · gold popups · placement dust and thump · upgrade sparkle · sell coin burst · gate flash and horn on leak · lingering craters · distance-scaled camera shake (toggle in settings) · hit flash · death animations.

## 13. Audio

Buses: Master, Music, SFX, UI, Ambience (sliders in settings).

- **SFX:** fire and impact per tower, death per creep type, leak horn, gate flash, coin, invalid-placement thunk, build thump, upgrade, sell, fuse, boss roar, wave horn, victory and defeat stingers.
- **Announcer:** wave start, boss incoming, victory, defeat.
- **Music:** calm build theme, battle theme, boss theme, crossfaded by state.
- **Ambience:** wind, birds, river, village.

## 14. Quality presets

Presets scale only presentation. They never change maze size, wave count, creep count or counter logic.

| Setting | Cinematic | Balanced (default) | Performance |
|---|---|---|---|
| 3D render scale (upscaled) | 0.85 | 0.7 | 0.5 |
| Global illumination | SDFGI | SSIL | Off |
| Shadows | 4096, soft, 4 cascades | 2048, 3 cascades | 1024, 2 cascades |
| Volumetric fog | High | Low | Off |
| Screen-space reflections | On | Off | Off |
| SSAO | High | Medium | Off |
| Particles | 100% | 70% | 40% |
| Ambient crowd (villagers, sheep, birds) | 100% | 70% | 35% |
| Foliage density | 100% | 80% | 50% |

## 15. Save data

`user://save.cfg` (in `~/Library/Application Support/Maze Citadel/`): best wave and best score per mode, quality preset, volumes, camera-shake toggle. This is the native-app equivalent of browser local storage.
