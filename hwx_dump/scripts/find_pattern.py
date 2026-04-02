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
            segname = data[offset+8:offset+24].strip(b"\x00").decode("ascii", errors="ignore")
            if segname == "__TEXT":
                nsects = struct.unpack_from("<I", data, offset + 64)[0]
                sect_offset = offset + 72
                for _ in range(nsects):
                    sectname = data[sect_offset:sect_offset+16].strip(b"\x00").decode("ascii", errors="ignore")
                    if sectname == "__text":
                        return struct.unpack_from("<I", data, sect_offset + 32 + 16)[0]
                    sect_offset += 80
        offset += cmdsize
    return None

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    text_off = parse_macho_text_text(data)
    print(f"__text file offset: 0x{text_off:x}")

    pattern = b"\xe0\x00\xe0\x00"
    pos = data.find(pattern)
    while pos != -1:
        rel_off = pos - text_off
        print(f"Found 0x00e000e0 at file offset 0x{pos:x} (relative to __text: 0x{rel_off:x} / {rel_off//4} words)")
        pos = data.find(pattern, pos + 1)

if __name__ == "__main__":
    main()
