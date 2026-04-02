import re
import sys

with open("hwx_parsing.m", "r") as f:
    content = f.read()

m1_structs = """
// [0x128] M1 Common Registers
typedef struct {
  // 0x128 Common.InDim
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

// [0x240] Neural Engine (NE) Block 
typedef struct {
  // Word 0 (0x240)
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

  // Word 1 (0x244)
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

} __attribute__((packed)) ane_m1_ne_t;

"""

replacement = m1_structs + "\nconst char *get_ch_fmt_name(uint32_t fmt) {"
content = content.replace("const char *get_ch_fmt_name(uint32_t fmt) {", replacement)

# Now refactor decode_ane_td
decoding_logic = """void decode_ane_td(const uint8_t *ptr, size_t total_len) {
  uint32_t offset = 0;
  int task_idx = 0;

  while (offset + sizeof(ane_td_header_t) <= total_len) {
    const ane_td_header_t *td = (const ane_td_header_t *)(ptr + offset);
    if (td->next_pointer == 0 && td->exe_cycles == 0 && td->log_events == 0) {
      break; // Probably hit zero padding at end
    }

    printf("      [ANE Task %d @ 0x%x]\n", task_idx++, offset);
    printf("        TID: 0x%04x NID: 0x%02x LNID: %d EON: %d\n", td->tid,
           td->nid, td->lnid_eon & 1, (td->lnid_eon >> 1) & 1);
    printf("        ExeCycles: %u NextSize: %u\n", td->exe_cycles,
           td->next_size_pad & 0x1FF);
    printf("        Flags: 0x%08x NextPointer: 0x%08x\n", td->flags,
           td->next_pointer);

    // M1 Common Block at 0x128
    if (offset + 0x160 <= total_len) {
      const ane_m1_common_t *common = (const ane_m1_common_t *)(ptr + offset + 0x128);
      
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
        printf("        ConvCfg: K=%ux%u S=%ux%u P=%ux%u\n", 
               common->convcfg.kw, common->convcfg.kh, 
               common->convcfg.sx, common->convcfg.sy, 
               common->convcfg.px, common->convcfg.py);

        printf("        GroupConvCfg: Groups=%u UnicastEn=%d ElemMult=%d UnicastCin=%u\n",
               common->groupcfg.num_groups, common->groupcfg.unicast_en, 
               common->groupcfg.elem_mult_mode, common->groupcfg.unicast_cin);
      }
      
      printf("        ActiveNE: %u\n", common->cfg.active_ne);
    }
    
    // M1 L2 Cache Block at 0x1E0
    if (offset + 0x220 <= total_len) {
      const ane_m1_l2_t *l2 = (const ane_m1_l2_t *)(ptr + offset + 0x1E0);
      printf("        L2Cfg: InputRelu=%d PaddingMode=%u\n", l2->l2cfg.input_relu, l2->l2cfg.padding_mode);
      
      printf("        SourceCfg: Type=%u Dep=%u Fmt=%u Intrlv=%u CmpV=%u OffCh=%u\n",
             l2->scfg.type, l2->scfg.dep, l2->scfg.fmt, l2->scfg.interleave, l2->scfg.cmpv, l2->scfg.offch);
             
      printf("        ResultCfg: Type=%u Bfr=%u Fmt=%u Intrlv=%u CmpV=%u OffCh=%u\n",
             l2->rcfg.type, l2->rcfg.bfrmode, l2->rcfg.fmt, l2->rcfg.interleave, l2->rcfg.cmpv, l2->rcfg.offch);
    }
    
    // M1 NE block at 0x240
    if (offset + 0x250 <= total_len) {
      const ane_m1_ne_t *ne = (const ane_m1_ne_t *)(ptr + offset + 0x240);
      printf("        NE MACCfg: OpMode=%u NLMode=%u KernelMode=%d BiasMode=%d\n",
             ne->mac_cfg.op_mode, ne->mac_cfg.non_linear_mode, ne->mac_cfg.kernel_mode, ne->mac_cfg.bias_mode);
             
      printf("        NE KernelCfg: Fmt=%u PalettizedEn=%d SparseFmt=%d\n",
             ne->kernel_cfg.kernel_fmt, ne->kernel_cfg.palettized_en, ne->kernel_cfg.sparse_fmt);
    }

    if (td->next_pointer == 0 || td->next_pointer <= offset) {
      break;
    }
    offset = td->next_pointer;
  }
}"""

# Using regex to replace the function definition
content = re.sub(r'void decode_ane_td\(const uint8_t \*ptr, size_t total_len\).*?^}\n*', decoding_logic + '\n\n', content, flags=re.MULTILINE | re.DOTALL)

with open("hwx_parsing.m", "w") as f:
    f.write(content)

