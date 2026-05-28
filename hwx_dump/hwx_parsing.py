import struct
import sys
import os
import argparse
import json

# ANE HWX Parser (Python Alignment with hwx_parsing.m)
# Replicates C-based Mach-O, LUT, Task, and Register analysis.

HWX_MAGIC = 0xbeefface
LC_ANE_MAPPED_REGION = 0x40
HW_MAX_REGS = 0x20000

# Architecture block start addresses
H13_COMMON_START = 0x0000
H13_L2_START = 0x4800
H13_PE_START = 0x8800
H13_NE_START = 0xC800
H13_TILEDMA_SRC_START = 0x13800
H13_TILEDMA_DST_START = 0x17800
H13_KERNELDMA_START = 0x1F800

# H14 (subtype 5, ISA v11) OLD hardware addresses
H14_COMMON_START = 0x0000
H14_L2_START = 0x0500
H14_PE_START = 0x0900
H14_NE_START = 0x0D00
H14_TILEDMA_SRC_START = 0x1100
H14_TILEDMA_DST_START = 0x1500
H14_KERNELDMA_START = 0x1900

H14_COMMON_COUNT = 19
H14_L2_COUNT = 25
H14_PE_COUNT = 5
H14_NE_COUNT = 5
H14_TILEDMA_SRC_COUNT = 53
H14_TILEDMA_DST_COUNT = 9
H14_KERNELDMA_COUNT = 70

H16_COMMON_START = 0x0000
H16_L2_START = 0x4100
H16_PE_START = 0x4500
H16_NE_START = 0x4900
H16_TILEDMA_SRC_START = 0x4D00
H16_TILEDMA_DST_START = 0x5100
H16_KERNELDMA_START = 0x5500
H16_CACHEDMA_START = 0x5900
H16_PE_EXT_START = 0x44D0

H17_COMMON_COUNT = 23
H17_L2_COUNT = 42
H17_PE_COUNT = 16
H17_NE_COUNT = 13
H17_TILEDMA_SRC_COUNT = 83
H17_TILEDMA_DST_COUNT = 23
H17_KERNELDMA_COUNT = 74
H17_CACHEDMA_COUNT = 14

H18_COMMON_COUNT = 23
H18_L2_COUNT = 43
H18_PE_COUNT = 16
H18_NE_COUNT = 13
H18_TILEDMA_SRC_COUNT = 81
H18_TILEDMA_DST_COUNT = 27
H18_KERNELDMA_COUNT = 83
H18_CACHEDMA_COUNT = 14

# Register names dictionaries
h13_common_names = [
    "InDim", "pad0", "ChCfg", "Cin", "Cout", "OutDim",
    "pad1", "ConvCfg", "pad2", "GroupConvCfg", "TileCfg", "pad3",
    "pad4", "Cfg", "TaskInfo", "DPE"
]
h13_l2_names = [
    "L2Cfg", "SourceCfg", "SourceBase", "SourceChannelStride",
    "SourceRowStride", "pad0", "pad1", "pad2", "pad3", "pad4",
    "pad5", "pad6", "ResultCfg", "ResultBase", "ConvResultChannelStride",
    "ConvResultRowStride"
]
h13_pe_names = ["Cfg", "BiasScale", "PreScale", "FinalScale"]
h13_ne_names = ["KernelCfg", "MacCfg", "MatrixVectorBias", "AccBias", "PostScale"]
h13_tdma_src_names = [
    "DMAConfig", "pad0", "BaseAddr", "RowStride",
    "PlaneStride", "DepthStride", "GroupStride", "pad1",
    "pad2", "pad3", "pad4", "pad5",
    "pad6", "pad7", "Fmt", "pad8",
    "pad9", "pad10", "pad11", "pad12",
    "PixelOffset0", "PixelOffset1", "PixelOffset2", "PixelOffset3"
]
h13_tdma_dst_names = [
    "DMAConfig", "BaseAddr", "RowStride", "PlaneStride",
    "DepthStride", "GroupStride", "Fmt"
]
h13_kdma_names = ["Unknown", "Unknown", "CoeffDMAConfig", "CoeffBaseAddr", "CoeffBfrSize"]

# ============================================================================
# H14 Register Names
# ============================================================================

h14_common_names = [
    "InDim", "InDepth", "ChannelCfg", "InChannels", "OutChannels", "OutDim",
    "OutDepth", "pad0", "ConvCfg", "ConvCfg3d", "NumGroups", "TileHeight",
    "TileOverlap", "NECfg", "PatchCfg", "NID", "DPE", "pad1", "pad2"
]
h14_l2_names = [
    "Control", "Src1Cfg", "Src2Cfg", "Src1Base",
    "Src1ChannelStride", "Src1RowStride", "Src1DepthStride", "Src1GroupStride",
    "Src2Base", "Src2ChannelStride", "Src2RowStride", "Src2DepthStride", "Src2GroupStride",
    "ResultCfg", "ResultBase", "ResultChannelStride", "ResultRowStride", "ResultDepthStride", "ResultGroupStride",
    "SrcAndResultWrapCfg", "Src1WrapStart", "Src2WrapStart", "L2Reserved0", "ResultWrapIndex", "ResultWrapStartOffset"
]
h14_pe_names = [
    "PEConfig", "Bias", "Scale", "PreScale", "Quant"
]
h14_ne_names = [
    "KernelCfg", "MacCfg", "NEBias", "NEPostScale", "RoundModeCfg"
]
h14_tdma_src_names = [
    "Src1DMAConfig", "Src2DMAConfig", "Src1WrapCfg", "Src2WrapCfg", "Src1BaseAddr",
    "Src1RowStride", "Src1ChannelStride", "Src1DepthStride", "Src1GroupStride",
    "Src2BaseAddr", "Src2RowStride", "Src2ChannelStride", "Src2DepthStride", "Src2GroupStride",
    "Src1Fmt", "Src2Fmt", "Src1CacheHint2", "Src2CacheHint2", "Src1PixelOffsetX",
    "Src1PixelOffsetY", "Src1PixelOffsetZ", "Src1PixelOffsetW", "Src2PixelOffsetX",
    "Src2PixelOffsetY", "Src2PixelOffsetZ", "Src2PixelOffsetW", "Src1CompressedInfo",
    "Src1CompressedSizeLo", "Src1CompressedSizeHi", "Src2CompressedInfo", "Src2CompressedSizeLo",
    "Src2CompressedSizeHi", "Src1CropOffset", "Src2CropOffset", "Src1WrapDynamic",
    "Src2WrapDynamic", "Src1DependencyOffset", "Src2DependencyOffset", "TileDmaSrcReserved0",
    "TileDmaSrcReserved1", "TileDmaSrcReserved2", "TileDmaSrcReserved3", "TileDmaSrcReserved4",
    "TileDmaSrcReserved5", "TileDmaSrcReserved6", "TileDmaSrcReserved7", "TileDmaSrcReserved8",
    "TileDmaSrcReserved9", "TileDmaSrcReserved10", "TileDmaSrcReserved11", "TileDmaSrcReserved12",
    "TileDmaSrcReserved13", "TileDmaSrcReserved14"
]
h14_tdma_dst_names = [
    "DstDMAConfig", "DstBaseAddr", "DstRowStride", "DstPlaneStride",
    "DstDepthStride", "DstGroupStride", "DstFmt", "DstPixelOffset", "DstReserved"
]
h14_kdma_names = [
    "MasterConfig", "AlignedCoeffSizePerCh", "Prefetch", "Reserved0",
    "Reserved1", "Reserved2", "KernelGroupStride", "KernelOCGStride",
    "CoeffDMAConfig0", "CoeffDMAConfig1", "CoeffDMAConfig2", "CoeffDMAConfig3",
    "CoeffDMAConfig4", "CoeffDMAConfig5", "CoeffDMAConfig6", "CoeffDMAConfig7",
    "CoeffDMAConfig8", "CoeffDMAConfig9", "CoeffDMAConfig10", "CoeffDMAConfig11",
    "CoeffDMAConfig12", "CoeffDMAConfig13", "CoeffDMAConfig14", "CoeffDMAConfig15",
    "CoeffBaseAddr0", "CoeffBaseAddr1", "CoeffBaseAddr2", "CoeffBaseAddr3",
    "CoeffBaseAddr4", "CoeffBaseAddr5", "CoeffBaseAddr6", "CoeffBaseAddr7",
    "CoeffBaseAddr8", "CoeffBaseAddr9", "CoeffBaseAddr10", "CoeffBaseAddr11",
    "CoeffBaseAddr12", "CoeffBaseAddr13", "CoeffBaseAddr14", "CoeffBaseAddr15",
    "CoeffBfrSize0", "CoeffBfrSize1", "CoeffBfrSize2", "CoeffBfrSize3",
    "CoeffBfrSize4", "CoeffBfrSize5", "CoeffBfrSize6", "CoeffBfrSize7",
    "CoeffBfrSize8", "CoeffBfrSize9", "CoeffBfrSize10", "CoeffBfrSize11",
    "CoeffBfrSize12", "CoeffBfrSize13", "CoeffBfrSize14", "CoeffBfrSize15",
    "BiasDMAConfig", "BiasBaseAddr", "BiasReserved0", "BiasReserved1",
    "PostScaleDMAConfig", "PostScaleBaseAddr", "PostScaleReserved0", "PostScaleReserved1",
    "SparseBlockSizeCfg", "Reserved3", "Reserved4", "Reserved5",
    "Reserved6", "Reserved7"
]

h16_common_names = [
    "ChannelCfg", "InWidth", "InHeight", "InChannels", "InDepth",
    "OutWidth", "OutHeight", "OutChannels", "OutDepth", "NumGroups",
    "ConvCfg", "ConvCfg3d", "UnicastCfg", "TileHeight", "TileOverlap",
    "MacCfg", "NECfg", "PatchCfg", "PECfg", "NID",
    "DPE", "DPE0", "DPE1"
]
h16_l2_names = [
    "L2_Control", "L2_Src1Cfg", "L2_Src2Cfg",
    "L2_SrcIdxCfg", "L2_Src1Base", "L2_Src1CStride",
    "L2_Src1RStride", "L2_Src1DStride", "L2_Src1GStride",
    "L2_Src2Base", "L2_Src2CStride", "L2_Src2RStride",
    "L2_Src2DStride", "L2_Src2GStride", "L2_SrcIdxBase",
    "L2_SrcIdxCStride", "L2_SrcIdxDStride", "L2_SrcIdxGStride",
    "L2_ResultCfg", "L2_ResultBase", "L2_ResultCStride",
    "L2_ResultRStride", "L2_ResultDStride", "L2_ResultGStride",
    "L2_Res24", "L2_ResultWrapCfg", "L2_Res26",
    "L2_Res27", "L2_Res28", "L2_ResultWrapIdxOff",
    "L2_Res30", "L2_Result2Base", "L2_Result2CStride",
    "L2_Result2RStride", "L2_Result2DStride", "PEIndexCfg",
    "L2_Res36", "L2_Res37", "L2_Res38",
    "L2_ResultWrapAddr", "L2_CropTex"
]
h17_l2_names = [
    "L2_Control", "L2_Src1Cfg", "L2_Src2Cfg",
    "L2_SrcIdxCfg", "L2_Src1Base", "L2_Src1CStride",
    "L2_Src1RStride", "L2_Src1DStride", "L2_Src1GStride",
    "L2_Src2Base", "L2_Src2CStride", "L2_Src2RStride",
    "L2_Src2DStride", "L2_Src2GStride", "L2_SrcIdxBase",
    "L2_SrcIdxCStride", "L2_SrcIdxDStride", "L2_SrcIdxGStride",
    "L2_ResultCfg", "L2_ResultBase", "L2_ResultCStride",
    "L2_ResultRStride", "L2_ResultDStride", "L2_ResultGStride",
    "L2_Res24", "L2_ResultWrapCfg", "L2_Res26",
    "L2_Res27", "L2_Res28", "L2_ResultWrapIdxOff",
    "L2_Res30", "L2_Result2Base", "L2_Result2CStride",
    "L2_Result2RStride", "L2_Result2DStride", "L2_Result2GStride",
    "L2_Res36", "L2_Res37", "L2_Res38",
    "L2_ResultWrapAddr", "L2_CropTex", "L2_Res41"
]
h18_l2_names = [
    "L2_Control", "L2_Src1Cfg", "L2_Src2Cfg",
    "L2_SrcIdxCfg", "L2_Src1Base", "L2_Src1CStride",
    "L2_Src1RStride", "L2_Src1DStride", "L2_Src1GStride",
    "L2_Src2Base", "L2_Src2CStride", "L2_Src2RStride",
    "L2_Src2DStride", "L2_Src2GStride", "L2_SrcIdxBase",
    "L2_SrcIdxCStride", "L2_SrcIdxDStride", "L2_SrcIdxGStride",
    "L2_ResultCfg", "L2_ResultBase", "L2_ResultCStride",
    "L2_ResultRStride", "L2_ResultDStride", "L2_ResultGStride",
    "L2_Res24", "L2_ResultWrapCfg", "L2_Res26",
    "L2_Res27", "L2_Res28", "L2_ResultWrapIdxOff",
    "L2_Res30", "L2_Result2Base", "L2_Result2CStride",
    "L2_Result2RStride", "L2_Result2DStride", "L2_Result2GStride",
    "L2_Res36", "L2_Res37", "L2_Res38",
    "L2_ResultWrapAddr", "L2_Res40", "L2_Res41",
    "L2_Res42"
]

h16_pe_names = [
    "PE_Config", "PE_Bias", "PE_Scale", "PE_FinalScaleEpsilon",
    "PE_PreScale", "PE_FinalScale", "PE_LUT1", "PE_LUT2",
    "PE_LUT3", "PE_LUT4", "PE_LUT5", "PE_LUT6",
    "PE_LUT7", "PE_LUT8", "PE_Quant"
]
h17_pe_names = [
    "PE_Config", "PE_Bias", "PE_Scale", "PE_FinalScaleEpsilon",
    "PE_PreScale", "PE_FinalScale", "PE_LUT1", "PE_LUT2",
    "PE_LUT3", "PE_LUT4", "PE_LUT5", "PE_LUT6",
    "PE_LUT7", "PE_LUT8", "PE_Quant", "PE_Res15"
]

h16_ne_names = [
    "KernelCfg", "MacCfg", "MatrixVectorBias", "NEBias",
    "PostScale", "RcasConfig", "RoundModeCfg", "SRSeed[0]",
    "SRSeed[1]", "SRSeed[2]", "SRSeed[3]", "QuantZeroPoint"
]
h17_ne_names = [
    "KernelCfg", "MacCfg", "MatrixVectorBias", "NEBias",
    "PostScale", "RcasConfig", "RoundModeCfg", "SRSeed[0]",
    "SRSeed[1]", "SRSeed[2]", "SRSeed[3]", "QuantZeroPoint",
    "NE_Res12"
]

h16_cdma_names = [
    "CacheDMAControl", "CacheDMAPre0", "CacheDMAPre1",
    "CacheDMAPad3", "CacheDMAPad4", "CacheDMAPad5",
    "CacheDMADsid", "CacheDMAFootprint", "EarlyTermArg12",
    "CacheDMAFlushArg", "EarlyTermArg34", "TelemetryBackOff"
]
h17_cdma_names = [
    "CacheDMAControl", "CacheDMAPre0", "CacheDMAPre1",
    "CacheDMAPad3", "CacheDMAPad4", "CacheDMAPad5",
    "CacheDMADsid", "CacheDMAFootprint", "EarlyTermArg12",
    "CacheDMAFlushArg", "EarlyTermArg34", "TelemetryBackOff",
    "CDMA_Res12", "CDMA_Res13"
]
h16_pe_index_names = ["PE_IndexCfg"]

h16_tdma_src_names = [
    "Src1DMAConfig", "Src2DMAConfig", "Src1WrapCfg", "Src2WrapCfg",
    "Src1BaseAddrLo", "Src1BaseAddrHi", "Src1RowStride", "Src1PlaneStride",
    "Src2BaseAddrLo", "Src1GroupStride", "Src2BaseAddrHi", "Src2RowStride",
    "Src2PlaneStride", "Src2GroupStride", "pad_38", "pad_3C",
    "Src1MetaDataConfig", "pad_44", "pad_48", "pad_4C",
    "Src1MetaDataAddrLo", "Src1MetaDataAddrHi", "Src1MetaDataSize", "Src2MetaDataConfig",
    "Src2MetaDataAddrLo", "Src2MetaDataAddrHi", "Src1Fmt", "Src2FmtMode",
    "Reserved_0x4D70", "Reserved_0x4D74", "Src1CompressedInfo", "Src1CompressedSizeLo",
    "Src1CompressedSizeHi", "Src1CropOffset", "Src2CompressedInfo", "Src2CompressedSizeLo",
    "Src2CompressedSizeHi", "Src2CropOffset", "Reserved_0x4D98", "Reserved_0x4D9C",
    "Reserved_0x4DA0", "Reserved_0x4DA4", "Reserved_0x4DA8", "Reserved_0x4DAC",
    "Reserved_0x4DB0", "Reserved_0x4DB4", "Src1WrapDynamic", "Src2WrapDynamic",
    "Src1DependencyOffset", "Src2DependencyOffset", "TextureConfig", "TextureIdxPermute",
    "TextureSrcPermute", "TextureBackgroundVal", "TextureExtMaxDim1", "TextureExtMaxDim2",
    "TextureExtMaxDim3", "TextureCropBatchSplitDim1", "TextureCropDepthDim1", "TextureCropBatchSplitDim2",
    "Reserved_0x4DF0", "Reserved_0x4DF4", "Src1Ephemeral", "Reserved_0x4DFC",
    "Reserved_0x4E00", "TextureCropCoeffVal", "pad_66", "pad_67",
    "pad_68", "pad_69", "pad_70", "pad_71",
    "pad_72", "pad_73", "pad_74", "pad_75",
    "pad_76", "pad_77", "pad_78", "pad_79",
    "pad_80"
]
h17_tdma_src_names = [
    "Src1DMAConfig", "Src2DMAConfig", "Src1WrapCfg", "Src2WrapCfg",
    "Src1BaseAddrLo", "Src1BaseAddrHi", "Src1RowStride", "Src1PlaneStride",
    "Src2BaseAddrLo", "Src1GroupStride", "Src2BaseAddrHi", "Src2RowStride",
    "Src2PlaneStride", "Src2GroupStride", "pad_38", "pad_3C",
    "Src1MetaDataConfig", "pad_44", "pad_48", "pad_4C",
    "Src1MetaDataAddrLo", "Src1MetaDataAddrHi", "Src1MetaDataSize", "Src2MetaDataConfig",
    "Src2MetaDataAddrLo", "Src2MetaDataAddrHi", "Src1FmtMode", "Src2FmtMode",
    "Res_70", "Res_74", "Src1CompressedInfo", "Src1CompressedSizeLo",
    "Src1CompressedSizeHi", "Src1CropOffset", "Src2CompressedInfo", "Src2CompressedSizeLo",
    "Src2CompressedSizeHi", "Src2CropOffset", "Res_98", "Res_9C",
    "Res_A0", "Res_A4", "Res_A8", "Res_AC",
    "Res_B0", "Res_B4", "Src1WrapDynamic", "Src2WrapDynamic",
    "Src1DependencyOffset", "Src2DependencyOffset", "TextureConfig", "TextureIdxPermute",
    "TextureSrcPermute", "TextureBackgroundVal", "TextureExtMaxDim1", "TextureExtMaxDim2",
    "TextureExtMaxDim3", "TextureCropBatchSplitDim1", "TextureCropDepthDim1", "TextureCropBatchSplitDim2",
    "Res_F0", "Res_F4", "Res_F8", "Res_FC",
    "Res_100", "TextureCropCoeffVal", "Res_108", "Res_10C",
    "Res_110", "Res_114", "Res_118", "Res_11C",
    "Res_120", "Res_124", "Res_128", "Res_12C",
    "Res_130", "Res_134", "Res_138", "Res_13C",
    "Res_140", "TS_Res81", "TS_Res82"
]

h16_tdma_dst_names = [
    "DstDMAConfig", "pad0", "DstBaseAddrLo", "DstBaseAddrHi",
    "DstRowStride", "DstPlaneStride", "DstDepthStride", "DstGroupStride",
    "DstInternalCfg", "pad1", "DstMetaDataAddrLo", "DstMetaDataAddrHi",
    "DstFmtMode", "pad2", "DstFmt", "pad3",
    "DstCompressedInfo", "pad4", "DstCompSizeLo", "DstCompSizeHi",
    "DstPixelOffset"
]
h17_tdma_dst_names = [
    "DstDMAConfig", "pad0", "DstBaseAddrLo", "DstBaseAddrHi",
    "DstRowStride", "DstPlaneStride", "DstDepthStride", "DstGroupStride",
    "DstInternalCfg", "pad1", "DstMetaDataAddrLo", "DstMetaDataAddrHi",
    "DstFmtMode", "pad2", "DstFmtCtrl", "pad3",
    "DstCompressedInfo", "pad4", "DstCompSizeLo", "DstCompSizeHi",
    "DstPixelOffset", "TD_Res21", "TD_Res22"
]
h18_tdma_dst_names = [
    "DstDMAConfig", "pad0", "DstBaseAddrLo", "DstBaseAddrHi",
    "DstRowStride", "DstPlaneStride", "DstDepthStride", "DstGroupStride",
    "DstInternalCfg", "pad1", "DstMetaDataAddrLo", "DstMetaDataAddrHi",
    "DstFmtMode", "pad2", "DstFmtCtrl", "pad3",
    "DstCompressedInfo", "pad4", "DstCompSizeLo", "DstCompSizeHi",
    "DstPixelOffset", "TD_Res21", "TD_Res22", "TD_Res23",
    "TD_Res24", "TD_Res25", "TD_Res26"
]

h16_kdma_names = [
    "MasterCfg", "AlignedCoeffSize", "Prefetch", "Reserved[0]",
    "Reserved[1]", "Reserved[2]", "KernelGroupStride", "KernelOCGStride",
    "CoeffDMAConfig[0]", "CoeffDMAConfig[1]", "CoeffDMAConfig[2]", "CoeffDMAConfig[3]",
    "CoeffDMAConfig[4]", "CoeffDMAConfig[5]", "CoeffDMAConfig[6]", "CoeffDMAConfig[7]",
    "CoeffDMAConfig[8]", "CoeffDMAConfig[9]", "CoeffDMAConfig[10]", "CoeffDMAConfig[11]",
    "CoeffDMAConfig[12]", "CoeffDMAConfig[13]", "CoeffDMAConfig[14]", "CoeffDMAConfig[15]",
    "CoeffBaseAddr[0]", "CoeffBaseAddr[1]", "CoeffBaseAddr[2]", "CoeffBaseAddr[3]",
    "CoeffBaseAddr[4]", "CoeffBaseAddr[5]", "CoeffBaseAddr[6]", "CoeffBaseAddr[7]",
    "CoeffBaseAddr[8]", "CoeffBaseAddr[9]", "CoeffBaseAddr[10]", "CoeffBaseAddr[11]",
    "CoeffBaseAddr[12]", "CoeffBaseAddr[13]", "CoeffBaseAddr[14]", "CoeffBaseAddr[15]",
    "CoeffBfrSize[0]", "CoeffBfrSize[1]", "CoeffBfrSize[2]", "CoeffBfrSize[3]",
    "CoeffBfrSize[4]", "CoeffBfrSize[5]", "CoeffBfrSize[6]", "CoeffBfrSize[7]",
    "CoeffBfrSize[8]", "CoeffBfrSize[9]", "CoeffBfrSize[10]", "CoeffBfrSize[11]",
    "CoeffBfrSize[12]", "CoeffBfrSize[13]", "CoeffBfrSize[14]", "CoeffBfrSize[15]",
    "BiasCfg", "pad_57", "pad_58", "pad_59",
    "PSScaleCfg", "pad_61", "pad_62", "pad_63",
    "PalCfg", "pad_65", "pad_66", "pad_67",
    "NLutCfg", "pad_69", "pad_70", "pad_71"
]
h17_kdma_names = [
    "MasterCfg", "AlignedCoeffSize", "Prefetch", "Res_0",
    "Res_1", "Res_2", "KernelGroupStride", "KernelOCGStride",
    "CoeffDMAConfig[0]", "CoeffDMAConfig[1]", "CoeffDMAConfig[2]", "CoeffDMAConfig[3]",
    "CoeffDMAConfig[4]", "CoeffDMAConfig[5]", "CoeffDMAConfig[6]", "CoeffDMAConfig[7]",
    "CoeffDMAConfig[8]", "CoeffDMAConfig[9]", "CoeffDMAConfig[10]", "CoeffDMAConfig[11]",
    "CoeffDMAConfig[12]", "CoeffDMAConfig[13]", "CoeffDMAConfig[14]", "CoeffDMAConfig[15]",
    "CoeffBaseAddr[0]", "CoeffBaseAddr[1]", "CoeffBaseAddr[2]", "CoeffBaseAddr[3]",
    "CoeffBaseAddr[4]", "CoeffBaseAddr[5]", "CoeffBaseAddr[6]", "CoeffBaseAddr[7]",
    "CoeffBaseAddr[8]", "CoeffBaseAddr[9]", "CoeffBaseAddr[10]", "CoeffBaseAddr[11]",
    "CoeffBaseAddr[12]", "CoeffBaseAddr[13]", "CoeffBaseAddr[14]", "CoeffBaseAddr[15]",
    "CoeffBfrSize[0]", "CoeffBfrSize[1]", "CoeffBfrSize[2]", "CoeffBfrSize[3]",
    "CoeffBfrSize[4]", "CoeffBfrSize[5]", "CoeffBfrSize[6]", "CoeffBfrSize[7]",
    "CoeffBfrSize[8]", "CoeffBfrSize[9]", "CoeffBfrSize[10]", "CoeffBfrSize[11]",
    "CoeffBfrSize[12]", "CoeffBfrSize[13]", "CoeffBfrSize[14]", "CoeffBfrSize[15]",
    "BiasDMAConfig", "BiasBaseAddr", "Res_Bias0", "Res_Bias1",
    "PostScaleDMAConfig", "PostScaleBaseAddr", "Res_PS0", "Res_PS1",
    "PaletteDMAConfig", "PaletteBaseAddr", "Res_Pal0", "Res_Pal1",
    "NLutDMAConfig", "NLutBaseAddr", "Res_NL0", "Res_NL1",
    "KDMA_Res72", "KDMA_Res73"
]
h18_kdma_names = [
    "MasterCfg", "AlignedCoeffSize", "Prefetch", "Res_0",
    "Res_1", "Res_2", "KernelGroupStride", "KernelOCGStride",
    "CoeffDMAConfig[0]", "CoeffDMAConfig[1]", "CoeffDMAConfig[2]", "CoeffDMAConfig[3]",
    "CoeffDMAConfig[4]", "CoeffDMAConfig[5]", "CoeffDMAConfig[6]", "CoeffDMAConfig[7]",
    "CoeffDMAConfig[8]", "CoeffDMAConfig[9]", "CoeffDMAConfig[10]", "CoeffDMAConfig[11]",
    "CoeffDMAConfig[12]", "CoeffDMAConfig[13]", "CoeffDMAConfig[14]", "CoeffDMAConfig[15]",
    "CoeffBaseAddr[0]", "CoeffBaseAddr[1]", "CoeffBaseAddr[2]", "CoeffBaseAddr[3]",
    "CoeffBaseAddr[4]", "CoeffBaseAddr[5]", "CoeffBaseAddr[6]", "CoeffBaseAddr[7]",
    "CoeffBaseAddr[8]", "CoeffBaseAddr[9]", "CoeffBaseAddr[10]", "CoeffBaseAddr[11]",
    "CoeffBaseAddr[12]", "CoeffBaseAddr[13]", "CoeffBaseAddr[14]", "CoeffBaseAddr[15]",
    "CoeffBfrSize[0]", "CoeffBfrSize[1]", "CoeffBfrSize[2]", "CoeffBfrSize[3]",
    "CoeffBfrSize[4]", "CoeffBfrSize[5]", "CoeffBfrSize[6]", "CoeffBfrSize[7]",
    "CoeffBfrSize[8]", "CoeffBfrSize[9]", "CoeffBfrSize[10]", "CoeffBfrSize[11]",
    "CoeffBfrSize[12]", "CoeffBfrSize[13]", "CoeffBfrSize[14]", "CoeffBfrSize[15]",
    "BiasDMAConfig", "BiasBaseAddr", "Res_Bias0", "Res_Bias1",
    "PostScaleDMAConfig", "PostScaleBaseAddr", "Res_PS0", "Res_PS1",
    "PaletteDMAConfig", "PaletteBaseAddr", "Res_Pal0", "Res_Pal1",
    "NLutDMAConfig", "NLutBaseAddr", "Res_NL0", "Res_NL1",
    "KDMA_Res72", "KDMA_Res73", "KDMA_Res74", "KDMA_Res75",
    "KDMA_Res76", "KDMA_Res77", "KDMA_Res78", "KDMA_Res79",
    "KDMA_Res80", "KDMA_Res81", "KDMA_Res82"
]

m1_ranges = [
    (H13_COMMON_START, 16, h13_common_names),
    (H13_L2_START, 16, h13_l2_names),
    (H13_PE_START, 4, h13_pe_names),
    (H13_NE_START, 5, h13_ne_names),
    (H13_TILEDMA_SRC_START, 24, h13_tdma_src_names),
    (H13_TILEDMA_DST_START, 7, h13_tdma_dst_names),
    (H13_KERNELDMA_START, 5, h13_kdma_names),
]
h14_ranges = [
    (H14_COMMON_START, H14_COMMON_COUNT, h14_common_names),
    (H14_L2_START, H14_L2_COUNT, h14_l2_names),
    (H14_PE_START, H14_PE_COUNT, h14_pe_names),
    (H14_NE_START, H14_NE_COUNT, h14_ne_names),
    (H14_TILEDMA_SRC_START, H14_TILEDMA_SRC_COUNT, h14_tdma_src_names),
    (H14_TILEDMA_DST_START, H14_TILEDMA_DST_COUNT, h14_tdma_dst_names),
    (H14_KERNELDMA_START, H14_KERNELDMA_COUNT, h14_kdma_names),
]
h15_ranges = [
    (H16_COMMON_START, 19, h14_common_names),
    (H16_L2_START, 25, h14_l2_names),
    (H16_PE_START, 5, h14_pe_names),
    (H16_NE_START, 5, h14_ne_names),
    (H16_TILEDMA_SRC_START, 53, h14_tdma_src_names),
    (H16_TILEDMA_DST_START, 9, h14_tdma_dst_names),
    (H16_KERNELDMA_START, 70, h14_kdma_names),
    (H16_CACHEDMA_START, 12, h16_cdma_names),
]
m4_ranges = [
    (H16_COMMON_START, 23, h16_common_names),
    (H16_L2_START, 41, h16_l2_names),
    (H16_PE_EXT_START, 1, h16_pe_index_names),
    (H16_PE_START, 15, h16_pe_names),
    (H16_NE_START, 12, h16_ne_names),
    (H16_CACHEDMA_START, 12, h16_cdma_names),
    (H16_TILEDMA_SRC_START, 81, h16_tdma_src_names),
    (H16_TILEDMA_DST_START, 21, h16_tdma_dst_names),
    (H16_KERNELDMA_START, 72, h16_kdma_names),
]
h17_ranges = [
    (H16_COMMON_START, H17_COMMON_COUNT, h16_common_names),
    (H16_L2_START, H17_L2_COUNT, h17_l2_names),
    (H16_PE_START, H17_PE_COUNT, h17_pe_names),
    (H16_NE_START, H17_NE_COUNT, h17_ne_names),
    (H16_TILEDMA_SRC_START, H17_TILEDMA_SRC_COUNT, h17_tdma_src_names),
    (H16_TILEDMA_DST_START, H17_TILEDMA_DST_COUNT, h17_tdma_dst_names),
    (H16_KERNELDMA_START, H17_KERNELDMA_COUNT, h17_kdma_names),
    (H16_CACHEDMA_START, H17_CACHEDMA_COUNT, h17_cdma_names),
]
h18_ranges = [
    (H16_COMMON_START, H18_COMMON_COUNT, h16_common_names),
    (H16_L2_START, H18_L2_COUNT, h18_l2_names),
    (H16_PE_START, H18_PE_COUNT, h17_pe_names),
    (H16_NE_START, H18_NE_COUNT, h17_ne_names),
    (H16_TILEDMA_SRC_START, H18_TILEDMA_SRC_COUNT, h16_tdma_src_names),
    (H16_TILEDMA_DST_START, H18_TILEDMA_DST_COUNT, h18_tdma_dst_names),
    (H16_KERNELDMA_START, H18_KERNELDMA_COUNT, h18_kdma_names),
    (H16_CACHEDMA_START, H18_CACHEDMA_COUNT, h17_cdma_names),
]

class HwxState:
    def __init__(self, subtype, instr_ver):
        self.values = [0] * HW_MAX_REGS
        self.valid = [False] * HW_MAX_REGS
        self.first_values = [0] * HW_MAX_REGS
        self.first_written = [False] * HW_MAX_REGS
        self.subtype = subtype
        self.instr_ver = instr_ver

def get_arch_name(subtype):
    return {
        1: "H11 (A12)",
        3: "H12 (A13)",
        4: "H13 (A14/M1)",
        5: "H14 (A15/M2)",
        6: "H15 (A16/M3)",
        7: "H16 (A17 Pro/M4)",
        9: "H17 (A18 Pro/M5)",
        10: "H18 (A19)",
    }.get(subtype, "Unknown Architecture")

def get_instruction_set_version(subtype):
    return {
        1: 5,
        3: 6,
        4: 7,
        5: 11,
        6: 8,
        7: 17,
        9: 19,
        10: 20,
    }.get(subtype, 0)

def get_ch_fmt_name(fmt_val):
    if fmt_val == 0: return "INT8"
    if fmt_val == 1: return "UINT8"
    if fmt_val == 2: return "FLOAT16"
    return "Unknown"

def get_l2_dma_fmt_name(fmt_val):
    if fmt_val == 0: return "8b"
    if fmt_val == 1: return "16b"
    if fmt_val == 3: return "32b"
    return "??"

def get_pe_op_mode_name_v17(op):
    return {0: "Add", 1: "Mul", 2: "Max", 3: "Min", 4: "SumSqr"}.get(op, "Unknown")

def get_pe_pool_mode_name_v17(mode):
    return {0: "None", 1: "Avg", 2: "Max", 3: "Min"}.get(mode, "Unknown")

def get_pe_condition_name_v17(cond):
    labels = ["None", "Abs", "Equal", "Greater", "GreaterEqual", "LessEqual", "Less", "NotEqual"]
    return labels[cond] if cond < len(labels) else "Unknown"

def get_pe_nl_mode_name_v17(mode):
    labels = ["None", "ReLU", "Clamp", "Abs"]
    return labels[mode] if mode < len(labels) else "Unknown"

def get_pe_src1_name_v17(sel):
    return "PrimarySource" if sel == 0 else "TextureSource" if sel == 1 else "Unknown"

def get_pe_src2_name_v17(sel):
    labels = ["PrimarySource", "TextureSource", "L2Source", "RegSource"]
    return labels[sel] if sel < len(labels) else "Unknown"

def get_ne_op_mode_name(mode):
    return {
        0: "Conv",
        1: "ElemWise",
        2: "RCAS",
        3: "EWSqrt",
        4: "Bypass",
        5: "TransposedConv",
    }.get(mode, "Unknown")

def get_task_type_mapping(subtype):
    return {0: 0, 1: 2, 2: 6, 3: 5, 4: 7, 5: 4, 6: 3, 7: 0, 8: 1}.get(subtype, 0)

def get_hw_task_type_name(type_val):
    return {
        1: "Pooling w/o input ReLU",
        2: "Pooling w/ input ReLU",
        3: "EW w/ Reduction w/o ReLU",
        4: "EW w/ Reduction w/ ReLU",
        5: "EW w/o Reduction w/o ReLU",
        6: "EW w/o Reduction w/ ReLU",
        7: "GOC",
    }.get(type_val, "Unknown")

def get_texture_mode_name(mode):
    return {0: "Off", 1: "Gather", 2: "Bilinear", 3: "Bicubic", 4: "Nearest"}.get(mode, "Unknown")

def get_hw_tensor_format_mode_name(mode):
    return {0: "None", 1: "Cmp", 2: "Lossy"}.get(mode, "Unknown")

def get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift):
    if mode == 3 and mem_fmt == 3 and shift == 1:
        return "FLOAT32"
    if mode == 1 and mem_fmt == 2 and trunc == 3:
        return "FLOAT16"
    if mode == 0 and mem_fmt == 1:
        return "INT8"
    if mode == 0 and mem_fmt == 0 and shift == 0 and trunc == 0:
        return "UINT8"
    if mode == 1 and mem_fmt == 2 and trunc == 1 and shift == 0:
        return "RAW12"
    if mode == 1 and mem_fmt == 0 and trunc == 1 and shift == 1:
        return "Y12"
    if mode == 2 and mem_fmt == 3:
        return "INT16"
    if mode == 2 and mem_fmt == 0 and shift == 1:
        return "Packed10 (Deprecated?)"
    if mode == 1 and trunc == 3 and shift == 1:
        if mem_fmt == 0: return "RAW10"
        if mem_fmt == 1: return "Y10"
        if mem_fmt == 2: return "RAW10/Y10 (Shared)"
    return "UNKNOWN"

def fp16_to_fp32(val_u16):
    return struct.unpack('<e', struct.pack('<H', val_u16))[0]

def print_float_reg(name, val):
    if val & 0xFFF80000:
        val_f = struct.unpack('f', struct.pack('<I', val))[0]
        print(f"        {name:<23}: 0x{val:08x} ({val_f:.6f})")
    else:
        bits = (val & 0x7FFFF) << 13
        val_f = struct.unpack('f', struct.pack('<I', bits))[0]
        print(f"        {name:<23}: 0x{val & 0x7FFFF:05x} ({val_f:.6f})")

def lookup_reg_name(addr, ranges):
    for start, count, names in ranges:
        if start <= addr < start + count * 4:
            idx = (addr - start) // 4
            if idx < len(names):
                return names[idx]
    return None

def get_reg_name(addr, subtype):
    if subtype in (1, 3, 4):
        return lookup_reg_name(addr, m1_ranges)
    elif subtype == 5:
        return lookup_reg_name(addr, h14_ranges)
    elif subtype == 6:
        return lookup_reg_name(addr, h15_ranges)
    elif subtype == 7:
        return lookup_reg_name(addr, m4_ranges)
    elif subtype == 9:
        return lookup_reg_name(addr, h17_ranges)
    elif subtype == 10:
        return lookup_reg_name(addr, h18_ranges)
    return None

def dump_hw_blocks(state, blocks, name_lookup):
    print("        --- HW Block Register State ---")
    for name, start_addr, count in blocks:
        printed_header = False
        word_start = start_addr // 4
        word_end = word_start + count
        for r in range(word_start, word_end):
            if state.valid[r]:
                if not printed_header:
                    print(f"        {name}:")
                    printed_header = True
                addr = r * 4
                reg_name = name_lookup(addr)
                if reg_name:
                    print(f"          0x{addr:05x}: 0x{state.values[r]:08x} ({reg_name})")
                else:
                    print(f"          0x{addr:05x}: 0x{state.values[r]:08x}")

# older H13 style decoders
def print_common_h13(state):
    print("        --- Common (0x0000) ---")
    base = H13_COMMON_START // 4
    win, hin, cin, wout, hout, cout = 0, 0, 0, 0, 0, 0
    infmt_name, outfmt_name = "Unknown", "Unknown"
    
    # InDim (w_in: bit 0..14, h_in: bit 16..30)
    if state.valid[base]:
        v = state.values[base]
        win, hin = v & 0x7FFF, (v >> 16) & 0x7FFF
    # ChCfg (infmt: bit 0..1, outfmt: bit 4..5)
    if state.valid[base + 2]:
        v = state.values[base + 2]
        infmt_name = get_ch_fmt_name(v & 3)
        outfmt_name = get_ch_fmt_name((v >> 4) & 3)
    # Cin
    if state.valid[base + 3]:
        cin = state.values[base + 3]
    # Cout
    if state.valid[base + 4]:
        cout = state.values[base + 4]
    # OutDim (w_out: bit 0..14, h_out: bit 16..30)
    if state.valid[base + 5]:
        v = state.values[base + 5]
        wout, hout = v & 0x7FFF, (v >> 16) & 0x7FFF
        
    print(f"        {win} x {hin} x {cin} ({infmt_name}) -> {wout} x {hout} x {cout} ({outfmt_name})")
    
    # ConvCfg
    if state.valid[base + 7]:
        c = state.values[base + 7]
        kw, kh = c & 0x1f, (c >> 5) & 0x1f
        sx, sy = (c >> 13) & 3, (c >> 15) & 3
        px, py = (c >> 17) & 0x1f, (c >> 22) & 0x1f
        if kw != 0 or kh != 0:
            print(f"        ConvCfg: K={kw}x{kh} S={sx}x{sy} P={px}x{py}")
            # GroupConvCfg
            if state.valid[base + 9]:
                g = state.values[base + 9]
                print(f"        GroupConvCfg: Groups={g & 0x1fff} UnicastEn={(g >> 14) & 1} ElemMult={(g >> 15) & 1} UnicastCin={(g >> 16) & 0xffff}")
                
    # Cfg
    if state.valid[base + 13]:
        c = state.values[base + 13]
        active_ne = (c >> 19) & 7
        small_src = (c >> 2) & 1
        sh_pref = (c >> 8) & 7
        sh_min = (c >> 12) & 7
        sh_max = (c >> 16) & 7
        acc_db = (c >> 26) & 1
        print(f"        Cfg: ActiveNE={active_ne} SmallSrc={small_src} ShPref={sh_pref} ShMin={sh_min} ShMax={sh_max} AccDB={acc_db}")
        
    # TaskInfo
    if state.valid[base + 14]:
        t = state.values[base + 14]
        print(f"        TaskInfo: TID=0x{t & 0xffff:04x} Q={(t >> 16) & 0xf} NID=0x{(t >> 20) & 0xff:02x}")

def print_l2_h13(state):
    print("        --- L2 (0x4800) ---")
    base = H13_L2_START // 4
    if state.valid[base]:
        c = state.values[base]
        print(f"        L2Cfg: InputReLU={c&1} PaddingMode={(c>>1)&3}")
    if state.valid[base + 1]:
        s = state.values[base + 1]
        print(f"        L2 SourceCfg: Type={s&3} Dep={(s>>2)&3} DMAFmt={get_l2_dma_fmt_name((s>>6)&3)} Intrlv={(s>>8)&0xf} CmpV={(s>>12)&0xf} OffCh={(s>>16)&7}")
    if state.valid[base + 2]:
        print(f"        L2 Src1: Base=0x{state.values[base+2]&0x1ffff:05x} ChanStride=0x{state.values[base+3]&0x1ffff:05x} RowStride=0x{state.values[base+4]&0x1ffff:05x}")
    if state.valid[base + 12]:
        r = state.values[base + 12]
        print(f"        L2 ResultCfg: Type={r&3} Bfr={(r>>2)&3} DMAFmt={get_l2_dma_fmt_name((r>>6)&3)} Intrlv={(r>>8)&0xf} CmpV={(r>>12)&0xf} OffCh={(r>>16)&7}")

def print_ne_h13(state):
    print("        --- Neural Engine (0xC800) ---")
    base = H13_NE_START // 4
    if state.valid[base + 1]:
        m = state.values[base + 1]
        print(f"        NE MacCfg: OpMode={m&0xf} NLMode={(m>>16)&3} KernelMode={(m>>4)&1} BiasMode={(m>>5)&1} BinaryPoint={(m>>9)&0xf}")
    if state.valid[base]:
        k = state.values[base]
        print(f"        NE KernelCfg: Fmt={get_ch_fmt_name(k&3)} PalettizedEn={(k>>2)&1} PalettizeBits={(k>>4)&0xf} SparseFmt={(k>>8)&1} GroupKernelReuse={(k>>10)&1}")
    if state.valid[base + 2]:
        print(f"        NE MatrixVectorBias: 0x{state.values[base+2]&0xffff:04x}")
    if state.valid[base + 3]:
        v = state.values[base + 3]
        print(f"        NE AccBias: 0x{v&0xffff:04x} Shift={(v>>16)&0x1f}")
    if state.valid[base + 4]:
        v = state.values[base + 4]
        print(f"        NE PostScale: 0x{v&0xffff:04x} RightShift={(v>>16)&0x1f}")

def print_pe_h13(state):
    base = H13_PE_START // 4
    if state.valid[base]:
        print("        --- Planar Engine (0x8800) ---")
        c = state.values[base]
        print(f"        PECfg: En={(c>>1)&1} OpMode={(c>>2)&7} ReluEn={(c>>5)&1} Cond={(c>>6)&1} FirstSrc={(c>>16)&1} SecondSrc={(c>>18)&3}")
        if state.valid[base + 1]:
            bs = state.values[base + 1]
            print(f"        PEBiasScale: Bias=0x{bs&0xffff:04x} Scale=0x{(bs>>16)&0xffff:04x}")
        if state.valid[base + 2]:
            print(f"        PEPreScale: 0x{state.values[base+2]&0xffff:04x} PEFinalScale: 0x{state.values[base+3]:08x}")

def print_tiledmasrc_h13(state):
    print("        --- TileDMASrc (0x13800) ---")
    base = H13_TILEDMA_SRC_START // 4
    if state.valid[base]:
        c = state.values[base]
        print(f"        Src1DMAConfig: En={c&1} CacheHint={(c>>4)&0xf} DepMode={(c>>16)&0xf}")
    if state.valid[base + 2]:
        print(f"        Src1Strides: Base=0x{state.values[base+2]&0x3ffffff:05x} Row=0x{state.values[base+3]&0x3ffffff:05x} Plane=0x{state.values[base+4]&0x3ffffff:05x} Depth=0x{state.values[base+5]&0x3ffffff:05x} Group=0x{state.values[base+6]&0x3ffffff:05x}")
    if state.valid[base + 14]:
        f = state.values[base + 14]
        print(f"        Src1Fmt: FmtMode={f&3} Trunc={(f>>4)&3} Shift={(f>>8)&1} MemFmt={(f>>12)&3} OffCh={(f>>16)&7} Intrlv={(f>>24)&0xf} CmpV={(f>>28)&0xf}")

def print_tiledmadst_h13(state):
    print("        --- TileDMADst (0x17800) ---")
    base = H13_TILEDMA_DST_START // 4
    if state.valid[base]:
        c = state.values[base]
        print(f"        DstDMAConfig: En={c&1} CacheHint={(c>>4)&0xf} L2BfrMode={(c>>24)&1} BypassEOW={(c>>25)&1}")
    if state.valid[base + 1]:
        print(f"        DstStrides: Base=0x{state.values[base+1]&0x3ffffff:05x} Row=0x{state.values[base+2]&0x3ffffff:05x} Plane=0x{state.values[base+3]&0x3ffffff:05x} Depth=0x{state.values[base+4]&0x3ffffff:05x} Group=0x{state.values[base+5]&0x3ffffff:05x}")
    if state.valid[base + 6]:
        f = state.values[base + 6]
        print(f"        DstFmt: FmtMode={f&3} Trunc={(f>>4)&3} Shift={(f>>8)&1} MemFmt={(f>>12)&3} OffCh={(f>>16)&7} ZPLast={(f>>19)&1} ZPFirst={(f>>20)&1} Fill={(f>>21)&1} Intrlv={(f>>24)&0xf} CmpV={(f>>28)&0xf}")

def print_kerneldmasrc_h13(state):
    print("        --- KernelDMASrc (0x1F800) ---")
    base = H13_KERNELDMA_START // 4
    for i in range(16):
        if base + i < len(state.valid) and state.valid[base + i]:
            cfg = state.values[base + i]
            en = cfg & 1
            if en:
                cbase = state.values[base + 16 + i]
                csz = state.values[base + 32 + i]
                print(f"        Coeff[{i}]: En=1 CacheHint={(cfg>>4)&0xf} Base=0x{cbase:08x} Size=0x{csz:08x}")

# H14 decoders
def print_common_h14(state):
    print("        --- Common (0x0000) ---")
    base = H14_COMMON_START // 4
    indim  = state.values[base + 0]
    indep  = state.values[base + 1]
    chcfg  = state.values[base + 2]
    inch   = state.values[base + 3]
    outch  = state.values[base + 4]
    outdim = state.values[base + 5]
    outdep = state.values[base + 6]
    conv   = state.values[base + 8]
    mac    = state.values[base + 10]
    
    infmt  = (chcfg >> 0) & 0x3
    outfmt = (chcfg >> 4) & 0x3
    
    inw = indim & 0x7FFF
    inh = (indim >> 16) & 0x7FFF
    inc = inch & 0x1FFFF
    ind = indep & 0x7FFF
    
    outw = outdim & 0x7FFF
    outh = (outdim >> 16) & 0x7FFF
    outc = outch & 0x1FFFF
    outd = outdep & 0x7FFF
    
    print(f"        InDim : W={inw} H={inh} C={inc} D={ind} Type={get_ch_fmt_name(infmt)}")
    print(f"        OutDim: W={outw} H={outh} C={outc} D={outd} Type={get_ch_fmt_name(outfmt)}")
    
    kw = (conv >> 0) & 0x3F
    kh = (conv >> 6) & 0x3F
    sx = (conv >> 13) & 0x3
    sy = (conv >> 15) & 0x3
    pl = (conv >> 17) & 0x1F
    pt = (conv >> 22) & 0x1F
    if kw or kh:
        print(f"        ConvCfg: K={kw}x{kh} S={sx}x{sy} P(left/top)={pl}x{pt}")
        
    task_type = (mac >> 0) & 0xF
    active_ne = (mac >> 4) & 0x7
    small_src = (mac >> 7) & 0x1
    relu_type = (mac >> 8) & 0x7
    print(f"        MacCfg: TaskType={task_type} ActiveNE={active_ne} SmallSrc={small_src} ReluType={relu_type}")

def print_l2_h14(state):
    print("        --- L2 Cache (0x0500) ---")
    base = H14_L2_START // 4
    if not state.valid[base] and not state.valid[base + 1]:
        return
    ctrl = state.values[base + 0]
    scfg1 = state.values[base + 1]
    scfg2 = state.values[base + 2]
    sbase = state.values[base + 3]
    rcfg = state.values[base + 13]
    rbase = state.values[base + 14]
    
    print(f"        L2Ctrl: Src1ReLU={(ctrl>>0)&1} PaddingMode={(ctrl>>2)&3} Src2ReLU={(ctrl>>4)&1}")
    print(f"        Src1Cfg: Type={(scfg1>>0)&3} DMAFmt={get_l2_dma_fmt_name((scfg1>>6)&3)} Intrlv={(scfg1>>8)&0xF} AliasConvSrc={(scfg1>>4)&1}")
    print(f"        Src2Cfg: Type={(scfg2>>0)&3} DMAFmt={get_l2_dma_fmt_name((scfg2>>6)&3)} Intrlv={(scfg2>>8)&0xF}")
    print(f"        Src1Base: 0x{sbase:05x}")
    print(f"        ResultCfg: Type={(rcfg>>0)&3} DMAFmt={get_l2_dma_fmt_name((rcfg>>6)&3)} Intrlv={(rcfg>>8)&0xF}")
    print(f"        ResultBase: 0x{rbase:05x}")

def print_pe_h14(state):
    base = H14_PE_START // 4
    if not state.valid[base]:
        return
    print("        --- Planar Engine (0x0900) ---")
    cfg = state.values[base + 0]
    bias = state.values[base + 1]
    scale = state.values[base + 2]
    pre = state.values[base + 3]
    quant = state.values[base + 4]
    print(f"        PECfg: PoolMode={(cfg>>0)&3} Operation={(cfg>>2)&7} NLMode={(cfg>>12)&3}")
    print(f"        Bias=0x{bias:05x} Scale=0x{scale:05x} PreScale=0x{pre:05x}")
    print(f"        Quant: Src1ZP={(quant>>0)&0xFF} Src2ZP={(quant>>8)&0xFF} OutZP={(quant>>16)&0xFF}")

def print_ne_h14(state):
    print("        --- Neural Engine (0x0D00) ---")
    base = H14_NE_START // 4
    kcfg = state.values[base + 0]
    mcfg = state.values[base + 1]
    bias = state.values[base + 2]
    ps = state.values[base + 3]
    rmode = state.values[base + 4]
    
    print(f"        KernelCfg: Fmt={get_ch_fmt_name((kcfg>>0)&3)} PalEn={(kcfg>>2)&1} SparseEn={(kcfg>>8)&1} Reuse={(kcfg>>10)&1}")
    print(f"        MacCfg: OpMode={get_ne_op_mode_name((mcfg>>0)&7)} KMode={(mcfg>>3)&1} BiasEn={(mcfg>>4)&1} BinPoint={(mcfg>>8)&0x3F} NLMode={(mcfg>>16)&3}")
    if state.valid[base + 2]:
        print(f"        NEBias: 0x{bias:08x}")
    if state.valid[base + 3]:
        print(f"        NEPostScale: 0x{ps:08x}")
    if state.valid[base + 4]:
        print(f"        RoundMode: Mode={(rmode>>0)&3} IntBits={(rmode>>4)&0x1F}")

def print_tiledmasrc_h14(state):
    print("        --- TileDMA Source (0x1100) ---")
    base = H14_TILEDMA_SRC_START // 4
    s1cfg = state.values[base + 0]
    s1base = state.values[base + 4]
    s1row = state.values[base + 5]
    s1ch = state.values[base + 6]
    s1fmt = state.values[base + 14]
    s2cfg = state.values[base + 1]
    s2base = state.values[base + 9]
    s2row = state.values[base + 10]
    s2fmt = state.values[base + 15]
    
    print(f"        Src1: En={(s1cfg>>0)&1} DataSetId={(s1cfg>>8)&0xFF} CacheHint={(s1cfg>>4)&0xF} Base=0x{s1base>>6:06x} Row=0x{s1row>>6:06x} Ch=0x{s1ch>>6:06x}")
    print(f"        Src1Fmt: Mode={(s1fmt>>0)&3} MemFmt={(s1fmt>>12)&3} Intrlv={(s1fmt>>24)&0xF}")
    if state.valid[base + 1]:
        print(f"        Src2: En={(s2cfg>>0)&1} DataSetId={(s2cfg>>8)&0xFF} Base=0x{s2base>>6:06x} Row=0x{s2row>>6:06x}")
        print(f"        Src2Fmt: Mode={(s2fmt>>0)&3} MemFmt={(s2fmt>>12)&3} Intrlv={(s2fmt>>24)&0xF}")

def print_tiledmadst_h14(state):
    print("        --- TileDMA Destination (0x1500) ---")
    base = H14_TILEDMA_DST_START // 4
    cfg = state.values[base + 0]
    base_val = state.values[base + 1]
    row = state.values[base + 2]
    plane = state.values[base + 3]
    depth = state.values[base + 4]
    group = state.values[base + 5]
    fmt = state.values[base + 6]
    pxoff = state.values[base + 7]
    
    print(f"        DstCfg: En={(cfg>>0)&1} DataSetId={(cfg>>8)&0xFF} CacheHint={(cfg>>4)&0xF}")
    print(f"        DstBase: 0x{base_val>>6:06x} RowStride=0x{row>>6:06x} PlaneStride=0x{plane>>6:06x}")
    if depth or group:
        print(f"        DstDepthStride=0x{depth>>6:06x} GroupStride=0x{group>>6:06x}")
    print(f"        DstFmt: Mode={(fmt>>0)&3} MemFmt={(fmt>>12)&3}")
    if pxoff:
        print(f"        DstPixelOffset: 0x{pxoff&0xFFFF:04x}")

def print_kerneldmasrc_h14(state):
    print("        --- KernelDMA Source (0x1900) ---")
    base = H14_KERNELDMA_START // 4
    master = state.values[base + 0]
    kgstr = state.values[base + 6]
    kogstr = state.values[base + 7]
    
    print(f"        MasterCfg: GroupKernelReuse={(master>>4)&1} SparseFmt={(master>>5)&1} MasterEn={(master>>6)&1}")
    if kgstr or kogstr:
        print(f"        KernelStride: GroupStride={kgstr>>6} OCGStride={kogstr>>6}")
        
    for i in range(16):
        ccfg = state.values[base + 8 + i]
        cbase = state.values[base + 24 + i]
        csz = state.values[base + 40 + i]
        if (ccfg >> 0) & 1:
            print(f"        Coeff[{i}]: En=1 DataSetId={(ccfg>>8)&0xFF} CacheHint={(ccfg>>4)&0xF} Base=0x{cbase>>6:08x} Size=0x{csz>>6:08x}")

# H15 decoders
def print_l2_h15(state):
    print("        --- L2 Cache (0x4100) ---")
    base = H16_L2_START // 4
    if not state.valid[base] and not state.valid[base + 1]:
        return
    ctrl = state.values[base + 0]
    scfg1 = state.values[base + 1]
    scfg2 = state.values[base + 2]
    sbase = state.values[base + 3]
    rcfg = state.values[base + 13]
    rbase = state.values[base + 14]
    
    print(f"        L2Ctrl: Src1ReLU={(ctrl>>0)&1} PaddingMode={(ctrl>>2)&3} Src2ReLU={(ctrl>>4)&1}")
    print(f"        Src1Cfg: Type={(scfg1>>0)&3} DMAFmt={get_l2_dma_fmt_name((scfg1>>6)&3)} Intrlv={(scfg1>>8)&0xF} AliasConvSrc={(scfg1>>4)&1}")
    print(f"        Src2Cfg: Type={(scfg2>>0)&3} DMAFmt={get_l2_dma_fmt_name((scfg2>>6)&3)} Intrlv={(scfg2>>8)&0xF}")
    print(f"        Src1Base: 0x{sbase:05x}")
    print(f"        ResultCfg: Type={(rcfg>>0)&3} DMAFmt={get_l2_dma_fmt_name((rcfg>>6)&3)} Intrlv={(rcfg>>8)&0xF}")
    print(f"        ResultBase: 0x{rbase:05x}")

def print_pe_h15(state):
    base = H16_PE_START // 4
    if not state.valid[base]:
        return
    print("        --- Planar Engine (0x4500) ---")
    cfg = state.values[base + 0]
    bias = state.values[base + 1]
    scale = state.values[base + 2]
    pre = state.values[base + 3]
    quant = state.values[base + 4]
    print(f"        PECfg: PoolMode={(cfg>>0)&3} Operation={(cfg>>2)&7} NLMode={(cfg>>12)&3}")
    print(f"        Bias=0x{bias:05x} Scale=0x{scale:05x} PreScale=0x{pre:05x}")
    print(f"        Quant: Src1ZP={(quant>>0)&0xFF} Src2ZP={(quant>>8)&0xFF} OutZP={(quant>>16)&0xFF}")

def print_ne_h15(state):
    print("        --- Neural Engine (0x4900) ---")
    base = H16_NE_START // 4
    kcfg = state.values[base + 0]
    mcfg = state.values[base + 1]
    bias = state.values[base + 2]
    ps = state.values[base + 3]
    rmode = state.values[base + 4]
    
    print(f"        KernelCfg: Fmt={get_ch_fmt_name((kcfg>>0)&3)} PalEn={(kcfg>>2)&1} SparseEn={(kcfg>>8)&1} Reuse={(kcfg>>10)&1}")
    print(f"        MacCfg: OpMode={get_ne_op_mode_name((mcfg>>0)&7)} KMode={(mcfg>>3)&1} BiasEn={(mcfg>>4)&1} BinPoint={(mcfg>>8)&0x3F} NLMode={(mcfg>>16)&3}")
    if state.valid[base + 2]:
        print(f"        NEBias: 0x{bias:08x}")
    if state.valid[base + 3]:
        print(f"        NEPostScale: 0x{ps:08x}")
    if state.valid[base + 4]:
        print(f"        RoundMode: Mode={(rmode>>0)&3} IntBits={(rmode>>4)&0x1F}")

def print_tiledmasrc_h15(state):
    print("        --- TileDMA Source (0x4D00) ---")
    base = H16_TILEDMA_SRC_START // 4
    s1cfg = state.values[base + 0]
    s1base = state.values[base + 4]
    s1row = state.values[base + 5]
    s1ch = state.values[base + 6]
    s1fmt = state.values[base + 14]
    s2cfg = state.values[base + 1]
    s2base = state.values[base + 9]
    s2row = state.values[base + 10]
    s2fmt = state.values[base + 15]
    
    print(f"        Src1: En={(s1cfg>>0)&1} DataSetId={(s1cfg>>8)&0xFF} CacheHint={(s1cfg>>4)&0xF} Base=0x{s1base>>6:06x} Row=0x{s1row>>6:06x} Ch=0x{s1ch>>6:06x}")
    print(f"        Src1Fmt: Mode={(s1fmt>>0)&3} MemFmt={(s1fmt>>12)&3} Intrlv={(s1fmt>>24)&0xF}")
    if state.valid[base + 1]:
        print(f"        Src2: En={(s2cfg>>0)&1} DataSetId={(s2cfg>>8)&0xFF} Base=0x{s2base>>6:06x} Row=0x{s2row>>6:06x}")
        print(f"        Src2Fmt: Mode={(s2fmt>>0)&3} MemFmt={(s2fmt>>12)&3} Intrlv={(s2fmt>>24)&0xF}")

def print_tiledmadst_h15(state):
    print("        --- TileDMA Destination (0x5100) ---")
    base = H16_TILEDMA_DST_START // 4
    cfg = state.values[base + 0]
    base_val = state.values[base + 1]
    row = state.values[base + 2]
    plane = state.values[base + 3]
    depth = state.values[base + 4]
    group = state.values[base + 5]
    fmt = state.values[base + 6]
    pxoff = state.values[base + 7]
    
    print(f"        DstCfg: En={(cfg>>0)&1} DataSetId={(cfg>>8)&0xFF} CacheHint={(cfg>>4)&0xF}")
    print(f"        DstBase: 0x{base_val>>6:06x} RowStride=0x{row>>6:06x} PlaneStride=0x{plane>>6:06x}")
    if depth or group:
        print(f"        DstDepthStride=0x{depth>>6:06x} GroupStride=0x{group>>6:06x}")
    print(f"        DstFmt: Mode={(fmt>>0)&3} MemFmt={(fmt>>12)&3}")
    if pxoff:
        print(f"        DstPixelOffset: 0x{pxoff&0xFFFF:04x}")

def print_kerneldmasrc_h15(state):
    print("        --- KernelDMA Source (0x5500) ---")
    base = H16_KERNELDMA_START // 4
    master = state.values[base + 0]
    kgstr = state.values[base + 6]
    kogstr = state.values[base + 7]
    
    print(f"        MasterCfg: GroupKernelReuse={(master>>4)&1} SparseFmt={(master>>5)&1} MasterEn={(master>>6)&1}")
    if kgstr or kogstr:
        print(f"        KernelStride: GroupStride={kgstr>>6} OCGStride={kogstr>>6}")
        
    for i in range(16):
        ccfg = state.values[base + 8 + i]
        cbase = state.values[base + 24 + i]
        csz = state.values[base + 40 + i]
        if (ccfg >> 0) & 1:
            print(f"        Coeff[{i}]: En=1 DataSetId={(ccfg>>8)&0xFF} CacheHint={(ccfg>>4)&0xF} Base=0x{cbase>>6:08x} Size=0x{csz>>6:08x}")

# H16/H17/H18 decoders
def print_common_h16(state):
    print("        --- Common (0x0000) ---")
    base = H16_COMMON_START // 4
    
    infmt, src2infmt, outfmt = 0, 0, 0
    inw, inh, inc, ind = 0, 0, 0, 0
    outw, outh, outc, outd = 0, 0, 0, 0
    ng = 0
    kw, kh, sx, sy, pl, pt, ox, oy = 0, 0, 0, 0, 0, 0, 0, 0
    k3d, s3d, p3d, o3d = 0, 0, 0, 0
    ucin, ucen = 0, 0
    overlap, overlapt, overlapb = 0, 0, 0
    active_ne, small_src, task_type, out_trans, fill_lower = 0, 0, 0, 0, 0
    ocg, fat, wustack, halfwu, relu_type = 0, 0, 0, 0, 0
    pw, ph = 0, 0
    s1br, s2br, s1t, s2t, ot = 0, 0, 0, 0, 0
    nid, dpe = 0, 0
    
    if state.instr_ver >= 20:
        # H18 layout
        c_ch_cfg = state.values[base]
        infmt = c_ch_cfg & 7
        src2infmt = (c_ch_cfg >> 3) & 7
        outfmt = (c_ch_cfg >> 6) & 7
        inw = state.values[base + 1]
        inh = state.values[base + 2]
        inc = state.values[base + 3]
        ind = state.values[base + 4]
        outw = state.values[base + 5]
        outh = state.values[base + 6]
        outc = state.values[base + 7]
        outd = state.values[base + 8]
        ng = state.values[base + 9]
        conv_cfg = state.values[base + 10]
        kw = conv_cfg & 0x3F
        kh = (conv_cfg >> 6) & 0x3F
        sx = (conv_cfg >> 13) & 3
        sy = (conv_cfg >> 15) & 3
        pl = (conv_cfg >> 17) & 0x1F
        pt = (conv_cfg >> 22) & 0x1F
        ox = (conv_cfg >> 28) & 3
        oy = (conv_cfg >> 30) & 3
        c3 = state.values[base + 11]
        k3d = c3 & 0x1F
        s3d = (c3 >> 6) & 3
        p3d = (c3 >> 8) & 0xF
        o3d = (c3 >> 13) & 3
        u = state.values[base + 12]
        ucin = (u >> 16) & 0xFFFF
        ucen = (u >> 14) & 1
        # tile_height = state.values[base + 13] is printed? No, wait: TileHeight is not printed in print_common_h16 when valid. Let's check:
        # wait! It is printed in C code? No, let's search for TileHeight in `hwx_parsing.m`!
        # Ah, in `hwx_parsing.m` there is NO TileHeight print in the `print_common_h16` function! Wait!
        # Let's verify from hwx_parsing.m lines 705 to 1100: indeed, it prints tile_overlap, patches, pe_cfg, but NOT TileHeight!
        # Oh, in `hwx_parsing.py` it was printing `TileHeight` at line 441. But `hwx_parsing.m` does not print it.
        # Wait, let's check: `state->valid[(H16_COMMON_START + 0x34) / 4]` is tile_overlap.
        # What about `0x38` / 4? `state.values[(H16_COMMON_START + 0x34) / 4]` in H16 is `tile_height`!
        # Let's look at `ane_common_h16_t` definition: `tile_height` is word 13.
        # And word 14 is `tile_overlap`.
        # So `0x34` is `tile_height` (which is word 13), and `0x38` is `tile_overlap` (word 14).
        # In H17/H18: word 13 is `tile_height`, word 14 is `tile_overlap`.
        # Wait, in C: `state->valid[(H16_COMMON_START + 0x34) / 4]` prints `TileOvlp : Ovlp=%u Pad(T/B)=%ux%u`.
        # Wait! `0x34` / 4 is 13. But in `ane_common_h16_t` `tile_overlap` is word 14 (which is `0x38` / 4).
        # Ah! `state->valid[(H16_COMMON_START + 0x34) / 4]` is used in C:
        # `if (state->valid[(H16_COMMON_START + 0x34) / 4]) { printf("        TileOvlp  : Ovlp=%u Pad(T/B)=%ux%u\n", overlap, overlapt, overlapb); }`
        # Wait! Why did they check `0x34` (word 13) instead of `0x38` (word 14)?
        # Because `state->valid[(H16_COMMON_START + 0x34) / 4]` is checked, but the values `overlap`, `overlapt`, `overlapb` are populated from `c.tile_overlap`!
        # Let's follow C's exact checks!
        
        tile_overlap = state.values[base + 14]
        overlap = (tile_overlap >> 16) & 0x1F
        overlapt = (tile_overlap >> 21) & 0x1F
        overlapb = (tile_overlap >> 26) & 0x1F
        m = state.values[base + 15]
        active_ne = (m >> 19) & 7
        small_src = (m >> 2) & 3
        task_type = (m >> 4) & 0xF
        out_trans = (m >> 28) & 1
        fill_lower = (m >> 29) & 1
        ne_cfg = state.values[base + 16]
        ocg = ne_cfg & 7
        fat = (ne_cfg >> 3) & 1
        halfwu = (ne_cfg >> 4) & 3
        patch = state.values[base + 17]
        pw = patch & 0xF
        ph = (patch >> 4) & 0x1F
        pe_cfg = state.values[base + 18]
        s1br = pe_cfg & 1
        s2br = (pe_cfg >> 1) & 1
        s1t = (pe_cfg >> 2) & 1
        s2t = (pe_cfg >> 3) & 1
        ot = (pe_cfg >> 4) & 1
        nid = state.values[base + 19]
        dpe = state.values[base + 20]
        
    elif state.instr_ver >= 19:
        # H17 layout
        c_ch_cfg = state.values[base]
        infmt = c_ch_cfg & 3
        src2infmt = (c_ch_cfg >> 2) & 3
        outfmt = (c_ch_cfg >> 4) & 3
        inw = state.values[base + 1]
        inh = state.values[base + 2]
        inc = state.values[base + 3]
        ind = state.values[base + 4]
        outw = state.values[base + 5]
        outh = state.values[base + 6]
        outc = state.values[base + 7]
        outd = state.values[base + 8]
        ng = state.values[base + 9]
        conv_cfg = state.values[base + 10]
        kw = conv_cfg & 0x3F
        kh = (conv_cfg >> 6) & 0x3F
        sx = (conv_cfg >> 13) & 3
        sy = (conv_cfg >> 15) & 3
        pl = (conv_cfg >> 17) & 0x1F
        pt = (conv_cfg >> 22) & 0x1F
        ox = (conv_cfg >> 28) & 3
        oy = (conv_cfg >> 30) & 3
        c3 = state.values[base + 11]
        k3d = c3 & 0x1F
        s3d = (c3 >> 6) & 3
        p3d = (c3 >> 8) & 0xF
        o3d = (c3 >> 13) & 3
        u = state.values[base + 12]
        ucin = (u >> 16) & 0xFFFF
        ucen = (u >> 14) & 1
        tile_overlap = state.values[base + 14]
        overlap = (tile_overlap >> 16) & 0x1F
        overlapt = (tile_overlap >> 21) & 0x1F
        overlapb = (tile_overlap >> 26) & 0x1F
        m = state.values[base + 15]
        active_ne = (m >> 19) & 7
        small_src = (m >> 2) & 3
        task_type = (m >> 4) & 0xF
        out_trans = (m >> 28) & 1
        fill_lower = (m >> 29) & 1
        ne_cfg = state.values[base + 16]
        ocg = ne_cfg & 7
        fat = (ne_cfg >> 3) & 1
        wustack = (ne_cfg >> 4) & 3
        patch = state.values[base + 17]
        pw = patch & 0xF
        ph = (patch >> 4) & 0x1F
        pe_cfg = state.values[base + 18]
        s1br = pe_cfg & 1
        s2br = (pe_cfg >> 1) & 1
        s1t = (pe_cfg >> 2) & 1
        s2t = (pe_cfg >> 3) & 1
        ot = (pe_cfg >> 4) & 1
        nid = state.values[base + 19]
        dpe = state.values[base + 20]
        
    else:
        # H16 layout - including dimension extraction heuristics
        dim_w = state.values[1] & 0x1FFFF
        dim_h = state.values[2] & 0x1FFFF
        dim_c = state.values[3] & 0x1FFFF
        
        hybrid_values = [state.values[H16_COMMON_START // 4 + idx] for idx in range(23)]
        
        if dim_w == 0 or dim_w >= 65536 or dim_h >= 65536 or dim_c >= 65536 or state.values[0] == 0:
            test_w = state.values[0xb] & 0x1FFFF
            test_h = state.values[0xc] & 0x1FFFF
            test_c = state.values[0xd] & 0x1FFFF
            if 0 < test_w < 10000 and test_h <= test_w and test_h < 10000 and 0 < test_c < 10000:
                dim_w = test_w
                dim_h = test_h
                dim_c = test_c
                for idx in range(23):
                    if 0xa + idx < HW_MAX_REGS:
                        hybrid_values[idx] = state.values[0xa + idx]
                        
        c_ch_cfg = hybrid_values[0]
        infmt = c_ch_cfg & 3
        src2infmt = (c_ch_cfg >> 2) & 3
        outfmt = (c_ch_cfg >> 4) & 3
        inw = hybrid_values[1] & 0x1FFFF
        inh = hybrid_values[2] & 0x1FFFF
        inc = hybrid_values[3] & 0x1FFFF
        ind = hybrid_values[4] & 0x1FFFF
        outw = hybrid_values[5] & 0x1FFFF
        outh = hybrid_values[6] & 0x1FFFF
        outc = hybrid_values[7] & 0x1FFFF
        outd = hybrid_values[8] & 0x1FFFF
        ng = hybrid_values[9] & 0x1FFFF
        conv_cfg = hybrid_values[10]
        kw = conv_cfg & 0x3F
        kh = (conv_cfg >> 6) & 0x3F
        sx = (conv_cfg >> 13) & 3
        sy = (conv_cfg >> 15) & 3
        pl = (conv_cfg >> 17) & 0x1F
        pt = (conv_cfg >> 22) & 0x1F
        ox = (conv_cfg >> 28) & 3
        oy = (conv_cfg >> 30) & 3
        c3 = hybrid_values[11]
        k3d = c3 & 0x1F
        s3d = (c3 >> 5) & 7
        p3d = (c3 >> 8) & 7
        o3d = (c3 >> 11) & 7
        u = hybrid_values[12]
        ucin = (u >> 16) & 0xFFFF
        ucen = (u >> 14) & 1
        tile_overlap = hybrid_values[14]
        overlap = (tile_overlap >> 16) & 0x1F
        overlapt = (tile_overlap >> 21) & 0x1F
        overlapb = (tile_overlap >> 26) & 0x1F
        m = hybrid_values[15]
        active_ne = (m >> 19) & 7
        small_src = (m >> 2) & 3
        task_type = (m >> 4) & 0xF
        out_trans = (m >> 28) & 1
        fill_lower = (m >> 29) & 1
        relu_type = (m >> 24) & 0xF
        ne_cfg = hybrid_values[16]
        ocg = ne_cfg & 7
        fat = (ne_cfg >> 3) & 1
        wustack = (ne_cfg >> 4) & 3
        patch = hybrid_values[17]
        pw = patch & 0xF
        ph = (patch >> 4) & 0x1F
        pe_cfg = hybrid_values[18]
        s1br = pe_cfg & 0xF
        s2br = (pe_cfg >> 4) & 0xF
        s1t = (pe_cfg >> 8) & 1
        s2t = (pe_cfg >> 9) & 1
        ot = (pe_cfg >> 10) & 1
        nid = hybrid_values[19]
        dpe = hybrid_values[20]
        
        # Dimensions L2 Stride Heuristics
        if inw == 0 and inh == 0 and inc == 0:
            use_1045 = False
            if state.valid[0x1046]:
                r1046 = state.values[0x1046]
                if (r1046 & 0xF0) == 0x10:
                    use_1045 = True
            elif state.valid[0x1045] and not state.valid[0x1047]:
                use_1045 = True
                
            if use_1045 and state.valid[0x1045]:
                small_stride = state.values[0x1045]
                candidate = small_stride // 4
                if 7 <= candidate <= 224:
                    inw = candidate
                    inh = candidate
                    
            if inw == 0 and state.valid[0x1047]:
                stride = state.values[0x1047]
                common_dims = [224, 112, 56, 28, 14, 7]
                factors = [16, 32, 64, 128, 256, 512]
                for idx in range(6):
                    if stride % factors[idx] == 0 and stride // factors[idx] == common_dims[idx]:
                        inw = common_dims[idx]
                        inh = common_dims[idx]
                        break
                if inw == 0:
                    all_factors = [4, 8, 16, 32, 64, 128]
                    for idx in range(6):
                        candidate = stride // all_factors[idx]
                        if 7 <= candidate <= 224:
                            inw = candidate
                            inh = candidate
                            break
                            
            if inc == 0 and state.valid[0x1053]:
                packed = state.values[0x1053]
                candidate_c = (packed >> 16) & 0xFFFF
                if 0 < candidate_c < 512:
                    inc = candidate_c
            if inc == 0 and state.valid[0x1044]:
                packed = state.values[0x1044]
                candidate_c = (packed >> 16) & 0xFFFF
                if 0 < candidate_c < 512:
                    inc = candidate_c
            if inc == 0 and state.valid[0x1442]:
                packed = state.values[0x1442]
                candidate_c = (packed >> 16) & 0xFFFF
                if 0 < candidate_c < 512:
                    inc = candidate_c

    if not state.valid[H16_COMMON_START // 4]:
        infmt, src2infmt, outfmt = 2, 2, 2
        
    if (state.valid[(H16_COMMON_START + 0x04) // 4] or
        state.valid[(H16_COMMON_START + 0x08) // 4] or
        state.valid[(H16_COMMON_START + 0x0C) // 4] or
        state.valid[(H16_COMMON_START + 0x10) // 4] or
        (inw > 0 and inw < 1024)):
        print(f"        InDim     : W={inw} H={inh} C={inc} D={ind} Type={get_ch_fmt_name(infmt)} (Src2Type={get_ch_fmt_name(src2infmt)})")
        
    if (state.valid[(H16_COMMON_START + 0x14) // 4] or
        state.valid[(H16_COMMON_START + 0x18) // 4] or
        state.valid[(H16_COMMON_START + 0x1C) // 4] or
        state.valid[(H16_COMMON_START + 0x20) // 4]):
        print(f"        OutDim    : W={outw} H={outh} C={outc} D={outd} Type={get_ch_fmt_name(outfmt)}")
        
    if state.valid[(H16_COMMON_START + 0x24) // 4]:
        print(f"        NumGroups : {ng}")
        
    if state.valid[(H16_COMMON_START + 0x28) // 4]:
        print(f"        ConvCfg   : K={kw}x{kh} S={sx}x{sy} P(left/top)={pl}x{pt} O={ox}x{oy}")
        
    if state.valid[(H16_COMMON_START + 0x2C) // 4]:
        v = state.values[(H16_COMMON_START + 0x2C) // 4]
        print(f"        ConvCfg3D : 0x{v:08x} (Kd={k3d} Sz={s3d} Pz={p3d} Oz={o3d})")
        
    if state.valid[(H16_COMMON_START + 0x30) // 4]:
        print(f"        Unicast   : Cin={ucin} En={ucen}")
        
    if state.valid[(H16_COMMON_START + 0x34) // 4]:
        print(f"        TileOvlp  : Ovlp={overlap} Pad(T/B)={overlapt}x{overlapb}")
        
    if state.valid[(H16_COMMON_START + 0x3C) // 4]:
        task_type_mapped = get_task_type_mapping(task_type)
        task_str = f"({get_hw_task_type_name(task_type_mapped)})" if task_type_mapped != 0 else "((None))"
        print(f"        MacCfg    : TaskType={task_type_mapped} {task_str} ActiveNE={active_ne} SmSrc={small_src} ReluType={relu_type} OutTrans={out_trans} FillLowerNE={fill_lower}")
        
    if state.valid[(H16_COMMON_START + 0x40) // 4]:
        if state.instr_ver >= 20:
            print(f"        NECfg     : OCGSize={ocg} FatTileEn={fat} HalfWUMode={halfwu}")
        else:
            print(f"        NECfg     : OCGSize={ocg} FatTileEn={fat} WUStack={wustack}")
            
    if state.valid[(H16_COMMON_START + 0x44) // 4]:
        print(f"        PatchCfg  : PW={pw} PH={ph}")
        
    if state.valid[(H16_COMMON_START + 0x48) // 4]:
        print(f"        PECfg     : S1BR={s1br} S2BR={s2br} S1T={s1t} S2T={s2t} OutTrans={ot}")
        
    if state.valid[(H16_COMMON_START + 0x4C) // 4]:
        print(f"        NID       : 0x{nid:08x}")
    if state.valid[(H16_COMMON_START + 0x50) // 4]:
        print(f"        DPE       : 0x{dpe:08x}")

def print_ne_h16(state):
    print("        --- Neural Engine (0x4900) ---")
    base = H16_NE_START // 4
    
    kfmt, pen, pbits, sen, reuse, sbs_w, sbs_a, asym = 0, 0, 0, 0, 0, 0, 0, 0
    op, km, ssrc = 0, 0, 0
    bias_en, pass_en, mv_bias_en, bin_point, post_en = 0, 0, 0, 0, 0
    nl_mode_ne, max_pool_en, arg_sel, double_int8_en = 0, 0, 0, 0
    mbias, nebias, ps, rcas, rmode, rbits, qzp = 0, 0, 0, 0, 0, 0, 0
    seeds = [0, 0, 0, 0]
    
    if state.instr_ver >= 20:
        kernel_cfg = state.values[base]
        kfmt = kernel_cfg & 3
        pen = (kernel_cfg >> 2) & 1
        pbits = (kernel_cfg >> 4) & 0xF
        sen = (kernel_cfg >> 8) & 1
        reuse = (kernel_cfg >> 10) & 1
        sbs_w = (kernel_cfg >> 21) & 0xF
        sbs_a = (kernel_cfg >> 25) & 0xF
        mac_cfg = state.values[base + 1]
        op = mac_cfg & 0x3F
        km = (mac_cfg >> 6) & 0x1F
        ssrc = (mac_cfg >> 27) & 3
        mbias = state.values[base + 2]
        nebias = state.values[base + 3]
        ps = state.values[base + 4]
        rcas = state.values[base + 5]
        rmode = state.values[base + 6] & 0xF
        rbits = (state.values[base + 6] >> 4) & 0xF
        seeds = [state.values[base + 7 + idx] for idx in range(4)]
        qzp = state.values[base + 11]
        
    elif state.instr_ver >= 19:
        kernel_cfg = state.values[base]
        kfmt = kernel_cfg & 3
        pen = (kernel_cfg >> 2) & 1
        pbits = (kernel_cfg >> 4) & 0xF
        sen = (kernel_cfg >> 8) & 1
        reuse = (kernel_cfg >> 10) & 1
        sbs_w = (kernel_cfg >> 21) & 7
        asym = (kernel_cfg >> 24) & 1
        mac_cfg = state.values[base + 1]
        op = mac_cfg & 0x3F
        km = (mac_cfg >> 6) & 0x1F
        mbias = state.values[base + 2]
        nebias = state.values[base + 3]
        ps = state.values[base + 4]
        rcas = state.values[base + 5]
        rmode = state.values[base + 6] & 0xF
        rbits = (state.values[base + 6] >> 4) & 0xF
        seeds = [state.values[base + 7 + idx] for idx in range(4)]
        qzp = state.values[base + 11]
        
    else:
        # H16 layout
        kernel_cfg = state.values[base]
        kfmt = kernel_cfg & 3
        pen = (kernel_cfg >> 2) & 1
        pbits = (kernel_cfg >> 4) & 0xF
        sen = (kernel_cfg >> 8) & 1
        reuse = (kernel_cfg >> 10) & 1
        sbs_w = (kernel_cfg >> 21) & 7
        asym = (kernel_cfg >> 24) & 1
        mac_cfg = state.values[base + 1]
        op = mac_cfg & 7
        km = (mac_cfg >> 3) & 1
        bias_en = (mac_cfg >> 4) & 1
        pass_en = (mac_cfg >> 5) & 1
        mv_bias_en = (mac_cfg >> 6) & 1
        bin_point = (mac_cfg >> 8) & 0x3F
        post_en = (mac_cfg >> 14) & 1
        nl_mode_ne = (mac_cfg >> 16) & 3
        max_pool_en = (mac_cfg >> 18) & 1
        arg_sel = (mac_cfg >> 19) & 0xF
        double_int8_en = (mac_cfg >> 23) & 1
        mbias = state.values[base + 2] & 0xFFFFF
        nebias = state.values[base + 3] & 0xFFFFFF
        ps = state.values[base + 4] & 0xFFFFFF
        rcas = state.values[base + 5]
        round_cfg = state.values[base + 6]
        rmode = round_cfg & 3
        rbits = (round_cfg >> 4) & 0x1F
        seeds = [state.values[base + 7 + idx] for idx in range(4)]
        qzp = state.values[base + 11] & 0xFF

    if state.valid[base]:
        sys.stdout.write(f"        KernelCfg: Fmt={get_ch_fmt_name(kfmt)} Pal={pen}({pbits}bit) SparseEn={sen} Reuse={reuse}")
        if state.instr_ver >= 20:
            print(f" SBS(W/A)={sbs_w}/{sbs_a}")
        else:
            print(f" SBS={sbs_w} Asym={asym}")
            
    if state.valid[base + 1]:
        print(f"        MacCfg: Op={op} ({get_ne_op_mode_name(op)}) KMode={km} BiasEn={bias_en} PassEn={pass_en} MVBiasEn={mv_bias_en}")
        sys.stdout.write(f"                BinPoint={bin_point} PostEn={post_en} NLMode={nl_mode_ne} MaxPoolEn={max_pool_en} ArgSel={arg_sel} DblInt8={double_int8_en}")
        if state.instr_ver >= 20:
            sys.stdout.write(f" SmallSrc={ssrc}")
        print("")
        
    if state.valid[base + 2]:
        print(f"        MatrixBias: 0x{mbias:08x}")
    if state.valid[base + 3]:
        print(f"        NEBias: 0x{nebias:08x}")
    if state.valid[base + 4]:
        print(f"        PostScale: 0x{ps:08x}")
    if state.valid[base + 5]:
        print(f"        RcasConfig: KeyMask=0x{rcas&0xFF:02x} CmpBit={(rcas>>8)&7} Axis={(rcas>>12)&3} SenseBit={(rcas>>16)&0xF} Mode={(rcas>>20)&1}")
    if state.valid[base + 6]:
        print(f"        RoundMode: Mode={rmode} Bits={rbits}")
    if any(state.valid[base + 7 + idx] for idx in range(4)):
        print(f"        SRSeeds: 0x{seeds[0]:08x} 0x{seeds[1]:08x} 0x{seeds[2]:08x} 0x{seeds[3]:08x}")
    if state.valid[base + 11]:
        print(f"        QuantZeroPoint: {qzp}")

def print_pe_index_h16(state):
    addr = H16_PE_EXT_START
    if not state.valid[addr // 4]:
        return
    val = state.values[addr // 4]
    max_idx = val & 0xFFFF
    en = (val >> 16) & 1
    print("        --- PE Indexing ---")
    print(f"        PE IndexCfg: MaxIndex={max_idx} Enable={en}")

def print_pe_h16(state):
    base = H16_PE_START // 4
    
    # check if pe is active based on task type
    task_type = 0
    is_task_type_valid = False
    maccfg_offset = 0x48 if state.instr_ver >= 19 else 0x3C
    if state.valid[(H16_COMMON_START + maccfg_offset) // 4]:
        maccfg_reg = state.values[(H16_COMMON_START + maccfg_offset) // 4]
        task_type = (maccfg_reg >> 4) & 0xF
        is_task_type_valid = True
        
    if is_task_type_valid and task_type == 0:
        return
        
    print("        --- Planar Engine (0x4500) ---")
    
    pe_cfg = state.values[base]
    pool = pe_cfg & 3
    op = (pe_cfg >> 2) & 7
    lut_en = (pe_cfg >> 5) & 1
    cond = (pe_cfg >> 6) & 0xF
    red_idx = (pe_cfg >> 10) & 3  # Wait, in C red_idx is bits [10:9]? Let's check: yes, 2 bits.
    # Ah! In H16:
    #   uint32_t red_idx : 2;    // [10:9]
    # So red_idx = (pe_cfg >> 9) & 3.
    # Let's fix that!
    red_idx = (pe_cfg >> 9) & 3
    red_keep = (pe_cfg >> 11) & 1
    nl = (pe_cfg >> 12) & 3
    src1 = (pe_cfg >> 16) & 1
    src2 = (pe_cfg >> 18) & 3
    
    bias = state.values[base + 1]
    scale = state.values[base + 2]
    eps = state.values[base + 3]
    ps = state.values[base + 4]
    fs = state.values[base + 5]
    
    if is_task_type_valid:
        task_type_mapped = get_task_type_mapping(task_type)
        pool_str = get_pe_pool_mode_name_v17(pool) if task_type_mapped in (0, 2) else "None"
        op_str = get_pe_op_mode_name_v17(op) if 3 <= task_type_mapped <= 6 else "None"
        
        if task_type_mapped == 7:
            pe_common_cfg_offset = 0x4c if state.instr_ver >= 19 else 0x40
            if state.valid[(H16_COMMON_START + pe_common_cfg_offset) // 4]:
                pe_common_cfg = state.values[(H16_COMMON_START + pe_common_cfg_offset) // 4]
                print(f"        PE Config (GOC) : Cond={(pe_common_cfg>>4)&0x1F} CtoW={(pe_common_cfg>>10)&1} Src1Sel={(pe_common_cfg>>16)&3} Src2Sel={(pe_common_cfg>>18)&3}")
        elif state.valid[base]:
            print(f"        PE Config : Pool={pool} ({pool_str}) Op={op} ({op_str}) LutEn={lut_en} Cond={cond} RedIdx={red_idx} RedKeep={red_keep} NLMode={nl} Src1={src1} Src2={src2}")
    elif state.valid[base]:
        print(f"        PE Config : Pool={pool} ({get_pe_pool_mode_name_v17(pool)}) Op={op} ({get_pe_op_mode_name_v17(op)}) LutEn={lut_en} Cond={cond} RedIdx={red_idx} RedKeep={red_keep} NLMode={nl} Src1={src1} Src2={src2}")
        
    if state.valid[base + 1]: print_float_reg("PE Bias", bias)
    if state.valid[base + 2]: print_float_reg("PE Scale", scale)
    if state.valid[base + 3]: print_float_reg("PE Final Scale Epsilon", eps)
    if state.valid[base + 4]: print_float_reg("PE PreScale", ps)
    if state.valid[base + 5]: print_float_reg("PE Final Scale", fs)

def print_pe_h17(state):
    base = H16_PE_START // 4
    print("        --- Planar Engine (0x4500) [H17] ---")
    if state.valid[base]:
        pe_cfg = state.values[base]
        pool = pe_cfg & 3
        op = (pe_cfg >> 2) & 7
        lut_en = (pe_cfg >> 5) & 1
        cond = (pe_cfg >> 6) & 7
        red_idx = (pe_cfg >> 9) & 3
        red_keep = (pe_cfg >> 11) & 1
        nl = (pe_cfg >> 12) & 7
        ctow = (pe_cfg >> 15) & 1
        src1_idx = (pe_cfg >> 16) & 0xF
        src2_idx = (pe_cfg >> 20) & 0xF
        max_idx = (pe_cfg >> 24) & 0xFF
        pe_op_names = ["None", "Add", "Mul", "Min", "Max", "5?", "6?", "7?"]
        print(f"        PE Config : Pool={pool} Op={op}({pe_op_names[op&7]}) LutEn={lut_en} Cond={cond} RedIdx={red_idx} RedKeep={red_keep} NLMode={nl} CtoW={ctow} Src1Idx={src1_idx} Src2Idx={src2_idx} MaxIdx={max_idx}")
        
    if state.valid[base + 1]: print_float_reg("PE Bias", state.values[base + 1])
    if state.valid[base + 2]: print_float_reg("PE Scale", state.values[base + 2])
    if state.valid[base + 4]: print_float_reg("PE PreScale", state.values[base + 4])
    if state.valid[base + 5]: print_float_reg("PE Final Scale", state.values[base + 5])
    
    if state.valid[base + 6]:
        s1 = state.values[base + 6]
        print(f"        PE Src1   : Index={(s1>>12)&0xF} Relu={(s1>>1)&1} Transpose={(s1>>3)&1}")
    if state.valid[base + 8]:
        s2 = state.values[base + 8]
        print(f"        PE Src2   : Index={(s2>>12)&0xF} Relu={(s2>>1)&1} Transpose={(s2>>3)&1}")

def print_pe_h18(state):
    base = H16_PE_START // 4
    print("        --- Planar Engine (0x4500) [H18] ---")
    if state.valid[base]:
        pe_cfg = state.values[base]
        pool = pe_cfg & 3
        op = (pe_cfg >> 2) & 7
        lut_en = (pe_cfg >> 5) & 1
        cond = (pe_cfg >> 6) & 7
        red_idx = (pe_cfg >> 9) & 3
        red_keep = (pe_cfg >> 11) & 1
        nl = (pe_cfg >> 12) & 7
        ctow = (pe_cfg >> 15) & 1
        src1_idx = (pe_cfg >> 16) & 0xF
        src2_idx = (pe_cfg >> 20) & 0xF
        max_idx = (pe_cfg >> 24) & 0xFF
        pe_op_names = ["None", "Add", "Mul", "Min", "Max", "5?", "6?", "7?"]
        print(f"        PE Config : Pool={pool} Op={op}({pe_op_names[op&7]}) LutEn={lut_en} Cond={cond} RedIdx={red_idx} RedKeep={red_keep} NLMode={nl} CtoW={ctow} Src1Idx={src1_idx} Src2Idx={src2_idx} MaxIdx={max_idx}")
        
    if state.valid[base + 1]: print_float_reg("PE Bias", state.values[base + 1])
    if state.valid[base + 2]: print_float_reg("PE Scale", state.values[base + 2])
    if state.valid[base + 4]: print_float_reg("PE PreScale", state.values[base + 4])
    if state.valid[base + 5]: print_float_reg("PE Final Scale", state.values[base + 5])

def print_l2_h16(state):
    if state.subtype == 9:
        print_l2_h17(state)
        return
    elif state.subtype == 10:
        print_l2_h18(state)
        return
        
    base = H16_L2_START // 4
    print("        --- L2 Cache Control (0x4100) ---")
    
    l2_type_names = ["L2Read", "DmaRead2", "DmaRead", "L2ChainRead"]
    def get_l2_type_str(t):
        return l2_type_names[t] if t < 4 else "Unk"
        
    def get_l2_dma_fmt_name_h16(fmt_val):
        if fmt_val == 0: return "8b"
        if fmt_val == 1: return "16b"
        if fmt_val == 3: return "32b"
        return "Unk"
        
    if state.valid[base]:
        val = state.values[base]
        print(f"        L2_Control: 0x{val:08x} (src1_relu: {val&1}, padding: {(val>>2)&3}, src2_relu: {(val>>4)&1}, barrier_en: {(val>>16)&1}, barrier_idx: {(val>>17)&0x7f})")
        
    if state.valid[base + 1]:
        s1 = state.values[base + 1]
        t = s1 & 3
        d = (s1 >> 2) & 3
        fmt = (s1 >> 6) & 3
        fmt_str = get_l2_dma_fmt_name_h16(fmt)
        intrlv = (s1 >> 8) & 0xF
        comp = (s1 >> 25) & 3
        print(f"        Src1Cfg  : Type={t} ({get_l2_type_str(t)}) Dependent={d} EnRelu={state.values[base]&1} DMAFmt={fmt} ({fmt_str}) Alias(C={(s1>>4)&1},P={(s1>>20)&1},CR={(s1>>5)&1},PR={(s1>>22)&1}) Cmp={comp}")
        
    if state.valid[base + 2]:
        s2 = state.values[base + 2]
        t = s2 & 3
        d = (s2 >> 2) & 3
        fmt = (s2 >> 6) & 3
        fmt_str = get_l2_dma_fmt_name_h16(fmt)
        intrlv = (s2 >> 8) & 0xF
        comp = (s2 >> 25) & 3
        print(f"        Src2Cfg  : Type={t} ({get_l2_type_str(t)}) Dependent={d} EnRelu={(state.values[base]>>4)&1} DMAFmt={fmt} ({fmt_str}) Alias(C={(s2>>4)&1},P={(s2>>20)&1},CR={(s2>>5)&1},PR={(s2>>22)&1}) Cmp={comp}")
        
    if state.valid[base + 3]:
        sidx = state.values[base + 3]
        t = sidx & 3
        d = (sidx >> 2) & 3
        fmt = (sidx >> 6) & 3
        fmt_str = get_l2_dma_fmt_name_h16(fmt)
        print(f"        L2_SrcIdxCfg: Type={t} ({get_l2_type_str(t)}) Dep={d} DMAFmt={fmt} ({fmt_str}) AliasConv(S={(sidx>>4)&1},R={(sidx>>5)&1})")
        print(f"                      AliasPlanar(S={(sidx>>20)&1},R={(sidx>>22)&1}) Bit27={(sidx>>27)&1}")
        
    if state.valid[base + 4]:
        print(f"        L2_Src1Base: 0x{((state.values[base+4] >> 4) & 0x1FFFF):05x}0")
        print(f"        L2_Src1Strides: C=0x{((state.values[base+5] >> 4) & 0x1FFFF):05x}0 R=0x{((state.values[base+6] >> 4) & 0x1FFFF):05x}0 D=0x{((state.values[base+7] >> 4) & 0x1FFFF):05x}0 G=0x{((state.values[base+8] >> 4) & 0x1FFFF):05x}0")
        
    if state.valid[base + 9]:
        print(f"        L2_Src2Base: 0x{((state.values[base+9] >> 4) & 0x1FFFF):05x}0")
        print(f"        L2_Src2Strides: C=0x{((state.values[base+10] >> 4) & 0x1FFFF):05x}0 R=0x{((state.values[base+11] >> 4) & 0x1FFFF):05x}0 D=0x{((state.values[base+12] >> 4) & 0x1FFFF):05x}0 G=0x{((state.values[base+13] >> 4) & 0x1FFFF):05x}0")
        
    if state.valid[base + 14]:
        print(f"        L2_SrcIdxBase: 0x{((state.values[base+14] >> 4) & 0x1FFFF):05x}0")
        print(f"        L2_SrcIdxStrides: C=0x{((state.values[base+15] >> 4) & 0x1FFFF):05x}0 D=0x{((state.values[base+16] >> 4) & 0x1FFFF):05x}0 G=0x{((state.values[base+17] >> 4) & 0x1FFFF):05x}0")
        
    if state.valid[base + 18]:
        r = state.values[base + 18]
        t = r & 3
        fmt = (r >> 6) & 3
        fmt_str = get_l2_dma_fmt_name_h16(fmt)
        intrlv = (r >> 8) & 0xF
        comp = (r >> 25) & 3
        print(f"        L2_ResultCfg: Type={t} ({get_l2_type_str(t)}) DMAFmt={fmt} ({fmt_str}) Intrlv={intrlv} Cmp={comp}")
        print(f"        L2_ResultBase: 0x{((state.values[base+19] >> 4) & 0x1FFFF):05x}0")
        print(f"        L2_ResultStrides: C=0x{((state.values[base+20] >> 4) & 0x1FFFF):05x}0 R=0x{((state.values[base+21] >> 4) & 0x1FFFF):05x}0 D=0x{((state.values[base+22] >> 4) & 0x1FFFF):05x}0 G=0x{((state.values[base+23] >> 4) & 0x1FFFF):05x}0")
        
    if state.valid[base + 24]:
        print(f"        L2_Res24 : 0x{state.values[base+24]:08x}")
        
    for i in range(3):
        if state.valid[base + 25 + i]:
            val = state.values[base + 25 + i]
            blocks = val & 0xFFF
            length = (val >> 12) & 0xFFFFF
            print(f"        WrapCfg[{i}]: Blocks={blocks} Len=0x{length:05x}")
            
    if state.valid[base + 28]:
        print(f"        L2_Res28 : 0x{state.values[base+28]:08x}")
        
    if state.valid[base + 29]:
        val = state.values[base + 29]
        mask = val & 0xF
        off = (val >> 4) & 0xFFF
        print(f"        ResultWrap: Mask=0x{mask:x} StartOffset=0x{off:x}")
        
    if state.valid[base + 30]:
        print(f"        L2_Res30 : 0x{state.values[base+30]:08x}")
        
    # Result2 Block
    if (state.valid[base + 31] or state.valid[base + 32] or state.valid[base + 33] or state.valid[base + 34]):
        sys.stdout.write("        Result2  :")
        if state.valid[base + 31]: sys.stdout.write(f" Base=0x{((state.values[base+31] >> 4) & 0x1FFFF):05x}")
        if state.valid[base + 32]: sys.stdout.write(f" CS=0x{((state.values[base+32] >> 4) & 0x1FFFF):05x}")
        if state.valid[base + 33]: sys.stdout.write(f" RS=0x{((state.values[base+33] >> 4) & 0x1FFFF):05x}")
        if state.valid[base + 34]: sys.stdout.write(f" DS=0x{((state.values[base+34] >> 4) & 0x1FFFF):05x}")
        print("")
        
    if state.valid[base + 35]:
        val = state.values[base + 35]
        t = val & 1
        m = (val >> 1) & 3
        b = (val >> 3) & 1
        max_idx = (val >> 4) & 0xFFF
        # Wait, get pe index fields layout:
        # pe_index_cfg: max_index: 16 (bits 15:0), mode: 3 (bits 18:16), broadcast: 2 (bits 25:24), transpose: 1 (bits 26).
        # Let's extract exactly:
        max_idx = val & 0xFFFF
        m = (val >> 16) & 7
        b = (val >> 24) & 3
        t = (val >> 26) & 1
        print(f"        PEIndex  : Trans={t} Mode={m} Broadcast={b} MaxIdx={max_idx}")
        
    if state.valid[base + 36]: print(f"        L2_Res36 : 0x{state.values[base+36]:08x}")
    if state.valid[base + 37]: print(f"        L2_Res37 : 0x{state.values[base+37]:08x}")
    if state.valid[base + 38]: print(f"        L2_Res38 : 0x{state.values[base+38]:08x}")
    
    if state.valid[base + 39]:
        print(f"        ResultWrapIdx: Addr=0x{state.values[base+39]:x}")
        
    if state.valid[base + 40]:
        crop = state.values[base + 40]
        s1x = crop & 0x3F
        s1y = (crop >> 8) & 0x1F
        s2x = (crop >> 16) & 0x3F
        s2y = (crop >> 24) & 0x1F
        print(f"        CropTex   : S1X={s1x} S1Y={s1y} S2X={s2x} S2Y={s2y}")

def print_l2_h17(state):
    base = H16_L2_START // 4
    print("        --- L2 Cache Control (0x4100) [H17] ---")
    if state.valid[base]:
        print(f"        L2_Control: 0x{state.values[base]:08x}")
    if state.valid[base + 1]:
        print(f"        L2_Src1Cfg: 0x{state.values[base+1]:08x}")
    if state.valid[base + 2]:
        print(f"        L2_Src2Cfg: 0x{state.values[base+2]:08x}")
        
    # Strides
    print(f"        L2_Src1: Base=0x{state.values[base+4]:x}0 RS=0x{state.values[base+5]:x}0 CS=0x{state.values[base+6]:x}0 DS=0x{state.values[base+7]:x}0 GS=0x{state.values[base+8]:x}0")
    print(f"        L2_Result: Base=0x{state.values[base+19]:x}0 CS=0x{state.values[base+20]:x}0 RS=0x{state.values[base+21]:x}0 DS=0x{state.values[base+22]:x}0 GS=0x{state.values[base+23]:x}0 Type=0x{state.values[base+18]:x}")
    
    if state.valid[base + 25]:
        print(f"        L2_WrapCfg: 0x{state.values[base+25]:08x}")

def print_l2_h18(state):
    base = H16_L2_START // 4
    print("        --- L2 Cache Control (0x4100) [H18] ---")
    if state.valid[base]:
        print(f"        L2_Control: 0x{state.values[base]:08x}")
        
    print(f"        L2_Src1: Base=0x{state.values[base+4]:x}0 RS=0x{state.values[base+5]:x}0 CS=0x{state.values[base+6]:x}0 DS=0x{state.values[base+7]:x}0 GS=0x{state.values[base+8]:x}0")
    print(f"        L2_Result: Base=0x{state.values[base+19]:x}0 CS=0x{state.values[base+20]:x}0 RS=0x{state.values[base+21]:x}0 DS=0x{state.values[base+22]:x}0 GS=0x{state.values[base+23]:x}0 Type=0x{state.values[base+18]:x}")

def print_tiledmasrc_h16(state):
    base = H16_TILEDMA_SRC_START // 4
    print("        --- TileDMASrc (0x4D00) ---")
    
    src_names = ["Src1", "Src2"]
    for i in range(2):
        base_word = base + i
        if not state.valid[base_word]:
            continue
            
        val = state.values[base_word]
        enable = val & 1
        dsid = (val >> 5) & 7 # Wait, in C it is written: `src->dmacfg[i].dsid_cache_hint` which is [5:7]. Yes!
        # wait! It is printed as DSID/Hint in C:
        # printf("        %sDMAConfig : En=%u (%s) DSID/Hint=%u Tag=%u DepInt=%u DepMode=%u\n", ...)
        tag = (val >> 16) & 0xFF
        dep_int = (val >> 24) & 0xF
        dep_mode = (val >> 28) & 3
        enable_str = "Enabled" if enable else "Disabled"
        print(f"        {src_names[i]}DMAConfig : En={enable} ({enable_str}) DSID/Hint={dsid} Tag={tag} DepInt={dep_int} DepMode={dep_mode}")
        
        # Wrap Config
        wrap_word = base + 2 + i
        if state.valid[wrap_word]:
            wval = state.values[wrap_word]
            dim = (wval >> 8) & 7
            wstatic = (wval >> 16) & 0xFFFF
            print(f"        {src_names[i]}WrapCfg    : Dim={dim} Static=0x{wstatic:x}")
            
        # Base and Strides
        strides_valid_word = base + 4 + i * 6 # word 4 for Src1, word 10 for Src2
        if state.valid[strides_valid_word]:
            s_base = base + 4 + i * 6
            base_lo = state.values[s_base]
            base_hi = state.values[s_base + 1]
            row = state.values[s_base + 2]
            plane = state.values[s_base + 3]
            depth = state.values[s_base + 4]
            group = state.values[s_base + 5]
            print(f"        {src_names[i]}Base       : 0x{base_hi:08x}{base_lo:08x}")
            print(f"        {src_names[i]}Strides    : Row=0x{row:x} Chan=0x{plane:x} Depth=0x{depth:x} Group=0x{group:x}")
            
        # Metadata
        meta_valid_word = base + (20 if i == 0 else 23)
        if state.valid[meta_valid_word]:
            meta_cfg = state.values[meta_valid_word]
            print(f"        {src_names[i]}MetaCfg    : 0x{meta_cfg:08x}")
            
        meta_addr_word = base + (16 if i == 0 else 18)
        if state.valid[meta_addr_word]:
            m_hi = state.values[meta_addr_word + 1]
            m_lo = state.values[meta_addr_word]
            print(f"        {src_names[i]}MetaData   : Addr=0x{m_hi:08x}{m_lo:08x}")
            
        # Format Info
        fmt_word = base + 26 + i
        if state.valid[fmt_word]:
            fval = state.values[fmt_word]
            mode = fval & 3
            trunc = (fval >> 4) & 7
            shift = (fval >> 8) & 0xF
            mem_fmt = (fval >> 12) & 3
            offset_ch = (fval >> 16) & 7
            # wait! OffsetCh is printed as signed or unsigned? In C: `src->fmt[i].offset_ch` is printed with `%d`. But since it's 3 bits, it's typically unsigned or signed depending on type. But it's fine.
            # wait, in get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift):
            fmt_str = get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift)
            interleave = (fval >> 24) & 0xF
            cmp_vec = (fval >> 28) & 0xF
            print(f"        {src_names[i]}Fmt     : Mode={mode} MemFmt={mem_fmt} Trunc={trunc} Shift={shift} -> {fmt_str}")
            # wait, is OffsetCh printed as signed? In C offset_ch is declared as `int offset_ch : 3;`?
            # Let's check `ane_hwx_regs.h` line 682: `uint32_t offset_ch : 3;`.
            # So it is unsigned in struct, but printed with `%d` in printf. We can print it as signed integer if it is negative?
            # For 3 bits, unsigned 0..7. If we treat it as unsigned it is fine.
            # But let's check: if value is > 3 (e.g. 4..7), signed 3-bit would be -4..-1.
            # Usually offset_ch is small. Let's just print it. If it is 3 bits, we can do:
            off_ch_val = offset_ch
            if off_ch_val >= 4: off_ch_val -= 8
            cmp_vec_val = cmp_vec
            if cmp_vec_val >= 8: cmp_vec_val -= 16
            
            # Wait, in C format:
            # "                 Intrlv=%u OffCh=%d CmpVec=%d\n"
            # Let's see if we should sign-extend offset_ch and cmp_vec:
            # yes, in `ane_hwx_regs.h` it is declared as `int offset_ch : 3;` or `uint32_t`?
            # Wait! In line 682: `uint32_t offset_ch : 3;`? No, wait: in the C struct definition of `ane_tiledmasrc_h16_t` line 682, it says `uint32_t offset_ch : 3;`.
            # But in `print_tiledmasrc_h16` it printed with `%d`.
            # If it's unsigned, then %d will just print it as a positive number.
            # Wait, let's look at `cmp_vec : 4;`. In line 685: `uint32_t cmp_vec : 4;`.
            # If it's unsigned, %d prints it positive.
            # Let's sign-extend them just in case, or print as signed.
            # Actually, let's check `cmp_vec` and `offset_ch` in standard outputs. In previous python output it printed:
            # `Intrlv=1 OffCh=0 CmpVec=0` (all 0s).
            # So let's do:
            print(f"                 Intrlv={interleave} OffCh={off_ch_val} CmpVec={cmp_vec_val}")
            
        # Compressed Info
        comp_word = base + 30 + i * 4 # word 30 for Src1, word 34 for Src2
        if state.valid[comp_word]:
            cval = state.values[comp_word]
            comp_en = cval & 1
            comp_en_str = "Enabled" if comp_en else "Disabled"
            mbsize = (cval >> 2) & 1
            packing = (cval >> 4) & 0x3F
            lossy = (cval >> 13) & 1
            md_tag = (cval >> 24) & 0xFF
            print(f"        {src_names[i]}Comp       : En={comp_en} ({comp_en_str}) PF={packing} MBS={mbsize} Lossy={lossy} MdTag=0x{md_tag:x}")
            
            c_lo = state.values[base + 31 + i * 4]
            c_hi = state.values[base + 32 + i * 4]
            crop = state.values[base + 33 + i * 4]
            print(f"        {src_names[i]}CompSize   : 0x{c_hi:08x}{c_lo:08x}")
            print(f"        {src_names[i]}CropOffset : 0x{crop:08x}")
            
        # Wrap Dynamic / Dependency Offset
        wd_word = base + 46 + i
        if state.valid[wd_word]:
            print(f"        {src_names[i]}WrapDyn    : 0x{state.values[wd_word]:08x}")
            
        do_word = base + 48 + i
        if state.valid[do_word]:
            print(f"        {src_names[i]}DepOff     : 0x{state.values[do_word]:08x}")
            
    # Texture Config (at 0x4DC8 / word 50)
    tex_word = base + 50
    if state.valid[tex_word]:
        tval = state.values[tex_word]
        mode = tval & 7
        norm1 = (tval >> 3) & 7
        norm2 = (tval >> 6) & 7
        filt = (tval >> 12) & 7
        bgen = (tval >> 22) & 1
        dval = (tval >> 23) & 1
        wrap = (tval >> 24) & 0x1F
        print(f"        TextureCfg    : 0x{tval:08x} Mode={mode} ({get_texture_mode_name(mode)}) Norm1={norm1} Norm2={norm2} Filter={filt} BGEn={bgen} DepthVal={dval} Wrap={wrap}")
        
    if state.valid[base + 51]:
        print(f"        TextureIdxPerm: 0x{state.values[base+51]:08x}")
    if state.valid[base + 52]:
        print(f"        TextureSrcPerm: 0x{state.values[base+52]:08x}")
        
    # Ephemeral (word 62)
    eph_word = base + 62
    if state.valid[eph_word]:
        en = state.values[eph_word] & 1
        en_str = "Enabled" if en else "Disabled"
        print(f"        Src1Ephemeral : En={en} ({en_str})")

def print_tiledmadst_h16(state):
    base = H16_TILEDMA_DST_START // 4
    print("        --- TileDMADst (0x5100) ---")
    if state.valid[base]:
        val = state.values[base]
        en = val & 1
        en_str = "Enabled" if en else "Disabled"
        dsid = (val >> 8) & 0xFF
        tag = (val >> 16) & 0xFF
        print(f"        DstDMAConfig: En={en} ({en_str}) DSID={dsid} Tag={tag}")
        
    if state.valid[base + 4]: # RowStride
        # strides: base+4 is Row, base+5 is Plane, base+6 is Depth, base+7 is Group
        row = state.values[base + 4]
        plane = state.values[base + 5]
        depth = state.values[base + 6]
        group = state.values[base + 7]
        print(f"        DstStrides: Row=0x{row:08x} Plane=0x{plane:08x} Depth=0x{depth:08x} Group=0x{group:08x}")
        
    if state.valid[base + 10]: # Meta base
        m_lo = state.values[base + 10]
        m_hi = state.values[base + 11]
        fmt_mode = state.values[base + 12]
        fmt_mode_val = fmt_mode & 3
        meta_size = (fmt_mode >> 7) & 0x1FFFFFF
        print(f"        DstMeta   : Addr=0x{m_hi:x}{m_lo:08x} FmtMode={fmt_mode_val} ({get_hw_tensor_format_mode_name(fmt_mode_val)}) Size=0x{meta_size:x}")
        
    if state.valid[base + 14]: # DstFmt
        # wait! `dst->dstfmt` starts at base+14 (which is word 14).
        # Let's check `ane_tiledmadst_h16_t` in `ane_hwx_regs.h` to see fields:
        # Wait, we can unpack fields of DstFmt:
        fval = state.values[base + 14]
        mode = fval & 3
        trunc = (fval >> 4) & 7
        shift = (fval >> 8) & 0xF
        mem_fmt = (fval >> 12) & 3
        offset_ch = (fval >> 16) & 7
        zero_pad_first = (fval >> 20) & 1
        zero_pad_last = (fval >> 21) & 1
        interleave = (fval >> 24) & 0xF
        cmp_vec = (fval >> 28) & 0xF
        fmt_str = get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift)
        print(f"        DstFmt: Mode={mode} MemFmt={mem_fmt} Trunc={trunc} Shift={shift} -> {fmt_str}")
        print(f"                OffCh={offset_ch} ZeroPad (F={zero_pad_first}, L={zero_pad_last}) Intrlv={interleave} CmpVec={cmp_vec}")
        
    if state.valid[base + 16]: # DstComp
        # wait! DstComp starts at base+16 (word 16).
        # Let's check `ane_tiledmadst_h16_t` in `ane_hwx_regs.h` to see fields of `dstcompinfo`:
        cval = state.values[base + 16]
        comp_en = cval & 1
        comp_en_str = "Enabled" if comp_en else "Disabled"
        packing = (cval >> 4) & 0x3F
        mbsize = (cval >> 2) & 1
        lossy = (cval >> 13) & 1
        print(f"        DstComp: En={comp_en} ({comp_en_str}) Packing={packing} MBSize={mbsize} Lossy={lossy}")
        
    if state.valid[base + 20]:
        pxoff = state.values[base + 20]
        print(f"        DstPixelOff: 0x{pxoff:08x} (CropY={pxoff>>16})")

def print_kerneldmasrc_h16(state):
    if state.subtype == 9:
        print_kerneldmasrc_h17(state)
        return
    elif state.subtype == 10:
        print_kerneldmasrc_h18(state)
        return
        
    base = H16_KERNELDMA_START // 4
    print("        --- KernelDMASrc (0x5500) ---")
    if state.valid[base]:
        val = state.values[base]
        en = (val >> 6) & 1
        en_str = "Enabled" if en else "Disabled"
        sparse = (val >> 5) & 1
        reuse = (val >> 4) & 1
        print(f"        MasterCfg: En={en} ({en_str}) Sparse={sparse} Reuse={reuse}")
        
    if state.valid[base + 1]:
        print(f"        AlignedCoeffSize: 0x{state.values[base+1]:08x}")
        
    if state.valid[base + 2]:
        val = state.values[base + 2]
        rate = (val >> 16) & 0xFFFF
        early = val & 1
        print(f"        Prefetch : Rate={rate} Early={early}")
        
    if state.valid[base + 6]:
        print(f"        KernelGroupStride: {state.values[base+6]&0x3ffffff}")
    if state.valid[base + 7]:
        print(f"        KernelOCGStride  : {state.values[base+7]&0x3ffffff}")
        
    for i in range(16):
        if state.valid[base + 8 + i]:
            cfg = state.values[base + 8 + i]
            en = cfg & 1
            en_str = "Enabled" if en else "Disabled"
            dsid = (cfg >> 8) & 0xFF
            tag = (cfg >> 16) & 0xFF
            print(f"        CoeffCfg[{i}] : En={en} ({en_str}) DSID={dsid} Tag={tag}")
            
    for i in range(16):
        if state.valid[base + 24 + i]:
            print(f"        CoeffBase[{i}]: 0x{state.values[base+24+i]:08x}")
            
    for i in range(16):
        if state.valid[base + 40 + i]:
            print(f"        CoeffSize[{i}]: 0x{state.values[base+40+i]&0x3ffffff:08x}")
            
    if state.valid[base + 56]:
        val = state.values[base + 56]
        en = val & 1
        tag = (val >> 16) & 0xFF
        print(f"        Bias: En={en} Tag={tag}")
        
    if state.valid[base + 60]:
        val = state.values[base + 60]
        en = val & 1
        tag = (val >> 16) & 0xFF
        print(f"        PSScale: En={en} Tag={tag}")
        
    if state.valid[base + 68]:
        val = state.values[base + 68]
        en = val & 1
        tag = (val >> 16) & 0xFF
        print(f"        NLut: En={en} Tag={tag}")

def print_kerneldmasrc_h17(state):
    base = H16_KERNELDMA_START // 4
    print("        --- KernelDMASrc (0x5500) [H17] ---")
    if state.valid[base]:
        val = state.values[base]
        en = (val >> 6) & 1
        sparse = (val >> 5) & 1
        reuse = (val >> 4) & 1
        print(f"        MasterCfg: En={en} Sparse={sparse} Reuse={reuse}")
        
    if state.valid[base + 1]:
        print(f"        AlignedCoeffSize: 0x{state.values[base+1]:08x}")
    if state.valid[base + 2]:
        print(f"        Prefetch : 0x{state.values[base+2]:08x}")
    if state.valid[base + 6]:
        print(f"        StrideX  : {state.values[base+6]}")
    if state.valid[base + 7]:
        print(f"        StrideY  : {state.values[base+7]}")
        
    for i in range(16):
        if state.valid[base + 8 + i]:
            cfg = state.values[base + 8 + i]
            hint = (cfg >> 4) & 0xF
            dsid = (cfg >> 8) & 0xFF
            tag = (cfg >> 16) & 0xFF
            print(f"        CoeffCfg[{i}] : Hint={hint} DSID={dsid} Tag={tag}")
            
    for i in range(16):
        if state.valid[base + 24 + i]:
            print(f"        CoeffBase[{i}]: 0x{state.values[base+24+i]:08x}")
            
    for i in range(16):
        if state.valid[base + 40 + i]:
            print(f"        CoeffSize[{i}]: 0x{state.values[base+40+i]:08x}")
            
    if state.valid[base + 56]:
        cfg = state.values[base + 56]
        hint = (cfg >> 4) & 0xF
        print(f"        BiasCfg  : Hint={hint}")
        
    if state.valid[base + 60]:
        cfg = state.values[base + 60]
        hint = (cfg >> 4) & 0xF
        print(f"        PSCfg    : Hint={hint}")
        
    if state.valid[base + 64]:
        cfg = state.values[base + 64]
        hint = (cfg >> 4) & 0xF
        tag = (cfg >> 16) & 0xFF
        print(f"        PalCfg   : Hint={hint} Tag={tag}")
        
    if state.valid[base + 68]:
        cfg = state.values[base + 68]
        hint = (cfg >> 4) & 0xF
        tag = (cfg >> 16) & 0xFF
        print(f"        NLutCfg  : Hint={hint} Tag={tag}")

def print_kerneldmasrc_h18(state):
    print("        --- KernelDMASrc (0x5500) [H18] ---")
    print_kerneldmasrc_h17(state)

def print_cachedma_h16(state):
    base = H16_CACHEDMA_START // 4
    # CacheDMA / Telemetry
    print("        --- CacheDMASrc (0x5900) ---")
    if state.valid[base]:
        val = state.values[base]
        flush = val & 1
        en = (val >> 1) & 1
        en_str = "Enabled" if en else "Disabled"
        sync = (val >> 2) & 3
        et = (val >> 4) & 0x1F
        fl = (val >> 9) & 1
        thresh = (val >> 16) & 0xFFFF
        print(f"        Control: Flush={flush} En={en} ({en_str}) TaskSync={hex(sync)} ET={hex(et)} FL={fl} Thresh=0x{thresh:04x}")
        
    if state.valid[base + 1]:
        val = state.values[base + 1]
        bw = val & 0x3FF
        sieve2 = (val >> 16) & 0xF
        age = (val >> 20) & 0xF
        print(f"        Pre0: BWLimit={bw} Sieve2={sieve2} AgeOut={age}")
        
    if state.valid[base + 2]:
        val = state.values[base + 2]
        sieve1 = val & 0x3FFF
        print(f"        Pre1: Sieve1={sieve1}")
        
    if state.valid[base + 6]:
        val = state.values[base + 6]
        print(f"        DSID: DSID_Size=0x{val:x}")
        
    if state.valid[base + 7]:
        val = state.values[base + 7]
        print(f"        Footprint: Arg2=0x{val:x}")
        
    if state.valid[base + 8]:
        val = state.values[base + 8]
        arg1 = val & 0xFFFF
        arg2 = (val >> 16) & 0xFFFF
        print(f"        ET_Args12: Arg1=0x{arg1:04x} Arg2=0x{arg2:04x}")
        
    if state.valid[base + 9]:
        val = state.values[base + 9]
        print(f"        Flush: Arg=0x{val&0xFFFF:04x}")
        
    if state.valid[base + 10]:
        val = state.values[base + 10]
        arg3 = val & 0xFF
        arg4 = (val >> 16) & 0xFF
        print(f"        ET_Args34: Arg3=0x{arg3:02x} Arg4=0x{arg4:02x}")
        
    if state.valid[base + 11]:
        val = state.values[base + 11]
        en = val & 1
        delay = (val >> 4) & 0xF
        min_v = (val >> 8) & 0xFF
        max_v = (val >> 16) & 0xFF
        scale = (val >> 24) & 0xFF
        print(f"        BackOff: En={en} Delay={delay} Min={min_v} Max={max_v} Scale={scale}")

def report_hwx_state_json(state):
    arch = "M4" if (state.instr_ver > 11 or state.subtype == 6) else "H14" if state.instr_ver == 11 else "M1"
    regs = []
    for r in range(HW_MAX_REGS):
        if state.valid[r]:
            addr = r * 4
            name = get_reg_name(addr, state.subtype)
            reg_dict = {
                "val": f"0x{state.values[r]:08x}",
                "addr": f"0x{addr:05x}"
            }
            if name:
                reg_dict["name"] = name
            regs.append(reg_dict)
            
    dict_out = {
        "subtype": state.subtype,
        "registers": regs,
        "arch": arch
    }
    return dict_out

def report_hwx_state(state, dump_reg_blocks):
    if state.instr_ver == 11:
        print_common_h14(state)
        print_l2_h14(state)
        print_pe_h14(state)
        print_ne_h14(state)
        print_tiledmasrc_h14(state)
        print_tiledmadst_h14(state)
        print_kerneldmasrc_h14(state)
        if dump_reg_blocks:
            blocks = [
                ("[0x0000] Common Module", H14_COMMON_START, H14_COMMON_COUNT),
                ("[0x0500] L2 Cache Control", H14_L2_START, H14_L2_COUNT),
                ("[0x0900] Planar Engine (PE)", H14_PE_START, H14_PE_COUNT),
                ("[0x0D00] Neural Engine (NE)", H14_NE_START, H14_NE_COUNT),
                ("[0x1100] TileDMA Source", H14_TILEDMA_SRC_START, H14_TILEDMA_SRC_COUNT),
                ("[0x1500] TileDMA Destination", H14_TILEDMA_DST_START, H14_TILEDMA_DST_COUNT),
                ("[0x1900] KernelDMA Source", H14_KERNELDMA_START, H14_KERNELDMA_COUNT),
            ]
            dump_hw_blocks(state, blocks, lambda addr: get_reg_name(addr, state.subtype))
    elif state.subtype == 6:
        print_common_h14(state)
        print_ne_h15(state)
        print_pe_h15(state)
        print_l2_h15(state)
        print_tiledmasrc_h15(state)
        print_tiledmadst_h15(state)
        print_kerneldmasrc_h15(state)
        print_cachedma_h16(state)
        if dump_reg_blocks:
            blocks = [
                ("[0x0000] Common Module", H16_COMMON_START, 19),
                ("[0x4100] L2 Cache Control", H16_L2_START, 30),
                ("[0x4500] Planar Engine (PE)", H16_PE_START, 14),
                ("[0x4900] Neural Engine Core (NE)", H16_NE_START, 11),
                ("[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, 69),
                ("[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, 21),
                ("[0x5500] KernelDMA Source", H16_KERNELDMA_START, 72),
                ("[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, 12),
            ]
            dump_hw_blocks(state, blocks, lambda addr: get_reg_name(addr, state.subtype))
    elif state.instr_ver > 11:
        print_common_h16(state)
        print_ne_h16(state)
        print_pe_index_h16(state)
        if state.subtype == 9:
            print_pe_h17(state)
        elif state.subtype == 10:
            print_pe_h18(state)
        else:
            print_pe_h16(state)
        print_l2_h16(state)
        print_tiledmasrc_h16(state)
        print_tiledmadst_h16(state)
        print_kerneldmasrc_h16(state)
        print_cachedma_h16(state)
        if dump_reg_blocks:
            if state.instr_ver == 20:
                blocks = [
                    ("[0x0000] Common Module", H16_COMMON_START, H18_COMMON_COUNT),
                    ("[0x4100] L2 Cache Control", H16_L2_START, H18_L2_COUNT),
                    ("[0x4500] Planar Engine (PE)", H16_PE_START, H18_PE_COUNT),
                    ("[0x4900] Neural Engine Core (NE)", H16_NE_START, H18_NE_COUNT),
                    ("[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, H18_TILEDMA_SRC_COUNT),
                    ("[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, H18_TILEDMA_DST_COUNT),
                    ("[0x5500] KernelDMA Source", H16_KERNELDMA_START, H18_KERNELDMA_COUNT),
                    ("[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, H18_CACHEDMA_COUNT),
                ]
            elif state.instr_ver == 19:
                blocks = [
                    ("[0x0000] Common Module", H16_COMMON_START, H17_COMMON_COUNT),
                    ("[0x4100] L2 Cache Control", H16_L2_START, H17_L2_COUNT),
                    ("[0x4500] Planar Engine (PE)", H16_PE_START, H17_PE_COUNT),
                    ("[0x4900] Neural Engine Core (NE)", H16_NE_START, H17_NE_COUNT),
                    ("[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, H17_TILEDMA_SRC_COUNT),
                    ("[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, H17_TILEDMA_DST_COUNT),
                    ("[0x5500] KernelDMA Source", H16_KERNELDMA_START, H17_KERNELDMA_COUNT),
                    ("[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, H17_CACHEDMA_COUNT),
                ]
            else:
                blocks = [
                    ("[0x0000] Common Module", H16_COMMON_START, 23),
                    ("[0x4100] L2 Cache Control", H16_L2_START, 41),
                    ("[0x4500] Planar Engine (PE)", H16_PE_START, 16),
                    ("[0x4900] Neural Engine Core (NE)", H16_NE_START, 12),
                    ("[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, 81),
                    ("[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, 21),
                    ("[0x5500] KernelDMA Source", H16_KERNELDMA_START, 72),
                    ("[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, 12),
                ]
            dump_hw_blocks(state, blocks, lambda addr: get_reg_name(addr, state.subtype))
    else:
        print_common_h13(state)
        print_l2_h13(state)
        print_pe_h13(state)
        print_ne_h13(state)
        print_tiledmasrc_h13(state)
        print_tiledmadst_h13(state)
        print_kerneldmasrc_h13(state)
        if dump_reg_blocks:
            blocks = [
                ("[0x00000] Common Module", H13_COMMON_START, 16),
                ("[0x04800] L2 Cache Control", H13_L2_START, 16),
                ("[0x08800] Planar Engine (PE)", H13_PE_START, 4),
                ("[0x0C800] Neural Engine Core (NE)", H13_NE_START, 5),
                ("[0x13800] TileDMA Source", H13_TILEDMA_SRC_START, 24),
                ("[0x17800] TileDMA Destination", H13_TILEDMA_DST_START, 7),
                ("[0x1F800] KernelDMA Source", H13_KERNELDMA_START, 5),
            ]
            dump_hw_blocks(state, blocks, lambda addr: get_reg_name(addr, state.subtype))

def decode_ane_td(section_data, subtype, dump_reg_blocks, dump_json):
    offset = 0
    task_idx = 0
    total_len = len(section_data)
    
    # sizeof(ane_header_h13_t) is 40 bytes (0x28)
    while offset + 40 <= total_len:
        h = struct.unpack_from("<2H2B3H5I3Q", section_data, offset)
        tid = h[0]
        nid = h[1]
        flags_b = h[2]
        lnid = flags_b & 1
        eon = (flags_b >> 1) & 1
        exe_cycles = h[3]
        next_size = h[4] & 0x1F9 # wait, next_size:9 bits (bits 0-8). mask with 0x1FF
        next_size = h[4] & 0x1FF
        log_events = h[6] & 0xFFFFFF
        exceptions = h[7] & 0xFFFFFF
        flags = h[10]
        tsr = (flags >> 19) & 1
        tse = (flags >> 16) & 1
        
        next_pointer = h[11]
        base_ene = h[12]
        rbase0 = base_ene & 0x1F
        rbase1 = (base_ene >> 6) & 0x1F
        wbase = (base_ene >> 12) & 0x1F
        tbase = (base_ene >> 18) & 0x1F
        ene = (base_ene >> 24) & 7
        
        kbase = h[13]
        kbase0 = kbase & 0x1F
        kbe0 = (kbase >> 5) & 1
        kbase1 = (kbase >> 6) & 0x1F
        kbe1 = (kbase >> 11) & 1
        kbase2 = (kbase >> 12) & 0x1F
        kbe2 = (kbase >> 17) & 1
        kbase3 = (kbase >> 18) & 0x1F
        kbe3 = (kbase >> 23) & 1
        
        # Hit zero padding
        if next_pointer == 0 and exe_cycles == 0 and log_events == 0:
            break
            
        if not dump_json:
            print(f"      [ANE Task {task_idx} @ 0x{offset:x}]")
            print(f"        TID: 0x{tid:04x} NID: 0x{nid:02x} LNID: {lnid} EON: {eon}")
            print(f"        ExeCycles: {exe_cycles} NextSize: {next_size}")
            print(f"        NextPtr: 0x{next_pointer:08x} TSR: {tsr} TSE: {tse} ENE: {ene}")
            print(f"        RBase: {rbase0}/{rbase1} WBase: {wbase} TBase: {tbase}")
            if kbe0 or kbe1 or kbe2 or kbe3:
                print(f"        KBase: {kbase0}/{kbase1}/{kbase2}/{kbase3}")
            task_idx += 1
        else:
            task_idx += 1
            
        state = HwxState(subtype, 7)
        
        # Modern Stream Parse
        words = struct.unpack_from(f"<{(total_len - offset - 40)//4}I", section_data, offset + 40)
        td_words = len(words)
        if next_pointer > offset + 40:
            limit_words = (next_pointer - offset - 40) // 4
            if limit_words < td_words:
                td_words = limit_words
                
        w_idx = 0
        while w_idx < td_words:
            hdr = words[w_idx]
            w_idx += 1
            if hdr == 0:
                continue
            count = (hdr >> 26) & 0x3F
            addr = (hdr & 0x3FFFFFF) >> 2
            num_vals = count + 1
            for i in range(num_vals):
                if w_idx >= td_words:
                    break
                if addr + i < HW_MAX_REGS:
                    state.values[addr + i] = words[w_idx]
                    state.valid[addr + i] = True
                w_idx += 1
                
        if dump_json:
            jdict = report_hwx_state_json(state)
            print(json.dumps(jdict, indent=2).replace('": ', '" : '))
        else:
            report_hwx_state(state, dump_reg_blocks)
            
        if next_pointer == 0 or next_pointer <= offset:
            break
        offset = next_pointer

def decode_ane_td_m4(section_data, subtype, dump_reg_blocks, dump_json):
    if not dump_json:
        print(f"\n[{get_arch_name(subtype)}] Detected Dense HWX Format (CPU Subtype 0x{subtype:x})")
        
    offset = 0
    task_idx = 0
    total_len = len(section_data)
    
    # sizeof(ane_header_h16_t) is 40 bytes (0x28)
    # Header format: tid(2B), task_size_n_flags(2B), exe_cycles(2B), pad1(2B),
    # log_events(4B), exceptions(4B), debug_log_events(4B), debug_exceptions(4B),
    # live_outs(4B), unknown_flags(4B), ctrl_flags(4B), dtid(2B), pad8(2B)
    while offset + 40 <= total_len:
        h = struct.unpack_from("<4H 6I I 2H", section_data, offset)
        tid = h[0]
        # h[1] is task_size and pad0.
        task_size = h[1] & 0x7FF
        exe_cycles = h[2]
        log_events = h[4] & 0xFFFFFF
        exceptions = h[5] & 0xFFFFFF
        live_outs = h[8] & 0xFFFFFF
        ctrl_flags = h[10]
        tsr = ctrl_flags & 1
        tde = (ctrl_flags >> 1) & 1
        ene = (ctrl_flags >> 16) & 7
        dtid = h[11]
        
        if task_size == 0:
            offset += 16
            continue
            
        if tid > 0x1000:
            if not dump_json:
                print(f"      [M4 Parser] Found likely end of tasks at offset 0x{offset:x} (TID: 0x{tid:04x})")
            break
            
        size_bytes = task_size * 4
        if not dump_json:
            print(f"      [ANE Task {task_idx} @ 0x{offset:x}] (Size: 0x{size_bytes:x} bytes)")
            print(f"        TID: 0x{tid:04x} TaskSize: 0x{task_size:x} ExeCycles: {exe_cycles} ENE: {ene} DTID: 0x{dtid:04x}")
            print(f"        LogEvents: 0x{log_events:06x} Exceptions: 0x{exceptions:06x}")
            print(f"        LiveOuts: 0x{live_outs:08x} TSR: {tsr} TDE: {tde}")
            task_idx += 1
        else:
            task_idx += 1
            
        state = HwxState(subtype, get_instruction_set_version(subtype))
        
        words = struct.unpack_from(f"<{task_size}I", section_data, offset)
        num_words = task_size
        
        i = 8 if subtype in (5, 6) else 10
        while i < num_words:
            header = words[i]
            i += 1
            word_addr = header & 0x7FFF
            
            if (header >> 31) == 0:
                num_regs = (header >> 15) & 0x3F
                for j in range(num_regs + 1):
                    if i >= num_words:
                        break
                    if word_addr + j < HW_MAX_REGS:
                        if not state.first_written[word_addr + j]:
                            state.first_values[word_addr + j] = words[i]
                            state.first_written[word_addr + j] = True
                        state.values[word_addr + j] = words[i]
                        state.valid[word_addr + j] = True
                    i += 1
            else:
                mask = (header >> 15) & 0xFFFF
                if i < num_words:
                    if word_addr < HW_MAX_REGS:
                        if not state.first_written[word_addr]:
                            state.first_values[word_addr] = words[i]
                            state.first_written[word_addr] = True
                        state.values[word_addr] = words[i]
                        state.valid[word_addr] = True
                    i += 1
                for bit in range(16):
                    if (mask >> bit) & 1:
                        if i >= num_words:
                            break
                        if word_addr + bit + 1 < HW_MAX_REGS:
                            if not state.first_written[word_addr + bit + 1]:
                                state.first_values[word_addr + bit + 1] = words[i]
                                state.first_written[word_addr + bit + 1] = True
                            state.values[word_addr + bit + 1] = words[i]
                            state.valid[word_addr + bit + 1] = True
                        i += 1
                        
        if dump_json:
            jdict = report_hwx_state_json(state)
            print(json.dumps(jdict, indent=2).replace('": ', '" : '))
        else:
            report_hwx_state(state, dump_reg_blocks)
            
        offset += (size_bytes + 15) & ~15

def get_cmd_name(cmd):
    return {
        0x01: "LC_SEGMENT",
        0x02: "LC_SYMTAB",
        0x03: "LC_SYMSEG",
        0x04: "LC_THREAD",
        0x05: "LC_UNIXTHREAD",
        0x06: "LC_LOADFVMLIB",
        0x07: "LC_IDFVMLIB",
        0x08: "LC_IDENT",
        0x09: "LC_FVMFILE",
        0x0a: "LC_PREPAGE",
        0x0b: "LC_DYSYMTAB",
        0x0c: "LC_LOAD_DYLIB",
        0x0d: "LC_ID_DYLIB",
        0x0e: "LC_LOAD_DYLINKER",
        0x0f: "LC_ID_DYLINKER",
        0x10: "LC_PREBOUND_DYLIB",
        0x11: "LC_ROUTINES",
        0x12: "LC_SUB_FRAMEWORK",
        0x13: "LC_SUB_UMBRELLA",
        0x14: "LC_SUB_CLIENT",
        0x15: "LC_SUB_LIBRARY",
        0x16: "LC_TWOLEVEL_HINTS",
        0x17: "LC_PREBIND_CKSUM",
        0x18: "LC_LOAD_WEAK_DYLIB",
        0x19: "LC_SEGMENT_64",
        0x1a: "LC_ROUTINES_64",
        0x1b: "LC_UUID",
        0x1c: "LC_RPATH",
        0x1d: "LC_CODE_SIGNATURE",
        0x1e: "LC_SEGMENT_SPLIT_INFO",
        0x1f: "LC_REEXPORT_DYLIB",
        0x20: "LC_LAZY_LOAD_DYLIB",
        0x21: "LC_ENCRYPTION_INFO",
        0x22: "LC_DYLD_INFO",
        0x22 | 0x80000000: "LC_DYLD_INFO_ONLY",
        0x23: "LC_LOAD_UPWARD_DYLIB",
        0x24: "LC_VERSION_MIN_MACOSX",
        0x25: "LC_VERSION_MIN_IPHONEOS",
        0x26: "LC_FUNCTION_STARTS",
        0x27: "LC_DYLD_ENVIRONMENT",
        0x28: "LC_MAIN",
        0x29: "LC_DATA_IN_CODE",
        0x2a: "LC_SOURCE_VERSION",
        0x2b: "LC_DYLIB_CODE_SIGN_DRS",
        0x2c: "LC_ENCRYPTION_INFO_64",
        0x2d: "LC_LINKER_OPTION",
        0x2e: "LC_LINKER_OPTIMIZATION_HINT",
        0x2f: "LC_BUILD_VERSION",
        0x31: "LC_NOTE",
        0x40: "LC_ANE_MAPPED_REGION",
    }.get(cmd, "UNKNOWN")

def hex_dump(label, ptr, length):
    print(f"      {label} ({length} bytes):")
    for i in range(0, length, 16):
        line = ptr[i : i + 16]
        hex_str = " ".join(f"{b:02x}" for b in line)
        hex_str = hex_str.ljust(47)
        chars = "".join(chr(b) if 32 <= b <= 126 else "." for b in line)
        print(f"        {i:04x}: {hex_str} |{chars}|")

def decode_lut_coefficients(data, size, operation_hint):
    if not data or size == 0:
        return

    print("        --- LUT Coefficient Analysis ---")
    print(f"        Total Size: {size} bytes ({size // 2} FP16 values)")

    num_values = size // 2

    print("        ")
    print("        Raw FP16 Values (first 32):")
    fp16_data = []
    for i in range(num_values):
        val_u16 = struct.unpack_from("<H", data, i * 2)[0]
        fp16_data.append(val_u16)

    for i in range(min(num_values, 32)):
        val = fp16_to_fp32(fp16_data[i])
        sys.stdout.write(f"        [{i:2d}] 0x{fp16_data[i]:04x} = {val:8.4f}")
        if (i + 1) % 4 == 0:
            sys.stdout.write("\n")
        else:
            sys.stdout.write("  ")

    if num_values > 0 and num_values < 32 and num_values % 4 != 0:
        sys.stdout.write("\n")

    if num_values > 32:
        print(f"        ... ({num_values - 32} more values)")
    print()

    print("        Attempting segment detection:")

    if num_values >= 9:
        print("        Pattern: [breakpoint, slope, intercept] triplets")
        num_segments = num_values // 3
        for i in range(min(num_segments, 12)):
            breakpoint = fp16_to_fp32(fp16_data[i * 3 + 0])
            slope = fp16_to_fp32(fp16_data[i * 3 + 1])
            intercept = fp16_to_fp32(fp16_data[i * 3 + 2])
            print(f"        Segment {i:2d}: x >= {breakpoint:7.3f}, y = {slope:7.3f}*x + {intercept:7.3f}")
        if num_segments > 12:
            print(f"        ... ({num_segments - 12} more segments)")

    print("\n        Alternative: [slope, intercept] pairs")
    if num_values >= 4:
        num_segments = num_values // 2
        for i in range(min(num_segments, 12)):
            slope = fp16_to_fp32(fp16_data[i * 2 + 0])
            intercept = fp16_to_fp32(fp16_data[i * 2 + 1])
            print(f"        Segment {i:2d}: y = {slope:7.3f}*x + {intercept:7.3f}")
        if num_segments > 12:
            print(f"        ... ({num_segments - 12} more segments)")
    print()

def handle_segment_64(header, lc_data, cmdsize, file_data, dump_hexdump, dump_reg_blocks, dump_json):
    seg = struct.unpack_from("<16s4Q4I", lc_data, 8)
    segname = seg[0].split(b'\x00', 1)[0].decode(errors='ignore')
    vmaddr, vmsize, fileoff, filesize = seg[1], seg[2], seg[3], seg[4]
    nsects = seg[7]
    
    print(f"  Segment Name: {segname}")
    print(f"  VM Addr: 0x{vmaddr:x}")
    print(f"  VM Size: 0x{vmsize:x}")
    print(f"  File Off: 0x{fileoff:x}")
    print(f"  File Size: 0x{filesize:x}")
    print(f"  Num Sections: {nsects}")
    
    sect_offset = 72
    for j in range(nsects):
        if sect_offset + 80 > cmdsize:
            break
        sect = struct.unpack_from("<16s16s2Q8I", lc_data, sect_offset)
        sectname = sect[0].split(b'\x00', 1)[0].decode(errors='ignore')
        sect_segname = sect[1].split(b'\x00', 1)[0].decode(errors='ignore')
        addr, size = sect[2], sect[3]
        offset = sect[4]
        flags = sect[8]
        
        print(f"    Section {j}:")
        print(f"      Name: {sectname}")
        print(f"      Segment: {sect_segname}")
        print(f"      Addr: 0x{addr:x}")
        print(f"      Size: 0x{size:x}")
        print(f"      Offset: 0x{offset:x}")
        print(f"      Flags: 0x{flags:x}")
        
        if segname == "__TEXT":
            if offset + size <= len(file_data):
                section_ptr = file_data[offset : offset + size]
                if sectname in ("__text", "__TEXT"):
                    instr_ver = get_instruction_set_version(header['cpusubtype'])
                    if instr_ver >= 11 or header['cpusubtype'] == 6:
                        decode_ane_td_m4(section_ptr, header['cpusubtype'], dump_reg_blocks, dump_json)
                    else:
                        decode_ane_td(section_ptr, header['cpusubtype'], dump_reg_blocks, dump_json)
                    if dump_hexdump:
                        hex_dump(sectname, section_ptr, size)
                        
        if segname.startswith("__KERN_"):
            if offset + size <= len(file_data):
                section_ptr = file_data[offset : offset + size]
                print(f"      LUT Data Found (segment {segname}, section {sectname}):")
                decode_lut_coefficients(section_ptr, size, segname)
                if dump_hexdump:
                    hex_dump(sectname, section_ptr, size)
                    
        sect_offset += 80

def handle_symtab(lc_data, cmdsize, file_data, dump_all_symbols):
    sym = struct.unpack_from("<4I", lc_data, 8)
    symoff, nsyms, stroff, strsize = sym[0], sym[1], sym[2], sym[3]
    print(f"  Symbol Table Offset: 0x{symoff:x}")
    print(f"  Num Symbols: {nsyms}")
    print(f"  String Table Offset: 0x{stroff:x}")
    
    if nsyms > 0 and symoff < len(file_data):
        max_syms = nsyms if dump_all_symbols else 5
        if not dump_all_symbols and nsyms > 5:
            print("    (Printing first 5 symbols - use -s to see all)")
        else:
            print(f"    (Printing {max_syms} symbols)")
            
        for k in range(max_syms):
            sym_offset = symoff + k * 16
            if sym_offset + 16 > len(file_data):
                break
            n_strx = struct.unpack_from("<I", file_data, sym_offset)[0]
            n_value = struct.unpack_from("<Q", file_data, sym_offset + 8)[0]
            
            name = ""
            if n_strx < strsize and stroff + n_strx < len(file_data):
                end = stroff + n_strx
                while end < len(file_data) and file_data[end] != 0:
                    end += 1
                name = file_data[stroff + n_strx : end].decode(errors='ignore')
            print(f"    [{k}] {name} @ 0x{n_value:x}")

def handle_thread(cmd_data, cmdsize, dump_threads):
    if not dump_threads:
        return
    internal_offset = 8
    flavor_idx = 0
    while internal_offset + 8 <= cmdsize:
        flavor, count = struct.unpack_from("<2I", cmd_data, internal_offset)
        print(f"  Flavor Set {flavor_idx}: Flavor={flavor} Count={count}")
        flavor_idx += 1
        internal_offset += 8
        print("    State:")
        for k in range(count):
            if internal_offset + 4 > cmdsize:
                break
            val = struct.unpack_from("<I", cmd_data, internal_offset)[0]
            if k % 4 == 0:
                sys.stdout.write(f"      [{k:03d}]:")
            sys.stdout.write(f" 0x{val:08x}")
            if k % 4 == 3 or k == count - 1:
                sys.stdout.write("\n")
            internal_offset += 4

def handle_note(cmd_data, cmdsize, file_data):
    if cmdsize < 32:
        return
    nc = struct.unpack_from("<16s2Q", cmd_data, 8)
    owner = nc[0].split(b'\x00', 1)[0].decode(errors='ignore')
    offset, size = nc[1], nc[2]
    print(f"  Data Owner: {owner}")
    print(f"  Offset: 0x{offset:x}")
    print(f"  Size: 0x{size:x}")
    
    if offset + size <= len(file_data):
        note_data = file_data[offset : offset + size]
        check_len = min(size, 256)
        printable = True
        for k in range(check_len):
            c = note_data[k]
            if c != 0 and (c < 32 or c > 126):
                if c not in (10, 13, 9): # \n, \r, \t
                    printable = False
                    break
        if printable and size > 0:
            text = note_data.decode(errors='ignore')
            print(f"  Content:\n{text}")
        else:
            print("  (Binary Content or too large to verify text)")

def handle_mapped_region(cmd_data, cmdsize):
    print("  (LC_ANE_MAPPED_REGION)")
    count = cmdsize // 4
    if count > 6:
        raw = struct.unpack(f"<{count}I", cmd_data[:count*4])
        region = raw[4]
        str_bytes = cmd_data[24:]
        end_idx = str_bytes.find(b'\x00')
        if end_idx != -1:
            name = str_bytes[:end_idx].decode(errors='ignore')
        else:
            name = str_bytes.decode(errors='ignore')
        print(f"    Region: 0x{region:08x} Name: {name}")

def handle_ident(cmd_data, cmdsize):
    if cmdsize > 8:
        ident_bytes = cmd_data[8:cmdsize]
        end_idx = ident_bytes.find(b'\x00')
        if end_idx != -1:
            ident = ident_bytes[:end_idx].decode(errors='ignore')
        else:
            ident = ident_bytes.decode(errors='ignore')
        print(f"  Ident: {ident}")
    else:
        print("  (Empty Ident)")

def print_macho_headers(data, dump_all_symbols, dump_threads, dump_hexdump, dump_reg_blocks, dump_json):
    if len(data) < 32:
        print("Error: File too small.")
        return
        
    # Mach-O header 64 structure
    magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags = struct.unpack_from("<7I", data, 0)
    
    if magic != HWX_MAGIC:
        print(f"Error: Invalid magic 0x{magic:08x} (Expected 0x{HWX_MAGIC:08x})")
        return
        
    print(f"Magic verified: 0x{magic:08x}")
    print(f"CPU Type: 0x{cputype:04x}")
    print(f"CPU Subtype: 0x{cpusubtype:04x}")
    print(f"File Type: 0x{filetype:04x}")
    print(f"Number of Load Commands: 0x{ncmds:04x}")
    print(f"Size of Load Commands: 0x{sizeofcmds:04x}")
    print(f"Flags: 0x{flags:04x}")
    
    header = {
        'magic': magic,
        'cputype': cputype,
        'cpusubtype': cpusubtype,
        'filetype': filetype,
        'ncmds': ncmds,
        'sizeofcmds': sizeofcmds,
        'flags': flags
    }
    
    offset = 32
    for i in range(ncmds):
        if offset + 8 > len(data):
            print(f"Error: Unexpected EOF reading load command {i}")
            break
            
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        cmd_name = get_cmd_name(cmd)
        cmd_data = data[offset : offset + cmdsize]
        
        print(f"\nLoad Command {i}:")
        print(f"  Cmd: 0x{cmd:x} ({cmd_name})")
        print(f"  Size: {cmdsize}")
        
        if cmd == 0x19: # LC_SEGMENT_64
            if offset + 72 <= len(data):
                handle_segment_64(header, cmd_data, cmdsize, data, dump_hexdump, dump_reg_blocks, dump_json)
        elif cmd == 0x02: # LC_SYMTAB
            handle_symtab(cmd_data, cmdsize, data, dump_all_symbols)
        elif cmd in (0x04, 0x05): # LC_THREAD, LC_UNIXTHREAD
            handle_thread(cmd_data, cmdsize, dump_threads)
        elif cmd == 0x31: # LC_NOTE
            handle_note(cmd_data, cmdsize, data)
        elif cmd == 0x40: # LC_ANE_MAPPED_REGION
            handle_mapped_region(cmd_data, cmdsize)
        elif cmd == 0x08: # LC_IDENT
            handle_ident(cmd_data, cmdsize)
            
        offset += cmdsize

def main():
    parser = argparse.ArgumentParser(description="ANE HWX Parser (M1/M4)")
    parser.add_argument("path", help="Path to .hwx file")
    parser.add_argument("-s", "--symbols", action="store_true", help="Dump all symbol table entries")
    parser.add_argument("-t", "--threads", action="store_true", help="Dump thread states")
    parser.add_argument("-r", "--regs", action="store_true", help="Dump raw register blocks")
    parser.add_argument("-x", "--hex", action="store_true", help="Dump hexdumps of sections")
    parser.add_argument("-j", "--json", action="store_true", help="Output in JSON format")
    parser.add_argument("--subtype", type=int, default=None, help="Force CPU Subtype (for test script compatibility)")
    args = parser.parse_args()
    
    path = args.path
    if not os.path.exists(path):
        print(f"Error reading file: {path}")
        return
        
    with open(path, "rb") as f:
        data = f.read()
        
    # If a subtype is forced by testing scripts, override it in header parsing logic
    if args.subtype is not None and len(data) >= 12:
        # We rewrite the subtype in the parsed Mach-O memory struct so that all downstream functions see it
        # Actually, let's just write it back to data array, or we can handle it in print_macho_headers.
        # Writing it back to data array ensures struct unpacking gets the forced subtype!
        # cpusubtype is at offset 8 (4 bytes)
        data_mut = bytearray(data)
        struct.pack_into("<I", data_mut, 8, args.subtype)
        data = bytes(data_mut)
        
    print_macho_headers(data, args.symbols, args.threads, args.hex, args.regs, args.json)

if __name__ == "__main__":
    main()
