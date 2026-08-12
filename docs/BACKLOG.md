# Reste à faire

What is not done, and why it is not done. Kept here rather than in commit
messages so it can be argued with.

The implementation plan
(`docs/plans/2026-08-11-001-feat-obscura-pro-culling-app-plan.md`) is the
authority for units U1–U14. This file holds everything the plan does not: work
that was asked for later, verifications that need hardware, and gaps found by
building the thing.

---

## Asked for, not yet built

### An exports viewer
Requested 2026-08-12. Today an export lands in
`~/Pictures/Q3Culling/Exports/<date>/` and the only feedback is a filename in
the crop bar. A photographer who has just made a decision about a frame should
be able to see the result of it without leaving for the Finder.

Wanted, roughly: a fourth sidebar destination listing what has been exported —
by session, newest first — with the crop's ratio and pixel size, the ability to
open one full-frame, to reveal it in the Finder, and to delete an export that
was a mistake. The `crop_export` table already records every export with its
photo, ratio, rectangle and path, so the data is there; nothing reads it back
yet.

Two things it must not do: pretend an export still exists when the user has
moved or deleted it behind the app's back, and offer to "restore" an export to
the card. Exports are Mac-side deliverables and the card is not their home.

---

## Owed verifications

These need a real card and a person. None of them can be run headlessly, and
several need a card whose contents are expendable.

- **U7 — 60 fps grid scroll.** Release build, DevTools frame chart, a real
  941-frame session. The cold-decode figures are measured; the scroll is not.
- **U8 — next/previous under 100 ms perceived, zoom at 60 fps.** Release build.
- **U9 — AE1 and AE2 on a sacrificial card.** A full culling session ending in
  Empty Trash, and a card physically pulled during an Empty Trash in progress.
  The fault-injection suite simulates the second at every step boundary, which
  is not the same as doing it.
- **U10 — Phase A exit benchmark.** A full session, then `ls -la@` on the volume
  showing zero parasite files, then the card back in the Q3 booting with its
  numbering intact. This is the gate the plan sets for Phase A being real.
- **U11 — AE4.** Partly done: an exported file was checked and carries the right
  model, date and ISO. Still to do on a real card end to end.

---

## Gaps found by building it

Ordered by how much they would cost a user.

### The card-open report is computed and never shown
`cardOpenProvider` returns debris removed, foreign parasites found, whether the
card is writable, how many interrupted operations were reconciled, and any
unresolved losses. Nothing reads it. Every one of those is something a
photographer is entitled to see, and the loss list especially: it is the single
case the app admits it cannot repair.

### Orientation is applied by two copies of the same switch
`isolate_pool.dart` and `export_service.dart` each carry their own
`_applyOrientation` over the eight EXIF cases. They run in different isolates
and neither can import the other's private helper today, but the rule is one
rule and it is written twice.

### Marking does not survive a relaunch
The grid and viewer record marks in memory (`markedForDeletionProvider`), and
`TrashService` writes them to the database only when Empty Trash runs. Close the
app halfway through culling 900 frames and the decisions are gone. The trash
table and its state machine are built and tested; nothing has been wired to
write a mark at the moment it is made.

### The card must be picked again every launch
`CardAccessService.reopenLastCard` exists, is tested, and is never called.
Security-scoped bookmarks are minted on every open, so the machinery to reopen
last session's card without the panel is present and unused.

### A JPG-only card gets soft thumbnails
A Q3 JPEG's only embedded preview is the 160 × 120 EXIF thumbnail, and its only
larger source is the 39 Mpx frame — over the escalation budget. Fixing it needs
a scaled JPEG decode (the DCT 1/2, 1/4, 1/8 modes the pure-Dart decoder does not
expose), not a bigger budget. RAW+JPG and RAW-only cards are unaffected.

### Durability is app-crash-safe, not power-loss-safe
`F_FULLFSYNC`, directory `fsync` and `statfs` all need FFI to libc, which is not
written. KTD-14 already states the honest claim and the code says so where it
matters; what protects the data is the read-back-and-hash, not the flush.

### The Inter font is named but not bundled
`theme.dart` specifies it; the asset is not in the repository, so text falls
back to the system font. Sizes, weights and tracking are already final.

### No focus-visible treatment on crop controls
Keyboard focus is invisible on the ratio buttons and the straighten slider. The
design system defines a focus ring; it is not applied there.

### An unsaved crop is lost on navigate-away
Leaving crop mode without exporting discards the rectangle silently. Whether it
should be kept per photograph is a product question, not a bug — but it is
undecided rather than decided.

---

## Decided

### The straightened frame is the canvas of record — 2026-08-12
`CropRect.rect` was already documented as living in the normalized space of the
*straightened* frame, but the crop screen built its `ViewTransform` from the
unrotated aspect, so the overlay, the corner hit-testing and the export each
worked in a slightly different space once the horizon came off zero. The
alternative was to keep the unrotated frame authoritative and convert at the
export boundary; `ratio.dart` already committed to the other answer, and one
canvas that everything shares beats two that have to be kept in step.

### The Spotlight switch actually writes the marker — 2026-08-12
It was inert: the control said it would write `.metadata_never_index` at card
open and `SpotlightPolicy.optIn` had no caller anywhere. The choice was to wire
it or to relabel it as not yet active. Wired, because the switch is off by
default, states its cost on both sides, and turning it on is an explicit
instruction about the user's own card — and because a settings screen whose
whole purpose is saying what the app does to a card must not be the thing that
lies about it. Written only when absent, so an opted-in card is not written to
on every open.

### Video is ignored — 2026-08-12
Not catalogued, not shown, not deleted. The settings screen counts the ignored
files and names the first few, so a card reporting "0 photographs" cannot leave
anyone thinking it is empty. Silence about a card's contents was the one option
that was not defensible.

### Settings live in their own screen — 2026-08-12
Export folder, deletion mode, and the Spotlight tradeoff. Each is stated with
its cost on both sides rather than presented as a switch with a good side and a
bad one. Stored as JSON beside the bookmarks, readable in a text editor.

Still unexposed there: nothing, for now. `TrashService`'s immediate mode is
selectable but the grid does not yet act on the choice — the same wiring gap as
persistent marking, and it should be closed with it.

## Undecided, and waiting on you

### A key for the EXIF overlay
The spec's keyboard table (section 5) assigns none, so it is a visible control
only. `I` would be conventional.

---

## Not started

- **U12** — the 30 Grammaire-du-cadre patterns as typed vector data.
- **U13** — the layer canvas: placing, moving, resizing composition guides.
- **U14** — the layers panel and per-photo persistence.

---

## Reviewed

`ce-code-review` was run on 2026-08-12 over `HEAD~10..21b956e` — 27 files, ~5900
lines — with correctness, testing, maintainability, performance and reliability
reviewers plus an independent validation pass. Fourteen findings, all validated,
all fixed in the two commits that follow it.

Two things that review is owed:

- **The cross-model adversarial pass produced nothing.** The Codex peer ran but
  its CLI hung on a stale Vim swap file at `~/.codex/.instructions.md.swp`, and
  because a started peer replaces the in-process fallback, no adversarial
  reviewer covered this diff at all. The "what else could go wrong here" lens is
  the one that is missing. Worth re-running once that file is deleted.
- **Requirements completeness was not checked.** No plan was passed and the
  branch name yields no keywords, so the R/U coverage of
  `docs/plans/2026-08-11-001-feat-obscura-pro-culling-app-plan.md` against the
  code is still unverified. Re-run with `plan:<that path>`.

What the review found is worth recording, because two of the three worst
findings were invisible to a suite of 367 passing tests:

- A cast across two sealed hierarchies (`VolumeGone` into `CopyOutcome`) that
  compiled cleanly and threw at runtime on exactly the pulled-card path the
  module exists to survive. No test reached it, because a test cannot mount and
  pull a real volume — so `TrashService` now takes injectable stand-ins for its
  two card operations, and the `VolumeGone` arms are finally exercised.
- A fault-injection test that filtered its list by the predicate it then
  asserted, so it could not fail. It was the only guard on debris left by the
  one path that writes a photograph to a card.
- An export that straightened the opposite way from the preview. Every existing
  straightening test still passed: the crop shrank, kept its ratio and had no
  black corner — all true of a rotation the wrong way round.
