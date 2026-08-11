# Preview fixtures

The parser tests forge their own TIFF/DNG bytes in `tiff_fixture.dart`. That
proves the reader handles the format's grammar — both byte orders, SubIFD
chains, strip-encoded previews, truncation, cyclic chains — without needing an
80 MB file in the repository.

What forged bytes cannot say is what a genuine Leica Q3 file actually contains.
Those figures are below, and they were measured, not estimated.

## Measured on real hardware

Leica Q3, body serial `REDACTED`, card written 2026-04, exFAT, 941 DNG + 941 JPG
(plus 2 MP4) in `DCIM/100LEICA`. Reproduce with:

```
Q3_DIR=/Volumes/<card>/DCIM/100LEICA flutter test \
  test/infra/preview/q3_measurement_test.dart
```

### Embedded preview streams

Every DNG carries three, all strip-encoded (`jpegStrips`), all with the
reduced-resolution bit set:

| Role | Dimensions | Size |
|---|---|---|
| Grid thumbnail | 720 × 480 | 0.16 MB |
| Intermediate | 1620 × 1080 | 0.75 MB |
| Viewer / export source | 9520 × 6336 | 13.71 MB |

The full-resolution stream confirms the premise the whole app rests on: a
60.3 Mpx encoded frame is already in the file, so nothing ever has to demosaic
the RAW to put a photograph on screen.

Note that all three streams are reached through `StripOffsets`/`StripByteCounts`,
not `JPEGInterchangeFormat`. This is why the photometric-interpretation check in
`preview_extractor.dart` is load-bearing rather than defensive: the raw CFA image
is also strip-encoded with `Compression 7`, so without it the mosaic would be
handed to a JPEG decoder as if it were a picture.

### Header read size

8 KB resolves the stable-key EXIF fields and all three preview ranges on
**941 of 941 files**. `kHeaderPrefixBytes` is set to 16 KB for margin against
other bodies and firmware.

### Scan cost

941 files, headers only, read from the card over USB:

| Read size | Total | Per file |
|---|---|---|
| 8 KB | 1840 ms | 2.0 ms |
| 64 KB | 2325 ms | 2.5 ms |

(A 16 KB pass measured 174 ms, but it ran after the 8 KB pass and was reading a
warm page cache — treat ~2 ms/file as the cold figure.)

Filling the grid's first row needs only the first handful of headers, so
PERF-1's "first row under 500 ms" has a wide margin.

### Stable-key fields

`DateTimeOriginal` and the body serial are both present and readable from the
bounded header read, so the composite photo key is computable during the scan
without a second pass.

## What a real card contains that the spec does not model

Two findings from the same card that reach beyond the preview pipeline:

- **`PRIVATE/` exists at the volume root** — `META_001.DAT`, `META_002.DAT`,
  `FASTLOAD.DAT`, and a `TEMP/` holding `.CPC`/`.CPG` files. The origin spec
  states the camera writes no annex files. It does. The catalog must ignore this
  folder, and deletion must never touch it: it is the camera's own bookkeeping.
- **Video files share the card** — 2 `.MP4` alongside the stills. The
  DNG-plus-JPG entity model does not cover them, so the scan has to decide
  whether they are catalogued, shown, or skipped.

Both belong to the catalog and deletion units, not to preview extraction.

## Sample files

Sample DNG/JPG files are deliberately not committed — one DNG is ~80 MB and
would live in the history forever. `.gitignore` excludes `*.DNG`, `*.dng` and
`test/fixtures/samples/`; copy a file there locally if you want one at hand.
