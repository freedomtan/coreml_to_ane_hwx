import sys, subprocess

cmd = ["llvm-objdump-mp-19", "-d", "ANECompiler"]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)

recent_adds = []

for line in p.stdout:
    line = line.strip()
    if ", #0x21c" in line and "add\tx" in line:
        recent_adds.append((line, 0))
    
    new_adds = []
    for add_line, dist in recent_adds:
        if dist < 40: 
            if "str\tx" in line and ", #0x80]" in line:
                print("FOUND MATCH:")
                print(add_line)
                print(line)
                print("---")
            new_adds.append((add_line, dist + 1))
    recent_adds = new_adds
