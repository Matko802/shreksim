import os
import re
import shutil

SRC = "/mnt/ssd/My-Files/Projects/godot/Backrooms+"
DST = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

sounds_src = os.path.join(SRC, "Assets", "Sounds", "footsteps")
sounds_dst = os.path.join(DST, "assets", "sounds", "footsteps")
os.makedirs(sounds_dst, exist_ok=True)
copied = 0
for f in os.listdir(sounds_src):
    if f.endswith(".wav"):
        shutil.copyfile(os.path.join(sounds_src, f), os.path.join(sounds_dst, f))
        copied += 1

for script in ("footstep_surfaces.gd", "surface_entry.gd",
               "footstep_surfaces.gd.uid", "surface_entry.gd.uid"):
    src_path = os.path.join(SRC, script)
    code = open(src_path, encoding="utf-8").read()
    if script.endswith(".gd"):
        code = "\n".join(ln for ln in code.split("\n")
                         if not re.match(r'^\s*#', ln)).replace("\n\n\n", "\n\n")
    open(os.path.join(DST, "scripts", script), "w", encoding="utf-8").write(code)

tres = open(os.path.join(SRC, "footstep_surfaces.tres"), encoding="utf-8").read()
tres = re.sub(r'\s*uid="uid://[^"]*"', "", tres)
tres = tres.replace('path="res://footstep_surfaces.gd"', 'path="res://scripts/footstep_surfaces.gd"')
tres = tres.replace('path="res://surface_entry.gd"', 'path="res://scripts/surface_entry.gd"')


def audio_sub(m):
    base = os.path.basename(m.group(1))
    return 'path="res://assets/sounds/footsteps/%s"' % base


tres = re.sub(r'path="(res://Assets/Sounds/footsteps/[^"]+)"', audio_sub, tres)

res_dir = os.path.join(DST, "assets", "footsteps")
os.makedirs(res_dir, exist_ok=True)
open(os.path.join(res_dir, "footstep_surfaces.tres"), "w", encoding="utf-8").write(tres)

count = len(re.findall(r'\[ext_resource type="AudioStream" path="res://assets/sounds/footsteps/', tres))
print("wavs:", copied, "audio refs:", count)
