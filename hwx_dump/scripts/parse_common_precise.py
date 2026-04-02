import re
import subprocess

def parse_common_setters():
    cmd1 = 'nm /Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/ANECompiler | c++filt | grep "ZinAneTd<17u>::SetCommon"'
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

    results = {}
    for addr, func in symbols.items():
        cmd2 = f"/Users/freedom/work/ios-hacking/ipsw-git/ipsw macho disass /Users/freedom/work/coreml_to_ane_hwx_hacks/hwx_dump/ANECompiler --vaddr {addr} --count 60 --force --quiet --demangle"
        try:
            output = subprocess.check_output(cmd2, shell=True).decode('utf-8')
            for instr in output.split('\n'):
                m = re.search(r'(str|strb|strh|ldr|ldrb|ldrh)\s+[wxs]\d+,\s*\[(x0|x1|x2|x19|x20|x21),\s*#0x([0-9a-fA-F]+)\]', instr)
                if m:
                    op = m.group(1)
                    offset_hex = m.group(3)
                    offset_val = int(offset_hex, 16)
                    
                    if op.startswith('str') and 0x1f0 <= offset_val <= 0x254:
                        if func not in results:
                            results[func] = set()
                        results[func].add(offset_hex)
        except subprocess.CalledProcessError:
            pass

    for func in sorted(results.keys()):
        offsets = ", ".join(["+0x" + off for off in sorted(results[func])])
        print(f"{func}: {offsets}")

if __name__ == '__main__':
    parse_common_setters()
