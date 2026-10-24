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

## What's new in v1.4.26

- Android and desktop now share the same rendering: native 1.0 3D render scale, anti-aliasing off by default, a 200 m camera far plane, the same terrain shader, and the same tree draw distances. Android additionally runs 30 Hz physics.
- The terrain shader now uses two albedo fetches per pixel instead of the full Terrain3D per-texture blend. It blends the packed control map bilinearly so path edges stay smooth, and lights the terrain per pixel with Lambert shading. It measured about 2.3x cheaper than the full Terrain3D shader at 1535x864.
- Godot's frustum culling removes terrain chunks behind the camera, and the 200 m far plane removes distant terrain LODs. Terrain collision shapes are 32 m, cutting the number of collision shapes.
- Near trees render only within 32 m and distant trees only within 150 m on both platforms. Both tree LODs now reject out-of-range instances in the vertex shader instead of running the fragment shader just to discard them.
- Android exports are pinned to ETC2/ASTC textures.
- Video settings migrate automatically; an old config resets anti-aliasing and render scale once so PC and mobile match.
- Movement now uses a floating origin: the player stays near the render origin and the terrain, trees, and props shift in 32 m chunks around them. Physics, collision, and AI keep absolute coordinates, while rendering and shader height sampling use render space, so the terrain is still culled exactly like before. The first-person camera applies the shift per frame instead of through physics interpolation, so the world and camera move on the same frame with no visible flicker.

## What's new in v1.4.25

- Terrain3D is back on PC and Android, tuned for mobile: a lightweight terrain shader, a 64-region cap, fewer mesh LODs, smaller clipmap meshes, no tessellation, no world-noise background, no cull margin, and dynamic game-only collision. Terrain geometry drops from roughly 166k to 20k primitives.
- Shrek now runs away fast and slowly fades out when he loses you, then stays hidden until you collect another onion. He reappears 20-25 m in front of you, including his first appearance after the first onion.
- The fog no longer thickens when Shrek loses you.
- Android is no longer capped at 60 FPS. It renders at native 1.0 resolution with MSAA 2x by default and the same anti-aliasing options as desktop. Dynamic resolution scaling and FSR are removed.

## About

The swamp is full of onions. Grab all eight before the 150 second timer runs out. Shrek hunts by sound and sight, and the fog thickens as the night goes on. There is also an endless mode for chasing a high score.

The game runs on the Mobile renderer on Android and Forward+ on desktop, with identical terrain shading, tree LOD distances, and camera far plane. Terrain3D uses a lightweight per-pixel Lambert shader with bilinear control-map blending, plus a mobile-tuned clipmap. Trees use a hybrid LOD system so the forest stays dense without overwhelming low-end phones. Both platforms render at native 1.0 3D resolution with anti-aliasing off by default and no FPS cap, while Godot frustum-culls terrain behind the camera. Android runs physics at 30 Hz.

The renderer uses a floating origin. The player stays within one 32 m cell of the render origin while the world shifts around them in 32 m steps. Physics, collision, navigation, and AI stay in absolute world coordinates; terrain, trees, onions, and the enemy are drawn in render space. Terrain3D's clipmap is centered on a render-space target, so its mesh bounds line up with the shifted camera and frustum culling keeps working. The terrain shader adds the origin back before sampling the heightmap and control map, so the terrain looks and collides identically at any offset. A chunk size divisible by every clipmap snap step (2, 4, 8, 16, 32 m) keeps LOD transitions pixel-stable across origin shifts.

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

## Tests

```bash
godot --headless --path . tests/test_floating_origin.tscn
godot --headless --path . tests/test_ground.tscn
godot --headless --path . tests/test_tree_lod.tscn
godot --headless --path . tests/test_settings.tscn
godot --headless --path . tests/integration_test.tscn
```

## Credits

- Built with [Godot Engine](https://godotengine.org/).
- Terrain powered by [Terrain3D](https://github.com/TokisanGames/Terrain3D).
- Shrek is a fan-made character tribute. This is a free fan project and is not affiliated with DreamWorks.
