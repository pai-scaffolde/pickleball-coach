#!/usr/bin/env bash
# SCA-1861 — Swift-native parity verification.
#
# The MechanicsScoringEngine is verified headless via a behaviour-identical
# Python port (reference_port.py) because the host CommandLineTools swiftc has a
# duplicate SwiftBridging modulemap defect. Once full Xcode is installed, this
# script compiles the REAL MechanicsScoringEngine.swift (+ the ComparisonEngine
# it reuses) using Xcode's bundled swiftc + matched SDK (no sudo, no license
# acceptance), runs it over the same inputs as the port, and diffs the two
# MechanicsScore outputs for numeric + string parity.
#
# Usage:  tools/sca1861-scoring-harness/verify_swift_parity.sh
# Exit 0 = Swift binary built AND its score matches the Python port within tolerance.
# Exit 3 = blocked (Xcode/toolchain not present) — run verify_determinism.sh instead.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

XCODE_APP="${XCODE_APP:-/Applications/Xcode.app}"
DEV="$XCODE_APP/Contents/Developer"
SWIFTC="$DEV/usr/bin/swiftc"
SDK="$DEV/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

TIMELINE="tests/fixtures/forehand-pose-timeline-v0.json"
REF="PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json"
APP="PickleballCoach/PickleballCoach"
SRC=(
  "tools/sca1861-scoring-harness/main.swift"
  "$APP/Services/MechanicsScoringEngine.swift"
  "$APP/Services/ComparisonEngine.swift"
  "$APP/Services/RightsGate.swift"
  "$APP/Models/ReferenceExemplar.swift"
  "$APP/Models/PoseFrame.swift"
  "$APP/Models/PoseAnalysisResult.swift"
  "$APP/Models/ClipInterval.swift"
  "$APP/Models/MechanicsScore.swift"
  "$APP/Models/MechanicsObservation.swift"
)
OUT_SWIFT="/tmp/sca1861-swift-score.json"
OUT_PY="/tmp/sca1861-py-score.json"
BIN="/tmp/sca1861-harness"

if [[ ! -d "$XCODE_APP" ]]; then
  echo "BLOCKED: $XCODE_APP not present — run verify_determinism.sh (sudo-free) instead."
  exit 3
fi
if [[ ! -x "$SWIFTC" || ! -d "$SDK" ]]; then
  echo "BLOCKED: Xcode present but toolchain incomplete (swiftc=$SWIFTC sdk=$SDK)."
  exit 3
fi

echo "==> Using bundled toolchain: $SWIFTC"
"$SWIFTC" --version | head -1

echo "==> Compiling real MechanicsScoringEngine.swift (no sudo, bundled SDK)..."
"$SWIFTC" -sdk "$SDK" -O -o "$BIN" "${SRC[@]}"

echo "==> Running Swift binary..."
"$BIN" "$TIMELINE" "$REF" "$OUT_SWIFT"

echo "==> Running Python reference port on identical inputs..."
python3 tools/sca1861-scoring-harness/reference_port.py "$TIMELINE" "$REF" "$OUT_PY"

echo "==> Diffing the two MechanicsScore outputs (numeric tol 0.01, strings exact)..."
python3 - "$OUT_SWIFT" "$OUT_PY" <<'PY'
import json, sys
swift = json.load(open(sys.argv[1]))                     # raw MechanicsScore
py = json.load(open(sys.argv[2])).get("mechanicsScore")  # wrapped in _meta doc
TOL = 0.01
diffs = []
def cmp(path, a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        if a != b: diffs.append(f"{path}: swift={a} py={b}")
    elif isinstance(a, (int, float)) and isinstance(b, (int, float)):
        if abs(a - b) > TOL: diffs.append(f"{path}: swift={a} py={b}")
    elif isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)): cmp(f"{path}.{k}", a.get(k), b.get(k))
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b): diffs.append(f"{path}: len {len(a)} vs {len(b)}")
        for i,(x,y) in enumerate(zip(a,b)): cmp(f"{path}[{i}]", x, y)
    elif a != b:
        diffs.append(f"{path}: swift={a!r} py={b!r}")
cmp("mechanicsScore", swift, py)
print(f"swift keyFrame={swift.get('keyFrameTimestamp')} categories={len(swift.get('scores',{}))}")
if diffs:
    print(f"PARITY FAIL — {len(diffs)} difference(s):")
    for d in diffs[:30]: print("  -", d)
    sys.exit(1)
print(f"PARITY OK — Swift MechanicsScore matches the Python port (tol {TOL}).")
PY

echo "==> DONE: Swift-native MechanicsScoringEngine verified, parity with Python port confirmed."
