# Literate source: PE (Pooling Engine) `_v17` name tables

Third tangle pilot. These six `hwx_dump/hwx_parsing.m`/`.py` functions
decode the PE-block register fields (`PE.Cfg`'s pool mode, op mode,
condition, nonlinearity mode, and two source selectors) and already
match exactly between `.m` and `.py`.

**Not tangled into `hwx_dump_js/hwx_parser.js`.** JS has its own,
independent PE decode (`parseStateRegisters`'s `pe` section) with
different value labels for the same fields — e.g. its inline `opNames`
is `["Add", "Multiply", "Max", "Min", "Subtract", "SumSqr"]` (6 entries,
"Multiply"/"Subtract") where `.m`/`.py`'s `get_pe_op_mode_name_v17` is
`{0: Add, 1: Mul, 2: Max, 3: Min, 4: SumSqr}` (5 entries, "Mul", no
Subtract). This is a real, unresolved discrepancy between JS and
`.m`/`.py` for the PE op-mode field — flagged here rather than silently
tangled over, since tangling would require deciding which is correct
first (out of scope for this pass; see `literate/README.md`).

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

<!-- tangle: hwx_dump/hwx_parsing.m#get_pe_condition_name_v17 -->
```c
const char *get_pe_condition_name_v17(uint32_t cond) {
  static const char *labels[] = {"None",    "Abs",          "Equal",
                                 "Greater", "GreaterEqual", "LessEqual",
                                 "Less",    "NotEqual"};
  return (cond < 8) ? labels[cond] : "Unknown";
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_pe_condition_name_v17 -->
```python
def get_pe_condition_name_v17(cond):
    labels = ["None", "Abs", "Equal", "Greater", "GreaterEqual", "LessEqual", "Less", "NotEqual"]
    return labels[cond] if cond < len(labels) else "Unknown"
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
