import os
import re
import subprocess

def parse_setters(sym_file):
    symbols = {}
    with open(sym_file, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 3:
                addr = parts[0].zfill(16)
                func = " ".join(parts[2:])
                func = func.replace("ZinAneTd<17u>::", "").split("(")[0]
                symbols["0x" + addr.lstrip("0").lower()] = func

    results = {}
    
    for addr, func in symbols.items():
        # Disassemble each function
        cmd = f"/Users/freedom/work/ios-hacking/ipsw-git/ipsw macho disass /Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/ANECompiler --vaddr {addr} --count 50 --force --quiet --demangle"
        try:
            output = subprocess.check_output(cmd, shell=True).decode('utf-8')
            for instr in output.split('\n'):
                # Look for str writes to x0 or x19
                m = re.search(r'(str|strb|strh|ldr|ldrb|ldrh)\s+[wxs]\d+,\s*\[(x0|x1|x2|x19|x20),\s*#0x([0-9a-fA-F]+)\]', instr)
                if m:
                    op = m.group(1)
                    offset_hex = m.group(3)
                    offset_val = int(offset_hex, 16)
                    
                    # CacheDMA typically mapped around +0x52c
                    if 0x510 <= offset_val <= 0x600 and op.startswith('str'):
                        if func not in results:
                            results[func] = set()
                        results[func].add(offset_hex)
        except subprocess.CalledProcessError:
            pass

    for func in sorted(results.keys()):
        offsets = ", ".join(["+0x" + off for off in sorted(results[func])])
        print(f"{func}: {offsets}")

if __name__ == '__main__':
    parse_setters('/Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/all_cachedma_setters.txt')
