# ANE H18 (A19) Register Map

Exhaustive row-by-row mapping for H18 (A19).

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
- **Object Layout**: Starts at `+0x240` of the `ZinAneTd` object.
| HW Addr | Index | ZinOffset | Name |
| :--- | :---: | :--- | :--- |
| **0x0000** | 0 | `+0x240` | **ChCfg** | **InFmt**: 0-2, **OutFmt**: 6-8. |
| **0x0004** | 1 | `+0x22c` | **InWidth** | 0-16. |
| **0x0008** | 2 | `+0x230` | **InHeight** | 0-16. |
| **0x000C** | 3 | `+0x234` | **InChannels** | 0-16. |
| **0x0010** | 4 | `+0x238` | **InDepth** | 0-16. |
| **0x0014** | 5 | `+0x23c` | **OutWidth** | 0-16. |
| **0x0018** | 6 | `+0x240` | **OutHeight** | 0-16. |
| **0x001C** | 7 | `+0x244` | **OutChannels** | 0-16. |
| **0x0020** | 8 | `+0x248` | **OutDepth** | 0-16. |
| **0x0024** | 9 | `+0x24c` | **NumGroups** | 0-16. |
| **0x0028** | 10| `+0x250` | **ConvCfg** | **Kw**: 0-5, **Kh**: 6-11, **Sx**: 13-14, **Sy**: 15-16, **TexMode**: 22. |
| **0x002C** | 11| `+0x254` | **ConvCfg3d** | **Sz**: 6-7, **Oz**: 21-25. |
| **0x0030** | 12| `+0x258` | **UnicastCin** | |
| **0x0034** | 13| `+0x25c` | **TileHeight** | 0-16. |
| **0x0038** | 14| `+0x260` | **TileOverlap** | **Overlap**: 16-20, **PadTop**: 21-25, **PadBottom**: 26-30, **Reflect**: 31. |
| **0x003C** | 15| `+0x264` | **Sync_Pads** | |
| **0x0040** | 16| `+0x268` | **Sync_Pads2** | |
| **0x0044** | 17| `+0x26c` | **PatchCfg** | **PatchWidth**: 0-3, **PatchHeight**: 4-8. |
| **0x0048** | 18| `+0x270` | **NECfg** | **TaskType**: 4-7. |
| **0x004C** | 19| `+0x274` | **PECfg** | |
| **0x0050** | 20| `+0x278` | **NID** | |
| **0x0054** | 21| `+0x27c` | **DPE** | |
| **0x0058** | 22| `+0x280` | **Ldtid** | |

## L2 Cache (0x4100)
- **Count**: 43 registers (`0x2b` words, `0xac` bytes).
- **Object Layout**: Starts at `+0x3d4` of the `ZinAneTd` object.
| HW Addr | Index | ZinOffset | Name |
| :--- | :---: | :--- | :--- |
| **0x4100** | 0 | `+0x3d4` | **Control** |
| **0x4104** | 1 | `+0x3d8` | **MirrorWord_1** |
| **0x4108** | 2 | `+0x3dc` | **MirrorWord_2** |
| **0x410C** | 3 | `+0x3e0` | **MirrorWord_3** |
| **0x4110** | 4 | `+0x3e4` | **Src1ChannelStride** |
| **0x4114** | 5 | `+0x3e8` | **Src1RowStride** |
| **0x4118** | 6 | `+0x3ec` | **Src1DepthStride** |
| **0x411C** | 7 | `+0x3f0` | **Src1GroupStride** |
| **0x4120** | 8 | `+0x3f4` | **Src1PlaneStride** |
| **0x4124** | 9 | `+0x3f8` | **Src2ChannelStride** |
| **0x4128** | 10| `+0x3fc` | **Src2RowStride** |
| **0x412C** | 11| `+0x400` | **Src2DepthStride** |
| **0x4130** | 12| `+0x404` | **Src2GroupStride** |
| **0x4134** | 13| `+0x408` | **SrcIdxBaseAddr** |
| **0x413C** | 15| `+0x410` | **SrcIdxChannelStride** |
| **0x4140** | 16| `+0x414` | **SrcIdxDepthStride** |
| **0x4144** | 17| `+0x418` | **Config** |
| **0x414C** | 19| `+0x420` | **ResultBaseAddr** |
| **0x4150** | 20| `+0x424` | **ResultChannelStride** |
| **0x4154** | 21| `+0x428` | **ResultRowStride** |
| **0x4158** | 22| `+0x42c` | **ResultDepthStride** |

## Planar Engine (PE) (0x4500)
- **Count**: 16 registers (`0x10` words, `0x40` bytes).
- **Object Layout**: Starts at `+0x48c` of the `ZinAneTd` object.
| HW Addr | Index | ZinOffset | Name | Bits |
| :--- | :---: | :--- | :--- | :--- |
| **0x4500** | 0 | `+0x42c` | **Config** | **OpMode**: 2-4, **FirstSource**: 16-18, **SecondSource**: 19-21. |
| **0x4504** | 1 | `+0x430` | **Bias** | |
| **0x4508** | 2 | `+0x434` | **Scale** | |
| **0x450C** | 3 | `+0x438` | **FinalScaleEps** | |
| **0x4510** | 4 | `+0x43c` | **PreScale** | |
| **0x4514** | 5 | `+0x440` | **FinalScale** | |
| **0x4518** | 6 | `+0x444` | **LUT1** | |
| **0x451C** | 7 | `+0x448` | **LUT2** | |
| **0x4520** | 8 | `+0x44c` | **LUT3** | |
| **0x4524** | 9 | `+0x450` | **LUT4** | |
| **0x4528** | 10| `+0x454` | **LUT5** | |
| **0x452C** | 11| `+0x458` | **LUT6** | |
| **0x4530** | 12| `+0x45c` | **LUT7** | |
| **0x4534** | 13| `+0x460` | **LUT8** | |
| **0x4538** | 14| `+0x464` | **Quant** | |
| **0x453C** | 15| `+0x468` | **ExtraCfg** | |

## Neural Engine (NE) (0x4900)
- **Base Offset**: `+0x4d4` (relative to ZinAneTd base).
- **Structure**: Core convolution and post-processing registers.

| HW Addr | Index | ZinOffset | Name | Bits |
| :--- | :---: | :--- | :--- | :--- |
| **0x4900** | 0 | `+0x4d4` | **KernelCfg** | |
| **0x4904** | 1 | `+0x4d8` | **MacCfg** | |
| **0x4908** | 2 | `+0x4dc` | **MatVecBias** | |
| **0x490C** | 3 | `+0x4e0` | **Bias** | 0-31. |
| **0x4910** | 4 | `+0x4e4` | **PostScale** | 0-31. |
| **0x4914** | 5 | `+0x4e8` | **RcasConfig** | |
| **0x4918** | 6 | `+0x4ec` | **RoundModeCfg** | |
| **0x491C** | 7 | `+0x4f0` | **SRSeed0** | |
| **0x4920** | 8 | `+0x4f4` | **SRSeed1** | |
| **0x4924** | 9 | `+0x4f8` | **SRSeed2** | |
| **0x4928** | 10| `+0x4fc` | **SRSeed3** | |
| **0x492C** | 11| `+0x500` | **QuantZeroPoint** | |
| **0x4930** | 12| `+0x504` | **ExtraCfg** | |

## TileDMA Source (TileDmaSrc) (0x4D00)
- **Base Offset**: `+0x2ac` (relative to ZinAneTd base).
- **Structure**: 81 registers (`0x51` words, `0x144` bytes).

| HW Addr | Index | ZinOffset | Name | Bits |
| :--- | :---: | :--- | :--- | :--- |
| **0x4D00** | 0 | `+0x2ac` | **Src1BaseLo** | |
| **0x4D04** | 1 | `+0x2b0` | **Src1BaseHi** | |
| **0x4D08** | 2 | `+0x2b4` | **Src1ChanStride** | |
| **0x4D0C** | 3 | `+0x2b8` | **Src1RowStride** |
| **0x4D10** | 4 | `+0x2bc` | **Src1DepthStride** |
| **0x4D14** | 5 | `+0x2c0` | **Src1GroupStride** |
| **0x4D18** | 6 | `+0x2c4` | **Src1PlaneStride** |
| **0x4D1C** | 7 | `+0x2c8` | **Src1W7_Res** |
| **0x4D20** | 8 | `+0x2cc` | **Src1W8_Res** |
| **0x4D24** | 9 | `+0x2d0` | **Src1W9_Res** |
| **0x4D28** | 10| `+0x2d4` | **Src1MDAddrLo** |
| **0x4D2C** | 11| `+0x2d8` | **Src1MDAddrHi** |
| **0x4D30** | 12| `+0x2dc` | **Src1MDConfig** |
| **0x4D34** | 13| `+0x2e0` | **Src1MDSize** |
| **0x4D38** | 14| `+0x2e4` | **Src1W14_Res** |
| **0x4D3C** | 15| `+0x2e8` | **Src1W15_Res** |
| **0x4D40** | 16| `+0x2ec` | **Src1W16_Res** |
| **0x4D44** | 17| `+0x2f0` | **Src1W17_Res** |
| **0x4D48** | 18| `+0x2f4` | **Src1W18_Res** |
| **0x4D4C** | 19| `+0x2f8` | **Src1W19_Res** |
| **0x4D50** | 20| `+0x2fc` | **Src1W20_Res** |
| **0x4D54** | 21| `+0x300` | **Src1W21_Res** |
| **0x4D58** | 22| `+0x304` | **Src1W22_Res** |
| **0x4D5C** | 23| `+0x308` | **Src1W23_Res** |
| **0x4D60** | 24| `+0x30c` | **Src1W24_Res** |
| **0x4D64** | 25| `+0x310` | **Src1W25_Res** |
| **0x4D68** | 26| `+0x314` | **Src1W26_Res** |
| **0x4D6C** | 27| `+0x318` | **Src1W27_Res** |
| **0x4D70** | 28| `+0x31c` | **Src1Format** |
| **0x4D74** | 29| `+0x320` | **Src1W29_Res** |
| **0x4D78** | 30| `+0x324` | **Src1W30_Res** |
| **0x4D7C** | 31| `+0x328` | **Src1W31_Res** |
| **0x4D80** | 32| `+0x32c` | **Src1W32_Res** |
| **0x4D84** | 33| `+0x330` | **Src1W33_Res** |
| **0x4D88** | 34| `+0x334` | **Src1W34_Res** |
| **0x4D8C** | 35| `+0x338` | **Src1W35_Res** |
| **0x4D90** | 36| `+0x33c` | **Src1W36_Res** |
| **0x4D94** | 37| `+0x340` | **Src1W37_Res** |
| **0x4D98** | 38| `+0x344` | **Src1W38_Res** |
| **0x4D9C** | 39| `+0x348` | **Src1W39_Res** |
| **0x4DA0** | 40| `+0x34c` | **Src1W40_Res** |
| **0x4DA4** | 41| `+0x350` | **Src1W41_Res** |
| **0x4DA8** | 42| `+0x354` | **Src1W42_Res** |
| **0x4DAC** | 43| `+0x358` | **Src1W43_Res** |
| **0x4DB0** | 44| `+0x35c` | **Src1W44_Res** |
| **0x4DB4** | 45| `+0x360` | **Src1W45_Res** |
| **0x4DB8** | 46| `+0x364` | **Src2Format** |
| **0x4DBC** | 47| `+0x368` | **Src2W47_Res** |
| **0x4DC0** | 48| `+0x36c` | **Src2W48_Res** |
| **0x4DC4** | 49| `+0x370` | **Src2W49_Res** |
| **0x4DC8** | 50| `+0x374` | **Src2W50_Res** |
| **0x4DCC** | 51| `+0x378` | **Src2W51_Res** |
| **0x4DD0** | 52| `+0x37c` | **Src2W52_Res** |
| **0x4DD4** | 53| `+0x380` | **Src2W53_Res** |
| **0x4DD8** | 54| `+0x384` | **Src2W54_Res** |
| **0x4DDC** | 55| `+0x388` | **Src2W55_Res** |
| **0x4DE0** | 56| `+0x38c` | **Src2W56_Res** |
| **0x4DE4** | 57| `+0x390` | **Src2W57_Res** |
| **0x4DE8** | 58| `+0x394` | **Src2W58_Res** |
| **0x4DEC** | 59| `+0x398` | **Src2W59_Res** |
| **0x4DF0** | 60| `+0x39c` | **Src2W60_Res** |
| **0x4DF4** | 61| `+0x3a0` | **Src2W61_Res** |
| **0x4DF8** | 62| `+0x3a4` | **Src2W62_Res** |
| **0x4DFC** | 63| `+0x3a8` | **Src2W63_Res** |
| **0x4E00** | 64| `+0x3ac` | **Src2W64_Res** |
| **0x4E04** | 65| `+0x3b0` | **Src2W65_Res** |
| **0x4E08** | 66| `+0x3b4` | **Src2W66_Res** |
| **0x4E0C** | 67| `+0x3b8` | **Src2W67_Res** |
| **0x4E10** | 68| `+0x3bc` | **Src2W68_Res** |
| **0x4E14** | 69| `+0x3c0` | **Src2W69_Res** |
| **0x4E18** | 70| `+0x3c4` | **Src2W70_Res** |
| **0x4E1C** | 71| `+0x3c8` | **Src2W71_Res** |
| **0x4E20** | 72| `+0x3cc` | **Src2W72_Res** |
| **0x4E24** | 73| `+0x3d0` | **Src2W73_Res** |
| **0x4E28** | 74| `+0x3d4` | **Src2W74_Res** |
| **0x4E2C** | 75| `+0x3d8` | **Src2W75_Res** |
| **0x4E30** | 76| `+0x3dc` | **Src2W76_Res** |
| **0x4E34** | 77| `+0x3e0` | **Src2W77_Res** |
| **0x4E38** | 78| `+0x3e4` | **Src2W78_Res** |
| **0x4E3C** | 79| `+0x3e8` | **Src2W79_Res** |
| **0x4E40** | 80| `+0x3ec` | **Src1UserTag** |

## TileDMA Destination (TileDmaDst) (0x5100)
- **Count**: 27 registers (`0x1b` words, `0x6c` bytes).
- **Object Layout**: Starts at `+0x510` of the `ZinAneTd` object.
| HW Addr | Index | ZinOffset | Name |
| :--- | :---: | :--- | :--- |
| **0x5100** | 0 | `+0x514` | **DstBaseAddrLo** |
| **0x5104** | 1 | `+0x518` | **DstBaseAddrHi** |
| **0x5108** | 2 | `+0x51c` | **DstChanStride** |
| **0x510C** | 3 | `+0x520` | **DstRowStride** |
| **0x5110** | 4 | `+0x524` | **DstDepthStride** |
| **0x5114** | 5 | `+0x528` | **DstGroupStride** |
| **0x5118** | 6 | `+0x52c` | **DstW6_Res** |
| **0x511C** | 7 | `+0x530` | **DstW7_Res** |
| **0x5120** | 8 | `+0x534` | **DstW8_Res** |
| **0x5124** | 9 | `+0x538` | **DstW9_Res** |
| **0x5128** | 10| `+0x53c` | **DstW10_Res** |
| **0x512C** | 11| `+0x540` | **DstW11_Res** |
| **0x5130** | 12| `+0x544` | **DstW12_Res** |
| **0x5134** | 13| `+0x548` | **DstW13_Res** |
| **0x5138** | 14| `+0x54c` | **DstFormat** |
| **0x513C** | 15| `+0x550` | **DstW15_Res** |
| **0x5140** | 16| `+0x554` | **DstW16_Res** |
| **0x5144** | 17| `+0x558` | **DstW17_Res** |
| **0x5148** | 18| `+0x55c` | **DstW18_Res** |
| **0x514C** | 19| `+0x560` | **DstW19_Res** |
| **0x5150** | 20| `+0x564` | **DstW20_Res** |
| **0x5154** | 21| `+0x568` | **DstW21_Res** |
| **0x5158** | 22| `+0x56c` | **DstW22_Res** |
| **0x515C** | 23| `+0x570` | **DstW23_Res** |
| **0x5160** | 24| `+0x574` | **DstW24_Res** |
| **0x5164** | 25| `+0x578` | **DstW25_Res** |
| **0x5168** | 26| `+0x57c` | **DstUserTag** |

## KernelDMA Source (KernelDmaSrc) (0x5500)
- **Count**: 83 registers (`0x53` words, `0x14c` bytes).
- **Object Layout**: Starts at `+0x034` of the `ZinAneTd` object.
| HW Addr | Index | ZinOffset | Name |
| :--- | :---: | :--- | :--- |
| **0x5500** | 0 | `+0x034` | **KernelDmaEnable** |
| **0x5504** | 1 | `+0x038` | **AlignedCoeffSize** |
| **0x5508** | 2 | `+0x03c` | **Prefetch** |
| **0x550C** | 3 | `+0x040` | **KW3_Res** |
| **0x5510** | 4 | `+0x044` | **KW4_Res** |
| **0x5514** | 5 | `+0x048` | **KW5_Res** |
| **0x5518** | 6 | `+0x04c` | **KernelGroupStride** |
| **0x551C** | 7 | `+0x050` | **KernelOCGStride** |
| **0x5520** | 8 | `+0x054` | **CoeffDMAConfig0** |
| **0x5524** | 9 | `+0x058` | **CoeffDMAConfig1** |
| **0x5528** | 10| `+0x05c` | **CoeffDMAConfig2** |
| **0x552C** | 11| `+0x060` | **CoeffDMAConfig3** |
| **0x5530** | 12| `+0x064` | **CoeffDMAConfig4** |
| **0x5534** | 13| `+0x068` | **CoeffDMAConfig5** |
| **0x5538** | 14| `+0x06c` | **CoeffDMAConfig6** |
| **0x553C** | 15| `+0x070` | **CoeffDMAConfig7** |
| **0x5540** | 16| `+0x074` | **CoeffDMAConfig8** |
| **0x5544** | 17| `+0x078` | **CoeffDMAConfig9** |
| **0x5548** | 18| `+0x07c` | **CoeffDMAConfig10** |
| **0x554C** | 19| `+0x080` | **CoeffDMAConfig11** |
| **0x5550** | 20| `+0x084` | **CoeffDMAConfig12** |
| **0x5554** | 21| `+0x088` | **CoeffDMAConfig13** |
| **0x5558** | 22| `+0x08c` | **CoeffDMAConfig14** |
| **0x555C** | 23| `+0x090` | **CoeffDMAConfig15** |
| **0x5560** | 24| `+0x094` | **CoeffBaseAddr0** |
| **0x5564** | 25| `+0x098` | **CoeffBaseAddr1** |
| **0x5568** | 26| `+0x09c` | **CoeffBaseAddr2** |
| **0x556C** | 27| `+0x0a0` | **CoeffBaseAddr3** |
| **0x5570** | 28| `+0x0a4` | **CoeffBaseAddr4** |
| **0x5574** | 29| `+0x0a8` | **CoeffBaseAddr5** |
| **0x5578** | 30| `+0x0ac` | **CoeffBaseAddr6** |
| **0x557C** | 31| `+0x0b0` | **CoeffBaseAddr7** |
| **0x5580** | 32| `+0x0b4` | **CoeffBaseAddr8** |
| **0x5584** | 33| `+0x0b8` | **CoeffBaseAddr9** |
| **0x5588** | 34| `+0x0bc` | **CoeffBaseAddr10** |
| **0x558C** | 35| `+0x0c0` | **CoeffBaseAddr11** |
| **0x5590** | 36| `+0x0c4` | **CoeffBaseAddr12** |
| **0x5594** | 37| `+0x0c8` | **CoeffBaseAddr13** |
| **0x5598** | 38| `+0x0cc` | **CoeffBaseAddr14** |
| **0x559C** | 39| `+0x0d0` | **CoeffBaseAddr15** |
| **0x55A0** | 40| `+0x0d4` | **CoeffBfrSize0** |
| **0x55A4** | 41| `+0x0d8` | **CoeffBfrSize1** |
| **0x55A8** | 42| `+0x0dc` | **CoeffBfrSize2** |
| **0x55AC** | 43| `+0x0e0` | **CoeffBfrSize3** |
| **0x55B0** | 44| `+0x0e4` | **CoeffBfrSize4** |
| **0x55B4** | 45| `+0x0e8` | **CoeffBfrSize5** |
| **0x55B8** | 46| `+0x0ec` | **CoeffBfrSize6** |
| **0x55BC** | 47| `+0x0f0` | **CoeffBfrSize7** |
| **0x55C0** | 48| `+0x0f4` | **CoeffBfrSize8** |
| **0x55C4** | 49| `+0x0f8` | **CoeffBfrSize9** |
| **0x55C8** | 50| `+0x0fc` | **CoeffBfrSize10** |
| **0x55CC** | 51| `+0x100` | **CoeffBfrSize11** |
| **0x55D0** | 52| `+0x104` | **CoeffBfrSize12** |
| **0x55D4** | 53| `+0x108` | **CoeffBfrSize13** |
| **0x55D8** | 54| `+0x10c` | **CoeffBfrSize14** |
| **0x55DC** | 55| `+0x110` | **CoeffBfrSize15** |
| **0x55E0** | 56| `+0x114` | **BiasDMAConfig** |
| **0x55E4** | 57| `+0x118` | **BiasBaseAddr** |
| **0x55E8** | 58| `+0x11c` | **BiasW58_Res** |
| **0x55EC** | 59| `+0x120` | **BiasW59_Res** |
| **0x55F0** | 60| `+0x124` | **PostScaleDMAConfig** |
| **0x55F4** | 61| `+0x128` | **PostScaleBaseAddr** |
| **0x55F8** | 62| `+0x12c` | **PostScaleW62_Res** |
| **0x55FC** | 63| `+0x130` | **PostScaleW63_Res** |
| **0x5600** | 64| `+0x134` | **PaletteDMAConfig** |
| **0x5604** | 65| `+0x138` | **PaletteBaseAddr** |
| **0x5608** | 66| `+0x13c` | **PaletteW66_Res** |
| **0x560C** | 67| `+0x140` | **PaletteW67_Res** |
| **0x5610** | 68| `+0x144` | **NLutDMAConfig** |
| **0x5614** | 69| `+0x148` | **NLutBaseAddr** |
| **0x5618** | 70| `+0x14c` | **NLutW70_Res** |
| **0x561C** | 71| `+0x150` | **NLutW71_Res** |
| **0x5620** | 72| `+0x154` | **KW72_Res** |
| **0x5624** | 73| `+0x158` | **KW73_Res** |
| **0x5628** | 74| `+0x15c` | **KW74_Res** |
| **0x562C** | 75| `+0x160` | **KW75_Res** |
| **0x5630** | 76| `+0x164` | **KW76_Res** |
| **0x5634** | 77| `+0x168` | **KW77_Res** |
| **0x5638** | 78| `+0x16c` | **KW78_Res** |
| **0x563C** | 79| `+0x170` | **KW79_Res** |
| **0x5640** | 80| `+0x174` | **KW80_Res** |
| **0x5644** | 81| `+0x178` | **KW81_Res** |
| **0x5648** | 82| `+0x17c` | **NonLinearUserTag** |

## CacheDMA (0x5900)
- **Count**: 14 registers (`0x0e` words, `0x38` bytes).
- **Object Layout**: Starts at `+0x584` of the `ZinAneTd` object.
| HW Addr | Index | ZinOffset | Name |
| :--- | :---: | :--- | :--- |
| **0x5900** | 0 | `+0x584` | **CacheDmaEnable** |
| **0x5904** | 1 | `+0x588` | **CacheDmaW1_Res** |
| **0x5908** | 2 | `+0x58c` | **CacheDmaW2_Res** |
| **0x590C** | 3 | `+0x590` | **CacheDmaW3_Res** |
| **0x5910** | 4 | `+0x594` | **CacheDmaW4_Res** |
| **0x5914** | 5 | `+0x598` | **CacheDmaW5_Res** |
| **0x5918** | 6 | `+0x59c` | **CacheDmaW6_Res** |
| **0x591C** | 7 | `+0x5a0` | **CacheDmaW7_Res** |
| **0x5920** | 8 | `+0x5a4` | **CacheDmaW8_Res** |
| **0x5924** | 9 | `+0x5a8` | **CacheDmaW9_Res** |
| **0x5928** | 10| `+0x5ac` | **CacheDmaW10_Res** |
| **0x592C** | 11| `+0x5b0` | **CacheDmaW11_Res** |
| **0x5930** | 12| `+0x5b4` | **CacheDmaW12_Res** |
| **0x5934** | 13| `+0x5b8` | **PrefetchRate** |

## Hardware Traits (ZinHWTraits<20u>)
The compiler maintains a set of statically defined traits for the H18 architecture (20u) that explicitly dictate the raw memory offsets of hardware components.

### L2 Stride Offsets
| Trait Symbol | Hex Value | Channel | Stride Type |
| :--- | :--- | :--- | :--- |
| ANE_L2_SOURCE_CHANNEL_STRIDE_OFFSET | 0x4110 | Source 1 | Channel |
| ANE_L2_SOURCE_ROW_STRIDE_OFFSET | 0x4114 | Source 1 | Row |
| ANE_L2_SOURCE_DEPTH_STRIDE_OFFSET | 0x4118 | Source 1 | Depth |
| ANE_L2_SOURCE_GROUP_STRIDE_OFFSET | 0x4120 | Source 1 | Group |
| ANE_L2_SOURCE2_CHANNEL_STRIDE_OFFSET | 0x4124 | Source 2 | Channel |
| ANE_L2_SOURCE2_ROW_STRIDE_OFFSET | 0x4128 | Source 2 | Row |
| ANE_L2_SOURCE2_DEPTH_STRIDE_OFFSET | 0x412C | Source 2 | Depth |
| ANE_L2_SOURCE2_GROUP_STRIDE_OFFSET | 0x4130 | Source 2 | Group |
| ANE_L2_RESULT_CHANNEL_STRIDE_OFFSET | 0x414C | Result | Channel |
| ANE_L2_RESULT_ROW_STRIDE_OFFSET | 0x4150 | Result | Row |
| ANE_L2_RESULT_DEPTH_STRIDE_OFFSET | 0x4154 | Result | Depth |
| ANE_L2_RESULT_GROUP_STRIDE_OFFSET | 0x4158 | Result | Group |

### Tile DMA Stride Offsets
| Trait Symbol | Hex Value | Channel | Stride Type |
| :--- | :--- | :--- | :--- |
| ANE_TILE_DMA_SRC_ROW_STRIDE_OFFSET | 0x4D0C | Source 1 | Row |
| ANE_TILE_DMA_SRC_PLANE_STRIDE_OFFSET | 0x4D10 | Source 1 | Plane |
| ANE_TILE_DMA_SRC_DEPTH_STRIDE_OFFSET | 0x4D1C | Source 1 | Depth |
| ANE_TILE_DMA_SRC_GROUP_STRIDE_OFFSET | 0x4D24 | Source 1 | Group |
| ANE_TILE_DMA_SRC_ROW_STRIDE2_OFFSET | 0x4D28 | Source 2 | Row |
| ANE_TILE_DMA_SRC_PLANE_STRIDE2_OFFSET | 0x4D2C | Source 2 | Plane |
| ANE_TILE_DMA_SRC_DEPTH_STRIDE2_OFFSET | 0x4D38 | Source 2 | Depth |
| ANE_TILE_DMA_SRC_GROUP_STRIDE2_OFFSET | 0x4D3C | Source 2 | Group |
| ANE_TILE_DMA_DST_ROW_STRIDE_OFFSET | 0x5110 | Destination | Row |

