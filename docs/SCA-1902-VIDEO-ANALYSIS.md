# SCA-1902 — Video Analysis: Ben Johns & Anna Leigh Waters, Ultra Slow Motion

Frame-by-frame mechanics breakdown of the four shots Gary flagged in
[*"Ben Johns & Anna Leigh Waters in Ultra Slow Motion"* — Johnkew Pickleball](https://youtu.be/VbtNRKB3xB8)
(11:01, 1080p/24fps). Goal: extract the copyable mechanics of each shot in the
app's mechanics-scoring vocabulary (kinetic chain → contact point → low-to-high
brush → follow-through), so they can be drilled and, where useful, added as
**reference exemplars**.

> "Lean Waters" in the issue = **Anna Leigh Waters (ALW)**. The video is a
> slow-motion reel; the editor cuts between replay clips, so the on-screen
> timestamps drift slightly from the moment of contact. Windows below are the
> *extracted* second ranges from the local download.

## How this was produced

1. `yt-dlp` → 1080p MP4 (local, not committed).
2. `ffmpeg` frame extraction at each flagged window; ImageMagick contact sheets
   to locate contact, then full-res hero frames + isolated slow-mo clips.
3. Visual mechanics read against the app's existing reference models
   (`reference_forehand_drive_v0.json`, `reference_backhand_drive_v0.json`).

Artifacts **committed** to `docs/artifacts/sca1902-frames/` (stills = analysis/commentary):
- `shot{A,B,C,C2}_*_*.jpg` — full-res hero contact frames
- `shot{A,B,C}_sequence-{1,2}.jpg` — kinetic-chain contact sheets

Isolated slow-mo clips + full source are kept **local, not committed**
(`~/Movies/sca1902-clips/` — copyrighted Johnkew footage; mirrors the
`exemplar-rights-register.json` posture):
- `shot{A,B,C,C2}_*.mp4` — single-shot slow-mo clips to rewatch
- `source_full_VbtNRKB3xB8.mp4` — full download, re-extract any window with
  `ffmpeg -ss <sec> -i source_full_VbtNRKB3xB8.mp4 -t <dur> out.mp4`

---

## Shot A — Ben Johns, low forehand roll (≈4:06 → extracted 246–260 s)

**What it is.** Johns slides to his forehand and digs a ball **below net height**
near the kitchen, brushing low-to-high to lift it into a dipping, topspin-loaded
ball — a *roll volley / low forehand roll*, not a flat dink. This is the shot that
turns defense into offense without popping the ball up.
Sequence: `shotA_sequence-1.jpg`, `shotA_sequence-2.jpg`; clip: `shotA_johns-low-roll.mp4`.

**Kinetic chain (copyable cues):**
1. **Split + lateral load** — wide athletic base, weight on the outside leg, paddle
   already low. He gets *under* the ball with his knees, not his back (hips sink,
   chest stays up).
2. **Compact backswing** — paddle face slightly open, takeback short. No big wind-up;
   the power is in the brush, not the arm.
3. **Low-to-high brush at contact** — contact is **out in front and below the wrist**;
   the paddle accelerates *up the back of the ball*. This is the entire shot: the
   upward brush is what creates the dip that keeps it offensive yet safe.
4. **Short, upward follow-through** — finishes high and compact, body staying
   balanced over the base for instant recovery to the kitchen line.

**Drill it:** feed yourself low balls at the kitchen; the only target is brush
direction — start the paddle below the ball and finish above your eyeline, ball
must clear the net by <1 ft and dip. Knees do the lowering, not the waist.

---

## Shot B — Anna Leigh Waters, two-handed slam (≈4:55 → extracted 294–308 s)

**What it is.** ALW tracks a high ball on her backhand side and drives it down with
**both hands on the paddle** — a two-handed overhead/drive that hits like a
two-handed backhand groundstroke rather than a one-handed smash. It's compact,
rotational, and brutally consistent because the off-hand controls the face.
Sequence: `shotB_sequence-1.jpg`, `shotB_sequence-2.jpg`; clip: `shotB_alw-2hand-slam.mp4`.

**Kinetic chain (copyable cues):**
1. **Early two-hand prep** — both hands up and paddle back *as the ball rises*. She
   commits to two hands early; no late decision.
2. **Coil + step in** — shoulders turn, she steps into the ball so contact is in
   front; the slam is driven by **trunk rotation**, not arm-throwing.
3. **Contact slightly in front, above shoulder** — both arms extend through the ball;
   the off-hand keeps the face stable so the ball is *driven down*, not sprayed.
4. **Long rotational follow-through across the body** — finishes with the shoulders
   fully rotated through, weight transferred forward, balanced.

**Why two hands:** the second hand trades a little reach for a lot of *control and
topspin* — she can take a high ball that isn't a clean overhead and still flatten it
down safely. This is the highest-value shot in the reel to copy if you have a
two-handed backhand already.

**App mapping:** mechanically this is closest to the existing
`reference_backhand_drive_v0.json` chain (two-handed, trunk-driven, contact in front)
but at a **high contact point** — a strong candidate to become a dedicated
`reference_two_hand_overhead` exemplar.

---

## Shot C — Ben Johns, stretch brush-over (≈5:36 → extracted 342–353 s)

**What it is.** Johns is **stretched wide and high** for a ball above his head and,
instead of a flat swat, **brushes up and over the top** — topspin on a reaching,
off-balance ball. This is the "perfect-form setup": the brush-over keeps the ball in
and heavy, *forcing a weak reply he (or his partner) puts away next ball*.
Sequence: `shotC_sequence-1.jpg`, `shotC_sequence-2.jpg`; hero: `shotC_johns-brushover_extension.jpg`;
clip: `shotC_johns-brushover.mp4`.

**Kinetic chain (copyable cues):**
1. **Full reach without losing the face** — arm extends overhead/across; even
   stretched, the wrist stays firm and the paddle face controlled.
2. **Up-and-over brush, not a flat hit** — the paddle travels *over the top* of the
   ball (high-to-higher), imparting topspin so a ball hit from a bad position still
   drops in. The brush is what buys the margin.
3. **Recovery built into the finish** — he's already re-loading toward the middle as
   the follow-through ends, ready for the next ball.

**The "next-shot slam"** (`shotC2_johns-putaway.jpg`, `shotC2_johns-putaway.mp4`,
extracted 357–365 s): the heavy brush-over draws a floaty reply, taken at the net as
a **compact, in-front punch/roll put-away** — short backswing, contact in front,
firm wrist, downward finish. The lesson is the *sequence*: an aggressive-but-safe
topspin shot from a stretched position manufactures the easy put-away. Copy the
pairing, not just the slam.

---

## Takeaways & app follow-ups

**For Gary's game (priority order):**
1. **Low forehand roll (Shot A)** — the brush direction is the whole shot; drill
   knees-down + low-to-high.
2. **Two-handed slam (Shot B)** — copy the early two-hand prep and trunk rotation;
   highest-leverage put-away.
3. **Brush-over → put-away sequence (Shot C)** — topspin buys margin from bad
   positions and sets up the next-ball kill.

**For the pickleball-coach app (optional, not in this issue's scope):**
- The app currently models only forehand/backhand *drives*. Shots B (two-hand
  overhead) and A (low roll) are unmodeled shot types. The isolated slow-mo clips
  here are clean, single-shot, slow-motion exemplars — good source material for new
  `ReferenceExemplar` entries **if rights/attribution clear** (Johnkew Pickleball;
  see `exemplar-rights-register.json`). Flagging as a candidate, not building it here.
