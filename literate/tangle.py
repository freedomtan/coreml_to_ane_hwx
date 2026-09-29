#!/usr/bin/env python3
"""Minimal noweb-style tangle tool for coreml_to_ane_hwx_hacks.

Motivating problem: the same register-field knowledge (e.g. "raw 0 =
UINT8, raw 1 = INT8" for ChannelCfg/KernelCfg) is hand-copied across
hwx_parsing.m, hwx_parsing.py, hwx_dump_js/hwx_parser.js, and
docs/GUIDE_ANE_HWX_FORMAT.md. When one copy gets fixed and the others
don't, they silently drift (this happened for real: see git commits
8eff668/5de3262/0b417ac fixing the same int8<->uint8 swap four times).

This script lets one literate Markdown file under literate/ own a
fact (as prose + a table) and "tangle" the exact same code into every
file that needs to embed it, so the four copies can never disagree.

Literate source format
-----------------------
A literate/*.lit.md file contains ordinary Markdown, plus directive
comments immediately followed by a fenced code block::

    <!-- tangle: hwx_dump/hwx_parsing.m#get_ch_fmt_name -->
    ```c
    const char *get_ch_fmt_name(uint32_t fmt) {
      ...
    }
    ```

Each target file must contain a matching marker region using its own
comment syntax, e.g. in a .m/.js file::

    // LIT:BEGIN(get_ch_fmt_name)
    const char *get_ch_fmt_name(uint32_t fmt) {
      ...
    }
    // LIT:END(get_ch_fmt_name)

or in a .py file (# comments) or .md file (<!-- --> comments).

`tangle.py write` overwrites the region between BEGIN/END with the
fenced code block's contents (re-indented to match the BEGIN marker's
indentation). `tangle.py check` does the same comparison but reports
drift and exits non-zero instead of writing -- intended for CI/pre-commit,
so the exact bug this tool is a response to becomes a hard failure
instead of a silent, multi-file typo.
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

DIRECTIVE_RE = re.compile(
    r"^<!--\s*tangle:\s*(?P<path>[^#\s]+)#(?P<id>[A-Za-z0-9_]+)\s*-->\s*$"
)
FENCE_OPEN_RE = re.compile(r"^```[A-Za-z0-9_+-]*\s*$")
FENCE_CLOSE_RE = re.compile(r"^```\s*$")

# Comment styles tried in order for each target file, by suffix.
MARKER_STYLES = {
    ".m": [("//", "")],
    ".c": [("//", "")],
    ".h": [("//", "")],
    ".js": [("//", "")],
    ".py": [("#", "")],
    ".md": [("<!--", "-->")],
}


def marker_regex(id_, start_or_end, open_c, close_c):
    close_c = (" " + close_c) if close_c else ""
    pattern = rf"^(?P<indent>\s*){re.escape(open_c)}\s*LIT:{start_or_end}\({re.escape(id_)}\){re.escape(close_c)}\s*$"
    return re.compile(pattern)


def find_markers(lines, id_, suffix):
    styles = MARKER_STYLES.get(suffix)
    if not styles:
        raise ValueError(f"no marker style registered for suffix {suffix!r}")
    for open_c, close_c in styles:
        begin_re = marker_regex(id_, "BEGIN", open_c, close_c)
        end_re = marker_regex(id_, "END", open_c, close_c)
        begin_idx = end_idx = None
        for i, line in enumerate(lines):
            m = begin_re.match(line)
            if m:
                begin_idx = i
                indent = m.group("indent")
                continue
            if begin_idx is not None and end_re.match(line):
                end_idx = i
                break
        if begin_idx is not None and end_idx is not None:
            return begin_idx, end_idx, indent
    return None, None, None


def parse_literate_file(path):
    """Yield (target_relpath, id, code_lines) for each tangle block."""
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        m = DIRECTIVE_RE.match(lines[i])
        if not m:
            i += 1
            continue
        target, id_ = m.group("path"), m.group("id")
        j = i + 1
        if j >= len(lines) or not FENCE_OPEN_RE.match(lines[j]):
            raise ValueError(
                f"{path}:{i+1}: tangle directive not followed by a fenced code block"
            )
        j += 1
        code_start = j
        while j < len(lines) and not FENCE_CLOSE_RE.match(lines[j]):
            j += 1
        if j >= len(lines):
            raise ValueError(f"{path}:{code_start}: unterminated code fence")
        code_lines = lines[code_start:j]
        yield target, id_, code_lines
        i = j + 1


def render_block(code_lines, indent):
    return [(indent + line if line else line) for line in code_lines]


def apply_to_target(target_path, id_, code_lines, write, results):
    lines = target_path.read_text().splitlines()
    begin_idx, end_idx, indent = find_markers(lines, id_, target_path.suffix)
    if begin_idx is None:
        results.append((target_path, id_, "MISSING_MARKERS", None))
        return
    new_block = render_block(code_lines, indent)
    current_block = lines[begin_idx + 1 : end_idx]
    if current_block == new_block:
        results.append((target_path, id_, "OK", None))
        return
    if write:
        new_lines = lines[: begin_idx + 1] + new_block + lines[end_idx:]
        target_path.write_text("\n".join(new_lines) + "\n")
        results.append((target_path, id_, "WRITTEN", None))
    else:
        results.append((target_path, id_, "DRIFT", (current_block, new_block)))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("mode", choices=["check", "write"])
    ap.add_argument(
        "literate_files",
        nargs="*",
        help="literate/*.lit.md files (default: all of literate/*.lit.md)",
    )
    args = ap.parse_args()

    lit_files = (
        [pathlib.Path(p) for p in args.literate_files]
        if args.literate_files
        else sorted((ROOT / "literate").glob("*.lit.md"))
    )

    results = []
    for lit_file in lit_files:
        for target_rel, id_, code_lines in parse_literate_file(lit_file):
            target_path = ROOT / target_rel
            apply_to_target(
                target_path, id_, code_lines, write=(args.mode == "write"), results=results
            )

    drift = [r for r in results if r[2] in ("DRIFT", "MISSING_MARKERS")]
    for target_path, id_, status, extra in results:
        rel = target_path.relative_to(ROOT)
        if status == "OK":
            print(f"  ok      {rel}#{id_}")
        elif status == "WRITTEN":
            print(f"  written {rel}#{id_}")
        elif status == "MISSING_MARKERS":
            print(f"  ERROR   {rel}#{id_}: no LIT:BEGIN/END({id_}) markers found")
        elif status == "DRIFT":
            print(f"  DRIFT   {rel}#{id_}: file differs from literate source")
            current_block, new_block = extra
            for line in current_block:
                print(f"    - {line}")
            for line in new_block:
                print(f"    + {line}")

    if drift:
        print(f"\n{len(drift)} region(s) out of sync with literate source.")
        return 1
    print(f"\nAll {len(results)} region(s) in sync.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
