# v1.4.30

- Mobile anti-aliasing can no longer be turned off. The Off option is removed from the mobile anti-aliasing list, FXAA is forced, and the MSAA modes remain selectable. This fixes visual glitching at native render scale without anti-aliasing.
- Fog is now a depth fog that stays clear through the middle of the view and becomes fully opaque right at the effective draw-distance edge, hiding the terrain and tree cutoff the way Minecraft's edge fog does.
- The fog edge follows the effective tree draw distance, which is capped at 150 m, and the clear zone gets smaller during the night phases.
- The first onion now triggers a short cutscene: Shrek fades in ahead of you, the camera spins you around, and a shaking RUN!!! warning appears before he starts hunting.
- When Shrek loses you, he sprints off to the edge of the render distance and fades into the fog. If he is hidden when you grab another onion, he fades in smoothly instead of popping into view.
- Render distance changes update the fog edge immediately.
