import re
import sys

MAP = "scenes/map.tscn"
VARIANTS = {
    "tree_tex1": (0, "res://scenes/tree3d_a.tscn", "tree3d_a"),
    "tree_tex2": (0, "res://scenes/tree3d_b.tscn", "tree3d_b"),
    "tree_tex5": (0, "res://scenes/tree3d_c.tscn", "tree3d_c"),
}

src = open(MAP, encoding="utf-8").read()
lines = src.split("\n")

if any('parent="Trees/FarTree' in ln and 'instance=ExtResource("tree3d' in ln for ln in lines):
    print("far splice already applied")
    sys.exit(0)

header_re = re.compile(r'^\[node name="(FarTree\d+)" type="Node3D" parent="Trees"\]$')
child_end_re = re.compile(r'^\[node name="[^"]+" type="[^"]+" parent="Trees/([^"]+)"')

out = []
counts = {}
i = 0
n = len(lines)
while i < n:
    mh = header_re.match(lines[i])
    if not mh:
        out.append(lines[i])
        i += 1
        continue
    name = mh.group(1)
    block = [lines[i]]
    i += 1
    tex_id = None
    while i < n:
        me = child_end_re.match(lines[i])
        if me and me.group(1) != name:
            break
        if lines[i].startswith("[node"):
            if me is None:
                break
            block.append(lines[i])
            i += 1
            continue
        if me is None:
            mt = re.match(r'^texture = ExtResource\("(tree_tex\d+)"\)', lines[i])
            if mt and tex_id is None:
                tex_id = mt.group(1)
        block.append(lines[i])
        i += 1
    var_id = VARIANTS[tex_id][2] if tex_id in VARIANTS else "tree3d_a"
    block.append('[node name="TreeMesh" parent="Trees/%s" instance=ExtResource("%s")]' % (name, var_id))
    block.append("visible = false")
    out.extend(block)
    counts[var_id] = counts.get(var_id, 0) + 1

sub_idx = next(i for i, ln in enumerate(out) if ln.startswith("[sub_resource"))
ext = []
for kid, (_, path, eid) in sorted(VARIANTS.items()):
    declared = any(re.match(r'^\[ext_resource type="PackedScene".*id="%s"\]$' % eid, ln) for ln in out)
    if not declared:
        ext.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (path, eid))
ext.sort()
out = out[:sub_idx] + ext + out[sub_idx:]
open(MAP, "w", encoding="utf-8").write("\n".join(out))
print("far spliced:", counts)
