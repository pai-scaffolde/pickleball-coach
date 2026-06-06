# sca1888-corpus-gate

Headless harness that runs the **real** app capture pipeline —
`PoseExtractionService` (Apple Vision `VNDetectHumanBodyPoseRequest`) →
`CaptureQualityGate` — over arbitrary video files on macOS, with **no device
and no simulator**.

## Why

SCA-1888's runbook claimed pre-recorded footage could not satisfy
`CaptureQualityGate`. This harness empirically disproves that: it links the
unmodified app sources and prints the gate verdict per clip.

## Build & run

```bash
cd tools/sca1888-corpus-gate
SDK=$(xcrun --sdk macosx --show-sdk-path)
swiftc -O -sdk "$SDK" \
  ../../PickleballCoach/PickleballCoach/Models/PoseFrame.swift \
  ../../PickleballCoach/PickleballCoach/Models/PoseAnalysisResult.swift \
  ../../PickleballCoach/PickleballCoach/Services/PoseExtractionService.swift \
  ../../PickleballCoach/PickleballCoach/Services/CaptureQualityGate.swift \
  main.swift -o corpus-gate

./corpus-gate ../../tests/fixtures/yt-forehand-drive-navratil-v0.mp4 \
              ../../tests/fixtures/yt-backhand-drive-selkirk-v0.mp4
```

Exit code `0` if **any** input passes the gate, `1` if none pass.

## Verified result (2026-06-06)

Both real in-repo fixtures **PASS**:

| clip | coverage (≥60%) | detected frames (≥15) | verdict |
| --- | --- | --- | --- |
| `yt-forehand-drive-navratil-v0.mp4` | 89.1% | 803 | ✅ PASS |
| `yt-backhand-drive-selkirk-v0.mp4` | 84.0% | 769 | ✅ PASS |

The gate evaluates pose quality only; provenance is irrelevant. The remaining
≥30-clip corpus needs ~30 *independent* real-stroke sources (live or supplied),
not a physical device. See `docs/SCA-1888-BETA-CORPUS-CAPTURE-RUNBOOK.md`.
