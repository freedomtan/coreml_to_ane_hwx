#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/nlist.h>
#include <stdlib.h>
#include <unistd.h>

#define HWX_MAGIC 0xbeefface
#define LC_ANE_MAPPED_REGION 0x40

typedef struct __attribute__((packed)) {
  uint16_t tid;      // 0x000
  uint8_t nid;       // 0x002
  uint8_t lnid : 1;  // 0x003 bit 0
  uint8_t eon : 1;   // 0x003 bit 1
  uint8_t pad0 : 6;
  uint16_t exe_cycles;     // 0x004
  uint16_t next_size : 9;  // 0x006 bits 0-8
  uint16_t pad1 : 7;
  uint32_t log_events : 24;  // 0x008
  uint32_t pad2 : 8;
  uint32_t exceptions : 24;  // 0x00c
  uint32_t pad3 : 8;
  uint32_t debug_log_events : 24;  // 0x010
  uint32_t pad4 : 8;
  uint32_t debug_exceptions : 24;  // 0x014
  uint32_t pad5 : 8;
  struct {
    uint32_t tq_dis : 1;  // bit 0
    uint32_t pad0 : 1;
    uint32_t dst_loc : 1;  // bit 2
    uint32_t src_loc : 1;  // bit 3
    uint32_t pad1 : 3;
    uint32_t tde : 1;  // bit 7
    uint32_t pad2 : 2;
    uint32_t next_priority : 6;   // bits 10-15
    uint32_t tse : 1;             // bit 16
    uint32_t dpc : 1;             // bit 17
    uint32_t spc : 1;             // bit 18
    uint32_t tsr : 1;             // bit 19
    uint32_t spl : 1;             // bit 20
    uint32_t kpc : 1;             // bit 21
    uint32_t td_skip : 1;         // bit 22
    uint32_t disallow_abort : 1;  // bit 23
    uint32_t pad3 : 8;
  } flags;                // 0x018
  uint32_t next_pointer;  // 0x01c
  struct {
    uint32_t rbase0 : 5;
    uint32_t rbe0 : 1;
    uint32_t rbase1 : 5;
    uint32_t rbe1 : 1;
    uint32_t wbase : 5;
    uint32_t wbe : 1;
    uint32_t tbase : 5;
    uint32_t tbe : 1;
    uint32_t ene : 3;
    uint32_t pad : 5;
  } base_ene;  // 0x020
  struct {
    uint32_t kbase0 : 5;
    uint32_t kbe0 : 1;
    uint32_t kbase1 : 5;
    uint32_t kbe1 : 1;
    uint32_t kbase2 : 5;
    uint32_t kbe2 : 1;
    uint32_t kbase3 : 5;
    uint32_t kbe3 : 1;
    uint32_t pad : 8;
  } kbase;  // 0x024
} ane_td_header_h13_t;

typedef struct __attribute__((packed)) {
  uint16_t tid;              // 0x000
  uint32_t task_size : 11;   // 0x002 bits 0-10 (Header[0] bits 16-26)
  uint32_t pad0 : 5;         // 0x002 bits 11-15 (Header[0] bits 27-31)
  uint16_t exe_cycles;       // 0x004
  uint16_t pad1;             // 0x006
  uint32_t log_events : 24;  // 0x008
  uint32_t pad2 : 8;
  uint32_t exceptions : 24;  // 0x00c
  uint32_t pad3 : 8;
  uint32_t debug_log_events : 24;  // 0x010
  uint32_t pad4 : 8;
  uint32_t debug_exceptions : 24;  // 0x014
  uint32_t pad5 : 8;
  uint32_t live_outs;  // 0x018
  uint32_t tsr : 1;    // 0x01c bit 0
  uint32_t tde : 1;    // 0x01c bit 1
  uint32_t pad6 : 14;  // 0x01c bits 2-15
  uint32_t ene : 3;    // 0x01c bits 16-18
  uint32_t pad7 : 13;  // 0x01c bits 19-31
  uint16_t tdid;
  uint16_t pad8;
} ane_header_h16_t;

typedef struct __attribute__((packed)) {
  // Word 0 (0x000)
  struct {
    uint32_t infmt : 2;
    uint32_t pad0_0 : 2;
    uint32_t outfmt : 2;
    uint32_t pad0_1 : 2;
    uint32_t src2infmt : 2;
    uint32_t pad0_2 : 22;
  } ch_cfg;

  // Word 1-8
  uint32_t inwidth;      // Word 1
  uint32_t inheight;     // Word 2
  uint32_t inchannels;   // Word 3
  uint32_t indepth;      // Word 4
  uint32_t outwidth;     // Word 5
  uint32_t outheight;    // Word 6
  uint32_t outchannels;  // Word 7
  uint32_t outdepth;     // Word 8

  // Word 9 (0x024)
  uint32_t num_groups;

  // Word 10 (0x028)
  struct {
    uint32_t kw : 6;
    uint32_t kh : 6;
    uint32_t pad10_0 : 1;
    uint32_t sx : 2;
    uint32_t sy : 2;
    uint32_t pad_left : 5;
    uint32_t pad_top : 5;
    uint32_t pad10_1 : 1;
    uint32_t ox : 2;
    uint32_t oy : 2;
  } conv_cfg;

  // Word 11 (0x02C)
  uint32_t conv_cfg_3d;

  // Word 12 (0x030)
  struct {
    uint32_t unicast_en : 1;
    uint32_t pad0 : 3;
    uint32_t unicast_cin : 14;
    uint32_t pad1 : 14;
  } unicast_cfg;

  // Word 13 (0x034)
  uint32_t tile_height;

  // Word 14 (0x038)
  struct {
    uint32_t pad_bottom : 6;
    uint32_t pad_top : 6;
    uint32_t overlap : 14;
    uint32_t pad0 : 6;
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
  } lane_cfg;

  // Word 17 (0x044)
  struct {
    uint32_t patch_width : 4;
    uint32_t patch_height : 5;
    uint32_t pad0 : 23;
  } patch_cfg;

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

  uint32_t nid;     // 0x04C (Word 19)
  uint32_t dpe;     // 0x050 (Word 20)
  uint32_t val_21;  // 0x054 (Word 21)
  uint32_t val_22;  // 0x058 (Word 22)
} ane_common_h16_t;

const char *get_m1_reg_name(uint32_t addr) {
  // Common (0x0000)
  if (addr >= 0 && addr <= 0x40) {
    static const char *names[] = {
        "InDim", "pad0",         "ChCfg",   "Cin",  "Cout", "OutDim", "pad1",     "ConvCfg",
        "pad2",  "GroupConvCfg", "TileCfg", "pad3", "pad4", "Cfg",    "TaskInfo", "DPE"};
    if (addr / 4 < 16) return names[addr / 4];
  }
  // L2 (0x4800)
  if (addr >= 0x4800 && addr <= 0x483C) {
    uint32_t off = addr - 0x4800;
    static const char *names[] = {"L2Cfg",
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
    if (off / 4 < 16) return names[off / 4];
  }
  // PE (0x8800)
  if (addr >= 0x8800 && addr <= 0x880C) {
    uint32_t off = addr - 0x8800;
    static const char *names[] = {"Cfg", "BiasScale", "PreScale", "FinalScale"};
    if (off / 4 < 4) return names[off / 4];
  }
  // NE (0xC800)
  if (addr >= 0xC800 && addr <= 0xC810) {
    uint32_t off = addr - 0xC800;
    static const char *names[] = {"KernelCfg", "MACCfg", "MatrixVectorBias", "AccBias",
                                  "PostScale"};
    if (off / 4 < 5) return names[off / 4];
  }
  // TileDMA Src (0x13800)
  if (addr >= 0x13800 && addr <= 0x13890) {
    uint32_t off = addr - 0x13800;
    if (off == 0x00) return "DMAConfig";
    if (off == 0x08) return "BaseAddr";
    if (off == 0x0C) return "RowStride";
    if (off == 0x10) return "PlaneStride";
    if (off == 0x14) return "DepthStride";
    if (off == 0x18) return "GroupStride";
    if (off == 0x38) return "Fmt";
    if (off >= 0x50 && off <= 0x5C) return "PixelOffset";
  }
  // TileDMA Dst (0x17800)
  if (addr >= 0x17800 && addr <= 0x17830) {
    uint32_t off = addr - 0x17800;
    if (off == 0x00) return "DMAConfig";
    if (off == 0x04) return "BaseAddr";
    if (off == 0x08) return "RowStride";
    if (off == 0x0C) return "PlaneStride";
    if (off == 0x10) return "DepthStride";
    if (off == 0x14) return "GroupStride";
    if (off == 0x18) return "Fmt";
  }
  // KernelDMA (0x1F800)
  // Base at 0x1F800. Offsets from tex: 0x02C (base), 0x034 (coeff)
  // Let's assume start at 0x1F800
  if (addr >= 0x1F800 && addr <= 0x1F900) {
    uint32_t off = addr - 0x1F800;
    if ((off == 0x00) || (off == 0x04)) return "Unknown";
    if (off >= 0x08 && off < 0x48) return "CoeffDMAConfig";
    if (off >= 0x48 && off < 0x88) return "CoeffBaseAddr";
    if (off >= 0x88 && off < 0xC8) return "CoeffBfrSize";
  }
  return NULL;
}

const char *get_m4_reg_name(uint32_t addr) {
  if (addr < 23 * 4) {
    static const char *common_names[] = {
        "ChannelCfg", "InWidth",     "InHeight",    "InChannels", "InDepth", "OutWidth",
        "OutHeight",  "OutChannels", "OutDepth",    "NumGroups",  "ConvCfg", "ConvCfg3d",
        "UnicastCfg", "TileHeight",  "TileOverlap", "MacCfg",     "LaneCfg", "PatchCfg",
        "PERouting",  "NID",         "DPE",         "Val21",      "Val22"};
    return common_names[addr / 4];
  }
  // L2 0x4100
  if (addr >= 0x4100 && addr <= 0x41A0) {
    uint32_t off = addr - 0x4100;
    uint32_t word_off = off / 4;
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
    if (word_off < 41) return l2_names[word_off];
  }
  // Auxiliary PE Indexing 0x44D0
  if (addr >= 0x44D0 && addr <= 0x44D4) {
    return (addr == 0x44D0) ? "PE_IndexMode" : "PE_IndexBroadcast";
  }
  // PE 0x4500
  if (addr >= 0x4500 && addr <= 0x4538) {
    uint32_t off = (addr - 0x4500) / 4;
    static const char *pe_names[] = {
        "PE_Config",      "PE_Bias",      "PE_Scale",     "PE_FinalScale", "PE_PreScale",
        "PE_FinalScale2", "PE_Reserved1", "PE_Reserved2", "PE_Reserved3",  "PE_Reserved4",
        "PE_Reserved5",   "PE_Reserved6", "PE_Reserved7", "PE_Reserved8",  "PE_Quant"};
    if (off < 15) return pe_names[off];
  }
  // NE 0x4900
  if (addr >= 0x4900 && addr <= 0x492C) {
    uint32_t off = (addr - 0x4900) / 4;
    static const char *ne_names[] = {
        "KernelCfg",    "MACCfg",  "MatrixVectorBias", "NEBias",  "PostScale", "RcasConfig",
        "RoundModeCfg", "SRSeed0", "SRSeed1",          "SRSeed2", "SRSeed3",   "QuantZeroPoint"};
    if (off < 12) return ne_names[off];
  }
  // CE/CacheDMA 0x5900
  if (addr >= 0x5900 && addr <= 0x5930) {
    uint32_t off = addr - 0x5900;
    static const char *cdma_names[] = {"CacheDMAControl",  "CacheDMAPre0",      "CacheDMAPre1",
                                       "CacheDMAPad3",     "CacheDMAPad4",      "CacheDMAPad5",
                                       "CacheDMADsid",     "CacheDMAFootprint", "EarlyTermArg12",
                                       "CacheDMAFlushArg", "EarlyTermArg34",    "TelemetryBackOff"};
    if (off / 4 < 12) return cdma_names[off / 4];
  }
  // TileDMA Src 0x4D00
  if (addr >= 0x4D00 && addr <= 0x4DB4) {
    uint32_t off = addr - 0x4D00;
    if (off == 0x00) return "Src1DMAConfig";
    if (off == 0x04) return "Src2DMAConfig";
    if (off == 0x08) return "Src1BaseAddrLo";
    if (off == 0x0C) return "Src1BaseAddrHi";
    if (off == 0x10) return "Src2BaseAddrLo";
    if (off == 0x14) return "Src2BaseAddrHi";
    if (off == 0x18) return "Src1RowStride";
    if (off == 0x1C) return "Src1PlaneStride";
    if (off == 0x20) return "Src1DepthStride";
    if (off == 0x24) return "Src1GroupStride";
    if (off == 0x30) return "Src2RowStride";
    if (off == 0x34) return "Src2PlaneStride";
    if (off == 0x38) return "Src2DepthStride";
    if (off == 0x3C) return "Src2GroupStride";
    if (off == 0x50) return "Src1MetaDataAddrLo";
    if (off == 0x58) return "Src1MetaDataSize";
    if (off == 0x5C) return "Src2MetaDataAddrLo";
    if (off == 0x64) return "Src2MetaDataSize";
    if (off == 0x68) return "Src1Fmt";
    if (off == 0x6C) return "Src2Fmt";
    if (off == 0x98) return "Src1PixelOffset";
    if (off == 0xA8) return "Src2PixelOffset";
  }
  // TileDMA Dst 0x5100
  if (addr >= 0x5100 && addr <= 0x5150) {
    uint32_t off = addr - 0x5100;
    if (off == 0x00) return "DstDMAConfig";
    if (off == 0x08) return "DstBaseAddrLo";
    if (off == 0x0C) return "DstBaseAddrHi";
    if (off == 0x10) return "DstRowStride";
    if (off == 0x14) return "DstPlaneStride";
    if (off == 0x18) return "DstDepthStride";
    if (off == 0x1C) return "DstGroupStride";
    if (off == 0x20) return "DstInternalCfg";
    if (off == 0x28) return "DstMetaDataAddrLo";
    if (off == 0x2C) return "DstMetaDataAddrHi";
    if (off == 0x30) return "DstFmtMode";
    if (off == 0x38) return "DstCompStatus";
    if (off == 0x40) return "DstCompressionCfg";
    if (off == 0x48) return "DstCompSizeLo";
    if (off == 0x4C) return "DstCompSizeHi";
    if (off == 0x50) return "DstPixelOffset";
  }
  // KernelDMA Src 0x5500
  if (addr >= 0x5500 && addr <= 0x5610) {
    uint32_t off = addr - 0x5500;
    if (off == 0x00) return "KDMA_MasterConfig";
    if (off == 0x08) return "KDMA_Prefetch";
    if (off == 0x18) return "KDMA_StrideX";
    if (off == 0x1C) return "KDMA_StrideY";
    if (off >= 0x20 && off <= 0x5C) return "CoeffDMAConfig";
    if (off >= 0x60 && off <= 0x9C) return "CoeffBaseAddr";
    if (off >= 0xA0 && off <= 0xDC) return "CoeffBfrSize";
    if (off == 0xE0) return "BiasDMAConfig";
    if (off == 0xF0) return "PostScaleDMAConfig";
    if (off == 0x100) return "PaletteDMAConfig";
    if (off == 0x110) return "NLutDMAConfig";
  }
  return NULL;
}

typedef struct {
  const char *name;
  uint32_t startAddr;
} hwx_block_info_t;

void dump_hw_blocks(const uint32_t *reg_values, const bool *reg_valid,
                    const hwx_block_info_t *blocks, int count,
                    const char *(*name_lookup)(uint32_t)) {
  for (int b = 0; b < count; b++) {
    bool printed_header = false;
    uint32_t word_start = blocks[b].startAddr / 4;
    uint32_t word_end = word_start + 0x100;  // Look ahead 0x400 bytes

    for (uint32_t r = word_start; r < word_end; r++) {
      if (reg_valid[r]) {
        if (!printed_header) {
          printf("        %s:\n", blocks[b].name);
          printed_header = true;
        }
        uint32_t addr = r * 4;
        const char *reg_name = name_lookup(addr);
        if (reg_name) {
          printf("          0x%05x: 0x%08x (%s)\n", addr, reg_values[r], reg_name);
        } else {
          printf("          0x%05x: 0x%08x\n", addr, reg_values[r]);
        }
      }
    }
  }
}

// [0x5500] KernelDMA Source Block
typedef struct {
  struct {
    uint32_t pad0 : 6;
    uint32_t master_enable : 1;  // Bit 6
    uint32_t pad1 : 25;
  } master_cfg;       // Word 0 (0x5500)
  uint32_t pad1;      // Word 1
  uint32_t prefetch;  // Word 2 (0x5508)
  uint32_t pad2[3];   // Word 3-5
  uint32_t stridex;   // Word 6 (0x5518)
  uint32_t stridey;   // Word 7 (0x551C)

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t pad1 : 8;
  } coeff_cfg[16];  // Word 8-23 (0x5520-0x555C)

  uint32_t coeff_base[16];  // Word 24-39 (0x5560-0x559C)
  uint32_t coeff_size[16];  // Word 40-55 (0x55A0-0x55DC)

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } bias_cfg;  // Word 56 (0x55E0)

  uint32_t pad3[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } post_scale_cfg;  // Word 60 (0x55F0)

  uint32_t pad4[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } palette_cfg;  // Word 64 (0x5600)

  uint32_t pad5[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } non_linear_cfg;  // Word 68 (0x5610)
} __attribute__((packed)) ane_kerneldma_src_h16_t;

typedef struct {
  struct {
    uint32_t flush : 1;                 // Bit 0
    uint32_t enable : 1;                // Bit 1
    uint32_t task_sync : 2;             // Bits 2-3 (WaitPrev:3, PostDone:2)
    uint32_t early_term : 5;            // Bits 4-8
    uint32_t footprint_limiter : 1;     // Bit 9
    uint32_t pad1 : 6;                  // Bits 10-15
    uint32_t footprint_threshold : 16;  // Bits 16-31
  } control;                            // 0x5900 (Word 0)

  struct {
    uint32_t bandwidth_limit : 10;   // Bits 0-9
    uint32_t pad0 : 6;               // Bits 10-15
    uint32_t sieve2 : 4;             // Bits 16-19
    uint32_t telemetry_age_out : 4;  // Bits 20-23
    uint32_t pad1 : 8;               // Bits 24-31
  } pre0;                            // 0x5904 (Word 1)

  struct {
    uint32_t sieve1 : 14;  // Bits 0-13
    uint32_t pad0 : 18;    // Bits 14-31
  } pre1;                  // 0x5908 (Word 2)

  uint32_t pad0[3];  // 0x590c, 0x5910, 0x5914

  struct {
    uint32_t pad0 : 7;            // Bits 0-6
    uint32_t dsid_and_size : 23;  // Bits 7-29
    uint32_t pad1 : 2;            // Bits 30-31
  } dsid;                         // 0x5918 (Word 6)

  struct {
    uint32_t pad0 : 17;            // Bits 0-16
    uint32_t footprint_arg2 : 11;  // Bits 17-27
    uint32_t pad1 : 4;             // Bits 28-31
  } footprint_arg;                 // 0x591c (Word 7)

  struct {
    uint16_t arg1;     // Bits 0-15 (Half)
    uint16_t arg2;     // Bits 16-31 (Half)
  } early_term_arg12;  // 0x5920 (Word 8)

  struct {
    uint16_t flush_arg;  // Bits 0-15 (Half)
    uint16_t pad0;       // Bits 16-31
  } flush_reg;           // 0x5924 (Word 9)

  struct {
    uint8_t arg3;      // Bits 0-7 (Byte)
    uint8_t pad0;      // Bits 8-15
    uint8_t arg4;      // Bits 16-23 (Byte)
    uint8_t pad1;      // Bits 24-31
  } early_term_arg34;  // 0x5928 (Word 10)

  struct {
    uint32_t enable : 1;  // Bit 0
    uint32_t pad0 : 3;    // Bits 1-3
    uint32_t delay : 4;   // Bits 4-7
    uint32_t min : 8;     // Bits 8-15
    uint32_t max : 8;     // Bits 16-23
    uint32_t scale : 8;   // Bits 24-31
  } backoff;              // 0x592c (Word 11)
} __attribute__((packed)) ane_cachedma_h16_t;

// [0x4D00] TileDMA Source Block
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 7;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t format : 4;
    uint32_t pad1 : 4;
  } src1cfg;  // Word 0

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 7;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t pad1 : 4;
    uint32_t dep_mode : 2;
    uint32_t pad2 : 2;
  } src2cfg;  // Word 1

  uint32_t src1base_lo;  // Word 2
  uint32_t src1base_hi;  // Word 3
  uint32_t src2base_lo;  // Word 4
  uint32_t src2base_hi;  // Word 5

  uint32_t src1rows;    // Word 6
  uint32_t src1chans;   // Word 7
  uint32_t src1depths;  // Word 8
  uint32_t src1groups;  // Word 9

  uint32_t pad0[2];  // Word 10-11

  uint32_t src2rows;    // Word 12
  uint32_t src2chans;   // Word 13
  uint32_t src2depths;  // Word 14
  uint32_t src2groups;  // Word 15

  uint32_t pad1[4];  // Word 16-19

  uint32_t src1meta_lo;    // Word 20
  uint32_t src1meta_hi;    // Word 21
  uint32_t src1meta_size;  // Word 22
  uint32_t src2meta_lo;    // Word 23
  uint32_t src2meta_hi;    // Word 24
  uint32_t src2meta_size;  // Word 25

  uint32_t src1memfmt;  // Word 26
  uint32_t src2memfmt;  // Word 27

  uint32_t pad2[10];         // Word 28-37
  uint32_t src1pixeloff[4];  // Word 38-41
  uint32_t src2pixeloff[4];  // Word 42-45
} __attribute__((packed)) ane_tiledma_src_h16_t;

// [0x5100] TileDma Destination Block
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t pad1 : 8;
  } dstcfg;  // Word 0

  uint32_t dstpadding;  // Word 1

  uint32_t dstbase_lo;  // Word 2
  uint32_t dstbase_hi;  // Word 3

  uint32_t dstrows;    // Word 4
  uint32_t dstchans;   // Word 5
  uint32_t dstdepths;  // Word 6
  uint32_t dstgroups;  // Word 7

  uint32_t dstinternalcfg;  // Word 8
  uint32_t pad0;            // Word 9

  uint32_t dstmeta_lo;  // Word 10
  uint32_t dstmeta_hi;  // Word 11
  uint32_t dstfmtmode;  // Word 12
  uint32_t pad1;        // Word 13

  uint32_t dstcompstatus;  // Word 14
  uint32_t pad2;           // Word 15

  uint32_t dstcompressioncfg;  // Word 16
  uint32_t pad3;               // Word 17

  uint32_t dstcompsize_lo;  // Word 18
  uint32_t dstcompsize_hi;  // Word 19

  uint32_t dstpixeloffset;  // Word 20
} __attribute__((packed)) ane_tiledma_dst_h16_t;

// [0x4900] Neural Engine (NE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4900)
  struct {
    uint32_t kernel_fmt : 2;          // [1:0]
    uint32_t palettized_en : 1;       // [2]
    uint32_t pad0 : 1;                // [3]
    uint32_t palettized_bits : 4;     // [7:4]
    uint32_t sparse_fmt : 1;          // [8]
    uint32_t pad1_0 : 1;              // [9]
    uint32_t group_kernel_reuse : 1;  // [10]
    uint32_t pad1_1 : 4;              // [14:11]
    uint32_t sparse_binary : 1;       // [15]
    uint32_t alignment_fmt : 1;       // [16]
    uint32_t pad2 : 4;                // [20:17]
    uint32_t sparse_block_size : 3;   // [23:21]
    uint32_t asym_quant_en : 1;       // [24]
    uint32_t pad3 : 7;
  } kernel_cfg;

  // Word 1 (0x4904)
  struct {
    uint32_t op_mode : 3;            // [2:0]
    uint32_t kernel_mode : 1;        // [3]
    uint32_t ne_bias_en : 1;         // [4]
    uint32_t passthrough_en : 1;     // [5]
    uint32_t matrix_bias_en : 1;     // [6]
    uint32_t pad0 : 1;               // [7]
    uint32_t binary_point : 6;       // [13:8]
    uint32_t post_scale_en : 1;      // [14]
    uint32_t pad1 : 1;               // [15]
    uint32_t non_linear_mode : 2;    // [17:16]
    uint32_t padding_mode : 1;       // [18]
    uint32_t max_pool_mode : 1;      // [19]
    uint32_t arg_output_select : 4;  // [23:20]
    uint32_t pad2 : 2;               // [25:24]
    uint32_t double_int8_en : 1;     // [26]
    uint32_t pad3 : 5;
  } mac_cfg;

  // Word 2 (0x4908)
  struct {
    uint32_t matrix_vector_bias : 16;
    uint32_t pad0 : 16;
  } matrix_bias;

  // Word 3 (0x490C)
  struct {
    uint32_t val : 21;
    uint32_t pad0 : 11;
  } ne_bias;

  // Word 4 (0x4910)
  struct {
    uint32_t val : 21;
    uint32_t pad0 : 11;
  } post_scale;

  // Word 5 (0x4914)
  struct {
    uint32_t key_mask : 8;    // [7:0]
    uint32_t cmp_bit : 3;     // [10:8]
    uint32_t pad0 : 1;        // [11]
    uint32_t sense_axis : 2;  // [13:12]
    uint32_t pad1 : 2;        // [15:14]
    uint32_t sense_bit : 4;   // [19:16]
    uint32_t mode : 1;        // [20]
    uint32_t pad2 : 11;
  } rcas_cfg;

  // Word 6 (0x4918)
  struct {
    uint32_t round_mode : 2;    // [1:0]
    uint32_t pad0 : 2;          // [3:2]
    uint32_t integer_bits : 5;  // [8:4]
    uint32_t pad1 : 23;
  } st_round_cfg;

  // Words 7-10 (0x491C, 4920, 4924, 4928)
  uint32_t st_round_seed[4];

  // Word 11 (0x492C)
  struct {
    uint32_t quant_zero_point : 8;  // [7:0]
    uint32_t pad0 : 24;
  } quant;

} ane_ne_h16_t;

// [0x4500] Planar Engine (PE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4500)
  struct {
    uint32_t op : 6;    // [5:0]
    uint32_t cond : 3;  // [8:6]
    uint32_t pad0 : 7;  // [15:9]
    uint32_t src1 : 1;  // [16]
    uint32_t pad1 : 1;  // [17]
    uint32_t src2 : 2;  // [19:18]
    uint32_t pad2 : 12;
  } pe_cfg;

  uint32_t bias;          // Word 1 (0x4504)
  uint32_t scale;         // Word 2 (0x4508)
  uint32_t final_scale;   // Word 3 (0x450C)
  uint32_t pre_scale;     // Word 4 (0x4510)
  uint32_t final_scale2;  // Word 5 (0x4514)
  uint32_t res[8];        // Words 6-13
  struct {
    uint32_t input_relu : 1;
    uint32_t output_relu : 1;
    uint32_t zero_point : 8;
    uint32_t pad : 22;
  } quant;  // Word 14 (0x4538)
} ane_pe_h16_t;

// [0x4100] L2 Cache Control Block (M4 specific mapping - 41 registers)
typedef struct {
  // Word 0 (0x4100)
  struct {
    uint32_t pad0 : 2;
    uint32_t padding_mode : 2;  // [3:2]
    uint32_t src1_fifo : 1;     // [4]
    uint32_t pad1 : 1;
    uint32_t src1_double : 1;  // [6]
    uint32_t pad2 : 9;
    uint32_t barrier : 1;  // [16]
    uint32_t pad3 : 15;
  } l2_control;

  // Word 1 (0x4104)
  struct {
    uint32_t pad0 : 2;
    uint32_t src_type : 2;  // [3:2]
    uint32_t pad1 : 2;
    uint32_t dma_fmt : 2;        // [7:6]
    uint32_t interleave : 4;     // [11:8]
    uint32_t offset_y_lsbs : 4;  // [15:12]
    uint32_t pad2 : 9;
    uint32_t compression : 1;  // [25]
    uint32_t pad3 : 6;
  } src1_cfg;

  // Word 2 (0x4108)
  struct {
    uint32_t pad0 : 2;
    uint32_t src_type : 2;  // [3:2]
    uint32_t pad1 : 4;
    uint32_t interleave : 4;  // [11:8]
    uint32_t pad2 : 13;
    uint32_t compression : 1;  // [25]
    uint32_t pad3 : 6;
  } src2_cfg;

  uint32_t l2_pad3;  // Word 3 (0x410c)

  // Dense 17-bit packed tensor blocks (Bits 4:20)
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
  } src1;  // Words 4-8

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
  } src2;  // Words 9-13

  struct {
    uint32_t base : 17;
    uint32_t pad0 : 15;
    uint32_t channel_stride : 17;
    uint32_t pad1 : 15;
    uint32_t depth_stride : 17;
    uint32_t pad2 : 15;
    uint32_t group_stride : 17;
    uint32_t pad3 : 15;
  } srcidx;  // Words 14-17

  // Word 18 (0x4148)
  struct {
    uint32_t pad0 : 3;
    uint32_t bfr_mode : 1;       // [3]
    uint32_t crop_offset_x : 3;  // [6:4]
    uint32_t pad1 : 1;
    uint32_t interleave : 4;  // [11:8]
    uint32_t res_type : 2;    // [13:12]
    uint32_t pad2 : 11;
    uint32_t compression : 1;  // [25]
    uint32_t pad3 : 6;
  } result_cfg;

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
  } result;  // Words 19-23

  uint32_t l2_res24;  // 0x4160
  uint32_t l2_res25;  // 0x4164 (WrapCfg)
  uint32_t l2_res26;  // 0x4168
  uint32_t l2_res27;  // 0x416c
  uint32_t l2_res28;  // 0x4170

  // Word 29 (0x4174)
  struct {
    uint32_t wrap_index : 16;
    uint32_t wrap_start_offset : 16;
  } result_wrap_idx_off;

  uint32_t l2_res30;  // 0x4178

  // Words 31-35 (Secondary Result)
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
  } result2;

  uint32_t l2_res36;  // 0x4190
  uint32_t l2_res37;  // 0x4194
  uint32_t l2_res38;  // 0x4198

  // Word 39 (0x419c)
  struct {
    uint32_t wrap_addr : 12;
    uint32_t pad0 : 4;
    uint32_t wrap_addr_offset : 11;
    uint32_t pad1 : 5;
  } result_wrap_addr;

  uint32_t l2_res40;  // 0x41a0

} __attribute__((packed)) ane_l2_h16_t;

// [0x0000] M1 Common Registers
typedef struct {
  // 0x0000 Common.InDim
  struct {
    uint32_t w_in : 15;
    uint32_t pad0 : 1;
    uint32_t h_in : 15;
    uint32_t pad1 : 1;
  } indim;
  uint32_t pad2;  // 0x12C

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

  uint32_t pad3;  // 0x140

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

  uint32_t pad4;  // 0x148

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

  uint32_t pad5[2];  // 0x154-0x158

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
  } task_info;  // 0x160

  struct {
    uint32_t category : 4;
    uint32_t pad0 : 28;
  } dpe;  // 0x164

} __attribute__((packed)) ane_common_h13_t;

// [0x1e0] L2
typedef struct {
  struct {
    uint32_t input_relu : 1;
    uint32_t padding_mode : 2;
    uint32_t pad0 : 29;
  } l2cfg;  // 0x1E0

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
  } scfg;  // 0x1E4

  struct {
    uint32_t pad0 : 4;
    uint32_t addr : 17;
    uint32_t pad1 : 11;
  } srcbase;  // 0x1E8

  struct {
    uint32_t pad0 : 4;
    uint32_t stride : 17;
    uint32_t pad1 : 11;
  } src_chan_stride;  // 0x1EC

  struct {
    uint32_t pad0 : 4;
    uint32_t stride : 17;
    uint32_t pad1 : 11;
  } src_row_stride;  // 0x1F0

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
  } rcfg;  // 0x210
} __attribute__((packed)) ane_l2_h13_t;

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

} __attribute__((packed)) ane_ne_h13_t;

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
  } src_dma_config;  // 0x16c

  uint32_t pad2;  // 0x170

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } base_addr;  // 0x174

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } row_stride;  // 0x178

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } plane_stride;  // 0x17c

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } depth_stride;  // 0x180

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } group_stride;  // 0x184

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
  } fmt;  // 0x1a4

  uint32_t pad4[(0x1bc - 0x1a8) / 4];

  uint32_t pixel_offset[4];  // 0x1bc - 0x1c8

  uint32_t pad5[(0x1f8 - 0x1cc) / 4];

} __attribute__((packed)) ane_tiledma_src_h13_t;

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
  } cfg;  // 0x8800 (offset 0x22c in tex)

  struct {
    uint16_t bias;
    uint16_t scale;
  } bias_scale;  // 0x8804 (offset 0x230 in tex)

  struct {
    uint16_t pre_scale;
    uint16_t pad0;
  } pre_scale;  // 0x8808 (offset 0x234 in tex)

  struct {
    uint32_t final_scale;
  } final_scale;  // 0x880c (offset 0x238 in tex)
} __attribute__((packed)) ane_pe_h13_t;

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
  } coeff_dma_config[16];  // 0xc0 - 0xfc

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } coeff_base_addr[16];  // 0x100 - 0x13c

  uint32_t coeff_bfr_size[16];  // 0x140 - 0x17c
} __attribute__((packed)) ane_kerneldma_h13_t;

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
  } dst_dma_config;  // 0x258

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } base_addr;  // 0x25c

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } row_stride;  // 0x260

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } plane_stride;  // 0x264

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } depth_stride;  // 0x268

  struct {
    uint32_t pad0 : 6;
    uint32_t stride : 26;
  } group_stride;  // 0x26c

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
  } fmt;  // 0x270

} __attribute__((packed)) ane_tiledma_dst_h13_t;

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

void decode_ane_td(const uint8_t *ptr, size_t total_len) {
  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_td_header_h13_t) <= total_len) {
    const ane_td_header_h13_t *td = (const ane_td_header_h13_t *)(ptr + offset);
    if (td->next_pointer == 0 && td->exe_cycles == 0 && td->log_events == 0) {
      break;  // Hit zero padding
    }

    printf("      [ANE Task %d @ 0x%x]\n", task_idx++, offset);
    printf("        TID: 0x%04x NID: 0x%02x LNID: %d EON: %d\n", td->tid, td->nid, td->lnid,
           td->eon);
    printf("        ExeCycles: %u NextSize: %u\n", td->exe_cycles, td->next_size);
    printf("        NextPtr: 0x%08x TSR: %d TSE: %d ENE: %d\n", td->next_pointer, td->flags.tsr,
           td->flags.tse, td->base_ene.ene);
    printf("        RBase: %d/%d WBase: %d TBase: %d\n", td->base_ene.rbase0, td->base_ene.rbase1,
           td->base_ene.wbase, td->base_ene.tbase);
    if (td->kbase.kbe0 || td->kbase.kbe1 || td->kbase.kbe2 || td->kbase.kbe3) {
      printf("        KBase: %d/%d/%d/%d\n", td->kbase.kbase0, td->kbase.kbase1, td->kbase.kbase2,
             td->kbase.kbase3);
    }

    uint32_t reg_values[0x20000] = {0};
    bool reg_valid[0x20000] = {false};

    // Modern Stream Parse
    if (offset + sizeof(ane_td_header_h13_t) <= total_len) {
      const uint32_t *words = (const uint32_t *)(td + 1);
      uint32_t max_payload_bytes =
          (total_len > offset + sizeof(ane_td_header_h13_t))
              ? (uint32_t)(total_len - offset - sizeof(ane_td_header_h13_t))
              : 0;
      uint32_t num_words = max_payload_bytes / 4;

      if (td->next_pointer > offset + sizeof(ane_td_header_h13_t)) {
        uint32_t td_words = (td->next_pointer - offset - sizeof(ane_td_header_h13_t)) / 4;
        if (td_words < num_words) {
          num_words = td_words;
        }
      }

      int w_idx = 0;
      while (w_idx < num_words) {
        uint32_t hdr = words[w_idx++];

        // skip padding words
        if (hdr == 0) continue;
        uint32_t count = (hdr >> 26) & 0x3f;
        uint32_t addr = (hdr & 0x3ffffff) >> 2;
        uint32_t num_vals = count + 1;
        for (uint32_t i = 0; i < num_vals; i++) {
          if (w_idx >= num_words) break;
          // Mask addr just in case it exceeds our struct buffer logic
          if (addr + i < 0x20000) {
            reg_values[addr + i] = words[w_idx];
            reg_valid[addr + i] = true;
          }
          w_idx++;
        }
      }
    }

    if (offset + sizeof(ane_td_header_h13_t) <= total_len) {
      printf("        --- HW Block Register State ---\n");
      // Decode Common Block (0x0000)
      printf("        --- Common (0x0000) ---\n");
      const ane_common_h13_t *common = (const ane_common_h13_t *)&reg_values[0];

      uint16_t win = common->indim.w_in;
      uint16_t hin = common->indim.h_in;
      uint32_t cin = common->cin.c_in;

      uint16_t wout = common->outdim.w_out;
      uint16_t hout = common->outdim.h_out;
      uint32_t cout = common->cout.c_out;

      const char *infmt_name = get_ch_fmt_name(common->chcfg.infmt);
      const char *outfmt_name = get_ch_fmt_name(common->chcfg.outfmt);

      printf("        %u x %u x %u (%s) -> %u x %u x %u (%s)\n", win, hin, cin, infmt_name, wout,
             hout, cout, outfmt_name);

      if (common->convcfg.kw != 0 || common->convcfg.kh != 0) {
        printf("        ConvCfg: K=%ux%u S=%ux%u P=%ux%u\n", common->convcfg.kw, common->convcfg.kh,
               common->convcfg.sx, common->convcfg.sy, common->convcfg.px, common->convcfg.py);

        printf("        GroupConvCfg: Groups=%u UnicastEn=%d ElemMult=%d "
               "UnicastCin=%u\n",
               common->groupcfg.num_groups, common->groupcfg.unicast_en,
               common->groupcfg.elem_mult_mode, common->groupcfg.unicast_cin);
      }

      printf("        Cfg: ActiveNE=%u SmallSrc=%u ShPref=%u ShMin=%u ShMax=%u "
             "AccDB=%u\n",
             common->cfg.active_ne, common->cfg.small_src_mode, common->cfg.sh_pref,
             common->cfg.sh_min, common->cfg.sh_max, common->cfg.acc_db_buf_en);

      printf("        TaskInfo: TID=0x%04x Q=%u NID=0x%02x\n", common->task_info.tid,
             common->task_info.task_q, common->task_info.task_nid);

      // Decode L2 Block (0x4800)
      printf("        --- L2 (0x4800) ---\n");
      const ane_l2_h13_t *l2 = (const ane_l2_h13_t *)&reg_values[0x4800 / 4];
      printf("        L2Cfg: InputRelu=%d PaddingMode=%u\n", l2->l2cfg.input_relu,
             l2->l2cfg.padding_mode);
      printf("        L2 SourceCfg: Type=%u Dep=%u Fmt=%u Intrlv=%u CmpV=%u "
             "OffCh=%u\n",
             l2->scfg.type, l2->scfg.dep, l2->scfg.fmt, l2->scfg.interleave, l2->scfg.cmpv,
             l2->scfg.offch);
      printf("        L2 Src1: Base=0x%05x ChanStride=0x%05x RowStride=0x%05x\n", l2->srcbase.addr,
             l2->src_chan_stride.stride, l2->src_row_stride.stride);

      printf("        L2 ResultCfg: Type=%u Bfr=%u Fmt=%u Intrlv=%u CmpV=%u "
             "OffCh=%u\n",
             l2->rcfg.type, l2->rcfg.bfrmode, l2->rcfg.fmt, l2->rcfg.interleave, l2->rcfg.cmpv,
             l2->rcfg.offch);

      // Decode NE Block (0xC800)
      printf("        --- Neural Engine (0xC800) ---\n");
      const ane_ne_h13_t *ne = (const ane_ne_h13_t *)&reg_values[0xC800 / 4];
      printf("        NE MACCfg: OpMode=%u NLMode=%u KernelMode=%d BiasMode=%d "
             "BinaryPoint=%u\n",
             ne->mac_cfg.op_mode, ne->mac_cfg.non_linear_mode, ne->mac_cfg.kernel_mode,
             ne->mac_cfg.bias_mode, ne->mac_cfg.binary_point);
      printf("        NE KernelCfg: Fmt=%s PalettizedEn=%d PalettizeBits=%u "
             "SparseFmt=%d GroupKernelReuse=%d\n",
             get_ch_fmt_name(ne->kernel_cfg.kernel_fmt), ne->kernel_cfg.palettized_en,
             ne->kernel_cfg.palettized_bits, ne->kernel_cfg.sparse_fmt,
             ne->kernel_cfg.group_kernel_reuse);
      printf("        NE MatrixVectorBias: 0x%04x\n", ne->matrix_vector_bias.matrix_vector_bias);
      printf("        NE AccBias: 0x%04x Shift=%u\n", ne->acc_bias.acc_bias,
             ne->acc_bias.acc_bias_shift);
      printf("        NE PostScale: 0x%04x RightShift=%u\n", ne->post_scale.post_scale,
             ne->post_scale.post_scale_right_shift);

      // Decode TileDMA Source (0x13800)
      const ane_tiledma_src_h13_t *tsrc = (const ane_tiledma_src_h13_t *)&reg_values[0x13800 / 4];
      printf("        --- TileDMA Source (0x13800) ---\n");
      printf("        Src1DMAConfig: En=%d CacheHint=%u DepMode=%u\n", tsrc->src_dma_config.en,
             tsrc->src_dma_config.cache_hint, tsrc->src_dma_config.dep_mode);
      printf("        Src1Strides: Base=0x%05x Row=0x%05x Plane=0x%05x "
             "Depth=0x%05x Group=0x%05x\n",
             tsrc->base_addr.addr, tsrc->row_stride.stride, tsrc->plane_stride.stride,
             tsrc->depth_stride.stride, tsrc->group_stride.stride);

      printf("        Src1Fmt: FmtMode=%u Trunc=%u Shift=%u MemFmt=%u "
             "OffCh=%u Intrlv=%u CmpV=%u\n",
             tsrc->fmt.fmt_mode, tsrc->fmt.truncate, tsrc->fmt.shift, tsrc->fmt.mem_fmt,
             tsrc->fmt.offset_ch, tsrc->fmt.interleave, tsrc->fmt.cmp_vec);

      // Decode PE Block (0x8800)
      const ane_pe_h13_t *pe = (const ane_pe_h13_t *)&reg_values[0x8800 / 4];
      if (reg_valid[0x8800 / 4]) {
        printf("        --- Planar Engine (0x8800) ---\n");
        printf("        PECfg: En=%d OpMode=%u ReluEn=%d Cond=%u FirstSrc=%u "
               "SecondSrc=%u\n",
               pe->cfg.enable, pe->cfg.op_mode, pe->cfg.relu_en, pe->cfg.cond, pe->cfg.first_source,
               pe->cfg.second_source);
        printf("        PEBiasScale: Bias=0x%04x Scale=0x%04x\n", pe->bias_scale.bias,
               pe->bias_scale.scale);
        printf("        PEPreScale: 0x%04x PEFinalScale: 0x%08x\n", pe->pre_scale.pre_scale,
               pe->final_scale.final_scale);
      }

      // Decode KernelDMA (0x1F800)
      const ane_kerneldma_h13_t *k = (const ane_kerneldma_h13_t *)&reg_values[0x1F800 / 4];
      printf("        --- KernelDMA (0x1F800) ---\n");
      for (int i = 0; i < 16; i++) {
        if (k->coeff_dma_config[i].en) {
          printf("        Coeff[%d]: En=%d CacheHint=%u Base=0x%08x Size=0x%08x\n", i,
                 k->coeff_dma_config[i].en, k->coeff_dma_config[i].cache_hint,
                 k->coeff_base_addr[i].addr, k->coeff_bfr_size[i]);
        }
      }

      // Decode TileDMA Destination (0x17800)
      const ane_tiledma_dst_h13_t *tdst = (const ane_tiledma_dst_h13_t *)&reg_values[0x17800 / 4];
      printf("        --- TileDMA Destination (0x17800) ---\n");
      printf("        DstDMAConfig: En=%d CacheHint=%u L2BfrMode=%d "
             "BypassEOW=%d\n",
             tdst->dst_dma_config.en, tdst->dst_dma_config.cache_hint,
             tdst->dst_dma_config.l2bfrmode, tdst->dst_dma_config.bypass_eow);
      printf("        DstStrides: Base=0x%05x Row=0x%05x Plane=0x%05x "
             "Depth=0x%05x Group=0x%05x\n",
             tdst->base_addr.addr, tdst->row_stride.stride, tdst->plane_stride.stride,
             tdst->depth_stride.stride, tdst->group_stride.stride);

      printf("        DstFmt: FmtMode=%u Trunc=%u Shift=%u MemFmt=%u "
             "OffCh=%u ZPLast=%d ZPFirst=%d Fill=%d Intrlv=%u CmpV=%u\n",
             tdst->fmt.fmt_mode, tdst->fmt.truncate, tdst->fmt.shift, tdst->fmt.mem_fmt,
             tdst->fmt.offset_ch, tdst->fmt.zero_pad_last, tdst->fmt.zero_pad_first,
             tdst->fmt.cmp_vec_fill, tdst->fmt.interleave, tdst->fmt.cmp_vec);

      if (1) {
        hwx_block_info_t blocks[] = {
            {"[0x00000] Common Module", 0x00000},
            {"[0x04800] L2 Cache Control", 0x04800},
            {"[0x08800] Planar Engine (PE)", 0x08800},
            {"[0x0C800] Neural Engine Core (NE)", 0x0C800},
            {"[0x13800] TileDMA Source", 0x13800},
            {"[0x17800] TileDMA Destination", 0x17800},
            {"[0x1F800] KernelDMA Source", 0x1F800},
        };
        dump_hw_blocks(reg_values, reg_valid, blocks, 7, get_m1_reg_name);
      }
    }

    if (td->next_pointer == 0 || td->next_pointer <= offset) break;
    offset = td->next_pointer;
  }
}

void decode_ane_td_m4(const uint8_t *ptr, size_t total_len, uint32_t subtype) {
  printf("\n[%s] Detected Dense HWX Format (CPU Subtype 0x%x)\n", get_arch_name(subtype), subtype);

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
    printf("      [ANE Task %d @ 0x%x] (Size: 0x%x bytes)\n", task_idx++, offset, size_bytes);

    printf("        TID: 0x%04x ExeCycles: %u ENE: %u\n", m4h->tid, m4h->exe_cycles, m4h->ene);
    printf("        LogEvents: 0x%06x Exceptions: 0x%06x\n", m4h->log_events, m4h->exceptions);
    printf("        LiveOuts: 0x%08x TSR: %d TDE: %d\n", m4h->live_outs, m4h->tsr, m4h->tde);
    if (m4h->tde == 1) {
      printf("        TDID: 0x%04x\n", m4h->tdid);
    }

    uint32_t reg_values[0x8000] = {0};
    bool reg_valid[0x8000] = {false};

    // Phase 4: Verbose Register Logging
    const uint32_t *words = (const uint32_t *)(ptr + offset);
    int num_words = size_bytes / 4;
    int i = sizeof(ane_header_h16_t) / 4;

    if (i >= num_words) break;

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
        uint32_t mask = (header >> 15) & 0xFFFF;  // 16-bit mask
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
    ane_common_h16_t common;
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
      // M4 Discrete Block Decoding logic below...

      if (reg_valid[9]) {
        printf("        Batch     : B=%u\n", common.num_groups);
      }
      const char *infmt_name = get_ch_fmt_name(common.ch_cfg.infmt);
      const char *outfmt_name = get_ch_fmt_name(common.ch_cfg.outfmt);
      if (reg_valid[1] || reg_valid[2] || reg_valid[3] || reg_valid[4] || reg_valid[0]) {
        printf("        InDim     : W=%u H=%u C=%u D=%u Type=%s\n", common.inwidth, common.inheight,
               common.inchannels, common.indepth, infmt_name);
      }
      if (reg_valid[5] || reg_valid[6] || reg_valid[7] || reg_valid[8] || reg_valid[0]) {
        printf("        OutDim    : W=%u H=%u C=%u D=%u Type=%s\n", common.outwidth,
               common.outheight, common.outchannels, common.outdepth, outfmt_name);
      }

      if (reg_valid[10]) {
        printf("        ConvCfg   : K=%ux%u S=%ux%u P=%ux%u O=%ux%u\n", common.conv_cfg.kw,
               common.conv_cfg.kh, common.conv_cfg.sx, common.conv_cfg.sy, common.conv_cfg.pad_left,
               common.conv_cfg.pad_top, common.conv_cfg.ox, common.conv_cfg.oy);
      }

      if (reg_valid[13]) {
        printf("        TileHeight: %u\n", common.tile_height);
      }

      if (reg_valid[17]) {
        printf("        PatchCfg  : %ux%u\n", common.patch_cfg.patch_width,
               common.patch_cfg.patch_height);
      }

      if (reg_valid[11]) {
        printf("        ConvCfg3D : 0x%08x\n", common.conv_cfg_3d);
      }

      if (reg_valid[12]) {
        printf("        UnicastCfg: En=%d Cin=%u\n", common.unicast_cfg.unicast_en,
               common.unicast_cfg.unicast_cin);
      }

      if (reg_valid[14]) {
        printf("        Overlap   : Skip=%u PadTop=%u PadBottom=%u\n", common.tile_overlap.overlap,
               common.tile_overlap.pad_top, common.tile_overlap.pad_bottom);
      }

      if (reg_valid[15]) {
        printf("        MacCfg    : TaskType=%u ActiveNE=%u SmallSrcMode=%u "
               "L2Barrier=%u OutTrans=%u\n",
               common.maccfg.task_type, common.maccfg.active_ne, common.maccfg.small_src_mode,
               common.maccfg.l2_barrier, common.maccfg.out_trans);
      }
      if (reg_valid[16]) {
        printf("        LaneCfg   : OCGSize=%u\n", common.lane_cfg.ocg_size);
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
        printf("        DPE       : 0x%08x\n", common.dpe);
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
      if (reg_valid[i]) ne_has_valid = true;
    }

    if (ne_has_valid) {
      ane_ne_h16_t ne = *(ane_ne_h16_t *)&reg_values[0x4900 / 4];
      printf("        --- Neural Engine Config ---\n");

      if (reg_valid[0x4900 / 4]) {
        printf("        KernelCfg: Fmt=%s Palettized=%d (%dbit) SparseFmt=%d "
               "AsymQuant=%d\n",
               get_ch_fmt_name(ne.kernel_cfg.kernel_fmt), ne.kernel_cfg.palettized_en,
               ne.kernel_cfg.palettized_bits, ne.kernel_cfg.sparse_fmt,
               ne.kernel_cfg.asym_quant_en);
      }

      if (reg_valid[0x4904 / 4]) {
        printf("        MACCfg: OpMode=%d KernelMode=%d BiasEn=%d Passthrough=%d "
               "MVBiasEn=%d BinaryPoint=%u PostScaleEn=%d NonLinear=%d\n"
               "                PaddingMode=%d MaxPoolMode=%d "
               "arg_output_select=%d "
               "double_int8_en=%d\n",
               ne.mac_cfg.op_mode, ne.mac_cfg.kernel_mode, ne.mac_cfg.ne_bias_en,
               ne.mac_cfg.passthrough_en, ne.mac_cfg.matrix_bias_en, ne.mac_cfg.binary_point,
               ne.mac_cfg.post_scale_en, ne.mac_cfg.non_linear_mode, ne.mac_cfg.padding_mode,
               ne.mac_cfg.max_pool_mode, ne.mac_cfg.arg_output_select, ne.mac_cfg.double_int8_en);
      }

      if (reg_valid[0x4908 / 4]) {
        printf("        MatrixBias: 0x%04x\n", ne.matrix_bias.matrix_vector_bias);
      }

      if (reg_valid[0x490c / 4]) {
        printf("        NEBias: 0x%06x\n", ne.ne_bias.val);
      }

      if (reg_valid[0x4910 / 4]) {
        printf("        PostScale: 0x%06x\n", ne.post_scale.val);
      }

      if (reg_valid[0x4914 / 4]) {
        printf("        RcasConfig: KeyMask=0x%02x CmpBit=%d SenseAxis=%d "
               "SenseBit=%d Mode=%d\n",
               ne.rcas_cfg.key_mask, ne.rcas_cfg.cmp_bit, ne.rcas_cfg.sense_axis,
               ne.rcas_cfg.sense_bit, ne.rcas_cfg.mode);
      }

      if (reg_valid[0x4918 / 4]) {
        printf("        RoundModeCfg: Mode=%d IntegerBits=%d\n", ne.st_round_cfg.round_mode,
               ne.st_round_cfg.integer_bits);
      }

      if (reg_valid[0x491c / 4]) {
        printf("        SRSeeds: 0x%08x 0x%08x 0x%08x 0x%08x\n", ne.st_round_seed[0],
               ne.st_round_seed[1], ne.st_round_seed[2], ne.st_round_seed[3]);
      }

      if (reg_valid[0x492c / 4]) {
        printf("        QuantZeroPoint: %d\n", ne.quant.quant_zero_point);
      }
    }

    // Decode 0x4500 PE Block
    bool pe_has_valid = false;
    for (int i = 0x4500 / 4; i < 0x4500 / 4 + 25; i++) {
      if (reg_valid[i]) pe_has_valid = true;
    }

    if (pe_has_valid) {
      ane_pe_h16_t pe = *(ane_pe_h16_t *)&reg_values[0x4500 / 4];
      printf("        --- Planar Engine Config ---\n");

      if (reg_valid[0x4500 / 4]) {
        printf("        PEConfig: Op=%d Cond=%d Src1=%d Src2=%d\n", pe.pe_cfg.op, pe.pe_cfg.cond,
               pe.pe_cfg.src1, pe.pe_cfg.src2);
      }
      if (reg_valid[0x4504 / 4])
        printf("        PEBias   : 0x%05x (%f)\n", pe.bias & 0x7FFFF, decode_f19(pe.bias));
      if (reg_valid[0x4508 / 4])
        printf("        PEScale  : 0x%05x (%f)\n", pe.scale & 0x7FFFF, decode_f19(pe.scale));
      if (reg_valid[0x450c / 4])
        printf("        PEFScale : 0x%05x (%f)\n", pe.final_scale & 0x7FFFF,
               decode_f19(pe.final_scale));
      if (reg_valid[0x4510 / 4])
        printf("        PEPScale : 0x%05x (%f)\n", pe.pre_scale & 0x7FFFF,
               decode_f19(pe.pre_scale));
      if (reg_valid[0x4514 / 4])
        printf("        PEFScale2: 0x%05x (%f)\n", pe.final_scale2 & 0x7FFFF,
               decode_f19(pe.final_scale2));
      if (reg_valid[0x4538 / 4]) {
        printf("        PEQuant: InReLU=%d OutReLU=%d ZeroPoint=%d\n", pe.quant.input_relu,
               pe.quant.output_relu, pe.quant.zero_point);
      }
    }

    // Decode 0x4100 L2 Block (41 registers)
    bool l2_has_valid = false;
    for (int i = 0x4100 / 4; i < 0x4100 / 4 + 41; i++) {
      if (reg_valid[i]) l2_has_valid = true;
    }

    if (l2_has_valid) {
      ane_l2_h16_t l2 = *(ane_l2_h16_t *)&reg_values[0x4100 / 4];
      printf("        --- L2 Cache Control ---\n");

      if (reg_valid[0x4100 / 4]) {
        printf("        L2Control: Padding=%d Src1FIFO=%d Src1Double=%d "
               "Barrier=%d\n",
               l2.l2_control.padding_mode, l2.l2_control.src1_fifo, l2.l2_control.src1_double,
               l2.l2_control.barrier);
      }
      if (reg_valid[0x4104 / 4]) {
        printf("        Src1Cfg  : Type=%d DmaFmt=%d Interleave=%d OffY=%d "
               "Comp=%d\n",
               l2.src1_cfg.src_type, l2.src1_cfg.dma_fmt, l2.src1_cfg.interleave,
               l2.src1_cfg.offset_y_lsbs, l2.src1_cfg.compression);
      }
      if (reg_valid[0x4108 / 4]) {
        printf("        Src2Cfg  : Type=%d Interleave=%d Comp=%d\n", l2.src2_cfg.src_type,
               l2.src2_cfg.interleave, l2.src2_cfg.compression);
      }
      if (reg_valid[0x4110 / 4]) {
        printf("        Src1  : BaseAddr=0x%05x CStride=0x%05x "
               "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
               l2.src1.base, l2.src1.channel_stride, l2.src1.row_stride, l2.src1.depth_stride,
               l2.src1.group_stride);
      }
      if (reg_valid[0x4124 / 4]) {
        printf("        Src2  : BaseAddr=0x%05x CStride=0x%05x "
               "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
               l2.src2.base, l2.src2.channel_stride, l2.src2.row_stride, l2.src2.depth_stride,
               l2.src2.group_stride);
      }
      if (reg_valid[0x4138 / 4]) {
        printf("        SrcIdx: BaseAddr=0x%05x CStride=0x%05x "
               "DStride=0x%05x GStride=0x%05x\n",
               l2.srcidx.base, l2.srcidx.channel_stride, l2.srcidx.depth_stride,
               l2.srcidx.group_stride);
      }
      if (reg_valid[0x4148 / 4]) {
        printf("        ResCfg: BfrMode=%d CropX=%d Interleave=%d Type=%d "
               "Comp=%d\n",
               l2.result_cfg.bfr_mode, l2.result_cfg.crop_offset_x, l2.result_cfg.interleave,
               l2.result_cfg.res_type, l2.result_cfg.compression);
      }
      if (reg_valid[0x414c / 4]) {
        printf("        Result: BaseAddr=0x%05x CStride=0x%05x "
               "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
               l2.result.base, l2.result.channel_stride, l2.result.row_stride,
               l2.result.depth_stride, l2.result.group_stride);
      }
      if (reg_valid[0x417c / 4]) {
        printf("        Res2 / L2Wr: BaseAddr=0x%05x CStride=0x%05x "
               "RStride=0x%05x DStride=0x%05x GStride=0x%05x\n",
               l2.result2.base, l2.result2.channel_stride, l2.result2.row_stride,
               l2.result2.depth_stride, l2.result2.group_stride);
      }
      if (reg_valid[0x4174 / 4]) {
        printf("        ResultWrap: Index=0x%x StartOffset=0x%x\n",
               l2.result_wrap_idx_off.wrap_index, l2.result_wrap_idx_off.wrap_start_offset);
      }
      if (reg_valid[0x419c / 4]) {
        printf("        ResultWrap: Addr=0x%x AddrOffset=0x%x\n", l2.result_wrap_addr.wrap_addr,
               l2.result_wrap_addr.wrap_addr_offset);
      }
    }

    // Decode 0x4D00 TileDMA Source
    bool src_has_valid = false;
    for (int i = 0x4d00 / 4; i < 0x4d00 / 4 + 64; i++) {
      if (reg_valid[i]) src_has_valid = true;
    }
    if (src_has_valid) {
      ane_tiledma_src_h16_t *src = (ane_tiledma_src_h16_t *)&reg_values[0x4d00 / 4];
      printf("        --- TileDMA Source (0x4D00) ---\n");
      if (reg_valid[0x4d00 / 4]) {
        printf("        Src1DMAConfig: En=%d DSID=%u Tag=%u Format=%u\n", src->src1cfg.en,
               src->src1cfg.dataset_id, src->src1cfg.user_tag, src->src1cfg.format);
      }
      if (reg_valid[0x4d04 / 4]) {
        printf("        Src2DMAConfig: En=%d DSID=%u Tag=%u DepMode=%u\n", src->src2cfg.en,
               src->src2cfg.dataset_id, src->src2cfg.user_tag, src->src2cfg.dep_mode);
      }
      if (reg_valid[0x4d18 / 4]) {
        printf("        Src1Strides: RowStride=0x%08x PlaneStride=0x%08x "
               "DepthStride=0x%08x GroupStride=0x%08x\n",
               src->src1rows, src->src1chans, src->src1depths, src->src1groups);
      }
      if (reg_valid[0x4d30 / 4]) {
        printf("        Src2Strides: RowStride=0x%08x PlaneStride=0x%08x "
               "DepthStride=0x%08x GroupStride=0x%08x\n",
               src->src2rows, src->src2chans, src->src2depths, src->src2groups);
      }
      if (reg_valid[0x4d50 / 4]) {
        printf("        Src1MetaData: Addr=0x%08x%08x Size=0x%08x\n", src->src1meta_hi,
               src->src1meta_lo, src->src1meta_size);
      }
      if (reg_valid[0x4d5c / 4]) {
        printf("        Src2MetaData: Addr=0x%08x%08x Size=0x%08x\n", src->src2meta_hi,
               src->src2meta_lo, src->src2meta_size);
      }
      if (reg_valid[0x4d68 / 4]) {
        printf("        Src1Fmt: 0x%08x, Src2Fmt: 0x%08x\n", src->src1memfmt, src->src2memfmt);
      }
    }

    // Decode 0x5100 TileDMA Destination
    bool dst_has_valid = false;
    for (int i = 0x5100 / 4; i < 0x5100 / 4 + 32; i++) {
      if (reg_valid[i]) dst_has_valid = true;
    }
    if (dst_has_valid) {
      ane_tiledma_dst_h16_t *dst = (ane_tiledma_dst_h16_t *)&reg_values[0x5100 / 4];
      printf("        --- TileDMA Destination (0x5100) ---\n");
      if (reg_valid[0x5100 / 4]) {
        printf("        DstDMAConfig: En=%d CacheHint=%u DSID=%u Tag=%u\n", dst->dstcfg.en,
               dst->dstcfg.cache_hint, dst->dstcfg.dataset_id, dst->dstcfg.user_tag);
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
      if (reg_valid[i]) kernel_has_valid = true;
    }
    if (kernel_has_valid) {
      ane_kerneldma_src_h16_t *k = (ane_kerneldma_src_h16_t *)&reg_values[0x5500 / 4];
      printf("        --- KernelDMA Source (0x5500) ---\n");
      if (reg_valid[0x5500 / 4]) {
        printf("        MasterConfig: MasterEnable=%d\n", k->master_cfg.master_enable);
      }
      for (int i = 0; i < 16; i++) {
        if (reg_valid[0x5520 / 4 + i] || reg_valid[0x5560 / 4 + i]) {
          printf("        Coeff[%d]: En=%d CacheHint=%u DSID=%u Tag=%u "
                 "Base=0x%08x "
                 "Size=0x%08x\n",
                 i, k->coeff_cfg[i].en, k->coeff_cfg[i].cache_hint, k->coeff_cfg[i].dataset_id,
                 k->coeff_cfg[i].user_tag, k->coeff_base[i], k->coeff_size[i]);
        }
      }
      if (reg_valid[0x55e0 / 4]) {
        printf("        Bias: En=%d CacheHint=%u Tag=%u\n", k->bias_cfg.en, k->bias_cfg.cache_hint,
               k->bias_cfg.user_tag);
      }
      if (reg_valid[0x55f0 / 4]) {
        printf("        PostScale: En=%d CacheHint=%u Tag=%u\n", k->post_scale_cfg.en,
               k->post_scale_cfg.cache_hint, k->post_scale_cfg.user_tag);
      }
      if (reg_valid[0x5600 / 4]) {
        printf("        Palette: En=%d CacheHint=%u Tag=%u\n", k->palette_cfg.en,
               k->palette_cfg.cache_hint, k->palette_cfg.user_tag);
      }
      if (reg_valid[0x5610 / 4]) {
        printf("        NonLinear: En=%d CacheHint=%u Tag=%u\n", k->non_linear_cfg.en,
               k->non_linear_cfg.cache_hint, k->non_linear_cfg.user_tag);
      }
    }

    if (1) {  // Dump key M4 registers mapped to discrete blocks
      printf("        --- HW Block Register State ---\n");  // Decode 0x5900
                                                            // CacheDMA & Telemetry
      bool cdma_has_valid = false;
      for (int i = 0x5900 / 4; i < 0x5900 / 4 + 13; i++) {
        if (reg_valid[i]) cdma_has_valid = true;
      }
      if (cdma_has_valid) {
        ane_cachedma_h16_t cdma = *(ane_cachedma_h16_t *)&reg_values[0x5900 / 4];
        printf("        --- CacheDMA & Telemetry (0x5900) ---\n");
        if (reg_valid[0x5900 / 4]) {
          printf("        Control: Flush=%d En=%d TaskSync=0x%x ET=0x%x FL=%d "
                 "Thresh=0x%04x\n",
                 cdma.control.flush, cdma.control.enable, cdma.control.task_sync,
                 cdma.control.early_term, cdma.control.footprint_limiter,
                 cdma.control.footprint_threshold);
        }
        if (reg_valid[0x5904 / 4]) {
          printf("        Pre0: BWLimit=%u Sieve2=%u AgeOut=%u\n", cdma.pre0.bandwidth_limit,
                 cdma.pre0.sieve2, cdma.pre0.telemetry_age_out);
        }
        if (reg_valid[0x5908 / 4]) {
          printf("        Pre1: Sieve1=%u\n", cdma.pre1.sieve1);
        }
        if (reg_valid[0x5918 / 4]) {
          printf("        DSID: DSID_Size=0x%x\n", cdma.dsid.dsid_and_size);
        }
        if (reg_valid[0x591c / 4]) {
          printf("        Footprint: Arg2=0x%x\n", cdma.footprint_arg.footprint_arg2);
        }
        if (reg_valid[0x5920 / 4]) {
          printf("        ET_Args12: Arg1=0x%04x Arg2=0x%04x\n", cdma.early_term_arg12.arg1,
                 cdma.early_term_arg12.arg2);
        }
        if (reg_valid[0x5924 / 4]) {
          printf("        Flush: Arg=0x%04x\n", cdma.flush_reg.flush_arg);
        }
        if (reg_valid[0x5928 / 4]) {
          printf("        ET_Args34: Arg3=0x%02x Arg4=0x%02x\n", cdma.early_term_arg34.arg3,
                 cdma.early_term_arg34.arg4);
        }
        if (reg_valid[0x592c / 4]) {
          printf("        BackOff: En=%d Delay=%u Min=%u Max=%u Scale=%u\n", cdma.backoff.enable,
                 cdma.backoff.delay, cdma.backoff.min, cdma.backoff.max, cdma.backoff.scale);
        }
      }

      hwx_block_info_t blocks[] = {
          {"[0x0000] Common Module", 0x0000},      {"[0x4100] L2 Cache Control", 0x4100},
          {"[0x4500] Planar Engine (PE)", 0x4500}, {"[0x4900] Neural Engine Core (NE)", 0x4900},
          {"[0x4D00] TileDMA Source", 0x4D00},     {"[0x5100] TileDMA Destination", 0x5100},
          {"[0x5500] KernelDMA Source", 0x5500},   {"[0x5900] CacheDMA & Telemetry", 0x5900},
      };

      dump_hw_blocks(reg_values, reg_valid, blocks, 8, get_m4_reg_name);
    }

    if (offset + size_bytes > total_len) break;

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
      return "LC_ANE_MAPPED_REGION";  // Mapped region based on ANECompiler 'Zin'
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

  const struct mach_header_64 *header = (const struct mach_header_64 *)data.bytes;

  uint32_t magic = header->magic;
  if (magic != HWX_MAGIC) {
    printf("Error: Invalid magic 0x%08x (Expected 0x%08x)\n", magic, HWX_MAGIC);
    return;
  }
  printf("Magic verified: 0x%08x\n", magic);

  if (data.length < 32) return;

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

    const struct load_command *lc = (const struct load_command *)(data.bytes + offset);
    const char *cmd_name = get_cmd_name(lc->cmd);

    printf("\nLoad Command %u:\n", i);
    printf("  Cmd: 0x%x (%s)\n", lc->cmd, cmd_name);
    printf("  Size: %u\n", lc->cmdsize);

    if (lc->cmd == LC_SEGMENT_64) {
      if (offset + sizeof(struct segment_command_64) <= data.length) {
        const struct segment_command_64 *seg = (const struct segment_command_64 *)lc;
        printf("  Segment Name: %s\n", seg->segname);
        printf("  VM Addr: 0x%llx\n", seg->vmaddr);
        printf("  VM Size: 0x%llx\n", seg->vmsize);
        printf("  File Off: 0x%llx\n", seg->fileoff);
        printf("  File Size: 0x%llx\n", seg->filesize);
        printf("  Num Sections: %u\n", seg->nsects);

        const struct section_64 *sect =
            (const struct section_64 *)(data.bytes + offset + sizeof(struct segment_command_64));
        for (uint32_t j = 0; j < seg->nsects; j++) {
          if ((uintptr_t)(sect + 1) > (uintptr_t)(data.bytes + data.length)) break;
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

              if (strcmp(sect->sectname, "__text") == 0 || strcmp(sect->sectname, "__TEXT") == 0) {
                uint32_t instr_ver = get_instruction_set_version(header->cpusubtype);
                if (instr_ver >= 11) {
                  // v11+ Dense format (Burst/Scatter)
                  decode_ane_td_m4(section_ptr, section_size, header->cpusubtype);
                } else {
                  // v7- and similar (Stream format)
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

          const struct nlist_64 *list = (const struct nlist_64 *)(data.bytes + sym->symoff);
          const char *strtab = (const char *)(data.bytes + sym->stroff);

          for (uint32_t k = 0; k < max_syms; k++) {
            if ((uintptr_t)(list + 1) > (uintptr_t)(data.bytes + data.length)) break;
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
          const uint32_t *content = (const uint32_t *)((const uint8_t *)lc + internal_offset);
          uint32_t flavor = content[0];
          uint32_t count = content[1];
          printf("  Flavor Set %u: Flavor=%u Count=%u\n", flavor_idx++, flavor, count);

          internal_offset += 8;
          const uint32_t *state = content + 2;
          printf("    State:\n");
          for (uint32_t k = 0; k < count; k++) {
            if (internal_offset + 4 > lc->cmdsize) break;
            if (k % 4 == 0) printf("      [%03u]:", k);
            printf(" 0x%08x", state[k]);
            if (k % 4 == 3 || k == count - 1) printf("\n");
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
