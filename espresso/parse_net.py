import json
import sys
import os

import liblzfse
import networkx as nx

def read_espresso_file(file):
    compressed=False
    with open(file, 'rb') as f:
        first_4_bytes = f.peek(4)[:4]
        if (first_4_bytes == b'pbze'):
            compressed = True
        if compressed:
            f.seek(28)
            compressed_buffer = f.read()
            json_data = liblzfse.decompress(compressed_buffer)
        else:
            json_data = f.read()
    return json_data

NET_FILE=sys.argv[1]

net_buffer = read_espresso_file(NET_FILE)
net_dict = json.loads(net_buffer)

shape_buffer = read_espresso_file(NET_FILE.replace('espresso.net', 'espresso.shape'))
shape_dict = json.loads(shape_buffer)

# take .espresso.net file
print(NET_FILE)

class Node:
    def __init__(self, name):
        self.name = name
        self.bottoms = []
        self.tops = []
        self.type = None
        self.is_output = 0

nodes = {}
for n in net_dict['layers']:
    k = n['name']
    if not k in nodes:
        nodes[k] = Node(k)
    nodes[k].type = n['type']
   
    # if a layer is explicitly annotated as 'is_output', we take it 
    if ('attributes' in n) and ('is_output' in n['attributes']):
        nodes[k].is_output = n['attributes']['is_output']
   
    # connecting with 'bottom' layers 
    if not n['bottom'] == '':
        bottoms = n['bottom'].split(',')
        for b in bottoms:
            if not b in nodes:
                nodes[b] = Node(b)
                #print("adding", b)
            # dont layers with is_output == 1 as bottom layers
            if not (nodes[b].is_output == 1):
                nodes[k].bottoms.append(b)
                nodes[b].tops.append(k)
            #print(b)

    # connecting with 'top' layers 
    if not n['top'] == '':
        tops = n['top'].split(',')
        for t in tops:
            if not t in nodes:
                nodes[t] = Node(t)
                #print("adding", t)
            # ignore layers with top == itself
            if not (k == t):
                nodes[k].tops.append(t)
                nodes[t].bottoms.append(k)
            #print("t.tops:", nodes[t].name, nodes[t].tops)
            
output_dict = {}
# print(len(net_dict['layers']))
for n in nodes:
    #print(nodes[n].name)
    #print(" tops:", nodes[n].tops)
    #print(" bottoms:", nodes[n].bottoms)A

    if (len(nodes[n].bottoms) == 0) and (nodes[n].type == None):
        shape = shape_dict['layer_shapes'][n]
        print("  input:", n, shape)

    if len(nodes[n].tops) == 0 or (nodes[n].is_output == 1):
        if len(nodes[n].tops) == 0:
              if not (n in output_dict):
                    shape = shape_dict['layer_shapes'][n]
                    print("  output: ", n, shape)
                    output_dict[n] = shape
        else:
              if not (nodes[n].tops[0] in output_dict):
                    shape = shape_dict['layer_shapes'][nodes[n].tops[0]]
                    print("  output: ", nodes[n].tops[0], shape)
                    output_dict[nodes[n].tops[0]] = shape


G = nx.DiGraph()

for n in nodes:
    for b in nodes[n].bottoms:
        G.add_edges_from([(f'{b} ({nodes[b].type})', f'{nodes[n].name} ({nodes[n].type})')])
    for t in nodes[n].tops:
        G.add_edges_from([(f'{nodes[n].name} ({nodes[n].type})', f'{t} ({nodes[t].type})')])

p = nx.drawing.nx_pydot.to_pydot(G)

network_base = os.path.basename(NET_FILE.replace('espresso.net', 'espresso.pdf'))
p.write_pdf(f'/tmp/{network_base}')
