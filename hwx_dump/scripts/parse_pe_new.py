import re
import sys

def parse_dump(file_path, sym_path):
    symbols = {}
    with open(sym_path, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 3:
                addr = parts[0].zfill(16)
                func = " ".join(parts[2:])
                func = func.replace("ZinAneTd<17u>::", "").split("(")[0]
                symbols["0x" + addr.lstrip("0").lower()] = func

    current_func = "Unknown"
    results = {}
    
    with open(file_path, 'r') as f:
        for line in f:
            parts = line.strip().split(":")
            if len(parts) < 2: continue
            addr = parts[0].strip()
            instr = parts[1].strip()
            
            if addr in symbols:
                current_func = symbols[addr]
                
            m = re.search(r'(str|strb|strh|ldr|ldrb|ldrh)\s+[wxs]\d+,\s*\[(x\d+|x19),\s*#0x([0-9a-fA-F]+)\]', instr)
            if m:
                op = m.group(1)
                offset_hex = m.group(3)
                offset_val = int(offset_hex, 16)
                
                # PE block offset range: ~+0x450
                if 0x450 <= offset_val <= 0x600 and op.startswith('str') and "SetPE" in current_func:
                    if current_func not in results:
                        results[current_func] = set()
                    results[current_func].add(offset_hex)

    for func in sorted(results.keys()):
        offsets = ", ".join(["+0x" + off for off in sorted(results[func])])
        print(f"{func}: {offsets}")

if __name__ == '__main__':
    parse_dump('/Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/pe_block_dump.txt', '/Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/all_pe_setters.txt')
