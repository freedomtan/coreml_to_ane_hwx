import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    print(f"Number of Load Commands: {ncmds}")
    for i in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        print(f"LC {i:2d}: Cmd 0x{cmd:02x} cmdsize {cmdsize}")
        if cmd == 0x19: # segment 64
             segname = data[offset+8:offset+24].strip(b'\x00').decode('ascii', errors='ignore')
             print(f"       Segment: {segname}")
        offset += cmdsize

if __name__ == "__main__":
    main()
