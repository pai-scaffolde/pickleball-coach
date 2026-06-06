#!/usr/bin/env python3
"""SCA-1871 Gate 4 — coach agreement scorer / log manager.

Gate 4 requires a qualified pickleball coach to independently rate the app's
TOP recommendation per accepted beta clip. This tool does NOT generate coach
verdicts (that is the human coach's job) — it manages the structured log and
computes the pass/fail result deterministically so the live session is turnkey.

Top recommendation (per issue SCA-1871):
    RuleBasedFeedbackEngine.generateFeedback(...) returns one ClipFeedback per
    phase, already sorted ascending by phaseIndex. The TOP recommendation is the
    FIRST card whose primaryObservation.severity == "improvement". If no card is
    an improvement (all strength/neutral/insufficient), the clip has no top
    recommendation and is excluded from the denominator (record verdict "n/a").

Pass criterion: >= 21 of 30 reviewable clips (70%) rated "agree".

Subcommands:
    init   Write an empty 30-slot template to docs/assets/coach-review-log.json.
    score  Validate the log and print the agreement result.

Usage:
    python3 coach_agreement.py init   [--clips N] [--out PATH] [--force]
    python3 coach_agreement.py score  [--log PATH]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LOG = REPO_ROOT / "docs" / "assets" / "coach-review-log.json"

VALID_VERDICTS = {"agree", "disagree", "n/a", None}
TARGET_CLIPS = 30
PASS_THRESHOLD = 0.70  # >= 21/30 reviewable clips


def make_template(n_clips: int) -> dict:
    return {
        "_meta": {
            "gate": "SCA-1826 Gate 4 — coach agreement",
            "issue": "SCA-1871",
            "schemaVersion": 1,
            "strokeType": "forehand_drive",
            "passCriterion": ">= 21/30 reviewable clips (70%) rated 'agree'",
            "topRecommendationDefinition": (
                "First ClipFeedback (ascending phaseIndex) from "
                "RuleBasedFeedbackEngine.generateFeedback whose "
                "primaryObservation.severity == 'improvement'."
            ),
            "verdictValues": {
                "agree": "Coach agrees the top recommendation is the right primary fix for this clip.",
                "disagree": "Coach disagrees (wrong fix, false positive, or a more important issue was missed).",
                "n/a": "Clip had no improvement-severity card; excluded from denominator.",
                "null": "Not yet reviewed.",
            },
            "status": "TEMPLATE — pending beta corpus + qualified coach (see runbook).",
        },
        "clips": [
            {
                "slot": i + 1,
                "clipId": None,                 # beta session/clip identifier
                "footagePath": None,            # path/URL the coach reviewed against
                "captureGatePassed": None,      # must be true (CaptureQualityGate)
                "topRecommendation": {
                    "ruleId": None,             # e.g. "ph5.hip_turn.low"
                    "phaseIndex": None,
                    "phaseTitle": None,
                    "observation": None,        # exact card text shown to coach
                    "citedMetricName": None,
                    "citedMetricValue": None,
                },
                "coachVerdict": None,           # "agree" | "disagree" | "n/a" | null
                "coachNotes": None,
            }
            for i in range(n_clips)
        ],
    }


def cmd_init(args: argparse.Namespace) -> int:
    out = Path(args.out)
    if out.exists() and not args.force:
        print(f"refusing to overwrite existing {out} (use --force)", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(make_template(args.clips), indent=2) + "\n")
    print(f"wrote {args.clips}-slot template → {out}")
    return 0


def cmd_score(args: argparse.Namespace) -> int:
    log_path = Path(args.log)
    if not log_path.exists():
        print(f"log not found: {log_path}", file=sys.stderr)
        return 2
    data = json.loads(log_path.read_text())
    clips = data.get("clips", [])

    errors: list[str] = []
    agree = disagree = na = pending = 0
    for c in clips:
        v = c.get("coachVerdict")
        if v not in VALID_VERDICTS:
            errors.append(f"slot {c.get('slot')}: invalid coachVerdict {v!r}")
            continue
        if v is None:
            pending += 1
        elif v == "agree":
            agree += 1
        elif v == "disagree":
            disagree += 1
        elif v == "n/a":
            na += 1

    reviewable = agree + disagree
    total = len(clips)

    print(f"log: {log_path}")
    print(f"clips: {total}  agree: {agree}  disagree: {disagree}  n/a: {na}  pending: {pending}")
    if errors:
        for e in errors:
            print(f"  ERROR {e}", file=sys.stderr)
        return 2

    if pending > 0:
        print(f"STATUS: PENDING — {pending} clip(s) not yet reviewed by coach.")
        return 3
    if total < TARGET_CLIPS:
        print(f"STATUS: INCOMPLETE — need {TARGET_CLIPS} clips, have {total}.")
        return 3
    if reviewable == 0:
        print("STATUS: INVALID — no reviewable clips (all n/a).")
        return 2

    rate = agree / reviewable
    verdict = "PASS" if rate >= PASS_THRESHOLD else "FAIL"
    print(f"agreement: {agree}/{reviewable} = {rate:.0%}  →  GATE {verdict}")
    if verdict == "FAIL":
        worst: dict[str, int] = {}
        for c in clips:
            if c.get("coachVerdict") == "disagree":
                rid = (c.get("topRecommendation") or {}).get("ruleId") or "<unknown>"
                worst[rid] = worst.get(rid, 0) + 1
        if worst:
            ranked = sorted(worst.items(), key=lambda kv: -kv[1])
            print("lowest-agreement rule IDs (revise in FeedbackRuleSet.swift):")
            for rid, n in ranked:
                print(f"  {rid}: {n} disagreement(s)")
        return 1
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="SCA-1871 Gate 4 coach agreement tool")
    sub = p.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("init", help="write empty template")
    pi.add_argument("--clips", type=int, default=TARGET_CLIPS)
    pi.add_argument("--out", default=str(DEFAULT_LOG))
    pi.add_argument("--force", action="store_true")
    pi.set_defaults(func=cmd_init)

    ps = sub.add_parser("score", help="validate and score the log")
    ps.add_argument("--log", default=str(DEFAULT_LOG))
    ps.set_defaults(func=cmd_score)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
