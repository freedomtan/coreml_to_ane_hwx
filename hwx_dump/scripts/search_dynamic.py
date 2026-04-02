import sys, re

def find_seq():
    lines = open("ANECompiler.S").read().split('\n')
    
    for i, line in enumerate(lines):
        if "str\tx" in line and ", #0x80]" in line:
            # check + 10 lines for #0x88
            found_88 = False
            found_90 = False
            for j in range(i, min(len(lines), i+15)):
                if "str\tx" in lines[j] and ", #0x88]" in lines[j]:
                    found_88 = True
                if "str\tx" in lines[j] and ", #0x90]" in lines[j]:
                    found_90 = True
            if found_88 and found_90:
                print("FOUND SEQ AT:", i)
                print('\n'.join(lines[max(0, i-10):min(len(lines), i+20)]))
                print('--------------------')

if __name__ == "__main__":
    find_seq()
