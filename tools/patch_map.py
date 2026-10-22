import math
import random
import re

SRC = "scenes/map.tscn"
GRID_N = 241
HALF = 256.0

PATH_WPTS = [
    (0, 0), (34, -20), (70, -42), (98, -14), (62, 18), (26, 40), (66, 64),
    (98, 90), (58, 110), (12, 86), (-30, 58), (-64, 28), (-42, 2), (-72, -28),
    (-98, -54), (-62, -82), (-18, -64), (26, -76), (68, -90), (96, -72),
]
TRAIL_STEP = 1.2
ONION_RADII = [22.4, 25.6, 28.0, 42.4, 46.0, 62.4, 65.2, 78.0, 84.0, 98.0, 104.0, 116.0]
GOLDEN = 2.399963229728653


def load_heights():
    raw = open("assets/maps/terrain_data.tres", "r", encoding="utf-8").read()
    m = re.search(r"heights = PackedFloat32Array\((.*?)\)\n", raw, re.S)
    vals = [float(v) for v in m.group(1).split(",")]
    assert len(vals) == GRID_N * GRID_N, len(vals)
    return vals


def terrain_height(hs, x, z):
    fx = max(0.0, min(1.0, (x + HALF) / (HALF * 2.0))) * (GRID_N - 1)
    fz = max(0.0, min(1.0, (z + HALF) / (HALF * 2.0))) * (GRID_N - 1)
    ix = max(0, min(GRID_N - 2, int(fx)))
    iz = max(0, min(GRID_N - 2, int(fz)))
    dx = fx - ix
    dz = fz - iz
    h00 = hs[iz * GRID_N + ix]
    h10 = hs[iz * GRID_N + ix + 1]
    h01 = hs[(iz + 1) * GRID_N + ix]
    h11 = hs[(iz + 1) * GRID_N + ix + 1]
    return (h00 * (1 - dx) + h10 * dx) * (1 - dz) + (h01 * (1 - dx) + h11 * dx) * dz


def path_samples():
    pts = [(PATH_WPTS[0][0], PATH_WPTS[0][1])]
    w = PATH_WPTS
    for k in range(1, len(w) - 1):
        p0 = w[k - 1]
        p1 = w[k]
        p2 = w[k + 1]
        p3 = w[k + 2] if k + 2 < len(w) else tuple(2.0 * v2 - v1 for v1, v2 in zip(p1, p2))
        steps = max(2, int(math.ceil(math.dist(p1, p2) / TRAIL_STEP)))
        for s in range(steps):
            u = s / steps
            u2 = u * u
            u3 = u2 * u
            x = p1[0] + 0.5 * ((p2[0] - p0[0]) * u + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * u2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * u3)
            z = p1[1] + 0.5 * ((p2[1] - p0[1]) * u + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * u2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * u3)
            pts.append((x, z))
    pts.append(tuple(PATH_WPTS[-1]))
    return pts


def onion_spots():
    return [
        (math.cos(GOLDEN * j) * ONION_RADII[j % len(ONION_RADII)], math.sin(GOLDEN * j) * ONION_RADII[j % len(ONION_RADII)])
        for j in range(40)
    ]


def scatter_normal(count, hs, samples, spots, rng):
    placed = []
    attempts = 0
    while len(placed) < count and attempts < count * 6000:
        attempts += 1
        x = rng.uniform(-122.0, 122.0)
        z = rng.uniform(-122.0, 122.0)
        if math.hypot(x, z) < 10.0:
            continue
        ok = True
        for sp in spots:
            if (sp[0] - x) ** 2 + (sp[1] - z) ** 2 < 3.5 ** 2:
                ok = False
                break
        if ok:
            for sp in samples:
                if (sp[0] - x) ** 2 + (sp[1] - z) ** 2 < 4.0 ** 2:
                    ok = False
                    break
        if ok:
            for other in placed:
                if (other[0] - x) ** 2 + (other[1] - z) ** 2 < 6.5 ** 2:
                    ok = False
                    break
        if ok:
            placed.append((x, z, terrain_height(hs, x, z)))
    if len(placed) != count:
        raise SystemExit("normal tree placement incomplete %d/%d" % (len(placed), count))
    return placed


def scatter_far(count, hs, rng):
    placed = []
    attempts = 0
    while len(placed) < count and attempts < count * 6000:
        attempts += 1
        x = rng.uniform(-176.0, 176.0)
        z = rng.uniform(-176.0, 176.0)
        if max(abs(x), abs(z)) < 134.0 or max(abs(x), abs(z)) > 172.0:
            continue
        ok = True
        for other in placed:
            if (other[0] - x) ** 2 + (other[1] - z) ** 2 < 8.0 ** 2:
                ok = False
                break
        if ok:
            placed.append((x, z, terrain_height(hs, x, z)))
    if len(placed) != count:
        raise SystemExit("far tree placement incomplete %d/%d" % (len(placed), count))
    return placed


def set_transform(para, pos):
    m = re.search(r"transform = Transform3D\(([-0-9., e]+)\)", para)
    if not m:
        raise SystemExit("no transform in para: " + para.split("\n")[0])
    vals = m.group(1).split(",")
    if [v.strip() for v in vals[:9]] != ["1", "0", "0", "0", "1", "0", "0", "0", "1"]:
        basis = ",".join(vals[:9])
    else:
        basis = "1, 0, 0, 0, 1, 0, 0, 0, 1"
    new = "transform = Transform3D(%s, %s, %s, %s)" % (basis, fmt(pos[0]), fmt(pos[1]), fmt(pos[2]))
    return para[: m.start()] + new + para[m.end() :]


def row(pos):
    return (pos[0], pos[2], pos[1])


def fmt(v):
    s = repr(round(float(v), 6))
    if s == "-0.0":
        s = "-0"
    return s


def main():
    rng = random.Random(4212)
    hs = load_heights()
    samples = path_samples()
    spots = onion_spots()
    src = open(SRC, "r", encoding="utf-8").read()
    root_normal = re.findall(r'\[node name="Tree(\d+)" type="[^"]*" parent="Trees"', src)
    root_far = re.findall(r'\[node name="FarTree(\d+)" type="[^"]*" parent="Trees"', src)
    print("normal roots:", len(root_normal), "far roots:", len(root_far))
    normal_pos = {int(n): p for n, p in zip(sorted(map(int, root_normal)), scatter_normal(len(root_normal), hs, samples, spots, rng))}
    far_pos = {int(n): p for n, p in zip(sorted(map(int, root_far)), scatter_far(len(root_far), hs, rng))}
    paras = src.split("\n\n")
    out = []
    stats = {"flat": 0, "boundary": 0, "far_unhidden": 0, "ext": 0, "swapped": 0, "normal_moved": 0, "far_moved": 0}
    for para in paras:
        head = para.split("\n")[0]
        if head.startswith("[node name=\"Flat\""):
            stats["flat"] += 1
            continue
        if head.startswith("[node name=\"Boundary\" type=\"StaticBody3D\" parent=\"Terrain\""):
            stats["boundary"] += 1
            continue
        if head.startswith("[node name=\"TerrainShape\" type=\"CollisionShape3D\" parent=\"Terrain/Boundary\""):
            continue
        if head.startswith("[ext_resource"):
            keep = []
            for ln in para.split("\n"):
                if re.search(r'"(1_mesh|2_material|3_shape)"', ln):
                    stats["ext"] += 1
                    continue
                keep.append(ln)
            if not keep:
                continue
            para = "\n".join(keep)
        if head.startswith("[node name=\"Terrain\" type=\"MeshInstance3D\" parent=\".\""):
            onion_block = ""
            for k, sp in enumerate(onion_spots()):
                ox, oz = sp
                oh = terrain_height(hs, ox, oz)
                onion_block += (
                    "\n\n[node name=\"Onion%03d\" type=\"Node3D\" parent=\"OnionSpots\" unique_id=%d]\n"
                    "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)"
                    % (k + 1, 1632094417 + 7 * (k + 1), fmt(ox), fmt(oh), fmt(oz))
                )
            para = (
                "[node name=\"Terrain\" type=\"Terrain3D\" parent=\".\" unique_id=721461624]\n"
                "region_size = 256\n"
                "vertex_spacing = 2.1333333333333333\n"
                "collision_mode = 3\n"
                "material = ExtResource(\"t3d_material\")\n"
                "assets = ExtResource(\"t3d_assets\")\n"
                "data_directory = \"res://assets/maps/terrain3d/\"\n"
                "\n"
                "[node name=\"OnionSpots\" type=\"Node3D\" parent=\".\" unique_id=1704439101]"
                + onion_block
            )
            stats["swapped"] += 1
            out.append(para)
            continue
        m = re.match(r'\[node name="Tree(\d+)" type="[^"]*" parent="Trees"', head)
        if m and int(m.group(1)) in normal_pos:
            para = set_transform(para, row(normal_pos[int(m.group(1))]))
            stats["normal_moved"] += 1
            out.append(para)
            continue
        m = re.match(r'\[node name="FarTree(\d+)" type="[^"]*" parent="Trees"', head)
        if m and int(m.group(1)) in far_pos:
            para = set_transform(para, row(far_pos[int(m.group(1))]))
            stats["far_moved"] += 1
            out.append(para)
            continue
        pm = re.search(r'parent="(Trees/FarTree\d+)"', head) and head.startswith("[node name=\"Cross")
        if pm and "visible = false" in para:
            keep = [ln for ln in para.split("\n") if ln.strip() != "visible = false"]
            stats["far_unhidden"] += len(para.split("\n")) - len(keep)
            out.append("\n".join(keep))
            continue
        out.append(para)
    text = "\n\n".join(out)
    text = text.replace("visibility_range_end = 34.0", "visibility_range_end = 0.0")
    exts = (
        '[ext_resource type="Terrain3DMaterial" path="res://assets/maps/terrain3d_material.tres" id="t3d_material"]\n'
        '[ext_resource type="Terrain3DAssets" path="res://assets/maps/terrain3d_assets.tres" id="t3d_assets"]\n'
    )
    idx = text.rfind("[ext_resource")
    line_end = text.find("\n", idx)
    text = text[: line_end + 1] + exts + text[line_end + 1 :]
    print(stats)
    open(SRC, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
