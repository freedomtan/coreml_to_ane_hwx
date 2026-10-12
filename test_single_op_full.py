#!/usr/bin/env python3
"""
Create single-operation CoreML models for ANE analysis.
Covers all operations supported by SSAOpRegistry (core, custom, and dialect ops).
"""
import coremltools as ct
from coremltools.converters.mil.mil import Builder as mb
from coremltools.converters.mil.mil.ops.registry import SSAOpRegistry
from coremltools.converters.mil.mil import types
import numpy as np
import traceback
import sys
import os

def get_op_class(op_name):
    """Find the op class for the given op name in registry."""
    for registry in [SSAOpRegistry.core_ops, SSAOpRegistry.custom_ops, SSAOpRegistry.dialect_ops]:
        if op_name in registry:
            val = registry[op_name]
            if isinstance(val, dict):
                return val.get(ct.target.iOS16) or list(val.values())[0]
            else:
                return val
    return None

def mil_type_to_np_dtype(t):
    """Resolve numpy dtype from MIL type."""
    if types.is_bool(t):
        return np.bool_
    if types.is_str(t):
        return str
    if types.is_float(t):
        return np.float32
    if types.is_int(t):
        bitwidth = t.get_bitwidth()
        is_unsigned = t.is_unsigned() if hasattr(t, 'is_unsigned') else False
        if bitwidth == 8:
            return np.uint8 if is_unsigned else np.int8
        elif bitwidth == 16:
            return np.uint16 if is_unsigned else np.int16
        elif bitwidth == 32:
            return np.uint32 if is_unsigned else np.int32
        elif bitwidth == 64:
            return np.uint64 if is_unsigned else np.int64
        elif bitwidth == 1:
            return getattr(types, 'np_uint1_dtype', np.uint8) if is_unsigned else np.int8
        elif bitwidth == 2:
            return getattr(types, 'np_uint2_dtype', np.uint8) if is_unsigned else np.int8
        elif bitwidth == 3:
            return getattr(types, 'np_uint3_dtype', np.uint8) if is_unsigned else np.int8
        elif bitwidth == 4:
            return getattr(types, 'np_uint4_dtype', np.uint8) if is_unsigned else getattr(types, 'np_int4_dtype', np.int8)
        elif bitwidth == 6:
            return getattr(types, 'np_uint6_dtype', np.uint8) if is_unsigned else np.int8
    return np.float32

def make_mock_const(name, itype, op_name, op_cls):
    """Generate mock constant inputs based on target specifications."""
    domain = getattr(itype, 'type_domain', ())
    if len(domain) == 0 and getattr(itype, 'type_domain_id', None) is not None:
        if hasattr(op_cls, 'type_domains') and itype.type_domain_id in op_cls.type_domains:
            domain = op_cls.type_domains[itype.type_domain_id]

    is_int = False
    is_bool = False
    is_str = False
    
    if any(t in str(domain) for t in ['int', 'uint']):
        is_int = True
    if 'bool' in str(domain):
        is_bool = True
    if 'str' in str(domain) or 'string' in str(domain):
        is_str = True

    is_spatial = any(s in op_name for s in ['conv', 'pool', 'pad', 'pixel', 'space', 'depth', 'upsample', 'resize', 'crop'])

    if name in ['data', 'lut', 'nonzero_data', 'indices_nonzero_data', 'quantized_data', 'indices_mask', 'data_mask']:
        return np.ones((10,), dtype=np.float32)

    if name == 'weight':
        if op_name == 'conv_quantized':
            return np.ones((4, 4, 3, 3), dtype=np.uint8)
        elif 'linear' in op_name or op_name == 'matmul':
            return np.ones((10, 10), dtype=np.float32)
        elif is_spatial:
            return np.ones((4, 4, 3, 3), dtype=np.float32)

    if name in ['axes', 'axis']:
        if op_name == 'layer_norm':
            return [-1]
        return [0]
    elif name in ['strides', 'kernel_sizes', 'dilations', 'block_shape']:
        if op_name == 'space_to_batch' or op_name == 'batch_to_space':
            return [2, 2]
        return [1, 1]
    elif name in ['pad', 'crops', 'paddings']:
        if op_name == 'pad':
            return np.array([0, 0, 0, 0, 0, 0, 0, 0], dtype=np.int32)
        if op_name == 'space_to_batch' or op_name == 'batch_to_space':
            return [[0, 0], [0, 0]]
        return [0, 0, 0, 0]
    elif name == 'pad_type':
        return 'valid'
    elif name == 'epsilon':
        return 1e-5
    elif name in ['alpha', 'beta', 'gamma']:
        if op_name == 'relu6' or op_name == 'clip':
            if name == 'alpha': return 0.0
            if name == 'beta': return 6.0
        return 1.0
    elif name in ['sampling_mode', 'padding_mode', 'coordinates_mode']:
        if name == 'sampling_mode': return 'bilinear'
        if name == 'padding_mode': return 'zeros'
        if name == 'coordinates_mode': return 'relative'
    elif name in ['align_corners', 'ceil_mode', 'keep_dims', 'ascending', 'exclude_padding_from_average']:
        return True
    elif name == 'sort':
        return True
    elif name in ['shape', 'target_size', 'reps', 'begin', 'end', 'size', 'elem_shape', 'element_shape', 'resized_dims', 'crop_height', 'crop_width']:
        if name == 'shape' or name == 'elem_shape' or name == 'element_shape':
            if op_name == 'reshape': return [1, 10]
            return [1, 10]
        if name == 'begin': return [0, 0]
        if name == 'end': return [1, 10]
        if name == 'size': return [1, 10]
        if name == 'resized_dims':
            return np.array([16, 16], dtype=np.uint32)
        if name == 'crop_height' or name == 'crop_width':
            return [1, 1]
        return [10, 10]
    elif name == 'perm':
        return [0, 1]
    elif name == 'indices':
        return [0]
    elif name == 'equation':
        return 'ij,jk->ik'
    elif name == 'dtype':
        return 'fp32'
    elif name == 'mode':
        return 'constant'
    elif name == 'classes':
        return ['class0']
    elif name == 'val':
        if op_name == 'constexpr_cast':
            return np.ones((1, 10), dtype=np.float16)
        return np.ones((1, 10), dtype=np.float32)
    elif name == 'lower':
        return 0
    elif name == 'upper':
        return 10
    elif name == 'offset':
        return np.array([0.0], dtype=np.float32)
    elif name == 'k':
        return 1
    elif name == 'constant_val':
        return 0.0
    elif name == 'num_splits':
        return int(2)
    elif name == 'axis_splits':
        return [5, 5]
    elif name == 'alpha_val':
        return 1.0
    elif name == 'beta_val':
        return 0.0
    elif name == 'scale':
        return 1.0
    elif name in ['scale_factor_height', 'scale_factor_width', 'target_height', 'target_width', 'output_height', 'output_width']:
        if 'factor' in name: return 2.0
        return 10
    elif name == 'roi':
        return np.array([[0.0, 0.0, 1.0, 1.0]], dtype=np.float32)
    elif name == 'direction':
        return 'forward'
    elif name == 'zero_point':
        return np.int8(0)
    elif name == 'scale':
        return np.float32(1.0)
    elif name == 'downscale_factor':
        return np.uint32(2)
    
    if is_bool:
        return True
    if is_int:
        return 1
    if is_str:
        return 'valid'
    return 1.0

def make_prog_function(input_names, const_inputs, op_name):
    """Compile program helper dynamically."""
    arg_list = [f"arg{i}" for i in range(len(input_names))]
    arg_str = ", ".join(arg_list)
    
    local_vars = {}
    exec_globals = dict(globals())
    exec_globals.update({
        'mb': mb,
        'const_inputs': const_inputs,
        'op_name': op_name
    })
    
    body_lines = [
        f"def prog({arg_str}):",
        "    op_args = {}",
    ]
    for i, name in enumerate(input_names):
        body_lines.append(f"    op_args['{name}'] = arg{i}")
    body_lines.extend([
        "    for name, val in const_inputs.items():",
        "        op_args[name] = val",
        "    op_func = getattr(mb, op_name)",
        "    op_args['name'] = 'result'",
        "    return op_func(**op_args)"
    ])
    
    func_code = "\n".join(body_lines)
    exec(func_code, exec_globals, local_vars)
    return local_vars['prog']

def build_program(op_name, op_cls):
    """Build the mb.program and return it with deployment target and conversion kwargs."""
    deployment_target = ct.target.iOS16
    if op_name.startswith('constexpr_') or op_name in ['read_state', 'coreml_update_state', 'scaled_dot_product_attention', 'slice_update', 'non_maximum_suppression']:
        deployment_target = ct.target.iOS18
    elif op_name in ['quantize', 'dequantize', 'resize']:
        deployment_target = ct.target.iOS17

    # Overrides for complex operations
    if op_name == 'cond':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1,), dtype=types.bool)])
        def prog(pred):
            return mb.cond(pred=pred, 
                           _true_fn=lambda: mb.const(val=1.0),
                           _false_fn=lambda: mb.const(val=0.0),
                           name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'while_loop':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1,), dtype=types.int32)])
        def prog(loop_var):
            def cond(loop_var):
                return mb.less(x=loop_var, y=10)
            def body(loop_var):
                return mb.add(x=loop_var, y=1)
            return mb.while_loop(loop_vars=(loop_var,), _cond=cond, _body=body, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'make_list':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            l = mb.make_list(init_length=mb.const(val=2), dtype='fp32', elem_shape=(1, 10))
            val = mb.list_read(ls=l, index=mb.const(val=0))
            return mb.add(x=x, y=val, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'tf_make_list':
        @mb.program(input_specs=[])
        def prog():
            l = mb.tf_make_list(init_length=mb.const(val=2), elem_shape=(1, 10), dtype='fp32')
            return mb.list_read(ls=l, index=mb.const(val=0), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'read_state':
        @mb.program(input_specs=[mb.state_tensor_placeholder(shape=(1, 10), dtype=types.fp16)])
        def prog(s):
            return mb.read_state(input=s, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'coreml_update_state':
        @mb.program(input_specs=[mb.state_tensor_placeholder(shape=(1, 10), dtype=types.fp16), mb.TensorSpec(shape=(1, 10), dtype=types.fp16)])
        def prog(s, v):
            return mb.coreml_update_state(state=s, value=v, name='result')
        return prog, deployment_target, {}
        
    elif op_name in ['list_gather', 'list_length', 'list_read', 'list_scatter', 'list_write']:
        if op_name == 'list_length':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(x):
                l = mb.make_list(init_length=mb.const(val=2), dtype='fp32', elem_shape=(1, 10))
                length = mb.list_length(ls=l)
                length_fp = mb.cast(x=length, dtype='fp32')
                length_reshaped = mb.reshape(x=length_fp, shape=[1, 1])
                return mb.add(x=x, y=length_reshaped, name='result')
            return prog, deployment_target, {}
        elif op_name == 'list_read':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(x):
                l = mb.make_list(init_length=mb.const(val=2), dtype='fp32', elem_shape=(1, 10))
                val = mb.list_read(ls=l, index=mb.const(val=0))
                return mb.add(x=x, y=val, name='result')
            return prog, deployment_target, {}
        elif op_name == 'list_gather':
            @mb.program(input_specs=[mb.TensorSpec(shape=(2, 1, 10), dtype=types.fp32)])
            def prog(x):
                l = mb.make_list(init_length=mb.const(val=2), dtype='fp32', elem_shape=(1, 10))
                val = mb.list_gather(ls=l, indices=mb.const(val=[0, 1]))
                return mb.add(x=x, y=val, name='result')
            return prog, deployment_target, {}
        elif op_name == 'list_write':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(x):
                l = mb.make_list(init_length=mb.const(val=2), dtype='fp32', elem_shape=(1, 10))
                l_new = mb.list_write(ls=l, index=mb.const(val=0), value=x)
                return mb.list_read(ls=l_new, index=mb.const(val=0), name='result')
            return prog, deployment_target, {}
        elif op_name == 'list_scatter':
            @mb.program(input_specs=[mb.TensorSpec(shape=(2, 1, 10), dtype=types.fp32)])
            def prog(x):
                l = mb.make_list(init_length=mb.const(val=2), dtype='fp32', elem_shape=(1, 10))
                l_new = mb.list_scatter(ls=l, indices=mb.const(val=[0, 1]), value=x)
                return mb.list_read(ls=l_new, index=mb.const(val=0), name='result')
            return prog, deployment_target, {}
            
    elif op_name == 'einsum':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 2, 3), dtype=types.fp32), mb.TensorSpec(shape=(3, 2, 4), dtype=types.fp32)])
        def prog(x, y):
            return mb.einsum(values=[x, y], equation='abc,cbd->abd', name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'reshape_like':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32),
                                  mb.TensorSpec(shape=(2, 5), dtype=types.fp32)])
        def prog(x, ref):
            return mb.reshape_like(x=x, ref_tensors=(ref,),
                begins=(0,), ends=(0,), end_masks=(True,), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'lstm':
        # x: (seq_len, batch, input_size), initial_h/c: (batch, hidden_size)
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(5, 1, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
        ])
        def prog(x, h, c):
            return mb.lstm(x=x, initial_h=h, initial_c=c,
                weight_ih=mb.const(val=np.random.randn(16, 8).astype(np.float32)),
                weight_hh=mb.const(val=np.random.randn(16, 4).astype(np.float32)),
                direction='forward', name='result')
        return prog, deployment_target, {}

    elif op_name == 'gru':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(5, 1, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
        ])
        def prog(x, h):
            return mb.gru(x=x, initial_h=h,
                weight_ih=mb.const(val=np.random.randn(12, 8).astype(np.float32)),
                weight_hh=mb.const(val=np.random.randn(12, 4).astype(np.float32)),
                direction='forward', name='result')
        return prog, deployment_target, {}

    elif op_name == 'rnn':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(5, 1, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
        ])
        def prog(x, h):
            return mb.rnn(x=x, initial_h=h,
                weight_ih=mb.const(val=np.random.randn(4, 8).astype(np.float32)),
                weight_hh=mb.const(val=np.random.randn(4, 4).astype(np.float32)),
                direction='forward', name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'non_maximum_suppression':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(1, 10, 4), dtype=types.fp32), # boxes
            mb.TensorSpec(shape=(1, 10, 1), dtype=types.fp32)  # scores
        ], opset_version=ct.target.iOS17)
        def prog(boxes, scores):
            # ANE iOS 17/18 NMS: requires transposed inputs (batch, 4, num_boxes)
            # and returns only FP32 outputs (excluding int32 indices) to compile natively.
            boxes_t = mb.transpose(x=boxes, perm=[0, 2, 1])
            scores_t = mb.transpose(x=scores, perm=[0, 2, 1])
            res = mb.non_maximum_suppression(
                boxes=boxes_t,
                scores=scores_t,
                max_boxes=mb.const(val=np.int32(5)),
                iou_threshold=mb.const(val=np.float32(0.5))
            )
            out0 = mb.cast(x=res[0], dtype='fp32')
            out1 = mb.cast(x=res[1], dtype='fp32')
            return mb.identity(x=out0, name='result_0'), mb.identity(x=out1, name='result_1')
        return prog, deployment_target, {}
        
    elif 'complex_' in op_name or op_name == 'complex':
        if op_name == 'complex':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                return mb.complex_real(data=c, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_abs':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                return mb.complex_abs(x=c, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_real':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                return mb.complex_real(data=c, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_imag':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                return mb.complex_imag(data=c, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_fft':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                fft = mb.complex_fft(data=c)
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_fftn':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                fft = mb.complex_fftn(data=c)
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_ifft':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                fft = mb.complex_ifft(data=c)
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_ifftn':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                fft = mb.complex_ifftn(data=c)
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_rfft':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(x):
                fft = mb.complex_rfft(data=x)
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_rfftn':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(x):
                fft = mb.complex_rfftn(data=x)
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_irfft':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                fft = mb.complex_irfft(data=c)
                return fft
            return prog, deployment_target, {}
        elif op_name == 'complex_irfftn':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                fft = mb.complex_irfftn(data=c)
                return fft
            return prog, deployment_target, {}
        elif op_name == 'complex_shape':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
            def prog(r, i):
                c = mb.complex(real_data=r, imag_data=i)
                return mb.complex_shape(x=c, name='result')
            return prog, deployment_target, {}
        elif op_name == 'complex_stft':
            @mb.program(input_specs=[mb.TensorSpec(shape=(1, 100), dtype=types.fp32)])
            def prog(x):
                fft = mb.complex_stft(input=x, n_fft=mb.const(val=16), hop_length=mb.const(val=8))
                return mb.complex_real(data=fft, name='result')
            return prog, deployment_target, {}
            
    elif op_name == 'crop':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.crop(x=x, crop_height=[1, 1], crop_width=[1, 1], name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'crop_resize':
        # iOS17+: boxes/box_indices API; box_indices must be uint16 (cast from int32)
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)],
                    opset_version=ct.target.iOS17)
        def prog(x):
            boxes = mb.const(val=np.array([[0.1, 0.3, 0.8, 0.9]], dtype=np.float32))
            box_indices = mb.cast(x=mb.const(val=np.array([0], dtype=np.int32)), dtype='uint16')
            return mb.crop_resize(x=x, boxes=boxes, box_indices=box_indices,
                target_height=4, target_width=4,
                normalized_coordinates=True,
                box_coordinate_mode='CORNERS_HEIGHT_FIRST',
                sampling_mode='ALIGN_CORNERS',
                name='result')
        return prog, ct.target.iOS17, {}
        
    elif op_name == 'dequantize':
        # Realistic use: constant int8 weights dequantized before a matmul (iOS18 folds to constexpr)
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            w_int8 = mb.const(val=np.ones((10, 10), dtype=np.int8))
            w_fp = mb.dequantize(input=w_int8, scale=mb.const(val=np.float16(0.1)),
                                  zero_point=mb.const(val=np.int8(0)))
            return mb.matmul(x=x, y=w_fp, name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'quantize':
        # quantize+dequantize pair (fake quantization) — both iOS17+ required
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            q = mb.quantize(input=x, scale=mb.const(val=np.float16(0.1)),
                             zero_point=mb.const(val=np.int8(0)), output_dtype='int8')
            return mb.dequantize(input=q, scale=mb.const(val=np.float16(0.1)),
                                  zero_point=mb.const(val=np.int8(0)), name='result')
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'gather':
        # iOS18: constant int32 indices auto-converted to uint16, ANE-compatible
        @mb.program(input_specs=[mb.TensorSpec(shape=(100, 64), dtype=types.fp16)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            return mb.gather(x=x, indices=mb.const(val=np.array([0,10,20], dtype=np.int32)), axis=0, name='result')
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'gather_along_axis':
        # iOS18: constant int32 indices auto-converted to uint16, ANE-compatible
        @mb.program(input_specs=[mb.TensorSpec(shape=(10, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            return mb.gather_along_axis(x=x,
                indices=mb.const(val=np.array([[0,1,2,3,4,5,6,7,8,9]], dtype=np.int32)),
                axis=0, name='result')
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'scatter_along_axis':
        @mb.program(input_specs=[mb.TensorSpec(shape=(10, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 10), dtype=types.int32), mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(data, indices, updates):
            return mb.scatter_along_axis(data=data, indices=indices, updates=updates, axis=0, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'gather_nd':
        # iOS18: constant int32 indices auto-converted to uint16, ANE-compatible
        @mb.program(input_specs=[mb.TensorSpec(shape=(10, 10, 64), dtype=types.fp16)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            return mb.gather_nd(x=x, indices=mb.const(val=np.array([[[0,0],[1,1]]], dtype=np.int32)), name='result')
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'scatter_nd':
        @mb.program(input_specs=[mb.TensorSpec(shape=(10, 10), dtype=types.fp32)])
        def prog(data):
            return mb.scatter_nd(data=data, indices=mb.const(val=[[0, 0], [1, 1]]), updates=mb.const(val=[1.0, 2.0]), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'linear':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            weight = mb.const(val=np.ones((5, 10), dtype=np.float32))
            bias = mb.const(val=np.zeros(5, dtype=np.float32))
            return mb.linear(x=x, weight=weight, bias=bias, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'prelu':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.prelu(x=x, alpha=mb.const(val=np.ones(4, dtype=np.float32)), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'resample':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32), mb.TensorSpec(shape=(1, 4, 8, 2), dtype=types.fp32)])
        def prog(x, coordinates):
            return mb.resample(x=x, coordinates=coordinates, sampling_mode='bilinear', padding_mode='border', padding_value=0.0, coordinates_mode='normalized_minus_one_to_one', align_corners=True, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'resize':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.resize(
                x=x,
                shape=mb.const(val=np.array([1, 4, 16, 16], dtype=np.int32)),
                resized_dims=mb.const(val=np.uint32(2)),
                name='result'
            )
        return prog, deployment_target, {}
        
        
    elif op_name == 'quantize':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 16, 8, 8), dtype=types.fp16)])
        def prog(x):
            scale = mb.const(val=np.float16(0.1))
            zp = mb.const(val=np.int8(0))
            return mb.quantize(input=x, scale=scale, zero_point=zp, output_dtype='int8', name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'dequantize':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 16, 8, 8), dtype=types.int8)])
        def prog(x):
            scale = mb.const(val=np.float16(0.1))
            zp = mb.const(val=np.int8(0))
            return mb.dequantize(input=x, scale=scale, zero_point=zp, name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'scatter':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(10, 10), dtype=types.fp32),
            mb.TensorSpec(shape=(2,), dtype=types.int32),
            mb.TensorSpec(shape=(2, 10), dtype=types.fp32)
        ])
        def prog(data, indices, updates):
            return mb.scatter(data=data, indices=indices, updates=updates, axis=0, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'slice_by_size':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            return mb.slice_by_size(x=x, begin=[0, 0], size=[1, 5], name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'slice_by_index':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            return mb.slice_by_index(x=x, begin=[0, 0], end=[1, 5], stride=[1, 1], name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'slice_update':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32), mb.TensorSpec(shape=(1, 5), dtype=types.fp32)])
        def prog(x, update):
            return mb.slice_update(x=x, update=update, begin=[0, 0], end=[1, 5], name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'logical_and':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 16, 8, 8), dtype=types.fp32), mb.TensorSpec(shape=(1, 16, 8, 8), dtype=types.fp32)])
        def prog(x, y):
            xb = mb.cast(x=x, dtype='bool')
            yb = mb.cast(x=y, dtype='bool')
            res = mb.logical_and(x=xb, y=yb)
            return mb.cast(x=res, dtype='fp32', name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'sliding_windows':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            return mb.sliding_windows(x=x, axis=1, size=mb.const(val=2), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'softplus_parametric':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.softplus_parametric(x=x, alpha=mb.const(val=np.ones(4, dtype=np.float32)), beta=mb.const(val=np.ones(4, dtype=np.float32)), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'split':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            return mb.split(x=x, num_splits=2, axis=1, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'layer_norm':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            return mb.layer_norm(x=x, axes=[-1], gamma=mb.const(val=np.ones(10, dtype=np.float32)), beta=mb.const(val=np.zeros(10, dtype=np.float32)), epsilon=1e-5, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'classify':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 3), dtype=types.fp32)])
        def prog(probabilities):
            return mb.identity(x=probabilities, name='result')
        return prog, deployment_target, {'classifier_config': ct.ClassifierConfig(['class0', 'class1', 'class2'])}
        
    elif op_name == 'affine':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 6), dtype=types.fp32)
        ])
        def prog(x, transform_matrix):
            return mb.affine(
                x=x,
                transform_matrix=transform_matrix,
                output_height=8,
                output_width=8,
                sampling_mode='bilinear',
                padding_mode='constant',
                padding_value=0.0,
                coordinates_mode='normalized_minus_one_to_one',
                align_corners=True,
                name='result'
            )
        return prog, deployment_target, {}
        
    elif op_name == 'pad':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(8,), dtype=types.int32)
        ])
        def prog(x, pad):
            return mb.pad(x=x, pad=pad, name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'threshold':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            return mb.threshold(x=x, alpha=mb.const(val=0.0), name='result')
        return prog, deployment_target, {}
        
    elif op_name == 'constexpr_lut_to_dense':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 64), dtype=types.fp32)])
        def prog(x):
            indices = mb.const(val=np.ones((8,), dtype=np.uint8))
            lut = mb.const(val=np.ones((2,), dtype=np.float32))
            shape = mb.const(val=np.array([64], dtype=np.uint32))
            dense = mb.constexpr_lut_to_dense(indices=indices, lut=lut, shape=shape)
            return mb.add(x=x, y=dense, name='result')
        return prog, ct.target.iOS16, {}

    elif op_name == 'constexpr_sparse_to_dense':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 8), dtype=types.fp32)])
        def prog(x):
            mask = mb.const(val=np.array([255], dtype=np.uint8))
            nonzero = mb.const(val=np.ones((8,), dtype=np.float32))
            shape = mb.const(val=np.array([8], dtype=np.uint32))
            dense = mb.constexpr_sparse_to_dense(nonzero_data=nonzero, mask=mask, shape=shape)
            return mb.add(x=x, y=dense, name='result')
        return prog, ct.target.iOS16, {}
        
    elif op_name == 'constexpr_lut_to_sparse':
        @mb.program(input_specs=[], opset_version=ct.target.iOS18)
        def prog():
            mask = mb.const(val=np.array([1], dtype=types.np_uint1_dtype))
            nonzero = mb.const(val=np.array([1], dtype=types.np_uint1_dtype))
            lut = mb.const(val=np.ones((1, 2, 1), dtype=np.float32))
            output_mask, output_nonzero_data = mb.constexpr_lut_to_sparse(
                indices_mask=mask,
                indices_nonzero_data=nonzero,
                lut=lut,
            )
            return mb.constexpr_sparse_to_dense(
                nonzero_data=output_nonzero_data,
                mask=output_mask,
                name='result'
            )
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'constexpr_sparse_blockwise_shift_scale':
        @mb.program(input_specs=[], opset_version=ct.target.iOS18)
        def prog():
            mask = mb.const(val=np.array([1], dtype=types.np_uint1_dtype))
            nonzero = mb.const(val=np.array([1], dtype=np.int8))
            scale = mb.const(val=np.array([1.0], dtype=np.float32))
            offset = mb.const(val=np.array([0.0], dtype=np.float32))
            output_mask, output_nonzero_data = mb.constexpr_sparse_blockwise_shift_scale(
                data_mask=mask,
                nonzero_data=nonzero,
                scale=scale,
                offset=offset,
            )
            return mb.constexpr_sparse_to_dense(
                nonzero_data=output_nonzero_data,
                mask=output_mask,
                name='result'
            )
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'constexpr_blockwise_shift_scale':
        @mb.program(input_specs=[], opset_version=ct.target.iOS18)
        def prog():
            data = mb.const(val=np.array([1, 2, 3, 4], dtype=np.int8))
            scale = mb.const(val=np.array([1.0, 1.0, 1.0, 1.0], dtype=np.float32))
            offset = mb.const(val=np.array([0.0, 0.0, 0.0, 0.0], dtype=np.float32))
            out = mb.constexpr_blockwise_shift_scale(
                data=data,
                scale=scale,
                offset=offset
            )
            return mb.identity(x=out, name='result')
        return prog, ct.target.iOS18, {}
        
    elif op_name == 'constexpr_cast':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            cast = mb.constexpr_cast(source_val=np.ones((1, 10), dtype=np.float16), output_dtype='fp32')
            return mb.add(x=x, y=cast, name='result')
        return prog, ct.target.iOS16, {}

    elif op_name == 'topk':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 100), dtype=types.fp32)])
        def prog(x):
            # topk returns (values, indices); return only values
            values, _ = mb.topk(x=x, k=10, axis=-1)
            return mb.identity(x=values, name='result')
        return prog, deployment_target, {}

    elif op_name == 'reduce_argmax':
        # iOS18 + uint16 avoids int32 rejection by the ANE compiler
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 32, 56, 56), dtype=types.fp32)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            return mb.cast(x=mb.reduce_argmax(x=x, axis=-1, keep_dims=True, output_dtype='uint16'),
                           dtype='fp16', name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'reduce_argmin':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 32, 56, 56), dtype=types.fp32)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            return mb.cast(x=mb.reduce_argmin(x=x, axis=-1, keep_dims=True, output_dtype='uint16'),
                           dtype='fp16', name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'argsort':
        # iOS18 + fp16 input: argsort int32 output goes directly to network output
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 1001), dtype=types.fp16)],
                    opset_version=ct.target.iOS18)
        def prog(x):
            return mb.argsort(x=x, name='result')
        return prog, ct.target.iOS18, {}


    elif op_name == 'reshape':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 100), dtype=types.fp32)])
        def prog(x):
            return mb.reshape(x=x, shape=[1, 100], name='result')
        return prog, deployment_target, {}

    elif op_name == 'fill':
        # Use fill result in add so it's not a bare constant output
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS16)
        def prog(x):
            f = mb.fill(shape=[1, 10], value=0.0)
            return mb.add(x=x, y=mb.cast(x=f, dtype='fp16'), name='result')
        return prog, ct.target.iOS16, {}

    elif op_name == 'fill_like':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS16)
        def prog(x):
            f = mb.fill_like(ref_tensor=x, value=0.0)
            return mb.add(x=x, y=mb.cast(x=f, dtype='fp16'), name='result')
        return prog, ct.target.iOS16, {}

    elif op_name == 'shape':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS16)
        def prog(x):
            s = mb.shape(x=x)
            return mb.reshape(x=x, shape=s, name='result')
        return prog, ct.target.iOS16, {}

    elif op_name == 'tile':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.tile(x=x, reps=[1, 1, 2, 2], name='result')
        return prog, deployment_target, {}

    elif op_name == 'random_bernoulli':
        @mb.program(input_specs=[], opset_version=ct.target.iOS18)
        def prog():
            return mb.random_bernoulli(shape=[1, 10], prob=0.5, name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'random_normal':
        @mb.program(input_specs=[], opset_version=ct.target.iOS18)
        def prog():
            return mb.random_normal(shape=[1, 10], mean=0.0, stddev=1.0, name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'random_uniform':
        @mb.program(input_specs=[], opset_version=ct.target.iOS18)
        def prog():
            return mb.random_uniform(shape=[1, 10], low=0.0, high=1.0, name='result')
        return prog, ct.target.iOS18, {}

    elif op_name == 'batch_norm':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.batch_norm(x=x,
                mean=mb.const(val=np.zeros(4, dtype=np.float32)),
                variance=mb.const(val=np.ones(4, dtype=np.float32)),
                gamma=mb.const(val=np.ones(4, dtype=np.float32)),
                beta=mb.const(val=np.zeros(4, dtype=np.float32)),
                epsilon=1e-5, name='result')
        return prog, deployment_target, {}

    elif op_name == 'instance_norm':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.instance_norm(x=x,
                gamma=mb.const(val=np.ones(4, dtype=np.float32)),
                beta=mb.const(val=np.zeros(4, dtype=np.float32)),
                epsilon=1e-5, name='result')
        return prog, deployment_target, {}

    elif op_name == 'local_response_norm':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32)])
        def prog(x):
            return mb.local_response_norm(x=x, size=3, alpha=0.0001, beta=0.75, k=1.0, name='result')
        return prog, deployment_target, {}



    elif op_name == 'range_1d':
        # Use range result in add so it's not a bare constant output
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp16)],
                    opset_version=ct.target.iOS16)
        def prog(x):
            r = mb.range_1d(start=0.0, end=10.0, step=1.0)
            return mb.add(x=x, y=mb.cast(x=mb.reshape(x=r, shape=[1, 10]), dtype='fp16'), name='result')
        return prog, ct.target.iOS16, {}

    elif op_name == 'resample':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 4, 8, 8), dtype=types.fp32),
                                  mb.TensorSpec(shape=(1, 4, 8, 2), dtype=types.fp32)])
        def prog(x, coordinates):
            return mb.resample(x=x, coordinates=coordinates,
                sampling_mode='bilinear', padding_mode='border',
                padding_value=0.0, coordinates_mode='normalized_minus_one_to_one',
                align_corners=True, name='result')
        return prog, deployment_target, {}



    elif op_name == 'reverse_sequence':
        @mb.program(input_specs=[mb.TensorSpec(shape=(2, 10), dtype=types.fp32)])
        def prog(x):
            return mb.reverse_sequence(x=x,
                lengths=mb.const(val=np.array([10, 8], dtype=np.int32)),
                seq_axis=1, batch_axis=0, name='result')
        return prog, deployment_target, {}

    elif op_name == 'lstm':
        # x: (seq_len, batch, input_size), initial_h/c: (batch, hidden_size)
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(5, 1, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
        ])
        def prog(x, h, c):
            return mb.lstm(x=x, initial_h=h, initial_c=c,
                weight_ih=mb.const(val=np.random.randn(16, 8).astype(np.float32)),
                weight_hh=mb.const(val=np.random.randn(16, 4).astype(np.float32)),
                direction='forward', name='result')
        return prog, deployment_target, {}

    elif op_name == 'gru':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(5, 1, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
        ])
        def prog(x, h):
            return mb.gru(x=x, initial_h=h,
                weight_ih=mb.const(val=np.random.randn(12, 8).astype(np.float32)),
                weight_hh=mb.const(val=np.random.randn(12, 4).astype(np.float32)),
                direction='forward', name='result')
        return prog, deployment_target, {}

    elif op_name == 'rnn':
        @mb.program(input_specs=[
            mb.TensorSpec(shape=(5, 1, 8), dtype=types.fp32),
            mb.TensorSpec(shape=(1, 4), dtype=types.fp32),
        ])
        def prog(x, h):
            return mb.rnn(x=x, initial_h=h,
                weight_ih=mb.const(val=np.random.randn(4, 8).astype(np.float32)),
                weight_hh=mb.const(val=np.random.randn(4, 4).astype(np.float32)),
                direction='forward', name='result')
        return prog, deployment_target, {}

    elif op_name == 'l2_norm':
        # needs 4D input for ANE
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 32, 56, 56), dtype=types.fp32)])
        def prog(x):
            return mb.l2_norm(x=x, epsilon=1e-5, name='result')
        return prog, deployment_target, {}

    elif op_name == 'const':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            c = mb.const(val=np.ones((1, 10), dtype=np.float32))
            return mb.add(x=x, y=c, name='result')
        return prog, deployment_target, {}

    elif op_name == '_const_symbolic':
        @mb.program(input_specs=[mb.TensorSpec(shape=(1, 10), dtype=types.fp32)])
        def prog(x):
            c = mb._const_symbolic(val=10)
            c_cast = mb.cast(x=c, dtype='fp32')
            return mb.add(x=x, y=c_cast, name='result')
        return prog, deployment_target, {}

    elif op_name == 'one_hot':
        @mb.program(input_specs=[mb.TensorSpec(shape=(5,), dtype=types.int32)])
        def prog(indices):
            one_hot_res = mb.one_hot(indices=indices, one_hot_vector_size=10)
            return mb.identity(x=one_hot_res, name='result')
        return prog, deployment_target, {}

    elif op_name in (
        'acos', 'asin', 'atanh', 'band_part', 'complex_imag', 'complex_irfft',
        'complex_irfftn', 'complex_real', 'complex_rfft', 'complex_rfftn',
        'complex', 'cond', 'cosh', 'crop_resize', 'cumsum', 'gru', 'list_scatter',
        'list_write', 'lstm', 'logical_or', 'logical_xor', 'mod',
        'non_zero', 'random_bernoulli',
        'random_categorical', 'random_normal', 'random_uniform', 'reduce_prod',
        'resample', 'reverse_sequence', 'rnn', 'scatter_along_axis', 'scatter_nd',
        'scatter', 'sinh', 'slice_update', 'sliding_windows', 'tan', 'while_loop',
        'conv_quantized', 'constexpr_cast', 'make_list', 'list_read', 'list_gather',
        'list_length', 'reshape_like'
    ):
        # Not ANE-runnable ops — skip
        raise ValueError(f"{op_name} is not an ANE-runnable op")

    # Determine if it's a constexpr op
    is_constexpr = op_name.startswith('constexpr_')

    # General Dynamic Op Builder:
    # Try building with only required inputs first, then with all inputs
    for include_opts in [False, True]:
        input_names = []
        input_specs = []
        const_inputs = {}
        
        try:
            for name, itype in op_cls.input_spec._input_types:
                if not include_opts and itype.optional:
                    continue
                
                # Skip internal inputs
                if itype.__class__.__name__ == 'InternalInputType':
                    const_inputs[name] = np.ones((1, 10), dtype=np.float32)
                    continue
                
                if itype.const or is_constexpr:
                    # Generate constant
                    domain = getattr(itype, 'type_domain', ())
                    if len(domain) == 0 and getattr(itype, 'type_domain_id', None) is not None:
                        if hasattr(op_cls, 'type_domains') and itype.type_domain_id in op_cls.type_domains:
                            domain = op_cls.type_domains[itype.type_domain_id]

                    dtype = np.float32
                    if len(domain) > 0:
                        dtype = mil_type_to_np_dtype(domain[0])
                    
                    if name in ['axes', 'axis']:
                        const_inputs[name] = [-1] if op_name == 'layer_norm' else (0 if is_constexpr else [0])
                    elif name in ['strides', 'kernel_sizes', 'dilations', 'block_shape']:
                        const_inputs[name] = [2, 2] if (op_name == 'space_to_batch' or op_name == 'batch_to_space') else [1, 1]
                    elif name in ['pad', 'crops', 'paddings']:
                        const_inputs[name] = np.array([0, 0, 0, 0, 0, 0, 0, 0], dtype=np.int32) if op_name == 'pad' else [[0, 0], [0, 0]]
                    elif name == 'pad_type':
                        const_inputs[name] = 'valid'
                    elif name == 'epsilon':
                        const_inputs[name] = 1e-5
                    elif name in ['alpha', 'beta', 'gamma']:
                        const_inputs[name] = np.float32(1.0)
                    elif name in ['shape', 'target_size', 'reps', 'begin', 'end', 'size', 'elem_shape', 'element_shape', 'resized_dims', 'crop_height', 'crop_width']:
                        const_inputs[name] = np.array([1, 10], dtype=dtype)
                    elif name == 'indices' or name == 'indices_mask' or name == 'data_mask':
                        const_inputs[name] = np.ones((10,), dtype=dtype)
                    elif name == 'zero_point':
                        const_inputs[name] = np.array(0, dtype=dtype) if is_constexpr else np.int8(0)
                    elif name == 'scale':
                        const_inputs[name] = np.array(1.0, dtype=dtype) if is_constexpr else np.float32(1.0)
                    elif name == 'output_dtype':
                        const_inputs[name] = 'fp32' if op_name == 'constexpr_cast' else 'int8'
                    else:
                        val = make_mock_const(name, itype, op_name, op_cls)
                        if isinstance(val, np.ndarray):
                            const_inputs[name] = val.astype(dtype)
                        elif isinstance(val, (int, float, bool)):
                            const_inputs[name] = np.array(val, dtype=dtype)
                        else:
                            const_inputs[name] = val
                else:
                    # Non-const input
                    is_spatial = any(s in op_name for s in ['conv', 'pool', 'pad', 'pixel', 'space', 'depth', 'upsample', 'resize', 'crop'])
                    is_recurrent = any(s in op_name for s in ['lstm', 'gru', 'rnn'])
                    
                    shape = (1, 10)
                    if op_name == 'affine':
                        shape = (1, 4, 8, 8)
                    elif op_name == 'batch_to_space':
                        shape = (4, 4, 8, 8)
                    elif is_spatial:
                        if name in ['roi']:
                            shape = (1, 4)
                        else:
                            shape = (1, 4, 8, 8)
                    elif is_recurrent:
                        shape = (1, 5, 10)
                    
                    if op_name == 'matmul':
                        if name == 'x': shape = (1, 10)
                        elif name == 'y': shape = (10, 10)
                    elif op_name == 'einsum':
                        shape = (10, 10)
                    elif op_name in ['concat', 'stack']:
                        continue
                    elif op_name == 'layer_norm':
                        if name == 'x': shape = (1, 10)
                        elif name in ['gamma', 'beta']:
                            const_inputs[name] = np.ones(10, dtype=np.float32)
                            continue
                    elif op_name == 'prelu':
                        if name == 'x': shape = (1, 4, 8, 8)
                        elif name == 'alpha': shape = (4,)
                    elif op_name == 'l2_norm':
                        shape = (1, 10, 10)
                    elif op_name == 'resample':
                        shape = (1, 4, 8, 8)
                    elif op_name == 'scaled_dot_product_attention':
                        shape = (1, 5, 10)
                    elif op_name == 'softplus_parametric':
                        shape = (1, 4, 8, 8)
                    elif op_name == 'sigmoid_hard':
                        shape = (1, 1001)
                    
                    domain = getattr(itype, 'type_domain', ())
                    if len(domain) == 0 and getattr(itype, 'type_domain_id', None) is not None:
                        if hasattr(op_cls, 'type_domains') and itype.type_domain_id in op_cls.type_domains:
                            domain = op_cls.type_domains[itype.type_domain_id]

                    dtype = types.fp32
                    if len(domain) > 0:
                        if any(types.is_float(td) for td in domain):
                            dtype = types.fp32
                        else:
                            dtype = domain[0]

                    if name == 'weight' and is_spatial:
                        if op_name == 'conv_quantized':
                            const_inputs[name] = np.ones((4, 4, 3, 3), dtype=np.uint8)
                        else:
                            const_inputs[name] = np.ones((4, 4, 3, 3), dtype=np.float32)
                        continue
                    
                    input_names.append(name)
                    input_specs.append(mb.TensorSpec(shape=shape, dtype=dtype))
            
            if op_name in ['concat', 'stack']:
                @mb.program(input_specs=[mb.TensorSpec(shape=(1, 5), dtype=types.fp32), mb.TensorSpec(shape=(1, 5), dtype=types.fp32)])
                def prog(x, y):
                    op_func = getattr(mb, op_name)
                    return op_func(values=[x, y], axis=0, name='result')
                return prog, deployment_target, {}

            prog_fn = make_prog_function(input_names, const_inputs, op_name)
            prog = mb.program(input_specs=input_specs, opset_version=deployment_target)(prog_fn)
            return prog, deployment_target, {}
        except Exception as e:
            last_err = e
            continue
            
    raise last_err

def create_op_model(op_name, models_dir='test_models'):
    """Create and compile a single op model, then save it to the output directory."""
    op_cls = get_op_class(op_name)
    if op_cls is None:
        raise ValueError(f"Operation '{op_name}' not found in SSAOpRegistry.")

    res = build_program(op_name, op_cls)
    prog, target, convert_kwargs = res

    # Add FP16 compute precision for ANE optimization
    convert_kwargs['compute_precision'] = ct.precision.FLOAT16
    convert_kwargs['compute_units'] = ct.ComputeUnit.ALL

    model = ct.convert(prog, minimum_deployment_target=target, **convert_kwargs)

    os.makedirs(models_dir, exist_ok=True)
    output_path = os.path.join(models_dir, f'test_{op_name}.mlpackage')
    model.save(output_path)
    return output_path

def main():
    # Load all ops from registries
    all_ops = {}
    all_ops.update(SSAOpRegistry.core_ops)
    all_ops.update(SSAOpRegistry.custom_ops)
    all_ops.update(SSAOpRegistry.dialect_ops)


    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 test_single_op_full.py <op_name>   - Compile a specific operation")
        print("  python3 test_single_op_full.py --all       - Test and compile all operations")
        print("  python3 test_single_op_full.py --list      - List all supported operations")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == '--list':
        print(f"Supported Operations ({len(all_ops)}):")
        for op in sorted(all_ops.keys()):
            print(f"  {op}")
        sys.exit(0)

    elif cmd == '--all':
        print(f"Testing all {len(all_ops)} operations from SSAOpRegistry...")
        success = []
        failed = []

        # Dialect ops are internal-only (TF/Torch intermediate) and cannot be converted to CoreML
        # We manually support/override some of them (complex functions and state functions)
        all_dialect_keys = set(SSAOpRegistry.dialect_ops.keys())
        supported_dialect_ops = {
            'complex_abs', 'complex_fft', 'complex_fftn',
            'complex_ifft', 'complex_ifftn', 'complex_stft',
            'coreml_update_state'
        }
        dialect_ops = (all_dialect_keys - supported_dialect_ops) | {
            'tf_lstm_block', 'tf_lstm_block_cell', 'tf_make_list',
            'torch_tensor_assign', 'torch_upsample_bilinear', 'torch_upsample_nearest_neighbor',
            'complex_shape', 'conv_quantized', 'constexpr_cast',
            'make_list', 'list_read', 'list_gather', 'list_length', 'reshape_like'
        }

        # Operations not supported on ANE
        unsupported_ops = {
            'acos', 'asin', 'atanh', 'band_part', 'cosh', 'cumsum',
            'gru', 'list_scatter', 'list_write', 'lstm', 'logical_or',
            'logical_xor', 'mod', 'non_zero', 'one_hot',
            'random_bernoulli', 'random_categorical', 'random_normal', 'random_uniform',
            'reduce_prod', 'resample', 'reverse_sequence', 'rnn', 'scatter_along_axis',
            'scatter_nd', 'scatter', 'sinh', 'slice_update', 'sliding_windows',
            'tan', 'while_loop'
        }

        for op_name in sorted(all_ops.keys()):
            if op_name in dialect_ops:
                print(f"⚠ {op_name} skipped (dialect op, internal-only)")
                continue
            if op_name in unsupported_ops:
                print(f"⚠ {op_name} skipped (unsupported op)")
                continue
            try:
                out_path = create_op_model(op_name)
                success.append(op_name)
                print(f"✓ {op_name} compiled successfully! Saved to: {out_path}")
            except Exception as e:
                err_str = "".join(traceback.format_exception_only(type(e), e)).strip()
                failed.append((op_name, err_str))
                print(f"✗ {op_name} failed: {err_str}")

        print("\n" + "="*80)
        print("COMPILATION SUMMARY")
        print("="*80)
        print(f"Total ops tested: {len(all_ops)}")
        print(f"✓ Succeeded: {len(success)}")
        print(f"✗ Failed: {len(failed)}")
        print("="*80)
        
        if failed:
            print("\nFailed ops details:")
            for op, err in failed:
                print(f"  - {op}: {err}")
        sys.exit(0 if not failed else 1)

    else:
        op_name = cmd
        try:
            out_path = create_op_model(op_name)
            print(f"✓ {op_name} compiled successfully! Saved to: {out_path}")
        except Exception as e:
            print(f"✗ {op_name} failed to compile.")
            traceback.print_exc()
            sys.exit(1)

if __name__ == '__main__':
    main()
