# Investigation: validating `get_pe_condition_name_v17`'s raw-bits→name table

**Status: applied and empirically confirmed.** The corrected table below
(Steps 1-4, derived via binary disassembly) has been wired into
`hwx_dump/hwx_parsing.m`/`.py`/`hwx_dump_js/hwx_parser.js`'s
`get_pe_condition_name_v17`/`condNames`, and every one of its 8 entries
has since been directly confirmed by compiling real MIL ops to HWX on
real Apple Silicon hardware (Step 5) — not just inferred from
disassembly. Binary used for Steps 1-4: `ANECompiler` (arm64e slice)
from the dyld shared cache, extracted at `~/work/ios-hacking/disassm/
extracted/System/Library/PrivateFrameworks/ANECompiler.framework/
Versions/A/ANECompiler`.

## The question

`hwx_dump/hwx_parsing.m`/`.py` have a function `get_pe_condition_name_v17`
with a hardcoded 8-entry table mapping the PE Config register's `cond`
field (bits `[8:6]`, raw values 0-7) to names:

```
0:None 1:Abs 2:Equal 3:Greater 4:GreaterEqual 5:LessEqual 6:Less 7:NotEqual
```

It's dead code (defined, never called) in both `.m` and `.py` — the real
`PE Config` printf shows `cond` as a raw integer. The user asked to
validate this table against the ANECompiler binary (ground truth) and,
if correct, wire the function into the actual print statements instead
of showing the raw int.

## Step 1: `SetPECondition` proves raw bits ≠ enum value

The function that actually *writes* this field,
`ZinAneTd<17>::SetPECondition(ZinHWPECondition)` (symbol
`__ZN8ZinAneTdILj17EE14SetPEConditionE16ZinHWPECondition`, address
`0x20bcded38`), disassembled via:

```
otool -arch arm64e -tV ANECompiler
```

is a `cmp`/`b.gt` ladder dispatching on its `ZinHWPECondition` parameter
(`w1`), each case doing `ldr w8,[x0,#0x454]` (the H16 PE Config word),
then either `and`-clearing bits `[8:6]` (`#0xfffffe3f`) and `orr`-ing in a
specific pattern, or (for enum value 5) a `bfi w8,w9,#6,#3` inserting the
literal value 5. Reading off every case gives an exact, unambiguous
enum→raw-bits table:

| `ZinHWPECondition` enum value | raw bits written to `[8:6]` |
|---|---|
| 0 | 0 |
| 1 | 7 |
| 2 | 4 |
| 3 | 6 |
| 4 | 2 |
| 5 | 5 |
| 6 | 1 |
| 7 | 3 |

This is a non-identity permutation. **This alone disproves the existing
table's premise** that raw bits can be indexed directly by a "natural"
condition ordering — whatever that ordering is, the hardware scrambles it.

Confirmed stable across generations: `ZinAneTd<19>::SetPECondition`
(H17, address `0x20bce42d0`) has byte-for-byte identical dispatch logic,
just a different field offset (`[x0,#0x46c]` instead of `[x0,#0x454]`,
consistent with H17's PE block living at a different context offset).

## Step 2: `PredicateOp`'s names are ground truth, not guesswork

A *different* enum, `ZinConditionLayerUtils::PredicateOp`, has its exact
names in the binary as literal debug strings, in
`ZinConditionLayerUtils::DumpTDBranchingInfo(PredicateOp, ...)`
(address `0x20acd6810`). Walking its `cmp`/`b.eq` chain and following each
branch to its `adrp`/`add` string-literal load gives:

| `PredicateOp` value | string literal |
|---|---|
| 1 | `" < "` (Less) |
| 2 | `" >= "` (GreaterEqual) |
| 3 | `" > "` (Greater) |
| 4 | `" <= "` (LessEqual) |
| 5 | `" == "` (Equal) |
| 6 | `" != "` (NotEqual) |
| 11 | `" Always"` (branch utility, not a comparison) |
| 12 | `" Never"` (branch utility, not a comparison) |

Value 7 is accepted as valid by a sibling function,
`ZinConditionLayerUtils::IsValidSneConditionOp(PredicateOp)` (address
`0x20acd63e8`, valid range `[1,7]`), but has no entry in
`DumpTDBranchingInfo` — it falls through to the "Error: Unsupported td
branching op to dump" assert path. This is consistent with (not proof of)
it being a non-binary-comparison predicate like `Abs`.

Cross-check: `ZinConditionLayerUtils::ReversePredicateOpDirection(PredicateOp)`
(address `0x20acd66f8`) is a jump table that, decoded, gives an exact
involution: `{1,3}` pair with each other, `{2,4}` pair with each other,
`{5}` and `{6}` are self-paired (fixed points). This exactly matches
`{Less,Greater}` being direction-reversible, `{GreaterEqual,LessEqual}`
being direction-reversible, and `{Equal,NotEqual}` being symmetric under
operand swap — i.e. the table above is internally self-consistent, not
just independently plausible.

**But `PredicateOp` is a different C++ type from `ZinHWPECondition`.**
Nothing so far connects the two numberings.

## Step 3: bridging `PredicateOp` to `ZinHWPECondition` via a shared input domain

All 5 real callers of `SetPECondition<17>` in the binary are inside
`PECodegenUtils::HandlePEGOCLayer<17>` and
`PECodegenUtils::HandlePECommonPostOps<17>` (verified via
`grep -n "bl.*SetPECondition" /tmp/anecompiler_full.txt` then walking
backward to the nearest preceding `^__Z` symbol for each call site). None
of them are in the `ZinSNEConditionOperation`/`ZinSNEConditionLayer` code
path that actually carries `PredicateOp` — so there's no direct call
chain from `PredicateOp` to `SetPECondition` visible in this binary.

However, both call sites share this exact shape:

```
ldr  w8, [x0, #0x80]       ; read some op-type field
sub  w8, w8, #0x19         ; normalize: valid range becomes [0,6]
cmp  w8, #0x6
b.hs <out-of-range>
adrp x9, ...                ; table base 0x20c502e5c
add  x9, x9, #0xe5c
ldr  w1, [x9, w8, uxtw #2]  ; table[w8] -> ZinHWPECondition enum value
bl   SetPECondition
```

i.e. the field at `[x0,#0x80]` (some op-type enum, raw values 25-31) is
looked up in a 7-entry table at `0x20c502e5c` to get the
`ZinHWPECondition` enum value. Dumping that table
(`otool -arch arm64e -s __TEXT __const ANECompiler`, bytes at
`0x20c502e5c`-`0x20c502e78`) gives, for op values 25,26,27,28,29,30,31
respectively:

```
enum values: [2, 7, 6, 5, 3, 4, 2]
```

Separately, `ZinConditionLayerUtils::ConvertNonLinearModeToPredicateOp
(ZinIrNonLinearMode, bool reverse)` (address `0x20acd6784`) dispatches on
the *exact same numeric range* — `ZinIrNonLinearMode` values 25
(`0x19`) through 30 (`0x1e`) — and converts to `PredicateOp`. Decoding its
branch tree:

| mode | `reverse=false` | `reverse=true` |
|---|---|---|
| 25 | 5 (Equal) | 5 (Equal) — unconditional, `reverse` unused for this case |
| 26 | 6 (NotEqual) | 6 (NotEqual) — unconditional |
| 27 | 7 | 1 (Less) |
| 28 | 10 | 4 (LessEqual) |
| 29 | 8 | 2 (GreaterEqual) |
| 30 | 9 | 3 (Greater) |

**The anchor**: modes 25 and 26 give the *same* `PredicateOp` result
regardless of `reverse` — i.e. this is not a hypothesis-dependent data
point. And those same two modes (25, 26) are exactly where the GOC table
gives enum values 2 and 7. Two independent enums, fed the same literal
input value, both landing on a result for the same real-world semantic
concept (`Equal`/`NotEqual`), with no `reverse`-flag ambiguity — this is
about as strong a correlation as reverse engineering without source gets.

That gives, directly:

```
ZinHWPECondition enum 2 = Equal       (from mode 25, unconditional)
ZinHWPECondition enum 7 = NotEqual    (from mode 26, unconditional)
```

For modes 27-30, taking the `reverse=true` column (the one that lands on
named, in-range `PredicateOp` values 1-4 rather than the unnamed
8/9/10/7-again) produces a complete, consistent extension:

```
ZinHWPECondition enum 6 = Less        (mode 27, reverse=true -> PredicateOp 1)
ZinHWPECondition enum 5 = LessEqual   (mode 28, reverse=true -> PredicateOp 4)
ZinHWPECondition enum 3 = GreaterEqual(mode 29, reverse=true -> PredicateOp 2)
ZinHWPECondition enum 4 = Greater     (mode 30, reverse=true -> PredicateOp 3)
```

That accounts for 6 of 8 `ZinHWPECondition` values (2,3,4,5,6,7). The
remaining two (`0`, `1`) are unaccounted for by any `NonLinearMode` in
this converter's range. By elimination against the known 8-name set
(`None, Abs, Equal, Greater, GreaterEqual, LessEqual, Less, NotEqual`),
only `None` and `Abs` are left:

```
ZinHWPECondition enum 0 = None   (also the function's literal default/
                                   invalid-input fallback in every
                                   SetPECondition variant -- "and"-clear
                                   with no "orr", the natural "no
                                   condition" encoding)
ZinHWPECondition enum 1 = Abs    (by elimination only -- no positive
                                   evidence found)
```

## Step 4: apply the Step-1 permutation to get raw bits

Combining the enum→name table above with the Step 1 enum→raw-bits
permutation (`0→0, 1→7, 2→4, 3→6, 4→2, 5→5, 6→1, 7→3`):

| raw bits `[8:6]` | name | how derived |
|---|---|---|
| 0 | **None** | enum 0 → raw 0; default/clear-only case |
| 1 | **Less** | enum 6 → raw 1 |
| 2 | **Greater** | enum 4 → raw 2 |
| 3 | **NotEqual** | enum 7 → raw 3; *unconditional anchor* |
| 4 | **Equal** | enum 2 → raw 4; *unconditional anchor* |
| 5 | **LessEqual** | enum 5 → raw 5 |
| 6 | **GreaterEqual** | enum 3 → raw 6 |
| 7 | **Abs** | enum 1 → raw 7; *elimination only* |

A complete bijection (each of the 8 names used exactly once). Compared to
the existing hardcoded table (`0:None 1:Abs 2:Equal 3:Greater
4:GreaterEqual 5:LessEqual 6:Less 7:NotEqual`), only slots `0` (`None`)
and `5` (`LessEqual`, a coincidental fixed point of the raw-bit
permutation) agree. The other six are different.

## Confidence summary (superseded by Step 5 below -- kept for history)

At the time this was written (before compiling real MIL ops), confidence
varied per entry:

- **Highest** (unconditional, reverse-flag-independent anchor): raw 3 =
  `NotEqual`, raw 4 = `Equal`.
- **High** (depends on the `reverse=true` branch being the one that
  corresponds to the GOC table, which is strongly supported by producing
  a complete, self-consistent bijection with no leftover ambiguity, but
  isn't independently anchored the way `Equal`/`NotEqual` are): raw 1 =
  `Less`, raw 2 = `Greater`, raw 5 = `LessEqual`, raw 6 = `GreaterEqual`.
  Also: raw 0 = `None`, well-supported structurally (every
  `SetPECondition` variant's "default" case is a bare clear with no set
  bits).
- **Medium** (pure elimination, no direct positive evidence): raw 7 =
  `Abs`.

**All 8 entries are now empirically confirmed** (see Step 5) by compiling
the actual named MIL op and reading back the real compiled register
value -- the disassembly-based derivation above turned out to be exactly
correct in every slot.

## What would raise confidence further (not done)

- Finding an actual `PredicateOp → ZinHWPECondition` converter function
  (if the `ZinSNEConditionOperation`/`ZinSNEConditionLayer` path reaches
  the PE at all in this binary -- not established either way).
- Finding what `ZinIrNonLinearMode` values 28/29/30 produce under
  `reverse=false` (8, 9, 10) actually mean, to rule out an alternate
  reading where those -- not the `reverse=true` values -- are the ones
  that correspond to the GOC table.
- A real decompiler (Hopper/Ghidra) resolving the object type behind the
  three `blraa` virtual calls preceding the `[x0,#0x80]` read in
  `HandlePEGOCLayer`/`HandlePECommonPostOps`, to confirm what enum that
  field actually is by name rather than by inferred numeric range.

## Step 5: empirical confirmation -- compiling real MIL ops on real hardware

This repo has `mil_to_hwx` (wraps ANECompiler directly, see `mil/README.md`)
and `test_single_op_full.py` (generates a single-op `.mlpackage` via MIL
Builder for any op in `SSAOpRegistry`). Run on the actual Apple Silicon
machine this session has access to (M4 Pro, i.e. H16), these let us
*directly compile* a real MIL op and inspect the real resulting
`PE_Config` register -- no disassembly inference needed at all. Pipeline:

```
python3 test_single_op_full.py <op>
xcrun coremlcompiler compile test_models/test_<op>.mlpackage /tmp/
./mil_to_hwx -a h16 test_<op>
python3 hwx_dump/hwx_parsing.py -r /tmp/hwx_output/test_<op>_h16/model.hwx
```

Results (raw `PE_Config` word and the `cond` field it decodes to):

| MIL op | raw `PE_Config` | raw `cond` (bits `[8:6]`) | name shown |
|---|---|---|---|
| `greater` | `0x000c0080` | 2 | Greater |
| `less` | `0x000c0040` | 1 | Less |
| `greater_equal` | `0x000c0180` | 6 | GreaterEqual |
| `less_equal` | `0x000c0140` | 5 | LessEqual |
| `equal` | `0x000c0100` | 4 | Equal |
| `not_equal` | `0x000c00c0` | 3 | NotEqual |
| `abs` | `0x000001c0` | 7 | Abs |

**Every single value in the derived table (0-7) is now directly
confirmed** -- `0` (`None`) was already observed in every other real
`.hwx` sample in this repo (any PE task with no active condition), and
`1` through `7` are now each confirmed by compiling the exact MIL op
that name describes and reading back the exact raw bits the real
ANECompiler produced. This upgrades every entry from "derived via
disassembly, highest/high/medium confidence" (Steps 1-4 above) to
"empirically confirmed by direct hardware compilation." The
disassembly-based derivation in Steps 1-4 turned out to be 100% correct
in all 8 slots.

(`maximum`/`minimum` were also tested as a sanity check and correctly
show `Cond=0 (None)` with `Op=2 (Max)`/`Op=3 (Min)` instead -- confirming
the PE's `cond` mechanism is specific to true comparison/`abs` ops, not
triggered generically by any binary op.)

## Step 6: follow-up attempt on the PE's `nl` field -- negative result

The same PE Config register has a neighboring `nl` field (bits `[13:12]`,
decoded by the still-dead `get_pe_nl_mode_name_v17`) with a plausible
guessed table (`0:None 1:ReLU 2:Clamp 3:Abs`). Tried to confirm it the
same way `cond` was confirmed, in three escalating steps:

1. Single standalone activation MIL ops (`relu`, `clip`, `relu6`, `abs`,
   `leaky_relu`, `clamped_relu`) via `test_single_op_full.py` -- none of
   these even produced a PE task in the compiled `.hwx` (activation
   folded elsewhere, e.g. L2's `EnRelu` bit for standalone `relu`).
2. Hand-built conv+activation fusion models (`test_conv_activations.py`:
   conv followed directly by each of the six activations above) -- PE
   tasks appeared, but `nl` read `0` in every one, and so did the
   *other* plausible candidate field, `Common.MacCfg`'s `relu_type`.
3. Two real production ResNet50 `.hwx` compiles already in this repo
   (`resnet50_fp16_m4/`, `resnet50_quant_m4/` -- FP16 and INT8-quantized)
   -- grepping every `PE Config` line across both: `nl` reads `0` in all
   17 (FP16) and all 18 (INT8) occurrences. ResNet50 unambiguously *does*
   fuse ReLU after its convolutions, but that fusion shows up in a
   different, already-named, already-wired field instead: the **NE
   block's own** `nl_mode_ne` (`NLMode=1` on 69/123 FP16 conv tasks, 43/95
   INT8 conv tasks -- not the PE block at all), and fused elementwise+ReLU
   (residual add + ReLU) is carried by `Common.MacCfg`'s `task_type`
   (`EW w/ Reduction w/ ReLU`, etc.) instead.

**Conclusion: the PE's `nl` field is not reached by any of the common
fusion patterns tried, including a full real-world CNN.** This is a
genuine negative result, not just "not yet tested enough" -- three
independent methodologies (isolated ops, hand-built fusions, real
production model) all agree it stays `0`. `get_pe_nl_mode_name_v17`
(and the untouched `src1`/`src2` siblings) remain dead code, left as
the pre-existing guessed table, pending a real graph that actually
exercises this specific field -- possibly something outside standard
CNN activation fusion entirely (e.g. the TD-branching/conditional-layer
machinery that `cond`'s own derivation chain passed through in Step 2
above).
