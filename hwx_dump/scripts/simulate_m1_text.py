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
                        file_off = struct.unpack_from("<I", data, sect_offset + 48)[0]
                        size = struct.unpack_from("<Q", data, sect_offset + 40)[0]
                        return data[file_off : file_off + size]
                    sect_offset += 80
        offset += cmdsize
    return None

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ane_data = parse_macho_text_text(data)
    if not ane_data:
        print("Could not find __TEXT.__text")
        return

    words = struct.unpack_from(f"<{len(ane_data)//4}I", ane_data, 0)
    
    print("Header bytes (first 40 bytes):")
    for i in range(10):
        print(f"[{i:2d}] 0x{words[i]:08x}")

    print("\nStream:")
    idx = 10 # skip 40 bytes header
    parsed = 0
    while idx < len(words) and parsed < 30:
        w = words[idx]
        idx += 1
        
        count = (w >> 26) & 0x3F # Top 6 bits
        addr = w & 0x3FFFFFF     # Bottom 26 bits
        
        print(f"[{parsed:4d}] Raw 0x{w:08x} => Count: {count:2d}, Addr: 0x{addr:06x} (0x{addr*4:04x})")
        
        if count == 0:
            print(f"           + 0: 0x{words[idx]:08x}")
            idx += 1
        else:
            for i in range(count):
                if idx < len(words):
                    print(f"           +{i:2d}: 0x{words[idx]:08x}")
                    idx += 1
        parsed += 1

if __name__ == "__main__":
    main()
