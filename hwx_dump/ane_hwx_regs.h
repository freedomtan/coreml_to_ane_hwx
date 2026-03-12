#ifndef ANE_HWX_REGS_H
#define ANE_HWX_REGS_H

#import <Foundation/Foundation.h>

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
  uint16_t dtid;
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
  uint32_t inwidth;     // Word 1
  uint32_t inheight;    // Word 2
  uint32_t inchannels;  // Word 3
  uint32_t indepth;     // Word 4
  uint32_t outwidth;    // Word 5
  uint32_t outheight;   // Word 6
  uint32_t outchannels; // Word 7
  uint32_t outdepth;    // Word 8

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
} hwx_block_info_t;

// [0x5500] KernelDMA Source Block
typedef struct {
  struct {
    uint32_t pad0 : 6;
    uint32_t master_enable : 1; // Bit 6
    uint32_t pad1 : 25;
  } master_cfg;      // Word 0 (0x5500)
  uint32_t reserved1; // Word 1
  uint32_t prefetch; // Word 2 (0x5508)
  uint32_t reserved[3]; // Word 3-5
  uint32_t stridex;  // Word 6 (0x5518)
  uint32_t stridey;  // Word 7 (0x551C)

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
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
    uint32_t en : 1;
    uint32_t pad0 : 7;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t format : 4;
    uint32_t pad1 : 4;
  } src1cfg; // Word 0

  struct {
    uint32_t en : 1;
    uint32_t pad0 : 7;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t pad1 : 4;
    uint32_t dep_mode : 2;
    uint32_t pad2 : 2;
  } src2cfg; // Word 1

  uint32_t src1base_lo; // Word 2
  uint32_t src1base_hi; // Word 3
  uint32_t src2base_lo; // Word 4
  uint32_t src2base_hi; // Word 5

  uint32_t src1row_stride;   // Word 6
  uint32_t src1plane_stride;  // Word 7
  uint32_t src1depth_stride; // Word 8
  uint32_t src1group_stride; // Word 9

  uint32_t src2config;  // Word 10
  uint32_t src2padding; // Word 11

  uint32_t src2row_stride;   // Word 12
  uint32_t src2plane_stride;  // Word 13
  uint32_t src2depth_stride; // Word 14
  uint32_t src2group_stride; // Word 15

  uint32_t src1metadataconfig; // Word 16
  uint32_t pad1[3];            // Word 17-19

  uint32_t src1meta_lo;   // Word 20
  uint32_t src1meta_hi;   // Word 21
  uint32_t src1meta_size; // Word 22
  uint32_t src2meta_lo;   // Word 23
  uint32_t src2meta_hi;   // Word 24
  uint32_t src2meta_size; // Word 25

  uint32_t src1memfmt; // Word 26
  uint32_t src2memfmt; // Word 27

  uint32_t pad2[10];        // Word 28-37
  uint32_t src1pixeloff[4]; // Word 38-41
  uint32_t src2pixeloff[4]; // Word 42-45

  uint32_t pad3[35]; // Word 46-80 (Size 81)
} __attribute__((packed)) ane_tiledmasrc_h16_t;

// [0x5100] TileDma Destination Block
typedef struct {
  struct {
    uint32_t en : 1;
    uint32_t pad0 : 3;
    uint32_t cache_hint : 4;
    uint32_t dataset_id : 8;
    uint32_t user_tag : 8;
    uint32_t pad1 : 8;
  } dstcfg; // Word 0

  uint32_t dstpadding; // Word 1

  uint32_t dstbase_lo; // Word 2
  uint32_t dstbase_hi; // Word 3

  uint32_t dstrow_stride;   // Word 4
  uint32_t dstplane_stride;  // Word 5
  uint32_t dstdepth_stride; // Word 6
  uint32_t dstgroup_stride; // Word 7

  uint32_t dstinternalcfg; // Word 8
  uint32_t pad0;           // Word 9

  uint32_t dstmeta_lo; // Word 10
  uint32_t dstmeta_hi; // Word 11
  uint32_t dstfmtmode; // Word 12
  uint32_t pad1;       // Word 13

  uint32_t dstcompstatus; // Word 14
  uint32_t pad2;          // Word 15

  uint32_t dstcompressioncfg; // Word 16
  uint32_t pad3;              // Word 17

  uint32_t dstcompsize_lo; // Word 18
  uint32_t dstcompsize_hi; // Word 19

  uint32_t dstpixeloffset; // Word 20
} __attribute__((packed)) ane_tiledmadst_h16_t;

// [0x4900] Neural Engine (NE) Block (M4 specific mapping)
typedef struct {
  // Word 0 (0x4900)
  struct {
    uint32_t kernel_fmt : 2;         // [1:0]
    uint32_t palettized_en : 1;      // [2]
    uint32_t pad0 : 1;               // [3]
    uint32_t palettized_bits : 4;    // [7:4]
    uint32_t sparse_fmt : 1;         // [8]
    uint32_t pad1_0 : 1;             // [9]
    uint32_t group_kernel_reuse : 1; // [10]
    uint32_t pad1_1 : 4;             // [14:11]
    uint32_t sparse_binary : 1;      // [15]
    uint32_t alignment_fmt : 1;      // [16]
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
    uint32_t src1_relu : 1;    // [0]
    uint32_t pad0 : 1;         // [1]
    uint32_t padding_mode : 2; // [3:2]
    uint32_t src2_relu : 1;    // [4]
    uint32_t pad1 : 1;
    uint32_t src1_double : 1; // [6]
    uint32_t pad2 : 9;
    uint32_t barrier : 1; // [16]
    uint32_t pad3 : 15;
  } l2_control;

  // Word 1 (0x4104)
  struct {
    uint32_t pad0 : 2;
    uint32_t src_type : 2; // [3:2]
    uint32_t pad1 : 2;
    uint32_t dma_fmt : 2;       // [7:6]
    uint32_t interleave : 4;    // [11:8]
    uint32_t offset_y_lsbs : 4; // [15:12]
    uint32_t pad2 : 9;
    uint32_t compression : 1; // [25]
    uint32_t pad3 : 6;
  } src1_cfg;

  // Word 2 (0x4108)
  struct {
    uint32_t pad0 : 2;
    uint32_t src_type : 2; // [3:2]
    uint32_t pad1 : 4;
    uint32_t interleave : 4; // [11:8]
    uint32_t pad2 : 13;
    uint32_t compression : 1; // [25]
    uint32_t pad3 : 6;
  } src2_cfg;

  uint32_t l2_pad3; // Word 3 (0x410c)

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
  } srcidx; // Words 14-17

  // Word 18 (0x4148)
  struct {
    uint32_t pad0 : 3;
    uint32_t bfr_mode : 1;      // [3]
    uint32_t crop_offset_x : 3; // [6:4]
    uint32_t pad1 : 1;
    uint32_t interleave : 4; // [11:8]
    uint32_t res_type : 2;   // [13:12]
    uint32_t pad2 : 11;
    uint32_t compression : 1; // [25]
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
  } result; // Words 19-23

  uint32_t l2_res24; // 0x4160
  uint32_t l2_res25; // 0x4164 (WrapCfg)
  uint32_t l2_res26; // 0x4168
  uint32_t l2_res27; // 0x416c
  uint32_t l2_res28; // 0x4170

  // Word 29 (0x4174)
  struct {
    uint32_t wrap_index : 16;
    uint32_t wrap_start_offset : 16;
  } result_wrap_idx_off;

  uint32_t l2_res30; // 0x4178

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

  uint32_t l2_res36; // 0x4190
  uint32_t l2_res37; // 0x4194
  uint32_t l2_res38; // 0x4198

  // Word 39 (0x419c)
  struct {
    uint32_t wrap_addr : 12;
    uint32_t pad0 : 4;
    uint32_t wrap_addr_offset : 11;
    uint32_t pad1 : 5;
  } result_wrap_addr;

  uint32_t l2_res40; // 0x41a0

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
    uint32_t op : 6;    // [5:0]
    uint32_t cond : 3;  // [8:6]
    uint32_t pad0 : 7;  // [15:9]
    uint32_t src1 : 1;  // [16]
    uint32_t pad1 : 1;  // [17]
    uint32_t src2 : 2;  // [19:18]
    uint32_t pad2 : 12;
  } pe_cfg;

  uint32_t bias;        // Word 1 (0x4504) - F19
  uint32_t scale;       // Word 2 (0x4508) - F19
  uint32_t res3;        // Word 3 (0x450C)
  uint32_t pre_scale;   // Word 4 (0x4510) - F19
  uint32_t final_scale; // Word 5 (0x4514) - F19
  uint32_t res6[8];     // Words 6-13

  // Word 14 (0x4538)
  struct {
    uint32_t pad0 : 16;
    uint32_t zero_point : 8; // [23:16]
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
