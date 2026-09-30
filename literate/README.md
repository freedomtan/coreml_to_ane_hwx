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
3. ~~Pick the next highest-value fact~~ — done: `Common.MacCfg`'s bit
   table (`literate/common_maccfg.lit.md`), NE op-mode/task-type tables
   (`literate/task_and_opmode_naming.lit.md`), and PE name tables
   (`literate/pe_naming.lit.md`) are all now tangled. Coverage is 37
   regions as of this pass.
4. ~~Fix JS's PE op-mode table~~ — done: it was using H13's *different*
   PE op-mode encoding by mistake; now matches `.m`/`.py`/docs.
5. ~~Add JS's missing PE `RedIdx`/`RedKeep`/`Src1`/`Src2` fields~~ — done.
6. ~~JS's PE decode showed a raw-op-derived name even when Python would
   suppress it to `"None"`~~ — done: added the same `taskTypeMapped`
   gating (`0`/`2` for pool, `3`-`6` for op) `.m`/`.py` use, verified
   task-by-task against `resnet50_quant_m4`'s sample (19 active-PE tasks,
   all now match `hwx_parsing.py -r`'s raw output exactly, including the
   Pool=Max task that previously showed a spurious `opMode: "Add"`).
7. ~~Add `literate/tangle.py check` to CI (or a pre-commit hook)~~ — done:
   `.github/workflows/tangle-check.yml` runs it on every push/PR; a local
   pre-commit hook (`literate/git-hooks/pre-commit`) is available via
   `sh literate/install-hooks.sh` (one-time per clone). Both run the same
   `python3 literate/tangle.py check`.

   Wiring this up immediately caught a real, pre-existing gap: fixing
   `hwx_dump/hwx_parsing.py`'s `get_ch_fmt_name`/`kernel_fmt` split
   (`literate/format_encoding.lit.md`) had marked the region with
   `LIT:BEGIN(id)` but never added a `<!-- tangle: ... -->` directive for
   it in any `.lit.md` — so `check` silently skipped it, and a
   deliberately reintroduced bug in that exact function passed clean.
   Fixed by teaching `tangle.py check` to scan the whole repo for
   `LIT:BEGIN(id)` markers with no declaring directive (`ORPHAN` in its
   output, non-zero exit) — a class of gap this project has now hit more
   than once (the multi-region-per-file bug found while building
   `literate/common_maccfg.lit.md` was the other), so it's worth checking
   for by construction rather than by memory. Verified end-to-end:
   reintroduced the same drift after the fix, and the pre-commit hook
   correctly rejected the commit this time.
