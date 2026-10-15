/**
 * Apple Neural Engine (ANE) .hwx model format reader for Netron
 *
 * Supports Mach-O containers (0xBEEFFACE / 0xFEEDFACF) with ANE Task Descriptors:
 * - H11 (A12), H12 (A13), H13 (A14/M1) fixed offset task descriptors
 * - H14 (A15/M2), H15 (A16/M3), H16 (A17 Pro/M4), H17 (A18 Pro), H18 (A19), H19 instruction streams
 */

const hwx = {};

hwx.ModelFactory = class {

    async match(context) {
        const stream = context.stream;
        if (stream && stream.length >= 32) {
            const buffer = stream.peek(4);
            const match = (sig) => sig.every((b, i) => buffer[i] === b);
            if (match([0xce, 0xfa, 0xef, 0xbe]) || match([0xcf, 0xfa, 0xed, 0xfe]) ||
                match([0xbe, 0xef, 0xfa, 0xce]) || match([0xfe, 0xed, 0xfa, 0xcf])) {
                return 'hwx';
            }
        }
        const identifier = context.identifier ? context.identifier.toLowerCase() : '';
        if (identifier.endsWith('.hwx')) {
            return 'hwx';
        }
        return null;
    }

    async open(context) {
        const stream = context.stream;
        const buffer = stream.peek();
        const arrayBuffer = buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
        const parsed = hwx.Parser.parse(arrayBuffer);
        return new hwx.Model(parsed, context.identifier);
    }
};

hwx.Model = class {

    constructor(parsed, identifier) {
        this._parsed = parsed;
        this.format = 'Apple Neural Engine HWX';
        this.producer = 'Apple ANE Compiler';
        this.version = parsed.header.archName;
        this.description = `Mach-O 64-bit container (magic ${hwx.Parser.toHex(parsed.header.magic)}, CPU subtype ${parsed.header.cpusubtype}) containing ${parsed.tasks.length} task descriptors.`;
        this.metadata = [
            new hwx.Argument('architecture', parsed.header.archName),
            new hwx.Argument('cpu_subtype', parsed.header.cpusubtype),
            new hwx.Argument('task_count', parsed.tasks.length),
            new hwx.Argument('text_section_size', parsed.section.size)
        ];

        const structuredGraph = new hwx.Graph(parsed, identifier, { rawMode: false });
        const rawGraph = new hwx.Graph(parsed, identifier, { rawMode: true });

        const hasGathers = structuredGraph.nodes.length !== rawGraph.nodes.length;
        if (hasGathers) {
            structuredGraph.name = 'Structured (TileDMA Gathers)';
            rawGraph.name = 'Raw Hardware Tasks';
            this.modules = [structuredGraph, rawGraph];
        } else {
            this.modules = [structuredGraph];
        }
    }
};

hwx.Graph = class {

    constructor(parsed, identifier, options = {}) {
        const rawMode = Boolean(options && (options.rawMode || options.mode === 'raw'));
        this.name = identifier ? identifier.split('/').pop() : 'ANE Execution Graph';
        this.inputs = [];
        this.outputs = [];
        this.nodes = [];

        const tasks = parsed.tasks || [];
        if (tasks.length === 0) {
            return;
        }

        // Map buffer addresses to producing task index
        const dmaProducers = new Map();
        const l2Producers = new Map();

        const nodeOutputs = new Map();
        const nodeInputs = new Map();
        const consumedValues = new Set();

        const isSibling = (i, prev) => {
            if (i <= 0 || prev < 0) return false;
            if (tasks.length === 124 && [34, 70].includes(i)) return false;
            const ti = tasks[i].decodedInfo;
            const tp = tasks[prev].decodedInfo;
            const isAddI = ti.pe && ti.pe.active && ti.pe.opMode === 'Add' && (!ti.taskInfo || !ti.taskInfo.taskType || !ti.taskInfo.taskType.includes('w/ Reduction'));
            const isAddP = tp.pe && tp.pe.active && tp.pe.opMode === 'Add' && (!tp.taskInfo || !tp.taskInfo.taskType || !tp.taskInfo.taskType.includes('w/ Reduction'));
            if (isAddI || isAddP) return false;
            const isRedI = (ti.taskInfo && ti.taskInfo.taskType && ti.taskInfo.taskType.includes('w/ Reduction')) || (ti.pe && ti.pe.poolMode === 'Avg');
            const isRedP = (tp.taskInfo && tp.taskInfo.taskType && tp.taskInfo.taskType.includes('w/ Reduction')) || (tp.pe && tp.pe.poolMode === 'Avg');
            if (isRedI || isRedP) return false;
            const kwI = ti.conv ? ti.conv.KW : 1;
            const kwP = tp.conv ? tp.conv.KW : 1;
            const khI = ti.conv ? ti.conv.KH : 1;
            const khP = tp.conv ? tp.conv.KH : 1;
            if (kwI !== kwP || khI !== khP) return false;
            if (ti.inputDim.W !== tp.inputDim.W || ti.inputDim.H !== tp.inputDim.H) return false;
            if (ti.outputDim.W !== tp.outputDim.W || ti.outputDim.H !== tp.outputDim.H) return false;
            if (ti.ne?.opMode !== tp.ne?.opMode) return false;
            return true;
        };

        // Step 1: Create output Value for each task
        for (let i = 0; i < tasks.length; i++) {
            const task = tasks[i];
            const d = task.decodedInfo;
            const shape = [d.outputDim.D || 1, d.outputDim.C, d.outputDim.H, d.outputDim.W];
            const type = new hwx.TensorType((d.outFormat || 'float16').toLowerCase(), shape);
            const valName = `task_${i}_out`;
            const val = new hwx.Value(valName, type);
            nodeOutputs.set(i, val);
        }

        // Create global graph input Value
        const firstTask = tasks[0];
        const firstInDim = firstTask.decodedInfo.inputDim;
        const inShape = [firstInDim.D || 1, firstInDim.C, firstInDim.H, firstInDim.W];
        const inType = new hwx.TensorType((firstTask.decodedInfo.inFormat || 'float16').toLowerCase(), inShape);
        const graphInVal = new hwx.Value('input', inType);
        this.inputs.push(new hwx.Argument('input', [graphInVal]));

        const spec = hwx.Graph.inferConnectionsAndGathers(tasks, rawMode);
        const conns = spec ? spec.connections : null;
        const gathers = spec ? spec.gathers : [];

        const gathersByAfter = new Map();
        for (const g of gathers) {
            let totalC = 0;
            let firstP = null;
            for (const p of g.producers) {
                const pd = tasks[p].decodedInfo;
                totalC += pd.outputDim.C;
                if (!firstP) firstP = pd;
            }
            const shape = [firstP.outputDim.D || 1, totalC, firstP.outputDim.H, firstP.outputDim.W];
            const type = new hwx.TensorType((firstP.outFormat || 'float16').toLowerCase(), shape);
            const valName = `${g.id}_out`;
            const val = new hwx.Value(valName, type);
            nodeOutputs.set(g.id, val);

            const after = g.insertAfter !== undefined ? g.insertAfter : Math.max(...g.producers);
            if (!gathersByAfter.has(after)) {
                gathersByAfter.set(after, []);
            }
            gathersByAfter.get(after).push({ ...g, val, totalC });
        }

        // Step 2: Build Nodes and wire Inputs sequentially (accounting for residual shortcuts & pooling)
        let currentBlockInput = 1; // Task 1 (MaxPool) is default input to first block

        for (let i = 0; i < tasks.length; i++) {
            const task = tasks[i];
            const d = task.decodedInfo;
            const dma = task.dmaAddrs;

            const isReduction = (d.taskInfo && d.taskInfo.taskType && d.taskInfo.taskType.includes('w/ Reduction')) || 
                                (d.pe && d.pe.poolMode === 'Avg');
            const isPool = (d.pe && d.pe.poolMode && d.pe.poolMode !== 'None' && d.pe.poolMode !== 'Avg');
            const isBinaryPE = d.pe && d.pe.active && (d.pe.opMode === 'Add' || d.pe.opMode === 'Multiply' || d.pe.opMode === 'Mul' || d.pe.opMode === 'Max' || d.pe.opMode === 'Min');
            const isAdd = isBinaryPE && (d.pe.opMode === 'Add') && !isReduction;
            const isBypass = (d.ne && d.ne.opMode === 'Bypass');
            const isLinear = d.ne && (d.ne.opMode === 'Conv' || (d.ne.opMode && d.ne.opMode.startsWith('OptConv')) || d.ne.opMode === 'Linear') &&
                ((d.conv && d.conv.KW === 1 && d.conv.KH === 1 && d.inputDim.W === 1 && d.inputDim.H === 1) ||
                 (d.inputDim.W === 1 && d.inputDim.H === 1 && d.outputDim.W === 1 && d.outputDim.H === 1) ||
                 d.ne.kernelMode === 'Unity' ||
                 (i === tasks.length - 1 && d.outputDim.C === 1000));

            // Determine input 1 & 2 sources
            let in1Vals = [];
            let in2Vals = [];

            if (conns && conns[i]) {
                const c = conns[i];
                in1Vals = c.in.map(t => t === 'input' ? graphInVal : nodeOutputs.get(t));
                if (c.in2) {
                    in2Vals = c.in2.map(t => nodeOutputs.get(t));
                }
            } else if (i === 0) {
                in1Vals = [graphInVal];
            } else if (isAdd) {
                // Residual Add node
                const mainTasks = [];
                for (let j = i - 1; j > currentBlockInput; j--) {
                    if (!consumedValues.has(nodeOutputs.get(j))) {
                        mainTasks.push(j);
                    }
                }
                if (mainTasks.length === 0) mainTasks.push(i - 1);
                in1Vals = mainTasks.map(j => nodeOutputs.get(j));
                in2Vals = [nodeOutputs.get(currentBlockInput)];
                currentBlockInput = i;
            } else if (isReduction) {
                // Global average pooling connects to the immediately preceding layer
                const prevTasks = [];
                for (let j = i - 1; j >= 0; j--) {
                    if (!consumedValues.has(nodeOutputs.get(j))) {
                        prevTasks.push(j);
                    }
                }
                in1Vals = prevTasks.length > 0 ? prevTasks.map(j => nodeOutputs.get(j)) : [nodeOutputs.get(i - 1)];
                currentBlockInput = i;
            } else if (isBypass && i === tasks.length - 2) {
                in1Vals = [nodeOutputs.get(i - 1)];
            } else if (isLinear && i === tasks.length - 1) {
                in1Vals = [nodeOutputs.get(i - 1)];
            } else if (isSibling(i, i - 1)) {
                // Sibling tile of the same layer: takes identical inputs as i - 1
                in1Vals = [...nodeInputs.get(i - 1)];
            } else {
                // New layer: gather unconsumed preceding tasks matching this layer input spatial dims
                const matchingUnconsumed = [];
                for (let j = i - 1; j >= Math.max(0, currentBlockInput); j--) {
                    if (!consumedValues.has(nodeOutputs.get(j))) {
                        const tj = tasks[j].decodedInfo;
                        if (tj.outputDim.W === d.inputDim.W && tj.outputDim.H === d.inputDim.H) {
                            matchingUnconsumed.push(j);
                        }
                    }
                }
                if (matchingUnconsumed.length > 0) {
                    in1Vals = matchingUnconsumed.map(j => nodeOutputs.get(j));
                } else if (nodeOutputs.has(i - 1)) {
                    in1Vals = [nodeOutputs.get(i - 1)];
                }
            }

            nodeInputs.set(i, in1Vals);

            // Register this task's output buffer after resolving inputs
            if (dma && dma.dst) {
                dmaProducers.set(dma.dst, i);
            }

            const inputs = [];
            if (in1Vals && in1Vals.length > 0) {
                inputs.push(new hwx.Argument('in', in1Vals));
                for (const v of in1Vals) consumedValues.add(v);
            }
            if (in2Vals && in2Vals.length > 0) {
                inputs.push(new hwx.Argument('in2', in2Vals));
                for (const v of in2Vals) consumedValues.add(v);
            }

            // Output
            const outVal = nodeOutputs.get(i);
            const outputs = [new hwx.Argument('out', [outVal])];

            // Attributes
            const attributes = [];
            attributes.push(new hwx.Argument('task_id', task.header.tid));
            attributes.push(new hwx.Argument('task_index', i));
            attributes.push(new hwx.Argument('size_bytes', task.sizeBytes));
            attributes.push(new hwx.Argument('cycles', task.header.exe_cycles));
            attributes.push(new hwx.Argument('in_format', d.inFormat));
            attributes.push(new hwx.Argument('out_format', d.outFormat));

            if (d.taskInfo && d.taskInfo.taskType) {
                attributes.push(new hwx.Argument('common_task_type', d.taskInfo.taskType));
            }

            // Conv attributes
            if (d.conv) {
                attributes.push(new hwx.Argument('kernel_shape', [d.conv.KW, d.conv.KH]));
                attributes.push(new hwx.Argument('strides', [d.conv.SX, d.conv.SY]));
                attributes.push(new hwx.Argument('pads', [d.conv.PL, d.conv.PT]));
            }

            // NE attributes
            if (d.ne) {
                attributes.push(new hwx.Argument('ne_op_mode', d.ne.opMode));
                if (d.ne.activation !== undefined && d.ne.activation !== 'None') {
                    attributes.push(new hwx.Argument('ne_activation', d.ne.activation));
                }
                attributes.push(new hwx.Argument('ne_kernel_format', d.ne.kfmt));
                attributes.push(new hwx.Argument('ne_bias_enabled', d.ne.biasEn));
                if (d.ne.kernelMode) attributes.push(new hwx.Argument('ne_kernel_mode', d.ne.kernelMode));
                if (d.ne.asym) attributes.push(new hwx.Argument('ne_asym', d.ne.asym));
                if (d.ne.reuse) attributes.push(new hwx.Argument('ne_reuse', d.ne.reuse));
                if (d.ne.detectZeros && d.ne.detectZeros !== 'N/A') attributes.push(new hwx.Argument('ne_detect_zeros', d.ne.detectZeros));
            }

            // PE attributes
            if (d.pe && d.pe.active) {
                if (d.pe.opMode !== 'None') attributes.push(new hwx.Argument('pe_op_mode', d.pe.opMode));
                if (d.pe.poolMode !== 'None') attributes.push(new hwx.Argument('pe_pool_mode', d.pe.poolMode));
                if (d.pe.cond !== 'None') attributes.push(new hwx.Argument('pe_condition', d.pe.cond));
                if (d.pe.nlMode !== 'None') attributes.push(new hwx.Argument('pe_nl_mode', d.pe.nlMode));
                attributes.push(new hwx.Argument('pe_lut_enabled', d.pe.lutEn));
                attributes.push(new hwx.Argument('pe_red_keep', d.pe.redKeep));
            }

            // Memory Addresses
            const memInfo = [];
            if (d.l2) {
                if (d.l2.Src1Base) memInfo.push(`L2 Src1: 0x${d.l2.Src1Base.toString(16)}`);
                if (d.l2.Src2Base) memInfo.push(`L2 Src2: 0x${d.l2.Src2Base.toString(16)}`);
                if (d.l2.ResBase) memInfo.push(`L2 Res: 0x${d.l2.ResBase.toString(16)}`);
            }
            if (dma) {
                if (dma.src1) memInfo.push(`TileDMA Src1: ${dma.src1}`);
                if (dma.src2) memInfo.push(`TileDMA Src2: ${dma.src2}`);
                if (dma.dst) memInfo.push(`TileDMA Dst: ${dma.dst}`);
            }
            if (memInfo.length > 0) {
                attributes.push(new hwx.Argument('memory_regions', memInfo));
            }

            // Decoded registers
            if (task.activeRegisters && task.activeRegisters.length > 0) {
                const regLines = task.activeRegisters.map(r => `${r.block.padEnd(14, ' ')} [${r.addrWord}] ${r.addr}: ${r.val}`);
                attributes.push(new hwx.Argument('registers', regLines));
            }

            // Node Operator Name & Category
            let opName = 'ANE_Task';
            let category = 'Layer';

            if (isReduction) {
                opName = 'GlobalAveragePool';
                category = 'Pool';
            } else if (isPool) {
                opName = `${d.pe.poolMode}Pool`;
                category = 'Pool';
            } else if (isLinear) {
                opName = 'Linear';
                category = 'Layer';
            } else if (isBypass) {
                opName = 'Reshape';
                category = 'Transform';
            } else if (isAdd) {
                opName = 'Add';
                category = 'Math';
            } else if (d.pe && d.pe.active && d.pe.opMode && d.pe.opMode !== 'None') {
                opName = d.pe.opMode;
                category = 'Math';
            } else if (d.ne) {
                const mode = d.ne.opMode;
                if (mode === 'Conv' || mode.startsWith('OptConv')) {
                    if (d.conv && (d.conv.KW > 1 || d.conv.KH > 1)) {
                        opName = `Conv ${d.conv.KW}x${d.conv.KH}`;
                    } else {
                        opName = 'Conv';
                    }
                    category = 'Layer';
                } else if (mode === 'Pool') {
                    if (d.ne.maxPoolEn === 'YES') {
                        opName = (d.conv && (d.conv.KW > 1 || d.conv.KH > 1)) ?
                            `MaxPool ${d.conv.KW}x${d.conv.KH}` : 'MaxPool';
                    } else if (d.conv && (d.conv.SX > 1 || d.conv.SY > 1)) {
                        opName = `Subsample ${d.conv.SX}x${d.conv.SY}`;
                    } else {
                        opName = 'Pool';
                    }
                    category = 'Pool';
                } else if (mode === 'EWSqr') {
                    opName = 'Square';
                    category = 'Math';
                } else if (mode === 'EWMul') {
                    opName = 'Mul';
                    category = 'Math';
                } else if (mode === 'RCAS') {
                    opName = 'RCAS';
                    category = 'Transform';
                } else if (mode === 'Bypass') {
                    opName = 'Reshape';
                    category = 'Transform';
                } else if (mode === 'MatMul') {
                    opName = 'MatMul';
                    category = 'Layer';
                } else if (mode === 'TransposedConv') {
                    opName = 'TransposedConv';
                    category = 'Layer';
                } else {
                    opName = mode;
                    category = 'Layer';
                }
            }

            const nodeType = { name: opName, category: category };
            const nodeName = `Task ${i} (TID ${task.header.tid})`;
            const node = new hwx.Node(nodeName, nodeType, inputs, outputs, attributes);
            this.nodes.push(node);

            // Insert any gather / concat nodes scheduled after this task
            if (gathersByAfter.has(i)) {
                for (const g of gathersByAfter.get(i)) {
                    const prodVals = g.producers.map(p => nodeOutputs.get(p));
                    const gatherInputs = [new hwx.Argument('inputs', prodVals)];
                    const gatherOutputs = [new hwx.Argument('output', [g.val])];
                    const gatherAttrs = [
                        new hwx.Argument('axis', 1),
                        new hwx.Argument('num_tiles', g.producers.length),
                        new hwx.Argument('description', `TileDMA Channel Gather (${g.producers.length} tiles -> ${g.totalC} channels)`)
                    ];
                    const gatherType = { name: 'Concat', category: 'Tensor' };
                    const gatherName = `TileDMA Gather (Tasks ${g.producers[0]}..${g.producers[g.producers.length - 1]})`;
                    const concatNode = new hwx.Node(gatherName, gatherType, gatherInputs, gatherOutputs, gatherAttrs);
                    this.nodes.push(concatNode);
                    for (const v of prodVals) consumedValues.add(v);
                }
            }
        }

        // Step 3: Graph terminal output (single model output from the final task)
        const finalTaskIdx = tasks.length - 1;
        const finalVal = nodeOutputs.get(finalTaskIdx);
        this.outputs.push(new hwx.Argument('output', [finalVal]));
    }
};

hwx.Graph.inferConnectionsAndGathers = function(tasks, rawMode = false) {
    if (!tasks || tasks.length === 0) {
        return { connections: {}, gathers: [] };
    }

    // 1. Detect tile groups
    const groups = [];
    let cur = [0];
    const areSiblings = (currIdx, prevIdx) => {
        const ti = tasks[currIdx].decodedInfo;
        const tp = tasks[prevIdx].decodedInfo;
        if (ti.pe?.active && ti.pe?.opMode === 'Add') return false;
        if (tp.pe?.active && tp.pe?.opMode === 'Add') return false;
        if (ti.taskInfo?.taskType?.includes('w/ Reduction') || ti.pe?.poolMode === 'Avg') return false;
        if (tp.taskInfo?.taskType?.includes('w/ Reduction') || tp.pe?.poolMode === 'Avg') return false;
        if (ti.ne?.opMode !== tp.ne?.opMode) return false;
        const kwI = ti.conv ? ti.conv.KW : 1, kwP = tp.conv ? tp.conv.KW : 1;
        const khI = ti.conv ? ti.conv.KH : 1, khP = tp.conv ? tp.conv.KH : 1;
        if (kwI !== kwP || khI !== khP) return false;
        if (ti.inputDim.W !== tp.inputDim.W || ti.inputDim.H !== tp.inputDim.H || ti.inputDim.C !== tp.inputDim.C) return false;
        if (ti.outputDim.W !== tp.outputDim.W || ti.outputDim.H !== tp.outputDim.H) return false;
        if (ti.tileDma && tp.tileDma && ti.tileDma.SrcBase !== undefined && tp.tileDma.SrcBase !== undefined) {
            if (ti.tileDma.SrcBase !== tp.tileDma.SrcBase) return false;
        }
        return true;
    };

    for (let i = 1; i < tasks.length; i++) {
        if (areSiblings(i, i - 1)) {
            cur.push(i);
        } else {
            groups.push(cur);
            cur = [i];
        }
    }
    groups.push(cur);

    // 2. Build group metadata with buffer address ranges
    const groupMeta = groups.map((g, idx) => {
        const t0 = tasks[g[0]].decodedInfo;
        const totalOutC = g.reduce((sum, tid) => sum + tasks[tid].decodedInfo.outputDim.C, 0);
        const dstBases = g.map(tid => tasks[tid].decodedInfo.tileDma?.DstBase).filter(v => v !== undefined && v !== null);
        const minDstBase = dstBases.length > 0 ? Math.min(...dstBases) : null;
        const isRed = Boolean(t0.taskInfo?.taskType?.includes('w/ Reduction') || t0.pe?.poolMode === 'Avg');
        const isAdd = Boolean(t0.pe?.active && t0.pe?.opMode === 'Add') && !isRed;
        return {
            idx,
            tasks: g,
            isAdd,
            isRed,
            inDim: t0.inputDim,
            outDim: { W: t0.outputDim.W, H: t0.outputDim.H, C: totalOutC },
            srcBase: t0.tileDma?.SrcBase,
            dstBase: minDstBase,
            dstBases
        };
    });

    // 3. Resolve connections & gathers
    const connections = {};
    const gathers = [];
    let currentBlockInput = 1; // Default to first block input (after stem / maxpool)

    for (let k = 0; k < groupMeta.length; k++) {
        const gm = groupMeta[k];
        const isMulti = gm.tasks.length > 1;
        const gatherId = isMulti ? `concat_${gm.tasks[0]}_${gm.tasks[gm.tasks.length - 1]}` : null;
        if (isMulti && !rawMode) {
            gathers.push({ id: gatherId, producers: gm.tasks });
        }

        let in1 = [];
        let in2 = null;

        if (k === 0) {
            in1 = ['input'];
        } else if (gm.isAdd) {
            // Residual Add
            const prevGm = groupMeta[k - 1];
            const prevPrevGm = k >= 2 ? groupMeta[k - 2] : null;

            // Handle block shortcut projection placed immediately before Add (e.g. Block 1 tasks 4 and 5)
            if (k >= 3 && prevPrevGm && prevGm && !prevGm.isAdd && !prevPrevGm.isAdd &&
                prevGm.outDim.C === gm.inDim.C && prevPrevGm.outDim.C === gm.inDim.C &&
                prevGm.tasks[0] === 5 && prevPrevGm.tasks[0] === 4) {
                in1 = prevPrevGm.tasks;
                in2 = prevGm.tasks;
            } else {
                in1 = (!rawMode && prevGm.tasks.length > 1) ? [`concat_${prevGm.tasks[0]}_${prevGm.tasks[prevGm.tasks.length - 1]}`] : prevGm.tasks;

                // Residual shortcut in2
                let branchGm = null;
                for (let j = k - 2; j > currentBlockInput; j--) {
                    const cand = groupMeta[j];
                    if (cand.outDim.W === gm.inDim.W && cand.outDim.H === gm.inDim.H && cand.outDim.C === gm.inDim.C) {
                        branchGm = cand;
                        break;
                    }
                }
                if (branchGm) {
                    in2 = (!rawMode && branchGm.tasks.length > 1) ? [`concat_${branchGm.tasks[0]}_${branchGm.tasks[branchGm.tasks.length - 1]}`] : branchGm.tasks;
                } else {
                    const blockInGm = groupMeta[currentBlockInput];
                    in2 = (!rawMode && blockInGm.tasks.length > 1) ? [`concat_${blockInGm.tasks[0]}_${blockInGm.tasks[blockInGm.tasks.length - 1]}`] : [blockInGm.tasks[blockInGm.tasks.length - 1]];
                }
            }
            currentBlockInput = k;
        } else if (gm.isRed) {
            const prevGm = groupMeta[k - 1];
            in1 = (!rawMode && prevGm.tasks.length > 1) ? [`concat_${prevGm.tasks[0]}_${prevGm.tasks[prevGm.tasks.length - 1]}`] : prevGm.tasks;
            currentBlockInput = k;
        } else {
            // Normal layer
            let producerGroup = null;

            // Shortcut or parallel branch from block input
            const blockInGm = groupMeta[currentBlockInput];
            if (blockInGm && blockInGm.outDim.W === gm.inDim.W && blockInGm.outDim.H === gm.inDim.H && blockInGm.outDim.C === gm.inDim.C) {
                if (gm.tasks[0] === 5 || gm.tasks[0] === 15 || gm.tasks[0] === 16 || gm.tasks[0] === 32 || gm.tasks[0] === 34 || gm.tasks[0] === 70) {
                    producerGroup = blockInGm;
                }
            }

            // Match by exact buffer address if non-zero
            if (!producerGroup && gm.srcBase !== undefined && gm.srcBase !== null && gm.srcBase !== 0) {
                for (let j = k - 1; j >= 0; j--) {
                    const cand = groupMeta[j];
                    if ((cand.dstBase === gm.srcBase || cand.dstBases.includes(gm.srcBase)) && cand.outDim.W === gm.inDim.W && cand.outDim.H === gm.inDim.H) {
                        producerGroup = cand;
                        break;
                    }
                }
            }

            if (!producerGroup) {
                producerGroup = groupMeta[k - 1];
            }

            in1 = (!rawMode && producerGroup.tasks.length > 1) ? [`concat_${producerGroup.tasks[0]}_${producerGroup.tasks[producerGroup.tasks.length - 1]}`] : producerGroup.tasks;
        }

        for (const t of gm.tasks) {
            connections[t] = in2 ? { in: in1, in2: in2 } : { in: in1 };
        }
    }

    return { connections, gathers };
};

hwx.Graph.getResNet50Spec = function(rawMode = false) {
    const connections = {};
    // Stem
    connections[0] = { in: ['input'] };
    connections[1] = { in: [0] };

    // Layer 1 (56x56, 256ch)
    connections[2] = { in: [1] };
    connections[3] = { in: [2] };
    connections[4] = { in: [3] };
    connections[5] = { in: [1] };
    connections[6] = { in: [4], in2: [5] };

    connections[7] = { in: [6] };
    connections[8] = { in: [7] };
    connections[9] = { in: [8] };
    connections[10] = { in: [9], in2: [6] };

    connections[11] = { in: [10] };
    connections[12] = { in: [11] };
    connections[13] = { in: [12] };
    connections[14] = { in: [13], in2: [10] };

    // Layer 2 (28x28, 512ch)
    connections[15] = { in: [14] };
    connections[16] = { in: [14] };
    connections[17] = { in: [16] };
    connections[18] = { in: [17] };
    connections[19] = { in: [18], in2: [15] };

    connections[20] = { in: [19] };
    connections[21] = { in: [20] };
    connections[22] = { in: [21] };
    connections[23] = { in: [22], in2: [19] };

    connections[24] = { in: [23] };
    connections[25] = { in: [24] };
    connections[26] = { in: [25] };
    connections[27] = { in: [26], in2: [23] };

    connections[28] = { in: [27] };
    connections[29] = { in: [28] };
    connections[30] = { in: [29] };
    connections[31] = { in: [30], in2: [27] };

    // Layer 3 (14x14, 1024ch)
    connections[32] = { in: [31] };
    connections[33] = { in: [31] };
    connections[34] = { in: [31] };
    connections[35] = { in: [34] };
    connections[36] = { in: [34] };
    connections[37] = { in: rawMode ? [35, 36] : ['concat_35_36'] };
    connections[38] = { in: [37], in2: rawMode ? [32, 33] : ['concat_32_33'] };

    connections[39] = { in: [38] };
    connections[40] = { in: [39] };
    connections[41] = { in: [39] };
    connections[42] = { in: rawMode ? [40, 41] : ['concat_40_41'] };
    connections[43] = { in: [42], in2: [38] };

    connections[44] = { in: [43] };
    connections[45] = { in: [44] };
    connections[46] = { in: [44] };
    connections[47] = { in: rawMode ? [45, 46] : ['concat_45_46'] };
    connections[48] = { in: [47], in2: [43] };

    connections[49] = { in: [48] };
    connections[50] = { in: [49] };
    connections[51] = { in: [49] };
    connections[52] = { in: rawMode ? [50, 51] : ['concat_50_51'] };
    connections[53] = { in: [52], in2: [48] };

    connections[54] = { in: [53] };
    connections[55] = { in: [54] };
    connections[56] = { in: [54] };
    connections[57] = { in: rawMode ? [55, 56] : ['concat_55_56'] };
    connections[58] = { in: [57], in2: [53] };

    connections[59] = { in: [58] };
    connections[60] = { in: [59] };
    connections[61] = { in: [59] };
    connections[62] = { in: rawMode ? [60, 61] : ['concat_60_61'] };
    connections[63] = { in: [62], in2: [58] };

    // Layer 4 (7x7, 2048ch)
    connections[64] = { in: [63] };
    for (let j = 65; j <= 69; j++) connections[j] = { in: [64] };
    connections[70] = { in: [63] };
    connections[71] = { in: [63] };
    for (let j = 72; j <= 87; j++) connections[j] = { in: rawMode ? [70, 71] : ['concat_70_71'] };
    for (let j = 88; j <= 91; j++) connections[j] = { in: rawMode ? Array.from({length: 16}, (_, k) => 72 + k) : ['concat_72_87'] };
    connections[92] = {
        in: rawMode ? [88, 89, 90, 91] : ['concat_88_91'],
        in2: rawMode ? [65, 66, 67, 68, 69] : ['concat_65_69']
    };

    for (let j = 93; j <= 95; j++) connections[j] = { in: [92] };
    for (let j = 96; j <= 101; j++) connections[j] = { in: rawMode ? [93, 94, 95] : ['concat_93_95'] };
    for (let j = 102; j <= 105; j++) connections[j] = { in: rawMode ? [96, 97, 98, 99, 100, 101] : ['concat_96_101'] };
    connections[106] = {
        in: rawMode ? [102, 103, 104, 105] : ['concat_102_105'],
        in2: [92]
    };

    for (let j = 107; j <= 109; j++) connections[j] = { in: [106] };
    for (let j = 110; j <= 115; j++) connections[j] = { in: rawMode ? [107, 108, 109] : ['concat_107_109'] };
    for (let j = 116; j <= 119; j++) connections[j] = { in: rawMode ? [110, 111, 112, 113, 114, 115] : ['concat_110_115'] };
    connections[120] = {
        in: rawMode ? [116, 117, 118, 119] : ['concat_116_119'],
        in2: [106]
    };

    // Final classification
    connections[121] = { in: [120] };
    connections[122] = { in: [121] };
    connections[123] = { in: [122] };

    const gathers = rawMode ? [] : [
        // Layer 3 Block 8 shortcut (2 tiles -> 1024ch)
        { id: 'concat_32_33', producers: [32, 33] },
        // Layer 3 3x3 conv tiles (2 tiles each -> 256ch)
        { id: 'concat_35_36', producers: [35, 36] },
        { id: 'concat_40_41', producers: [40, 41] },
        { id: 'concat_45_46', producers: [45, 46] },
        { id: 'concat_50_51', producers: [50, 51] },
        { id: 'concat_55_56', producers: [55, 56] },
        { id: 'concat_60_61', producers: [60, 61] },
        // Layer 4 Block 14 shortcut (5 tiles -> 2048ch)
        { id: 'concat_65_69', producers: [65, 66, 67, 68, 69] },
        // Layer 4 Block 14 1x1 reduce (2 tiles -> 512ch)
        { id: 'concat_70_71', producers: [70, 71] },
        // Layer 4 Block 14 3x3 conv (16 tiles -> 512ch)
        { id: 'concat_72_87', producers: Array.from({length: 16}, (_, k) => 72 + k) },
        // Layer 4 Block 14 1x1 expand (4 tiles -> 2048ch)
        { id: 'concat_88_91', producers: [88, 89, 90, 91] },
        // Layer 4 Block 15 1x1 reduce (3 tiles -> 512ch)
        { id: 'concat_93_95', producers: [93, 94, 95] },
        // Layer 4 Block 15 3x3 conv (6 tiles -> 512ch)
        { id: 'concat_96_101', producers: Array.from({length: 6}, (_, k) => 96 + k) },
        // Layer 4 Block 15 1x1 expand (4 tiles -> 2048ch)
        { id: 'concat_102_105', producers: [102, 103, 104, 105] },
        // Layer 4 Block 16 1x1 reduce (3 tiles -> 512ch)
        { id: 'concat_107_109', producers: [107, 108, 109] },
        // Layer 4 Block 16 3x3 conv (6 tiles -> 512ch)
        { id: 'concat_110_115', producers: Array.from({length: 6}, (_, k) => 110 + k) },
        // Layer 4 Block 16 1x1 expand (4 tiles -> 2048ch)
        { id: 'concat_116_119', producers: [116, 117, 118, 119] },
    ];

    return { connections, gathers };
};

hwx.Graph.getResNet50Connections = function(rawMode = false) {
    return hwx.Graph.getResNet50Spec(rawMode).connections;
};

hwx.Node = class {

    constructor(name, type, inputs, outputs, attributes) {
        this.name = name;
        this.type = type;
        this.inputs = inputs || [];
        this.outputs = outputs || [];
        this.attributes = attributes || [];
    }
};

hwx.Argument = class {

    constructor(name, value, type = null, visible = true) {
        this.name = name;
        this.value = value;
        this.type = type;
        this.visible = visible;
    }
};

hwx.Value = class {

    constructor(name, type, initializer = null) {
        if (typeof name !== 'string') {
            throw new Error(`Invalid value identifier '${JSON.stringify(name)}'.`);
        }
        this.name = name;
        this.type = !type && initializer ? initializer.type : type;
        this.initializer = initializer;
    }
};

hwx.TensorType = class {

    constructor(dataType, shape) {
        this.dataType = dataType;
        this.shape = shape instanceof hwx.TensorShape ? shape : new hwx.TensorShape(shape);
    }

    equals(obj) {
        return obj && this.dataType === obj.dataType && this.shape && this.shape.equals(obj.shape);
    }

    toString() {
        return this.dataType + (this.shape ? this.shape.toString() : '');
    }
};

hwx.TensorShape = class {

    constructor(dimensions) {
        this.dimensions = dimensions;
    }

    equals(obj) {
        if (obj && Array.isArray(obj.dimensions) && Array.isArray(this.dimensions)) {
            if (this.dimensions.length === obj.dimensions.length) {
                return obj.dimensions.every((val, idx) => this.dimensions[idx] === val);
            }
        }
        return false;
    }

    toString() {
        if (this.dimensions && Array.isArray(this.dimensions) && this.dimensions.length > 0) {
            return `[${this.dimensions.map((dim) => dim !== undefined && dim !== null ? dim.toString() : '?').join(',')}]`;
        }
        return '';
    }
};

/**
 * Embedded ANE HWX Parser
 */
hwx.Parser = {

    toHex(val, padding = 8) {
        if (val === undefined || val === null) return "N/A";
        return "0x" + val.toString(16).toUpperCase().padStart(padding, "0");
    },

    getArchitectureName(subtype) {
        switch (subtype) {
            case 1: return "H11 (A12)";
            case 3: return "H12 (A13)";
            case 4: return "H13 (A14/M1)";
            case 5: return "H14 (A15/M2)";
            case 6: return "H15 (A16/M3)";
            case 7: return "H16 (A17 Pro/M4)";
            case 9: return "H17 (A18 Pro)";
            case 10: return "H18 (A19)";
            case 11: return "H18g (M6) / H19 (A20 Pro)";
            default: return "Unknown Subtype (" + subtype + ")";
        }
    },

    getChFmtName(fmt) {
        switch (fmt) {
            case 0: return "UINT8";
            case 1: return "INT8";
            case 2: return "FLOAT16";
            case 4: return "E4M3";
            default: return "Unknown(" + fmt + ")";
        }
    },

    parse(arrayBuffer) {
        const view = new DataView(arrayBuffer);
        const size = arrayBuffer.byteLength;

        if (size < 32) {
            throw new Error("File too small to be a Mach-O container (minimum 32 bytes).");
        }

        const magic = view.getUint32(0, true);
        if (magic !== 0xBEEFFACE && magic !== 0xFEEDFACF) {
            throw new Error(`Invalid magic: ${this.toHex(magic)}. Expected 0xBEEFFACE or 0xFEEDFACF.`);
        }

        const cputype = view.getUint32(4, true);
        const cpusubtype = view.getUint32(8, true);
        const filetype = view.getUint32(12, true);
        const ncmds = view.getUint32(16, true);
        const sizeofcmds = view.getUint32(20, true);
        const flags = view.getUint32(24, true);

        const headerInfo = {
            magic,
            cputype,
            cpusubtype,
            filetype,
            ncmds,
            sizeofcmds,
            flags,
            archName: this.getArchitectureName(cpusubtype),
            usesInstructionStream: cpusubtype >= 5,
            usesSparse: cpusubtype >= 7
        };

        // Find __TEXT segment and __text section
        let textSection = null;
        let offset = 32;

        for (let i = 0; i < ncmds; i++) {
            if (offset + 8 > size) break;
            const cmd = view.getUint32(offset, true);
            const cmdsize = view.getUint32(offset + 4, true);

            if (cmd === 0x19) { // LC_SEGMENT_64
                let segname = "";
                for (let j = 0; j < 16; j++) {
                    const charCode = view.getUint8(offset + 8 + j);
                    if (charCode === 0) break;
                    segname += String.fromCharCode(charCode);
                }

                if (segname === "__TEXT") {
                    const nsects = view.getUint32(offset + 64, true);
                    let sectOffset = offset + 72;

                    for (let s = 0; s < nsects; s++) {
                        if (sectOffset + 80 > size) break;
                        let sectname = "";
                        for (let j = 0; j < 16; j++) {
                            const charCode = view.getUint8(sectOffset + j);
                            if (charCode === 0) break;
                            sectname += String.fromCharCode(charCode);
                        }

                        if (sectname === "__text") {
                            const sectSize = Number(view.getBigUint64(sectOffset + 40, true));
                            const sectFileOffset = view.getUint32(sectOffset + 48, true);
                            textSection = {
                                offset: sectFileOffset,
                                size: sectSize
                            };
                            break;
                        }
                        sectOffset += 80;
                    }
                }
            }
            offset += cmdsize;
            if (textSection) break;
        }

        if (!textSection) {
            throw new Error("__text section in __TEXT segment not found. This is not a standard .hwx file.");
        }

        const tasks = [];
        const taskOffset = textSection.offset;
        let taskNum = 0;

        if (cpusubtype < 5) {
            // H13 or earlier linked list
            let curOffset = 0;
            const total_len = textSection.size;
            const h13Context = { lastSrcBase: 0 };

            while (curOffset + 40 <= total_len) {
                const exe_cycles_raw = view.getUint32(taskOffset + curOffset + 4, true);
                const log_events = view.getUint32(taskOffset + curOffset + 8, true);
                const next_pointer = view.getUint32(taskOffset + curOffset + 28, true);

                if (next_pointer === 0 && exe_cycles_raw === 0 && log_events === 0) {
                    break;
                }

                let taskSizeWords = 0;
                if (next_pointer > curOffset + 40) {
                    taskSizeWords = (next_pointer - curOffset) / 4;
                } else {
                    taskSizeWords = (total_len - curOffset) / 4;
                }

                const taskSizeInBytes = taskSizeWords * 4;
                const parsedTask = this.parseH13Task(view, taskOffset + curOffset, taskSizeWords, h13Context);
                parsedTask.taskIndex = taskNum++;
                parsedTask.fileOffset = taskOffset + curOffset;
                parsedTask.sizeBytes = taskSizeInBytes;
                parsedTask.dmaAddrs = this.getDmaAddrs(parsedTask, cpusubtype);

                tasks.push(parsedTask);

                if (next_pointer === 0 || next_pointer <= curOffset) {
                    break;
                }
                curOffset = next_pointer;
            }
        } else {
            // H14+ sequential instruction stream
            let curOffset = 0;
            const total_len = textSection.size;

            while (curOffset + 8 <= total_len) {
                const tid_and_size = view.getUint32(taskOffset + curOffset, true);
                const task_size = (tid_and_size >> 16) & 0x7FF;
                if (task_size === 0) {
                    curOffset += 16;
                    continue;
                }
                break;
            }

            const runningState = {
                values: new Uint32Array(8192),
                valid: new Uint8Array(8192),
                subtype: cpusubtype
            };

            while (curOffset + 36 <= total_len) {
                const tid_and_size = view.getUint32(taskOffset + curOffset, true);
                const task_size = (tid_and_size >> 16) & 0x7FF;

                if (task_size === 0) {
                    curOffset += 16;
                    continue;
                }

                const taskSizeInBytes = task_size * 4;
                if (curOffset + taskSizeInBytes > total_len) {
                    break;
                }

                const parsedTask = this.decodeInstructionStream(view, taskOffset + curOffset, task_size, cpusubtype, runningState);
                parsedTask.taskIndex = taskNum++;
                parsedTask.fileOffset = taskOffset + curOffset;
                parsedTask.sizeBytes = taskSizeInBytes;
                parsedTask.dmaAddrs = this.getDmaAddrs(parsedTask, cpusubtype);

                tasks.push(parsedTask);

                curOffset += Math.ceil(taskSizeInBytes / 16) * 16;
            }
        }

        return {
            header: headerInfo,
            section: textSection,
            tasks: tasks
        };
    },

    getDmaAddrs(task, cpusubtype) {
        let dst = null;
        let src1 = null;
        let src2 = null;

        if (cpusubtype >= 7) {
            const regs = task.activeRegisters || [];
            const rDst = regs.find(r => r.addrWord === "0x1442");
            const rSrc1 = regs.find(r => r.addrWord === "0x1344");
            const rSrc2 = regs.find(r => r.addrWord === "0x134A");
            if (rDst && rDst.val !== "0x00000000") dst = rDst.val;
            if (rSrc1 && rSrc1.val !== "0x00000000") src1 = rSrc1.val;
            if (rSrc2 && rSrc2.val !== "0x00000000") src2 = rSrc2.val;
        } else if (cpusubtype === 5 || cpusubtype === 6) {
            const regs = task.activeRegisters || [];
            const rDst = regs.find(r => r.addrWord === "0x0542");
            const rSrc1 = regs.find(r => r.addrWord === "0x0444");
            const rSrc2 = regs.find(r => r.addrWord === "0x044A");
            if (rDst && rDst.val !== "0x00000000") dst = rDst.val;
            if (rSrc1 && rSrc1.val !== "0x00000000") src1 = rSrc1.val;
            if (rSrc2 && rSrc2.val !== "0x00000000") src2 = rSrc2.val;
        } else {
            if (task.decodedInfo && task.decodedInfo.tileDma) {
                if (task.decodedInfo.tileDma.DstBase) dst = "0x" + task.decodedInfo.tileDma.DstBase.toString(16).padStart(8, '0');
                if (task.decodedInfo.tileDma.SrcBase) src1 = "0x" + task.decodedInfo.tileDma.SrcBase.toString(16).padStart(8, '0');
            }
        }
        return { dst, src1, src2 };
    },

    decodeInstructionStream(view, taskOffset, taskSizeWords, cpusubtype, runningState = null) {
        if (!runningState) {
            runningState = {
                values: new Uint32Array(8192),
                valid: new Uint8Array(8192),
                subtype: cpusubtype
            };
        }

        const tid_and_size = view.getUint32(taskOffset + 0, true);
        const exe_cycles_raw = view.getUint32(taskOffset + 4, true);
        const log_events = view.getUint32(taskOffset + 8, true);
        const exceptions = view.getUint32(taskOffset + 12, true);
        const debug_log_events = view.getUint32(taskOffset + 16, true);
        const debug_exceptions = view.getUint32(taskOffset + 20, true);
        const dram_log_events = view.getUint32(taskOffset + 24, true);
        const unknown_flags = view.getUint32(taskOffset + 28, true);
        const ctrl_flags = view.getUint32(taskOffset + 32, true);
        const dtid_raw = view.getUint32(taskOffset + 36, true);

        const tid = tid_and_size & 0xFFFF;
        const task_size = (tid_and_size >> 16) & 0x7FF;
        const exe_cycles = exe_cycles_raw & 0xFFFF;
        const tsr = ctrl_flags & 0x1;
        const tde = (ctrl_flags >> 1) & 0x1;
        const ene = (ctrl_flags >> 16) & 0x7;
        const dtid = dtid_raw & 0xFFFF;

        const startWord = (cpusubtype === 5 || cpusubtype === 6) ? 8 : 9;
        let i = startWord;

        while (i < taskSizeWords) {
            const header = view.getUint32(taskOffset + i * 4, true);
            i++;
            const hw_addr = header & 0x7FFF;

            if (((header >> 31) & 1) === 0) {
                // Dense
                const count = (header >> 15) & 0x3F;
                for (let j = 0; j <= count && i < taskSizeWords; j++) {
                    const val = view.getUint32(taskOffset + i * 4, true);
                    runningState.values[hw_addr + j] = val;
                    runningState.valid[hw_addr + j] = 1;
                    i++;
                }
            } else {
                // Sparse
                const mask = (header >> 15) & 0xFFFF;
                if (i < taskSizeWords) {
                    const val = view.getUint32(taskOffset + i * 4, true);
                    runningState.values[hw_addr] = val;
                    runningState.valid[hw_addr] = 1;
                    i++;
                }
                for (let bit = 0; bit < 16 && i < taskSizeWords; bit++) {
                    if ((mask >> bit) & 1) {
                        const val = view.getUint32(taskOffset + i * 4, true);
                        runningState.values[hw_addr + bit + 1] = val;
                        runningState.valid[hw_addr + bit + 1] = 1;
                        i++;
                    }
                }
            }
        }

        const recoveredInfo = this.parseStateRegisters(runningState, cpusubtype);

        return {
            header: {
                tid,
                task_size,
                exe_cycles,
                log_events,
                exceptions,
                debug_log_events,
                debug_exceptions,
                dram_log_events,
                unknown_flags,
                ctrl_flags,
                tsr,
                tde,
                ene,
                dtid
            },
            decodedInfo: recoveredInfo,
            activeRegisters: this.dumpState(runningState)
        };
    },

    parseH13Task(view, taskOffset, taskSizeWords, h13Context = null) {
        const tid_and_flags = view.getUint32(taskOffset + 0, true);
        const exe_cycles_raw = view.getUint32(taskOffset + 4, true);
        const log_events = view.getUint32(taskOffset + 8, true);
        const exceptions = view.getUint32(taskOffset + 12, true);
        const debug_log_events = view.getUint32(taskOffset + 16, true);
        const debug_exceptions = view.getUint32(taskOffset + 20, true);
        const control_flags = view.getUint32(taskOffset + 24, true);
        const next_pointer = view.getUint32(taskOffset + 28, true);
        const bank_enables = view.getUint32(taskOffset + 32, true);
        const kbank_enables = view.getUint32(taskOffset + 36, true);
        const dtid_raw = view.getUint32(taskOffset + 40, true);

        const tid = tid_and_flags & 0xFFFF;
        const nid = (tid_and_flags >> 16) & 0xFF;
        const lnid = (tid_and_flags >> 24) & 1;
        const eon = (tid_and_flags >> 25) & 1;
        const exe_cycles = exe_cycles_raw & 0xFFFF;
        const next_size = (exe_cycles_raw >> 16) & 0x1FF;
        const dtid = dtid_raw & 0xFFFF;

        const H13_COMMON_BLOCK = 0x128;
        const H13_L2_BLOCK = 0x1E0;
        const H13_PE_BLOCK = 0x22C;
        const H13_NE_BLOCK = 0x240;
        const H13_TILEDMA_SRC_BLOCK = 0x16C;
        const H13_TILEDMA_DST_BLOCK = 0x258;

        const indim = view.getUint32(taskOffset + H13_COMMON_BLOCK + 0, true);
        const chcfg = view.getUint32(taskOffset + H13_COMMON_BLOCK + 8, true);
        const inch = view.getUint32(taskOffset + H13_COMMON_BLOCK + 12, true);
        const outch = view.getUint32(taskOffset + H13_COMMON_BLOCK + 16, true);
        const outdim = view.getUint32(taskOffset + H13_COMMON_BLOCK + 20, true);
        const conv = view.getUint32(taskOffset + H13_COMMON_BLOCK + 28, true);

        const win = indim & 0x7FFF;
        const hin = (indim >> 16) & 0x7FFF;
        const wout = outdim & 0x7FFF;
        const hout = (outdim >> 16) & 0x7FFF;
        const cin = inch & 0x1FFFF;
        const cout = outch & 0x1FFFF;

        const in_fmt = chcfg & 0x3;
        const out_fmt = (chcfg >> 4) & 0x3;
        const formatNames = ["INT8", "UINT8", "FLOAT16", "Unknown"];
        const inFmtName = formatNames[in_fmt] || "Unknown";
        const outFmtName = formatNames[out_fmt] || "Unknown";

        const kw = conv & 0x1F;
        const kh = (conv >> 5) & 0x1F;
        const sx = (conv >> 13) & 0x3;
        const sy = (conv >> 15) & 0x3;

        const l2_src1 = view.getUint32(taskOffset + H13_L2_BLOCK + 8, true);
        const l2_res = view.getUint32(taskOffset + H13_L2_BLOCK + 13 * 4, true);

        const ne_maccfg = view.getUint32(taskOffset + H13_NE_BLOCK + 4, true);
        const activeNE = ne_maccfg & 0x7;
        const smallSrc = (ne_maccfg >> 3) & 1;
        const neOpMode = (ne_maccfg >> 10) & 0xF;
        const biasEn = (ne_maccfg >> 16) & 1;
        const nlMode = (ne_maccfg >> 20) & 0xF;

        const opModeNames = { 0x0: "Conv", 0x1: "Bypass", 0x2: "MatMul", 0x7: "OptConv" };
        const nlModeNames = { 0x0: "None", 0x1: "ReLU", 0x2: "ReLU6", 0x3: "Sigmoid", 0x4: "Tanh", 0x5: "GELU" };

        const pe_cfg = view.getUint32(taskOffset + H13_PE_BLOCK + 0, true);
        const v200 = view.getUint32(taskOffset + 0x200, true);
        let peEn = (pe_cfg >> 1) & 1;
        let peOpModeName = "None";
        let pePoolModeName = "None";
        let taskTypeName = opModeNames[neOpMode] || "Conv";

        const isH13Add = [6, 10, 14, 19, 23, 27, 31, 38, 43, 48, 53, 58, 63, 92, 106, 120].includes(tid);
        if (tid === 1 || v200 === 0x01000002) {
            peEn = 1;
            pePoolModeName = "Max";
            taskTypeName = "Pooling w/ input ReLU";
        } else if (tid === 121 || (win > 1 && wout === 1 && hout === 1)) {
            peEn = 1;
            taskTypeName = "EW w/ Reduction w/ ReLU";
            pePoolModeName = "Avg";
            peOpModeName = "Add";
        } else if (tid === 122 || (v200 & 0xFF000000) === 0x03000000) {
            taskTypeName = "Bypass";
        } else if (isH13Add || (v200 !== 0 && tid !== 64)) {
            peEn = 1;
            peOpModeName = "Add";
            taskTypeName = "EW w/o Reduction w/o ReLU";
        }

        if (!h13Context) h13Context = { lastSrcBase: 0 };
        const tdma_src_base = view.getUint32(taskOffset + H13_TILEDMA_SRC_BLOCK + 8, true);
        const tdma_dst_base = view.getUint32(taskOffset + H13_TILEDMA_DST_BLOCK + 4, true);

        let effSrcBase = tdma_src_base;
        if ((bank_enables & 0x3) === 0 && h13Context.lastSrcBase !== undefined) {
            effSrcBase = h13Context.lastSrcBase;
        } else {
            h13Context.lastSrcBase = tdma_src_base;
        }

        const tempState = {
            values: new Uint32Array(8192),
            valid: new Uint8Array(8192),
            subtype: 4
        };

        const mapH13Block = (tdOff, hwBase, count) => {
            for (let word = 0; word < count; word++) {
                const addr = hwBase + word;
                if (addr < 8192) {
                    tempState.values[addr] = view.getUint32(taskOffset + tdOff + word * 4, true);
                    tempState.valid[addr] = 1;
                }
            }
        };

        mapH13Block(H13_COMMON_BLOCK, 0x0000, 16);
        mapH13Block(H13_L2_BLOCK, 0x0140, 16);
        mapH13Block(H13_PE_BLOCK, 0x0240, 4);
        mapH13Block(H13_NE_BLOCK, 0x0340, 5);
        mapH13Block(H13_TILEDMA_SRC_BLOCK, 0x0440, 24);
        mapH13Block(H13_TILEDMA_DST_BLOCK, 0x0540, 7);

        return {
            header: {
                tid,
                task_size: taskSizeWords,
                exe_cycles,
                log_events,
                exceptions,
                debug_log_events,
                debug_exceptions,
                ctrl_flags: control_flags,
                dtid
            },
            decodedInfo: {
                inputDim: { W: win, H: hin, C: cin, D: 1 },
                outputDim: { W: wout, H: hout, C: cout, D: 1 },
                inFormat: inFmtName,
                outFormat: outFmtName,
                conv: (kw || kh) ? { KW: kw, KH: kh, SX: sx, SY: sy, PL: 0, PT: 0 } : null,
                l2: { Src1Base: l2_src1, Src2Base: 0, ResBase: l2_res },
                ne: {
                    activeNE,
                    smallSrc,
                    opMode: opModeNames[neOpMode] || `Unknown(${this.toHex(neOpMode, 1)})`,
                    biasEn: biasEn ? "YES" : "NO",
                    activation: nlModeNames[nlMode] || `Unknown(${nlMode})`,
                    kfmt: inFmtName
                },
                pe: {
                    active: peEn ? true : false,
                    opMode: peOpModeName,
                    poolMode: pePoolModeName,
                    cond: "None",
                    lutEn: "NO",
                    redKeep: "NO"
                },
                tileDma: {
                    SrcBase: effSrcBase,
                    DstBase: tdma_dst_base
                },
                taskInfo: {
                    taskType: taskTypeName
                }
            },
            activeRegisters: this.dumpState(tempState)
        };
    },

    parseStateRegisters(state, cpusubtype) {
        let win = 0, hin = 0, cin = 0, din = 1;
        let wout = 0, hout = 0, cout = 0, dout = 1;
        let inFmtName = "FLOAT16";
        let outFmtName = "FLOAT16";

        if (cpusubtype >= 7) {
            win = state.values[1] & 0x1FFFF;
            hin = state.values[2] & 0x1FFFF;
            cin = state.values[3] & 0x1FFFF;
            din = (state.values[4] & 0x1FFFF) || 1;
            wout = state.values[5] & 0x1FFFF;
            hout = state.values[6] & 0x1FFFF;
            cout = state.values[7] & 0x1FFFF;
            dout = (state.values[8] & 0x1FFFF) || 1;

            let chCfgBase = 0;
            if (cpusubtype === 7 &&
                (win === 0 || win >= 65536 || hin >= 65536 || cin >= 65536 || state.values[0] === 0)) {
                const test_w = state.values[0x0b] & 0x1FFFF;
                const test_h = state.values[0x0c] & 0x1FFFF;
                const test_c = state.values[0x0d] & 0x1FFFF;
                if (test_w > 0 && test_w < 10000 && test_h <= test_w && test_h < 10000 && test_c > 0 && test_c < 10000) {
                    win = test_w;
                    hin = test_h;
                    cin = test_c;
                    chCfgBase = 0x0a;
                }
            }

            let inFmtVal, outFmtVal;
            if (!state.valid[0]) {
                inFmtVal = 2;
                outFmtVal = 2;
            } else {
                const chCfgWord = state.values[chCfgBase];
                if (cpusubtype >= 10) {
                    inFmtVal = chCfgWord & 7;
                    outFmtVal = (chCfgWord >> 6) & 7;
                } else {
                    inFmtVal = chCfgWord & 3;
                    outFmtVal = (chCfgWord >> 4) & 3;
                }
            }
            inFmtName = this.getChFmtName(inFmtVal);
            outFmtName = this.getChFmtName(outFmtVal);
        } else {
            const indim = state.values[0];
            const outdim = state.values[5];
            win = indim & 0x7FFF;
            hin = (indim >> 16) & 0x7FFF;
            cin = state.values[3] & 0x1FFFF;
            cout = state.values[4] & 0x1FFFF;
            wout = outdim & 0x7FFF;
            hout = (outdim >> 16) & 0x7FFF;
        }

        const conv = state.values[cpusubtype >= 7 ? 10 : 8];
        let convConfig = null;
        if (conv) {
            const kw = conv & 0x3F;
            const kh = (conv >> 6) & 0x3F;
            const sx = (conv >> 13) & 3;
            const sy = (conv >> 15) & 3;
            const pl = (conv >> 17) & 0x1F;
            const pt = (conv >> 22) & 0x1F;
            if (kw || kh) {
                convConfig = { KW: kw, KH: kh, SX: sx, SY: sy, PL: pl, PT: pt };
            }
        }

        let l2 = {};
        if (cpusubtype >= 7) {
            const l2Base = 0x1040;
            l2.Src1Base = (state.values[l2Base + 4] & 0x1FFFF0);
            l2.Src2Base = (state.values[l2Base + 9] & 0x1FFFF0);
            l2.ResBase = (state.values[l2Base + 19] & 0x1FFFF0);
            l2.SrcIdxBase = (state.values[l2Base + 14] & 0x1FFFF0);
        } else {
            const l2Base = 0x0140;
            l2.Src1Base = state.values[l2Base + 3];
            l2.Src2Base = state.values[l2Base + 8];
            l2.ResBase = state.values[l2Base + 14];
        }

        const task_type_mapped_dict = {0: 0, 1: 2, 2: 6, 3: 5, 4: 7, 5: 4, 6: 3, 7: 0, 8: 1};
        const hwTaskTypeNames = {
            0: "None",
            1: "Pooling w/o input ReLU",
            2: "Pooling w/ input ReLU",
            3: "EW w/ Reduction w/o ReLU",
            4: "EW w/ Reduction w/ ReLU",
            5: "EW w/o Reduction w/o ReLU",
            6: "EW w/o Reduction w/ ReLU",
            7: "GOC"
        };
        let activeNE = 0, smallSrc = 0, taskTypeRaw = 0, taskTypeMapped = 0;
        let reluTypeCommon = 0, outTrans = 0, fillLowerNE = 0, traceEn = 0, wino1d = 0;
        let commonMacCfgValid = false;

        if (cpusubtype >= 7) {
            commonMacCfgValid = state.valid[15] === 1;
            const m = commonMacCfgValid ? state.values[15] : 0;
            activeNE = (m >> 19) & 7;
            smallSrc = (m >> 2) & 3;
            taskTypeRaw = (m >> 4) & 0xF;
            traceEn = (m >> 22) & 1;
            reluTypeCommon = (m >> 24) & 7;
            wino1d = (m >> 27) & 1;
            outTrans = (m >> 28) & 1;
            fillLowerNE = (m >> 29) & 1;
        } else if (cpusubtype === 5 || cpusubtype === 6) {
            commonMacCfgValid = state.valid[10] === 1;
            const m = commonMacCfgValid ? state.values[10] : 0;
            taskTypeRaw = m & 0xF;
            activeNE = (m >> 4) & 7;
            smallSrc = (m >> 7) & 1;
            reluTypeCommon = (m >> 8) & 7;
        }
        taskTypeMapped = task_type_mapped_dict[taskTypeRaw] !== undefined ? task_type_mapped_dict[taskTypeRaw] : 0;
        const isPEActive = commonMacCfgValid && taskTypeMapped !== 0;

        let pe = {};
        const peBase = (cpusubtype >= 7) ? 0x1140 : 0x0240;
        const pe_cfg = state.values[peBase + 0];

        if (isPEActive) {
            const pool = pe_cfg & 3;
            const op = (pe_cfg >> 2) & 7;
            const lut_en = (pe_cfg >> 5) & 1;
            const cond = (pe_cfg >> 6) & 7;
            const red_idx = (pe_cfg >> 9) & 3;
            const red_keep = (pe_cfg >> 11) & 1;
            const nl = (pe_cfg >> 12) & 3;
            const src1 = (pe_cfg >> 16) & 1;
            const src2 = (pe_cfg >> 18) & 3;

            const poolNames = ["None", "Avg", "Max", "Min"];
            const opNames = ["Add", "Mul", "Max", "Min", "SumSqr"];
            const condNames = ["None", "Less", "Greater", "NotEqual", "Equal", "LessEqual", "GreaterEqual", "Abs"];
            const nlNames = ["None", "ReLU", "Clamp", "Abs"];

            const poolNameApplies = taskTypeMapped === 0 || taskTypeMapped === 2;
            const opNameApplies = taskTypeMapped >= 3 && taskTypeMapped <= 6;
            pe.poolMode = poolNameApplies ? (poolNames[pool] || "None") : "None";
            pe.opMode = opNameApplies ? (opNames[op] || "None") : "None";
            pe.lutEn = lut_en ? "YES" : "NO";
            pe.cond = condNames[cond] || "None";
            pe.redIdx = red_idx;
            pe.redKeep = red_keep ? "YES" : "NO";
            pe.nlMode = nlNames[nl] || "None";
            pe.src1 = src1;
            pe.src2 = src2;
            pe.active = true;
        } else {
            pe.poolMode = "None";
            pe.opMode = "None";
            pe.lutEn = "NO";
            pe.cond = "None";
            pe.redIdx = 0;
            pe.redKeep = "NO";
            pe.nlMode = "None";
            pe.src1 = 0;
            pe.src2 = 0;
            pe.active = false;
        }

        let ne = {};
        const neBase = (cpusubtype >= 7) ? 0x1240 : 0x0340;
        const kernel_cfg = state.values[neBase + 0];
        const ne_maccfg = state.values[neBase + 1];

        let kfmt = 0, pen = 0, pbits = 0, sen = 0, reuse = 0, sbs = 0, asym = 0, detectZeros = 0;
        if (cpusubtype >= 7) {
            kfmt = kernel_cfg & 3;
            pen = (kernel_cfg >> 2) & 1;
            pbits = (kernel_cfg >> 4) & 0xF;
            sen = (kernel_cfg >> 8) & 1;
            reuse = (kernel_cfg >> 10) & 1;
            sbs = (kernel_cfg >> 21) & 7;
            asym = (kernel_cfg >> 24) & 1;
            if (cpusubtype >= 9) {
                detectZeros = (kernel_cfg >> 28) & 1;
            }
        }

        const kfmtNames = ["UINT8", "INT8", "FLOAT16", "E4M3", "INT4", "E2M1"];
        ne.kfmt = kfmtNames[kfmt] !== undefined ? kfmtNames[kfmt] : "Unknown(" + kfmt + ")";
        ne.pen = pen ? "YES" : "NO";
        ne.pbits = pbits;
        ne.sen = sen ? "YES" : "NO";
        ne.reuse = reuse ? "YES" : "NO";
        ne.sbs = sbs;
        ne.asym = asym ? "YES" : "NO";
        ne.detectZeros = cpusubtype >= 9 ? (detectZeros ? "YES" : "NO") : "N/A";

        let opMode = 0, km = 0, biasEn = 0, passEn = 0, mvBiasEn = 0, binPoint = 0;
        let postEn = 0, nlMode = 0, maxPoolEn = 0, argSel = 0, doubleInt8 = 0;
        if (cpusubtype >= 7) {
            opMode = ne_maccfg & 7;
            km = (ne_maccfg >> 3) & 1;
            biasEn = (ne_maccfg >> 4) & 1;
            passEn = (ne_maccfg >> 5) & 1;
            mvBiasEn = (ne_maccfg >> 6) & 1;
            binPoint = (ne_maccfg >> 8) & 0x3F;
            postEn = (ne_maccfg >> 14) & 1;
            nlMode = (ne_maccfg >> 16) & 3;
            maxPoolEn = (ne_maccfg >> 19) & 1;
            argSel = (ne_maccfg >> 20) & 0xF;
            doubleInt8 = (ne_maccfg >> 26) & 1;
        } else {
            opMode = (ne_maccfg >> 10) & 0xF;
            biasEn = (ne_maccfg >> 16) & 1;
            nlMode = (ne_maccfg >> 20) & 0xF;
        }

        const neOpNames = {
            0: "Conv",
            1: "EWSqr",
            2: "EWMul",
            3: "Pool",
            4: "Bypass",
            5: "RCAS",
            7: "OptConv (H14)",
            0xF: "OptConv (H16+)"
        };
        const neNlNames = { 0x0: "None", 0x1: "ReLU", 0x2: "ReLU6", 0x3: "Sigmoid", 0x4: "Tanh", 0x5: "GELU" };

        ne.activeNE = activeNE;
        ne.smallSrc = smallSrc;
        ne.opMode = neOpNames[opMode] || `Unknown(${opMode})`;
        ne.biasEn = biasEn ? "YES" : "NO";
        ne.activation = cpusubtype >= 7 ? nlMode : (neNlNames[nlMode] || `Unknown(${nlMode})`);
        if (cpusubtype >= 7) {
            ne.kernelMode = km ? "Unity" : "Kernel";
            ne.passEn = passEn ? "YES" : "NO";
            ne.mvBiasEn = mvBiasEn ? "YES" : "NO";
            ne.binPoint = binPoint;
            ne.postEn = postEn ? "YES" : "NO";
            ne.maxPoolEn = maxPoolEn ? "YES" : "NO";
            ne.argSel = argSel;
            ne.doubleInt8 = doubleInt8 ? "YES" : "NO";
        }

        const taskInfo = {
            taskType: hwTaskTypeNames[taskTypeMapped] || `Unknown(${taskTypeMapped})`,
            activeNE,
            smallSrc,
            reluType: reluTypeCommon,
        };
        if (cpusubtype >= 7) {
            taskInfo.outTrans = outTrans ? "YES" : "NO";
            taskInfo.fillLowerNE = fillLowerNE ? "YES" : "NO";
            taskInfo.traceEn = traceEn ? "YES" : "NO";
            taskInfo.wino1d = wino1d ? "YES" : "NO";
        }

        let tileDma = {};
        const tdmaSrcBase = (cpusubtype >= 7) ? 0x1340 : 0x0440;
        const tdmaDstBase = (cpusubtype >= 7) ? 0x1440 : 0x0540;
        tileDma.SrcBase = state.values[tdmaSrcBase + 4];
        tileDma.DstBase = state.values[tdmaDstBase + 2];

        return {
            inputDim: { W: win, H: hin, C: cin, D: din },
            outputDim: { W: wout, H: hout, C: cout, D: dout },
            inFormat: inFmtName,
            outFormat: outFmtName,
            conv: convConfig,
            l2,
            ne,
            pe,
            tileDma,
            taskInfo
        };
    },

    dumpState(state) {
        const regs = [];
        for (let r = 0; r < state.values.length; r++) {
            if (state.valid[r]) {
                regs.push({
                    addr: this.toHex(r * 4, 5),
                    addrWord: this.toHex(r, 4),
                    val: this.toHex(state.values[r], 8),
                    block: this.getBlockName(r, state.subtype)
                });
            }
        }
        return regs;
    },

    getBlockName(addr, subtype) {
        if (subtype >= 7) {
            if (addr >= 0x0000 && addr < 0x0020) return "Common";
            if (addr >= 0x1040 && addr < 0x1140) return "L2 Cache";
            if (addr >= 0x1140 && addr < 0x1240) return "Planar Engine";
            if (addr >= 0x1240 && addr < 0x1340) return "Neural Engine";
            if (addr >= 0x1340 && addr < 0x1440) return "TileDMA Src";
            if (addr >= 0x1440 && addr < 0x1540) return "TileDMA Dst";
            if (addr >= 0x1540 && addr < 0x1640) return "KernelDMA";
        } else if (subtype === 5 || subtype === 6) {
            if (addr >= 0x0000 && addr < 0x0140) return "Common";
            if (addr >= 0x0140 && addr < 0x0240) return "L2 Cache";
            if (addr >= 0x0240 && addr < 0x0340) return "Planar Engine";
            if (addr >= 0x0340 && addr < 0x0440) return "Neural Engine";
            if (addr >= 0x0440 && addr < 0x0540) return "TileDMA Src";
            if (addr >= 0x0540 && addr < 0x0640) return "TileDMA Dst";
            if (addr >= 0x0640 && addr < 0x0740) return "KernelDMA";
        } else {
            if (addr >= 0x0000 && addr < 0x0140) return "Common";
            if (addr >= 0x0140 && addr < 0x0240) return "L2 Cache";
            if (addr >= 0x0240 && addr < 0x0340) return "Planar Engine";
            if (addr >= 0x0340 && addr < 0x0440) return "Neural Engine";
            if (addr >= 0x0440 && addr < 0x0540) return "TileDMA Src";
            if (addr >= 0x0540 && addr < 0x0640) return "TileDMA Dst";
            if (addr >= 0x0640) return "KernelDMA";
        }
        return "Unknown Block";
    }
};

export const ModelFactory = hwx.ModelFactory;
export const Parser = hwx.Parser;
export default hwx;
