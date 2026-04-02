import struct
import sys

# __text starts at 0x2c000
# User says 0x0 should be 0x00e000e0
# My find_pattern found 0x00e000e0 at 0x2c128 (relative 0x128)

FILE = "/tmp/resnet50_fp16_m1/67AD9D03B4D29705495AC9EEFF43121007EC1D347D6E08F73F4251CFC66226D0/model.hwx"

with open(FILE, "rb") as f:
    f.seek(0x2c000 + 0x120)
    data = f.read(64)
    for i in range(0, 64, 4):
        val = struct.unpack_from("<I", data, i)[0]
        off = 0x120 + i
        count = val >> 26
        addr = val & 0x3ffffff
        print(f"Rel Offset 0x{off:03x}: 0x{val:08x} -> count={count}, addr=0x{addr:05x}")
