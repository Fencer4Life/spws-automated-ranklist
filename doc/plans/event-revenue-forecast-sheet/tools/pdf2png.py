import sys, subprocess, os
from pypdf import PdfReader, PdfWriter
src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
r = PdfReader(src)
base = os.path.splitext(os.path.basename(src))[0]
for i, p in enumerate(r.pages):
    w = PdfWriter(); w.add_page(p)
    one = f"{out}/{base}-p{i+1}.pdf"
    w.write(one)
    subprocess.run(["sips", "-s", "format", "png", "-Z", "1400", one, "--out", one[:-4] + ".png"], capture_output=True)
    os.remove(one)
print(base, len(r.pages))
