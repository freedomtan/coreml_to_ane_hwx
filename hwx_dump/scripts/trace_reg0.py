import struct
import sys

# __text starts at 0x2c000
FILE = "/tmp/resnet50_fp16_m1/67AD9D03B4D29705495AC9EEFF43121007EC1D347D6E08F73F4251CFC66226D0/model.hwx"

with open(FILE, "rb") as f:
    f.seek(0x2c000 + 40) # Skip header
    data = f.read(2048) # Read a chunk of payload
    
    words = []
    for i in range(0, len(data), 4):
        words.append(struct.unpack_from("<I", data, i)[0])

    reg_map = {}
    w_idx = 0
    while w_idx < len(words):
        hdr = words[w_idx]
        w_idx += 1
        count = (hdr >> 26) & 0x3f
        addr = hdr & 0x3ffffff
        num_vals = count + 1
        
        for i in range(num_vals):
            if w_idx < len(words):
                val = words[w_idx]
                if (addr + i) == 0:
                    print(f"Register 0 write at word index {w_idx-1} (rel offset 0x{40 + (w_idx-1)*4:03x}): value=0x{val:08x}")
                reg_map[addr + i] = val
                w_idx += 1
            else:
                break
    
    print(f"Final Register 0 value: 0x{reg_map.get(0, 0):08x}")
