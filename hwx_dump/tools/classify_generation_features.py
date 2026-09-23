#!/usr/bin/env python3
"""Classify ZinAneTd<Nu>::Set* feature-toggle setters in ANECompiler as
STUB (unconditionally rejected via ZinAssertImpl) or REAL (writes a bit/field)
per ISA version, to determine which ANE generation first added each feature.

Usage:
    python3 classify_generation_features.py [/path/to/ANECompiler]

Writes hwx_dump/feature_support.csv next to this script's repo, and prints
a markdown table to stdout.
"""
import bisect
import csv
import os
import re
import subprocess
import sys
import tempfile

DEFAULT_BINARY = (
    "/Users/freedom/work/ios-hacking/disassm/extracted/System/Library/"
    "PrivateFrameworks/ANECompiler.framework/Versions/A/ANECompiler"
)

# ISA version -> chip codename, from hwx_dump/README.md's SoC Architecture
# Reference Table. Order here is CHRONOLOGICAL release order (not numeric
# ISA version order -- H15 (v8) shipped after H14 (v11), so version numbers
# are not monotonic with release date).
CHIP_ORDER = [
    (5, "H11"),
    (6, "H12"),
    (7, "H13"),
    (11, "H14"),
    (8, "H15"),
    (17, "H16"),
    (19, "H17"),
    (20, "H18"),
    (24, "H19"),
]
KNOWN_VERSIONS = {v for v, _ in CHIP_ORDER}

# Feature-toggle setters worth checking: plain bool toggles, plus anything
# whose name suggests a hardware capability gate even if not a bare bool.
KEYWORD_RE = re.compile(
    r"Winograd|Int8|Sparse|Palett|Quant|Gather|Texture|Reswizzle|Isolation|"
    r"CircularBuffer|DetectZero|Asym|Compress|Reduction|Broadcast|"
    r"DoubleRate|DoubleMac|FatTile|Interleave",
    re.IGNORECASE,
)

SETTER_RE = re.compile(
    r"^(?P<addr>[0-9a-f]+)\s+\w+\s+"
    r"ZinAneTd<(?P<ver>\d+)u>::(?P<name>Set\w+)\((?P<sig>[^)]*)\)"
)


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout


def load_symbols(binary):
    """Return (candidates, all_addrs_sorted) where candidates maps
    method_name -> {version: addr}."""
    raw = run(["nm", "-a", binary])
    demangled = subprocess.run(
        ["c++filt"], input=raw, capture_output=True, text=True, check=True
    ).stdout

    all_addrs = []
    candidates = {}
    for line in demangled.splitlines():
        if ".cold" in line:
            continue
        m = SETTER_RE.match(line)
        if not m:
            # still collect address for function-extent bounds if it's any
            # kind of text symbol
            parts = line.split(None, 2)
            if parts and re.match(r"^[0-9a-f]+$", parts[0]):
                all_addrs.append(int(parts[0], 16))
            continue
        addr = int(m["addr"], 16)
        all_addrs.append(addr)
        ver = int(m["ver"])
        name = m["name"]
        sig = m["sig"].strip()
        if sig == "bool" or KEYWORD_RE.search(name):
            candidates.setdefault(name, {})[ver] = addr

    all_addrs = sorted(set(all_addrs))
    return candidates, all_addrs


def function_bounds(addr, all_addrs):
    i = bisect.bisect_right(all_addrs, addr)
    end = all_addrs[i] if i < len(all_addrs) else addr + 0x200
    return addr, end


def disasm_range(binary, start, end):
    out = subprocess.run(
        [
            "xcrun",
            "llvm-objdump",
            "-d",
            f"--start-address=0x{start:x}",
            f"--stop-address=0x{end:x}",
            "--triple=arm64e",
            binary,
        ],
        capture_output=True,
        text=True,
    ).stdout
    return out


ASSERT_RE = re.compile(r"\bbl\b.*ZinAssertImpl")
STORE_RE = re.compile(r"\b(str|stur|strb|strh)\b")
ADRP_RE = re.compile(r"adrp\s+x\d+,\s*(0x[0-9a-f]+)")
ADD_LITERAL_RE = re.compile(r"add\s+x\d+,\s*x\d+,\s*#(0x[0-9a-f]+)")


INSN_RE = re.compile(r"^\s*[0-9a-f]+:\s+[0-9a-f]+\s+\t?(\w+)", re.MULTILINE)


def classify(disasm_text):
    has_assert = bool(ASSERT_RE.search(disasm_text))
    has_store = bool(STORE_RE.search(disasm_text))
    if has_store:
        return "REAL"
    if has_assert:
        return "STUB"
    # No store, no assert: check whether the body is a trivial bare-`ret`
    # stub (ICF-folded across many unrelated empty functions in this
    # binary) vs. something else (e.g. delegates to another setter via
    # `bl`, or genuinely unclear).
    mnemonics = [m.group(1) for m in INSN_RE.finditer(disasm_text)]
    body = [m for m in mnemonics if m not in ("pacibsp", "retab")]
    if body == ["ret"] or (len(body) <= 2 and "ret" in body and "bl" not in body):
        return "NOOP"
    if "bl" in mnemonics or "b" in mnemonics:
        return "DELEGATES"
    return "UNCLEAR"


def resolve_assert_string(binary, disasm_text):
    """Best-effort: find adrp/add pair feeding the assert call and read the
    C string at that computed address directly from the file."""
    lines = disasm_text.splitlines()
    base = None
    for line in lines:
        m = ADRP_RE.search(line)
        if m:
            base = int(m.group(1), 16)
            continue
        m = ADD_LITERAL_RE.search(line)
        if m and base is not None:
            addr = base + int(m.group(1), 16)
            s = read_cstring_at_vmaddr(binary, addr)
            if s:
                return s
            base = None
    return ""


_SECTIONS_CACHE = {}


def _load_sections(binary):
    if binary in _SECTIONS_CACHE:
        return _SECTIONS_CACHE[binary]
    out = run(["otool", "-l", binary])
    sections = []
    cur = {}
    for line in out.splitlines():
        line = line.strip()
        if line == "Section":
            if cur:
                sections.append(cur)
            cur = {}
        elif line.startswith("addr "):
            cur["addr"] = int(line.split()[1], 16)
        elif line.startswith("size "):
            cur["size"] = int(line.split()[1], 16)
        elif line.startswith("offset "):
            try:
                cur["offset"] = int(line.split()[1])
            except ValueError:
                pass
    if cur:
        sections.append(cur)
    sections = [s for s in sections if "addr" in s and "offset" in s and "size" in s]
    _SECTIONS_CACHE[binary] = sections
    return sections


def read_cstring_at_vmaddr(binary, vmaddr):
    for s in _load_sections(binary):
        if s["addr"] <= vmaddr < s["addr"] + s["size"]:
            fileoff = s["offset"] + (vmaddr - s["addr"])
            with open(binary, "rb") as f:
                f.seek(fileoff)
                data = f.read(256)
            end = data.find(b"\x00")
            if end == -1:
                end = len(data)
            try:
                return data[:end].decode("utf-8", errors="replace")
            except Exception:
                return ""
    return ""


def main():
    binary = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_BINARY
    if not os.path.exists(binary):
        print(f"error: binary not found: {binary}", file=sys.stderr)
        sys.exit(1)

    candidates, all_addrs = load_symbols(binary)
    print(f"# {len(candidates)} candidate setter(s) found", file=sys.stderr)

    rows = []
    for name in sorted(candidates):
        by_ver = candidates[name]
        status_by_chip = {}
        evidence_by_chip = {}
        for ver, chip in CHIP_ORDER:
            addr = by_ver.get(ver)
            if addr is None:
                status_by_chip[chip] = "n/a"
                continue
            start, end = function_bounds(addr, all_addrs)
            disasm = disasm_range(binary, start, end)
            status = classify(disasm)
            status_by_chip[chip] = status
            if status == "STUB":
                evidence_by_chip[chip] = resolve_assert_string(binary, disasm)
            else:
                evidence_by_chip[chip] = f"addr=0x{addr:x}"

        first_real_chip = ""
        first_real_ver = ""
        for ver, chip in CHIP_ORDER:
            if status_by_chip.get(chip) == "REAL":
                first_real_chip = chip
                first_real_ver = ver
                break

        never_real = all(
            status_by_chip.get(chip) in ("STUB", "n/a") for _, chip in CHIP_ORDER
        )

        extra_versions = sorted(v for v in by_ver if v not in KNOWN_VERSIONS)

        rows.append(
            {
                "feature": name[3:],  # strip "Set"
                "setter": name,
                "first_chip": first_real_chip or ("never (through H19)" if never_real else ""),
                "first_isa_version": first_real_ver,
                "status_by_chip": status_by_chip,
                "evidence": evidence_by_chip,
                "unmapped_isa_versions_seen": extra_versions,
            }
        )

    out_csv = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "feature_support.csv",
    )
    chip_names = [chip for _, chip in CHIP_ORDER]
    with open(out_csv, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(
            ["feature", "setter", "first_chip", "first_isa_version"]
            + chip_names
            + ["unmapped_isa_versions_seen", "evidence_at_first_real"]
        )
        for r in rows:
            evidence_first = r["evidence"].get(r["first_chip"], "")
            w.writerow(
                [
                    r["feature"],
                    r["setter"],
                    r["first_chip"],
                    r["first_isa_version"],
                ]
                + [r["status_by_chip"].get(c, "") for c in chip_names]
                + [
                    ";".join(str(v) for v in r["unmapped_isa_versions_seen"]),
                    evidence_first,
                ]
            )
    print(f"wrote {out_csv}", file=sys.stderr)

    print("| Feature | First Real | Chip Status (" + ", ".join(chip_names) + ") |")
    print("| :--- | :--- | :--- |")
    for r in rows:
        status_str = " / ".join(r["status_by_chip"].get(c, "-") for c in chip_names)
        print(f"| {r['feature']} | {r['first_chip']} | {status_str} |")


if __name__ == "__main__":
    main()
