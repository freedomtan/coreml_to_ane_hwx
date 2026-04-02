import re

with open("l2_block_dump.txt", "r") as f:
    lines = f.readlines()

offsets = {}

# Parse ldr/str instructions with x0
for line in lines:
    m = re.search(r'ldr\s+\w+,\s+\[x0,\s+#(0x[0-9a-fA-F]+)\]', line)
    if m:
        offsets[m.group(1)] = True
    m = re.search(r'str\w*\s+\w+,\s+\[x0,\s+#(0x[0-9a-fA-F]+)\]', line)
    if m:
        offsets[m.group(1)] = True

sorted_offsets = sorted([int(x, 16) for x in offsets.keys()])
for off in sorted_offsets:
    byte_addr = 0x4100 + (off - 0x3a8) if off >= 0x3a8 else off
    print(f"Offset +0x{off:x} -> HW 0x{byte_addr:x}")
