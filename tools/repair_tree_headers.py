import re

MAP = "scenes/map.tscn"
lines = open(MAP, encoding="utf-8").read().split("\n")

start = next(i for i, ln in enumerate(lines) if ln.startswith('[node name="Trees" type='))
out = lines[:start + 1]
i = start + 1
n = len(lines)
tm_re = re.compile(r'^\[node name="TreeMesh" parent="Trees/([^"]+)" instance=ExtResource\("(tree3d_[abc])"\)\]$')

while i < n:
    ln = lines[i]
    if ln.startswith("[node"):
        break
    buf = [ln]
    i += 1
    while i < n and not tm_re.match(lines[i]) and not lines[i].startswith("[node"):
        buf.append(lines[i])
        i += 1
    if i >= n:
        print("ERROR: ran past end of file")
        raise SystemExit(1)
    tm = tm_re.match(lines[i])
    tree_id = tm.group(1)
    groups = []
    cur = []
    for dl in buf:
        if dl.strip() == "":
            if cur:
                groups.append(cur)
                cur = []
        else:
            cur.append(dl)
    if cur:
        groups.append(cur)
    if len(groups) != 5 or len(groups[0]) != 1 or len(groups[1]) != 2:
        print("SEGMENT ERROR", tree_id, [len(g) for g in groups])
        raise SystemExit(1)
    if not any("0.785" in x for g in (groups[2], groups[3]) for x in g):
        print("CROSS SIGNATURE ERROR", tree_id)
        raise SystemExit(1)
    if not any("billboard = 2" in x for x in groups[4]):
        print("FLAT SIGNATURE ERROR", tree_id)
        raise SystemExit(1)
    out.extend(['[node name="%s" type="StaticBody3D" parent="Trees"]' % tree_id, groups[0][0], ""])
    out.extend(['[node name="Collision" type="CollisionShape3D" parent="Trees/%s"]' % tree_id, groups[1][0], groups[1][1], ""])
    out.extend(['[node name="CrossA" type="Sprite3D" parent="Trees/%s"]' % tree_id])
    out.extend(groups[2])
    out.extend(["", '[node name="CrossB" type="Sprite3D" parent="Trees/%s"]' % tree_id])
    out.extend(groups[3])
    out.extend(["", '[node name="Flat" type="Sprite3D" parent="Trees/%s"]' % tree_id])
    out.extend(groups[4])
    out.append("")
    tmblk = [lines[i]]
    i += 1
    while i < n and lines[i].strip() != "" and (lines[i].startswith("scale = ") or lines[i].startswith("visible = ")):
        tmblk.append(lines[i])
        i += 1
    out.extend(tmblk)
    out.append("")

out.extend(lines[i:])
open(MAP, "w", encoding="utf-8").write("\n".join(out))
print("repaired ok")
