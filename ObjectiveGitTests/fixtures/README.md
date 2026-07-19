# Test fixtures

`fixtures.zip` contains the repositories the specs unpack into a per-run
temporary directory (see `QuickSpec+GTFixtures`).

When regenerating the archive, do not include symbolic links whose targets
resolve outside the extracted directory. Historical fixtures contained
absolute symlinks into `/Applications/GitHub.app/...`; SSZipArchive refuses to
extract such links ("escapes target directory"), which breaks every spec. The
archive was repacked in July 2026 with those links replaced by empty files —
keep it that way.
