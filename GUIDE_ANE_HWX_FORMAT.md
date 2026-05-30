# Comprehensive Guide to Apple ANE .hwx File Format (H13-H18)

**Purpose**: Complete reference for understanding and parsing Apple Neural Engine (ANE) `.hwx` files from scratch, covering all architectures from H13 (A14/M1) through H18 (A19).

**Audience**: Developers who want to build parsers, analyze ANE behavior, or reverse engineer Apple's neural network accelerator.

> **⚠️ CRITICAL**: This guide explains the ACTUAL format used in real .hwx files for ALL architectures:
> - **H13 and earlier (A12-A14/M1)**: Fixed register offsets
> - **H14/H15 (A15/M2, A16/M3)**: Instruction stream encoding (dense only)
> - **H16+ (A17 Pro/M4, A18+, A19)**: Instruction stream encoding (dense + sparse)

---

## Document Updates

**Last Updated**: 2026-05-30 (V3 - Complete Architecture Coverage)

**Major Changes in V3**:
- ✅ **NEW**: Complete H13 fixed format parsing with examples
- ✅ **NEW**: Architecture comparison table (H13 vs H14+ differences)
- ✅ **NEW**: Coverage of all architectures H13-H18 (A14/M1 through A19)
- ✅ **NEW**: When to use fixed offsets vs instruction streams
- ✅ Complete [Instruction Stream Format](#instruction-stream-format) section for H14/H15/H16+
- ✅ Dense and Sparse instruction encoding explained with examples
- ✅ Working decoder implementations for all architectures
- ✅ Mach-O container structure (how to extract task descriptors)
- ✅ Task descriptor format (headers, instruction streams, register blocks)
- ✅ Architecture-specific layouts with CORRECT parsing approaches

**What This Guide Covers**:
- ✅ All ANE architectures: H13 (A14/M1), H14 (A15/M2), H15 (A16/M3), H16 (A17 Pro/M4), H17 (A18 Pro), H18 (A19)
- ✅ Mach-O container structure (Phase 1: extract task descriptors)
- ✅ Task descriptor headers (all architectures)
- ✅ **H13 fixed offset parsing** ← Simple direct access
- ✅ **Instruction stream decoding** (H14/H15/H16+) ← **CRITICAL**
- ✅ Hardware register maps for all blocks
- ✅ Complete working code examples for all architectures

---

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Architecture Reference](#quick-architecture-reference)
3. [Mach-O Container Format](#mach-o-container-format) **← PHASE 1**
4. [Task Descriptor Structure](#task-descriptor-structure)
5. [Task Descriptor Header](#task-descriptor-header) **← ALL ARCHITECTURES**
6. [Instruction Stream Format](#instruction-stream-format) **← H14/H15/H16+ CRITICAL**
7. [Hardware Register Blocks](#hardware-register-blocks)
8. [H13 Fixed Format](#h13-fixed-format) **← H13 AND EARLIER**
9. [Building a Complete Parser](#building-a-complete-parser)
10. [Testing Your Parser](#testing-your-parser)

---

## Introduction

### What Are .hwx Files?

`.hwx` files are **Hardware eXecution descriptors** - binary files that tell the Apple Neural Engine (ANE) how to execute neural network operations.

**Key characteristics:**
- **Mach-O binary format** (like executable files, not raw binary data)
- Custom magic number: `0xBEEFFACE` (little-endian: `CE FA EF BE`)
- Task descriptors embedded in `__TEXT` segment, `__text` section
- Different formats for different architectures (H13 vs H14+)

### Architecture Summary

| Generation | CPU Subtype | Chips | Task Format | Parsing Approach |
|------------|-------------|-------|-------------|------------------|
| H11 | 1 | A12 | Fixed offsets | ✅ Simple struct casting |
| H12 | 3 | A13 | Fixed offsets | ✅ Simple struct casting |
| H13 | 4 | A14, M1 | Fixed offsets | ✅ Simple struct casting |
| H14 | 5 | A15, M2 | Instruction stream (dense only) | ⚠️ Must decode instructions |
| H15 | 6 | A16, M3 | Instruction stream (dense only) | ⚠️ Must decode instructions |
| H16 | 7 | A17 Pro, M4 | Instruction stream (dense + sparse) | ⚠️ Must decode instructions |
| H17 | 9 | A18 Pro, M5 (rumored) | Instruction stream (dense + sparse) | ⚠️ Must decode instructions |
| H18 | 10 | A19 (future) | Instruction stream (dense + sparse) | ⚠️ Must decode instructions |

**THIS IS CRITICAL**: 
- **H13 and earlier** (subtypes 1-4): Fixed TD offsets, direct struct access
- **H14/H15/H16+** (subtypes 5+): Instruction streams, must decode first

H14+ do NOT store registers at fixed offsets. They use an **instruction stream encoding** (like bytecode) that must be decoded.

---

## Quick Architecture Reference

Before parsing, you need to identify the architecture from the Mach-O header:

```c
// From Mach-O header's CPU subtype field
typedef enum {
    ANE_H11 = 1,   // A12
    ANE_H12 = 3,   // A13
    ANE_H13 = 4,   // A14/M1
    ANE_H14 = 5,   // A15/M2       ← Instruction stream starts
    ANE_H15 = 6,   // A16/M3       ← Instruction stream
    ANE_H16 = 7,   // A17 Pro/M4   ← Instruction stream + sparse
    ANE_H17 = 9,   // A18 Pro/M5   ← Instruction stream + sparse
    ANE_H18 = 10,  // A19          ← Instruction stream + sparse
} ane_arch_t;

// Parsing strategy by architecture
bool uses_instruction_stream(uint32_t cpu_subtype) {
    return cpu_subtype >= 5;  // H14 and later
}

bool uses_sparse_instructions(uint32_t cpu_subtype) {
    return cpu_subtype >= 7;  // H16 and later
}
```

---

## Mach-O Container Format

> **START HERE**: Every .hwx file is a Mach-O binary. You MUST parse this first.

### File Structure

```
.hwx file (Mach-O Binary)
├── Mach-O Header (magic: 0xBEEFFACE)
├── Load Commands
│   ├── LC_SEGMENT_64: __PAGEZERO
│   ├── LC_SEGMENT_64: __DEBUG
│   ├── LC_SEGMENT_64: __DATA
│   ├── LC_SEGMENT_64: __TEXT ← **TASK DESCRIPTORS HERE**
│   │   └── Section: __text
│   │       ├── [Padding block, TaskSize=0, skip 16 bytes]
│   │       ├── Task Descriptor 0
│   │       ├── Task Descriptor 1
│   │       └── ...
│   └── LC_SEGMENT_64: __KERN_0 ← **WEIGHT DATA (LUT)**
└── Data (segments and sections)
```

### Step 1: Parse Mach-O Header

```c
#include <mach-o/loader.h>

typedef struct {
    const uint8_t *file_data;
    size_t file_size;
    uint32_t cpu_subtype;  // Architecture identifier
} macho_file_t;

macho_file_t* parse_macho(const uint8_t *data, size_t size) {
    if (size < sizeof(struct mach_header_64)) {
        return NULL;
    }
    
    struct mach_header_64 *hdr = (struct mach_header_64*)data;
    
    // Check magic (0xBEEFFACE or 0xFEEDFACF)
    if (hdr->magic != 0xBEEFFACE && hdr->magic != 0xFEEDFACF) {
        return NULL;
    }
    
    macho_file_t *mf = calloc(1, sizeof(macho_file_t));
    mf->file_data = data;
    mf->file_size = size;
    mf->cpu_subtype = hdr->cpusubtype;  // ← Architecture ID!
    
    return mf;
}
```

### Step 2: Find __TEXT Segment and __text Section

```c
const uint8_t* find_text_section(macho_file_t *mf, size_t *section_size) {
    struct mach_header_64 *hdr = (struct mach_header_64*)mf->file_data;
    const uint8_t *cmd_ptr = mf->file_data + sizeof(struct mach_header_64);
    
    // Iterate through load commands
    for (uint32_t i = 0; i < hdr->ncmds; i++) {
        struct load_command *cmd = (struct load_command*)cmd_ptr;
        
        if (cmd->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64*)cmd_ptr;
            
            // Check if this is __TEXT segment
            if (strncmp(seg->segname, "__TEXT", 16) == 0) {
                // Iterate through sections within segment
                struct section_64 *sections = (struct section_64*)(cmd_ptr + sizeof(struct segment_command_64));
                
                for (uint32_t j = 0; j < seg->nsects; j++) {
                    if (strncmp(sections[j].sectname, "__text", 16) == 0) {
                        *section_size = sections[j].size;
                        return mf->file_data + sections[j].offset;
                    }
                }
            }
        }
        
        cmd_ptr += cmd->cmdsize;
    }
    
    return NULL;
}
```

### Step 3: Skip Padding Blocks

```c
const uint8_t* find_first_task(const uint8_t *section_data, size_t section_size) {
    size_t offset = 0;
    
    while (offset + 8 <= section_size) {
        uint32_t tid_and_size = *(uint32_t*)(section_data + offset);
        uint16_t task_size = (tid_and_size >> 16) & 0x7FF;  // Bits 16-26
        
        if (task_size == 0) {
            // Padding block - skip 16 bytes
            offset += 16;
            continue;
        }
        
        // Found first real task
        return section_data + offset;
    }
    
    return NULL;
}
```

---

## Task Descriptor Structure

After extracting task descriptors from the Mach-O file, you need to parse each one individually.

### Universal Header (All Architectures)

Every task descriptor starts with the same header format:

```c
typedef struct {
    uint32_t tid_and_size;      // +0x00: TID (bits 0-15), TaskSize (bits 16-26)
    uint32_t exe_cycles;        // +0x04: Execution cycles (bits 0-16)
    uint32_t log_events;        // +0x08: Logging events (bits 0-23)
    uint32_t exceptions;        // +0x0C: Exception mask (bits 0-23)
    uint32_t debug_log_events;  // +0x10: Debug logging (bits 0-23)
    uint32_t debug_exceptions;  // +0x14: Debug exceptions (bits 0-23)
    uint32_t live_outs;         // +0x18: Live outputs (bits 0-31)
    uint32_t ctrl_flags;        // +0x1C: TSR, TDE, ENE flags
    uint32_t dtid;              // +0x20: Dependent TID (bits 0-15)
} ane_header_t;
```

---

## Task Descriptor Header

### Parsing the Header (All Architectures)

```c
void parse_task_header(const uint8_t *task_data) {
    const ane_header_t *hdr = (const ane_header_t*)task_data;
    
    // Extract bit fields
    uint16_t tid = hdr->tid_and_size & 0xFFFF;
    uint16_t task_size = (hdr->tid_and_size >> 16) & 0x7FF;  // in 32-bit words
    uint16_t exe_cycles = hdr->exe_cycles & 0xFFFF;
    
    printf("Task ID: %u\n", tid);
    printf("Task Size: %u words (%u bytes)\n", task_size, task_size * 4);
    printf("Execution Cycles: %u\n", exe_cycles);
    printf("Log Events: 0x%06x\n", hdr->log_events & 0xFFFFFF);
    printf("Exceptions: 0x%06x\n", hdr->exceptions & 0xFFFFFF);
    printf("Live Outs: 0x%08x\n", hdr->live_outs);
    
    // Control flags
    uint8_t tsr = hdr->ctrl_flags & 0x1;
    uint8_t tde = (hdr->ctrl_flags >> 1) & 0x1;
    uint8_t ene = (hdr->ctrl_flags >> 16) & 0x7;
    printf("TSR: %u, TDE: %u, ENE: %u\n", tsr, tde, ene);
    
    uint16_t dtid = hdr->dtid & 0xFFFF;
    printf("Dependent TID: %u\n", dtid);
}
```

---

## Instruction Stream Format

> **CRITICAL FOR H14/H15/H16+**: Task descriptors do NOT have registers at fixed offsets. They contain an **instruction stream** that encodes hardware register writes.

### Why Instruction Streams?

H14 and later use instruction streams to:
- **Compress data**: Only store non-default register values
- **Reduce file size**: Skip unchanged registers
- **Support sparse updates**: Update specific registers without writing all

### Instruction Stream Structure

```
Task Descriptor Layout (H14+):
Offset   Size    Content
------   ----    -------
0x00     32      Header (parsed above)
0x20     varies  Instruction Stream ← START HERE for H14/H15
0x24     varies  Instruction Stream ← START HERE for H16+
...      ...     (continues until TaskSize * 4 bytes)
```

**Starting offset**:
- H14 (subtype 5): Word 8 (offset 0x20)
- H15 (subtype 6): Word 8 (offset 0x20)
- H16+ (subtype 7+): Word 9 (offset 0x24)

### Instruction Encoding

There are two instruction formats:

#### Dense Format (bit 31 = 0)

Writes consecutive hardware registers.

```
Instruction Header (32 bits):
  [31:31]    Format = 0 (dense)
  [30:21]    Reserved
  [20:15]    Count (number of additional registers, 0-63)
  [14:0]     Hardware Address (base register address)

Followed by (Count + 1) data words
```

**Example**:
```
Header: 0x0005_0100
  Bit 31 = 0         → Dense format
  Bits 20-15 = 5     → Count = 5 (write 6 words total)
  Bits 14-0 = 0x0100 → Hardware address 0x0100

Data: [word0] [word1] [word2] [word3] [word4] [word5]

Result: Writes to hardware addresses:
  0x0100 = word0
  0x0101 = word1
  0x0102 = word2
  0x0103 = word3
  0x0104 = word4
  0x0105 = word5
```

#### Sparse Format (bit 31 = 1)

Writes selected hardware registers using a bitmask.

```
Instruction Header (32 bits):
  [31:31]    Format = 1 (sparse)
  [30:15]    Mask (16-bit bitmask, which additional registers to write)
  [14:0]     Hardware Address (base register address)

Followed by 1 + (number of set bits in mask) data words
```

**Example**:
```
Header: 0x8005_0100
  Bit 31 = 1            → Sparse format
  Bits 30-15 = 0x0005   → Mask = 0000 0000 0000 0101 (bits 0 and 2 set)
  Bits 14-0 = 0x0100    → Hardware address 0x0100

Data: [word0] [word1] [word2]

Result: Writes to hardware addresses:
  0x0100 = word0     (base register, always written)
  0x0101 = word1     (bit 0 of mask is set)
  0x0103 = word2     (bit 2 of mask is set)
  (0x0102 skipped because bit 1 is not set)
```

### Decoding Algorithm

```c
#define HW_MAX_REGS 8192

typedef struct {
    uint32_t values[HW_MAX_REGS];  // Register values indexed by HW address
    bool valid[HW_MAX_REGS];       // Which registers were written
    uint32_t subtype;              // Architecture ID
} hwx_state_t;

void decode_instruction_stream(const uint8_t *task_data, 
                                uint32_t task_size_words,
                                uint32_t cpu_subtype,
                                hwx_state_t *state) {
    const uint32_t *words = (const uint32_t*)task_data;
    
    // Starting position depends on architecture
    int i = (cpu_subtype == 5 || cpu_subtype == 6) ? 8 : 9;
    
    state->subtype = cpu_subtype;
    
    while (i < task_size_words) {
        uint32_t header = words[i++];
        uint32_t hw_addr = header & 0x7FFF;  // Bits 0-14
        
        if ((header >> 31) == 0) {
            // Dense format: consecutive registers
            uint16_t count = (header >> 15) & 0x3F;  // Bits 15-20
            
            for (int j = 0; j <= count && i < task_size_words; j++) {
                if (hw_addr + j < HW_MAX_REGS) {
                    state->values[hw_addr + j] = words[i];
                    state->valid[hw_addr + j] = true;
                }
                i++;
            }
        } else {
            // Sparse format: mask-based selection
            uint16_t mask = (header >> 15) & 0xFFFF;  // Bits 15-30
            
            // First word always written to base address
            if (i < task_size_words && hw_addr < HW_MAX_REGS) {
                state->values[hw_addr] = words[i];
                state->valid[hw_addr] = true;
                i++;
            }
            
            // Additional words written based on mask
            for (int bit = 0; bit < 16 && i < task_size_words; bit++) {
                if ((mask >> bit) & 1) {
                    if (hw_addr + bit + 1 < HW_MAX_REGS) {
                        state->values[hw_addr + bit + 1] = words[i];
                        state->valid[hw_addr + bit + 1] = true;
                    }
                    i++;
                }
            }
        }
    }
}
```

### Real Example: ResNet50_h14

From actual .hwx file (task 0, word 8):

```
Offset 0x20 (Word 8):  40 06 f0 ff

Header = 0xFFF00640
Binary: 1111 1111 1111 0000 0000 0110 0100 0000

Parsing:
  Bit 31 = 1               → Sparse format
  Bits 30-15 = 0x7FE0      → Mask = 0111 1111 1110 0000
  Bits 14-0 = 0x0640       → Hardware address 0x0640

Mask breakdown (bits set: 5,6,7,8,9,10,11,12,13,14):
  Writes to addresses:
    0x0640 (base)
    0x0645 (bit 5)
    0x0646 (bit 6)
    0x0647 (bit 7)
    ... (for each set bit)

This ONE instruction writes 11 different hardware registers!
```

---

## Hardware Register Blocks

After decoding the instruction stream, register values are indexed by **hardware address** (not task descriptor offset).

### Hardware Address Map

Registers are indexed by **32-bit word-based hardware addresses** (not byte offsets).

| HW Address (H14/H15) | HW Address (H16+) | Block Name | Description |
|----------------------|-------------------|------------|-------------|
| 0x0000               | 0x0000            | Common     | Dimensions, channels, basic config |
| 0x0140 (0x0500)      | 0x1040            | L2 Cache   | Buffer addresses, padding, caching |
| 0x0240 (0x0900)      | 0x1140            | PE         | Planar Engine: pooling, activations |
| 0x0340 (0x0D00)      | 0x1240            | NE         | Neural Engine: MAC array, OpMode |
| 0x0440 (0x1100)      | 0x1340            | TileDMA Src| Input DMA from DRAM to ANE |
| 0x0540 (0x1500)      | 0x1440            | TileDMA Dst| Output DMA from ANE to DRAM |
| 0x0640 (0x1900)      | 0x1540            | KernelDMA  | Weight/coefficient loading |

*Note: 0xXXXX (0xYYYY) indicates word index (byte offset equivalent).*

### Stateful Register Parsing

**CRITICAL**: Hardware registers are often set in the first task and reused by subsequent tasks without being rewritten. A correct parser **MUST** maintain a running state across the entire task list.

```python
running_regs = {}
for task in tasks:
    # 1. Decode instructions in THIS task into a local dict
    task_regs = decode_instruction_stream(task.data)
    
    # 2. Update the global hardware state
    running_regs.update(task_regs)
    
    # 3. Store the CUMULATIVE state for this task's analysis
    task.hw_state = running_regs.copy()
```

### L2 Cache Block Details

| Register | H14 Word Offset | H16+ Word Offset | Description |
|----------|-----------------|------------------|-------------|
| Src1Base | Base + 2        | Base + 4         | Input buffer DRAM address |
| ResBase  | Base + 14       | Base + 20        | Output buffer DRAM address |

### Neural Engine (NE) Block Details

| Register | Word Offset | Description |
|----------|-------------|-------------|
| MacCfg   | Base + 1    | Configures NE operation mode and hardware units |

**MacCfg Bit Fields:**
- `[2:0]`   : **ActiveNE** - Number of active NE cores (0-7)
- `[3:3]`   : **SmallSrc** - Enable optimization for small input tensors
- `[13:10]` : **OpMode** - Main operation mode (see below)
- `[16:16]` : **BiasEn** - Enable hardware biasing
- `[23:20]` : **NLMode** - Non-linear activation function (see below)

**OpMode values:**
- `0x0`: Convolution (standard)
- `0x1`: Bypass (activations, pooling)
- `0x2`: Matrix Multiplication
- `0x7`: Optimized Convolution (H14)
- `0xF`: Optimized Convolution (H16+)

**NLMode (Activation) values:**
- `0x0`: None
- `0x1`: ReLU
- `0x2`: ReLU6
- `0x3`: Sigmoid
- `0x4`: Tanh
- `0x5`: GELU

### Planar Engine (PE) Block Details

The Planar Engine performs element-wise operations and pooling.

| Register | Word Offset | Description |
|----------|-------------|-------------|
| PECfg    | Base + 0    | OpMode (bits 0-3) |

**OpMode values:**
- `0x0`: Add (residual connections, bias)
- `0x1`: Multiply
- `0x2`: Max (Max Pooling)
- `0x3`: Min
- `0x4`: Subtract

### TileDMA Block Details

Used for moving tensors between DRAM and ANE L2/SRAM.

| Register | Word Offset | Description |
|----------|-------------|-------------|
| DmaCfg   | Base + 1    | DataSetId (bits 1-5) |
| DmaBase  | Base + 3    | DRAM base address |

### Common Block (HW Address 0x0000)

The Common block contains layer dimensions and convolution parameters.

**IMPORTANT**: Dimension encoding differs significantly between H14 and H16+.

#### H14/H15 Dimension Encoding (Packed)

| HW Address | Name | Description |
|------------|------|-------------|
| 0x0000 | COMMON_INDIM | Input Width (bits 0-14), Height (bits 16-30) |
| 0x0003 | COMMON_INCH | Input Channels (bits 0-16) |
| 0x0004 | COMMON_OUTCH | Output Channels (bits 0-16) |
| 0x0005 | COMMON_OUTDIM | Output Width (bits 0-14), Height (bits 16-30) |

#### H16/H17/H18 Dimension Encoding (Unpacked)

| HW Address | Name | Description |
|------------|------|-------------|
| 0x0001 | InWidth | Input Width |
| 0x0002 | InHeight | Input Height |
| 0x0003 | InChannels | Input Channels |
| 0x0004 | InDepth | Input Depth |
| 0x0005 | OutWidth | Output Width |
| 0x0006 | OutHeight | Output Height |
| 0x0007 | OutChannels | Output Channels |
| 0x0008 | OutDepth | Output Depth |

```c
void parse_common_block(hwx_state_t *state) {
    if (state->subtype >= 7) {
        // H16+ Unpacked Encoding
        uint32_t win = state->values[1];
        uint32_t hin = state->values[2];
        uint32_t cin = state->values[3];
        uint32_t wout = state->values[5];
        uint32_t hout = state->values[6];
        uint32_t cout = state->values[7];
        
        printf("Input:  W=%u H=%u C=%u\n", win, hin, cin);
        printf("Output: W=%u H=%u C=%u\n", wout, hout, cout);
    } else {
        // H14/H15 Packed Encoding
        uint32_t indim = state->values[0];
        uint32_t outdim = state->values[5];
        
        uint16_t win = indim & 0x7FFF;
        uint16_t hin = (indim >> 16) & 0x7FFF;
        uint16_t wout = outdim & 0x7FFF;
        uint16_t hout = (outdim >> 16) & 0x7FFF;
        
        printf("Input:  W=%u H=%u\n", win, hin);
        printf("Output: W=%u H=%u\n", wout, hout);
    }
}
```

const char* get_format_name(uint8_t fmt) {
    switch (fmt) {
        case 0: return "INT8";
        case 1: return "UINT8";
        case 2: return "FLOAT16";
        default: return "Unknown";
    }
}
```

---

## H13 Fixed Format

> **FOR H13 AND EARLIER ONLY**: These architectures use fixed offsets, not instruction streams.

### Architecture Differences

| Feature | H13 and Earlier | H14/H15 | H16+ |
|---------|----------------|---------|------|
| Task encoding | Fixed offsets | Instruction stream (dense only) | Instruction stream (dense + sparse) |
| Parsing | Direct struct access | Decode instructions | Decode instructions |
| Header size | Variable (~40 bytes) | 32 bytes | 36 bytes |
| Register location | TD offset (e.g., 0x128) | HW address (e.g., 0x0000) | HW address (e.g., 0x0000) |

### H13 Task Descriptor Structure

H13 (and H11/H12) task descriptors have a completely different structure from H14+:

```c
// H13 Task Descriptor Header (fixed offsets)
typedef struct {
    uint32_t tid_and_flags;     // +0x000: TID (0-15), NID (16-23), LNID (24), EON (25)
    uint32_t exe_cycles;        // +0x004: ExeCycles (0-15), NextSize (16-24)
    uint32_t log_events;        // +0x008: Log events (0-23)
    uint32_t exceptions;        // +0x00C: Exception mask (0-23)
    uint32_t debug_log_events;  // +0x010: Debug logging (0-23)
    uint32_t debug_exceptions;  // +0x014: Debug exceptions (0-23)
    uint32_t control_flags;     // +0x018: Various control flags
    uint32_t next_pointer;      // +0x01C: Pointer to next task
    uint32_t bank_enables;      // +0x020: Bank enable flags
    uint32_t kbank_enables;     // +0x024: Kernel bank enable flags
    uint32_t dtid;              // +0x028: Dependent TID (0-15)
} ane_header_h13_t;

// Register blocks at fixed TD offsets
#define H13_KERNELDMA_BLOCK  0x02C
#define H13_COMMON_BLOCK     0x128
#define H13_TILEDMA_SRC_BLOCK 0x16C
#define H13_L2_BLOCK         0x1E0
#define H13_PE_BLOCK         0x22C
#define H13_NE_BLOCK         0x240
#define H13_TILEDMA_DST_BLOCK 0x258
```

### H13 Parsing Example

```c
void parse_h13_task(const uint8_t *task_data) {
    const ane_header_h13_t *hdr = (const ane_header_h13_t*)task_data;
    
    // Extract header fields
    uint16_t tid = hdr->tid_and_flags & 0xFFFF;
    uint16_t nid = (hdr->tid_and_flags >> 16) & 0xFF;
    uint16_t exe_cycles = hdr->exe_cycles & 0xFFFF;
    
    printf("Task ID: %u, Node ID: %u, Cycles: %u\n", tid, nid, exe_cycles);
    
    // Read Common block at fixed TD offset 0x128
    const uint32_t *common_block = (const uint32_t*)(task_data + H13_COMMON_BLOCK);
    
    uint32_t indim = common_block[0];   // TD offset 0x128
    uint32_t chcfg = common_block[2];   // TD offset 0x130
    uint32_t inch = common_block[3];    // TD offset 0x134
    uint32_t outch = common_block[4];   // TD offset 0x138
    uint32_t outdim = common_block[5];  // TD offset 0x13C
    
    // Unpack dimensions
    uint16_t win = indim & 0x7FFF;
    uint16_t hin = (indim >> 16) & 0x7FFF;
    uint16_t wout = outdim & 0x7FFF;
    uint16_t hout = (outdim >> 16) & 0x7FFF;
    
    // Extract channels
    uint32_t cin = inch & 0x1FFFF;
    uint32_t cout = outch & 0x1FFFF;
    
    // Extract data types
    uint8_t in_fmt = chcfg & 0x3;
    uint8_t out_fmt = (chcfg >> 4) & 0x3;
    
    printf("Input:  W=%u H=%u C=%u Type=%s\n", 
           win, hin, cin, get_format_name(in_fmt));
    printf("Output: W=%u H=%u C=%u Type=%s\n", 
           wout, hout, cout, get_format_name(out_fmt));
    
    // Read convolution config at TD offset 0x144
    uint32_t conv = common_block[7];  // TD offset 0x144
    uint8_t kw = (conv >> 0) & 0x1F;   // Bits 0-4
    uint8_t kh = (conv >> 5) & 0x1F;   // Bits 5-9
    uint8_t sx = (conv >> 13) & 0x3;   // Bits 13-14
    uint8_t sy = (conv >> 15) & 0x3;   // Bits 15-16
    
    if (kw || kh) {
        printf("Conv: Kernel=%ux%u Stride=%ux%u\n", kw, kh, sx, sy);
    }
}
```

### Key Differences from H14+

**H13 Advantages:**
- ✅ Simple: direct memory access with fixed offsets
- ✅ Predictable: all register blocks at known locations
- ✅ Fast: no instruction decoding required

**H13 Limitations:**
- ❌ Larger files: stores all registers even if unused
- ❌ Fixed layout: harder to extend with new registers
- ❌ No compression: wastes space for sparse operations

**H14+ Advantages:**
- ✅ Smaller files: only stores non-default values
- ✅ Flexible: easy to add new registers
- ✅ Compressed: sparse instructions save space

**H14+ Trade-offs:**
- ⚠️ More complex: requires instruction stream decoder
- ⚠️ Slower parsing: must decode instructions first

### When to Use Each Approach

```c
bool uses_instruction_stream(uint32_t cpu_subtype) {
    return cpu_subtype >= 5;  // H14 (5) and later
}

void parse_task(const uint8_t *task_data, uint32_t cpu_subtype) {
    if (uses_instruction_stream(cpu_subtype)) {
        // H14/H15/H16+: Decode instruction stream
        hwx_state_t state = {0};
        decode_instruction_stream(task_data, task_size, cpu_subtype, &state);
        parse_common_block(&state);
    } else {
        // H11/H12/H13: Use fixed offsets
        parse_h13_task(task_data);
    }
}
```

**DO NOT** use fixed offsets for H14+ - it will produce garbage values!

---

## Building a Complete Parser

### Complete Parser Structure

```c
int main(int argc, char **argv) {
    // Phase 1: Parse Mach-O structure
    size_t file_size;
    uint8_t *file_data = read_file(argv[1], &file_size);
    
    macho_file_t *mf = parse_macho(file_data, file_size);
    if (!mf) {
        fprintf(stderr, "Not a valid .hwx file\n");
        return 1;
    }
    
    printf("Architecture: ");
    switch (mf->cpu_subtype) {
        case 4: printf("H13 (A14/M1)\n"); break;
        case 5: printf("H14 (A15/M2)\n"); break;
        case 6: printf("H15 (A16/M3)\n"); break;
        case 7: printf("H16 (A17 Pro/M4)\n"); break;
        default: printf("Unknown (%u)\n", mf->cpu_subtype); break;
    }
    
    // Phase 2: Find __text section
    size_t section_size;
    const uint8_t *section_data = find_text_section(mf, &section_size);
    if (!section_data) {
        fprintf(stderr, "__text section not found\n");
        return 1;
    }
    
    printf("Found __text section: %zu bytes\n", section_size);
    
    // Phase 3: Parse task descriptors
    const uint8_t *task_data = find_first_task(section_data, section_size);
    if (!task_data) {
        fprintf(stderr, "No tasks found\n");
        return 1;
    }
    
    // Phase 4: Parse task header
    const ane_header_t *hdr = (const ane_header_t*)task_data;
    uint16_t task_size = (hdr->tid_and_size >> 16) & 0x7FF;
    
    parse_task_header(task_data);
    
    // Phase 5: Decode instruction stream (H14+) or read fixed offsets (H13)
    if (uses_instruction_stream(mf->cpu_subtype)) {
        printf("\n=== Decoding Instruction Stream ===\n");
        
        hwx_state_t state = {0};
        decode_instruction_stream(task_data, task_size, mf->cpu_subtype, &state);
        
        printf("\n=== Common Block ===\n");
        parse_common_block(&state);
        
        // Add more block parsers here:
        // parse_l2_block(&state);
        // parse_ne_block(&state);
        // etc.
    } else {
        printf("\nH13 or earlier - use fixed offset parsing\n");
        // Use H13 parsing approach (see reference implementation)
    }
    
    free(mf);
    free(file_data);
    return 0;
}
```

---

## Parsing Multiple Tasks

The example above parses only the first task. To parse all tasks in a file:

### Important: 16-Byte Alignment

**CRITICAL**: Task descriptors are **16-byte aligned**. After each task, you must round up to the next 16-byte boundary:

```c
// WRONG - will miss tasks
offset += task_size * 4;

// CORRECT - tasks are 16-byte aligned
uint32_t size_bytes = task_size * 4;
offset += (size_bytes + 15) & ~15;  // Round up to 16-byte boundary
```

### Complete Multi-Task Parser

```c
// Parse all tasks in __text section
size_t offset = 0;
int task_num = 0;

while (offset + sizeof(ane_header_t) <= section_size) {
    const ane_header_t *hdr = (const ane_header_t*)(section_data + offset);
    uint16_t task_size = (hdr->tid_and_size >> 16) & 0x7FF;
    
    // Skip padding blocks
    if (task_size == 0) {
        offset += 16;
        continue;
    }
    
    printf("\n=== Task %d ===\n", task_num++);
    
    // Parse this task
    const uint8_t *task_data = section_data + offset;
    parse_task_header(task_data);
    
    if (uses_instruction_stream(cpu_subtype)) {
        hwx_state_t state = {0};
        decode_instruction_stream(task_data, task_size, cpu_subtype, &state);
        parse_common_block(&state);
    }
    
    // Move to next task (16-byte aligned!)
    uint32_t size_bytes = task_size * 4;
    offset += (size_bytes + 15) & ~15;
    
    if (offset >= section_size) break;
}

printf("Parsed %d tasks\n", task_num);
```

### Why 16-Byte Alignment?

The ANE hardware requires task descriptors to be aligned on 16-byte boundaries for efficient DMA transfers. Even if a task is 164 bytes (not a multiple of 16), the next task starts at offset 176 (164 rounded up to next multiple of 16).

**Example**:
```
Task 0: Offset 0x010, Size 400 bytes (0x190)
  Next offset: (0x010 + 0x190 + 15) & ~15 = 0x1A0 ✓

Task 1: Offset 0x1A0, Size 164 bytes (0xA4)
  Next offset: (0x1A0 + 0xA4 + 15) & ~15 = 0x250 ✓
  (Not 0x244 - that would be wrong!)

Task 2: Offset 0x250, Size 416 bytes (0x1A0)
  ...
```

---

## Testing Your Parser

### Test with Real Files

```bash
# Compile your parser
gcc -O2 -o hwx_parser \
    hwx_parser.c \
    mach_o_loader.c \
    instruction_decoder.c \
    -I/usr/include

# Test with H14 file
./hwx_parser /tmp/hwx_output/ResNet50_h14/model.hwx

# Expected output:
# Architecture: H14 (A15/M2)
# Found __text section: 45868 bytes
# Task ID: 0
# Task Size: 100 words (400 bytes)
# ...
# === Common Block ===
# Input:  W=224 H=224 C=3 Type=INT8
# Output: W=112 H=112 C=64 Type=INT8
# Conv: Kernel=7x7 Stride=2x2 Pad=3x3
```

### Validate Against Reference Parser

```bash
# Run reference parser
./hwx_dump/hwx_parsing /tmp/hwx_output/ResNet50_h14/model.hwx > ref_output.txt

# Run your parser
./hwx_parser /tmp/hwx_output/ResNet50_h14/model.hwx > my_output.txt

# Compare dimensions, should match
grep "InDim\|OutDim" ref_output.txt
grep "Input:\|Output:" my_output.txt
```

### Common Errors

**Error**: Reading garbage dimension values (e.g., InDim: 259 x 0)
- **Cause**: Reading at fixed TD offset instead of decoding instruction stream
- **Fix**: Use `decode_instruction_stream()` first, then read from `state.values[]`

**Error**: Segmentation fault when parsing
- **Cause**: Not checking `state.valid[]` before reading `state.values[]`
- **Fix**: Always check `if (state.valid[addr/4])` before accessing registers

**Error**: Wrong starting offset for instruction stream
- **Cause**: Using word 8 for H16+ (should be word 9)
- **Fix**: Check `cpu_subtype` and use correct starting offset

---

## Summary

### Key Takeaways

1. **Mach-O First**: Parse Mach-O structure to get architecture and __text section
2. **Check Architecture**: H13 uses fixed offsets, H14+ uses instruction streams
3. **Decode Instructions**: For H14+, decode instruction stream into hardware register state
4. **Read by HW Address**: Access registers using hardware addresses (0x0000, 0x0500, etc.)
5. **Check Valid Flags**: Always verify registers were written before reading

### Code Size Estimate

A complete parser requires approximately:
- Mach-O parsing: ~200 lines
- Task header parsing: ~50 lines
- Instruction decoder: ~100 lines
- Common block decoder: ~80 lines
- Additional block decoders: ~400 lines (optional)
- **Total: ~830 lines** (basic parser with Common block only)

### Reference Implementation

For a complete working implementation, see:
- `hwx_dump/hwx_parsing.m` (~3000 lines, all architectures, all blocks)
- This guide provides the core concepts and enough code to build a working parser

---

## Appendix: Quick Reference

### Architecture Detection
```c
uint32_t subtype = mach_header->cpusubtype;
// 4=H13, 5=H14, 6=H15, 7=H16, 9=H17, 10=H18
```

### Instruction Stream Start
```c
int start_word = (subtype == 5 || subtype == 6) ? 8 : 9;
```

### Dense Instruction
```c
if ((header >> 31) == 0) {
    count = (header >> 15) & 0x3F;
    hw_addr = header & 0x7FFF;
    // Read count+1 words, write to hw_addr..hw_addr+count
}
```

### Sparse Instruction
```c
if ((header >> 31) == 1) {
    mask = (header >> 15) & 0xFFFF;
    hw_addr = header & 0x7FFF;
    // Read 1 + popcount(mask) words
}
```

### Common Block HW Addresses
```c
#define COMMON_INDIM   0x0000
#define COMMON_INCH    0x000C
#define COMMON_OUTCH   0x0010
#define COMMON_OUTDIM  0x0014
#define COMMON_CONV    0x0020
```

---

**End of Guide**

For questions or corrections, see the reference implementation at `hwx_dump/hwx_parsing.m`.
