## Object-to-Hardware Mapping Blocks

The `ZinAneTd<20u>` object maps internal offsets to hardware register blocks as follows:

| Source Offset (`this`) | Reg Count (Words) | HW Start Address | HW End Address | Primary Feature Area |
| :--- | :--- | :--- | :--- | :--- |
| `+0x224` | `0x17` | `0x0000` | `0x005C` | Common (InDim, OutDim, Patch, PETra) |
| `+0x3d8` | `0x2b` | `0x4100` | `0x41AC` | L2 Cache / Buffer |
| `+0x48c` | `0x10` | `0x4500` | `0x4540` | PE (Planar Engine) |
| `+0x4d4` | `0x0d` | `0x4900` | `0x4934` | NE (Neural Engine) |
| `+0x28c` | `0x51` | `0x4d00` | `0x4E44` | TileDmaSrc (Engine Control) |
| `+0x510` | `0x1b` | `0x5100` | `0x516C` | TileDmaDst (Engine Control) |
| `+0x034` | `0x53` | `0x5500` | `0x564C` | KernelDmaSrc (Stride, Coeffs) |
| `+0x584` | `0x0e` | `0x5900` | `0x5938` | CacheDMA & Telemetry |

## Internal Object Blocks

### KernelDmaSrc (0x5500 block, Object `+0x034`)
- **Count**: 83 registers (`0x53` words, `0x14c` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x034` | **MasterConfig** | **GroupKernelReuse**: 4, **KernelSparseFmt**: 5, **MasterEnable**: 6. |
| **0x5504** | `+0x038` | **AlignedCoeffSizePerCh** | **Size**: 0-27. |
| **0x5508** | `+0x03c` | **Prefetch** | **EarlyTermEn**: 0, **StopOnError**: 1, **PrefetchRate**: 16-31. |
| ... | ... | ... | ... |
| **0x5614** | `+0x148` | **NLutBaseAddr** | **Addr**: 6-31. |
| **0x5618** | `+0x14c` | **NLutReserved0** |  |
| **0x561C** | `+0x150` | **NLutReserved1** |  |
| **0x5620** | `+0x154` | **NewField0x5620** | New in H18. |
| **0x564C** | `+0x180` | **NewField0x564C** | New in H18 (End of block). |

| **0x003C** | `+0x264` | **MacCfg** | **SmallSrcMode**: 2-3, **TaskType**: 4-7, **ActiveNE**: 19-21, **OutTranspose**: 28, **FillLowerNEFirst**: 29. (Verified via binary) |
| **0x0040** | `+0x268` | **NECfg** | **OCGSize**: 0-7, **FatTileEnable**: 8, **WUStackLog2**: 9-10. (Verified via binary) |
| **0x0044** | `+0x26C` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x270` | **PECfg** | **Flags**: 0-4 (Src1BR:0, Src2BR:1, Src1T:2, Src2T:3, OutT:4). (Verified via binary) |
| **0x004C** | `+0x274` | **NID** | Network ID / Layer Trace ID. |
| **0x0050** | `+0x278` | **DPE** | Distributed Processing Element config. |
| ... | ... | ... | ... |

### TileDMA Source (0x4D00 block, Object `+0x28c`)
- **Count**: 81 registers (`0x51` words, `0x144` bytes).

| HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4D00** | `+0x28c` | **Src1DMAConfig** |  |
| **0x4D78** | `+0x304` | **Src1CompressedInfo** | **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingFormatTableIdx**: 4-9, **LossyEnable**: 13, **MdUserTag**: 24-31. (Verified via binary) |
| **0x4DF8** | `+0x384` | **Src1Ephemeral** | **EphemeralEnable**: 0. (Verified via binary) |
| ... | ... | ... | ... |
| **0x4E40** | `+0x3cc` | **TileDmaSrcReserved** |  |

### L2 Cache / Buffer (0x4100 block, Object `+0x3d8`)
- **Count**: 43 registers (`0x2b` words, `0xac` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3d8` | **Control** |  |
| ... | ... | ... | ... |
| **0x41A8** | `+0x480` | **NewField0x41A8** | New in H18. |
| **0x41AC** | `+0x484` | **NewField0x41AC** | New in H18. |

### Neural Engine (NE) (0x4900 block, Object `+0x4d4`)
- **Count**: 13 registers (`0x0d` words, `0x34` bytes).

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x4d4` | **KernelCfg** |  |
| ... | ... | ... | ... |
| **0x4930** | `+0x504` | **NewField0x4930** | New in H18. |

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
