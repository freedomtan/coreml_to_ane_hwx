# Literate source: Common.MacCfg bit layout (H16+)

Fourth tangle pilot, and the one `literate/README.md` originally
flagged as the next candidate: `Common.MacCfg` (word offset 15 / byte
`0x3C` on H16+) carries `TaskType`, `SmallSrc`, `ActiveNE`, `TraceEn`,
`ReluType`, `OutTrans`, `FillLowerNE`, and `Wino1D` — the exact fact
that took three separate hand-verification passes this session
(against `ane_hwx_regs.h`, then again for `docs/GUIDE_ANE_HWX_FORMAT.md`
§6.1.C, then again when porting it into `hwx_dump_js/hwx_parser.js`).

Unlike the earlier pilots, this fact was **already duplicated three
times inside `hwx_dump/hwx_parsing.py` itself** (once per `instr_ver`
branch in `print_common_h16` — H18/H17/H16-hybrid all share the
identical bit layout) before ever reaching `.js` or the docs. That's
exactly the kind of same-file drift risk `literate/tangle.py` didn't
originally support (it only tracked one marker pair per id per file) —
fixed as part of this pilot: `find_marker_regions` now returns every
`LIT:BEGIN(id)`/`LIT:END(id)` pair in a file, and `write`/`check` apply
to all of them.

## `ane_hwx_regs.h`'s `maccfg` bitfield struct (H17, H18)

H17 and H18's copies are byte-for-byte identical; H16's own struct
(not tangled here) differs by exactly one bit — `wino1d` is `pad3`
there, annotated `// [27] (1D Winograd unsupported in H16)`.

<!-- tangle: hwx_dump/ane_hwx_regs.h#common_maccfg_h17 -->
```c
struct {
  uint32_t pad0 : 2;            // [1:0]
  uint32_t small_src_mode : 2;  // [3:2]
  uint32_t task_type : 4;       // [7:4]
  uint32_t sh_pref : 3;         // [10:8]
  uint32_t pad1 : 1;            // [11]
  uint32_t sh_min : 3;          // [14:12]
  uint32_t pad2 : 1;            // [15]
  uint32_t sh_max : 3;          // [18:16]
  uint32_t active_ne : 3;       // [21:19]
  uint32_t trace_en : 1;        // [22]
  uint32_t l2_barrier : 1;      // [23]
  uint32_t relu_type : 3;       // [26:24]
  uint32_t wino1d : 1;          // [27]
  uint32_t out_trans : 1;       // [28]
  uint32_t fill_lower_ne : 1;   // [29]
  uint32_t pad4 : 2;            // [31:30]
} maccfg;
```

<!-- tangle: hwx_dump/ane_hwx_regs.h#common_maccfg_h18 -->
```c
struct {
  uint32_t pad0 : 2;            // [1:0]
  uint32_t small_src_mode : 2;  // [3:2]
  uint32_t task_type : 4;       // [7:4]
  uint32_t sh_pref : 3;         // [10:8]
  uint32_t pad1 : 1;            // [11]
  uint32_t sh_min : 3;          // [14:12]
  uint32_t pad2 : 1;            // [15]
  uint32_t sh_max : 3;          // [18:16]
  uint32_t active_ne : 3;       // [21:19]
  uint32_t trace_en : 1;        // [22]
  uint32_t l2_barrier : 1;      // [23]
  uint32_t relu_type : 3;       // [26:24]
  uint32_t wino1d : 1;          // [27]
  uint32_t out_trans : 1;       // [28]
  uint32_t fill_lower_ne : 1;   // [29]
  uint32_t pad4 : 2;            // [31:30]
} maccfg;
```

## `hwx_parsing.py`'s manual bit-shift extraction (3 occurrences)

`print_common_h16`'s H18 (`instr_ver >= 20`), H17 (`instr_ver >= 19`),
and H16-hybrid (`else`) branches all read this register the same way.
Tangled into all three occurrences.

<!-- tangle: hwx_dump/hwx_parsing.py#common_maccfg_h16_bits -->
```python
active_ne = (m >> 19) & 7
small_src = (m >> 2) & 3
task_type = (m >> 4) & 0xF
out_trans = (m >> 28) & 1
fill_lower = (m >> 29) & 1
wino1d = (m >> 27) & 1
trace_en = (m >> 22) & 1
relu_type = (m >> 24) & 0x7
```

## `docs/GUIDE_ANE_HWX_FORMAT.md` §6.1.C prose table

**Not tangled into `hwx_dump_js/hwx_parser.js`.** JS's equivalent block
(`parseStateRegisters`, `cpusubtype >= 7` branch) uses the same 8 raw
bit positions but different variable names and order (`activeNE`,
`taskTypeRaw`, `reluTypeCommon`, camelCase, non-matching order) —
forcing it into byte-identical text with Python would mean an
out-of-place rename for no functional benefit. It already carries a
prose cross-reference comment instead ("Bit layout confirmed identical
across H16/H17/H18/H19..."); if JS's decode is ever restructured to
match Python's variable order, revisit tangling it here too.

<!-- tangle: docs/GUIDE_ANE_HWX_FORMAT.md#common_maccfg_doc_table -->
```markdown
* **task_type** (`bits [7:4]`): Raw hardware task-type code, remapped through a fixed lookup table before use (see `get_task_type_mapping`/`get_hw_task_type_name` in `hwx_parsing.py`) — `0` after remapping means "None" (a plain conv/elementwise task, not a fused pooling/reduction task).
* **small_src** (`bits [3:2]`): Small-Source Mode selector (`ZinSmallSourceMode` in the compiler's own terms — see the Winograd guide's §4/§5 for the full enum and its interaction with Winograd/format eligibility).
* **active_ne** (`bits [21:19]`): Number of active Neural Engine cores for this task.
* **trace_en** (`bit [22]`): Debug tracing enable for this task.
* **relu_type** (`bits [26:24]`): Task-level ReLU-type selector (distinct from NE.MacCfg's `nl_mode_ne` above).
* **wino1d** (`bit [27]`, H17+ only — STUB/always-0 on H16 and earlier): **1D Winograd fast-convolution mode enable.** Set only for `(kernel, stride)` shapes `(3,1)`, `(5,2)`, `(6,2)`, and only for eligible weight/activation formats — see [GUIDE_ANE_WINOGRAD.md](GUIDE_ANE_WINOGRAD.md) for the complete, empirically-verified eligibility contract and real-world `.hwx` measurements.
* **out_trans** (`bit [28]`): Output transpose enable.
* **fill_lower_ne** (`bit [29]`): Fill-lower-NE-cores mode (used when a task's active-core count is less than the hardware maximum, to keep the unused cores' outputs deterministic).
```
