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
        if cmd == LC_ANE_MAPPED_REGION:
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

    # In M1 resnet50, the first task that worked was at offset 0x3ac0 in the region
    offset = 0x3ac0
    words = struct.unpack_from(f"<{0x1000//4}I", ane_data, offset)
    
    print("Header bytes (at 0x3ac0 in mapped region):")
    for i in range(10):
        print(f"[{i:2d}] 0x{words[i]:08x}")

    print("\nStream at 0x3ac0 + 40 bytes:")
    idx = 10 # skip 40 bytes header
    parsed = 0
    while idx < len(words) and parsed < 30:
        w = words[idx]
        idx += 1
        
        count = (w >> 26) & 0x3F # Top 6 bits
        addr = w & 0x3FFFFFF     # Bottom 26 bits
        
        print(f"[{parsed:4d}] Raw 0x{w:08x} => Count: {count:2d}, Addr: 0x{addr:06x}")
        
        num_vals = count if count > 0 else 1
        for i in range(num_vals):
            if idx < len(words):
                print(f"           +{i:2d}: 0x{words[idx]:08x}")
                idx += 1
        parsed += 1

if __name__ == "__main__":
    main()
