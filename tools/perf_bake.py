import re
import sys

PATH = "scenes/map.tscn"
FADE_CROSS_END = 34.0
FADE_CROSS_MARGIN = 4.0
FLAT_BEGIN = 27.0
FLAT_BEGIN_MARGIN = 4.0
FLAT_END = 110.0
FLAT_END_MARGIN = 20.0


def main() -> None:
    with open(PATH, "r", encoding="utf-8") as f:
        lines = f.readlines()
    headers = []
    for i, line in enumerate(lines):
        m = re.match(r'\[node name="(CrossA|CrossB|Flat)" type="Sprite3D" parent="Trees/Tree\d+"', line)
        if m:
            headers.append((i, m.group(1)))
    bounds = {}
    for idx, (i, name) in enumerate(headers):
        end = headers[idx + 1][0] if idx + 1 < len(headers) else len(lines)
        bounds[i] = (name, end)
    need_range = set()
    for i, (name, end) in bounds.items():
        if not any(lines[j].startswith("visibility_range") for j in range(i + 1, end)):
            need_range.add(i)
    out = []
    shaded_fixed = 0
    range_added = 0
    vis_flipped = 0
    current_tree_sprite = ""
    for i, line in enumerate(lines):
        m = re.match(r'\[node name="(CrossA|CrossB|Flat)" type="Sprite3D" parent="Trees/Tree\d+"', line)
        if m:
            current_tree_sprite = m.group(1)
        elif line.startswith("[node"):
            current_tree_sprite = ""
        if line == "shaded = true\n":
            out.append("shaded = false\n")
            shaded_fixed += 1
            continue
        if line == "visible = false\n" and current_tree_sprite in ("CrossA", "CrossB"):
            out.append("visible = true\n")
            vis_flipped += 1
            continue
        out.append(line)
        if m and i in need_range:
            name = m.group(1)
            if name == "Flat":
                props = [
                    f"visibility_range_begin = {FLAT_BEGIN}\n",
                    f"visibility_range_begin_margin = {FLAT_BEGIN_MARGIN}\n",
                    f"visibility_range_end = {FLAT_END}\n",
                    f"visibility_range_end_margin = {FLAT_END_MARGIN}\n",
                ]
            else:
                props = [
                    f"visibility_range_end = {FADE_CROSS_END}\n",
                    f"visibility_range_end_margin = {FADE_CROSS_MARGIN}\n",
                ]
            out.extend(props)
            range_added += 1
    with open(PATH, "w", encoding="utf-8") as f:
        f.writelines(out)
    print(f"shaded fixed: {shaded_fixed}, ranges: {range_added}, cross visibility flipped: {vis_flipped}")


if __name__ == "__main__":
    sys.exit(main())
