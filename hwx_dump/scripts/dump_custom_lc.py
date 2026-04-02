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
             print(f"LC_ANE_MAPPED_REGION size {cmdsize}")
             words = struct.unpack_from(f"<{cmdsize//4}I", data, offset)
             for j, w in enumerate(words):
                 s = struct.pack("<I", w)
                 print(f"  Word {j:2d} (off {j*4:2d}): 0x{w:08x} '{s}'")
        offset += cmdsize

if __name__ == "__main__":
    main()
