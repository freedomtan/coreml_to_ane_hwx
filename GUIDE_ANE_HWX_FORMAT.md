# Comprehensive Guide to Apple ANE .hwx File Format (H13-H18)

**Purpose**: A complete, beginner-friendly reference for understanding, parsing, and analyzing Apple Neural Engine (ANE) `.hwx` files from scratch. This guide covers all hardware architectures from H13 (A14/M1) through H18 (A19).

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
| **H18** | 10 | A19 | Instruction Stream (dense + sparse) | 20 |

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
│  __TEXT Segment  ->  __text Section   │  (Contains ANE Task Descriptors / Instructions)
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

The ChannelCfg register encodes data types using 2-bit fields:
* `0x0` (0): INT8 - 8-bit signed integer (quantized)
* `0x1` (1): UINT8 - 8-bit unsigned integer
* `0x2` (2): FLOAT16 - 16-bit IEEE 754 half-precision float
* `0x3` (3): Reserved/Unknown

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

---

## 6. Hardware Register Unpacking & Bitwise Logic

In binary formats, we perform bitwise shifting (`>>`) and bitwise ANDing (`&`) to read values. This is because multiple variables are packed into a single 32-bit register to save storage space. 

For example, to extract a 4-bit value that starts at bit 12:
`const value = (registerWord >> 12) & 0xF;`

Below are the exact bitwise equations to unpack crucial ANE registers.

### 1. Neural Engine Core Block Unpacking

#### A. KernelCfg Register (NE Block + 0)
Controls the layout, datatype, and density of model weights:
* **kfmt** (`bits [1:0]`): Weight Data Format
  * `0`: INT8 (Quantized integers)
  * `1`: UINT8 (Unsigned quantized integers)
  * `2`: FLOAT16 (16-bit floating point precision)
* **pen** (`bit [2]`): Palette Enable. If `1`, weights are compressed as indexed palette entries.
* **pbits** (`bits [7:4]`): Palette Bit-width. Quantization depth of the index table.
* **sen** (`bit [8]`): Sparse Compression Enable. If `1`, zero-weight pruning is active (skips processing zero weights to save cycles).
* **reuse** (`bit [10]`): Core weight buffer reuse. If `1`, the engine reuses the weights already stored in the local buffer from the previous layer, avoiding a slow DRAM reload.
* **sbs_w** (`bits [24:21]`): Sparse block size selector for weights.

#### B. MacCfg Register (NE Block + 1)
Determines what mathematical operation the core execution units perform:
* **bias_en** (`bit [4]`): If `1`, adds a bias tensor to the MAC output.
* **pass_en** (`bit [5]`): If `1`, bypasses the activation path (runs direct pooling/pooling bypass).
* **bin_point** (`bits [13:8]`): The fixed-point scaling shift factor.
* **post_en** (`bit [14]`): Post-scaling multiplier enable.
* **nl_mode_ne** (`bits [17:16]`): Core Activation Function
  * `0`: None (Linear output)
  * `1`: ReLU
  * `2`: ReLU6
  * `3`: Sigmoid

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
* **cond** (`bits [8:6]`): Conditional Logic Mask
  * `0`: None
  * `1`: Absolute Value
  * `2`: Equal
  * `3`: Greater Than
  * `4`: Greater or Equal
* **nl** (`bits [13:12]`): Non-Linear Activation
  * `0`: None
  * `1`: ReLU
  * `2`: Clamp
  * `3`: Abs
* **src1** (`bits [17:16]`): First input source selector (`0` = Primary, `1` = Texture cache).
* **src2** (`bits [19:18]`): Second input source selector (`0` = Primary, `1` = Texture, `2` = L2 source, `3` = Register).

---

### 3. L2 Cache Address Layout & 4-bit Alignment

ANE memory access uses the system L2 cache. The base buffer registers (e.g., `LSrc1Base`, `LSrc2Base`, `LResultBase`) store the locations of input and output tensors in memory.

However, to save bits inside the control registers, addresses are stored as **page pointers shifted right by 4 bits** (which guarantees 16-byte alignment).

To reconstruct the actual physical DRAM byte address, extract the register value and shift it left by 4 bits (padding the lowest 4 bits with zeros):

```c
uint32_t get_physical_address(uint32_t register_value) {
    // Clear any high flag bits and shift alignment
    return register_value & 0x1FFFF0;
}
```

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
