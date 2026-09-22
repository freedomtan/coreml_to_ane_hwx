# ANE H19 (A20 Pro) Register Map

Exhaustive row-by-row mapping for H19 (A20 Pro) (Instruction Set Version 24, CPU Subtype 11).

## Block Index

1. [Common (0x0000)](#common-0x0000)
2. [L2 Cache (0x4100)](#l2-cache-0x4100)
3. [PE (0x4500)](#pe-0x4500)
4. [NE (0x4900)](#ne-0x4900)
5. [TileDMA Source (0x4D00)](#tiledmasrc-0x4d00)
6. [TileDMA Destination (0x5100)](#tiledmadst-0x5100)
7. [KernelDMA Source (0x5500)](#kerneldmasrc-0x5500)
8. [CacheDMA (0x5900)](#cachedma-0x5900)

---

## Common (0x0000)
- **Count**: 23 registers (`0x17` words, `0x5c` bytes).
- **Object Layout**: Starts at `+0x238` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x238` | **ChCfg** | **InFmt**: 0-2, **OutFmt**: 6-8. |
| **0x0004** | `+0x23c` | **InWidth** | 0-16. |
| **0x0008** | `+0x240` | **InHeight** | 0-16. |
| **0x000C** | `+0x244` | **InChannels** | 0-16. |
| **0x0010** | `+0x248` | **InDepth** | 0-16. |
| **0x0014** | `+0x24c` | **OutWidth** | 0-16. |
| **0x0018** | `+0x250` | **OutHeight** | 0-16. |
| **0x001C** | `+0x254` | **OutChannels** | 0-16. |
| **0x0020** | `+0x258` | **OutDepth** | 0-16. |
| **0x0024** | `+0x25c` | **NumGroups** | 0-16. |
| **0x0028** | `+0x260` | **ConvCfg** | **Kw**: 0-5, **Kh**: 6-11, **Sx**: 13-14, **Sy**: 15-16, **TexMode**: 22. |
| **0x002C** | `+0x264` | **ConvCfg3d** | **Sz**: 6-7, **Oz**: 21-25. |
| **0x0030** | `+0x268` | **UnicastCin** |  |
| **0x0034** | `+0x26c` | **TileHeight** | 0-16. |
| **0x0038** | `+0x270` | **TileOverlap** | **Overlap**: 16-20, **PadTop**: 21-25, **PadBottom**: 26-30, **Reflect**: 31. |
| **0x003C** | `+0x274` | **MacCfg** | **SmallSrc**: 2-3, **TaskType**: 4-7, **SpatialPref/Min/Max**: 8-18, **ActiveNE**: 19-21, **TraceEn**: 22, **L2Barrier**: 23, **ReluType**: 24-26, **1DWinograd**: 27, **OutTrans**: 28, **FillLowerNE**: 29. *(`Set2DWinogradMode` still asserts unconditionally on H19 — 2D Winograd has never been enabled on any documented generation. See [README.md § Feature Support by Generation](README.md#feature-support-by-generation).)* |
| **0x0040** | `+0x278` | **NECfg** | **OCGSize**, **PaddingMode**, **HalfWU**. |
| **0x0044** | `+0x27c` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | `+0x280` | **PECfg** | **Src1Transpose**, **Src1Broadcast**, etc. |
| **0x004C** | `+0x284` | **NID** | Network ID / Layer Trace ID. |
| **0x0050** | `+0x288` | **DPE** | Distributed Processing Element config. |
| **0x0054** | `+0x28c` | **Reserved0** | Padding / unused. |
| **0x0058** | `+0x290` | **Reserved1** | Padding / unused. |


## L2 Cache (0x4100)
- **Count**: 43 registers (`0x2b` words, `0xac` bytes).
- **Object Layout**: Starts at `+0x400` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x400` | **Control** |  |
| **0x4104** | `+0x404` | **MirrorWord_1** |  |
| **0x4108** | `+0x408` | **MirrorWord_2** |  |
| **0x410C** | `+0x40c` | **MirrorWord_3** |  |
| **0x4110** | `+0x410` | **Src1ChannelStride** |  |
| **0x4114** | `+0x414` | **Src1RowStride** |  |
| **0x4118** | `+0x418` | **Src1DepthStride** |  |
| **0x411C** | `+0x41c` | **Src1BaseAddr** |  |
| **0x4120** | `+0x420` | **Src1GroupStride** |  |
| **0x4124** | `+0x424` | **Src2ChannelStride** |  |
| **0x4128** | `+0x428` | **Src2RowStride** |  |
| **0x412C** | `+0x42c` | **Src2DepthStride** |  |
| **0x4130** | `+0x430` | **Src2GroupStride** |  |
| **0x4134** | `+0x434` | **SrcIdxBaseAddr** |  |
| **0x4138** | `+0x438` | **SrcIdxBaseAddrHi?** |  |
| **0x413C** | `+0x43c` | **SrcIdxChannelStride** |  |
| **0x4140** | `+0x440` | **SrcIdxDepthStride** |  |
| **0x4144** | `+0x444` | **Config** |  |
| **0x4148** | `+0x448` | **ResultBaseAddr** |  |
| **0x414C** | `+0x44c` | **ResultChannelStride** |  |
| **0x4150** | `+0x450` | **ResultRowStride** |  |
| **0x4154** | `+0x454` | **ResultDepthStride** |  |
| **0x4158** | `+0x458` | **ResultGroupStride** |  |
| **0x415C** | `+0x45c` | **LW_W23_Res** |  |
| **0x4160** | `+0x460` | **LW_W24_Res** |  |
| **0x4164** | `+0x464` | **LW_W25_Res** |  |
| **0x4168** | `+0x468` | **LW_W26_Res** |  |
| **0x416C** | `+0x46c` | **LW_W27_Res** |  |
| **0x4170** | `+0x470` | **LW_W28_Res** |  |
| **0x4174** | `+0x474` | **LW_W29_Res** |  |
| **0x4178** | `+0x478` | **LW_W30_Res** |  |
| **0x417C** | `+0x47c` | **LW_W31_Res** |  |
| **0x4180** | `+0x480` | **LW_W32_Res** |  |
| **0x4184** | `+0x484` | **LW_W33_Res** |  |
| **0x4188** | `+0x488` | **LW_W34_Res** |  |
| **0x418C** | `+0x48c` | **LW_W35_Res** |  |
| **0x4190** | `+0x490` | **LW_W36_Res** |  |
| **0x4194** | `+0x494` | **LW_W37_Res** |  |
| **0x4198** | `+0x498` | **LW_W38_Res** |  |
| **0x419C** | `+0x49c` | **LW_W39_Res** |  |
| **0x41A0** | `+0x4a0` | **LW_W40_Res** |  |
| **0x41A4** | `+0x4a4` | **LW_W41_Res** |  |
| **0x41A8** | `+0x4a8` | **L2TraceCfg** |  |


## Planar Engine (PE) (0x4500)
- **Count**: 16 registers (`0x10` words, `0x40` bytes).
- **Object Layout**: Starts at `+0x4b4` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x4500** | `+0x4b4` | **Config** | **OpMode**: 2-4, **FirstSource**: 16-18, **SecondSource**: 19-21. |
| **0x4504** | `+0x4b8` | **Bias** |  |
| **0x4508** | `+0x4bc` | **Scale** |  |
| **0x450C** | `+0x4c0` | **FinalScaleEps** |  |
| **0x4510** | `+0x4c4` | **PreScale** |  |
| **0x4514** | `+0x4c8` | **FinalScale** |  |
| **0x4518** | `+0x4cc` | **LUT1** |  |
| **0x451C** | `+0x4d0` | **LUT2** |  |
| **0x4520** | `+0x4d4` | **LUT3** |  |
| **0x4524** | `+0x4d8` | **LUT4** |  |
| **0x4528** | `+0x4dc` | **LUT5** |  |
| **0x452C** | `+0x4e0` | **LUT6** |  |
| **0x4530** | `+0x4e4` | **LUT7** |  |
| **0x4534** | `+0x4e8` | **LUT8** |  |
| **0x4538** | `+0x4ec` | **Quant** |  |
| **0x453C** | `+0x4f0` | **PETraceCfg** |  |


## Neural Engine (NE) (0x4900)
- **Count**: 14 registers (`0x0e` words, `0x38` bytes).
- **Object Layout**: Starts at `+0x4fc` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x4fc` | **KernelCfg** | **Fmt**: 0-1, **PalettizedEn**: 2, **PalBits**: 4-7, **SparseEn**: 8, **Reuse**: 10, **SparseBinary**: 15, **Align**: 16, **BlockSize**: 21-23, **AsymQuantEn**: 24, **DetectZeros**: 28. |
| **0x4904** | `+0x500` | **MacCfg** | **OpMode**: 0-2 (0:Conv, 1:EW, 2:RCAS, 3:EWSqrt, 4:Bypass, 5:Transconv), **KMode**: 3, **BiasEn**: 4, **PassEn**: 5, **MVBiasEn**: 6, **BinPoint**: 8-13, **PostEn**: 14, **NLMode**: 16-17, **MaxPoolEn**: 19, **ArgSel**: 20-23, **DoubleInt8En**: 26. |
| **0x4908** | `+0x504` | **MatrixVectorBias** |  |
| **0x490C** | `+0x508` | **NEBias** | 0-31. |
| **0x4910** | `+0x50c` | **PostScale** | 0-31. |
| **0x4914** | `+0x510` | **RcasConfig** |  |
| **0x4918** | `+0x514` | **RoundModeCfg** |  |
| **0x491C** | `+0x518` | **SRSeed[0]** |  |
| **0x4920** | `+0x51c` | **SRSeed[1]** |  |
| **0x4924** | `+0x520` | **SRSeed[2]** |  |
| **0x4928** | `+0x524` | **SRSeed[3]** |  |
| **0x492C** | `+0x528` | **QuantZeroPoint** |  |
| **0x4930** | `+0x52c` | **NE_Res12** |  |
| **0x4934** | `+0x530` | **NETraceCfg** | NE Core Trace Configuration. |


## TileDMA Source (TileDmaSrc) (0x4D00)
- **Count**: 87 registers (`0x57` words, `0x15c` bytes).
- **Object Layout**: Starts at `+0x29c` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x4D00** | `+0x29c` | **Src1DMAConfig** |  |
| **0x4D04** | `+0x2a0` | **Src2DMAConfig** |  |
| **0x4D08** | `+0x2a4` | **Src1WrapCfg** |  |
| **0x4D0C** | `+0x2a8` | **Src2WrapCfg** |  |
| **0x4D10** | `+0x2ac` | **Src1BaseAddrLo** |  |
| **0x4D14** | `+0x2b0` | **Src1BaseAddrHi** |  |
| **0x4D18** | `+0x2b4` | **Src1RowStride** |  |
| **0x4D1C** | `+0x2b8` | **Src1PlaneStride** |  |
| **0x4D20** | `+0x2bc` | **Src2BaseAddrLo** |  |
| **0x4D24** | `+0x2c0` | **Src1GroupStride** |  |
| **0x4D28** | `+0x2c4` | **Src2BaseAddrHi** |  |
| **0x4D2C** | `+0x2c8` | **Src2RowStride** |  |
| **0x4D30** | `+0x2cc` | **Src2PlaneStride** |  |
| **0x4D34** | `+0x2d0` | **Src2GroupStride** |  |
| **0x4D38** | `+0x2d4` | **pad_38** |  |
| **0x4D3C** | `+0x2d8` | **pad_3C** |  |
| **0x4D40** | `+0x2dc` | **Src1MetaDataConfig** |  |
| **0x4D44** | `+0x2e0` | **pad_44** |  |
| **0x4D48** | `+0x2e4` | **pad_48** |  |
| **0x4D4C** | `+0x2e8` | **pad_4C** |  |
| **0x4D50** | `+0x2ec` | **Src1MetaDataAddrLo** |  |
| **0x4D54** | `+0x2f0` | **Src1MetaDataAddrHi** |  |
| **0x4D58** | `+0x2f4` | **Src1MetaDataSize** |  |
| **0x4D5C** | `+0x2f8` | **Src2MetaDataConfig** |  |
| **0x4D60** | `+0x2fc` | **Src2MetaDataAddrLo** |  |
| **0x4D64** | `+0x300` | **Src2MetaDataAddrHi** |  |
| **0x4D68** | `+0x304` | **Src1Fmt** |  |
| **0x4D6C** | `+0x308` | **Src2FmtMode** |  |
| **0x4D70** | `+0x30c` | **Reserved_0x4D70** |  |
| **0x4D74** | `+0x310` | **Reserved_0x4D74** |  |
| **0x4D78** | `+0x314` | **Src1CompressedInfo** |  |
| **0x4D7C** | `+0x318` | **Src1CompressedSizeLo** |  |
| **0x4D80** | `+0x31c` | **Src1CompressedSizeHi** |  |
| **0x4D84** | `+0x320` | **Src1CropOffset** |  |
| **0x4D88** | `+0x324` | **Src2CompressedInfo** |  |
| **0x4D8C** | `+0x328` | **Src2CompressedSizeLo** |  |
| **0x4D90** | `+0x32c` | **Src2CompressedSizeHi** |  |
| **0x4D94** | `+0x330` | **Src2CropOffset** |  |
| **0x4D98** | `+0x334` | **Reserved_0x4D98** |  |
| **0x4D9C** | `+0x338` | **Reserved_0x4D9C** |  |
| **0x4DA0** | `+0x33c` | **Reserved_0x4DA0** |  |
| **0x4DA4** | `+0x340` | **Reserved_0x4DA4** |  |
| **0x4DA8** | `+0x344` | **Reserved_0x4DA8** |  |
| **0x4DAC** | `+0x348` | **Reserved_0x4DAC** |  |
| **0x4DB0** | `+0x34c` | **Reserved_0x4DB0** |  |
| **0x4DB4** | `+0x350` | **Reserved_0x4DB4** |  |
| **0x4DB8** | `+0x354` | **Src1WrapDynamic** |  |
| **0x4DBC** | `+0x358` | **Src2WrapDynamic** |  |
| **0x4DC0** | `+0x35c` | **Src1DependencyOffset** |  |
| **0x4DC4** | `+0x360` | **Src2DependencyOffset** |  |
| **0x4DC8** | `+0x364` | **TextureConfig** |  |
| **0x4DCC** | `+0x368` | **TextureIdxPermute** |  |
| **0x4DD0** | `+0x36c` | **TextureSrcPermute** |  |
| **0x4DD4** | `+0x370` | **TextureBackgroundVal** |  |
| **0x4DD8** | `+0x374` | **TextureExtMaxDim1** |  |
| **0x4DDC** | `+0x378` | **TextureExtMaxDim2** |  |
| **0x4DE0** | `+0x37c` | **TextureExtMaxDim3** |  |
| **0x4DE4** | `+0x380` | **TextureCropBatchSplitDim1** |  |
| **0x4DE8** | `+0x384` | **TextureCropDepthDim1** |  |
| **0x4DEC** | `+0x388` | **TextureCropBatchSplitDim2** |  |
| **0x4DF0** | `+0x38c` | **Reserved_0x4DF0** |  |
| **0x4DF4** | `+0x390` | **Reserved_0x4DF4** |  |
| **0x4DF8** | `+0x394` | **Src1Ephemeral** |  |
| **0x4DFC** | `+0x398` | **Reserved_0x4DFC** |  |
| **0x4E00** | `+0x39c` | **Reserved_0x4E00** |  |
| **0x4E04** | `+0x3a0` | **TextureCropCoeffVal** |  |
| **0x4E08** | `+0x3a4` | **pad_66** |  |
| **0x4E0C** | `+0x3a8` | **pad_67** |  |
| **0x4E10** | `+0x3ac` | **pad_68** |  |
| **0x4E14** | `+0x3b0` | **pad_69** |  |
| **0x4E18** | `+0x3b4` | **pad_70** |  |
| **0x4E1C** | `+0x3b8` | **pad_71** |  |
| **0x4E20** | `+0x3bc` | **pad_72** |  |
| **0x4E24** | `+0x3c0` | **pad_73** |  |
| **0x4E28** | `+0x3c4` | **pad_74** |  |
| **0x4E2C** | `+0x3c8` | **pad_75** |  |
| **0x4E30** | `+0x3cc` | **pad_76** |  |
| **0x4E34** | `+0x3d0` | **pad_77** |  |
| **0x4E38** | `+0x3d4` | **pad_78** |  |
| **0x4E3C** | `+0x3d8` | **pad_79** |  |
| **0x4E40** | `+0x3dc` | **pad_80** |  |
| **0x4E44** | `+0x3e0` | **TS_Res81** |  |
| **0x4E48** | `+0x3e4` | **TS_Res82** |  |
| **0x4E4C** | `+0x3e8` | **TileDmaSrcTraceCfg** | TileDMA source trace configuration. |
| **0x4E50** | `+0x3ec` | **TileDmaSrcTraceCfgLatency** | TileDMA source trace latency configuration. |
| **0x4E54** | `+0x3f0` | **TS_Res85** |  |
| **0x4E58** | `+0x3f4` | **TS_Res86** |  |


## TileDMA Destination (TileDmaDst) (0x5100)
- **Count**: 29 registers (`0x1d` words, `0x74` bytes).
- **Object Layout**: Starts at `+0x53c` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x5100** | `+0x53c` | **DstDMAConfig** |  |
| **0x5104** | `+0x540` | **pad0** |  |
| **0x5108** | `+0x544` | **DstBaseAddrLo** |  |
| **0x510C** | `+0x548` | **DstBaseAddrHi** |  |
| **0x5110** | `+0x54c` | **DstRowStride** |  |
| **0x5114** | `+0x550` | **DstPlaneStride** |  |
| **0x5118** | `+0x554` | **DstDepthStride** |  |
| **0x511C** | `+0x558` | **DstGroupStride** |  |
| **0x5120** | `+0x55c` | **DstInternalCfg** |  |
| **0x5124** | `+0x560` | **pad1** |  |
| **0x5128** | `+0x564` | **DstMetaDataAddrLo** |  |
| **0x512C** | `+0x568` | **DstMetaDataAddrHi** |  |
| **0x5130** | `+0x56c` | **DstFmtMode** |  |
| **0x5134** | `+0x570` | **pad2** |  |
| **0x5138** | `+0x574` | **DstFmtCtrl** |  |
| **0x513C** | `+0x578` | **pad3** |  |
| **0x5140** | `+0x57c` | **DstCompressedInfo** |  |
| **0x5144** | `+0x580` | **pad4** |  |
| **0x5148** | `+0x584` | **DstCompSizeLo** |  |
| **0x514C** | `+0x588` | **DstCompSizeHi** |  |
| **0x5150** | `+0x58c` | **DstPixelOffset** |  |
| **0x5154** | `+0x590` | **TD_Res21** |  |
| **0x5158** | `+0x594` | **TD_Res22** |  |
| **0x515C** | `+0x598` | **TD_Res23** |  |
| **0x5160** | `+0x59c` | **TD_Res24** |  |
| **0x5164** | `+0x5a0` | **TD_Res25** |  |
| **0x5168** | `+0x5a4` | **TileDmaDstTraceCfg** | TileDMA destination trace configuration. |
| **0x516C** | `+0x5a8` | **TileDmaDstTraceCfgLatency** | TileDMA destination trace latency configuration. |
| **0x5170** | `+0x5ac` | **TD_Res28** |  |


## KernelDMA Source (KernelDmaSrc) (0x5500)
- **Count**: 85 registers (`0x55` words, `0x154` bytes).
- **Object Layout**: Starts at `+0x03c` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x03c` | **MasterCfg** |  |
| **0x5504** | `+0x040` | **AlignedCoeffSize** |  |
| **0x5508** | `+0x044` | **Prefetch** |  |
| **0x550C** | `+0x048` | **Res_0** |  |
| **0x5510** | `+0x04c` | **Res_1** |  |
| **0x5514** | `+0x050` | **Res_2** |  |
| **0x5518** | `+0x054` | **KernelGroupStride** |  |
| **0x551C** | `+0x058` | **KernelOCGStride** |  |
| **0x5520** | `+0x05c` | **CoeffDMAConfig[0]** |  |
| **0x5524** | `+0x060` | **CoeffDMAConfig[1]** |  |
| **0x5528** | `+0x064` | **CoeffDMAConfig[2]** |  |
| **0x552C** | `+0x068` | **CoeffDMAConfig[3]** |  |
| **0x5530** | `+0x06c` | **CoeffDMAConfig[4]** |  |
| **0x5534** | `+0x070` | **CoeffDMAConfig[5]** |  |
| **0x5538** | `+0x074` | **CoeffDMAConfig[6]** |  |
| **0x553C** | `+0x078` | **CoeffDMAConfig[7]** |  |
| **0x5540** | `+0x07c` | **CoeffDMAConfig[8]** |  |
| **0x5544** | `+0x080` | **CoeffDMAConfig[9]** |  |
| **0x5548** | `+0x084` | **CoeffDMAConfig[10]** |  |
| **0x554C** | `+0x088` | **CoeffDMAConfig[11]** |  |
| **0x5550** | `+0x08c` | **CoeffDMAConfig[12]** |  |
| **0x5554** | `+0x090` | **CoeffDMAConfig[13]** |  |
| **0x5558** | `+0x094` | **CoeffDMAConfig[14]** |  |
| **0x555C** | `+0x098` | **CoeffDMAConfig[15]** |  |
| **0x5560** | `+0x09c` | **CoeffBaseAddr[0]** |  |
| **0x5564** | `+0x0a0` | **CoeffBaseAddr[1]** |  |
| **0x5568** | `+0x0a4` | **CoeffBaseAddr[2]** |  |
| **0x556C** | `+0x0a8` | **CoeffBaseAddr[3]** |  |
| **0x5570** | `+0x0ac` | **CoeffBaseAddr[4]** |  |
| **0x5574** | `+0x0b0` | **CoeffBaseAddr[5]** |  |
| **0x5578** | `+0x0b4` | **CoeffBaseAddr[6]** |  |
| **0x557C** | `+0x0b8` | **CoeffBaseAddr[7]** |  |
| **0x5580** | `+0x0bc` | **CoeffBaseAddr[8]** |  |
| **0x5584** | `+0x0c0` | **CoeffBaseAddr[9]** |  |
| **0x5588** | `+0x0c4` | **CoeffBaseAddr[10]** |  |
| **0x558C** | `+0x0c8` | **CoeffBaseAddr[11]** |  |
| **0x5590** | `+0x0cc` | **CoeffBaseAddr[12]** |  |
| **0x5594** | `+0x0d0` | **CoeffBaseAddr[13]** |  |
| **0x5598** | `+0x0d4` | **CoeffBaseAddr[14]** |  |
| **0x559C** | `+0x0d8` | **CoeffBaseAddr[15]** |  |
| **0x55A0** | `+0x0dc` | **CoeffBfrSize[0]** |  |
| **0x55A4** | `+0x0e0` | **CoeffBfrSize[1]** |  |
| **0x55A8** | `+0x0e4` | **CoeffBfrSize[2]** |  |
| **0x55AC** | `+0x0e8` | **CoeffBfrSize[3]** |  |
| **0x55B0** | `+0x0ec` | **CoeffBfrSize[4]** |  |
| **0x55B4** | `+0x0f0` | **CoeffBfrSize[5]** |  |
| **0x55B8** | `+0x0f4` | **CoeffBfrSize[6]** |  |
| **0x55BC** | `+0x0f8` | **CoeffBfrSize[7]** |  |
| **0x55C0** | `+0x0fc` | **CoeffBfrSize[8]** |  |
| **0x55C4** | `+0x100` | **CoeffBfrSize[9]** |  |
| **0x55C8** | `+0x104` | **CoeffBfrSize[10]** |  |
| **0x55CC** | `+0x108` | **CoeffBfrSize[11]** |  |
| **0x55D0** | `+0x10c` | **CoeffBfrSize[12]** |  |
| **0x55D4** | `+0x110` | **CoeffBfrSize[13]** |  |
| **0x55D8** | `+0x114` | **CoeffBfrSize[14]** |  |
| **0x55DC** | `+0x118` | **CoeffBfrSize[15]** |  |
| **0x55E0** | `+0x11c` | **BiasDMAConfig** |  |
| **0x55E4** | `+0x120` | **BiasBaseAddr** |  |
| **0x55E8** | `+0x124` | **Res_Bias0** |  |
| **0x55EC** | `+0x128` | **Res_Bias1** |  |
| **0x55F0** | `+0x12c` | **PostScaleDMAConfig** |  |
| **0x55F4** | `+0x130` | **PostScaleBaseAddr** |  |
| **0x55F8** | `+0x134` | **Res_PS0** |  |
| **0x55FC** | `+0x138` | **Res_PS1** |  |
| **0x5600** | `+0x13c` | **PaletteDMAConfig** |  |
| **0x5604** | `+0x140` | **PaletteBaseAddr** |  |
| **0x5608** | `+0x144` | **Res_Pal0** |  |
| **0x560C** | `+0x148` | **Res_Pal1** |  |
| **0x5610** | `+0x14c` | **NLutDMAConfig** |  |
| **0x5614** | `+0x150` | **NLutBaseAddr** |  |
| **0x5618** | `+0x154` | **Res_NL0** |  |
| **0x561C** | `+0x158` | **Res_NL1** |  |
| **0x5620** | `+0x15c` | **KDMA_Res72** |  |
| **0x5624** | `+0x160` | **KDMA_Res73** |  |
| **0x5628** | `+0x164` | **KDMA_Res74** |  |
| **0x562C** | `+0x168` | **KDMA_Res75** |  |
| **0x5630** | `+0x16c` | **KDMA_Res76** |  |
| **0x5634** | `+0x170` | **KDMA_Res77** |  |
| **0x5638** | `+0x174` | **KDMA_Res78** |  |
| **0x563C** | `+0x178` | **KDMA_Res79** |  |
| **0x5640** | `+0x17c` | **KDMA_Res80** |  |
| **0x5644** | `+0x180` | **LdtidForKernelDmaSrc** | Logical Data Transfer ID for KernelDMA Src. |
| **0x5648** | `+0x184` | **RdtidForKernelDmaSrc** | Request Data Transfer ID for KernelDMA Src. |
| **0x564C** | `+0x188` | **KernelDmaSrcTraceCfg** | KernelDMA source trace configuration. |
| **0x5650** | `+0x18c` | **KernelDmaSrcTraceCfgLatency** | KernelDMA source trace latency configuration. |


## CacheDMA (0x5900)
- **Count**: 14 registers (`0x0e` words, `0x38` bytes).
- **Object Layout**: Starts at `+0x5b8` of the `ZinAneTd` object.

| HW Addr | Offset (`this`) | Register Name | Bit-Field Mapping / Description |
| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x5b8` | **CacheDmaEnable** |  |
| **0x5904** | `+0x5bc` | **CacheDmaW1_Res** |  |
| **0x5908** | `+0x5c0` | **CacheDmaW2_Res** |  |
| **0x590C** | `+0x5c4` | **CacheDmaW3_Res** |  |
| **0x5910** | `+0x5c8` | **CacheDmaW4_Res** |  |
| **0x5914** | `+0x5cc` | **CacheDmaW5_Res** |  |
| **0x5918** | `+0x5d0` | **CacheDmaW6_Res** |  |
| **0x591C** | `+0x5d4` | **CacheDmaW7_Res** |  |
| **0x5920** | `+0x5d8` | **CacheDmaW8_Res** |  |
| **0x5924** | `+0x5dc` | **CacheDmaW9_Res** |  |
| **0x5928** | `+0x5e0` | **CacheDmaW10_Res** |  |
| **0x592C** | `+0x5e4` | **CacheDmaW11_Res** |  |
| **0x5930** | `+0x5e8` | **CacheDmaW12_Res** |  |
| **0x5934** | `+0x5ec` | **PrefetchRate** |  |


## Hardware Traits (`ZinHWTraits<24u>`)
The compiler maintains a set of statically defined traits for H19 (ISA `24u`) that explicitly dictate the raw memory offsets of hardware components:

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
| `ANE_TILE_DMA_SRC_ROW_STRIDE_OFFSET` | `0x4D20` | `19744` | TileDmaSrc1 Row Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET` | `0x4D24` | `19748` | TileDmaSrc1 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET` | `0x4D28` | `19752` | TileDmaSrc1 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET` | `0x4D2C` | `19756` | TileDmaSrc1 Group Stride |
| `ANE_TILE_DMA_SRC_ROW_STRIDE2_OFFSET` | `0x4D38` | `19768` | TileDmaSrc2 Row Stride |
| `ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET` | `0x4D3C` | `19772` | TileDmaSrc2 Channel Stride |
| `ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET` | `0x4D40` | `19776` | TileDmaSrc2 Depth Stride |
| `ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET` | `0x4D44` | `19780` | TileDmaSrc2 Group Stride |
| `ANE_TILE_DMA_DST_ROW_STRIDE_OFFSET` | `0x5118` | `20760` | TileDmaDst Row Stride |
| `ANE_TILE_DMA_DST_PLANE_STRIDE_OFFSET` | `0x511C` | `20764` | TileDmaDst Channel Stride |
| `ANE_TILE_DMA_DST_DEPTH_STRIDE_OFFSET` | `0x5120` | `20768` | TileDmaDst Depth Stride |
| `ANE_TILE_DMA_DST_GROUP_STRIDE_OFFSET` | `0x5124` | `20772` | TileDmaDst Group Stride |
