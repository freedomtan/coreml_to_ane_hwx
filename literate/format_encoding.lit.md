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

`hwx_parsing.m`'s switch and `hwx_dump_js/hwx_parser.js`'s switch are
structurally identical and both tangle from this block. `hwx_parsing.py`
is **not** tangled from this block yet: it conflates `ch_fmt` and
`kernel_fmt` decoding into a single `get_ch_fmt_name()` (see
`literate/README.md`'s "Findings" section for why that's a real,
separate gap this investigation surfaced rather than fixed).

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

## NE.KernelCfg (`get_kernel_fmt_name`) — `.m` only for now

Superset of the ChannelCfg table above (adds INT4/E2M1 for the 3-bit
H18+ field). `hwx_parsing.py` and `hwx_dump_js/hwx_parser.js` currently
only decode a 2-4 value subset of this (see Findings) so this block is
tangled into `.m` alone until those are unified.

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
