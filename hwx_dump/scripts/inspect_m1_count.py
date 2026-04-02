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

    # Assume header is 40 bytes, words follow
    words = struct.unpack_from(f"<{len(data[start_off+40:])//4}I", data, start_off + 40)
    
    idx = 0
    parsed = 0
    while idx < len(words) and parsed < 30:
        w = words[idx]
        idx += 1
        addr = w & ((1 << 26) - 1)
        count = (w >> 26) & 0x3F
        
        # If count == 0, it likely means 1 word follow.
        # Let's see how many words follow.
        num_words = count if count > 0 else 1
        
        vals = []
        for i in range(num_words):
            if idx < len(words):
                vals.append(words[idx])
                idx += 1
                
        print(f"[{parsed:4d}] Addr: 0x{addr:05x} (val {addr*4:08x}) Count: {count}")
        for i, val in enumerate(vals):
             print(f"           +0x{i*4:02x}: 0x{val:08x}")
             
        parsed += 1

if __name__ == "__main__":
    main()
