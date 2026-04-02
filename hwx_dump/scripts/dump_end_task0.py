import struct
import sys

# __text starts at 0x2c000
FILE = "/tmp/resnet50_fp16_m1/67AD9D03B4D29705495AC9EEFF43121007EC1D347D6E08F73F4251CFC66226D0/model.hwx"

with open(FILE, "rb") as f:
    f.seek(0x2c000 + 40) # Task 0 payload start
    data = f.read(2048)
    # Dump last 128 bytes of the 2048 chunk
    for i in range(len(data)-128, len(data), 4):
        val = struct.unpack_from("<I", data, i)[0]
        print(f"Rel Offset 0x{40 + i:03x}: 0x{val:08x}")
