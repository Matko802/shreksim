import re

MAP = "scenes/map.tscn"
lines = open(MAP, encoding="utf-8").read().split("\n")

hdr_re = re.compile(r'^\[node name="(CrossA|CrossB|Flat)" type="Sprite3D" parent="Trees/[^"]+"\]')

out = []
cur = None
for ln in lines:
    m = hdr_re.match(ln)
    if m:
        if cur == "x":
            out.append("visible = false")
            out.append("")
        cur = {"CrossA": "x", "CrossB": "x", "Flat": "flat"}[m.group(1)]
        out.append(ln)
        continue
    if ln.startswith("[node"):
        if cur == "x":
            out.append("visible = false")
            out.append("")
        out.append(ln)
        cur = None
        continue
    if ln.strip() == "":
        if cur == "x":
            out.append("visible = false")
        out.append(ln)
        cur = None
        continue
    if cur == "flat" and ln.strip() == "visible = false":
        continue
    out.append(ln)
if cur == "x":
    out.append("visible = false")

open(MAP, "w", encoding="utf-8").write("\n".join(out))

flat_vis = sum(1 for ln in out if ln == "visible = false")
print("crossed hidden lines:", flat_vis)
