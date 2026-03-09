import struct
import sys

# Constants for HWX parsing
HWX_MAGIC_64 = 0xbeefface
LC_SEGMENT_64 = 0x19

def get_bits(val, start, count):
    return (val >> start) & ((1 << count) - 1)

def format_data_type(fmt, is_h16=True):
    # M4 (H16): INT8=0, FLOAT16=1, UINT8=2
    # M1 (H13): INT8=0, UINT8=1, FLOAT16=2 (Per user correction)
    if is_h16:
        mapping = {0: "INT8", 1: "FLOAT16", 2: "UINT8", 3: "Reserved"}
    else:
        mapping = {0: "INT8", 1: "UINT8", 2: "FLOAT16", 3: "Reserved"}
    return mapping.get(fmt, f"UNKNOWN({fmt})")

def format_op_mode(mode):
    mapping = {0: "CONV", 1: "MATRIX_VECTOR/ELEMENTWISE", 2: "ELEMENTWISE_UNARY", 3: "REDUCE"}
    return mapping.get(mode, f"UNKNOWN({mode})")

def format_l2_type(typ):
    mapping = {0: "DRAM", 1: "L2", 2: "NE_INTERNAL", 3: "TILE_DMA"}
    return mapping.get(typ, f"UNKNOWN({typ})")

def format_nonlinear_mode(mode):
    mapping = {0: "NONE", 1: "RELU", 2: "CUSTOM"}
    return mapping.get(mode, f"UNKNOWN({mode})")

def format_ne_op_mode(mode):
    mapping = {0: "CONV", 1: "MV/ELEM", 2: "ELEM_UNARY", 3: "REDUCE"}
    return mapping.get(mode, f"UNKNOWN({mode})")

def format_pe_op(op):
    # Op codes from hwx_parsing.m logic
    if op == 0x31: return "ADD"
    if op == 0x32: return "MUL"
    if op == 0x34: return "MAX"
    if op == 0x22: return "POOL_MAX"
    return f"0x{op:x}"

def popcount(x):
    return bin(x).count('1')

def decode_register_stream(words):
    # Words start from index 9 (after header)
    regs = {}
    i = 9
    num_words = len(words)
    
    while i < num_words:
        header = words[i]
        i += 1
        
        # Bits 0-14: Word Address
        # Bit 31: 1=Masked, 0=Sequential
        word_addr = header & 0x7FFF
        
        if (header >> 31) == 0:
            # Sequential / Burst Mode
            # Bits 15-20: num_regs - 1
            num_regs_m1 = (header >> 15) & 0x3F
            for j in range(num_regs_m1 + 1):
                if i < num_words:
                    regs[word_addr + j] = words[i]
                    i += 1
        else:
            # Masked / Scattered Mode
            # Bits 15-30: 16-bit mask
            mask = (header >> 15) & 0xFFFF
            # V11 Masked commands always include base register value first
            if i < num_words:
                regs[word_addr] = words[i]
                i += 1
            
            for bit in range(16):
                if (mask >> bit) & 1:
                    if i < num_words:
                        regs[word_addr + bit + 1] = words[i]
                        i += 1
    return regs

def decode_register_stream_m1(words):
    regs = {}
    i = 0
    num_words = len(words)
    while i < num_words:
        header = words[i]
        if header == 0 and i > 0: # Padding
            break
        i += 1
        
        # M1 format: 26-bit address (0-25), 6-bit count (26-31)
        word_addr = header & 0x03FFFFFF
        count = (header >> 26) & 0x3F
        
        for j in range(count + 1):
            if i < num_words:
                regs[word_addr + j] = words[i]
                i += 1
    return regs

def dump_m1_block(regs, base, name, size=64):
    print(f"    --- {name} ({base:04x}) ---")
    any_reg = False
    for i in range(size):
        addr = base + i
        if addr in regs and regs[addr] != 0:
            print(f"      [{addr:04x}] 0x{regs[addr]:08x}")
            any_reg = True
    if not any_reg:
        print(f"      (All Zero)")

def decode_segment_header(data):
    # ZinAneSegmentHeader_V2
    # Small header is 8 bytes, Large is 40 bytes
    flags = struct.unpack('<I', data[0:4])[0]
    is_large = (flags & 4) != 0
    eon = (flags >> 3) & 1
    
    header = {
        "flags": flags,
        "is_large": is_large,
        "eon": eon,
        "size": 40 if is_large else 8
    }
    
    if is_large:
        # Based on DumpSegmentHeaderBranchField
        header["true_size"] = struct.unpack('<I', data[8:12])[0]
        header["false_size"] = struct.unpack('<I', data[12:16])[0]
        header["false_addr"] = struct.unpack('<Q', data[16:24])[0]
        header["true_addr"] = struct.unpack('<Q', data[24:32])[0]
    
    return header

def parse_hwx(filename):
    with open(filename, 'rb') as f:
        magic_raw = f.read(4)
        magic = struct.unpack('<I', magic_raw)[0]
        if magic != HWX_MAGIC_64:
            print(f"Not a .hwx file (magic: 0x{magic:08x})")
            return
            
        cputype = struct.unpack('<I', f.read(4))[0]
        cpusubtype = struct.unpack('<I', f.read(4))[0]
        
        print(f"Mach-O Header: CpuType: 0x{cputype:x}, CpuSubtype: 0x{cpusubtype:x}")
        
        # Architecture Detection
        # Based on observed values: M1=.hwx(4), M4=.hwx(7)
        # We map these to our internal logic:
        # 4 -> H13 (Linear NextPtr)
        # 7 -> H16 (Segmented)
        
        is_h16 = False
        if cpusubtype == 7:
            is_h16 = True
            print("Architecture: H16 (Segment-based)")
        elif cpusubtype == 4:
            is_h16 = False
            print("Architecture: H13 (Linear Linked-List)")
        else:
            print(f"Unknown architecture subtype {cpusubtype}, defaulting to heuristic.")
            # Fallback? Or just assume H13? Let's assume H13 for safety if low, H16 if high?
            is_h16 = (cpusubtype >= 7)

        f.seek(16)
        ncmds, sizeofcmds = struct.unpack('<II', f.read(8))

        text_offset = None
        text_addr = None
        current_pos = 32
        for i in range(ncmds):
            f.seek(current_pos)
            cmd_type, cmd_size = struct.unpack('<II', f.read(8))
            if cmd_type == LC_SEGMENT_64:
                seg_data = struct.unpack('<16sQQQQiiII', f.read(8 * 4 + 16 + 4 * 4))
                segname = seg_data[0].strip(b'\x00').decode('ascii')
                nsects = seg_data[7]
                for j in range(nsects):
                    sect_data = struct.unpack('<16s16sQQIIIIIIII', f.read(16 + 16 + 8 * 2 + 4 * 8))
                    sectname = sect_data[0].strip(b'\x00').decode('ascii')
                    if sectname == '__text' and segname == '__TEXT':
                        text_offset = sect_data[4]
                        text_addr = sect_data[2]
            current_pos += cmd_size

        if text_offset is None:
            print("Could not find __TEXT.__text section")
            return
            
        print(f"Text Section: Offset=0x{text_offset:x}, Addr=0x{text_addr:x}")

        current_offset = text_offset
        td_count = 0
        h16_regs = {} # Maintain register state across TDs for delta-based updates
        m1_regs = {}  # Maintain register state for M1 as well
        
        while True:
            f.seek(current_offset)
            
            # Unified Inner Loop for content
            # If H16, check for Segment Header first.
            
            if is_h16:
                # Read Word 0 to check for TD or Segment Header
                peek = f.read(4)
                if len(peek) < 4: break
                w0 = struct.unpack('<I', peek)[0]
                
                tid = w0 & 0xFFFF
                task_size = (w0 >> 16) & 0x7FF
                
                # 1. Prioritize TD Parsing (size > 9 confirms it's a TD with payload)
                if tid < 0x1000 and task_size > 9:
                    td_count += 1
                    f.seek(current_offset)
                    td_raw = f.read(task_size * 4)
                    if len(td_raw) < task_size * 4: break
                    td_words = struct.unpack(f'<{task_size}I', td_raw)
                    
                    exec_cycles = td_words[1] & 0xFFFF
                    regs = decode_register_stream(td_words)
                    h16_regs.update(regs) # Delta update
                    
                    # Register Mapping (verified for v17/M4):
                    reg0 = h16_regs.get(0, 0)
                    in_fmt = reg0 & 0x3
                    out_fmt = (reg0 >> 4) & 0x3
                    
                    in_w = h16_regs.get(1, 0)
                    in_h = h16_regs.get(2, 0)
                    in_ch = h16_regs.get(3, 0)
                    in_d = h16_regs.get(4, 0)
                    out_w = h16_regs.get(5, 0)
                    out_h = h16_regs.get(6, 0)
                    out_ch = h16_regs.get(7, 0)
                    out_d = h16_regs.get(8, 0)
                    batch = h16_regs.get(9, 0)
                    
                    print(f"--- TD {td_count} ---")
                    print(f"  current:  0x{current_offset:04x}")
                    print(f"  exec_cycles:  0x{exec_cycles:04x}")
                    print(f"  Input:  {in_w}x{in_h}x{in_ch} (B={batch}, D={in_d}), Type: {format_data_type(in_fmt, True)}")
                    print(f"  Output: {out_w}x{out_h}x{out_ch} (D={out_d}), Type: {format_data_type(out_fmt, True)}")
                    
                    if 10 in h16_regs:
                        convcfg = h16_regs[10]
                        kw = convcfg & 0x3F
                        kh = (convcfg >> 6) & 0x3F
                        sx = (convcfg >> 13) & 0x3
                        sy = (convcfg >> 15) & 0x3
                        px = (convcfg >> 17) & 0x1F
                        py = (convcfg >> 22) & 0x1F
                        ox = (convcfg >> 28) & 0x3
                        oy = (convcfg >> 30) & 0x3
                        print(f"  Conv:   K={kw}x{kh} S={sx}x{sy} P={px}x{py} O={ox}x{oy}")
                    
                    active_ne = (h16_regs.get(15, 0) >> 19) & 0x7
                    ocg_size = h16_regs.get(16, 0) & 0x7
                    print(f"  Config: ActiveNE={active_ne}, OCGSize={ocg_size}")
                    
                    # Planar Engine (PE) 0x4500
                    if (0x4500 >> 2) in h16_regs:
                        pe_op_word = h16_regs[0x4500 >> 2]
                        pe_en = (pe_op_word >> 19) & 1
                        if pe_en:
                            pe_op = pe_op_word & 0x3F
                            pe_bias1 = h16_regs.get(0x4504 >> 2, 0)
                            pe_scale1 = h16_regs.get(0x4508 >> 2, 0)
                            pe_bias2 = h16_regs.get(0x4510 >> 2, 0)
                            pe_scale2 = h16_regs.get(0x4514 >> 2, 0)
                            print(f"  PE:     Op={format_pe_op(pe_op)} En={pe_en}")
                            print(f"          Bias1=0x{pe_bias1:08x} Scale1=0x{pe_scale1:08x}")
                            if pe_bias2 or pe_scale2:
                                print(f"          Bias2=0x{pe_bias2:08x} Scale2=0x{pe_scale2:08x}")

                    # Neural Engine (NE) 0x4900
                    if (0x4900 >> 2) in h16_regs:
                        ne_kcfg = h16_regs[0x4900 >> 2]
                        ne_mcfg = h16_regs.get(0x4904 >> 2, 0)
                        
                        ne_fmt = ne_kcfg & 0x3
                        ne_op = ne_mcfg & 0x7
                        ne_nl = (ne_mcfg >> 16) & 0x3
                        ne_bias = (ne_mcfg >> 4) & 1
                        
                        print(f"  NE:     Fmt={format_data_type(ne_fmt, True)} Op={format_ne_op_mode(ne_op)} NL={format_nonlinear_mode(ne_nl)} Bias={ne_bias}")
                        if ne_bias:
                            print(f"          AccBias=0x{h16_regs.get(0x490C >> 2, 0):x} PostScale=0x{h16_regs.get(0x4910 >> 2, 0):x}")

                    # L2 Cache 0x4100
                    if (0x4148 >> 2) in h16_regs:
                        res_base = h16_regs.get(0x414C >> 2, 0) & 0x1FFFF
                        res_cs = h16_regs.get(0x4150 >> 2, 0) & 0x1FFFF
                        res_rs = h16_regs.get(0x4154 >> 2, 0) & 0x1FFFF
                        print(f"  L2:     ResBase=0x{res_base:x} ChanS=0x{res_cs:x} RowS=0x{res_rs:x}")
                    
                    # Advance with 16-byte alignment
                    current_offset += (task_size * 4 + 15) & ~15
                    continue

                # 2. Check for empty tasks (Filler/Separators)
                if tid < 0x1000 and task_size == 0:
                    current_offset += 16
                    continue
                
                # 3. Check for Segment Header (heuristics)
                is_large = (w0 & 4) != 0
                looks_like_header = False
                if (w0 & 0xFFFFFFF0) == 0:
                     looks_like_header = True
                elif (w0 & 0x00FF0000) != 0:
                     # Tighten heuristic: Segment flags usually have specific high bytes
                     high_byte = (w0 >> 16) & 0xFF
                     if high_byte in [0x57, 0x5D, 0x67] and task_size < 10: # Avoid TD overlap
                         looks_like_header = True
                
                if looks_like_header:
                    f.seek(current_offset)
                    header = decode_segment_header(f.read(40 if is_large else 8))
                    print(f"\n--- Segment Header ---")
                    print(f"  Flags: 0x{header['flags']:08x}")
                    print(f"  Type: {'Large' if header['is_large'] else 'Small'}")
                    print(f"  EON: {header['eon']}")
                    if header['is_large']:
                        print(f"  TrueAddr: 0x{header['true_addr']:016x}, Size: {header['true_size']}")
                        print(f"  FalseAddr: 0x{header['false_addr']:016x}, Size: {header['false_size']}")
                    
                    current_offset += header['size']
                    continue
                
                # 4. End marker Check
                if tid >= 0x1000 and tid != 0xFFFF:
                     print(f"Found end marker at 0x{current_offset:x} (TID 0x{tid:x})")
                     break

                current_offset += 4
                if td_count > 10000: break
                continue
            
            f.seek(current_offset)
            header_raw = f.read(40)
            if len(header_raw) < 40: break
            
            header_struct = struct.unpack('<IIIIIIIIII', header_raw)
            tid = header_struct[0] & 0xFFFF
            nid = (header_struct[0] >> 16) & 0xFF
            lnid = (header_struct[0] >> 24) & 1
            eon = (header_struct[0] >> 25) & 1
            
            exec_cycles = header_struct[1] & 0xFFFF
            next_size = (header_struct[1] >> 16) & 0x1FF
            
            flags = header_struct[6]
            next_ptr = header_struct[7]
            
            header8 = header_struct[8]
            ene = (header8 >> 24) & 0x7
            rbase0 = header8 & 0x1F
            rbase1 = (header8 >> 6) & 0x1F
            wbase = (header8 >> 12) & 0x1F
            tbase = (header8 >> 18) & 0x1F
            
            # The instruction stream follows the header (40 bytes) and ends at next_ptr
            # We assume next_ptr is relative to segment base? No, hwx_parsing.m uses absolute.
            # but usually it's within the __text section.
            
            stream_size = next_ptr - (current_offset - text_offset) - 40
            if stream_size > 0:
                stream_raw = f.read(stream_size)
                stream_words = struct.unpack(f'<{stream_size // 4}I', stream_raw)
                regs = decode_register_stream_m1(stream_words)
            m1_regs.update(regs) # Delta update

            td_count += 1

            
            # Use m1_regs to extract values (Indices from M1 Stream/Observation)
            # 0: InDim, 2: ChCfg, 3: Cin, 5: OutDim, 6: Cout, 7: ConvCfg
            in_dim = m1_regs.get(0, 0)
            in_w = in_dim & 0x7FFF
            in_h = (in_dim >> 16) & 0x7FFF
            
            ch_cfg = m1_regs.get(2, 0)
            in_fmt = ch_cfg & 0x3
            out_fmt = (ch_cfg >> 4) & 0x3
            
            in_ch = m1_regs.get(3, 0) & 0x1FFFF
            out_ch = m1_regs.get(6, 0) & 0x1FFFF
            
            out_dim = m1_regs.get(5, 0)
            out_w = out_dim & 0x7FFF
            out_h = (out_dim >> 16) & 0x7FFF
            
            conv_cfg = m1_regs.get(7, 0)
            k_w = conv_cfg & 0x1F
            k_h = (conv_cfg >> 5) & 0x1F
            ocg = (conv_cfg >> 10) & 0x7
            s_x = (conv_cfg >> 13) & 0x3
            s_y = (conv_cfg >> 15) & 0x3
            p_x = (conv_cfg >> 17) & 0x1F
            p_y = (conv_cfg >> 22) & 0x1F
            o_x = (conv_cfg >> 28) & 0x3
            o_y = (conv_cfg >> 30) & 0x3
            
            # 8: GroupConvCfg, 9: TileCfg
            group_conv = m1_regs.get(8, 0)
            num_groups = group_conv & 0x1FFF
            unicast_en = (group_conv >> 14) & 1
            
            tile_cfg = m1_regs.get(9, 0)
            tile_h = tile_cfg & 0xFFFF
            
            # C: Cfg
            cfg_word = m1_regs.get(12, 0)
            op_mode = cfg_word & 0x7
            sm_src = (cfg_word >> 11) & 1
            active_ne = (cfg_word >> 19) & 0x7
            acc_db_buf = (cfg_word >> 24) & 1
            nonlinear_mode = (cfg_word >> 27) & 0x3
            
            # L2 Cache (0x4800)
            l2_relu = (m1_regs.get(0x4801, 0) >> 16) & 1
            l2_pad = (m1_regs.get(0x4801, 0) >> 18) & 0x3
            l2_scfg = m1_regs.get(0x4802, 0)
            dst_type = l2_scfg & 0x3
            
            # NE / L2 (Observation: NE=0xc800, L2=0x4800)
            ne_kcfg = m1_regs.get(0xc800, 0)
            ne_fmt = ne_kcfg & 0x3
            ne_pal = (ne_kcfg >> 2) & 1
            ne_sparse = (ne_kcfg >> 8) & 1
            
            ne_mcfg = m1_regs.get(0xc801, 0)
            op_mode = ne_mcfg & 0xF
            nonlinear_mode = (ne_mcfg >> 16) & 0x3
            
            l2_cfg = m1_regs.get(0x4800, 0)
            l2_relu = l2_cfg & 1
            l2_pad = (l2_cfg >> 1) & 0x3
            
            l2_scfg = m1_regs.get(0x4801, 0)
            dst_type = l2_scfg & 0x3

            # PE (0x8800)
            pe_cfg = m1_regs.get(0x8800, 0)
            pe_en = (pe_cfg >> 1) & 1
            pe_op = (pe_cfg >> 2) & 0x7
            pe_relu = (pe_cfg >> 5) & 1
            
            pe_bs = m1_regs.get(0x8804, 0)
            pe_bias = pe_bs & 0xFFFF
            pe_scale = (pe_bs >> 16) & 0xFFFF
            
            pe_pre = m1_regs.get(0x8808, 0) & 0xFFFF
            pe_final = m1_regs.get(0x880c, 0)

            print(f"--- TD {td_count} ---")
            print(f"  current:  0x{current_offset:04x}")
            print(f"  exec_cycles:  0x{exec_cycles:04x}")
            print(f"  EON: {eon}, NextSize: {next_size}, NextPtr: 0x{next_ptr:08x}")
            print(f"  ENE: {ene}, RBases: {rbase0}/{rbase1}, WBase: {wbase}, TBase: {tbase}")
            print(f"  Input:  {in_w}x{in_h}x{in_ch}, Type: {format_data_type(in_fmt, False)}")
            print(f"  Output: {out_w}x{out_h}x{out_ch}, Type: {format_data_type(out_fmt, False)}")
            if op_mode == 0: # CONV
                print(f"  Conv:   K={k_w}x{k_h}, Stride={s_x+1}x{s_y+1}, Pad={p_x}x{p_y}, OCG={ocg}")
            if num_groups > 1 or unicast_en:
                print(f"  Groups: Count={num_groups}, Unicast={unicast_en}")
            if tile_h > 0:
                print(f"  TileH:  {tile_h}")
            
            print(f"  OpMode: {format_op_mode(op_mode)}, Nonlinear: {format_nonlinear_mode(nonlinear_mode)}")
            if pe_en:
                print(f"  PE:     Op={format_pe_op(pe_op)} En={pe_en} ReLU={pe_relu}")
                print(f"          Bias=0x{pe_bias:04x} Scale=0x{pe_scale:04x} Pre=0x{pe_pre:04x} Final=0x{pe_final:08x}")
            
            print(f"  NE:     Fmt={format_data_type(ne_fmt, False)}, Sparse={ne_sparse}, Palettized={ne_pal}")
            
            # TileDmaSrc (0x13800)
            tdma_src_en = (m1_regs.get(0x13801 >> 2, 0) >> 31) & 1
            if tdma_src_en:
                tdma_src_base = m1_regs.get(0x13802 >> 2, 0)
                tdma_src_row = m1_regs.get(0x13803 >> 2, 0) >> 6
                print(f"  TileDmaSrc: Base=0x{tdma_src_base:08x}, RowStride={tdma_src_row}")

            # TileDmaDst (0x17800)
            tdma_dst_en = (m1_regs.get(0x17801 >> 2, 0) >> 31) & 1
            if tdma_dst_en:
                tdma_dst_base = m1_regs.get(0x17802 >> 2, 0)
                tdma_dst_row = m1_regs.get(0x17803 >> 2, 0) >> 6
                print(f"  TileDmaDst: Base=0x{tdma_dst_base:08x}, RowStride={tdma_dst_row}")

            print(f"  L2:     ReLU={l2_relu}, Padding={l2_pad}")
            print(f"  Result: {format_l2_type(dst_type)}")
            
            print(f"  --- HW Block Register State ---")
            dump_m1_block(m1_regs, 0x0000, "Common", 64)
            dump_m1_block(m1_regs, 0x4800, "L2", 64)
            dump_m1_block(m1_regs, 0x8800, "PE", 64)
            dump_m1_block(m1_regs, 0xc800, "NE", 64)
            dump_m1_block(m1_regs, 0x13800, "TileDmaSrc", 64)
            dump_m1_block(m1_regs, 0x17800, "TileDmaDst", 64)
            dump_m1_block(m1_regs, 0x1f800, "KernelDma", 64)
            
            print(f"  NextPtr:  0x{next_ptr:04x}")
            if next_ptr == 0: break
            current_offset = text_offset + next_ptr
        
        print(f"\nTotal TDs parsed: {td_count}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 parse_ane_td.py <file.hwx>")
    else:
        parse_hwx(sys.argv[1])
