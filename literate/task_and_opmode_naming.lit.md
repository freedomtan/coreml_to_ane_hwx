# Literate source: NE.MacCfg Op naming + Common.MacCfg TaskType mapping/naming

Second tangle pilot, covering the NE-block name tables that were
already identical across `hwx_dump/hwx_parsing.m` and `.py` (and, for
`task_type_mapped_dict`/`hwTaskTypeNames`, `hwx_dump_js/hwx_parser.js`
too) at the time this file was written — moved under tangle control
so that stays true, rather than because a drift was found.

## `get_ne_op_mode_name` — NE.MacCfg `Op` field (bits [2:0])

Shared by `.m`/`.py` exactly. `hwx_dump_js/hwx_parser.js`'s `neOpNames`
carries this same 0-5 subset plus two JS-only legacy entries (`7`/`0xF`,
for the older cpusubtype<7 op-mode encoding, which isn't a field
`.m`/`.py` name at all) — only the shared 0-5 subset is tangled into it.

<!-- tangle: hwx_dump/hwx_parsing.m#get_ne_op_mode_name -->
```c
const char *get_ne_op_mode_name(uint32_t mode) {
  switch (mode) {
  case 0:
    return "Conv";
  case 1:
    return "ElemWise";
  case 2:
    return "RCAS";
  case 3:
    return "EWSqrt";
  case 4:
    return "Bypass";
  case 5:
    return "TransposedConv";
  default:
    return "Unknown";
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_ne_op_mode_name -->
```python
def get_ne_op_mode_name(mode):
    return {
        0: "Conv",
        1: "ElemWise",
        2: "RCAS",
        3: "EWSqrt",
        4: "Bypass",
        5: "TransposedConv",
    }.get(mode, "Unknown")
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_ne_op_mode_name -->
```js
0: "Conv",
1: "ElemWise",
2: "RCAS",
3: "EWSqrt",
4: "Bypass",
5: "TransposedConv",
```

## `get_task_type_mapping` — cpusubtype-dependent TaskType raw-value remap

Shared verbatim by `.m`, `.py`, and `.js`'s `task_type_mapped_dict`.

<!-- tangle: hwx_dump/hwx_parsing.m#get_task_type_mapping -->
```c
uint32_t get_task_type_mapping(uint32_t subtype) {
  switch (subtype) {
  case 0:
    return 0;
  case 1:
    return 2;
  case 2:
    return 6;
  case 3:
    return 5;
  case 4:
    return 7;
  case 5:
    return 4;
  case 6:
    return 3;
  case 7:
    return 0;
  case 8:
    return 1;
  default:
    return 0;
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_task_type_mapping -->
```python
def get_task_type_mapping(subtype):
    return {0: 0, 1: 2, 2: 6, 3: 5, 4: 7, 5: 4, 6: 3, 7: 0, 8: 1}.get(subtype, 0)
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_task_type_mapping -->
```js
const task_type_mapped_dict = {0: 0, 1: 2, 2: 6, 3: 5, 4: 7, 5: 4, 6: 3, 7: 0, 8: 1};
```

## `get_hw_task_type_name` — mapped TaskType (1-7) display name

Shared by `.m`/`.py` exactly (both treat `0`/unmapped via a separate
`"((None))"`/`"Unknown"` path, not a case in this table).
`hwx_dump_js/hwx_parser.js`'s `hwTaskTypeNames` folds a JS-only
`0: "None"` entry into the same object for convenience — that entry
sits outside the tangled region since it's not part of the shared
1-7 table.

<!-- tangle: hwx_dump/hwx_parsing.m#get_hw_task_type_name -->
```c
const char *get_hw_task_type_name(uint32_t type) {
  switch (type) {
  case 1:
    return "Pooling w/o input ReLU";
  case 2:
    return "Pooling w/ input ReLU";
  case 3:
    return "EW w/ Reduction w/o ReLU";
  case 4:
    return "EW w/ Reduction w/ ReLU";
  case 5:
    return "EW w/o Reduction w/o ReLU";
  case 6:
    return "EW w/o Reduction w/ ReLU";
  case 7:
    return "GOC";
  default:
    return "Unknown";
  }
}
```

<!-- tangle: hwx_dump/hwx_parsing.py#get_hw_task_type_name -->
```python
def get_hw_task_type_name(type_val):
    return {
        1: "Pooling w/o input ReLU",
        2: "Pooling w/ input ReLU",
        3: "EW w/ Reduction w/o ReLU",
        4: "EW w/ Reduction w/ ReLU",
        5: "EW w/o Reduction w/o ReLU",
        6: "EW w/o Reduction w/ ReLU",
        7: "GOC",
    }.get(type_val, "Unknown")
```

<!-- tangle: hwx_dump_js/hwx_parser.js#get_hw_task_type_name -->
```js
1: "Pooling w/o input ReLU",
2: "Pooling w/ input ReLU",
3: "EW w/ Reduction w/o ReLU",
4: "EW w/ Reduction w/ ReLU",
5: "EW w/o Reduction w/o ReLU",
6: "EW w/o Reduction w/ ReLU",
7: "GOC"
```
