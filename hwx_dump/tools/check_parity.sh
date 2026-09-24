#!/usr/bin/env bash
# Regression check: hwx_parsing.py must decode the same dimensions as
# hwx_parsing.m for every task in every sample .hwx file.
#
# This intentionally only compares the numeric InDim/OutDim (W/H/C/D)
# fields, not full textual output -- the two files use different naming
# conventions for format/type labels (e.g. "fp16" vs "FLOAT16") that are
# tracked separately and aren't what this check is for. What this check
# *does* catch: silent divergence in dimension-recovery logic like the
# missing recover_dimensions_from_l2_cache() port (fixed 2026-09).
#
# Usage:
#   hwx_dump/tools/check_parity.sh [dir ...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HWX_DUMP_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$HWX_DUMP_DIR")"

PARSER_M="$HWX_DUMP_DIR/hwx_parsing"
PARSER_PY="$HWX_DUMP_DIR/hwx_parsing.py"

if [ ! -x "$PARSER_M" ]; then
  echo "Building hwx_parsing (Objective-C parser)..."
  make -C "$HWX_DUMP_DIR" >/dev/null
fi

SEARCH_DIRS=("$@")
if [ ${#SEARCH_DIRS[@]} -eq 0 ]; then
  SEARCH_DIRS=("$REPO_ROOT")
fi

HWX_FILES=()
while IFS= read -r line; do
  HWX_FILES+=("$line")
done < <(find "${SEARCH_DIRS[@]}" -name '*.hwx' -type f 2>/dev/null | sort)

if [ ${#HWX_FILES[@]} -eq 0 ]; then
  echo "No .hwx files found under: ${SEARCH_DIRS[*]}"
  echo "Pass one or more directories containing sample .hwx files as arguments."
  exit 1
fi

# Keep only the numeric W/H/C/D fields, dropping format/type name labels.
dims_only() {
  grep -E '^\s*(InDim|OutDim)\s*:' | grep -oE 'W=[0-9]+ H=[0-9]+ C=[0-9]+ D=[0-9]+'
}

fail=0
checked=0
for f in "${HWX_FILES[@]}"; do
  checked=$((checked + 1))
  m_out=$("$PARSER_M" "$f" 2>/dev/null | dims_only) || true
  py_out=$(python3 "$PARSER_PY" "$f" 2>/dev/null | dims_only) || true

  if [ "$m_out" != "$py_out" ]; then
    fail=$((fail + 1))
    echo "MISMATCH: $f"
    diff <(echo "$m_out") <(echo "$py_out") | head -20
    echo "---"
  fi
done

echo "Checked $checked file(s), $fail mismatch(es)."
[ "$fail" -eq 0 ]
