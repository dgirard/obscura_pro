# Obscura Pro

A macOS culling application for the Leica Q3, written in Flutter.

It reads an SD card straight out of the camera, builds a grid from the previews
already embedded in the DNG files, and lets you go through a session at speed:
arrow keys to move, Enter to open, Delete to mark, then one atomic pass to
empty the trash and eject.

**Status: in development.** Units U1–U6 are implemented and tested — the app can
open a card, catalogue it, and produce thumbnails. The grid, the viewer, and
deletion (U7–U10) are not built yet, so there is no usable UI at this point.

## The rule the whole project is built around

**The card is read-only, and it must come out of the Mac exactly as the camera
left it.**

That is not a preference, it is the requirement everything else bends to:

- Strict DCF 2.0 respect. No file or folder is ever renamed, renumbered or moved.
- Zero parasite files. No `.DS_Store`, no `._*`, no Spotlight index.
- The card is never written to, with exactly one exception: deleting a
  photograph the user asked to delete.
- The camera's `PRIVATE/` folder is never touched — it is the body's own
  bookkeeping, and a real Q3 card has one even though the spec said it would not.
- All application state — catalogue, thumbnail cache, crop rectangles, layers —
  lives on the Mac. Nothing the app invents ever lands on the card.

Anything that reads a card in the test suite is gated behind an environment
variable and is read-only, and card integrity is verified afterwards.

## Why it is fast

A Q3 DNG already contains three encoded JPEG previews — 720 × 480, 1620 × 1080,
and a 9520 × 6336 frame. Nothing in this app ever demosaics a RAW file to put a
photograph on screen. The grid decodes the 720 × 480 stream, whose short side
already exceeds a Retina grid cell, so filling the first row never reaches for
the 60 Mpx one.

Measured on a real card (941 DNG + 941 JPG, USB, **debug** build — release is
faster, the JPEG decoder is pure Dart and gains most from AOT):

| | |
|---|---|
| Header scan | 2.0 ms per file |
| First 6 grid cells, cold | 257 ms (budget: 500 ms) |
| Per cell, cold | 59 ms |
| Per cell, from disk cache | 0.45 ms |
| Thumbnail cache for a full card | 78 MB |

More detail, and what a real card contains that the spec did not model, is in
[`test/fixtures/README.md`](test/fixtures/README.md).

## Layout

```
lib/
  app/                  shell, theme, keyboard shortcuts
  features/
    volume_select/      choosing and holding an SD card
    catalog/            DCF scan, photo entities, stable keys
    grid/               thumbnail service, full-preview memory budget
  infra/
    card_access/        security-scoped bookmarks, mount/unmount, eject
    db/                 Drift schema, DAOs, migrations
    preview/            TIFF/IFD parsing, decode isolate pool, disk cache
docs/
  plans/                the implementation plan being executed
  reference/            product spec and design system
```

## Running it

Requires Flutter 3.41+ and a Mac.

```sh
flutter pub get
flutter test
flutter run -d macos
```

Code generation (Drift) after touching a table or DAO:

```sh
flutter pub run build_runner build
```

Hardware tests are skipped unless you point them at a mounted card:

```sh
Q3_DIR=/Volumes/<card> flutter test test/features/grid/thumbnail_benchmark_test.dart
```

Sample DNG files are deliberately not committed — one is about 80 MB and would
live in the history forever. The parser tests forge their own TIFF bytes instead.
