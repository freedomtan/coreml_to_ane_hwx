// ============================================================================
// HandleNEConfig Decompiled C++ - ZinAneTd<17u>
// Source: /hwx_dump/ANECompiler.S (Apple ANE Compiler, v17/M4)
//
// NOTE: x0 = this = ZinAneTd<17u>*
//       ZinAneTdHW_v17 is at (this + 0x8), i.e., register writes use (x0 + offset)
//
// Register Layout (confirmed via assembly analysis):
//   Offset 0x30  = KernelControl  (misc kernel flags, shared with KernelCfg)
//   Offset 0x498 = NE.KernelCfg   (NE kernel configuration word)
//   Offset 0x49c = NE.MacCfg      (MAC unit configuration word)
//   Offset 0x4a4 = NE.PostScale   (half-float postscale + exponent index)
//   Offset 0x4a8 = NE.BiasData    (half-float bias + exponent index)
// ============================================================================

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelPalettizedEn (0x1e4492b74)
//
// Sets the PalettizedEn bit (bit [2]) in NE.KernelCfg (0x498) based on
// whether kernel format enum value falls within a palettized range.
//
// Assembly snippet:
//   1e4492be0: 51001c29    sub  w9, w1, #0x7
//   1e4492be4: 7100213f    cmp  w9, #0x8
//   1e4492be8: 54000102    b.hs 0x1e4492c08  ; out of range: clear
//   1e4492bec: 52800088    mov  w8, #0x4     ; PalettizedEn = 1 (bit [2])
//   1e4492bf0: b9449809    ldr  w9, [x0, #0x498]
//   1e4492bf4: 121d7929    and  w9, w9, #0xfffffffb  ; clear bit [2]
//   1e4492bf8: 2a080128    orr  w8, w9, w8
//   1e4492bfc: b9049808    str  w8, [x0, #0x498]
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelPalettizedEn(ZinKernelFormat fmt) {
    bool is_palettized = false;
    if (fmt >= 7 && fmt <= 14) {
        is_palettized = true;  // 8-entry range -> palettized
    } else if (fmt >= 23 && fmt <= 32) {
        // Check bitmask: 0xf800000 | 0x780000 | 0x1f0000000
        uint64_t mask = (1ULL << fmt);
        is_palettized = (mask & 0x1f0000000) || (mask & 0xf800000) || (mask & 0x780000);
    } else if (fmt >= 15 && fmt <= 18) {
        is_palettized = true;  // sub-range check
    }
    // NE.KernelCfg[2] = PalettizedEn
    uint32_t reg = read32(0x498);
    reg = (reg & ~0x4u) | (is_palettized ? 0x4u : 0u);
    write32(0x498, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelSparseFmt (0x1e4492b1c)
//
// Assembly snippet:
//   1e4492b1c: b9449808    ldr  w8, [x0, #0x498]
//   1e4492b20: 52802009    mov  w9, #0x100     ; bit [8]
//   1e4492b24: 7100003f    cmp  w1, #0x0
//   1e4492b28: 1a9f1129    csel w9, w9, wzr, ne
//   1e4492b2c: 12177908    and  w8, w8, #0xfffffeff  ; clear bit [8]
//   1e4492b30: 2a090108    orr  w8, w8, w9
//   1e4492b34: b9049808    str  w8, [x0, #0x498]     ; NE.KernelCfg
//   -- also sets KernelControl[0x30] bit [5] --
//   1e4492b38: b9403008    ldr  w8, [x0, #0x30]
//   1e4492b3c: 52800409    mov  w9, #0x20      ; bit [5]
//   1e4492b40: 1a9f1129    csel w9, w9, wzr, ne
//   1e4492b44: 121a7908    and  w8, w8, #0xffffffdf  ; clear bit [5]
//   1e4492b48: 2a090108    orr  w8, w8, w9
//   1e4492b4c: b9003008    str  w8, [x0, #0x30]      ; KernelControl
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelSparseFmt(bool enable) {
    // NE.KernelCfg[8] = SparseFmt
    uint32_t kcfg = read32(0x498);
    kcfg = (kcfg & ~0x100u) | (enable ? 0x100u : 0u);
    write32(0x498, kcfg);
    // KernelControl[5] = SparseFmt mirror
    uint32_t kctl = read32(0x30);
    kctl = (kctl & ~0x20u) | (enable ? 0x20u : 0u);
    write32(0x30, kctl);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelSparseBinary (0x1e4492b54)
//
// Assembly snippet:
//   1e4492b54: b9449808    ldr  w8, [x0, #0x498]
//   1e4492b58: 52900009    mov  w9, #0x8000    ; bit [15]
//   1e4492b60: 1a9f1129    csel w9, w9, wzr, ne
//   1e4492b64: 12107908    and  w8, w8, #0xffff7fff  ; clear bit [15]
//   1e4492b68: 2a090108    orr  w8, w8, w9
//   1e4492b6c: b9049808    str  w8, [x0, #0x498]     ; NE.KernelCfg
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelSparseBinary(bool enable) {
    // NE.KernelCfg[15] = SparseBinary
    uint32_t reg = read32(0x498);
    reg = (reg & ~0x8000u) | (enable ? 0x8000u : 0u);
    write32(0x498, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetGroupKernelReuse (0x1e4492ae4)
//
// Assembly snippet:
//   1e4492ae4: b9449808    ldr  w8, [x0, #0x498]
//   1e4492ae8: 52808009    mov  w9, #0x400     ; bit [10]
//   1e4492aec: 7100003f    cmp  w1, #0x0
//   1e4492af0: 1a9f1129    csel w9, w9, wzr, ne
//   1e4492af4: 12157908    and  w8, w8, #0xfffffbff  ; clear bit [10]
//   1e4492af8: 2a090108    orr  w8, w8, w9
//   1e4492afc: b9049808    str  w8, [x0, #0x498]     ; NE.KernelCfg
//   -- also sets KernelControl[0x30] bit [4] --
//   1e4492b04: 52800209    mov  w9, #0x10      ; bit [4]
//   1e4492b0c: 121b7908    and  w8, w8, #0xffffffef  ; clear bit [4]
//   1e4492b14: b9003008    str  w8, [x0, #0x30]      ; KernelControl
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetGroupKernelReuse(bool enable) {
    // NE.KernelCfg[10] = GroupKernelReuse
    uint32_t kcfg = read32(0x498);
    kcfg = (kcfg & ~0x400u) | (enable ? 0x400u : 0u);
    write32(0x498, kcfg);
    // KernelControl[4] = GroupKernelReuse mirror
    uint32_t kctl = read32(0x30);
    kctl = (kctl & ~0x10u) | (enable ? 0x10u : 0u);
    write32(0x30, kctl);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetOpMode (0x1e448f8f4)
//   Maps ZinHWOpMode enum -> NE.MacCfg[2:0] (offset 0x49c, bits [2:0])
//
// Assembly analysis:
//   OpMode 0 (Conv)         -> bits [2:0] = 0b000 (clear all 3)
//   OpMode 1 (ElemWise)     -> bits [2:0] = 0b001
//   OpMode 2 (EWSqrt)       -> bits [2:0] = 0b011
//   OpMode 3 (EWMult)       -> bits [2:0] = 0b001
//   OpMode 4 (RCAS)         -> bits [2:0] = 0b010
//   OpMode 5 (Bypass)       -> bits [2:0] = 0b100
//   OpMode 6 (TransposedConv)-> bits [2:0] = 0b101 (via bfxil from w9=#5)
//
// Key instruction (for w1=6, TransposedConv):
//   1e448f970: 528000a9    mov  w9, #0x5
//   1e448f978: 33000928    bfxil w8, w9, #0, #3   ; insert 3 bits
//
// Other modes use and/orr pattern:
//   1e448f924: 121d7108    and  w8, w8, #0xfffffff8  ; clear bits [2:0]
//   1e448f928: 32000108    orr  w8, w8, #0x1         ; set value
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetOpMode(ZinHWOpMode mode) {
    uint32_t reg = read32(0x49c);  // NE.MacCfg
    reg &= ~0x7u;                   // clear bits [2:0]
    switch (mode) {
        case 0: /* Conv */           break;  // 0b000 -> no-op after clear
        case 1: /* ElemWise */       reg |= 0x1u; break;  // 0b001
        case 2: /* EWSqrt */         reg |= 0x3u; break;  // 0b011
        case 3: /* EWMult */         reg |= 0x1u; break;  // 0b001 (same as ElemWise)
        case 4: /* RCAS */           reg |= 0x2u; break;  // 0b010
        case 5: /* Bypass */         reg |= 0x4u; break;  // 0b100
        case 6: /* TransposedConv */ reg |= 0x5u; break;  // 0b101
        default: return;  // invalid mode -> no write
    }
    write32(0x49c, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelMode (0x1e448f9d0)
//   Maps ZinHWKernelMode -> NE.MacCfg (offset 0x49c)
//   Assembly is truncated with only branch destinations shown; the function
//   continues at 3 branch targets for modes 0, 1, 2.
//   (Full body at lines 2024312-2024340 in ANECompiler.S)
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelMode(ZinHWKernelMode mode) {
    // Three modes branch to three different encoding paths in 0x49c
    // Exact bitfield position not determined from truncated extract
    /* assembly:
       1e448f9d0: 34000121    cbz  w1, 0x1e448f9f4    ; mode==0 -> path A
       1e448f9d8: 54000080    b.eq 0x1e448f9e8         ; mode==1 -> path B
       1e448f9e0: 54000120    b.eq 0x1e448fa04         ; mode==2 -> path C
       1e448f9e4: d65f03c0    ret                      ; invalid -> return
    */
}

// ----------------------------------------------------------------------------
// Sub-routine: SetPassthroughEnable (0x1e448fa1c)
//
// Assembly snippet:
//   1e448fa1c: b9449c08    ldr  w8, [x0, #0x49c]
//   1e448fa20: 52800409    mov  w9, #0x20      ; bit [5]
//   1e448fa24: 7100003f    cmp  w1, #0x0
//   1e448fa28: 1a9f1129    csel w9, w9, wzr, ne
//   1e448fa2c: 121a7908    and  w8, w8, #0xffffffdf  ; clear bit [5]
//   1e448fa30: 2a090108    orr  w8, w8, w9
//   1e448fa34: b9049c08    str  w8, [x0, #0x49c]     ; NE.MacCfg
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetPassthroughEnable(bool enable) {
    // NE.MacCfg[5] = PassthroughEnable
    uint32_t reg = read32(0x49c);
    reg = (reg & ~0x20u) | (enable ? 0x20u : 0u);
    write32(0x49c, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelFmt (0x1e448fa3c)
//   Maps ZinHWKernelFmt enum -> NE.KernelCfg[1:0] (offset 0x498, bits [1:0])
//
// Assembly analysis:
//   KernelFmt==0 -> bits [1:0] = 0b00 (clear)
//   KernelFmt==1 -> bits [1:0] = 0b01
//   KernelFmt==2 -> bits [1:0] = 0b10
//
// Key instructions:
//   1e448fa8: 121e7508    and  w8, w8, #0xfffffffc  ; clear bits [1:0]
//   1e448fa58: 32000108    orr  w8, w8, #0x1
//   1e448fa70: 321f0108    orr  w8, w8, #0x2
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelFmt(ZinHWKernelFmt fmt) {
    uint32_t reg = read32(0x498);  // NE.KernelCfg
    reg &= ~0x3u;                   // clear bits [1:0]
    if (fmt == 1) reg |= 0x1u;
    else if (fmt == 2) reg |= 0x2u;
    // fmt==0 -> clear only (already done)
    write32(0x498, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetNEBinaryPoint (0x1e4492db0)
//   Inserts a 6-bit binary point value at NE.MacCfg[13:8] (offset 0x49c)
//
// Assembly:
//   1e4492db0: b9449c08    ldr  w8, [x0, #0x49c]
//   1e4492db4: 33181428    bfi  w8, w1, #8, #6   ; insert BinaryPoint[5:0] at bit [8]
//   1e4492db8: b9049c08    str  w8, [x0, #0x49c]
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetNEBinaryPoint(int binary_point) {
    // NE.MacCfg[13:8] = BinaryPoint
    uint32_t reg = read32(0x49c);
    reg = (reg & ~(0x3Fu << 8)) | ((binary_point & 0x3F) << 8);
    write32(0x49c, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetNEPostScale (0x1e4492e34)
//   Controls NE.MacCfg[14] = EnablePostScale and NE.PostScaleData[20:0]
//   PostScale is passed as ZinKernelComponentInfo (std::optional<>)
//
// Assembly analysis:
//   x1 bit [40] = has_value flag (optional)
//   x1 bits [15:0] = float32 mantissa of the scale value
//   x1 bits [36:32] = exponent index (5 bits), negated before storing
//
//   When has_value/enable (w2[0]==1):
//     NE.MacCfg[14] |= 0x4000            (EnablePostScale bit)
//     NE.PostScaleData[20:0] = { neg_exp5[20:16] | fp16_val[15:0] }
//   When not has_value:
//     NE.MacCfg[14] = 0x3c00 (default?)  (bit [14] only? or 0.0 fp16 value)
//     NE.PostScaleData[20:0] = 0
//
// Key instructions:
//   1e4492e38: f2580029    ands x9, x1, #0x10000000000  ; bit [40] -> has_value
//   1e4492e40: 1e270020    fmov s0, w1        ; treat low 32 bits as float
//   1e4492e44: 1e23c000    fcvt h0, s0        ; convert to float16
//   1e4492e54: 1210114a    and  w10, w10, #0x1f0000  ; exponent index [20:16], 5 bits
//   1e4492e58: 4b0a03ea    neg  w10, w10      ; negate the exponent field
//   1e4492e5c: 1210114a    and  w10, w10, #0x1f0000  ; re-mask after negate
//   1e4492e74: 1211794a    and  w10, w10, #0xffffbfff  ; clear bit [14] of MacCfg
//   1e4492e80: b904a808    str  w8, [x0, #0x4a8]  ; NE.PostScaleData
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetNEPostScale(std::optional<ZinKernelComponentInfo> info) {
    bool has_value = info.has_value() && (info->flags & 1);  // w2[0]
    float16_t fp16_val = 0;
    uint32_t neg_exp_idx = 0;

    if (has_value) {
        fp16_val = float32_to_float16(info->scale_f32);   // fcvt
        neg_exp_idx = (-(int)(info->exponent_index & 0x1F)) & 0x1F;  // 5-bit negated
    }

    // NE.MacCfg[14] = EnablePostScale
    uint32_t mac_cfg = read32(0x49c);
    mac_cfg = (mac_cfg & ~0x4000u) | (has_value ? 0x4000u : 0u);
    write32(0x49c, mac_cfg);

    // NE.PostScaleData[20:0] = { neg_exp_idx[4:0]@[20:16] | fp16_val[15:0] }
    uint32_t post_scale = read32(0x4a8);
    post_scale &= ~0x1FFFFFu;                             // clear bits [20:0]
    post_scale |= (neg_exp_idx << 16) | (uint32_t)fp16_val;
    write32(0x4a8, post_scale);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetNEBias (0x1e4492e94)
//   Controls NE.MacCfg[4] = EnableBias and NE.BiasData[20:0]
//   Symmetric mirror of SetNEPostScale but for Bias register (0x4a4)
//
// Key instructions:
//   1e4492e94: f2580028    ands x8, x1, #0x10000000000  ; bit [40] -> has_value
//   1e4492e9c: 1e270020    fmov s0, w1        ; treat low 32 bits as float
//   1e4492ea0: 1e23c000    fcvt h0, s0        ; convert to float16
//   1e4492eac: d364fd08    lsr  x8, x8, #36   ; shift has_value flag
//   1e4492eb0: 12101129    and  w9, w9, #0x1f0000  ; exponent [20:16]
//   1e4492eb4: 2a0a0129    orr  w9, w9, w10       ; combine with fp16
//   1e4492ec8: 121b794a    and  w10, w10, #0xffffffef  ; clear bit [4]
//   1e4492ecc: 2a080148    orr  w8, w10, w8    ; EnableBias bit
//   1e4492ed0: b9049c08    str  w8, [x0, #0x49c]  ; NE.MacCfg
//   1e4492ed8: 120b2908    and  w8, w8, #0xffe00000  ; clear bits [20:0]
//   1e4492edc: 2a080128    orr  w8, w9, w8
//   1e4492ee0: b904a408    str  w8, [x0, #0x4a4]  ; NE.BiasData
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetNEBias(std::optional<ZinKernelComponentInfo> info) {
    bool has_value = info.has_value() && (info->flags & 1);  // w2[0]
    float16_t fp16_val = 0;
    uint32_t exp_idx = 0;

    if (has_value) {
        fp16_val = float32_to_float16(info->bias_f32);    // fcvt
        exp_idx = (info->exponent_index >> 16) & 0x1F;   // 5-bit
    }

    // NE.MacCfg[4] = EnableBias
    uint32_t mac_cfg = read32(0x49c);
    mac_cfg = (mac_cfg & ~0x10u) | (has_value ? 0x10u : 0u);
    write32(0x49c, mac_cfg);

    // NE.BiasData[20:0] = { exp_idx[4:0]@[20:16] | fp16_val[15:0] }
    uint32_t bias_data = read32(0x4a4);
    bias_data &= ~0x1FFFFFu;
    bias_data |= (exp_idx << 16) | (uint32_t)fp16_val;
    write32(0x4a4, bias_data);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelAsymQuantEn (0x1e4492cf4)
//
// Assembly:
//   1e4492cf4: b9449808    ldr  w8, [x0, #0x498]
//   1e4492cf8: 52a02009    mov  w9, #0x1000000   ; bit [24]
//   1e4492d00: 1a9f1129    csel w9, w9, wzr, ne
//   1e4492d04: 12077908    and  w8, w8, #0xfeffffff  ; clear bit [24]
//   1e4492d08: 2a090108    orr  w8, w8, w9
//   1e4492d0c: b9049808    str  w8, [x0, #0x498]     ; NE.KernelCfg
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelAsymQuantEn(bool enable) {
    // NE.KernelCfg[24] = AsymQuantEn
    uint32_t reg = read32(0x498);
    reg = (reg & ~0x1000000u) | (enable ? 0x1000000u : 0u);
    write32(0x498, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelAlignmentFormat (0x1e448ff10)
//   AlignmentFormat==0 -> KernelCfg[16] = 1 (set)
//   AlignmentFormat==1 -> KernelCfg[16] = 0 (clear)
//
// Assembly:
//   1e448ff1c: b9449808    ldr  w8, [x0, #0x498]
//   1e448ff20: 120f7908    and  w8, w8, #0xfffeffff  ; AlignmentFmt=1: clear bit [16]
//   1e448ff28: b9449808    ldr  w8, [x0, #0x498]
//   1e448ff2c: 32100108    orr  w8, w8, #0x10000     ; AlignmentFmt=0: set bit [16]
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelAlignmentFormat(ZinHWKernelAlignmentFormat fmt) {
    // NE.KernelCfg[16] = AlignmentFormat (inverted: 0=default(C-major), 1=row-major)
    uint32_t reg = read32(0x498);
    if (fmt == 0)      reg |=  0x10000u;   // default -> bit set
    else if (fmt == 1) reg &= ~0x10000u;   // alt format -> bit clear
    // fmt >= 2: no-op (return early in assembly)
    write32(0x498, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetDoubleInt8Enable (0x1e44928b4)
//
// Assembly:
//   1e44928b4: b9449c08    ldr  w8, [x0, #0x49c]
//   1e44928b8: 12057908    and  w8, w8, #0xfbffffff  ; clear bit [26]
//   1e44928bc: 52a08009    mov  w9, #0x4000000       ; bit [26]
//   1e44928c4: 1a9f1129    csel w9, w9, wzr, ne
//   1e44928c8: 2a090108    orr  w8, w8, w9
//   1e44928cc: b9049c08    str  w8, [x0, #0x49c]     ; NE.MacCfg
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetDoubleInt8Enable(bool enable) {
    // NE.MacCfg[26] = DoubleInt8Enable
    uint32_t reg = read32(0x49c);
    reg = (reg & ~0x4000000u) | (enable ? 0x4000000u : 0u);
    write32(0x49c, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetKernelSparseBlockSize (0x1e44929dc)
//
// Assembly:
//   1e44929dc: b9449808    ldr  w8, [x0, #0x498]
//   1e44929e0: 330b0828    bfi  w8, w1, #21, #3   ; insert 3-bit value at [23:21]
//   1e44929e4: b9049808    str  w8, [x0, #0x498]
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetKernelSparseBlockSize(uint32_t block_size) {
    // NE.KernelCfg[23:21] = SparseBlockSize (3-bit log2)
    uint32_t reg = read32(0x498);
    reg = (reg & ~(0x7u << 21)) | ((block_size & 0x7u) << 21);
    write32(0x498, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetArgOutputSelect (0x1e44928d4)
//   Used for pooling (ArgMax/ArgMin) mode selection in NE.MacCfg[23:20]
//
// Assembly:
//   1e44928d4: 51001828    sub  w8, w1, #0x6
//   1e44928d8: 7100151f    cmp  w8, #0x5
//   1e44928dc: 540000a8    b.hi 0x1e44928f0      ; out of range: default value
//   1e44928e0: b8685928    ldr  w8, [x9, w8, uxtw #2]  ; table lookup
//   1e44928f0: 52a00208    mov  w8, #0x100000         ; default: 0x100000
//   1e44928f4: b9449c09    ldr  w9, [x0, #0x49c]
//   1e44928f8: 12086d29    and  w9, w9, #0xff0fffff   ; clear bits [23:20]
//   1e44928fc: 2a080128    orr  w8, w9, w8
//   1e4492900: b9049c08    str  w8, [x0, #0x49c]      ; NE.MacCfg
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetArgOutputSelect(ZinIrPoolingMode mode) {
    // NE.MacCfg[23:20] = ArgOutputSelect (uses jump table for mode -> encoded value)
    static const uint32_t table[] = { /* table indexed by (mode - 6) */ };
    uint32_t encoded = (mode >= 6 && mode <= 11) ? table[mode - 6] : 0x100000u;

    uint32_t reg = read32(0x49c);
    reg = (reg & ~0xF00000u) | encoded;
    write32(0x49c, reg);
}

// ----------------------------------------------------------------------------
// Sub-routine: SetMaxPoolMode (0x1e4492908)
//   Checks if pooling mode is one of: 1, 4, 6, 7, 11, 14 (bitmask 0x48e2)
//   If yes, sets NE.MacCfg[19] = MaxPoolEnable
//
// Assembly:
//   1e4492908: 7100383f    cmp  w1, #0xe
//   1e449290c: 54000148    b.hi 0x1e4492934    ; mode > 14: no-op
//   1e4492910: 52800028    mov  w8, #0x1
//   1e4492914: 1ac12108    lsl  w8, w8, w1     ; 1 << mode
//   1e4492918: 52891c49    mov  w9, #0x48e2    ; valid mode bitmask
//   1e449291c: 6a09011f    tst  w8, w9         ; is mode in set?
//   1e4492920: 540000a0    b.eq 0x1e4492934    ; no: skip
//   1e4492924: b9449c08    ldr  w8, [x0, #0x49c]
//   1e4492928: 320d0108    orr  w8, w8, #0x80000  ; set bit [19]
//   1e449292c: b9049c08    str  w8, [x0, #0x49c]  ; NE.MacCfg
// ----------------------------------------------------------------------------
void ZinAneTd<17u>::SetMaxPoolMode(ZinIrPoolingMode mode) {
    // NE.MacCfg[19] = MaxPoolEnable (if mode is a valid max-pool type)
    static const uint32_t valid_modes_mask = 0x48e2;  // modes: 1,4,6,7,11,14
    if (mode <= 14 && ((1u << mode) & valid_modes_mask)) {
        uint32_t reg = read32(0x49c);
        reg |= 0x80000u;  // bit [19]
        write32(0x49c, reg);
    }
}

// ============================================================================
// Main function: HandleNEConfig (0x1e3d53298)
//   ZinAneTd<17u>::HandleNEConfig(const ZinNELayer* layer,
//                                   const ZinIrHalParameters& params)
//
// Inputs:
//   x0 = this ptr (ZinAneTd<17u>*)
//   x1 = layer (const ZinNELayer*)      -> saved to x19
//   x2 = params (const ZinIrHalParameters*) -> saved to x22
//
// The function body has 3 main flow paths:
//   1. Fast path (kernel == null): no sparse/palettized config
//   2. Normal path: full kernel format + MAC config + optional activation
//   3. Error path: kernel pointer auth failure -> cold function call
// ============================================================================
bool ZinAneTd<17u>::HandleNEConfig(const ZinNELayer* layer,
                                    const ZinIrHalParameters& params) {
    // ---- PROLOGUE ----
    // 1e3d532b8: aa0203f6    mov  x22, x2       ; params
    // 1e3d532c8: f9400010    ldr  x16, [x0]     ; vtable ptr (PAC authenticated)
    // 1e3d532e8: d73f0911    blraa x8, x17      ; virtual call via vtable[0x58]

    // --- vtable call at vtable+0x58 (likely "Prepare" or "GetKernel") ---

    // x21 = layer (raw or shared kernel access)
    // x8 = layer->kernelArray[0xa0 offset] (pointer to ZinIrKernel or null)
    const ZinIrKernel* kernel = layer->kernels[0].get();  // at x19+0xa0

    // ---- SPARSE / PALETTIZE KERNEL CONFIG ----
    // 1e3d532f4: b4000288    cbz  x8, 0x1e3d53344  ; no kernel -> skip to fast path

    if (kernel == nullptr) {
        // Fast path: no kernel
        // 1e3d53344: aa1303e0    mov  x0, x19
        // 1e3d53348: 94183ace    bl   GetKernelGroupReuse
        bool group_reuse = GetKernelGroupReuse(layer);
        // x27=0, x28=0 (SparseBinary=0, SparseFmt=0)
        SetKernelPalettizedEn(/*ZinKernelFormat::*/ 4);   // default: format=4
        SetKernelPalettizedBits(/*ZinKernelFormat::*/ 4);
        SetKernelSparseFmt(false);
        SetKernelSparseBinary(false);
        SetGroupKernelReuse(group_reuse);
    } else {
        // 1e3d532f8: 39472118    ldrb w24, [x8, #0x1c8]  ; kernel->flags at +0x1c8
        uint8_t kernel_flags = *(uint8_t*)((uintptr_t)kernel + 0x1c8);

        // 1e3d532fc: 5304131b    ubfx w27, w24, #4, #1   ; bit [4] = SparseBinary flag
        // 1e3d53300: 53030f1c    ubfx w28, w24, #3, #1   ; bit [3] = SparseFmt flag
        bool sparse_binary = (kernel_flags >> 4) & 1;
        bool sparse_fmt    = (kernel_flags >> 3) & 1;

        bool group_reuse = GetKernelGroupReuse(layer);

        // 1e3d53310: 36100258    tbz  w24, #0x2, 0x1e3d53358 ; bit[2] = HasCompressedKernel?
        bool has_sparse_kernel_ptr = (kernel_flags >> 2) & 1;

        if (has_sparse_kernel_ptr) {
            // Load the sparse kernel compression descriptor
            const ZinIrKernelCompression* comp = layer->GetKernelCompression(); // [x0+0x378]->[+0x28]
            if (comp == nullptr) {
                // 1e3d53494: ... ZinLog / assertion path
                bool ok = ZinLog(/*level*/16);
                if (!ok) return false;
                // cold.1 error handler
            }

            // 1e3d53324: b940b01a    ldr  w26, [x0, #0xb0]  ; layer->kernel_format
            uint32_t layer_kernel_format = *(uint32_t*)((uintptr_t)layer + 0xb0);

            // 1e3d53328: 39400118    ldrb w24, [x8]          ; comp->type byte
            uint8_t comp_type = *(uint8_t*)comp;

            if (comp_type == 1) {  // ZinKernelCompressionType::SparseBinary
                // 1e3d53334: 94218478    bl   ZinIrKernel::ShouldUseSparseBinaryForCompression
                bool use_sparse_binary = kernel->ShouldUseSparseBinaryForCompression();
                sparse_binary = use_sparse_binary;
                // jump to common path with layer_kernel_format (x26 = format)
            }
            // else: sparse_binary = 0 (cleared at 1e3d534b0)
        }

        // 1e3d53358: 52800019    mov  w25, #0x0   ; x25 = palettized_bits_format? = 0
        // 1e3d5360: 5280009a    mov  w26, #0x4    ; x26 = KernelFormat::4 (default)
        uint32_t kernel_fmt_enum = has_sparse_kernel_ptr ? layer_kernel_format : 4;

        // --- Set kernel format configuration ---
        // 1e3d5336c: bl SetKernelPalettizedEn(kernel_fmt_enum)
        SetKernelPalettizedEn((ZinKernelFormat)kernel_fmt_enum);
        // 1e3d53378: bl SetKernelPalettizedBits(kernel_fmt_enum)
        SetKernelPalettizedBits((ZinKernelFormat)kernel_fmt_enum);
        // 1e3d53384: bl SetKernelSparseFmt(x28)
        SetKernelSparseFmt(sparse_fmt);
        // 1e3d53390: bl SetKernelSparseBinary(x25)
        SetKernelSparseBinary(sparse_binary);
        // 1e3d5339c: bl SetGroupKernelReuse(group_reuse)
        SetGroupKernelReuse(group_reuse);
    }

    // ---- MAC CONFIGURATION ----
    // 1e3d533a0: str  wzr, [sp, #0xc]         ; local op_mode = 0
    // 1e3d533b0: bl   GetMacCfgOpMode(layer, params, &op_mode)
    ZinHWOpMode op_mode = ZinHWOpMode_Conv;
    int err = GetMacCfgOpMode(layer, params, &op_mode);

    if (err != 0) return false;  // 1e3d533bc: cbnz w8, -> return false

    // 1e3d533c8: bl SetOpMode(op_mode)
    SetOpMode(op_mode);

    // 1e3d533d4: bl GetMacCfgKernelMode(layer, params) -> ZinHWKernelMode
    ZinHWKernelMode kernel_mode = GetMacCfgKernelMode(layer, params);
    // 1e3d533e0: bl SetKernelMode(kernel_mode)
    SetKernelMode(kernel_mode);

    // 1e3d533ec: bl GetMacCfgPassthroughEnable(layer, params) -> bool
    bool passthrough = GetMacCfgPassthroughEnable(layer, params);
    // 1e3d533f8: bl SetPassthroughEnable(passthrough)
    SetPassthroughEnable(passthrough);

    // 1e3d53400: str  wzr, [sp, #0x8]         ; kernel_fmt_out = 0
    // 1e3d53410: bl   GetKernelCfgKernelFmt(layer, params, op_mode, &kernel_fmt_out)
    ZinHWKernelFmt kernel_fmt_hw = ZinHWKernelFmt_Default;
    err = GetKernelCfgKernelFmt(layer, params, op_mode, &kernel_fmt_hw);
    if (err != 0) return false;  // 1e3d53418: return false on error

    // 1e3d53428: bl SetKernelFmt(kernel_fmt_hw)
    SetKernelFmt(kernel_fmt_hw);

    // ---- CHECK IF ACTIVATION / BINARY POINT NEEDED ----
    // 1e3d5342c: add  x8, x19, #0x2ec        ; layer + 0x2ec = ZinIrKernel shared_ptr field
    // 1e3d53434: tbz  x1, #0x20, 0x1e3d53820 ; bit [32] of something -> skip
    auto* kernel_ptr_field = *(void**)((uintptr_t)layer + 0x2ec);
    if ((*(uint64_t*)kernel_ptr_field) & (1ULL << 32)) {
        // Has activation/binary-point kernel
        // 1e3d5343c: bl SetNEBinaryPoint(...)    -- reads from vtable call
        // SetNEBinaryPoint is called via vtable dispatch here (blraa)
        // vtable offset 0x148 -> likely "GetBinaryPoint"
        SetNEBinaryPoint(/* vtable call result */ GetBinaryPoint());

        // vtable[0x148] -> NE activation query (IsSoftmax, etc.)
        // 1e3d53460: mov x0, x20 (this), x1=layer
        // 1e3d53470: blraa x8, x17   ; virtual call
        bool has_activation = vtable_call_0x148(layer);

        if (has_activation) {
            // 1e3d53478: add  x0, x19, #0x2a0   ; unwrap activation layer variant
            ZinActivationLayer* act = layer->activation.get();  // at layer+0x2a0

            if (act) {
                // 1e3d5348c: b940b017    ldr  w23, [x0, #0xb0]
                uint32_t act_type = *(uint32_t*)((uintptr_t)act + 0xb0);
                // x23 = activation type (NonLinearMode)
            }
            // x23 = activation_type (or 0 if no activation)
        }
    }

    // ---- NON-LINEAR MODE ----
    // 1e3d5359c: add  x2, x22, #0x640       ; params.nonlinear_lut at +0x640
    // 1e3d535a8: bl SetNENonLinearMode(act_type, params.nonlinear_modes_vec)
    SetNENonLinearMode(act_type, params.nonlinear_modes_vec);

    // ---- QUANTIZATION OUTPUT ZERO OFFSET ----
    // 1e3d535b0: unwrap ZinQuantLayer at layer+0x2d0
    ZinQuantLayer* quant_layer = layer->quant.get();  // at layer+0x2d0

    if (quant_layer) {
        // 1e3d535d0: bl ZinDeQuantLayer::GetScalarZeroPoint() -> x2
        int64_t zero_point = quant_layer->GetScalarZeroPoint();
        bool has_quant = true;
        // 1e3d535e8: bl SetQuantizationOutputZeroOffset(has_quant, zero_point,
        //                                               act_type, params.nonlinear_modes)
        SetQuantizationOutputZeroOffset(true, zero_point, act_type, params.nonlinear_modes_vec);
    } else {
        SetQuantizationOutputZeroOffset(false, 0, act_type, params.nonlinear_modes_vec);
    }

    // ---- POST-SCALE (optional) ----
    // 1e3d535f0: tbz  w28, #0 (sparse_fmt flag) gating post-scale lookup
    // 1e3d535f4: ldr  x1, [x8, #0xb4]  ; kernel->post_scale_component_info
    // 1e3d5360c: bl SetNEPostScale(optional<ZinKernelComponentInfo>)
    {
        std::optional<ZinKernelComponentInfo> post_scale;
        if (sparse_binary && kernel) {
            post_scale = {kernel->post_scale_component_info};  // at kernel+0xb4
        }
        SetNEPostScale(post_scale);
    }

    // ---- BIAS (optional) ----
    // 1e3d53610: tbz  w27 (SparseBinary flag)
    // 1e3d53618: ldr  x1, [x8, #0xbc]  ; kernel->bias_component_info
    // 1e3d53630: bl SetNEBias(optional<ZinKernelComponentInfo>)
    {
        std::optional<ZinKernelComponentInfo> bias;
        if (sparse_binary && kernel) {
            bias = {kernel->bias_component_info};  // at kernel+0xbc
        }
        SetNEBias(bias);
    }

    // ---- MATRIX VECTOR BIAS ----
    // 1e3d53634: ldr  x8, [x19, #0x58]   ; layer->type_ptr at +0x58
    // 1e3d53638: ldr  w8, [x8, #0x8]     ; type ID at +0x8
    // 1e3d5363c: cmp  w8, #0x5d          ; 0x5d = ZinNEConvLayer type ID
    uint32_t layer_type_id = *(uint32_t*)(*(uintptr_t*)((uintptr_t)layer + 0x58) + 0x8);

    std::optional<float> matrix_mult_bias;
    if (layer_type_id == 0x5d) {
        // 1e3d53648: bl ZinNEConvLayer::GetMatrixMultBias()
        matrix_mult_bias = static_cast<ZinNEConvLayer*>(layer)->GetMatrixMultBias();
        // Mask to 40-bit signed
    }
    // 1e3d53660: bl SetNEMatrixVectorBias(kernel_ptr, matrix_mult_bias)
    SetNEMatrixVectorBias(kernel ? *kernel_unique_ptr : nullptr, matrix_mult_bias);

    // ---- ASYMMETRIC QUANTIZATION ----
    bool asym_quant = false;
    if (kernel) {
        const ZinIrKernelCompression* comp2 =
            *(ZinIrKernelCompression**)((uintptr_t)kernel->comp_ptr + 0x378);
        // 1e3d5368c: ldr  x8, [x8, #0x378]
        // 1e3d53697: ldrb w8, [x8]   ; comp->type
        if (comp2) {
            asym_quant = (*(uint8_t*)comp2) & 1;
        }
    }
    // 1e3d53684: bl SetKernelAsymQuantEn(bool)
    SetKernelAsymQuantEn(asym_quant);

    // 1e3d53685: bl ZinAneTd<8u>::SetKernelDetectZeros(bool)  (base class call via vtable)
    vtable_call_0x90(/* detect zeros = */ asym_quant);

    // ---- KERNEL ALIGNMENT FORMAT ----
    // 1e3d53700: bl SetKernelAlignmentFormat(fmt)   -- result of vtable call
    ZinHWKernelAlignmentFormat align_fmt = vtable_call_0x140(layer);
    SetKernelAlignmentFormat(align_fmt);

    // ---- DOUBLE INT8 ENABLE ----
    // 1e3d53708: ldr  x8, [x19, #0x208]   ; layer field at +0x208
    // 1e3d5370c: ldrb w1, [x8, #0x4ff]    ; byte at [+0x208]+0x4ff
    bool double_int8 = *(uint8_t*)((uintptr_t)(*(void**)((uintptr_t)layer + 0x208)) + 0x4ff);
    // 1e3d53714: bl SetDoubleInt8Enable(bool)
    SetDoubleInt8Enable(double_int8);

    // ---- SPARSE BLOCK SIZE ----
    // 1e3d53720: bl SetKernelSparseBlockSize(0)   ; default = 0
    SetKernelSparseBlockSize(0);

    // Optional override from vector palettized weight:
    // 1e3d53724: ldr  x0, [x19, #0xa0]   ; kernel pointer again
    if (kernel && kernel->HasVectorPalettizedWeight()) {
        // 1e3d5373c: ldr  x9, [x8, #0x378]->[+0x28]  ; check comp_type == 1
        if (kernel_comp_type == 1) {
            // 1e3d53750: bl ZinLog2OfPow2(kernel->weight_count)
            uint32_t log2_block = ZinLog2OfPow2(kernel->weight_count);  // at kernel+0x1a0
            // 1e3d5375c: bl SetKernelSparseBlockSize(log2_block)
            SetKernelSparseBlockSize(log2_block);
        }
    }

    // ---- POOL / ARG OUTPUT SELECT ----
    // 1e3d53760: ldr  x8, [x19, #0x58]
    // 1e3d53764: ldr  w8, [x8, #0x8]
    // 1e3d53768: cmp  w8, #0x61   ; 0x61 = pooling layer type
    if (layer_type_id == 0x61) {
        // 1e3d53770: add  x0, x19, #0x2f8   ; layer->pool at +0x2f8
        ZinPoolLayer* pool = *(ZinPoolLayer**)((uintptr_t)layer + 0x2f8);
        // 1e3d5377c: ldr  x8, [x0, #0x58]  ; pool->mode_info
        // 1e3d53780: ldr  w21, [x8, #0x68] ; pooling mode enum
        ZinIrPoolingMode pool_mode = pool->GetPoolingMode();  // at pool+0x58+0x68
        // 1e3d53788: bl SetArgOutputSelect(pool_mode)
        SetArgOutputSelect(pool_mode);
        // 1e3d53794: bl SetMaxPoolMode(pool_mode)
        SetMaxPoolMode(pool_mode);
    }

    // ---- FINAL VTABLE CALL (e.g. SetNEOcgSize or related) ----
    // 1e3d537a8: mov  x17, #0x140         ; vtable offset 0x140
    // 1e3d537c8: d73f0911    blraa x8, x17  ; virtual dispatch
    bool final_ok = vtable_call_0x140(layer);

    if (!final_ok) {
        // 1e3d537d0: mov w0, #0x1  -> return true (success) from cold path?
        // 1e3d537d8: log + check
        bool log_ok = ZinLog(/*level*/16);
        if (log_ok) {
            cold_handler_2();  // cold.2
        }
        return false;
    }

    return true;  // 1e3d537ec: ldp/ret
}
