import re

MAP = "scenes/map.tscn"
RADIUS_K = 0.5
HEIGHT_K = 12.2
CENTER_K = 6.1

src = open(MAP, encoding="utf-8").read()
lines = src.split("\n")

tree_hdr_re = re.compile(r'^\[node name="(Tree\d+)" type="StaticBody3D" parent="Trees"\]$')
shape_ref_re = re.compile(r'^shape = SubResource\("(tree_cyl\d+)"\)$')
pos_rep_re = re.compile(r'^position = Vector3\(0\.0, 16\.0, 0\.0\)$')
scale_re = re.compile(r'^scale = Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)$')
sub_re = re.compile(r'^\[sub_resource type="CylinderShape3D" id="(tree_cyl\d+)"\]$')

info = {}
tree_id = None
shape_id = None
tree_scale = 1.0
shape_seen = False
i = 0
while i < len(lines):
    ln = lines[i]
    m = tree_hdr_re.match(ln)
    if m:
        tree_id = m.group(1)
        shape_id = None
        tree_scale = 1.0
        shape_seen = False
        i += 1
        continue
    if tree_id is None:
        i += 1
        continue
    if ln.startswith("[node"):
        if '[node name="TreeMesh"' in ln:
            info[tree_id] = (shape_id, tree_scale)
        i += 1
        continue
    m = scale_re.match(ln)
    if m and tree_scale == 1.0:
        tree_scale = float(m.group(1))
    m = shape_ref_re.match(ln)
    if m and shape_id is None:
        shape_id = m.group(1)
        shape_seen = True
    i += 1

shape_scale = {}
for tid, (sid, s) in info.items():
    if sid is not None:
        shape_scale[sid] = s

out = []
i = 0
while i < len(lines):
    ln = lines[i]
    m = sub_re.match(ln)
    if m and m.group(1) in shape_scale:
        s = shape_scale[m.group(1)]
        out.extend([ln, "radius = %s" % round(RADIUS_K * s, 4), "height = %s" % round(HEIGHT_K * s, 4)])
        i += 3
        continue
    out.append(ln)
    i += 1

lines2 = "\n".join(out).split("\n")
info2 = {}
tree_id = None
shape_id = None
i = 0
while i < len(lines2):
    ln = lines2[i]
    m = tree_hdr_re.match(ln)
    if m:
        tree_id = m.group(1)
        shape_id = None
        i += 1
        continue
    if tree_id is None:
        i += 1
        continue
    if ln.startswith("[node"):
        if '[node name="TreeMesh"' in ln:
            info2[tree_id] = shape_id
        i += 1
        continue
    m = shape_ref_re.match(ln)
    if m and shape_id is None:
        shape_id = m.group(1)
    i += 1

out = []
i = 0
tree_id = None
shape_id = None
while i < len(lines2):
    ln = lines2[i]
    m = tree_hdr_re.match(ln)
    if m:
        tree_id = m.group(1)
        shape_id = None
        out.append(ln)
        i += 1
        continue
    if tree_id is not None:
        m = pos_rep_re.match(ln)
        if m and info2.get(tree_id) is not None:
            s = shape_scale.get(info2[tree_id], 1.0)
            out.append("position = Vector3(0.0, %s, 0.0)" % round(CENTER_K * s, 4))
            i += 1
            continue
    out.append(ln)
    i += 1

open(MAP, "w", encoding="utf-8").write("\n".join(out))
print("trees:", len(info2), "shapes:", len(shape_scale))
