import re

def parse_tasks(filename):
    tasks = {}
    current_task = None
    
    with open(filename, 'r') as f:
        lines = f.readlines()
        
    for line in lines:
        task_match = re.search(r'\[ANE Task (\d+)', line)
        if task_match:
            current_task = int(task_match.group(1))
            tasks[current_task] = {'dims': 'N/A', 'info': []}
            continue
            
        if current_task is not None:
            # Look for dimensions line: "224 x 224 x 3 ... -> ..."
            dim_match = re.search(r'(\d+ x \d+ x \d+ .* -> \d+ x \d+ x \d+ .*)', line)
            if dim_match:
                tasks[current_task]['dims'] = dim_match.group(1).strip()
            
            # Check for other configs like active NE
            if "ConvCfg:" in line:
                 tasks[current_task]['info'].append(line.strip())
            if "ActiveNE:" in line:
                 tasks[current_task]['info'].append(line.strip())

    return tasks

m1 = parse_tasks('m1_full.txt')
m4 = parse_tasks('m4_full.txt')

print(f"{'Task':<5} | {'M1 Dims':<60} | {'M4 Dims':<60} | {'Status'}")
print("-" * 140)

all_match = True
for i in range(68):
    if i not in m1:
        print(f"{i:<5} | {'MISSING in M1':<60} | {'---':<60} | ❌")
        all_match = False
        continue
        
    m1_dims = m1[i]['dims']
    # Removing [SIG] tag for comparison if present
    m4_dims = m4.get(i, {}).get('dims', 'MISSING').replace(' [SIG]', '') 
    
    status = "✅" if m1_dims == m4_dims else "❌"
    if status == "❌":
        all_match = False
    
    print(f"{i:<5} | {m1_dims:<60} | {m4_dims:<60} | {status}")

if all_match:
    print("\nSUCCESS: All 68 tasks match dimensions!")
else:
    print("\nFAILURE: Some tasks mismatch.")
