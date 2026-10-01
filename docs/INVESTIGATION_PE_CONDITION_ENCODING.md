# Investigation: validating `get_pe_condition_name_v17`'s raw-bits→name table

**Status: unapplied.** No code or doc changes have been made yet — this is
a writeup of the reasoning chain for review before deciding whether to
apply it. Binary: `ANECompiler` (arm64e slice) from the dyld shared cache,
extracted at `~/work/ios-hacking/disassm/extracted/System/Library/
PrivateFrameworks/ANECompiler.framework/Versions/A/ANECompiler`.

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

## Confidence summary

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
