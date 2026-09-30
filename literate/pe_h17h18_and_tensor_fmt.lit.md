# Literate source: H17/H18 PE op-name table, and `get_hw_tensor_format_name_v17`

Two more facts duplicated across `hwx_dump/hwx_parsing.m` and
`hwx_dump/hwx_parsing.py` (found while surveying for further tangle
candidates after wiring `literate/tangle.py check` into CI — see
`literate/README.md`). Neither is present in `hwx_dump_js/hwx_parser.js`,
which has no H17/H18 PE decode and no tensor-format-mode decode.

## H17/H18 Planar Engine op-name table

Distinct from the already-tangled `_v17` PE op table in
`literate/pe_naming.lit.md` — that's a different register generation with
a different name set (`Min`/`Max` in the opposite order, plus `SumSqr`,
no bare `Op=N(name)` inline print). This table backs `print_pe_h17` and
`print_pe_h18`'s `PE Config` line and is duplicated 4 times: twice in
`.m` (once per function) and twice in `.py` (ditto). All 4 occurrences
were already byte-for-byte identical before tangling.

<!-- tangle: hwx_dump/hwx_parsing.m#pe_h17h18_op_names -->
```c
static const char *pe_op_names[] = {"None", "Add", "Mul", "Min",
                                    "Max",  "5?",  "6?",  "7?"};
```

<!-- tangle: hwx_dump/hwx_parsing.py#pe_h17h18_op_names -->
```python
pe_op_names = ["None", "Add", "Mul", "Min", "Max", "5?", "6?", "7?"]
```

## `get_hw_tensor_format_name_v17`

A 9-branch `(mode, mem_fmt, trunc, shift)` cascade mapping to tensor
format names (FLOAT32/FLOAT16/INT8/UINT8/RAW12/Y12/INT16/Packed10/
RAW10/Y10). Complex enough to be a real drift risk if hand-copied again;
`.m` and `.py` currently agree exactly.

<!-- tangle: hwx_dump/hwx_parsing.m#get_hw_tensor_format_name_v17 -->
```c
const char *get_hw_tensor_format_name_v17(uint32_t mode, uint32_t mem_fmt,
                                          uint32_t trunc, uint32_t shift) {
  if (mode == 3 && mem_fmt == 3 && shift == 1)
    return "FLOAT32";
  if (mode == 1 && mem_fmt == 2 && trunc == 3)
    return "FLOAT16";
  if (mode == 0 && mem_fmt == 1)
    return "INT8";
  if (mode == 0 && mem_fmt == 0 && shift == 0 && trunc == 0)
    return "UINT8";
  if (mode == 1 && mem_fmt == 2 && trunc == 1 && shift == 0)
    return "RAW12";
  if (mode == 1 && mem_fmt == 0 && trunc == 1 && shift == 1)
    return "Y12";
  if (mode == 2 && mem_fmt == 3)
    return "INT16";
  if (mode == 2 && mem_fmt == 0 && shift == 1)
    return "Packed10 (Deprecated?)";
  if (mode == 1 && trunc == 3 && shift == 1) {
    if (mem_fmt == 0)
      return "RAW10";
    if (mem_fmt == 1)
      return "Y10";
    if (mem_fmt == 2)
      return "RAW10/Y10 (Shared)";
  }
  return "UNKNOWN";
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_hw_tensor_format_name_v17 -->
```python
def get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift):
    if mode == 3 and mem_fmt == 3 and shift == 1:
        return "FLOAT32"
    if mode == 1 and mem_fmt == 2 and trunc == 3:
        return "FLOAT16"
    if mode == 0 and mem_fmt == 1:
        return "INT8"
    if mode == 0 and mem_fmt == 0 and shift == 0 and trunc == 0:
        return "UINT8"
    if mode == 1 and mem_fmt == 2 and trunc == 1 and shift == 0:
        return "RAW12"
    if mode == 1 and mem_fmt == 0 and trunc == 1 and shift == 1:
        return "Y12"
    if mode == 2 and mem_fmt == 3:
        return "INT16"
    if mode == 2 and mem_fmt == 0 and shift == 1:
        return "Packed10 (Deprecated?)"
    if mode == 1 and trunc == 3 and shift == 1:
        if mem_fmt == 0: return "RAW10"
        if mem_fmt == 1: return "Y10"
        if mem_fmt == 2: return "RAW10/Y10 (Shared)"
    return "UNKNOWN"
```
