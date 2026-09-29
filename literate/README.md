# Literate programming for hwx_parsing.{m,py} and friends — investigation

## Motivating problem

The same hardware-register fact routinely needs to live in four places:
`hwx_dump/hwx_parsing.m` (the canonical ObjC parser, castsraw memory onto
`ane_hwx_regs.h` structs), `hwx_dump/hwx_parsing.py` (a from-scratch port),
`hwx_dump_js/hwx_parser.js` (a browser port), and `docs/GUIDE_ANE_HWX_FORMAT.md`
(prose + tables describing the same bits). Earlier this session all four
disagreed about `ChannelCfg`/`KernelCfg`'s raw `0`/`1` value (`int8` vs
`uint8`), and fixing it took five separate commits (`8eff668`, `5de3262`,
`0b417ac`, plus the two that ported missing `MacCfg`/`Wino1D` fields).
Nothing enforced that the four copies agreed; they only agreed because a
human re-checked all four by hand.

This branch prototypes a **tangle-only literate-programming tool**
(`literate/tangle.py`) that lets one Markdown file own a fact and push the
exact same text into every file that needs to embed it, so a future
in-branch edit to just one of the four copies becomes a detectable,
checkable drift instead of a silent one.

## Design

- `literate/*.lit.md` — ordinary Markdown (readable/weavable as-is; no
  separate "weave" step needed since GitHub/editors already render it).
  Prose sits next to fenced code blocks; each block that should be
  tangled is preceded by a directive comment:
  `<!-- tangle: <path>#<id> -->`.
- Target files mark the region a block tangles into with comments in
  their own syntax: `// LIT:BEGIN(id)` / `// LIT:END(id)` for C/ObjC/JS,
  `# LIT:BEGIN(id)` / `# LIT:END(id)` for Python, `<!-- LIT:BEGIN(id) -->`
  for Markdown.
- `python3 literate/tangle.py check` — parses every `literate/*.lit.md`,
  and for each tangle block, diffs it against the marked region in its
  target file. Non-zero exit + a unified-diff-style report if anything
  differs. Meant to run in CI/pre-commit so drift fails the build instead
  of shipping.
- `python3 literate/tangle.py write` — same, but overwrites the marked
  regions to match the literate source (the actual "tangle" step, for
  when you edit the `.lit.md` and want to push the change out).

This is deliberately *not* a full noweb/CWEB/org-babel setup: there's no
chunk transclusion (`<<name>>`), no single "master" file that generates
everything (`.m`/`.py`/`.js`/`.h` stay real, independently-compilable/
runnable source files — tangle only touches clearly marked sub-regions
inside them). That's intentional: `hwx_parsing.m` is 3387 lines that
Xcode/clang need to keep working on as an ordinary file, and rewriting
it as a fully-tangled literate document would be a large, risky rewrite
for uncertain benefit. The scoped version costs one pair of marker
comments per fact and gets the actual property we want (cross-file
consistency, checkable in CI) without touching anything else.

## Pilot: `literate/format_encoding.lit.md`

Tangles the `ChannelCfg`/`KernelCfg` raw-value-to-name table — the exact
fact that caused this session's five-commit fire drill — into:

- `hwx_dump/hwx_parsing.m#get_ch_fmt_name` and `#get_kernel_fmt_name`
- `hwx_dump_js/hwx_parser.js#get_ch_fmt_name`
- `docs/GUIDE_ANE_HWX_FORMAT.md#ch_fmt_doc_table`

Verified against the current (already-fixed) code: `tangle.py check`
reports all 4 regions in sync. Verified drift detection works by
temporarily swapping `get_ch_fmt_name`'s case 0/1 bodies in `.m` and
confirming `check` reports a `DRIFT` diff and exits 1; reverted and
re-confirmed clean.

## Findings (real gaps this surfaced — now fixed)

- `hwx_dump/hwx_parsing.py`'s `get_ch_fmt_name()` was overloaded to decode
  **both** `ch_fmt` and `kernel_fmt`, unlike `.m`/`.js` which have two
  separate functions. That overload made two real, reachable raw values
  print wrong: `kernel_fmt=3` (E4M3, reachable on real H16-H19 hardware
  since `kernel_fmt` is a 2-bit field) fell through to `Unknown(3)`
  instead of `E4M3`, and a ch_fmt-only `fmt_val in (0, 5)` branch mapped
  `kernel_fmt=5` to `UINT8` instead of `E2M1`. **Fixed**: split into
  `get_ch_fmt_name` (now matches `.m` exactly) and a new
  `get_kernel_fmt_name` (matches `.m`'s 6-case table), repointed the four
  kernel-format call sites, and both are now tangled from
  `literate/format_encoding.lit.md` alongside `.m` and `.js`.
- `hwx_dump_js/hwx_parser.js`'s `kfmtNames` array only covered 4 of `.m`'s
  6 `get_kernel_fmt_name` cases (no INT4/E2M1), and its `|| "UINT8"`
  fallback would have mislabeled an out-of-range value as UINT8 instead
  of `Unknown(n)`. `kfmt` is masked to 2 bits (max value 3) so INT4/E2M1
  are unreachable today — same as `.py`'s newly-split function — but both
  are now tangled from the same literate source as `.m`/`.py` so a future
  wider field can't silently disagree across the three parsers again.

## Recommendation

Adopt the scoped marker+tangle approach incrementally, fact by fact, for
exactly the content that has already drifted or is likely to (format
encodings, bit-position tables, task-type maps) — not as a wholesale
rewrite. Suggested next steps if this is picked up:
1. ~~Fix the two gaps above~~ — done: `.py`/`.js` now structurally match
   `.m`, and `format_encoding.lit.md` tangles into all three.
2. Add `literate/tangle.py check` to CI (or a pre-commit hook) so any
   future edit to a tangled region without updating its `.lit.md` source
   fails immediately, the way this session's bug wouldn't have survived
   five commits' worth of manual re-checking.
3. Pick the next highest-value fact to move under tangle control —
   `Common.MacCfg`'s bit table (`Wino1D` etc., recently added to
   `GUIDE_ANE_HWX_FORMAT.md` §6.1.C) is the obvious next candidate since
   it was *also* just hand-copied across `.m`/`.py`/`.js`/docs this
   session.
