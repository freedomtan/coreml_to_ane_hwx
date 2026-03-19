## Object-to-Hardware Mapping Blocks

The `ZinAneTd<19u>` object maps internal offsets to hardware register blocks as follows:

| Source Offset (`this`) | Reg Count (Words) | HW Start Address | HW End Address | Primary Feature Area |
| :--- | :--- | :--- | :--- | :--- |
| `+0x204` | `0x17` | `0x0000` | `0x005C` | Common (InDim, OutDim, Patch, PETra) |
| `+0x3bc` | `0x2a` | `0x4100` | `0x41A8` | L2 Cache / Buffer |
| `+0x46c` | `0x10` | `0x4500` | `0x4540` | PE (Planar Engine) |
| `+0x4b4` | `0x0d` | `0x4900` | `0x4934` | NE (Neural Engine) |
| `+0x268` | `0x53` | `0x4d00` | `0x4E4C` | TileDmaSrc (Engine Control) |
| `+0x4f0` | `0x17` | `0x5100` | `0x515C` | TileDmaDst (Engine Control) |
| `+0x034` | `0x4a` | `0x5500` | `0x5628` | KernelDmaSrc (Stride, Coeffs) |
| `+0x554` | `0x0e` | `0x5900` | `0x5938` | CacheDMA & Telemetry |

Before registers, there are some header words.

| Source Offset (`this`) | Name | Word index | Note |
| :--- | :--- | :--- | :--- |
| `+0x008` | `TID / TaskSize` | 2 | Headers[0] |
| `+0x00c` | `ExeCycles` | 3 | Headers[1] |
| `+0x010` | `LogEvents` | 4 | Headers[2] |
| `+0x014` | `Exceptions` | 5 | Headers[3] |
| `+0x01c` | `DebugExceptions`| 7 | Headers[5] |
| `+0x024` | `UnknownFlags` | 9 | Headers[7] |
| `+0x028` | `Control Flags`| 10 | Headers[8] |
| `+0x02c` | `DTID` | 11 | Headers[9] |

## Internal Object Blocks

### KernelDmaSrc (0x5500 block, Object `+0x034`)
- **Count**: 74 registers (`0x4a` words, `0x128` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x034` | **MasterConfig** | **GroupKernelReuse**: 4, **KernelSparseFmt**: 5, **MasterEnable**: 6. |
| **0x5504** | `+0x038` | **AlignedCoeffSizePerCh** | **Size**: 0-27. |
| **0x5508** | `+0x03c` | **Prefetch** | **EarlyTermEn**: 0, **StopOnError**: 1, **PrefetchRate**: 16-31. |
| **0x5518** | `+0x04c` | **StrideX** | **Stride**: 6-31. |
| **0x551C** | `+0x050` | **StrideY** | **Stride**: 6-31. |
| **0x5520** | `+0x054` | **CoeffDMAConfig0**| **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| ... | ... | ... | ... |
| **0x5560** | `+0x094` | **CoeffBaseAddr0** | **Addr**: 6-31. |
| ... | ... | ... | ... |
| **0x55A0** | `+0x0d4` | **CoeffBfrSize0** | **Size**: 6-31. |
| ... | ... | ... | ... |
| **0x55E0** | `+0x114` | **BiasDMAConfig** |  |
| **0x55E4** | `+0x118` | **BiasBaseAddr** |  |
| **0x55F0** | `+0x124` | **PostScaleDMAConfig** |  |
| **0x55F4** | `+0x128` | **PostScaleBaseAddr** |  |
| **0x5600** | `+0x134` | **PaletteDMAConfig** |  |
| **0x5604** | `+0x138` | **PaletteBaseAddr** |  |
| **0x5610** | `+0x144` | **NLutDMAConfig** |  |
| **0x5614** | `+0x148` | **NLutBaseAddr** |  |
| **0x5620** | `+0x154` | **NewField0x5620** | New in H17. |
| **0x5624** | `+0x158` | **NewField0x5624** | New in H17. |

### Common (0x0000 block, Object `+0x204`)
- **Count**: 23 registers (`0x17` words, `0x5C` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x204` | **ChannelCfg** | **InFmt**: 0-1, **Src2InFmt**: 2-3, **OutFmt**: 4-5. |
| **0x0004** | `+0x208` | **InWidth** | **Win**: 0-16. (Verified via binary: `GetWin` @ `+208`) |
| **0x0008** | `+0x20C` | **InHeight** | **Hin**: 0-16. (Verified via binary: `GetHin` @ `+20C`) |
| **0x000C** | `+0x210` | **InChannels** | **Cin**: 0-16. (Verified via binary) |
| **0x0010** | `+0x214` | **InDepth** | **Din**: 0-16. (Verified via binary) |
| **0x0014** | `+0x218` | **OutWidth** | **Wout**: 0-16. (Verified via binary) |
| **0x0018** | `+0x21C` | **OutHeight** | **Hout**: 0-16. (Verified via binary) |
| **0x001C** | `+0x220` | **OutChannels** | **Cout**: 0-16. (Verified via binary) |
| **0x0020** | `+0x224` | **OutDepth** | **Dout**: 0-16. (Verified via binary) |
| **0x0024** | `+0x228` | **NumGroups** | Batch size / Number of groups. (Verified via binary) |
| **0x0028** | `+0x22C` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PadLeft**: 17-21, **PadTop**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **0x002C** | `+0x230` | **ConvCfg3d** | **3dKd**: 0-4, **3dSz**: 6-7, **3dPz**: 8-11, **3dOz**: 13-14. |
| **0x0030** | `+0x234` | **UnicastCfg** | **UnicastEn**: 14, **UnicastCin**: 16-31. |
| **0x0034** | `+0x238` | **TileHeight** | **TileHeight**: 0-16. |
| **0x0038** | `+0x23C` | **TileOverlap** | **Overlap**: 16-20, **PadTop**: 21-25, **PadBottom**: 26-30. |
| **0x003C** | `+0x240` | **MacCfg** | **SmallSrcMode**: 2-3, **TaskType**: 4-7, **ActiveNE**: 19-21, **OutTranspose**: 28, **FillLowerNEFirst**: 29. (Verified via binary) |
| **0x0040** | `+0x244` | **NECfg** | **OCGSize**: 0-7, **FatTileEnable**: 8, **WUStackLog2**: 9-10. (Verified via binary) |
| **0x0044** | `+0x248` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x24C` | **PECfg** | **Flags**: 0-4 (Src1BR:0, Src2BR:1, Src1T:2, Src2T:3, OutT:4). (Verified via binary) |
| **0x004C** | `+0x250` | **NID** | Network ID / Layer Trace ID. |
| **0x0050** | `+0x254` | **DPE** | Distributed Processing Element config. |

### TileDMA Source (0x4D00 block, Object `+0x268`)
- **Count**: 83 registers (`0x53` words, `0x14c` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4D78** | `+0x2d4` | **Src1CompressedInfo** | **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingFormatTableIdx**: 4-9, **LossyEnable**: 13, **MdUserTag**: 24-31. (Verified via binary) |
| **0x4D7C** | `+0x2d8` | **Src1CompressedSizeLo** | **SizeLo**: 0-31. |
| **0x4D80** | `+0x2dc` | **Src1CompressedSizeHi** | **SizeHi**: 0-31. |
| **0x4D84** | `+0x2e0` | **Src1CropOffset** | **OffsetY**: 0-15 (strh), **CropOffset**: 16-31. |
| **0x4D88** | `+0x2e4` | **Src2CompressedInfo** | **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingFormatTableIdx**: 4-9, **LossyEnable**: 13, **MdUserTag**: 24-31. (Verified via binary) |
| ... | ... | ... | ... |
| **0x4DF8** | `+0x354` | **Src1Ephemeral** | **EphemeralEnable**: 0. (Verified via binary) |
| **0x4DFC** | `+0x358` | **TileDmaSrcReserved** |  |
| **0x5138** | `+0x528` | **DstFmtCtrl** | **ZeroPadLast**: 0, **ZeroPadFirst**: 1, **OffsetCh**: 8-11, **CmpVec**: 12-15, **Interleave**: 24-27. (Verified via binary) |
| **0x513C** | `+0x52c` | **DstReserved3** | Reserved. |
| **0x5140** | `+0x530` | **DstCompressedInfo**| **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingFormatTableIdx**: 4-9, **LossyEnable**: 13. (Verified via binary) |

### L2 Cache / Buffer (0x4100 block, Object `+0x3bc`)
- **Count**: 42 registers (`0x2a` words, `0xA8` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3bc` | **Control** |  |
| ... | ... | ... | ... |
| **0x41A4** | `+0x460` | **NewField0x41A4** | New in H17. |

### Planar Engine (PE) (0x4500 block, Object `+0x46c`)
- **Count**: 16 registers (`0x10` words, `0x40` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4500** | `+0x46c` | **Config** |  |
| ... | ... | ... | ... |
| **0x453C** | `+0x4ac` | **NewField0x453C** | New in H17? (M4 padding). |

### Neural Engine (NE) (0x4900 block, Object `+0x4b4`)
- **Count**: 13 registers (`0x0d` words, `0x34` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x4b4` | **KernelCfg** |  |
| ... | ... | ... | ... |
| **0x4930** | `+0x4e4` | **NewField0x4930** | New in H17. |

### TileDMA Destination (0x5100 block, Object `+0x4f0`)
- **Count**: 23 registers (`0x17` words, `0x5c` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5100** | `+0x4f0` | **DstDMAConfig** |  |
| ... | ... | ... | ... |
| **0x5154** | `+0x544` | **NewField0x5154** | New in H17. |
| **0x5158** | `+0x548` | **NewField0x5158** | New in H17. |

### CacheDMA / Telemetry (0x5900 block, Object `+0x554`)
- **Count**: 14 registers (`0x0e` words, `0x38` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x554` | **TelemetryControl** |  |
| ... | ... | ... | ... |
| **0x5930** | `+0x584` | **NewField0x5930** | New in H17. |
| **0x5934** | `+0x588` | **NewField0x5934** | New in H17. |

---
*Verified via binary analysis of ANECompiler on macOS (H17/v19).*
