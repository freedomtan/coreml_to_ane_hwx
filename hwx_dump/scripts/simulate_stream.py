import struct
import sys

def main():
    with open(sys.argv[1], "rb") as f:
        data = f.read()

    # M1 resnet50 task 0
    start_off = 0x3ac0
    words = struct.unpack_from(f"<{0x3000//4}I", data, start_off)
    
    idx = 10 # skip 40-byte header
    reg_map = {}
    
    parsed = 0
    while idx < len(words) and parsed < 100:
        w = words[idx]
        if w == 0:
            # Maybe padding at end
            idx+=1
            continue
            
        count = (w >> 26) & 0x3F
        addr = w & 0x3FFFFFF
        idx += 1
        
        num_vals = count if count > 0 else 1
        for i in range(num_vals):
            if idx < len(words):
                val = words[idx]
                reg_map[addr + i] = val
                print(f"Write [0x{(addr+i)*4:04x}] = 0x{val:08x}")
                idx += 1
        parsed += 1
        
    print("\nLooking for Common (0x128):")
    if (0x128 // 4) in reg_map:
        print(f"0x128 = 0x{reg_map[0x128//4]:08x}")
    else:
        print("Not mapped!")

if __name__ == "__main__":
    main()
