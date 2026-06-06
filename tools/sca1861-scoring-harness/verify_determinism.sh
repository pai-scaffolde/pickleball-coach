#!/usr/bin/env bash
# SCA-1861 — Determinism verification (sudo-free, no Swift toolchain required).
#
# Proves the core acceptance criterion: scoring the SAME [PoseFrame] input twice
# produces BITWISE-equal MechanicsScore output. Runs the MechanicsScoringEngine
# reference port twice on the canonical fixture pose timeline and byte-diffs the
# two outputs. Also regenerates the durable SCA-1861 scorecard artifact.
#
# The Swift XCTest (PickleballCoachTests/MechanicsScoringEngineTests.swift)
# asserts the identical property against the REAL engine; this script gives the
# same guarantee headless on a host whose CommandLineTools swiftc is broken.
#
# Usage:  tools/sca1861-scoring-harness/verify_determinism.sh
# Exit 0 = two independent runs are byte-identical.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repo root

TIMELINE="tests/fixtures/forehand-pose-timeline-v0.json"
REF="PickleballCoach/PickleballCoach/Resources/reference_forehand_drive_v0.json"
PORT="tools/sca1861-scoring-harness/reference_port.py"
OUT_A="/tmp/sca1861-score-a.json"
OUT_B="/tmp/sca1861-score-b.json"
ARTIFACT="docs/artifacts/SCA-1861-mechanics-score-artifact.json"

echo "==> Run 1 on $TIMELINE"
python3 "$PORT" "$TIMELINE" "$REF" "$OUT_A"
echo "==> Run 2 on identical input"
python3 "$PORT" "$TIMELINE" "$REF" "$OUT_B" >/dev/null

echo "==> Byte-diffing the two MechanicsScore outputs..."
if ! cmp -s "$OUT_A" "$OUT_B"; then
  echo "DETERMINISM FAIL — two runs differ:"
  diff "$OUT_A" "$OUT_B" || true
  exit 1
fi
SUM=$(shasum -a 256 "$OUT_A" | cut -d' ' -f1)
echo "DETERMINISM OK — two independent runs are byte-identical (sha256 $SUM)."

echo "==> Writing durable scorecard artifact: $ARTIFACT"
cp "$OUT_A" "$ARTIFACT"
echo "==> DONE."
