# Maze Citadel documentation

**Website and download: [obsesivegamer.github.io/maze-citadel](https://obsesivegamer.github.io/maze-citadel/)**

## Overview

Maze Citadel is a single-player maze tower defense game for Mac, Windows and Linux, built with Godot 4.7. You wall a plateau with towers to stretch the road that creeps have to walk from a demon portal to the town gate, and you hold that gate for forty waves. It plays by Element TD's rules: each tower reaches only the tiles around it, and you earn the elements your towers need through eight element picks, most of which summon a Guardian you have to kill first. There are three maps and four difficulties, and the classic rules of version 0.3.1 are one click away. The [README](../README.md) has the full introduction and a guide to playing.

This folder holds everything else that's written down about the game. If you want to get it running, start with the install guide. If you want to read the code, start with the architecture page.

## Start here

| Document | Read it when |
|---|---|
| [INSTALL.md](INSTALL.md) | You want to install the game, check the system requirements, fix a problem, or set up the tools to build it yourself |

## How the game works

| Document | Read it when |
|---|---|
| [GDD.md](GDD.md) | You want the exact rules: every tower, creep, wave, element pick and difficulty, with the numbers, and how the classic rules differ |
| [maps.md](maps.md) | You want to know how the three maps differ, or how a map is defined in the code |

## How it's built and shipped

| Document | Read it when |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | You're about to read or change the code |
| [RELEASING.md](RELEASING.md) | You're publishing a new version, or want to know how the website gets updated |

## Logs and history

These three are records. They're written in date order and say what was tried, what was measured and what was decided.

| Document | Read it when |
|---|---|
| [playtests.md](playtests.md) | You want to send a playtest, or replay one. The game records every game you play to a file on your computer. |
| [balance.md](balance.md) | You wonder why a number is what it is. Bots play full games and this is what they found. |
| [perf.md](perf.md) | You care about frame rates. It has every measurement and the changes that came out of them. |
| [PLAN.md](PLAN.md) | You want to see the original build plan and the decisions made at the start |

## Other folders

- `screens/` has the screenshots used in the README and the performance log.
- `perf/` has the raw benchmark reports, as JSON, that the performance log refers to.
