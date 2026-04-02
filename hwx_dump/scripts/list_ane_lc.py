import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for i in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        if cmd == 0x40:
             file_off = struct.unpack_from("<I", data, offset + 8)[0]
             size = struct.unpack_from("<I", data, offset + 12)[0]
             print(f"LC {i:2d}: file_off 0x{file_off:08x}, size 0x{size:08x}")
        offset += cmdsize

if __name__ == "__main__":
    main()
