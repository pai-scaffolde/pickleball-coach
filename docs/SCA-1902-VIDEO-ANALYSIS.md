# SCA-1902 — Video Analysis: pro-shot mechanics breakdown

Frame-by-frame mechanics breakdown of the **14 shots** Gary flagged across **two
videos**:

- **Video 1 (shots A–K)** — [*"Ben Johns & Anna Leigh Waters in Ultra Slow Motion"* — Johnkew Pickleball](https://youtu.be/VbtNRKB3xB8)
  (11:01, 1080p/24fps slow-mo). Stroke mechanics.
- **Video 2 (shots L–M)** — [*Bright/Patriquin v Dennehy/Shimabukuro, Veolia Atlanta* — PPA Tour](https://www.youtube.com/watch?v=7cc4GWlLuuw)
  (full-speed broadcast). **Hayden Patriquin** footwork.

Goal: extract the copyable mechanics of each shot in the app's mechanics-scoring
vocabulary (kinetic chain → contact point → low-to-high brush → follow-through), so
they can be drilled and, where useful, added as **reference exemplars**.

> "Lean Waters" in the issue = **Anna Leigh Waters (ALW)**; "Hayden" = **Hayden
> Patriquin**. Video 1 is a slow-motion reel whose editor cuts between replay clips, so
> on-screen timestamps drift slightly from contact. Windows below are the *extracted*
> second ranges from the local downloads.

## How this was produced

1. `yt-dlp` → 1080p MP4 per video (local, not committed).
2. `ffmpeg` frame extraction at each flagged window; ImageMagick contact sheets to
   locate contact, then full-res hero frames + isolated clips. For the full-speed
   Video 2, near-court regions were cropped and tracked at higher fps.
3. Visual mechanics read against the app's existing reference models
   (`reference_forehand_drive_v0.json`, `reference_backhand_drive_v0.json`).

Artifacts **committed** to `docs/artifacts/sca1902-frames/` (stills = analysis/commentary):
- `shot{A,B,C,C2,D,E,F,G,H,I,J,K}_*_*.jpg` — full-res hero contact frames
- `shot{A..K}_sequence*.jpg` — kinetic-chain contact sheets
- `shotL_*`, `shotM_*` — Video 2 court view + near-court footwork tracking sheets

Isolated clips + full sources are kept **local, not committed**
(`~/Movies/sca1902-clips/` — copyrighted footage; mirrors the
`exemplar-rights-register.json` posture):
- `shot{A..M}_*.mp4` — single-shot clips to rewatch
- `source_full_VbtNRKB3xB8.mp4`, `source_full_7cc4GWlLuuw.mp4` — full downloads;
  re-extract any window with `ffmpeg -ss <sec> -i <source> -t <dur> out.mp4`

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

## Shot G — Ben Johns, pronation change-of-direction jump slam (≈7:31 → extracted 450–458 s)

**What it is.** Johns springs **straight up off both feet** for an overhead and, at
the last instant, **pronates his forearm** (the paddle face rotates/snaps over) to
**change the direction of the slam after the opponent has committed**. Gary's note is
the key: *he gets in the air to let his body do this* — being airborne is what frees
the rotation that powers the late redirect.
Jump load: `shotG_sequence-1-jump.jpg`; contact + pronation: `shotG_sequence-2-pronation.jpg`;
hero: `shotG_johns-pronation-jump-slam_contact.jpg`; clip (local): `shotG_johns-pronation-jump-slam.mp4`.

**Why the jump enables the shot (the lesson):**
1. **Unweight the feet → free the hips.** On the ground, the planted stance and foot
   friction *brake* trunk rotation — the legs have to anchor. Jumping unweights the
   feet so the hips and shoulders rotate as a free system; angular momentum carries
   through instead of being checked.
2. **Pronation is the disguise.** The forearm stays neutral until the last instant,
   then **rotates through contact** (palm/paddle face turning over). The face direction
   is set *after* the opponent reads the swing → they break the wrong way. This is a
   direction change, not just a power add.
3. **Height = a downward angle + time at the peak.** Getting up to the ball lets him
   take it at the top and hit *down*, and the hang time gives the forearm room to fire
   the pronation cleanly.

**Kinetic chain (copyable cues):**
1. **Read early, explosive two-foot jump straight up** — load both legs, spring
   vertically (not forward), paddle up early.
2. **Airborne coil** — body rotates freely; contact **out in front and above the head**.
3. **Late forearm pronation at contact** — keep the face neutral, then snap the forearm
   over *through* the ball to angle it sharply and change its line.
4. **Balanced landing + instant recovery** — absorb on landing, reset for the next ball.

**Drill it (advanced):** this is a high-skill, high-risk put-away — build it only once
the grounded overhead is solid. Start with a stationary two-foot jump and a *neutral*
overhead, then layer in the forearm pronation to redirect line at the last instant.
Cue: "jump to free the hips, turn the forearm over late." Don't reach forward off-balance
— the jump is **up**, the redirect is **in the forearm**, not the shoulder.

---

## Shot H — Anna Leigh Waters, "velvet" soft reset (≈8:31 → extracted 508–516 s)

**What it is.** Under pressure at the kitchen, ALW takes the pace off a driven ball
and floats it back soft into the opponent's kitchen — a **reset** with "velvet" (dead,
relaxed) hands. The skill is *absorption*: the paddle gives on contact so the ball dies
short instead of popping up.
Sequence: `shotH_sequence.jpg`; hero: `shotH_alw-soft-reset_contact.jpg`;
clip (local): `shotH_alw-soft-reset.mp4`.

**Kinetic chain (copyable cues):**
1. **Low, early, balanced** — she's down at ball height with a wide base *before*
   contact, paddle out front.
2. **Loose grip = soft hands** — relaxed grip (~3/10). The wrist/paddle **gives
   backward** on contact to absorb pace; she's catching the ball, not hitting it.
3. **Contact in front, paddle face slightly open** — quiet hands, no swing; the ball is
   *cushioned* and re-floated just over the net to land soft in the kitchen.
4. **Hold and recover** — minimal motion means she's instantly balanced for the next
   ball.

**Drill it:** have a partner drive at you; the win condition is a ball that lands in the
kitchen and bounces *low*. Loose grip, contact in front, let the paddle absorb — no
backswing, no follow-through.

---

## Shot I — Anna Leigh Waters, full-arm-extension two-handed finish (≈9:09 → extracted 545–553 s)

**What it is.** ALW drives a two-handed ball and **finishes with both arms fully
extended** through the line of the shot — the "magic" Gary flagged. Full extension =
the paddle stays on the ball longer through the contact zone, which is where the pace,
depth, and control come from. Note also Gary's point: **both players stay engaged and
ready until the ball stops coming back** — no admiring the shot.
Sequence: `shotI_sequence.jpg`; hero: `shotI_alw-2hand-extension-finish_contact.jpg`;
clip (local): `shotI_alw-2hand-extension.mp4`.

**Kinetic chain (copyable cues):**
1. **Coil then drive from the trunk** — power starts in the legs/hips, not the arms.
2. **Two hands through contact** — the off-hand drives the face *through* the ball, not
   around it; contact in front.
3. **Extend fully toward the target** — both arms reach out long after contact (the
   "finish"); this keeps the paddle on-line longer and is what makes the ball heavy and
   accurate. Short-arming it kills the pace.
4. **Reset instantly, stay engaged** — recover to ready; the point isn't over until the
   ball doesn't come back.

**Drill it:** on every two-handed drive, exaggerate the **finish** — reach the paddle
toward your target and hold it a beat. Pace comes from extension through the ball, not
from a violent short swing.

---

## Shot J — Ben Johns, shortened two-handed backhand under pressure (≈10:26 → extracted 626–634 s)

**What it is.** Johns is **late / jammed** — the ball is on him faster than a full swing
allows. Instead of reaching or flailing, he **shortens his two-handed backhand to a
compact punch-block**, taking the ball close and in front, and still redirects it
cleanly. The lesson is damage control: when you're late, *subtract backswing*.
Sequence: `shotJ_sequence.jpg`; hero: `shotJ_johns-shortened-2hbh_contact.jpg`;
clip (local): `shotJ_johns-shortened-2hbh.mp4`.

**Kinetic chain (copyable cues):**
1. **Recognize "late" instantly** — no time for a takeback, so there *is* no takeback.
2. **Compact two-hand block in front** — paddle stays in front of the body, both hands
   firm; the two-handed grip gives a stable face with almost no swing.
3. **Absorb + redirect, don't swing** — he meets the ball early and lets its own pace do
   the work, steering it back deep/low rather than trying to crush it.
4. **Quick reset** — compactness keeps him balanced to continue the exchange.

**Drill it:** practice a no-backswing two-handed backhand block off fast feeds — contact
in front, firm face, zero takeback. This is the shot that turns "I got jammed" into a
neutral reset instead of an error.

---

## Shot K — Anna Leigh Waters, jumping two-handed backhand (≈10:46 → extracted 642–650 s)

**What it is.** ALW **leaves the ground** to take a high/wide ball with a two-handed
backhand — jumping to reach a ball she couldn't handle flat-footed and still drive it.
Gary's honest caveat applies: *not sure an amateur can copy this one* — it's an
athletic, high-risk shot. Catalogued for completeness, not as a build priority.
Sequence: `shotK_sequence.jpg`; hero: `shotK_alw-jumping-2hbh_contact.jpg`;
clip (local): `shotK_alw-jumping-2hbh.mp4`.

**What to actually take from it (not the jump):**
1. **Two-handed backhand reach** — two hands let her take a ball above the ideal strike
   zone and still control the face; the *reach + face control* is the transferable part.
2. **Explosive base** — the jump is just an extreme version of "load the legs to reach a
   tough ball." For amateurs: the takeaway is footwork to *get to* the ball, not the
   airborne finish.
3. **Skip the jump until everything else is automatic** — high reward, high error; ALW
   can do it because the fundamentals underneath are perfect.

---

## Second source — Bright/Patriquin v Dennehy/Shimabukuro (PPA Tour, full speed)

Gary's last comment pointed to a different clip:
[*Bright/Patriquin v Dennehy/Shimabukuro, Veolia Atlanta Pickleball Championships*](https://www.youtube.com/watch?v=7cc4GWlLuuw)
(PPA Tour, mixed doubles, **full-speed broadcast** — not slow-mo). **Hayden Patriquin**
is the near-court man in the black Franklin shirt; his partner Bright is to his right.
These two are about **footwork**, not stroke shape.

> Fidelity note: this is a wide broadcast angle at full speed, so the footwork reads are
> tracked from cropped near-court frame sequences (see the `shotL/M_*` tracking sheets),
> not the crisp slow-mo of the first video. Re-extract any window from the local source
> `~/Movies/sca1902-clips/source_full_7cc4GWlLuuw.mp4`.

### Shot L — Patriquin "sits middle," recovers to his side (≈1:24 → 81–86 s)

**What it is.** Patriquin holds a **central / middle position** covering the gap while
his partner works the side, and uses disciplined small steps so he can **recover to his
own side instantly** when the ball goes there. The footwork *is* the shot.
Court view: `shotL_patriquin_court-view.jpg`; footwork track: `shotL_patriquin-middle-footwork_track.jpg`;
clip (local): `shotL_patriquin-middle-recovery.mp4`.

**Copyable cues:**
1. **Hold the middle in a neutral, athletic base** — low, weight balanced, paddle out
   front; he doesn't drift or lean early.
2. **Small continuous adjustment steps + split-step** — feet keep moving in tiny
   increments and he split-steps as the opponent strikes, so he's never flat-footed or
   crossed up.
3. **Push off, don't lunge** — when the ball commits to his side he pushes off the
   outside foot and shuffles to recover position, staying square to the net.

**Drill it:** shadow-drill holding the middle: split-step on every opponent contact,
recover to a centered base after each step. The goal is to *never* be caught leaning the
wrong way.

### Shot M — Patriquin out-of-position chop step → soft-hands backhand finish (≈1:31 → 88–95 s)

**What it is.** Pulled **out of position** in a fast net exchange, Patriquin uses a
**chop step** (a quick stutter/split that re-plants the feet and kills momentum) to stop
his drift and re-establish a base, then **finishes with soft hands and a backhand taken
in front** of his body. Chop step to recover, soft hands to convert.
Footwork track: `shotM_patriquin-chopstep-bh_track.jpg`;
clip (local): `shotM_patriquin-chopstep-finish.mp4`.

**Copyable cues:**
1. **Chop step to arrest momentum** — when you're moving the wrong way, a quick
   stutter-step (chop) re-plants both feet so you can hit from balance instead of on the
   run. It buys a stable base in a half-beat.
2. **Hands in front, soft grip** — the backhand is taken **in front of the body** with
   relaxed hands so a hard ball is absorbed/redirected, not slapped.
3. **Finish from balance** — the chop step is what makes the soft-hands finish possible;
   without re-planting, that ball is a pop-up or an error.

**Drill it:** practice the chop step — sprint a couple of steps, chop-stutter to stop,
and hit a controlled backhand from the re-planted base. Pair it with the soft-hands
block (Shot H): footwork buys the position, soft hands convert it.

---

## Takeaways & app follow-ups

**For Gary's game.** Four themes run through all 14 shots: **brush for margin**
(A, C, D, E spin the ball, never flatten it); **set the base early / let the body
rotate** (B, F plant to rotate; G jumps to un-plant and rotate; same goal — the trunk
fires, not the arm); **soft hands win the reset battle** (H, I's engagement, M's
finish — relaxed grip absorbs and redirects); and **footwork buys the shot** (L, M, and
F's foot-plant — position is earned with the feet before the paddle ever matters).

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
7. **Soft reset + shortened block (Shots H, J)** — *defensive fundamentals.* Loose-grip
   absorption (H) and a no-backswing two-handed block when jammed (J) turn pressure into
   neutral resets instead of errors. High-frequency, copy these early.
8. **Footwork: hold-the-middle + chop step (Shots L, M)** — Patriquin's positional game:
   stay centered with split-steps, chop-step to recover when out of position, finish
   with soft hands in front. Footwork is the most transferable skill in the whole set.
9. **Full-extension finish (Shot I)** — reach through the ball toward the target on
   drives; pace comes from extension, not a short violent swing.
10. **Pronation jump slam / jumping 2H backhand (Shots G, K)** — *advanced/high-risk.*
    Build last. G: jump to free the hips, pronate late to redirect. K: athletic reach —
    take the footwork lesson, skip the airborne finish until everything else is automatic.

**For the pickleball-coach app (optional, not in this issue's scope):**
- The app currently models only forehand/backhand *drives*. Most shots here are
  unmodeled types — two-hand overhead (B, F, K), low roll (A), cut drop (D), backhand
  flick (E), jumping pronation overhead (G), soft reset (H), and pure-footwork patterns
  (L, M). The isolated clips are clean, single-shot exemplars — good source material for
  new `ReferenceExemplar` entries **if rights/attribution clear** (Johnkew Pickleball;
  PPA Tour — see `exemplar-rights-register.json`). Note shots L/M are *footwork*, not
  stroke shape, so they'd need a different exemplar schema than the pose-at-contact
  model. Flagging as candidates, not building here.
