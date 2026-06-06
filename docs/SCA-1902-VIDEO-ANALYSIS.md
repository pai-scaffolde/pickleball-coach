# SCA-1902 — Video Analysis: Ben Johns & Anna Leigh Waters, Ultra Slow Motion

Frame-by-frame mechanics breakdown of the seven shots Gary flagged (four in the
original brief, three added in follow-up comments) in
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
- `shot{A,B,C,C2,D,E,F}_*_*.jpg` — full-res hero contact frames
- `shot{A,B,C,D,E,F}_sequence-*.jpg` — kinetic-chain contact sheets

Isolated slow-mo clips + full source are kept **local, not committed**
(`~/Movies/sca1902-clips/` — copyrighted Johnkew footage; mirrors the
`exemplar-rights-register.json` posture):
- `shot{A,B,C,C2,D,E,F}_*.mp4` — single-shot slow-mo clips to rewatch
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

## Shot D — Ben Johns, cut (slice) third-shot drop (≈6:10 → extracted 366–374 s)

**What it is.** From the transition zone Johns floats a **third-shot drop with
underspin** — an open paddle face slides *under and through* the ball so it carries
backspin, lands soft in the kitchen, and **stays low after the bounce** instead of
sitting up. The "cut" is what denies the opponent an attackable ball.
Sequence: `shotD_sequence-1.jpg`, `shotD_sequence-2.jpg`; hero: `shotD_johns-cut-drop_contact.jpg`;
clip (local): `shotD_johns-cut-drop.mp4`.

**Kinetic chain (copyable cues):**
1. **Low, balanced base** — knees bent, weight settled and moving *forward* through
   the shot, not lunging.
2. **Open face, contact out front** — paddle face beveled open, contact well in front
   of the body so he can guide the ball, not slap it.
3. **High-to-low slice "cut"** — paddle travels slightly downward/forward across the
   back-bottom of the ball, shaving underspin. Soft hands — the grip stays relaxed so
   pace comes *off* the ball, not onto it.
4. **Short push-through finish** — minimal follow-through, paddle finishes pointing at
   the target; he's already stepping in toward the kitchen line.

**Drill it:** target is *trajectory + spin*, not power — the ball should arc up,
peak before the net, and drop into the kitchen with backspin so it skids low. Soft
grip, open face, contact in front, feet moving forward.

---

## Shot E — Ben Johns, backhand flick (≈6:33 → extracted 391–399 s)

**What it is.** Off a low ball at the kitchen, Johns delivers a **disguised,
wrist-led backhand speed-up** — the "flick." It looks like he's about to dink, then
the paddle tip drops and snaps up through the ball for sudden pace from a position
that reads as defensive. Gary's "best shot in pickleball" call is fair: it's the
hardest speed-up to read.
Sequence: `shotE_sequence-1.jpg`, `shotE_sequence-2.jpg`; hero: `shotE_johns-bh-flick_contact.jpg`;
clip (local): `shotE_johns-bh-flick.mp4`.

**Kinetic chain (copyable cues):**
1. **Disguise via a dink-look setup** — same posture and paddle height as a dink until
   the last instant; the opponent can't pre-react.
2. **Paddle-tip drop + wrist load** — the tip drops below the ball and the wrist cocks;
   this is the spring that stores the speed.
3. **Explosive low-to-high wrist snap at contact** — contact **out in front**, the
   wrist (not the arm) unloads up the back of the ball → topspin + pace from almost no
   backswing. Compactness is what keeps it disguised and controllable.
4. **Short check-finish** — abbreviated follow-through, instant recovery for the
   counter, because a flick invites a fast exchange.

**Drill it:** practice the dink and the flick from an **identical setup** so they're
indistinguishable until contact. The power is a wrist snap on a ball *in front of you*;
if you reach or take it late, it sails. Build the topspin brush first, speed second.

---

## Shot F — Anna Leigh Waters, early foot-plant → two-handed slam from a bad position (≈6:52 → extracted 409–426 s)

**What it is.** This is the one Gary nailed in the comment: ALW **plants her feet
early — sets a wide, stable, loaded base *before* the ball comes back** — so that even
though she's pulled out of position, she has a solid platform to rotate and unload a
**two-handed slam**. The footwork *is* the shot; the slam is just the payoff.
Foot-plant: `shotF_sequence-1-footplant.jpg`; slam: `shotF_sequence-2-slam.jpg`;
hero: `shotF_alw-footplant-slam_contact.jpg`; clip (local): `shotF_alw-footplant-slam.mp4`.

**Why the early plant matters (the lesson):**
1. **Plant before the ball, not with the ball** — she's set in a wide, low base while
   the ball is still travelling. A late, still-moving body can only *block or reset*;
   a planted base can *attack*.
2. **Stable platform → rotation → power** — with both feet down she can fire the trunk
   rotation that drives the two-handed slam. Out-of-position becomes irrelevant once the
   base is solid.
3. **Two hands rescue a bad contact point** — the off-hand stabilizes the face so a ball
   she's stretched/late on still gets driven *down* instead of sprayed.

**Drill it:** the discipline is timing, not athleticism — read the ball early, get the
feet **set and wide a beat before** you'd "need" to, then hit. Pair this directly with
Shot B (the clean two-handed slam): same swing, but Shot F is the version you'll
actually face — under pressure, out of position, saved by early footwork.

---

## Takeaways & app follow-ups

**For Gary's game.** Two themes run through all seven shots: **brush for margin**
(A, C, D, E all win by spinning the ball, never flattening it) and **set the base
early** (B and especially F — power comes from a planted, rotated body, not a
reaching arm).

Priority order:
1. **ALW early foot-plant → 2-hand slam (Shot F)** — the highest-leverage *habit*
   here: plant wide a beat before the ball, and a bad position still becomes an
   attack. Drill the timing, not the swing.
2. **Two-handed slam (Shot B)** — the clean version of F's swing; early two-hand prep
   + trunk rotation.
3. **Backhand flick (Shot E)** — disguised wrist-snap speed-up from a dink-look; the
   hardest shot to read once you own it.
4. **Cut third-shot drop (Shot D)** — open-face underspin that stays low; trajectory
   and spin over power.
5. **Low forehand roll (Shot A)** — knees-down, low-to-high brush.
6. **Brush-over → put-away sequence (Shot C)** — topspin buys margin from a stretch
   and sets up the next-ball kill.

**For the pickleball-coach app (optional, not in this issue's scope):**
- The app currently models only forehand/backhand *drives*. Most shots here are
  unmodeled types — two-hand overhead (B, F), low roll (A), cut drop (D), backhand
  flick (E). The isolated slow-mo clips are clean, single-shot exemplars — good source
  material for new `ReferenceExemplar` entries **if rights/attribution clear** (Johnkew
  Pickleball; see `exemplar-rights-register.json`). Flagging as a candidate, not
  building it here.
