# Test fixtures — preview extraction (U2)

## State of this unit

U2 was planned as a spike against an authentic Leica Q3 `.DNG`. **No Q3 DNG has
been available on this machine**, so what shipped is the parser and extractor
(`lib/infra/preview/`) plus a suite that runs entirely on fixtures forged
byte-for-byte in `test/infra/preview/tiff_fixture.dart`.

That suite proves the parser handles the *format*. It cannot prove anything
about a Q3 file in particular. Everything below is **unmeasured** — not
estimated, not inferred, not derived from the spec. Nothing in the app should
cite these as facts until someone has run them against a real card.

No sample DNG is committed here: a Q3 raw is ~85 MB and does not belong in git.
Drop one in this directory when you have the card — and add an ignore rule for
it first, because `.gitignore` does not currently cover `*.DNG`.

## Checklist — needs a real Q3 DNG

- [ ] **Pixel dimensions of every embedded preview.** How many preview streams a
      Q3 DNG actually carries, and the width/height of each. The app assumes at
      least two (a small one for the grid, a full-size one for the viewer); if
      the full-size preview turns out not to exist, that is the plan's stop
      condition (KTD-1 collapses and the viewer has nothing to show).
      *Unmeasured.*

- [ ] **Header prefix size.** `kHeaderPrefixBytes` in
      `lib/infra/preview/preview_extractor.dart` is currently 256 KiB, a
      placeholder. The real value is the smallest prefix that covers IFD0, the
      SubIFD chain, the EXIF IFD and every preview offset in one read. Measure
      it by feeding growing prefixes to `scanPhotoHeader` until it stops
      returning `PreviewScanNeedsMoreBytes` — the result names the byte count it
      wants, so this is a loop, not a guess. *Unmeasured.*

- [ ] **Scan time for a few hundred files at that read size.** The catalog scan
      (U5) does one bounded read per file off an SD card over a USB reader; the
      number that matters is wall-clock time for ~300 files on the real card,
      not on an SSD copy. *Unmeasured.*

- [ ] **Whether the `image` package can re-embed the essential EXIF tags into an
      exported JPEG.** U11 exports crops from the full-size preview and must
      carry `DateTimeOriginal`, the body serial, focal length, shutter, aperture
      and ISO into the output. If `image` cannot write them back, the fallback
      has to be picked before U11 starts. *Unverified.*

- [ ] **Byte order and tag layout as Leica actually writes them.** The fixtures
      exercise both `II` and `MM`, `JPEGInterchangeFormat` and single-strip
      `StripOffsets`, and both serial tags (`BodySerialNumber` 0xA431 and DNG's
      `CameraSerialNumber` 0xC62F). Which combination a Q3 uses is unknown; the
      extractor accepts all of them, so this is a confirmation, not a risk.
      *Unobserved.*

## How to run the checks once a DNG is available

The extractor is pure Dart over a byte prefix and has no Flutter dependency, so
a real file can be dropped straight into a test:

```dart
final file = File('test/fixtures/L1000001.DNG');
final length = file.lengthSync();
final prefix = file.openSync().readSync(kHeaderPrefixBytes);
final result = scanPhotoHeader(prefix, fileLength: length);
```

`result` is one of `PreviewScanSuccess`, `PreviewScanNeedsMoreBytes` (grow the
prefix and retry — it names the byte count) or `PreviewScanFailure`.
