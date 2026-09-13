# Contributing

Use a macOS 14+ development machine and a Swift 5.9+ toolchain (Swift 6 recommended).
Run `swift test`, `python3 scripts/check-public.py`, and `bash scripts/build-app.sh` before a pull request.

Keep the boundaries between Core, Mac, Storage and App. Add new operations as separate strategies with their own preview and approval contract; never silently widen an existing cleanup plan. Add a regression test for safety fixes. SQLite schema changes require a new numbered migration; never edit a published migration.

Tests and screenshots must use synthetic folders only. Do not attach your settings database, user paths, documents, logs with private filenames or credentials. The native Trash smoke test is opt-in: `BTOFOLDERLOOP_NATIVE_TRASH_TEST=1 swift test --filter StorageAndNativeTests/testNativeSingleAndCascadeTrashWithOriginalFilePreserved`. It creates three synthetic empty folders and leaves them in Trash; it never empties Trash.

Contributions must be compatible with GPL-3.0-or-later. Include `SPDX-License-Identifier: GPL-3.0-or-later` in new source files. By contributing, you license your contribution under the project's license. Do not copy private or incompatible third-party code.
