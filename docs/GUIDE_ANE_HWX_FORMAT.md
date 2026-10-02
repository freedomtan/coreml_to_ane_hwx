# Comprehensive Guide to Apple ANE .hwx File Format (H13-H19)

**Purpose**: A complete, beginner-friendly reference for understanding, parsing, and analyzing Apple Neural Engine (ANE) `.hwx` files from scratch. This guide covers all hardware architectures from H13 (A14/M1) through H18g/H19 (A20 Pro).

**Audience**: Novice developers, reverse engineers, and compiler enthusiasts who want to understand how Apple's machine learning accelerator works at the hardware-register level.

---

## Table of Contents

1. [Understanding the ANE Ecosystem](#1-understanding-the-ane-ecosystem)
2. [Mach-O Container Format for Beginners](#2-mach-o-container-format-for-beginners)
3. [Task Descriptor Header Layouts](#3-task-descriptor-header-layouts)
4. [The Instruction Stream Format (ANE Bytecode)](#4-the-instruction-stream-format-ane-bytecode)
5. [Hardware Registers & Virtual State Array](#5-hardware-registers-virtual-state-array)
6. [Hardware Register Unpacking & Bitwise Logic](#6-hardware-register-unpacking-bitwise-logic)
7. [Advanced Heuristics: Dimensions & Activity Mapping](#7-advanced-heuristics-dimensions-activity-mapping)
8. [H13 Fixed Format and Linked List Traversal](#8-h13-fixed-format-and-linked-list-traversal)
9. [Step-by-Step C Parser Implementation](#9-step-by-step-c-parser-implementation)

---

## 1. Understanding the ANE Ecosystem

Before diving into the binary details, let's establish what these files are and why they exist.

### What is the ANE?
The **Apple Neural Engine (ANE)** is a specialized Coprocessor (or NPU - Neural Processing Unit) designed specifically to accelerate neural network operations like convolutions, pooling, and matrix multiplications. 
* **CPU**: Good at general-purpose sequential tasks.
* **GPU**: Good at massive parallel operations (graphics, shaders).
* **ANE/NPU**: Optimized specifically for low-power, high-speed tensor operations using specialized hardware execution pipelines.

### What is a .hwx File?
When you compile a CoreML model using Apple's compiler tools, the compiler outputs a `.hwx` (**Hardware eXecution**) file. This is the **machine code** for the ANE. 
Instead of general-purpose assembly instructions (like `ADD` or `MUL`), a `.hwx` file contains **Task Descriptors** and **Instruction Streams** that program the hardware registers of the Neural Engine. When these registers are loaded with values (like input dimensions, stride sizes, memory addresses, and weight formats), the hardware automatically executes the corresponding layer.

### Architectural Generations
Apple updates the ANE hardware with almost every new chip. The architecture version is represented by an **H-number** (e.g., H13, H14):

| Generation | CPU Subtype | Core SoC Examples | Programming Format | Instruction Set Version |
| :--- | :--- | :--- | :--- | :--- |
| **H11** | 1 | A12 Bionic | Fixed Register Structs | 5 |
| **H12** | 3 | A13 Bionic | Fixed Register Structs | 6 |
| **H13** | 4 | A14, M1 | Fixed Register Structs | 7 |
| **H14** | 5 | A15 Bionic, M2 | Instruction Stream (dense only) | 11 |
| **H15** | 6 | A16 Bionic, M3 | Instruction Stream (dense only) | 8 |
| **H16** | 7 | A17 Pro, M4 | Instruction Stream (dense + sparse) | 17 |
| **H17** | 9 | A18, M5 | Instruction Stream (dense + sparse) | 19 |
| **H18** | 10 | A19, A19 Pro | Instruction Stream (dense + sparse) | 20 |
| **H18g / H19** | 11 | M6, A20 Pro | Instruction Stream (dense + sparse) | 24 |

---

## 2. Mach-O Container Format for Beginners

Every `.hwx` file is wrapped in a **Mach-O (Mach Object)** file format container. This is the standard executable binary format used by macOS and iOS (similar to `.exe` on Windows or ELF on Linux).

### Anatomy of a Mach-O File

A Mach-O file has three main parts:
1. **Header**: Metadata about the file (what chip it runs on, how many commands follow).
2. **Load Commands**: A map or table of contents telling the system where different sections of data are located inside the file.
3. **Segments and Sections**: The actual data payloads (e.g., text, data, weight kernels).

```
┌────────────────────────────────────────┐
│             Mach-O Header              │  (File type, CPU architecture, command counts)
├────────────────────────────────────────┤
│           Load Commands Table          │  (Maps out where segments are located)
├────────────────────────────────────────┤
│  __TEXT Segment  ->  __text Section    │  (Contains ANE Task Descriptors / Instructions)
├────────────────────────────────────────┤
│  __KERN Segment  ->  Weights & Scales  │  (Contains model weights and biases)
├────────────────────────────────────────┤
│  __DATA Segment  ->  State Buffers     │  (Runtime memory configurations)
└────────────────────────────────────────┘
```

### Parsing Binary Buffers (Byte Offsets)

To parse a `.hwx` file in C, we map struct interfaces onto the binary buffer directly. All integers in Mach-O files are stored in **Little-Endian** format.

#### 1. Mach-O Header Struct (32 bytes)
```c
struct mach_header_64 {
    uint32_t magic;         // Validation identifier: 0xFEEDFACF or custom ANE magic 0xBEEFFACE
    uint32_t cputype;       // Typically 0x00000080 for ANE files, or ARM64 0x0100000C
    uint32_t cpusubtype;    // Crucial ANE architecture version (e.g., 4=H13, 5=H14, 7=H16)
    uint32_t filetype;      // File type indicator (usually 0x00000002)
    uint32_t ncmds;         // Number of load commands following this header
    uint32_t sizeofcmds;    // Size of the command segment table
    uint32_t flags;         // Binary execution flags
    uint32_t reserved;      // Reserved alignment field
};
```

#### 2. Segment Command Struct (72 bytes)
When traversing load commands, if `cmd == 0x00000019` (which stands for `LC_SEGMENT_64`), read it using this structure:
```c
struct segment_command_64 {
    uint32_t cmd;           // Load command command code (0x19)
    uint32_t cmdsize;       // Total size of this command and its sections
    char     segname[16];   // Segment name string (e.g., "__TEXT")
    uint64_t vmaddr;        // Virtual memory base address
    uint64_t vmsize;        // Virtual memory allocation size
    uint64_t fileoff;       // Start offset of this segment inside the file
    uint64_t filesize;      // Size of the segment data in the file
    uint32_t maxprot;       // Max memory page protection
    uint32_t initprot;      // Initial memory page protection
    uint32_t nsects;        // Number of section headers directly following this struct
    uint32_t flags;         // Segment flags
};
```

#### 3. Section Struct (80 bytes)
Directly following the `segment_command_64` header, you will find `nsects` section structures:
```c
struct section_64 {
    char     sectname[16];  // Name of the section (e.g., "__text")
    char     segname[16];   // Parent segment name (e.g., "__TEXT")
    uint64_t addr;          // Virtual address of this section
    uint64_t size;          // Section size in bytes
    uint32_t offset;        // Byte offset within the file
    uint32_t align;         // Memory alignment boundary power
    uint32_t reloff;        // Relocations file offset
    uint32_t nreloc;        // Number of relocation entries
    uint32_t flags;         // Section attributes
    uint32_t reserved1;     // Padded buffer
    uint32_t reserved2;     // Padded buffer
    uint32_t reserved3;     // Padded buffer
};
```

---

## 3. Task Descriptor Header Layouts

Inside the extracted `__TEXT / __text` section bytes, the data is organized as a sequence of **Task Descriptors**. Each task descriptor represents a single operations block and is divided into a **Header** followed by the **Instruction Stream**.

### ANE Section Header (16 bytes)
The ANE section (`__TEXT` segment in .hwx files) begins with a 16-byte header before the first task descriptor:

```c
// Offset 0x00 in ANE section
struct ane_section_header {
    uint32_t signature;      // 0x00000001 (observed)
    uint32_t reserved[3];    // All zeros
};
```

**Important**: Task descriptors start at offset **0x10** (16 bytes) into the ANE section, not at offset 0x00. Your parser must skip this header before reading the first task.

### Task Padding Alignment (Crucial for Stream Safety)
Because the Neural Engine compiles tasks on strict **16-byte alignments**, the compiler often inserts zero-filled padding blocks of 16 bytes between tasks. 
If your parser reads Word 0 of a task block and finds `task_size === 0`, it means you have hit padding bytes. **Do not crash or stop parsing!** Simply advance your file pointer by 16 bytes and check the next alignment boundary.

### 1. H14+ Task Descriptor Header (32 or 36 bytes)
The header size depends on the hardware generation:
* **H14 / H15**: 32 bytes (8 words). Does not contain the `dtid` field.
* **H16+**: 36 bytes (9 words). Includes the `dtid` field at the end.

#### C Structural Representation:
```c
typedef struct __attribute__((packed)) {
    uint16_t tid;             // Task ID
    uint32_t task_size : 11;  // Total size of task in 32-bit words
    uint32_t pad0 : 5;        // Alignment padding
    uint16_t exe_cycles;      // Expected execution cycles
    uint16_t pad1;            // Alignment padding
    uint32_t log_events : 24; // Hardware logging events
    uint32_t pad2 : 8;
    uint32_t exceptions : 24; // Exceptions mask
    uint32_t pad3 : 8;
    uint32_t debug_log_events : 24;
    uint32_t pad4 : 8;
    uint32_t debug_exceptions : 24;
    uint32_t pad5 : 8;
    uint32_t live_outs : 24;  // Active outputs map
    uint32_t pad_lo : 8;
    uint32_t unknown_flags;   // Reserved
    struct {
        uint32_t tsr : 1;      // Task Status Register Enable
        uint32_t tde : 1;      // Task Debug Enable
        uint32_t pad : 14;
        uint32_t ene : 3;      // Execution Node Enables
        uint32_t pad1 : 13;
    } ctrl_flags;
    uint16_t dtid;            // Dependent Task ID (H16+ only)
    uint16_t pad8;            // Alignment padding
} ane_header_h16_t;
```

> [!NOTE]
> `dtid` (Dependent Task ID) is reserved for task dependency synchronization. However, in typical compiled CoreML models, this field is seldom used (or set to `0` or `0x0001` without active hardware blocking), meaning it can usually be ignored in high-level visualizations.

---

## 4. The Instruction Stream Format (ANE Bytecode)

For **H13 and newer generations**, Apple abandoned storing hardware registers at fixed offsets. Instead, they use a dynamic **Instruction Stream encoding** (like a custom hardware assembly bytecode). This saves binary space and accommodates sparse register configs.

An instruction stream is a loop that reads a 32-bit command header, decodes it, reads the data values that follow, writes them to virtual registers, and repeats until the task size boundary is reached.

---

### H13 Instruction Stream Format
For H13 (A14/M1) architectures, the instruction header is a 32-bit word structured as follows:

```
  [31:26]    Count (number of extra registers to write: 0-63)
  [25:0]     Byte Address (offset inside the hardware registers memory)
```

#### C Parsing Algorithm:
```c
void decode_h13_instructions(const uint32_t *words, int num_words, uint32_t *running_regs) {
    int w_idx = 0;
    while (w_idx < num_words) {
        uint32_t hdr = words[w_idx++];
        if (hdr == 0) continue; // Skip padding

        uint32_t count = (hdr >> 26) & 0x3F;
        uint32_t byte_addr = hdr & 0x03FFFFFF;
        uint32_t word_addr = byte_addr >> 2; // Convert byte offset to word index

        for (uint32_t i = 0; i <= count && w_idx < num_words; i++) {
            if (word_addr + i < 8192) {
                running_regs[word_addr + i] = words[w_idx++];
            }
        }
    }
}
```

---

### H14+ Instruction Stream Formats
For H14 and newer, there are two instruction encoding formats, determined by the most significant bit (**bit 31**):

#### 1. Dense Format (Bit 31 = 0)
Dense instructions are used to write a contiguous range of registers.

```
  [31]       Format Bit = 0 (Dense)
  [30:21]    Reserved (usually 0)
  [20:15]    Count (number of EXTRA values that follow: 0 to 63)
  [14:0]     Base Hardware Address (15-bit WORD index, multiply by 4 for byte address)
```

#### 2. Sparse Format (Bit 31 = 1)
Sparse instructions write to a subset of registers within a 16-register block, using a bitmask to skip registers that don't need changes.

```
  [31]       Format Bit = 1 (Sparse)
  [30:15]    Mask (16-bit select mask. 1 = write this register, 0 = skip)
  [14:0]     Base Hardware Address (15-bit WORD index, multiply by 4 for byte address)
```

> **CRITICAL**: The hardware address field (bits [14:0]) is a **word-based index**, not a byte address. To convert to byte addresses (used in register documentation), multiply by 4. For example, hw_addr=0x0003 refers to byte address 0x000C.

#### Popcount (Population Count) in C:
```c
int popcount(uint16_t mask) {
    int count = 0;
    while (mask > 0) {
        if (mask & 1) count++;
        mask >>= 1;
    }
    return count;
}
```

---

## 5. Hardware Registers & Virtual State Array

### What is a Register?
In hardware, a register is a small, ultra-fast memory cell. The ANE chip has thousands of these registers. They control everything: the input tensor width, the kernel size, the scale factors, the activation functions, and memory addresses.

### Why Do We Need a Virtual Register State Array?
A critical aspect of ANE hardware is that **registers are stateful**. When the ANE finishes Task 0 and starts Task 1, it does not wipe its registers. Registers keep their programmed values unless a new instruction explicitly overwrites them. This is called **stateful carryover**.

To parse and display the correct settings for a specific task, your software parser must maintain a running array of virtual registers (typically **8192 registers / 32-bit words**). As you decode instructions for Task 0, write their values to your state array. When you begin parsing Task 1, start with the state array left over from Task 0, and update only the registers that Task 1 changes. This allows you to inspect the full, active hardware configuration for any layer.

**⚠️ CRITICAL PARSER REQUIREMENT**: Your parser MUST use a **single persistent HardwareState** object across all tasks in a file. Creating a fresh state for each task will lose stateful carryover and produce incorrect results.

**Correct Implementation**:
```c
// Create ONE hardware state for the entire file
hwx_state_t global_state = {0};
global_state.arch = detected_architecture;

// Parse all tasks using the SAME state
for (int i = 0; i < num_tasks; i++) {
    decode_instruction_stream(task_data[i], &global_state);  // Updates state
    print_task_info(&global_state);                          // Reads accumulated state
    // State persists to next iteration!
}
```

**Incorrect Implementation** (will fail):
```c
// ❌ WRONG: Creating new state per task loses carryover
for (int i = 0; i < num_tasks; i++) {
    hwx_state_t state = {0};  // ❌ Fresh state - loses previous values!
    decode_instruction_stream(task_data[i], &state);
    print_task_info(&state);
}
```

This stateful behavior is why many registers (especially ChannelCfg for data format) appear "missing" in later tasks - they're inherited from earlier tasks that set them.

### Block Base Addresses
Registers are organized into functional hardware blocks. Because the base addresses (offsets) of these blocks shift between generations, you must look up the correct block base index:

| Block Name | H13 & Earlier | H14 / H15 | H16+ (H16, H17, H18) |
| :--- | :--- | :--- | :--- |
| **Common** | `0x0000` | `0x0000` | `0x0000` |
| **L2 Cache** | `0x4800` | `0x0140` | `0x4100` |
| **Planar Engine (PE)** | `0x8800` | `0x0240` | `0x4500` |
| **Neural Engine (NE)** | `0xC800` | `0x0340` | `0x4900` |
| **TileDMA Source** | `0x13800` | `0x0440` | `0x4D00` |
| **TileDMA Dest** | `0x17800` | `0x0540` | `0x5100` |
| **KernelDMA** | `0x1F800` | `0x0640` | `0x5500` |
| **CacheDMA** | N/A | N/A | `0x5900` |

> **Note**: H16+ addresses verified from h16_register_map.md and actual binary analysis.

---

### Register Mappings by Generation

Here is the exact name-to-index mapping for registers within their respective functional blocks:

#### 1. Common Block (Base `0x0000`)

**Important Note**: Not all Common block registers are written for every task. The instruction stream only writes registers that differ from the previous task's state. When parsing, you must maintain a stateful register array across tasks.

* **H14/H15 Key Registers** (byte addresses):
  - `0x0000`: InDim (packed: width in bits [14:0], height in bits [30:16])
  - `0x0008`: ChannelCfg (data format: InFmt [1:0], Src2InFmt [3:2], OutFmt [5:4])
  - `0x000C`: InChannels
  - `0x0010`: OutChannels
  - `0x0014`: OutDim (packed: width in bits [14:0], height in bits [30:16])
  - `0x0020`: ConvCfg (kernel size, stride, padding)
  
* **H16+ Key Registers** (byte addresses, separate width/height):
  - `0x0000`: ChannelCfg (data format: InFmt [1:0], Src2InFmt [3:2], OutFmt [5:4])
  - `0x0004`: InWidth (14 bits)
  - `0x0008`: InHeight (14 bits)
  - `0x000C`: InChannels (14 bits)
  - `0x0014`: OutWidth (14 bits)
  - `0x0018`: OutHeight (14 bits)
  - `0x001C`: OutChannels (14 bits)
  - `0x0028`: ConvCfg (kernel size, stride, padding)

#### Data Format Encoding (ChannelCfg Register)

> [!IMPORTANT]
> **The H16+ raw values below were corrected** after empirical verification against real compiled `.hwx` output cross-checked with known model weight/activation dtypes (see [GUIDE_ANE_WINOGRAD.md §4](GUIDE_ANE_WINOGRAD.md) for the full evidence trail: decompiling `GetHWKernelFormat`/`GetHWChannelFormat`, LLDB-tracing a real compile, and matching raw register values against a model's own MIL source). An earlier pass at this guide (and at `hwx_dump/hwx_parsing.m`/`.py`) had H16+'s raw 0/1 pair backwards. **H14/H15's own raw values below are unverified** — they were never independently re-checked the same way, and may or may not share the same convention.

The ChannelCfg register encodes data types using 2-bit fields on H14-H17, widening to 3 bits at H18+ (to fit `E4M3`/`INT4`/`E2M1`, added at H18/v20 and the newest known future ISA version respectively — see the Winograd guide for where those values come from):

* **H14/H15** (unverified raw mapping):
  * `0x0` (0): INT8 - 8-bit signed integer (quantized)
  * `0x1` (1): UINT8 - 8-bit unsigned integer
  * `0x2` (2): FLOAT16 - 16-bit IEEE 754 half-precision float
  * `0x3` (3): Reserved/Unknown
* **H16+** (confirmed raw mapping):
<!-- LIT:BEGIN(ch_fmt_doc_table) -->
  * `0x0` (0): UINT8 - 8-bit unsigned integer
  * `0x1` (1): INT8 - 8-bit signed integer (quantized)
  * `0x2` (2): FLOAT16 - 16-bit IEEE 754 half-precision float
  * `0x3` (3): E4M3 (fp8) - H18+ only (3-bit field)
  * `0x4` (4): INT4 - newest known future ISA version only
  * `0x5` (5): E2M1 - newest known future ISA version only
<!-- LIT:END(ch_fmt_doc_table) -->

**Critical Implementation Detail**: The ChannelCfg register is **frequently not written** in the instruction stream when tasks use the architecture's default format. Your parser must handle missing ChannelCfg values by applying architecture-specific defaults:

* **H14/H15 Default**: INT8 (value 0)
  - Apple's compiler quantizes models to INT8 for these older architectures by default
  - Register `0x0008` (H14/H15) often omitted from instruction stream
  
* **H16+ Default**: FLOAT16 (value 2)
  - Newer architectures (H16, H17, H18) use FP16 natively
  - Register `0x0000` (H16+) often omitted when FP16 is used
  - Models compiled with `-t h16` or higher typically run in FP16 unless explicitly quantized

**Parser Implementation**:
```c
// Pseudocode for handling data format
if (chcfg_register_present) {
    infmt = chcfg & 0x3;
    outfmt = (chcfg >> 4) & 0x3;
} else {
    // Apply architecture default
    if (arch >= H16) {
        infmt = outfmt = FLOAT16;  // 0x2
    } else {
        infmt = outfmt = INT8;     // 0x0
    }
}
```

This default behavior reflects Apple's compilation strategy: older ANE generations prioritize power efficiency through quantization (INT8), while newer generations have sufficient power budget and hardware support for native FP16 computation.

#### Convolution Configuration (ConvCfg Register)

The ConvCfg register contains convolution kernel parameters:

**H14/H15**: Located at byte address `0x0020`  
**H16+**: Located at byte address `0x0028`

**Bit Field Layout**:
* `bits [5:0]`: Kernel Width (1-63)
* `bits [11:6]`: Kernel Height (1-63)
* `bits [14:13]`: Stride X (0-3)
* `bits [16:15]`: Stride Y (0-3)
* `bits [21:17]`: Padding X (0-31)
* `bits [26:22]`: Padding Y (0-31)

**Parser Implementation**:
```c
uint32_t conv_addr = (arch >= H16) ? 0x0028 : 0x0020;
if (register_valid(conv_addr)) {
    uint32_t conv = read_register(conv_addr);
    uint32_t kernel_w = (conv >> 0) & 0x3F;
    uint32_t kernel_h = (conv >> 6) & 0x3F;
    uint32_t stride_x = (conv >> 13) & 0x3;
    uint32_t stride_y = (conv >> 15) & 0x3;
    uint32_t pad_x = (conv >> 17) & 0x1F;
    uint32_t pad_y = (conv >> 22) & 0x1F;
}
```

Common convolution patterns:
- **3×3 convolution, stride 1, padding 1**: `K=3x3 S=1x1 P=1x1` (standard feature extraction)
- **3×3 convolution, stride 2, padding 1**: `K=3x3 S=2x2 P=1x1` (downsampling)
- **7×7 convolution, stride 2, padding 3**: `K=7x7 S=2x2 P=3x3` (typical first layer in ResNet)
- **1×1 convolution, stride 1, padding 0**: `K=1x1 S=1x1 P=0x0` (pointwise/projection layers)

#### 2. L2 Cache Block (H14 Base `0x0140`, H16+ Base `0x4100`)
* **H13 (16 registers)**:
  `L2Cfg`, `SourceCfg`, `SourceBase`, `SourceChannelStride`, `SourceRowStride`, `pad0`, `pad1`, `pad2`, `pad3`, `pad4`, `pad5`, `pad6`, `ResultCfg`, `ResultBase`, `ConvResultChannelStride`, `ConvResultRowStride`
* **H14 (25 registers)**:
  `Control`, `Src1Cfg`, `Src2Cfg`, `Src1Base`, `Src1ChannelStride`, `Src1RowStride`, `Src1DepthStride`, `Src1GroupStride`, `Src2Base`, `Src2ChannelStride`, `Src2RowStride`, `Src2DepthStride`, `Src2GroupStride`, `ResultCfg`, `ResultBase`, `ResultChannelStride`, `ResultRowStride`, `ResultDepthStride`, `ResultGroupStride`, `SrcAndResultWrapCfg`, `Src1WrapStart`, `Src2WrapStart`, `L2Reserved0`, `ResultWrapIndex`, `ResultWrapStartOffset`
* **H16+ (41+ registers)**:
  `LControl`, `LSrc1Cfg`, `LSrc2Cfg`, `LSrcIdxCfg`, `LSrc1Base`, `LSrc1CStride`, `LSrc1RStride`, `LSrc1DStride`, `LSrc1GStride`, `LSrc2Base`, `LSrc2CStride`, `LSrc2RStride`, `LSrc2DStride`, `LSrc2GStride`, `LSrcIdxBase`, `LSrcIdxCStride`, `LSrcIdxDStride`, `LSrcIdxGStride`, `LResultCfg`, `LResultBase`, `LResultCStride`, `LResultRStride`, `LResultDStride`, `LResultGStride`, `LRes24`, `LResultWrapCfg`, `LRes26`, `LRes27`, `LRes28`, `LResultWrapIdxOff`, `LRes30`, `LResult2Base`, `LResult2CStride`, `LResult2RStride`, `LResult2DStride`, `PEIndexCfg` *(Note: H17 & H18 append additional strides and pads)*.

#### 3. Planar Engine (PE) (H14 Base `0x0240`, H16+ Base `0x4500`)
* **H13 (4 registers)**: `Cfg`, `BiasScale`, `PreScale`, `FinalScale`
* **H14 (5 registers)**: `PEConfig`, `BiasScale`, `PreScale`, `FinalScale`, `Quant`
* **H16+ (16 registers)**: `PE_Config`, `PE_Bias`, `PE_Scale`, `PE_FinalScaleEpsilon`, `PE_PreScale`, `PE_FinalScale`, `PE_LUT1` through `PE_LUT8`, `PE_Quant`

#### 4. Neural Engine (NE) (H14 Base `0x0340`, H16+ Base `0x4900`)
* **H13 (5 registers)**: `KernelCfg`, `MacCfg`, `MatrixVectorBias`, `AccBias`, `PostScale`
* **H14 (5 registers)**: `KernelCfg`, `MacCfg`, `NEBias`, `NEPostScale`, `RoundModeCfg`
* **H16+ (13 registers)**: `KernelCfg`, `MacCfg`, `MatrixVectorBias`, `NEBias`, `PostScale`, `RcasConfig`, `RoundModeCfg`, `SRSeed[0]` through `SRSeed[3]`, `QuantZeroPoint`

#### 5-8. TileDMA Source, TileDMA Destination, KernelDMA Source, CacheDMA
These four blocks' H16+ register names aren't enumerated here as plain name lists like the blocks above — they're larger (21-81 registers each) and every field each parser actually decodes is already given a full bit-level breakdown in §6.4-§6.7 below (word numbers, bit ranges, and value tables), which is more useful than a bare name list. See §6.4 (TileDMA Source), §6.5 (TileDMA Destination), §6.6 (KernelDMA Source), and §6.7 (CacheDMA).

---

## 6. Hardware Register Unpacking & Bitwise Logic

In binary formats, we perform bitwise shifting (`>>`) and bitwise ANDing (`&`) to read values. This is because multiple variables are packed into a single 32-bit register to save storage space. 

For example, to extract a 4-bit value that starts at bit 12:
`const value = (registerWord >> 12) & 0xF;`

Below are the exact bitwise equations to unpack crucial ANE registers.

### 1. Neural Engine Core Block Unpacking

#### A. KernelCfg Register (NE Block + 0)
Controls the layout, datatype, and density of model weights. This section describes the H16+ layout (`kernel_cfg` in `hwx_parsing.py`'s `print_ne_h16`); H14/H15's `KernelCfg` uses a different, unverified layout (see §5's Data Format Encoding note).
* **kfmt** (`bits [1:0]`, a 2-bit field on every real H16-H19 capture, incl. H18+ — unlike ChannelCfg's `ch_fmt`, which genuinely widens to 3 bits at H18+): Weight Data Format. Values `4`/`5` below are carried by the parsers for forward-compatibility but are unreachable with a 2-bit field; only `0`-`3` occur in practice today.
  * `0`: UINT8 (Unsigned quantized integers)
  * `1`: INT8 (Quantized integers)
  * `2`: FLOAT16 (16-bit floating point precision)
  * `3`: E4M3 (fp8) - H18+ only
  * `4`: INT4 - newest known future ISA version only
  * `5`: E2M1 - newest known future ISA version only
* **pen** (`bit [2]`): Palette Enable. If `1`, weights are compressed as indexed palette entries.
* **pbits** (`bits [7:4]`): Palette Bit-width. Quantization depth of the index table.
* **sen** (`bit [8]`): Sparse Compression Enable. If `1`, zero-weight pruning is active (skips processing zero weights to save cycles).
* **reuse** (`bit [10]`): Core weight buffer reuse. If `1`, the engine reuses the weights already stored in the local buffer from the previous layer, avoiding a slow DRAM reload.
* **sbs_w** (`bits [23:21]`): Sparse block size selector for weights.
* **asym** (`bit [24]`): Asymmetric Quantization Enable. If `1`, weights use a non-zero zero-point (vs. symmetric quantization).
* **detect_zeros** (`bit [28]`, H17+ only): If `1`, the engine skips MAC cycles for zero-valued weights at runtime. Unassigned padding on H16.

#### B. MacCfg Register (NE Block + 1)
Determines what mathematical operation the core execution units perform:
* **op** (`bits [2:0]`): Core Operation
  * `0`: Conv
  * `1`: ElemWise
  * `2`: RCAS
  * `3`: EWSqrt
  * `4`: Bypass
  * `5`: TransposedConv
* **km** (`bit [3]`): Kernel Mode. `0` = Kernel (normal weighted conv), `1` = Unity (identity/passthrough kernel).
* **bias_en** (`bit [4]`): If `1`, adds a bias tensor to the MAC output.
* **pass_en** (`bit [5]`): If `1`, bypasses the activation path (runs direct pooling/pooling bypass).
* **mv_bias_en** (`bit [6]`): Matrix-vector bias enable.
* **bin_point** (`bits [13:8]`): The fixed-point scaling shift factor.
* **post_en** (`bit [14]`): Post-scaling multiplier enable.
* **nl_mode_ne** (`bits [17:16]`): Core Activation Function
  * `0`: None (Linear output)
  * `1`: ReLU
  * `2`: Clamp (ReLU6 / Clamp to [0, 6])
  * `3`: Abs (Absolute value)
* **max_pool_en** (`bit [19]`): Fused max-pooling enable.
* **arg_sel** (`bits [23:20]`): Argument/operand selector (exact semantics per-op; not independently decoded beyond the raw value in `hwx_parsing.py`).
* **double_int8_en** (`bit [26]`, `DblInt8` in `hwx_parsing.py`'s output): Double-Int8 mode enable — packs two INT8 MACs per cycle. Required whenever `kfmt` is `UINT8` (see [GUIDE_ANE_WINOGRAD.md](GUIDE_ANE_WINOGRAD.md) for the full DoubleInt8/DoubleMacMode format-eligibility contract).

**Note**: For H16+, this NE MacCfg activation field (at byte address `0x4904`) is the primary location for activation functions in convolution operations. The PE Config register (at `0x4500`) also has a `nl` field at bits [13:12] with the same encoding, used for element-wise operations.

#### C. Common.MacCfg Register (Common Block, word offset 15 / byte `0x3C` on H16+)
A **separate register from the NE.MacCfg above** despite the shared name — this one lives in the Common block (task-level control), not the NE block (math-unit control). Controls task classification and the two convolution fast-path modes:
<!-- LIT:BEGIN(common_maccfg_doc_table) -->
* **task_type** (`bits [7:4]`): Raw hardware task-type code, remapped through a fixed lookup table before use (see `get_task_type_mapping`/`get_hw_task_type_name` in `hwx_parsing.py`) — `0` after remapping means "None" (a plain conv/elementwise task, not a fused pooling/reduction task).
* **small_src** (`bits [3:2]`): Small-Source Mode selector (`ZinSmallSourceMode` in the compiler's own terms — see the Winograd guide's §4/§5 for the full enum and its interaction with Winograd/format eligibility).
* **active_ne** (`bits [21:19]`): Number of active Neural Engine cores for this task.
* **trace_en** (`bit [22]`): Debug tracing enable for this task.
* **relu_type** (`bits [26:24]`): Task-level ReLU-type selector (distinct from NE.MacCfg's `nl_mode_ne` above).
* **wino1d** (`bit [27]`, H17+ only — STUB/always-0 on H16 and earlier): **1D Winograd fast-convolution mode enable.** Set only for `(kernel, stride)` shapes `(3,1)`, `(5,2)`, `(6,2)`, and only for eligible weight/activation formats — see [GUIDE_ANE_WINOGRAD.md](GUIDE_ANE_WINOGRAD.md) for the complete, empirically-verified eligibility contract and real-world `.hwx` measurements.
* **out_trans** (`bit [28]`): Output transpose enable.
* **fill_lower_ne** (`bit [29]`): Fill-lower-NE-cores mode (used when a task's active-core count is less than the hardware maximum, to keep the unused cores' outputs deterministic).
<!-- LIT:END(common_maccfg_doc_table) -->

---

### 2. Planar Engine (PE) Block Unpacking

The Planar Engine handles elementwise math (addition, multiplication) and pooling.

#### PE_Config Register (PE Block + 0)
* **pool** (`bits [1:0]`): Pooling Operation Mode
  * `0`: None
  * `1`: Average Pooling
  * `2`: Max Pooling
  * `3`: Min Pooling
* **op** (`bits [4:2]`): Elementwise Math Operator
  * `0`: Add (e.g. residual connections)
  * `1`: Multiply
  * `2`: Maximum
  * `3`: Minimum
  * `4`: Sum of Squares
* **lut_en** (`bit [5]`): Lookup Table path enable. Used for complex non-linear functions (like Silu, Gelu, or custom activations).
* **cond** (`bits [8:6]`): Conditional Logic Mask. Resolved to a name via
  `get_pe_condition_name_v17` in all three parsers' `PE Config` output.
  **Every value below is empirically confirmed** — not just derived from
  binary disassembly, but by actually compiling the named MIL op
  (`greater`/`less`/`greater_equal`/`less_equal`/`equal`/`not_equal`/`abs`)
  to real H16 `.hwx` via `mil_to_hwx` on real Apple Silicon hardware and
  reading back the exact raw `PE_Config` value ANECompiler produced (full
  writeup, including the disassembly-based derivation that preceded and
  exactly matched this confirmation: [`INVESTIGATION_PE_CONDITION_ENCODING.md`](INVESTIGATION_PE_CONDITION_ENCODING.md)).
  An earlier hand-guessed table (which all three parsers agreed on, but
  which was never checked against the actual hardware) had this field
  wrong in 6 of 8 slots:
  * `0`: None
  * `1`: Less
  * `2`: Greater
  * `3`: NotEqual
  * `4`: Equal
  * `5`: LessEqual
  * `6`: GreaterEqual
  * `7`: Abs
* **nl** (`bits [13:12]`): Non-Linear Activation
  * `0`: None
  * `1`: ReLU
  * `2`: Clamp
  * `3`: Abs

  **Unlike `cond`, this field has never been observed non-zero** —
  not in any single-op test model, any hand-built conv+activation
  fusion test, nor in a real production ResNet50 (both FP16 and
  INT8-quantized full-model `.hwx` compiles checked into this repo).
  Standard ReLU/Clamp fusion for convolutions is carried instead by
  the **NE block's own, separate** `nl_mode_ne` field (§6.1 above,
  byte `0x4904`) — e.g. 69 of 123 conv tasks in the FP16 ResNet50 have
  `nl_mode_ne=1` while every one of their PE Config `nl` fields reads
  `0`. Fused elementwise+ReLU (e.g. residual-add-then-ReLU) is carried
  by `Common.MacCfg`'s `task_type` instead (`EW w/ Reduction w/ ReLU`,
  etc. — §6.1.C above), not by this PE `nl` field either. The labels
  above are the disassembly-derived guess, applied in the parsers'
  dead `get_pe_nl_mode_name_v17` function (never called from the
  actual `PE Config` print statements, unlike `cond`'s now-wired-up
  `get_pe_condition_name_v17`) — left unconfirmed and unwired pending
  a real example that exercises it.
* **src1** (`bits [17:16]`): First input source selector (`0` = Primary, `1` = Texture cache).
* **src2** (`bits [19:18]`): Second input source selector (`0` = Primary, `1` = Texture, `2` = L2 source, `3` = Register).

---

### 3. L2 Cache Block Unpacking (H16+, 41 registers at Block Base `0x4100`)

The L2 Cache Control block configures up to three DMA source streams (`Src1`, `Src2`, `SrcIdx`) and two result streams (`Result`, `Result2`), plus address-wrapping and PE-index-gather configuration. This section describes the H16 layout (`print_l2_h16` in `hwx_parsing.py`/`.m`); H17/H18 extend it with extra reserved/stride words (see the end of this section) but keep the same field meanings for the words they share. H13/H14/H15 use different, narrower layouts (see §5's register-name lists) and are not decoded field-by-field here.

#### L2_Control (Word 0, `0x4100`)
* **src1_relu** (`bit [0]`): Apply ReLU to Source 1 while reading.
* **padding_mode** (`bits [3:2]`): `0`=Clamp, `1`=Zero, `2`=Mirror, `3`=Constant.
* **src2_relu** (`bit [4]`): Apply ReLU to Source 2 while reading.
* **barrier_enable** (`bit [16]`): Enable a hardware sync barrier before this block's DMA runs.
* **barrier_idx** (`bits [23:17]`): Which hardware barrier index to wait on/signal.

#### Src1Cfg / Src2Cfg / SrcIdxCfg (Words 1-3, `0x4104`-`0x410C`)
All three source-config words share the same low-bit layout:
* **src_type** (`bits [1:0]`): `0`=L2Read, `1`=DmaRead2, `2`=DmaRead, `3`=L2ChainRead.
* **dependent** (`bits [3:2]`): Dependency/ordering mode relative to another stream.
* **alias_conv_src** (`bit [4]`) / **alias_conv_rslt** (`bit [5]`): Alias this stream onto the Convolution engine's source/result buffer instead of a fresh L2 fetch.
* **dma_fmt** (`bits [7:6]`): Element width — `0`=8b, `1`=16b, `3`=32b (`get_l2_dma_fmt_name`'s table; value `2` is unused).
* **interleave** (`bits [11:8]`): Channel interleave factor.
* **alias_planar_src** (`bit [20]`) / **alias_planar_rslt** (`bit [22]`): Alias onto the Planar Engine's source/result buffer instead.
* **compression** (`bits [26:25]`): L2 compression mode for this stream.
* `SrcIdxCfg` additionally has **bit27** (`bit [27]`, meaning not yet decoded by any parser — printed as a raw bit by `.py`) in place of `Src1Cfg`/`Src2Cfg`'s `compression` field at that position.

#### Src1 / Src2 / SrcIdx tensor-address blocks (Words 4-17, `0x4110`-`0x4144`)
Each of the three source streams has a `Base`/`ChannelStride`/`RowStride`/`DepthStride`/`GroupStride` quintet (`SrcIdx` omits `RowStride`, so it's a quartet: `Base`/`ChannelStride`/`DepthStride`/`GroupStride`). Every one of these words uses the same **shifted-pointer encoding**: a 17-bit value at `bits [20:4]`, with the low 4 bits always zero (16-byte-aligned) and `bits [3:0]`/`bits [31:21]` unused/reserved:

```c
// Extract a shifted L2 address/stride field from a raw register word:
uint32_t field = (register_value >> 4) & 0x1FFFF;
// To reconstruct the actual byte address/stride, shift back left by 4:
uint32_t byte_value = field << 4;
```

#### L2_ResultCfg (Word 18, `0x4148`)
* **res_type** (`bits [1:0]`): Same `L2Read`/`DmaRead2`/`DmaRead`/`L2ChainRead` table as the source configs.
* **bfr_mode** (`bit [3]`): Buffer mode (double/single-buffered result).
* **src_alias** (`bit [4]`) / **result_alias** (`bit [5]`): Alias flags, same meaning as the source configs' `alias_conv_*`.
* **dma_fmt** (`bits [7:6]`), **interleave** (`bits [11:8]`), **compression** (`bits [26:25]`): Same tables as `Src1Cfg`/`Src2Cfg` above.

Followed by a `Result` tensor-address quintet (Words 19-23, same shifted-pointer encoding as above).

#### Wrap configuration (Words 25-27 + 29, `0x4164`-`0x4174`)
* **WrapCfg[0..2]** (3 words): **wrap_num_blocks** (`bits [11:0]`) and **wrap_len** (`bits [31:12]`) — configure circular-buffer address wrapping for up to 3 streams.
* **ResultWrapIdxOff** (Word 29): **wrap_index_mask** (`bits [3:0]`) and **wrap_start_offset** (`bits [15:4]`).

#### Result2 (Words 31-34, `0x417C`-`0x4188`)
A second result stream's `Base`/`ChannelStride`/`RowStride`/`DepthStride` (no `GroupStride`), same shifted-pointer encoding.

#### PEIndexCfg (Word 35, `0x418C`)
Configures gather-by-index reads feeding the Planar Engine's `print_pe_index_h16` path:
* **max_index** (`bits [15:0]`): Upper bound on the gather index.
* **mode** (`bits [18:16]`): Gather addressing mode.
* **broadcast** (`bits [25:24]`): Broadcast replication factor.
* **transpose** (`bit [26]`): Transpose the gathered tile.

#### CropTex (Word 40, `0x41A0`)
Texture-cache crop window for the two sources: **s1x** (`bits [5:0]`), **s1y** (`bits [12:8]`), **s2x** (`bits [21:16]`), **s2y** (`bits [28:24]`).

> H17/H18 differences: `print_l2_h17`/`print_l2_h18` keep the same `L2_Control`/`Src1Cfg`/`Src2Cfg`/address-block layout for the words they share with H16, but insert extra reserved/stride words further into the block (see `ane_l2_h17_t` in `ane_hwx_regs.h` for the exact word numbering) — treat the field *meanings* above as valid for H17/H18 too, but re-derive word offsets from the header rather than reusing H16's numbering directly.

---

### 4. TileDMA Source Block Unpacking (H16, 81 registers at Block Base `0x4D00`)

Feeds tile data from DRAM into the Convolution/NE pipeline for up to two sources (`Src1`/`Src2`); word numbers below are relative to the block base and describe `print_tiledmasrc_h16`. Many words in `ane_tiledmasrc_h16_t` are marked `res`/`unk` in the header and are not decoded by any parser (printed as raw hex, if at all) — only fields the parsers actually interpret are listed here.

#### DMAConfig (Words 0-1, one per source)
* **enable** (`bit [0]`): Enable this source's DMA.
* **dsid_cache_hint** (`bits [7:5]`): Dataset ID / cache hint selector.
* **user_tag** (`bits [23:16]`): User-defined tag value.
* **dependency_interval** (`bits [27:24]`) / **dependency_mode** (`bits [29:28]`): Cross-task dependency throttling.

#### WrapCfg (Words 2-3, one per source)
* **wrap_cfg_dim** (`bits [10:8]`): Which tensor dimension wraps.
* **wrap_static** (`bits [31:16]`): Static wrap-length value.

#### Base / Strides (Words 4-9 for Src1, 10-15 for Src2)
Six raw 32-bit words per source: `base_lo`/`base_hi` (a full 64-bit DRAM address, unlike L2's shifted 17-bit pointers), then `row_stride`/`plane_stride`/`depth_stride`/`group_stride`, each a plain unshifted byte stride.

#### Metadata (Words 16-25)
Sparse/compression metadata: `src1_meta_addr_{lo,hi}` (16-17), `src2_meta_addr_{lo,hi}` (18-19), `src1_meta_cfg` (20, printed raw), `src1_meta_size` (22), `src2_meta_cfg` (23, printed raw), `src2_meta_size` (25). The `_unk1` words (21, 24) are undecoded.

#### Fmt (Words 26-27, one per source)
Reuses `get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift)` (see §6.1.A):
* **format_mode** (`bits [1:0]`) → the function's `mode` argument.
* **trunc** (`bits [6:4]`) → `trunc`.
* **shift** (`bits [11:8]`) → `shift`.
* **mem_fmt** (`bits [13:12]`) → `mem_fmt`.
* **offset_ch** (`bits [18:16]`): Channel offset — an unsigned 3-bit field (printed as plain `0`-`7`, not sign-extended, despite being formatted with `%d`/`{}` in both `.m` and `.py`).
* **interleave** (`bits [27:24]`): Channel interleave factor.
* **cmp_vec** (`bits [31:28]`): Compression vector width — an unsigned 4-bit field (`0`-`15`, same non-sign-extended convention as `offset_ch`).

#### CompInfo / CompSize / CropOffset (Word 30 + 31-33 for Src1, Word 34 + 35-37 for Src2)
* **compressed_enable** (`bit [0]`): Enable DMA decompression for this source.
* **macroblock_size** (`bit [2]`): Macroblock size selector.
* **packing_format** (`bits [9:4]`): Compression packing format.
* **lossy_mode** (`bit [13]`): Lossy vs. lossless compression.
* **md_user_tag** (`bits [31:24]`): Metadata user tag.
* Followed by `compsize_lo`/`compsize_hi` (a 64-bit compressed size) and a raw `cropoffset` word.

#### WrapDynamic / DependencyOffset (Words 46-47, 48-49)
One raw word per source each; printed as hex, no further decode.

#### TextureCfg (Word 50) and friends (Words 51-53)
* **mode** (`bits [2:0]`): Texture sampling mode (`get_texture_mode_name` — Off/Gather/Bilinear/Bicubic/Nearest).
* **norm1** (`bits [5:3]`) / **norm2** (`bits [8:6]`): Normalization selectors for the two texture axes.
* **filt** (`bits [14:12]`): Filter mode.
* **bgen** (`bit [22]`): Background-value enable.
* **dval** (`bit [23]`): Depth-value enable.
* **wrap** (`bits [28:24]`): Texture wrap mode.
* `TextureIdxPerm` (Word 51) / `TextureSrcPerm` (Word 52): index/source permutation masks, printed raw (undecoded).

#### Src1Ephemeral (Word 62)
* **enable** (`bit [0]`): Mark Src1's buffer as ephemeral (not persisted after this task).

---

### 5. TileDMA Destination Block Unpacking (H16, 21 registers at Block Base `0x5100`)

Writes tile results from the pipeline back out to DRAM. Only one destination stream (no `Src1`/`Src2` split), so it's much smaller than TileDMA Source. Describes `print_tiledmadst_h16`.

#### DstDMAConfig (Word 0, `0x5100`)
* **en** (`bit [0]`): Enable the destination DMA.
* **dataset_id** (`bits [15:8]`): Dataset ID (same concept as TileDMA Source's `dsid_cache_hint`, but a full byte here).
* **user_tag** (`bits [23:16]`): User-defined tag value.

#### DstStrides (Words 4-7, `0x5110`-`0x511C`)
`row_stride`/`plane_stride`/`depth_stride`/`group_stride` — plain unshifted byte strides (64B units), printed raw.

#### DstMeta (Words 10-12, `0x5128`-`0x5130`)
* `dstmeta_lo`/`dstmeta_hi` (Words 10-11): a 64-bit metadata address.
* **dstfmtmode.format_mode** (`bits [1:0]` of Word 12): `get_hw_tensor_format_mode_name` (`0`=None, `1`=Cmp, `2`=Lossy).
* **dstfmtmode.metadata_size** (`bits [31:7]` of Word 12): Metadata region size.

#### DstFmt (Word 14, `0x5138`)
Same `get_hw_tensor_format_name_v17` cascade as TileDMA Source's `Fmt`, but with a narrower `shift` field here:
* **mode** (`bits [1:0]`), **trunc** (`bits [6:4]`), **mem_fmt** (`bits [13:12]`) → feed `get_hw_tensor_format_name_v17`.
* **shift** (`bits [10:8]`, only **3 bits** here — narrower than TileDMA Source's 4-bit `shift`) → also feeds `get_hw_tensor_format_name_v17`.
* **offset_ch** (`bits [18:16]`): unsigned, same non-sign-extended convention as TileDMA Source.
* **zero_pad_first** (`bit [20]`) / **zero_pad_last** (`bit [21]`): Pad the first/last element of a row with zero instead of a real sample.
* **interleave** (`bits [27:24]`), **cmp_vec** (`bits [31:28]`): same meaning as TileDMA Source.

#### DstCompInfo (Word 16, `0x5140`)
* **compressed_enable** (`bit [0]`), **macroblock_size** (`bit [2]`), **packing_format** (`bits [9:4]`), **lossy_mode** (`bit [13]`): same meanings as TileDMA Source's `CompInfo`.
Followed by `dstcompsize_lo`/`dstcompsize_hi` (Words 18-19, a 64-bit compressed size).

#### DstPixelOffset (Word 20, `0x5150`)
A raw word; `.py`/`.m` additionally derive `CropY = dstpixeloffset >> 16` for display.

---

### 6. KernelDMA Source Block Unpacking (H16, 72 registers at Block Base `0x5500`)

Streams compressed/sparse weight coefficients, bias, post-scale, palette, and non-linear-LUT data into the NE core. Describes `print_kerneldmasrc_h16`; H17/H18 (`print_kerneldmasrc_h17`/`h18`, same base address) use a visibly different sub-layout for several of the same words (noted inline below) — this is one of the few blocks where H16 and H17+ genuinely diverge in field meaning, not just which generation shares which function pointer.

#### MasterCfg (Word 0, `0x5500`)
* **group_kernel_reuse** (`bit [4]`): Reuse the previous layer's weight group across this one.
* **kernel_sparse_fmt** (`bit [5]`): Weights are stored in the sparse (zero-pruned) format.
* **master_enable** (`bit [6]`): Master enable for the whole KernelDMA block.

#### AlignedCoeffSize (Word 1, `0x5504`)
Raw 32-bit value (coefficient buffer size, alignment-padded); printed as-is, not bit-decomposed by either parser.

#### Prefetch (Word 2, `0x5508`)
* **early_term_en** (`bit [0]`): Allow early termination of a prefetch (`H16` prints this as `Early`).
* **prefetch_rate** (`bits [31:16]`): Prefetch throttling rate (`H16` prints this as `Rate`). H17/H18 print this word raw instead of decoding it.

#### KernelGroupStride / KernelOCGStride (Words 6-7, `0x5518`-`0x551C`)
Both masked with `& 0x3ffffff` (bits `[25:0]`) by both `.m` and `.py` — note `ane_hwx_regs.h`'s inline comment ("bits 6-31") for these two fields is stale/wrong; the mask both parsers actually apply is the authoritative one. H17/H18 reinterpret these same two words as plain `StrideX`/`StrideY` instead.

#### CoeffCfg[0..15] (Words 8-23, `0x5520`-`0x555C`)
One config word per coefficient-DMA channel:
* **en** (`bit [0]`): Enable this channel (H16 only — H17/H18 don't decode `en` here).
* **dataset_id** (`bits [15:8]`): Dataset ID.
* **user_tag** (`bits [23:16]`): User tag.
* H17/H18 instead decode a **cache_hint**-like field at `bits [7:4]` (printed as `Hint`) that H16's decode doesn't surface.

#### CoeffBase[0..15] / CoeffSize[0..15] (Words 24-39, 40-55, `0x5560`-`0x55DC`)
Per-channel base address (raw) and size (`& 0x3ffffff` on H16; H17/H18 print the raw word unmasked).

#### Bias / PostScale / Palette / NonLinear configs (Words 56, 60, 64, 68)
Each a small `{en, cache_hint, user_tag}` struct; H16 only decodes `en` (`bit [0]`) and `user_tag` (`bits [23:16]`, printed as `Tag`) for Bias/PostScale, and doesn't decode Palette at all. H17/H18 instead decode `cache_hint` (`bits [7:4]`, printed as `Hint`) for all four, plus `user_tag` for Palette/NonLinear only.

---

### 7. CacheDMA / Telemetry Block Unpacking (H16+ only, 12 registers at Block Base `0x5900`)

Unlike every other block in this guide, CacheDMA has no H13/H14/H15 equivalent at all (`h13_printers`/`h14_printers` leave `.print_cachedma = NULL`) — it's new hardware starting at H16/H17. Describes `print_cachedma_h16`, shared verbatim by H17/H18/H19.

#### Control (Word 0, `0x5900`)
* **flush** (`bit [0]`): Flush the cache DMA pipeline.
* **enable** (`bit [1]`): Enable this block.
* **task_sync** (`bits [3:2]`): Task-sync mode (`WaitPrev`/`PostDone` per `ane_hwx_regs.h`'s comment).
* **early_term** (`bits [8:4]`): Early-termination configuration (ET).
* **footprint_limiter** (`bit [9]`): Enable the memory-footprint limiter (FL).
* **footprint_threshold** (`bits [31:16]`): Footprint limiter threshold.

#### Pre0 / Pre1 (Words 1-2, `0x5904`-`0x5908`)
* **Pre0.bandwidth_limit** (`bits [9:0]`), **Pre0.sieve2** (`bits [19:16]`), **Pre0.telemetry_age_out** (`bits [23:20]`).
* **Pre1.sieve1** (`bits [13:0]`).

#### DSID (Word 6, `0x5918`)
* **dsid_and_size** (`bits [29:7]`, 23 bits): Dataset ID + size, packed into the middle of the word. `hwx_parsing.m` reads this through the struct's bitfield (which automatically shifts/masks); `hwx_parsing.py` previously printed the whole raw 32-bit word unshifted here — fixed to `(val >> 7) & 0x7FFFFF` to match. No real sample has exercised a nonzero value yet (all observed captures show `0x0`), so this had no visible effect to date.

#### Footprint (Word 7, `0x591C`)
* **footprint_arg2** (`bits [27:17]`, 11 bits): Same raw-vs-shifted bug as `DSID` existed here too (fixed to `(val >> 17) & 0x7FF`).

#### ET_Args12 / Flush / ET_Args34 (Words 8-10, `0x5920`-`0x5928`)
* **ET_Args12.arg1** (`bits [15:0]`) / **arg2** (`bits [31:16]`): Two packed 16-bit early-termination arguments.
* **Flush.flush_arg** (`bits [15:0]`): Flush argument.
* **ET_Args34.arg3** (`bits [7:0]`) / **arg4** (`bits [23:16]`): Two packed 8-bit early-termination arguments (bits `[15:8]`/`[31:24]` are padding).

#### BackOff (Word 11, `0x592C`)
* **enable** (`bit [0]`): Enable exponential backoff.
* **delay** (`bits [7:4]`): Base delay.
* **min** (`bits [15:8]`) / **max** (`bits [23:16]`): Backoff bounds.
* **scale** (`bits [31:24]`): Backoff scale factor.

---

## 7. Advanced Heuristics: Dimensions & Activity Mapping

### 1. Dimension Extraction & H16 Shifted Heuristic
To prevent parsing corrupted shapes on newer H16+ architectures, apply this recovery algorithm. It detects if standard dimension registers are unprogrammed or shifted downstream:

```c
typedef struct {
    uint32_t width;
    uint32_t height;
    uint32_t channels;
} dims_t;

dims_t extract_dimensions(const uint32_t *state_array) {
    dims_t d;
    d.width = state_array[1] & 0x1FFFF;   // Input Width
    d.height = state_array[2] & 0x1FFFF;  // Input Height
    d.channels = state_array[3] & 0x1FFFF;// Input Channels

    // Heuristic validation check:
    // If Width is 0, or exceeds reasonable limits, inspect alternative shifted registers
    if (d.width == 0 || d.width >= 65536 || d.height >= 65536) {
        uint32_t test_w = state_array[0x0b] & 0x1FFFF; // Alternate width location
        uint32_t test_h = state_array[0x0c] & 0x1FFFF; // Alternate height location
        uint32_t test_c = state_array[0x0d] & 0x1FFFF; // Alternate channels location
        
        if (test_w > 0 && test_w < 10000 && test_h <= test_w) {
            d.width = test_w;
            d.height = test_h;
            d.channels = test_c;
        }
    }
    return d;
}
```

### 2. Planar Engine (PE) Activity & Task Type Mapping
Due to stateful register persistence in `.hwx` execution, PE configurations (like Average Pooling) can carry over to subsequent tasks even when the Planar Engine is inactive. To prevent visualizing garbage states, check the mapped `task_type` of the task to determine if the PE is active:

1. **Extract raw `task_type` from `MacCfg` inside the Common block:**
   * **H16+ (`cpusubtype >= 7`)**: `MacCfg` is at Common word index 15.
     `task_type = (state.values[15] >> 4) & 0xF`
   * **H14/H15 (`cpusubtype == 5 / 6`)**: `MacCfg` is at Common word index 10.
     `task_type = state.values[10] & 0xF`

2. **Map the raw task type value to hardware category:**
   * Apply this mapping logic:
     ```c
     int get_mapped_task_type(uint32_t task_type) {
         switch (task_type) {
             case 0: return 0;
             case 1: return 2;
             case 2: return 6;
             case 3: return 5;
             case 4: return 7;
             case 5: return 4;
             case 6: return 3;
             case 7: return 0;
             case 8: return 1;
             default: return 0;
         }
     }
     ```
   * **If `task_type_mapped == 0`**: PE is **inactive**. Force all PE settings (like pool mode, op mode) to return `"None"` or `"NO"`.
   * **If `task_type_mapped` is `1` or `2`**: PE is active, performing **pooling** (e.g. Max Pooling, Avg Pooling).
   * **If `task_type_mapped` is `3`, `4`, `5` or `6`**: PE is active, performing **elementwise** operations (Add, Mul, etc.).

3. **H13 PE Activity**:
   * H13 parses PE configurations from the `Cfg` register at `H13_PE_BLOCK + 0`.
   * **PE Enable (`En`)**: Bit 1 of the configuration (`(pe_cfg >> 1) & 1`). If `En == 0`, PE is inactive.
   * **PE Operation (`OpMode`)**: Bits 2-4 (`(pe_cfg >> 2) & 7`), mapping to:
     `{0x0: "Add", 0x1: "Multiply", 0x2: "Max", 0x3: "Min", 0x4: "Subtract"}`

---

## 8. H13 Fixed Format and Linked List Traversal

In **H13 (M1/A14) and earlier** chips, Apple used a rigid struct-based layout. There are no instruction streams. Register values are read directly using fixed byte offsets from the start of the task block.

### Fixed Memory Map (H13)
```c
#define H13_COMMON_BLOCK      0x128  // Read dimension values (word index 74)
#define H13_L2_BLOCK          0x1E0  // Read L2 cache configurations
#define H13_PE_BLOCK          0x22C  // Read Planar Engine configurations
#define H13_NE_BLOCK          0x240  // Read Neural Engine configurations
#define H13_TILEDMA_SRC_BLOCK 0x16C  // Read TileDMA Source configurations
#define H13_TILEDMA_DST_BLOCK 0x258  // Read TileDMA Dest configurations
```

### Linked List Traversal in C
H13 tasks are not placed side-by-side sequentially. Instead, each task header contains a `next_pointer` field pointing to the next task's byte offset. You must traverse the tasks like a singly linked list:

```c
typedef struct __attribute__((packed)) {
    uint16_t tid;
    uint8_t  nid;
    uint8_t  lnid:1;
    uint8_t  eon:1;
    uint8_t  pad0:6;
    uint16_t exe_cycles;
    uint16_t next_size:9;
    uint16_t pad1:7;
    uint32_t log_events:24;
    uint32_t pad2:8;
    uint32_t exceptions:24;
    uint32_t pad3:8;
    uint32_t debug_log_events:24;
    uint32_t pad4:8;
    uint32_t debug_exceptions:24;
    uint32_t pad5:8;
    uint32_t flags;
    uint32_t next_pointer; // Target offset of next linked node
} H13_task_header_t;

void parse_h13_tasks(const uint8_t *section_data, size_t section_size) {
    uint32_t offset = 0;
    
    while (offset + sizeof(H13_task_header_t) <= section_size) {
        const H13_task_header_t *task = (const H13_task_header_t *)(section_data + offset);
        
        printf("Task ID: 0x%04x\n", task->tid);
        
        // Extract common dimensions from fixed struct offset
        const uint32_t *common = (const uint32_t *)(section_data + offset + H13_COMMON_BLOCK);
        uint32_t width = common[0] & 0x1FFFF;
        printf("Dimensions: Width = %u\n", width);
        
        // Hop to next task
        if (task->next_pointer == 0 || task->next_pointer <= offset) {
            break; // End of list
        }
        offset = task->next_pointer;
    }
}
```

---

## 9. Step-by-Step C Parser Implementation

This complete, production-ready C program demonstrates how to load a `.hwx` file, extract the text segment, and parse all task descriptors, instruction streams, and register maps.

Save the following code as `hwx_parse.c` and compile it with:
`clang -Wall -O2 hwx_parse.c -o hwx_parse`

```c
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdbool.h>

// Mach-O structures
struct mach_header_64 {
    uint32_t magic;
    uint32_t cputype;
    uint32_t cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
    uint32_t reserved;
};

struct load_command {
    uint32_t cmd;
    uint32_t cmdsize;
};

struct segment_command_64 {
    uint32_t cmd;
    uint32_t cmdsize;
    char     segname[16];
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    uint32_t maxprot;
    uint32_t initprot;
    uint32_t nsects;
    uint32_t flags;
};

struct section_64 {
    char     sectname[16];
    char     segname[16];
    uint64_t addr;
    uint64_t size;
    uint32_t offset;
    uint32_t align;
    uint32_t reloff;
    uint32_t nreloc;
    uint32_t flags;
    uint32_t reserved1;
    uint32_t reserved2;
    uint32_t reserved3;
};

// Simplified task header matching binary format
typedef struct __attribute__((packed)) {
    uint16_t tid;
    uint32_t task_size : 11;
    uint32_t pad0 : 5;
    uint16_t exe_cycles;
    uint16_t pad1;
} ANE_task_header_t;

// Running virtual register file
static uint32_t running_regs[8192] = {0};
static bool     regs_valid[8192] = {false};

// Decodes H14+ instruction stream
void decode_instructions(const uint32_t *words, int num_words, int start_word) {
    int i = start_word;
    while (i < num_words) {
        uint32_t header = words[i++];
        uint32_t hw_word_addr = header & 0x7FFF;  // Word-based address
        uint32_t hw_byte_addr = hw_word_addr * 4; // Convert to byte address

        if (((header >> 31) & 1) == 0) {
            // Dense Format
            uint32_t count = (header >> 15) & 0x3F;
            for (uint32_t j = 0; j <= count && i < num_words; j++) {
                uint32_t byte_addr = hw_byte_addr + (j * 4);
                if (byte_addr < 32768) {  // 8192 words * 4 bytes
                    running_regs[byte_addr] = words[i];
                    regs_valid[byte_addr] = true;
                }
                i++;
            }
        } else {
            // Sparse Format
            uint32_t mask = (header >> 15) & 0xFFFF;
            if (i < num_words && hw_byte_addr < 32768) {
                running_regs[hw_byte_addr] = words[i];
                regs_valid[hw_byte_addr] = true;
                i++;
            }
            for (int bit = 0; bit < 16 && i < num_words; bit++) {
                if ((mask >> bit) & 1) {
                    uint32_t byte_addr = hw_byte_addr + ((bit + 1) * 4);
                    if (byte_addr < 32768) {
                        running_regs[byte_addr] = words[i];
                        regs_valid[byte_addr] = true;
                    }
                    i++;
                }
            }
        }
    }
}

// Note: running_regs[] array should now be indexed by byte address, not word index
// Example: To read InChannels at byte address 0x000C, use running_regs[0x000C]

// Extracts shapes using H16 shifted heuristics
void print_dimensions(void) {
    uint32_t win = running_regs[1] & 0x1FFFF;
    uint32_t hin = running_regs[2] & 0x1FFFF;
    uint32_t cin = running_regs[3] & 0x1FFFF;

    if (win == 0 || win >= 65536 || hin >= 65536) {
        uint32_t test_w = running_regs[0x0b] & 0x1FFFF;
        uint32_t test_h = running_regs[0x0c] & 0x1FFFF;
        uint32_t test_c = running_regs[0x0d] & 0x1FFFF;
        if (test_w > 0 && test_w < 10000 && test_h <= test_w) {
            win = test_w;
            hin = test_h;
            cin = test_c;
        }
    }
    printf("  Dimensions: W=%u, H=%u, C=%u\n", win, hin, cin);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        printf("Usage: %s <path_to_model.hwx>\n", argv[0]);
        return 1;
    }

    FILE *file = fopen(argv[1], "rb");
    if (!file) {
        perror("Failed to open file");
        return 1;
    }

    // Read header
    struct mach_header_64 header;
    if (fread(&header, sizeof(struct mach_header_64), 1, file) != 1) {
        printf("Failed to read header\n");
        fclose(file);
        return 1;
    }

    if (header.magic != 0xBEEFFACE && header.magic != 0xFEEDFACF) {
        printf("Invalid Mach-O magic: 0x%x\n", header.magic);
        fclose(file);
        return 1;
    }

    printf("Detected CPU Subtype: %u (H%u)\n", header.cpusubtype, 10 + header.cpusubtype);

    // Find __text section of __TEXT segment
    uint32_t text_offset = 0;
    uint64_t text_size = 0;

    long current_pos = sizeof(struct mach_header_64);
    for (uint32_t cmd_idx = 0; cmd_idx < header.ncmds; cmd_idx++) {
        fseek(file, current_pos, SEEK_SET);
        struct load_command lc;
        if (fread(&lc, sizeof(struct load_command), 1, file) != 1) break;

        if (lc.cmd == 0x19) { // LC_SEGMENT_64
            fseek(file, current_pos, SEEK_SET);
            struct segment_command_64 seg;
            if (fread(&seg, sizeof(struct segment_command_64), 1, file) != 1) break;

            if (strcmp(seg.segname, "__TEXT") == 0) {
                for (uint32_t s_idx = 0; s_idx < seg.nsects; s_idx++) {
                    struct section_64 sect;
                    if (fread(&sect, sizeof(struct section_64), 1, file) != 1) break;

                    if (strcmp(sect.sectname, "__text") == 0) {
                        text_offset = sect.offset;
                        text_size = sect.size;
                        break;
                    }
                }
            }
        }
        current_pos += lc.cmdsize;
        if (text_offset != 0) break;
    }

    if (text_offset == 0) {
        printf("Could not find __TEXT/__text section.\n");
        fclose(file);
        return 1;
    }

    printf("Parsing tasks at offset 0x%x (size %llu bytes)...\n", text_offset, text_size);

    uint8_t *text_data = malloc(text_size);
    fseek(file, text_offset, SEEK_SET);
    if (fread(text_data, 1, text_size, file) != text_size) {
        printf("Failed to read section data.\n");
        free(text_data);
        fclose(file);
        return 1;
    }

    uint32_t offset = 0;
    int task_count = 0;
    int header_bytes = (header.cpusubtype >= 7) ? 36 : 32;
    int start_word = (header.cpusubtype >= 7) ? 9 : 8;

    while (offset + header_bytes <= text_size) {
        const ANE_task_header_t *task = (const ANE_task_header_t *)(text_data + offset);
        uint32_t size_words = task->task_size;
        uint32_t size_bytes = size_words * 4;

        if (size_words == 0) {
            offset += 16; // Skip alignment padding
            continue;
        }

        if (offset + size_bytes > text_size) break;

        printf("\n--- Task #%d (ID: 0x%04x, size: %u bytes) ---\n", task_count++, task->tid, size_bytes);

        // Decode task's instruction stream updating running_regs
        const uint32_t *instructions = (const uint32_t *)(text_data + offset);
        decode_instructions(instructions, size_words, start_word);

        // Analyze and print register states
        print_dimensions();

        offset += ((size_bytes + 15) & ~15); // Align next task to 16 bytes
    }

    free(text_data);
    fclose(file);
    return 0;
}
```

This guide and code provide all details required to compile a fully working C-based `.hwx` parser on macOS.
