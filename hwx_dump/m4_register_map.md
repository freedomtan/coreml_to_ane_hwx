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
| **13** | `0x34` | **TileHeight** | **TileHeight**: 0-15. |
| **15** | `0x3C` | **MacCfg** | **TaskType**: 4-7, **ActiveNE**: 19-21, **OutTrans**: 28. |
| **16** | `0x40` | **LaneCfg** | **OCGSize**: 0-2. |
| **17** | `0x44` | **Patch** | **PW**: 0-3, **PH**: 4-8. |
| **18** | `0x48` | **PERouting** | **Broadcasts**: 0-7, **Transposes**: 8-10. |
| ... | ... | ... | ... |
| **0x1240** | `0x4900` | **KernelCfg** | **KernelFmt**: 0-1, **SparseEn**: 8, **PalEn**: 2. |
| **0x1241** | `0x4904` | **MACCfg** | **OpMode**: 0-2, **KernelMode**: 3. |
| **0x1546** | `0x5518` | **KernelStrideX** | **StrideX**: 6-31. |
| **0x1547** | `0x551C` | **KernelStrideY** | **StrideY**: 6-31. |
| **0x156C** | `0x55b0` | **SparseControl** | **DetectZeros**: 0, **SparseEn**: 1. |

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
| **0x0004** | `+0x1fc` | **InWidth** | **Win**: 0-13. |
| **0x0008** | `+0x200` | **InHeight** | **Hin**: 0-13. |
| **0x000C** | `+0x204` | **InChannels** | **Cin**: 0-13. |
| **0x0010** | `+0x208` | **InDepth** | **Din**: 0-13. |
| **0x0014** | `+0x20c` | **OutWidth** | **Wout**: 0-13. |
| **0x0018** | `+0x210` | **OutHeight** | **Hout**: 0-13. |
| **0x001C** | `+0x214` | **OutChannels** | **Cout**: 0-13. |
| **0x0020** | `+0x218` | **OutDepth** | **Dout**: 0-13. |
| **0x0024** | `+0x21c` | **NumGroups** | Batch size / Number of groups. |
| **0x0028** | `+0x220` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PadLeft**: 17-21, **PadTop**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **0x002C** | `+0x224` | **ConvCfg3d** | Extended paddings / 3D kernel dims. |
| **0x0030** | `+0x228` | **UnicastCfg** | **UnicastEn**: 0, **UnicastCin**: 4-17. |
| **0x0034** | `+0x22c` | **TileHeight** | **TileHeight**: 0-15. |
| **0x0038** | `+0x230` | **TileOverlap** | **PadBottom**: 0-5, **PadTop**: 6-11, **Overlap**: 12-25. |
| **0x003C** | `+0x234` | **MacCfg** | **SmallSrcMode**: 2-3, **TaskType**: 4-7, **ActiveNE**: 19-21, **OutTranspose**: 28, **FillLowerNEFirst**: 29. |
| **0x0040** | `+0x238` | **LaneCfg** | **OCGSize**: 0-2 (1=16, 2=32, 4=64), **FatTileEnable**: 3, **WUStackLog2**: 4-5. |
| **0x0044** | `+0x23c` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x240` | **PERouting** | **Src1Broadcast**: 0-3 (W:0, H:1, D:2, C:3), **Src2Broadcast**: 4-7 (W:4, H:5, D:6, C:7), **Src1Transpose**: 8, **Src2Transpose**: 9, **OutputCtoW**: 10. |
| **0x004C** | `+0x244` | **NID** | Network ID / Layer Trace ID. |
| **0x0050** | `+0x248` | **DPE** | Distributed Processing Element config. |

*Note: M4 drops `ChannelDmaLength` and several M1 properties. E4M3Overflow and TextureBypassFilter are explicitly unsupported in the binary.*

*Compiler Sub-Struct Note (`ZinAneTdHw_v17`)*: The `ZinGetRegisterProgramming<17u>` getters map directly onto our Common Block layout with a `+0x8` descriptor header offset.

### Neural Engine (NE) (0x4900 block, Object `+0x498`)
Size: 12 registers (`0x30` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x498` | **KernelCfg** | **KernelFmt**: 0-1, **PalEn**: 2, **PalBits**: 4-7, **SparseEn**: 8, **GroupKernelReuse**: 10, **SparseBinary**: 15, **AsymQuantEn**: 24. |
| **0x4904** | `+0x49c` | **MACCfg** | **OpMode**: 0-2 (0:Conv, 1:MatMul, 2:EWise, 3:XCorr), **KernelMode**: 3, **BiasEnable**: 4, **PassthroughEnable**: 5, **MatrixVectorBiasEnable**: 6, **BinaryPoint**: 8-13, **PostScaleEnable**: 14, **NonlinearMode**: 16-17, **MaxPoolMode**: 19, **ArgOutputSelect**: 20-23, **DoubleInt8Enable**: 26. |
| **0x4908** | `+0x4a0` | **MatrixVectorBias**| **Bias**: 0-15. |
| **0x490C** | `+0x4a4` | **NEBias** | **Bias**: 0-20 (F19/F21). |
| **0x4910** | `+0x4a8` | **NEPostScale** | **PostScale**: 0-20 (F19/F21). |
| **0x4914** | `+0x4ac` | **RcasConfig** | **KeyMask**: 0-7, **CmpBit**: 8-10, **SenseAxis**: 12-13, **SenseBit**: 16-19, **RcasMode**: 20. |
| **0x4918** | `+0x4b0` | **RoundModeCfg** | **StochasticRoundMode**: 0-1, **StochasticRoundIntegerBits**: 4-8. |
| **0x491C** | `+0x4b4` | **SRSeed[0]**| **Seed**: 0-31 (Relocations suggest 16-bit granularity). |
| **0x4920** | `+0x4b8` | **SRSeed[1]**| **Seed**: 0-31. |
| **0x4924** | `+0x4bc` | **SRSeed[2]**| **Seed**: 0-31. |
| **0x4928** | `+0x4c0` | **SRSeed[3]**| **Seed**: 0-31. |
| **0x492C** | `+0x4c4` | **QuantZeroPoint** | **ZeroPoint**: 0-7. |

##### KernelDmaSrc (0x5500 block, Object `+0x030`)
Size: 72 registers (`0x48` words, `0x120` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x030` | **KDMA_MasterConfig** | **MasterEnable**: 6. |
| **0x5504** | `+0x034` | **KDMA_Reserved1** | Unknown. |
| **0x5508** | `+0x038` | **KDMA_Prefetch** | **EarlyTermEn**: 0, **StopOnError**: 1, **PrefetchRate**: 16-31. |
| **0x550C-0x5514**| `+0x03c`..`+0x044` | **KDMA_Reserved[3]** | Unknown. |
| **0x5518** | `+0x048` | **KDMA_StrideX** | **Stride**: 6-31. |
| **0x551C** | `+0x04c` | **KDMA_StrideY** | **Stride**: 6-31. |
| **0x5520-0x555C**| `+0x050`..`+0x08c` | **CoeffDMAConfig[16]**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x5560-0x559C**| `+0x090`..`+0x0cc` | **CoeffBaseAddr[16]** | **Addr**: 6-31. |
| **0x55A0-0x55DC**| `+0x0d0`..`+0x10c` | **CoeffBfrSize[16]** | **Size**: 0-31. |
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
| **0x4D08** | `+0x264` | **Src1BaseAddrLo** | **AddrLo**: 0-31. |
| **0x4D0C** | `+0x268` | **Src1BaseAddrHi** | **AddrHi**: 0-31. |
| **0x4D10** | `+0x26c` | **Src2BaseAddrLo** | **AddrLo**: 0-31. |
| **0x4D14** | `+0x270` | **Src2BaseAddrHi** | **AddrHi**: 0-31. |
| **0x4D18** | `+0x274` | **Src1RowStride** | **Stride**: 6-31. |
| **0x4D1C** | `+0x278` | **Src1PlaneStride** | **Stride**: 6-31. |
| **0x4D20** | `+0x27c` | **Src1DepthStride** | **Stride**: 6-31. |
| **0x4D24** | `+0x280` | **Src1GroupStride** | **Stride**: 6-31. |
| **0x4D28** | `+0x284` | **Src2Config** | Reserved / Mode Flags. |
| **0x4D2C** | `+0x288` | **Src2Padding** | Reserved / Padding Mode. |
| **0x4D30** | `+0x28c` | **Src2RowStride** | **Stride**: 6-31. |
| **0x4D34** | `+0x290` | **Src2PlaneStride** | **Stride**: 6-31. |
| **0x4D38** | `+0x294` | **Src2DepthStride** | **Stride**: 6-31. |
| **0x4D3C** | `+0x298` | **Src2GroupStride** | **Stride**: 6-31. |
| **0x4D40** | `+0x29c` | **Src1MetaDataConfig**| MetaData Enable/Flags. |
| **0x4D50** | `+0x2ac` | **Src1MetaDataAddrLo**| **AddrLo**: 0-31. |
| **0x4D54** | `+0x2b0` | **Src1MetaDataAddrHi**| **AddrHi**: 0-31. |
| **0x4D58** | `+0x2b4` | **Src1MetaDataSize** | MetaData Size / Config. |
| **0x4D5C** | `+0x2b8` | **Src2MetaDataAddrLo**| **AddrLo**: 0-31. |
| **0x4D60** | `+0x2bc` | **Src2MetaDataAddrHi**| **AddrHi**: 0-31. |
| **0x4D64** | `+0x2c0` | **Src2MetaDataSize** | MetaData Size / Config. |
| **0x4D68** | `+0x2c4` | **Src1Fmt** | **Interleave**: 12-13. |
| **0x4D6C** | `+0x2c8` | **Src2Fmt** | **Interleave**: 12-13. |
| **0x4D98** | `+0x2f4` | **Src1PixelOffset** | Cropping Offset. |
| **0x4DA8** | `+0x304` | **Src2PixelOffset** | Cropping Offset. |

### TileDMA Destination (0x5100 block, Object `+0x4d0`)
Size: 21 registers (`0x15` words, `0x54` bytes).

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
| **0x5148** | `+0x518` | **DstCompSizeLo** | **SizeLo**: 0-31. |
| **0x514C** | `+0x51c` | **DstCompSizeHi** | **SizeHi**: 0-31. |
| **0x5150** | `+0x520` | **DstPixelOffset** | Cropping Offset. |

### CacheDMA / Telemetry (0x5900 block, Object `+0x52c`)
This block handles telemetry, caching hints, and task synchronization.
Size: 12 registers (`0x30` bytes, `0x0c` words).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x52c` | **TelemetryControl** | **Flush**: 0, **Enable**: 1, **TaskSync**: 2-3, **EarlyTerm**: 4-8. |
| **0x5904** | `+0x530` | **TelemetryPre0** | **BandwidthLimit**: 0-9... |
| **0x5908** | `+0x534` | **TelemetryPre1** | **Sieve1**: 0-13. |
| **0x5918** | `+0x544` | **TelemetryDSID** | **DataSetIdAndSize**: 7-29. |
| **0x591C** | `+0x548` | **FootprintArg** | **FootprintArg2**: 17-27. |
| **0x5920** | `+0x54c` | **EarlyTermArg12** | **Arg1**: 0-15, **Arg2**: 16-31. |
| **0x5924** | `+0x550` | **FlushRegister** | **FlushArg**: 0-15. |
| **0x5928** | `+0x554` | **EarlyTermArg34** | **Arg3**: 0-7, **Arg4**: 16-23. |
| **0x592C** | `+0x558` | **BackoffControl** | **Enable**: 0, **Delay**: 4-7, **Min**: 8-15... |

### Planar Engine (PE) (0x4500 block, Object `+0x454`)
This block controls the Planar Engine (PE) which handles element-wise operations, pooling, and scaling.
Size: 15 registers (`0xf` words, `0x3c` bytes).

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

#### PE Indexing Extension (H16_PE_EXT_START block, Object `+0x434`)
These registers coordinate with the PE for indexing operations.

| HW Addr | Index | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **H16_PE_EXT_START** | Word 0 | **IndexCfg** | **MaxIndex**: 0-15, **IndexMode**: 16-18, **IndexBroadcast**: 24-25, **IndexTranspose**: 26. |

#### L2 Cache / Buffer (0x4100 block, Object `+0x3a8`)
The L2 block handles local buffering and tensor tiling.
Size: 41 registers (`0xA4` bytes, `0x29` words).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3a8` | **Control** | **Src1ReLU**: 0, **PaddingMode**: 2-3, **Src2ReLU**: 4, **Barrier**: 16. |
| **0x4104** | `+0x3ac` | **Src1Cfg** | **Type**: 0-1, **Format**: 6-7, **Interleave**: 8-11, **Compression**: 25-26. |
| **0x4108** | `+0x3b0` | **Src2Cfg** | **Type**: 0-1, **Format**: 6-7, **Interleave**: 8-11, **Compression**: 25-26. |
| **0x410C** | `+0x3b4` | **SrcIdxCfg** | **Type**: 0-1, **Format**: 6-7, **Interleave**: 8-11. |
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
| **0x413C** | `+0x3e4` | **SrcIdxChStride** | **Stride**: 4-20 (16B units). |
| **0x4140** | `+0x3e8` | **SrcIdxGrpStride** | **Stride**: 4-20 (16B units). |
| **0x4144** | `+0x3ec` | **SrcIdxDepStride** | **Stride**: 4-20 (16B units). |
| **0x4148** | `+0x3f0` | **ResultCfg** | **Type**: 0-1, **BfrMode**: 3, **CropOffsetXLSBs**: 4-6, **Format**: 6-7, **Interleave**: 8-11, **Compression**: 25-26. |
| **0x414C** | `+0x3f4` | **ResultBase** | **Addr**: 4-20 (16B units). |
| **0x4150** | `+0x3f8` | **ResultChStride** | **Stride**: 4-20 (16B units). |
| **0x4154** | `+0x3fc` | **ResultRowStride** | **Stride**: 4-20 (16B units). |
| **0x4158** | `+0x400` | **ResultDepStride** | **Stride**: 4-20 (16B units). |
| **0x415C** | `+0x404` | **ResultGrpStride** | **Stride**: 4-20 (16B units). |
| **0x4160** | `+0x408` | **ResultWrapBase** | **Addr**: 0-16. |
| **0x4164** | `+0x40c` | **GlobalWrapCfg** | **Src1Mode**: 0-2, **Src2Mode**: 4-6, **ResultMode**: 14-16. |
| **0x4168** | `+0x410` | **Src1WrapStride** | **Stride**: 16-31. |
| **0x416C** | `+0x414` | **Src2WrapStride** | **Stride**: 16-31. |
| **0x4170** | `+0x418` | **ResultWrapStride**| **Stride**: 16-31. |
| **0x4174** | `+0x41c` | **ResultWrapIdxOff** | **WrapIndex**: 0-15, **WrapStartOffs**: 16-31. |
| **0x4178** | `+0x420` | **Result2Cfg** | **SourceType**: 0-1, **Format**: 6-7, **Interleave**: 8-11. |
| **0x417C** | `+0x424` | **Result2Base** | **Addr**: 0-16. |
| **0x4180** | `+0x428` | **Result2ChStride** | **Stride**: 0-17. |
| **0x4184** | `+0x42c` | **Result2RowStride** | **Stride**: 0-16. |
| **0x4188** | `+0x430` | **Result2DepStride** | **Stride**: 0-17. |
| **0x418C** | `+0x434` | **Result2GrpStride** | **Stride**: 0-17. |
| **0x4190** | `+0x438` | **Src1AddrWrap** | **WrapAddr**: 0-11. |
| **0x4194** | `+0x43c` | **Src2AddrWrap** | **WrapAddr**: 0-11. |
| **0x419C** | `+0x444` | **ResultWrapAddr** | **WrapAddr**: 0-11. |
| **0x41A0** | `+0x448` | **ConsolidatedOff** | **Src1X**: 0-5, **Src1Y**: 8-12, **Src2X**: 16-21, **Src2Y**: 24-28. |

#### L2 Wrap Constraints:
- **0x4164**: **ResultWrapCfg**
- **0x4174**: **ResultWrapIdxOff**
- **0x419C**: **ResultWrapAddr**

### Cross-Cutting Subsystems: Quantization
Certain high-level configurations, like Quantization, touch multiple disparate hardware blocks simultaneously to coordinate data scaling and types across the pipeline. As decompiled from `ZinAneTd<17u>::SetQuantization*` methods:

**SetQuantizationSrc1InputOffset / Src2InputOffset**
- **Common (`+0x030`)**: Format overrides (`ch_cfg`).
- **L2 Cache (`+0x1cc` / `0x4100`)**: Padding/Relu scale (`control`).
- **Planar Engine (`+0x274`, `+0x278`, `+0x280`, `+0x284`, `+0x2a8`)**: Configures `bias`, `scale`, `pre_scale`, `final_scale`, and `quant` zero points.

**SetQuantizationOutputZeroOffset**
- **Neural Engine (`+0x2c8` / `0x4904`)**: Flips bit flags in `mac_cfg`.
- **Neural Engine (`+0x2f0`)**: Writes to `quant`.

**SetTexture***
The texture sampling feature (such as GatherMode) maps heavily into the extended spaces of the **TileDmaSrc** block (`0x4D00`).
- **TileDmaSrc (`+0x2C8`)**: Used for `TextureFilter`, `TextureWrap`, and `TextureIndexTensorInterleave`.
- **TileDmaSrc Extended (`+0x324` to `+0x33C`)**: Memory region explicitly dedicated to texture logic. Configures `ExtMax`, `Permute` (Idx, Ind, Src), `PreserveFraction`, `BackgroundEn`, and `CropBatchSplit`.
- *Note: `TextureBypassFilter` is checked via `SetTextureBypassFilter` but explicitly triggers an assertion since it is no longer supported on M4.*

## Hardware Traits (`ZinHWTraits<17u>`)
The compiler maintains a set of statically defined traits for the M4 architecture (`17u`) that explicitly dictate the raw memory offsets of hardware components. Memory dumping `__DATA_CONST` reveals strict validation of our L2 and TileDMA address deductions:

| Trait Symbol | Hex Value | Decimal | Block Affiliation |
| --- | --- | --- | --- |
| `ANE_L2_SOURCE2_CHANNEL_STRIDE_OFFSET` | `0x4128` | `16680` | Src2 Base Channel Stride |
| `ANE_L2_RESULT_CHANNEL_STRIDE_OFFSET` | `0x4150` | `16720` | Result Group Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET` | `0x4D1C` | `19740` | TileDmaSrc1 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET` | `0x4D20` | `19744` | TileDmaSrc1 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET` | `0x4D24` | `19748` | TileDmaSrc1 Group Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET` | `0x4D34` | `19764` | TileDmaSrc2 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET` | `0x4D38` | `19768` | TileDmaSrc2 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET` | `0x4D3C` | `19772` | TileDmaSrc2 Group Stride |
| `ANE_TILE_DMA_DST_PLANE_STRIDE_OFFSET` | `0x5114` | `20756` | TileDmaDst Channel Stride |
| `ANE_TILE_DMA_DST_DEPTH_STRIDE_OFFSET` | `0x5118` | `20760` | TileDmaDst Depth Stride |
| `ANE_TILE_DMA_DST_GROUP_STRIDE_OFFSET` | `0x511C` | `20764` | TileDmaDst Group Stride |

*(Note: In the ANE nomenclature, "Plane" defines the Channel spacing offset.)*
