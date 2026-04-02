import struct
import sys

MH_MAGIC_64, LC_SEGMENT_64 = 0xfeedfacf, 0x19
HWX_MAGIC = 0xbeefface

def parse_macho_text_text(data):
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != MH_MAGIC_64 and magic != HWX_MAGIC: return None
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        if cmd == LC_SEGMENT_64:
            segname = data[offset+8:offset+24].strip(b'\x00').decode('ascii', errors='ignore')
            if segname == "__TEXT":
                nsects = struct.unpack_from("<I", data, offset + 64)[0]
                sect_offset = offset + 72
                for _ in range(nsects):
                    sectname = data[sect_offset:sect_offset+16].strip(b'\x00').decode('ascii', errors='ignore')
                    if sectname == "__text":
                        size = struct.unpack_from("<Q", data, sect_offset + 32 + 8)[0]
                        file_off = struct.unpack_from("<I", data, sect_offset + 32 + 16)[0]
                        return file_off
                    sect_offset += 80
        offset += cmdsize
    return None

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    file_off = parse_macho_text_text(data)
    if file_off is None:
        print("Could not find __TEXT.__text")
        return

    ane_data = data[file_off:]
    
    offset = 0
    task_idx = 0
    
    while offset + 40 <= len(ane_data):
        # 40 byte header
        hdr_words = struct.unpack_from("<10I", ane_data, offset)
        tid = hdr_words[4] & 0xffff
        nid = (hdr_words[4] >> 16) & 0xff
        lnid_eon = (hdr_words[4] >> 24) & 0xff
        exe_cycles = hdr_words[6]
        next_size_pad = hdr_words[7] & 0x1ff
        flags = hdr_words[8]
        next_pointer = hdr_words[9]
        
        if next_pointer == 0 and exe_cycles == 0:
            break
            
        print(f"      [ANE Task {task_idx} @ 0x{offset:x}]")
        print(f"        TID: 0x{tid:04x} NID: 0x{nid:02x} LNID: {lnid_eon & 1} EON: {(lnid_eon >> 1) & 1}")
        max_payload_bytes = len(ane_data) - offset - 40
        if next_pointer <= offset + 40:
            if exe_cycles == 0: break
            # Use next_size_pad as a fallback if next_pointer is missing (0)
            next_pointer = offset + 40 + min(next_size_pad * 4, max_payload_bytes)
            
        words_count = min(max_payload_bytes, next_pointer - offset - 40) // 4
        if words_count <= 0:
            words = []
        else:
            words = struct.unpack_from(f"<{words_count}I", ane_data, offset + 40)
        reg_map = {}
        idx = 0
        while idx < len(words):
            hdr = words[idx]
            idx += 1
            if hdr == 0:
                continue
            count = (hdr >> 26) & 0x3F
            addr = hdr & 0x3FFFFFF
            num_vals = count + 1
            for i in range(num_vals):
                if idx < len(words):
                    reg_map[addr + i] = words[idx]
                    idx += 1
                    
        # Check Common block at 0x0
        if 0 in reg_map:
            win = reg_map[0] & 0x3fff
            hin = (reg_map[0] >> 16) & 0x3fff
            cin = reg_map[1] & 0x7ffff
            wout = reg_map[4] & 0x3fff
            hout = (reg_map[4] >> 16) & 0x3fff
            cout = reg_map[5] & 0x7ffff
            
            infmt = (reg_map[7] >> 5) & 0x7
            outfmt = (reg_map[7] >> 8) & 0x7
            
            fmt_names = {0: "INT8", 1: "UINT8", 2: "FLOAT16"}
            infmt_name = fmt_names.get(infmt, "Unknown")
            outfmt_name = fmt_names.get(outfmt, "Unknown")
            
            print(f"        {win} x {hin} x {cin} ({infmt_name}) -> {wout} x {hout} x {cout} ({outfmt_name})")
            
            
        for b_name, b_addr in [
            ("L2 Cache", 0x4800),
            ("PE", 0x8800),
            ("NE", 0xc800),
            ("TileDMA Src", 0x13800),
            ("TileDMA Dst", 0x17800),
            ("KernelDMA", 0x1f800),
        ]:
            found = 0
            for i in range(b_addr // 4, (b_addr // 4) + 0x100):
                if i in reg_map:
                    found += 1
            print(f"        {b_name} mapped registers: {found}")
            
        print("    --- DEBUG: all keys > 0x1000 ---")
        for k in sorted(reg_map.keys()):
            if k > 0x1000:
                print(f"       0x{k*4:05x}: 0x{reg_map[k]:08x}")
            
        task_idx += 1
        
        # Advance
        offset = next_pointer

if __name__ == "__main__":
    main()
