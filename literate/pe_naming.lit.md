# Literate source: PE (Pooling Engine) `_v17` name tables

Third tangle pilot. These six `hwx_dump/hwx_parsing.m`/`.py` functions
decode the PE-block register fields (`PE.Cfg`'s pool mode, op mode,
condition, nonlinearity mode, and two source selectors) and already
match exactly between `.m` and `.py`.

**`pool`/`cond`/`nl` tangled into `hwx_dump_js/hwx_parser.js` too**
(`parseStateRegisters`'s `pe` section, `poolNames`/`condNames`/`nlNames`)
— these already matched `.m`/`.py` exactly.

**`op` was a real bug, now fixed.** JS's inline `opNames` was
`["Add", "Multiply", "Max", "Min", "Subtract", "SumSqr"]` (6 entries) —
which turns out to be *H13's* PE op-mode table (`parseH13Task`'s own
`peOpNames`, decoding a completely different register at
`H13_PE_BLOCK`), apparently copy-pasted into this H14+/instruction-stream
path by mistake. `.m`, `.py`, and this doc's own general PE_Config
section (`docs/GUIDE_ANE_HWX_FORMAT.md`, "op" bits `[4:2]`) all agree on
`{0: Add, 1: Mul, 2: Max, 3: Min, 4: SumSqr}` (5 entries) for this field
specifically — 3-way documentary convergence against JS's lone,
suspiciously-H13-shaped outlier. No real `.hwx` sample in this repo
exercises op=1 or op=4 to empirically confirm the way the int8/uint8 fix
was confirmed (see `GUIDE_ANE_WINOGRAD.md` §7) — flagged here rather
than treated as certain.

**`cond` was also a real bug, found and fixed via direct ANECompiler
binary disassembly** (full writeup:
`docs/INVESTIGATION_PE_CONDITION_ENCODING.md`), not just cross-file
comparison — all three parsers had agreed with each other, but all three
were wrong relative to the hardware. `ZinAneTd<N>::SetPECondition`'s
disassembly proves the raw register bits are a non-identity permutation
of the `ZinHWPECondition` enum (not a direct index), and a cross-reference
through `ZinConditionLayerUtils`'s `PredicateOp` enum (whose names are
ground truth from literal debug strings in `DumpTDBranchingInfo`) gives a
corrected, complete bijection: `0:None 1:Less 2:Greater 3:NotEqual
4:Equal 5:LessEqual 6:GreaterEqual 7:Abs`. Confidence is highest for `3`
and `4` (an unconditional cross-reference anchor), high for the rest,
medium for `7` (`Abs`, by elimination only) — see the investigation doc
for the full chain. The function was dead code (defined, never called)
before this fix; `cond` is now resolved to a name in the actual
`PE Config` printf/print statements in all three parsers.

Still **not tangled**: JS's PE decode has no `src1`/`src2` fields at all
(a missing-feature gap, not a naming mismatch) — see `literate/README.md`.

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_op_mode_name_v17 -->
```c
const char *get_pe_op_mode_name_v17(uint32_t op) {
  switch (op) {
  case 0:
    return "Add";
  case 1:
    return "Mul";
  case 2:
    return "Max";
  case 3:
    return "Min";
  case 4:
    return "SumSqr";
  default:
    return "Unknown";
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_op_mode_name_v17 -->
```python
def get_pe_op_mode_name_v17(op):
    return {0: "Add", 1: "Mul", 2: "Max", 3: "Min", 4: "SumSqr"}.get(op, "Unknown")
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_pe_op_mode_name_v17 -->
```js
const opNames = ["Add", "Mul", "Max", "Min", "SumSqr"];
```

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_pool_mode_name_v17 -->
```c
const char *get_pe_pool_mode_name_v17(uint32_t mode) {
  switch (mode) {
  case 0:
    return "None";
  case 1:
    return "Avg";
  case 2:
    return "Max";
  case 3:
    return "Min";
  default:
    return "Unknown";
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_pool_mode_name_v17 -->
```python
def get_pe_pool_mode_name_v17(mode):
    return {0: "None", 1: "Avg", 2: "Max", 3: "Min"}.get(mode, "Unknown")
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_pe_pool_mode_name_v17 -->
```js
const poolNames = ["None", "Avg", "Max", "Min"];
```

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_condition_name_v17 -->
```c
const char *get_pe_condition_name_v17(uint32_t cond) {
  static const char *labels[] = {"None",     "Less",     "Greater", "NotEqual",
                                 "Equal", "LessEqual", "GreaterEqual", "Abs"};
  return (cond < 8) ? labels[cond] : "Unknown";
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_condition_name_v17 -->
```python
def get_pe_condition_name_v17(cond):
    labels = ["None", "Less", "Greater", "NotEqual", "Equal", "LessEqual", "GreaterEqual", "Abs"]
    return labels[cond] if cond < len(labels) else "Unknown"
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_pe_condition_name_v17 -->
```js
const condNames = ["None", "Less", "Greater", "NotEqual", "Equal", "LessEqual", "GreaterEqual", "Abs"];
```

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_nl_mode_name_v17 -->
```c
const char *get_pe_nl_mode_name_v17(uint32_t mode) {
  static const char *labels[] = {"None", "ReLU", "Clamp", "Abs"};
  return (mode < 4) ? labels[mode] : "Unknown";
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_nl_mode_name_v17 -->
```python
def get_pe_nl_mode_name_v17(mode):
    labels = ["None", "ReLU", "Clamp", "Abs"]
    return labels[mode] if mode < len(labels) else "Unknown"
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_pe_nl_mode_name_v17 -->
```js
const nlNames = ["None", "ReLU", "Clamp", "Abs"];
```

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_src1_name_v17 -->
```c
const char *get_pe_src1_name_v17(uint32_t sel) {
  return (sel == 0)   ? "PrimarySource"
         : (sel == 1) ? "TextureSource"
                      : "Unknown";
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_src1_name_v17 -->
```python
def get_pe_src1_name_v17(sel):
    return "PrimarySource" if sel == 0 else "TextureSource" if sel == 1 else "Unknown"
```

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_src2_name_v17 -->
```c
const char *get_pe_src2_name_v17(uint32_t sel) {
  static const char *labels[] = {"PrimarySource", "TextureSource", "L2Source",
                                 "RegSource"};
  return (sel < 4) ? labels[sel] : "Unknown";
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_src2_name_v17 -->
```python
def get_pe_src2_name_v17(sel):
    labels = ["PrimarySource", "TextureSource", "L2Source", "RegSource"]
    return labels[sel] if sel < len(labels) else "Unknown"
```
