# HWX Parsing Guide

This document describes the structure of Apple Neural Engine (ANE) hardware executable files (`.hwx`) and the protocol for parsing task descriptors (TDs) across different architectures (M1-M4).

## 1. File Container: Mach-O HWX

The `.hwx` file is a customized Mach-O binary.

- **Magic Number**: `0xbeefface` (HWX_MAGIC).
- **Architecture Detection**: 
    - **Instruction Set Version $\le 7$**: Uses `ZinAneSequentialCommand_v7minus` (Stream Payload).
    - **Instruction Set Version $\ge 11$**: Uses `ZinAneSequentialCommand_v11` and `ZinAneMaskCommand_v11` (Dense Instruction Payload).

### SoC Architecture Reference Table

| Platform (SoCs) | ANE CPU Subtype | ANE Instruction Set Version |
| :--- | :--- | :--- |
| H11 (A12) | 1 | 5 |
| H12 (A13) | 3 | 6 |
| H13/H13g (A14/M1) | 4 | 7 |
| H14/H14c/H14g (A15/M2) | 5 | 11 |
| H15/H15c/H15g (A16/M3) | 6 | 8 |
| H16/H16c/H16g/H16s (A17 Pro/M4) | 7 | 17 |
| H17/H17a/H17g (A18 Pro/M5) | 9 | 19 |
| H18 (A19/A19 Pro) | 10 | 20 |

> [!NOTE]
> The **Instruction Set Version** $n$ corresponds directly to the template parameter in the **`ZinAneTd<n u>`** class within the ANECompiler binary. For example, M1 (subtype 4) uses version 7, processed by `ZinAneTd<7u>`.

- **Location of Tasks**: ANE tasks are stored in the `__TEXT` segment, `__text` section.

## 2. M1 Architecture (v7)

M1 uses a **Linked-List** task structure with a **Stream Payload** for register configuration.

### Header: `ane_td_header_h13_t` (0x28 bytes)
```c
typedef struct {
  uint16_t tid;             // 0x000
  uint8_t nid;              // 0x002
  uint8_t lnid_eon;         // 0x003: LNID (bit 0), EON (bit 1)
  uint16_t exe_cycles;      // 0x004
  uint16_t next_size_pad;   // 0x006: NextSize (9 bits)
  uint32_t log_events : 24; // 0x008
  uint32_t exceptions : 24; // 0x00c
  uint32_t debug_log_events:24; // 0x010
  uint32_t debug_exceptions:24; // 0x014
  uint32_t flags;           // 0x018
  uint32_t next_pointer;    // 0x01c
  uint32_t pad[2];          // 0x20-0x28
} ane_td_header_h13_t;
```

### Payload: Stream Parse
Immediately following the header (at offset `0x28`) is the register stream. Each command block consists of a 32-bit header followed by a variable number of data words.

- **Header Word**:
    - `bits [25:0]`: Word Address (Hardware address >> 2).
    - `bits [31:26]`: Count (Number of 32-bit values following - 1).
- **Data Words**:
    - The next `count + 1` words are written sequentially starting at the target word address.

## 3. M4 Architecture (v11+)

M4 uses an **Aligned Array** task structure with a **Dense Instruction** format (Burst/Scatter).

### Header: `ane_td_header_h16_t` (0x24 bytes)
```c
typedef struct {
  uint16_t tid;             // 0x000
  uint32_t task_size : 11;  // 0x002
  uint16_t exe_cycles;      // 0x004
  uint32_t log_events : 24; // 0x008
  uint32_t exceptions : 24; // 0x00c
  uint32_t debug_log_events:24; // 0x010
  uint32_t debug_exceptions:24; // 0x014
  uint32_t live_outs;       // 0x018
  uint32_t tsr_tde_ene;     // 0x01c
  uint16_t tdid;            // 0x020
  uint16_t pad;             // 0x022
} ane_td_header_h16_t;
```
Tasks are 16-byte aligned. If `task_size` is 0, the parser skips to the next alignment boundary.

### Payload: Dense Instruction Format
The payload consists of command headers that specify sequential (Burst) or masked (Scatter) register writes.

**Mode A: Sequential / Burst (Bit 31 = 0)**
- `bits [14:0]`: Base word address.
- `bits [20:15]`: Count (burst length).
- `bits [30:21]`: Reserved.
- **Action**: Read `count + 1` data words and write them to `address ... address + count`.

**Mode B: Masked / Scatter (Bit 31 = 1)**
- `bits [14:0]`: Base word address.
- `bits [30:15]`: 16-bit population mask.
- **Action**:
    1. The first word following the header is ALWAYS written to `base_address`.
    2. For each bit $i$ set in the mask (0-15), the next word in the stream is written to `base_address + i + 1`.

## 4. Hardware Block Memory Map

Registers are grouped into functional blocks. Note the base address shift between architectures.

| Block Name | M1 Base (Byte) | M4 Base (Byte) | Description |
| :--- | :--- | :--- | :--- |
| **Common** | `0x00000` | `0x0000` | Tensor dims, strides, task types. |
| **L2** | `0x04800` | `0x4100` | L2 Cache and buffer management. |
| **PE** | `0x08800` | `0x4500` | Planar Engine (Pooling, Activation). |
| **NE** | `0x0C800` | `0x4900` | Neural Engine (Convolutions, MACC). |
| **TileDMA Src** | `0x13800` | `0x4D00` | Tiled memory input DMA. |
| **TileDMA Dst** | `0x17800` | `0x5100` | Tiled memory output DMA. |
| **KernelDMA** | `0x1F800` | `0x5500` | Weight and bias loading. |
| **CacheDMA** | N/A | `0x5900` | Telemetry and cache management (M4+). |

## 5. Parsing Workflow

1.  **Open HWX**: Read Mach-O header and verify `0xbeefface`.
2.  **Identify Architecture**: Check `cpusubtype` to choose parsing logic.
3.  **Locate Section**: Find the `__text` section offset and size.
4.  **Iterate Tasks**:
    -   **M1**: Follow `next_pointer` until it is 0.
    -   **M4**: Read `task_size`, parse payload, and jump to the next 16-byte boundary.
5.  **Reconstruct Register State**: For each task, process the payload instructions to populate a 512KB virtual register array (`reg_values[0x20000]`).
6.  **Interpret State**: Map the register array to hardware block structs (e.g., `ane_m1_pe_t`) based on the base addresses above.
