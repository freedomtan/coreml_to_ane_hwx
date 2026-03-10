## Object-to-Hardware Mapping Blocks

The `ZinAneTd<17u>` object maps internal offsets to hardware register blocks as follows:

| Source Offset (`this`) | Reg Count (Words) | HW Start Address | HW End Address (approx) | Primary Feature Area |
| :--- | :--- | :--- | :--- | :--- |
| `+0x1f8` | `0x17` | `0x0000` | `0x005C` | Common (InDim, OutDim, Patch, PETra) |
| `+0x3a8` | `0x29` | `0x4100` | `0x41A4` | L2 Cache / Buffer |
| `+0x454` | `0x15` | `0x4500` | `0x4550` | PE (Planar Engine) |
| `+0x498` | `0x0c` | `0x4900` | `0x4930` | NE (Neural Engine) |
| `+0x25c` | `0x51` | `0x4d00` | `0x4E44` | TileDmaSrc (Engine Control) |
| `+0x4d0` | `0x15` | `0x5100` | `0x5154` | TileDmaDst (Engine Control) |
| `+0x030` | `0x48` | `0x5500` | `0x5547` | KernelDmaSrc (Stride, Coeffs) |
| `+0x52c` | `0x0c` | `0x5900` | `0x5930` | CacheDMA & Telemetry |

## Register Offsets and Meanings

| Word Index | Byte Offset | Name | Description |
| :--- | :--- | :--- | :--- |
| **0** | `0x00` | **ChannelCfg** | Channel Format (Bits 0-1: In, 4-5: Out). |
| **1** | `0x04` | **InWidth** | Input width dimension. |
| **2** | `0x08` | **InHeight** | Input height dimension. |
| **3** | `0x0C` | **InChannels** | Input channel count. |
| **4** | `0x10` | **InDepth** | Input depth dimension. |
| **5** | `0x14` | **OutWidth** | Output width dimension. |
| **6** | `0x18` | **OutHeight** | Output height dimension. |
| **7** | `0x1C` | **OutChannels** | Output channel count. |
| **8** | `0x20` | **OutDepth** | Output depth dimension. |
| **9** | `0x24` | **Batch** | Batch size. |
| **10** | `0x28` | **ConvCfg** | 2D Kernel (KW:0-5, KH:6-11), Stride (SX:13-14, SY:15-16), Padding (PX:17-21, PY:22-26), Offset (OX:28-29, OY:30-31). (Object `+0x220` / `0x44` words into M4 block). |
| **11** | `0x2C` | **ConvCfg3d** | 3D Kernel (KD, SZ, PZ, OZ). (Object `+0x224` / `0x45` words). |
| **13** | `0x34` | **TileHeight** | Height of the processing tile. |
| **15** | `0x3C` | **MacCfg** | TaskType (4:7), ActiveNE (19:21), OutTrans (28). |
| **16** | `0x40` | **LaneCfg** | OCGSize (0:2). |
| **17** | `0x44` | **Patch** | PW (0:3), PH (4:8). |
| **18** | `0x48` | **PERouting** | Broadcast/Transpose bits (OutTrans Bit 10). |
| ... | ... | ... | ... |
| **0x1240** | `0x4900` | **KernelCfg** | Primary kernel configuration (Fmt, Sparse, Palettization, Align). |
| **0x1241** | `0x4904` | **MACCfg** | OpMode and KernelMode. |
| **0x1546** | `0x5518` | **KernelStrideX** | Stride X configuration (Bits 6-31). |
| **0x1547** | `0x551C` | **KernelStrideY** | Stride Y configuration (Bits 6-31). |
| **0x156C** | `0x55b0` | **SparseControl** | Detect Zeros and Sparse controls. |

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

#### Common (0x0000 block, Object `+0x1f8`)
Size: 21 registers (`0x15` words, `0x54` bytes). Dictates fundamental geometries, primary convolutions, and routing.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x1f8` | **ChannelCfg** | **InFmt**: 0-1, **OutFmt**: 4-5, **Src2InFmt**: 8-9. |
| **0x0004** | `+0x1fc` | **InWidth** | Input width (14 bits). |
| **0x0008** | `+0x200` | **InHeight** | Input height (14 bits). |
| **0x000C** | `+0x204` | **InChannels** | Input channels (14 bits). |
| **0x0010** | `+0x208` | **InDepth** | Input depth (14 bits). |
| **0x0014** | `+0x20c` | **OutWidth** | Output width (14 bits). |
| **0x0018** | `+0x210` | **OutHeight** | Output height (14 bits). |
| **0x001C** | `+0x214` | **OutChannels** | Output channels (14 bits). |
| **0x0020** | `+0x218` | **OutDepth** | Output depth (14 bits). |
| **0x0024** | `+0x21c` | **NumGroups** | Batch size / Number of groups. |
| **0x0028** | `+0x220` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PadLeft**: 17-21, **PadTop**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **0x002C** | `+0x224` | **ConvCfg3d** | Extended paddings / 3D kernel dims. |
| **0x0030** | `+0x228` | **UnicastCfg** | **UnicastEn**: Bit 0, **UnicastCin**: Bits 4-17. |
| **0x0034** | `+0x22c` | **TileHeight** | Processing tile height. |
| **0x0038** | `+0x230` | **TileOverlap** | **PadBottom**: 0-5, **PadTop**: 6-11, **Overlap**: 12-25. |
| **0x003C** | `+0x234` | **MacCfg** | **SmallSrcMode**: 2-3, **TaskType**: 4-7, **ActiveNE**: 19-21, **L2Barrier**: 23, **OutTranspose**: 28. |
| **0x0040** | `+0x238` | **LaneCfg** | **OCGSize**: Bits 0-2 (1=16, 2=32, 4=64). |
| **0x0044** | `+0x23c` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x240` | **PERouting** | **Broadcasts**: Src1[W:0, H:1, D:2, C:3], Src2[W:4, H:5, D:6, C:7]. **Transposes**: Src1:8, Src2:9, Output:10. |
| **0x004C** | `+0x244` | **NID** | Network ID / Layer Trace ID. |
| **0x0050** | `+0x248` | **DPE** | Distributed Processing Element config. |

*Note: M4 drops `ChannelDmaLength` and several M1 properties. E4M3Overflow and TextureBypassFilter are explicitly unsupported in the binary.*

*Compiler Sub-Struct Note (`ZinAneTdHw_v17`)*: The `ZinGetRegisterProgramming<17u>` getters map directly onto our Common Block layout with a `+0x8` descriptor header offset.

### Neural Engine (NE) (0x4900 block, Object `+0x498`)
Size: 12 registers (`0x30` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x498` | **KernelCfg** | **KernelFmt**: 0-1, **PalettizedEn**: 2, **PalettizedBits**: 4-7, **SparseFmt**: 8, **GroupKernelReuse**: 10, **SparseBinary**: 15, **AlignmentFormat**: 16, **SparseBlockSize**: 21-23, **AsymQuantEn**: 24. |
| **0x4904** | `+0x49c` | **MACCfg** | **OpMode**: 0-2, **KernelMode**: 3, **NEBiasEnable**: 4, **NEMatrixVectorBiasEnable**: 6, **BinaryPoint**: 8-13, **NEPostScaleEnable**: 14, **NENonLinearMode**: 16-17, **PaddingMode**: 18, **MaxPoolMode**: 19. |
| **0x4908** | `+0x4a0` | **MatrixVectorBias**| 16-bit Bias value (`strh`). |
| **0x490C** | `+0x4a4` | **NEBias** | 21-bit Bias value (Bits 0-20). |
| **0x4910** | `+0x4a8` | **NEPostScale** | 21-bit Post-Scale value (Bits 0-20). |
| **0x4914** | `+0x4ac` | **RcasConfig** | **KeyMask**: 0-7, **CmpBit**: 8-10, **SenseAxis**: 12-13, **SenseBit**: 16-19, **Mode**: 20. |
| **0x4918** | `+0x4b0` | **RoundModeCfg** | **StochasticRoundMode**: 0-1, **StochasticRoundIntegerBits**: 4-8. |
| **0x491C** | `+0x4b4` | **SRSeed[0]** | 32-bit Stochastic Rounding Seed 0. |
| **0x4920** | `+0x4b8` | **SRSeed[1]** | 32-bit Stochastic Rounding Seed 1. |
| **0x4924** | `+0x4bc` | **SRSeed[2]** | 32-bit Stochastic Rounding Seed 2. |
| **0x4928** | `+0x4c0` | **SRSeed[3]** | 32-bit Stochastic Rounding Seed 3. |
| **0x492C** | `+0x4c4` | **QuantZeroPoint** | 8-bit Quantization Zero Point (`strb`). |

##### KernelDmaSrc (0x5500 block, Object `+0x030`)
Size: 72 registers (`0x48` words, `0x120` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x030` | **KDMA_MasterConfig** | **MasterEnable**: 6. |
| **0x5504** | `+0x034` | **KDMA_Reserved1** | Unknown. |
| **0x5508** | `+0x038` | **KDMA_Prefetch** | **EarlyTermEn**: 0, **StopOnError**: 1, **PrefetchRate**: 16-31. |
| **0x550C** | `+0x03c` | **KDMA_Reserved2** | Unknown. |
| **0x5510** | `+0x040` | **KDMA_Reserved3** | Unknown. |
| **0x5514** | `+0x044` | **KDMA_Reserved4** | Unknown. |
| **0x5518** | `+0x048` | **KDMA_StrideX** | Stride X (Bits 6-31). |
| **0x551C** | `+0x04c` | **KDMA_StrideY** | Stride Y (Bits 6-31). |
| **0x5520-0x555C**| `+0x050`..`+0x08c` | **CoeffDMAConfig[16]**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5560-0x559C**| `+0x090`..`+0x0cc` | **CoeffBaseAddr[16]** | Base Offset (Bits 6-31, 64-byte aligned). |
| **0x55A0-0x55DC**| `+0x0d0`..`+0x10c` | **CoeffBfrSize[16]** | Buffer Size (Bits 0-31). |
| **0x55E0** | `+0x110` | **BiasDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **UserTag**: 16-23. |
| **0x55F0** | `+0x120` | **PostScaleDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **UserTag**: 16-23. |
| **0x5600** | `+0x130` | **PaletteDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **UserTag**: 16-23. |
| **0x5610** | `+0x140` | **NLutDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **UserTag**: 16-23. |

### TileDMA Source (0x4D00 block, Object `+0x25c`)
Size: 81 registers (`0x51` words, `0x144` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4D00** | `+0x25c` | **Src1DMAConfig** | **Enable**: 0, **DataSetId**: 8-15, **UserTag**: 16-23, **Format**: 24-27. |
| **0x4D04** | `+0x260` | **Src2DMAConfig** | **Enable**: 0, **DataSetId**: 8-15, **UserTag**: 16-23, **DependencyMode**: 28-29. |
| **0x4D08** | `+0x264` | **Src1BaseAddrLo** | Lower 32 bits of 64-bit base address. |
| **0x4D0C** | `+0x268` | **Src1BaseAddrHi** | Upper 32 bits of 64-bit base address. |
| **0x4D10** | `+0x26c` | **Src2BaseAddrLo** | Lower 32 bits of 64-bit base address. |
| **0x4D14** | `+0x270` | **Src2BaseAddrHi** | Upper 32 bits of 64-bit base address. |
| **0x4D18** | `+0x274` | **Src1RowStride** | Row stride (Bits 6-31). |
| **0x4D1C** | `+0x278` | **Src1PlaneStride** | Channel (Plane) stride (Bits 6-31). |
| **0x4D20** | `+0x27c` | **Src1DepthStride** | Depth stride (Bits 6-31). |
| **0x4D24** | `+0x280` | **Src1GroupStride** | Group stride (Bits 6-31). |
| **0x4D28** | `+0x284` | **Src2Config** | Reserved / Mode Flags. |
| **0x4D2C** | `+0x288` | **Src2Padding** | Reserved / Padding Mode. |
| **0x4D30** | `+0x28c` | **Src2RowStride** | Row stride (Bits 6-31). |
| **0x4D34** | `+0x290` | **Src2PlaneStride** | Channel (Plane) stride (Bits 6-31). |
| **0x4D38** | `+0x294` | **Src2DepthStride** | Depth stride (Bits 6-31). |
| **0x4D3C** | `+0x298` | **Src2GroupStride** | Group stride (Bits 6-31). |
| **0x4D40** | `+0x29c` | **Src1MetaDataConfig**| MetaData Enable/Flags. |
| **0x4D50** | `+0x2ac` | **Src1MetaDataAddrLo**| MetaData Buffer Lo (Bits 0-31). |
| **0x4D54** | `+0x2b0` | **Src1MetaDataAddrHi**| MetaData Buffer Hi (Bits 32-63). |
| **0x4D58** | `+0x2b4` | **Src1MetaDataSize** | MetaData Size / Config. |
| **0x4D5C** | `+0x2b8` | **Src2MetaDataAddrLo**| MetaData Buffer Lo (Bits 0-31). |
| **0x4D60** | `+0x2bc` | **Src2MetaDataAddrHi**| MetaData Buffer Hi (Bits 32-63). |
| **0x4D64** | `+0x2c0` | **Src2MetaDataSize** | MetaData Size / Config. |
| **0x4D68** | `+0x2c4` | **Src1Fmt** | Interleave Mode (Bits 12-13). |
| **0x4D6C** | `+0x2c8` | **Src2Fmt** | Interleave Mode (Bits 12-13). |
| **0x4D98** | `+0x2f4` | **Src1PixelOffset** | Cropping Offset (H: 0-13, W: 16-29, D: 32-45... 16 bytes). |
| **0x4DA8** | `+0x304` | **Src2PixelOffset** | Cropping Offset (H: 0-13, W: 16-29, D: 32-45... 16 bytes). |

### TileDMA Destination (0x5100 block, Object `+0x4d0`)
Size: 21 registers (`0x15` words, `0x54` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5100** | `+0x4d0` | **DstDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5104** | `+0x4d4` | **DstPadding** | Reserved / Padding Mode. |
| **0x5108** | `+0x4d8` | **DstBaseAddrLo**| Lower 32 bits of 64-bit output base address. |
| **0x510C** | `+0x4dc` | **DstBaseAddrHi**| Upper 32 bits of 64-bit output base address. |
| **0x5110** | `+0x4e0` | **DstRowStride** | Row stride (Bits 6-31). |
| **0x5114** | `+0x4e4` | **DstPlaneStride**| Channel (Plane) stride (Bits 6-31). |
| **0x5118** | `+0x4e8` | **DstDepthStride**| Depth stride (Bits 6-31). |
| **0x511C** | `+0x4ec` | **DstGroupStride**| Group stride (Bits 6-31). |
| **0x5120** | `+0x4f0` | **DstInternalCfg**| **InternalBits**: 0-15, **Flag1**: 16, **Flag2**: 17, **Flag3**: 18. (Set by `SetDmaDstInternal`). |
| **0x5124** | `+0x4f4` | **DstReserved1** | Unknown. |
| **0x5128** | `+0x4f8` | **DstMetaDataAddrLo**| MetaData Buffer Lo (Bits 0-31). |
| **0x512C** | `+0x4fc` | **DstMetaDataAddrHi**| MetaData Buffer Hi (Bits 32-63). |
| **0x5130** | `+0x500` | **DstFmtMode** | **FormatMode**: 0-1, **MetaDataSize**: 7-31. |
| **0x5134** | `+0x504` | **DstReserved2** | Unknown. |
| **0x5138** | `+0x508` | **DstCompStatus** | **IsCompressed**: 0. |
| **0x513C** | `+0x50c` | **DstReserved3** | Unknown. |
| **0x5140** | `+0x510` | **DstCompressionCfg**| **PackingFmt**: 4-7, **MacroblockSize**: 12-13. (Set by `SetTileDmaDstCompressedInfo`). |
| **0x5144** | `+0x514` | **DstReserved4** | Unknown. |
| **0x5148** | `+0x518` | **DstCompSizeLo** | Output Compressed Size (Bits 0-31). |
| **0x514C** | `+0x51c` | **DstCompSizeHi** | Output Compressed Size (Bits 32-63). |
| **0x5150** | `+0x520` | **DstPixelOffset** | Pixel/Crop offsets (See `GetCropOffsetDstY`). |

### CacheDMA / Telemetry (0x5900 block, Object `+0x52c`)
This block handles telemetry, caching hints, and task synchronization.
Size: 12 registers (`0x30` bytes, `0x0c` words).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x52c` | **CacheDMAControl** | **Flush**: Bit 0, **Enable**: Bit 1, **TaskSync**: WaitPrev:3, PostDone:2, **EarlyTerm**: 4-6, **FootprintLimiter**: Bit 9, **FootprintThreshold**: 16-31. |
| **0x5904** | `+0x530` | **CacheDMAPre0** | **BandwidthLimit**: 0-9, **Sieve2**: 16-19, **TelemetryAgeOut**: 20-23. |
| **0x5908** | `+0x534` | **CacheDMAPre1** | **Sieve1**: 0-13. |
| **0x590C** | `+0x538` | **CacheDMAPad3** | Reserved / Unknown. |
| **0x5910** | `+0x53c` | **CacheDMAPad4** | Reserved / Unknown. |
| **0x5914** | `+0x540` | **CacheDMAPad5** | Reserved / Unknown (Maybe DstCrop in Some contexts). |
| **0x5918** | `+0x544` | **CacheDMADsid** | **DSIDAndSize**: Bits 7-29. |
| **0x591C** | `+0x548` | **CacheDMAFootprint**| **FootprintArg2**: Bits 17-27. |
| **0x5920** | `+0x54c` | **EarlyTermArg12** | **Arg1**: Bits 0-15 (`strh`), **Arg2**: Bits 16-31 (`strh`). |
| **0x5924** | `+0x550` | **CacheDMAFlushArg**| **FlushArg**: Bits 0-15 (`strh`). |
| **0x5928** | `+0x554` | **EarlyTermArg34** | **Arg3**: Bits 0-7 (`strb`), **Arg4**: Bits 16-23 (`strb`). |
| **0x592C** | `+0x558` | **TelemetryBackOff**| **Enable**: Bit 0, **Delay**: 4-7, **Min**: 8-15, **Max**: 16-23, **Scale**: 24-31. |

### Planar Engine (PE) (0x4500 block, Object `+0x454`)
This block controls the Planar Engine (PE) which handles element-wise operations, pooling, and scaling.
Size: 15 registers (`0xf` words, `0x3c` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4500** | `+0x454` | **PE_Config** | **OpMode**: 0-5 (0=Add, 1=Sub, 2=Min, 3=Max, 4=Mul, 5=Div/Recip), **Condition**: 6-8 (0=True, 1=LT, 2=LE, 3=EQ, 4=NE, 5=GE, 6=GT), **FirstSource**: 16, **SecondSource**: 18-19. |
| **0x4504** | `+0x458` | **PE_Bias** | 19-bit Floating Point (F19) bias value. |
| **0x4508** | `+0x45c` | **PE_Scale** | 19-bit Floating Point (F19) scale value. |
| **0x450C** | `+0x460` | **PE_Reserved1** | Unknown configuration flags. |
| **0x4510** | `+0x464` | **PE_PreScale** | 19-bit Floating Point (F19) pre-scale value. |
| **0x4514** | `+0x468` | **PE_FinalScale** | 19-bit Floating Point (F19) final scale value. |
| **0x4518-0x4534** | `+0x46c`..`+0x488` | **PE_Reserved[8]** | Reserved. |
| **0x4538** | `+0x48c` | **PE_Quant** | **ZeroPoint**: Bits 16-23. (Note: ReLU flags moved to L2). |

#### PE Indexing Extension (H16_PE_EXT_START block, Object `+0x434`)
These registers coordinate with the PE for indexing operations.

| HW Addr | Index | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **H16_PE_EXT_START** | Word 0 | **PE_IndexCfg** | **MaxIndex**: 0-15, **IndexingEn**: 16. |

#### L2 Cache / Buffer (0x4100 block, Object `+0x3a8`)
The L2 block handles local buffering and tensor tiling.
Size: 41 registers (`0xA4` bytes, `0x29` words).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3a8` | **L2_Control** | **Src1ReLU**: Bit 0, **PaddingMode**: 2-3, **Src2ReLU**: Bit 4, **Src1DoubleRate**: 6, **Barrier**: 16. |
| **0x4104** | `+0x3ac` | **L2_Src1Cfg** | **SourceType**: 2-3, **DmaFormat**: 6-7, **Interleave**: 8-11, **OffsetYlsbs**: 12-15, **Compression**: 25. |
| **0x4108** | `+0x3b0` | **L2_Src2Cfg** | **SourceType**: 2-3, **Interleave**: 8-11, **Compression**: 25. |
| **0x410C** | `+0x3b4` | **L2_Pad3** | Reserved / Unknown. |
| **0x4110** | `+0x3b8` | **L2_Src1Base** | Bits 4-20: Base Address (17 bits), Bits 4-7: OffsetXlsbs. |
| **0x4114** | `+0x3bc` | **L2_Src1CStride** | Channel Stride for Source 1. |
| **0x4118** | `+0x3c0` | **L2_Src1RStride** | Row Stride for Source 1. |
| **0x411C** | `+0x3c4` | **L2_Src1DStride** | Depth Stride for Source 1. |
| **0x4120** | `+0x3c8` | **L2_Src1GStride** | Group Stride for Source 1. |
| **0x4124** | `+0x3cc` | **L2_Src2Base** | Bits 4-20: Base Address (17 bits), Bits 4-7: OffsetXlsbs. |
| **0x4128** | `+0x3d0` | **L2_Src2CStride** | Channel Stride for Source 2. |
| **0x412C** | `+0x3d4` | **L2_Src2RStride** | Row Stride for Source 2. |
| **0x4130** | `+0x3d8` | **L2_Src2DStride** | Depth Stride for Source 2. |
| **0x4134** | `+0x3dc` | **L2_Src2GStride** | Group Stride for Source 2. |
| **0x4138** | `+0x3e0` | **L2_SrcIdxBase** | Base Address for Index Source (Bits 4-20). |
| **0x413C** | `+0x3e4` | **L2_SrcIdxCStride** | Channel Stride for Index Source. |
| **0x4140** | `+0x3e8` | **L2_SrcIdxDStride** | Depth Stride for Index Source. |
| **0x4144** | `+0x3ec` | **L2_SrcIdxGStride** | Group Stride for Index Source. |
| **0x4148** | `+0x3f0` | **L2_ResultCfg** | **BfrMode**: 3, **CropOffsetXLSBs**: 4-6, **Interleave**: 8-11, **ResultType**: 12-13, **Compression**: 24-25. |
| **0x414C** | `+0x3f4` | **L2_ResultBase** | Bits 4-20: Base Address, Bits 4-7: SrcOffsetXlsbs? |
| **0x4150** | `+0x3f8` | **L2_ResultCStride**| Channel Stride for Result. |
| **0x4154** | `+0x3fc` | **L2_ResultRStride**| Row Stride for Result. |
| **0x4158** | `+0x400` | **L2_ResultDStride**| Depth Stride for Result. |
| **0x415C** | `+0x404` | **L2_ResultGStride**| Group Stride for Result. |
| **0x4160** | `+0x408` | **L2_Res24** | Unknown (Written by SetL2Src2FIFOModeRetention). |
| **0x4164** | `+0x40c` | **L2_ResultWrapCfg** | Result Wrapping Configuration. |
| **0x4168** | `+0x410` | **L2_Res26** | Unknown. |
| **0x416C** | `+0x414` | **L2_Res27** | Unknown. |
| **0x4170** | `+0x418` | **L2_Res28** | Unknown. |
| **0x4174** | `+0x41c` | **L2_ResultWrapIdxOff** | Bits 0-15: WrapIndex, Bits 16-31: WrapStartOffset. |
| **0x4178** | `+0x420` | **L2_Res30** | Unknown. |
| **0x417C** | `+0x424` | **L2_Result2Base**| Second Result / L2 Write Base (Bits 4-20). |
| **0x4180** | `+0x428` | **L2_Result2CStride**| Second Result Channel Stride. |
| **0x4184** | `+0x42c` | **L2_Result2RStride**| Second Result Row Stride. |
| **0x4188** | `+0x430` | **L2_Result2DStride**| Second Result Depth Stride. |
| **0x418C** | `+0x434` | **L2_Result2GStride**| Second Result Group Stride. |
| **0x4190** | `+0x438` | **L2_Res36** | Unknown. |
| **0x4194** | `+0x43c` | **L2_Res37** | Unknown. |
| **0x4198** | `+0x440` | **L2_Res38** | Unknown. |
| **0x419C** | `+0x444` | **L2_ResultWrapAddr** | Bits 0-11: WrapAddr, Bits 16-26: WrapAddrOffset. |
| **0x41A0** | `+0x448` | **L2_Res40** | Unknown. |

#### L2 Wrap Constraints:
- **0x4164**: **L2ResultWrapCfg**
- **0x4174**: **L2ResultWrapIdxOff**
- **0x419C**: **L2ResultWrapAddr**

### Cross-Cutting Subsystems: Quantization
Certain high-level configurations, like Quantization, touch multiple disparate hardware blocks simultaneously to coordinate data scaling and types across the pipeline. As decompiled from `ZinAneTd<17u>::SetQuantization*` methods:

**SetQuantizationSrc1InputOffset / Src2InputOffset**
- **Common (`+0x240`)**: Likely format overrides.
- **L2 Cache (`+0x3A8` / `0x4100`)**: Applies `L2Cfg` padding scale formats.
- **Planar Engine (`+0x458`, `+0x45c`, `+0x464`, `+0x468`, `+0x48e`)**: Configures `PEBias`, `PEScale`, `PEPreScale`, `PEFinalScale`, and `PEOutputQuantization` simultaneously.

**SetQuantizationOutputZeroOffset**
- **Neural Engine (`+0x49C` / `0x4904`)**: Flips bit flags in `MACCfg` regarding non-linear mode or binary points.
- **Neural Engine (`+0x4C4`)**: Likely writes to `AccBias` / `PostScale` extensions.

**SetTexture***
The texture sampling feature (such as GatherMode) maps heavily into the extended spaces of the **TileDmaSrc** block (`0x4D00`).
- **TileDmaSrc (`+0x2C8`)**: Used for `TextureFilter`, `TextureWrap`, and `TextureIndexTensorInterleave`.
- **TileDmaSrc Extended (`+0x324` to `+0x33C`)**: Memory region explicitly dedicated to texture logic. Configures `ExtMax`, `Permute` (Idx, Ind, Src), `PreserveFraction`, `BackgroundEn`, and `CropBatchSplit`.
- *Note: `TextureBypassFilter` is checked via `SetTextureBypassFilter` but explicitly triggers an assertion since it is no longer supported on M4.*

## Hardware Traits (`ZinHWTraits<17u>`)
The compiler maintains a set of statically defined traits for the M4 architecture (`17u`) that explicitly dictate the raw memory offsets of hardware components. Memory dumping `__DATA_CONST` reveals strict validation of our L2 and TileDMA address deductions:

| Trait Symbol | Hex Value | Decimal | Block Affiliation |
| --- | --- | --- | --- |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET` | `0x4D1C` | `19740` | TileDmaSrc1 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET` | `0x4D20` | `19744` | TileDmaSrc1 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET` | `0x4D24` | `19748` | TileDmaSrc1 Group Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET` | `0x4D34` | `19764` | TileDmaSrc2 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET` | `0x4D38` | `19768` | TileDmaSrc2 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET` | `0x4D3C` | `19772` | TileDmaSrc2 Group Stride |
| `ANE_L2_SOURCE2_CHANNEL_STRIDE_OFFSET` | `0x4128` | `16680` | L2 Src2 Base Channel Stride |
| `ANE_TILE_DMA_DST_PLANE_STRIDE_OFFSET` | `0x5114` | `20756` | TileDmaDst Channel Stride |
| `ANE_TILE_DMA_DST_DEPTH_STRIDE_OFFSET` | `0x5118` | `20760` | TileDmaDst Depth Stride |
| `ANE_TILE_DMA_DST_GROUP_STRIDE_OFFSET` | `0x511C` | `20764` | TileDmaDst Group Stride |
| `ANE_L2_RESULT_CHANNEL_STRIDE_OFFSET` | `0x4150` | `16720` | L2 Result Group Stride |

*(Note: In the ANE nomenclature, "Plane" defines the Channel spacing offset.)*
