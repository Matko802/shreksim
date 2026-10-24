# v1.4.28

- Removed the floating-origin world shifting entirely. The map, camera, terrain, trees, onions, and Shrek now stay in absolute world coordinates, so the world no longer teleports in 32 m steps and the map no longer recenters while moving or turning.
- Terrain3D's clipmap target follows the player's absolute position directly, keeping terrain LOD and frustum culling without moving the world.
- Added graphics presets and sliders. Quality Low/Medium/High sets render scale and anti-aliasing, with separate render distance and render scale controls. Mobile defaults to Low at 64 m; PC defaults to High at 200 m.
- Catching the player blinks three static frames at 0.5 seconds each before the game over screen, and the mouse stays unlocked during and after the capture.
- The debug overlay now shows 0.1% low FPS instead of maximum frame time.
- The updater now checks GitHub tags first, then releases, then the Atom feed, so new tags are detected even before the release is published.
- Added regression tests for world-space rendering, settings, the updater, and the capture sequence.
