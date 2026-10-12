# Literate source: Task Descriptor Header (H16+) & Hardware Event Logging

This document unifies the definition and decoding of the **H16+ Task Descriptor Header (40 bytes / 10 words)** across all parsers (`ane_hwx_regs.h`, `hwx_parsing.m`, `hwx_parsing.py`, `hwx_dump_js/hwx_parser.js`) and documentation (`docs/GUIDE_ANE_HWX_FORMAT.md`).

## Background & Telemetry Architecture

Every task descriptor in an ANE Mach-O `.hwx` binary begins with a fixed header parsed by the hardware sequencer and `AppleH16ANEInterface.kext` / `AppleH17ANE.kext`.

On H16+ (Apple M4, A18 Pro, and newer architectures), the header occupies **40 bytes (10 32-bit words)**:

1. **`Header[0]` (0x000)**: `tid` (16b), `task_size` (11b), `pad0` (5b)
2. **`Header[1]` (0x004)**: `exe_cycles` (16b), `pad1` (16b)
3. **`Header[2]` (0x008)**: `log_events` (24b) — standard hardware sequencer event logging mask
4. **`Header[3]` (0x00c)**: `exceptions` (24b) — hardware exceptions reporting mask
5. **`Header[4]` (0x010)**: `debug_log_events` (24b) — debug event logging mask (`|= 0x7E` stamped by `_ANEMachoPatcher`)
6. **`Header[5]` (0x014)**: `debug_exceptions` (24b) — debug exceptions reporting mask
7. **`Header[6]` (0x018)**: `dram_log_events` (24b) — dynamic DRAM event ring buffer flush mask (previously misidentified as `live_outs`)
8. **`Header[7]` (0x01c)**: `unknown_flags` (32b) — reserved hardware control flags
9. **`Header[8]` (0x020)**: `ctrl_flags` (32b) — execution control (`tsr:1`, `tde:1`, `ene:3` at bits 16-18)
10. **`Header[9]` (0x024)**: `dtid` (16b), `pad8` (16b) — Dependent Task ID barrier synchronization

Full disassembly derivations from `ANECompiler` and `/usr/libexec/aned` are detailed in `docs/INVESTIGATION_TD_HEADER_EVENT_LOGGING.md`.

---

## 1. C Struct Definition (`ane_hwx_regs.h`)

<!-- tangle: hwx_dump/ane_hwx_regs.h#ane_header_h16 -->
```c
typedef struct __attribute__((packed)) {
  uint16_t tid;             // 0x000 (Header[0] 0-15)
  uint32_t task_size : 11;  // 0x002 bits 0-10 (Header[0] 16-26)
  uint32_t pad0 : 5;        // 0x002 bits 11-15 (Header[0] 27-31)
  uint16_t exe_cycles;      // 0x004 (Header[1] 0-15)
  uint16_t pad1;            // 0x006 (Header[1] 16-31)
  uint32_t log_events : 24; // 0x008 (Header[2])
  uint32_t pad2 : 8;
  uint32_t exceptions : 24; // 0x00c (Header[3])
  uint32_t pad3 : 8;
  uint32_t debug_log_events : 24;  // 0x010 (Header[4])
  uint32_t pad4 : 8;
  uint32_t debug_exceptions : 24;  // 0x014 (Header[5])
  uint32_t pad5 : 8;
  uint32_t dram_log_events : 24;   // 0x018 (Header[6] 0-23, hw.td_header6.dram_log_events)
  uint32_t pad_lo : 8;
  uint32_t unknown_flags;  // 0x01c (Header[7])
  struct {
    uint32_t tsr : 1;      // 0x020 bit 0
    uint32_t tde : 1;      // 0x020 bit 1
    uint32_t pad : 1;      // 0x020 bit 2
    uint32_t unknown : 1;  // 0x020 bit 3
    uint32_t pad0 : 12;    // 0x020 bits 4-15
    uint32_t ene : 3;      // 0x020 bits 16-18
    uint32_t pad1 : 13;    // 0x020 bits 19-31
  } ctrl_flags;            // 0x020 (Header[8])
  uint16_t dtid;           // 0x024 (Header[9] 0-15)
  uint16_t pad8;           // 0x026 (Header[9] 16-31)
} ane_header_h16_t;
```

---

## 2. Documentation C Representation (`GUIDE_ANE_HWX_FORMAT.md`)

<!-- tangle: docs/GUIDE_ANE_HWX_FORMAT.md#ane_header_h16_doc -->
```c
typedef struct __attribute__((packed)) {
    uint16_t tid;             // Task ID (0x000 Header[0] 0-15)
    uint32_t task_size : 11;  // Total size of task in 32-bit words (0x002 bits 0-10)
    uint32_t pad0 : 5;        // Alignment padding (0x002 bits 11-15)
    uint16_t exe_cycles;      // Expected execution cycles (0x004 Header[1] 0-15)
    uint16_t pad1;            // Alignment padding (0x006 Header[1] 16-31)
    uint32_t log_events : 24; // Hardware sequencer logging events (0x008 Header[2])
    uint32_t pad2 : 8;
    uint32_t exceptions : 24; // Exceptions mask (0x00c Header[3])
    uint32_t pad3 : 8;
    uint32_t debug_log_events : 24;  // Debug logging events mask (0x010 Header[4])
    uint32_t pad4 : 8;
    uint32_t debug_exceptions : 24;  // Debug exceptions mask (0x014 Header[5])
    uint32_t pad5 : 8;
    uint32_t dram_log_events : 24;   // DRAM event ring buffer mask (0x018 Header[6])
    uint32_t pad_lo : 8;
    uint32_t unknown_flags;   // Reserved hardware flags (0x01c Header[7])
    struct {
        uint32_t tsr : 1;      // Task Status Register Enable (0x020 bit 0)
        uint32_t tde : 1;      // Task Debug Enable (0x020 bit 1)
        uint32_t pad : 1;      // 0x020 bit 2
        uint32_t unknown : 1;  // 0x020 bit 3
        uint32_t pad0 : 12;    // 0x020 bits 4-15
        uint32_t ene : 3;      // Execution Node Enables (0x020 bits 16-18)
        uint32_t pad1 : 13;    // 0x020 bits 19-31
    } ctrl_flags;             // 0x020 Header[8]
    uint16_t dtid;            // Dependent Task ID (0x024 Header[9] 0-15)
    uint16_t pad8;            // Alignment padding (0x026 Header[9] 16-31)
} ane_header_h16_t;
```

---

## 3. Python Unpack Block (`hwx_dump/hwx_parsing.py`)

<!-- tangle: hwx_dump/hwx_parsing.py#td_header_h16_unpack -->
```python
tid = h[0]
# h[1] is task_size and pad0.
task_size = h[1] & 0x7FF
exe_cycles = h[2]
log_events = h[4] & 0xFFFFFF
exceptions = h[5] & 0xFFFFFF
debug_log_events = h[6] & 0xFFFFFF
dram_log_events = h[8] & 0xFFFFFF
ctrl_flags = h[10]
tsr = ctrl_flags & 1
tde = (ctrl_flags >> 1) & 1
ene = (ctrl_flags >> 16) & 7
dtid = h[11]
```

---

## 4. Parser Print Statements

### Objective-C (`hwx_dump/hwx_parsing.m`)

<!-- tangle: hwx_dump/hwx_parsing.m#td_header_h16_print -->
```c
printf("        LogEvents: 0x%06x DebugLogEvents: 0x%06x DramLogEvents: 0x%06x Exceptions: 0x%06x\n",
       m4h->log_events, m4h->debug_log_events, m4h->dram_log_events, m4h->exceptions);
printf("        TSR: %d TDE: %d\n", m4h->ctrl_flags.tsr, m4h->ctrl_flags.tde);
```

### Python (`hwx_dump/hwx_parsing.py`)

<!-- tangle: hwx_dump/hwx_parsing.py#td_header_h16_print -->
```python
print(f"        LogEvents: 0x{log_events:06x} DebugLogEvents: 0x{debug_log_events:06x} DramLogEvents: 0x{dram_log_events:06x} Exceptions: 0x{exceptions:06x}")
print(f"        TSR: {tsr} TDE: {tde}")
```

---

## 5. JavaScript Parser (`hwx_dump_js/hwx_parser.js`)

<!-- tangle: hwx_dump_js/hwx_parser.js#td_header_h16_read -->
```js
const tid_and_size = view.getUint32(taskOffset + 0, true);
const exe_cycles_raw = view.getUint32(taskOffset + 4, true);
const log_events = view.getUint32(taskOffset + 8, true);
const exceptions = view.getUint32(taskOffset + 12, true);
const debug_log_events = view.getUint32(taskOffset + 16, true);
const debug_exceptions = view.getUint32(taskOffset + 20, true);
const dram_log_events = view.getUint32(taskOffset + 24, true);
const unknown_flags = view.getUint32(taskOffset + 28, true);
const ctrl_flags = view.getUint32(taskOffset + 32, true);
const dtid_raw = view.getUint32(taskOffset + 36, true);

const tid = tid_and_size & 0xFFFF;
const task_size = (tid_and_size >> 16) & 0x7FF;
const exe_cycles = exe_cycles_raw & 0xFFFF;
const tsr = ctrl_flags & 0x1;
const tde = (ctrl_flags >> 1) & 0x1;
const ene = (ctrl_flags >> 16) & 0x7;
const dtid = dtid_raw & 0xFFFF;
```
