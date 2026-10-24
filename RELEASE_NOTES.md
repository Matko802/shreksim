# v1.4.24

- Mobile performance pass aimed at holding 60 FPS: terrain now uses a dedicated lightweight shader with fewer texture lookups and no expensive specular work. Terrain rendering is roughly a third faster in profiling.
- Adaptive 3D render resolution on Android scales between 0.55x and 0.8x on the fly to protect the frame rate, which especially helps when looking down at the ground.
- Desktop keeps the full Forward+ renderer and the original terrain shader, unchanged.
- No gameplay or visual content changes.
