import * as fs from 'fs';
import * as hwx from './hwx.js';

class MockStream {
    constructor(buffer) {
        this._buffer = buffer;
        this._position = 0;
    }
    get length() {
        return this._buffer.length;
    }
    get position() {
        return this._position;
    }
    seek(pos) {
        this._position = pos;
    }
    peek(length) {
        if (length === undefined) return this._buffer;
        return this._buffer.subarray(this._position, this._position + length);
    }
    read(length) {
        const end = length === undefined ? this._buffer.length : this._position + length;
        const res = this._buffer.subarray(this._position, end);
        this._position = end;
        return res;
    }
}

class MockContext {
    constructor(filePath) {
        this.identifier = filePath;
        const buf = fs.readFileSync(filePath);
        this.stream = new MockStream(new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength));
    }
}

async function testFile(path) {
    console.log(`\n================ Testing: ${path} ================`);
    const context = new MockContext(path);
    const factory = new hwx.ModelFactory();

    const matchResult = await factory.match(context);
    console.log(`Match result: '${matchResult}' (expected 'hwx')`);
    if (!matchResult) {
        throw new Error(`Failed to match ${path}`);
    }

    const model = await factory.open(context);
    console.log(`Model Format: ${model.format}`);
    console.log(`Model Producer: ${model.producer}`);
    console.log(`Model Version: ${model.version}`);
    console.log(`Model Description: ${model.description}`);
    console.log(`Metadata:`, model.metadata.map(m => `${m.name}=${m.value}`));

    console.log(`Model Modules: ${model.modules.length}`);
    for (let mIdx = 0; mIdx < model.modules.length; mIdx++) {
        const g = model.modules[mIdx];
        console.log(`  Module [${mIdx}]: ${g.name} (${g.nodes.length} nodes, ${g.inputs.length} inputs, ${g.outputs.length} outputs)`);
    }

    const graph = model.modules[0];
    console.log(`Active Graph Name: ${graph.name}`);
    console.log(`Graph Inputs: ${graph.inputs.length}`);
    graph.inputs.forEach(i => console.log(`  Input: ${i.name} -> ${i.value[0].name} ${i.value[0].type}`));
    console.log(`Graph Outputs: ${graph.outputs.length}`);
    graph.outputs.slice(0, 3).forEach(o => console.log(`  Output: ${o.name} -> ${o.value[0].name} ${o.value[0].type}`));
    console.log(`Graph Total Nodes: ${graph.nodes.length}`);

    // Print first 5 nodes
    console.log(`\nSample Nodes (first 5):`);
    for (let i = 0; i < Math.min(5, graph.nodes.length); i++) {
        const n = graph.nodes[i];
        const inStr = n.inputs.map(a => `${a.name}: ${a.value.map(v => v.name).join(',')}`).join('; ');
        const outStr = n.outputs.map(a => `${a.name}: ${a.value.map(v => v.name).join(',')}`).join('; ');
        console.log(`  [Node ${i}] ${n.name} | Type: ${n.type.name} (${n.type.category})`);
        console.log(`    Inputs:  ${inStr}`);
        console.log(`    Outputs: ${outStr}`);
        const attrKeys = n.attributes.map(a => a.name).join(', ');
        console.log(`    Attributes: ${attrKeys}`);
    }

    // Check for residual add nodes
    const residualNodes = graph.nodes.filter(n => n.inputs.length > 1);
    console.log(`\nNodes with multiple inputs (e.g. residual joins): ${residualNodes.length}`);
    for (const n of residualNodes.slice(0, 5)) {
        const inStr = n.inputs.map(a => `${a.name}: ${a.value.map(v => v.name).join(',')}`).join('; ');
        console.log(`  ${n.name} [${n.type.name}]: ${inStr}`);
    }

    console.log(`[PASS] ${path}`);
}

async function main() {
    const testFiles = [
        "./pytorch_fp8_conv.mlmodelc/model.hwx",
        "./resnet50_fp16_m4/864A55188C0CF96F9B8AC6F768721ED331239D2D6235C0F9C02D14C9EF047E1F/model.hwx",
        "./resnet50_fp16_m1/AAC1287057A13DC504B2251BDDEF86F895F48BBAC83698A3787D82844AC839DB/model.hwx",
        "./mobilenet_v2_quant_m4/899CA02D20D18C103C787B716A05AAACB2D76CFE0AA0F502D237A47487EC72F8/model.hwx"
    ];

    for (const f of testFiles) {
        if (fs.existsSync(f)) {
            await testFile(f);
        }
    }
}

main().catch(err => {
    console.error("Test failed:", err);
    process.exit(1);
});
