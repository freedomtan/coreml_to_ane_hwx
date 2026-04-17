# ANE H17 (A18) Register Map

Exhaustive row-by-row mapping for H17 (A18).

## Block Index
1. [Common (0x0000)](#common-0x0000)
2. [L2 Cache (0x4100)](#l2-cache-0x4100)
3. [PE (0x4500)](#pe-0x4500)
4. [NE (0x4900)](#ne-0x4900)
5. [TileDMA Source (0x4D00)](#tiledma-source-tiledmasrc-0x4d00)
6. [TileDMA Destination (0x5100)](#tiledma-destination-tiledmadst-0x5100)
7. [KernelDMA Source (0x5500)](#kerneldma-source-kerneldmasrc-0x5500)
8. [CacheDMA (0x5900)](#cachedma-0x5900)

---

## Common (0x0000)
- **Count**: 23 registers (`0x17` words, `0x5c` bytes).
- **Object Layout**: Starts at `+0x1f8` of the `ZinAneTd` object.
| :--- | :--- | :--- | :--- |
| **0x0000** | `+0x1f8` | **ChCfg** |  |
| **0x0004** | `+0x1fc` | **MirrorWord_1** |  |
| **0x0008** | `+0x200` | **MirrorWord_2** |  |
| **0x000C** | `+0x204` | **FmtCfg** | **Src1InFmt**: 0-1, **Src2InFmt**: 2-3, **OutFmt**: 4-5. |
| **0x0010** | `+0x208` | **InWidth** | 0-16. |
| **0x0014** | `+0x20c` | **InHeight** | 0-16. |
| **0x0018** | `+0x210` | **InChannels** | 0-16. |
| **0x001C** | `+0x214` | **InDepth** | 0-16. |
| **0x0020** | `+0x218` | **OutWidth** | 0-16. |
| **0x0024** | `+0x21c` | **OutHeight** | 0-16. |
| **0x0028** | `+0x220` | **OutChannels** | 0-16. |
| **0x002C** | `+0x224` | **OutDepth** | 0-16. |
| **0x0030** | `+0x228` | **NumGroups** | 0-16. |
| **0x0034** | `+0x22c` | **ConvCfg** | **Kw**: 0-5, **Kh**: 6-11, **Sx**: 13-14, **Sy**: 15-16, **Ox**: 28-29, **Oy**: 30-31. |
| **0x0038** | `+0x230` | **ConvCfg3d** | **Kd**: 0-4, **Sz**: 6-7, **Oz**: 13-14. |
| **0x003C** | `+0x234` | **TileOverlap** |  |
| **0x0040** | `+0x238` | **MirrorWord_16** |  |
| **0x0044** | `+0x23c` | **MirrorWord_17** |  |
| **0x0048** | `+0x240` | **NECfg** | **TaskType**: 4-7, **PerfTraceEn**: 22. |
| **0x004C** | `+0x244` | **MirrorWord_19** |  |
| **0x0050** | `+0x248` | **MirrorWord_20** |  |
| **0x0054** | `+0x24c` | **MirrorWord_21** |  |
| **0x0058** | `+0x250` | **MirrorWord_22** |  |


## L2 Cache (0x4100)
- **Base Offset**: `+0x3bc` (relative to ZinAneTd base).
- **Structure**: 42 registers (`0x2a` words, `0xa8` bytes).
- **Alignment Note**: H17 (v19) uses a 3-word shift relative to H18 (v20); Source 1 starts at Index 7 (+0x3d8).

| :--- | :--- | :--- | :--- |
| **0x4100** | `+0x3bc` | **Control** |  |
| **0x4104** | `+0x3c0` | **MirrorWord_1** |  |
| **0x4108** | `+0x3c4` | **MirrorWord_2** |  |
| **0x410C** | `+0x3c8` | **MirrorWord_3** |  |
| **0x4110** | `+0x3cc` | **MirrorWord_4** |  |
| **0x4114** | `+0x3d0` | **Src1ChannelStride** | 4-20. |
| **0x4118** | `+0x3d4` | **Src1RowStride** | 4-20. |
| **0x411C** | `+0x3d8` | **Src1BaseAddr** | 0-63 (2 words). |
| **0x4124** | `+0x3e0` | **Src2ChannelStride** |  |
| **0x4128** | `+0x3e4` | **Src2RowStride** |  |
| **0x412C** | `+0x3e8` | **Src2DepthStride** |  |
| **0x4130** | `+0x3ec` | **Src2GroupStride** |  |
| **0x4134** | `+0x3f0` | **SrcIdxBaseAddr** |  |
| **0x413C** | `+0x3f8` | **SrcIdxChannelStride** |  |
| **0x4140** | `+0x3fc` | **SrcIdxDepthStride** |  |
| **0x4144** | `+0x400` | **ResultBaseAddr** | 4-20. |
| **0x4148** | `+0x404` | **ResultChannelStride** | 4-20. |
| **0x414C** | `+0x408` | **ResultRowStride** |  |
| **0x4150** | `+0x40c` | **ResultDepthStride** |  |
| **0x4154** | `+0x410` | **Config** |  |
| **0x4158** | `+0x414` | **ResultMDAddrLo** |  |
| **0x415C** | `+0x418` | **ResultMDAddrHi** |  |
| **0x4160** | `+0x41c` | **ResultMDConfig** |  |
| **0x4164** | `+0x420` | **ResultMDSize** |  |
| **0x4168** | `+0x424` | **LW26_Res** |  |
| **0x416C** | `+0x428` | **LW27_Res** |  |
| **0x4170** | `+0x42c` | **LW28_Res** |  |
| **0x4174** | `+0x430` | **LW29_Res** |  |
| **0x4178** | `+0x434` | **LW30_Res** |  |
| **0x417C** | `+0x438` | **LW31_Res** |  |
| **0x4180** | `+0x43c` | **LW32_Res** |  |
| **0x4184** | `+0x440` | **LW33_Res** |  |
| **0x4188** | `+0x444` | **LW34_Res** |  |
| **0x418C** | `+0x448` | **LW35_Res** |  |
| **0x4190** | `+0x44c` | **LW36_Res** |  |
| **0x4194** | `+0x450` | **LW37_Res** |  |
| **0x4198** | `+0x454` | **LW38_Res** |  |
| **0x419C** | `+0x458` | **LW39_Res** |  |
| **0x41A0** | `+0x45c` | **LW40_Res** |  |
| **0x41A4** | `+0x460` | **L2TraceCfg** |  |



## Planar Engine (PE) (0x4500)
- **Object Layout**: Starts at `+0x3dc` of the `ZinAneTd` object.
| :--- | :--- | :--- | :--- |
| **0x4500** | `+0x3dc` | **Config** | **OpMode**: 2-4, **FirstSource**: 16-18, **SecondSource**: 19-21. |
| **0x4504** | `+0x3e0` | **Bias** |  |
| **0x4508** | `+0x3e4` | **Scale** |  |
| **0x450C** | `+0x3e8` | **FinalScaleEps** |  |
| **0x4510** | `+0x3ec` | **PreScale** |  |
| **0x4514** | `+0x3f0` | **FinalScale** |  |
| **0x4518** | `+0x3f4` | **LUT1** |  |
| **0x451C** | `+0x3f8` | **LUT2** |  |
| **0x4520** | `+0x3fc` | **LUT3** |  |
| **0x4524** | `+0x400` | **LUT4** |  |
| **0x4528** | `+0x404` | **LUT5** |  |
| **0x452C** | `+0x408` | **LUT6** |  |
| **0x4530** | `+0x40c` | **LUT7** |  |
| **0x4534** | `+0x410` | **LUT8** |  |
| **0x4538** | `+0x414` | **Quant** |  |
| **0x453C** | `+0x418` | **ExtraCfg** |  |


## Neural Engine (NE) (0x4900)
- **Base Offset**: `+0x3a0` (relative to ZinAneTd base).
- **Structure**: Core convolution and post-processing registers.

| :--- | :--- | :--- | :--- |
| **0x4900** | `+0x3a0` | **KernelCfg** |  |
| **0x4904** | `+0x3a4` | **MacCfg** |  |
| **0x4908** | `+0x3a8` | **MatVecBias** |  |
| **0x490C** | `+0x3ac` | **Bias** | 0-31. |
| **0x4910** | `+0x3b0` | **PostScale** | 0-31. |
| **0x4914** | `+0x3b4` | **RcasConfig** |  |
| **0x4918** | `+0x3b8` | **RoundModeCfg** |  |
| **0x491C** | `+0x3bc` | **SRSeed0** |  |
| **0x4920** | `+0x3c0` | **SRSeed1** |  |
| **0x4924** | `+0x3c4` | **SRSeed2** |  |
| **0x4928** | `+0x3c8` | **SRSeed3** |  |
| **0x492C** | `+0x3cc` | **QuantZeroPoint** |  |
| **0x4930** | `+0x3d0` | **ExtraCfg** |  |


## TileDMA Source (TileDmaSrc) (0x4D00)
- **Base Offset**: `+0x290` (relative to ZinAneTd base).
- **Structure**: 81 registers (`0x51` words, `0x144` bytes).

| :--- | :--- | :--- | :--- |
| **0x4D00** | `+0x290` | **Src1BaseLo** |  |
| **0x4D04** | `+0x294` | **Src1BaseHi** |  |
| **0x4D08** | `+0x298` | **Src1ChanStride** |  |
| **0x4D18** | `+0x2a8` | **Src1RowStride** |  |
| **0x4D1C** | `+0x2ac` | **Src1DepthStride** |  |
| **0x4D20** | `+0x2b0` | **Src1GroupStride** |  |
| **0x4D24** | `+0x2b4` | **Src1PlaneStride** |  |
| **0x4D28** | `+0x2b8` | **Src1MDAddrLo** |  |
| **0x4D2C** | `+0x2bc` | **Src1MDAddrHi** |  |
| **0x4D30** | `+0x2c0` | **Src1MDConfig** |  |
| **0x4D34** | `+0x2c4` | **Src1MDSize** |  |
| **0x4D38** | `+0x2c8` | **Src1W14_Res** |  |
| **0x4D3C** | `+0x2cc` | **Src1W15_Res** |  |
| **0x4D40** | `+0x2d0` | **Src1W16_Res** |  |
| **0x4D44** | `+0x2d4` | **Src1W17_Res** |  |
| **0x4D48** | `+0x2d8` | **Src1W18_Res** |  |
| **0x4D4C** | `+0x2dc` | **Src1W19_Res** |  |
| **0x4D50** | `+0x2e0` | **Src1W20_Res** |  |
| **0x4D54** | `+0x2e4` | **Src1W21_Res** |  |
| **0x4D58** | `+0x2e8` | **Src1W22_Res** |  |
| **0x4D5C** | `+0x2ec` | **Src1W23_Res** |  |
| **0x4D60** | `+0x2f0` | **Src1W24_Res** |  |
| **0x4D64** | `+0x2f4` | **Src1W25_Res** |  |
| **0x4D68** | `+0x2f8` | **Src1W26_Res** |  |
| **0x4D6C** | `+0x2fc` | **Src1W27_Res** |  |
| **0x4D70** | `+0x300` | **Src1Format** |  |
| **0x4D74** | `+0x304` | **Src1W29_Res** |  |
| **0x4D78** | `+0x308` | **Src1W30_Res** |  |
| **0x4D7C** | `+0x30c` | **Src1W31_Res** |  |
| **0x4D80** | `+0x310` | **Src1W32_Res** |  |
| **0x4D84** | `+0x314` | **Src1W33_Res** |  |
| **0x4D88** | `+0x318` | **Src1W34_Res** |  |
| **0x4D8C** | `+0x31c` | **Src1W35_Res** |  |
| **0x4D90** | `+0x320` | **Src1W36_Res** |  |
| **0x4D94** | `+0x324` | **Src1W37_Res** |  |
| **0x4D98** | `+0x328` | **Src1W38_Res** |  |
| **0x4D9C** | `+0x32c` | **Src1W39_Res** |  |
| **0x4DA0** | `+0x330` | **Src1W40_Res** |  |
| **0x4DA4** | `+0x334` | **Src1W41_Res** |  |
| **0x4DA8** | `+0x338` | **Src1W42_Res** |  |
| **0x4DAC** | `+0x33c` | **Src1W43_Res** |  |
| **0x4DB0** | `+0x340` | **Src1W44_Res** |  |
| **0x4DB4** | `+0x344` | **Src1W45_Res** |  |
| **0x4DB8** | `+0x348` | **Src2Format** |  |
| **0x4DBC** | `+0x34c` | **Src2W47_Res** |  |
| **0x4DC0** | `+0x350` | **Src2W48_Res** |  |
| **0x4DC4** | `+0x354` | **Src2W49_Res** |  |
| **0x4DC8** | `+0x358` | **Src2W50_Res** |  |
| **0x4DCC** | `+0x35c` | **Src2W51_Res** |  |
| **0x4DD0** | `+0x360` | **Src2W52_Res** |  |
| **0x4DD4** | `+0x364` | **Src2W53_Res** |  |
| **0x4DD8** | `+0x368` | **Src2W54_Res** |  |
| **0x4DDC** | `+0x36c` | **Src2W55_Res** |  |
| **0x4DE0** | `+0x370` | **Src2W56_Res** |  |
| **0x4DE4** | `+0x374` | **Src2W57_Res** |  |
| **0x4DE8** | `+0x378` | **Src2W58_Res** |  |
| **0x4DEC** | `+0x37c` | **Src2W59_Res** |  |
| **0x4DF0** | `+0x380` | **Src2W60_Res** |  |
| **0x4DF4** | `+0x384` | **Src2W61_Res** |  |
| **0x4DF8** | `+0x388` | **Src2W62_Res** |  |
| **0x4DFC** | `+0x38c` | **Src2W63_Res** |  |
| **0x4E00** | `+0x390` | **Src2W64_Res** |  |
| **0x4E04** | `+0x394` | **Src2W65_Res** |  |
| **0x4E08** | `+0x398` | **Src2W66_Res** |  |
| **0x4E0C** | `+0x39c` | **Src2W67_Res** |  |
| **0x4E10** | `+0x3a0` | **Src2W68_Res** |  |
| **0x4E14** | `+0x3a4` | **Src2W69_Res** |  |
| **0x4E18** | `+0x3a8` | **Src2W70_Res** |  |
| **0x4E1C** | `+0x3ac` | **TileDmaSrcTraceCfg** |  |
| **0x4E20** | `+0x3b0` | **Src2W72_Res** |  |
| **0x4E24** | `+0x3b4` | **Src2W73_Res** |  |
| **0x4E28** | `+0x3b8` | **Src2W74_Res** |  |
| **0x4E2C** | `+0x3bc` | **Src2W75_Res** |  |
| **0x4E30** | `+0x3c0` | **Src2W76_Res** |  |
| **0x4E34** | `+0x3c4` | **Src2W77_Res** |  |
| **0x4E38** | `+0x3c8` | **Src2W78_Res** |  |
| **0x4E3C** | `+0x3cc` | **Src2W79_Res** |  |
| **0x4E40** | `+0x3d0` | **Src1UserTag** |  |


## TileDMA Destination (TileDmaDst) (0x5100)
- **Base Offset**: `+0x4f0` (relative to ZinAneTd base).
- **Structure**: 23 registers (`0x17` words, `0x5c` bytes).

| :--- | :--- | :--- | :--- |
| **0x5100** | `+0x4f0` | **DstBaseAddrLo** |  |
| **0x5104** | `+0x4f4` | **DstBaseAddrHi** |  |
| **0x510C** | `+0x4fc` | **DstRowStride** |  |
| **0x5110** | `+0x500` | **DstPlaneStride** |  |
| **0x5114** | `+0x504` | **DstDepthStride** |  |
| **0x5118** | `+0x508` | **DstGroupStride** |  |
| **0x511C** | `+0x50c` | **DstW7_Res** |  |
| **0x5120** | `+0x510` | **DstW8_Res** |  |
| **0x5124** | `+0x514` | **DstW9_Res** |  |
| **0x5128** | `+0x518` | **DstW10_Res** |  |
| **0x512C** | `+0x51c` | **DstW11_Res** |  |
| **0x5130** | `+0x520` | **DstW12_Res** |  |
| **0x5134** | `+0x524` | **DstW13_Res** |  |
| **0x5138** | `+0x528` | **DstFormat** |  |
| **0x513C** | `+0x52c` | **DstW15_Res** |  |
| **0x5140** | `+0x530` | **DstW16_Res** |  |
| **0x5144** | `+0x534` | **DstW17_Res** |  |
| **0x5148** | `+0x538` | **DstW18_Res** |  |
| **0x514C** | `+0x53c` | **DstW19_Res** |  |
| **0x5150** | `+0x540` | **DstW20_Res** |  |
| **0x5154** | `+0x544` | **DstW21_Res** |  |
| **0x5158** | `+0x548` | **DstUserTag** |  |


## KernelDMA Source (KernelDmaSrc) (0x5500)
- **Count**: 81 registers (`0x51` words, `0x144` bytes).
- **Object Layout**: Starts at `+0x034` of the `ZinAneTd` object.
| :--- | :--- | :--- | :--- |
| **0x5500** | `+0x034` | **KernelDmaEnable** |  |
| **0x5504** | `+0x038` | **AlignedCoeffSize** |  |
| **0x5508** | `+0x03c` | **Prefetch** |  |
| **0x550C** | `+0x040` | **KW3_Res** |  |
| **0x5510** | `+0x044` | **KW4_Res** |  |
| **0x5514** | `+0x048` | **KW5_Res** |  |
| **0x5518** | `+0x04c` | **KernelGroupStride** |  |
| **0x551C** | `+0x050` | **KernelOCGStride** |  |
| **0x5520** | `+0x054` | **CoeffDMAConfig0** |  |
| **0x5524** | `+0x058` | **CoeffDMAConfig1** |  |
| **0x5528** | `+0x05c` | **CoeffDMAConfig2** |  |
| **0x552C** | `+0x060` | **CoeffDMAConfig3** |  |
| **0x5530** | `+0x064` | **CoeffDMAConfig4** |  |
| **0x5534** | `+0x068` | **CoeffDMAConfig5** |  |
| **0x5538** | `+0x06c` | **CoeffDMAConfig6** |  |
| **0x553C** | `+0x070` | **CoeffDMAConfig7** |  |
| **0x5540** | `+0x074` | **CoeffDMAConfig8** |  |
| **0x5544** | `+0x078` | **CoeffDMAConfig9** |  |
| **0x5548** | `+0x07c` | **CoeffDMAConfig10** |  |
| **0x554C** | `+0x080` | **CoeffDMAConfig11** |  |
| **0x5550** | `+0x084` | **CoeffDMAConfig12** |  |
| **0x5554** | `+0x088` | **CoeffDMAConfig13** |  |
| **0x5558** | `+0x08c` | **CoeffDMAConfig14** |  |
| **0x555C** | `+0x090` | **CoeffDMAConfig15** |  |
| **0x5560** | `+0x094` | **CoeffBaseAddr0** |  |
| **0x5564** | `+0x098` | **CoeffBaseAddr1** |  |
| **0x5568** | `+0x09c` | **CoeffBaseAddr2** |  |
| **0x556C** | `+0x0a0` | **CoeffBaseAddr3** |  |
| **0x5570** | `+0x0a4` | **CoeffBaseAddr4** |  |
| **0x5574** | `+0x0a8` | **CoeffBaseAddr5** |  |
| **0x5578** | `+0x0ac` | **CoeffBaseAddr6** |  |
| **0x557C** | `+0x0b0` | **CoeffBaseAddr7** |  |
| **0x5580** | `+0x0b4` | **CoeffBaseAddr8** |  |
| **0x5584** | `+0x0b8` | **CoeffBaseAddr9** |  |
| **0x5588** | `+0x0bc` | **CoeffBaseAddr10** |  |
| **0x558C** | `+0x0c0` | **CoeffBaseAddr11** |  |
| **0x5590** | `+0x0c4` | **CoeffBaseAddr12** |  |
| **0x5594** | `+0x0c8` | **CoeffBaseAddr13** |  |
| **0x5598** | `+0x0cc` | **CoeffBaseAddr14** |  |
| **0x559C** | `+0x0d0` | **CoeffBaseAddr15** |  |
| **0x55A0** | `+0x0d4` | **CoeffBfrSize0** |  |
| **0x55A4** | `+0x0d8` | **CoeffBfrSize1** |  |
| **0x55A8** | `+0x0dc` | **CoeffBfrSize2** |  |
| **0x55AC** | `+0x0e0` | **CoeffBfrSize3** |  |
| **0x55B0** | `+0x0e4` | **CoeffBfrSize4** |  |
| **0x55B4** | `+0x0e8` | **CoeffBfrSize5** |  |
| **0x55B8** | `+0x0ec` | **CoeffBfrSize6** |  |
| **0x55BC** | `+0x0f0` | **CoeffBfrSize7** |  |
| **0x55C0** | `+0x0f4` | **CoeffBfrSize8** |  |
| **0x55C4** | `+0x0f8` | **CoeffBfrSize9** |  |
| **0x55C8** | `+0x0fc` | **CoeffBfrSize10** |  |
| **0x55CC** | `+0x100` | **CoeffBfrSize11** |  |
| **0x55D0** | `+0x104` | **CoeffBfrSize12** |  |
| **0x55D4** | `+0x108` | **CoeffBfrSize13** |  |
| **0x55D8** | `+0x10c` | **CoeffBfrSize14** |  |
| **0x55DC** | `+0x110` | **CoeffBfrSize15** |  |
| **0x55E0** | `+0x114` | **BiasDMAConfig** |  |
| **0x55E4** | `+0x118` | **BiasBaseAddr** |  |
| **0x55E8** | `+0x11c` | **BiasW58_Res** |  |
| **0x55EC** | `+0x120` | **BiasW59_Res** |  |
| **0x55F0** | `+0x124` | **PostScaleDMAConfig** |  |
| **0x55F4** | `+0x128` | **PostScaleBaseAddr** |  |
| **0x55F8** | `+0x12c` | **PostScaleW62_Res** |  |
| **0x55FC** | `+0x130` | **PostScaleW63_Res** |  |
| **0x5600** | `+0x134` | **PaletteDMAConfig** |  |
| **0x5604** | `+0x138` | **PaletteBaseAddr** |  |
| **0x5608** | `+0x13c` | **PaletteW66_Res** |  |
| **0x560C** | `+0x140` | **PaletteW67_Res** |  |
| **0x5610** | `+0x144` | **NLutDMAConfig** |  |
| **0x5614** | `+0x148` | **NLutBaseAddr** |  |
| **0x5618** | `+0x14c` | **NLutW70_Res** |  |
| **0x561C** | `+0x150` | **NLutW71_Res** |  |
| **0x5620** | `+0x154` | **KW72_Res** |  |
| **0x5624** | `+0x158` | **KW73_Res** |  |
| **0x5628** | `+0x15c` | **KW74_Res** |  |
| **0x562C** | `+0x160` | **KW75_Res** |  |
| **0x5630** | `+0x164` | **KW76_Res** |  |
| **0x5634** | `+0x168` | **KW77_Res** |  |
| **0x5638** | `+0x16c` | **KW78_Res** |  |
| **0x563C** | `+0x170` | **KW79_Res** |  |
| **0x5640** | `+0x174` | **KernelDmaUserTag** |  |


## CacheDMA (0x5900)
- **Base Offset**: `+0x554` (relative to ZinAneTd base).
- **Structure**: 14 registers (`0x0e` words, `0x38` bytes).

| :--- | :--- | :--- | :--- |
| **0x5900** | `+0x554` | **CacheDmaEnable** |  |
| **0x5904** | `+0x558` | **CacheDmaW1_Res** |  |
| **0x5908** | `+0x55c` | **CacheDmaW2_Res** |  |
| **0x590C** | `+0x560` | **CacheDmaW3_Res** |  |
| **0x5910** | `+0x564` | **CacheDmaW4_Res** |  |
| **0x5914** | `+0x568` | **CacheDmaW5_Res** |  |
| **0x5918** | `+0x56c` | **CacheDmaW6_Res** |  |
| **0x591C** | `+0x570` | **CacheDmaW7_Res** |  |
| **0x5920** | `+0x574` | **CacheDmaW8_Res** |  |
| **0x5924** | `+0x578` | **CacheDmaW9_Res** |  |
| **0x5928** | `+0x57c` | **CacheDmaW10_Res** |  |
| **0x592C** | `+0x580` | **CacheDmaW11_Res** |  |
| **0x5930** | `+0x584` | **CacheDmaW12_Res** |  |
| **0x5934** | `+0x588` | **PrefetchRate** |  |


## Hardware Traits (ZinHWTraits<19u>)
The compiler maintains a set of statically defined traits for the H17 architecture (19u) that explicitly dictate the raw memory offsets of hardware components.

### L2 Stride Offsets
| :--- | :--- | :--- | :--- |
| ANE_L2_SOURCE_CHANNEL_STRIDE_OFFSET | `+Source 1` | Channel |  |
| ANE_L2_SOURCE_ROW_STRIDE_OFFSET | `+Source 1` | Row |  |
| ANE_L2_SOURCE_DEPTH_STRIDE_OFFSET | `+Source 1` | Depth |  |
| ANE_L2_SOURCE_GROUP_STRIDE_OFFSET | `+Source 1` | Group |  |
| ANE_L2_SOURCE2_CHANNEL_STRIDE_OFFSET | `+Source 2` | Channel |  |
| ANE_L2_SOURCE2_ROW_STRIDE_OFFSET | `+Source 2` | Row |  |
| ANE_L2_SOURCE2_DEPTH_STRIDE_OFFSET | `+Source 2` | Depth |  |
| ANE_L2_SOURCE2_GROUP_STRIDE_OFFSET | `+Source 2` | Group |  |
| ANE_L2_RESULT_CHANNEL_STRIDE_OFFSET | `+Result` | Channel |  |
| ANE_L2_RESULT_ROW_STRIDE_OFFSET | `+Result` | Row |  |
| ANE_L2_RESULT_DEPTH_STRIDE_OFFSET | `+Result` | Depth |  |
| ANE_L2_RESULT_GROUP_STRIDE_OFFSET | `+Result` | Group |  |


### Tile DMA Stride Offsets
| :--- | :--- | :--- | :--- |
| ANE_TILE_DMA_SRC_ROW_STRIDE_OFFSET | `+Source 1` | Row |  |
| ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET | `+Source 1` | Plane |  |
| ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET | `+Source 1` | Depth |  |
| ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET | `+Source 1` | Group |  |
| ANE_TILE_DMA_SRC_ROW_STRIDE2_OFFSET | `+Source 2` | Row |  |
| ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET | `+Source 2` | Plane |  |
| ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET | `+Source 2` | Depth |  |
| ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET | `+Source 2` | Group |  |
| ANE_TILE_DMA_DST_ROW_STRIDE_OFFSET | `+Destination` | Row |  |


## Standalone Performance Tracer Registers
| :--- | :--- | :--- | :--- |
| **0x5D00** | `+0x4a8` | **PETraceCfg** | Found via HandlesPerfTracerConfig disassembly |
| **0x5D04** | `+0x4e4` | **NETraceCfg** | Found via HandlesPerfTracerConfig disassembly |


