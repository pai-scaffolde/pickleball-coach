# Rights Plan — Pro References and Demo Assets

Status: **active policy** · Owner: Product · Issue: SCA-1821 · Last updated: 2026-06-05

This document resolves the legal/asset path **before any public pro comparison** ships.
It is binding on every exemplar, demo, screenshot, and marketing surface for Pickleball
Coach. It is an operating policy, not formal legal advice; treat licensed-counsel review
as a gate before any public launch that touches a named athlete (see [Escalation](#escalation)).

Companion artifact: [`docs/assets/exemplar-rights-register.json`](assets/exemplar-rights-register.json)
is the source of truth for the rights status of **every** exemplar asset. No asset enters
the bundled reference library or any public surface without a row there.

---

## 1. Aspirational references only (until licensed)

The following athletes are **aspirational references only**. They may inform our internal
sense of "ideal mechanics" as a private design target. They may **not** appear — by name,
likeness, photo, video, or as a labeled comparison target — in the app, the bundled
reference library, demos, screenshots, or any marketing, until written rights are in hand.

- Ben Johns
- Hayden Patriquin
- Anna Leigh Waters
- Leigh Waters

"Aspirational reference" means: we can privately study publicly available footage to
calibrate our own thresholds and generic exemplars, but we do **not** ship their identity,
their footage, or pose tracks derived from their footage. Their names do not become UI
labels, scoring baselines presented to users, or marketing hooks ("Train like …").

Why this is restricted (plain-language, not legal advice):

- **Copyright** — video/photos of these players are owned by whoever shot them (leagues,
  broadcasters, photographers — e.g. PPA Tour, Major League Pickleball, USA Pickleball,
  or individual creators). Bundling or republishing that footage needs a license. Pose
  data **extracted from** that footage can be treated as a derivative use and is also
  subject to the source's terms of service.
- **Right of publicity / NIL** — a person's name, image, likeness, and identifiable
  identity are protected. Using them to promote a product implies endorsement and
  generally requires written consent. This is state law and varies; it is strong in
  jurisdictions like California and New York.
- **False endorsement / trademark (Lanham Act §43(a))** — using a well-known athlete in a
  way that suggests they sponsor or approve the app is actionable even without using their
  literal footage.

These four are tracked in the register with status `aspirational-reference` and usage
scope `none` — they are explicitly **not** assets until a license moves them to
`cleared-public`.

---

## 2. Safe MVP options (use these now)

These are the approved paths to obtain exemplar/reference material for the MVP without
unlicensed pro content. Each produced asset must get a register row.

| Option | What it is | Default usage scope | Rights requirement |
| --- | --- | --- | --- |
| **A. Self-recorded coach/player** | We (or a consenting coach/player) record original footage. | `public-marketing` once release is signed | Signed [talent/likeness release](#appendix-a-release-checklist) per person on camera. We own or license the footage. |
| **B. Licensed clinic footage** | Footage from a clinic/coach we have a written agreement with. | Per the license terms | Written license naming permitted uses (bundled app, marketing). No license → internal-dev only. |
| **C. Pose-only generic exemplar** | A synthetic/idealized skeleton or normalized joint track with **no real identifiable person**. Hand-authored thresholds or composited from cleared sources. | `bundled-app`, `public-marketing` | None for publicity (no person depicted). Must not be reverse-derived from a specific pro's copyrighted footage. |
| **D. Private internal research clips** | Publicly available or purchased footage used **only** to calibrate our own thresholds. | `internal-dev` **only** | Never bundled, never shown publicly, never shipped. Access limited to the team. |

Recommended MVP default: **Option C (pose-only generic exemplar)** as the bundled
reference library, calibrated privately under **Option D**, with **Option A** self-recorded
clips for demos and marketing. This keeps the shippable surface free of any third-party
rights dependency.

The MVP reference library described in `docs/MVP_PLAN.md` ("small bundled reference library
with JSON pose metrics and short annotated example clips") must be built from Option C
and/or Option A assets only.

---

## 3. What cannot appear in public UI or marketing without written rights

The following are **prohibited** on any public surface (App Store listing, website,
in-app UI shown to users, social, demo videos, screenshots, pitch decks) unless a specific
written grant covering that exact use is recorded in the register:

- A pro athlete's **name** used as a label, comparison target, scoring baseline, or hook
  (e.g. "vs. Ben Johns", "Ben Johns reference", "Train like Anna Leigh Waters").
- A pro athlete's **likeness** — photo, video frame, recognizable silhouette, caricature,
  or AI-generated lookalike.
- **Pose tracks or metrics derived from a specific identified pro's copyrighted footage**,
  when presented as the app's reference or attributed to that pro.
- **Third-party footage** (broadcast, league, tournament, another creator's clip) without
  a license covering the intended use.
- **Logos and marks** of leagues, tours, brands, or sponsors (PPA, MLP, USA Pickleball,
  paddle/apparel brands), including on courts/apparel visible in footage.
- Any framing that **implies endorsement, sponsorship, or affiliation** by an athlete,
  league, or brand that has not granted it in writing.
- **Medical-grade or professional-coaching-accuracy claims** (already barred by `AGENTS.md`;
  restated here because marketing copy is the usual leak point).

Allowed on public surfaces (with the corresponding register status `cleared-public`):

- Generic pose-only exemplars (Option C).
- Self-recorded footage with a signed release (Option A).
- Licensed footage within the bounds of its written license (Option B).
- Aggregate/anonymized "ideal mechanics" presented without attribution to a named person.

When in doubt, the asset is prohibited until a register row says otherwise.

---

## 4. Track rights status on every exemplar asset

Every exemplar asset — bundled clip, reference pose JSON, demo video, marketing image —
has exactly one row in [`docs/assets/exemplar-rights-register.json`](assets/exemplar-rights-register.json).

Rights status values:

| `rights_status` | Meaning | Allowed usage scopes |
| --- | --- | --- |
| `cleared-public` | Written rights cover public/marketing use of this asset. | any, up to the grant |
| `cleared-internal` | Usable for development/calibration only; not bundled, not public. | `internal-dev` |
| `pending` | Rights requested / under negotiation; not yet granted. | none until cleared |
| `aspirational-reference` | A named target we study privately; **not** a shippable asset. | `none` |
| `prohibited` | Must not be used in any shipped or public form. | `none` |

Required fields per asset row: `id`, `description`, `asset_type`, `source`,
`rights_holder`, `usage_scope`, `rights_status`, `license_ref`, `expiry`, `owner`, `notes`.

Rules:

- **No row, no ship.** CI/review should reject any bundled asset or public screenshot whose
  source asset lacks a register row with a usage scope that permits the surface it appears on.
- An asset's `usage_scope` must be **≤** what its `rights_status` permits (table above).
- `license_ref` must point to the actual signed release / license / written grant (path or
  link) for anything `cleared-public` or `cleared-internal` that came from a third party.
- Re-verify rows with an `expiry` before any release after that date.
- Changing a row from a restricted status to `cleared-public` requires the `license_ref` to
  exist first.

---

## Escalation

Before any public launch, marketing campaign, or partnership that depends on a named
athlete, league, or brand: route through licensed counsel and record the written grant in
the register. This document and the register are the engineering-side gate; counsel sign-off
is the legal-side gate. Do not treat this plan as a substitute for that review.

---

## Appendix A — Release checklist (Option A, self-recorded)

Minimum before footage of a real person ships publicly:

- [ ] Signed talent/likeness release naming Pickleball Coach and permitted uses
      (in-app, App Store, web, social, ads), perpetual or with a tracked `expiry`.
- [ ] Confirmation the person owns/cleared anything branded on camera (apparel, paddle,
      court signage) or that branding is removed/obscured.
- [ ] For a minor: parent/guardian signature.
- [ ] Stored copy of the release; path recorded in the asset's `license_ref`.

---

## Related

- `docs/MVP_PLAN.md` — out-of-scope explicitly lists "Bundled unlicensed pro footage".
- `AGENTS.md` — "Do not use unlicensed pro footage as bundled commercial reference material."
- `docs/assets/exemplar-rights-register.json` — per-asset rights tracking (source of truth).
