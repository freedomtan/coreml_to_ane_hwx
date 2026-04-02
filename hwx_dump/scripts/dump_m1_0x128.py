import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    # M1 resnet50 task 0
    start_off = 0x3ac0
    words = struct.unpack_from(f"<500I", data, start_off)
    
    print("Words at byte offset 0x128 (Word 74):")
    for i in range(70, 85):
        w = words[i]
        print(f"Word {i:3d} (offset 0x{i*4:03x}): 0x{w:08x}")

if __name__ == "__main__":
    main()
