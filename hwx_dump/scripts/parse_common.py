import re
import sys

def parse_dump(file_path, sym_path):
    # Load symbols to map address to function name
    symbols = {}
    with open(sym_path, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 3:
                addr = parts[0].zfill(16)
                func = " ".join(parts[2:])
                # Clean up function name
                func = func.replace("ZinAneTd<17u>::", "")
                func = func.split("(")[0]
                symbols["0x" + addr.lstrip("0").lower()] = func

    # Parse disassembly
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
                
            # Look for str/ldr [x..., #offset]
            m = re.search(r'\[(x\d+|x19), #0x([0-9a-fA-F]+)\]', instr)
            if m:
                offset_hex = m.group(2)
                offset_val = int(offset_hex, 16)
                
                # Verify it's in the common block bounds roughly (+0x1f8 to +0x250)
                if 0x1f8 <= offset_val <= 0x258:
                    if current_func not in results:
                        results[current_func] = set()
                    results[current_func].add(offset_hex)

    # Print results sorted
    for func in sorted(results.keys()):
        offsets = ", ".join(["+0x" + off for off in sorted(results[func])])
        print(f"{func}: {offsets}")

if __name__ == '__main__':
    parse_dump('common_block_dump.txt', 'all_common_setters.txt')
