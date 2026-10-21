import re

TRES = "assets/footsteps/footstep_surfaces.tres"
text = open(TRES, encoding="utf-8").read()

sand_ids = ["sand_1", "sand_2", "sand_3", "sand_4", "sand_5", "sand_6"]
files = [
    "Fantozzi-SandL1.ogg", "Fantozzi-SandL2.ogg", "Fantozzi-SandL3.ogg",
    "Fantozzi-SandR1.ogg", "Fantozzi-SandR2.ogg", "Fantozzi-SandR3.ogg",
]

ext_lines = "".join(
    '[ext_resource type="AudioStream" path="res://assets/sounds/fantozzi/%s" id="%s"]\n' % (f, i)
    for f, i in zip(files, sand_ids)
)
sub_idx = text.index("[sub_resource")
text = text[:sub_idx] + ext_lines + text[sub_idx:]

m = re.search(r'(\[sub_resource type="Resource" id="Resource_default"\]\nscript = ExtResource\("2_msx8i"\)\nname = &"Default"\n)sounds = Array\[AudioStream\]\(\[[^\]]*\]\)', text)
assert m, "default block not found"
text = text.replace(m.group(0), m.group(1) + 'sounds = Array[AudioStream]([%s])' % ", ".join('ExtResource("%s")' % i for i in sand_ids))

l_block = (
    '\n\n[sub_resource type="Resource" id="Resource_default_l"]\n'
    'script = ExtResource("2_msx8i")\n'
    'name = &"DefaultL"\n'
    'sounds = Array[AudioStream]([ExtResource("sand_1"), ExtResource("sand_2"), ExtResource("sand_3")])'
)
r_block = (
    '\n\n[sub_resource type="Resource" id="Resource_default_r"]\n'
    'script = ExtResource("2_msx8i")\n'
    'name = &"DefaultR"\n'
    'sounds = Array[AudioStream]([ExtResource("sand_4"), ExtResource("sand_5"), ExtResource("sand_6")])'
)
text = text.replace(m.group(0), m.group(0) + l_block + r_block, 1)

text = text.replace(
    '[SubResource("Resource_default")])',
    '[SubResource("Resource_default_l"), SubResource("Resource_default_r"), SubResource("Resource_default")])',
)

open(TRES, "w", encoding="utf-8").write(text)
print("default rewired to", len(sand_ids), "sand steps; added L/R entries")
