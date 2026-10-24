# v1.4.26

- Added a floating-origin renderer: the player stays near the render origin and the world shifts in 32 m chunks. Physics, collision, navigation, and AI stay in absolute coordinates, while terrain, trees, onions, and Shrek render in shifted space.
- Fixed the one-frame flicker at origin shifts by applying the camera offset per frame instead of through physics interpolation.
- Android and desktop now share the same rendering: native 1.0 3D render scale, anti-aliasing off by default, a 200 m camera far plane, the same terrain shader, and the same tree draw distances. Android runs physics at 30 Hz with no FPS cap.
- Replaced the full Terrain3D texture blend with a per-pixel Lambert shader that blends the packed control map bilinearly, keeping path edges smooth at about 2.3x lower cost.
- Terrain behind the camera is frustum-culled, distant LODs are removed by the 200 m far plane, and collision shapes are 32 m.
- Near trees render only within 32 m and distant trees only within 150 m. Both LODs reject out-of-range instances in the vertex shader.
- Android exports are pinned to ETC2/ASTC textures.
- Video settings migrate automatically; old configs reset anti-aliasing and render scale once so PC and mobile match.
