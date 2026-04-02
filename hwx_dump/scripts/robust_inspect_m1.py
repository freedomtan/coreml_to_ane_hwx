import struct
import sys

MH_MAGIC_64, LC_SEGMENT_64, LC_ANE_MAPPED_REGION = 0xfeedfacf, 0x19, 0x40
HWX_MAGIC = 0xbeefface

def parse_macho(data):
    magic = struct.unpack_from("<I", data, 0)[0]
    if magic != MH_MAGIC_64 and magic != HWX_MAGIC: return None
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        if cmd == LC_SEGMENT_64:
            segname = data[offset+8:offset+24].strip(b'\x00').decode()
            if segname == "__TEXT":
                nsects = struct.unpack_from("<I", data, offset + 64)[0]
                sect_offset = offset + 72
                for _ in range(nsects):
                    sectname = data[sect_offset:sect_offset+16].strip(b'\x00').decode()
                    if sectname == "__text":
                        file_off = struct.unpack_from("<I", data, sect_offset + 48)[0]
                        size = struct.unpack_from("<Q", data, sect_offset + 40)[0]
                        return data[file_off : file_off + size]
                    sect_offset += 80
        elif cmd == LC_ANE_MAPPED_REGION:
            file_off = struct.unpack_from("<I", data, offset + 8)[0]
            size = struct.unpack_from("<I", data, offset + 12)[0]
            return data[file_off : file_off + size]
        offset += cmdsize
    return None

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ane_data = parse_macho(data)
    if not ane_data:
        print("Not an ANE file")
        return

    # In M1 resnet50, first Task 0 is at offset 0x3ac0
    offset = 0x3ac0
    
    words = struct.unpack_from(f"<{len(ane_data)//4}I", ane_data, 0)
    start_word = offset // 4
    
    print("Header bytes:")
    for i in range(10):
        print(f"[{i:2d}] 0x{words[start_word + i]:08x}")

    print("\nStream:")
    idx = start_word + 10 # skip 40 bytes header
    parsed = 0
    while idx < len(words) and parsed < 30:
        w = words[idx]
        idx += 1
        
        # User: "The address is 26-bit, the mask is 6-bit. oops, it's not mask. it's count"
        # Let's try to infer if count is top or bottom 6 bits by printing both
        count_top = (w >> 26) & 0x3F
        addr_bot  = w & 0x3FFFFFF
        
        count_bot = w & 0x3F
        addr_top  = (w >> 6) & 0x3FFFFFF
        
        print(f"[{parsed:4d}] Raw 0x{w:08x} -> Top=C:{count_top:2d},A:0x{addr_bot:06x} | Bot=C:{count_bot:2d},A:0x{addr_top:06x}")
        
        # Let's assume count_top is right because we saw it earlier
        count = count_top
        
        # count=0 might mean 1 word. Let's see:
        num_vals = count if count > 0 else 1
        for i in range(num_vals):
            if idx < len(words):
                print(f"           +{i:2d}: 0x{words[idx]:08x}")
                idx += 1
        parsed += 1

if __name__ == "__main__":
    main()
