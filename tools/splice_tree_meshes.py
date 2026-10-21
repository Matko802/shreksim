import re
import sys

MAP = "scenes/map.tscn"
VARIANTS = {
    "tree_tex1": ("tree3d_a", "res://scenes/tree3d_a.tscn"),
    "tree_tex2": ("tree3d_b", "res://scenes/tree3d_b.tscn"),
    "tree_tex5": ("tree3d_c", "res://scenes/tree3d_c.tscn"),
}

src = open(MAP, "r", encoding="utf-8").read()
lines = src.split("\n")

if any('instance=ExtResource("tree3d' in ln for ln in lines):
    print("splicing already applied, nothing to do")
    sys.exit(0)

tex_ids = {}
for ln in lines:
    m = re.match(r'\[ext_resource type="Texture2D" path="res://assets/images/trees/tree(\d+)\.png" id="(tree_tex\d+)"\]', ln)
    if m:
        tex_ids[m.group(2)] = int(m.group(1))

ext_lines = []
used = set()
sub_idx = next(i for i, ln in enumerate(lines) if ln.startswith("[sub_resource"))
for kid in ("tree_tex1", "tree_tex2", "tree_tex5"):
    if kid in tex_ids:
        used.add(kid)
        ext_lines.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (VARIANTS[kid][1], VARIANTS[kid][0]))

header_re = re.compile(r'^\[node name="([^"]+)" type="StaticBody3D" parent="Trees"\]$')
tex_re = re.compile(r'^texture = ExtResource\("(tree_tex\d+)"\)')
end_re = re.compile(r'^\[node name="[^"]+" type="[^"]+" parent="Trees/([^"]+)"')

out = []
i = 0
counts = {}
while i < len(lines):
    mh = header_re.match(lines[i])
    if not mh:
        out.append(lines[i])
        i += 1
        continue
    name = mh.group(1)
    tex_id = None
    scale = 1.45
    i += 1
    while i < len(lines):
        me = end_re.match(lines[i])
        if me and me.group(1) != name:
            break
        if lines[i].startswith("[node"):
            child = end_re.match(lines[i])
            if child is None:
                break
            i += 1
            continue
        if None == me:
            mt = tex_re.match(lines[i])
            if mt and tex_id is None:
                tex_id = mt.group(1)
            ms = re.match(r'^scale = Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)$', lines[i])
            if ms:
                scale = float(ms.group(1))
        out.append(lines[i])
        i += 1
        if i < len(lines) and lines[i - 1].strip() == "":
            pass
    out.extend(["[node name=\"TreeMesh\" parent=\"Trees/%s\" instance=ExtResource(\"%s\")]" % (name, VARIANTS[tex_id][0] if VARIANTS.get(tex_id) else "tree3d_a")])
    if abs(scale - 1.45) > 0.001:
        out.append("scale = Vector3(%s, %s, %s)" % (scale, scale, scale))
    out.append("visible = false")
    key = (tex_id or "default")[:9]
    counts[key] = counts.get(key, 0) + 1

out2 = out[:sub_idx] + ext_lines + out[sub_idx:]
open(MAP, "w", encoding="utf-8").write("\n".join(out2))
print("spliced:", counts)
print("ext variants:", sorted(used))
