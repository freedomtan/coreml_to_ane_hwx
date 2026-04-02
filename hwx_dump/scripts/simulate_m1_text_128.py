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
    words = struct.unpack_from(f"<{len(ane_data)//4}I", ane_data, 0)
    
    print(f"Word 74 (0x128): 0x{words[74]:08x}")
    print(f"Word 75 (0x12c): 0x{words[75]:08x}")

if __name__ == "__main__":
    main()
