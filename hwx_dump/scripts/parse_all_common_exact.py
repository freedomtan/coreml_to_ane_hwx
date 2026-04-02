import re
import subprocess
import collections

def parse_all_methods():
    # Get all ZinAneTd<17u> setters
    cmd1 = 'nm /Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/ANECompiler | c++filt | grep "ZinAneTd<17u>::Set"'
    try:
        symbols_raw = subprocess.check_output(cmd1, shell=True).decode('utf-8')
    except Exception as e:
        print(f"Error: {e}")
        return

    symbols = {}
    for line in symbols_raw.split('\n'):
        parts = line.strip().split()
        if len(parts) >= 3:
            addr = parts[0].zfill(16)
            func = " ".join(parts[2:])
            func_clean = func.replace("ZinAneTd<17u>::", "").split("(")[0]
            symbols["0x" + addr.lstrip("0").lower()] = func_clean

    offset_map = collections.defaultdict(set)
    for addr, func in symbols.items():
        cmd2 = f"/Users/freedom/work/ios-hacking/ipsw-git/ipsw macho disass /Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/ANECompiler --vaddr {addr} --count 100 --force --quiet --demangle"
        try:
            output = subprocess.check_output(cmd2, shell=True).decode('utf-8')
            for instr in output.split('\n'):
                m = re.search(r'(str|strb|strh|ldr|ldrb|ldrh)\s+[wxs]\d+,\s*\[(x0|x1|x2|x19|x20|x21),\s*#0x([0-9a-fA-F]+)\]', instr)
                if m:
                    op = m.group(1)
                    offset_hex = m.group(3)
                    offset_val = int(offset_hex, 16)
                    
                    if op.startswith('str') and 0x1f8 <= offset_val <= 0x250:
                        offset_map[offset_hex.lower()].add(func)
        except subprocess.CalledProcessError:
            pass

    for off in sorted(offset_map.keys(), key=lambda x: int(x, 16)):
        funcs = ", ".join(sorted(offset_map[off]))
        word_idx = (int(off, 16) - 0x1f8) // 4
        print(f"Offset +0x{off} (Word {word_idx}): {funcs}")

if __name__ == '__main__':
    parse_all_methods()
