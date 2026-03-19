import struct
import sys
import os
import plistlib

# ANE HWX M4 Parser (Python Implementation)
# Mirrors hwx_parsing.m functionality

HWX_MAGIC = 0xbeefface

# Architecture block start addresses
H13_COMMON_START = 0x0000
H13_L2_START = 0x4800
H13_PE_START = 0x8800
H13_NE_START = 0xC800
H13_TILEDMA_SRC_START = 0x13800
H13_TILEDMA_DST_START = 0x17800
H13_KERNELDMA_START = 0x1F800

H16_COMMON_START = 0x0000
H16_L2_START = 0x4100
H16_PE_START = 0x4500
H16_NE_START = 0x4900
H16_TILEDMA_SRC_START = 0x4D00
H16_TILEDMA_DST_START = 0x5100
H16_KERNELDMA_START = 0x5500
H16_CACHEDMA_START = 0x5900
H16_PE_EXT_START = 0x44D0

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

fmt = get_ch_fmt_name

def f19(v):
    bits = (v & 0x7FFFF) << 13
    return struct.unpack('f', struct.pack('I', bits))[0]

def get_m1_reg_name(addr):
    # Common (0x0000)
    if H13_COMMON_START <= addr < H13_COMMON_START + 16 * 4:
        names = ["InDim", "pad0", "ChCfg", "Cin", "Cout", "OutDim",
                 "pad1", "ConvCfg", "pad2", "GroupConvCfg", "TileCfg", "pad3",
                 "pad4", "Cfg", "TaskInfo", "DPE"]
        return names[(addr - H13_COMMON_START) // 4]

    # L2 (0x4800)
    if H13_L2_START <= addr < H13_L2_START + 16 * 4:
        names = ["L2Cfg", "SourceCfg", "SourceBase", "SourceChannelStride",
                 "SourceRowStride", "pad0", "pad1", "pad2", "pad3", "pad4",
                 "pad5", "pad6", "ResultCfg", "ResultBase", "ConvResultChannelStride",
                 "ConvResultRowStride"]
        return names[(addr - H13_L2_START) // 4]

    # PE (0x8800)
    if H13_PE_START <= addr < H13_PE_START + 4 * 4:
        names = ["Cfg", "BiasScale", "PreScale", "FinalScale"]
        return names[(addr - H13_PE_START) // 4]

    # NE (0xC800)
    if H13_NE_START <= addr < H13_NE_START + 5 * 4:
        names = ["KernelCfg", "MACCfg", "MatrixVectorBias", "AccBias", "PostScale"]
        return names[(addr - H13_NE_START) // 4]

    # TileDMA Src (0x13800)
    if H13_TILEDMA_SRC_START <= addr < H13_TILEDMA_SRC_START + 24 * 4:
        names = ["DMAConfig", "pad0", "BaseAddr", "RowStride", "PlaneStride",
                 "DepthStride", "GroupStride", "pad1", "pad2", "pad3", "pad4",
                 "pad5", "pad6", "pad7", "Fmt", "pad8", "pad9", "pad10",
                 "pad11", "pad12", "PixelOffset0", "PixelOffset1", "PixelOffset2",
                 "PixelOffset3"]
        return names[(addr - H13_TILEDMA_SRC_START) // 4]

    # TileDMA Dst (0x17800)
    if H13_TILEDMA_DST_START <= addr < H13_TILEDMA_DST_START + 7 * 4:
        names = ["DMAConfig", "BaseAddr", "RowStride", "PlaneStride",
                 "DepthStride", "GroupStride", "Fmt"]
        return names[(addr - H13_TILEDMA_DST_START) // 4]

    # KernelDMA (0x1F800)
    if H13_KERNELDMA_START <= addr < H13_KERNELDMA_START + 5 * 4:
        names = ["Unknown", "Unknown", "CoeffDMAConfig", "CoeffBaseAddr", "CoeffBfrSize"]
        return names[(addr - H13_KERNELDMA_START) // 4]

    return None

def get_m4_reg_name(addr):
    # Common (0x0000)
    if H16_COMMON_START <= addr < H16_COMMON_START + 23 * 4:
        common_names = [
            "ChannelCfg", "InWidth", "InHeight", "InChannels",
            "InDepth", "OutWidth", "OutHeight", "OutChannels",
            "OutDepth", "NumGroups", "ConvCfg", "ConvCfg3d",
            "UnicastCfg", "TileHeight", "TileOverlap", "MacCfg",
            "NECfg", "PatchCfg", "PECfg", "NID",
            "DPE"
        ]
        off = (addr - H16_COMMON_START) // 4
        if off < len(common_names): return common_names[off]
        return f"CommonReserved_0x{addr:02x}"

    # L2 (0x4100)
    if H16_L2_START <= addr < H16_L2_START + 41 * 4:
        l2_names = [
            "Control", "Src1Cfg", "Src2Cfg", "SrcIdxCfg",
            "Src1Base", "Src1ChannelStride", "Src1RowStride", "Src1DepthStride",
            "Src1GroupStride", "Src2Base", "Src2ChannelStride", "Src2RowStride",
            "Src2DepthStride", "Src2GroupStride", "SrcIdxBase", "SrcIdxChannelStride",
            "SrcIdxDepthStride", "SrcIdxGroupStride", "ResultCfg", "ResultBase",
            "ResultChannelStride", "ResultRowStride", "ResultDepthStride", "ResultGroupStride",
            "L2Reserved", "SrcAndResultWrapCfg", "Src1WrapStart", "Src2WrapStart",
            "L2Reserved", "ResultWrapStart", "MiscField0x4178", "MiscField0x417C",
            "MiscField0x4180", "MiscField0x4184", "MiscField0x4188", "PEIndexCfg",
            "Src1AddrWrap", "Src2AddrWrap", "L2Reserved", "ResultWrapAddr",
            "CropOffsetTexture"
        ]
        return l2_names[(addr - H16_L2_START) // 4]

    # PE Indexing Extension (0x44D0)
    if addr == H16_PE_EXT_START:
        return "IndexCfg"

    # PE (0x4500)
    if H16_PE_START <= addr < H16_PE_START + 15 * 4:
        pe_names = [
            "Config", "Bias", "Scale", "Reserved_0x450C",
            "PreScale", "FinalScale", "LUT1", "LUT2",
            "LUT3", "LUT4", "LUT5", "LUT6",
            "CommonReserved_0x4530", "CommonReserved_0x4534", "Quant"
        ]
        return pe_names[(addr - H16_PE_START) // 4]

    # NE (0x4900)
    if H16_NE_START <= addr < H16_NE_START + 12 * 4:
        ne_names = [
            "KernelMode1", "KernelMode2", "MatrixVectorBias", "NEBias",
            "NEPostScale", "RcasConfig", "RoundModeCfg", "SRSeed[0]",
            "SRSeed[1]", "SRSeed[2]", "SRSeed[3]", "QuantZeroPoint"
        ]
        return ne_names[(addr - H16_NE_START) // 4]

    # TileDMA Src (0x4D00)
    if H16_TILEDMA_SRC_START <= addr < H16_TILEDMA_SRC_START + 81 * 4:
        tdma_src_names = [
            "Src1DMAConfig", "Src2DMAConfig", "Src1WrapCfg", "Src2WrapCfg",
            "Src1BaseAddrLo", "Src1BaseAddrHi", "Src1RowStride", "Src1ChannelStride",
            "Src1DepthStride", "Src1GroupStride", "Src2BaseAddrLo", "Src2BaseAddrHi",
            "Src2RowStride", "Src2ChannelStride", "Src2DepthStride", "Src2GroupStride",
            "Src1MetaDataAddrLo", "Src1MetaDataAddrHi", "Src2MetaDataAddrLo", "Src2MetaDataAddrHi",
            "Src1MetaDataConfig", "Src1MetaUnknown1", "Src1MetaDataSize", "Src2MetaDataConfig",
            "Src2MetaUnknown1", "Src2MetaDataSize", "Src1FmtMode", "Src2FmtMode",
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4D70, 0x4D74
            "Src1CompressedInfo", "Src1CompressedSizeLo", "Src1CompressedSizeHi", "Src1CropOffset",
            "Src2CompressedInfo", "Src2CompressedSizeLo", "Src2CompressedSizeHi", "Src2CropOffset",
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4D98, 0x4D9C
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4DA0, 0x4DA4
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4DA8, 0x4DAC
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4DB0, 0x4DB4
            "Src1WrapDynamic", "Src2WrapDynamic", # 0x4DB8, 0x4DBC
            "Src1DependencyOffset", "Src2DependencyOffset", # 0x4DC0, 0x4DC4
            "TextureConfig", "TextureIdxPermute", "TextureSrcPermute", "TextureBackgroundVal", # 0x4DC8-0x4DD4
            "TextureExtMaxDim1", "TextureExtMaxDim2", "TextureExtMaxDim3", # 0x4DD8, 0x4DDC, 0x4DE0
            "TextureCropBatchSplitDim1", "TextureCropDepthDim1", "TextureCropBatchSplitDim2", # 0x4DE4, 0x4DE8, 0x4DEC
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4DF0, 0x4DF4
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4DF8, 0x4DFC
            "TileDmaSrcReserved", # 0x4E00
            "TextureCropCoeffVal", # 0x4E04
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E08, 0x4E0C
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E10, 0x4E14
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E18, 0x4E1C
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E20, 0x4E24
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E28, 0x4E2C
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E30, 0x4E34
            "TileDmaSrcReserved", "TileDmaSrcReserved", # 0x4E38, 0x4E3C
            "TileDmaSrcReserved" # 0x4E40
        ]
        idx = (addr - H16_TILEDMA_SRC_START) // 4
        if idx < len(tdma_src_names): return tdma_src_names[idx]
        return f"SrcDMA_pad_{idx}"

    # TileDMA Dst (0x5100)
    if H16_TILEDMA_DST_START <= addr < H16_TILEDMA_DST_START + 21 * 4:
        tdma_dst_names = [
            "DstDMAConfig", "DstPadding", "DstBaseAddrLo", "DstBaseAddrHi",
            "DstRowStride", "DstPlaneStride", "DstDepthStride", "DstGroupStride",
            "DstInternalCfg", "DstReserved1", "DstMetaDataAddrLo", "DstMetaDataAddrHi",
            "DstFormatMode", "DstReserved2", "DstFmtCtrl", "DstReserved3",
            "DstCompressedInfo", "DstReserved4", "DstCompSizeLo", "DstCompSizeHi",
            "DstPixelOffset"
        ]
        return tdma_dst_names[(addr - H16_TILEDMA_DST_START) // 4]

    # KernelDMA Src (0x5500)
    if H16_KERNELDMA_START <= addr < H16_KERNELDMA_START + 72 * 4:
        off = (addr - H16_KERNELDMA_START) // 4
        if off == 0: return "MasterConfig"
        if off == 1: return "AlignedCoeffSizePerCh"
        if off == 2: return "Prefetch"
        if 3 <= off <= 5: return f"Reserved[{off-3}]"
        if off == 6: return "StrideX"
        if off == 7: return "StrideY"
        if 8 <= off <= 23: return f"CoeffDMAConfig{off-8}"
        if 24 <= off <= 39: return f"CoeffBaseAddr{off-24}"
        if 40 <= off <= 55: return f"CoeffBfrSize{off-40}"
        if off == 56: return "BiasDMAConfig"
        if off == 57: return "BiasBaseAddr"
        if off == 58: return "BiasReserved0"
        if off == 59: return "BiasReserved1"
        if off == 60: return "PostScaleDMAConfig"
        if off == 61: return "PostScaleBaseAddr"
        if off == 62: return "PostScaleReserved0"
        if off == 63: return "PostScaleReserved1"
        if off == 64: return "PaletteDMAConfig"
        if off == 65: return "PaletteBaseAddr"
        if off == 66: return "PaletteReserved0"
        if off == 67: return "PaletteReserved1"
        if off == 68: return "NLutDMAConfig"
        if off == 69: return "NLutBaseAddr"
        if off == 70: return "NLutReserved0"
        if off == 71: return "NLutReserved1"
        return f"KDMA_pad_{off}"

    # CacheDMA / Telemetry (0x5900)
    if H16_CACHEDMA_START <= addr < H16_CACHEDMA_START + 12 * 4:
        cdma_names = [
            "CacheDMAControl",  "CacheDMAPre0",      "CacheDMAPre1",
            "CacheDMAPad3",     "CacheDMAPad4",      "CacheDMAPad5",
            "CacheDMADsid",     "CacheDMAFootprint", "EarlyTermArg12",
            "CacheDMAFlushArg", "EarlyTermArg34",    "TelemetryBackOff"
        ]
        return cdma_names[(addr - H16_CACHEDMA_START) // 4]

    return None

def get_reg_name(addr, subtype):
    if 4 <= subtype <= 5:
        return get_m1_reg_name(addr)
    return get_m4_reg_name(addr)


def decode_common_h13(values, valid):
    print("        --- Common (0x0000) ---")
    # In M1/H13, Common starts at 0x0 (TD offset) but we need to check the actual TD layout.
    # Based on hwx_parsing.m:
    base = H13_COMMON_START // 4
    if any(valid[base + i] for i in range(16)):
        # InDim (0x0)
        win, hin = 0, 0
        if valid[base]:
            v = values.get(base, 0)
            win, hin = v & 0x7fff, (v >> 16) & 0x7fff
        
        # ChCfg (0x8)
        infmt, outfmt = "Unknown", "Unknown"
        if valid[base + 2]:
            v = values.get(base + 2, 0)
            infmt = get_ch_fmt_name(v & 3)
            outfmt = get_ch_fmt_name((v >> 4) & 3)
        
        # Cin/Cout/OutDim (0xC, 0x10, 0x14)
        cin = values.get(base + 3, 0) & 0x1ffff if valid[base+3] else 0
        cout = values.get(base + 4, 0) & 0x1ffff if valid[base+4] else 0
        wout, hout = 0, 0
        if valid[base + 5]:
            v = values.get(base + 5, 0)
            wout, hout = v & 0x7fff, (v >> 16) & 0x7fff
        
        print(f"        {win} x {hin} x {cin} ({infmt}) -> {wout} x {hout} x {cout} ({outfmt})")
        
        # ConvCfg (0x1C)
        if valid[base + 7]:
            c = values.get(base + 7, 0)
            kw, kh = c & 0x1f, (c >> 5) & 0x1f
            sx, sy = (c >> 13) & 3, (c >> 15) & 3
            px, py = (c >> 17) & 0x1f, (c >> 22) & 0x1f
            print(f"        ConvCfg: K={kw}x{kh} S={sx}x{sy} P={px}x{py}")

        # GroupConvCfg (0x24)
        if valid[base + 9]:
            g = values.get(base + 9, 0)
            print(f"        GroupConvCfg: Groups={g & 0x1fff} UnicastEn={(g >> 14) & 1} ElemMult={(g >> 15) & 1} UnicastCin={(g >> 16) & 0xffff}")

        # Cfg (0x34)
        if valid[base + 13]:
            c = values.get(base + 13, 0)
            active_ne = (c >> 19) & 7
            small_src = (c >> 2) & 1
            sh_pref = (c >> 8) & 7
            sh_min = (c >> 12) & 7
            sh_max = (c >> 16) & 7
            acc_db = (c >> 26) & 1
            print(f"        Cfg: ActiveNE={active_ne} SmallSrc={small_src} ShPref={sh_pref} ShMin={sh_min} ShMax={sh_max} AccDB={acc_db}")

        # TaskInfo (0x38)
        if valid[base + 14]:
            t = values.get(base + 14, 0)
            print(f"        TaskInfo: TID=0x{t & 0xffff:04x} Q={(t >> 16) & 0xf} NID=0x{(t >> 20) & 0xff:02x}")

def decode_l2_h13(values, valid):
    base = H13_L2_START // 4
    if any(valid[base + i] for i in range(16)):
        print("        --- L2 (0x4800) ---")
        if valid[base]:
            c = values.get(base, 0)
            print(f"        L2Cfg: InputReLU={c&1} PaddingMode={(c>>1)&3}")
        if valid[base + 1]:
            s = values.get(base + 1, 0)
            print(f"        L2 SourceCfg: Type={s&3} Dep={(s>>2)&3} Fmt={(s>>6)&3} Intrlv={(s>>8)&0xf} CmpV={(s>>12)&0xf} OffCh={(s>>16)&7}")
        if valid[base + 2]:
            print(f"        L2 Src1: Base=0x{values.get(base+2,0)&0x1ffff:05x} ChanStride=0x{values.get(base+3,0)&0x1ffff:05x} RowStride=0x{values.get(base+4,0)&0x1ffff:05x}")
        if valid[base + 12]:
            r = values.get(base + 12, 0)
            print(f"        L2 ResultCfg: Type={r&3} Bfr={(r>>2)&3} Fmt={(r>>6)&3} Intrlv={(r>>8)&0xf} CmpV={(r>>12)&0xf} OffCh={(r>>16)&7}")

def decode_ne_h13(values, valid):
    base = H13_NE_START // 4
    if any(valid[base + i] for i in range(5)):
        print("        --- Neural Engine (0xC800) ---")
        if valid[base + 1]:
            m = values.get(base + 1, 0)
            print(f"        NE MACCfg: OpMode={m&0xf} NLMode={(m>>16)&3} KernelMode={(m>>4)&1} BiasMode={(m>>5)&1} BP={(m>>9)&0xf}")
        if valid[base]:
            k = values.get(base, 0)
            print(f"        NE KernelCfg: Fmt={get_ch_fmt_name(k&3)} PalEn={(k>>2)&1} PalBits={(k>>4)&0xf} SparseFmt={(k>>8)&1} Reuse={(k>>10)&1}")
        if valid[base + 2]: print(f"        NE MatrixVectorBias: 0x{values.get(base+2, 0)&0xffff:04x}")
        if valid[base + 3]: print(f"        NE AccBias: 0x{values.get(base+3, 0)&0xffff:04x} Shift={(values.get(base+3, 0)>>16)&0x1f}")
        if valid[base + 4]: print(f"        NE PostScale: 0x{values.get(base+4, 0)&0xffff:04x} RightShift={(values.get(base+4, 0)>>16)&0x1f}")

def decode_pe_h13(values, valid):
    base = H13_PE_START // 4
    if valid[base]:
        print("        --- Planar Engine (0x8800) ---")
        c = values.get(base, 0)
        print(f"        PECfg: En={(c>>1)&1} OpMode={(c>>2)&7} ReluEn={(c>>5)&1} Cond={(c>>6)&1} FirstSrc={(c>>16)&1} SecondSrc={(c>>18)&3}")
        if valid[base + 1]:
            bs = values.get(base + 1, 0)
            print(f"        PEBiasScale: Bias=0x{bs&0xffff:04x} Scale=0x{(bs>>16)&0xffff:04x}")
        if valid[base + 2]: print(f"        PEPreScale: 0x{values.get(base+2, 0)&0xffff:04x} PEFinalScale: 0x{values.get(base+3, 0):08x}")

def decode_tiledma_h13(values, valid):
    base = H13_TILEDMA_SRC_START // 4
    if any(valid[base + i] for i in range(24)):
        print("        --- TileDMASrc (0x13800) ---")
        if valid[base]:
            c = values.get(base, 0)
            print(f"        Src1DMAConfig: En={c&1} CacheHint={(c>>4)&0xf} DepMode={(c>>16)&0xf}")
        if valid[base + 2]:
            print(f"        Src1Strides: Base=0x{values.get(base+2, 0)&0x3ffffff:05x} Row=0x{values.get(base+3, 0)&0x3ffffff:05x} Plane=0x{values.get(base+4, 0)&0x3ffffff:05x} Depth=0x{values.get(base+5, 0)&0x3ffffff:05x} Group=0x{values.get(base+6, 0)&0x3ffffff:05x}")
        if valid[base + 14]:
            f = values.get(base + 14, 0)
            print(f"        Src1Fmt: FmtMode={f&3} Trunc={(f>>4)&3} Shift={(f>>8)&1} MemFmt={(f>>12)&3} OffCh={(f>>16)&7} Intrlv={(f>>24)&0xf} CmpV={(f>>28)&0xf}")

    dst_base = H13_TILEDMA_DST_START // 4
    if any(valid[dst_base + i] for i in range(7)):
        print("        --- TileDMADst (0x17800) ---")
        if valid[dst_base]:
            c = values.get(dst_base, 0)
            print(f"        DstDMAConfig: En={c&1} CacheHint={(c>>4)&0xf} L2BfrMode={(c>>24)&1} BypassEOW={(c>>25)&1}")
        if valid[dst_base + 1]:
            print(f"        DstStrides: Base=0x{values.get(dst_base+1, 0)&0x3ffffff:05x} Row=0x{values.get(dst_base+2, 0)&0x3ffffff:05x} Plane=0x{values.get(dst_base+3, 0)&0x3ffffff:05x} Depth=0x{values.get(dst_base+4, 0)&0x3ffffff:05x} Group=0x{values.get(dst_base+5, 0)&0x3ffffff:05x}")

def decode_kerneldma_h13(values, valid):
    base = H13_KERNELDMA_START // 4
    if any(valid[base + i] for i in range(5)):
        print("        --- KernelDMASrc (0x1F800) ---")
        # In H13, it's just a few registers or arrays
        # hwx_parsing.m shows it iterates 16 channels but looking at get_m1_reg_name, it only covers 5 regs.
        # Let's mirror what's in high-level print:
        for i in range(16):
            cfg_off = base + 2 + i # This logic might be complex depending on actual HW traits.
            # Simplified based on the available information.

def decode_common_h16(values, valid):
    base = H16_COMMON_START // 4
    if any(valid[base + i] for i in range(23)):
        print("        --- Common (0x0000) ---")
        if valid[base]:
            cf = values.get(base, 0)
        if valid[base+0]:
            cc = values.get(base+0, 0)
            print(f"        ChannelCfg: InFmt={get_ch_fmt_name(cc&3)} Src2Fmt={get_ch_fmt_name((cc>>2)&3)} OutFmt={get_ch_fmt_name((cc>>4)&3)}")

        for name, off in [("InDim ", 1), ("OutDim", 5)]:
            if all(valid[base+off+i] for i in range(4)):
                w, h, c, d = [values.get(base+off+i, 0) & 0x1ffff for i in range(4)]
                print(f"        {name:10}: W={w} H={h} C={c} D={d}")
        
        if valid[base+9]:
            print(f"        NumGroups : {values.get(base+9, 0)}")
            
        if valid[base+10]:
            cv = values.get(base+10, 0)
            print(f"        ConvCfg   : K={cv&0x3f}x{(cv>>6)&0x3f} S={(cv>>13)&3}x{(cv>>15)&3} P(L/T)={(cv>>17)&0x1f}x{(cv>>22)&0x1f} O={(cv>>28)&3}x{(cv>>30)&3}")
            
        if valid[base+11]:
            c3 = values.get(base+11, 0)
            print(f"        ConvCfg3D : KD={c3&0x1f} SZ={(c3>>6)&3} PZ={(c3>>8)&0xf} OZ={(c3>>13)&3}")
            
        if valid[base+12]:
            u = values.get(base+12, 0)
            print(f"        Unicast   : Cin={(u>>16)&0xffff} En={(u>>14)&1}")
            
        if valid[base+13]:
            print(f"        TileHeight: {values.get(base+13, 0) & 0x1ffff}")
            
        if valid[base+14]:
            o = values.get(base+14, 0)
            print(f"        TileOvr   : Ovr={(o>>16)&0x1f} Top={(o>>21)&0x1f} Bot={(o>>26)&0x1f}")

        if valid[base+15]:
            mc = values.get(base+15, 0)
            print(f"        MacCfg    : ActNE={(mc>>19)&7} SmSrc={(mc>>2)&3} Task={(mc>>4)&0xf} OutTrans={(mc>>28)&1} FillLow={(mc>>29)&1}")
            
        if valid[base+16]:
            ne = values.get(base+16, 0)
            print(f"        LaneCfg   : OCGSize={(ne&7)} FatTile={(ne>>3)&1} WUStack={(ne>>4)&3}")
            
        if valid[base+17]:
            pc = values.get(base+17, 0)
            print(f"        Patch     : W={pc&0xf} H={(pc>>4)&0x1f}")
            
        if valid[base+18]:
            pec = values.get(base+18, 0)
            print(f"        PERouting : Src1Br={(pec)&0xf} Src2Br={(pec>>4)&0xf} S1Tr={(pec>>8)&1} S2Tr={(pec>>9)&1} OutCtoW={(pec>>10)&1}")

        if valid[base+19]: print(f"        NID       : 0x{values.get(base+19, 0):02x}")
        if valid[base+20]: print(f"        DPE       : 0x{values.get(base+20, 0):08x}")

def decode_ne_h16(values, valid):
    base = H16_NE_START // 4
    if any(valid[base + i] for i in range(12)):
        print("        --- Neural Engine (0x4900) ---")
        if valid[base]:
            k = values.get(base, 0)
            fmt = get_ch_fmt_name(k & 3)
            pal_en = (k >> 2) & 1
            pal_bits = (k >> 4) & 0xf
            sparse = (k >> 8) & 1
            reuse = (k >> 10) & 1
            asym = (k >> 24) & 1
            align = (k >> 16) & 1
            print(f"        KernelCfg : Fmt={fmt} Palettized={pal_en} ({pal_bits}bit) Sparse={sparse} Reuse={reuse} Align={align} AsymQuant={asym}")
        
        if valid[base + 1]:
            m = values.get(base + 1, 0)
            print(f"        MACCfg    : OpMode={m&7} BP={(m>>8)&0x3f} NLMode={(m>>16)&3} ArgSel={(m>>20)&0xf}")
            
        if valid[base + 2]: print(f"        MatrixBias: 0x{values.get(base+2, 0)&0xffff:04x}")
        if valid[base + 3]: print(f"        NEBias    : 0x{values.get(base+3, 0)&0x1fffff:06x}")
        if valid[base + 4]: print(f"        PostScale : 0x{values.get(base+4, 0)&0x1fffff:06x}")
        
        if valid[base + 5]:
            r = values.get(base + 5, 0)
            print(f"        RcasConfig: KeyMask=0x{r&0xff:02x} CmpBit={(r>>8)&7} SenseAxis={(r>>12)&3} SenseBit={(r>>16)&0xf} Mode={(r>>20)&1}")
        
        if valid[base+6]:
            r = values.get(base+6, 0)
            print(f"        RoundMode : Mode={r&3} IntegerBits={(r>>4)&0x1f}")
        
        if any(valid[base+7+i] for i in range(4)):
            seeds = [values.get(base+7+i, 0) for i in range(4)]
            print(f"        SRSeeds   : 0x{seeds[0]:08x} 0x{seeds[1]:08x} 0x{seeds[2]:08x} 0x{seeds[3]:08x}")
            
        if valid[base+11]:
            print(f"        QuantZero : {values.get(base+11, 0) & 0xff}")

def decode_pe_h16(values, valid):
    # PE Extension (Indexing)
    ext_base = H16_PE_EXT_START // 4
    if valid[ext_base]:
        ec = values.get(ext_base, 0)
        print("        --- PE Indexing (0x44D0) ---")
        print(f"        PE Index  : Max={ec&0xffff} En={(ec>>16)&1}")

    base = H16_PE_START // 4
    if any(valid[base + i] for i in range(15)):
        print("        --- Planar Engine (0x4500) ---")
        if valid[base]:
            pc = values.get(base, 0)
            print(f"        PECfg     : Op={(pc>>2)&7} LutEn={(pc>>5)&1} Cond={(pc>>6)&7} Src1={(pc>>16)&1} Src2={(pc>>18)&3}")
            
        if valid[base + 1]: print(f"        PE Bias   : 0x{values.get(base+1, 0)&0x7ffff:05x} ({f19(values.get(base+1, 0)):.4f})")
        if valid[base + 2]: print(f"        PE Scale  : 0x{values.get(base+2, 0)&0x7ffff:05x} ({f19(values.get(base+2, 0)):.4f})")
        if valid[base + 4]: print(f"        PE PreScl : 0x{values.get(base+4, 0)&0x7ffff:05x} ({f19(values.get(base+4, 0)):.4f})")
        if valid[base + 5]: print(f"        PE FinScl : 0x{values.get(base+5, 0)&0x7ffff:05x} ({f19(values.get(base+5, 0)):.4f})")
        if valid[base + 14]:
            q = values.get(base + 14, 0)
            print(f"        PE Quant  : S1Off={q&0xff} S2Off={(q>>8)&0xff} OutZP={(q>>16)&0xff}")

def decode_l2_h16(values, valid):
    base = H16_L2_START // 4
    if any(valid[base + i] for i in range(41)):
        print("        --- L2 Cache (0x4100) ---")
        if valid[base]:
            c = values.get(base, 0)
            print(f"        L2Control : S1ReLU={c&1} PadMode={(c>>2)&3} S2ReLU={(c>>4)&1} Barrier={(c>>16)&1}")
            
        for name, off in [("Src1", 1), ("Src2", 2), ("SrcIdx", 3)]:
            if valid[base + off]:
                cfg = values.get(base + off, 0)
                t, d, asrc, arsl = cfg&3, (cfg>>2)&3, (cfg>>4)&1, (cfg>>5)&1
                fmt = (cfg>>6)&3
                intrlv = (cfg>>8)&0xf
                comp = (cfg>>25)&3
                print(f"        {name}Cfg  : Type={t} Dep={d} Alias(C={asrc}, R={arsl}) Fmt={fmt} Intrlv={intrlv} Comp={comp}")
        
        def print_l2_unit(name, ubase):
            if any(valid[ubase+i] for i in range(5)):
                b, c, r, d, g = [values.get(ubase+i, 0) & 0x1ffff for i in range(5)]
                print(f"        {name:10}: Base=0x{b:05x} CStr=0x{c:05x} RStr=0x{r:05x} DStr=0x{d:05x} GStr=0x{g:05x}")

        print_l2_unit("Src1", base + 4)
        print_l2_unit("Src2", base + 9)
        
        if any(valid[base+14+i] for i in range(4)):
            b, c, d, g = [values.get(base+14+i, 0) & 0x1ffff for i in range(4)]
            print(f"        SrcIdx    : Base=0x{b:05x} CStr=0x{c:05x} DStr=0x{d:05x} GStr=0x{g:05x}")

        if valid[base + 18]:
            r = values.get(base+18, 0)
            print(f"        ResultCfg : Type={r&3} Bfr={(r>>3)&1} Alias(S={(r>>4)&1}, R={(r>>5)&1}) Fmt={(r>>6)&3} Intrlv={(r>>8)&0xf} Comp={(r>>25)&3}")
        
        print_l2_unit("Result", base + 19)
        
        if valid[base + 25]:
            w = values.get(base + 25, 0)
            print(f"        WrapCfg   : S1={w&7} S2={(w>>4)&7} Res={(w>>14)&7}")
            
        if valid[base + 29]: # WrapIdxOff
            w = values.get(base + 29, 0)
            print(f"        ResultWrap: Idx=0x{w&0xffff:04x} Off=0x{(w>>16)&0xffff:04x}")

        if valid[base + 39]: # WrapAddr
            wa = values.get(base + 39, 0)
            print(f"        ResultWrap: Addr=0x{wa:08x}")

        if valid[base + 40]: # CropOffsetTexture
            cot = values.get(base + 40, 0)
            print(f"        CropTex   : S1X={cot&0x3f} S1Y={(cot>>8)&0x1f} S2X={(cot>>16)&0x3f} S2Y={(cot>>24)&0x1f}")

def decode_cachedma_h16(values, valid):
    base = H16_CACHEDMA_START // 4
    if any(valid[base + i] for i in range(12)):
        print("        --- CacheDMA (0x5900) ---")
        if valid[base]:
            c = values.get(base, 0)
            print(f"        Control   : Flush={c&1} En={(c>>1)&1} TaskSync={(c>>2)&3} EarlyTerm={(c>>4)&0x1f} Limiter={(c>>9)&1} Thresh={(c>>16)&0xffff}")
        
        if valid[base + 1]:
            pre0 = values.get(base+1, 0)
            print(f"        Bandwidth : {pre0&0x3ff} Sieve2={(pre0>>16)&0xf} AgeOut={(pre0>>20)&0xf}")
            
        if valid[base + 2]:
            print(f"        Sieve1    : 0x{values.get(base+2,0)&0x3fff:04x}")
            
        if valid[base + 6]:
            d = values.get(base+6, 0)
            print(f"        DSID      : 0x{(d>>7)&0x7fffff:06x}")
            
        if valid[base + 11]:
            bk = values.get(base+11, 0)
            print(f"        BackOff   : En={bk&1} Delay={(bk>>4)&0xf} Min={(bk>>8)&0xff} Max={(bk>>16)&0xff} Scl={(bk>>24)&0xff}")

def decode_tiledma_h16(values, valid):
    base = H16_TILEDMA_SRC_START // 4
    if any(valid[base + i] for i in range(81)):
        print("        --- TileDMASrc (0x4D00) ---")
        if valid[base]:
            c1 = values.get(base, 0)
            print(f"        Src1DMAConfig: En={c1&1} DSID={(c1>>8)&0xff} Tag={(c1>>16)&0xff} DepInt={(c1>>24)&0xf}")
        if valid[base + 1]:
            c2 = values.get(base+1, 0)
            print(f"        Src2DMAConfig: En={c2&1} DSID={(c2>>8)&0xff} Tag={(c2>>16)&0xff} DepMode={(c2>>28)&3}")
        if valid[base+2]: print(f"        Src1Base   : 0x{values.get(base+3, 0):08x}{values.get(base+2,0):08x}")
        if valid[base+4]: print(f"        Src2Base   : 0x{values.get(base+5, 0):08x}{values.get(base+4,0):08x}")
        if valid[base + 6]:
            print(f"        Src1Strides : Row=0x{values.get(base+6,0):08x} Plane=0x{values.get(base+7,0):08x} Depth=0x{values.get(base+8,0):08x} Group=0x{values.get(base+9,0):08x}")
        if valid[base + 12]:
            print(f"        Src2Strides : Row=0x{values.get(base+12,0):08x} Plane=0x{values.get(base+13,0):08x} Depth=0x{values.get(base+14,0):08x} Group=0x{values.get(base+15,0):08x}")
        if valid[base + 20]:
            print(f"        Src1Meta   : Addr=0x{values.get(base+21,0):08x}{values.get(base+20,0):08x} Size=0x{values.get(base+22,0):08x}")
        if valid[base + 23]:
            print(f"        Src2Meta   : Addr=0x{values.get(base+24,0):08x}{values.get(base+23,0):08x} Size=0x{values.get(base+25,0):08x}")

    dst_base = H16_TILEDMA_DST_START // 4
    if any(valid[dst_base + i] for i in range(21)):
        print("        --- TileDMADst (0x5100) ---")
        if valid[dst_base]:
            c = values.get(dst_base, 0)
            print(f"        DstDMAConfig : En={c&1} DSID={(c>>8)&0xff} Tag={(c>>16)&0xff}")
        if valid[dst_base + 2]: print(f"        DstBase    : 0x{values.get(dst_base+3, 0):08x}{values.get(dst_base+2,0):08x}")
        if valid[dst_base + 4]:
            print(f"        DstStrides  : Row=0x{values.get(dst_base+4,0):08x} Plane=0x{values.get(dst_base+5,0):08x} Depth=0x{values.get(dst_base+6,0):08x} Group=0x{values.get(dst_base+7,0):08x}")
        if valid[dst_base + 10]:
            print(f"        DstMetaAddr : Addr=0x{values.get(dst_base+11,0):08x}{values.get(dst_base+10,0):08x}")
        if valid[dst_base + 12]:
            fm = values.get(dst_base + 12, 0)
            print(f"        DstFmtMode  : Fmt={fm&3} MetaSize={(fm>>7)&0x1ffffff}")
        if valid[dst_base + 14]:
            fc = values.get(dst_base + 14, 0)
            print(f"        DstFmtCtrl  : ZeroPad={fc&1} OffsetCh={(fc>>8)&7} CmpVec={(fc>>12)&0xf}")
        if valid[dst_base + 20]:
            print(f"        DstPixelOff : 0x{values.get(dst_base+20, 0):08x}")

def decode_kerneldma_h16(values, valid):
    base = H16_KERNELDMA_START // 4
    if any(valid[base + i] for i in range(72)):
        print("        --- KernelDMASrc (0x5500) ---")
        if valid[base]:
            kv = values.get(base, 0)
            print(f"        MasterCfg : En={(kv>>6)&1} Sparse={(kv>>5)&1} Reuse={(kv>>4)&1}")
        if valid[base+1]:
            print(f"        CoeffSize : 0x{values.get(base+1, 0)&0xfffffff:08x}")
        if valid[base+2]:
            pv = values.get(base+2, 0)
            print(f"        Prefetch  : Rate={(pv>>16)&0xffff} EarlyEn={pv&1} StopErr={(pv>>1)&1}")
        if valid[base+6]: print(f"        StrideX   : {values.get(base+6, 0) & 0x3ffffff}")
        if valid[base+7]: print(f"        StrideY   : {values.get(base+7, 0) & 0x3ffffff}")
        
        for i in range(16):
            if valid[base+8+i] or valid[base+24+i] or valid[base+40+i]:
                c = values.get(base + 8 + i, 0)
                sz = values.get(base+40+i, 0) & 0x3ffffff
                print(f"        Coeff[{i:2}]: En={c&1} DSID={(c>>8)&0xff} Tag={(c>>16)&0xff} Base=0x{values.get(base+24+i, 0):08x} Size=0x{sz:08x}")
        
        for name, off in [("BiasCfg", 56), ("PSScaleCfg", 60), ("PalCfg", 64), ("NLutCfg", 68)]:
            if valid[base + off]:
                c = values.get(base + off, 0)
                print(f"        {name:10}: En={c&1} DSID={(c>>8)&0xff} Tag={(c>>16)&0xff}")

def decode_regs(reg_values, reg_valid, subtype):
    arch_ver = get_instruction_set_version(subtype)
    arch = "M4" if arch_ver >= 11 else "M1"
    
    if arch == "M1":
        decode_common_h13(reg_values, reg_valid)
        decode_l2_h13(reg_values, reg_valid)
        decode_pe_h13(reg_values, reg_valid)
        decode_ne_h13(reg_values, reg_valid)
        decode_tiledma_h13(reg_values, reg_valid)
        decode_kerneldma_h13(reg_values, reg_valid)
    else: # M4 style (H16)
        decode_common_h16(reg_values, reg_valid)
        decode_pe_h16(reg_values, reg_valid) # Includes Extension
        decode_ne_h16(reg_values, reg_valid)
        decode_l2_h16(reg_values, reg_valid)
        decode_tiledma_h16(reg_values, reg_valid)
        decode_kerneldma_h16(reg_values, reg_valid)
        decode_cachedma_h16(reg_values, reg_valid)

    # Phase 2: Block Register Dumps
    print("        --- HW Block Register State ---")
    blocks = [
        ("[0x0000] Common Module", 0x0000),
        ("[0x4100] L2 Cache Control", 0x4100),
        ("[0x44D0] PE Extension", 0x44D0),
        ("[0x4500] Planar Engine (PE)", 0x4500),
        ("[0x4900] Neural Engine Core (NE)", 0x4900),
        ("[0x4D00] TileDMA Source", 0x4D00),
        ("[0x5100] TileDMA Destination", 0x5100),
        ("[0x5500] KernelDMA Source", 0x5500),
        ("[0x5900] CacheDMA & Telemetry", 0x5900),
    ] if arch == "M4" else [
        ("[0x00000] Common Module", 0x00000),
        ("[0x04800] L2 Cache Control", 0x04800),
        ("[0x08800] Planar Engine (PE)", 0x08800),
        ("[0x0C800] Neural Engine (NE)", 0x0C800),
        ("[0x13800] TileDMA Source", 0x13800),
        ("[0x17800] TileDMA Destination", 0x17800),
        ("[0x1F800] KernelDMA Source", 0x1F800),
    ]

    # M4 exact block word counts (number of 32-bit registers)
    m4_block_sizes = {
        0x0000: 23,   # Common Module
        0x4100: 41,   # L2 Cache
        0x44D0: 1,    # PE Extension
        0x4500: 15,   # Planar Engine (PE)
        0x4900: 12,   # Neural Engine (NE)
        0x4D00: 81,   # TileDMA Source
        0x5100: 21,   # TileDMA Destination
        0x5500: 72,   # KernelDMA Source
        0x5900: 12,   # CacheDMA & Telemetry
    }

    name_lookup = get_m4_reg_name if arch == "M4" else get_m1_reg_name
    for name, start_addr in blocks:
        if arch == "M4" and start_addr in m4_block_sizes:
            we = start_addr // 4 + m4_block_sizes[start_addr]
        else:
            we = start_addr // 4 + 0x100  # fallback lookahead
        printed_header = False
        ws = start_addr // 4
        for r in range(ws, min(we, 0x8000)):
            if reg_valid[r]:
                if not printed_header:
                    print(f"        {name}:")
                    printed_header = True
                reg_name = name_lookup(r * 4)
                print(f"          0x{r*4:05x}: 0x{reg_values[r]:08x}{' (' + reg_name + ')' if reg_name else ''}")

import json

def report_hwx_state_json(reg_values, reg_valid, subtype):
    arch = "M4" if get_instruction_set_version(subtype) >= 11 else "M1"
    regs = []
    name_lookup = get_m4_reg_name if arch == "M4" else get_m1_reg_name
    
    for r in range(0x8000):
        if reg_valid[r]:
            addr = r * 4
            name = name_lookup(addr)
            reg = {"addr": f"0x{addr:05x}", "val": f"0x{reg_values[r]:08x}"}
            if name: reg["name"] = name
            regs.append(reg)
    
    return {"arch": arch, "subtype": subtype, "registers": regs}

def parse_hwx(data, subtype=7, dump_json=False):
    arch_name = get_arch_name(subtype)
    is_version = get_instruction_set_version(subtype)
    if not dump_json:
        print(f"--- HWX Parse Report ---")
        print(f"Architecture: {arch_name}")
        print(f"Instruction Set Version: {is_version}")
    
    json_output = {"tasks": []}
    
    if is_version >= 11: # M4 / H16 style chaining
        offset, task_idx, total_len = 0, 0, len(data)
        while offset + 40 <= total_len:
            h = struct.unpack_from("<10I", data, offset)
            tid = h[0] & 0xffff
            task_size = (h[0] >> 16) & 0x7ff
            if task_size == 0:
                offset += 16; continue
            if tid > 0x1000: break
            
            size_bytes = task_size * 4
            if not dump_json:
                print(f"      [ANE Task {task_idx} @ 0x{offset:x}] (Size: 0x{size_bytes:x} bytes)")
                print(f"        TID: 0x{tid:04x} ExeCycles: {h[1] & 0xffff} ENE: {(h[8] >> 16) & 7} DTID: 0x{h[9] & 0xffff:04x}")
                print(f"        LogEvents: 0x{h[2] & 0xffffff:06x} Exceptions: 0x{h[3] & 0xffffff:06x}")
                print(f"        LiveOuts: 0x{h[6] & 0xffffff:06x} TSR: {h[8] & 1} TDE: {(h[8] >> 1) & 1}")
            
            reg_values, reg_valid = {}, [False] * 0x8000
            num_words = size_bytes // 4
            words = struct.unpack_from(f"<{num_words}I", data, offset)
            w_idx = 10 # H16 header is 40 bytes (10 words)
            while w_idx < num_words:
                hdr = words[w_idx]; w_idx += 1
                is_masked = (hdr >> 31) & 1
                word_addr = hdr & 0x7fff
                if not is_masked:
                    num_regs = (hdr >> 15) & 0x3f
                    for j in range(num_regs + 1):
                        if w_idx >= num_words: break
                        reg_values[word_addr + j] = words[w_idx]
                        reg_valid[word_addr + j] = True
                        w_idx += 1
                else:
                    mask = (hdr >> 15) & 0xffff
                    if w_idx < num_words:
                        reg_values[word_addr] = words[w_idx]
                        reg_valid[word_addr] = True
                        w_idx += 1
                    for bit in range(16):
                        if (mask >> bit) & 1:
                            if w_idx >= num_words: break
                            reg_values[word_addr + bit + 1] = words[w_idx]
                            reg_valid[word_addr + bit + 1] = True
                            w_idx += 1
            
            if dump_json:
                json_output["tasks"].append(report_hwx_state_json(reg_values, reg_valid, subtype))
            else:
                decode_regs(reg_values, reg_valid, subtype)
            
            task_idx += 1
            offset += (size_bytes + 15) & ~15
    else: # M1 / H13
        offset, task_idx, total_len = 0, 0, len(data)
        while offset + 32 <= total_len:
            # H13 Header (approx 32 bytes used in .m)
            h = struct.unpack_from("<8I", data, offset)
            tid = h[0] & 0xffff
            if tid == 0 and h[1] == 0 and h[2] == 0: break # Padding
            
            next_ptr = h[7] # 0x1c offset
            next_size = (h[1] >> 16) & 0xffff # Ref README.md next_size_pad
            
            if not dump_json:
                print(f"      [ANE Task {task_idx} @ 0x{offset:x}]")
                print(f"        TID: 0x{tid:04x} NID: 0x{(h[0]>>16)&0xff:02x} ExeCycles: {h[2]}")
                print(f"        NextPtr: 0x{next_ptr:08x} NextSize: {next_size}")
            
            # Stream parse for H13
            reg_values, reg_valid = {}, [False] * 0x8000
            # Header is 32 bytes (8 words)
            start_off = offset + 40 # Stream starts after 0x28 byte header
            end_off = next_ptr if next_ptr > start_off and next_ptr < total_len else total_len
            
            num_words = (end_off - start_off) // 4
            if num_words > 0:
                words = struct.unpack_from(f"<{num_words}I", data, start_off)
                w_idx = 0
                while w_idx < num_words:
                    hdr = words[w_idx]; w_idx += 1
                    if hdr == 0: continue
                    count = (hdr >> 26) & 0x3f
                    addr = (hdr & 0x3ffffff) >> 2
                    for i in range(count + 1):
                        if w_idx >= num_words: break
                        if addr + i < 0x8000:
                            reg_values[addr + i] = words[w_idx]
                            reg_valid[addr + i] = True
                        w_idx += 1
            
            if dump_json:
                json_output["tasks"].append(report_hwx_state_json(reg_values, reg_valid, subtype))
            else:
                decode_regs(reg_values, reg_valid, subtype)
                
            task_idx += 1
            if next_ptr == 0 or next_ptr <= offset: break
            offset = next_ptr

    if dump_json:
        print(json.dumps(json_output, indent=2))

MH_MAGIC_64 = 0xfeedfacf
LC_SEGMENT_64 = 0x19
LC_ANE_MAPPED_REGION = 0x40

def parse_macho(data):
    if len(data) < 32: return None
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != MH_MAGIC_64 and magic != HWX_MAGIC: return None
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        if offset + 8 > len(data): break
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        if cmd == LC_SEGMENT_64:
            segname = data[offset+8:offset+24].strip(b'\x00').decode(errors='ignore')
            if segname == "__TEXT" or segname == "__DATA":
                nsects = struct.unpack_from("<I", data, offset + 64)[0]
                sect_offset = offset + 72
                for _ in range(nsects):
                    sectname = data[sect_offset:sect_offset+16].strip(b'\x00').decode(errors='ignore')
                    if sectname == "__text" or sectname == "__TEXT":
                        file_off = struct.unpack_from("<I", data, sect_offset + 48)[0]
                        size = struct.unpack_from("<Q", data, sect_offset + 40)[0]
                        if file_off > 0 and size > 0:
                            return data[file_off : file_off + size]
                    sect_offset += 80
        elif cmd == LC_ANE_MAPPED_REGION: # Custom ANE segment
            file_off = struct.unpack_from("<I", data, offset + 8)[0]
            size = struct.unpack_from("<I", data, offset + 12)[0]
            if file_off > 0 and size > 0:
                return data[file_off : file_off + size]
        offset += cmdsize
    return None

def main():
    import argparse
    parser = argparse.ArgumentParser(description="ANE HWX Parser (M1/M4)")
    parser.add_argument("path", help="Path to .hwx or directory")
    parser.add_argument("-j", "--json", action="store_true", help="Output in JSON format")
    args = parser.parse_args()
    
    path = args.path
    subtype = 7 # Default to M4
    data = None

    if os.path.isdir(path):
        plist_path = os.path.join(path, "hwx.plist")
        bin_path = os.path.join(path, "hwx.bin")
        if os.path.exists(plist_path):
            with open(plist_path, "rb") as f:
                try:
                    plist = plistlib.load(f)
                    subtype = plist.get("ANE_CPU_SUBTYPE", 7)
                except: pass
        if os.path.exists(bin_path):
            with open(bin_path, "rb") as f: data = f.read()
    else:
        with open(path, "rb") as f: data = f.read()
        
    if not data:
        print(f"Error: Could not read HWX data from {path}")
        return

    ane_data = parse_macho(data)
    if not ane_data:
        magic = struct.unpack_from("<I", data, 0)[0]
        if magic == HWX_MAGIC:
            ane_data = data[16:]
        else:
            for o in range(0, min(len(data), 0x1000) - 40, 4):
                h = struct.unpack_from("<I", data, o)[0]
                tid = h & 0xffff
                if 0 < tid < 0x1000:
                    ane_data = data[o:]
                    break
    
    if ane_data:
        parse_hwx(ane_data, subtype, args.json)
    else:
        print("Error: Could not identify HWX format.")

if __name__ == "__main__": main()
