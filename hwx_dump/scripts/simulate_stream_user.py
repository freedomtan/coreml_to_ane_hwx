import struct
import sys

MH_MAGIC_64, LC_SEGMENT_64 = 0xfeedfacf, 0x19

def parse_macho_text_text(data):
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
                        # sectname(16) + segname(16) + addr(8) + size(8) + offset(4)
                        size = struct.unpack_from("<Q", data, sect_offset + 32 + 8)[0]
                        file_off = struct.unpack_from("<I", data, sect_offset + 32 + 16)[0]
                        return data[file_off : file_off + size]
                    sect_offset += 80
        offset += cmdsize
    return None

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ane_data = parse_macho_text_text(data)
    words = struct.unpack_from(f"<{len(ane_data)//4}I", ane_data, 0)
    
    # Task 0 starts at offset 0 (since it's the __text section)
    # The header is 40 bytes (10 words)
    print("Header bytes (first 40 bytes):")
    for i in range(10):
        print(f"[{i:2d}] 0x{words[i]:08x}")

    print("\nStream:")
    idx = 10 # skip 40 bytes header
    parsed = 0
    reg_map = {}
    
    while idx < len(words) and parsed < 50:
        w = words[idx]
        idx += 1
        
        # User: offset+0x124 is the 26-bit address, 6-bit count
        count = (w >> 26) & 0x3F # Top 6 bits
        addr = w & 0x3FFFFFF     # Bottom 26 bits
        
        print(f"[{parsed:4d}] Raw 0x{w:08x} => Count: {count:2d}, Addr: 0x{addr:06x} (0x{addr*4:04x})")
        
        num_vals = count if count > 0 else 1
        for i in range(num_vals):
            if idx < len(words):
                val = words[idx]
                reg_map[addr + i] = val
                print(f"           +{i:2d} (0x{(addr+i)*4:04x}): 0x{val:08x}")
                idx += 1
        parsed += 1

    print("\nChecking for Common block registers (started from 0x0):")
    for i in range(10):
        if i in reg_map:
            print(f"0x{i*4:03x} = 0x{reg_map[i]:08x}")
        else:
            print(f"0x{i*4:03x} = Not mapped")

if __name__ == "__main__":
    main()
