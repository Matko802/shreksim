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

## What's new in v1.4.23

- Added a **Mobile renderer** path with FXAA, a 60 FPS cap, and 0.8 render scale for smoother Android performance.
- Reworked tree rendering with crossed 3D quads up close and batched billboards in the distance, out to 500 m.
- Trees and onions now sit correctly on the terrain instead of floating or sinking.
- Shrek now retreats into thick fog and fades away after losing sight of you for 5 seconds.
- Added **F11** to toggle fullscreen on desktop.
- Smoother cubic crouch animation and cleaner editor output.

## About

The swamp is full of onions. Grab all eight before the 150 second timer runs out. Shrek hunts by sound and sight, and the fog gets much worse when he is close. There is also an endless mode for chasing a high score.

The game runs on the Mobile renderer on Android and Forward+ on desktop. Trees use a hybrid LOD system so the forest stays dense without overwhelming low-end phones.

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
