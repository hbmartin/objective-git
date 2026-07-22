# Upgrading from the previous fork

This guide covers migrating from the previous fork of ObjectiveGit (the
`gitx/objective-git` lineage, up to commit `85e73a6a`) to this fork. The
headline change is the upgrade of the bundled libgit2 from **0.28.5 to
1.9.6**, along with a move to Apple Silicon–only builds, XCFramework
packaging for the iOS dependencies, and a round of defensive hardening at
the libgit2 boundary.

At a glance:

| Area | Before (`85e73a6a`) | Now |
| --- | --- | --- |
| libgit2 | 0.28.5 | 1.9.6 |
| Architectures | x86_64 + arm64 | arm64 only |
| iOS dependencies | fat static libraries | XCFrameworks (device + simulator slices) |
| libgit2 init failure | silently ignored | logged, then `abort()` |
| Deployment targets | iOS 12.0 / macOS 13.0 | unchanged |

## 1. Platform and packaging changes

### Apple Silicon only

All targets now build exclusively for arm64 (`VALID_ARCHS = arm64`, with
`ARCHS` pinned to arm64 for the macOS and iOS Simulator SDKs). This means:

- Intel Macs are no longer supported, and an x86_64 host app (including one
  running under Rosetta) cannot link or load the Mac framework.
- The iOS Simulator is supported only on Apple Silicon.
- Building the framework from source requires an Apple Silicon host;
  `script/update_libgit2` fails fast with an error on Intel machines.

If your app still ships a universal (x86_64 + arm64) binary, you will need
to either drop the Intel slice or stay on the previous fork for that
configuration.

### iOS dependencies are XCFrameworks

libgit2, libssh2, and OpenSSL (libssl/libcrypto) for iOS are now built as
XCFrameworks under `External/build/` instead of fat static libraries.
Because XCFrameworks keep device and simulator slices separate:

- No simulator-slice stripping is needed before App Store submission. If
  your build pipeline runs a strip-frameworks script (e.g. Realm's
  `strip-frameworks.sh`) against ObjectiveGit's dependencies, remove that
  step.
- If you build the dependencies yourself, the `IOS_ARCHS` environment
  variable is no longer used. Use `IOS_SLICES` instead, with
  `<platform>:<arch>` pairs, e.g.
  `IOS_SLICES="iphoneos:arm64 iphonesimulator:arm64"` (that value is the
  default).

## 2. Compile-time API changes

### Transfer-progress blocks use `git_indexer_progress`

libgit2 renamed `git_transfer_progress` to `git_indexer_progress` (the
struct layout is identical). Every ObjectiveGit progress block that took a
`const git_transfer_progress *` now takes a `const git_indexer_progress *`:

- `+[GTRepository cloneFromURL:toWorkingDirectory:options:error:transferProgressBlock:]`
- `-[GTRepository fetchRemote:withOptions:error:progress:]`
- `GTRemoteFetchTransferProgressBlock` (used by `-[GTRepository pullBranch:fromRemote:withOptions:error:progress:]`)

In Objective-C, update explicitly typed blocks:

```objc
// Before
^(const git_transfer_progress *progress, BOOL *stop) { ... }

// After
^(const git_indexer_progress *progress, BOOL *stop) { ... }
```

The field names (`total_objects`, `received_objects`, `received_bytes`,
etc.) are unchanged, so only the type name needs to change.

In Swift, closures with inferred parameter types keep compiling as-is; you
only need changes where you spelled out `UnsafePointer<git_transfer_progress>`
(replace with `UnsafePointer<git_indexer_progress>`).

### Conflict enumeration entries are now nullable

`-[GTIndex enumerateConflictedFilesWithError:usingBlock:]` now declares its
block parameters as `GTIndexEntry * _Nullable`. This reflects reality: in
add/add or modify/delete conflicts, one or more sides (including the
ancestor) genuinely have no entry, and the previous fork could hand your
block an invalid object in those cases.

```objc
[index enumerateConflictedFilesWithError:&error
                              usingBlock:^(GTIndexEntry * _Nullable ancestor,
                                           GTIndexEntry * _Nullable ours,
                                           GTIndexEntry * _Nullable theirs,
                                           BOOL *stop) {
    NSString *path = ours.path ?: theirs.path ?: ancestor.path;
    ...
}];
```

This is a source break for Swift callers: the closure parameters become
optionals (`GTIndexEntry?`), so member access needs `?`/`!` or an unwrap.

Relatedly, `-[GTRepository contentsOfDiffWithAncestor:ourSide:theirSide:error:]`
now accepts nil for any of the three entries (so you can pass through
whatever the enumeration block gave you), but asserts that at least one is
non-nil.

### `GTCredential` uses `git_credential`

libgit2 renamed `git_cred` to `git_credential` and `git_credtype_t` to
`git_credential_t`. Accordingly:

- `-[GTCredential git_cred]` now returns `git_credential *` (the method
  name is unchanged).
- `GTCredentialAcquireCallback` takes `git_credential **`.
- The `GTCredentialType` enum cases keep their names and raw values; only
  the underlying constants changed (`GIT_CREDTYPE_*` → `GIT_CREDENTIAL_*`).

Code that only uses the `GTCredential` / `GTCredentialProvider` Objective-C
API needs no changes; only code touching the raw `git_cred` type must
rename it.

### Smaller signature changes

- `-[GTDiffPatch patchData]` is now `NSData * _Nullable` and returns nil if
  generating the patch fails (previously it could return garbage data built
  from an error result).
- `+[GTReference isValidReferenceName:]` accepts a nullable name and
  returns `NO` for nil.
- `-[NSData git_buf]` documents that the returned buffer *borrows* the
  receiver's storage and must never be passed to `git_buf_dispose()`.
  `+[NSData git_dataWithBuffer:]` now copies the buffer's contents and
  disposes/resets the source buffer for you.
- `GIT_TRANSPORTFLAGS_NONE` was removed from libgit2's public headers;
  ObjectiveGit defines it locally, so `GTTransportFlagsNone` keeps working
  with no changes on your side.

## 3. Runtime behavior changes

### Failed libgit2 initialization aborts the process

The framework constructor previously ignored the result of
`git_libgit2_init()`; a failure would surface later as crashes or undefined
behavior deep inside libgit2. It now logs the failure and calls `abort()`,
because no ObjectiveGit call is safe after a failed initialization.

On success, one default-level line is written to the unified log with the
libgit2 version and enabled features. Both messages use the log subsystem
`org.libgit2.objective-git` (category `init`), which you can filter in
Console.app or with `log stream` for support diagnostics.

### Credential callback error reporting

The credential-acquisition path validates its inputs and reports failures
with libgit2 1.x error classes (`GIT_ERROR_CALLBACK`, `GIT_ERROR_INVALID`)
instead of the removed `GIT_EUSER` class. If you match on the error strings
or classes surfaced from failed fetch/push/clone authentication, re-test
those paths.

### Merge conflict reporting

When `-[GTRepository mergeBranchIntoCurrentBranch:withError:]` fails with
conflicts, the file list attached to the error (`GTPullMergeConflictedFiles`)
now handles one-sided conflicts: each path is taken from "ours", falling
back to "theirs", then to the ancestor. Previously the code assumed "ours"
always existed, which is not true for delete conflicts.

### Reimplemented `NSData` helpers

`-[NSData git_isBinary]` and `-[NSData git_containsNUL]` no longer call
libgit2 (the underlying APIs were removed from libgit2's public surface).
They are reimplemented locally with the same heuristics, so results are
unchanged, including for empty data.

## 4. If you call libgit2 directly

ObjectiveGit deliberately exposes raw libgit2 handles
(`-[GTRepository git_repository]`, `-[GTObject git_object]`, etc.) and its
headers import libgit2's. Any code of yours using those handles is now
compiled against **libgit2 1.9**, which renamed a large part of the API
after 0.28. Renames you are most likely to hit:

| libgit2 0.28 | libgit2 1.x |
| --- | --- |
| `git_strarray_free` | `git_strarray_dispose` |
| `git_cred_*`, `git_credtype_t` | `git_credential_*`, `git_credential_t` |
| `git_transfer_progress` | `git_indexer_progress` |
| `git_blob_create_frombuffer` / `_fromdisk` | `git_blob_create_from_buffer` / `_from_disk` |
| `git_blob_filtered_content` | `git_blob_filter` |
| `git_index_add_frombuffer` | `git_index_add_from_buffer` |
| `git_oid_iszero` | `git_oid_is_zero` |
| `GIT_OID_HEXSZ` / `GIT_OID_RAWSZ` | `GIT_OID_SHA1_HEXSIZE` / `GIT_OID_SHA1_SIZE` |
| `git_reference_is_valid_name` | `git_reference_name_is_valid` (out-parameter) |
| `git_remote_is_valid_name` | `git_remote_name_is_valid` (out-parameter) |
| `git_*_init_options` | `git_*_options_init` |
| `GITERR_*` error classes | `GIT_ERROR_*` |

The bundled libgit2 is built with deprecated APIs still available (the old
names live in `git2/deprecated.h`, and `GIT_DEPRECATE_HARD` is not
defined), so much legacy code will keep compiling — but the old names are
gone from the primary headers and can be removed upstream at any time, so
migrate as you touch each call site. For the full story, see the upstream
release notes in the libgit2 repository (`docs/changelog.md`, versions
1.0 through 1.9).

## 5. Building from source and running tests

Only relevant if you build the framework yourself rather than consuming a
release binary:

- `script/bootstrap` then `script/update_libgit2` (macOS) or
  `script/update_libgit2_ios` (iOS) as before. Builds are cached; the cache
  key now includes the architecture, deployment target, and toolchain
  versions, so stale artifacts from the previous fork are rebuilt
  automatically.
- The macOS static libgit2 is built with pthreads, SecureTransport HTTPS,
  and libssh2 SSH (`-DUSE_SSH=libssh2`); Homebrew `libssh2` is required on
  the host.
- The test-fixture archive (`ObjectiveGitTests/fixtures/fixtures.zip`) was
  repacked without absolute symlinks; regenerate fixtures the same way if
  you modify them, or the upgraded SSZipArchive used by the test suite will
  refuse to extract them.
