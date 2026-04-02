import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    # Find magic
    start_off = -1
    for o in range(0, len(data) - 40, 4):
        h = struct.unpack_from("<I", data, o)[0]
        if 0 < (h & 0xffff) < 0x1000 and 10 < ((h >> 16) & 0x7ff) < 0x800:
            start_off = o
            break

    if start_off < 0:
        return

    print("First 64 bytes of Task 0:")
    words = struct.unpack_from("<32I", data, start_off)
    for i in range(len(words)):
        print(f"0x{start_off + i*4:04x} (Word {i:2d}): 0x{words[i]:08x}")

if __name__ == "__main__":
    main()
