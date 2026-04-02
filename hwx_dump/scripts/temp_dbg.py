import struct, sys
from simulate_full_parse import parse_macho_text_text

with open("/tmp/resnet50_fp16_m1/67AD9D03B4D29705495AC9EEFF43121007EC1D347D6E08F73F4251CFC66226D0/model.hwx", "rb") as f:
    data = f.read()

file_off = parse_macho_text_text(data)
ane_data = data[file_off:]
offset = 0
for i in range(120):
    val = struct.unpack_from("<I", ane_data, offset + i*4)[0]
    count = val >> 26
    addr = val & 0x3ffffff
    print(f"Word {i} (0x{i*4:04x}): 0x{val:08x} -> count={count}, addr=0x{addr:05x}")
