#ifndef ANE_HWX_REGS_H
#define ANE_HWX_REGS_H

#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdbool.h>

#define HWX_MAGIC 0xbeefface
#define LC_ANE_MAPPED_REGION 0x40

#define HW_MAX_REGS 0x20000

// Architecture block start addresses
#define H13_COMMON_START 0x0000
#define H13_L2_START 0x4800
#define H13_PE_START 0x8800
#define H13_NE_START 0xC800
#define H13_TILEDMA_SRC_START 0x13800
#define H13_TILEDMA_DST_START 0x17800
#define H13_KERNELDMA_START 0x1F800

#define H16_COMMON_START 0x0000
#define H16_L2_START 0x4100
#define H16_PE_START 0x4500
#define H16_NE_START 0x4900
#define H16_TILEDMA_SRC_START 0x4D00
#define H16_TILEDMA_DST_START 0x5100
#define H16_KERNELDMA_START 0x5500
#define H16_CACHEDMA_START 0x5900
#define H16_PE_EXT_START 0x44D0

typedef struct {
  uint32_t values[HW_MAX_REGS];
  bool valid[HW_MAX_REGS];
  uint32_t subtype;
  uint32_t instr_ver;
} hwx_state_t;

typedef struct __attribute__((packed)) {
  uint16_t tid;     // 0x000
  uint8_t nid;      // 0x002
  uint8_t lnid : 1; // 0x003 bit 0
  uint8_t eon : 1;  // 0x003 bit 1
  uint8_t pad0 : 6;
  uint16_t exe_cycles;    // 0x004
  uint16_t next_size : 9; // 0x006 bits 0-8
  uint16_t pad1 : 7;
  uint32_t log_events : 24; // 0x008
  uint32_t pad2 : 8;
  uint32_t exceptions : 24; // 0x00c
  uint32_t pad3 : 8;
  uint32_t debug_log_events : 24; // 0x010
  uint32_t pad4 : 8;
  uint32_t debug_exceptions : 24; // 0x014
  uint32_t pad5 : 8;
  struct {
    uint32_t tq_dis : 1; // bit 0
    uint32_t pad0 : 1;
    uint32_t dst_loc : 1; // bit 2
    uint32_t src_loc : 1; // bit 3
    uint32_t pad1 : 3;
    uint32_t tde : 1; // bit 7
    uint32_t pad2 : 2;
    uint32_t next_priority : 6;  // bits 10-15
    uint32_t tse : 1;            // bit 16
    uint32_t dpc : 1;            // bit 17
    uint32_t spc : 1;            // bit 18
    uint32_t tsr : 1;            // bit 19
    uint32_t spl : 1;            // bit 20
    uint32_t kpc : 1;            // bit 21
    uint32_t td_skip : 1;        // bit 22
    uint32_t disallow_abort : 1; // bit 23
    uint32_t pad3 : 8;
  } flags;               // 0x018
  uint32_t next_pointer; // 0x01c
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
  } base_ene; // 0x020
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
  } kbase; // 0x024
} ane_header_h13_t;

typedef struct __attribute__((packed)) {
  uint16_t tid;             // 0x000 (Header[0] 0-15)
  uint32_t task_size : 11;  // 0x002 bits 0-10 (Header[0] 16-26)
  uint32_t pad0 : 5;        // 0x002 bits 11-15 (Header[0] 27-31)
  uint16_t exe_cycles;      // 0x004 (Header[1] 0-15)
  uint16_t pad1;
  uint32_t log_events : 24; // 0x008 (Header[2])
  uint32_t pad2 : 8;
  uint32_t exceptions : 24; // 0x00c (Header[3])
  uint32_t pad3 : 8;
  uint32_t debug_log_events : 24; // 0x010 (Header[4])
  uint32_t pad4 : 8;
  uint32_t debug_exceptions : 24; // 0x014 (Header[5])
  uint32_t pad5 : 8;
  uint32_t live_outs : 24;  // 0x018 (Header[6] 0-23)
  uint32_t pad_lo : 8;
  uint32_t unknown_flags;   // 0x01c (Header[7])
  struct {
    uint32_t tsr : 1;       // 0x020 bit 0
    uint32_t tde : 1;       // 0x020 bit 1
    uint32_t pad : 1;       // 0x020 bit 2
    uint32_t unknown : 1;   // 0x020 bit 3
    uint32_t pad0 : 12;     // 0x020 bits 4-15
    uint32_t ene : 3;       // 0x020 bits 16-18
    uint32_t pad1 : 13;     // 0x020 bits 19-31
  } ctrl_flags;             // 0x020 (Header[8])
  uint16_t dtid;            // 0x024 (Header[9] 0-15)
  uint16_t pad8;
} ane_header_h16_t;

typedef struct __attribute__((packed)) {
  // Word 0 (0x000)
  struct {
    uint32_t infmt : 2;     // [1:0]
    uint32_t src2infmt : 2; // [3:2]
    uint32_t outfmt : 2;    // [5:4]
    uint32_t pad0 : 26;
  } ch_cfg;

  // Word 1-8
  uint32_t inwidth : 17;     // Word 1
  uint32_t inwidth_pad : 15;
  uint32_t inheight : 17;    // Word 2
  uint32_t inheight_pad : 15;
  uint32_t inchannels : 17;  // Word 3
  uint32_t inchannels_pad : 15;
  uint32_t indepth : 17;     // Word 4
  uint32_t indepth_pad : 15;
  uint32_t outwidth : 17;    // Word 5
  uint32_t outwidth_pad : 15;
  uint32_t outheight : 17;   // Word 6
  uint32_t outheight_pad : 15;
  uint32_t outchannels : 17; // Word 7
  uint32_t outchannels_pad : 15;
  uint32_t outdepth : 17;    // Word 8
  uint32_t outdepth_pad : 15;

  // Word 9 (0x024)
  uint32_t num_groups : 17;
  uint32_t num_groups_pad : 15;

  // Word 10 (0x028)
  struct {
    uint32_t kw : 6;       // [5:0] (H16: Kw-1)
    uint32_t kh : 6;       // [11:6] (H16: Kh-1)
    uint32_t pad0 : 1;     // [12]
    uint32_t sx : 2;       // [14:13] (H16: Sx-1)
    uint32_t sy : 2;       // [16:15] (H16: Sy-1)
    uint32_t pad_left : 5; // [21:17]
    uint32_t pad_top : 5;  // [26:22]
    uint32_t pad1 : 1;     // [27]
    uint32_t ox : 2;       // [29:28] (H16: Ox-1)
    uint32_t oy : 2;       // [31:30] (H16: Oy-1)
  } conv_cfg;

  // Word 11 (0x02C)
  struct {
    uint32_t kd : 5;    // [4:0] (H16: Kd-1)
    uint32_t sz : 3;    // [7:5] (H16: Sz-1)
    uint32_t pz : 3;    // [10:8]
    uint32_t oz : 3;    // [13:11]
    uint32_t pad0 : 18;
  } conv_cfg_3d;

  // Word 12 (0x030)
  struct {
    uint32_t pad0 : 14;        // [13:0]
    uint32_t unicast_en : 1;   // [14]
    uint32_t pad1 : 1;         // [15]
    uint32_t unicast_cin : 16; // [31:16]
  } unicast_cfg;

  // Word 13 (0x034)
  uint32_t tile_height : 17;
  uint32_t tile_height_pad : 15;

  // Word 14 (0x038)
  struct tile_overlap_h16_s {
    uint32_t pad0 : 16;      // [15:0]
    uint32_t overlap : 5;    // [20:16]
    uint32_t pad_top : 5;    // [25:21]
    uint32_t pad_bottom : 5; // [30:26]
    uint32_t pad1 : 1;       // [31]
  } tile_overlap;

  // Word 15 (0x03C)
  struct maccfg_h16_s {
    uint32_t pad0 : 4;
    uint32_t task_type : 4;       // [7:4]
    uint32_t pad1 : 11;
    uint32_t active_ne : 3;       // [21:19]
    uint32_t pad2 : 2;            // [23:22]
    uint32_t relu_type : 4;       // [27:24]
    uint32_t out_trans : 1;       // [28] (Verified via binary)
    uint32_t fill_lower_ne : 1;   // [29]
    uint32_t pad4 : 2;
  } maccfg;

  // Word 16 (0x40)
  struct ne_cfg_h16_s {
    uint32_t ocg_size : 3;        // [2:0]
    uint32_t fat_tile_en : 1;     // [3]
    uint32_t wustack_log2 : 2;    // [5:4]
    uint32_t pad0 : 26;
  } ne_cfg;

  // Word 17 (0x044)
  struct patch_cfg_h16_s {
    uint32_t patch_width : 4;
    uint32_t patch_height : 5;
    uint32_t pad0 : 23;
  } patch_cfg;

  // Word 18 (0x048)
  struct pe_cfg_common_h16_s {
    uint32_t src1_br : 4;   // [3:0] (W:0, H:1, D:2, C:3)
    uint32_t src2_br : 4;   // [7:4] (W:4, H:5, D:6, C:7)
    uint32_t src1_trans : 1; // [8]
    uint32_t src2_trans : 1; // [9]
    uint32_t out_trans : 1;  // [10] (Verified via binary)
    uint32_t pad0 : 21;
  } pe_cfg; // Word 18 (0x048)

  uint32_t nid;    // 0x04C (Word 19)
  uint32_t dpe;    // 0x050 (Word 20)
  uint32_t val_21; // 0x054 (Word 21)
  uint32_t val_22; // 0x058 (Word 22)
} ane_common_h16_t;

typedef struct {
  uint32_t startAddr;
  uint32_t count;
  const char **names;
} hwx_reg_range_t;

typedef struct {
  const char *name;
  uint32_t startAddr;
  uint32_t count;
} hwx_block_info_t;

// [0x5500] KernelDMA Source Block
typedef struct {
  struct {
    uint32_t pad0 : 4;          // [3:0]
    uint32_t group_kernel_reuse : 1; // [4]
    uint32_t kernel_sparse_fmt : 1; // [5]
    uint32_t master_enable : 1; // [6]
    uint32_t pad1 : 25;
  } master_cfg;      // Word 0 (0x5500)
  
  uint32_t aligned_coeff_size_per_ch; // Word 1 (0x5504) - bits 0-27

  struct {
    uint32_t early_term_en : 1; // [0]
    uint32_t stop_on_error : 1; // [1]
    uint32_t pad0 : 14;         // [15:2]
    uint32_t prefetch_rate : 16; // [31:16]
  } prefetch; // Word 2 (0x5508)

  uint32_t res_550c_5514[3]; // Word 3-5

  uint32_t kernel_group_stride; // Word 6 (0x5518) - bits 6-31
  uint32_t kernel_ocg_stride;   // Word 7 (0x551C) - bits 6-31

  struct {
    uint32_t en : 1;             // [0]
    uint32_t pad0 : 7;           // [7:1]
    uint32_t dataset_id : 8;     // [15:8]
    uint32_t user_tag : 8;       // [23:16]
    uint32_t pad1 : 8;
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

  uint32_t pad3[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } post_scale_cfg; // Word 60 (0x55F0)

  uint32_t pad4[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } palette_cfg; // Word 64 (0x5600)

  uint32_t pad5[3];

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t pad1 : 8;
    uint32_t user_tag : 8;
    uint32_t pad2 : 8;
  } non_linear_cfg; // Word 68 (0x5610)

  uint32_t pad6[3]; // Word 69-71
} __attribute__((packed)) ane_kerneldmasrc_h16_t;

typedef struct {
  struct {
    uint32_t flush : 1;                // Bit 0
    uint32_t enable : 1;               // Bit 1
    uint32_t task_sync : 2;            // Bits 2-3 (WaitPrev:3, PostDone:2)
    uint32_t early_term : 5;           // Bits 4-8
    uint32_t footprint_limiter : 1;    // Bit 9
    uint32_t pad1 : 6;                 // Bits 10-15
    uint32_t footprint_threshold : 16; // Bits 16-31
  } control;                           // 0x5900 (Word 0)

  struct {
    uint32_t bandwidth_limit : 10;  // Bits 0-9
    uint32_t pad0 : 6;              // Bits 10-15
    uint32_t sieve2 : 4;            // Bits 16-19
    uint32_t telemetry_age_out : 4; // Bits 20-23
    uint32_t pad1 : 8;              // Bits 24-31
  } pre0;                           // 0x5904 (Word 1)

  struct {
    uint32_t sieve1 : 14; // Bits 0-13
    uint32_t pad0 : 18;   // Bits 14-31
  } pre1;                 // 0x5908 (Word 2)

  uint32_t pad0[3]; // 0x590c, 0x5910, 0x5914

  struct {
    uint32_t pad0 : 7;           // Bits 0-6
    uint32_t dsid_and_size : 23; // Bits 7-29
    uint32_t pad1 : 2;           // Bits 30-31
  } dsid;                        // 0x5918 (Word 6)

  struct {
    uint32_t pad0 : 17;           // Bits 0-16
    uint32_t footprint_arg2 : 11; // Bits 17-27
    uint32_t pad1 : 4;            // Bits 28-31
  } footprint_arg;                // 0x591c (Word 7)

  struct {
    uint16_t arg1;    // Bits 0-15 (Half)
    uint16_t arg2;    // Bits 16-31 (Half)
  } early_term_arg12; // 0x5920 (Word 8)

  struct {
    uint16_t flush_arg; // Bits 0-15 (Half)
    uint16_t pad0;      // Bits 16-31
  } flush_reg;          // 0x5924 (Word 9)

  struct {
    uint8_t arg3;     // Bits 0-7 (Byte)
    uint8_t pad0;     // Bits 8-15
    uint8_t arg4;     // Bits 16-23 (Byte)
    uint8_t pad1;     // Bits 24-31
  } early_term_arg34; // 0x5928 (Word 10)

  struct {
    uint32_t enable : 1; // Bit 0
    uint32_t pad0 : 3;   // Bits 1-3
    uint32_t delay : 4;  // Bits 4-7
    uint32_t min : 8;    // Bits 8-15
    uint32_t max : 8;    // Bits 16-23
    uint32_t scale : 8;  // Bits 24-31
  } backoff;             // 0x592c (Word 11)
} __attribute__((packed)) ane_cachedma_h16_t;

// [0x4D00] TileDMA Source Block
typedef struct {
  struct {
    uint32_t enable : 1;             // [0]
    uint32_t res1 : 4;               // [1:4]
    uint32_t dsid_cache_hint : 3;    // [5:7] (dataset_id/cache_hint)
    uint32_t dataset_id : 8;         // [8:15]
    uint32_t user_tag : 8;           // [16:23]
    uint32_t dependency_interval : 4; // [24:27]
    uint32_t dependency_mode : 2;     // [28:29]
    uint32_t pad1 : 2;               // [30:31]
  } dmacfg[2]; // Words 0, 1 (Src1, Src2)

  struct {
    uint32_t cache_hint : 8; // (strb hint?)
    uint32_t wrap_cfg_dim : 3;
    uint32_t pad0 : 5;
    uint32_t wrap_static : 16;
  } wrapcfg[2]; // Words 2, 3 (Src1, Src2)

  struct {
    uint32_t base_lo;
    uint32_t base_hi;
    uint32_t row_stride;
    uint32_t plane_stride;
    uint32_t depth_stride;
    uint32_t group_stride;
  } strides[2]; // Words 4-9 (Src1), 10-15 (Src2)

  // Flatter structure for metadata (Words 16-25)
  uint32_t src1_meta_addr_lo; // Word 16
  uint32_t src1_meta_addr_hi; // Word 17
  uint32_t src2_meta_addr_lo; // Word 18
  uint32_t src2_meta_addr_hi; // Word 19
  uint32_t src1_meta_cfg;     // Word 20
  uint32_t src1_meta_unk1;    // Word 21
  uint32_t src1_meta_size;    // Word 22
  uint32_t src2_meta_cfg;     // Word 23
  uint32_t src2_meta_unk1;    // Word 24
  uint32_t src2_meta_size;    // Word 25

  struct {
    uint32_t format_mode : 2;    // [0:1]
    uint32_t res1 : 2;           // [2:3]
    uint32_t trunc : 3;          // [4:6]
    uint32_t res2 : 1;           // [7]
    uint32_t shift : 4;          // [8:11]
    uint32_t mem_fmt : 2;        // [12:13]
    uint32_t res3 : 2;           // [14:15]
    uint32_t offset_ch : 3;      // [16:18]
    uint32_t res4 : 5;           // [19:23]
    uint32_t interleave : 4;     // [24:27]
    uint32_t cmp_vec : 4;        // [28:31]
  } fmt[2]; // Words 26, 27 (Src1, Src2)

  uint32_t res_4d70_74[2]; // Words 28-29

  struct {
    uint32_t compressed_enable : 1; // [0]
    uint32_t pad0 : 1;
    uint32_t macroblock_size : 1;   // [2]
    uint32_t pad1 : 1;
    uint32_t packing_format : 6;    // [9:4]
    uint32_t pad2 : 3;
    uint32_t lossy_mode : 1;        // [13]
    uint32_t pad3 : 10;
    uint32_t md_user_tag : 8;       // [31:24]
  } compinfo[2];    // Words 30 (Src1), 34 (Src2)
  
  uint32_t compsize_lo[2]; // Word 31, 35
  uint32_t compsize_hi[2]; // Word 32, 36
  uint32_t cropoffset[2];  // Word 33, 37

  uint32_t res_4d98_b4[8]; // Words 38-45

  uint32_t wrapdynamic[2];      // Words 46, 47
  uint32_t dependencyoffset[2]; // Words 48, 49

  uint32_t texture_config;      // Word 50
  uint32_t texture_idx_permute; // Word 51
  uint32_t texture_src_permute; // Word 52
  uint32_t texture_background_val; // Word 53

  uint32_t texture_ext_max_dim1;   // Word 54
  uint32_t texture_ext_max_dim2;   // Word 55
  uint32_t texture_ext_max_dim3;   // Word 56
  
  uint32_t texture_crop_batch_split_dim1; // Word 57
  uint32_t texture_crop_depth_dim1;       // Word 58
  uint32_t texture_crop_batch_split_dim2; // Word 59

  uint32_t res_4df0_f4[2]; // Word 60-61
  uint32_t src1ephemeral;  // Word 62 (bits [0]: enable)
  uint32_t res_4dfc_e00[2]; // Word 63-64
  uint32_t texture_crop_coeff_val; // Word 65
  
  uint32_t pad3[15]; // Word 66-80
} __attribute__((packed)) ane_tiledmasrc_h16_t;

// [0x5100] TileDma Destination Block
typedef struct {
  struct {
    uint32_t en : 1;             // [0]
    uint32_t pad0 : 7;           // [7:1]
    uint32_t dataset_id : 8;     // [15:8]
    uint32_t user_tag : 8;       // [23:16]
    uint32_t pad1 : 8;
  } dstcfg; // Word 0 (0x5100)

  uint32_t dstpadding; // Word 1 (0x5104)

  uint32_t dstbase_lo; // Word 2 (0x5108)
  uint32_t dstbase_hi; // Word 3 (0x510C)

  uint32_t dstrow_stride;   // Word 4 (0x5110) - 64B units
  uint32_t dstplane_stride;  // Word 5 (0x5114) - 64B units
  uint32_t dstdepth_stride; // Word 6 (0x5118) - 64B units
  uint32_t dstgroup_stride; // Word 7 (0x511C) - 64B units

  uint32_t dstinternalcfg; // Word 8 (0x5120)
  uint32_t pad0;           // Word 9

  uint32_t dstmeta_lo; // Word 10 (0x5128)
  uint32_t dstmeta_hi; // Word 11 (0x512C)
  struct {
    uint32_t format_mode : 2;   // [1:0]
    uint32_t pad0 : 5;
    uint32_t metadata_size : 25; // [31:7]
  } dstfmtmode; // Word 12 (0x5130)

  uint32_t pad1;       // Word 13

  struct {
    uint32_t mode : 2;           // [1:0]
    uint32_t pad0 : 2;
    uint32_t trunc : 3;          // [6:4]
    uint32_t pad1 : 1;
    uint32_t shift : 3;          // [10:8]
    uint32_t pad2 : 1;
    uint32_t mem_fmt : 2;        // [13:12]
    uint32_t pad3 : 2;
    uint32_t offset_ch : 3;      // [18:16]
    uint32_t pad4 : 1;
    uint32_t zero_pad_first : 1; // [20]
    uint32_t zero_pad_last : 1;  // [21]
    uint32_t pad5 : 2;
    uint32_t interleave : 4;     // [27:24]
    uint32_t cmp_vec : 4;        // [31:28]
  } dstfmt; // Word 14 (0x5138)
  uint32_t pad2;          // Word 15
  
  struct {
    uint32_t compressed_enable : 1; // [0]
    uint32_t pad0 : 1;
    uint32_t macroblock_size : 1;   // [2]
    uint32_t pad1 : 1;
    uint32_t packing_format : 6;    // [9:4]
    uint32_t pad2 : 3;
    uint32_t lossy_mode : 1;        // [13]
    uint32_t pad3 : 18;
  } dstcompinfo; // Word 16 (0x5140)

  uint32_t pad3;              // Word 17

  uint32_t dstcompsize_lo; // Word 18 (0x5148)
  uint32_t dstcompsize_hi; // Word 19 (0x514C)

  uint32_t dstpixeloffset; // Word 20 (0x5150)
} __attribute__((packed)) ane_tiledmadst_h16_t;

// [0x4900] Neural Engine (NE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4900)
  struct {
    uint32_t kernel_fmt : 2;         // [1:0]
    uint32_t palettized_en : 1;      // [2]
    uint32_t pad0 : 1;               // [3]
    uint32_t palettized_bits : 4;    // [7:4]
    uint32_t sparse_en : 1;          // [8]
    uint32_t pad1_0 : 1;             // [9]
    uint32_t group_kernel_reuse : 1; // [10]
    uint32_t pad1_1 : 4;             // [14:11]
    uint32_t sparse_binary : 1;      // [15]
    uint32_t kernel_align_fmt : 1;   // [16]
    uint32_t pad2 : 4;               // [20:17]
    uint32_t sparse_block_size : 3;  // [23:21]
    uint32_t asym_quant_en : 1;      // [24]
    uint32_t pad3 : 7;
  } kernel_cfg;

  // Word 1 (0x4904)
  struct {
    uint32_t op_mode : 3;           // [2:0]
    uint32_t kernel_mode : 1;       // [3]
    uint32_t ne_bias_en : 1;        // [4]
    uint32_t passthrough_en : 1;    // [5]
    uint32_t matrix_bias_en : 1;    // [6]
    uint32_t pad0 : 1;              // [7]
    uint32_t binary_point : 6;      // [13:8]
    uint32_t post_scale_en : 1;     // [14]
    uint32_t pad1 : 1;              // [15]
    uint32_t non_linear_mode : 2;   // [17:16]
    uint32_t padding_mode : 1;      // [18]
    uint32_t max_pool_mode : 1;     // [19]
    uint32_t arg_output_select : 4; // [23:20]
    uint32_t pad2 : 2;              // [25:24]
    uint32_t double_int8_en : 1;    // [26]
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
    uint32_t key_mask : 8;   // [7:0]
    uint32_t cmp_bit : 3;    // [10:8]
    uint32_t pad0 : 1;       // [11]
    uint32_t sense_axis : 2; // [13:12]
    uint32_t pad1 : 2;       // [15:14]
    uint32_t sense_bit : 4;  // [19:16]
    uint32_t mode : 1;       // [20]
    uint32_t pad2 : 11;
  } rcas_cfg;

  // Word 6 (0x4918)
  struct {
    uint32_t round_mode : 2;   // [1:0]
    uint32_t pad0 : 2;         // [3:2]
    uint32_t integer_bits : 5; // [8:4]
    uint32_t pad1 : 23;
  } st_round_cfg;

  // Words 7-10 (0x491C, 4920, 4924, 4928)
  uint32_t st_round_seed[4];

  // Word 11 (0x492C)
  struct {
    uint32_t quant_zero_point : 8; // [7:0]
    uint32_t pad0 : 24;
  } quant;

} ane_ne_h16_t;

// [0x4100] L2 Cache Control Block (M4 specific mapping - 41 registers)
typedef struct {
  // Word 0 (0x4100)
  struct {
    uint32_t src1_relu: 1;      // Bit 0: Enable ReLU for Source 1
    uint32_t reserved1: 1;      // Bit 1: Reserved
    uint32_t padding_mode: 2;   // Bits 2-3: 0: Clamp, 1: Zero, 2: Mirror, 3: Constant
    uint32_t src2_relu: 1;      // Bit 4: Enable ReLU for Source 2
    uint32_t reserved2: 11;     // Bits 5-15: Reserved
    uint32_t barrier_enable: 1; // Bit 16: Enable hardware barrier sync
    uint32_t barrier_idx: 7;    // Bits 17-23: Hardware barrier index
    uint32_t reserved3: 8;      // Bits 24-31: Reserved
  } l2_control;

  // Word 1 (0x4104)
  struct {
    uint32_t src_type : 2;          // [1:0]
    uint32_t dependent : 2;         // [3:2]
    uint32_t alias_conv_src : 1;    // [4]
    uint32_t alias_conv_rslt : 1;   // [5]
    uint32_t dma_fmt : 2;           // [7:6]
    uint32_t interleave : 4;        // [11:8]
    uint32_t pad0 : 8;              // [19:12]
    uint32_t alias_planar_src : 1;  // [20]
    uint32_t pad1 : 1;              // [21]
    uint32_t alias_planar_rslt : 1; // [22]
    uint32_t pad2 : 2;              // [24:23]
    uint32_t compression : 2;       // [26:25]
    uint32_t pad3 : 5;              // [31:27]
  } src1_cfg;

  // Word 2 (0x4108) (Src2Cfg)
  struct {
    uint32_t src_type : 2;          // [1:0]
    uint32_t dependent : 2;         // [3:2]
    uint32_t alias_conv_src : 1;    // [4]
    uint32_t alias_conv_rslt : 1;   // [5]
    uint32_t dma_fmt : 2;           // [7:6]
    uint32_t interleave : 4;        // [11:8]
    uint32_t pad0 : 8;              // [19:12]
    uint32_t alias_planar_src : 1;  // [20]
    uint32_t pad1 : 1;              // [21]
    uint32_t alias_planar_rslt : 1; // [22]
    uint32_t pad2 : 2;              // [24:23]
    uint32_t compression : 2;       // [26:25]
    uint32_t pad3 : 5;              // [31:27]
  } src2_cfg;

  // Word 3 (0x410c) (SrcIdxCfg)
  struct {
    uint32_t src_type : 2;          // [1:0]
    uint32_t dependent : 2;         // [3:2]
    uint32_t alias_conv_src : 1;    // [4]
    uint32_t alias_conv_rslt : 1;   // [5]
    uint32_t dma_fmt : 2;           // [7:6]
    uint32_t interleave : 4;        // [11:8]
    uint32_t pad0 : 8;              // [19:12]
    uint32_t alias_planar_src : 1;  // [20]
    uint32_t pad1 : 1;              // [21]
    uint32_t alias_planar_rslt : 1; // [22]
    uint32_t pad2 : 4;              // [26:23]
    uint32_t bit27 : 1;             // [27]
    uint32_t pad3 : 4;              // [31:28]
  } srcidx_cfg;

  // Dense 17-bit packed tensor blocks (Bits 4:20)
  struct {
    uint32_t pad0 : 4;
    uint32_t base : 17;
    uint32_t pad1 : 11;
    uint32_t pad2 : 4;
    uint32_t channel_stride : 17;
    uint32_t pad3 : 11;
    uint32_t pad4 : 4;
    uint32_t row_stride : 17;
    uint32_t pad5 : 11;
    uint32_t pad6 : 4;
    uint32_t depth_stride : 17;
    uint32_t pad7 : 11;
    uint32_t pad8 : 4;
    uint32_t group_stride : 17;
    uint32_t pad9 : 11;
  } src1; // Words 4-8 (0x4110-0x4120)

  struct {
    uint32_t pad0 : 4;
    uint32_t base : 17;
    uint32_t pad1 : 11;
    uint32_t pad2 : 4;
    uint32_t channel_stride : 17;
    uint32_t pad3 : 11;
    uint32_t pad4 : 4;
    uint32_t row_stride : 17;
    uint32_t pad5 : 11;
    uint32_t pad6 : 4;
    uint32_t depth_stride : 17;
    uint32_t pad7 : 11;
    uint32_t pad8 : 4;
    uint32_t group_stride : 17;
    uint32_t pad9 : 11;
  } src2; // Words 9-13

  struct {
    uint32_t pad0 : 4;
    uint32_t base : 17;
    uint32_t pad1 : 11;
    uint32_t pad2 : 4;
    uint32_t channel_stride : 17;
    uint32_t pad3 : 11;
    uint32_t pad4 : 4;
    uint32_t depth_stride : 17;
    uint32_t pad5 : 11;
    uint32_t pad6 : 4;
    uint32_t group_stride : 17;
    uint32_t pad7 : 11;
  } srcidx; // Words 14-17

  // Word 18 (0x4148)
  struct {
    uint32_t res_type : 2;       // [1:0]
    uint32_t pad0 : 1;           // [2]
    uint32_t bfr_mode : 1;       // [3]
    uint32_t src_alias : 1;      // [4]
    uint32_t result_alias : 1;   // [5]
    uint32_t dma_fmt : 2;        // [7:6]
    uint32_t interleave : 4;     // [11:8]
    uint32_t pad1 : 13;          // [24:12]
    uint32_t compression : 2;    // [26:25]
    uint32_t pad2 : 5;           // [31:27]
  } result_cfg;

  // Words 19-23 (0x414c-0x415c)
  struct {
    uint32_t pad0 : 4;
    uint32_t base : 17;
    uint32_t pad1 : 11;
    uint32_t pad2 : 4;
    uint32_t channel_stride : 17;
    uint32_t pad3 : 11;
    uint32_t pad4 : 4;
    uint32_t row_stride : 17;
    uint32_t pad5 : 11;
    uint32_t pad6 : 4;
    uint32_t depth_stride : 17;
    uint32_t pad7 : 11;
    uint32_t pad8 : 4;
    uint32_t group_stride : 17;
    uint32_t pad9 : 11;
  } result; // Words 19-23

  uint32_t l2_res24; // 0x4160
  
  // Words 25-27 (0x4164-0x416c)
  struct {
    uint32_t wrap_num_blocks : 12; // [11:0]
    uint32_t wrap_len : 20;        // [31:12]
  } wrap_cfg[3];

  uint32_t l2_res28; // 0x4170

  // Word 29 (0x4174)
  struct {
    uint32_t wrap_index_mask : 4;  // [3:0]
    uint32_t wrap_start_offset : 12; // [15:4]
    uint32_t pad : 16;
  } result_wrap_idx_off;

  uint32_t l2_res30; // 0x4178

  // Words 31-34 (0x417c-0x4188)
  struct {
    uint32_t pad0 : 4;
    uint32_t base : 17;
    uint32_t pad1 : 11;
    uint32_t pad2 : 4;
    uint32_t channel_stride : 17;
    uint32_t pad3 : 11;
    uint32_t pad4 : 4;
    uint32_t row_stride : 17;
    uint32_t pad5 : 11;
    uint32_t pad6 : 4;
    uint32_t depth_stride : 17;
    uint32_t pad7 : 11;
  } result2; // 0x417c

  // Word 35 (0x418c)
  struct {
    uint32_t max_index : 16;  // [15:0]
    uint32_t mode : 3;        // [18:16]
    uint32_t pad1 : 5;        // [23:19]
    uint32_t broadcast : 2;   // [25:24]
    uint32_t transpose : 1;   // [26]
    uint32_t pad2 : 5;        // [31:27]
  } pe_index_cfg;

  uint32_t l2_res36; // 0x4190
  uint32_t l2_res37; // 0x4194
  uint32_t l2_res38; // 0x4198

  uint32_t wrap_addr; // Word 39 (0x419c)

  struct {
    uint32_t s1x : 6;  // [5:0]
    uint32_t pad0 : 2; // [7:6]
    uint32_t s1y : 5;  // [12:8]
    uint32_t pad1 : 3; // [15:13]
    uint32_t s2x : 6;  // [21:16]
    uint32_t pad2 : 2; // [23:22]
    uint32_t s2y : 5;  // [28:24]
    uint32_t pad3 : 3; // [31:29]
  } crop_tex; // Word 40 (0x41a0)

} __attribute__((packed)) ane_l2_h16_t;

// [0x44D0] PE Extension / Indexing Block
typedef struct {
  struct {
    uint32_t max_index : 16;  // [15:0]
    uint32_t indexing_en : 1; // [16]
    uint32_t pad : 15;
  } pe_index_cfg;
  uint32_t res[11];
} ane_pe_index_h16_t;

// [0x4500] Planar Engine (PE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4500)
  struct {
    uint32_t pool_mode : 2; // [1:0]
    uint32_t op : 3;        // [4:2]
    uint32_t lut_en : 1;    // [5]
    uint32_t cond : 3;      // [8:6]
    uint32_t red_idx : 2;   // [10:9]
    uint32_t red_keep : 1;  // [11]
    uint32_t nl_mode : 2;   // [13:12]
    uint32_t pad0 : 2;      // [15:14]
    uint32_t src1 : 1;      // [16]
    uint32_t pad1 : 1;      // [17]
    uint32_t src2 : 2;      // [19:18]
    uint32_t pad2 : 12;     // [31:20]
  } pe_cfg;

  uint32_t bias;        // Word 1 (0x4504) - F19
  uint32_t scale;       // Word 2 (0x4508) - F19
  uint32_t final_scale_epsilon; // Word 3 (0x450C) - F19
  uint32_t pre_scale;           // Word 4 (0x4510) - F19
  uint32_t final_scale;         // Word 5 (0x4514) - F19
  uint32_t lut[8];              // Words 6-13 (0x4518-0x4534)

  // Word 14 (0x4538)
  struct {
    uint32_t src1_in_off : 8; // [7:0]
    uint32_t src2_in_off : 8; // [15:8]
    uint32_t out_zp : 8;      // [23:16]
    uint32_t pad1 : 8;
  } quant;

  uint32_t res15; // Word 15
} ane_pe_h16_t;

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

} __attribute__((packed)) ane_common_h13_t;

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

} __attribute__((packed)) ane_tiledmasrc_h13_t;

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
  } coeff_dma_config[16]; // 0xc0 - 0xfc

  struct {
    uint32_t pad0 : 6;
    uint32_t addr : 26;
  } coeff_base_addr[16]; // 0x100 - 0x13c

  uint32_t coeff_bfr_size[16]; // 0x140 - 0x17c
} __attribute__((packed)) ane_kerneldmasrc_h13_t;

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

} __attribute__((packed)) ane_tiledmadst_h13_t;

#endif
