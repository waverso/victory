# VIctory

A fork of [VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX) by
avatarmanz, itself a fork of [VIctory](https://github.com/Marvisak/VIctory), a
compatibility layer that runs an Xbox Series title natively on Windows from files
the user supplies. This one is about running it on a **mid-range PC**: 8 GB of
video memory and 32 GB of RAM.

**This repository contains no game files, code or assets.** You need your own
copy of the game. It is not affiliated with or endorsed by the game's developer
or publisher.

## Where it stands (2026-11-26)

Ryzen 5 5600 (12 threads), Radeon RX 7600 8 GB (PCIe x8), 32 GB RAM, Windows 11,
the Series X profile, the prologue:

| | frame in the world | video memory (budget about 6.8 GB) |
|---|---|---|
| internal 2560x1440, as the title picks it | about 1 s (1 fps) | 9.1 GB, over budget |
| `-Height 576` (1024x576 inside) | 187 ms median (10 fps in the first room) | 7.7 GB |
| `-Fit -Height 576` | 103-107 ms median (9-10 fps), 117 ms p75 | 6.3-7.0 GB |

- 28-29 GB of private memory: it runs with Windows' own paging file on 32 GB.
- Over the budget, video memory spills into RAM over the bus and the card waits:
  that, not the resolution, is what held the frame on this card. Under it, the
  layer's submitting thread is the limit again (the card about 35 % busy).
- The title's `settings.xml` (resolution, LOD) and the Series S profile do not lower
  what it renders; the Series S profile shows a black picture.

On the PC the upstream fork was made on (i9-12900K, 64 GB RAM, RX 7900 XTX,
internal 1440p) it reports 13-22 fps indoors, on the water and flying, 6-10 fps
in a busy street chase, and 40-46 GB of private memory.

What is known to be wrong:

- Video memory grows over a session with `-Fit`; long sessions may spill again.
- Trees, plants and far buildings flicker outdoors in some places.
- Rooms with little direct light are too dark without `-RayTracing`.
- Textures of what just came into view appear late while the title streams.
- The first run with a new driver or a new build stutters while the driver makes
  pipelines (`victory warm` makes them ahead).
- Recording a frame in the world makes the title's own watchdog end it.

## How to run it

You need Windows 10/11 x64, a CPU with AVX2, a Direct3D 12 GPU with shader
model 6.6 and mesh shaders, Rust (the toolchain is pinned), the MSVC build
tools, and your own dump of the title.

1. `copy victory.example.toml victory.toml`, then set your paths in it, outside this folder.
2. `scripts\build.cmd` builds the diagnostics build (`logs\build.log`).
3. `scripts\shaders.cmd` translates every shader ahead of time, a few minutes, once
   per change of the translator (`logs\shaders.log`).
4. `scripts\play.cmd -Fit -Height 576` plays: the executable in `game_dir`, the
   run's output in `logs\play-<time>.log`.

`scripts\play.ps1` switches (`scripts\play.cmd` passes them on):

| switch | does |
|---|---|
| `-Fit` | for 8 GB of video memory and 12 threads: 4 texture blocks kept ahead instead of 12, textures up to 85 % of the budget instead of 90, 4 list workers instead of 8 |
| `-Height <n>` | renders at n lines of a 16:9 picture (576: 1024x576); FidelityFX scales it to the output |
| `-RenderScale <f>` | the same as a fraction of the output (0.2667) |
| `-Safe` | without the newer, faster ways; the first thing to try when something is wrong |
| `-RayTracing` | the title's ray-traced indirect light: lit interiors, about a third slower |
| `-Exe <path>` | another copy's executable |
| `-More @{...}` | any other `VICTORY_...` setting |

The render scale is a patch of one instruction pair in a cached copy of the
executable (`apps/victory/src/scale.rs`): the title keeps its render scale at
or above a lower limit of 2/3 of the output, and the patch makes the limit the
scale asked for and the scale the limit. It knows one build of the title and
refuses any other.

`target\diag\victory.exe warm --used` makes the pipelines earlier runs drew with,
for a new driver or build. Commands, debugging switches and upstream's own
description: [docs/README-fxceless.md](docs/README-fxceless.md). Every
`VICTORY_...` switch is described in a comment where it is read.

## What VIctory-7900XTX changed

In short; the reasons and the measurements are in [docs/findings.md](docs/findings.md).

- **List calls are written down, not carried out, on the title's threads**
  (`VICTORY_THIN`): eight threads of ours translate them.
- **Submissions are prepared by a thread of ours and joined**
  (`VICTORY_ASYNC_SUBMIT`, `VICTORY_JOIN_PARTS`), with what can be spread over
  threads spread: refreshes, compares (AVX2), descriptor records, landings.
- **What shaders wrote comes back beside the write guards**, by the dwords that
  changed, on a thread of its own (`VICTORY_RELAY`, `VICTORY_LAND`).
- **Buffer fills that need bytes still on the card are done on the card**
  (`VICTORY_CARD_STEPS`) instead of waiting for it.
- **The title's writes are caught more cheaply**: one view opened at a fault,
  blocks that rest, places in the title's code that look before they write.
- **Textures go up on a copy queue of their own** and a slot shows one only after
  its upload ran, which also ended a device loss that came every 15 minutes or so.
- **Boats float**: textures that shaders write and the title's CPU reads go back
  to title memory (from fxceless and Geckomacabre, on by default here).
- **Frame record and replay** with per-pass times and shader variants compared
  turn by turn ([docs/replay.md](docs/replay.md)).

## Credits

This is a tree of other people's work with more on top. Its history, with each
commit taken from elsewhere naming the commit and its author, is in
VIctory-7900XTX's repository.

- **[VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX)** by
  avatarmanz: the fork this one is a copy of, nearly all of its speed and
  stability, its findings (docs/findings.md) and its start script.
- **[VIctory](https://github.com/Marvisak/VIctory)** by Marvisak and its
  contributors: the loader, the runtime services, the Direct3D 12 back end and
  the shader recompiler.
- **[fxceless/victory-fork](https://github.com/fxceless/victory-fork)**: the fork
  VIctory-7900XTX started from, and the people whose pull requests it carries.
- **[DexNom/VIctory](https://github.com/DexNom/VIctory)**: ray tracing fixes,
  cube gradients, sparse textures.
- **[Belobug/VIctory-Belobug-AMD](https://github.com/Belobug/VIctory-Belobug-AMD)**:
  the ambient light idea, pipeline workers, and work by romainhedouin.
- **[FQY55kai/ZJOU-VICTORY](https://github.com/FQY55kai/ZJOU-VICTORY)**.
- **[myokex/victory-amd](https://github.com/myokex/victory-amd)**: the guard over
  every view of a page (with Spexivus, joroyt and tightfall), and Joshua Odom's
  reads into title memory.
- **Geckomacabre** and **cxy0072019-sketch**: the texture read-back.
- **[XCL](https://github.com/ivall/xcl)** (GPL-2.0-only) was read for how the same
  title behaves under another layer; no code of it is here.
- avatarmanz's changes were made with [Claude Code](https://claude.com/claude-code);
  this fork's with Claude Code and Codex.

## License

GPL-3.0-or-later, as VIctory. See [LICENSE](LICENSE); the one file that is not
covered is named in [docs/asset-policy.md](docs/asset-policy.md).
