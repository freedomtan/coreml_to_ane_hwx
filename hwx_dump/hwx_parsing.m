#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <stdlib.h>
#include <unistd.h>

#import "ane_hwx_regs.h"

static const char *lookup_reg_name(uint32_t addr, const hwx_reg_range_t *ranges,
                                   int range_count) {
  for (int i = 0; i < range_count; i++) {
    if (addr >= ranges[i].startAddr &&
        addr < ranges[i].startAddr + (ranges[i].count * 4)) {
      uint32_t index = (addr - ranges[i].startAddr) / 4;
      if (index < ranges[i].count) {
        return ranges[i].names[index];
      }
    }
  }
  return NULL;
}

const char *get_m1_reg_name(uint32_t addr) {
  static const char *common_names[] = {
      "InDim", "pad0",    "ChCfg",    "Cin",          "Cout",    "OutDim",
      "pad1",  "ConvCfg", "pad2",     "GroupConvCfg", "TileCfg", "pad3",
      "pad4",  "Cfg",     "TaskInfo", "DPE"};
  static const char *l2_names[] = {"L2Cfg",
                                   "SourceCfg",
                                   "SourceBase",
                                   "SourceChannelStride",
                                   "SourceRowStride",
                                   "pad0",
                                   "pad1",
                                   "pad2",
                                   "pad3",
                                   "pad4",
                                   "pad5",
                                   "pad6",
                                   "ResultCfg",
                                   "ResultBase",
                                   "ConvResultChannelStride",
                                   "ConvResultRowStride"};
  static const char *pe_names[] = {"Cfg", "BiasScale", "PreScale",
                                   "FinalScale"};
  static const char *ne_names[] = {"KernelCfg", "MacCfg", "MatrixVectorBias",
                                   "AccBias", "PostScale"};
  static const char *tdma_src_names[] = {
      "DMAConfig",    "pad0",         "BaseAddr",     "RowStride",
      "PlaneStride",  "DepthStride",  "GroupStride",  "pad1",
      "pad2",         "pad3",         "pad4",         "pad5",
      "pad6",         "pad7",         "Fmt",          "pad8",
      "pad9",         "pad10",        "pad11",        "pad12",
      "PixelOffset0", "PixelOffset1", "PixelOffset2", "PixelOffset3"};
  static const char *tdma_dst_names[] = {
      "DMAConfig",   "BaseAddr",    "RowStride", "PlaneStride",
      "DepthStride", "GroupStride", "Fmt"};
  static const char *kdma_names[] = {"Unknown", "Unknown", "CoeffDMAConfig",
                                     "CoeffBaseAddr", "CoeffBfrSize"};

  static const hwx_reg_range_t m1_ranges[] = {
      {H13_COMMON_START, 16, common_names},
      {H13_L2_START, 16, l2_names},
      {H13_PE_START, 4, pe_names},
      {H13_NE_START, 5, ne_names},
      {H13_TILEDMA_SRC_START, 24, tdma_src_names},
      {H13_TILEDMA_DST_START, 7, tdma_dst_names},
      {H13_KERNELDMA_START, 5, kdma_names},
  };

  return lookup_reg_name(addr, m1_ranges, 7);
}

const char *get_m4_reg_name(uint32_t addr) {
  static const char *common_names[] = {
      "ChannelCfg", "InWidth",   "InHeight",    "InChannels", "InDepth",
      "OutWidth",   "OutHeight", "OutChannels", "OutDepth",   "NumGroups",
      "ConvCfg",    "ConvCfg3d", "UnicastCfg",  "TileHeight", "TileOverlap",
      "MacCfg",     "NECfg",     "PatchCfg",    "PECfg",      "NID",
      "DPE",        "Val21",     "Val22"};
  static const char *l2_names[] = {
      "L2_Control",        "L2_Src1Cfg",        "L2_Src2Cfg",
      "L2_SrcIdxCfg",      "L2_Src1Base",       "L2_Src1CStride",
      "L2_Src1RStride",    "L2_Src1DStride",    "L2_Src1GStride",
      "L2_Src2Base",       "L2_Src2CStride",    "L2_Src2RStride",
      "L2_Src2DStride",    "L2_Src2GStride",    "L2_SrcIdxBase",
      "L2_SrcIdxCStride",  "L2_SrcIdxDStride",  "L2_SrcIdxGStride",
      "L2_ResultCfg",      "L2_ResultBase",     "L2_ResultCStride",
      "L2_ResultRStride",  "L2_ResultDStride",  "L2_ResultGStride",
      "L2_Res24",          "L2_ResultWrapCfg",  "L2_Res26",
      "L2_Res27",          "L2_Res28",          "L2_ResultWrapIdxOff",
      "L2_Res30",          "L2_Result2Base",    "L2_Result2CStride",
      "L2_Result2RStride", "L2_Result2DStride", "PEIndexCfg",
      "L2_Res36",          "L2_Res37",          "L2_Res38",
      "L2_ResultWrapAddr", "L2_CropTex"};
  static const char *pe_names[] = {
      "PE_Config",    "PE_Bias",       "PE_Scale",     "PE_FinalScaleEpsilon",
      "PE_PreScale",  "PE_FinalScale", "PE_LUT1",      "PE_LUT2",
      "PE_LUT3",      "PE_LUT4",       "PE_LUT5",      "PE_LUT6",
      "PE_LUT7",      "PE_LUT8",       "PE_Quant"};
  static const char *ne_names[] = {
      "KernelCfg",   "MacCfg",      "MatrixVectorBias", "NEBias",
      "PostScale",   "RcasConfig", "RoundModeCfg",     "SRSeed[0]",
      "SRSeed[1]",   "SRSeed[2]",  "SRSeed[3]",        "QuantZeroPoint"};
  static const char *cdma_names[] = {
      "CacheDMAControl",  "CacheDMAPre0",      "CacheDMAPre1",
      "CacheDMAPad3",     "CacheDMAPad4",      "CacheDMAPad5",
      "CacheDMADsid",     "CacheDMAFootprint", "EarlyTermArg12",
      "CacheDMAFlushArg", "EarlyTermArg34",    "TelemetryBackOff"};
  static const char *pe_index_names[] = {"PE_IndexCfg"};
  static const char *tdma_src_names[81] = {"Src1DMAConfig",
                                           "Src2DMAConfig",
                                           "Src1WrapCfg",
                                           "Src2WrapCfg",
                                           "Src1BaseAddrLo",
                                           "Src1BaseAddrHi",
                                           "Src1RowStride",
                                           "Src1PlaneStride",
                                           "Src2BaseAddrLo",
                                           "Src1GroupStride",
                                           "Src2BaseAddrHi",
                                           "Src2RowStride",
                                           "Src2PlaneStride",
                                           "Src2GroupStride",
                                           "pad_38",
                                           "pad_3C",
                                           "Src1MetaDataConfig",
                                           "pad_44",
                                           "pad_48",
                                           "pad_4C",
                                           "Src1MetaDataAddrLo",
                                           "Src1MetaDataAddrHi",
                                           "Src1MetaDataSize",
                                           "Src2MetaDataConfig",
                                           "Src2MetaDataAddrLo",
                                           "Src2MetaDataAddrHi",
                                           "Src1FmtMode",
                                           "Src2FmtMode",
                                           "Reserved_0x4D70",
                                           "Reserved_0x4D74",
                                           "Src1CompressedInfo",
                                           "Src1CompressedSizeLo",
                                           "Src1CompressedSizeHi",
                                           "Src1CropOffset",
                                           "Src2CompressedInfo",
                                           "Src2CompressedSizeLo",
                                           "Src2CompressedSizeHi",
                                           "Src2CropOffset",
                                           "Reserved_0x4D98",
                                           "Reserved_0x4D9C",
                                           "Reserved_0x4DA0",
                                           "Reserved_0x4DA4",
                                           "Reserved_0x4DA8",
                                           "Reserved_0x4DAC",
                                           "Reserved_0x4DB0",
                                           "Reserved_0x4DB4",
                                           "Src1WrapDynamic",
                                           "Src2WrapDynamic",
                                           "Src1DependencyOffset",
                                           "Src2DependencyOffset",
                                           "TextureConfig",
                                           "TextureIdxPermute",
                                           "TextureSrcPermute",
                                           "TextureBackgroundVal",
                                           "TextureExtMaxDim1",
                                           "TextureExtMaxDim2",
                                           "TextureExtMaxDim3",
                                           "TextureCropBatchSplitDim1",
                                           "TextureCropDepthDim1",
                                           "TextureCropBatchSplitDim2",
                                           "Reserved_0x4DF0",
                                           "Reserved_0x4DF4",
                                           "Src1Ephemeral",
                                           "Reserved_0x4DFC",
                                           "Reserved_0x4E00",
                                           "TextureCropCoeffVal",
                                           "pad_66",
                                           "pad_67",
                                           "pad_68",
                                           "pad_69",
                                           "pad_70",
                                           "pad_71",
                                           "pad_72",
                                           "pad_73",
                                           "pad_74",
                                           "pad_75",
                                           "pad_76",
                                           "pad_77",
                                           "pad_78",
                                           "pad_79",
                                           "pad_80"};
  static const char *tdma_dst_names[] = {
      "DstDMAConfig",      "pad0",
      "DstBaseAddrLo",     "DstBaseAddrHi",
      "DstRowStride",      "DstPlaneStride",
      "DstDepthStride",    "DstGroupStride",
      "DstInternalCfg",    "pad1",
      "DstMetaDataAddrLo", "DstMetaDataAddrHi",
      "DstFmtMode",        "pad2",
      "DstFmtCtrl",        "pad3",
      "DstCompressedInfo", "pad4",
      "DstCompSizeLo",     "DstCompSizeHi",
      "DstPixelOffset"};
  static const char *kdma_names[72] = {"MasterCfg",
                                       "AlignedCoeffSize",
                                       "Prefetch",
                                       "Reserved[0]",
                                       "Reserved[1]",
                                       "Reserved[2]",
                                       "KernelGroupStride",
                                       "KernelOCGStride",
                                       "CoeffDMAConfig[0]",
                                       "CoeffDMAConfig[1]",
                                       "CoeffDMAConfig[2]",
                                       "CoeffDMAConfig[3]",
                                       "CoeffDMAConfig[4]",
                                       "CoeffDMAConfig[5]",
                                       "CoeffDMAConfig[6]",
                                       "CoeffDMAConfig[7]",
                                       "CoeffDMAConfig[8]",
                                       "CoeffDMAConfig[9]",
                                       "CoeffDMAConfig[10]",
                                       "CoeffDMAConfig[11]",
                                       "CoeffDMAConfig[12]",
                                       "CoeffDMAConfig[13]",
                                       "CoeffDMAConfig[14]",
                                       "CoeffDMAConfig[15]",
                                       "CoeffBaseAddr[0]",
                                       "CoeffBaseAddr[1]",
                                       "CoeffBaseAddr[2]",
                                       "CoeffBaseAddr[3]",
                                       "CoeffBaseAddr[4]",
                                       "CoeffBaseAddr[5]",
                                       "CoeffBaseAddr[6]",
                                       "CoeffBaseAddr[7]",
                                       "CoeffBaseAddr[8]",
                                       "CoeffBaseAddr[9]",
                                       "CoeffBaseAddr[10]",
                                       "CoeffBaseAddr[11]",
                                       "CoeffBaseAddr[12]",
                                       "CoeffBaseAddr[13]",
                                       "CoeffBaseAddr[14]",
                                       "CoeffBaseAddr[15]",
                                       "CoeffBfrSize[0]",
                                       "CoeffBfrSize[1]",
                                       "CoeffBfrSize[2]",
                                       "CoeffBfrSize[3]",
                                       "CoeffBfrSize[4]",
                                       "CoeffBfrSize[5]",
                                       "CoeffBfrSize[6]",
                                       "CoeffBfrSize[7]",
                                       "CoeffBfrSize[8]",
                                       "CoeffBfrSize[9]",
                                       "CoeffBfrSize[10]",
                                       "CoeffBfrSize[11]",
                                       "CoeffBfrSize[12]",
                                       "CoeffBfrSize[13]",
                                       "CoeffBfrSize[14]",
                                       "CoeffBfrSize[15]",
                                       "BiasCfg",
                                       "pad_57",
                                       "pad_58",
                                       "pad_59",
                                       "PSScaleCfg",
                                       "pad_61",
                                       "pad_62",
                                       "pad_63",
                                       "PalCfg",
                                       "pad_65",
                                       "pad_66",
                                       "pad_67",
                                       "NLutCfg",
                                       "pad_69",
                                       "pad_70",
                                       "pad_71"};

  static const hwx_reg_range_t m4_ranges[] = {
      {H16_COMMON_START, 23, common_names},
      {H16_L2_START, 41, l2_names},
      {H16_PE_EXT_START, 1, pe_index_names},
      {H16_PE_START, 15, pe_names},
      {H16_NE_START, 12, ne_names},
      {H16_CACHEDMA_START, 12, cdma_names},
      {H16_TILEDMA_SRC_START, 81, tdma_src_names},
      {H16_TILEDMA_DST_START, 21, tdma_dst_names},
      {H16_KERNELDMA_START, 72, kdma_names},
  };

  return lookup_reg_name(addr, m4_ranges, 9);
}

void dump_hw_blocks(const hwx_state_t *state, const hwx_block_info_t *blocks,
                    int count, const char *(*name_lookup)(uint32_t)) {
  printf("        --- HW Block Register State ---\n");
  for (int b = 0; b < count; b++) {
    bool printed_header = false;
    uint32_t word_start = blocks[b].startAddr / 4;
    uint32_t word_end = word_start + blocks[b].count;

    for (uint32_t r = word_start; r < word_end; r++) {
      if (state->valid[r]) {
        if (!printed_header) {
          printf("        %s:\n", blocks[b].name);
          printed_header = true;
        }
        uint32_t addr = r * 4;
        const char *reg_name = name_lookup(addr);
        if (reg_name) {
          printf("          0x%05x: 0x%08x (%s)\n", addr, state->values[r],
                 reg_name);
        } else {
          printf("          0x%05x: 0x%08x\n", addr, state->values[r]);
        }
      }
    }
  }
}

const char *get_arch_name(uint32_t subtype) {
  switch (subtype) {
  case 1:
    return "H11 (A12)";
  case 3:
    return "H12 (A13)";
  case 4:
    return "H13 (A14/M1)";
  case 5:
    return "H14 (A15/M2)";
  case 6:
    return "H15 (A16/M3)";
  case 7:
    return "H16 (A17 Pro/M4)";
  case 9:
    return "H17 (A18 Pro/M5)";
  case 10:
    return "H18 (A19)";
  default:
    return "Unknown Architecture";
  }
}

uint32_t get_instruction_set_version(uint32_t subtype) {
  switch (subtype) {
  case 1:
    return 5;
  case 3:
    return 6;
  case 4:
    return 7;
  case 5:
    return 11;
  case 6:
    return 8;
  case 7:
    return 17;
  case 9:
    return 19;
  case 10:
    return 20;
  default:
    return 0;
  }
}

static float decode_f19(uint32_t val) {
  uint32_t bits = (val & 0x7FFFF) << 13;
  return *(float *)&bits;
}

const char *get_ch_fmt_name(uint32_t fmt) {
  switch (fmt) {
  case 0:
    return "INT8";
  case 1:
    return "UINT8";
  case 2:
    return "FLOAT16";
  case 3:
    return "Unknown";
  default:
    return "Unknown";
  }
}

const char *get_ne_op_mode_name(uint32_t mode) {
  switch (mode) {
  case 0: return "Conv";
  case 1: return "ElemWise";
  case 2: return "unknown";
  case 3: return "EWSqr";
  case 4: return "EWMult";
  case 5: return "RCAS";
  case 6: return "Bypass";
  case 7: return "TransposedConv";
  default: return "Invalid";
  }
}

void print_common_h13(const hwx_state_t *state) {
  printf("        --- Common (0x0000) ---\n");
  const ane_common_h13_t *common =
      (const ane_common_h13_t *)&state->values[H13_COMMON_START / 4];

  uint16_t win = common->indim.w_in;
  uint16_t hin = common->indim.h_in;
  uint32_t cin = common->cin.c_in;

  uint16_t wout = common->outdim.w_out;
  uint16_t hout = common->outdim.h_out;
  uint32_t cout = common->cout.c_out;

  const char *infmt_name = get_ch_fmt_name(common->chcfg.infmt);
  const char *outfmt_name = get_ch_fmt_name(common->chcfg.outfmt);

  printf("        %u x %u x %u (%s) -> %u x %u x %u (%s)\n", win, hin, cin,
         infmt_name, wout, hout, cout, outfmt_name);

  if (common->convcfg.kw != 0 || common->convcfg.kh != 0) {
    printf("        ConvCfg: K=%ux%u S=%ux%u P=%ux%u\n", common->convcfg.kw,
           common->convcfg.kh, common->convcfg.sx, common->convcfg.sy,
           common->convcfg.px, common->convcfg.py);

    printf("        GroupConvCfg: Groups=%u UnicastEn=%d ElemMult=%d "
           "UnicastCin=%u\n",
           common->groupcfg.num_groups, common->groupcfg.unicast_en,
           common->groupcfg.elem_mult_mode, common->groupcfg.unicast_cin);
  }

  printf("        Cfg: ActiveNE=%u SmallSrc=%u ShPref=%u ShMin=%u ShMax=%u "
         "AccDB=%u\n",
         common->cfg.active_ne, common->cfg.small_src_mode, common->cfg.sh_pref,
         common->cfg.sh_min, common->cfg.sh_max, common->cfg.acc_db_buf_en);

  printf("        TaskInfo: TID=0x%04x Q=%u NID=0x%02x\n",
         common->task_info.tid, common->task_info.task_q,
         common->task_info.task_nid);
}

void print_l2_h13(const hwx_state_t *state) {
  printf("        --- L2 (0x4800) ---\n");
  const ane_l2_h13_t *l2 =
      (const ane_l2_h13_t *)&state->values[H13_L2_START / 4];
  printf("        L2Cfg: InputReLU=%d PaddingMode=%u\n", l2->l2cfg.input_relu,
         l2->l2cfg.padding_mode);
  printf("        L2 SourceCfg: Type=%u Dep=%u Fmt=%u Intrlv=%u CmpV=%u "
         "OffCh=%u\n",
         l2->scfg.type, l2->scfg.dep, l2->scfg.fmt, l2->scfg.interleave,
         l2->scfg.cmpv, l2->scfg.offch);
  printf("        L2 Src1: Base=0x%05x ChanStride=0x%05x RowStride=0x%05x\n",
         l2->srcbase.addr, l2->src_chan_stride.stride,
         l2->src_row_stride.stride);

  printf("        L2 ResultCfg: Type=%u Bfr=%u Fmt=%u Intrlv=%u CmpV=%u "
         "OffCh=%u\n",
         l2->rcfg.type, l2->rcfg.bfrmode, l2->rcfg.fmt, l2->rcfg.interleave,
         l2->rcfg.cmpv, l2->rcfg.offch);
}

void print_ne_h13(const hwx_state_t *state) {
  printf("        --- Neural Engine (0xC800) ---\n");
  const ane_ne_h13_t *ne =
      (const ane_ne_h13_t *)&state->values[H13_NE_START / 4];
  printf("        NE MacCfg: OpMode=%u NLMode=%u KernelMode=%d BiasMode=%d "
         "BinaryPoint=%u\n",
         ne->mac_cfg.op_mode, ne->mac_cfg.non_linear_mode,
         ne->mac_cfg.kernel_mode, ne->mac_cfg.bias_mode,
         ne->mac_cfg.binary_point);
  printf("        NE KernelCfg: Fmt=%s PalettizedEn=%d PalettizeBits=%u "
         "SparseFmt=%d GroupKernelReuse=%d\n",
         get_ch_fmt_name(ne->kernel_cfg.kernel_fmt),
         ne->kernel_cfg.palettized_en, ne->kernel_cfg.palettized_bits,
         ne->kernel_cfg.sparse_fmt, ne->kernel_cfg.group_kernel_reuse);
  printf("        NE MatrixVectorBias: 0x%04x\n",
         ne->matrix_vector_bias.matrix_vector_bias);
  printf("        NE AccBias: 0x%04x Shift=%u\n", ne->acc_bias.acc_bias,
         ne->acc_bias.acc_bias_shift);
  printf("        NE PostScale: 0x%04x RightShift=%u\n",
         ne->post_scale.post_scale, ne->post_scale.post_scale_right_shift);
}

void print_pe_h13(const hwx_state_t *state) {
  const ane_pe_h13_t *pe =
      (const ane_pe_h13_t *)&state->values[H13_PE_START / 4];
  if (state->valid[H13_PE_START / 4]) {
    printf("        --- Planar Engine (0x8800) ---\n");
    printf("        PECfg: En=%d OpMode=%u ReluEn=%d Cond=%u FirstSrc=%u "
           "SecondSrc=%u\n",
           pe->cfg.enable, pe->cfg.op_mode, pe->cfg.relu_en, pe->cfg.cond,
           pe->cfg.first_source, pe->cfg.second_source);
    printf("        PEBiasScale: Bias=0x%04x Scale=0x%04x\n",
           pe->bias_scale.bias, pe->bias_scale.scale);
    printf("        PEPreScale: 0x%04x PEFinalScale: 0x%08x\n",
           pe->pre_scale.pre_scale, pe->final_scale.final_scale);
  }
}

void print_tiledmasrc_h13(const hwx_state_t *state) {
  const ane_tiledmasrc_h13_t *tsrc =
      (const ane_tiledmasrc_h13_t *)&state->values[H13_TILEDMA_SRC_START / 4];
  printf("        --- TileDMASrc (0x13800) ---\n");
  printf("        Src1DMAConfig: En=%d CacheHint=%u DepMode=%u\n",
         tsrc->src_dma_config.en, tsrc->src_dma_config.cache_hint,
         tsrc->src_dma_config.dep_mode);
  printf("        Src1Strides: Base=0x%05x Row=0x%05x Plane=0x%05x "
         "Depth=0x%05x Group=0x%05x\n",
         tsrc->base_addr.addr, tsrc->row_stride.stride,
         tsrc->plane_stride.stride, tsrc->depth_stride.stride,
         tsrc->group_stride.stride);

  printf("        Src1Fmt: FmtMode=%u Trunc=%u Shift=%u MemFmt=%u "
         "OffCh=%u Intrlv=%u CmpV=%u\n",
         tsrc->fmt.fmt_mode, tsrc->fmt.truncate, tsrc->fmt.shift,
         tsrc->fmt.mem_fmt, tsrc->fmt.offset_ch, tsrc->fmt.interleave,
         tsrc->fmt.cmp_vec);
}

void print_tiledmadst_h13(const hwx_state_t *state) {
  const ane_tiledmadst_h13_t *tdst =
      (const ane_tiledmadst_h13_t *)&state->values[H13_TILEDMA_DST_START / 4];
  printf("        --- TileDMADst (0x17800) ---\n");
  printf("        DstDMAConfig: En=%d CacheHint=%u L2BfrMode=%d "
         "BypassEOW=%d\n",
         tdst->dst_dma_config.en, tdst->dst_dma_config.cache_hint,
         tdst->dst_dma_config.l2bfrmode, tdst->dst_dma_config.bypass_eow);
  printf("        DstStrides: Base=0x%05x Row=0x%05x Plane=0x%05x "
         "Depth=0x%05x Group=0x%05x\n",
         tdst->base_addr.addr, tdst->row_stride.stride,
         tdst->plane_stride.stride, tdst->depth_stride.stride,
         tdst->group_stride.stride);

  printf("        DstFmt: FmtMode=%u Trunc=%u Shift=%u MemFmt=%u "
         "OffCh=%u ZPLast=%d ZPFirst=%d Fill=%d Intrlv=%u CmpV=%u\n",
         tdst->fmt.fmt_mode, tdst->fmt.truncate, tdst->fmt.shift,
         tdst->fmt.mem_fmt, tdst->fmt.offset_ch, tdst->fmt.zero_pad_last,
         tdst->fmt.zero_pad_first, tdst->fmt.cmp_vec_fill, tdst->fmt.interleave,
         tdst->fmt.cmp_vec);
}

void print_kerneldmasrc_h13(const hwx_state_t *state) {
  const ane_kerneldmasrc_h13_t *k =
      (const ane_kerneldmasrc_h13_t *)&state->values[H13_KERNELDMA_START / 4];
  printf("        --- KernelDMASrc (0x1F800) ---\n");
  for (int i = 0; i < 16; i++) {
    if (k->coeff_dma_config[i].en) {
      printf("        Coeff[%d]: En=%d CacheHint=%u Base=0x%08x Size=0x%08x\n",
             i, k->coeff_dma_config[i].en, k->coeff_dma_config[i].cache_hint,
             k->coeff_base_addr[i].addr, k->coeff_bfr_size[i]);
    }
  }
}

void print_common_h16(const hwx_state_t *state) {
  printf("        --- Common (0x0000) ---\n");
  ane_common_h16_t common =
      *(ane_common_h16_t *)&state->values[H16_COMMON_START / 4];

  if (state->valid[(H16_COMMON_START + 0x04) / 4] ||
      state->valid[(H16_COMMON_START + 0x08) / 4] ||
      state->valid[(H16_COMMON_START + 0x0C) / 4] ||
      state->valid[(H16_COMMON_START + 0x10) / 4]) {
    const char *infmt_name = get_ch_fmt_name(common.ch_cfg.infmt);
    const char *src2fmt_name = get_ch_fmt_name(common.ch_cfg.src2infmt);
    printf("        InDim     : W=%u H=%u C=%u D=%u Type=%s (Src2Type=%s)\n",
           common.inwidth, common.inheight, common.inchannels, common.indepth,
           infmt_name, src2fmt_name);
  }

  if (state->valid[(H16_COMMON_START + 0x14) / 4] ||
      state->valid[(H16_COMMON_START + 0x18) / 4] ||
      state->valid[(H16_COMMON_START + 0x1C) / 4] ||
      state->valid[(H16_COMMON_START + 0x20) / 4]) {
    const char *outfmt_name = get_ch_fmt_name(common.ch_cfg.outfmt);
    printf("        OutDim    : W=%u H=%u C=%u D=%u Type=%s\n", common.outwidth,
           common.outheight, common.outchannels, common.outdepth, outfmt_name);
  }

  if (state->valid[(H16_COMMON_START + 0x24) / 4]) {
    printf("        NumGroups : %u\n", common.num_groups);
  }

  if (state->valid[(H16_COMMON_START + 0x28) / 4]) {
    printf("        ConvCfg   : K=%ux%u S=%ux%u P(left/top)=%ux%u O=%ux%u\n",
           common.conv_cfg.kw, common.conv_cfg.kh, common.conv_cfg.sx,
           common.conv_cfg.sy, common.conv_cfg.pad_left,
           common.conv_cfg.pad_top, common.conv_cfg.ox, common.conv_cfg.oy);
  }

  if (state->valid[(H16_COMMON_START + 0x2C) / 4]) {
    uint32_t v = state->values[(H16_COMMON_START + 0x2C) / 4];
    printf("        ConvCfg3D : 0x%08x (Kd=%u Sz=%u Pz=%u Oz=%u)\n", v,
           common.conv_cfg_3d.kd, common.conv_cfg_3d.sz, common.conv_cfg_3d.pz,
           common.conv_cfg_3d.oz);
  }

  if (state->valid[(H16_COMMON_START + 0x30) / 4]) {
    printf("        Unicast   : Cin=%u En=%d\n", common.unicast_cfg.unicast_cin,
           common.unicast_cfg.unicast_en);
  }

  if (state->valid[(H16_COMMON_START + 0x34) / 4]) {
    printf("        TileHeight: %u\n", common.tile_height);
  }

  if (state->valid[(H16_COMMON_START + 0x38) / 4]) {
    printf("        TileOverlap: %u (Top=%u Bottom=%u)\n",
           common.tile_overlap.overlap, common.tile_overlap.pad_top,
           common.tile_overlap.pad_bottom);
  }

  if (state->valid[(H16_COMMON_START + 0x3C) / 4]) {
    printf("        MacCfg    : ActiveNE=%u SmallSrc=%u TaskType=%u "
           "OutTrans=%d FillLowerNE=%d\n",
           common.maccfg.active_ne, common.maccfg.small_src_mode,
           common.maccfg.task_type, common.maccfg.out_trans,
           common.maccfg.fill_lower_ne);
  }

  if (state->valid[(H16_COMMON_START + 0x40) / 4]) {
    printf("        NECfg     : OCGSize=%u FatTileEn=%d WUStack=%u\n",
           common.ne_cfg.ocg_size, common.ne_cfg.fat_tile_en,
           common.ne_cfg.wustack_log2);
  }

  if (state->valid[(H16_COMMON_START + 0x44) / 4]) {
    printf("        PatchCfg  : PW=%u PH=%u\n", common.patch_cfg.patch_width,
           common.patch_cfg.patch_height);
  }

  if (state->valid[(H16_COMMON_START + 0x48) / 4]) {
    printf("        PECfg     : S1BR=%d S2BR=%d S1T=%d S2T=%d OutTrans=%d\n",
           common.pe_cfg.src1_br, common.pe_cfg.src2_br,
           common.pe_cfg.src1_trans, common.pe_cfg.src2_trans,
           common.pe_cfg.out_trans);
  }

  if (state->valid[(H16_COMMON_START + 0x4C) / 4])
    printf("        NID       : 0x%08x\n", common.nid);
  if (state->valid[(H16_COMMON_START + 0x50) / 4])
    printf("        DPE       : 0x%08x\n", common.dpe);
  if (state->valid[(H16_COMMON_START + 0x54) / 4])
    printf("        Val21     : 0x%08x\n", common.val_21);
  if (state->valid[(H16_COMMON_START + 0x58) / 4])
    printf("        Val22     : 0x%08x\n", common.val_22);
}

void print_ne_h16(const hwx_state_t *state) {
  ane_ne_h16_t ne = *(ane_ne_h16_t *)&state->values[H16_NE_START / 4];
  printf("        --- Neural Engine (0x4900) ---\n");

  if (state->valid[H16_NE_START / 4]) {
    printf("        KernelCfg: Fmt=%s Palettized=%d (%dbit) SparseEn=%d "
           "GroupKernelReuse=%d AlignmentFmt=%d "
           "AsymQuant=%d\n",
           get_ch_fmt_name(ne.kernel_cfg.kernel_fmt),
           ne.kernel_cfg.palettized_en, ne.kernel_cfg.palettized_bits,
           ne.kernel_cfg.sparse_en, ne.kernel_cfg.group_kernel_reuse,
           ne.kernel_cfg.kernel_align_fmt, ne.kernel_cfg.asym_quant_en);
  }

  if (state->valid[(H16_NE_START + 0x4) / 4]) {
    printf("        MacCfg: OpMode=%s KernelMode=%d BiasEn=%d Passthrough=%d "
           "MVBiasEn=%d BinaryPoint=%u PostScaleEn=%d NonLinear=%d\n"
           "                PaddingMode=%d MaxPoolMode=%d "
           "ArgOutputSelect=%d "
           "DoubleInt8En=%d\n",
           get_ne_op_mode_name(ne.mac_cfg.op_mode), ne.mac_cfg.kernel_mode,
           ne.mac_cfg.ne_bias_en,
           ne.mac_cfg.passthrough_en, ne.mac_cfg.matrix_bias_en,
           ne.mac_cfg.binary_point, ne.mac_cfg.post_scale_en,
           ne.mac_cfg.non_linear_mode, ne.mac_cfg.padding_mode,
           ne.mac_cfg.max_pool_mode, ne.mac_cfg.arg_output_select,
           ne.mac_cfg.double_int8_en);
  }

  if (state->valid[(H16_NE_START + 0x8) / 4])
    printf("        MatrixBias: 0x%04x\n", ne.matrix_bias.matrix_vector_bias);
  if (state->valid[(H16_NE_START + 0x0c) / 4])
    printf("        NEBias: 0x%06x\n", ne.ne_bias.val);
  if (state->valid[(H16_NE_START + 0x10) / 4])
    printf("        PostScale: 0x%06x\n", ne.post_scale.val);

  if (state->valid[(H16_NE_START + 0x14) / 4]) {
    printf("        RcasConfig: KeyMask=0x%02x CmpBit=%d SenseAxis=%d "
           "SenseBit=%d Mode=%d\n",
           ne.rcas_cfg.key_mask, ne.rcas_cfg.cmp_bit, ne.rcas_cfg.sense_axis,
           ne.rcas_cfg.sense_bit, ne.rcas_cfg.mode);
  }

  if (state->valid[(H16_NE_START + 0x18) / 4]) {
    printf("        RoundModeCfg: Mode=%d IntegerBits=%d\n",
           ne.st_round_cfg.round_mode, ne.st_round_cfg.integer_bits);
  }

  if (state->valid[(H16_NE_START + 0x1c) / 4]) {
    printf("        SRSeeds: 0x%08x 0x%08x 0x%08x 0x%08x\n",
           ne.st_round_seed[0], ne.st_round_seed[1], ne.st_round_seed[2],
           ne.st_round_seed[3]);
  }

  if (state->valid[(H16_NE_START + 0x2c) / 4])
    printf("        QuantZeroPoint: %d\n", ne.quant.quant_zero_point);
}

void print_pe_h16(const hwx_state_t *state) {
  ane_pe_h16_t pe = *(ane_pe_h16_t *)&state->values[H16_PE_START / 4];
  printf("        --- Planar Engine (0x4500) ---\n");

  if (state->valid[H16_PE_START / 4]) {
    static const char *pe_op_names[] = {"None", "Add", "Mul", "Min", "Max",
                                        "5?",   "6?",  "7?"};
    printf("        PE Config : Pool=%u Op=%u(%s) LutEn=%u Cond=%u RedIdx=%u RedKeep=%u NLMode=%u Src1=%u Src2=%u\n",
           pe.pe_cfg.pool_mode, pe.pe_cfg.op, pe_op_names[pe.pe_cfg.op & 7],
           pe.pe_cfg.lut_en, pe.pe_cfg.cond, pe.pe_cfg.red_idx,
           pe.pe_cfg.red_keep, pe.pe_cfg.nl_mode, pe.pe_cfg.src1, pe.pe_cfg.src2);
  }
  if (state->valid[(H16_PE_START + 0x4) / 4])
    printf("        PE Bias   : 0x%05x (%f)\n", pe.bias & 0x7FFFF,
           decode_f19(pe.bias));
  if (state->valid[(H16_PE_START + 0x8) / 4])
    printf("        PE Scale  : 0x%05x (%f)\n", pe.scale & 0x7FFFF,
           decode_f19(pe.scale));
  if (state->valid[(H16_PE_START + 0x0c) / 4])
    printf("        PE Final Scale Epsilon : 0x%05x (%f)\n",
           pe.final_scale_epsilon & 0x7FFFF, decode_f19(pe.final_scale_epsilon));
  if (state->valid[(H16_PE_START + 0x10) / 4])
    printf("        PE PreScale  : 0x%05x (%f)\n", pe.pre_scale & 0x7FFFF,
           decode_f19(pe.pre_scale));
  if (state->valid[(H16_PE_START + 0x14) / 4])
    printf("        PE Final Scale : 0x%05x (%f)\n", pe.final_scale & 0x7FFFF,
           decode_f19(pe.final_scale));
  for (int i = 0; i < 8; i++) {
    if (state->valid[(H16_PE_START + 0x18 + i * 4) / 4])
      printf("        PE LUT%d    : 0x%08x\n", i + 1, pe.lut[i]);
  }
  if (state->valid[(H16_PE_START + 0x38) / 4]) {
    printf("        PE Quant  : Src1Off=%u Src2Off=%u OutZP=%u\n",
           pe.quant.src1_in_off, pe.quant.src2_in_off, pe.quant.out_zp);
  }
}

void print_pe_index_h16(const hwx_state_t *state) {
  uint32_t addr = H16_PE_EXT_START;
  if (!state->valid[addr / 4])
    return;
  ane_pe_index_h16_t idx = *(ane_pe_index_h16_t *)&state->values[addr / 4];
  printf("        --- PE Indexing ---\n");
  printf("        PE IndexCfg: MaxIndex=%d Enable=%d\n",
         idx.pe_index_cfg.max_index, idx.pe_index_cfg.indexing_en);
}

void print_l2_h16(const hwx_state_t *state) {
  ane_l2_h16_t l2 = *(ane_l2_h16_t *)&state->values[H16_L2_START / 4];
  printf("        --- L2 (0x4100) ---\n");

  if (state->valid[H16_L2_START / 4]) {
    printf("        L2Control: Src1ReLU=%d Src2ReLU=%d Padding=%d "
           "Src1Double=%d Barrier=%d\n",
           l2.l2_control.src1_relu, l2.l2_control.src2_relu,
           l2.l2_control.padding_mode, l2.l2_control.src1_double,
           l2.l2_control.barrier);
  }
  if (state->valid[(H16_L2_START + 0x04) / 4]) {
    printf("        Src1Cfg  : Type=%d Dep=%d Alias(C=%d, R=%d) Fmt=%d "
           "Intrlv=%d Comp=%d Planar(S=%d, R=%d)\n",
           l2.src1_cfg.src_type, l2.src1_cfg.dependent,
           l2.src1_cfg.alias_conv_src, l2.src1_cfg.alias_conv_rslt,
           l2.src1_cfg.dma_fmt, l2.src1_cfg.interleave,
           l2.src1_cfg.compression, l2.src1_cfg.alias_planar_src,
           l2.src1_cfg.alias_planar_rslt);
  }
  if (state->valid[(H16_L2_START + 0x08) / 4]) {
    printf("        Src2Cfg  : Type=%d Dep=%d Alias(C=%d, R=%d) Fmt=%d "
           "Intrlv=%d Comp=%d Planar(S=%d, R=%d)\n",
           l2.src2_cfg.src_type, l2.src2_cfg.dependent,
           l2.src2_cfg.alias_conv_src, l2.src2_cfg.alias_conv_rslt,
           l2.src2_cfg.dma_fmt, l2.src2_cfg.interleave,
           l2.src2_cfg.compression, l2.src2_cfg.alias_planar_src,
           l2.src2_cfg.alias_planar_rslt);
  }
  if (state->valid[(H16_L2_START + 0x0c) / 4]) {
    printf(
        "        SrcIdxCfg: Type=%d Dep=%d Alias(C=%d, R=%d, PS=%d, PR=%d) Fmt=%d B27=%d\n",
        l2.srcidx_cfg.src_type, l2.srcidx_cfg.dependent,
        l2.srcidx_cfg.alias_conv_src, l2.srcidx_cfg.alias_conv_rslt,
        l2.srcidx_cfg.alias_planar_src, l2.srcidx_cfg.alias_planar_rslt,
        l2.srcidx_cfg.dma_fmt, l2.srcidx_cfg.bit27);
  }

  // --- Src1 Block ---
  if (state->valid[(H16_L2_START + 0x10) / 4] || state->valid[(H16_L2_START + 0x14) / 4] ||
      state->valid[(H16_L2_START + 0x18) / 4] || state->valid[(H16_L2_START + 0x1c) / 4] ||
      state->valid[(H16_L2_START + 0x20) / 4]) {
    printf("        Src1     :");
    if (state->valid[(H16_L2_START + 0x10) / 4]) printf(" Base=0x%05x", l2.src1.base);
    if (state->valid[(H16_L2_START + 0x14) / 4]) printf(" CS=0x%05x", l2.src1.channel_stride);
    if (state->valid[(H16_L2_START + 0x18) / 4]) printf(" RS=0x%05x", l2.src1.row_stride);
    if (state->valid[(H16_L2_START + 0x1c) / 4]) printf(" DS=0x%05x", l2.src1.depth_stride);
    if (state->valid[(H16_L2_START + 0x20) / 4]) printf(" GS=0x%05x", l2.src1.group_stride);
    printf("\n");
  }

  // --- Src2 Block ---
  if (state->valid[(H16_L2_START + 0x24) / 4] || state->valid[(H16_L2_START + 0x28) / 4] ||
      state->valid[(H16_L2_START + 0x2c) / 4] || state->valid[(H16_L2_START + 0x30) / 4] ||
      state->valid[(H16_L2_START + 0x34) / 4]) {
    printf("        Src2     :");
    if (state->valid[(H16_L2_START + 0x24) / 4]) printf(" Base=0x%05x", l2.src2.base);
    if (state->valid[(H16_L2_START + 0x28) / 4]) printf(" CS=0x%05x", l2.src2.channel_stride);
    if (state->valid[(H16_L2_START + 0x2c) / 4]) printf(" RS=0x%05x", l2.src2.row_stride);
    if (state->valid[(H16_L2_START + 0x30) / 4]) printf(" DS=0x%05x", l2.src2.depth_stride);
    if (state->valid[(H16_L2_START + 0x34) / 4]) printf(" GS=0x%05x", l2.src2.group_stride);
    printf("\n");
  }

  // --- SrcIdx Block ---
  if (state->valid[(H16_L2_START + 0x38) / 4] || state->valid[(H16_L2_START + 0x3c) / 4] ||
      state->valid[(H16_L2_START + 0x40) / 4] || state->valid[(H16_L2_START + 0x44) / 4]) {
    printf("        SrcIdx   :");
    if (state->valid[(H16_L2_START + 0x38) / 4]) printf(" Base=0x%05x", l2.srcidx.base);
    if (state->valid[(H16_L2_START + 0x3c) / 4]) printf(" CS=0x%05x", l2.srcidx.channel_stride);
    if (state->valid[(H16_L2_START + 0x40) / 4]) printf(" DS=0x%05x", l2.srcidx.depth_stride);
    if (state->valid[(H16_L2_START + 0x44) / 4]) printf(" GS=0x%05x", l2.srcidx.group_stride);
    printf("\n");
  }

  if (state->valid[(H16_L2_START + 0x48) / 4]) {
    printf("        ResCfg   : Type=%d Bfr=%d Alias(S=%d, R=%d) Fmt=%d "
           "Intrlv=%d Comp=%d\n",
           l2.result_cfg.res_type, l2.result_cfg.bfr_mode,
           l2.result_cfg.src_alias, l2.result_cfg.result_alias,
           l2.result_cfg.dma_fmt, l2.result_cfg.interleave,
           l2.result_cfg.compression);
  }

  // --- Result Block ---
  if (state->valid[(H16_L2_START + 0x4c) / 4] || state->valid[(H16_L2_START + 0x50) / 4] ||
      state->valid[(H16_L2_START + 0x54) / 4] || state->valid[(H16_L2_START + 0x58) / 4] ||
      state->valid[(H16_L2_START + 0x5c) / 4]) {
    printf("        Result   :");
    if (state->valid[(H16_L2_START + 0x4c) / 4]) printf(" Base=0x%05x", l2.result.base);
    if (state->valid[(H16_L2_START + 0x50) / 4]) printf(" CS=0x%05x", l2.result.channel_stride);
    if (state->valid[(H16_L2_START + 0x54) / 4]) printf(" RS=0x%05x", l2.result.row_stride);
    if (state->valid[(H16_L2_START + 0x58) / 4]) printf(" DS=0x%05x", l2.result.depth_stride);
    if (state->valid[(H16_L2_START + 0x5c) / 4]) printf(" GS=0x%05x", l2.result.group_stride);
    printf("\n");
  }

  // Dump intermediate "Res" registers if valid
  if (state->valid[(H16_L2_START + 0x60) / 4])
     printf("        L2_Res24 : 0x%08x\n", l2.l2_res24);
  
  for (int i=0; i<3; i++) {
    if (state->valid[(H16_L2_START + 0x64 + i*4) / 4]) {
       printf("        WrapCfg[%d]: Blocks=%d Len=0x%05x\n", i,
              l2.wrap_cfg[i].wrap_num_blocks, l2.wrap_cfg[i].wrap_len);
    }
  }

  if (state->valid[(H16_L2_START + 0x70) / 4])
     printf("        L2_Res28 : 0x%08x\n", l2.l2_res28);

  if (state->valid[(H16_L2_START + 0x74) / 4]) {
    printf("        ResultWrap: Mask=0x%x StartOffset=0x%x\n",
           l2.result_wrap_idx_off.wrap_index_mask,
           l2.result_wrap_idx_off.wrap_start_offset);
  }
  
  if (state->valid[(H16_L2_START + 0x78) / 4])
     printf("        L2_Res30 : 0x%08x\n", l2.l2_res30);

  // --- Result2 Block ---
  if (state->valid[(H16_L2_START + 0x7c) / 4] || state->valid[(H16_L2_START + 0x80) / 4] ||
      state->valid[(H16_L2_START + 0x84) / 4] || state->valid[(H16_L2_START + 0x88) / 4]) {
    printf("        Result2  :");
    if (state->valid[(H16_L2_START + 0x7c) / 4]) printf(" Base=0x%05x", l2.result2.base);
    if (state->valid[(H16_L2_START + 0x80) / 4]) printf(" CS=0x%05x", l2.result2.channel_stride);
    if (state->valid[(H16_L2_START + 0x84) / 4]) printf(" RS=0x%05x", l2.result2.row_stride);
    if (state->valid[(H16_L2_START + 0x88) / 4]) printf(" DS=0x%05x", l2.result2.depth_stride);
    printf("\n");
  }

  if (state->valid[(H16_L2_START + 0x8c) / 4]) {
    printf("        PEIndex  : Trans=%d Mode=%d MaxIdx=%d\n",
           l2.pe_index_cfg.transpose, l2.pe_index_cfg.mode,
           l2.pe_index_cfg.max_index);
  }

  if (state->valid[(H16_L2_START + 0x90) / 4])
     printf("        L2_Res36 : 0x%08x\n", l2.l2_res36);
  if (state->valid[(H16_L2_START + 0x94) / 4])
     printf("        L2_Res37 : 0x%08x\n", l2.l2_res37);
  if (state->valid[(H16_L2_START + 0x98) / 4])
     printf("        L2_Res38 : 0x%08x\n", l2.l2_res38);

  if (state->valid[(H16_L2_START + 0x9c) / 4]) {
    printf("        ResultWrapIdx: Addr=0x%x\n", l2.wrap_addr);
  }
  if (state->valid[(H16_L2_START + 0xa0) / 4]) {
    printf("        CropTex   : S1X=%d S1Y=%d S2X=%d S2Y=%d\n", l2.crop_tex.s1x,
           l2.crop_tex.s1y, l2.crop_tex.s2x, l2.crop_tex.s2y);
  }
}

void print_tiledmasrc_h16(const hwx_state_t *state) {
  const ane_tiledmasrc_h16_t *src =
      (const ane_tiledmasrc_h16_t *)&state->values[H16_TILEDMA_SRC_START / 4];
  printf("        --- TileDMASrc (0x4D00) ---\n");
  if (state->valid[H16_TILEDMA_SRC_START / 4]) {
    printf("        Src1DMAConfig: En=%d DSID=%u Tag=%u DepInt=%u\n",
           src->src1cfg.en, src->src1cfg.dataset_id, src->src1cfg.user_tag,
           src->src1cfg.dep_interval);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x04) / 4]) {
    printf("        Src2DMAConfig: En=%d DSID=%u Tag=%u DepMode=%u\n",
           src->src2cfg.en, src->src2cfg.dataset_id, src->src2cfg.user_tag,
           src->src2cfg.dep_mode);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x18) / 4]) {
    printf("        Src1Strides: Row=0x%x Plane=0x%x Depth=0x%x Group=0x%x\n",
           src->src1row_stride, src->src1plane_stride, 0,
           src->src1group_stride);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x2C) / 4]) {
    printf("        Src2Strides: Row=0x%x Plane=0x%x Depth=0x%x Group=0x%x\n",
           src->src2row_stride, src->src2plane_stride, 0,
           src->src2group_stride);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x40) / 4]) {
    printf("        Src1MetaCfg: 0x%08x\n", src->src1metadataconfig);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x50) / 4]) {
    printf("        Src1MetaData: Addr=0x%08x%08x Size=0x%x\n",
           src->src1meta_hi, src->src1meta_lo, src->src1meta_size);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x5C) / 4]) {
    printf("        Src2MetaCfg: 0x%08x\n", src->src2metadataconfig);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x60) / 4]) {
    printf("        Src2MetaData: Addr=0x%08x%08x\n", src->src2meta_hi,
           src->src2meta_lo);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x68) / 4]) {
    printf("        Src1Fmt: 0x%08x, Src2Fmt: 0x%08x\n", src->src1memfmt,
           src->src2memfmt);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x78) / 4]) {
    printf("        Src1Comp: En=%d MBS=%d PF=%d Lossy=%d MdTag=0x%02x Size=0x%x%08x Crop=0x%x\n",
           src->src1compinfo.compressed_enable,
           src->src1compinfo.macroblock_size,
           src->src1compinfo.packing_format,
           src->src1compinfo.lossy_mode,
           src->src1compinfo.md_user_tag,
           src->src1compsize_hi, src->src1compsize_lo, src->src1cropoffset);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x88) / 4]) {
    printf("        Src2Comp: En=%d MBS=%d PF=%d Lossy=%d MdTag=0x%02x Size=0x%x%08x Crop=0x%x\n",
           src->src2compinfo.compressed_enable,
           src->src2compinfo.macroblock_size,
           src->src2compinfo.packing_format,
           src->src2compinfo.lossy_mode,
           src->src2compinfo.md_user_tag,
           src->src2compsize_hi, src->src2compsize_lo, src->src2cropoffset);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0xf8) / 4]) {
    printf("        Src1Ephemeral: En=%d\n", src->src1ephemeral & 1);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0xc8) / 4]) {
    printf("        TextureCfg: 0x%08x\n", src->texture_config);
  }
}

void print_tiledmadst_h16(const hwx_state_t *state) {
  const ane_tiledmadst_h16_t *dst =
      (const ane_tiledmadst_h16_t *)&state->values[H16_TILEDMA_DST_START / 4];
  printf("        --- TileDMADst (0x5100) ---\n");
  if (state->valid[H16_TILEDMA_DST_START / 4]) {
    printf("        DstDMAConfig: En=%d DSID=%u Tag=%u\n", dst->dstcfg.en,
           dst->dstcfg.dataset_id, dst->dstcfg.user_tag);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x10) / 4]) {
    printf("        DstStrides: Row=0x%08x Plane=0x%08x Depth=0x%08x "
           "Group=0x%08x\n",
           dst->dstrow_stride, dst->dstplane_stride, dst->dstdepth_stride,
           dst->dstgroup_stride);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x28) / 4]) {
    printf("        DstMeta   : Addr=0x%x%08x Mode=0x%x\n", dst->dstmeta_hi,
           dst->dstmeta_lo, dst->dstfmtmode);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x38) / 4]) {
    printf("        DstFmtCtrl: ZeroPad(L=%d,F=%d) OffCh=%d CmpVec=%d Intrlv=%d\n",
           dst->dstfmtctrl & 1, (dst->dstfmtctrl >> 1) & 1,
           (dst->dstfmtctrl >> 8) & 0xF, (dst->dstfmtctrl >> 12) & 0xF,
           (dst->dstfmtctrl >> 24) & 0xF);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x40) / 4]) {
    printf("        DstComp: En=%d Packing=%d MBSize=%d Lossy=%d\n",
           dst->dstcompinfo.compressed_enable, dst->dstcompinfo.packing_format,
           dst->dstcompinfo.macroblock_size, dst->dstcompinfo.lossy_mode);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x50) / 4]) {
    printf("        DstPixelOff: 0x%08x (CropY=%u)\n", dst->dstpixeloffset,
           dst->dstpixeloffset >> 16);
  }
}

void print_kerneldmasrc_h16(const hwx_state_t *state) {
  const ane_kerneldmasrc_h16_t *k =
      (const ane_kerneldmasrc_h16_t *)&state->values[H16_KERNELDMA_START / 4];
  printf("        --- KernelDMASrc (0x5500) ---\n");
  if (state->valid[H16_KERNELDMA_START / 4])
    printf("        MasterCfg: En=%d Sparse=%d Reuse=%d\n",
           k->master_cfg.master_enable, k->master_cfg.kernel_sparse_fmt,
           k->master_cfg.group_kernel_reuse);
  if (state->valid[(H16_KERNELDMA_START + 0x04) / 4])
    printf("        AlignedCoeffSize: 0x%08x\n", k->aligned_coeff_size_per_ch);
  if (state->valid[(H16_KERNELDMA_START + 0x08) / 4])
    printf("        Prefetch : Rate=%u Early=%d\n", k->prefetch.prefetch_rate,
           k->prefetch.early_term_en);
  if (state->valid[(H16_KERNELDMA_START + 0x18) / 4])
    printf("        KernelGroupStride: %u\n", k->kernel_group_stride & 0x3ffffff);
  if (state->valid[(H16_KERNELDMA_START + 0x1c) / 4])
    printf("        KernelOCGStride  : %u\n", k->kernel_ocg_stride & 0x3ffffff);

  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0x20) / 4 + i] ||
        state->valid[(H16_KERNELDMA_START + 0x60) / 4 + i] ||
        state->valid[(H16_KERNELDMA_START + 0xa0) / 4 + i]) {
      printf("        Coeff[%d]: En=%d DSID=%u Tag=%u "
             "Base=0x%08x "
             "Size=0x%08x\n",
             i, k->coeff_cfg[i].en, k->coeff_cfg[i].dataset_id,
             k->coeff_cfg[i].user_tag, k->coeff_base[i],
             k->coeff_size[i] & 0x3ffffff);
    }
  }
  if (state->valid[(H16_KERNELDMA_START + 0xe0) / 4])
    printf("        Bias: En=%d Tag=%u\n", k->bias_cfg.en,
           k->bias_cfg.user_tag);
  if (state->valid[(H16_KERNELDMA_START + 0xf0) / 4])
    printf("        PSScale: En=%d Tag=%u\n", k->post_scale_cfg.en,
           k->post_scale_cfg.user_tag);
  if (state->valid[(H16_KERNELDMA_START + 0x110) / 4])
    printf("        NLut: En=%d Tag=%u\n", k->non_linear_cfg.en,
           k->non_linear_cfg.user_tag);
}

void print_cachedma_h16(const hwx_state_t *state) {
  ane_cachedma_h16_t cdma =
      *(ane_cachedma_h16_t *)&state->values[H16_CACHEDMA_START / 4];
  printf("        --- CacheDMASrc (0x5900) ---\n");
  if (state->valid[H16_CACHEDMA_START / 4]) {
    printf("        Control: Flush=%d En=%d TaskSync=0x%x ET=0x%x FL=%d "
           "Thresh=0x%04x\n",
           cdma.control.flush, cdma.control.enable, cdma.control.task_sync,
           cdma.control.early_term, cdma.control.footprint_limiter,
           cdma.control.footprint_threshold);
  }
  if (state->valid[H16_CACHEDMA_START / 4 + 1]) {
    printf("        Pre0: BWLimit=%u Sieve2=%u AgeOut=%u\n",
           cdma.pre0.bandwidth_limit, cdma.pre0.sieve2,
           cdma.pre0.telemetry_age_out);
  }
  if (state->valid[(H16_CACHEDMA_START + 0x08) / 4])
    printf("        Pre1: Sieve1=%u\n", cdma.pre1.sieve1);
  if (state->valid[(H16_CACHEDMA_START + 0x18) / 4])
    printf("        DSID: DSID_Size=0x%x\n", cdma.dsid.dsid_and_size);
  if (state->valid[(H16_CACHEDMA_START + 0x1c) / 4])
    printf("        Footprint: Arg2=0x%x\n", cdma.footprint_arg.footprint_arg2);
  if (state->valid[(H16_CACHEDMA_START + 0x20) / 4]) {
    printf("        ET_Args12: Arg1=0x%04x Arg2=0x%04x\n",
           cdma.early_term_arg12.arg1, cdma.early_term_arg12.arg2);
  }
  if (state->valid[(H16_CACHEDMA_START + 0x24) / 4])
    printf("        Flush: Arg=0x%04x\n", cdma.flush_reg.flush_arg);
  if (state->valid[(H16_CACHEDMA_START + 0x28) / 4]) {
    printf("        ET_Args34: Arg3=0x%02x Arg4=0x%02x\n",
           cdma.early_term_arg34.arg3, cdma.early_term_arg34.arg4);
  }
  if (state->valid[(H16_CACHEDMA_START + 0x2c) / 4]) {
    printf("        BackOff: En=%d Delay=%u Min=%u Max=%u Scale=%u\n",
           cdma.backoff.enable, cdma.backoff.delay, cdma.backoff.min,
           cdma.backoff.max, cdma.backoff.scale);
  }
}

void report_hwx_state(const hwx_state_t *state, BOOL dump_reg_blocks) {
  if (state->instr_ver >= 11) {
    print_common_h16(state);
    print_ne_h16(state);
    print_pe_index_h16(state);
    print_pe_h16(state);
    print_l2_h16(state);
    print_tiledmasrc_h16(state);
    print_tiledmadst_h16(state);
    print_kerneldmasrc_h16(state);
    print_cachedma_h16(state);

    if (dump_reg_blocks) {
      hwx_block_info_t blocks[] = {
          {"[0x0000] Common Module", H16_COMMON_START, 23},
          {"[0x4100] L2 Cache Control", H16_L2_START, 41},
          {"[0x4500] Planar Engine (PE)", H16_PE_START, 16},
          {"[0x4900] Neural Engine Core (NE)", H16_NE_START, 12},
          {"[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, 81},
          {"[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, 21},
          {"[0x5500] KernelDMA Source", H16_KERNELDMA_START, 72},
          {"[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, 12},
      };
      dump_hw_blocks(state, blocks, 8, get_m4_reg_name);
    }
  } else {
    print_common_h13(state);
    print_l2_h13(state);
    print_pe_h13(state);
    print_ne_h13(state);
    print_tiledmasrc_h13(state);
    print_tiledmadst_h13(state);
    print_kerneldmasrc_h13(state);

    if (dump_reg_blocks) {
      hwx_block_info_t blocks[] = {
          {"[0x00000] Common Module", H13_COMMON_START, 16},
          {"[0x04800] L2 Cache Control", H13_L2_START, 16},
          {"[0x08800] Planar Engine (PE)", H13_PE_START, 4},
          {"[0x0C800] Neural Engine Core (NE)", H13_NE_START, 5},
          {"[0x13800] TileDMA Source", H13_TILEDMA_SRC_START, 24},
          {"[0x17800] TileDMA Destination", H13_TILEDMA_DST_START, 7},
          {"[0x1F800] KernelDMA Source", H13_KERNELDMA_START, 5},
      };
      dump_hw_blocks(state, blocks, 7, get_m1_reg_name);
    }
  }
}

void report_hwx_state_json(const hwx_state_t *state) {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:(state->instr_ver >= 11 ? @"M4" : @"M1") forKey:@"arch"];
  [dict setObject:@(state->subtype) forKey:@"subtype"];

  NSMutableArray *regs = [NSMutableArray array];
  const char *(*name_lookup)(uint32_t) =
      (state->instr_ver >= 11) ? get_m4_reg_name : get_m1_reg_name;

  for (uint32_t r = 0; r < HW_MAX_REGS; r++) {
    if (state->valid[r]) {
      uint32_t addr = r * 4;
      const char *name = name_lookup(addr);
      NSMutableDictionary *reg = [NSMutableDictionary dictionary];
      [reg setObject:[NSString stringWithFormat:@"0x%05x", addr]
              forKey:@"addr"];
      [reg setObject:[NSString stringWithFormat:@"0x%08x", state->values[r]]
              forKey:@"val"];
      if (name)
        [reg setObject:[NSString stringWithUTF8String:name] forKey:@"name"];
      [regs addObject:reg];
    }
  }
  [dict setObject:regs forKey:@"registers"];

  NSError *error;
  NSData *data =
      [NSJSONSerialization dataWithJSONObject:dict
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  if (data) {
    NSString *jsonString = [[NSString alloc] initWithData:data
                                                 encoding:NSUTF8StringEncoding];
    printf("%s\n", [jsonString UTF8String]);
  }
}

void decode_ane_td(const uint8_t *ptr, size_t total_len, uint32_t subtype,
                   BOOL dump_reg_blocks, BOOL dump_json) {
  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_header_h13_t) <= total_len) {
    const ane_header_h13_t *td = (const ane_header_h13_t *)(ptr + offset);
    if (td->next_pointer == 0 && td->exe_cycles == 0 && td->log_events == 0) {
      break; // Hit zero padding
    }

    if (!dump_json) {
      printf("      [ANE Task %d @ 0x%x]\n", task_idx++, offset);
      printf("        TID: 0x%04x NID: 0x%02x LNID: %d EON: %d\n", td->tid,
             td->nid, td->lnid, td->eon);
      printf("        ExeCycles: %u NextSize: %u\n", td->exe_cycles,
             td->next_size);
      printf("        NextPtr: 0x%08x TSR: %d TSE: %d ENE: %d\n",
             td->next_pointer, td->flags.tsr, td->flags.tse, td->base_ene.ene);
      printf("        RBase: %d/%d WBase: %d TBase: %d\n", td->base_ene.rbase0,
             td->base_ene.rbase1, td->base_ene.wbase, td->base_ene.tbase);
      if (td->kbase.kbe0 || td->kbase.kbe1 || td->kbase.kbe2 ||
          td->kbase.kbe3) {
        printf("        KBase: %d/%d/%d/%d\n", td->kbase.kbase0,
               td->kbase.kbase1, td->kbase.kbase2, td->kbase.kbase3);
      }
    } else {
      task_idx++;
    }

    hwx_state_t state = {0};
    state.instr_ver = 7;
    state.subtype = subtype;

    // Modern Stream Parse
    if (offset + sizeof(ane_header_h13_t) <= total_len) {
      const uint32_t *words = (const uint32_t *)(td + 1);
      uint32_t max_payload_bytes =
          (total_len > offset + sizeof(ane_header_h13_t))
              ? (uint32_t)(total_len - offset - sizeof(ane_header_h13_t))
              : 0;
      uint32_t num_words = max_payload_bytes / 4;

      if (td->next_pointer > offset + sizeof(ane_header_h13_t)) {
        uint32_t td_words =
            (td->next_pointer - offset - sizeof(ane_header_h13_t)) / 4;
        if (td_words < num_words) {
          num_words = td_words;
        }
      }

      int w_idx = 0;
      while (w_idx < num_words) {
        uint32_t hdr = words[w_idx++];

        // skip padding words
        if (hdr == 0)
          continue;
        uint32_t count = (hdr >> 26) & 0x3f;
        uint32_t addr = (hdr & 0x3ffffff) >> 2;
        uint32_t num_vals = count + 1;
        for (uint32_t i = 0; i < num_vals; i++) {
          if (w_idx >= num_words)
            break;
          // Mask addr just in case it exceeds our struct buffer logic
          if (addr + i < HW_MAX_REGS) {
            state.values[addr + i] = words[w_idx];
            state.valid[addr + i] = true;
          }
          w_idx++;
        }
      }
    }

    if (offset + sizeof(ane_header_h13_t) <= total_len) {
      if (dump_json) {
        report_hwx_state_json(&state);
      } else {
        report_hwx_state(&state, dump_reg_blocks);
      }
    }

    if (td->next_pointer == 0 || td->next_pointer <= offset)
      break;
    offset = td->next_pointer;
  }
}

void decode_ane_td_m4(const uint8_t *ptr, size_t total_len, uint32_t subtype,
                      BOOL dump_reg_blocks, BOOL dump_json) {
  printf("\n[%s] Detected Dense HWX Format (CPU Subtype 0x%x)\n",
         get_arch_name(subtype), subtype);

  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_header_h16_t) <= total_len) {
    const ane_header_h16_t *m4h = (const ane_header_h16_t *)(ptr + offset);

    if (m4h->task_size == 0) {
      offset += 16;
      continue;
    }

    // Basic Validation: Logic IDs are generally small (tid < 0x1000)
    if (m4h->tid > 0x1000) {
      printf("      [M4 Parser] Found likely end of tasks at offset 0x%x (TID: "
             "0x%04x)\n",
             offset, m4h->tid);
      break;
    }

    if (!dump_json) {
      uint32_t size_bytes = m4h->task_size * 4;
      printf("      [ANE Task %d @ 0x%x] (Size: 0x%x bytes)\n", task_idx++,
             offset, size_bytes);
      printf("        TID: 0x%04x ExeCycles: %u ENE: %u DTID: 0x%04x\n",
             m4h->tid, m4h->exe_cycles, m4h->ctrl_flags.ene, m4h->dtid);
      printf("        LogEvents: 0x%06x Exceptions: 0x%06x\n", m4h->log_events,
             m4h->exceptions);
      printf("        LiveOuts: 0x%08x TSR: %d TDE: %d\n", m4h->live_outs,
             m4h->ctrl_flags.tsr, m4h->ctrl_flags.tde);
    } else {
      task_idx++;
    }

    hwx_state_t state = {0};
    state.instr_ver = 11;
    state.subtype = subtype;

    const uint32_t *words = (const uint32_t *)(ptr + offset);
    int num_words = (m4h->task_size * 4) / 4;
    int i = sizeof(ane_header_h16_t) / 4;

    while (i < num_words) {
      uint32_t header = words[i++];
      uint32_t word_addr = header & 0x7FFF;

      if ((header >> 31) == 0) {
        uint16_t num_regs = (header >> 15) & 0x3F;
        for (int j = 0; j <= num_regs && i < num_words; j++) {
          if (word_addr + j < HW_MAX_REGS) {
            state.values[word_addr + j] = words[i];
            state.valid[word_addr + j] = true;
          }
          i++;
        }
      } else {
        uint32_t mask = (header >> 15) & 0xFFFF;
        if (i < num_words) {
          if (word_addr < HW_MAX_REGS) {
            state.values[word_addr] = words[i];
            state.valid[word_addr] = true;
          }
          i++;
        }
        for (int bit = 0; bit < 16 && i < num_words; bit++) {
          if ((mask >> bit) & 1) {
            if (word_addr + bit + 1 < HW_MAX_REGS) {
              state.values[word_addr + bit + 1] = words[i];
              state.valid[word_addr + bit + 1] = true;
            }
            i++;
          }
        }
      }
    }

    if (dump_json) {
      report_hwx_state_json(&state);
    } else {
      report_hwx_state(&state, dump_reg_blocks);
    }

    uint32_t size_bytes = m4h->task_size * 4;
    offset += (size_bytes + 15) & ~15;
  }
}

void hex_dump(const char *label, const uint8_t *ptr, size_t len) {
  printf("      %s (%zu bytes):\n", label, len);
  for (size_t i = 0; i < len; i += 16) {
    printf("        %04lx: ", i);
    for (size_t j = 0; j < 16; j++) {
      if (i + j < len)
        printf("%02x ", ptr[i + j]);
      else
        printf("   ");
    }
    printf(" |");
    for (size_t j = 0; j < 16; j++) {
      if (i + j < len) {
        char c = ptr[i + j];
        printf("%c", (c >= 32 && c <= 126) ? c : '.');
      }
    }
    printf("|\n");
  }
}

const char *get_cmd_name(uint32_t cmd) {
  switch (cmd) {
  case LC_SEGMENT:
    return "LC_SEGMENT";
  case LC_SYMTAB:
    return "LC_SYMTAB";
  case LC_SYMSEG:
    return "LC_SYMSEG";
  case LC_THREAD:
    return "LC_THREAD";
  case LC_UNIXTHREAD:
    return "LC_UNIXTHREAD";
  case LC_LOADFVMLIB:
    return "LC_LOADFVMLIB";
  case LC_IDFVMLIB:
    return "LC_IDFVMLIB";
  case LC_IDENT:
    return "LC_IDENT";
  case LC_FVMFILE:
    return "LC_FVMFILE";
  case LC_PREPAGE:
    return "LC_PREPAGE";
  case LC_DYSYMTAB:
    return "LC_DYSYMTAB";
  case LC_LOAD_DYLIB:
    return "LC_LOAD_DYLIB";
  case LC_ID_DYLIB:
    return "LC_ID_DYLIB";
  case LC_LOAD_DYLINKER:
    return "LC_LOAD_DYLINKER";
  case LC_ID_DYLINKER:
    return "LC_ID_DYLINKER";
  case LC_PREBOUND_DYLIB:
    return "LC_PREBOUND_DYLIB";
  case LC_ROUTINES:
    return "LC_ROUTINES";
  case LC_SUB_FRAMEWORK:
    return "LC_SUB_FRAMEWORK";
  case LC_SUB_UMBRELLA:
    return "LC_SUB_UMBRELLA";
  case LC_SUB_CLIENT:
    return "LC_SUB_CLIENT";
  case LC_SUB_LIBRARY:
    return "LC_SUB_LIBRARY";
  case LC_TWOLEVEL_HINTS:
    return "LC_TWOLEVEL_HINTS";
  case LC_PREBIND_CKSUM:
    return "LC_PREBIND_CKSUM";
  case LC_LOAD_WEAK_DYLIB:
    return "LC_LOAD_WEAK_DYLIB";
  case LC_SEGMENT_64:
    return "LC_SEGMENT_64";
  case LC_ROUTINES_64:
    return "LC_ROUTINES_64";
  case LC_UUID:
    return "LC_UUID";
  case LC_RPATH:
    return "LC_RPATH";
  case LC_CODE_SIGNATURE:
    return "LC_CODE_SIGNATURE";
  case LC_SEGMENT_SPLIT_INFO:
    return "LC_SEGMENT_SPLIT_INFO";
  case LC_REEXPORT_DYLIB:
    return "LC_REEXPORT_DYLIB";
  case LC_LAZY_LOAD_DYLIB:
    return "LC_LAZY_LOAD_DYLIB";
  case LC_ENCRYPTION_INFO:
    return "LC_ENCRYPTION_INFO";
  case LC_DYLD_INFO:
    return "LC_DYLD_INFO";
  case LC_DYLD_INFO_ONLY:
    return "LC_DYLD_INFO_ONLY";
  case LC_LOAD_UPWARD_DYLIB:
    return "LC_LOAD_UPWARD_DYLIB";
  case LC_VERSION_MIN_MACOSX:
    return "LC_VERSION_MIN_MACOSX";
  case LC_VERSION_MIN_IPHONEOS:
    return "LC_VERSION_MIN_IPHONEOS";
  case LC_FUNCTION_STARTS:
    return "LC_FUNCTION_STARTS";
  case LC_DYLD_ENVIRONMENT:
    return "LC_DYLD_ENVIRONMENT";
  case LC_MAIN:
    return "LC_MAIN";
  case LC_DATA_IN_CODE:
    return "LC_DATA_IN_CODE";
  case LC_SOURCE_VERSION:
    return "LC_SOURCE_VERSION";
  case LC_DYLIB_CODE_SIGN_DRS:
    return "LC_DYLIB_CODE_SIGN_DRS";
  case LC_ENCRYPTION_INFO_64:
    return "LC_ENCRYPTION_INFO_64";
  case LC_LINKER_OPTION:
    return "LC_LINKER_OPTION";
  case LC_LINKER_OPTIMIZATION_HINT:
    return "LC_LINKER_OPTIMIZATION_HINT";
  case LC_VERSION_MIN_TVOS:
    return "LC_VERSION_MIN_TVOS";
  case LC_VERSION_MIN_WATCHOS:
    return "LC_VERSION_MIN_WATCHOS";
  case LC_NOTE:
    return "LC_NOTE";
  case LC_BUILD_VERSION:
    return "LC_BUILD_VERSION";
  case LC_ANE_MAPPED_REGION:
    return "LC_ANE_MAPPED_REGION"; // Mapped region based on ANECompiler 'Zin'
                                   // generation
  default:
    return "UNKNOWN";
  }
}

static void handle_segment_64(const struct mach_header_64 *header,
                              const struct load_command *lc, NSData *data,
                              BOOL dump_hexdump, BOOL dump_reg_blocks,
                              BOOL dump_json) {
  const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
  printf("  Segment Name: %s\n", seg->segname);
  printf("  VM Addr: 0x%llx\n", seg->vmaddr);
  printf("  VM Size: 0x%llx\n", seg->vmsize);
  printf("  File Off: 0x%llx\n", seg->fileoff);
  printf("  File Size: 0x%llx\n", seg->filesize);
  printf("  Num Sections: %u\n", seg->nsects);

  const struct section_64 *sect =
      (const struct section_64 *)((const uint8_t *)lc +
                                  sizeof(struct segment_command_64));
  for (uint32_t j = 0; j < seg->nsects; j++) {
    if ((const uint8_t *)(sect + 1) > (const uint8_t *)data.bytes + data.length)
      break;
    printf("    Section %u:\n", j);
    printf("      Name: %s\n", sect->sectname);
    printf("      Segment: %s\n", sect->segname);
    printf("      Addr: 0x%llx\n", sect->addr);
    printf("      Size: 0x%llx\n", sect->size);
    printf("      Offset: 0x%x\n", sect->offset);
    printf("      Flags: 0x%x\n", sect->flags);

    if (strcmp(seg->segname, "__TEXT") == 0) {
      if (sect->offset + sect->size <= data.length) {
        const uint8_t *section_ptr = (const uint8_t *)data.bytes + sect->offset;
        size_t section_size = (size_t)sect->size;

        if (strcmp(sect->sectname, "__text") == 0 ||
            strcmp(sect->sectname, "__TEXT") == 0) {
          uint32_t instr_ver = get_instruction_set_version(header->cpusubtype);
          if (instr_ver >= 11) {
            decode_ane_td_m4(section_ptr, section_size, header->cpusubtype,
                             dump_reg_blocks, dump_json);
          } else {
            decode_ane_td(section_ptr, section_size, header->cpusubtype,
                          dump_reg_blocks, dump_json);
          }
          if (dump_hexdump) {
            hex_dump(sect->sectname, section_ptr, section_size);
          }
        }
      }
    }
    sect++;
  }
}

static void handle_symtab(const struct load_command *lc, NSData *data,
                          BOOL dump_all_symbols) {
  const struct symtab_command *sym = (const struct symtab_command *)lc;
  printf("  Symbol Table Offset: 0x%x\n", sym->symoff);
  printf("  Num Symbols: %u\n", sym->nsyms);
  printf("  String Table Offset: 0x%x\n", sym->stroff);

  if (sym->nsyms > 0 && sym->symoff < data.length) {
    uint32_t max_syms = dump_all_symbols ? sym->nsyms : 5;
    if (!dump_all_symbols && sym->nsyms > 5) {
      printf("    (Printing first 5 symbols - use -s to see all)\n");
    } else {
      printf("    (Printing %u symbols)\n", max_syms);
    }

    const struct nlist_64 *list =
        (const struct nlist_64 *)(data.bytes + sym->symoff);
    const char *strtab = (const char *)(data.bytes + sym->stroff);

    for (uint32_t k = 0; k < max_syms; k++) {
      if ((const uint8_t *)(list + 1) >
          (const uint8_t *)data.bytes + data.length)
        break;
      const char *name = "";
      if (list->n_un.n_strx < sym->strsize) {
        name = strtab + list->n_un.n_strx;
      }
      printf("    [%u] %s @ 0x%llx\n", k, name, list->n_value);
      list++;
    }
  }
}

static void handle_thread(const struct load_command *lc, BOOL dump_threads) {
  if (!dump_threads)
    return;
  uint32_t internal_offset = 8;
  uint32_t flavor_idx = 0;
  while (internal_offset + 8 <= lc->cmdsize) {
    const uint32_t *content =
        (const uint32_t *)((const uint8_t *)lc + internal_offset);
    uint32_t flavor = content[0];
    uint32_t count = content[1];
    printf("  Flavor Set %u: Flavor=%u Count=%u\n", flavor_idx++, flavor,
           count);

    internal_offset += 8;
    const uint32_t *state = content + 2;
    printf("    State:\n");
    for (uint32_t k = 0; k < count; k++) {
      if (internal_offset + 4 > lc->cmdsize)
        break;
      if (k % 4 == 0)
        printf("      [%03u]:", k);
      printf(" 0x%08x", state[k]);
      if (k % 4 == 3 || k == count - 1)
        printf("\n");
      internal_offset += 4;
    }
  }
}

static void handle_note(const struct load_command *lc, NSData *data) {
  if (lc->cmdsize < sizeof(struct note_command))
    return;
  const struct note_command *nc = (const struct note_command *)lc;
  printf("  Data Owner: %.16s\n", nc->data_owner);
  printf("  Offset: 0x%llx\n", nc->offset);
  printf("  Size: 0x%llx\n", nc->size);

  if (nc->offset + nc->size <= data.length) {
    const char *note_data = (const char *)data.bytes + nc->offset;
    uint64_t check_len = nc->size < 256 ? nc->size : 256;
    BOOL printable = YES;
    for (uint64_t k = 0; k < check_len; k++) {
      char c = note_data[k];
      if (c != 0 && (c < 32 || c > 126)) {
        if (c != '\n' && c != '\r' && c != '\t') {
          printable = NO;
          break;
        }
      }
    }

    if (printable && nc->size > 0) {
      char *buf = malloc(nc->size + 1);
      if (buf) {
        memcpy(buf, note_data, nc->size);
        buf[nc->size] = '\0';
        printf("  Content:\n%s\n", buf);
        free(buf);
      }
    } else {
      printf("  (Binary Content or too large to verify text)\n");
    }
  }
}

static void handle_mapped_region(const struct load_command *lc) {
  const uint32_t *raw = (const uint32_t *)lc;
  uint32_t count = lc->cmdsize / 4;
  printf("  (LC_ANE_MAPPED_REGION)\n");
  if (count > 6) {
    const char *str = (const char *)(raw + 6);
    const char *end_ptr = (const char *)lc + lc->cmdsize;
    if (str < end_ptr) {
      printf("    Region: 0x%08x Name: %s\n", raw[4], str);
    }
  }
}

static void handle_ident(const struct load_command *lc) {
  if (lc->cmdsize > 8) {
    uint32_t len = lc->cmdsize - 8;
    char *buf = malloc(len + 1);
    if (buf) {
      memcpy(buf, (const char *)lc + 8, len);
      buf[len] = '\0';
      printf("  Ident: %s\n", buf);
      free(buf);
    }
  } else {
    printf("  (Empty Ident)\n");
  }
}

void print_macho_headers(NSData *data, BOOL dump_all_symbols, BOOL dump_threads,
                         BOOL dump_hexdump, BOOL dump_reg_blocks,
                         BOOL dump_json) {
  if (data.length < sizeof(struct mach_header_64)) {
    printf("Error: File too small.\n");
    return;
  }

  const struct mach_header_64 *header =
      (const struct mach_header_64 *)data.bytes;

  uint32_t magic = header->magic;
  if (magic != HWX_MAGIC) {
    printf("Error: Invalid magic 0x%08x (Expected 0x%08x)\n", magic, HWX_MAGIC);
    return;
  }
  printf("Magic verified: 0x%08x\n", magic);

  if (data.length < 32)
    return;

  printf("CPU Type: 0x%04x\n", header->cputype);
  printf("CPU Subtype: 0x%04x\n", header->cpusubtype);
  printf("File Type: 0x%04x\n", header->filetype);
  printf("Number of Load Commands: 0x%04x\n", header->ncmds);
  printf("Size of Load Commands: 0x%04x\n", header->sizeofcmds);
  printf("Flags: 0x%04x\n", header->flags);

  uint32_t offset = 32;
  for (uint32_t i = 0; i < header->ncmds; i++) {
    if (offset + sizeof(struct load_command) > data.length) {
      printf("Error: Unexpected EOF reading load command %u\n", i);
      break;
    }

    const struct load_command *lc =
        (const struct load_command *)(data.bytes + offset);
    const char *cmd_name = get_cmd_name(lc->cmd);

    printf("\nLoad Command %u:\n", i);
    printf("  Cmd: 0x%x (%s)\n", lc->cmd, cmd_name);
    printf("  Size: %u\n", lc->cmdsize);

    if (lc->cmd == LC_SEGMENT_64) {
      if (offset + sizeof(struct segment_command_64) <= data.length) {
        handle_segment_64(header, lc, data, dump_hexdump, dump_reg_blocks,
                          dump_json);
      }
    } else if (lc->cmd == LC_SYMTAB) {
      if (offset + sizeof(struct symtab_command) <= data.length) {
        handle_symtab(lc, data, dump_all_symbols);
      }
    } else if (lc->cmd == LC_THREAD || lc->cmd == LC_UNIXTHREAD) {
      handle_thread(lc, dump_threads);
    } else if (lc->cmd == LC_NOTE) {
      handle_note(lc, data);
    } else if (lc->cmd == LC_ANE_MAPPED_REGION) {
      handle_mapped_region(lc);
    } else if (lc->cmd == LC_IDENT) {
      handle_ident(lc);
    }

    offset += lc->cmdsize;
  }
}

int main(int argc, char *const argv[]) {
  @autoreleasepool {
    int ch;
    BOOL dump_all = NO;
    BOOL dump_threads = NO;
    BOOL dump_hexdump = NO;
    BOOL dump_reg_blocks = NO;
    BOOL dump_json = NO;

    while ((ch = getopt(argc, argv, "strxj")) != -1) {
      switch (ch) {
      case 's':
        dump_all = YES;
        break;
      case 't':
        dump_threads = YES;
        break;
      case 'r':
        dump_reg_blocks = YES;
        break;
      case 'x':
        dump_hexdump = YES;
        break;
      case 'j':
        dump_json = YES;
        break;
      case '?':
      default:
        printf("Usage: %s [-s] [-t] [-r] [-x] [-j] <path_to_hwx>\n",
               getprogname());
        return 1;
      }
    }
    argc -= optind;
    argv += optind;

    if (argc < 1) {
      printf("Usage: %s [-s] [-t] [-r] [-x] <path_to_hwx>\n", getprogname());
      return 1;
    }

    NSString *path = [NSString stringWithUTF8String:argv[0]];
    NSData *data = [NSData dataWithContentsOfFile:path];

    if (!data) {
      printf("Error reading file: %s\n", argv[0]);
      return 1;
    }

    print_macho_headers(data, dump_all, dump_threads, dump_hexdump,
                        dump_reg_blocks, dump_json);
  }
  return 0;
}
