# v1.4.27

- Fixed the camera swinging sideways when the floating origin shifts while you are turning. The render offset now uses the interpolated player transform that the player is actually drawn with, so the camera stays exactly on the player through every 32 m shift.
- Added a regression check that rotates the player while the origin is shifted and fails if the rendered camera moves off the player.
