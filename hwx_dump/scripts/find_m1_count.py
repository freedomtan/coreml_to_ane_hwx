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

    words = struct.unpack_from(f"<{len(data[start_off+40:])//4}I", data, start_off + 40)
    
    idx = 0
    found_mask = 0
    while idx < len(words) and found_mask < 10:
        w = words[idx]
        idx += 1
        addr = w & ((1 << 26) - 1)
        count = (w >> 26) & 0x3F
        
        if count != 0:
            print(f"[{found_mask:4d}] Addr: 0x{addr:05x} (val {addr*4:08x}) Count: {count}")
            # print the next few words so we can see what makes sense
            for i in range(10):
                if idx < len(words):
                    print(f"           +0x{i*4:02x}: 0x{words[idx]:08x}")
                    idx += 1
            found_mask += 1
        else:
            # count == 0 means 1 word follows
            idx += 1

if __name__ == "__main__":
    main()
