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
  static const char *ne_names[] = {"KernelCfg", "MACCfg", "MatrixVectorBias",
                                   "AccBias", "PostScale"};

  static const hwx_reg_range_t m1_ranges[] = {
      {H13_COMMON_START, 16, common_names},
      {H13_L2_START, 16, l2_names},
      {H13_PE_START, 4, pe_names},
      {H13_NE_START, 5, ne_names},
  };

  const char *name = lookup_reg_name(addr, m1_ranges, 4);
  if (name)
    return name;

  // Manual logic for TileDMA and KernelDMA due to sparse mappings
  // TileDMA Src (0x13800)
  if (addr >= H13_TILEDMA_SRC_START && addr <= H13_TILEDMA_SRC_START + 0x90) {
    uint32_t off = addr - H13_TILEDMA_SRC_START;
    if (off == 0x00)
      return "DMAConfig";
    if (off == 0x08)
      return "BaseAddr";
    if (off == 0x0C)
      return "RowStride";
    if (off == 0x10)
      return "PlaneStride";
    if (off == 0x14)
      return "DepthStride";
    if (off == 0x18)
      return "GroupStride";
    if (off == 0x38)
      return "Fmt";
    if (off >= 0x50 && off <= 0x5C)
      return "PixelOffset";
  }
  // TileDMA Dst (0x17800)
  if (addr >= H13_TILEDMA_DST_START && addr <= H13_TILEDMA_DST_START + 0x30) {
    uint32_t off = addr - H13_TILEDMA_DST_START;
    if (off == 0x00)
      return "DMAConfig";
    if (off == 0x04)
      return "BaseAddr";
    if (off == 0x08)
      return "RowStride";
    if (off == 0x0C)
      return "PlaneStride";
    if (off == 0x10)
      return "DepthStride";
    if (off == 0x14)
      return "GroupStride";
    if (off == 0x18)
      return "Fmt";
  }
  // KernelDMA (0x1F800)
  if (addr >= H13_KERNELDMA_START && addr <= H13_KERNELDMA_START + 0x100) {
    uint32_t off = addr - H13_KERNELDMA_START;
    if ((off == 0x00) || (off == 0x04))
      return "Unknown";
    if (off >= 0x08 && off < 0x48)
      return "CoeffDMAConfig";
    if (off >= 0x48 && off < 0x88)
      return "CoeffBaseAddr";
    if (off >= 0x88 && off < 0xC8)
      return "CoeffBfrSize";
  }
  return NULL;
}

const char *get_m4_reg_name(uint32_t addr) {
  static const char *common_names[] = {
      "ChannelCfg", "InWidth",   "InHeight",    "InChannels", "InDepth",
      "OutWidth",   "OutHeight", "OutChannels", "OutDepth",   "NumGroups",
      "ConvCfg",    "ConvCfg3d", "UnicastCfg",  "TileHeight", "TileOverlap",
      "MacCfg",     "LaneCfg",   "PatchCfg",    "PERouting",  "NID",
      "DPE",        "Val21",     "Val22"};
  static const char *l2_names[] = {
      "L2_Control",        "L2_Src1Cfg",        "L2_Src2Cfg",
      "L2_Pad3",           "L2_Src1Base",       "L2_Src1CStride",
      "L2_Src1RStride",    "L2_Src1DStride",    "L2_Src1GStride",
      "L2_Src2Base",       "L2_Src2CStride",    "L2_Src2RStride",
      "L2_Src2DStride",    "L2_Src2GStride",    "L2_SrcIdxBase",
      "L2_SrcIdxCStride",  "L2_SrcIdxDStride",  "L2_SrcIdxGStride",
      "L2_ResultCfg",      "L2_ResultBase",     "L2_ResultCStride",
      "L2_ResultRStride",  "L2_ResultDStride",  "L2_ResultGStride",
      "L2_Res24",          "L2_ResultWrapCfg",  "L2_Res26",
      "L2_Res27",          "L2_Res28",          "L2_ResultWrapIdxOff",
      "L2_Res30",          "L2_Result2Base",    "L2_Result2CStride",
      "L2_Result2RStride", "L2_Result2DStride", "L2_Result2GStride",
      "L2_Res36",          "L2_Res37",          "L2_Res38",
      "L2_ResultWrapAddr", "L2_Res40"};
  static const char *pe_names[] = {
      "PE_Config",    "PE_Bias",        "PE_Scale",     "PE_FinalScale",
      "PE_PreScale",  "PE_FinalScale2", "PE_Reserved1", "PE_Reserved2",
      "PE_Reserved3", "PE_Reserved4",   "PE_Reserved5", "PE_Reserved6",
      "PE_Reserved7", "PE_Reserved8",   "PE_Quant"};
  static const char *ne_names[] = {
      "KernelCfg", "MACCfg",     "MatrixVectorBias", "NEBias",
      "PostScale", "RcasConfig", "RoundModeCfg",     "SRSeed0",
      "SRSeed1",   "SRSeed2",    "SRSeed3",          "QuantZeroPoint"};
  static const char *cdma_names[] = {
      "CacheDMAControl",  "CacheDMAPre0",      "CacheDMAPre1",
      "CacheDMAPad3",     "CacheDMAPad4",      "CacheDMAPad5",
      "CacheDMADsid",     "CacheDMAFootprint", "EarlyTermArg12",
      "CacheDMAFlushArg", "EarlyTermArg34",    "TelemetryBackOff"};

  static const hwx_reg_range_t m4_ranges[] = {
      {H16_COMMON_START, 23, common_names}, {H16_L2_START, 41, l2_names},
      {H16_PE_START, 15, pe_names},         {H16_NE_START, 12, ne_names},
      {H16_CACHEDMA_START, 12, cdma_names},
  };

  const char *name = lookup_reg_name(addr, m4_ranges, 5);
  if (name)
    return name;

  // PE Auxiliary
  if (addr >= H16_PE_START - 0x30 && addr <= H16_PE_START - 0x2C) {
    return (addr == H16_PE_START - 0x30) ? "PE_IndexMode" : "PE_IndexBroadcast";
  }

  // TileDMA Src 0x4D00
  if (addr >= H16_TILEDMA_SRC_START && addr <= H16_TILEDMA_SRC_START + 0xB4) {
    uint32_t off = addr - H16_TILEDMA_SRC_START;
    if (off == 0x00)
      return "Src1DMAConfig";
    if (off == 0x04)
      return "Src2DMAConfig";
    if (off == 0x08)
      return "Src1BaseAddrLo";
    if (off == 0x0C)
      return "Src1BaseAddrHi";
    if (off == 0x10)
      return "Src2BaseAddrLo";
    if (off == 0x14)
      return "Src2BaseAddrHi";
    if (off == 0x18)
      return "Src1RowStride";
    if (off == 0x1C)
      return "Src1PlaneStride";
    if (off == 0x20)
      return "Src1DepthStride";
    if (off == 0x24)
      return "Src1GroupStride";
    if (off == 0x30)
      return "Src2RowStride";
    if (off == 0x34)
      return "Src2PlaneStride";
    if (off == 0x38)
      return "Src2DepthStride";
    if (off == 0x3C)
      return "Src2GroupStride";
    if (off == 0x50)
      return "Src1MetaDataAddrLo";
    if (off == 0x58)
      return "Src1MetaDataSize";
    if (off == 0x5C)
      return "Src2MetaDataAddrLo";
    if (off == 0x64)
      return "Src2MetaDataSize";
    if (off == 0x68)
      return "Src1Fmt";
    if (off == 0x6C)
      return "Src2Fmt";
    if (off == 0x98)
      return "Src1PixelOffset";
    if (off == 0xA8)
      return "Src2PixelOffset";
  }
  // TileDMA Dst 0x5100
  if (addr >= H16_TILEDMA_DST_START && addr <= H16_TILEDMA_DST_START + 0x50) {
    uint32_t off = addr - H16_TILEDMA_DST_START;
    if (off == 0x00)
      return "DstDMAConfig";
    if (off == 0x08)
      return "DstBaseAddrLo";
    if (off == 0x0C)
      return "DstBaseAddrHi";
    if (off == 0x10)
      return "DstRowStride";
    if (off == 0x14)
      return "DstPlaneStride";
    if (off == 0x18)
      return "DstDepthStride";
    if (off == 0x1C)
      return "DstGroupStride";
    if (off == 0x20)
      return "DstInternalCfg";
    if (off == 0x28)
      return "DstMetaDataAddrLo";
    if (off == 0x2C)
      return "DstMetaDataAddrHi";
    if (off == 0x30)
      return "DstFmtMode";
    if (off == 0x38)
      return "DstCompStatus";
    if (off == 0x40)
      return "DstCompressionCfg";
    if (off == 0x48)
      return "DstCompSizeLo";
    if (off == 0x4C)
      return "DstCompSizeHi";
    if (off == 0x50)
      return "DstPixelOffset";
  }
  // KernelDMA Src 0x5500
  if (addr >= H16_KERNELDMA_START && addr <= H16_KERNELDMA_START + 0x110) {
    uint32_t off = addr - H16_KERNELDMA_START;
    if (off == 0x00)
      return "KDMA_MasterConfig";
    if (off == 0x08)
      return "KDMA_Prefetch";
    if (off == 0x18)
      return "KDMA_StrideX";
    if (off == 0x1C)
      return "KDMA_StrideY";
    if (off >= 0x20 && off <= 0x5C)
      return "CoeffDMAConfig";
    if (off >= 0x60 && off <= 0x9C)
      return "CoeffBaseAddr";
    if (off >= 0xA0 && off <= 0xDC)
      return "CoeffBfrSize";
    if (off == 0xE0)
      return "BiasDMAConfig";
    if (off == 0xF0)
      return "PostScaleDMAConfig";
    if (off == 0x100)
      return "PaletteDMAConfig";
    if (off == 0x110)
      return "NLutDMAConfig";
  }
  return NULL;
}


void dump_hw_blocks(const hwx_state_t *state,
                    const hwx_block_info_t *blocks, int count,
                    const char *(*name_lookup)(uint32_t)) {
  printf("        --- HW Block Register State ---\n");
  for (int b = 0; b < count; b++) {
    bool printed_header = false;
    uint32_t word_start = blocks[b].startAddr / 4;
    uint32_t word_end = word_start + 0x100; // Look ahead 0x400 bytes

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
  const ane_l2_h13_t *l2 = (const ane_l2_h13_t *)&state->values[H13_L2_START / 4];
  printf("        L2Cfg: InputRelu=%d PaddingMode=%u\n", l2->l2cfg.input_relu,
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
  const ane_ne_h13_t *ne = (const ane_ne_h13_t *)&state->values[H13_NE_START / 4];
  printf("        NE MACCfg: OpMode=%u NLMode=%u KernelMode=%d BiasMode=%d "
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
  const ane_pe_h13_t *pe = (const ane_pe_h13_t *)&state->values[H13_PE_START / 4];
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

void print_tiledma_src_h13(const hwx_state_t *state) {
  const ane_tiledma_src_h13_t *tsrc =
      (const ane_tiledma_src_h13_t *)&state->values[H13_TILEDMA_SRC_START / 4];
  printf("        --- TileDMA Source (0x13800) ---\n");
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

void print_tiledma_dst_h13(const hwx_state_t *state) {
  const ane_tiledma_dst_h13_t *tdst =
      (const ane_tiledma_dst_h13_t *)&state->values[H13_TILEDMA_DST_START / 4];
  printf("        --- TileDMA Destination (0x17800) ---\n");
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

void print_kerneldma_h13(const hwx_state_t *state) {
  const ane_kerneldma_h13_t *k =
      (const ane_kerneldma_h13_t *)&state->values[H13_KERNELDMA_START / 4];
  printf("        --- KernelDMA (0x1F800) ---\n");
  for (int i = 0; i < 16; i++) {
    if (k->coeff_dma_config[i].en) {
      printf("        Coeff[%d]: En=%d CacheHint=%u Base=0x%08x Size=0x%08x\n",
             i, k->coeff_dma_config[i].en, k->coeff_dma_config[i].cache_hint,
             k->coeff_base_addr[i].addr, k->coeff_bfr_size[i]);
    }
  }
}

void print_common_h16(const hwx_state_t *state) {
  printf("        --- Common Config ---\n");
  ane_common_h16_t common =
      *(ane_common_h16_t *)&state->values[H16_COMMON_START / 4];

  if (state->valid[(H16_COMMON_START + 0x4) / 4] ||
      state->valid[(H16_COMMON_START + 0x8) / 4] ||
      state->valid[(H16_COMMON_START + 0xC) / 4] ||
      state->valid[(H16_COMMON_START + 0x10) / 4] ||
      state->valid[H16_COMMON_START / 4]) {
    const char *infmt_name = get_ch_fmt_name(common.ch_cfg.infmt);
    const char *outfmt_name = get_ch_fmt_name(common.ch_cfg.outfmt);
    printf("        InDim     : W=%u H=%u C=%u D=%u Type=%s\n", common.inwidth,
           common.inheight, common.inchannels, common.indepth, infmt_name);
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
    printf("        ConvCfg3D : 0x%08x\n", common.conv_cfg_3d);
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
    printf("        MACCfg    : ActiveNE=%u SmallSrc=%u TaskType=%u L2Barr=%d "
           "OutTrans=%d\n",
           common.maccfg.active_ne, common.maccfg.small_src_mode,
           common.maccfg.task_type, common.maccfg.l2_barrier,
           common.maccfg.out_trans);
  }

  if (state->valid[(H16_COMMON_START + 0x40) / 4]) {
    printf("        LaneCfg   : OCGSize=%u\n", common.lane_cfg.ocg_size);
  }

  if (state->valid[(H16_COMMON_START + 0x48) / 4]) {
    printf("        PERouting : S1WB=%d S1HB=%d S1DB=%d S1CB=%d S2WB=%d "
           "S2HB=%d S2DB=%d S2CB=%d S1T=%d S2T=%d OT=%d\n",
           common.pe_routing.src1_w_bcast, common.pe_routing.src1_h_bcast,
           common.pe_routing.src1_d_bcast, common.pe_routing.src1_c_bcast,
           common.pe_routing.src2_w_bcast, common.pe_routing.src2_h_bcast,
           common.pe_routing.src2_d_bcast, common.pe_routing.src2_c_bcast,
           common.pe_routing.src1_trans, common.pe_routing.src2_trans,
           common.pe_routing.out_trans);
  }

  if (state->valid[(H16_COMMON_START + 0x4C) / 4])
    printf("        NID       : 0x%08x\n", common.nid);
  if (state->valid[(H16_COMMON_START + 0x50) / 4])
    printf("        DPE       : 0x%08x\n", common.dpe);
}

void print_ne_h16(const hwx_state_t *state) {
  ane_ne_h16_t ne = *(ane_ne_h16_t *)&state->values[H16_NE_START / 4];
  printf("        --- Neural Engine Config ---\n");

  if (state->valid[H16_NE_START / 4]) {
    printf("        KernelCfg: Fmt=%s Palettized=%d (%dbit) SparseFmt=%d "
           "AsymQuant=%d\n",
           get_ch_fmt_name(ne.kernel_cfg.kernel_fmt),
           ne.kernel_cfg.palettized_en, ne.kernel_cfg.palettized_bits,
           ne.kernel_cfg.sparse_fmt, ne.kernel_cfg.asym_quant_en);
  }

  if (state->valid[(H16_NE_START + 0x4) / 4]) {
    printf("        MACCfg: OpMode=%d KernelMode=%d BiasEn=%d Passthrough=%d "
           "MVBiasEn=%d BinaryPoint=%u PostScaleEn=%d NonLinear=%d\n"
           "                PaddingMode=%d MaxPoolMode=%d "
           "ArgOutputSelect=%d "
           "DoubleInt8En=%d\n",
           ne.mac_cfg.op_mode, ne.mac_cfg.kernel_mode, ne.mac_cfg.ne_bias_en,
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
  printf("        --- Planar Engine Config ---\n");

  if (state->valid[H16_PE_START / 4]) {
    printf("        PEConfig: Op=%d Cond=%d Src1=%d Src2=%d\n", pe.pe_cfg.op,
           pe.pe_cfg.cond, pe.pe_cfg.src1, pe.pe_cfg.src2);
  }
  if (state->valid[(H16_PE_START + 0x4) / 4])
    printf("        PEBias   : 0x%05x (%f)\n", pe.bias & 0x7FFFF,
           decode_f19(pe.bias));
  if (state->valid[(H16_PE_START + 0x8) / 4])
    printf("        PEScale  : 0x%05x (%f)\n", pe.scale & 0x7FFFF,
           decode_f19(pe.scale));
  if (state->valid[(H16_PE_START + 0x0c) / 4])
    printf("        PEFScale : 0x%05x (%f)\n", pe.final_scale & 0x7FFFF,
           decode_f19(pe.final_scale));
  if (state->valid[(H16_PE_START + 0x10) / 4])
    printf("        PEPScale : 0x%05x (%f)\n", pe.pre_scale & 0x7FFFF,
           decode_f19(pe.pre_scale));
  if (state->valid[(H16_PE_START + 0x14) / 4])
    printf("        PEFScale2: 0x%05x (%f)\n", pe.final_scale2 & 0x7FFFF,
           decode_f19(pe.final_scale2));
  if (state->valid[(H16_PE_START + 0x38) / 4]) {
    printf("        PEQuant: InReLU=%d OutReLU=%d ZeroPoint=%d\n",
           pe.quant.input_relu, pe.quant.output_relu, pe.quant.zero_point);
  }
}

void print_l2_h16(const hwx_state_t *state) {
  ane_l2_h16_t l2 = *(ane_l2_h16_t *)&state->values[H16_L2_START / 4];
  printf("        --- L2 Cache Control ---\n");

  if (state->valid[H16_L2_START / 4]) {
    printf("        L2Control: Padding=%d Src1FIFO=%d Src1Double=%d "
           "Barrier=%d\n",
           l2.l2_control.padding_mode, l2.l2_control.src1_fifo,
           l2.l2_control.src1_double, l2.l2_control.barrier);
  }
  if (state->valid[(H16_L2_START + 0x04) / 4]) {
    printf("        Src1Cfg  : Type=%d DmaFmt=%d Interleave=%d OffY=%d "
           "Comp=%d\n",
           l2.src1_cfg.src_type, l2.src1_cfg.dma_fmt, l2.src1_cfg.interleave,
           l2.src1_cfg.offset_y_lsbs, l2.src1_cfg.compression);
  }
  if (state->valid[(H16_L2_START + 0x08) / 4]) {
    printf("        Src2Cfg  : Type=%d Interleave=%d Comp=%d\n",
           l2.src2_cfg.src_type, l2.src2_cfg.interleave,
           l2.src2_cfg.compression);
  }
  if (state->valid[(H16_L2_START + 0x10) / 4]) {
    printf("        Src1  : BaseAddr=0x%05x CStride=0x%05x "
           "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
           l2.src1.base, l2.src1.channel_stride, l2.src1.row_stride,
           l2.src1.depth_stride, l2.src1.group_stride);
  }
  if (state->valid[(H16_L2_START + 0x24) / 4]) {
    printf("        Src2  : BaseAddr=0x%05x CStride=0x%05x "
           "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
           l2.src2.base, l2.src2.channel_stride, l2.src2.row_stride,
           l2.src2.depth_stride, l2.src2.group_stride);
  }
  if (state->valid[(H16_L2_START + 0x38) / 4]) {
    printf("        SrcIdx: BaseAddr=0x%05x CStride=0x%05x "
           "DStride=0x%05x GStride=0x%05x\n",
           l2.srcidx.base, l2.srcidx.channel_stride, l2.srcidx.depth_stride,
           l2.srcidx.group_stride);
  }
  if (state->valid[(H16_L2_START + 0x48) / 4]) {
    printf("        ResCfg: BfrMode=%d CropX=%d Interleave=%d Type=%d "
           "Comp=%d\n",
           l2.result_cfg.bfr_mode, l2.result_cfg.crop_offset_x,
           l2.result_cfg.interleave, l2.result_cfg.res_type,
           l2.result_cfg.compression);
  }
  if (state->valid[(H16_L2_START + 0x4c) / 4]) {
    printf("        Result: BaseAddr=0x%05x CStride=0x%05x "
           "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
           l2.result.base, l2.result.channel_stride, l2.result.row_stride,
           l2.result.depth_stride, l2.result.group_stride);
  }
  if (state->valid[(H16_L2_START + 0x7c) / 4]) {
    printf("        Res2 / L2Wr: BaseAddr=0x%05x CStride=0x%05x "
           "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
           l2.result2.base, l2.result2.channel_stride, l2.result2.row_stride,
           l2.result2.depth_stride, l2.result2.group_stride);
  }
  if (state->valid[(H16_L2_START + 0x74) / 4]) {
    printf("        ResultWrap: Index=0x%x StartOffset=0x%x\n",
           l2.result_wrap_idx_off.wrap_index,
           l2.result_wrap_idx_off.wrap_start_offset);
  }
  if (state->valid[(H16_L2_START + 0x9c) / 4]) {
    printf("        ResultWrap: Addr=0x%x AddrOffset=0x%x\n",
           l2.result_wrap_addr.wrap_addr, l2.result_wrap_addr.wrap_addr_offset);
  }
}

void print_tiledma_src_h16(const hwx_state_t *state) {
  const ane_tiledma_src_h16_t *src =
      (const ane_tiledma_src_h16_t *)&state->values[H16_TILEDMA_SRC_START / 4];
  printf("        --- TileDMA Source (0x4D00) ---\n");
  if (state->valid[H16_TILEDMA_SRC_START / 4]) {
    printf("        Src1DMAConfig: En=%d DSID=%u Tag=%u Format=%u\n",
           src->src1cfg.en, src->src1cfg.dataset_id, src->src1cfg.user_tag,
           src->src1cfg.format);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x04) / 4]) {
    printf("        Src2DMAConfig: En=%d DSID=%u Tag=%u DepMode=%u\n",
           src->src2cfg.en, src->src2cfg.dataset_id, src->src2cfg.user_tag,
           src->src2cfg.dep_mode);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x18) / 4]) {
    printf("        Src1Strides: RowStride=0x%08x PlaneStride=0x%08x "
           "DepthStride=0x%08x GroupStride=0x%08x\n",
           src->src1rows, src->src1chans, src->src1depths, src->src1groups);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x30) / 4]) {
    printf("        Src2Strides: RowStride=0x%08x PlaneStride=0x%08x "
           "DepthStride=0x%08x GroupStride=0x%08x\n",
           src->src2rows, src->src2chans, src->src2depths, src->src2groups);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x50) / 4]) {
    printf("        Src1MetaData: Addr=0x%08x%08x Size=0x%08x\n",
           src->src1meta_hi, src->src1meta_lo, src->src1meta_size);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x5c) / 4]) {
    printf("        Src2MetaData: Addr=0x%08x%08x Size=0x%08x\n",
           src->src2meta_hi, src->src2meta_lo, src->src2meta_size);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0x68) / 4]) {
    printf("        Src1Fmt: 0x%08x, Src2Fmt: 0x%08x\n", src->src1memfmt,
           src->src2memfmt);
  }
}

void print_tiledma_dst_h16(const hwx_state_t *state) {
  ane_tiledma_dst_h16_t *dst =
      (ane_tiledma_dst_h16_t *)&state->values[H16_TILEDMA_DST_START / 4];
  printf("        --- TileDMA Destination (0x5100) ---\n");
  if (state->valid[H16_TILEDMA_DST_START / 4]) {
    printf("        DstDMAConfig: En=%d CacheHint=%u DSID=%u Tag=%u\n",
           dst->dstcfg.en, dst->dstcfg.cache_hint, dst->dstcfg.dataset_id,
           dst->dstcfg.user_tag);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x10) / 4]) {
    printf("        DstStrides: RowStride=0x%08x PlaneStride=0x%08x "
           "DepthStride=0x%08x GroupStride=0x%08x\n",
           dst->dstrows, dst->dstchans, dst->dstdepths, dst->dstgroups);
  }
}

void print_kerneldma_h16(const hwx_state_t *state) {
  ane_kerneldma_src_h16_t *k =
      (ane_kerneldma_src_h16_t *)&state->values[H16_KERNELDMA_START / 4];
  printf("        --- KernelDMA Source (0x5500) ---\n");
  if (state->valid[H16_KERNELDMA_START / 4])
    printf("        MasterConfig: MasterEnable=%d\n",
           k->master_cfg.master_enable);
  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0x20) / 4 + i] ||
        state->valid[(H16_KERNELDMA_START + 0x60) / 4 + i]) {
      printf("        Coeff[%d]: En=%d CacheHint=%u DSID=%u Tag=%u "
             "Base=0x%08x "
             "Size=0x%08x\n",
             i, k->coeff_cfg[i].en, k->coeff_cfg[i].cache_hint,
             k->coeff_cfg[i].dataset_id, k->coeff_cfg[i].user_tag,
             k->coeff_base[i], k->coeff_size[i]);
    }
  }
  if (state->valid[(H16_KERNELDMA_START + 0xe0) / 4])
    printf("        Bias: En=%d CacheHint=%u Tag=%u\n", k->bias_cfg.en,
           k->bias_cfg.cache_hint, k->bias_cfg.user_tag);
  if (state->valid[(H16_KERNELDMA_START + 0xf0) / 4])
    printf("        PostScale: En=%d CacheHint=%u Tag=%u\n",
           k->post_scale_cfg.en, k->post_scale_cfg.cache_hint,
           k->post_scale_cfg.user_tag);
  if (state->valid[(H16_KERNELDMA_START + 0x100) / 4])
    printf("        Palette: En=%d CacheHint=%u Tag=%u\n", k->palette_cfg.en,
           k->palette_cfg.cache_hint, k->palette_cfg.user_tag);
  if (state->valid[(H16_KERNELDMA_START + 0x110) / 4])
    printf("        NonLinear: En=%d CacheHint=%u Tag=%u\n",
           k->non_linear_cfg.en, k->non_linear_cfg.cache_hint,
           k->non_linear_cfg.user_tag);
}

void print_cachedma_h16(const hwx_state_t *state) {
  ane_cachedma_h16_t cdma =
      *(ane_cachedma_h16_t *)&state->values[H16_CACHEDMA_START / 4];
  printf("        --- CacheDMA & Telemetry (0x5900) ---\n");
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

void decode_ane_td(const uint8_t *ptr, size_t total_len, BOOL dump_reg_blocks) {
  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_td_header_h13_t) <= total_len) {
    const ane_td_header_h13_t *td = (const ane_td_header_h13_t *)(ptr + offset);
    if (td->next_pointer == 0 && td->exe_cycles == 0 && td->log_events == 0) {
      break; // Hit zero padding
    }

    printf("      [ANE Task %d @ 0x%x]\n", task_idx++, offset);
    printf("        TID: 0x%04x NID: 0x%02x LNID: %d EON: %d\n", td->tid,
           td->nid, td->lnid, td->eon);
    printf("        ExeCycles: %u NextSize: %u\n", td->exe_cycles,
           td->next_size);
    printf("        NextPtr: 0x%08x TSR: %d TSE: %d ENE: %d\n",
           td->next_pointer, td->flags.tsr, td->flags.tse, td->base_ene.ene);
    printf("        RBase: %d/%d WBase: %d TBase: %d\n", td->base_ene.rbase0,
           td->base_ene.rbase1, td->base_ene.wbase, td->base_ene.tbase);
    if (td->kbase.kbe0 || td->kbase.kbe1 || td->kbase.kbe2 || td->kbase.kbe3) {
      printf("        KBase: %d/%d/%d/%d\n", td->kbase.kbase0, td->kbase.kbase1,
             td->kbase.kbase2, td->kbase.kbase3);
    }

    hwx_state_t state = {0};

    // Modern Stream Parse
    if (offset + sizeof(ane_td_header_h13_t) <= total_len) {
      const uint32_t *words = (const uint32_t *)(td + 1);
      uint32_t max_payload_bytes =
          (total_len > offset + sizeof(ane_td_header_h13_t))
               ? (uint32_t)(total_len - offset - sizeof(ane_td_header_h13_t))
               : 0;
      uint32_t num_words = max_payload_bytes / 4;

      if (td->next_pointer > offset + sizeof(ane_td_header_h13_t)) {
        uint32_t td_words =
            (td->next_pointer - offset - sizeof(ane_td_header_h13_t)) / 4;
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

    if (offset + sizeof(ane_td_header_h13_t) <= total_len) {

      print_common_h13(&state);
      print_l2_h13(&state);
      print_pe_h13(&state);
      print_ne_h13(&state);
      print_tiledma_src_h13(&state);
      print_tiledma_dst_h13(&state);
      print_kerneldma_h13(&state);

      if (dump_reg_blocks) {
        hwx_block_info_t blocks[] = {
            {"[0x00000] Common Module", H13_COMMON_START},
            {"[0x04800] L2 Cache Control", H13_L2_START},
            {"[0x08800] Planar Engine (PE)", H13_PE_START},
            {"[0x0C800] Neural Engine Core (NE)", H13_NE_START},
            {"[0x13800] TileDMA Source", H13_TILEDMA_SRC_START},
            {"[0x17800] TileDMA Destination", H13_TILEDMA_DST_START},
            {"[0x1F800] KernelDMA Source", H13_KERNELDMA_START},
        };
        dump_hw_blocks(&state, blocks, 7, get_m1_reg_name);
      }
    }

    if (td->next_pointer == 0 || td->next_pointer <= offset)
      break;
    offset = td->next_pointer;
  }
}

void decode_ane_td_m4(const uint8_t *ptr, size_t total_len, uint32_t subtype,
                      BOOL dump_reg_blocks) {
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

    uint32_t size_bytes = m4h->task_size * 4;
    printf("      [ANE Task %d @ 0x%x] (Size: 0x%x bytes)\n", task_idx++,
           offset, size_bytes);

    printf("        TID: 0x%04x ExeCycles: %u ENE: %u\n", m4h->tid,
           m4h->exe_cycles, m4h->ene);
    printf("        LogEvents: 0x%06x Exceptions: 0x%06x\n", m4h->log_events,
           m4h->exceptions);
    printf("        LiveOuts: 0x%08x TSR: %d TDE: %d\n", m4h->live_outs,
           m4h->tsr, m4h->tde);
    if (m4h->tde == 1) {
      printf("        TDID: 0x%04x\n", m4h->tdid);
    }

    hwx_state_t state = {0};

    // Phase 4: Verbose Register Logging
    const uint32_t *words = (const uint32_t *)(ptr + offset);
    int num_words = size_bytes / 4;
    int i = sizeof(ane_header_h16_t) / 4;

    if (i >= num_words)
      break;

    while (i < num_words) {
      uint32_t header = words[i++];
      uint32_t word_addr = header & 0x7FFF;
      uint16_t num_regs = 0;

      if ((header >> 31) == 0) {
        // Sequential / Burst Mode
        num_regs = (header >> 15) & 0x3F;
        for (int j = 0; j <= num_regs && i < num_words; j++) {
          uint32_t current_addr = word_addr + j;
          if (current_addr < HW_MAX_REGS) {
            state.values[current_addr] = words[i];
            state.valid[current_addr] = true;
          }
          i++;
        }
      } else {
        // Masked / Scattered Mode
        uint32_t mask = (header >> 15) & 0xFFFF; // 16-bit mask
        num_regs = __builtin_popcount(mask);

        // V11 Masked commands always include the base register value first
        if (i < num_words) {
          uint32_t current_addr = word_addr;
          if (current_addr < HW_MAX_REGS) {
            state.values[current_addr] = words[i];
            state.valid[current_addr] = true;
          }
          i++;
        }

        // Then follow the registers indicated by the 16-bit mask
        for (int bit = 0; bit < 16 && i < num_words; bit++) {
          if ((mask >> bit) & 1) {
            uint32_t current_addr = word_addr + bit + 1;
            if (current_addr < HW_MAX_REGS) {
              state.values[current_addr] = words[i];
              state.valid[current_addr] = true;
            }
            i++;
          }
        }
      }
    }
    printf("        Stream Parse: OK (End index %d/%d)\n", i, num_words);

    // Decode HW Blocks using specialized decoders
    print_common_h16(&state);
    print_l2_h16(&state);
    print_pe_h16(&state);
    print_ne_h16(&state);
    print_tiledma_src_h16(&state);
    print_tiledma_dst_h16(&state);
    print_kerneldma_h16(&state);
    print_cachedma_h16(&state);

    if (dump_reg_blocks) {
      hwx_block_info_t blocks[] = {
          {"[0x0000] Common Module", H16_COMMON_START},
          {"[0x4100] L2 Cache Control", H16_L2_START},
          {"[0x4500] Planar Engine (PE)", H16_PE_START},
          {"[0x4900] Neural Engine Core (NE)", H16_NE_START},
          {"[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START},
          {"[0x5100] TileDMA Destination", H16_TILEDMA_DST_START},
          {"[0x5500] KernelDMA Source", H16_KERNELDMA_START},
          {"[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START},
      };
      dump_hw_blocks(&state, blocks, 8, get_m4_reg_name);
    }

    if (offset + size_bytes > total_len)
      break;
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
                              BOOL dump_hexdump, BOOL dump_reg_blocks) {
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
                             dump_reg_blocks);
          } else {
            decode_ane_td(section_ptr, section_size, dump_reg_blocks);
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
      if ((const uint8_t *)(list + 1) > (const uint8_t *)data.bytes + data.length)
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
                         BOOL dump_hexdump, BOOL dump_reg_blocks) {
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
        handle_segment_64(header, lc, data, dump_hexdump, dump_reg_blocks);
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

    while ((ch = getopt(argc, argv, "strx")) != -1) {
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
      case '?':
      default:
        printf("Usage: %s [-s] [-t] [-r] [-x] <path_to_hwx>\n", getprogname());
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
                        dump_reg_blocks);
  }
  return 0;
}
