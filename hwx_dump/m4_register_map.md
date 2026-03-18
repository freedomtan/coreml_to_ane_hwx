## Object-to-Hardware Mapping Blocks

The `ZinAneTd<17u>` object maps internal offsets to hardware register blocks as follows:

| Source Offset (`this`) | Reg Count (Words) | HW Start Address | HW End Address (approx) | Primary Feature Area |
| :--- | :--- | :--- | :--- | :--- |
| `+0x1f8` | `0x17` | `0x0000` | `0x005C` | Common (InDim, OutDim, Patch, PETra) |
| `+0x3a8` | `0x29` | `0x4100` | `0x41A4` | L2 Cache / Buffer |
| `+0x454` | `0xf` | `0x4500` | `0x453C` | PE (Planar Engine) |
| `+0x498` | `0xc` | `0x4900` | `0x4930` | NE (Neural Engine) |
| `+0x25c` | `0x51` | `0x4d00` | `0x4E44` | TileDmaSrc (Engine Control) |
| `+0x4d0` | `0x15` | `0x5100` | `0x5154` | TileDmaDst (Engine Control) |
| `+0x030` | `0x48` | `0x5500` | `0x5620` | KernelDmaSrc (Stride, Coeffs) |
| `+0x52c` | `0x0c` | `0x5900` | `0x5930` | CacheDMA & Telemetry |

Before registers, there are some header words.

| Source Offset (`this`) | Name | Description | Note |
| :--- | :--- | :--- | :--- |
| `+0x008` | `TID / TaskSize` | **TID**: 0-15, **TaskSize**: 16-26. | Headers[0] |
| `+0x00c` | `ExeCycles` | **ExeCycles**: 0-16. | Headers[1] |
| `+0x010` | `LogEvents` | **LogEvents**: 0-23. | Headers[2] |
| `+0x014` | `Exceptions` | **Exceptions**: 0-23. | Headers[3] |
| `+0x018` | `DebugLogEvents`| **DebugLogEvents**: 0-23. | Headers[4] |
| `+0x01c` | `DebugExceptions`| **DebugExceptions**: 0-23. | Headers[5] |
| `+0x020` | `LiveOuts` | **LiveOuts**: 0-23. | Headers[6] |
| `+0x024` | `UnknownFlags` | Full 32-bit flags overwrite. | Headers[7] |
| `+0x028` | `Control Flags`| **TSR**: 0, **TDE**: 1, **Unknown**: 3, **ENE**: 16-18. | Headers[8] |
| `+0x02c` | `DTID` | **DTID**: 0-15. | Headers[9] |

## Register Offsets and Meanings

| Word Index | Byte Offset | Name | Description |
| :--- | :--- | :--- | :--- |
| **0** | `0x00` | **ChannelCfg** | **InFmt**: 0-1, **OutFmt**: 4-5. |
| **1** | `0x04` | **InWidth** | **Win**: 0-13. |
| **2** | `0x08` | **InHeight** | **Hin**: 0-13. |
| **3** | `0x0C` | **InChannels** | **Cin**: 0-13. |
| **4** | `0x10` | **InDepth** | **Din**: 0-13. |
| **5** | `0x14` | **OutWidth** | **Wout**: 0-13. |
| **6** | `0x18` | **OutHeight** | **Hout**: 0-13. |
| **7** | `0x1C` | **OutChannels** | **Cout**: 0-13. |
| **8** | `0x20` | **OutDepth** | **Dout**: 0-13. |
| **9** | `0x24` | **Batch** | **Batch**: 0-31. |
| **10** | `0x28` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PX**: 17-21, **PY**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **11** | `0x2C` | **ConvCfg3d** | **KD**: 0-5, **SZ**: 6-11, **PZ**: 12-16, **OZ**: 17-21. |
| ... | ... | ... | ... |
| **0x1240** | `0x4900` | **KernelCfg** | **KernelFmt**: 0-1, **SparseEn**: 8, **PalEn**: 2. |
| **0x1241** | `0x4904` | **MACCfg** | **OpMode**: 0-2, **KernelMode**: 3. |
| **0x1546** | `0x5518` | **KernelStrideX** | **StrideX**: 6-31. |
| **0x1547** | `0x551C` | **KernelStrideY** | **StrideY**: 6-31. |

## Internal Object Blocks
The `ZinAneTd<17u>` object (descriptor) is divided into these hardware-mapped regions:
- **Common (0x0000)**: Generic geometry, patch size, OCG size, and primary convolution config.
- **L2 Cache (0x4100)**: L2 buffer strides and wrap offsets.
- **PE (0x4500)**: Processing Element (Bias, Quantization, Pooling).
- **NE (0x4900)**: Neural Engine core config (BinaryPoint, KernelMode, OpMode).
- **TileDmaSrc (0x4D00)**: Tile DMA Source configurations.
- **TileDmaDst (0x5100)**: Tile DMA Destination configurations.
- **KernelDmaSrc (0x5500)**: Stride, coefficients, and sparse control.
- **CacheDMA (0x5900)**: Telemetry and task synchronization.

## Detailed Bitfield Mappings

### KernelDmaSrc (0x5500 block, Object `+0x030`)
- **Count**: 72 registers (`0x48` words, `0x120` bytes).
- **Object Layout**: Starts at `+0x030` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x030` | **MasterConfig** | **MasterEnable**: 6, **KernelSparseFmt**: 8, **GroupKernelReuse**: 10. (Inferred from setters) |
| **0x5504** | `+0x034` | **AlignedCoeffSizePerCh** | **Size**: 0-31. |
| **0x5508** | `+0x038` | **Prefetch** | **EarlyTermEn**: 0, **StopOnError**: 1, **PrefetchRate**: 16-31. |
| **0x550C** | `+0x03c` | **Reserved0** | Reserved. |
| **0x5510** | `+0x040` | **Reserved1** | Reserved. |
| **0x5514** | `+0x044` | **Reserved2** | Reserved. |
| **0x5518** | `+0x048` | **StrideX** | **Stride**: 6-31. |
| **0x551C** | `+0x04c` | **StrideY** | **Stride**: 6-31. |
| **0x5520** | `+0x050` | **CoeffDMAConfig0**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5524** | `+0x054` | **CoeffDMAConfig1**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5528** | `+0x058` | **CoeffDMAConfig2**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x552C** | `+0x05c` | **CoeffDMAConfig3**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5530** | `+0x060` | **CoeffDMAConfig4**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5534** | `+0x064` | **CoeffDMAConfig5**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5538** | `+0x068` | **CoeffDMAConfig6**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x553C** | `+0x06c` | **CoeffDMAConfig7**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5540** | `+0x070` | **CoeffDMAConfig8**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5544** | `+0x074` | **CoeffDMAConfig9**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5548** | `+0x078` | **CoeffDMAConfig10**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x554C** | `+0x07c` | **CoeffDMAConfig11**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5550** | `+0x080` | **CoeffDMAConfig12**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5554** | `+0x084` | **CoeffDMAConfig13**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5558** | `+0x088` | **CoeffDMAConfig14**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x555C** | `+0x08c` | **CoeffDMAConfig15**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5560** | `+0x090` | **CoeffBaseAddr0** | **Addr**: 6-31. |
| **0x5564** | `+0x094` | **CoeffBaseAddr1** | **Addr**: 6-31. |
| **0x5568** | `+0x098` | **CoeffBaseAddr2** | **Addr**: 6-31. |
| **0x556C** | `+0x09c` | **CoeffBaseAddr3** | **Addr**: 6-31. |
| **0x5570** | `+0x0a0` | **CoeffBaseAddr4** | **Addr**: 6-31. |
| **0x5574** | `+0x0a4` | **CoeffBaseAddr5** | **Addr**: 6-31. |
| **0x5578** | `+0x0a8` | **CoeffBaseAddr6** | **Addr**: 6-31. |
| **0x557C** | `+0x0ac` | **CoeffBaseAddr7** | **Addr**: 6-31. |
| **0x5580** | `+0x0b0` | **CoeffBaseAddr8** | **Addr**: 6-31. |
| **0x5584** | `+0x0b4` | **CoeffBaseAddr9** | **Addr**: 6-31. |
| **0x5588** | `+0x0b8` | **CoeffBaseAddr10** | **Addr**: 6-31. |
| **0x558C** | `+0x0bc` | **CoeffBaseAddr11** | **Addr**: 6-31. |
| **0x5590** | `+0x0c0` | **CoeffBaseAddr12** | **Addr**: 6-31. |
| **0x5594** | `+0x0c4` | **CoeffBaseAddr13** | **Addr**: 6-31. |
| **0x5598** | `+0x0c8` | **CoeffBaseAddr14** | **Addr**: 6-31. |
| **0x559C** | `+0x0cc` | **CoeffBaseAddr15** | **Addr**: 6-31. |
| **0x55A0** | `+0x0d0` | **CoeffBfrSize0** | **Size**: 0-31. |
| **0x55A4** | `+0x0d4` | **CoeffBfrSize1** | **Size**: 0-31. |
| **0x55A8** | `+0x0d8` | **CoeffBfrSize2** | **Size**: 0-31. |
| **0x55AC** | `+0x0dc` | **CoeffBfrSize3** | **Size**: 0-31. |
| **0x55B0** | `+0x0e0` | **CoeffBfrSize4** | **Size**: 0-31. |
| **0x55B4** | `+0x0e4` | **CoeffBfrSize5** | **Size**: 0-31. |
| **0x55B8** | `+0x0e8` | **CoeffBfrSize6** | **Size**: 0-31. |
| **0x55BC** | `+0x0ec` | **CoeffBfrSize7** | **Size**: 0-31. |
| **0x55C0** | `+0x0f0` | **CoeffBfrSize8** | **Size**: 0-31. |
| **0x55C4** | `+0x0f4` | **CoeffBfrSize9** | **Size**: 0-31. |
| **0x55C8** | `+0x0f8` | **CoeffBfrSize10** | **Size**: 0-31. |
| **0x55CC** | `+0x0fc` | **CoeffBfrSize11** | **Size**: 0-31. |
| **0x55D0** | `+0x100` | **CoeffBfrSize12** | **Size**: 0-31. |
| **0x55D4** | `+0x104` | **CoeffBfrSize13** | **Size**: 0-31. |
| **0x55D8** | `+0x108` | **CoeffBfrSize14** | **Size**: 0-31. |
| **0x55DC** | `+0x10c` | **CoeffBfrSize15** | **Size**: 0-31. |
| **0x55E0** | `+0x110` | **BiasDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x55E4** | `+0x114` | **BiasBaseAddr** | **Addr**: 6-31. |
| **0x55E8** | `+0x118` | **BiasReserved0** | Reserved. |
| **0x55EC** | `+0x11c` | **BiasReserved1** | Reserved. |
| **0x55F0** | `+0x120` | **PostScaleDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x55F4** | `+0x124` | **PostScaleBaseAddr** | **Addr**: 6-31. |
| **0x55F8** | `+0x128` | **PostScaleReserved0**| Reserved. |
| **0x55FC** | `+0x12c` | **PostScaleReserved1**| Reserved. |
| **0x5600** | `+0x130` | **PaletteDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5604** | `+0x134` | **PaletteBaseAddr** | **Addr**: 6-31. |
| **0x5608** | `+0x138` | **PaletteReserved0** | Reserved. |
| **0x560C** | `+0x13c` | **PaletteReserved1** | Reserved. |
| **0x5610** | `+0x140` | **NLutDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5614** | `+0x144` | **NLutBaseAddr** | **Addr**: 6-31. |
| **0x5618** | `+0x148` | **NLutReserved0** | Reserved. |
| **0x561C** | `+0x14c` | **NLutReserved1** | Reserved. |

### Common (0x0000 block, Object `+0x1f8`)
- **Count**: 23 registers (`0x17` words, `0x5c` bytes).
- **Object Layout**: Starts at `+0x1f8` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x1f8` | **ChannelCfg** | **InFmt**: 0-1, **Src2InFmt**: 2-3, **OutFmt**: 4-5. |
| **0x0004** | `+0x1fc` | **InWidth** | **Win**: 0-16. |
| **0x0008** | `+0x200` | **InHeight** | **Hin**: 0-16. |
| **0x000C** | `+0x204` | **InChannels** | **Cin**: 0-16. |
| **0x0010** | `+0x208` | **InDepth** | **Din**: 0-16. |
| **0x0014** | `+0x20c` | **OutWidth** | **Wout**: 0-16. |
| **0x0018** | `+0x210` | **OutHeight** | **Hout**: 0-16. |
| **0x001C** | `+0x214` | **OutChannels** | **Cout**: 0-16. |
| **0x0020** | `+0x218` | **OutDepth** | **Dout**: 0-16. |
| **0x0024** | `+0x21c` | **NumGroups** | Batch size / Number of groups. |
| **0x0028** | `+0x220` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PadLeft**: 17-21, **PadTop**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **0x002C** | `+0x224` | **ConvCfg3d** | **3dKd**: 0-4, **3dSz**: 6-7, **3dPz**: 8-11, **3dOz**: 13-14. |
| **0x0030** | `+0x228` | **UnicastCfg** | **UnicastEn**: 14, **UnicastCin**: 16-31. |
| **0x0034** | `+0x22c` | **TileHeight** | **TileHeight**: 0-16. |
| **0x0038** | `+0x230` | **TileOverlap** | **Overlap**: 16-20, **PadTop**: 21-25, **PadBottom**: 26-30. |
| **0x003C** | `+0x234` | **MacCfg** | **SmallSrcMode**: 2-3, **TaskType**: 4-7, **ActiveNE**: 19-21, **OutTranspose**: 28, **FillLowerNEFirst**: 29. |
| **0x0040** | `+0x238` | **NECfg** | **OCGSize**: 0-2 (1=16, 2=32, 4=64), **FatTileEnable**: 3, **WUStackLog2**: 4-5. |
| **0x0044** | `+0x23c` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x240` | **PECfg** | **Src1Broadcast**: 0-3 (W:0, H:1, D:2, C:3), **Src2Broadcast**: 4-7 (W:4, H:5, D:6, C:7), **Src1Transpose**: 8, **Src2Transpose**: 9, **OutputCtoW**: 10. |
| **0x004C** | `+0x244` | **NID** | Network ID / Layer Trace ID. |
| **0x0050** | `+0x248` | **DPE** | Distributed Processing Element config. |

*Note: M4 drops `ChannelDmaLength` and several M1 properties. E4M3Overflow and TextureBypassFilter are explicitly unsupported in the binary.*

*Compiler Sub-Struct Note (`ZinAneTdHw_v17`)*: The `ZinGetRegisterProgramming<17u>` getters map directly onto our Common Block layout with a `+0x8` descriptor header offset.

### TileDMA Source (0x4D00 block, Object `+0x25c`)
- **Count**: 81 registers (`0x51` words, `0x144` bytes).
- **Object Layout**: Starts at `+0x25c` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4D00** | `+0x25c` | **Src1DMAConfig** | **Enable**: 0, **DataSetId**: 8-15, **UserTag**: 16-23, **DependencyInterval**: 24-27. |
| **0x4D04** | `+0x260` | **Src2DMAConfig** | **Enable**: 0, **DataSetId**: 8-15, **UserTag**: 16-23, **DependencyInterval**: 24-27. |
| **0x4D08** | `+0x264` | **Src1WrapCfg** | **CacheHint**: 0-7 (strb), **WrapCfg**: 8-10, **WrapStatic**: 16-31. |
| **0x4D0C** | `+0x268` | **Src2WrapCfg** | **CacheHint**: 0-7, **WrapCfg**: 8-10, **WrapStatic**: 16-31. |
| **0x4D10** | `+0x26c` | **Src1BaseAddrLo** | **AddrLo**: 0-31. |
| **0x4D14** | `+0x270` | **Src1BaseAddrHi** | **AddrHi**: 0-31. |
| **0x4D18** | `+0x274` | **Src1RowStride** | **Stride**: 6-31. |
| **0x4D1C** | `+0x278` | **Src1ChannelStride** | **Stride**: 6-31. |
| **0x4D20** | `+0x27c` | **Src1DepthStride** | **Stride**: 6-31. |
| **0x4D24** | `+0x280` | **Src1GroupStride** | **Stride**: 6-31. |
| **0x4D28** | `+0x284` | **Src2BaseAddrLo** | **AddrLo**: 0-31. |
| **0x4D2C** | `+0x288` | **Src2BaseAddrHi** | **AddrHi**: 0-31. |
| **0x4D30** | `+0x28c` | **Src2RowStride** | **Stride**: 6-31. |
| **0x4D34** | `+0x290` | **Src2ChannelStride** | **Stride**: 6-31. |
| **0x4D38** | `+0x294` | **Src2DepthStride** | **Stride**: 6-31. |
| **0x4D3C** | `+0x298` | **Src2GroupStride** | **Stride**: 6-31. |
| **0x4D40** | `+0x29c` | **Src1MetaDataAddrLo** | **AddrLo**: 0-31. |
| **0x4D44** | `+0x2a0` | **Src1MetaDataAddrHi** | **AddrHi**: 0-31. |
| **0x4D48** | `+0x2a4` | **Src2MetaDataAddrLo** | **AddrLo**: 0-31. |
| **0x4D4C** | `+0x2a8` | **Src2MetaDataAddrHi** | **AddrHi**: 0-31. |
| **0x4D50** | `+0x2ac` | **Src1MetaDataConfig** | *(No direct 17u setter found; may be configured via MetaData helper)* |
| **0x4D54** | `+0x2b0` | **Src1MetaUnknown1** | *(No direct 17u setter found)* |
| **0x4D58** | `+0x2b4` | **Src1MetaDataSize** | **Size**: 7-31. |
| **0x4D5C** | `+0x2b8` | **Src2MetaDataConfig** | *(No direct 17u setter found; may be configured via MetaData helper)* |
| **0x4D60** | `+0x2bc` | **Src2MetaUnknown1** | *(No direct 17u setter found)* |
| **0x4D64** | `+0x2c0` | **Src2MetaDataSize** | **Size**: 7-31. |
| **0x4D68** | `+0x2c4` | **Src1FmtMode** | **OffsetCh**: 16-18, **Interleave**: 24-27, **CmpVec**: 28-31. |
| **0x4D6C** | `+0x2c8` | **Src2FmtMode** | **OffsetCh**: 16-18, **Interleave**: 24-27, **CmpVec**: 28-31. |
| **0x4D70** | `+0x2cc` | **TileDmaSrcReserved** |  |
| **0x4D74** | `+0x2d0` | **TileDmaSrcReserved** |  |
| **0x4D78** | `+0x2d4` | **Src1CompressedInfo** | **MdUserTag**: 24-31. |
| **0x4D7C** | `+0x2d8` | **Src1CompressedSizeLo** | **SizeLo**: 0-31. |
| **0x4D80** | `+0x2dc` | **Src1CompressedSizeHi** | **SizeHi**: 0-31. |
| **0x4D84** | `+0x2e0` | **Src1CropOffset** | **OffsetY**: 0-15 (strh), **CropOffset**: 16-31. |
| **0x4D88** | `+0x2e4` | **Src2CompressedInfo** | **MdUserTag**: 24-31. |
| **0x4D8C** | `+0x2e8` | **Src2CompressedSizeLo** | **SizeLo**: 0-31. |
| **0x4D90** | `+0x2ec` | **Src2CompressedSizeHi** | **SizeHi**: 0-31. |
| **0x4D94** | `+0x2f0` | **Src2CropOffset** | **OffsetY**: 0-15 (strh), **CropOffset**: 16-31. |
| **0x4D98** | `+0x2f4` | **TileDmaSrcReserved** |  |
| **0x4D9C** | `+0x2f8` | **TileDmaSrcReserved** |  |
| **0x4DA0** | `+0x2fc` | **TileDmaSrcReserved** |  |
| **0x4DA4** | `+0x300` | **TileDmaSrcReserved** |  |
| **0x4DA8** | `+0x304` | **TileDmaSrcReserved** |  |
| **0x4DAC** | `+0x308` | **TileDmaSrcReserved** |  |
| **0x4DB0** | `+0x30c` | **TileDmaSrcReserved** |  |
| **0x4DB4** | `+0x310` | **TileDmaSrcReserved** |  |
| **0x4DB8** | `+0x314` | **Src1WrapDynamic** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. (Dimension Y alternate; see Src1WrapCfg for X) |
| **0x4DBC** | `+0x318` | **Src2WrapDynamic** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. (Dimension Y alternate; see Src2WrapCfg for X) |
| **0x4DC0** | `+0x31c` | **Src1DependencyOffset** | **Offset**: 0-31. (Also encodes dependency period/interval for DRAM-dependent mode) |
| **0x4DC4** | `+0x320` | **Src2DependencyOffset** | **Offset**: 0-31. (Also encodes Src2 dependency period/interval for DRAM-dependent mode) |
| **0x4DC8** | `+0x324` | **TextureMode** | **Mode**: 0-31. (No dedicated 17u setter; may share config with DependencyMode path) |
| **0x4DCC** | `+0x328` | **TextureIdxPermute** | **Permute**: 0-31. |
| **0x4DD0** | `+0x32c` | **TextureSrcPermute** | **Permute**: 0-31. |
| **0x4DD4** | `+0x330` | **TextureBackgroundVal** | **Value**: 0-31. |
| **0x4DD8** | `+0x334` | **TileDmaSrcReserved** |  |
| **0x4DDC** | `+0x338` | **TileDmaSrcReserved** |  |
| **0x4DE0** | `+0x33c` | **TileDmaSrcReserved** |  |
| **0x4DE4** | `+0x340` | **TileDmaSrcReserved** |  |
| **0x4DE8** | `+0x344` | **TileDmaSrcReserved** |  |
| **0x4DEC** | `+0x348` | **TileDmaSrcReserved** |  |
| **0x4DF0** | `+0x34c` | **TileDmaSrcReserved** |  |
| **0x4DF4** | `+0x350` | **TileDmaSrcReserved** |  |
| **0x4DF8** | `+0x354` | **TileDmaSrcReserved** |  |
| **0x4DFC** | `+0x358` | **TileDmaSrcReserved** |  |
| **0x4E00** | `+0x35c` | **TileDmaSrcReserved** |  |
| **0x4E04** | `+0x360` | **TileDmaSrcReserved** |  |
| **0x4E08** | `+0x364` | **TileDmaSrcReserved** |  |
| **0x4E0C** | `+0x368` | **TileDmaSrcReserved** |  |
| **0x4E10** | `+0x36c` | **TileDmaSrcReserved** |  |
| **0x4E14** | `+0x370` | **TileDmaSrcReserved** |  |
| **0x4E18** | `+0x374` | **TileDmaSrcReserved** |  |
| **0x4E1C** | `+0x378` | **TileDmaSrcReserved** |  |
| **0x4E20** | `+0x37c` | **TileDmaSrcReserved** |  |
| **0x4E24** | `+0x380` | **TileDmaSrcReserved** |  |
| **0x4E28** | `+0x384` | **TileDmaSrcReserved** |  |
| **0x4E2C** | `+0x388` | **TileDmaSrcReserved** |  |
| **0x4E30** | `+0x38c` | **TileDmaSrcReserved** |  |
| **0x4E34** | `+0x390` | **TileDmaSrcReserved** |  |
| **0x4E38** | `+0x394` | **TileDmaSrcReserved** |  |
| **0x4E3C** | `+0x398` | **TileDmaSrcReserved** |  |
| **0x4E40** | `+0x39c` | **TileDmaSrcReserved** |  |

### L2 Cache / Buffer (0x4100 block, Object `+0x3a8`)
- **Count**: 41 registers (`0x29` words, `0xA4` bytes).
- **Object Layout**: Starts at `+0x3a8` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3a8` | **Control** | **Src1ReLU**: 0, **PaddingMode**: 2-3, **Src2ReLU**: 4, **Barrier**: 16. |
| **0x4104** | `+0x3ac` | **Src1Cfg** | **Type**: 0-1, **Dependent**: 2-3, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **Format**: 6-7, **Interleave**: 8-11, **AliasPlanarSrc**: 20, **AliasPlanarRslt**: 22, **Compression**: 25-26. |
| **0x4108** | `+0x3b0` | **Src2Cfg** | **Type**: 0-1, **Dependent**: 2-3, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **Format**: 6-7, **Interleave**: 8-11, **AliasPlanarSrc**: 20, **AliasPlanarRslt**: 22, **Compression**: 25-26. |
| **0x410C** | `+0x3b4` | **SrcIdxCfg** | **Type**: 0-1, **Dependent**: 2-3, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **Format**: 6-7, **Interleave**: 8-11, **AliasPlanarSrc**: 20, **AliasPlanarRslt**: 22, **Bit27**: 27. |
| **0x4110** | `+0x3b8` | **Src1Base** | **Addr**: 4-20 (16B units). |
| **0x4114** | `+0x3bc` | **Src1ChannelStride**| **Stride**: 4-20 (16B units). |
| **0x4118** | `+0x3c0` | **Src1RowStride** | **Stride**: 4-20 (16B units). |
| **0x411C** | `+0x3c4` | **Src1DepthStride** | **Stride**: 4-20 (16B units). |
| **0x4120** | `+0x3c8` | **Src1GroupStride** | **Stride**: 4-20 (16B units). |
| **0x4124** | `+0x3cc` | **Src2Base** | **Addr**: 4-20 (16B units). |
| **0x4128** | `+0x3d0` | **Src2ChannelStride**| **Stride**: 4-20 (16B units). |
| **0x412C** | `+0x3d4` | **Src2RowStride** | **Stride**: 4-20 (16B units). |
| **0x4130** | `+0x3d8` | **Src2DepthStride** | **Stride**: 4-20 (16B units). |
| **0x4134** | `+0x3dc` | **Src2GroupStride** | **Stride**: 4-20 (16B units). |
| **0x4138** | `+0x3e0` | **SrcIdxBase** | **Addr**: 4-20 (16B units). |
| **0x413C** | `+0x3e4` | **SrcIdxChannelStride**| **Stride**: 4-20 (16B units). |
| **0x4140** | `+0x3e8` | **SrcIdxDepthStride** | **Stride**: 4-20 (16B units). |
| **0x4144** | `+0x3ec` | **SrcIdxGroupStride** | **Stride**: 4-20 (16B units). |
| **0x4148** | `+0x3f0` | **ResultCfg** | **Type**: 0-1, **Format**: 6-7, **Interleave**: 8-11, **Compression**: 25-26. |
| **0x414C** | `+0x3f4` | **ResultBase** | **Addr**: 4-20 (16B units). |
| **0x4150** | `+0x3f8` | **ResultChannelStride**| **Stride**: 4-20 (16B units). |
| **0x4154** | `+0x3fc` | **ResultRowStride** | **Stride**: 4-20 (16B units). |
| **0x4158** | `+0x400` | **ResultDepthStride**| **Stride**: 4-20 (16B units). |
| **0x415C** | `+0x404` | **ResultGroupStride**| **Stride**: 4-20 (16B units). |
| **0x4160** | `+0x408` | **L2Reserved** |  |
| **0x4164** | `+0x40c` | **SrcAndResultWrapCfg** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x4168** | `+0x410` | **Src1WrapStart** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x416C** | `+0x414` | **Src2WrapStart** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x4170** | `+0x418` | **L2Reserved** |  |
| **0x4174** | `+0x41c` | **ResultWrapStart**| **IndexMask**: 0-3, **StartOffset**: 4-15. |
| **0x4178** | `+0x420` | **MiscField0x4178** |  |
| **0x417C** | `+0x424` | **MiscField0x417C** |  |
| **0x4180** | `+0x428` | **MiscField0x4180** |  |
| **0x4184** | `+0x42c` | **MiscField0x4184** |  |
| **0x4188** | `+0x430` | **MiscField0x4188** |  |
| **0x418C** | `+0x434` | **PEIndexCfg** | **Transpose**: 0, **Mode**: 1, **MaxIndex**: 16-31. |
| **0x4190** | `+0x438` | **Src1AddrWrap** |  |
| **0x4194** | `+0x43c` | **Src2AddrWrap** |  |
| **0x4198** | `+0x440` | **L2Reserved** |  |
| **0x419C** | `+0x444` | **ResultWrapAddr** |  |
| **0x41A0** | `+0x448` | **CropOffsetTexture** | **Src1X**: 0-5, **Src1Y**: 8-12, **Src2X**: 16-21, **Src2Y**: 24-28. |

### Planar Engine (PE) (0x4500 block, Object `+0x454`)
- **Count**: 15 registers (`0x0f` words, `0x3c` bytes).
- **Object Layout**: Starts at `+0x454` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4500** | `+0x454` | **Config** | **Op**: 2-4 (1:Add, 2:Mul, 3:Min, 4:Max), **LUTEnable**: 5, **Cond**: 6-8, **Src1Selection**: 16, **Src2Selection**: 18-19. |
| **0x4504** | `+0x458` | **Bias** | 19-bit Floating Point (F19) bias value (Bits 0-18). |
| **0x4508** | `+0x45c` | **Scale** | 19-bit Floating Point (F19) scale value (Bits 0-18). |
| **0x4510** | `+0x464` | **PreScale** | 19-bit Floating Point (F19) pre-scale value (Bits 0-18). |
| **0x4514** | `+0x468` | **FinalScale** | 19-bit Floating Point (F19) final scale value (Bits 0-18). |
| **0x4518** | `+0x46c` | **LUT1** | Piecewise Linear LUT Parameter. |
| **0x4520** | `+0x474` | **LUT2** | Piecewise Linear LUT Parameter. |
| **0x4524** | `+0x478` | **LUT3** | Piecewise Linear LUT Parameter. |
| **0x4528** | `+0x47c` | **LUT4** | Piecewise Linear LUT Parameter. |
| **0x4530** | `+0x484` | **LUT5** | Piecewise Linear LUT Parameter. |
| **0x4534** | `+0x488` | **LUT6** | Piecewise Linear LUT Parameter. |
| **0x4538** | `+0x48c` | **Quant** | **Src1InputOffset**: 0-7, **Src2InputOffset**: 8-15, **OutputZeroPoint**: 16-23. |

### Neural Engine (NE) (0x4900 block, Object `+0x498`)
- **Count**: 12 registers (`0x0c` words, `0x30` bytes).
- **Object Layout**: Starts at `+0x498` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x498` | **KernelCfg** | **KernelFmt**: 0-1, **PalEn**: 2, **PalBits**: 4-7, **SparseEn**: 8, **GroupKernelReuse**: 10, **SparseBinary**: 15, **AsymQuantEn**: 24. |
| **0x4904** | `+0x49c` | **MACCfg** | **OpMode**: 0-2 (0:Conv, 1:MatMul, 2:EWise, 3:XCorr), **KernelMode**: 3, **BiasEnable**: 4, **PassthroughEnable**: 5, **MatrixVectorBiasEnable**: 6, **BinaryPoint**: 8-13, **PostScaleEnable**: 14, **NonlinearMode**: 16-17, **MaxPoolMode**: 19, **ArgOutputSelect**: 20-23, **DoubleInt8Enable**: 26. |
| **0x4908** | `+0x4a0` | **MatrixVectorBias**| **Bias**: 0-15. |
| **0x490C** | `+0x4a4` | **NEBias** | **Bias**: 0-20 (F19/F21). |
| **0x4910** | `+0x4a8` | **NEPostScale** | **PostScale**: 0-20 (F19/F21). |
| **0x4914** | `+0x4ac` | **RcasConfig** | **KeyMask**: 0-7, **CmpBit**: 8-10, **SenseAxis**: 12-13, **SenseBit**: 16-19, **RcasMode**: 20. |
| **0x4918** | `+0x4b0` | **RoundModeCfg** | **StochasticRoundMode**: 0-1, **StochasticRoundIntegerBits**: 4-8. |
| **0x491C** | `+0x4b4` | **SRSeed[0]**| **Seed**: 0-31. |
| **0x4920** | `+0x4b8` | **SRSeed[1]**| **Seed**: 0-31. |
| **0x4924** | `+0x4bc` | **SRSeed[2]**| **Seed**: 0-31. |
| **0x4928** | `+0x4c0` | **SRSeed[3]**| **Seed**: 0-31. |
| **0x492C** | `+0x4c4` | **QuantZeroPoint** | **ZeroPoint**: 0-7. |

### TileDMA Destination (0x5100 block, Object `+0x4d0`)
- **Count**: 21 registers (`0x15` words, `0x54` bytes).
- **Object Layout**: Starts at `+0x4d0` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5100** | `+0x4d0` | **DstDMAConfig** | **Enable**: 0, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5104** | `+0x4d4` | **DstPadding** | Reserved / Padding Mode. |
| **0x5108** | `+0x4d8` | **DstBaseAddrLo** | **AddrLo**: 0-31. |
| **0x510C** | `+0x4dc` | **DstBaseAddrHi** | **AddrHi**: 0-31. |
| **0x5110** | `+0x4e0` | **DstRowStride** | **Stride**: 6-31. |
| **0x5114** | `+0x4e4` | **DstPlaneStride** | **Stride**: 6-31. |
| **0x5118** | `+0x4e8` | **DstDepthStride** | **Stride**: 6-31. |
| **0x511C** | `+0x4ec` | **DstGroupStride** | **Stride**: 6-31. |
| **0x5120** | `+0x4f0` | **DstInternalCfg**| **InternalBits**: 0-15, **Flag1**: 16, **Flag2**: 17, **Flag3**: 18. |
| **0x5124** | `+0x4f4` | **DstReserved1** | Unknown. |
| **0x5128** | `+0x4f8` | **DstMetaDataAddrLo**| **AddrLo**: 0-31. |
| **0x512C** | `+0x4fc` | **DstMetaDataAddrHi**| **AddrHi**: 0-31. |
| **0x5130** | `+0x500` | **DstFormatMode** | **FormatMode**: 0-1, **MetaDataSize**: 7-31. |
| **0x5134** | `+0x504` | **DstReserved2** | Reserved. |
| **0x5138** | `+0x508` | **DstFmtCtrl** | **ZeroPad**, **FmtOffsetCh**, **FmtCmpVec**. |
| **0x513C** | `+0x50C` | **DstReserved3** | Reserved. |
| **0x5140** | `+0x510` | **DstCompressedInfo**| **PackingFormat**, **MacroblockSize**, **LossyMode**. |
| **0x5144** | `+0x514` | **DstReserved4** | Reserved. |
| **0x5148** | `+0x518` | **DstCompSizeLo** | **SizeLo**: 0-31. |
| **0x514C** | `+0x51c` | **DstCompSizeHi** | **SizeHi**: 0-31. |
| **0x5150** | `+0x520` | **DstPixelOffset** | Cropping Offset. |

### CacheDMA / Telemetry (0x5900 block, Object `+0x52c`)
- **Count**: 12 registers (`0x0c` words, `0x30` bytes).
- **Object Layout**: Starts at `+0x52c` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x52c` | **TelemetryControl** | **Flush**: 0, **Enable**: 1, **TaskSync**: 2-3, **EarlyTerm**: 4-8. |
| **0x5904** | `+0x530` | **TelemetryPre0** | **BandwidthLimit**, **SieveFiltering**, **ResponseAgeOut**. |
| **0x5908** | `+0x534` | **TelemetryPre1** | **UserTag**, **Sieve1**: 0-13. |
| **0x590C** | `+0x538` | **TelemetryReserved1** | Reserved. |
| **0x5910** | `+0x53c` | **TelemetryReserved2** | Reserved. |
| **0x5914** | `+0x540` | **TelemetryReserved3** | Reserved. |
| **0x5918** | `+0x544` | **TelemetryDSID** | **DataSetIdAndSize**: 7-29. |
| **0x591C** | `+0x548` | **FootprintArg** | **FootprintArg2**: 17-27. |
| **0x5920** | `+0x54c` | **EarlyTermArg12** | **Arg1**: 0-15, **Arg2**: 16-31. |
| **0x5924** | `+0x550` | **FlushRegister** | **FlushArg**: 0-15. |
| **0x5928** | `+0x554` | **EarlyTermArg34** | **Arg3**: 0-7, **Arg4**: 16-23. |
| **0x592C** | `+0x558` | **BackoffControl** | **Enable**: 0, **Delay**: 4-7, **Min**: 8-15. |

### Cross-Cutting Subsystems: Quantization
Certain high-level configurations, like Quantization, touch multiple disparate hardware blocks simultaneously to coordinate data scaling and types across the pipeline. As decompiled from `ZinAneTd<17u>::SetQuantization*` methods:

**SetQuantizationSrc1InputOffset / Src2InputOffset**
- **Common** (`+0x030`): Format overrides (`ch_cfg`).
- **L2 Cache** (`+0x1cc` / `0x4100`): Padding/Relu scale (`control`).
- **Planar Engine** (`+0x274`, `+0x278`, `+0x280`, `+0x284`, `+0x2a8`): Configures `bias`, `scale`, `pre_scale`, `final_scale`, and `quant` zero points.

**SetQuantizationOutputZeroOffset**
- **Neural Engine** (`+0x2c8` / `0x4904`): Flips bit flags in `mac_cfg`.
- **Neural Engine** (`+0x2f0`): Writes to `quant`.

**SetTexture***
The texture sampling feature (such as GatherMode) maps heavily into the extended spaces of the **TileDmaSrc** block (`0x4D00`).
- **TileDmaSrc** (`+0x2C8`): Used for `TextureFilter`, `TextureWrap`, and `TextureIndexTensorInterleave`.
- **TileDmaSrc Extended** (`+0x324` to `+0x33C`): Memory region explicitly dedicated to texture logic. Configures `ExtMax`, `Permute` (Idx, Ind, Src), `PreserveFraction`, `BackgroundEn`, and `CropBatchSplit`.
- *Note: `TextureBypassFilter` is checked via `SetTextureBypassFilter` but explicitly triggers an assertion since it is no longer supported on M4.*

## Hardware Traits (`ZinHWTraits<17u>`)
The compiler maintains a set of statically defined traits for the M4 architecture (`17u`) that explicitly dictate the raw memory offsets of hardware components. Memory dumping `__DATA_CONST` reveals strict validation of our L2 and TileDMA address deductions:

### L2 Buffer Stride Offsets
| Trait Symbol | Hex Value | Decimal | Block Affiliation |
| :--- | :--- | :--- | :--- |
| `ANE_L2_SOURCE_CHANNEL_STRIDE_OFFSET` | `0x4114` | `16660` | Src1 Channel Stride |
| `ANE_L2_SOURCE_ROW_STRIDE_OFFSET` | `0x4118` | `16664` | Src1 Row Stride |
| `ANE_L2_SOURCE_DEPTH_STRIDE_OFFSET` | `0x411C` | `16668` | Src1 Depth Stride |
| `ANE_L2_SOURCE_GROUP_STRIDE_OFFSET` | `0x4120` | `16672` | Src1 Group Stride |
| `ANE_L2_SOURCE2_CHANNEL_STRIDE_OFFSET` | `0x4128` | `16680` | Src2 Channel Stride |
| `ANE_L2_SOURCE2_ROW_STRIDE_OFFSET` | `0x412C` | `16684` | Src2 Row Stride |
| `ANE_L2_SOURCE2_DEPTH_STRIDE_OFFSET` | `0x4130` | `16688` | Src2 Depth Stride |
| `ANE_L2_SOURCE2_GROUP_STRIDE_OFFSET` | `0x4134` | `16692` | Src2 Group Stride |
| `ANE_L2_RESULT_CHANNEL_STRIDE_OFFSET` | `0x4150` | `16720` | Result Channel Stride |
| `ANE_L2_RESULT_ROW_STRIDE_OFFSET` | `0x4154` | `16724` | Result Row Stride |
| `ANE_L2_RESULT_DEPTH_STRIDE_OFFSET` | `0x4158` | `16728` | Result Depth Stride |
| `ANE_L2_RESULT_GROUP_STRIDE_OFFSET` | `0x415C` | `16732` | Result Group Stride |

### Tile DMA Stride Offsets
| Trait Symbol | Hex Value | Decimal | Block Affiliation |
| :--- | :--- | :--- | :--- |
| `ANE_TILE_DMA_SRC_ROW_STRIDE_OFFSET` | `0x4D18` | `19736` | TileDmaSrc1 Row Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET` | `0x4D1C` | `19740` | TileDmaSrc1 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET` | `0x4D20` | `19744` | TileDmaSrc1 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET` | `0x4D24` | `19748` | TileDmaSrc1 Group Stride |
| `ANE_TILE_DMA_SRC_ROW_STRIDE2_OFFSET` | `0x4D30` | `19760` | TileDmaSrc2 Row Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET` | `0x4D34` | `19764` | TileDmaSrc2 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET` | `0x4D38` | `19768` | TileDmaSrc2 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET` | `0x4D3C` | `19772` | TileDmaSrc2 Group Stride |
| `ANE_TILE_DMA_DST_ROW_STRIDE_OFFSET` | `0x5110` | `20752` | TileDmaDst Row Stride |
| `ANE_TILE_DMA_DST_PLANE_STRIDE_OFFSET` | `0x5114` | `20756` | TileDmaDst Channel Stride |
| `ANE_TILE_DMA_DST_DEPTH_STRIDE_OFFSET` | `0x5118` | `20760` | TileDmaDst Depth Stride |
| `ANE_TILE_DMA_DST_GROUP_STRIDE_OFFSET` | `0x511C` | `20764` | TileDmaDst Group Stride |

---
*Verified via binary analysis of ANECompiler on macOS (A17/A18 compatible).*
