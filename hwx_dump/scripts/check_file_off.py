import struct
import sys

MH_MAGIC_64, LC_SEGMENT_64 = 0xfeedfacf, 0x19
HWX_MAGIC = 0xbeefface

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

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
                        print(f"FOUND __TEXT.__text at file offset: 0x{file_off:x}")
                        
                        w74 = struct.unpack_from("<I", data, file_off + 0x128)[0]
                        print(f"Word at 0x128 in __text: 0x{w74:08x}")
                    sect_offset += 80
        offset += cmdsize

if __name__ == "__main__":
    main()
