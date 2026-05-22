## Object-to-Hardware Mapping Blocks

The `ZinAneTd<11u>` object maps internal offsets to hardware register blocks as follows:

| Source Offset (`this`) | Reg Count (Words) | HW Start (OLD) | HW End (OLD) | HW Start (Modern) | Primary Feature Area |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `+0x02c` | `0x46` (70) | `0x1900` | `0x1A18` | `0x5500` | KernelDmaSrc (Stride, Coeffs) |
| `+0x1ec` | `0x13` (19) | `0x0000` | `0x004C` | `0x0000` | Common (InDim, OutDim, Conv params) |
| `+0x240` | `0x35` (53) | `0x1100` | `0x11D4` | `0x4D00` | TileDmaSrc (Engine Control) |
| `+0x31c` | `0x19` (25) | `0x0500` | `0x0564` | `0x4100` | L2 Cache / Buffer |
| `+0x388` | `0x05` (5)  | `0x0900` | `0x0914` | `0x4900` | NE (Neural Engine) |
| `+0x3a4` | `0x05` (5)  | `0x0D00` | `0x0D14` | `0x5100` | TileDmaDst (Engine Control) |
| `+0x3c0` | `0x09` (9)  | `0x1500` | `0x1524` | `0x5900` | CacheDMA & Telemetry |

Before registers, there are some header words.

**⚠️ H14 Address Translation Note:** H14 (`ZinAneTd<11u>`) uses an OLD hardware address layout. Modern tools (H15+) remap these:
- `0x0000` → `0x0000` (Common — unchanged)
- `0x0500` → `0x4100` (L2 Cache — `+0x3C00`)
- `0x0900` → `0x4900` (NE — `+0x4000`)
- `0x0D00` → `0x5100` (TileDmaDst — `+0x4400`)
- `0x1100` → `0x4D00` (TileDmaSrc — `+0x3C00`)
- `0x1500` → `0x5900` (CacheDMA — `+0x4400`)
- `0x1900` → `0x5500` (KernelDmaSrc — `+0x3C00`)

*All block offsets verified from `ZinAneTd<11u>::InitializeTdToDefaults()` at 0x1a6bff68c.*

*Note on `ZinAneTd<11u>` Initialization*: The block offset mapping is structurally enforced during memory initialization. `InitializeTdToDefaults` directly populates each array, e.g.:
```cpp
SetDefaultValuesToRegisters((uint *)(this + 0x31c), 0x19, 0x0500, puVar2);
```

| Source Offset (`this`) | Name | Description | Note |
| :--- | :--- | :--- | :--- |
| `+0x008` | `TID / TaskSize` | **TID**: 0-15, **TaskSize**: 16-26. | Headers[0] |
| `+0x00c` | `ExeCycles` | **ExeCycles**: 0-16. | Headers[1] |
| `+0x010` | `LogEvents` | **LogEvents**: 0-23. | Headers[2] |
| `+0x014` | `Exceptions` | **Exceptions**: 0-23. | Headers[3] |
| `+0x018` | `LiveOuts` | **LiveOuts**: 0-31. | Headers[4] |
| `+0x01c` | `Control Flags` | **TSR**: 0, **TDE**: 1, **ENE**: 16-18. | Headers[5] |
| `+0x020` | `DTID` | **DTID**: 0-15. | Headers[6] |

## Register Offsets and Meanings

Word Index is computed as `HW Addr (OLD) / 4`.

| Word Index | OLD HW Addr | Modern HW Addr | Name | Description |
| :--- | :--- | :--- | :--- | :--- |
| **0** | `0x0000` | `0x0000` | **ChannelCfg** | **InFmt**: 0-1, **Src2InFmt**: 2-3, **OutFmt**: 4-5. |
| **1** | `0x0004` | `0x0004` | **InWidth** | **Win**: 0-13. |
| **2** | `0x0008` | `0x0008` | **InHeight** | **Hin**: 0-13. |
| **3** | `0x000C` | `0x000C` | **InChannels** | **Cin**: 0-13. |
| **4** | `0x0010` | `0x0010` | **InDepth** | **Din**: 0-13. |
| **5** | `0x0014` | `0x0014` | **OutWidth** | **Wout**: 0-13. |
| **6** | `0x0018` | `0x0018` | **OutHeight** | **Hout**: 0-13. |
| **7** | `0x001C` | `0x001C` | **OutChannels** | **Cout**: 0-13. |
| **8** | `0x0020` | `0x0020` | **OutDepth** | **Dout**: 0-13. |
| **9** | `0x0024` | `0x0024` | **NumGroups** | Batch size / Number of groups. |
| **10** | `0x0028` | `0x0028` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PX**: 17-21, **PY**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **11** | `0x002C` | `0x002C` | **ConvCfg3d** | **Kd**: 0-5, **Sz**: 6-11, **Pz**: 12-16, **Oz**: 17-21. |
| **12** | `0x0030` | `0x0030` | **MacCfg** | **TaskType**: 0-3, **ActiveNE**: 4-6, **SmallSrc**: 7, **ReluType**: 8-10. |
| ... | ... | ... | ... | ... |
| **0x240** | `0x0900` | `0x4900` | **KernelCfg** | **Fmt**: 0-1, **PalettizedEn**: 2, **SparseEn**: 8. |
| **0x241** | `0x0904` | `0x4904` | **MacCfg (NE)** | **OpMode**: 0-2, **KernelMode**: 3, **BinPoint**: 8-13. |
| **0x646** | `0x1918` | `0x5518` | **KernelStrideX** | **StrideX**: 6-31. (NEW in H14) |
| **0x647** | `0x191C` | `0x551C` | **KernelStrideY** | **StrideY**: 6-31. (NEW in H14) |

## Internal Object Blocks
The `ZinAneTd<11u>` object (descriptor) is divided into these hardware-mapped regions:
- **Common (0x0000)**: Generic geometry, patch size, and primary convolution config.
- **L2 Cache (0x0500 OLD / 0x4100 Modern)**: L2 buffer strides and wrap offsets.
- **PE**: Planar Engine (Bias, Quantization, Pooling) — not initialized in `InitializeTdToDefaults`; written via `CommonConfig` API methods.
- **NE (0x0900 OLD / 0x4900 Modern)**: Neural Engine core config (KernelFmt, OpMode, BinaryPoint).
- **TileDmaSrc (0x1100 OLD / 0x4D00 Modern)**: Tile DMA Source with DataSet IDs and 4D pixel offsets.
- **TileDmaDst (0x0D00 OLD / 0x5100 Modern)**: Tile DMA Destination with DataSet ID.
- **KernelDmaSrc (0x1900 OLD / 0x5500 Modern)**: Stride, coefficients, sparse block sizes, and 16-buffer DMA.
- **CacheDMA (0x1500 OLD / 0x5900 Modern)**: Telemetry and cache prefetch control.

## Detailed Bitfield Mappings

### KernelDmaSrc (0x1900 OLD / 0x5500 Modern, Object `+0x02c`)
- **Count**: 70 registers (`0x46` words, `0x118` bytes).
- **Object Layout**: Starts at `+0x02c` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x1900** | `0x5500` | `+0x02c` | **MasterConfig** | **GroupKernelReuse**: 4, **KernelSparseFmt**: 5, **MasterEnable**: 6. |
| **0x1904** | `0x5504` | `+0x030` | **AlignedCoeffSizePerCh** | **Size**: 0-27. |
| **0x1908** | `0x5508` | `+0x034` | **Prefetch** | **EarlyTermEn**: 0, **StopOnError**: 1, **PrefetchRate**: 16-31. |
| **0x190C** | `0x550C` | `+0x038` | **Reserved0** | Reserved. |
| **0x1910** | `0x5510` | `+0x03c` | **Reserved1** | Reserved. |
| **0x1914** | `0x5514` | `+0x040` | **Reserved2** | Reserved. |
| **0x1918** | `0x5518` | `+0x044` | **KernelGroupStride** | **Stride**: 6-31. (NEW in H14; arg1 of `SetKernelStrideRegisters`) |
| **0x191C** | `0x551C` | `+0x048` | **KernelOCGStride** | **Stride**: 6-31. (NEW in H14; arg2 of `SetKernelStrideRegisters`) |
| **0x1920** | `0x5520` | `+0x04c` | **CoeffDMAConfig0** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1924** | `0x5524` | `+0x050` | **CoeffDMAConfig1** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1928** | `0x5528` | `+0x054` | **CoeffDMAConfig2** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x192C** | `0x552C` | `+0x058` | **CoeffDMAConfig3** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1930** | `0x5530` | `+0x05c` | **CoeffDMAConfig4** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1934** | `0x5534` | `+0x060` | **CoeffDMAConfig5** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1938** | `0x5538` | `+0x064` | **CoeffDMAConfig6** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x193C** | `0x553C` | `+0x068` | **CoeffDMAConfig7** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1940** | `0x5540` | `+0x06c` | **CoeffDMAConfig8** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1944** | `0x5544` | `+0x070` | **CoeffDMAConfig9** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1948** | `0x5548` | `+0x074` | **CoeffDMAConfig10** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x194C** | `0x554C` | `+0x078` | **CoeffDMAConfig11** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1950** | `0x5550` | `+0x07c` | **CoeffDMAConfig12** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1954** | `0x5554` | `+0x080` | **CoeffDMAConfig13** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1958** | `0x5558` | `+0x084` | **CoeffDMAConfig14** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x195C** | `0x555C` | `+0x088` | **CoeffDMAConfig15** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x1960** | `0x5560` | `+0x08c` | **CoeffBaseAddr0** | **Addr**: 6-31. |
| **0x1964** | `0x5564` | `+0x090` | **CoeffBaseAddr1** | **Addr**: 6-31. |
| **0x1968** | `0x5568` | `+0x094` | **CoeffBaseAddr2** | **Addr**: 6-31. |
| **0x196C** | `0x556C` | `+0x098` | **CoeffBaseAddr3** | **Addr**: 6-31. |
| **0x1970** | `0x5570` | `+0x09c` | **CoeffBaseAddr4** | **Addr**: 6-31. |
| **0x1974** | `0x5574` | `+0x0a0` | **CoeffBaseAddr5** | **Addr**: 6-31. |
| **0x1978** | `0x5578` | `+0x0a4` | **CoeffBaseAddr6** | **Addr**: 6-31. |
| **0x197C** | `0x557C` | `+0x0a8` | **CoeffBaseAddr7** | **Addr**: 6-31. |
| **0x1980** | `0x5580` | `+0x0ac` | **CoeffBaseAddr8** | **Addr**: 6-31. |
| **0x1984** | `0x5584` | `+0x0b0` | **CoeffBaseAddr9** | **Addr**: 6-31. |
| **0x1988** | `0x5588` | `+0x0b4` | **CoeffBaseAddr10** | **Addr**: 6-31. |
| **0x198C** | `0x558C` | `+0x0b8` | **CoeffBaseAddr11** | **Addr**: 6-31. |
| **0x1990** | `0x5590` | `+0x0bc` | **CoeffBaseAddr12** | **Addr**: 6-31. |
| **0x1994** | `0x5594` | `+0x0c0` | **CoeffBaseAddr13** | **Addr**: 6-31. |
| **0x1998** | `0x5598` | `+0x0c4` | **CoeffBaseAddr14** | **Addr**: 6-31. |
| **0x199C** | `0x559C` | `+0x0c8` | **CoeffBaseAddr15** | **Addr**: 6-31. |
| **0x19A0** | `0x55A0` | `+0x0cc` | **CoeffBfrSize0** | **Size**: 6-31. |
| **0x19A4** | `0x55A4` | `+0x0d0` | **CoeffBfrSize1** | **Size**: 6-31. |
| **0x19A8** | `0x55A8` | `+0x0d4` | **CoeffBfrSize2** | **Size**: 6-31. |
| **0x19AC** | `0x55AC` | `+0x0d8` | **CoeffBfrSize3** | **Size**: 6-31. |
| **0x19B0** | `0x55B0` | `+0x0dc` | **CoeffBfrSize4** | **Size**: 6-31. |
| **0x19B4** | `0x55B4` | `+0x0e0` | **CoeffBfrSize5** | **Size**: 6-31. |
| **0x19B8** | `0x55B8` | `+0x0e4` | **CoeffBfrSize6** | **Size**: 6-31. |
| **0x19BC** | `0x55BC` | `+0x0e8` | **CoeffBfrSize7** | **Size**: 6-31. |
| **0x19C0** | `0x55C0` | `+0x0ec` | **CoeffBfrSize8** | **Size**: 6-31. |
| **0x19C4** | `0x55C4` | `+0x0f0` | **CoeffBfrSize9** | **Size**: 6-31. |
| **0x19C8** | `0x55C8` | `+0x0f4` | **CoeffBfrSize10** | **Size**: 6-31. |
| **0x19CC** | `0x55CC` | `+0x0f8` | **CoeffBfrSize11** | **Size**: 6-31. |
| **0x19D0** | `0x55D0` | `+0x0fc` | **CoeffBfrSize12** | **Size**: 6-31. |
| **0x19D4** | `0x55D4` | `+0x100` | **CoeffBfrSize13** | **Size**: 6-31. |
| **0x19D8** | `0x55D8` | `+0x104` | **CoeffBfrSize14** | **Size**: 6-31. |
| **0x19DC** | `0x55DC` | `+0x108` | **CoeffBfrSize15** | **Size**: 6-31. |
| **0x19E0** | `0x55E0` | `+0x10c` | **BiasDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x19E4** | `0x55E4` | `+0x110` | **BiasBaseAddr** | **Addr**: 6-31. |
| **0x19E8** | `0x55E8` | `+0x114` | **BiasReserved0** | Reserved. |
| **0x19EC** | `0x55EC` | `+0x118` | **BiasReserved1** | Reserved. |
| **0x19F0** | `0x55F0` | `+0x11c` | **PostScaleDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. |
| **0x19F4** | `0x55F4` | `+0x120` | **PostScaleBaseAddr** | **Addr**: 6-31. |
| **0x19F8** | `0x55F8` | `+0x124` | **PostScaleReserved0** | Reserved. |
| **0x19FC** | `0x55FC` | `+0x128` | **PostScaleReserved1** | Reserved. |
| **0x1A00** | `0x5600` | `+0x12c` | **SparseBlockSizeCfg** | **BlockSize**: 0-7. (NEW in H14; `SetKernelSparseBlockSize`) |
| **0x1A04** | `0x5604` | `+0x130` | **Reserved** | Reserved. |
| **0x1A08** | `0x5608` | `+0x134` | **Reserved** | Reserved. |
| **0x1A0C** | `0x560C` | `+0x138` | **Reserved** | Reserved. |
| **0x1A10** | `0x5610` | `+0x13c` | **Reserved** | Reserved. |
| **0x1A14** | `0x5614` | `+0x140` | **Reserved** | Reserved. |
| **0x1A18** | `0x5618` | `+0x144` | **Reserved** | Reserved. |

### Common (0x0000 block, Object `+0x1ec`)
- **Count**: 19 registers (`0x13` words, `0x4C` bytes).
- **Object Layout**: Starts at `+0x1ec` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x0000** | `0x0000` | `+0x1ec` | **ChannelCfg** | **InFmt**: 0-1, **Src2InFmt**: 2-3, **OutFmt**: 4-5. (Verified via `SetCommonSrc1InFmt`, `SetCommonSrc2InFmt`) |
| **0x0004** | `0x0004` | `+0x1f0` | **InWidth** | **Win**: 0-13. |
| **0x0008** | `0x0008` | `+0x1f4` | **InHeight** | **Hin**: 0-13. |
| **0x000C** | `0x000C` | `+0x1f8` | **InChannels** | **Cin**: 0-13. |
| **0x0010** | `0x0010` | `+0x1fc` | **InDepth** | **Din**: 0-13. |
| **0x0014** | `0x0014` | `+0x200` | **OutWidth** | **Wout**: 0-13. |
| **0x0018** | `0x0018` | `+0x204` | **OutHeight** | **Hout**: 0-13. |
| **0x001C** | `0x001C` | `+0x208` | **OutChannels** | **Cout**: 0-13. |
| **0x0020** | `0x0020` | `+0x20c` | **OutDepth** | **Dout**: 0-13. |
| **0x0024** | `0x0024` | `+0x210` | **NumGroups** | **NumGroups**: 0-13. |
| **0x0028** | `0x0028` | `+0x214` | **ConvCfg** | **KW**: 0-5, **KH**: 6-11, **SX**: 13-14, **SY**: 15-16, **PadLeft**: 17-21, **PadTop**: 22-26, **OX**: 28-29, **OY**: 30-31. |
| **0x002C** | `0x002C` | `+0x218` | **ConvCfg3d** | **Kd**: 0-5, **Sz**: 6-11, **Pz**: 12-16, **Oz**: 17-21. |
| **0x0030** | `0x0030` | `+0x21c` | **MacCfg** | **TaskType**: 0-3, **ActiveNE**: 4-6, **SmallSrc**: 7, **ReluType**: 8-10. (Verified via `SetCommonTaskType`, `SetCommonMacCfgActiveNE`) |
| **0x0034** | `0x0034` | `+0x220` | **TileHeight** | **TileHeight**: 0-13. |
| **0x0038** | `0x0038` | `+0x224` | **TileOverlap** | **Overlap**: 0-5, **PadTop**: 6-10. |
| **0x003C** | `0x003C` | `+0x228` | **NECfg** | **OCGSize**: 0-2, **FatTileEnable**: 3, **WUStackLog2**: 4-5. |
| **0x0040** | `0x0040` | `+0x22c` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0044** | `0x0044` | `+0x230` | **NID** | Network ID / Layer Trace ID. |
| **0x0048** | `0x0048` | `+0x234` | **DPE** | Distributed Processing Element config. |

*Note: H14 Common block is narrower than H16 (19 vs 23 registers). H16 adds `UnicastCfg`, `PECfg`, and relocated `GocStrideX/Y`.*

### TileDMA Source (0x1100 OLD / 0x4D00 Modern, Object `+0x240`)
- **Count**: 53 registers (`0x35` words, `0xD4` bytes).
- **Object Layout**: Starts at `+0x240` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x1100** | `0x4D00` | `+0x240` | **Src1DMAConfig** | **Enable**: 0, **CacheHint0**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. (NEW: DataSetId in H14) |
| **0x1104** | `0x4D04` | `+0x244` | **Src2DMAConfig** | **Enable**: 0, **CacheHint0**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. (NEW: DataSetId in H14) |
| **0x1108** | `0x4D08` | `+0x248` | **Src1WrapCfg** | **CacheHint1**: 0-7 (triple hint), **WrapCfg**: 8-10, **WrapStatic**: 16-31. |
| **0x110C** | `0x4D0C` | `+0x24c` | **Src2WrapCfg** | **CacheHint1**: 0-7 (triple hint), **WrapCfg**: 8-10, **WrapStatic**: 16-31. |
| **0x1110** | `0x4D10` | `+0x250` | **Src1BaseAddr** | **Addr**: 6-31. |
| **0x1114** | `0x4D14` | `+0x254` | **Src1RowStride** | **Stride**: 6-31. |
| **0x1118** | `0x4D18` | `+0x258` | **Src1ChannelStride** | **Stride**: 6-31. |
| **0x111C** | `0x4D1C` | `+0x25c` | **Src1DepthStride** | **Stride**: 6-31. |
| **0x1120** | `0x4D20` | `+0x260` | **Src1GroupStride** | **Stride**: 6-31. |
| **0x1124** | `0x4D24` | `+0x264` | **Src2BaseAddr** | **Addr**: 6-31. |
| **0x1128** | `0x4D28` | `+0x268` | **Src2RowStride** | **Stride**: 6-31. |
| **0x112C** | `0x4D2C` | `+0x26c` | **Src2ChannelStride** | **Stride**: 6-31. |
| **0x1130** | `0x4D30` | `+0x270` | **Src2DepthStride** | **Stride**: 6-31. |
| **0x1134** | `0x4D34` | `+0x274` | **Src2GroupStride** | **Stride**: 6-31. |
| **0x1138** | `0x4D38` | `+0x278` | **Src1Fmt** | **FormatMode**: 0-1, **Truncate**: 4-5, **MemFmt**: 12-13, **OffsetCh**: 16-18, **Interleave**: 24-27. |
| **0x113C** | `0x4D3C` | `+0x27c` | **Src2Fmt** | **FormatMode**: 0-1, **Truncate**: 4-5, **MemFmt**: 12-13, **OffsetCh**: 16-18, **Interleave**: 24-27. |
| **0x1140** | `0x4D40` | `+0x280` | **Src1CacheHint2** | **CacheHint2**: 0-7 (triple hint, 3rd field). |
| **0x1144** | `0x4D44` | `+0x284` | **Src2CacheHint2** | **CacheHint2**: 0-7 (triple hint, 3rd field). |
| **0x1148** | `0x4D48` | `+0x288` | **Src1PixelOffsetX** | **PixelOffsetX**: 0-15. (H14 preserves 4D pixel offsets from H13) |
| **0x114C** | `0x4D4C` | `+0x28c` | **Src1PixelOffsetY** | **PixelOffsetY**: 0-15. |
| **0x1150** | `0x4D50` | `+0x290` | **Src1PixelOffsetZ** | **PixelOffsetZ**: 0-15. |
| **0x1154** | `0x4D54` | `+0x294` | **Src1PixelOffsetW** | **PixelOffsetW**: 0-15. |
| **0x1158** | `0x4D58` | `+0x298` | **Src2PixelOffsetX** | **PixelOffsetX**: 0-15. |
| **0x115C** | `0x4D5C` | `+0x29c` | **Src2PixelOffsetY** | **PixelOffsetY**: 0-15. |
| **0x1160** | `0x4D60` | `+0x2a0` | **Src2PixelOffsetZ** | **PixelOffsetZ**: 0-15. |
| **0x1164** | `0x4D64` | `+0x2a4` | **Src2PixelOffsetW** | **PixelOffsetW**: 0-15. |
| **0x1168** | `0x4D68` | `+0x2a8` | **Src1CompressedInfo** | **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingIdx**: 4-9, **LossyEnable**: 13. |
| **0x116C** | `0x4D6C` | `+0x2ac` | **Src1CompressedSizeLo** | **SizeLo**: 0-31. |
| **0x1170** | `0x4D70` | `+0x2b0` | **Src1CompressedSizeHi** | **SizeHi**: 0-31. |
| **0x1174** | `0x4D74` | `+0x2b4` | **Src2CompressedInfo** | **CompressedEnable**: 0, **MacroblockSize**: 2, **PackingIdx**: 4-9, **LossyEnable**: 13. |
| **0x1178** | `0x4D78` | `+0x2b8` | **Src2CompressedSizeLo** | **SizeLo**: 0-31. |
| **0x117C** | `0x4D7C` | `+0x2bc` | **Src2CompressedSizeHi** | **SizeHi**: 0-31. |
| **0x1180** | `0x4D80` | `+0x2c0` | **Src1CropOffset** | **OffsetY**: 0-15, **CropOffset**: 16-31. |
| **0x1184** | `0x4D84` | `+0x2c4` | **Src2CropOffset** | **OffsetY**: 0-15, **CropOffset**: 16-31. |
| **0x1188** | `0x4D88` | `+0x2c8` | **Src1WrapDynamic** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x118C** | `0x4D8C` | `+0x2cc` | **Src2WrapDynamic** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x1190** | `0x4D90` | `+0x2d0` | **Src1DependencyOffset** | **Offset**: 0-31. |
| **0x1194** | `0x4D94` | `+0x2d4` | **Src2DependencyOffset** | **Offset**: 0-31. |
| **0x1198** | `0x4D98` | `+0x2d8` | **TileDmaSrcReserved** | |
| **0x119C** | `0x4D9C` | `+0x2dc` | **TileDmaSrcReserved** | |
| **0x11A0** | `0x4DA0` | `+0x2e0` | **TileDmaSrcReserved** | |
| **0x11A4** | `0x4DA4` | `+0x2e4` | **TileDmaSrcReserved** | |
| **0x11A8** | `0x4DA8` | `+0x2e8` | **TileDmaSrcReserved** | |
| **0x11AC** | `0x4DAC` | `+0x2ec` | **TileDmaSrcReserved** | |
| **0x11B0** | `0x4DB0` | `+0x2f0` | **TileDmaSrcReserved** | |
| **0x11B4** | `0x4DB4` | `+0x2f4` | **TileDmaSrcReserved** | |
| **0x11B8** | `0x4DB8` | `+0x2f8` | **TileDmaSrcReserved** | |
| **0x11BC** | `0x4DBC` | `+0x2fc` | **TileDmaSrcReserved** | |
| **0x11C0** | `0x4DC0` | `+0x300` | **TileDmaSrcReserved** | |
| **0x11C4** | `0x4DC4` | `+0x304` | **TileDmaSrcReserved** | |
| **0x11C8** | `0x4DC8` | `+0x308` | **TileDmaSrcReserved** | |
| **0x11CC** | `0x4DCC` | `+0x30c` | **TileDmaSrcReserved** | |
| **0x11D0** | `0x4DD0` | `+0x310` | **TileDmaSrcReserved** | |
| **0x11D4** | `0x4DD4` | `+0x314` | **TileDmaSrcReserved** | |

*Note: H14 preserves triple cache hints (3 separate hint fields per source) and 4D pixel offsets (`SetTileDmaSrc1PixelOffset*`), both of which are removed in H16. H14 adds DataSet ID tracking (`SetTileDmaSrc1DataSetId`, `SetTileDmaSrc2DataSetId`) as new in this generation.*

### L2 Cache / Buffer (0x0500 OLD / 0x4100 Modern, Object `+0x31c`)
- **Count**: 25 registers (`0x19` words, `0x64` bytes).
- **Object Layout**: Starts at `+0x31c` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x0500** | `0x4100` | `+0x31c` | **Control** | **Src1ReLU**: 0, **PaddingMode**: 2-3, **Src2ReLU**: 4, **Barrier**: 16. |
| **0x0504** | `0x4104` | `+0x320` | **Src1Cfg** | **Type**: 0-1, **Dependent**: 2-3, **DMAFmt**: 6-7 (0=8b,1=16b,3=32b), **Interleave**: 8-11, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **Compression**: 25-26. |
| **0x0508** | `0x4108` | `+0x324` | **Src2Cfg** | **Type**: 0-1, **Dependent**: 2-3, **DMAFmt**: 6-7 (0=8b,1=16b,3=32b), **Interleave**: 8-11, **AliasConvSrc**: 4, **AliasConvRslt**: 5, **Compression**: 25-26. |
| **0x050C** | `0x410C` | `+0x328` | **Src1Base** | **Addr**: 4-20 (16B units). |
| **0x0510** | `0x4110` | `+0x32c` | **Src1ChannelStride** | **Stride**: 4-20 (16B units). |
| **0x0514** | `0x4114` | `+0x330` | **Src1RowStride** | **Stride**: 4-20 (16B units). |
| **0x0518** | `0x4118` | `+0x334` | **Src1DepthStride** | **Stride**: 4-20 (16B units). |
| **0x051C** | `0x411C` | `+0x338` | **Src1GroupStride** | **Stride**: 4-20 (16B units). |
| **0x0520** | `0x4120` | `+0x33c` | **Src2Base** | **Addr**: 4-20 (16B units). |
| **0x0524** | `0x4124` | `+0x340` | **Src2ChannelStride** | **Stride**: 4-20 (16B units). |
| **0x0528** | `0x4128` | `+0x344` | **Src2RowStride** | **Stride**: 4-20 (16B units). |
| **0x052C** | `0x412C` | `+0x348` | **Src2DepthStride** | **Stride**: 4-20 (16B units). |
| **0x0530** | `0x4130` | `+0x34c` | **Src2GroupStride** | **Stride**: 4-20 (16B units). |
| **0x0534** | `0x4134` | `+0x350` | **ResultCfg** | **Type**: 0-1, **DMAFmt**: 6-7, **Interleave**: 8-11, **Compression**: 25-26. |
| **0x0538** | `0x4138` | `+0x354` | **ResultBase** | **Addr**: 4-20 (16B units). |
| **0x053C** | `0x413C` | `+0x358` | **ResultChannelStride** | **Stride**: 4-20 (16B units). |
| **0x0540** | `0x4140` | `+0x35c` | **ResultRowStride** | **Stride**: 4-20 (16B units). |
| **0x0544** | `0x4144` | `+0x360` | **ResultDepthStride** | **Stride**: 4-20 (16B units). |
| **0x0548** | `0x4148` | `+0x364` | **ResultGroupStride** | **Stride**: 4-20 (16B units). |
| **0x054C** | `0x414C` | `+0x368` | **SrcAndResultWrapCfg** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x0550** | `0x4150` | `+0x36c` | **Src1WrapStart** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x0554** | `0x4154` | `+0x370` | **Src2WrapStart** | **WrapNumBlocks**: 0-11, **WrapLen**: 12-31. |
| **0x0558** | `0x4158` | `+0x374` | **L2Reserved** | |
| **0x055C** | `0x415C` | `+0x378` | **ResultWrapIndex** | **WrapIndex**: 0-15. (`SetL2ResultWrapIndex`) |
| **0x0560** | `0x4160` | `+0x37c` | **ResultWrapStartOffset** | **StartOffset**: 0-15. (`SetL2ResultWrapStartOffset`) |
| **0x0564** | `0x4164` | `+0x380` | **L2Reserved** | |

### Neural Engine (NE) (0x0900 OLD / 0x4900 Modern, Object `+0x388`)
- **Count**: 5 registers (`0x05` words, `0x14` bytes).
- **Object Layout**: Starts at `+0x388` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x0900** | `0x4900` | `+0x388` | **KernelCfg** | **Fmt**: 0-1, **PalettizedEn**: 2, **PalBits**: 4-7, **SparseEn**: 8, **Reuse**: 10, **SparseBinary**: 15, **Align**: 16, **BlockSize**: 21-23. |
| **0x0904** | `0x4904` | `+0x38c` | **MacCfg** | **OpMode**: 0-2 (0:Conv, 1:EW, 2:RCAS, 4:Bypass, 5:Transconv), **KMode**: 3, **BiasEn**: 4, **PassEn**: 5, **BinPoint**: 8-13, **NLMode**: 16-17. |
| **0x0908** | `0x4908` | `+0x390` | **NEBias** | **BiasVal**: 0-15, **ExpIdx**: 16-20. |
| **0x090C** | `0x490C` | `+0x394` | **NEPostScale** | **ScaleVal**: 0-15, **ExpIdx**: 16-20 (Negated). |
| **0x0910** | `0x4910` | `+0x398` | **RoundModeCfg** | **Mode**: 0-1, **IntBits**: 4-8. |
| **0x0914** | `0x4914` | `+0x39c` | **SRSeed0** | **Seed**: 0-31. |

### TileDMA Destination (0x0D00 OLD / 0x5100 Modern, Object `+0x3a4`)
- **Count**: 5 registers (`0x05` words, `0x14` bytes).
- **Object Layout**: Starts at `+0x3a4` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x0D00** | `0x5100` | `+0x3a4` | **DstDMAConfig** | **Enable**: 0, **CacheHint**: 4-7, **DataSetId**: 8-15, **UserTag**: 16-23. (NEW: DataSetId in H14) |
| **0x0D04** | `0x5104` | `+0x3a8` | **DstBaseAddr** | **Addr**: 6-31. |
| **0x0D08** | `0x5108` | `+0x3ac` | **DstRowStride** | **Stride**: 6-31. |
| **0x0D0C** | `0x510C` | `+0x3b0` | **DstPlaneStride** | **Stride**: 6-31. |
| **0x0D10** | `0x5110` | `+0x3b4` | **DstFmt** | **FormatMode**: 0-1, **MemFmt**: 12-13. |
| **0x0D14** | `0x5114` | `+0x3b8` | **DstPixelOffset** | **PixelOffset**: 0-15. (H14 preserves 4D pixel offset; removed in H16) |

### CacheDMA / Telemetry (0x1500 OLD / 0x5900 Modern, Object `+0x3c0`)
- **Count**: 9 registers (`0x09` words, `0x24` bytes).
- **Object Layout**: Starts at `+0x3c0` of the `ZinAneTd` object.

| OLD HW Addr | Modern HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- | :--- | :--- |
| **0x1500** | `0x5900` | `+0x3c0` | **TelemetryControl** | **Flush**: 0, **Enable**: 1, **TaskSync**: 2-3, **EarlyTerm**: 4-8. |
| **0x1504** | `0x5904` | `+0x3c4` | **TelemetryPre0** | **BandwidthLimit**, **SieveFiltering**, **ResponseAgeOut**. |
| **0x1508** | `0x5908` | `+0x3c8` | **TelemetryPre1** | **UserTag**, **Sieve1**: 0-13. |
| **0x150C** | `0x590C` | `+0x3cc` | **TelemetryReserved1** | Reserved. |
| **0x1510** | `0x5910` | `+0x3d0` | **TelemetryReserved2** | Reserved. |
| **0x1514** | `0x5914` | `+0x3d4` | **TelemetryReserved3** | Reserved. |
| **0x1518** | `0x5918` | `+0x3d8` | **TelemetryDSID** | **DataSetIdAndSize**: 7-29. |
| **0x151C** | `0x591C` | `+0x3dc` | **FootprintArg** | **FootprintArg2**: 17-27. |
| **0x1520** | `0x5920` | `+0x3e0` | **EarlyTermArg12** | **Arg1**: 0-15, **Arg2**: 16-31. |
| **0x1524** | `0x5924` | `+0x3e4` | **FlushRegister** | **FlushArg**: 0-15. |

### Planar Engine (PE) — Not initialized in `InitializeTdToDefaults`
- **HW Address**: Not present in `InitializeTdToDefaults()`; written via `CommonConfig` API methods.
- **Object Offset**: Unknown (inferred ~`+0x454` from H16 layout; unverified for H14).
- **Register Count**: Unknown.

The PE block in H14 is configured exclusively through higher-level API calls (`HandleCommonConfig`, bias/quantization setters), not the default initialization path. Likely uses the same addresses as H16 (modern `0x4500`), but this is unverified via binary.

| (Inferred) HW Addr | Register Name | Bit-Field Mapping |
| :--- | :--- | :--- |
| **0x4500** | **Config** | PoolMode: 0-1, Operation: 2-4, NLMode: 12-13. |
| **0x4504** | **Bias** | 19-bit Floating Point (F19) bias value. |
| **0x4508** | **Scale** | 19-bit Floating Point (F19) scale value. |
| **0x450C** | **FinalScaleEpsilon** | 19-bit Floating Point (F19) epsilon. |
| **0x4510** | **PreScale** | 19-bit Floating Point (F19) pre-scale value. |
| **0x4514** | **FinalScale** | 19-bit Floating Point (F19) final scale. |
| **0x4538** | **Quant** | **Src1InputOffset**: 0-7, **Src2InputOffset**: 8-15, **OutputZeroPoint**: 16-23. |

## Cross-Cutting Subsystems

### Quantization
Certain high-level configurations touch multiple disparate hardware blocks simultaneously. As decompiled from `ZinAneTd<11u>::SetQuantization*` methods:

**SetQuantizationSrc1InputOffset / Src2InputOffset**
- **Common** (`+0x21c` / `0x0030`): Format overrides (`ch_cfg`, `mac_cfg`).
- **L2 Cache** (`+0x31c` / `0x0500`): Padding/ReLU scale (`control`).
- **Planar Engine** (via CommonConfig API): Configures `bias`, `scale`, `pre_scale`, `final_scale`, and `quant` zero points.

**SetQuantizationOutputZeroOffset**
- **Neural Engine** (`+0x38c` / `0x0904`): Flips bit flags in `mac_cfg`.
- **Neural Engine** (`+0x398`): Writes to `quant` (post scale).

### DataSet IDs (NEW in H14)
H14 introduces DataSet ID fields across DMA blocks to enable memory tracking in multi-model execution:
- `SetTileDmaSrc1DataSetId(uint32_t)` — writes to `Src1DMAConfig[8:15]`
- `SetTileDmaSrc2DataSetId(uint32_t)` — writes to `Src2DMAConfig[8:15]`
- `SetTileDmaDstDataSetId(uint32_t)` — writes to `DstDMAConfig[8:15]`
- `SetKernelDmaSrcDataSetId(uint32_t, unsigned long)` — writes per-buffer `CoeffDMAConfig[N][8:15]`

### Sparse Kernel Block Size (NEW in H14)
`SetKernelSparseBlockSize(uint32_t)` — writes to `SparseBlockSizeCfg[0:7]` at OLD `0x1A00` / Modern `0x5600`.

## Hardware Traits (`ZinHWTraits<11u>`)
The compiler maintains statically defined traits for the H14 architecture (`11u`) that dictate raw memory offsets. The OLD-to-Modern address remapping is governed by these group offsets:

### Address Remapping Groups
| Group | OLD Base | Modern Base | Offset Delta | Blocks |
| :--- | :--- | :--- | :--- | :--- |
| **Group 0** | `0x0000` | `0x0000` | `+0x0000` | Common |
| **Group 1** | `0x0500` | `0x4100` | `+0x3C00` | L2 Cache, TileDmaSrc, KernelDmaSrc |
| **Group 2** | `0x0900` | `0x4900` | `+0x4000` | NE (Neural Engine) |
| **Group 3** | `0x0D00` | `0x5100` | `+0x4400` | TileDmaDst, CacheDMA |

### L2 Buffer Stride Offsets (OLD addresses)
| Trait Symbol | OLD Hex | Modern Hex | Block Affiliation |
| :--- | :--- | :--- | :--- |
| `ANE_L2_SOURCE_CHANNEL_STRIDE_OFFSET` | `0x0510` | `0x4110` | Src1 Channel Stride |
| `ANE_L2_SOURCE_ROW_STRIDE_OFFSET` | `0x0514` | `0x4114` | Src1 Row Stride |
| `ANE_L2_SOURCE_DEPTH_STRIDE_OFFSET` | `0x0518` | `0x4118` | Src1 Depth Stride |
| `ANE_L2_SOURCE_GROUP_STRIDE_OFFSET` | `0x051C` | `0x411C` | Src1 Group Stride |
| `ANE_L2_SOURCE2_CHANNEL_STRIDE_OFFSET` | `0x0524` | `0x4124` | Src2 Channel Stride |
| `ANE_L2_SOURCE2_ROW_STRIDE_OFFSET` | `0x0528` | `0x4128` | Src2 Row Stride |
| `ANE_L2_SOURCE2_DEPTH_STRIDE_OFFSET` | `0x052C` | `0x412C` | Src2 Depth Stride |
| `ANE_L2_SOURCE2_GROUP_STRIDE_OFFSET` | `0x0530` | `0x4130` | Src2 Group Stride |
| `ANE_L2_RESULT_CHANNEL_STRIDE_OFFSET` | `0x053C` | `0x413C` | Result Channel Stride |
| `ANE_L2_RESULT_ROW_STRIDE_OFFSET` | `0x0540` | `0x4140` | Result Row Stride |
| `ANE_L2_RESULT_DEPTH_STRIDE_OFFSET` | `0x0544` | `0x4144` | Result Depth Stride |
| `ANE_L2_RESULT_GROUP_STRIDE_OFFSET` | `0x0548` | `0x4148` | Result Group Stride |

### Tile DMA Stride Offsets (OLD addresses)
| Trait Symbol | OLD Hex | Modern Hex | Block Affiliation |
| :--- | :--- | :--- | :--- |
| `ANE_TILE_DMA_SRC_ROW_STRIDE_OFFSET` | `0x1114` | `0x4D14` | TileDmaSrc1 Row Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET` | `0x1118` | `0x4D18` | TileDmaSrc1 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET` | `0x111C` | `0x4D1C` | TileDmaSrc1 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET` | `0x1120` | `0x4D20` | TileDmaSrc1 Group Stride |
| `ANE_TILE_DMA_SRC_ROW_STRIDE2_OFFSET` | `0x1128` | `0x4D28` | TileDmaSrc2 Row Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET` | `0x112C` | `0x4D2C` | TileDmaSrc2 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET` | `0x1130` | `0x4D30` | TileDmaSrc2 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET` | `0x1134` | `0x4D34` | TileDmaSrc2 Group Stride |
| `ANE_TILE_DMA_DST_ROW_STRIDE_OFFSET` | `0x0D08` | `0x5108` | TileDmaDst Row Stride |
| `ANE_TILE_DMA_DST_PLANE_STRIDE_OFFSET` | `0x0D0C` | `0x510C` | TileDmaDst Channel Stride |

---
*Verified via binary analysis of ANECompiler (`ZinAneTd<11u>::InitializeTdToDefaults()` at 0x1a6bff68c).*
*Architecture: H14 (ISA Version 11) — A15 (iPhone 13 Pro), M2 (MacBook Air 2022). CPU Subtype: 0x0005.*
