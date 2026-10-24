# Swamp Horror Simulator 3D

A short first-person swamp horror game made with Godot 4.7. Collect eight onions before the timer runs out, listen for Shrek in the fog, and keep moving.

**[Android](https://github.com/Matko802/shreksim/releases/latest/download/SwampSim-Android-arm64.apk)** ·
**[Windows](https://github.com/Matko802/shreksim/releases/latest/download/SwampSim-Windows-x86_64.zip)** ·
**[Linux](https://github.com/Matko802/shreksim/releases/latest/download/SwampSim-Linux-x86_64.AppImage)**

![Swamp Horror Simulator 3D gameplay](docs/screenshots/swamp.jpg)

## Screenshots

| Menu | Shrek |
| --- | --- |
| ![Menu](docs/screenshots/menu.jpg) | ![Shrek in the fog](docs/screenshots/shrek.jpg) |

## Download

| Platform | File | Requirements |
| --- | --- | --- |
| Android | [SwampSim-Android-arm64.apk](https://github.com/Matko802/shreksim/releases/latest/download/SwampSim-Android-arm64.apk) | Android 8+, arm64 |
| Windows | [SwampSim-Windows-x86_64.zip](https://github.com/Matko802/shreksim/releases/latest/download/SwampSim-Windows-x86_64.zip) | Windows 10/11, x64, Vulkan |
| Linux | [SwampSim-Linux-x86_64.AppImage](https://github.com/Matko802/shreksim/releases/latest/download/SwampSim-Linux-x86_64.AppImage) | x86_64 Linux, Vulkan, FUSE |

On Linux, make the AppImage executable and run it:

```bash
chmod +x SwampSim-Linux-x86_64.AppImage
./SwampSim-Linux-x86_64.AppImage
```

## What's new in v1.4.25

- Terrain3D is back on PC and Android, tuned for mobile: a lightweight terrain shader, a 64-region cap, fewer mesh LODs, smaller clipmap meshes, no tessellation, no world-noise background, no cull margin, and dynamic game-only collision. Terrain geometry drops from roughly 166k to 20k primitives.
- Shrek now runs away fast and slowly fades out when he loses you, then stays hidden until you collect another onion. He reappears 20-25 m in front of you, including his first appearance after the first onion.
- The fog no longer thickens when Shrek loses you.
- Android is no longer capped at 60 FPS. It renders at native 1.0 resolution with MSAA 2x by default and the same anti-aliasing options as desktop. Dynamic resolution scaling and FSR are removed.

## About

The swamp is full of onions. Grab all eight before the 150 second timer runs out. Shrek hunts by sound and sight, and the fog thickens as the night goes on. There is also an endless mode for chasing a high score.

The game runs on the Mobile renderer on Android and Forward+ on desktop. Terrain3D uses a mobile-tuned clipmap and a lightweight shader on Android. Trees use a hybrid LOD system so the forest stays dense without overwhelming low-end phones. Android renders at native resolution with MSAA 2x and no frame cap.

## Controls

| Action | Key |
| --- | --- |
| Move | WASD / arrow keys |
| Sprint | Shift |
| Crouch | Ctrl or C |
| Interact | E |
| Flashlight | F |
| Pause | Esc or P |
| Fullscreen | F11 |
| Zoom | Right mouse button |

## Build from source

You need Godot 4.7 and the matching export templates.

```bash
godot --headless --import
godot --headless --export-release "Linux" builds/linux/SwampSim.x86_64
godot --headless --export-release "Windows" builds/windows/SwampSim.exe
godot --headless --export-release "Android" builds/swampsim.apk
```

The Android preset expects a release keystore in Godot's editor settings. The desktop presets are in `export_presets.cfg`.

## Credits

- Built with [Godot Engine](https://godotengine.org/).
- Terrain powered by [Terrain3D](https://github.com/TokisanGames/Terrain3D).
- Shrek is a fan-made character tribute. This is a free fan project and is not affiliated with DreamWorks.
