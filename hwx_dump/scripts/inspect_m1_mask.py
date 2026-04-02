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
    while idx < len(words) and found_mask < 5:
        w = words[idx]
        idx += 1
        addr = w & ((1 << 26) - 1)
        mask = (w >> 26) & 0x3F
        
        if mask != 0:
            print(f"[{idx-1:4d}] HDR: 0x{w:08x} => Addr: 0x{addr:08x} Mask: {mask:02x}")
            for i in range(10):
                if idx < len(words):
                    print(f"           0x{words[idx]:08x}")
                    idx+=1
            found_mask += 1
        else:
            idx += 1 # skip val

if __name__ == "__main__":
    main()
