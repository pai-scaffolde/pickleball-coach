# SCA-1888 — Beta Corpus Capture Runbook (human-owned)

**Goal:** collect **≥30 clips of real pickleball strokes that pass
`CaptureQualityGate`** on the real app pipeline. This corpus is the prerequisite
that unblocks all three beta quality gates — **G1 (SCA-1870)**, **G4 (SCA-1871)**,
**G6 (SCA-1872)**.

> **Correction (2026-06-06, SCA-1888):** an earlier version of this runbook
> claimed *"synthetic / pre-downloaded footage does not satisfy the gate; it
> must be real footage captured through the app."* **That is false and has been
> verified false.** `CaptureQualityGate` evaluates **pose quality only**
> (detected-frame count, coverage ratio, contact-zone wrist/elbow confidence) —
> it has **no notion of provenance**, and `ImportVideoView` already runs
> *imported* footage through the identical `PoseExtractionService` pipeline.
> Real **pre-recorded** pickleball footage passes the gate. Proof: the
> `tools/sca1888-corpus-gate` harness runs the real `PoseExtractionService` +
> `CaptureQualityGate` headless over the two real in-repo fixtures and both
> **PASS** (forehand 89.1% coverage / 803 detected frames; backhand 84.0% /
> 769 — vs the 60% / 15-frame floors). Rebuild & rerun:
> `swiftc` the four app sources + `main.swift` (see the tool dir), then
> `./corpus-gate tests/fixtures/yt-*.mp4`.
>
> **What this changes:** the corpus does *not* require a physical device or live
> capture **for gate-passing**. It requires ~30 **independent** real-stroke
> sources (each ≥3 s). Those can come from live play **or** from a supplied
> library of ~30 real pickleball clips imported through the app. What an agent
> still cannot fabricate is the *human-outcome* signal the downstream gates
> measure — see "Remaining human-owned scope" below.

**Owner:** Gary / product — decides the corpus source (live play vs supplied
clip library) and owns the human-outcome gates (G1 retry dynamics, G4 coach
review, G6 drill-recall survey).

---

## 1. Build & install from `main`

```bash
git checkout main && git pull
open PickleballCoach/PickleballCoach.xcodeproj
```

In Xcode: select your physical device as the run destination → **Run** (⌘R) to
install. (TestFlight also works once a build is uploaded.)

> Pre-flight verification of the committed `main` build is recorded in the
> SCA-1888 issue thread for the date this runbook landed. If Xcode reports a
> missing-symbol / "cannot find … in scope" error, it is almost always an
> **unregistered `.swift` file** (a new file added to disk but not added to the
> Xcode target / `project.pbxproj`). Add the file to the `PickleballCoach`
> target in Xcode's File Inspector and rebuild before starting the session.

## 2. What makes a clip PASS the gate

`CaptureQualityGate` (`PickleballCoach/PickleballCoach/Services/CaptureQualityGate.swift`)
is the single source of truth. A clip is **accepted** only when **all** of these
hold — frame your recording to satisfy them and your pass-rate stays high:

| Gate requirement | Threshold | Capture behaviour that satisfies it |
| --- | --- | --- |
| Body detected in enough frames | ≥ **15** detected frames | Record **≥ 3 s of continuous stroke motion**. |
| Body-detection coverage | ≥ **60 %** of frames | Stand **2–3 m** from the camera, **full body in frame**, plain background, even lighting, **no one else in frame**. |
| Contact-zone tracking | wrist conf > **0.60**, elbow conf > **0.65** (middle 30–70 % of the clip) | Keep the **paddle/hitting arm well-lit and unoccluded** through contact. Shoot **60 fps+ / slow-mo** if the swing is fast. |

(Short-clip / legacy path also requires ≥ **10** sampled frames and ≥ **6** key
joints reliable — the same framing rules cover these.)

**Practical setup that maximises pass rate**

- Phone on a tripod / propped, landscape, ~waist height, **2–3 m** back so your
  whole body is in frame.
- Plain, uncluttered background; even lighting; avoid backlight/silhouette.
- Only the hitting player in frame.
- Each clip = **one clean stroke, ≥ 3 s**, swing fully inside the frame.
- Prefer **60 fps / slow-mo** capture.

## 3. Record ≥30 and note the clips

1. In the app, import/record a stroke clip per session. Each session runs through
   `CaptureQualityGate`; rejected clips show on-screen fix instructions and a
   **"Record a new clip"** button (re-import path, which the G1 attempt counter
   tracks).
2. Repeat until you have **≥ 30 accepted (gate-passed) sessions**. A spread of
   forehand / backhand / serve and a couple of deliberately-bad framings is
   useful for the downstream gates, but the 30 must all be **accepted**.
3. **Where the data lands** (app's Documents container, pull via Xcode →
   Devices & Simulators → app container, or a debug export surface):
   - Session/clip records: the app's session store.
   - Gate analytics: **`capture-analytics.json`** — one event per gate
     evaluation `{ sessionId, captureAttemptCount, accepted, timestamp }`
     (`CaptureAnalytics`).
4. **Note the accepted session IDs / clip paths** in the SCA-1888 issue so the
   gate-scoring tools can consume them.

## 4. Turnkey follow-through once the corpus exists

| Gate | Action | Where |
| --- | --- | --- |
| **G1 (SCA-1870)** capture success ≥ 80 % by 2nd try | Pull `capture-analytics.json` (≥ 30 accepted sessions) and read `CaptureAnalytics.gateSummary()`; `passes == true` clears it. | `docs/SCA-1870-G1-CAPTURE-GATE.md` |
| **G4 (SCA-1871)** coach agreement | `python3 tools/sca1871-coach-agreement/coach_agreement.py init` → fill the log → `… score`; book the coach review. | `docs/SCA-1871-COACH-AGREEMENT-RUNBOOK.md` |
| **G6 (SCA-1872)** drill recall | `python3 tools/sca1872-drill-recall/drill_recall.py init` → administer survey → `… score`. | `docs/SCA-1872-DRILL-RECALL-RUNBOOK.md` |

All three tools were verified runnable (`--help` / `init`/`score` subcommands) at
the time this runbook landed; they are blocked only on the real corpus from
steps 1–3.

---

### Remaining human-owned scope (precise boundary)

The earlier "only a physical device can satisfy the gate" framing was wrong (see
the correction at the top). The **gate mechanics are agent-verifiable and were
verified** (`tools/sca1888-corpus-gate`). What genuinely remains human/product:

1. **Corpus source decision** — accept a *supplied real-clip library* (≥30
   independent ≥3 s real pickleball strokes; an agent can then import + gate +
   assemble the corpus and `capture-analytics.json` fully automatically), **or**
   require *live on-device beta captures*. This is a product call, not a
   technical blocker.
2. **G1 (SCA-1870) authentic retry dynamics** — the capture-success metric
   measures whether *real users* succeed within 2 attempts. A clean library
   corpus can validate the tooling but cannot fabricate genuine first/second-try
   user behaviour.
3. **G4 (SCA-1871)** — needs a **real coach** to review feedback agreement.
4. **G6 (SCA-1872)** — needs **real survey respondents** for drill recall.

Build health, gate thresholds, gate-vs-real-footage validation, and the three
downstream tools are all pre-verified so the human session is turnkey.
