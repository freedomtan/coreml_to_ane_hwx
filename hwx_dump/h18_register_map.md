## Object-to-Hardware Mapping Blocks

The `ZinAneTd<20u>` object maps internal offsets to hardware register blocks as follows:

| Source Offset (`this`) | Reg Count (Words) | HW Start Address | HW End Address | Primary Feature Area |
| :--- | :--- | :--- | :--- | :--- |
| `+0x228` | `0x17` | `0x0000` | `0x005C` | Common (InDim, OutDim, Patch, PETra) | (Verified @ 0x228)
| `+0x3d8` | `0x2b` | `0x4100` | `0x41AC` | L2 Cache / Buffer |
| `+0x48c` | `0x10` | `0x4500` | `0x4540` | PE (Planar Engine) | (Verified @ 0x48c)
| `+0x4d4` | `0x0d` | `0x4900` | `0x4934` | NE (Neural Engine) |
| `+0x28c` | `0x51` | `0x4d00` | `0x4E44` | TileDmaSrc (Engine Control) |
| `+0x510` | `0x1b` | `0x5100` | `0x516C` | TileDmaDst (Engine Control) |
| `+0x034` | `0x53` | `0x5500` | `0x564C` | KernelDmaSrc (Stride, Coeffs) |
| `+0x584` | `0x0e` | `0x5900` | `0x5938` | CacheDMA & Telemetry |

## Internal Object Blocks

### Common (0x0000 block, Object `+0x228`)
- **Count**: 23 registers (`0x17` words, `0x5c` bytes).

| **HW Addr** | **Offset (`this`)** | **Register Name** | **Bit-Field Mapping** |
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x228` | **ChannelCfg** | **InFmt**: 0-2, **Src2InFmt**: 3-5, **OutFmt**: 6-8. (Verified 3-bit fields) |
| **0x0004** | `+0x22C` | **InWidth** | **Win**: 0-16. (17-bit dimension) |
| **0x0008** | `+0x230` | **InHeight** | **Hin**: 0-16. (17-bit dimension) |
| **0x000C** | `+0x234` | **InChannels** | **Cin**: 0-16. (17-bit dimension) |
| **0x0010** | `+0x238` | **InDepth** | **Din**: 0-16. (17-bit dimension) |
| **0x0014** | `+0x23C` | **OutWidth** | **Wout**: 0-16. (17-bit dimension) |
| **0x0018** | `+0x240` | **OutHeight** | **Hout**: 0-16. (17-bit dimension) |
| **0x001C** | `+0x244` | **OutChannels** | **Cout**: 0-16. (17-bit dimension) |
| **0x0020** | `+0x248` | **OutDepth** | **Dout**: 0-16. (17-bit dimension) |
| **0x0024** | `+0x24C` | **NumGroups** | **Ng**: 0-12? (Verified `SetCommonNumGroups` @ `0x24c`) |
| **0x0028** | `+0x250` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PadLeft**: 17-21, **PadTop**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **0x002C** | `+0x254` | **ConvCfg3D** | **KD**: 0-5, **SZ**: 6-7, **PZ**: 8-12, **OZ**: 13-14. (Verified via disassembly) |
| **0x0030** | `+0x258` | **UnicastCfg** | **UnicastEnable**: 0. (Verified `SetUnicastEn` @ `0x258`) |
| **0x0034** | `+0x25C` | **TileHeight** | **Hin**: 0-16. (Verified `SetTileHeight` @ `0x25c`) |
| **0x0038** | `+0x260` | **TileOverlap** | **Overlap**: 0-4? **PadTop**: 16-20, **PadBottom**: 21-25. (Verified @ `0x260`) |
| **0x003C** | `+0x264` | **MacCfg** | **SmallSrcMode**: 2-3, **TaskType**: 4-7, **ActiveNE**: 19-21, **OutTranspose**: 28, **FillLowerNEFirst**: 29. |
| **0x0040** | `+0x268` | **NECfg** | **OCGSize**: 0-2, **HalfWUMode**: 6-7. (Verified 3-bit OCGSize) |
| **0x0044** | `+0x26C` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x270` | **PECfg** | **OutputCtoW:0, Src1Trans:2, Src2Trans:3, OutTrans:4**. (Verified via `Lj20::SetPE*`) |
| **0x004C** | `+0x274` | **NID** | **Network ID**: 0-31. (Verified `SetNID` @ `0x274`) |
| **0x0050** | `+0x278` | **DPE** | **DPE Control**. (Verified `SetCommonDPE` @ `0x278`) |
| **0x0054** | `+0x27C` | **DPE0** | **DPE Data 0**. (Verified `SetCommonDPE0` @ `0x27c`) |
| **0x0058** | `+0x280` | **DPE1** | **DPE Data 1**. (Verified `SetCommonDPE1` @ `0x280`) |

### L2 Cache / Buffer (0x4100 block, Object `+0x3d8`)
- **Count**: 43 registers (`0x2b` words, `0xac` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3d8` | **Control** | **Barrier**: 23. (Verified via `SetL2Barrier`) |
| **0x4104** | `+0x3dc` | **Src1Cfg** | **SrcType**: 0-1. (Verified via `SetL2Src1SourceType`) |
| **0x4108** | `+0x3e0` | **Src2Cfg** | **SrcType**: 0-1. |
| **0x4148** | `+0x420` | **ResultCfg** | **ResType**: 0-1. (Verified via `SetL2ResultType`) |
| **0x414C** | `+0x424` | **ResultBaseAddr** | **Base**: 0-31. |
| **0x4150** | `+0x428` | **ResultChannelStride** | **Stride**: 0-31. |
| **0x4154** | `+0x42c` | **ResultRowStride** | **Stride**: 0-31. |
| **0x4164** | `+0x43c` | **ResultWrapCfg** | (Wait, H18 calls this `SetL2ResultWrapAddr`) |


### Neural Engine (NE) (0x4900 block, Object `+0x4d4`)
- **Count**: 13 registers (`0x0d` words, `0x34` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x4d4` | **KernelCfg** | **KernelFmt**: 0-3. **Sparse**: 6. |
| **0x0004** | `+0x4d8` | **KernelCfg2** | **OpMode**: 0-5. **KernelMode**: 6-10. |
| **0x0008** | `+0x4dc` | **InShift** | |
| **0x000C** | `+0x4e0` | **InShift2** | |
| **0x0010** | `+0x4e4` | **OutputShift** | |
| **0x0014** | `+0x4e8` | **BiasCfg** | **RcasMode**: 0-2. |
| **0x0018** | `+0x4ec` | **PostScaleCfg** | **StochasticRounding**: 0-7. |
| **0x001C** | `+0x4f0` | **ZQuantCfg** | **StochasticRounding Seed**. |
| **0x0020** | `+0x4f4` | **ZQuantCfg2** | |
| **0x0024** | `+0x4f8` | **QuantCfg** | |
| **0x0028** | `+0x4fc` | **QuantCfg2** | |
| **0x002C** | `+0x500` | **NEFlags** | |
| **0x0030** | `+0x504` | **NEFlags2** | |

### Planar Engine (PE) (0x4500 block, Object `+0x48c`)
- **Count**: 16 registers (`0x10` words, `0x40` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4500** | `+0x48c` | **PE_Config** | **Pool**: 0-1, **Op**: 2-4, **LutEn**: 5, **Cond**: 6-8, **RedIdx**: 9-10, **RedKeep**: 11, **NLMode**: 12-14, **CtoW**: 15, **Src1Idx**: 16-19, **Src2Idx**: 20-23, **MaxIdx**: 24-31. |
| **0x4504** | `+0x490` | **PE_Bias** | Float32 bias value. |
| **0x4508** | `+0x494` | **PE_Scale** | Float32 scale value. |
| **0x450C** | `+0x498` | **PE_Epsilon** | Float32 epsilon value. |
| **0x4510** | `+0x49c` | **PE_PreScale** | Float32 pre-scale value. |
| **0x4514** | `+0x4a0` | **PE_FinalScale** | Float32 final scale value. |
| **0x4518** | `+0x4a4` | **PE_Src1Cfg** | **Relu**: 1, **Transpose**: 3, **Src1Idx**: 12-15. |
| **0x451C** | `+0x4a8` | **Reserved** |  |
| **0x4520** | `+0x4ac` | **PE_Src2Cfg** | **Relu**: 1, **Transpose**: 3, **Src2Idx**: 12-15. |


### TileDMA Source (0x4D00 block, Object `+0x28c`)
- **Count**: 81 registers (`0x51` words, `0x144` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4D00** | `+0x28c` | **Src1DMAConfig** |  |
| **0x4D78** | `+0x304` | **Src1CompressedInfo** | **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingFormatTableIdx**: 4-9, **LossyEnable**: 13, **MdUserTag**: 24-31. (Verified via binary) |
| **0x4DF8** | `+0x384` | **Src1Ephemeral** | **EphemeralEnable**: 0. (Verified via binary) |
| ... | ... | ... | ... |
| **0x4E40** | `+0x3cc` | **TileDmaSrcReserved** |  |

### TileDMA Destination (0x5100 block, Object `+0x510`)
- **Count**: 27 registers (`0x1b` words, `0x6c` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5100** | `+0x510` | **DstDMAConfig** |  |
| ... | ... | ... | ... |
| **0x5138** | `+0x548` | **DstFmtCtrl** | **ZeroPadLast**: 0, **ZeroPadFirst**: 1, **OffsetCh**: 8-11, **CmpVec**: 12-15, **Interleave**: 24-27. (Verified via binary) |
| **0x5140** | `+0x550` | **DstCompressedInfo**| **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingFormatTableIdx**: 4-9, **LossyEnable**: 13. (Verified via binary) |
| **0x5164** | `+0x574` | **NewField0x5164** | New in H18. |
| **0x5168** | `+0x578` | **NewField0x5168** | New in H18. |

### KernelDMA Source (0x5500 block, Object `+0x034`)
- **Count**: 83 registers (`0x53` words, `0x14c` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x034` | **MasterConfig** | **GroupKernelReuse**: 4, **KernelSparseFmt**: 5, **MasterEnable**: 6. |
| **0x5504** | `+0x038` | **AlignedCoeffSizePerCh** | **Size**: 0-27. |
| **0x5518** | `+0x04c` | **StrideX** | **Stride**: 6-31. |
| **0x551C** | `+0x050` | **StrideY** | **Stride**: 6-31. |
| **0x5520** | `+0x054` | **CoeffDMAConfig0**| **CacheHint**: 4-7, **DataSetId**: 8-15. |
| **0x5560** | `+0x094` | **CoeffBaseAddr0** | **Addr**: 6-31. |
| **0x55A0** | `+0x0d4` | **CoeffBfrSize0** | **Size**: 6-31. |
| **0x55E0** | `+0x114` | **BiasDMAConfig** | **CacheHint**: 4-7. |
| **0x55E4** | `+0x118` | **BiasBaseAddr** | **Addr**: 6-31. |
| **0x55F0** | `+0x124` | **PostScaleDMAConfig** | **CacheHint**: 4-7. |
| **0x55F4** | `+0x128` | **PostScaleBaseAddr** | **Addr**: 6-31. |
| **0x5600** | `+0x134` | **PaletteDMAConfig** | **CacheHint**: 4-7. |
| **0x5604** | `+0x138` | **PaletteBaseAddr** | **Addr**: 6-31. |
| **0x5610** | `+0x144` | **NLutDMAConfig** | **CacheHint**: 4-7. |
| **0x5614** | `+0x148` | **NLutBaseAddr** | **Addr**: 6-31. |

| **0x5618** | `+0x14c` | **NLutReserved0** |  |
| **0x561C** | `+0x150` | **NLutReserved1** |  |
| **0x5620** | `+0x154` | **NewField0x5620** | New in H18. |
| **0x564C** | `+0x180` | **NewField0x564C** | New in H18 (End of block). |

### CacheDMA / Telemetry (0x5900 block, Object `+0x584`)
- **Count**: 14 registers (`0x0e` words, `0x38` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x584` | **TelemetryControl** |  |
| ... | ... | ... | ... |
| **0x5930** | `+0x5b4` | **NewField0x5930** | New in H18. |
| **0x5934** | `+0x5b8` | **NewField0x5934** | New in H18. |

---
*Verified via binary analysis of ANECompiler on macOS (H18/v20).*
