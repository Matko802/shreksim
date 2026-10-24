# v1.4.25

- Terrain3D returns on PC and Android with a mobile-first setup: lightweight terrain shader, 64-region cap, fewer mesh LODs, smaller clipmap meshes, no tessellation, no world-noise background, no cull margin, and dynamic game-only collision. Terrain geometry drops from roughly 166k to 20k primitives.
- Shrek now runs away fast and slowly fades out when he loses you, then stays hidden until you collect another onion. He reappears 20-25 m in front of you, including his first appearance after the first onion.
- The fog no longer thickens when Shrek loses you.
- Android is no longer capped at 60 FPS. It renders at native 1.0 resolution with MSAA 2x by default and the same anti-aliasing options as desktop. Dynamic resolution scaling and FSR are removed.
- Enemy steering raycasts are throttled, and the onion prompt skips work when there are no onions left to collect.
