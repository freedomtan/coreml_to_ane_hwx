import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    ane_data = data
    start_off = 0x3ac0
    words = struct.unpack_from(f"<{0x1000//4}I", ane_data, start_off)
    
    idx = 10
    print("M1 Stream Words:")
    for _ in range(50):
        if idx >= len(words): break
        w = words[idx]
        print(f"[{idx:4d}] 0x{w:08x} -> Top6={(w>>26)&0x3F:2d}, Bot6={w&0x3F:2d}")
        idx += 1

if __name__ == "__main__":
    main()
