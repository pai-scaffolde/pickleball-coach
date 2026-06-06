#!/usr/bin/env bash
# SCA-1824 — Swift-native parity verification.
#
# Closes the prototype's honest carve-out: the comparison logic was originally
# verified via a behaviour-identical Python port because the host CommandLineTools
# swiftc has a duplicate `SwiftBridging` modulemap + SDK/compiler version mismatch.
#
# Once full Xcode is installed, this script compiles the REAL ComparisonEngine.swift
# using Xcode's *bundled* swiftc + matched SDK (no `sudo xcode-select`, no license
# acceptance needed — we invoke the toolchain directly), runs it over the same
# inputs as the Python port, and diffs the two reports for numeric parity.
#
# Usage:  tools/sca1824-comparison-harness/verify_swift_parity.sh
# Exit 0 = Swift binary built AND its report matches the Python port within tolerance.

set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

XCODE_APP="${XCODE_APP:-/Applications/Xcode.app}"
DEV="$XCODE_APP/Contents/Developer"
SWIFTC="$DEV/usr/bin/swiftc"
SDK="$DEV/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

USER_ART="docs/artifacts/SCA-1819-pose-spike-artifact.json"
REF="PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json"
SRC=(
  "tools/sca1824-comparison-harness/main.swift"
  "PickleballCoach/PickleballCoach/Services/ComparisonEngine.swift"
  "PickleballCoach/PickleballCoach/Models/ReferenceExemplar.swift"
)
OUT_SWIFT="/tmp/sca1824-swift-report.json"
OUT_PY="/tmp/sca1824-py-report.json"
BIN="/tmp/sca1824-harness"

if [[ ! -d "$XCODE_APP" ]]; then
  echo "BLOCKED: $XCODE_APP not present yet — Xcode install still in progress."
  echo "         (partial download at /Applications/Xcode.appdownload while installing)"
  exit 3
fi
if [[ ! -x "$SWIFTC" || ! -d "$SDK" ]]; then
  echo "BLOCKED: Xcode present but toolchain incomplete (swiftc=$SWIFTC sdk=$SDK)."
  exit 3
fi

echo "==> Using bundled toolchain: $SWIFTC"
"$SWIFTC" --version | head -1

echo "==> Compiling real ComparisonEngine.swift (no sudo, bundled SDK)..."
"$SWIFTC" -sdk "$SDK" -O -o "$BIN" "${SRC[@]}"

echo "==> Running Swift binary..."
"$BIN" "$USER_ART" "$REF" "$OUT_SWIFT"

echo "==> Running Python reference port on identical inputs..."
python3 tools/sca1824-comparison-harness/reference_port.py "$USER_ART" "$REF" "$OUT_PY"

echo "==> Diffing reports for numeric parity (tolerance 0.01)..."
python3 - "$OUT_SWIFT" "$OUT_PY" <<'PY'
import json, sys
def load(p):
    d = json.load(open(p))
    return d.get("report", d)
sw, py = load(sys.argv[1]), load(sys.argv[2])
TOL = 0.01
diffs = []
def cmp(path, a, b):
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        if abs(a - b) > TOL: diffs.append(f"{path}: swift={a} py={b}")
    elif isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)): cmp(f"{path}.{k}", a.get(k), b.get(k))
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b): diffs.append(f"{path}: len {len(a)} vs {len(b)}")
        for i,(x,y) in enumerate(zip(a,b)): cmp(f"{path}[{i}]", x, y)
    elif a != b:
        diffs.append(f"{path}: swift={a!r} py={b!r}")
cmp("report", sw, py)
print(f"swift overall = {sw.get('overallScore')}  |  py overall = {py.get('overallScore')}")
if diffs:
    print(f"PARITY FAIL — {len(diffs)} difference(s):")
    for d in diffs[:30]: print("  -", d)
    sys.exit(1)
print(f"PARITY OK — Swift report matches Python port across all numeric fields (tol {TOL}).")
PY

echo "==> DONE: Swift-native ComparisonEngine verified, parity with Python port confirmed."
