import sys, subprocess

cmd = ["llvm-objdump-mp-19", "-d", "ANECompiler"]
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True)

lines = []
for line in p.stdout:
    lines.append(line.strip())

print("Finished reading, scanning...")

for i in range(len(lines)):
    if "#0x80]" in lines[i] and "str\tx" in lines[i]:
        # check around for #0x88] and #0x90]
        count = 0
        for j in range(max(0, i-20), min(len(lines), i+20)):
            if "#0x88]" in lines[j] and "str\tx" in lines[j]:
                count += 1
            if "#0x90]" in lines[j] and "str\tx" in lines[j]:
                count += 1
        if count >= 2:
            print("FOUND INITIALIZER BLOCK:")
            for j in range(max(0, i-30), min(len(lines), i+30)):
                print(lines[j])
            print("====================================")
