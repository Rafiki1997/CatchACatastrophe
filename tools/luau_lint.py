"""Structural sanity check for Luau sources.

Not a parser. It strips comments and strings, then checks that block keywords
and brackets balance. That catches the two mistakes that actually happen when
writing thousands of lines by hand: a missing `end` and a stray bracket.

The one subtlety is that Luau has an `if a then b else c` EXPRESSION with no
`end`, alongside the `if ... then ... end` statement. They are told apart here
by position: a statement `if` starts its line, an expression `if` does not.

Validate any change to this file against a codebase known to compile before
trusting its output on a new one.
"""
import glob
import os
import re
import sys


def strip(src):
    """Remove comments and string literals, preserving line count."""
    out = []
    i = 0
    n = len(src)
    line = 1
    while i < n:
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                if j == -1:
                    return None, line, "unterminated long comment"
                out.append("\n" * src.count("\n", i, j))
                line += src.count("\n", i, j)
                i = j + len(close)
                continue
            j = src.find("\n", i)
            if j == -1:
                break
            i = j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            if j == -1:
                return None, line, "unterminated long string"
            out.append("\n" * src.count("\n", i, j))
            line += src.count("\n", i, j)
            i = j + len(close)
            continue
        c = src[i]
        if c in "\"'":
            quote = c
            i += 1
            closed = False
            while i < n:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "\n":
                    return None, line, "raw newline inside a quoted string"
                if src[i] == quote:
                    i += 1
                    closed = True
                    break
                i += 1
            if not closed:
                return None, line, "unterminated string"
            out.append("STR")
            continue
        if c == "\n":
            line += 1
        out.append(c)
        i += 1
    return "".join(out), None, None


TOKENS = re.compile(r"\b\w+\b|[(){}\[\]]")


def check(path):
    src = open(path, encoding="utf-8").read()
    clean, errline, why = strip(src)
    if clean is None:
        return [f"{path}:{errline}: {why}"]

    problems = []
    stack = []
    paren = brace = square = 0

    for lineno, text in enumerate(clean.split("\n"), 1):
        indent = len(text) - len(text.lstrip())
        for tok in TOKENS.finditer(text):
            t = tok.group(0)
            at_line_start = tok.start() == indent

            if t == "function":
                stack.append((lineno, "function"))
            elif t == "if":
                # expression `if` (mid-line) needs no `end`
                if at_line_start:
                    stack.append((lineno, "if"))
            elif t in ("for", "while"):
                stack.append((lineno, t))
            elif t == "do":
                # the `do` that closes `for ... do` / `while ... do` is not a block
                if stack and stack[-1][1] in ("for", "while"):
                    pass
                else:
                    stack.append((lineno, "do"))
            elif t == "repeat":
                stack.append((lineno, "repeat"))
            elif t == "until":
                if stack and stack[-1][1] == "repeat":
                    stack.pop()
                else:
                    problems.append(f"{path}:{lineno}: `until` with no `repeat`")
            elif t == "end":
                if not stack:
                    problems.append(f"{path}:{lineno}: extra `end`")
                else:
                    stack.pop()
            elif t == "(":
                paren += 1
            elif t == ")":
                paren -= 1
                if paren < 0:
                    problems.append(f"{path}:{lineno}: unbalanced )")
                    paren = 0
            elif t == "{":
                brace += 1
            elif t == "}":
                brace -= 1
                if brace < 0:
                    problems.append(f"{path}:{lineno}: unbalanced }}")
                    brace = 0
            elif t == "[":
                square += 1
            elif t == "]":
                square -= 1
                if square < 0:
                    problems.append(f"{path}:{lineno}: unbalanced ]")
                    square = 0

    if stack:
        detail = ", ".join(f"{kind} at line {ln}" for ln, kind in stack[:4])
        problems.append(f"{path}: {len(stack)} unclosed block(s): {detail}")
    if paren:
        problems.append(f"{path}: {paren} unclosed (")
    if brace:
        problems.append(f"{path}: {brace} unclosed {{")
    if square:
        problems.append(f"{path}: {square} unclosed [")
    return problems


root = sys.argv[1]
files = sorted(glob.glob(os.path.join(root, "**", "*.luau"), recursive=True))
allp = []
for f in files:
    allp.extend(check(f))
print(f"checked {len(files)} files in {root}")
for p in allp:
    print("  " + p)
print("STRUCTURE OK" if not allp else f"{len(allp)} PROBLEM(S)")
