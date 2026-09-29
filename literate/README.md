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

## Findings (real gaps this surfaced, not fixed on this branch)

- `hwx_dump/hwx_parsing.py`'s `get_ch_fmt_name()` is used for **both**
  `ch_fmt` and `kernel_fmt` (see `hwx_parsing.py:1595`), unlike `.m`
  and `.js` which have two separate functions. Because of that overload,
  Python's function has an extra `fmt_val in (0, 5)` branch (mapping the
  `kernel_fmt`-only value 5/E2M1 to `UINT8`) that `.m`/`.js` don't have,
  and it has no case for `kernel_fmt` values 3 (E4M3) or 4 (INT4) at all
  — those fall through to `f"Unknown({fmt_val})"` in the Python CLI
  output today. Not tangled from the pilot source because the shapes
  genuinely disagree; unifying it (splitting Python's function in two,
  matching `.m`) is a real, separate bug-fix task, not something to do
  silently as a side effect of this investigation.
- `hwx_dump_js/hwx_parser.js`'s `kfmtNames` array (`hwx_parser.js:692`)
  only covers 4 of `.m`'s 6 `get_kernel_fmt_name` cases (no INT4/E2M1) —
  same kind of gap, also left unfixed/untangled here for the same reason.

## Recommendation

Adopt the scoped marker+tangle approach incrementally, fact by fact, for
exactly the content that has already drifted or is likely to (format
encodings, bit-position tables, task-type maps) — not as a wholesale
rewrite. Suggested next steps if this is picked up:
1. Fix the two gaps above (make `.py`/`.js` structurally match `.m`),
   *then* extend `format_encoding.lit.md` to tangle into the
   now-matching `.py`/`.js` functions too.
2. Add `literate/tangle.py check` to CI (or a pre-commit hook) so any
   future edit to a tangled region without updating its `.lit.md` source
   fails immediately, the way this session's bug wouldn't have survived
   five commits' worth of manual re-checking.
3. Pick the next highest-value fact to move under tangle control —
   `Common.MacCfg`'s bit table (`Wino1D` etc., recently added to
   `GUIDE_ANE_HWX_FORMAT.md` §6.1.C) is the obvious next candidate since
   it was *also* just hand-copied across `.m`/`.py`/`.js`/docs this
   session.
