#!/usr/bin/env python3
"""SCA-1872 Gate 6 — drill recall survey scorer / log manager.

Gate 6 asks: after viewing feedback, can a beta user recall the ONE thing the
app told them to practice? We ask the exit question and mark a user "understood"
when their free-text answer matches the `drill` text of their TOP ClipFeedback
card. This tool does NOT generate user answers or grade them on the human's
behalf — the recall judgment is made by a human grader during the live session.
It manages the structured log and computes the pass/fail result deterministically
so the survey is turnkey, plus an OPTIONAL token-overlap *suggestion* to assist
(never replace) the grader.

Top recommendation / drill (per issue SCA-1872, matching Gate 4's definition):
    RuleBasedFeedbackEngine.generateFeedback(...) returns one ClipFeedback per
    phase, already sorted ascending by phaseIndex. The TOP recommendation is the
    FIRST card whose primaryObservation.severity == "improvement"; its
    primaryObservation.drill is the "one thing to practice" we test recall of.
    If no card is an improvement (all strength/neutral/insufficient), the user
    had no drill to recall and is excluded from the denominator (verdict "n/a").

Pass criterion: >= 16 of 20 reviewable users (80%) marked "understood".

The exit question (read verbatim, no prompting toward the answer):
    "What one thing did the app tell you to practice today?"

Subcommands:
    init   Write an empty 20-slot template to docs/assets/drill-recall-log.json.
    score  Validate the log and print the recall result (with --suggest hints).

Usage:
    python3 drill_recall.py init  [--users N] [--out PATH] [--force]
    python3 drill_recall.py score [--log PATH] [--suggest]

NO AGENT MAY FABRICATE USER ANSWERS OR RECALL VERDICTS — the independent human
recall measurement is the entire point of the gate.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LOG = REPO_ROOT / "docs" / "assets" / "drill-recall-log.json"

VALID_VERDICTS = {"understood", "not_understood", "n/a", None}
TARGET_USERS = 20
PASS_THRESHOLD = 0.80  # >= 16/20 reviewable users

# Filler words ignored when suggesting overlap between answer and drill text.
_STOP = {
    "the", "a", "an", "to", "of", "and", "or", "your", "you", "my", "i", "it",
    "on", "in", "at", "for", "with", "do", "did", "was", "is", "be", "more",
    "that", "this", "app", "told", "me", "practice", "drill", "work", "thing",
}


def _tokens(text: str) -> set[str]:
    return {t for t in re.findall(r"[a-z0-9]+", (text or "").lower()) if t not in _STOP}


def suggest_overlap(answer: str, drill: str) -> float:
    """Fraction of the DRILL's key tokens present in the answer (0..1), as a
    *hint* for the human grader only. Containment (not Jaccard) because recall
    means the user captured the drill's essence — extra answer words shouldn't
    penalize the match."""
    a, d = _tokens(answer), _tokens(drill)
    if not d:
        return 0.0
    return len(a & d) / len(d)


def make_template(n_users: int) -> dict:
    return {
        "_meta": {
            "gate": "SCA-1826 Gate 6 — drill recall",
            "issue": "SCA-1872",
            "schemaVersion": 1,
            "strokeType": "forehand_drive",
            "exitQuestion": "What one thing did the app tell you to practice today?",
            "passCriterion": ">= 16/20 reviewable users (80%) marked 'understood'",
            "topDrillDefinition": (
                "primaryObservation.drill of the FIRST ClipFeedback "
                "(ascending phaseIndex) from RuleBasedFeedbackEngine.generateFeedback "
                "whose primaryObservation.severity == 'improvement'."
            ),
            "verdictValues": {
                "understood": "User's answer matches the top card's drill (the one thing to practice).",
                "not_understood": "Answer does not match the top drill (recalled wrong thing / could not recall).",
                "n/a": "User had no improvement-severity card; excluded from denominator.",
                "null": "Not yet surveyed.",
            },
            "status": "TEMPLATE — pending 20-user beta cohort + human grader (see runbook).",
        },
        "users": [
            {
                "slot": i + 1,
                "sessionId": None,          # beta session identifier
                "topDrill": None,           # exact drill text shown as "Practice this"
                "userAnswer": None,         # verbatim answer to the exit question
                "recallVerdict": None,      # "understood" | "not_understood" | "n/a" | null
                "graderNotes": None,
            }
            for i in range(n_users)
        ],
    }


def cmd_init(args: argparse.Namespace) -> int:
    out = Path(args.out)
    if out.exists() and not args.force:
        print(f"refusing to overwrite existing {out} (use --force)", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(make_template(args.users), indent=2) + "\n")
    print(f"wrote {args.users}-slot template → {out}")
    return 0


def cmd_score(args: argparse.Namespace) -> int:
    log_path = Path(args.log)
    if not log_path.exists():
        print(f"log not found: {log_path}", file=sys.stderr)
        return 2
    data = json.loads(log_path.read_text())
    users = data.get("users", [])

    errors: list[str] = []
    understood = not_understood = na = pending = 0
    for u in users:
        v = u.get("recallVerdict")
        if v not in VALID_VERDICTS:
            errors.append(f"slot {u.get('slot')}: invalid recallVerdict {v!r}")
            continue
        if v is None:
            pending += 1
        elif v == "understood":
            understood += 1
        elif v == "not_understood":
            not_understood += 1
        elif v == "n/a":
            na += 1

    reviewable = understood + not_understood
    total = len(users)

    print(f"log: {log_path}")
    print(f"users: {total}  understood: {understood}  not_understood: {not_understood}  "
          f"n/a: {na}  pending: {pending}")

    if args.suggest:
        for u in users:
            if u.get("recallVerdict") is None and u.get("userAnswer") and u.get("topDrill"):
                ov = suggest_overlap(u["userAnswer"], u["topDrill"])
                hint = "likely understood" if ov >= 0.5 else "likely NOT understood"
                print(f"  hint slot {u.get('slot')}: overlap {ov:.0%} → {hint} (grader decides)")

    if errors:
        for e in errors:
            print(f"  ERROR {e}", file=sys.stderr)
        return 2

    if pending > 0:
        print(f"STATUS: PENDING — {pending} user(s) not yet surveyed.")
        return 3
    if total < TARGET_USERS:
        print(f"STATUS: INCOMPLETE — need {TARGET_USERS} users, have {total}.")
        return 3
    if reviewable == 0:
        print("STATUS: INVALID — no reviewable users (all n/a).")
        return 2

    rate = understood / reviewable
    verdict = "PASS" if rate >= PASS_THRESHOLD else "FAIL"
    print(f"recall: {understood}/{reviewable} = {rate:.0%}  →  GATE {verdict}")
    if verdict == "FAIL":
        print("FAIL action: improve drill visibility in ClipFeedbackView "
              "(font weight, 'Practice this' CTA, top-card emphasis), then re-survey.")
        return 1
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="SCA-1872 Gate 6 drill recall tool")
    sub = p.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("init", help="write empty template")
    pi.add_argument("--users", type=int, default=TARGET_USERS)
    pi.add_argument("--out", default=str(DEFAULT_LOG))
    pi.add_argument("--force", action="store_true")
    pi.set_defaults(func=cmd_init)

    ps = sub.add_parser("score", help="validate and score the log")
    ps.add_argument("--log", default=str(DEFAULT_LOG))
    ps.add_argument("--suggest", action="store_true",
                    help="print token-overlap hints for ungraded rows (grader decides)")
    ps.set_defaults(func=cmd_score)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
