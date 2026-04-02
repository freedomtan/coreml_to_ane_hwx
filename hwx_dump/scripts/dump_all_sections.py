import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for i in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<2I", data, offset)
        if cmd == 0x19: # LC_SEGMENT_64
            segname = data[offset+8:offset+24].strip(b'\x00').decode('ascii', errors='ignore')
            nsects = struct.unpack_from("<I", data, offset + 64)[0]
            print(f"LC {i:2d} Segment: {segname} with {nsects} sections")
            sect_offset = offset + 72
            for j in range(nsects):
                sectname = data[sect_offset:sect_offset+16].strip(b'\x00').decode('ascii', errors='ignore')
                file_off = struct.unpack_from("<I", data, sect_offset + 48)[0]
                print(f"  Sec {j}: {sectname} file_off: 0x{file_off:x}")
                sect_offset += 80
        offset += cmdsize

if __name__ == "__main__":
    main()
