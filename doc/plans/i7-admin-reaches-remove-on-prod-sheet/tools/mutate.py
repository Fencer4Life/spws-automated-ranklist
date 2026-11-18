"""I7 mutation runs (usage: python3 mutate.py <frontend dir>): each mutation must turn its guarding test red; the file is restored after each."""
import subprocess
import sys

FE = sys.argv[1]
MUTATIONS = [
    ("M1 · in-place switch ignores sign-in", "src/components/Sidebar.svelte",
     "} else if (inPlace && isAdmin) {", "} else if (inPlace) {",
     "tests/Sidebar.test.ts", "WP.NAV.06"),
    ("M2 · calculator and table also in place", "src/components/Sidebar.svelte",
     "    calendar: 'calendar',\n  }", "    calendar: 'calendar',\n    calculator: 'ranklist',\n    table: 'ranklist',\n  }",
     "tests/Sidebar.test.ts", "WP.NAV.07"),
    ("M3 · height class also on the calendar page", "src/App.svelte",
     "class:site-own-height={site && currentView === 'calendar' && view !== 'calendar'}",
     "class:site-own-height={site && currentView === 'calendar'}",
     "tests/SiteAdminCalendar.test.ts", "the calendar page never carries it"),
]
out: list[str] = []
for name, path, old, new, test, needle in MUTATIONS:
    p = f"{FE}/{path}"
    src = open(p, encoding="utf-8").read()
    assert src.count(old) == 1, (name, src.count(old))
    _ = open(p, "w", encoding="utf-8").write(src.replace(old, new))
    try:
        r = subprocess.run(["npx", "vitest", "run", test], cwd=FE, capture_output=True, text=True)
        text = r.stdout + r.stderr
        failed = [ln.strip() for ln in text.splitlines() if "×" in ln]
        hit = any(needle in ln for ln in failed)
        out.append(f"{name}: exit {r.returncode}; failing: {failed}; guarded test red: {hit}")
    finally:
        _ = open(p, "w", encoding="utf-8").write(src)
print("\n".join(out))
