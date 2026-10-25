# v1.4.29

- Quality presets now change every graphics quality setting together instead of only anti-aliasing. Low sets a 64 m render distance, 65% render scale, and anti-aliasing off. Medium sets 128 m, 80%, and FXAA. High sets 200 m, 100%, and FXAA.
- The render distance, render scale, and anti-aliasing sliders update immediately when a preset is selected.
- Mobile still defaults to Low quality and a 64 m render distance; PC still defaults to High quality and 200 m.
- Added regression checks that each preset applies all three graphics settings.
