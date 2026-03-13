# M1 ANE Hardware Register Map

This document maps the `ZinAneTd<7u>` object offsets to hardware registers for the M1 architecture.

## Architecture Alignment Principles (M1/H13)
1. **Header Registers**: Located at `this + 0x008` (Byte 8) in the object, mapping to `TD 0x000` in the Task Descriptor.
   - Formula: `TD Offset + 0x008 = Object Offset`.
2. **Hardware Blocks**: Seven blocks (KernelDMA, Common, TileDMA, L2, PE, NE).
   - Each block starts with a **Metadata/Info word (Word 0)** which is NOT a hardware register.
   - **Registers start at Word 1** of each block.
   - `ProcessRegisters` copies each block (including Word 0) from the object to the Task Descriptor.

## Block Assignments Summary

| Block | TD Start (Metadata) | Word 1 (First Reg) | ZinAneTd<7u> Source |
| :--- | :--- | :--- | :--- |
| **Header** | `0x000` | `0x000` | `this + 0x008` |
| **KernelDMA** | `0x028` | `0x02C` | `this + 0x034` |
| **Common** | `0x124` | `0x128` | `this + 0x1D8` |
| **TileDMA Src**| `0x168` | `0x16C` | `this + 0x220` |
| **L2** | `0x1DC` | `0x1E0` | `this + 0x298` |
| **PE** (Planar) | `0x228` | `0x22C` | `this + 0x2E8` |
| **NE** (Neural) | `0x23C` | `0x240` | `this + 0x300` |
| **TileDMA Dst**| `0x254` | `0x258` | `this + 0x31C` |

---

## Detailed Block Definitions (Registers Only)

### Header Block (TD 0x000)
Source: `this + 0x008`

| TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x000** | **Header[0]** | `this + 0x008` | **TID**: 0-15, **NID**: 16-23, **LNID**: 24, **EON**: 25. |
| **0x004** | **Header[1]** | `this + 0x00C` | **ExeCycles**: 0-15, **NextSize**: 16-24. |
| **0x008** | **Header[2]** | `this + 0x010` | **LogEvents**: 0-23. |
| **0x00C** | **Header[3]** | `this + 0x014` | **Exceptions**: 0-23. |
| **0x010** | **Header[4]** | `this + 0x018` | **DebugLogEvents**: 0-23. |
| **0x014** | **Header[5]** | `this + 0x01C` | **DebugExceptions**: 0-23. |
| **0x018** | **Header[6]** | `this + 0x020` | **TQDis**: 31, **DstLoc**: 29, **SrcLoc**: 28, **TDE**: 24, **NextPriority**: 16-21, **TSE**: 15, **DPC**: 14, **SPC**: 13, **TSR**: 12, **SPL**: 11, **KPC**: 10, **TDSkip**: 9, **DisallowAbort**: 8. |
| **0x01C** | **Header[7]** | `this + 0x024` | **NextPointer**: 0-31. |
| **0x020** | **Header[8]** | `this + 0x028` | **RBase0**: 0-4, **RBE0**: 5, **RBase1**: 6-10, **RBE1**: 11, **WBase**: 12-16, **WBE**: 17, **TBase**: 18-22, **TBE**: 23, **ENE**: 24-27. |
| **0x024** | **Header[9]** | `this + 0x02C` | **KBase0**: 0-4, **KBE0**: 5, **KBase1**: 6-10, **KBE1**: 11, **KBase2**: 12-16, **KBE2**: 17, **KBase3**: 18-2, **KBE3**: 23. |
| **0x028** | **Header[10]** | `this + 0x030` | **DTID**: 0-15. |

### KernelDMASrc Block (TD 0x02C)
Source: `this + 0x034`
Base HW Addr: `0x1F800`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x1F800** | **0x02C** | *pad0* | `this + 0x034` | - |
| **0x1F804** | **0x030** | *pad1* | `this + 0x038` | - |
| **0x1F808-0x1F844** | **0x034-0x070** | **CoeffDMAConfig[16]**| `this + 0x03C..0x078` | **En**: 0, **CrH**: 4-5, **CacheHint**: 6-9, **PrefetchParticipateEn**: 27. |
| **0x1F848-0x1F884** | **0x074-0x0B0** | **CoeffBaseAddr[16]** | `this + 0x07C..0x0B8` | **Addr**: 6-31. |
| **0x1F888-0x1F8C4** | **0x0B4-0x0F0** | **CoeffBfrSize[16]** | `this + 0x0BC..0x0F8` | **MemBfrSize**: 6-31. |

### Common Block (TD 0x128)
Source: `this + 0x1D8`
Base HW Addr: `0x0000`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x0000** | **0x128** | **InDim** | `this + 0x1D8` | **Win**: 0-14, **Hin**: 16-30. |
| **0x0004** | **0x12C** | *pad0* | `this + 0x1DC` | - |
| **0x0008** | **0x130** | **ChCfg** | `this + 0x1E0` | **InFmt**: 0-1, **OutFmt**: 4-5. |
| **0x000C** | **0x134** | **Cin** | `this + 0x1E4` | **Cin**: 0-16. |
| **0x0010** | **0x138** | **Cout** | `this + 0x1E8` | **Cout**: 0-16. |
| **0x0014** | **0x13C** | **OutDim** | `this + 0x1EC` | **Wout**: 0-14, **Hout**: 16-30. |
| **0x0018** | **0x140** | *pad1* | `this + 0x1F0` | - |
| **0x001C** | **0x144** | **ConvCfg** | `this + 0x1F4` | **Kw**: 0-4, **Kh**: 5-9, **OCGSize**: 10-12, **Sx**: 13-14, **Sy**: 15-16, **Px**: 17-21, **Py**: 22-26, **Ox**: 28-29, **Oy**: 30-31. |
| **0x0020** | **0x148** | *pad2* | `this + 0x1F8` | - |
| **0x0024** | **0x14C** | **GroupConvCfg**| `this + 0x1FC` | **NumGroups**: 0-12, **UnicastEn**: 14, **ElemMultMode**: 15, **UnicastCin**: 16-31. |
| **0x0028** | **0x150** | **TileCfg** | `this + 0x200` | **TileHeight**: 0-15. |
| **0x002C..** | **0x154..0x158** | *pad3* | `this + 0x204..0x208` | - |
| **0x0034** | **0x15C** | **Cfg** | `this + 0x20C` | **SmallSourceMode**: 2, **ShPref**: 8-10, **ShMin**: 12-14, **ShMax**: 16-18, **ActiveNE**: 19-21, **ContextSwitchIn**: 22, **ContextSwitchOut**: 24, **AccDoubleBufEn**: 26. |
| **0x0038** | **0x160** | **TaskInfo**| `this + 0x210` | **TaskID**: 0-15, **TaskQ**: 16-19, **TaskNID**: 20-27. |
| **0x003C** | **0x164** | **DPE** | `this + 0x214` | **Category**: 0-3. |

### TileDMASrc Block (TD 0x16C)
Source: `this + 0x220`
Base HW Addr: `0x13800`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x13800** | **0x16C** | **DMAConfig** | `this + 0x220` | **EN**: 0, **CacheHint**: 4-7, **CacheHintReuse**: 8-11, **CacheHintNoReuse**: 12-15, **DependencyMode**: 16-19. |
| **0x13804** | **0x170** | *pad2* | `this + 0x224` | - |
| **0x13808** | **0x174** | **BaseAddr** | `this + 0x228` | **Addr**: 6-31. |
| **0x1380C** | **0x178** | **RowStride** | `this + 0x22C` | **Stride**: 6-31. |
| **0x13810** | **0x17C** | **PlaneStride**| `this + 0x230` | **PlaneStride**: 6-31. |
| **0x13814** | **0x180** | **DepthStride**| `this + 0x234` | **Stride**: 6-31. |
| **0x13818** | **0x184** | **GroupStride**| `this + 0x238` | **Stride**: 6-31. |
| **0x1381C..** | **0x188..0x1A0** | *pad3[7]* | `this + 0x23C..0x258` | - |
| **0x138A4** | **0x1A4** | **Fmt** | `this + 0x25C` | **FmtMode**: 0-1, **Truncate**: 4-5, **Shift**: 8, **MemFmt**: 12-13, **OffsetCh**: 16-18, **Interleave**: 24-27, **CmpVec**: 28-31. |
| **0x138A8..** | **0x1A8..0x1B8** | *pad4[5]* | `this + 0x260..0x270` | - |
| **0x138BC-0x138C8**| **0x1BC-0x1C8**| **PixelOffset[4]**| `this + 0x274..0x280` | **Offset**: 0-15. |
| **0x138CC..** | **0x1CC..0x1F4** | *pad5[11]* | `this + 0x284..0x2D0` | - |

### L2 Block (TD 0x1E0)
Source: `this + 0x294`
Base HW Addr: `0x4800`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x4800** | **0x1E0** | **L2Cfg** | `this + 0x294` | **InputReLU**: 0, **PaddingMode**: 1-2. |
| **0x4804** | **0x1E4** | **SourceCfg** | `this + 0x298` | **SourceType**: 0-1, **Dependent**: 2-3, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **DMAFmt**: 6-7, **DMAInterleave**: 8-11, **DMACmpVec**: 12-15, **DMAOffsetCh**: 16-18, **AliasPlanarSrc**: 20, **AliasPlanarRslt**: 22. |
| **0x4808** | **0x1E8** | **SourceBase**| `this + 0x29C` | **Addr**: 4-20. |
| **0x480C** | **0x1EC** | **SourceChannelStride**| `this + 0x2A0` | **Stride**: 4-20. |
| **0x4810** | **0x1F0** | **SourceRowStride** | `this + 0x2A4` | **Stride**: 4-20. |
| **0x4814-0x482C**| **0x1F4-0x20C**| *pad3[7]* | `this + 0x2A8..0x2C0` | - |
| **0x4830** | **0x210** | **ResultCfg** | `this + 0x2C4` | **ResultType**: 0-1, **L2BfrMode**: 2-3, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **DMAFmt**: 6-7, **DMAInterleave**: 8-11, **DMACmpVec**: 12-15, **DMAOffsetCh**: 16-18, **AliasPlanarSrc**: 20, **AliasPlanarRslt**: 22. |
| **0x4834** | **0x214** | **ResultBase**| `this + 0x2C8` | **Addr**: 4-20. |
| **0x4838** | **0x218** | **ConvResultChannelStride** | `this + 0x2CC` | **Stride**: 4-20. |
| **0x483C** | **0x21C** | **ConvResultRowStride** | `this + 0x2D0` | **Stride**: 4-20. |

### PE Block (TD 0x22C)
Source: `this + 0x2E8`
Base HW Addr: `0x8800`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x8800** | **0x22C** | **Cfg** | `this + 0x2E8` | **En**: 1, **OpMode**: 2-4, **ReluEn**: 5, **Cond**: 6, **FirstSrc**: 16, **SecSrc**: 18-19. |
| **0x8804** | **0x230** | **BiasScale**| `this + 0x2EC` | **Bias**: 0-15, **Scale**: 16-31. |
| **0x8808** | **0x234** | **PreScale** | `this + 0x2F0` | **PreScale**: 0-15. |
| **0x880C** | **0x238** | **FinalScale**| `this + 0x2F4` | **FinalScale**: 0-31. |

### NE Block (TD 0x240)
Source: `this + 0x300`
Base HW Addr: `0xC800`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0xC800** | **0x240** | **KernelCfg** | `this + 0x300` | **KernelFmt**: 0-1, **PallettizedEn**: 2, **PallettizeBits**: 4-7, **SparseFmt**: 8, **GroupKenelReuse**: 10. |
| **0xC804** | **0x244** | **MACCfg** | `this + 0x304` | **OpMode**: 0-3, **KernelMode**: 4, **BiasMode**: 5, **MatrixBiasEn**: 7, **BinaryPoint**: 9-12, **PostScaleMode**: 14, **NonlinearMode**: 16-17. |
| **0xC808** | **0x248** | **MatrixVectorBias**| `this + 0x308` | **MatrixVectorBias**: 0-15. |
| **0xC80C** | **0x24C** | **AccBias** | `this + 0x30C` | **AccBias**: 0-15, **AccBiasShift**: 16-20. |
| **0xC810** | **0x250** | **PostScale** | `this + 0x310` | **PostScale**: 0-15, **PostScaleRightShift**: 16-20. |

### TileDMADst Block (TD 0x258)
Source: `this + 0x31C`
Base HW Addr: `0x17800`

| HW Addr | TD Offset | Register Name | Object Offset | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x17800** | **0x258** | **DMAConfig** | `this + 0x31C` | **EN**: 0, **CacheHint**: 4-7, **L2BfrMode**: 24, **BypassEOW**: 25. |
| **0x17804** | **0x25C** | **BaseAddr** | `this + 0x320` | **Addr**: 6-31. |
| **0x17808** | **0x260** | **RowStride** | `this + 0x324` | **Stride**: 6-31. |
| **0x1780C** | **0x264** | **PlaneStride**| `this + 0x328` | **PlaneStride**: 6-31. |
| **0x17810** | **0x268** | **DepthStride**| `this + 0x32C` | **Stride**: 6-31. |
| **0x17814** | **0x26C** | **GroupStride**| `this + 0x330` | **Stride**: 6-31. |
| **0x17818** | **0x270** | **Fmt** | `this + 0x334` | **FmtMode**: 0-1, **Truncate**: 4-5, **Shift**: 8, **MemFmt**: 12-13, **OffsetCh**: 16-18, **ZeroPadLast**: 20, **ZeroPadFirst**: 21, **CmpVecFill**: 22, **Interleave**: 24-27, **CmpVec**: 28-31. |

---
*Note: This architecture is simpler and flatter than M4, utilizing far fewer registers overall and relying strictly on direct object-to-TD offset copying within the `ProcessRegisters` routine.*
