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
            print(f"Task 0 at 0x{start_off:x}")
            break

    if start_off < 0:
        return

    # Assume header is 40 bytes, words follow
    words = struct.unpack_from("<400I", data, start_off + 40)
    
    idx = 0
    parsed = 0
    while idx < len(words) and parsed < 20:
        w = words[idx]
        idx += 1
        addr = w & ((1 << 26) - 1)
        mask = (w >> 26) & 0x3F
        print(f"[{idx-1:4d}] HDR: 0x{w:08x} => Addr: 0x{addr:08x} (val {addr*4:08x}) Mask: {mask:02x} ({bin(mask)[2:].zfill(6)})")
        
        # Read values based on mask
        if mask == 0:
            # Maybe burst? Or maybe 0 means 1 register?
            # Let's see the next word
            val = words[idx]
            idx += 1
            print(f"       VAL: 0x{val:08x}")
        else:
            # masked?
            print(f"       Has mask {mask}")
            # we just print the next few words
            for i in range(5):
                if idx < len(words):
                    print(f"           0x{words[idx]:08x}")
                    idx+=1
        parsed += 1

if __name__ == "__main__":
    main()
