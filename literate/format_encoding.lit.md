# Literate source: ChannelCfg / KernelCfg format-value tables

This is a pilot literate-programming source for `literate/tangle.py`
(see `literate/README.md` for the design writeup). It exists because
the exact fact below was hand-copied into four places this session
and drifted in three of them at once:

- `hwx_dump/hwx_parsing.m` (`get_ch_fmt_name`, `get_kernel_fmt_name`)
- `hwx_dump/hwx_parsing.py` (`get_ch_fmt_name`)
- `hwx_dump_js/hwx_parser.js` (`getChFmtName`)
- `docs/GUIDE_ANE_HWX_FORMAT.md` (Data Format Encoding table)

Confirmed (H16+) via `GetHWKernelFormat`/`GetHWChannelFormat` decompiles,
`ZinKernelFormatGetName`/`ZinTensorFormatToString` string-table decodes,
and real `.hwx` + MIL cross-checks (full evidence trail in
[`GUIDE_ANE_WINOGRAD.md` §7](../docs/GUIDE_ANE_WINOGRAD.md)):

| raw | name    |
|-----|---------|
| 0   | UINT8   |
| 1   | INT8    |
| 2   | FLOAT16 |
| 3   | E4M3 (KernelCfg only, H18+) |
| 4   | INT4 (KernelCfg only) / E4M3 (ChannelCfg, legacy 2-bit alias) |
| 5   | E2M1 (KernelCfg only) |

`ch_fmt` (ChannelCfg, activation dtype) and `kernel_fmt` (NE.KernelCfg,
weight dtype) share raw values 0-2, but only `kernel_fmt` widened to
a 3-bit field using values 3-5; `ch_fmt` still reuses value 4 as its
own separate "E4M3" alias in a 2-bit-adjacent encoding (see the doc
table below and the Winograd guide for why these aren't the same
field despite overlapping raw values).

## ChannelCfg (`get_ch_fmt_name`) — shared by .m, .py, .js

`hwx_parsing.py`'s `get_ch_fmt_name()` used to be overloaded to also
decode `kernel_fmt` (see `literate/README.md`'s "Findings" — fixed by
splitting it into this function plus a separate `get_kernel_fmt_name`).
All three now match `.m`'s switch exactly and tangle from this block.

<!-- tangle: hwx_dump/hwx_parsing.m#get_ch_fmt_name -->
```c
const char *get_ch_fmt_name(uint32_t fmt) {
  switch (fmt) {
  case 0:
    return "uint8";
  case 1:
    return "int8";
  case 2:
    return "float16";
  case 4:
    return "e4m3";
  default:
    return "Unknown";
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_ch_fmt_name -->
```python
def get_ch_fmt_name(fmt_val):
    if fmt_val == 0: return "UINT8"
    if fmt_val == 1: return "INT8"
    if fmt_val == 2: return "FLOAT16"
    if fmt_val == 4: return "E4M3"
    return f"Unknown({fmt_val})"
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_ch_fmt_name -->
```js
function getChFmtName(fmt) {
  switch (fmt) {
    case 0: return "UINT8";
    case 1: return "INT8";
    case 2: return "FLOAT16";
    case 4: return "E4M3";
    default: return "Unknown(" + fmt + ")";
  }
}
```

## NE.KernelCfg (`get_kernel_fmt_name`) — `.m`, `.py`, `.js`

Superset of the ChannelCfg table above (adds INT4/E2M1). `kernel_fmt`
is currently a 2-bit field on every real H16-H19 capture (see
`ane_hwx_regs.h`'s `kernel_fmt:2`), so INT4(4)/E2M1(5) are unreachable
today in practice — they're tangled anyway so all three parsers agree
the instant a wider field shows up in a real capture, rather than only
`.m` knowing about them.

<!-- tangle: hwx_dump/hwx_parsing.m#get_kernel_fmt_name -->
```c
const char *get_kernel_fmt_name(uint32_t fmt) {
  switch (fmt) {
  case 0:
    return "uint8";
  case 1:
    return "int8";
  case 2:
    return "fp16";
  case 3:
    return "e4m3";
  case 4:
    return "int4";
  case 5:
    return "e2m1";
  default:
    return "Unknown";
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_kernel_fmt_name -->
```python
def get_kernel_fmt_name(fmt_val):
    if fmt_val == 0: return "UINT8"
    if fmt_val == 1: return "INT8"
    if fmt_val == 2: return "FLOAT16"
    if fmt_val == 3: return "E4M3"
    if fmt_val == 4: return "INT4"
    if fmt_val == 5: return "E2M1"
    return f"Unknown({fmt_val})"
```

<!-- tangle: hwx_dump_js/hwx_parser.js#kfmt_names_js -->
```js
const kfmtNames = ["UINT8", "INT8", "FLOAT16", "E4M3", "INT4", "E2M1"];
```

## Doc table (H16+ confirmed raw mapping)

Same fact, rendered as the bullet list `docs/GUIDE_ANE_HWX_FORMAT.md`
uses in its "Data Format Encoding" section.

<!-- tangle: docs/GUIDE_ANE_HWX_FORMAT.md#ch_fmt_doc_table -->
```markdown
  * `0x0` (0): UINT8 - 8-bit unsigned integer
  * `0x1` (1): INT8 - 8-bit signed integer (quantized)
  * `0x2` (2): FLOAT16 - 16-bit IEEE 754 half-precision float
  * `0x3` (3): E4M3 (fp8) - H18+ only (3-bit field)
  * `0x4` (4): INT4 - newest known future ISA version only
  * `0x5` (5): E2M1 - newest known future ISA version only
```
