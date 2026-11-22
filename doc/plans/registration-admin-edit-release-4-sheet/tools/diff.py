"""Pixel comparison of two capture folders (usage: python diff.py <dir A> <dir B> <out.json>).

Every PNG present in both folders is compared; the report gives the number of
differing pixels and the box that holds them.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops

a_dir, b_dir, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
report: list[dict[str, object]] = []
for a in sorted(a_dir.glob("*.png")):
    b = b_dir / a.name
    if not b.exists():
        continue
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    if ia.size != ib.size:
        report.append({"name": a.name, "size": f"{ia.size} vs {ib.size}", "diff": -1, "box": None})
        continue
    delta = ImageChops.difference(ia, ib)
    box = delta.getbbox()
    r, g, b_ = delta.split()
    any_band = ImageChops.lighter(ImageChops.lighter(r, g), b_)
    diff = any_band.point(lambda v: 255 if v else 0).histogram()[255]
    report.append({"name": a.name, "size": f"{ia.size[0]}x{ia.size[1]}", "diff": diff, "box": box})
_ = out.write_text(json.dumps(report, indent=1), encoding="utf-8")
same = sum(1 for r in report if r["diff"] == 0)
print(f"{same} of {len(report)} identical")
for r in report:
    if r["diff"] != 0:
        print(" ", r["name"], r["diff"], r["box"])
