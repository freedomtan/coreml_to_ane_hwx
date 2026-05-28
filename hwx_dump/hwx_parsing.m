#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#import "ane_hwx_regs.h"
#import "hwx_register_names.h"

// Forward declarations
const char *get_l2_dma_fmt_name(uint32_t val);
// Helper function declarations
static void recover_dimensions_from_l2_cache(const hwx_state_t *state,
                                             uint32_t *inw, uint32_t *inh, uint32_t *inc);
static void parse_instruction_stream_h13(const uint8_t *ptr, size_t total_len,
                                         uint32_t offset, const ane_header_h13_t *td,
                                         hwx_state_t *state);
static void parse_instruction_stream_h16(const uint8_t *ptr, uint32_t offset,
                                         const ane_header_h16_t *hdr,
                                         hwx_state_t *state);

void print_common_h13(const hwx_state_t *state);
void print_common_h14(const hwx_state_t *state);
void print_common_h16(const hwx_state_t *state);
void print_l2_h13(const hwx_state_t *state);
void print_l2_h14(const hwx_state_t *state);
void print_l2_h16(const hwx_state_t *state);
void print_l2_h17(const hwx_state_t *state);
void print_l2_h18(const hwx_state_t *state);
void print_pe_h13(const hwx_state_t *state);
void print_pe_h14(const hwx_state_t *state);
void print_pe_h16(const hwx_state_t *state);
void print_pe_h17(const hwx_state_t *state);
void print_pe_h18(const hwx_state_t *state);
void print_pe_index_h16(const hwx_state_t *state);
void print_ne_h13(const hwx_state_t *state);
void print_ne_h14(const hwx_state_t *state);
void print_ne_h16(const hwx_state_t *state);
void print_tiledmasrc_h13(const hwx_state_t *state);
void print_tiledmasrc_h14(const hwx_state_t *state);
void print_tiledmasrc_h16(const hwx_state_t *state);
void print_tiledmadst_h13(const hwx_state_t *state);
void print_tiledmadst_h14(const hwx_state_t *state);
void print_tiledmadst_h16(const hwx_state_t *state);
void print_kerneldmasrc_h13(const hwx_state_t *state);
void print_kerneldmasrc_h14(const hwx_state_t *state);
void print_kerneldmasrc_h16(const hwx_state_t *state);
void print_kerneldmasrc_h17(const hwx_state_t *state);
void print_kerneldmasrc_h18(const hwx_state_t *state);
void print_cachedma_h16(const hwx_state_t *state);

// Architecture printer function table
typedef struct {
  void (*print_common)(const hwx_state_t *state);
  void (*print_l2)(const hwx_state_t *state);
  void (*print_pe_index)(const hwx_state_t *state);  // H16+ only
  void (*print_pe)(const hwx_state_t *state);
  void (*print_ne)(const hwx_state_t *state);
  void (*print_tiledmasrc)(const hwx_state_t *state);
  void (*print_tiledmadst)(const hwx_state_t *state);
  void (*print_kerneldmasrc)(const hwx_state_t *state);
  void (*print_cachedma)(const hwx_state_t *state);  // H16+ only
} arch_printers_t;

// Architecture descriptor
typedef struct {
  uint32_t instr_ver;
  uint32_t subtype;
  const char *name;
  const char *(*get_reg_name)(uint32_t);
  const arch_printers_t *printers;
  const hwx_block_info_t *blocks;
  int block_count;
} arch_descriptor_t;

// Register address constants for dimension extraction in print_common_h16()
// These are word offsets (not byte addresses) into the hwx_state_t->values[] array
#define REG_COMMON_CH_CFG           0x0     // Channel format config (Common+0x0)
#define REG_COMMON_IN_WIDTH         0x1     // Input width (Common+0x4)
#define REG_COMMON_IN_HEIGHT        0x2     // Input height (Common+0x8)
#define REG_COMMON_IN_CHANNELS      0x3     // Input channels (Common+0xc)
#define REG_COMMON_ALT_IN_WIDTH     0xb     // Alternative width location (shifted header)
#define REG_COMMON_ALT_IN_HEIGHT    0xc     // Alternative height location (shifted header)
#define REG_COMMON_ALT_IN_CHANNELS  0xd     // Alternative channels location (shifted header)

// L2 Cache register offsets (for dimension recovery heuristics)
#define REG_L2_POOL_STRIDE          0x1045  // L2+0x14: Pooling stride register
#define REG_L2_OP_DISCRIMINATOR     0x1046  // L2+0x18: Operation type discriminator
#define REG_L2_CACHE_STRIDE         0x1047  // L2+0x1c: Cache stride (width × factor)
#define REG_L2_PACKED_CHANNELS_1    0x1044  // L2+0x10: Packed value with channels in high 16 bits
#define REG_L2_PACKED_CHANNELS_2    0x1053  // L2+0x4c: Alternative packed channels location

// TileDMA Destination register offsets
#define REG_TDMA_DST_CHANNELS       0x1442  // TileDMA Dst+0x8: Destination channels (high 16 bits)

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
  static const hwx_reg_range_t m1_ranges[] = {
      {H13_COMMON_START, 16, h13_common_names},
      {H13_L2_START, 16, h13_l2_names},
      {H13_PE_START, 4, h13_pe_names},
      {H13_NE_START, 5, h13_ne_names},
      {H13_TILEDMA_SRC_START, 24, h13_tdma_src_names},
      {H13_TILEDMA_DST_START, 7, h13_tdma_dst_names},
      {H13_KERNELDMA_START, 5, h13_kdma_names},
  };

  return lookup_reg_name(addr, m1_ranges, 7);
}

// H14 (ISA v11, subtype 5) uses OLD hardware addresses.
// PE=0x0900, NE=0x0D00, TileDmaDst=0x1500, no CacheDMA block.
const char *get_h14_reg_name(uint32_t addr) {
  static const hwx_reg_range_t h14_ranges[] = {
      {H14_COMMON_START,      16,                     h13_common_names},
      {H14_L2_START,          16,                     h13_l2_names},
      {H14_PE_START,          4,                      h13_pe_names},
      {H14_NE_START,          5,                      h13_ne_names},
      {H14_TILEDMA_SRC_START, 24,                     h13_tdma_src_names},
      {H14_TILEDMA_DST_START, 7,                      h13_tdma_dst_names},
      {H14_KERNELDMA_START,   5,                      h13_kdma_names},
  };

  return lookup_reg_name(addr, h14_ranges, 7);
}

const char *get_m4_reg_name(uint32_t addr) {
  static const hwx_reg_range_t m4_ranges[] = {
      {H16_COMMON_START, 23, h16_common_names},
      {H16_L2_START, 41, h16_l2_names},
      {H16_PE_EXT_START, 1, h16_pe_index_names},
      {H16_PE_START, 15, h16_pe_names},
      {H16_NE_START, 12, h16_ne_names},
      {H16_CACHEDMA_START, 12, h16_cdma_names},
      {H16_TILEDMA_SRC_START, 81, h16_tdma_src_names},
      {H16_TILEDMA_DST_START, 21, h16_tdma_dst_names},
      {H16_KERNELDMA_START, 72, h16_kdma_names},
  };

  return lookup_reg_name(addr, m4_ranges, 9);
}

const char *get_h17_reg_name(uint32_t addr) {
  static const hwx_reg_range_t h17_ranges[] = {
      {H16_COMMON_START, H17_COMMON_COUNT, h16_common_names},
      {H16_L2_START, H17_L2_COUNT, h17_l2_names},
      {H16_PE_START, H17_PE_COUNT, h17_pe_names},
      {H16_NE_START, H17_NE_COUNT, h17_ne_names},
      {H16_TILEDMA_SRC_START, H17_TILEDMA_SRC_COUNT, h17_tdma_src_names},
      {H16_TILEDMA_DST_START, H17_TILEDMA_DST_COUNT, h17_tdma_dst_names},
      {H16_KERNELDMA_START, H17_KERNELDMA_COUNT, h17_kdma_names},
      {H16_CACHEDMA_START, H17_CACHEDMA_COUNT, h17_cdma_names},
  };

  return lookup_reg_name(addr, h17_ranges, 8);
}

const char *get_h18_reg_name(uint32_t addr) {
  static const hwx_reg_range_t h18_ranges[] = {
      {H16_COMMON_START, H18_COMMON_COUNT, h16_common_names},
      {H16_L2_START, H18_L2_COUNT, h18_l2_names},
      {H16_PE_START, H18_PE_COUNT, h17_pe_names},
      {H16_NE_START, H18_NE_COUNT, h17_ne_names},
      {H16_TILEDMA_SRC_START, H18_TILEDMA_SRC_COUNT, h16_tdma_src_names},
      {H16_TILEDMA_DST_START, H18_TILEDMA_DST_COUNT, h18_tdma_dst_names},
      {H16_KERNELDMA_START, H18_KERNELDMA_COUNT, h18_kdma_names},
      {H16_CACHEDMA_START, H18_CACHEDMA_COUNT, h17_cdma_names},
  };

  return lookup_reg_name(addr, h18_ranges, 8);
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

  uint32_t sign = (val >> 18) & 0x1;
  uint32_t exponent = (val >> 10) & 0xFF;  // Preserved 8-bit dynamic range
  uint32_t mantissa = (val & 0x3FF) << 13; // Padding to 23-bit precision

  uint32_t f32_bits = (sign << 31) | (exponent << 23) | mantissa;

  return (float)(f32_bits);
}

static void print_float_reg(const char *name, uint32_t val) {
  if (val & 0xFFF80000) {
    printf("        %-23s: 0x%08x (%f)\n", name, val, *(float *)&val);
  } else {
    uint32_t bits = (val & 0x7FFFF) << 13;
    printf("        %-23s: 0x%05x (%f)\n", name, val & 0x7FFFF, *(float *)&bits);
  }
}


const char *get_hw_tensor_format_name_v17(uint32_t mode, uint32_t mem_fmt,
                                          uint32_t trunc, uint32_t shift) {
  if (mode == 3 && mem_fmt == 3 && shift == 1)
    return "FLOAT32";
  if (mode == 1 && mem_fmt == 2 && trunc == 3)
    return "FLOAT16";
  if (mode == 0 && mem_fmt == 1)
    return "INT8";
  if (mode == 0 && mem_fmt == 0 && shift == 0 && trunc == 0)
    return "UINT8";
  if (mode == 1 && mem_fmt == 2 && trunc == 1 && shift == 0)
    return "RAW12";
  if (mode == 1 && mem_fmt == 0 && trunc == 1 && shift == 1)
    return "Y12";
  if (mode == 2 && mem_fmt == 3)
    return "INT16";
  if (mode == 2 && mem_fmt == 0 && shift == 1)
    return "Packed10 (Deprecated?)";
  if (mode == 1 && trunc == 3 && shift == 1) {
    if (mem_fmt == 0)
      return "RAW10";
    if (mem_fmt == 1)
      return "Y10";
    if (mem_fmt == 2)
      return "RAW10/Y10 (Shared)";
  }
  return "UNKNOWN";
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

const char *get_l2_dma_fmt_name(uint32_t fmt) {
  switch (fmt) {
  case 0:
    return "8b";
  case 1:
    return "16b";
  case 3:
    return "32b";
  default:
    return "??";
  }
}

const char *get_pe_op_mode_name_v17(uint32_t op) {
  switch (op) {
  case 0:
    return "Add";
  case 1:
    return "Mul";
  case 2:
    return "Max";
  case 3:
    return "Min";
  case 4:
    return "SumSqr";
  default:
    return "Unknown";
  }
}

const char *get_pe_pool_mode_name_v17(uint32_t mode) {
  switch (mode) {
  case 0:
    return "None";
  case 1:
    return "Avg";
  case 2:
    return "Max";
  case 3:
    return "Min";
  default:
    return "Unknown";
  }
}

const char *get_pe_condition_name_v17(uint32_t cond) {
  static const char *labels[] = {"None",    "Abs",          "Equal",
                                 "Greater", "GreaterEqual", "LessEqual",
                                 "Less",    "NotEqual"};
  return (cond < 8) ? labels[cond] : "Unknown";
}

const char *get_pe_nl_mode_name_v17(uint32_t mode) {
  static const char *labels[] = {"None", "ReLU", "Clamp", "Abs"};
  return (mode < 4) ? labels[mode] : "Unknown";
}

const char *get_pe_src1_name_v17(uint32_t sel) {
  return (sel == 0)   ? "PrimarySource"
         : (sel == 1) ? "TextureSource"
                      : "Unknown";
}

const char *get_pe_src2_name_v17(uint32_t sel) {
  static const char *labels[] = {"PrimarySource", "TextureSource", "L2Source",
                                 "RegSource"};
  return (sel < 4) ? labels[sel] : "Unknown";
}

const char *get_ne_op_mode_name(uint32_t mode) {
  switch (mode) {
  case 0:
    return "Conv";
  case 1:
    return "ElemWise";
  case 2:
    return "RCAS";
  case 3:
    return "EWSqrt";
  case 4:
    return "Bypass";
  case 5:
    return "TransposedConv";
  default:
    return "Unknown";
  }
}

uint32_t get_task_type_mapping(uint32_t subtype) {
  switch (subtype) {
  case 0:
    return 0;
  case 1:
    return 2;
  case 2:
    return 6;
  case 3:
    return 5;
  case 4:
    return 7;
  case 5:
    return 4;
  case 6:
    return 3;
  case 7:
    return 0;
  case 8:
    return 1;
  default:
    return 0;
  }
}

const char *get_hw_task_type_name(uint32_t type) {
  switch (type) {
  case 1:
    return "Pooling w/o input ReLU";
  case 2:
    return "Pooling w/ input ReLU";
  case 3:
    return "EW w/ Reduction w/o ReLU";
  case 4:
    return "EW w/ Reduction w/ ReLU";
  case 5:
    return "EW w/o Reduction w/o ReLU";
  case 6:
    return "EW w/o Reduction w/ ReLU";
  case 7:
    return "GOC";
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
  const ane_l2_h13_t *l2 =
      (const ane_l2_h13_t *)&state->values[H13_L2_START / 4];
  printf("        L2Cfg: InputReLU=%d PaddingMode=%u\n", l2->l2cfg.input_relu,
         l2->l2cfg.padding_mode);
  printf("        L2 SourceCfg: Type=%u Dep=%u DMAFmt=%s Intrlv=%u CmpV=%u "
         "OffCh=%u\n",
         l2->scfg.type, l2->scfg.dep, get_l2_dma_fmt_name(l2->scfg.fmt),
         l2->scfg.interleave, l2->scfg.cmpv, l2->scfg.offch);
  printf("        L2 Src1: Base=0x%05x ChanStride=0x%05x RowStride=0x%05x\n",
         l2->srcbase.addr, l2->src_chan_stride.stride,
         l2->src_row_stride.stride);

  printf("        L2 ResultCfg: Type=%u Bfr=%u DMAFmt=%s Intrlv=%u CmpV=%u "
         "OffCh=%u\n",
         l2->rcfg.type, l2->rcfg.bfrmode, get_l2_dma_fmt_name(l2->rcfg.fmt),
         l2->rcfg.interleave, l2->rcfg.cmpv, l2->rcfg.offch);
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

// ---------------------------------------------------------------------------
// H14 (ISA v11 / subtype 5) semantic printers
// All read from H14 OLD addresses: Common=0x0000, L2=0x0500, PE=0x0900,
// NE=0x0D00, TileDmaSrc=0x1100, TileDmaDst=0x1500, KernelDmaSrc=0x1900.
// ---------------------------------------------------------------------------

void print_common_h14(const hwx_state_t *state) {
  printf("        --- Common (0x0000) ---\n");
  // H14 Common layout: 19 registers starting at word 0
  uint32_t w0  = state->values[H14_COMMON_START/4 + 0];  // ChannelCfg
  uint32_t w1  = state->values[H14_COMMON_START/4 + 1];  // InWidth
  uint32_t w2  = state->values[H14_COMMON_START/4 + 2];  // InHeight
  uint32_t w3  = state->values[H14_COMMON_START/4 + 3];  // InChannels
  uint32_t w5  = state->values[H14_COMMON_START/4 + 5];  // OutWidth
  uint32_t w6  = state->values[H14_COMMON_START/4 + 6];  // OutHeight
  uint32_t w7  = state->values[H14_COMMON_START/4 + 7];  // OutChannels
  uint32_t w10 = state->values[H14_COMMON_START/4 + 10]; // ConvCfg
  uint32_t w12 = state->values[H14_COMMON_START/4 + 12]; // MacCfg

  uint32_t infmt  = (w0 >> 0) & 0x3;
  uint32_t outfmt = (w0 >> 4) & 0x3;
  uint32_t inw = w1 & 0x3FFF, inh = w2 & 0x3FFF, inc = w3 & 0x3FFF;
  uint32_t outw = w5 & 0x3FFF, outh = w6 & 0x3FFF, outc = w7 & 0x3FFF;
  printf("        InDim : W=%u H=%u C=%u Type=%s\n", inw, inh, inc, get_ch_fmt_name(infmt));
  printf("        OutDim: W=%u H=%u C=%u Type=%s\n", outw, outh, outc, get_ch_fmt_name(outfmt));

  uint32_t kw = (w10 >> 0) & 0x3F, kh = (w10 >> 6) & 0x3F;
  uint32_t sx = (w10 >> 13) & 0x3, sy = (w10 >> 15) & 0x3;
  uint32_t pl = (w10 >> 17) & 0x1F, pt = (w10 >> 22) & 0x1F;
  if (kw || kh)
    printf("        ConvCfg: K=%ux%u S=%ux%u P(left/top)=%ux%u\n", kw, kh, sx, sy, pl, pt);

  uint32_t task_type = (w12 >> 0) & 0xF;
  uint32_t active_ne = (w12 >> 4) & 0x7;
  uint32_t small_src = (w12 >> 7) & 0x1;
  printf("        MacCfg: TaskType=%u ActiveNE=%u SmallSrc=%u\n", task_type, active_ne, small_src);
}

void print_l2_h14(const hwx_state_t *state) {
  printf("        --- L2 Cache (0x0500) ---\n");
  uint32_t ctrl  = state->values[H14_L2_START/4 + 0];  // 0x0500 Control
  uint32_t scfg1 = state->values[H14_L2_START/4 + 1];  // 0x0504 Src1Cfg
  uint32_t scfg2 = state->values[H14_L2_START/4 + 2];  // 0x0508 Src2Cfg
  uint32_t sbase = state->values[H14_L2_START/4 + 3];  // 0x050C Src1Base
  uint32_t rcfg  = state->values[H14_L2_START/4 + 13]; // 0x0534 ResultCfg
  uint32_t rbase = state->values[H14_L2_START/4 + 14]; // 0x0538 ResultBase

  if (!state->valid[H14_L2_START/4] && !state->valid[H14_L2_START/4 + 1])
    return;

  printf("        L2Ctrl: Src1ReLU=%u PaddingMode=%u Src2ReLU=%u\n",
         (ctrl >> 0) & 1, (ctrl >> 2) & 3, (ctrl >> 4) & 1);
  printf("        Src1Cfg: Type=%u DMAFmt=%s Intrlv=%u AliasConvSrc=%u\n",
         (scfg1 >> 0) & 3, get_l2_dma_fmt_name((scfg1 >> 6) & 3),
         (scfg1 >> 8) & 0xF, (scfg1 >> 4) & 1);
  printf("        Src2Cfg: Type=%u DMAFmt=%s Intrlv=%u\n",
         (scfg2 >> 0) & 3, get_l2_dma_fmt_name((scfg2 >> 6) & 3),
         (scfg2 >> 8) & 0xF);
  printf("        Src1Base: 0x%05x\n", sbase);
  printf("        ResultCfg: Type=%u DMAFmt=%s Intrlv=%u\n",
         (rcfg >> 0) & 3, get_l2_dma_fmt_name((rcfg >> 6) & 3),
         (rcfg >> 8) & 0xF);
  printf("        ResultBase: 0x%05x\n", rbase);
}

void print_pe_h14(const hwx_state_t *state) {
  if (!state->valid[H14_PE_START/4])
    return;
  printf("        --- Planar Engine (0x0900) ---\n");
  uint32_t cfg   = state->values[H14_PE_START/4 + 0]; // 0x0900 PEConfig
  uint32_t bias  = state->values[H14_PE_START/4 + 1]; // 0x0904 Bias (F19)
  uint32_t scale = state->values[H14_PE_START/4 + 2]; // 0x0908 Scale (F19)
  uint32_t pre   = state->values[H14_PE_START/4 + 3]; // 0x090C PreScale (F19)
  uint32_t quant = state->values[H14_PE_START/4 + 4]; // 0x0910 Quant
  printf("        PECfg: PoolMode=%u Operation=%u NLMode=%u\n",
         (cfg >> 0) & 3, (cfg >> 2) & 7, (cfg >> 12) & 3);
  printf("        Bias=0x%05x Scale=0x%05x PreScale=0x%05x\n", bias, scale, pre);
  printf("        Quant: Src1ZP=%u Src2ZP=%u OutZP=%u\n",
         (quant >> 0) & 0xFF, (quant >> 8) & 0xFF, (quant >> 16) & 0xFF);
}

void print_ne_h14(const hwx_state_t *state) {
  printf("        --- Neural Engine (0x0D00) ---\n");
  uint32_t kcfg  = state->values[H14_NE_START/4 + 0]; // 0x0D00 KernelCfg
  uint32_t mcfg  = state->values[H14_NE_START/4 + 1]; // 0x0D04 MacCfg
  uint32_t bias  = state->values[H14_NE_START/4 + 2]; // 0x0D08 NEBias
  uint32_t ps    = state->values[H14_NE_START/4 + 3]; // 0x0D0C NEPostScale
  uint32_t rmode = state->values[H14_NE_START/4 + 4]; // 0x0D10 RoundModeCfg

  printf("        KernelCfg: Fmt=%s PalEn=%u SparseEn=%u Reuse=%u\n",
         get_ch_fmt_name((kcfg >> 0) & 3),
         (kcfg >> 2) & 1, (kcfg >> 8) & 1, (kcfg >> 10) & 1);
  printf("        MacCfg: OpMode=%s KMode=%u BiasEn=%u BinPoint=%u NLMode=%u\n",
         get_ne_op_mode_name((mcfg >> 0) & 7),
         (mcfg >> 3) & 1, (mcfg >> 4) & 1, (mcfg >> 8) & 0x3F, (mcfg >> 16) & 3);
  if (state->valid[H14_NE_START/4 + 2])
    printf("        NEBias: 0x%08x\n", bias);
  if (state->valid[H14_NE_START/4 + 3])
    printf("        NEPostScale: 0x%08x\n", ps);
  if (state->valid[H14_NE_START/4 + 4])
    printf("        RoundMode: Mode=%u IntBits=%u\n", (rmode >> 0) & 3, (rmode >> 4) & 0x1F);
}

void print_tiledmasrc_h14(const hwx_state_t *state) {
  printf("        --- TileDMA Source (0x1100) ---\n");
  // Src1
  uint32_t s1cfg  = state->values[H14_TILEDMA_SRC_START/4 + 0];  // 0x1100
  uint32_t s1base = state->values[H14_TILEDMA_SRC_START/4 + 4];  // 0x1110
  uint32_t s1row  = state->values[H14_TILEDMA_SRC_START/4 + 5];  // 0x1114
  uint32_t s1ch   = state->values[H14_TILEDMA_SRC_START/4 + 6];  // 0x1118
  uint32_t s1fmt  = state->values[H14_TILEDMA_SRC_START/4 + 14]; // 0x1138
  // Src2
  uint32_t s2cfg  = state->values[H14_TILEDMA_SRC_START/4 + 1];  // 0x1104
  uint32_t s2base = state->values[H14_TILEDMA_SRC_START/4 + 9];  // 0x1124
  uint32_t s2row  = state->values[H14_TILEDMA_SRC_START/4 + 10]; // 0x1128
  uint32_t s2fmt  = state->values[H14_TILEDMA_SRC_START/4 + 15]; // 0x113C

  printf("        Src1: En=%u DataSetId=%u CacheHint=%u Base=0x%06x Row=0x%06x Ch=0x%06x\n",
         (s1cfg >> 0) & 1, (s1cfg >> 8) & 0xFF, (s1cfg >> 4) & 0xF,
         s1base >> 6, s1row >> 6, s1ch >> 6);
  printf("        Src1Fmt: Mode=%u MemFmt=%u Intrlv=%u\n",
         (s1fmt >> 0) & 3, (s1fmt >> 12) & 3, (s1fmt >> 24) & 0xF);
  if (state->valid[H14_TILEDMA_SRC_START/4 + 1]) {
    printf("        Src2: En=%u DataSetId=%u Base=0x%06x Row=0x%06x\n",
           (s2cfg >> 0) & 1, (s2cfg >> 8) & 0xFF, s2base >> 6, s2row >> 6);
    printf("        Src2Fmt: Mode=%u MemFmt=%u Intrlv=%u\n",
           (s2fmt >> 0) & 3, (s2fmt >> 12) & 3, (s2fmt >> 24) & 0xF);
  }
}

void print_tiledmadst_h14(const hwx_state_t *state) {
  printf("        --- TileDMA Destination (0x1500) ---\n");
  uint32_t cfg   = state->values[H14_TILEDMA_DST_START/4 + 0]; // 0x1500
  uint32_t base  = state->values[H14_TILEDMA_DST_START/4 + 1]; // 0x1504
  uint32_t row   = state->values[H14_TILEDMA_DST_START/4 + 2]; // 0x1508
  uint32_t plane = state->values[H14_TILEDMA_DST_START/4 + 3]; // 0x150C
  uint32_t depth = state->values[H14_TILEDMA_DST_START/4 + 4]; // 0x1510
  uint32_t group = state->values[H14_TILEDMA_DST_START/4 + 5]; // 0x1514
  uint32_t fmt   = state->values[H14_TILEDMA_DST_START/4 + 6]; // 0x1518
  uint32_t pxoff = state->values[H14_TILEDMA_DST_START/4 + 7]; // 0x151C

  printf("        DstCfg: En=%u DataSetId=%u CacheHint=%u\n",
         (cfg >> 0) & 1, (cfg >> 8) & 0xFF, (cfg >> 4) & 0xF);
  printf("        DstBase: 0x%06x RowStride=0x%06x PlaneStride=0x%06x\n",
         base >> 6, row >> 6, plane >> 6);
  if (depth || group)
    printf("        DstDepthStride=0x%06x GroupStride=0x%06x\n", depth >> 6, group >> 6);
  printf("        DstFmt: Mode=%u MemFmt=%u\n", (fmt >> 0) & 3, (fmt >> 12) & 3);
  if (pxoff)
    printf("        DstPixelOffset: 0x%04x\n", pxoff & 0xFFFF);
}

void print_kerneldmasrc_h14(const hwx_state_t *state) {
  printf("        --- KernelDMA Source (0x1900) ---\n");
  uint32_t master = state->values[H14_KERNELDMA_START/4 + 0]; // 0x1900
  uint32_t kgstr  = state->values[H14_KERNELDMA_START/4 + 6]; // 0x1918 KernelGroupStride
  uint32_t kogstr = state->values[H14_KERNELDMA_START/4 + 7]; // 0x191C KernelOCGStride

  printf("        MasterCfg: GroupKernelReuse=%u SparseFmt=%u MasterEn=%u\n",
         (master >> 4) & 1, (master >> 5) & 1, (master >> 6) & 1);
  if (kgstr || kogstr)
    printf("        KernelStride: GroupStride=%u OCGStride=%u\n", kgstr >> 6, kogstr >> 6);

  // 16 Coeff DMA buffers at words 8-23 (0x1920-0x195C)
  for (int i = 0; i < 16; i++) {
    uint32_t ccfg  = state->values[H14_KERNELDMA_START/4 + 8  + i]; // CoeffDMAConfig
    uint32_t cbase = state->values[H14_KERNELDMA_START/4 + 24 + i]; // CoeffBaseAddr
    uint32_t csz   = state->values[H14_KERNELDMA_START/4 + 40 + i]; // CoeffBfrSize
    if ((ccfg >> 0) & 1) {
      printf("        Coeff[%d]: En=1 DataSetId=%u CacheHint=%u Base=0x%08x Size=0x%08x\n",
             i, (ccfg >> 8) & 0xFF, (ccfg >> 4) & 0xF, cbase >> 6, csz >> 6);
    }
  }
}

// Helper function to recover dimensions from L2 Cache registers
// Used for operations (Add, ReLU, etc.) that don't write Common block dimensions
static void recover_dimensions_from_l2_cache(const hwx_state_t *state,
                                             uint32_t *inw, uint32_t *inh, uint32_t *inc) {
  // Only attempt recovery if dimensions are not already set
  if (*inw != 0 || *inh != 0 || *inc != 0) {
    return;
  }

  // Decide which register to use based on operation discriminator pattern
  // Pooling pattern: discriminator ends in 0x10
  // Other operations: use cache stride register
  bool use_pool_stride = false;

  if (state->valid[REG_L2_OP_DISCRIMINATOR]) {
    uint32_t op_disc = state->values[REG_L2_OP_DISCRIMINATOR];
    if ((op_disc & 0xF0) == 0x10) {
      use_pool_stride = true;
    }
  } else if (state->valid[REG_L2_POOL_STRIDE] && !state->valid[REG_L2_CACHE_STRIDE]) {
    // Only pool stride exists → likely pooling
    use_pool_stride = true;
  }

  // Try pooling stride register (for pooling operations)
  if (use_pool_stride && state->valid[REG_L2_POOL_STRIDE]) {
    uint32_t small_stride = state->values[REG_L2_POOL_STRIDE];
    uint32_t candidate = small_stride / 4;
    if (candidate >= 7 && candidate <= 224) {
      *inw = candidate;
      *inh = candidate;
    }
  }

  // Check L2 Cache stride register (for other operations)
  // This register contains width × stride_factor
  if (*inw == 0 && state->valid[REG_L2_CACHE_STRIDE]) {
    uint32_t stride = state->values[REG_L2_CACHE_STRIDE];

    // Common neural network dimensions in order of preference
    uint32_t common_dims[] = {224, 112, 56, 28, 14, 7};
    int factors[] = {16, 32, 64, 128, 256, 512};  // Corresponding factors

    // First pass: Try to match common dimensions exactly
    for (int i = 0; i < 6; i++) {
      if (stride % factors[i] == 0 && stride / factors[i] == common_dims[i]) {
        *inw = common_dims[i];
        *inh = common_dims[i];
        break;
      }
    }

    // Second pass: If no exact match, try all factors and accept reasonable range
    if (*inw == 0) {
      int all_factors[] = {4, 8, 16, 32, 64, 128};
      for (int i = 0; i < 6; i++) {
        uint32_t candidate = stride / all_factors[i];
        if (candidate >= 7 && candidate <= 224) {  // Accept common dimension range
          *inw = candidate;
          *inh = candidate;
          break;
        }
      }
    }
  }

  // Try to extract channels from packed register values
  // Check L2 Cache register (high 16 bits often contain channels)
  if (*inc == 0 && state->valid[REG_L2_PACKED_CHANNELS_2]) {
    uint32_t packed = state->values[REG_L2_PACKED_CHANNELS_2];
    uint32_t candidate_c = (packed >> 16) & 0xFFFF;
    if (candidate_c > 0 && candidate_c < 512) {
      *inc = candidate_c;
    }
  }

  // Alternative: check alternative L2 packed channels register
  if (*inc == 0 && state->valid[REG_L2_PACKED_CHANNELS_1]) {
    uint32_t packed = state->values[REG_L2_PACKED_CHANNELS_1];
    uint32_t candidate_c = (packed >> 16) & 0xFFFF;
    if (candidate_c > 0 && candidate_c < 512) {
      *inc = candidate_c;
    }
  }

  // Alternative: check TileDMA destination register
  if (*inc == 0 && state->valid[REG_TDMA_DST_CHANNELS]) {
    uint32_t packed = state->values[REG_TDMA_DST_CHANNELS];
    uint32_t candidate_c = (packed >> 16) & 0xFFFF;
    if (candidate_c > 0 && candidate_c < 512) {
      *inc = candidate_c;
    }
  }
}

void print_common_h16(const hwx_state_t *state) {
  printf("        --- Common (0x0000) ---\n");
  uint32_t infmt = 0, src2infmt = 0, outfmt = 0;
  uint32_t inw = 0, inh = 0, inc = 0, ind = 0;
  uint32_t outw = 0, outh = 0, outc = 0, outd = 0;
  uint32_t ng = 0, kw = 0, kh = 0, sx = 0, sy = 0, pl = 0, pt = 0, ox = 0,
           oy = 0;
  uint32_t k3d = 0, s3d = 0, p3d = 0, o3d = 0;
  uint32_t ucin = 0, ucen = 0, overlap = 0, overlapt = 0, overlapb = 0;
  uint32_t active_ne = 0, small_src = 0, task_type = 0, out_trans = 0,
           fill_lower = 0;
  uint32_t ocg = 0, fat = 0, wustack = 0, halfwu = 0, relu_type = 0;
  uint32_t pw = 0, ph = 0;
  uint32_t s1br = 0, s2br = 0, s1t = 0, s2t = 0, ot = 0, nid = 0, dpe = 0;

  if (state->instr_ver >= 20) {
    ane_common_h18_t c =
        *(ane_common_h18_t *)&state->values[H16_COMMON_START / 4];
    infmt = c.ch_cfg.infmt;
    src2infmt = c.ch_cfg.src2infmt;
    outfmt = c.ch_cfg.outfmt;
    inw = c.inwidth;
    inh = c.inheight;
    inc = c.inchannels;
    ind = c.indepth;
    outw = c.outwidth;
    outh = c.outheight;
    outc = c.outchannels;
    outd = c.outdepth;
    ng = c.num_groups;
    kw = c.conv_cfg.kw;
    kh = c.conv_cfg.kh;
    sx = c.conv_cfg.sx;
    sy = c.conv_cfg.sy;
    pl = c.conv_cfg.pad_left;
    pt = c.conv_cfg.pad_top;
    ox = c.conv_cfg.ox;
    oy = c.conv_cfg.oy;
    k3d = c.conv_cfg_3d.kd;
    s3d = c.conv_cfg_3d.sz;
    p3d = c.conv_cfg_3d.pz;
    o3d = c.conv_cfg_3d.oz;
    ucin = c.unicast_cfg.unicast_cin;
    ucen = c.unicast_cfg.unicast_en;
    overlap = c.tile_overlap.overlap;
    overlapt = c.tile_overlap.pad_top;
    overlapb = c.tile_overlap.pad_bottom;
    active_ne = c.maccfg.active_ne;
    small_src = c.maccfg.small_src_mode;
    task_type = c.maccfg.task_type;
    out_trans = c.maccfg.out_trans;
    fill_lower = c.maccfg.fill_lower_ne;
    ocg = c.ne_cfg.ocg_size;
    fat = c.ne_cfg.fat_tile_en;
    halfwu = c.ne_cfg.half_wu_mode;
    pw = c.patch_cfg.patch_width;
    ph = c.patch_cfg.patch_height;
    s1br = c.pe_cfg.src1_br;
    s2br = c.pe_cfg.src2_br;
    s1t = c.pe_cfg.src1_trans;
    s2t = c.pe_cfg.src2_trans;
    ot = c.pe_cfg.out_trans;
    nid = c.nid;
    dpe = c.dpe;
  } else if (state->instr_ver >= 19) {
    ane_common_h17_t c =
        *(ane_common_h17_t *)&state->values[H16_COMMON_START / 4];
    infmt = c.ch_cfg.infmt;
    src2infmt = c.ch_cfg.src2infmt;
    outfmt = c.ch_cfg.outfmt;
    inw = c.inwidth;
    inh = c.inheight;
    inc = c.inchannels;
    ind = c.indepth;
    outw = c.outwidth;
    outh = c.outheight;
    outc = c.outchannels;
    outd = c.outdepth;
    ng = c.num_groups;
    kw = c.conv_cfg.kw;
    kh = c.conv_cfg.kh;
    sx = c.conv_cfg.sx;
    sy = c.conv_cfg.sy;
    pl = c.conv_cfg.pad_left;
    pt = c.conv_cfg.pad_top;
    ox = c.conv_cfg.ox;
    oy = c.conv_cfg.oy;
    k3d = c.conv_cfg_3d.kd;
    s3d = c.conv_cfg_3d.sz;
    p3d = c.conv_cfg_3d.pz;
    o3d = c.conv_cfg_3d.oz;
    ucin = c.unicast_cfg.unicast_cin;
    ucen = c.unicast_cfg.unicast_en;
    overlap = c.tile_overlap.overlap;
    overlapt = c.tile_overlap.pad_top;
    overlapb = c.tile_overlap.pad_bottom;
    active_ne = c.maccfg.active_ne;
    small_src = c.maccfg.small_src_mode;
    task_type = c.maccfg.task_type;
    out_trans = c.maccfg.out_trans;
    fill_lower = c.maccfg.fill_lower_ne;
    ocg = c.ne_cfg.ocg_size;
    fat = c.ne_cfg.fat_tile_en;
    wustack = c.ne_cfg.wustack_log2;
    pw = c.patch_cfg.patch_width;
    ph = c.patch_cfg.patch_height;
    s1br = c.pe_cfg.src1_br;
    s2br = c.pe_cfg.src2_br;
    s1t = c.pe_cfg.src1_trans;
    s2t = c.pe_cfg.src2_trans;
    ot = c.pe_cfg.out_trans;
    nid = c.nid;
    dpe = c.dpe;
  } else {
    // For H16, handle two different dimension encoding schemes:
    // 1. Normal: Dimensions written as VALUES to Reg[0x0001-0x0008]
    // 2. Sparse hash: Dimensions appear as ADDRESSES (e.g., addr=0x03e9 for dim=1001)
    uint32_t hybrid_values[sizeof(ane_common_h16_t) / 4];
    memcpy(hybrid_values, &state->values[H16_COMMON_START / 4], sizeof(ane_common_h16_t));

    // Check if dimension values (not just valid flags) look reasonable
    // Even if state->valid[] doesn't mark them, the actual values may be correct
    // Note: Some H16 tasks write ANE header to registers 0x0-0x9, shifting Common block.
    // The exact offset varies, so we check multiple possible locations.
    uint32_t dim_w = state->values[REG_COMMON_IN_WIDTH] & 0x1FFFF;
    uint32_t dim_h = state->values[REG_COMMON_IN_HEIGHT] & 0x1FFFF;
    uint32_t dim_c = state->values[REG_COMMON_IN_CHANNELS] & 0x1FFFF;
    int common_offset = 0;  // Offset where Common block actually starts

    // If dimensions at standard location don't look valid, search for them
    // Specifically check if alternative register contains a value that could be width (e.g., 1001 = 0x3e9)
    if (dim_w == 0 || dim_w >= 65536 || dim_h >= 65536 || dim_c >= 65536 ||
        state->values[REG_COMMON_CH_CFG] == 0) {

      // Try shifted location (common for tasks with header in register space)
      uint32_t test_w = state->values[REG_COMMON_ALT_IN_WIDTH] & 0x1FFFF;
      uint32_t test_h = state->values[REG_COMMON_ALT_IN_HEIGHT] & 0x1FFFF;
      uint32_t test_c = state->values[REG_COMMON_ALT_IN_CHANNELS] & 0x1FFFF;

      if (test_w > 0 && test_w < 10000 && test_h <= test_w && test_h < 10000 &&
          test_c > 0 && test_c < 10000) {
        // Use registers starting at 0xa (ch_cfg before width)
        common_offset = 0xa;
        dim_w = test_w;
        dim_h = test_h;
        dim_c = test_c;
        // Copy from offset 0xa
        for (int i = 0; i < (int)(sizeof(ane_common_h16_t) / 4) && 0xa + i < HW_MAX_REGS; i++) {
          hybrid_values[i] = state->values[0xa + i];
        }
      }
    }

    bool dims_look_reasonable = false;

    // Dimensions look reasonable if:
    // - Width and height are sensible (both > 0 and < 3000, or one is 0/1)
    // - Channels is reasonable (< 2048)
    // - Height is not suspiciously large (H > 3000 indicates garbage)
    if (dim_h < 3000 && dim_c < 2048) {
      if ((dim_w > 0 && dim_w < 3000 && dim_h > 0) ||
          (dim_w > 0 && dim_w < 3000 && (dim_h == 0 || dim_h == 1)) ||
          (dim_h > 0 && (dim_w == 0 || dim_w == 1))) {
        dims_look_reasonable = true;
      }
    }

    // Note: Disabled address-as-dimension heuristic for H16 as it causes false positives
    // The search-based approach above should find dimensions reliably
    (void)dims_look_reasonable;  // Suppress unused variable warning

    ane_common_h16_t c = *(ane_common_h16_t *)hybrid_values;
    infmt = c.ch_cfg.infmt;
    src2infmt = c.ch_cfg.src2infmt;
    outfmt = c.ch_cfg.outfmt;
    inw = c.inwidth;
    inh = c.inheight;
    inc = c.inchannels;
    ind = c.indepth;
    outw = c.outwidth;
    outh = c.outheight;
    outc = c.outchannels;
    outd = c.outdepth;
    ng = c.num_groups;
    kw = c.conv_cfg.kw;
    kh = c.conv_cfg.kh;
    sx = c.conv_cfg.sx;
    sy = c.conv_cfg.sy;
    pl = c.conv_cfg.pad_left;
    pt = c.conv_cfg.pad_top;
    ox = c.conv_cfg.ox;
    oy = c.conv_cfg.oy;
    k3d = c.conv_cfg_3d.kd;
    s3d = c.conv_cfg_3d.sz;
    p3d = c.conv_cfg_3d.pz;
    o3d = c.conv_cfg_3d.oz;
    ucin = c.unicast_cfg.unicast_cin;
    ucen = c.unicast_cfg.unicast_en;
    overlap = c.tile_overlap.overlap;
    overlapt = c.tile_overlap.pad_top;
    overlapb = c.tile_overlap.pad_bottom;
    active_ne = c.maccfg.active_ne;
    small_src = c.maccfg.small_src_mode;
    task_type = c.maccfg.task_type;
    out_trans = c.maccfg.out_trans;
    fill_lower = c.maccfg.fill_lower_ne;
    relu_type = c.maccfg.relu_type;
    ocg = c.ne_cfg.ocg_size;
    fat = c.ne_cfg.fat_tile_en;
    wustack = c.ne_cfg.wustack_log2;
    pw = c.patch_cfg.patch_width;
    ph = c.patch_cfg.patch_height;
    s1br = c.pe_cfg.src1_br;
    s2br = c.pe_cfg.src2_br;
    s1t = c.pe_cfg.src1_trans;
    s2t = c.pe_cfg.src2_trans;
    ot = c.pe_cfg.out_trans;
    nid = c.nid;
    dpe = c.dpe;

    // Attempt dimension recovery from L2 Cache registers
    // (for operations that don't write Common block dimensions)
    recover_dimensions_from_l2_cache(state, &inw, &inh, &inc);
  }

  if (!state->valid[H16_COMMON_START / 4]) {
    infmt = 2;
    src2infmt = 2;
    outfmt = 2;
  }

  if (state->valid[(H16_COMMON_START + 0x04) / 4] ||
      state->valid[(H16_COMMON_START + 0x08) / 4] ||
      state->valid[(H16_COMMON_START + 0x0C) / 4] ||
      state->valid[(H16_COMMON_START + 0x10) / 4] ||
      (inw > 0 && inw < 1024)) {  // Also show if dimensions were extracted from L2 Cache
    printf("        InDim     : W=%u H=%u C=%u D=%u Type=%s (Src2Type=%s)\n",
           inw, inh, inc, ind, get_ch_fmt_name(infmt),
           get_ch_fmt_name(src2infmt));
  }

  if (state->valid[(H16_COMMON_START + 0x14) / 4] ||
      state->valid[(H16_COMMON_START + 0x18) / 4] ||
      state->valid[(H16_COMMON_START + 0x1C) / 4] ||
      state->valid[(H16_COMMON_START + 0x20) / 4]) {
    printf("        OutDim    : W=%u H=%u C=%u D=%u Type=%s\n", outw, outh,
           outc, outd, get_ch_fmt_name(outfmt));
  }

  if (state->valid[(H16_COMMON_START + 0x24) / 4]) {
    printf("        NumGroups : %u\n", ng);
  }

  if (state->valid[(H16_COMMON_START + 0x28) / 4]) {
    printf("        ConvCfg   : K=%ux%u S=%ux%u P(left/top)=%ux%u O=%ux%u\n",
           kw, kh, sx, sy, pl, pt, ox, oy);
  }

  if (state->valid[(H16_COMMON_START + 0x2C) / 4]) {
    uint32_t v = state->values[(H16_COMMON_START + 0x2C) / 4];
    printf("        ConvCfg3D : 0x%08x (Kd=%u Sz=%u Pz=%u Oz=%u)\n", v, k3d,
           s3d, p3d, o3d);
  }

  if (state->valid[(H16_COMMON_START + 0x30) / 4]) {
    printf("        Unicast   : Cin=%u En=%d\n", ucin, ucen);
  }

  if (state->valid[(H16_COMMON_START + 0x34) / 4]) {
    printf("        TileOvlp  : Ovlp=%u Pad(T/B)=%ux%u\n", overlap, overlapt,
           overlapb);
  }

  if (state->valid[(H16_COMMON_START + 0x3C) / 4]) {
    task_type = get_task_type_mapping(task_type);
    printf(
        "        MacCfg    : TaskType=%u %s ActiveNE=%u SmSrc=%u ReluType=%u "
        "OutTrans=%d FillLowerNE=%d\n",
        task_type,
        (task_type != 0)
            ? [[NSString stringWithFormat:@"(%s)", get_hw_task_type_name(
                                                       task_type)] UTF8String]
            : "((None))",
        active_ne, small_src, relu_type, out_trans, fill_lower);
  }

  if (state->valid[(H16_COMMON_START + 0x40) / 4]) {
    if (state->instr_ver >= 20) {
      printf("        NECfg     : OCGSize=%u FatTileEn=%d HalfWUMode=%u\n", ocg,
             fat, halfwu);
    } else {
      printf("        NECfg     : OCGSize=%u FatTileEn=%d WUStack=%u\n", ocg,
             fat, wustack);
    }
  }

  if (state->valid[(H16_COMMON_START + 0x44) / 4]) {
    printf("        PatchCfg  : PW=%u PH=%u\n", pw, ph);
  }

  if (state->valid[(H16_COMMON_START + 0x48) / 4]) {
    printf("        PECfg     : S1BR=%d S2BR=%d S1T=%d S2T=%d OutTrans=%d\n",
           s1br, s2br, s1t, s2t, ot);
  }

  if (state->valid[(H16_COMMON_START + 0x4C) / 4])
    printf("        NID       : 0x%08x\n", nid);
  if (state->valid[(H16_COMMON_START + 0x50) / 4])
    printf("        DPE       : 0x%08x\n", dpe);
}

void print_ne_h16(const hwx_state_t *state) {
  printf("        --- Neural Engine (0x4900) ---\n");

  uint32_t kfmt = 0, pen = 0, pbits = 0, sen = 0, reuse = 0, sbs_w = 0,
           sbs_a = 0, asym = 0;
  uint32_t op = 0, km = 0, ssrc = 0;
  uint32_t bias_en = 0, pass_en = 0, mv_bias_en = 0, bin_point = 0, post_en = 0;
  uint32_t nl_mode_ne = 0, max_pool_en = 0, arg_sel = 0, double_int8_en = 0;
  uint32_t mbias = 0, nebias = 0, ps = 0, rcas = 0, rmode = 0, rbits = 0,
           qzp = 0;
  uint32_t seeds[4] = {0};

  if (state->instr_ver >= 20) {
    ane_ne_h18_t ne = *(ane_ne_h18_t *)&state->values[H16_NE_START / 4];
    kfmt = ne.kernel_cfg.kernel_fmt;
    pen = ne.kernel_cfg.palettized_en;
    pbits = ne.kernel_cfg.palettized_bits;
    sen = ne.kernel_cfg.sparse_en;
    reuse = ne.kernel_cfg.group_kernel_reuse;
    sbs_w = ne.kernel_cfg.sparse_block_size_w;
    sbs_a = ne.kernel_cfg.sparse_block_size_a;
    op = ne.mac_cfg.op_mode;
    km = ne.mac_cfg.kernel_mode;
    ssrc = ne.mac_cfg.small_src_mode;
    mbias = ne.matrix_bias;
    nebias = ne.ne_bias;
    ps = ne.post_scale;
    rcas = state->values[(H16_NE_START + 0x14) / 4];
    rmode = ne.round_mode_cfg.sr_mode;
    rbits = ne.round_mode_cfg.sr_int_bits;
    memcpy(seeds, ne.sr_seed, 16);
    qzp = ne.quant_zero_point;
  } else if (state->instr_ver >= 19) {
    ane_ne_h17_t ne = *(ane_ne_h17_t *)&state->values[H16_NE_START / 4];
    kfmt = ne.kernel_cfg.kernel_fmt;
    pen = ne.kernel_cfg.palettized_en;
    pbits = ne.kernel_cfg.palettized_bits;
    sen = ne.kernel_cfg.sparse_en;
    reuse = ne.kernel_cfg.group_kernel_reuse;
    sbs_w = ne.kernel_cfg.sparse_block_size;
    asym = ne.kernel_cfg.asym_quant_en;
    op = ne.mac_cfg.op_mode;
    km = ne.mac_cfg.kernel_mode;
    mbias = ne.matrix_bias;
    nebias = ne.ne_bias;
    ps = ne.post_scale;
    rcas = state->values[(H16_NE_START + 0x14) / 4];
    rmode = ne.round_mode_cfg.sr_mode;
    rbits = ne.round_mode_cfg.sr_int_bits;
    memcpy(seeds, ne.sr_seed, 16);
    qzp = ne.quant_zero_point;
  } else {
    ane_ne_h16_t ne = *(ane_ne_h16_t *)&state->values[H16_NE_START / 4];
    kfmt = ne.kernel_cfg.kernel_fmt;
    pen = ne.kernel_cfg.palettized_en;
    pbits = ne.kernel_cfg.palettized_bits;
    sen = ne.kernel_cfg.sparse_en;
    reuse = ne.kernel_cfg.group_kernel_reuse;
    sbs_w = ne.kernel_cfg.sparse_block_size;
    asym = ne.kernel_cfg.asym_quant_en;
    op = ne.mac_cfg.op_mode;
    km = ne.mac_cfg.kernel_mode;
    bias_en = ne.mac_cfg.bias_en;
    pass_en = ne.mac_cfg.pass_en;
    mv_bias_en = ne.mac_cfg.mv_bias_en;
    bin_point = ne.mac_cfg.bin_point;
    post_en = ne.mac_cfg.post_en;
    nl_mode_ne = ne.mac_cfg.nl_mode;
    max_pool_en = ne.mac_cfg.max_pool_en;
    arg_sel = ne.mac_cfg.arg_sel;
    double_int8_en = ne.mac_cfg.double_int8_en;
    mbias = ne.matrix_bias.matrix_vector_bias;
    nebias = ne.ne_bias.val;
    ps = ne.post_scale.val;
    rcas = state->values[(H16_NE_START + 0x14) / 4];
    rmode = ne.st_round_cfg.round_mode;
    rbits = ne.st_round_cfg.integer_bits;
    memcpy(seeds, ne.st_round_seed, 16);
    qzp = ne.quant.quant_zero_point;
  }

  if (state->valid[H16_NE_START / 4]) {
    printf("        KernelCfg: Fmt=%s Pal=%d(%dbit) SparseEn=%d Reuse=%d",
           get_ch_fmt_name(kfmt), pen, pbits, sen, reuse);
    if (state->instr_ver >= 20) {
      printf(" SBS(W/A)=%d/%d\n", sbs_w, sbs_a);
    } else {
      printf(" SBS=%d Asym=%d\n", sbs_w, asym);
    }
  }

  if (state->valid[(H16_NE_START + 0x4) / 4]) {
    printf(
        "        MacCfg: Op=%u (%s) KMode=%u BiasEn=%u PassEn=%u MVBiasEn=%u\n",
        op, get_ne_op_mode_name(op), km, bias_en, pass_en, mv_bias_en);
    printf("                BinPoint=%u PostEn=%u NLMode=%u MaxPoolEn=%u "
           "ArgSel=%u DblInt8=%u",
           bin_point, post_en, nl_mode_ne, max_pool_en, arg_sel,
           double_int8_en);
    if (state->instr_ver >= 20)
      printf(" SmallSrc=%u", ssrc);
    printf("\n");
  }

  if (state->valid[(H16_NE_START + 0x8) / 4])
    printf("        MatrixBias: 0x%08x\n", mbias);
  if (state->valid[(H16_NE_START + 0x0c) / 4])
    printf("        NEBias: 0x%08x\n", nebias);
  if (state->valid[(H16_NE_START + 0x10) / 4])
    printf("        PostScale: 0x%08x\n", ps);
  if (state->valid[(H16_NE_START + 0x14) / 4])
    printf("        RcasConfig: KeyMask=0x%02x CmpBit=%u Axis=%u SenseBit=%u "
           "Mode=%u\n",
           rcas & 0xFF, (rcas >> 8) & 0x7, (rcas >> 12) & 0x3,
           (rcas >> 16) & 0xF, (rcas >> 20) & 0x1);
  if (state->valid[(H16_NE_START + 0x18) / 4])
    printf("        RoundMode: Mode=%d Bits=%d\n", rmode, rbits);
  if (state->valid[(H16_NE_START + 0x1c) / 4])
    printf("        SRSeeds: 0x%08x 0x%08x 0x%08x 0x%08x\n", seeds[0], seeds[1],
           seeds[2], seeds[3]);
  if (state->valid[(H16_NE_START + 0x2c) / 4])
    printf("        QuantZeroPoint: %d\n", qzp);
}

void print_pe_h16(const hwx_state_t *state) {
  uint32_t task_type = 0;
  bool is_task_type_valid = false;
  uint32_t maccfg_offset = 0;

  if (state->instr_ver >= 20) {
    maccfg_offset = 0x48;
    if (state->valid[(H16_COMMON_START + maccfg_offset) / 4]) {
      task_type =
          ((const ane_common_h18_t *)&state->values[H16_COMMON_START / 4])
              ->maccfg.task_type;
      is_task_type_valid = true;
    }
  } else if (state->instr_ver >= 19) {
    maccfg_offset = 0x48;
    if (state->valid[(H16_COMMON_START + maccfg_offset) / 4]) {
      task_type =
          ((const ane_common_h17_t *)&state->values[H16_COMMON_START / 4])
              ->maccfg.task_type;
      is_task_type_valid = true;
    }
  } else {
    maccfg_offset = 0x3C;
    if (state->valid[(H16_COMMON_START + maccfg_offset) / 4]) {
      task_type =
          ((const ane_common_h16_t *)&state->values[H16_COMMON_START / 4])
              ->maccfg.task_type;
      is_task_type_valid = true;
    }
  }

  if (is_task_type_valid && task_type == 0)
    return;

  printf("        --- Planar Engine (0x4500) ---\n");

  uint32_t pool = 0, op = 0, lut_en = 0, cond = 0, red_idx = 0, red_keep = 0,
           nl = 0, src1 = 0, src2 = 0;
  uint32_t bias = 0, scale = 0, eps = 0, ps = 0, fs = 0;
  const char *pool_str = "None";
  const char *op_str = "None";

  if (state->instr_ver >= 19) {
    const ane_pe_h17_t *pe =
        (const ane_pe_h17_t *)&state->values[H16_PE_START / 4];
    pool = pe->pe_cfg.pool_mode;
    op = pe->pe_cfg.op;
    lut_en = pe->pe_cfg.lut_en;
    cond = pe->pe_cfg.cond;
    red_idx = pe->pe_cfg.red_idx;
    red_keep = pe->pe_cfg.red_keep;
    nl = pe->pe_cfg.nl_mode;
    src1 = pe->pe_cfg.src1_idx;
    src2 = pe->pe_cfg.src2_idx;
    bias = pe->bias;
    scale = pe->scale;
    eps = pe->epsilon;
    ps = pe->pre_scale;
    fs = pe->final_scale;
  } else {
    const ane_pe_h16_t *pe =
        (const ane_pe_h16_t *)&state->values[H16_PE_START / 4];
    pool = pe->pe_cfg.pool_mode;
    op = pe->pe_cfg.op;
    lut_en = pe->pe_cfg.lut_en;
    cond = pe->pe_cfg.cond;
    red_idx = pe->pe_cfg.red_idx;
    red_keep = pe->pe_cfg.red_keep;
    nl = pe->pe_cfg.nl_mode;
    src1 = pe->pe_cfg.src1;
    src2 = pe->pe_cfg.src2;
    bias = pe->bias;
    scale = pe->scale;
    eps = pe->final_scale_epsilon;
    ps = pe->pre_scale;
    fs = pe->final_scale;
  }

  if (is_task_type_valid) {
    task_type = get_task_type_mapping(task_type);
    pool_str = (task_type == 0 || task_type == 2)
                   ? get_pe_pool_mode_name_v17(pool)
                   : "None";
    op_str = (task_type >= 3 && task_type <= 6) ? get_pe_op_mode_name_v17(op)
                                                : "None";

    if (task_type == 7) {
      uint32_t pe_common_cfg_offset = (state->instr_ver >= 19) ? 0x4C : 0x40;
      if (state->valid[(H16_COMMON_START + pe_common_cfg_offset) / 4]) {
        uint32_t pe_common_cfg =
            state->values[(H16_COMMON_START + pe_common_cfg_offset) / 4];
        printf(
            "        PE Config (GOC) : Cond=%u CtoW=%u Src1Sel=%u Src2Sel=%u\n",
            (pe_common_cfg >> 4) & 0x1F, (pe_common_cfg >> 10) & 1,
            (pe_common_cfg >> 16) & 3, (pe_common_cfg >> 18) & 3);
      }
    } else if (state->valid[H16_PE_START / 4]) {
      printf("        PE Config : Pool=%u (%s) Op=%u (%s) LutEn=%u Cond=%u "
             "RedIdx=%u "
             "RedKeep=%u NLMode=%u Src1=%u Src2=%u\n",
             pool, pool_str, op, op_str, lut_en, cond, red_idx, red_keep, nl,
             src1, src2);
    }
  } else if (state->valid[H16_PE_START / 4]) {
    printf("        PE Config : Pool=%u (%s) Op=%u (%s) LutEn=%u Cond=%u "
           "RedIdx=%u "
           "RedKeep=%u NLMode=%u Src1=%u Src2=%u\n",
           pool, get_pe_pool_mode_name_v17(pool), op,
           get_pe_op_mode_name_v17(op), lut_en, cond, red_idx, red_keep, nl,
           src1, src2);
  }

  if (state->valid[(H16_PE_START + 0x4) / 4])
    print_float_reg("PE Bias", bias);
  if (state->valid[(H16_PE_START + 0x8) / 4])
    print_float_reg("PE Scale", scale);
  if (state->valid[(H16_PE_START + 0x0c) / 4])
    print_float_reg("PE Final Scale Epsilon", eps);
  if (state->valid[(H16_PE_START + 0x10) / 4])
    print_float_reg("PE PreScale", ps);
  if (state->valid[(H16_PE_START + 0x14) / 4])
    print_float_reg("PE Final Scale", fs);
}

void print_pe_h17(const hwx_state_t *state) {
  ane_pe_h17_t pe = *(ane_pe_h17_t *)&state->values[H16_PE_START / 4];
  printf("        --- Planar Engine (0x4500) [H17] ---\n");

  if (state->valid[H16_PE_START / 4]) {
    static const char *pe_op_names[] = {"None", "Add", "Mul", "Min",
                                        "Max",  "5?",  "6?",  "7?"};
    printf("        PE Config : Pool=%u Op=%u(%s) LutEn=%u Cond=%u RedIdx=%u "
           "RedKeep=%u NLMode=%u CtoW=%u Src1Idx=%u Src2Idx=%u MaxIdx=%u\n",
           pe.pe_cfg.pool_mode, pe.pe_cfg.op, pe_op_names[pe.pe_cfg.op & 7],
           pe.pe_cfg.lut_en, pe.pe_cfg.cond, pe.pe_cfg.red_idx,
           pe.pe_cfg.red_keep, pe.pe_cfg.nl_mode, pe.pe_cfg.c_to_w,
           pe.pe_cfg.src1_idx, pe.pe_cfg.src2_idx, pe.pe_cfg.max_idx);
  }
  if (state->valid[(H16_PE_START + 0x4) / 4])
    print_float_reg("PE Bias", pe.bias);
  if (state->valid[(H16_PE_START + 0x8) / 4])
    print_float_reg("PE Scale", pe.scale);
  if (state->valid[(H16_PE_START + 0x10) / 4])
    print_float_reg("PE PreScale", pe.pre_scale);
  if (state->valid[(H16_PE_START + 0x14) / 4])
    print_float_reg("PE Final Scale", pe.final_scale);

  if (state->valid[(H16_PE_START + 0x18) / 4]) {
    printf("        PE Src1   : Index=%u Relu=%d Transpose=%d\n",
           pe.src1_cfg.src1_idx, pe.src1_cfg.relu, pe.src1_cfg.transpose);
  }
  if (state->valid[(H16_PE_START + 0x20) / 4]) {
    printf("        PE Src2   : Index=%u Relu=%d Transpose=%d\n",
           pe.src2_cfg.src2_idx, pe.src2_cfg.relu, pe.src2_cfg.transpose);
  }
}

void print_pe_h18(const hwx_state_t *state) {
  ane_pe_h18_t pe = *(ane_pe_h18_t *)&state->values[H16_PE_START / 4];
  printf("        --- Planar Engine (0x4500) [H18] ---\n");

  if (state->valid[H16_PE_START / 4]) {
    static const char *pe_op_names[] = {"None", "Add", "Mul", "Min",
                                        "Max",  "5?",  "6?",  "7?"};
    printf("        PE Config : Pool=%u Op=%u(%s) LutEn=%u Cond=%u RedIdx=%u "
           "RedKeep=%u NLMode=%u CtoW=%u Src1Idx=%u Src2Idx=%u MaxIdx=%u\n",
           pe.pe_cfg.pool_mode, pe.pe_cfg.op, pe_op_names[pe.pe_cfg.op & 7],
           pe.pe_cfg.lut_en, pe.pe_cfg.cond, pe.pe_cfg.red_idx,
           pe.pe_cfg.red_keep, pe.pe_cfg.nl_mode, pe.pe_cfg.c_to_w,
           pe.pe_cfg.src1_idx, pe.pe_cfg.src2_idx, pe.pe_cfg.max_idx);
  }
  if (state->valid[(H16_PE_START + 0x4) / 4])
    print_float_reg("PE Bias", pe.bias);
  if (state->valid[(H16_PE_START + 0x8) / 4])
    print_float_reg("PE Scale", pe.scale);
  if (state->valid[(H16_PE_START + 0x10) / 4])
    print_float_reg("PE PreScale", pe.pre_scale);
  if (state->valid[(H16_PE_START + 0x14) / 4])
    print_float_reg("PE Final Scale", pe.final_scale);
}

void print_l2_h17(const hwx_state_t *state) {
  const ane_l2_h17_t *l2 =
      (const ane_l2_h17_t *)&state->values[(H16_L2_START) / 4];
  printf("        --- L2 Cache Control (0x4100) [H17] ---\n");
  if (state->valid[H16_L2_START / 4]) {
    printf("        L2_Control: 0x%08x\n", l2->l2_control);
  }

  if (state->valid[(H16_L2_START + 0x04) / 4]) {
    printf("        L2_Src1Cfg: 0x%08x\n", l2->dma_cfg.src1_cfg);
  }
  if (state->valid[(H16_L2_START + 0x08) / 4]) {
    printf("        L2_Src2Cfg: 0x%08x\n", l2->dma_cfg.src2_cfg);
  }

  printf("        L2_Src1: Base=0x%x0 RS=0x%x0 CS=0x%x0 DS=0x%x0 GS=0x%x0\n",
         l2->src1.base, l2->src1.row_stride, l2->src1.channel_stride,
         l2->src1.depth_stride, l2->src1.group_stride);

  printf("        L2_Result: Base=0x%x0 CS=0x%x0 RS=0x%x0 DS=0x%x0 GS=0x%x0 "
         "Type=0x%x\n",
         l2->result.base, l2->result.channel_stride, l2->result.row_stride,
         l2->result.depth_stride, l2->result.group_stride,
         l2->result.res_type_cfg);

  if (state->valid[(H16_L2_START + 0x64) / 4]) {
    printf("        L2_WrapCfg: 0x%08x\n", l2->wrap_cfg);
  }
}

void print_l2_h18(const hwx_state_t *state) {
  const ane_l2_h18_t *l2 =
      (const ane_l2_h18_t *)&state->values[(H16_L2_START) / 4];
  printf("        --- L2 Cache Control (0x4100) [H18] ---\n");
  if (state->valid[H16_L2_START / 4]) {
    printf("        L2_Control: 0x%08x\n", l2->l2_control);
  }

  printf("        L2_Src1: Base=0x%x0 RS=0x%x0 CS=0x%x0 DS=0x%x0 GS=0x%x0\n",
         l2->src1.base, l2->src1.row_stride, l2->src1.channel_stride,
         l2->src1.depth_stride, l2->src1.group_stride);

  printf("        L2_Result: Base=0x%x0 CS=0x%x0 RS=0x%x0 DS=0x%x0 GS=0x%x0 "
         "Type=0x%x\n",
         l2->result.base, l2->result.channel_stride, l2->result.row_stride,
         l2->result.depth_stride, l2->result.group_stride,
         l2->result.res_type_cfg);
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
  const ane_l2_h16_t *l2 =
      (const ane_l2_h16_t *)&state->values[H16_L2_START / 4];
  printf("        --- L2 Cache Control (0x4100) ---\n");
  // ZinL2AccessMode hw bits[1:0] → named string
  // Derived from SetL2Src1SourceType + HasDmaRead/HasL2Read/HasChainRead
  //   hw=0 (L2Read),  hw=1 (DmaRead2), hw=2 (DmaRead), hw=3 (L2ChainRead)
  static const char *l2_type_names[] = {"L2Read", "DmaRead2", "DmaRead",
                                        "L2ChainRead"};
#define L2_TYPE_STR(t) (((t) < 4) ? l2_type_names[(t)] : "Unk")

  if (state->valid[H16_L2_START / 4]) {
    uint32_t val = state->values[H16_L2_START / 4];
    printf("        L2_Control: 0x%08x (src1_relu: %d, padding: %d, src2_relu: "
           "%d, barrier_en: %d, "
           "barrier_idx: %d)\n",
           val, val & 1, (val >> 2) & 3, (val >> 4) & 1, (val >> 16) & 1,
           (val >> 17) & 0x7f);
  }

  if (state->valid[(H16_L2_START + 0x04) / 4]) {
    uint32_t dma_fmt = l2->src1_cfg.dma_fmt;
    const char *fmt_str = (dma_fmt == 0)   ? "8b"
                          : (dma_fmt == 1) ? "16b"
                          : (dma_fmt == 3) ? "32b"
                                           : "Unk";
    printf(
        "        Src1Cfg  : Type=%u (%s) Dependent=%u EnRelu=%u DMAFmt=%u (%s) "
        "Alias(C=%d,P=%d,CR=%d,PR=%d) Cmp=%u\n",
        l2->src1_cfg.src_type, L2_TYPE_STR(l2->src1_cfg.src_type),
        l2->src1_cfg.dependent, l2->l2_control.src1_relu, dma_fmt, fmt_str,
        l2->src1_cfg.alias_conv_src, l2->src1_cfg.alias_planar_src,
        l2->src1_cfg.alias_conv_rslt, l2->src1_cfg.alias_planar_rslt,
        l2->src1_cfg.compression);
  }

  if (state->valid[(H16_L2_START + 0x08) / 4]) {
    uint32_t dma_fmt = l2->src2_cfg.dma_fmt;
    const char *fmt_str = (dma_fmt == 0)   ? "8b"
                          : (dma_fmt == 1) ? "16b"
                          : (dma_fmt == 3) ? "32b"
                                           : "Unk";
    printf(
        "        Src2Cfg  : Type=%u (%s) Dependent=%u EnRelu=%u DMAFmt=%u (%s) "
        "Alias(C=%d,P=%d,CR=%d,PR=%d) Cmp=%u\n",
        l2->src2_cfg.src_type, L2_TYPE_STR(l2->src2_cfg.src_type),
        l2->src2_cfg.dependent, l2->l2_control.src2_relu, dma_fmt, fmt_str,
        l2->src2_cfg.alias_conv_src, l2->src2_cfg.alias_planar_src,
        l2->src2_cfg.alias_conv_rslt, l2->src2_cfg.alias_planar_rslt,
        l2->src2_cfg.compression);
  }

  if (state->valid[(H16_L2_START + 0x0c) / 4]) {
    const char *fmt_str = "Unk";
    if (l2->srcidx_cfg.dma_fmt == 0)
      fmt_str = "8b";
    else if (l2->srcidx_cfg.dma_fmt == 1)
      fmt_str = "16b";
    else if (l2->srcidx_cfg.dma_fmt == 3)
      fmt_str = "32b";

    printf("        L2_SrcIdxCfg: Type=%u (%s) Dep=%u DMAFmt=%u (%s) "
           "AliasConv(S=%d,R=%d)\n",
           l2->srcidx_cfg.src_type, L2_TYPE_STR(l2->srcidx_cfg.src_type),
           l2->srcidx_cfg.dependent, l2->srcidx_cfg.dma_fmt, fmt_str,
           l2->srcidx_cfg.alias_conv_src, l2->srcidx_cfg.alias_conv_rslt);
    printf("                      AliasPlanar(S=%d,R=%d) Bit27=%u\n",
           l2->srcidx_cfg.alias_planar_src, l2->srcidx_cfg.alias_planar_rslt,
           l2->srcidx_cfg.bit27);
  }

  if (state->valid[(H16_L2_START + 0x10) / 4]) {
    printf("        L2_Src1Base: 0x%05x0\n", l2->src1.base);
    printf("        L2_Src1Strides: C=0x%05x0 R=0x%05x0 D=0x%05x0 G=0x%05x0\n",
           l2->src1.channel_stride, l2->src1.row_stride, l2->src1.depth_stride,
           l2->src1.group_stride);
  }

  if (state->valid[(H16_L2_START + 0x24) / 4]) {
    printf("        L2_Src2Base: 0x%05x0\n", l2->src2.base);
    printf("        L2_Src2Strides: C=0x%05x0 R=0x%05x0 D=0x%05x0 G=0x%05x0\n",
           l2->src2.channel_stride, l2->src2.row_stride, l2->src2.depth_stride,
           l2->src2.group_stride);
  }

  if (state->valid[(H16_L2_START + 0x38) / 4]) {
    printf("        L2_SrcIdxBase: 0x%05x0\n", l2->srcidx.base);
    printf("        L2_SrcIdxStrides: C=0x%05x0 D=0x%05x0 G=0x%05x0\n",
           l2->srcidx.channel_stride, l2->srcidx.depth_stride,
           l2->srcidx.group_stride);
  }

  if (state->valid[(H16_L2_START + 0x48) / 4]) {
    const char *fmt_str = "Unk";
    if (l2->result_cfg.dma_fmt == 0)
      fmt_str = "8b";
    else if (l2->result_cfg.dma_fmt == 1)
      fmt_str = "16b";
    else if (l2->result_cfg.dma_fmt == 3)
      fmt_str = "32b";

    printf(
        "        L2_ResultCfg: Type=%u (%s) DMAFmt=%u (%s) Intrlv=%u Cmp=%u\n",
        l2->result_cfg.res_type, L2_TYPE_STR(l2->result_cfg.res_type),
        l2->result_cfg.dma_fmt, fmt_str, l2->result_cfg.interleave,
        l2->result_cfg.compression);
    printf("        L2_ResultBase: 0x%05x0\n", l2->result.base);
    printf(
        "        L2_ResultStrides: C=0x%05x0 R=0x%05x0 D=0x%05x0 G=0x%05x0\n",
        l2->result.channel_stride, l2->result.row_stride,
        l2->result.depth_stride, l2->result.group_stride);
  }

  // Dump intermediate "Res" registers if valid
  if (state->valid[(H16_L2_START + 0x60) / 4])
    printf("        L2_Res24 : 0x%08x\n", l2->l2_res24);

  for (int i = 0; i < 3; i++) {
    if (state->valid[(H16_L2_START + 0x64 + i * 4) / 4]) {
      printf("        WrapCfg[%d]: Blocks=%d Len=0x%05x\n", i,
             l2->wrap_cfg[i].wrap_num_blocks, l2->wrap_cfg[i].wrap_len);
    }
  }

  if (state->valid[(H16_L2_START + 0x70) / 4])
    printf("        L2_Res28 : 0x%08x\n", l2->l2_res28);

  if (state->valid[(H16_L2_START + 0x74) / 4]) {
    printf("        ResultWrap: Mask=0x%x StartOffset=0x%x\n",
           l2->result_wrap_idx_off.wrap_index_mask,
           l2->result_wrap_idx_off.wrap_start_offset);
  }

  if (state->valid[(H16_L2_START + 0x78) / 4])
    printf("        L2_Res30 : 0x%08x\n", l2->l2_res30);

  // --- Result2 Block ---
  if (state->valid[(H16_L2_START + 0x7c) / 4] ||
      state->valid[(H16_L2_START + 0x80) / 4] ||
      state->valid[(H16_L2_START + 0x84) / 4] ||
      state->valid[(H16_L2_START + 0x88) / 4]) {
    printf("        Result2  :");
    if (state->valid[(H16_L2_START + 0x7c) / 4])
      printf(" Base=0x%05x", l2->result2.base);
    if (state->valid[(H16_L2_START + 0x80) / 4])
      printf(" CS=0x%05x", l2->result2.channel_stride);
    if (state->valid[(H16_L2_START + 0x84) / 4])
      printf(" RS=0x%05x", l2->result2.row_stride);
    if (state->valid[(H16_L2_START + 0x88) / 4])
      printf(" DS=0x%05x", l2->result2.depth_stride);
    printf("\n");
  }

  if (state->valid[(H16_L2_START + 0x8c) / 4]) {
    printf("        PEIndex  : Trans=%d Mode=%d Broadcast=%d MaxIdx=%d\n",
           l2->pe_index_cfg.transpose, l2->pe_index_cfg.mode,
           l2->pe_index_cfg.broadcast, l2->pe_index_cfg.max_index);
  }

  if (state->valid[(H16_L2_START + 0x90) / 4])
    printf("        L2_Res36 : 0x%08x\n", l2->l2_res36);
  if (state->valid[(H16_L2_START + 0x94) / 4])
    printf("        L2_Res37 : 0x%08x\n", l2->l2_res37);
  if (state->valid[(H16_L2_START + 0x98) / 4])
    printf("        L2_Res38 : 0x%08x\n", l2->l2_res38);

  if (state->valid[(H16_L2_START + 0x9c) / 4]) {
    printf("        ResultWrapIdx: Addr=0x%x\n", l2->wrap_addr);
  }
  if (state->valid[(H16_L2_START + 0xa0) / 4]) {
    printf("        CropTex   : S1X=%d S1Y=%d S2X=%d S2Y=%d\n",
           l2->crop_tex.s1x, l2->crop_tex.s1y, l2->crop_tex.s2x,
           l2->crop_tex.s2y);
  }
}

const char *get_texture_mode_name(uint32_t mode) {
  switch (mode) {
  case 0:
    return "Off";
  case 1:
    return "Gather";
  case 2:
    return "Bilinear";
  case 3:
    return "Bicubic";
  case 4:
    return "Nearest";
  default:
    return "Unknown";
  }
}

const char *get_hw_tensor_format_mode_name(uint32_t mode) {
  switch (mode) {
  case 0:
    return "None";
  case 1:
    return "Cmp";
  case 2:
    return "Lossy";
  default:
    return "Unknown";
  }
}

void print_tiledmasrc_h16(const hwx_state_t *state) {
  const ane_tiledmasrc_h16_t *src =
      (const ane_tiledmasrc_h16_t *)&state->values[H16_TILEDMA_SRC_START / 4];
  printf("        --- TileDMASrc (0x4D00) ---\n");

  const char *src_names[] = {"Src1", "Src2"};

  for (int i = 0; i < 2; i++) {
    uint32_t base_word = (H16_TILEDMA_SRC_START / 4) + i;
    if (!state->valid[base_word])
      continue;

    printf("        %sDMAConfig : En=%u (%s) DSID/Hint=%u Tag=%u DepInt=%u "
           "DepMode=%u\n",
           src_names[i], src->dmacfg[i].enable,
           src->dmacfg[i].enable ? "Enabled" : "Disabled",
           src->dmacfg[i].dsid_cache_hint, src->dmacfg[i].user_tag,
           src->dmacfg[i].dependency_interval, src->dmacfg[i].dependency_mode);

    // Wrap Config
    if (state->valid[(H16_TILEDMA_SRC_START + 0x08 + (i * 4)) / 4]) {
      printf("        %sWrapCfg    : Dim=%u Static=0x%x\n", src_names[i],
             src->wrapcfg[i].wrap_cfg_dim, src->wrapcfg[i].wrap_static);
    }

    // Base and Strides
    if (state->valid[(H16_TILEDMA_SRC_START + 0x10 + (i * 0x18)) / 4]) {
      printf("        %sBase       : 0x%08x%08x\n", src_names[i],
             src->strides[i].base_hi, src->strides[i].base_lo);
      printf(
          "        %sStrides    : Row=0x%x Chan=0x%x Depth=0x%x Group=0x%x\n",
          src_names[i], src->strides[i].row_stride,
          src->strides[i].plane_stride, src->strides[i].depth_stride,
          src->strides[i].group_stride);
    }

    // Metadata
    uint32_t meta_valid_word =
        (H16_TILEDMA_SRC_START + (i == 0 ? 0x50 : 0x5C)) / 4;
    if (state->valid[meta_valid_word]) {
      printf("        %sMetaCfg    : 0x%08x\n", src_names[i],
             i == 0 ? src->src1_meta_cfg : src->src2_meta_cfg);
    }
    uint32_t meta_addr_word =
        (H16_TILEDMA_SRC_START + (i == 0 ? 0x40 : 0x48)) / 4;
    if (state->valid[meta_addr_word]) {
      printf("        %sMetaData   : Addr=0x%08x%08x\n", src_names[i],
             i == 0 ? src->src1_meta_addr_hi : src->src2_meta_addr_hi,
             i == 0 ? src->src1_meta_addr_lo : src->src2_meta_addr_lo);
    }

    // Format Info
    if (state->valid[(H16_TILEDMA_SRC_START + 0x68 + (i * 4)) / 4]) {
      uint32_t mode = src->fmt[i].format_mode;
      uint32_t mem_fmt = src->fmt[i].mem_fmt;
      uint32_t trunc = src->fmt[i].trunc;
      uint32_t shift = src->fmt[i].shift;

      printf("        %sFmt     : Mode=%u MemFmt=%u Trunc=%u Shift=%u -> %s\n",
             src_names[i], mode, mem_fmt, trunc, shift,
             get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift));
      printf("                 Intrlv=%u OffCh=%d CmpVec=%d\n",
             src->fmt[i].interleave, src->fmt[i].offset_ch,
             src->fmt[i].cmp_vec);
    }

    // Compressed Info
    if (state->valid[(H16_TILEDMA_SRC_START + 0x78 + (i * 0x10)) / 4]) {
      printf("        %sComp       : En=%u (%s) PF=%u MBS=%u Lossy=%u "
             "MdTag=0x%x\n",
             src_names[i], src->compinfo[i].compressed_enable,
             src->compinfo[i].compressed_enable ? "Enabled" : "Disabled",
             src->compinfo[i].packing_format, src->compinfo[i].macroblock_size,
             src->compinfo[i].lossy_mode, src->compinfo[i].md_user_tag);
      printf("        %sCompSize   : 0x%08x%08x\n", src_names[i],
             src->compsize_hi[i], src->compsize_lo[i]);
      printf("        %sCropOffset : 0x%08x\n", src_names[i],
             src->cropoffset[i]);
    }

    // Wrap Dynamic / Dependency Offset
    if (state->valid[(H16_TILEDMA_SRC_START + 0xB8 + (i * 4)) / 4]) {
      printf("        %sWrapDyn    : 0x%08x\n", src_names[i],
             src->wrapdynamic[i]);
    }
    if (state->valid[(H16_TILEDMA_SRC_START + 0xC0 + (i * 4)) / 4]) {
      printf("        %sDepOff     : 0x%08x\n", src_names[i],
             src->dependencyoffset[i]);
    }
  }

  // Texture Config (at 0x4DC8)
  if (state->valid[(H16_TILEDMA_SRC_START + 0xC8) / 4]) {
    uint32_t val = src->texture_config;
    uint32_t mode = val & 7;
    printf("        TextureCfg    : 0x%08x Mode=%u (%s) Norm1=%u Norm2=%u "
           "Filter=%u BGEn=%u "
           "DepthVal=%u Wrap=%u\n",
           val, mode, get_texture_mode_name(mode), (val >> 3) & 7,
           (val >> 6) & 7, (val >> 12) & 7, (val >> 22) & 1, (val >> 23) & 1,
           (val >> 24) & 0x1F);
  }

  if (state->valid[(H16_TILEDMA_SRC_START + 0xCC) / 4]) {
    printf("        TextureIdxPerm: 0x%08x\n", src->texture_idx_permute);
  }
  if (state->valid[(H16_TILEDMA_SRC_START + 0xD0) / 4]) {
    printf("        TextureSrcPerm: 0x%08x\n", src->texture_src_permute);
  }

  // Ephemeral (0x4DF8)
  if (state->valid[(H16_TILEDMA_SRC_START + 0xF8) / 4]) {
    printf("        Src1Ephemeral : En=%u (%s)\n", src->src1ephemeral & 1,
           (src->src1ephemeral & 1) ? "Enabled" : "Disabled");
  }
}

void print_tiledmadst_h16(const hwx_state_t *state) {
  const ane_tiledmadst_h16_t *dst =
      (const ane_tiledmadst_h16_t *)&state->values[H16_TILEDMA_DST_START / 4];
  printf("        --- TileDMADst (0x5100) ---\n");
  if (state->valid[H16_TILEDMA_DST_START / 4]) {
    printf("        DstDMAConfig: En=%d (%s) DSID=%u Tag=%u\n", dst->dstcfg.en,
           dst->dstcfg.en ? "Enabled" : "Disabled", dst->dstcfg.dataset_id,
           dst->dstcfg.user_tag);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x10) / 4]) {
    printf("        DstStrides: Row=0x%08x Plane=0x%08x Depth=0x%08x "
           "Group=0x%08x\n",
           dst->dstrow_stride, dst->dstplane_stride, dst->dstdepth_stride,
           dst->dstgroup_stride);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x28) / 4]) {
    uint32_t fmt_mode = dst->dstfmtmode.format_mode;
    printf("        DstMeta   : Addr=0x%x%08x FmtMode=%u (%s) Size=0x%x\n",
           dst->dstmeta_hi, dst->dstmeta_lo, fmt_mode,
           get_hw_tensor_format_mode_name(fmt_mode),
           dst->dstfmtmode.metadata_size);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x38) / 4]) {
    uint32_t mode = dst->dstfmt.mode;
    uint32_t mem_fmt = dst->dstfmt.mem_fmt;
    uint32_t trunc = dst->dstfmt.trunc;
    uint32_t shift = dst->dstfmt.shift;

    printf("        DstFmt: Mode=%u MemFmt=%u Trunc=%u Shift=%u -> %s\n", mode,
           mem_fmt, trunc, shift,
           get_hw_tensor_format_name_v17(mode, mem_fmt, trunc, shift));
    printf(
        "                OffCh=%u ZeroPad (F=%u, L=%u) Intrlv=%u CmpVec=%u\n",
        dst->dstfmt.offset_ch, dst->dstfmt.zero_pad_first,
        dst->dstfmt.zero_pad_last, dst->dstfmt.interleave, dst->dstfmt.cmp_vec);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x40) / 4]) {
    printf("        DstComp: En=%d (%s) Packing=%d MBSize=%d Lossy=%d\n",
           dst->dstcompinfo.compressed_enable,
           dst->dstcompinfo.compressed_enable ? "Enabled" : "Disabled",
           dst->dstcompinfo.packing_format, dst->dstcompinfo.macroblock_size,
           dst->dstcompinfo.lossy_mode);
  }
  if (state->valid[(H16_TILEDMA_DST_START + 0x50) / 4]) {
    printf("        DstPixelOff: 0x%08x (CropY=%u)\n", dst->dstpixeloffset,
           dst->dstpixeloffset >> 16);
  }
}

// ============================================================================
// FP16 and LUT Decoding Support
// ============================================================================

// Convert FP16 to FP32
static float fp16_to_fp32(uint16_t h) {
  uint32_t sign = (h & 0x8000) << 16;
  uint32_t exp = (h & 0x7C00) >> 10;
  uint32_t mant = (h & 0x03FF);

  if (exp == 0) {
    if (mant == 0) {
      // Zero
      uint32_t f = sign;
      return *(float *)&f;
    } else {
      // Denormalized
      exp = 1;
      while ((mant & 0x400) == 0) {
        mant <<= 1;
        exp--;
      }
      mant &= 0x3FF;
    }
  } else if (exp == 0x1F) {
    // Inf or NaN
    uint32_t f = sign | 0x7F800000 | (mant << 13);
    return *(float *)&f;
  }

  // Normalized: adjust exponent bias from 15 to 127
  uint32_t f = sign | ((exp + 127 - 15) << 23) | (mant << 13);
  return *(float *)&f;
}

// Decode and print LUT coefficients
static void decode_lut_coefficients(const uint8_t *data, size_t size,
                                   const char *operation_hint) {
  if (data == NULL || size == 0) {
    return;
  }

  printf("        --- LUT Coefficient Analysis ---\n");
  printf("        Total Size: %zu bytes (%zu FP16 values)\n", size, size / 2);

  const uint16_t *fp16_data = (const uint16_t *)data;
  size_t num_values = size / 2;

  // Try to identify segment structure
  // Typical patterns:
  // - Slope, intercept pairs (2 values per segment)
  // - Breakpoint, slope, intercept triplets (3 values per segment)

  printf("        \n");
  printf("        Raw FP16 Values (first 32):\n");
  for (size_t i = 0; i < num_values && i < 32; i++) {
    float val = fp16_to_fp32(fp16_data[i]);
    printf("        [%2zu] 0x%04x = %8.4f", i, fp16_data[i], val);
    if ((i + 1) % 4 == 0) {
      printf("\n");
    } else {
      printf("  ");
    }
  }
  if (num_values > 32) {
    printf("        ... (%zu more values)\n", num_values - 32);
  }
  printf("\n");

  // Attempt to detect segment pattern by looking for monotonic increasing breakpoints
  printf("        Attempting segment detection:\n");

  // Pattern 1: Try breakpoint, slope, intercept (3 values per segment)
  if (num_values >= 9) {  // At least 3 segments
    printf("        Pattern: [breakpoint, slope, intercept] triplets\n");
    int num_segments = (int)(num_values / 3);
    for (int i = 0; i < num_segments && i < 12; i++) {
      float breakpoint = fp16_to_fp32(fp16_data[i * 3 + 0]);
      float slope = fp16_to_fp32(fp16_data[i * 3 + 1]);
      float intercept = fp16_to_fp32(fp16_data[i * 3 + 2]);
      printf("        Segment %2d: x >= %7.3f, y = %7.3f*x + %7.3f\n",
             i, breakpoint, slope, intercept);
    }
    if (num_segments > 12) {
      printf("        ... (%d more segments)\n", num_segments - 12);
    }
  }

  // Pattern 2: Try slope, intercept pairs (2 values per segment)
  printf("\n        Alternative: [slope, intercept] pairs\n");
  if (num_values >= 4) {  // At least 2 segments
    int num_segments = (int)(num_values / 2);
    for (int i = 0; i < num_segments && i < 12; i++) {
      float slope = fp16_to_fp32(fp16_data[i * 2 + 0]);
      float intercept = fp16_to_fp32(fp16_data[i * 2 + 1]);
      printf("        Segment %2d: y = %7.3f*x + %7.3f\n", i, slope, intercept);
    }
    if (num_segments > 12) {
      printf("        ... (%d more segments)\n", num_segments - 12);
    }
  }
  printf("\n");
}

// Global pointer to hwx file data for LUT decoding
static NSData *g_hwx_file_data = nil;

void print_kerneldmasrc_h16(const hwx_state_t *state) {
  const ane_kerneldmasrc_h16_t *k =
      (const ane_kerneldmasrc_h16_t *)&state->values[H16_KERNELDMA_START / 4];
  printf("        --- KernelDMASrc (0x5500) ---\n");
  if (state->valid[H16_KERNELDMA_START / 4])
    printf("        MasterCfg: En=%d (%s) Sparse=%d Reuse=%d\n",
           k->master_cfg.master_enable,
           k->master_cfg.master_enable ? "Enabled" : "Disabled",
           k->master_cfg.kernel_sparse_fmt, k->master_cfg.group_kernel_reuse);
  if (state->valid[(H16_KERNELDMA_START + 0x04) / 4])
    printf("        AlignedCoeffSize: 0x%08x\n", k->aligned_coeff_size_per_ch);
  if (state->valid[(H16_KERNELDMA_START + 0x08) / 4])
    printf("        Prefetch : Rate=%u Early=%d\n", k->prefetch.prefetch_rate,
           k->prefetch.early_term_en);
  if (state->valid[(H16_KERNELDMA_START + 0x18) / 4])
    printf("        KernelGroupStride: %u\n",
           k->kernel_group_stride & 0x3ffffff);
  if (state->valid[(H16_KERNELDMA_START + 0x1c) / 4])
    printf("        KernelOCGStride  : %u\n", k->kernel_ocg_stride & 0x3ffffff);

  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0x20) / 4 + i]) {
      printf("        CoeffCfg[%d] : En=%d (%s) DSID=%u Tag=%u\n", i,
             k->coeff_cfg[i].en, k->coeff_cfg[i].en ? "Enabled" : "Disabled",
             k->coeff_cfg[i].dataset_id, k->coeff_cfg[i].user_tag);
    }
  }
  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0x60) / 4 + i]) {
      printf("        CoeffBase[%d]: 0x%08x\n", i, k->coeff_base[i]);
    }
  }
  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0xa0) / 4 + i]) {
      printf("        CoeffSize[%d]: 0x%08x\n", i,
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

void print_kerneldmasrc_h17(const hwx_state_t *state) {
  const ane_kerneldmasrc_h17_t *k =
      (const ane_kerneldmasrc_h17_t *)&state->values[H16_KERNELDMA_START / 4];
  printf("        --- KernelDMASrc (0x5500) [H17] ---\n");
  if (state->valid[H16_KERNELDMA_START / 4])
    printf("        MasterCfg: En=%d Sparse=%d Reuse=%d\n", k->pe_cfg.enable,
           k->pe_cfg.sparse, k->pe_cfg.reuse);
  if (state->valid[(H16_KERNELDMA_START + 0x04) / 4])
    printf("        AlignedCoeffSize: 0x%08x\n", k->aligned_coeff_size);
  if (state->valid[(H16_KERNELDMA_START + 0x08) / 4])
    printf("        Prefetch : 0x%08x\n", k->prefetch);
  if (state->valid[(H16_KERNELDMA_START + 0x18) / 4])
    printf("        StrideX  : %u\n", k->stridex);
  if (state->valid[(H16_KERNELDMA_START + 0x1c) / 4])
    printf("        StrideY  : %u\n", k->stridey);

  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0x20) / 4 + i]) {
      printf("        CoeffCfg[%d] : Hint=%u DSID=%u Tag=%u\n", i,
             k->coeff_dma_cfg[i].cache_hint, k->coeff_dma_cfg[i].dataset_id,
             k->coeff_dma_cfg[i].user_tag);
    }
  }
  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0x60) / 4 + i]) {
      printf("        CoeffBase[%d]: 0x%08x\n", i, k->coeff_base_addr[i]);
    }
  }
  for (int i = 0; i < 16; i++) {
    if (state->valid[(H16_KERNELDMA_START + 0xa0) / 4 + i]) {
      printf("        CoeffSize[%d]: 0x%08x\n", i, k->coeff_mem_bfr_size[i]);
    }
  }
  if (state->valid[(H16_KERNELDMA_START + 0xe0) / 4])
    printf("        BiasCfg  : Hint=%u\n", k->bias_dma_cfg.cache_hint);
  if (state->valid[(H16_KERNELDMA_START + 0xf0) / 4])
    printf("        PSCfg    : Hint=%u\n", k->postscale_dma_cfg.cache_hint);
  if (state->valid[(H16_KERNELDMA_START + 0x100) / 4])
    printf("        PalCfg   : Hint=%u Tag=%u\n", k->palette_dma_cfg.cache_hint,
           k->palette_dma_cfg.user_tag);
  if (state->valid[(H16_KERNELDMA_START + 0x110) / 4])
    printf("        NLutCfg  : Hint=%u Tag=%u\n", k->nlut_dma_cfg.cache_hint,
           k->nlut_dma_cfg.user_tag);
}

void print_kerneldmasrc_h18(const hwx_state_t *state) {
  printf("        --- KernelDMASrc (0x5500) [H18] ---\n");
  print_kerneldmasrc_h17(state);
}

void print_cachedma_h16(const hwx_state_t *state) {
  ane_cachedma_h16_t cdma =
      *(ane_cachedma_h16_t *)&state->values[H16_CACHEDMA_START / 4];
  printf("        --- CacheDMASrc (0x5900) ---\n");
  if (state->valid[H16_CACHEDMA_START / 4]) {
    printf("        Control: Flush=%d En=%d (%s) TaskSync=0x%x ET=0x%x FL=%d "
           "Thresh=0x%04x\n",
           cdma.control.flush, cdma.control.enable,
           cdma.control.enable ? "Enabled" : "Disabled", cdma.control.task_sync,
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

// Architecture printer tables
static const arch_printers_t h13_printers = {
  .print_common = print_common_h13,
  .print_l2 = print_l2_h13,
  .print_pe_index = NULL,
  .print_pe = print_pe_h13,
  .print_ne = print_ne_h13,
  .print_tiledmasrc = print_tiledmasrc_h13,
  .print_tiledmadst = print_tiledmadst_h13,
  .print_kerneldmasrc = print_kerneldmasrc_h13,
  .print_cachedma = NULL,
};

static const arch_printers_t h14_printers = {
  .print_common = print_common_h14,
  .print_l2 = print_l2_h14,
  .print_pe_index = NULL,
  .print_pe = print_pe_h14,
  .print_ne = print_ne_h14,
  .print_tiledmasrc = print_tiledmasrc_h14,
  .print_tiledmadst = print_tiledmadst_h14,
  .print_kerneldmasrc = print_kerneldmasrc_h14,
  .print_cachedma = NULL,
};

static const arch_printers_t h16_printers = {
  .print_common = print_common_h16,
  .print_l2 = print_l2_h16,
  .print_pe_index = print_pe_index_h16,
  .print_pe = print_pe_h16,
  .print_ne = print_ne_h16,
  .print_tiledmasrc = print_tiledmasrc_h16,
  .print_tiledmadst = print_tiledmadst_h16,
  .print_kerneldmasrc = print_kerneldmasrc_h16,
  .print_cachedma = print_cachedma_h16,
};

static const arch_printers_t h17_printers = {
  .print_common = print_common_h16,  // H17 uses H16 common
  .print_l2 = print_l2_h17,
  .print_pe_index = print_pe_index_h16,
  .print_pe = print_pe_h17,
  .print_ne = print_ne_h16,  // H17 uses H16 NE
  .print_tiledmasrc = print_tiledmasrc_h16,  // H17 uses H16 TileDMA
  .print_tiledmadst = print_tiledmadst_h16,
  .print_kerneldmasrc = print_kerneldmasrc_h17,
  .print_cachedma = print_cachedma_h16,
};

static const arch_printers_t h18_printers = {
  .print_common = print_common_h16,  // H18 uses H16 common
  .print_l2 = print_l2_h18,
  .print_pe_index = print_pe_index_h16,
  .print_pe = print_pe_h18,
  .print_ne = print_ne_h16,  // H18 uses H16 NE
  .print_tiledmasrc = print_tiledmasrc_h16,  // H18 uses H16 TileDMA
  .print_tiledmadst = print_tiledmadst_h16,
  .print_kerneldmasrc = print_kerneldmasrc_h18,
  .print_cachedma = print_cachedma_h16,
};

// Architecture block definitions
static const hwx_block_info_t h13_blocks[] = {
  {"[0x00000] Common Module", H13_COMMON_START, 16},
  {"[0x04800] L2 Cache Control", H13_L2_START, 16},
  {"[0x08800] Planar Engine (PE)", H13_PE_START, 4},
  {"[0x0C800] Neural Engine Core (NE)", H13_NE_START, 5},
  {"[0x13800] TileDMA Source", H13_TILEDMA_SRC_START, 24},
  {"[0x17800] TileDMA Destination", H13_TILEDMA_DST_START, 7},
  {"[0x1F800] KernelDMA Source", H13_KERNELDMA_START, 5},
};

static const hwx_block_info_t h14_blocks[] = {
  {"[0x0000] Common Module", H14_COMMON_START, H14_COMMON_COUNT},
  {"[0x0500] L2 Cache Control", H14_L2_START, H14_L2_COUNT},
  {"[0x0900] Planar Engine (PE)", H14_PE_START, H14_PE_COUNT},
  {"[0x0D00] Neural Engine (NE)", H14_NE_START, H14_NE_COUNT},
  {"[0x1100] TileDMA Source", H14_TILEDMA_SRC_START, H14_TILEDMA_SRC_COUNT},
  {"[0x1500] TileDMA Destination", H14_TILEDMA_DST_START, H14_TILEDMA_DST_COUNT},
  {"[0x1900] KernelDMA Source", H14_KERNELDMA_START, H14_KERNELDMA_COUNT},
};

static const hwx_block_info_t h16_blocks[] = {
  {"[0x0000] Common Module", H16_COMMON_START, 23},
  {"[0x4100] L2 Cache Control", H16_L2_START, 41},
  {"[0x4500] Planar Engine (PE)", H16_PE_START, 16},
  {"[0x4900] Neural Engine Core (NE)", H16_NE_START, 12},
  {"[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, 81},
  {"[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, 21},
  {"[0x5500] KernelDMA Source", H16_KERNELDMA_START, 72},
  {"[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, 12},
};

static const hwx_block_info_t h17_blocks[] = {
  {"[0x0000] Common Module", H16_COMMON_START, H17_COMMON_COUNT},
  {"[0x4100] L2 Cache Control", H16_L2_START, H17_L2_COUNT},
  {"[0x4500] Planar Engine (PE)", H16_PE_START, H17_PE_COUNT},
  {"[0x4900] Neural Engine Core (NE)", H16_NE_START, H17_NE_COUNT},
  {"[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, H17_TILEDMA_SRC_COUNT},
  {"[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, H17_TILEDMA_DST_COUNT},
  {"[0x5500] KernelDMA Source", H16_KERNELDMA_START, H17_KERNELDMA_COUNT},
  {"[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, H17_CACHEDMA_COUNT},
};

static const hwx_block_info_t h18_blocks[] = {
  {"[0x0000] Common Module", H16_COMMON_START, H18_COMMON_COUNT},
  {"[0x4100] L2 Cache Control", H16_L2_START, H18_L2_COUNT},
  {"[0x4500] Planar Engine (PE)", H16_PE_START, H18_PE_COUNT},
  {"[0x4900] Neural Engine Core (NE)", H16_NE_START, H18_NE_COUNT},
  {"[0x4D00] TileDMA Source", H16_TILEDMA_SRC_START, H18_TILEDMA_SRC_COUNT},
  {"[0x5100] TileDMA Destination", H16_TILEDMA_DST_START, H18_TILEDMA_DST_COUNT},
  {"[0x5500] KernelDMA Source", H16_KERNELDMA_START, H18_KERNELDMA_COUNT},
  {"[0x5900] CacheDMA & Telemetry", H16_CACHEDMA_START, H18_CACHEDMA_COUNT},
};

// Get architecture descriptor based on instruction version and subtype
static const arch_descriptor_t *get_arch_descriptor(uint32_t instr_ver, uint32_t subtype) {
  static const arch_descriptor_t descriptors[] = {
    // H13 (A14/M1) - ISA v7, subtype 4
    {7, 4, "H13 (A14/M1)", get_m1_reg_name, &h13_printers, h13_blocks, 7},

    // H14 (A15/M2) - ISA v11, subtype 5
    {11, 5, "H14 (A15/M2)", get_h14_reg_name, &h14_printers, h14_blocks, 7},

    // H15 (A16/M3) - ISA v8, subtype 6
    {8, 6, "H15 (A16/M3)", get_m4_reg_name, &h16_printers, h16_blocks, 8},

    // H16 (A17 Pro/M4) - ISA v17, subtype 7
    {17, 7, "H16 (A17 Pro/M4)", get_m4_reg_name, &h16_printers, h16_blocks, 8},

    // H17 (A18 Pro/M5) - ISA v19, subtype 9
    {19, 9, "H17 (A18 Pro/M5)", get_h17_reg_name, &h17_printers, h17_blocks, 8},

    // H18 (A19) - ISA v20, subtype 10
    {20, 10, "H18 (A19)", get_h18_reg_name, &h18_printers, h18_blocks, 8},
  };

  const int desc_count = sizeof(descriptors) / sizeof(descriptors[0]);

  // Match by instruction version first, then by subtype if ambiguous
  for (int i = 0; i < desc_count; i++) {
    if (descriptors[i].instr_ver == instr_ver && descriptors[i].subtype == subtype) {
      return &descriptors[i];
    }
  }

  // Fallback: match by instruction version only
  for (int i = 0; i < desc_count; i++) {
    if (descriptors[i].instr_ver == instr_ver) {
      return &descriptors[i];
    }
  }

  // Default to H13 if no match
  return &descriptors[0];
}

void report_hwx_state(const hwx_state_t *state, BOOL dump_reg_blocks) {
  const arch_descriptor_t *arch = get_arch_descriptor(state->instr_ver, state->subtype);
  const arch_printers_t *printers = arch->printers;

  // Call all printer functions in order
  if (printers->print_common)
    printers->print_common(state);

  if (printers->print_ne)
    printers->print_ne(state);

  if (printers->print_pe_index)
    printers->print_pe_index(state);

  if (printers->print_pe)
    printers->print_pe(state);

  if (printers->print_l2)
    printers->print_l2(state);

  if (printers->print_tiledmasrc)
    printers->print_tiledmasrc(state);

  if (printers->print_tiledmadst)
    printers->print_tiledmadst(state);

  if (printers->print_kerneldmasrc)
    printers->print_kerneldmasrc(state);

  if (printers->print_cachedma)
    printers->print_cachedma(state);

  // Dump raw register blocks if requested
  if (dump_reg_blocks) {
    dump_hw_blocks(state, arch->blocks, arch->block_count, arch->get_reg_name);
  }
}

void report_hwx_state_json(const hwx_state_t *state) {
  const arch_descriptor_t *arch = get_arch_descriptor(state->instr_ver, state->subtype);

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dict setObject:[NSString stringWithUTF8String:arch->name] forKey:@"arch"];
  [dict setObject:@(state->subtype) forKey:@"subtype"];
  [dict setObject:@(state->instr_ver) forKey:@"instr_ver"];

  NSMutableArray *regs = [NSMutableArray array];
  for (uint32_t r = 0; r < HW_MAX_REGS; r++) {
    if (state->valid[r]) {
      uint32_t addr = r * 4;
      const char *name = arch->get_reg_name(addr);
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

// Parse H13 (older) instruction stream format
static void parse_instruction_stream_h13(const uint8_t *ptr, size_t total_len,
                                         uint32_t offset, const ane_header_h13_t *td,
                                         hwx_state_t *state) {
  if (offset + sizeof(ane_header_h13_t) > total_len) {
    return;
  }

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

    // Skip padding words
    if (hdr == 0)
      continue;

    uint32_t count = (hdr >> 26) & 0x3f;
    uint32_t addr = (hdr & 0x3ffffff) >> 2;
    uint32_t num_vals = count + 1;

    for (uint32_t i = 0; i < num_vals; i++) {
      if (w_idx >= num_words)
        break;
      // Mask addr to prevent buffer overflow
      if (addr + i < HW_MAX_REGS) {
        state->values[addr + i] = words[w_idx];
        state->valid[addr + i] = true;
      }
      w_idx++;
    }
  }
}

// Parse H16 (newer) instruction stream format with sparse mask support
static void parse_instruction_stream_h16(const uint8_t *ptr, uint32_t offset,
                                         const ane_header_h16_t *hdr,
                                         hwx_state_t *state) {
  const uint32_t *words = (const uint32_t *)(ptr + offset);
  int num_words = (hdr->task_size * 4) / 4;

  // H16 task descriptor instruction stream starts at Word 9 (offset 36)
  int i = 9;

  while (i < num_words) {
    uint32_t header = words[i++];
    uint32_t word_addr = header & 0x7FFF;

    if ((header >> 31) == 0) {
      // Dense format: consecutive registers
      uint16_t num_regs = (header >> 15) & 0x3F;
      for (int j = 0; j <= num_regs && i < num_words; j++) {
        if (word_addr + j < HW_MAX_REGS) {
          // Track first write for dimension registers
          if (!state->first_written[word_addr + j]) {
            state->first_values[word_addr + j] = words[i];
            state->first_written[word_addr + j] = true;
          }
          state->values[word_addr + j] = words[i];
          state->valid[word_addr + j] = true;
        }
        i++;
      }
    } else {
      // Sparse format: mask-based register selection
      uint32_t mask = (header >> 15) & 0xFFFF;
      if (i < num_words) {
        if (word_addr < HW_MAX_REGS) {
          // Track first write
          if (!state->first_written[word_addr]) {
            state->first_values[word_addr] = words[i];
            state->first_written[word_addr] = true;
          }
          state->values[word_addr] = words[i];
          state->valid[word_addr] = true;
        }
        i++;
      }
      for (int bit = 0; bit < 16 && i < num_words; bit++) {
        if ((mask >> bit) & 1) {
          if (word_addr + bit + 1 < HW_MAX_REGS) {
            // Track first write
            if (!state->first_written[word_addr + bit + 1]) {
              state->first_values[word_addr + bit + 1] = words[i];
              state->first_written[word_addr + bit + 1] = true;
            }
            state->values[word_addr + bit + 1] = words[i];
            state->valid[word_addr + bit + 1] = true;
          }
          i++;
        }
      }
    }
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

    // Parse instruction stream
    parse_instruction_stream_h13(ptr, total_len, offset, td, &state);

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
      printf("        TID: 0x%04x TaskSize: 0x%x ExeCycles: %u ENE: %u DTID: "
             "0x%04x\n",
             m4h->tid, m4h->task_size, m4h->exe_cycles, m4h->ctrl_flags.ene,
             m4h->dtid);
      printf("        LogEvents: 0x%06x Exceptions: 0x%06x\n", m4h->log_events,
             m4h->exceptions);
      printf("        LiveOuts: 0x%08x TSR: %d TDE: %d\n", m4h->live_outs,
             m4h->ctrl_flags.tsr, m4h->ctrl_flags.tde);
    } else {
      task_idx++;
    }

    hwx_state_t state = {0};
    state.instr_ver = get_instruction_set_version(subtype);
    state.subtype = subtype;

    // Parse instruction stream
    parse_instruction_stream_h16(ptr, offset, m4h, &state);

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
          // H14 (subtype 5, ISA v11) and H15 (subtype 6, ISA v8) both use Dense format
          if (instr_ver >= 11 || header->cpusubtype == 6) {
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

    // Handle __KERN segments (contain LUT coefficients)
    if (strncmp(seg->segname, "__KERN_", 7) == 0) {
      if (sect->offset + sect->size <= data.length) {
        const uint8_t *section_ptr = (const uint8_t *)data.bytes + sect->offset;
        size_t section_size = (size_t)sect->size;

        printf("      LUT Data Found (segment %s, section %s):\n",
               seg->segname, sect->sectname);

        // Store globally for use by print_kerneldmasrc_h16
        g_hwx_file_data = data;

        // Decode the LUT coefficients
        decode_lut_coefficients(section_ptr, section_size, seg->segname);

        if (dump_hexdump) {
          hex_dump(sect->sectname, section_ptr, section_size);
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
