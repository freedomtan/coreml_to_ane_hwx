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
    
    print("Exact __texts head (Task 0):")
    for i in range(15):
        print(f"Word {i:2d} (0x{i*4:02x}): 0x{words[i]:08x}")

if __name__ == "__main__":
    main()
