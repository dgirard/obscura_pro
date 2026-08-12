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

Nothing. The exports viewer requested on 2026-08-12 is below, under Decided.

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
- **U13 — a guide on a real photograph.** Place the spiral on a frame at fit and
  at 400 %, drag it, take a corner, toggle obscura, and watch whether the
  handles stay under the pointer. The coordinate stack is tested at every step;
  what a test cannot say is whether it *feels* attached.
- **U14 — AE3 across a real eject and remount.** Compose on a frame, eject,
  put the card back (ideally in another reader, at another mount point), and
  reopen the same photograph. The unit test proves the key does not depend on
  the path; only the card proves the key survives the round trip.
- **The Finder channel, on a signed build.** Revealing an export and moving one
  to the Trash both go through `NSWorkspace` and `FileManager.trashItem`, which
  the sandbox allows for files under `~/Pictures` — the entitlement is there.
  Neither can be exercised headlessly: a test can only check that the app asked.
- **The launch-time reopen, on a signed build.** The order — scope first, then
  look at the card — is what makes it work under the sandbox, and no test can
  prove that: `RecordingBridge` grants everything it is asked for. Quit with a
  card open, relaunch, and the grid should come back with no panel and with last
  session's marks on it.

---

## Gaps found by building it

Ordered by how much they would cost a user.

### Orientation is applied by two copies of the same switch
`isolate_pool.dart` and `export_service.dart` each carry their own
`_applyOrientation` over the eight EXIF cases. They run in different isolates
and neither can import the other's private helper today, but the rule is one
rule and it is written twice.

### Undo still only reaches the layers
`⌘Z`/`⌘⇧Z` are global in the spec's keyboard table and are documented there as
covering *layers and marking*. U13 built the composition's undo stack and wired
those keys to it; marking has none, so on a photograph with no layers on it the
keys do nothing. Marks are written through, so the undo that is missing is a
convenience rather than a way of losing a decision — but the table promises it.

### The layers panel is a keystroke on the grid
`L` opens it in the viewer, and the viewer's action bar now carries a button for
it — but from the grid there is nothing: no way to see which photographs have a
composition on them, and no badge on a cell that carries one. The spec's grid
badges list RAW+JPG, marked and cropped/exported; a composed frame is not among
them and arguably should be.

### An export is listed but not searchable
The exports destination lists everything this Mac has exported, grouped by the
dated folder it went into. On a long-running library that is a long list with no
filter, no search by frame, and no way to jump from an export back to the
photograph it came from — which the `crop_export` row could support, since it
holds the photo id. Fine at a session's scale; not fine at a year's.

### A guide is a judgement, not a deliverable
Composition layers are drawn over the photograph and are never burned into an
export: `ExportService` writes the crop and nothing else. That is deliberate —
what leaves the app is a photograph, not a photograph with a diagram on it —
but it does mean there is no way to hand someone the frame *with* the spiral on
it, which is a reasonable thing to want when the point is to explain a
composition. Undecided rather than refused.

### A layer is turned from the panel, not from the canvas
Rotation is a slider under the selection. The spec calls rotation optional and
the maquette shows no control for it at all; a rotation handle outside the
corner handles would be the conventional answer and is not there.

### A per-photo undo in immediate mode
Immediate mode moves the originals to the Mac as each decision is made, and
`TrashService.restoreToCard` puts them back — but it restores *everything* in
`movedToMacTrash`, in one pass, because that is the shape reconciliation needed.
There is no "put this one back", so pressing Delete on the wrong frame in
immediate mode has no single-keystroke undo. The trash screen also does not yet
list what is sitting on the Mac, so restoring is not reachable from the
interface at all. Deferred mode — the default — is unaffected.

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

### A write must never precede the read it will overwrite — 2026-08-12
Found by running the app: seventeen guides placed on one photograph came back
as one. `save` makes the stored composition match what it is handed, and the
board handed it a set of one — the guide just placed — because the read of what
was already on that photograph had not landed yet. Every row it had not been
told about was deleted, which is exactly what the method is supposed to do and
exactly the wrong thing to ask it in that moment.

Writes now wait on the read, and the snapshot is taken when the write runs
rather than when it was asked for, so what reaches the disk is the composition
as it stands once the read has merged into it. The regression test drives the
same order — open, place, then let the read land — and fails without the wait.

The sixteen rows are gone; nothing could bring them back, and the honest note is
that the app lost them.

### Crop mode shows the crop — 2026-08-12
Asked for after using it: "le recadrage ne fait pas crop d'image". The exports
were in fact cropped — the files on disk are 5039 × 7559, 2563 × 2563,
6790 × 3819 — but the screen never showed it. The photograph sat whole under a
veil from the moment crop mode opened until a file appeared in a folder, so the
rectangle read as a decoration and the export as a leap of faith.

There is now a **Recadrer** button that applies the frame to the picture on
screen, and **Modifier** to take it back off; touching a ratio, the horizon or
the orientation returns to the frame automatically, because a screen still
showing the previous crop would be the one thing this view exists not to do.
Beside it, the size of the file the export will write — from the
full-resolution frame, not from the window.

Nothing about the export changed: the rectangle was always what got cut. What
changed is that it can be seen before it is committed to.

The control bar became a `Wrap` in the same pass. It was a single row, and a
row that cannot fit drops whichever child is last — on a narrow window that is
the export button, off the edge of the screen.

### The exports have a destination of their own — 2026-08-12
Asked for the same day: an export landed in
`~/Pictures/Q3Culling/Exports/<date>/` and the only sign of it was a filename in
the crop bar. It is now the fourth entry in the sidebar — by session, newest
first, each row drawing the exported file itself with the frame it came from,
its ratio and the pixel size it came out at.

The premise turned out to be half wrong, and finding that is most of the work:
`crop_export` was described as already recording every export, and nothing had
ever written a row to it. `ExportService` produced the file and returned; the
recording is now done by the crop screen, *after* the bytes are on disk, so a
refused write cannot leave the list claiming a deliverable that does not exist.
Schema v4 adds the pixel size to that row, because the alternative is decoding
a few dozen multi-megabyte JPEGs to draw a list.

The two prohibitions hold. A file the user has moved or deleted from the Finder
is shown as moved — every row is checked against the disk as the list is built —
rather than as an error or, worse, as still being there. And nothing offers to
put an export back on the card.

Removing an export moves it to the Mac's Trash and then drops the row, in that
order: a crash between the two leaves a row this list shows as missing, where
the other order would leave a file nothing in the app remembers. `trashItem`,
not an unlink — this app deletes exactly one class of thing for good, and a JPEG
on the user's own Mac is not it.

### The Grammaire's schemas are not overlay assets — 2026-08-12
U12 expected the thirty inline SVGs of `grammaire-du-cadre.html` to be lifted
out and used as layers. They cannot be. They are teaching diagrams: each fills
its frame white, labels itself, and draws a blue blob standing in for a subject
— `Règle des tiers` marks three points of force in red because the fourth is
under the blob. Extracting them faithfully would have shipped a three-point rule
of thirds.

So the generator takes the metadata (number, names, section, and the three
fields every card carries) and `constructions.dart` builds the geometry from the
frame the guide lands on. `patterns_test.dart` pins each construction back to
the coordinates the document draws, converted out of its own viewBox — verified
against the source rather than copied from it, and the one place where the two
disagree is recorded there: the golden spiral's "eye" is drawn by hand in the
document, a little outside its own last square, and here it is the limit of the
subdivision.

The split that came out of it is fifteen and fifteen. Fifteen schemas are
constructions of the frame and can be laid over a photograph; fifteen draw a
subject — a face for "remplir le cadre", a colour wheel for the complementaries
— and a stroke colour cannot render them. Those stay in the library and open
their card instead of dropping a shape, because a photographer looking for
"espace négatif" should find it where the book has it and be told what it says.

Five of the fifteen are recomputed from the frame's proportions rather than
stored: spiral, rabatment, dynamic symmetry, the diagonal method and the golden
triangle. A shape baked at 3:2 would be wrong on every other crop the app
offers, which is what the plan's execution note warned about.

### The pattern table stops claiming to hold SVG — 2026-08-12
Schema v3. `pattern.svg` and `pattern.aspect_ratio` are gone; `pattern.kind`
says `guide` or `reference`. The spec's §7 names those two columns, and they
were written for the assumption U12 disproved: there is no path to store, and a
stored reference ratio would only be the excuse to stretch one. Rebuilding a
table is the migration that can quietly break a foreign key, so
`migration_test.dart` puts a layer instance on a pattern first and checks it
still points at the same row afterwards — which is how the missing `newColumns`
was found before it reached a database.

### A layer is written when it is placed — 2026-08-12
The composition maquette ends with a red "Enregistrer la composition" button.
There is nothing for it to do: a placement is written through the moment it is
made, the same rule marking follows and for the same reason. A button that saved
what was already saved would teach the photographer to distrust everything they
had not pressed it for. In its place is a line that says whether the writing is
working, and `LayerBoard.durable` is what it reads.

Undo is a stack of whole compositions rather than of inverse operations: a
composition is a handful of small records, and the alternative is a second
implementation of every mutation kept in step by hope. One step per gesture, not
one per frame — undoing a drag puts the guide back where it was picked up.

### The panel takes the pointer only where a guide is — 2026-08-12
The obvious build is a gesture detector over the whole photograph while the
panel is open. It wins the arena for every drag, which would take panning away
from exactly the moment it is most wanted — aligning a guide to a detail at
400 %. So the canvas refuses the hit test everywhere a guide is not, and the
drag reaches the `InteractiveViewer` underneath.

Two things a widget test found and no unit test could. A pan is not recognised
until the pointer has travelled the touch slop, so hit-testing at the start of
the *gesture* looks for the handle twenty pixels from where the finger went
down: every corner drag came out as a move. The handle is now taken at pointer
down. And each frame of a drag is computed from the placement as it was when the
drag began, not from the placement as it is: feeding the result back in maps the
pointer through a frame that has already moved, and the guide walks away from
the pointer a little more with every frame.

### A mark is written at the moment it is made — 2026-08-12
Marks lived in `markedForDeletionProvider`, in memory, and reached the trash
table only when Empty Trash ran; quitting halfway through 900 frames threw away
every decision. They are now written through as they are made, and read back at
launch.

Kept in memory *and* written through, rather than driven off a database stream:
culling is a keyboard activity and the badge has to arrive on the keystroke, not
on the write. That means the two can disagree, so `Marks` carries `durable`
alongside the keys — a write that fails does not take the decision back, it
takes back the promise that the decision will still be there tomorrow, and the
status bar and the trash screen say so. The alternative, a silent in-memory
fallback, is the one thing a tool making this promise cannot do.

Immediate mode is wired with it, because a settings screen offering a mode the
grid ignores is the same class of lie. Marking in immediate mode writes the row
first and moves the originals second: a crash between the two leaves a mark,
which is the survivable half. A refused card write leaves the frame on the card,
still marked, and says which — never "deleted".

### The card is reopened without the panel — 2026-08-12
`reopenLastCard` had been written and tested and was called by nothing, so every
launch asked for a card that had not left the reader. It is now called at
startup — and its order had to be corrected first. It inspected the card and
*then* took the security scope, which works in a test and cannot work on a
signed build: resolving a bookmark yields a URL and no access, so listing
`DCIM/` first is the call the sandbox refuses, and that refusal looks exactly
like an absent card. The feature would have shipped, fallen back to the panel
every time, and looked like it had never been wired.

### The card-open report is shown — 2026-08-12
Debris removed, foreign parasites, whether the card is writable, interrupted
operations reconciled, unresolved losses: all computed on every card open, all
read by nothing. Now a strip above the grid, worst line first and its colour
taken from that line — a loss shown in the same grey as a housekeeping note is a
loss nobody reads. Dismissible, and keyed by the report's own contents so that
putting one card's findings away does not silence the next card's.

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

Still unexposed there: nothing. Immediate mode was wired on 2026-08-12 with
persistent marking, as this note said it should be; what it still lacks is a
per-photo undo, which is above under gaps.

## Undecided, and waiting on you

### A key for removing the selected layer
`⌫` marks the photograph for deletion, in every scope, which is the right
binding for a culling tool. Making it mean "remove this guide" while a layer is
selected would put the app's most consequential key on a second meaning that
depends on an invisible state. The panel's button is the only way to take a
guide off, and that is deliberate until someone says otherwise.

### A key for the EXIF overlay
The spec's keyboard table (section 5) assigns none, so it is a visible control
only. `I` would be conventional.

---

## Not started

Nothing from the plan. U1–U14 are all built; what is left is above (an exports
viewer, the gaps) and below (the verifications that need a card).

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
