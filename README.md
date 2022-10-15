# [Sega Saturn](https://en.wikipedia.org/wiki/Sega_Saturn) Compatible IP Core for FPGA

![Active Development](https://img.shields.io/badge/Maintenance%20Level-Actively%20Developed-brightgreen.svg)
[![Test Build (Single SDRAM)](https://github.com/srg320/Saturn_MiSTer/actions/workflows/test-build.yml/badge.svg?branch=master&event=push)](https://github.com/srg320/Saturn_MiSTer/actions/workflows/test-build.yml)
[![Test Build (Dual SDRAM)](https://github.com/srg320/Saturn_MiSTer/actions/workflows/test-build_ds.yml/badge.svg?branch=master&event=push)](https://github.com/srg320/Saturn_MiSTer/actions/workflows/test-build_ds.yml)
[![Funding](https://img.shields.io/endpoint?url=https://shieldsio-patreon.vercel.app/api/?username=srg320&type=patrons)](https://www.patreon.com/srg320)
[![Funding](https://img.shields.io/badge/paypal-donate-blue.svg)](https://www.paypal.com/donate/?hosted_button_id=RCF2BEEN4V75L)
[![Twitter Follow](https://img.shields.io/twitter/follow/srg320_?style=social)](https://twitter.com/srg320_)

> **WARNING**: This repository is in active development. There are no guarantees about stability. Breaking changes will occur until a stable release is made and announced.

## Overview

The Saturn was a 32-bit console by Sega, released in 1994 in Japan and 1995 in North America and Europe. Sega designed its Saturn with advanced hardware and with dual CPUs, making it difficult for programmers. In addition, components were not specifically created to work together, graphics hardware was complex, and the system's basic geometric primitive was based on quadrilaterals which proved difficult for Sega because the rest of the industry based its design on triangles. Eventually, the Saturn was eclipsed by the release of Sega's own Dreamcast.

## Technical specifications

- **CPU**: 2x Hitachi SH2 32-bit RISC CPUs @ 28.63 MHz
- **RAM**: 16Mbit SDRAM
- **VRAM**: 12Mbit SDRAM
- **Graphics**:
  - Sega/Hitachi VDP1 @ 28.63 MHz (sprite/texture and polygons)
  - Sega/Yamaha VDP2 @ 28.63 MHz (background, scroll and 3D)
- **Resolution**: 320x224 to 704x224, 16,777,216 millions colors
- **Sound CPU**: Motorola 68ECOO @ 22.6 MHz
- **Sound Processor**: Yamaha SCSP (Saturn Custom Sound Processor) YMF292
- **Media**: CD-ROM

## Hardware Requirements

- 128 MB SDRAM Module (Primary)
- SDRAM Module of any size (32MB-128MB) (Secondary)

> **Note:** Dual SDRAM modules is recommended for better compatibility.

## Test Builds

Test builds can be downloaded from the GitHub Actions, they are automatic generated on push against the current code of the repository and should not be considered releases.

To download select a workflow bellow, click on the most recent run and download the zip file under `Artifacts produced during runtime`.

- [Single SDRAM](https://github.com/srg320/Saturn_MiSTer/actions/workflows/test-build.yml)
- [Dual SDRAM](https://github.com/srg320/Saturn_MiSTer/actions/workflows/test-build_ds.yml)

> **Note:** Actions has a 90-day retention rule by default, after that the artifacts are not available anymore.

### Keys F1-F11 enable/disable the video screens/audio channels:
- F1 - VDP2 NBG0
- F2 - VDP2 NBG1
- F3 - VDP2 NBG2
- F4 - VDP2 NBG3
- F5 - VDP2 RBG0
- F6 - VDP2 Sprite
- F7 - VDP2 Windows
- F8 - SCSP Direct sound
- F9 - SCSP DSP sound
- F10 - CD audio
- F11 - enable all

## Building

### Prerequisites

To build this project you also need the following repositories [Saturn](https://github.com/srg320/Saturn) and [SH](https://github.com/srg320/SH)

### Cloning the Repositories

```bash
git clone https://github.com/srg320/Saturn_MiSTer.git
git clone https://github.com/srg320/Saturn.git
git clone https://github.com/srg320/SH.git
```

The repositories must be on the same level:

```bash
.
├── SH
├── Saturn
└── Saturn_MiSTer
```

### Project Files

Inside the folder `Saturn_MiSTer` you will find 2 Quartus project files.

- `Saturn.qpf` - Build project for usage with Single SDRAM.
- `Saturn_SD.qpf` - Build project for usage with Dual SDRAM (**recommended**).

> **Note:** For both builds the primary SDRAM module must be 128MB (i.e. with two chips)!

## Compatible BIOS

> **BIOS NOT INCLUDED:** In order to use this core, you need to provide your own BIOS.

Rename your Saturn bios file to `boot.rom` and place it in the `games/Saturn/` folder.

| Console           | Version | Region | SHA1                                     | Size   | Status |
|-------------------|---------|--------|------------------------------------------|--------|:------:|
| Sega Saturn       | 1.00    | Japan  | 2b8cb4f87580683eb4d760e4ed210813d667f0a2 | 512 KB |   ✅    |
| Sega Saturn       | 1.00a   | USA    | 3bb41feb82838ab9a35601ac666de5aacfd17a58 | 512 KB |   ✅    |
| Sega Saturn       | 1.00    | Europe | faa8ea183a6d7bbe5d4e03bb1332519800d3fbc3 | 512 KB |   ✅    |
| Sega Saturn       | 1.003   | Japan  | 7b23b53d62de0f29a23e423d0fe751dfb469c2fa | 512 KB |   ❌    |
| Sega Saturn       | 1.01    | Japan  | df94c5b4d47eb3cc404d88b33a8fda237eaf4720 | 512 KB |   ✅    |
| Sega Saturn       | 1.01a   | USA    | faa8ea183a6d7bbe5d4e03bb1332519800d3fbc3 | 512 KB |   ✅    |
| Hitachi Hi-Saturn | 1.01    | Japan  | 49d8493008fa715ca0c94d99817a5439d6f2c796 | 512 KB |   ✅    |
| Hitachi Hi-Saturn | 1.02    | Japan  | 8a22710e09ce75f39625894366cafe503ed1942d | 512 KB |   ✅    |
| Hitachi Hi-Saturn | 1.03    | Japan  | 8c031bf9908fd0142fdd10a9cdd79389f8a3f2fc | 512 KB |   ✅    |
| Victor V-Saturn   | 1.01    | Japan  | 4154e11959f3d5639b11d7902b3a393a99fb5776 | 512 KB |   ✅    |

> **Note:** You can also place a file named `cd_bios.rom` in the same directory as the CD image. This can be used for games that depend on a specific BIOS.

## Status of Features (Not yet Prioritized)

> Work in progress, don't report any bugs!

### Video Display Processor 1 (VDP1)

- [ ] 512×256 Framebuffer (current size is limited to 352x256 pixels). *Games that make usage of the framebuffer as temporary data storage will not work (e.g., Burning Rangers)*
- [ ] Gouraud Shading

### Video Display Processor 2 (VDP2)

- [ ] PAL Mode
- [ ] Line Screen
- [ ] Mosaic

### Yamaha SCSP (Saturn Custom Sound Processor) YMF292

- [ ] LFO

## Credits and acknowledgment

Made with ❤️ by [Sergey Dvodnenko](https://twitter.com/srg320_).

- To all my [Patreon](https://www.patreon.com/srg320) supporters. Your support keeps me working on the core and helps me bring it to life.
- Jorge Cwik - FX68K 68000 SystemVerilog core.

## Legal Notice

Sega Saturn™ - Copyright © 1994, 1995 SEGA ENTERPRISES, LTD. All rights reserved. SEGA and the SEGA logo are registered trademarks of SEGA CORPORATION. All other trademarks, logos, and copyrights are property of their respective owners.

The authors and contributors or any of its maintainers are in no way associated with or endorsed by SEGA®.
