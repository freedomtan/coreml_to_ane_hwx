# H14 (A15/M2) ANE Hardware Register Map

**Architecture:** H14 (ISA Version 11)  
**Chips:** A15, M2  
**CPU Subtype:** 0x0005  
**Format:** Dense HWX Format  

---

## Architecture Overview

H14 represents the ANE architecture used in A15 (iPhone 13 Pro, iPad mini 6) and M2 (MacBook Air 2022) chips.

**Key Characteristics:**
- ISA Version: 11
- Dense HWX format (vs sparse format in earlier architectures)
- Enhanced register layout compared to H13
- Improved performance over M1/H13

**Hardware Blocks:**
1. **Common** (0x0000) - Input/Output dimensions, convolution config
2. **Neural Engine (NE)** (0x4900) - MAC operations
3. **L2 Cache Control** (0x4100) - Memory caching
4. **TileDMASrc** (0x4D00) - Source tile DMA
5. **TileDMADst** (0x5100) - Destination tile DMA  
6. **KernelDMASrc** (0x5500) - Kernel/weight DMA
7. **CacheDMASrc** (0x5900) - Cache DMA operations

---

## Task Descriptor Header

Located at the beginning of each ANE task.

| Offset | Field Name | Bits | Description |
|--------|------------|------|-------------|
| **0x00** | **TID** | 0-15 | Task ID |
| **0x00** | **TaskSize** | 16-26 | Size of task descriptor in words |
| **0x04** | **ExeCycles** | 0-16 | Estimated execution cycles |
| **0x04** | **ENE** | - | Number of Neural Engines enabled |
| **0x04** | **DTID** | - | Destination Task ID |
| **0x08** | **LogEvents** | 0-23 | Event logging mask |
| **0x0C** | **Exceptions** | 0-23 | Exception mask |
| **0x10** | **LiveOuts** | 0-31 | Live output buffers |
| **0x14** | **TSR** | 0 | Task sync required |
| **0x14** | **TDE** | 1 | Task dependency enable |

---

## Common Block (HW Addr 0x0000)

Core configuration registers for input/output dimensions and operation parameters.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x0000** | **ChannelCfg** | InFmt[0-1], OutFmt[4-5] | Input/output data format |
| **0x0004** | **InWidth** | Win[0-13] | Input width (0-16383) |
| **0x0008** | **InHeight** | Hin[0-13] | Input height (0-16383) |
| **0x000C** | **InChannels** | Cin[0-13] | Input channels (0-16383) |
| **0x0010** | **InDepth** | Din[0-13] | Input depth (0-16383) |
| **0x0014** | **OutWidth** | Wout[0-13] | Output width (0-16383) |
| **0x0018** | **OutHeight** | Hout[0-13] | Output height (0-16383) |
| **0x001C** | **OutChannels** | Cout[0-13] | Output channels (0-16383) |
| **0x0020** | **OutDepth** | Dout[0-13] | Output depth (0-16383) |
| **0x0024** | **NumGroups** | - | Number of groups (for grouped conv) |
| **0x0028** | **ConvCfg** | KW[0-5], KH[6-11], SX[13-14], SY[15-16], PX[17-21], PY[22-26], OX[28-29], OY[30-31] | Convolution configuration |
| **0x002C** | **ConvCfg3D** | Kd, Sz, Pz, Oz | 3D convolution parameters |
| **0x0030** | **MacCfg** | TaskType, ActiveNE, SmSrc, ReluType, OutTrans, FillLowerNE | MAC operation configuration |

### Data Format Codes

**InFmt / OutFmt:**
- `0`: UINT8
- `1`: INT8  
- `2`: FLOAT16
- `3`: Reserved

**TaskType:**
- `0`: None/Bypass
- `1`: Convolution
- `2`: Pooling
- `3`: Element-wise

---

## Neural Engine Block (HW Addr 0x4900)

MAC (Multiply-Accumulate) operation configuration.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x4900** | **NEControl** | Op[0-3], Mode[4-7] | NE operation type and mode |
| **0x4904** | **NEConfig** | Precision, Activation | Precision and activation function |

**NE Operations:**
- `0`: Convolution
- `1`: Depthwise Convolution
- `2`: Fully Connected
- `3`: Element-wise

---

## L2 Cache Block (HW Addr 0x4100)

L2 cache configuration for input/output/weight tensors.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x4100** | **L2Control** | Enable, Mode | L2 cache enable and mode |
| **0x4104** | **L2CacheHint** | CacheHint[0-3] | Cache hint for prefetching |
| **0x4108** | **L2BufferSize** | Size[6-31] | Buffer size in bytes |

---

## TileDMASrc Block (HW Addr 0x4D00)

Source tile DMA configuration for input tensors.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x4D00** | **DMAConfig** | EN[0], CacheHint[4-7] | DMA enable and cache hints |
| **0x4D04** | **BaseAddr** | Addr[6-31] | Base address (64-byte aligned) |
| **0x4D08** | **RowStride** | Stride[6-31] | Row stride in bytes |
| **0x4D0C** | **PlaneStride** | Stride[6-31] | Plane stride in bytes |
| **0x4D10** | **DepthStride** | Stride[6-31] | Depth stride in bytes |
| **0x4D14** | **Fmt** | FmtMode[0-1], MemFmt[12-13], Interleave[24-27] | Data format and layout |

---

## TileDMADst Block (HW Addr 0x5100)

Destination tile DMA configuration for output tensors.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x5100** | **DMAConfig** | EN[0], CacheHint[4-7] | DMA enable and cache hints |
| **0x5104** | **BaseAddr** | Addr[6-31] | Base address (64-byte aligned) |
| **0x5108** | **RowStride** | Stride[6-31] | Row stride in bytes |
| **0x510C** | **PlaneStride** | Stride[6-31] | Plane stride in bytes |
| **0x5110** | **Fmt** | FmtMode[0-1], MemFmt[12-13] | Data format and layout |

---

## KernelDMASrc Block (HW Addr 0x5500)

Kernel/weight DMA configuration.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x5500** | **CoeffDMAConfig[N]** | EN[0], CacheHint[6-9] | Per-buffer DMA config |
| **0x5504** | **CoeffBaseAddr[N]** | Addr[6-31] | Coefficient buffer base address |
| **0x5508** | **CoeffBfrSize[N]** | Size[6-31] | Coefficient buffer size |

---

## CacheDMASrc Block (HW Addr 0x5900)

Cache DMA for intermediate results and telemetry.

| HW Addr | Register Name | Bit Fields | Description |
|---------|---------------|------------|-------------|
| **0x5900** | **CacheControl** | EN[0], Mode[4-7] | Cache DMA enable and mode |
| **0x5904** | **TelemetryConfig** | - | Performance monitoring config |

---

---

## Detailed Register Tables (TODO)

⚠️ **Note:** This document currently provides high-level register descriptions.  
Detailed register offset tables (like H16/H17/H18) are pending additional reverse engineering work.

**For detailed register mappings, see:**
- **H13 (M1):** [h13_register_map.md](h13_register_map.md) - Very similar to H14
- **H16 (M4):** [h16_register_map.md](h16_register_map.md) - Shows evolution from H14
- **Decompiled API:** [ZinAneTd_H14_*.h](.) - Complete method documentation

**Roadmap:** See [H14_H15_REGISTER_MAP_TODO.md](H14_H15_REGISTER_MAP_TODO.md) for detailed register extraction plan.

---

## Register Access Patterns

### Task Initialization
1. Write header fields (TID, TaskSize, ENE)
2. Configure Common block (dimensions, formats)
3. Set up DMA sources (TileDMASrc, KernelDMASrc)
4. Configure NE operation (MacCfg)
5. Set up DMA destination (TileDMADst)
6. Enable L2 cache if needed
7. Set LiveOuts and event masks

### Common Operation Sequences

**Convolution:**
```
Common: InDim, OutDim, ConvCfg (kernel, stride, padding)
NE: MacCfg (TaskType=1, ActiveNE=2)
TileDMASrc: BaseAddr, Strides, Fmt
KernelDMASrc: CoeffBaseAddr[0], CoeffBfrSize[0]
TileDMADst: BaseAddr, Strides, Fmt
```

**Element-wise:**
```
Common: InDim, OutDim
NE: MacCfg (TaskType=3)
TileDMASrc: BaseAddr, Fmt
TileDMADst: BaseAddr, Fmt
```

---

## Differences from H13 (M1)

1. **Dense HWX Format:** More compact task descriptor layout
2. **Enhanced Common Block:** Separate InDepth/OutDepth registers
3. **Improved L2 Control:** Better cache hint mechanisms
4. **ConvCfg3D:** Native 3D convolution support
5. **TaskType Field:** Explicit operation type in MacCfg

---

## Differences from H16 (M4)

1. **Register Addresses:** H14 uses different base addresses than H16
2. **ISA Version:** H14 is V11, H16 is V17
3. **Feature Set:** H16 has additional registers for advanced features
4. **Performance:** H16 has higher clock speeds and more NE units

---

## Decompiled API (ZinAneTd<11u>)

### Complete Categories (383 methods total)

From reverse-engineered ANECompiler binary:

1. **TileDMA:** 78 methods ([ZinAneTd_H14_TileDMA_Complete.h](ZinAneTd_H14_TileDMA_Complete.h))
2. **L2 Cache:** 49 methods ([ZinAneTd_H14_L2Cache_Complete.h](ZinAneTd_H14_L2Cache_Complete.h))
3. **Kernel DMA:** 50 methods ([ZinAneTd_H14_KernelDMA_Complete.h](ZinAneTd_H14_KernelDMA_Complete.h))
4. **Common Config:** ~130 methods ([ZinAneTd_H14_CommonConfig_Complete.h](ZinAneTd_H14_CommonConfig_Complete.h))
5. **Neural Engine:** 6 methods ([ZinAneTd_H14_NeuralEngine_Complete.h](ZinAneTd_H14_NeuralEngine_Complete.h))
6. **Hazard/Dependency:** 12 methods ([ZinAneTd_H14_HazardDependency_Complete.h](ZinAneTd_H14_HazardDependency_Complete.h))
7. **Cache Prefetch:** 18 methods ([ZinAneTd_H14_CachePrefetch_Complete.h](ZinAneTd_H14_CachePrefetch_Complete.h))
8. **Miscellaneous:** ~28 methods ([ZinAneTd_H14_Miscellaneous_Complete.h](ZinAneTd_H14_Miscellaneous_Complete.h))

### Key Methods

**Initialization:**
```cpp
ZinAneTd<11u>::InitializeTdToDefaults()
```

**Configuration Handlers:**
```cpp
ZinAneTd<11u>::HandleTdHeader(...)
ZinAneTd<11u>::HandleCommonConfigFormatAndConvParams(...)
ZinAneTd<11u>::HandleTileDmaSrcConfig(...)
ZinAneTd<11u>::HandleTileDmaDstConfig(...)
ZinAneTd<11u>::HandleKernelDmaSrcConfig(...)
ZinAneTd<11u>::HandleL2Config(...)
ZinAneTd<11u>::HandleNEConfig(...)
```

**Task Setup:**
```cpp
ZinAneTd<11u>::SetTaskSizesInHeader(uint32_t)
ZinAneTd<11u>::GetSizeInWords() const
```

### Differences from H13 (M1)

**Additions (+28 methods):**
- DataSet ID tracking (3 methods in TileDMA)
- Enhanced kernel DMA control (+3 methods)
- Expanded cache prefetch features
- Additional hazard handling methods

**Preserved from H13:**
- Triple cache hints (3 parameters)
- Pixel offset methods (4D offsets)
- Atomic operations
- All core functionality

### Differences from H16 (M4)

**H14 has more methods than H16:**
- H14: 383 methods
- H16: ~350 methods (simplified API)

**H14 preserves complexity:**
- Triple cache hints → simplified in H16
- More kernel DMA options → streamlined in H16
- Pixel offsets → removed in H16

**H16 modernization:**
- Cleaner API surface
- Better defaults
- Compiler handles more complexity

---

## Notes

- All addresses are 64-byte aligned (bits [5:0] must be 0)
- Strides are in bytes, not pixels
- Formats: 0=UINT8, 1=INT8, 2=FP16
- ActiveNE indicates how many NE units participate (typically 2)
- CacheHint values guide L2 prefetching behavior

---

**Status:** ✅ H14 Confirmed Working  
**Task Count:** Varies by operation (1-9 tasks)  
**Compilation:** Successful for all tested operations  
**API Methods:** 383 methods (fully decompiled)  
**Decompilation Status:** Complete ([H14_EXTRACTION_SUMMARY.md](H14_EXTRACTION_SUMMARY.md))  
**Last Updated:** 2026-05-22
