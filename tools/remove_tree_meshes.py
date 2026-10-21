import re

MAP = "scenes/map.tscn"
lines = open(MAP, encoding="utf-8").read().split("\n")

out = []
i = 0
n = len(lines)
removed_nodes = 0
removed_ext = 0
while i < n:
    ln = lines[i]
    if ln.startswith('[node name="TreeMesh" parent="Trees/'):
        removed_nodes += 1
        i += 1
        while i < n and lines[i].strip() != "" and not lines[i].startswith("[node"):
            i += 1
        continue
    if re.match(r'^\[ext_resource type="PackedScene" path="res://scenes/tree3d_', ln):
        removed_ext += 1
        i += 1
        continue
    out.append(ln)
    i += 1

open(MAP, "w", encoding="utf-8").write("\n".join(out))
print("removed nodes:", removed_nodes, "ext:", removed_ext)
