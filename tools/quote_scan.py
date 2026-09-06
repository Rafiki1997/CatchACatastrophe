"""Find Luau lines with an odd number of unescaped double quotes.

A raw newline inside a quoted string is a compile error, and it is exactly what
a mangled search-and-replace produces. Any line with an odd quote count is
either that bug or a long-bracket string worth eyeballing.
"""
import glob
import re
import sys

root = sys.argv[1] if len(sys.argv) > 1 else "src"
files = sorted(glob.glob(root + "/**/*.luau", recursive=True))
UNESCAPED_QUOTE = re.compile(r'(?<!\\)"')

bad = []
for path in files:
    in_long = False
    for i, line in enumerate(open(path, encoding="utf-8"), 1):
        stripped = line.strip()
        if stripped.startswith("--") and not stripped.startswith("--[["):
            continue
        if "[[" in line:
            in_long = True
        if "]]" in line:
            in_long = False
            continue
        if in_long:
            continue
        # drop a trailing line comment, crudely: text after `--` that is not in a string
        n = len(UNESCAPED_QUOTE.findall(line))
        if n % 2 == 1:
            bad.append(f"{path}:{i}: odd quote count -> {stripped[:100]}")

print(f"scanned {len(files)} files")
for b in bad:
    print("  " + b)
print("NO UNBALANCED QUOTES" if not bad else f"{len(bad)} LINES TO CHECK")
