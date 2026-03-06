#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <stdlib.h>
#include <unistd.h>

#define HWX_MAGIC 0xbeefface
#define LC_ANE_MAPPED_REGION 0x40

typedef struct __attribute__((packed)) {
  uint16_t tid;             // 0x000
  uint8_t nid;              // 0x002
  uint8_t lnid_eon;         // 0x003: LNID (bit 0), EON (bit 1)
  uint16_t exe_cycles;      // 0x004
  uint16_t next_size_pad;   // 0x006: NextSize (9 bits), Pad (7 bits)
  uint32_t log_events : 24; // 0x008
  uint32_t pad0 : 8;
  uint32_t exceptions : 24; // 0x00c
  uint32_t pad1 : 8;
  uint32_t debug_log_events : 24; // 0x010
  uint32_t pad2 : 8;
  uint32_t debug_exceptions : 24; // 0x014
  uint32_t pad3 : 8;
  uint32_t flags;        // 0x018
  uint32_t next_pointer; // 0x01c
  uint32_t pad4;
  uint32_t pad5;
} ane_td_header_t;

typedef struct __attribute__((packed)) {
  uint16_t tid;             // 0x000
  uint32_t task_size : 11;  // 0x002 bits 0-10 (Header[0] bits 16-26)
  uint32_t pad0 : 5;        // 0x002 bits 11-15 (Header[0] bits 27-31)
  uint16_t exe_cycles;      // 0x004
  uint16_t pad1;            // 0x006
  uint32_t log_events : 24; // 0x008
  uint32_t pad2 : 8;
  uint32_t exceptions : 24; // 0x00c
  uint32_t pad3 : 8;
  uint32_t debug_log_events : 24; // 0x010
  uint32_t pad4 : 8;
  uint32_t debug_exceptions : 24; // 0x014
  uint32_t pad5 : 8;
  uint32_t live_outs; // 0x018
  uint32_t tsr : 1;   // 0x01c bit 0
  uint32_t tde : 1;   // 0x01c bit 1
  uint32_t pad6 : 14; // 0x01c bits 2-15
  uint32_t ene : 3;   // 0x01c bits 16-18
  uint32_t pad7 : 13; // 0x01c bits 19-31
  uint16_t tdid;
  uint16_t pad8;
} ane_m4_header_t;

typedef struct __attribute__((packed)) {
  // Word 0 (0x000)
  struct {
    uint32_t infmt : 2;
    uint32_t pad0_0 : 2;
    uint32_t outfmt : 2;
    uint32_t pad0_1 : 26;
  } ch_cfg;

  // Word 1-8
  struct {
    uint32_t w_in : 17;
    uint32_t pad0 : 15;
  } win;
  struct {
    uint32_t h_in : 17;
    uint32_t pad0 : 15;
  } hin;
  struct {
    uint32_t c_in : 17;
    uint32_t pad0 : 15;
  } cin;
  struct {
    uint32_t d_in : 17;
    uint32_t pad0 : 15;
  } din;
  struct {
    uint32_t w_out : 17;
    uint32_t pad0 : 15;
  } wout;
  struct {
    uint32_t h_out : 17;
    uint32_t pad0 : 15;
  } hout;
  struct {
    uint32_t c_out : 17;
    uint32_t pad0 : 15;
  } cout;
  struct {
    uint32_t d_out : 17;
    uint32_t pad0 : 15;
  } dout;

  // Word 9 (0x024)
  struct {
    uint32_t num_groups : 13;
    uint32_t pad0 : 19;
  } group_cfg;

  // Word 10 (0x028)
  struct {
    uint32_t kw : 6;
    uint32_t kh : 6;
    uint32_t pad10_0 : 1;
    uint32_t sx : 2;
    uint32_t sy : 2;
    uint32_t px : 5;
    uint32_t py : 5;
    uint32_t pad10_1 : 1;
    uint32_t ox : 2;
    uint32_t oy : 2;
  } conv_cfg_0;

  // Word 11-14
  uint32_t conv_cfg_3d; // 0x02c (Word 11)

  // Word 12 (0x030)
  struct {
    uint32_t pad0 : 14;
    uint32_t unicast_en : 1;
    uint32_t pad1 : 1;
    uint32_t unicast_cin : 16;
  } unicast_cfg;

  // Word 13 (0x034)
  struct {
    uint32_t height : 17;
    uint32_t pad0 : 15;
  } tile_height;

  // Word 14 (0x038)
  struct {
    uint32_t pad0 : 16;
    uint32_t overlap : 5;
    uint32_t pad_top : 5;
    uint32_t pad_bottom : 5;
    uint32_t pad1 : 1;
  } tile_overlap;

  // Word 15 (0x03C)
  struct {
    uint32_t pad0 : 2;
    uint32_t small_src_mode : 2;
    uint32_t task_type : 4;
    uint32_t pad1 : 11;
    uint32_t active_ne : 3;
    uint32_t pad2 : 1;
    uint32_t l2_barrier : 1;
    uint32_t pad3 : 4;
    uint32_t out_trans : 1;
    uint32_t pad4 : 3;
  } maccfg;

  // Word 16 (0x40)
  struct {
    uint32_t ocg_size : 3;
    uint32_t pad0 : 29;
  } conv_cfg_1;

  // Word 17 (0x044)
  struct {
    uint32_t w : 4;
    uint32_t h : 5;
    uint32_t pad0 : 23;
  } patch_dim;

  // Word 18 (0x048)
  struct {
    uint32_t src1_w_bcast : 1;
    uint32_t src1_h_bcast : 1;
    uint32_t src1_d_bcast : 1;
    uint32_t src1_c_bcast : 1;
    uint32_t src2_w_bcast : 1;
    uint32_t src2_h_bcast : 1;
    uint32_t src2_d_bcast : 1;
    uint32_t src2_c_bcast : 1;
    uint32_t src1_trans : 1;
    uint32_t src2_trans : 1;
    uint32_t out_trans : 1;
    uint32_t pad0 : 21;
  } pe_routing;

  uint32_t nid; // 0x04C (Word 19)

  // Word 20 (0x050)
  struct {
    uint32_t category : 4;
    uint32_t pad0 : 28;
  } dpe;

  uint32_t val_21; // 0x054 (Word 21)
  uint32_t val_22; // 0x058 (Word 22)

} ane_m4_common_t;

const char *get_m4_reg_name(uint32_t addr) {
  if (addr < 23 * 4) {
    static const char *common_names[] = {
        "ChCfg",    "Win",       "Hin",        "Cin",        "Din",
        "Wout",     "Hout",      "Cout",       "Dout",       "Batch",
        "ConvCfg0", "ConvCfg3D", "UnicastCfg", "TileHeight", "TileOverlap",
        "MacCfg",   "ConvCfg1",  "PatchDim",   "PERouting",  "NID",
        "DPE",      "Val21",     "Val22"};
    return common_names[addr / 4];
  }
  // L2 0x4100
  if (addr >= 0x4100 && addr <= 0x41A4) {
    uint32_t off = addr - 0x4100;
    if (off == 0x00)
      return "L2BfrCfg";
    if (off == 0x04)
      return "L2Src1Cfg";
    if (off == 0x08)
      return "L2Src2Cfg";
    if (off >= 0x10 && off <= 0x20) {
      static const char *s1[] = {"L2Src1BaseAddr", "L2Src1PlaneStride",
                                 "L2Src1RowStride", "L2Src1DepthStride",
                                 "L2Src1GroupStride"};
      return s1[(off - 0x10) / 4];
    }
    if (off >= 0x24 && off <= 0x34) {
      static const char *s2[] = {"L2Src2BaseAddr", "L2Src2PlaneStride",
                                 "L2Src2RowStride", "L2Src2DepthStride",
                                 "L2Src2GroupStride"};
      return s2[(off - 0x24) / 4];
    }
    if (off >= 0x38 && off <= 0x44) {
      static const char *si[] = {"L2SrcIdxBaseAddr", "L2SrcIdxPlaneStride",
                                 "L2SrcIdxDepthStride", "L2SrcIdxGroupStride"};
      return si[(off - 0x38) / 4];
    }
    if (off == 0x48)
      return "L2ResultCfg";
    if (off >= 0x4C && off <= 0x5C) {
      static const char *res[] = {"L2ResultBaseAddr", "L2ResultPlaneStride",
                                  "L2ResultRowStride", "L2ResultDepthStride",
                                  "L2ResultGroupStride"};
      return res[(off - 0x4C) / 4];
    }
    if (off == 0x64)
      return "L2ResultWrapCfg";
    if (off == 0x74)
      return "L2ResultWrapIndex";
    if (off == 0x9C)
      return "L2ResultWrapAddrOff1";
    if (off == 0xA0)
      return "L2ResultWrapAddrOff2";
  }
  // PE 0x4500
  if (addr >= 0x4500 && addr <= 0x4514) {
    uint32_t off = addr - 0x4500;
    static const char *pe_names[] = {"PEOpMode", "PEBias1", "PEScale1",
                                     "PERaw3",   "PEBias2", "PEScale2"};
    return pe_names[off / 4];
  }
  // NE 0x4900
  if (addr >= 0x4900 && addr <= 0x4910) {
    uint32_t off = addr - 0x4900;
    static const char *ne_names[] = {"KernelCfg", "MACCfg", "MatrixBias",
                                     "AccBias", "PostScale"};
    return ne_names[off / 4];
  }
  // CE/CacheDMA 0x5900
  if (addr >= 0x5900 && addr <= 0x5930) {
    uint32_t off = addr - 0x5900;
    static const char *cdma_names[] = {
        "CacheDMAConfig",  "CacheDMAPre0",  "CacheDMAPre1",  "CacheDMAPad3",
        "CacheDMAPad4",    "CacheDMAPad5",  "CacheDMAPre2",  "CacheDMAPre3",
        "CacheDMATerm0",   "CacheDMATerm1", "CacheDMATerm2", "CacheDMATerm3",
        "TelemetryBackOff"};
    if (off / 4 < 13)
      return cdma_names[off / 4];
  }
  // TileDMA Src 0x4D00
  if (addr >= 0x4D00 && addr <= 0x4DB4) {
    uint32_t off = addr - 0x4D00;
    if (off == 0x00)
      return "Src1DMAConfig";
    if (off == 0x04)
      return "Src2DMAConfig";
    if (off == 0x08)
      return "Src1Wrap";
    if (off == 0x0C)
      return "Src2Wrap";
    if (off == 0x18)
      return "Src1RowStride";
    if (off == 0x1C)
      return "Src1PlaneStride";
    if (off == 0x20)
      return "Src1DepthStride";
    if (off == 0x24)
      return "Src1GroupStride";
    if (off == 0x68)
      return "Src1Fmt";
    if (off >= 0x98 && off <= 0xA4)
      return "Src1PixelOff";
    if (off >= 0xA8 && off <= 0xB4)
      return "Src2PixelOff";
  }
  // TileDMA Dst 0x5100
  if (addr >= 0x5100 && addr <= 0x5138) {
    uint32_t off = addr - 0x5100;
    if (off == 0x00)
      return "DstDMAConfig";
    if (off == 0x10)
      return "DstRowStride";
    if (off == 0x14)
      return "DstPlaneStride";
    if (off == 0x18)
      return "DstDepthStride";
    if (off == 0x1C)
      return "DstGroupStride";
    if (off == 0x38)
      return "DstFmt";
  }
  // KernelDMA Src 0x5500
  if (addr >= 0x5500 && addr <= 0x5650) {
    uint32_t off = addr - 0x5500;
    if (off == 0x08)
      return "KDMA_Prefetch";
    if (off == 0x18)
      return "KDMA_StrideX";
    if (off == 0x1C)
      return "KDMA_StrideY";
    if (off >= 0x20 && off <= 0x5C)
      return "CoeffCfg";
    if (off >= 0x60 && off <= 0x9C)
      return "CoeffBase";
    if (off >= 0xA0 && off <= 0xDC)
      return "CoeffSize";
    if (off == 0xE0)
      return "BiasCfg";
    if (off == 0xF0)
      return "PostScaleCfg";
    if (off == 0x100)
      return "PaletteCfg";
    if (off == 0x110)
      return "NonLinearCfg";
  }
  return NULL;
}

// [0x5500] KernelDMA Source Block
typedef struct {
  uint32_t pad0[2];  // Word 0-1
  uint32_t prefetch; // Word 2 (0x5508)
  uint32_t pad1[3];  // Word 3-5
  uint32_t stridex;  // Word 6 (0x5518)
  uint32_t stridey;  // Word 7 (0x551C)

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } coeff_cfg[16]; // Word 8-23 (0x5520-0x555C)

  uint32_t coeff_base[16]; // Word 24-39 (0x5560-0x559C)
  uint32_t coeff_size[16]; // Word 40-55 (0x55A0-0x55DC)

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } bias_cfg; // Word 56 (0x55E0)

  uint32_t pad2[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } post_scale_cfg; // Word 60 (0x55F0)

  uint32_t pad3[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } palette_cfg; // Word 64 (0x5600)

  uint32_t pad4[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } non_linear_cfg; // Word 68 (0x5610)
} __attribute__((packed)) ane_m4_kerneldma_src_t;

typedef struct {
  uint32_t config; // 0x5900: bits[3:2]: TaskSync, [6:4]: EarlyTerm, [16:31]:
                   // Footprint
  uint32_t
      pre0; // 0x5904: [9:0]: BWLimit, [19:16]: Sieve2, [23:20]: TelemetryAgeOut
  uint32_t pre1; // 0x5908: [13:0]: Sieve1
  uint32_t pad0[3];
  uint32_t pre2_term; // 0x5918: [0:15]: DSIDSize (low), [16:31]: EarlyTerm0 (H)
  uint32_t pre3;      // 0x591c: [27:17]: Footprint2
  uint32_t term1_low; // 0x5920: [16:31]: EarlyTerm1 (H)
  uint32_t pad1;      // 0x5924
  uint32_t term2_3;   // 0x5928: [0:7]: EarlyTerm2 (B), [16:23]: EarlyTerm3 (B)
  uint32_t backoff;   // 0x592c: TelemetryBackOff
} __attribute__((packed)) ane_m4_cachedma_t;

// [0x4D00] TileDMA Source Block
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 20;
    uint32_t dep_mode : 2;
    uint32_t pad2 : 2;
  } src1cfg; // Word 0

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 24;
  } src2cfg; // Word 1

  uint32_t src1wrap; // Word 2
  uint32_t src2wrap; // Word 3
  uint32_t pad0[2];  // Word 4-5

  uint32_t src1rows;   // Word 6
  uint32_t src1chans;  // Word 7
  uint32_t src1depths; // Word 8
  uint32_t src1groups; // Word 9

  uint32_t pad1[16];   // Word 10-25
  uint32_t src1memfmt; // Word 26

  uint32_t pad2[11];        // Word 27-37
  uint32_t src1pixeloff[4]; // Word 38-41
  uint32_t src2pixeloff[4]; // Word 42-45
} __attribute__((packed)) ane_m4_tiledma_src_t;

// [0x5100] TileDMA Destination Block
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 24;
  } dstcfg; // Word 0

  uint32_t pad0[3]; // Word 1-3

  uint32_t dstrows;   // Word 4
  uint32_t dstchans;  // Word 5
  uint32_t dstdepths; // Word 6
  uint32_t dstgroups; // Word 7

  uint32_t pad1[6];   // Word 8-13
  uint32_t dstmemfmt; // Word 14
} __attribute__((packed)) ane_m4_tiledma_dst_t;

// [0x4900] Neural Engine (NE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4900)
  struct {
    uint32_t kernel_fmt : 2;
    uint32_t palettized_en : 1;
    uint32_t pad0 : 1;
    uint32_t palettized_bits : 4;
    uint32_t sparse_fmt : 1;
    uint32_t pad1 : 6;
    uint32_t sparse_binary : 1;
    uint32_t alignment_fmt : 1;
    uint32_t pad2 : 4;
    uint32_t sparse_block_size : 3;
    uint32_t asym_quant_en : 1;
    uint32_t pad3 : 7;
  } kernel_cfg;

  // Word 1 (0x4904)
  struct {
    uint32_t op_mode : 3;
    uint32_t kernel_mode : 1;
    uint32_t ne_bias_en : 1;
    uint32_t passthrough_en : 1;
    uint32_t matrix_bias_en : 1;
    uint32_t pad0 : 1;
    uint32_t binary_point : 6;
    uint32_t post_scale_en : 1;
    uint32_t pad1 : 1;
    uint32_t non_linear_mode : 2;
    uint32_t padding_mode : 1;
    uint32_t max_pool_mode : 1;
    uint32_t pad2 : 12;
  } mac_cfg;

  // Word 2 (0x4908)
  struct {
    uint32_t matrix_vector_bias : 16;
    uint32_t pad0 : 16;
  } matrix_bias;

  // Word 3 (0x490C)
  struct {
    uint32_t acc_bias : 21;
    uint32_t pad0 : 11;
  } acc_bias;

  // Word 4 (0x4910)
  struct {
    uint32_t post_scale : 21;
    uint32_t pad0 : 11;
  } post_scale;

  uint32_t raw_4914; // Word 5
  uint32_t raw_4918; // Word 6
  uint32_t raw_491c; // Word 7
  uint32_t raw_4920; // Word 8

} ane_m4_ne_t;

// [0x4500] Planar Engine (PE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4500)
  struct {
    uint32_t op : 6;
    uint32_t pad0 : 13;
    uint32_t en : 1;
    uint32_t pad1 : 12;
  } op_mode;

  uint32_t bias_1;   // Word 1 (0x4504)
  uint32_t scale_1;  // Word 2 (0x4508)
  uint32_t raw_450c; // Word 3 (0x450c)
  uint32_t bias_2;   // Word 4 (0x4510)
  uint32_t scale_2;  // Word 5 (0x4514)
} ane_m4_pe_t;

// [0x4100] L2 Cache Control Block (M4 specific mapping)
typedef struct {
  uint32_t l2cfg;   // Word 0
  uint32_t src1cfg; // Word 1
  uint32_t src2cfg; // Word 2
  uint32_t pad0;    // Word 3

  // Dense 17-bit packed tensor block (Bits 4:20)
  struct {
    uint32_t base : 17;
    uint32_t pad0 : 15;
    uint32_t channel_stride : 17;
    uint32_t pad1 : 15;
    uint32_t row_stride : 17;
    uint32_t pad2 : 15;
    uint32_t depth_stride : 17;
    uint32_t pad3 : 15;
    uint32_t group_stride : 17;
    uint32_t pad4 : 15;
  } src1; // Words 4-8

  struct {
    uint32_t base : 17;
    uint32_t pad0 : 15;
    uint32_t channel_stride : 17;
    uint32_t pad1 : 15;
    uint32_t row_stride : 17;
    uint32_t pad2 : 15;
    uint32_t depth_stride : 17;
    uint32_t pad3 : 15;
    uint32_t group_stride : 17;
    uint32_t pad4 : 15;
  } src2; // Words 9-13

  struct {
    uint32_t base : 17;
    uint32_t pad0 : 15;
    uint32_t channel_stride : 17;
    uint32_t pad1 : 15;
    uint32_t depth_stride : 17;
    uint32_t pad2 : 15;
    uint32_t group_stride : 17;
    uint32_t pad3 : 15;
  } srcidx; // Words 14-17 (No RowStride)

  uint32_t resultcfg; // Word 18

  struct {
    uint32_t base : 17;
    uint32_t pad0 : 15;
    uint32_t channel_stride : 17;
    uint32_t pad1 : 15;
    uint32_t row_stride : 17;
    uint32_t pad2 : 15;
    uint32_t depth_stride : 17;
    uint32_t pad3 : 15;
    uint32_t group_stride : 17;
    uint32_t pad4 : 15;
  } result; // Words 19-23

} ane_m4_l2_t;

// [0x0000] M1 Common Registers
typedef struct {
  // 0x0000 Common.InDim
  struct {
    uint32_t w_in : 15;
    uint32_t pad0 : 1;
    uint32_t h_in : 15;
    uint32_t pad1 : 1;
  } indim;
  uint32_t pad2; // 0x12C

  // 0x130 Common.ChCfg
  struct {
    uint32_t infmt : 2;
    uint32_t pad0 : 2;
    uint32_t outfmt : 2;
    uint32_t pad1 : 26;
  } chcfg;

  // 0x134 Common.Cin
  struct {
    uint32_t c_in : 17;
    uint32_t pad0 : 15;
  } cin;

  // 0x138 Common.Cout
  struct {
    uint32_t c_out : 17;
    uint32_t pad0 : 15;
  } cout;

  // 0x13c Common.OutDim
  struct {
    uint32_t w_out : 15;
    uint32_t pad0 : 1;
    uint32_t h_out : 15;
    uint32_t pad1 : 1;
  } outdim;

  uint32_t pad3; // 0x140

  // 0x144 Common.ConvCfg
  struct {
    uint32_t kw : 5;
    uint32_t kh : 5;
    uint32_t ocg_size : 3;
    uint32_t sx : 2;
    uint32_t sy : 2;
    uint32_t px : 5;
    uint32_t py : 5;
    uint32_t pad0 : 1;
    uint32_t ox : 2;
    uint32_t oy : 2;
  } convcfg;

  uint32_t pad4; // 0x148

  // 0x14c Common.GroupConvCfg
  struct {
    uint32_t num_groups : 13;
    uint32_t pad0 : 1;
    uint32_t unicast_en : 1;
    uint32_t elem_mult_mode : 1;
    uint32_t unicast_cin : 16;
  } groupcfg;

  // 0x150 Common.TileCfg
  struct {
    uint32_t tile_height : 16;
    uint32_t pad0 : 16;
  } tilecfg;

  uint32_t pad5[2]; // 0x154-0x158

  // 0x15c Common.Cfg
  struct {
    uint32_t pad0 : 2;
    uint32_t small_src_mode : 1;
    uint32_t pad1 : 5;
    uint32_t sh_pref : 3;
    uint32_t pad2 : 1;
    uint32_t sh_min : 3;
    uint32_t pad3 : 1;
    uint32_t sh_max : 3;
    uint32_t active_ne : 3;
    uint32_t ctx_switch_in : 1;
    uint32_t pad4 : 1;
    uint32_t ctx_switch_out : 1;
    uint32_t pad5 : 1;
    uint32_t acc_db_buf_en : 1;
    uint32_t pad6 : 5;
  } cfg;

  struct {
    uint32_t tid : 16;
    uint32_t task_q : 4;
    uint32_t task_nid : 8;
    uint32_t pad0 : 4;
  } task_info; // 0x160

  struct {
    uint32_t category : 4;
    uint32_t pad0 : 28;
  } dpe; // 0x164

} __attribute__((packed)) ane_m1_common_t;

// [0x1e0] L2
typedef struct {
  struct {
    uint32_t input_relu : 1;
    uint32_t padding_mode : 2;
    uint32_t pad0 : 29;
  } l2cfg; // 0x1E0

  struct {
    uint32_t type : 2;
    uint32_t dep : 2;
    uint32_t alias_conv_src : 1;
    uint32_t alias_conv_rslt : 1;
    uint32_t fmt : 2;
    uint32_t interleave : 4;
    uint32_t cmpv : 4;
    uint32_t offch : 3;
    uint32_t pad0 : 1;
    uint32_t alias_planar_src : 1;
    uint32_t pad1 : 1;
    uint32_t alias_planar_rslt : 1;
    uint32_t pad2 : 9;
  } scfg; // 0x1E4

  struct {
    uint32_t pad0 : 4;
    uint32_t addr : 17;
    uint32_t pad1 : 11;
  } srcbase; // 0x1E8

  struct {
    uint32_t pad0 : 4;
    uint32_t stride : 17;
    uint32_t pad1 : 11;
  } src_chan_stride; // 0x1EC

  struct {
    uint32_t pad0 : 4;
    uint32_t stride : 17;
    uint32_t pad1 : 11;
  } src_row_stride; // 0x1F0

  uint32_t pad3[(0x210 - 0x1F4) / 4];

  struct {
    uint32_t type : 2;
    uint32_t bfrmode : 2;
    uint32_t alias_conv_src : 1;
    uint32_t alias_conv_rslt : 1;
    uint32_t fmt : 2;
    uint32_t interleave : 4;
    uint32_t cmpv : 4;
    uint32_t offch : 3;
    uint32_t pad0 : 1;
    uint32_t alias_planar_src : 1;
    uint32_t pad1 : 1;
    uint32_t alias_planar_rslt : 1;
    uint32_t pad2 : 9;
  } rcfg; // 0x210
} __attribute__((packed)) ane_m1_l2_t;

// [0xC800] Neural Engine (NE) Block
typedef struct {
  // Word 0 (0xC800)
  struct {
    uint32_t kernel_fmt : 2;
    uint32_t palettized_en : 1;
    uint32_t pad0 : 1;
    uint32_t palettized_bits : 4;
    uint32_t sparse_fmt : 1;
    uint32_t pad1 : 1;
    uint32_t group_kernel_reuse : 1;
    uint32_t pad2 : 21;
  } kernel_cfg;

  // Word 1 (0xC804)
  struct {
    uint32_t op_mode : 4;
    uint32_t kernel_mode : 1;
    uint32_t bias_mode : 1;
    uint32_t pad0 : 1;
    uint32_t matrix_bias_en : 1;
    uint32_t pad1 : 1;
    uint32_t binary_point : 4;
    uint32_t pad2 : 1;
    uint32_t post_scale_mode : 1;
    uint32_t pad3 : 1;
    uint32_t non_linear_mode : 2;
    uint32_t pad4 : 14;
  } mac_cfg;

  // Word 2 (0x248)
  struct {
    uint32_t matrix_vector_bias : 16;
    uint32_t pad0 : 16;
  } matrix_vector_bias;

  // Word 3 (0x24c)
  struct {
    uint32_t acc_bias : 16;
    uint32_t acc_bias_shift : 5;
    uint32_t pad0 : 11;
  } acc_bias;

  // Word 4 (0x250)
  struct {
    uint32_t post_scale : 16;
    uint32_t post_scale_right_shift : 5;
    uint32_t pad0 : 11;
  } post_scale;

} __attribute__((packed)) ane_m1_ne_t;

// [0x16c] TileDMA Source Block (M1 mapping)
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t cache_hint_reuse : 4;
    uint32_t cache_hint_noreuse : 4;
    uint32_t dep_mode : 4;
    uint32_t pad1 : 12;
  } src_dma_config; // 0x16c

  uint32_t pad2; // 0x170

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } base_addr; // 0x174

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } row_stride; // 0x178

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } plane_stride; // 0x17c

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } depth_stride; // 0x180

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } group_stride; // 0x184

  uint32_t pad3[(0x1a4 - 0x188) / 4];

  struct {
    uint32_t fmt_mode : 2;
    uint32_t pad0 : 2;
    uint32_t truncate : 2;
    uint32_t pad1 : 2;
    uint32_t shift : 1;
    uint32_t pad2 : 3;
    uint32_t mem_fmt : 2;
    uint32_t pad3 : 2;
    uint32_t offset_ch : 3;
    uint32_t pad4 : 5;
    uint32_t interleave : 4;
    uint32_t cmp_vec : 4;
  } fmt; // 0x1a4

  uint32_t pad4[(0x1bc - 0x1a8) / 4];

  uint32_t pixel_offset[4]; // 0x1bc - 0x1c8

  uint32_t pad5[(0x1f8 - 0x1cc) / 4];

} __attribute__((packed)) ane_m1_tiledma_src_t;

// [0x8800] Planar Engine (PE) Block
// Corresponds to range 0x22c-0x238 in ane_hwx.tex
typedef struct {
  struct {
    uint32_t pad0 : 1;
    uint32_t enable : 1;
    uint32_t op_mode : 3;
    uint32_t relu_en : 1;
    uint32_t cond : 1;
    uint32_t pad1 : 9;
    uint32_t first_source : 1;
    uint32_t pad2 : 1;
    uint32_t second_source : 2;
    uint32_t pad3 : 12;
  } cfg; // 0x8800 (offset 0x22c in tex)

  struct {
    uint16_t bias;
    uint16_t scale;
  } bias_scale; // 0x8804 (offset 0x230 in tex)

  struct {
    uint16_t pre_scale;
    uint16_t pad0;
  } pre_scale; // 0x8808 (offset 0x234 in tex)

  struct {
    uint32_t final_scale;
  } final_scale; // 0x880c (offset 0x238 in tex)
} __attribute__((packed)) ane_m1_pe_t;

// [0xc0] KernelDMA Config block
typedef struct {
  // to be added
  uint32_t pad0;
  uint32_t pad1;

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 24;
  } coeff_dma_config[16]; // 0xc0 - 0xfc

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } coeff_base_addr[16]; // 0x100 - 0x13c

  uint32_t coeff_bfr_size[16]; // 0x140 - 0x17c
} __attribute__((packed)) ane_m1_kerneldma_t;

// [0x258] TileDMA Destination Block
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 14;
    uint32_t pad2 : 2;
    uint32_t l2bfrmode : 1;
    uint32_t bypass_eow : 1;
    uint32_t pad3 : 4;
  } dst_dma_config; // 0x258

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } base_addr; // 0x25c

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } row_stride; // 0x260

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } plane_stride; // 0x264

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } depth_stride; // 0x268

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } group_stride; // 0x26c

  struct {
    uint32_t fmt_mode : 2;
    uint32_t pad0 : 2;
    uint32_t truncate : 2;
    uint32_t pad1 : 2;
    uint32_t shift : 1;
    uint32_t pad2 : 3;
    uint32_t mem_fmt : 2;
    uint32_t pad3 : 2;
    uint32_t offset_ch : 3;
    uint32_t pad4 : 1;
    uint32_t zero_pad_last : 1;
    uint32_t zero_pad_first : 1;
    uint32_t cmp_vec_fill : 1;
    uint32_t pad5 : 1;
    uint32_t interleave : 4;
    uint32_t cmp_vec : 4;
  } fmt; // 0x270

} __attribute__((packed)) ane_m1_tiledma_dst_t;

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

void decode_ane_td(const uint8_t *ptr, size_t total_len) {
  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_td_header_t) <= total_len) {
    const ane_td_header_t *td = (const ane_td_header_t *)(ptr + offset);
    if (td->next_pointer == 0 && td->exe_cycles == 0 && td->log_events == 0) {
      break; // Hit zero padding
    }

    printf("      [ANE Task %d @ 0x%x]\n", task_idx++, offset);
    printf("        TID: 0x%04x NID: 0x%02x LNID: %d EON: %d\n", td->tid,
           td->nid, td->lnid_eon & 1, (td->lnid_eon >> 1) & 1);
    printf("        ExeCycles: %u NextSize: %u\n", td->exe_cycles,
           td->next_size_pad & 0x1FF);
    printf("        Flags: 0x%08x NextPointer: 0x%08x\n", td->flags,
           td->next_pointer);

    uint32_t reg_values[0x20000] = {0};
    bool reg_valid[0x20000] = {false};

    // Modern Stream Parse
    if (offset + sizeof(ane_td_header_t) <= total_len) {
      const uint32_t *words = (const uint32_t *)(td + 1);
      uint32_t max_payload_bytes =
          (total_len > offset + sizeof(ane_td_header_t))
              ? (uint32_t)(total_len - offset - sizeof(ane_td_header_t))
              : 0;
      uint32_t num_words = max_payload_bytes / 4;

      if (td->next_pointer > offset + sizeof(ane_td_header_t)) {
        uint32_t td_words =
            (td->next_pointer - offset - sizeof(ane_td_header_t)) / 4;
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
          if (addr + i < 0x20000) {
            reg_values[addr + i] = words[w_idx];
            reg_valid[addr + i] = true;
          }
          w_idx++;
        }
      }
    }

    if (offset + sizeof(ane_td_header_t) <= total_len) {
      printf("        --- HW Block Register State ---\n");
      // Decode Common Block (0x0000)
      printf("        --- Common (0x0000) ---\n");
      const ane_m1_common_t *common = (const ane_m1_common_t *)&reg_values[0];

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
             common->cfg.active_ne, common->cfg.small_src_mode,
             common->cfg.sh_pref, common->cfg.sh_min, common->cfg.sh_max,
             common->cfg.acc_db_buf_en);

      printf("        TaskInfo: TID=0x%04x Q=%u NID=0x%02x\n",
             common->task_info.tid, common->task_info.task_q,
             common->task_info.task_nid);

      // Decode L2 Block (0x4800)
      printf("        --- L2 (0x4800) ---\n");
      const ane_m1_l2_t *l2 = (const ane_m1_l2_t *)&reg_values[0x4800 / 4];
      printf("        L2Cfg: InputRelu=%d PaddingMode=%u\n",
             l2->l2cfg.input_relu, l2->l2cfg.padding_mode);
      printf("        L2 SourceCfg: Type=%u Dep=%u Fmt=%u Intrlv=%u CmpV=%u "
             "OffCh=%u\n",
             l2->scfg.type, l2->scfg.dep, l2->scfg.fmt, l2->scfg.interleave,
             l2->scfg.cmpv, l2->scfg.offch);
      printf(
          "        L2 Src1: Base=0x%05x ChanStride=0x%05x RowStride=0x%05x\n",
          l2->srcbase.addr, l2->src_chan_stride.stride,
          l2->src_row_stride.stride);

      printf("        L2 ResultCfg: Type=%u Bfr=%u Fmt=%u Intrlv=%u CmpV=%u "
             "OffCh=%u\n",
             l2->rcfg.type, l2->rcfg.bfrmode, l2->rcfg.fmt, l2->rcfg.interleave,
             l2->rcfg.cmpv, l2->rcfg.offch);

      // Decode NE Block (0xC800)
      printf("        --- Neural Engine (0xC800) ---\n");
      const ane_m1_ne_t *ne = (const ane_m1_ne_t *)&reg_values[0xC800 / 4];
      printf("        NE MACCfg: OpMode=%u NLMode=%u KernelMode=%d BiasMode=%d "
             "BinaryPoint=%u\n",
             ne->mac_cfg.op_mode, ne->mac_cfg.non_linear_mode,
             ne->mac_cfg.kernel_mode, ne->mac_cfg.bias_mode,
             ne->mac_cfg.binary_point);
      printf("        NE KernelCfg: Fmt=%u PalettizedEn=%d PalettizeBits=%u "
             "SparseFmt=%d GroupKernelReuse=%d\n",
             ne->kernel_cfg.kernel_fmt, ne->kernel_cfg.palettized_en,
             ne->kernel_cfg.palettized_bits, ne->kernel_cfg.sparse_fmt,
             ne->kernel_cfg.group_kernel_reuse);
      printf("        NE MatrixVectorBias: 0x%04x\n",
             ne->matrix_vector_bias.matrix_vector_bias);
      printf("        NE AccBias: 0x%04x Shift=%u\n", ne->acc_bias.acc_bias,
             ne->acc_bias.acc_bias_shift);
      printf("        NE PostScale: 0x%04x RightShift=%u\n",
             ne->post_scale.post_scale, ne->post_scale.post_scale_right_shift);

      // Decode TileDMA Source (0x13800)
      const ane_m1_tiledma_src_t *tsrc =
          (const ane_m1_tiledma_src_t *)&reg_values[0x13800 / 4];
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

      // Decode PE Block (0x8800)
      const ane_m1_pe_t *pe = (const ane_m1_pe_t *)&reg_values[0x8800 / 4];
      if (reg_valid[0x8800 / 4]) {
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

      // Decode KernelDMA (0x1F800)
      const ane_m1_kerneldma_t *k =
          (const ane_m1_kerneldma_t *)&reg_values[0x1F800 / 4];
      printf("        --- KernelDMA (0x1F800) ---\n");
      for (int i = 0; i < 16; i++) {
        if (k->coeff_dma_config[i].en) {
          printf(
              "        Coeff[%d]: En=%d CacheHint=%u Base=0x%08x Size=0x%08x\n",
              i, k->coeff_dma_config[i].en, k->coeff_dma_config[i].cache_hint,
              k->coeff_base_addr[i].addr, k->coeff_bfr_size[i]);
        }
      }

      // Decode TileDMA Destination (0x17800)
      const ane_m1_tiledma_dst_t *tdst =
          (const ane_m1_tiledma_dst_t *)&reg_values[0x17800 / 4];
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
             tdst->fmt.zero_pad_first, tdst->fmt.cmp_vec_fill,
             tdst->fmt.interleave, tdst->fmt.cmp_vec);

      if (1) {
        struct {
          const char *name;
          uint32_t startWord;
        } blocks[] = {
            {"[0x00000] Common Module", 0x00000},
            {"[0x04800] L2 Cache Control", 0x04800},
            {"[0x08800] Planar Engine (PE)", 0x08800},
            {"[0x0C800] Neural Engine Core (NE)", 0x0C800},
            {"[0x13800] TileDMA Source", 0x13800},
            {"[0x17800] TileDMA Destination", 0x17800},
            {"[0x1F800] KernelDMA Source", 0x1F800},
        };

        for (int b = 0; b < 7; b++) {
          bool printed_header = false;
          uint32_t word_start = blocks[b].startWord / 4;
          uint32_t word_end = word_start + 0x100; // Look ahead 0x400 bytes

          for (uint32_t r = word_start; r < word_end; r++) {
            if (reg_valid[r]) {
              if (!printed_header) {
                printf("        %s:\n", blocks[b].name);
                printed_header = true;
              }
              uint32_t addr = r * 4;
              printf("          0x%05x: 0x%08x\n", addr, reg_values[r]);
            }
          }
        }
      }
    }

    if (td->next_pointer == 0 || td->next_pointer <= offset)
      break;
    offset = td->next_pointer;
  }
}

void decode_ane_td_m4(const uint8_t *ptr, size_t total_len) {
  printf("\n[M4] Detected M4 HWX Format (CPU Subtype 0x7)\n");

  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_m4_header_t) <= total_len) {
    const ane_m4_header_t *m4h = (const ane_m4_header_t *)(ptr + offset);

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

    uint32_t reg_values[0x8000] = {0};
    bool reg_valid[0x8000] = {false};

    // Phase 4: Verbose Register Logging
    const uint32_t *words = (const uint32_t *)(ptr + offset);
    int num_words = size_bytes / 4;
    int i = sizeof(ane_m4_header_t) / 4;

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
          if (current_addr < 0x8000) {
            reg_values[current_addr] = words[i];
            reg_valid[current_addr] = true;
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
          if (current_addr < 0x8000) {
            reg_values[current_addr] = words[i];
            reg_valid[current_addr] = true;
          }
          i++;
        }

        // Then follow the registers indicated by the 16-bit mask
        for (int bit = 0; bit < 16 && i < num_words; bit++) {
          if ((mask >> bit) & 1) {
            uint32_t current_addr = word_addr + bit + 1;
            if (current_addr < 0x8000) {
              reg_values[current_addr] = words[i];
              reg_valid[current_addr] = true;
            }
            i++;
          }
        }
      }
    }
    printf("        Stream Parse: OK (End index %d/%d)\n", i, num_words);

    // Decode Common Registers from Map M4 Style
    ane_m4_common_t common;
    bool has_common = false;
    for (int j = 0; j < 23; j++) {
      if (reg_valid[j]) {
        has_common = true;
        ((uint32_t *)&common)[j] = reg_values[j];
      } else {
        ((uint32_t *)&common)[j] = 0;
      }
    }

    if (has_common) {
      if (reg_valid[9]) {
        printf("        Batch     : B=%u\n", common.group_cfg.num_groups);
      }
      if (reg_valid[1] || reg_valid[2] || reg_valid[3] || reg_valid[4]) {
        printf("        InDim     : W=%u H=%u C=%u D=%u\n", common.win.w_in,
               common.hin.h_in, common.cin.c_in, common.din.d_in);
      }
      if (reg_valid[5] || reg_valid[6] || reg_valid[7] || reg_valid[8]) {
        printf("        OutDim    : W=%u H=%u C=%u D=%u\n", common.wout.w_out,
               common.hout.h_out, common.cout.c_out, common.dout.d_out);
      }

      if (reg_valid[0]) {
        const char *infmt_name = get_ch_fmt_name(common.ch_cfg.infmt);
        const char *outfmt_name = get_ch_fmt_name(common.ch_cfg.outfmt);
        printf("        ChCfg     : In=%s Out=%s\n", infmt_name, outfmt_name);
      }

      if (reg_valid[10]) {
        printf("        ConvCfg0  : K=%ux%u S=%ux%u P=%ux%u O=%ux%u\n",
               common.conv_cfg_0.kw, common.conv_cfg_0.kh, common.conv_cfg_0.sx,
               common.conv_cfg_0.sy, common.conv_cfg_0.px, common.conv_cfg_0.py,
               common.conv_cfg_0.ox, common.conv_cfg_0.oy);
      }

      if (reg_valid[13]) {
        printf("        TileHeight: %u\n", common.tile_height.height);
      }

      if (reg_valid[17]) {
        printf("        PatchDim  : %ux%u\n", common.patch_dim.w,
               common.patch_dim.h);
      }

      if (reg_valid[11]) {
        printf("        ConvCfg3D : 0x%08x\n", common.conv_cfg_3d);
      }

      if (reg_valid[12]) {
        printf("        UnicastCfg: En=%d Cin=%u\n",
               common.unicast_cfg.unicast_en, common.unicast_cfg.unicast_cin);
      }

      if (reg_valid[14]) {
        printf("        TileOverlap: Overlap=%u PadTop=%u PadBottom=%u\n",
               common.tile_overlap.overlap, common.tile_overlap.pad_top,
               common.tile_overlap.pad_bottom);
      }

      if (reg_valid[15]) {
        printf("        MacCfg    : TaskType=%u ActiveNE=%u SmallSrcMode=%u "
               "L2Barrier=%u OutTrans=%u\n",
               common.maccfg.task_type, common.maccfg.active_ne,
               common.maccfg.small_src_mode, common.maccfg.l2_barrier,
               common.maccfg.out_trans);
      }
      if (reg_valid[16]) {
        printf("        ConvCfg1  : OCGSize=%u\n", common.conv_cfg_1.ocg_size);
      }

      if (reg_valid[18]) {
        printf("        PERouting : S1WB=%d S1HB=%d S1DB=%d S1CB=%d S2WB=%d "
               "S2HB=%d S2DB=%d S2CB=%d S1T=%d S2T=%d OT=%d\n",
               common.pe_routing.src1_w_bcast, common.pe_routing.src1_h_bcast,
               common.pe_routing.src1_d_bcast, common.pe_routing.src1_c_bcast,
               common.pe_routing.src2_w_bcast, common.pe_routing.src2_h_bcast,
               common.pe_routing.src2_d_bcast, common.pe_routing.src2_c_bcast,
               common.pe_routing.src1_trans, common.pe_routing.src2_trans,
               common.pe_routing.out_trans);
      }

      if (reg_valid[19]) {
        printf("        NID       : 0x%08x\n", common.nid);
      }

      if (reg_valid[20]) {
        printf("        DPE       : Cat=%u\n", common.dpe.category);
      }

      if (reg_valid[21]) {
        printf("        Val21     : 0x%08x\n", common.val_21);
      }

      if (reg_valid[22]) {
        printf("        Val22     : 0x%08x\n", common.val_22);
      }
    }

    // Decode 0x4900 NE Block
    bool ne_has_valid = false;
    for (int i = 0x4900 / 4; i < 0x4900 / 4 + 32; i++) {
      if (reg_valid[i])
        ne_has_valid = true;
    }

    if (ne_has_valid) {
      ane_m4_ne_t ne = *(ane_m4_ne_t *)&reg_values[0x4900 / 4];
      printf("        --- Neural Engine Config ---\n");

      if (reg_valid[0x4900 / 4]) {
        printf("        KernelCfg: Fmt=%s Palettized=%d (%dbit) SparseFmt=%d "
               "AsymQuant=%d\n",
               get_ch_fmt_name(ne.kernel_cfg.kernel_fmt),
               ne.kernel_cfg.palettized_en, ne.kernel_cfg.palettized_bits,
               ne.kernel_cfg.sparse_fmt, ne.kernel_cfg.asym_quant_en);
      }

      if (reg_valid[0x4904 / 4]) {
        printf(
            "        MACCfg: OpMode=%d KernelMode=%d BiasEn=%d Passthrough=%d "
            "MVBiasEn=%d BinaryPoint=%u PostScaleEn=%d NonLinear=%d\n",
            ne.mac_cfg.op_mode, ne.mac_cfg.kernel_mode, ne.mac_cfg.ne_bias_en,
            ne.mac_cfg.passthrough_en, ne.mac_cfg.matrix_bias_en,
            ne.mac_cfg.binary_point, ne.mac_cfg.post_scale_en,
            ne.mac_cfg.non_linear_mode);
      }

      if (reg_valid[0x4908 / 4]) {
        printf("        MatrixBias: 0x%04x\n",
               ne.matrix_bias.matrix_vector_bias);
      }

      if (reg_valid[0x490c / 4]) {
        printf("        AccBias: 0x%06x\n", ne.acc_bias.acc_bias);
      }

      if (reg_valid[0x4910 / 4]) {
        printf("        PostScale: %u\n", ne.post_scale.post_scale);
      }

      if (reg_valid[0x4920 / 4]) {
        printf("        Raw[0x4920]: 0x%08x\n", ne.raw_4920);
      }
    }

    // Decode 0x4500 PE Block
    bool pe_has_valid = false;
    for (int i = 0x4500 / 4; i < 0x4500 / 4 + 25; i++) {
      if (reg_valid[i])
        pe_has_valid = true;
    }

    if (pe_has_valid) {
      ane_m4_pe_t pe = *(ane_m4_pe_t *)&reg_values[0x4500 / 4];
      printf("        --- Planar Engine Config ---\n");

      if (reg_valid[0x4500 / 4]) {
        printf("        PEOpMode: Op=%d En=%d\n", pe.op_mode.op, pe.op_mode.en);
      }
      if (reg_valid[0x4504 / 4]) {
        printf("        PEBias1: 0x%08x\n", pe.bias_1);
      }
      if (reg_valid[0x4508 / 4]) {
        printf("        PEScale1: 0x%08x\n", pe.scale_1);
      }
      if (reg_valid[0x4510 / 4]) {
        printf("        PEBias2: 0x%08x\n", pe.bias_2);
      }
      if (reg_valid[0x4514 / 4]) {
        printf("        PEScale2: 0x%08x\n", pe.scale_2);
      }
    }

    // Decode 0x4100 L2 Block
    bool l2_has_valid = false;
    for (int i = 0x4100 / 4; i < 0x4100 / 4 + 32; i++) {
      if (reg_valid[i])
        l2_has_valid = true;
    }

    if (l2_has_valid) {
      ane_m4_l2_t l2 = *(ane_m4_l2_t *)&reg_values[0x4100 / 4];
      printf("        --- L2 Cache Control ---\n");

      if (reg_valid[0x4110 / 4]) {
        printf("        Src1 : BaseAddr=0x%05x PlaneStride=0x%05x "
               "RowStride=0x%05x DepthStride=0x%05x GroupStride=0x%05x\n",
               l2.src1.base, l2.src1.channel_stride, l2.src1.row_stride,
               l2.src1.depth_stride, l2.src1.group_stride);
      }
      if (reg_valid[0x4124 / 4]) {
        printf("        Src2 : BaseAddr=0x%05x PlaneStride=0x%05x "
               "RowStride=0x%05x DepthStride=0x%05x GroupStride=0x%05x\n",
               l2.src2.base, l2.src2.channel_stride, l2.src2.row_stride,
               l2.src2.depth_stride, l2.src2.group_stride);
      }
      if (reg_valid[0x4138 / 4]) {
        printf("        SrcIdx: BaseAddr=0x%05x PlaneStride=0x%05x "
               "DepthStride=0x%05x GroupStride=0x%05x\n",
               l2.srcidx.base, l2.srcidx.channel_stride, l2.srcidx.depth_stride,
               l2.srcidx.group_stride);
      }
      if (reg_valid[0x414c / 4]) {
        printf("        Result: BaseAddr=0x%05x PlaneStride=0x%05x "
               "RowStride=0x%05x DepthStride=0x%05x GroupStride=0x%05x\n",
               l2.result.base, l2.result.channel_stride, l2.result.row_stride,
               l2.result.depth_stride, l2.result.group_stride);
      }
    }

    // Decode 0x4D00 TileDMA Source
    bool src_has_valid = false;
    for (int i = 0x4d00 / 4; i < 0x4d00 / 4 + 64; i++) {
      if (reg_valid[i])
        src_has_valid = true;
    }
    if (src_has_valid) {
      ane_m4_tiledma_src_t *src =
          (ane_m4_tiledma_src_t *)&reg_values[0x4d00 / 4];
      printf("        --- TileDMA Source (0x4D00) ---\n");
      if (reg_valid[0x4d00 / 4]) {
        printf("        Src1DMAConfig: En=%d CacheHint=%u DepMode=%u\n",
               src->src1cfg.en, src->src1cfg.cache_hint, src->src1cfg.dep_mode);
      }
      if (reg_valid[0x4d18 / 4]) {
        printf("        Src1Strides: RowStride=0x%08x PlaneStride=0x%08x "
               "DepthStride=0x%08x GroupStride=0x%08x\n",
               src->src1rows, src->src1chans, src->src1depths, src->src1groups);
      }
    }

    // Decode 0x5100 TileDMA Destination
    bool dst_has_valid = false;
    for (int i = 0x5100 / 4; i < 0x5100 / 4 + 32; i++) {
      if (reg_valid[i])
        dst_has_valid = true;
    }
    if (dst_has_valid) {
      ane_m4_tiledma_dst_t *dst =
          (ane_m4_tiledma_dst_t *)&reg_values[0x5100 / 4];
      printf("        --- TileDMA Destination (0x5100) ---\n");
      if (reg_valid[0x5100 / 4]) {
        printf("        DstDMAConfig: En=%d CacheHint=%u\n", dst->dstcfg.en,
               dst->dstcfg.cache_hint);
      }
      if (reg_valid[0x5110 / 4]) {
        printf("        DstStrides: RowStride=0x%08x PlaneStride=0x%08x "
               "DepthStride=0x%08x GroupStride=0x%08x\n",
               dst->dstrows, dst->dstchans, dst->dstdepths, dst->dstgroups);
      }
    }

    // Decode 0x5500 KernelDMA Source
    bool kernel_has_valid = false;
    for (int i = 0x5500 / 4; i < 0x5500 / 4 + 100; i++) {
      if (reg_valid[i])
        kernel_has_valid = true;
    }
    if (kernel_has_valid) {
      ane_m4_kerneldma_src_t *k =
          (ane_m4_kerneldma_src_t *)&reg_values[0x5500 / 4];
      printf("        --- KernelDMA Source (0x5500) ---\n");
      for (int i = 0; i < 16; i++) {
        if (reg_valid[0x5520 / 4 + i] || reg_valid[0x5560 / 4 + i]) {
          printf("        Coeff[%d]: En=%d CacheHint=%u Tag=%u Base=0x%08x "
                 "Size=0x%08x\n",
                 i, k->coeff_cfg[i].en, k->coeff_cfg[i].cache_hint,
                 k->coeff_cfg[i].user_tag, k->coeff_base[i], k->coeff_size[i]);
        }
      }
      if (reg_valid[0x55e0 / 4]) {
        printf("        Bias: En=%d CacheHint=%u Tag=%u\n", k->bias_cfg.en,
               k->bias_cfg.cache_hint, k->bias_cfg.user_tag);
      }
      if (reg_valid[0x55f0 / 4]) {
        printf("        PostScale: En=%d CacheHint=%u Tag=%u\n",
               k->post_scale_cfg.en, k->post_scale_cfg.cache_hint,
               k->post_scale_cfg.user_tag);
      }
      if (reg_valid[0x5600 / 4]) {
        printf("        Palette: En=%d CacheHint=%u Tag=%u\n",
               k->palette_cfg.en, k->palette_cfg.cache_hint,
               k->palette_cfg.user_tag);
      }
      if (reg_valid[0x5610 / 4]) {
        printf("        NonLinear: En=%d CacheHint=%u Tag=%u\n",
               k->non_linear_cfg.en, k->non_linear_cfg.cache_hint,
               k->non_linear_cfg.user_tag);
      }
    }

    if (1) { // Dump key M4 registers mapped to discrete blocks
      printf(
          "        --- HW Block Register State ---\n"); // Decode 0x5900
                                                        // CacheDMA & Telemetry
      bool cdma_has_valid = false;
      for (int i = 0x5900 / 4; i < 0x5900 / 4 + 13; i++) {
        if (reg_valid[i])
          cdma_has_valid = true;
      }
      if (cdma_has_valid) {
        ane_m4_cachedma_t cdma = *(ane_m4_cachedma_t *)&reg_values[0x5900 / 4];
        printf("        --- CacheDMA & Telemetry (0x5900) ---\n");
        if (reg_valid[0x5900 / 4]) {
          printf("        Config: WaitSync=%d PostSync=%d EarlyTermEn=0x%x "
                 "FootprintThresh=0x%04x\n",
                 (cdma.config >> 3) & 1, (cdma.config >> 2) & 1,
                 (cdma.config >> 4) & 7, (cdma.config >> 16));
        }
        if (reg_valid[0x5904 / 4]) {
          printf("        Pre0: BWLimit=%u Sieve2=%u TelemetryAgeOut=%u\n",
                 cdma.pre0 & 0x3ff, (cdma.pre0 >> 16) & 0xf,
                 (cdma.pre0 >> 20) & 0xf);
        }
        if (reg_valid[0x5908 / 4]) {
          printf("        Pre1: Sieve1=%u\n", cdma.pre1 & 0x3fff);
        }
        if (reg_valid[0x5918 / 4]) {
          printf("        Pre2_Term: DSIDSize_L=0x%04x EarlyTerm0=0x%04x\n",
                 cdma.pre2_term & 0xffff, cdma.pre2_term >> 16);
        }
        if (reg_valid[0x591c / 4]) {
          printf("        Pre3: Footprint2=0x%03x\n",
                 (cdma.pre3 >> 17) & 0x7ff);
        }
        if (reg_valid[0x5920 / 4]) {
          printf("        Term1_Low: EarlyTerm1=0x%04x\n",
                 cdma.term1_low >> 16);
        }
        if (reg_valid[0x5928 / 4]) {
          printf("        Term2_3: EarlyTerm2=0x%02x EarlyTerm3=0x%02x\n",
                 cdma.term2_3 & 0xff, (cdma.term2_3 >> 16) & 0xff);
        }
        if (reg_valid[0x592c / 4]) {
          printf("        BackOff: En=%d Delay=%u Min=%u Max=%u Scale=%u\n",
                 cdma.backoff & 1, (cdma.backoff >> 4) & 0xf,
                 (cdma.backoff >> 8) & 0xff, (cdma.backoff >> 16) & 0xff,
                 (cdma.backoff >> 24) & 0xff);
        }
      }

      struct {
        const char *name;
        uint32_t startAddr;
      } blocks[] = {
          {"[0x0000] Common Module", 0x0000},
          {"[0x4100] L2 Cache Control", 0x4100},
          {"[0x4500] Planar Engine (PE)", 0x4500},
          {"[0x4900] Neural Engine Core (NE)", 0x4900},
          {"[0x4D00] TileDMA Source", 0x4D00},
          {"[0x5100] TileDMA Destination", 0x5100},
          {"[0x5500] KernelDMA Source", 0x5500},
          {"[0x5900] CacheDMA & Telemetry", 0x5900},
      };

      for (int b = 0; b < 8; b++) {
        bool printed_header = false;
        uint32_t word_start = blocks[b].startAddr / 4;
        uint32_t word_end = word_start + 0x100; // Look ahead 0x400 bytes

        for (uint32_t r = word_start; r < word_end; r++) {
          if (reg_valid[r]) {
            if (!printed_header) {
              printf("        %s:\n", blocks[b].name);
              printed_header = true;
            }
            uint32_t addr = r * 4;
            const char *reg_name = get_m4_reg_name(addr);
            if (reg_name) {
              printf("          0x%04x: 0x%08x (%s)\n", addr, reg_values[r],
                     reg_name);
            } else {
              printf("          0x%04x: 0x%08x\n", addr, reg_values[r]);
            }
          }
        }
      }
    }

    if (offset + size_bytes > total_len)
      break;

    // Advance with 16-byte alignment
    uint32_t aligned_size = (size_bytes + 15) & ~15;
    offset += aligned_size;
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

void print_macho_headers(NSData *data, BOOL dump_all_symbols, BOOL dump_threads,
                         BOOL dump_hexdump) {
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
        const struct segment_command_64 *seg =
            (const struct segment_command_64 *)lc;
        printf("  Segment Name: %s\n", seg->segname);
        printf("  VM Addr: 0x%llx\n", seg->vmaddr);
        printf("  VM Size: 0x%llx\n", seg->vmsize);
        printf("  File Off: 0x%llx\n", seg->fileoff);
        printf("  File Size: 0x%llx\n", seg->filesize);
        printf("  Num Sections: %u\n", seg->nsects);

        const struct section_64 *sect =
            (const struct section_64 *)(data.bytes + offset +
                                        sizeof(struct segment_command_64));
        for (uint32_t j = 0; j < seg->nsects; j++) {
          if ((uintptr_t)(sect + 1) > (uintptr_t)(data.bytes + data.length))
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
              const uint8_t *section_ptr =
                  (const uint8_t *)data.bytes + sect->offset;
              size_t section_size = (size_t)sect->size;

              if (strcmp(sect->sectname, "__text") == 0 ||
                  strcmp(sect->sectname, "__TEXT") == 0) {
                if (header->cpusubtype == 0x7) {
                  decode_ane_td_m4(section_ptr, section_size);
                } else {
                  decode_ane_td(section_ptr, section_size);
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
    } else if (lc->cmd == LC_SYMTAB) {
      if (offset + sizeof(struct symtab_command) <= data.length) {
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
            if ((uintptr_t)(list + 1) > (uintptr_t)(data.bytes + data.length))
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
    } else if (lc->cmd == LC_THREAD || lc->cmd == LC_UNIXTHREAD) {
      if (dump_threads) {
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
      } else {
      }
    } else if (lc->cmd == LC_NOTE) {
      if (lc->cmdsize >= sizeof(struct note_command)) {
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
    } else if (lc->cmd == LC_ANE_MAPPED_REGION) {
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
    } else if (lc->cmd == LC_IDENT) {
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

    offset += lc->cmdsize;
  }
}

int main(int argc, char *const argv[]) {
  @autoreleasepool {
    int ch;
    BOOL dump_all = NO;
    BOOL dump_threads = NO;
    BOOL dump_hexdump = NO;

    while ((ch = getopt(argc, argv, "stx")) != -1) {
      switch (ch) {
      case 's':
        dump_all = YES;
        break;
      case 't':
        dump_threads = YES;
        break;
      case 'x':
        dump_hexdump = YES;
        break;
      case '?':
      default:
        printf("Usage: %s [-s] [-t] [-x] <path_to_hwx>\n", getprogname());
        return 1;
      }
    }
    argc -= optind;
    argv += optind;

    if (argc < 1) {
      printf("Usage: %s [-s] [-t] [-x] <path_to_hwx>\n", getprogname());
      return 1;
    }

    NSString *path = [NSString stringWithUTF8String:argv[0]];
    NSData *data = [NSData dataWithContentsOfFile:path];

    if (!data) {
      printf("Error reading file: %s\n", argv[0]);
      return 1;
    }

    print_macho_headers(data, dump_all, dump_threads, dump_hexdump);
  }
  return 0;
}
