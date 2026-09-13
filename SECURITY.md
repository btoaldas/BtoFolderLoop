# Security and privacy

Folder analysis and cleanup operate locally. The app has no login or telemetry and never uploads files, paths, journals or system profiles. An ephemeral HTTPS client checks published GitHub releases; pinned Sparkle validates and installs updates only after the user clicks the update button. Only a public Ed25519 verification key ships with the app. The private update-signing key remains in the maintainer's Keychain. Native macOS permissions remain in effect. Never grant extra permissions simply to silence an error; choose a folder the app can inspect.

The local SQLite file contains mode settings, timestamps, source/destination directory paths, operation state and error details. It is not encrypted by the app; the macOS user account and disk protection apply. It is created with user-only permissions and is never uploaded. History supports recovery. In 0.3.0, completed consistent operations expire after 180 days by default; running, interrupted, errored and inconsistent records remain protected. Settings expose retention before changes are applied. Diagnostics default to 30 days / 10 MiB and carry allow-listed codes without paths. The interface shows 200 recent runs/folders and pages through 200 events at a time. Migration first creates a separate local SQLite backup, which does not expire automatically. History expiration does not modify source folders or Trash, but removes expired recovery paths. Do not post that database publicly.

## Filesystem boundaries

- Every explicitly chosen root (including nested roots), files (including hidden files), symbolic links, packages, repository internals, filesystem/system folders and inaccessible entries are preserved.
- Only user-supplied Finder aliases and symbolic links are resolved to real local directories before scanning; the original shortcut is preserved. Broken links, cycles, files and protected targets are rejected. Duplicate/overlapping inputs do not produce duplicate candidates. Batch execution stops globally on error/cancellation and keeps a separate journal per top-level root.
- Targets of symbolic links discovered inside the scanned tree and their ancestors are preserved. References from outside the selected tree, Finder alias files and application-specific absolute paths cannot be inferred by this scanner.
- A preview is immutable and defines the maximum approved set. New folders require another scan and approval.
- Root, parent and candidate identities and emptiness are checked again before each native Trash move. The destination identity, emptiness and source absence are checked afterward.
- Native filesystem APIs cannot eliminate all races with concurrent writers. Pause other apps making changes to the selected tree. A post-move mismatch stops further work and reports the destination for review; the app never deletes or automatically restores uncertain content.
- File Provider may require bookkeeping to move an empty directory to Trash. The app temporarily permits that operation for the already-verified directory, then restores the previous process I/O policy. It does not read media contents, repair caches or force file downloads.
- No permanent-delete fallback exists. The application never empties Trash. Recovery availability depends on Trash still containing the moved directories.

If the app or computer stops during a move, consult the SQLite journal. A `prepared` event without a final result is uncertain, not proof of success or failure. Do not automatically retry it. Verify original path, inode and Trash before continuing. All confirmed destinations remain recorded.

Report security issues through the repository's private vulnerability reporting channel if available; otherwise contact the maintainer without posting private paths or exploit data publicly. No hosted authentication, payment, email or institution-specific data processing is part of this application. This document describes technical behavior, not a certification of legal compliance.

## Update boundary

Release discovery is restricted to the public project and architecture-specific ZIP naming. Numeric versions prevent downgrades. Sparkle 2.9.6 requires both a signed appcast and an Ed25519-signed archive, validating before extraction. The appcast item must match the version and exact asset URL selected from GitHub. A missing, altered or mismatched feed fails closed. There is no unsigned installation fallback or silent install-on-quit.

The production feed and download entry points use HTTPS. The isolated integration harness uses loopback HTTP for synthetic signed fixtures only; this does not relax production settings. Tests verify actual installation/relaunch and rejection of altered archives/feeds. Update installation is mutually exclusive with folder work. Downloads can be cancelled before installation is committed.

An update changes the application bundle, not the user's journal directory. Database schema compatibility still matters: never restore an older database over newer work automatically. Distribution currently uses ad-hoc application signing without Apple notarization; update signatures authenticate the release but do not promise a warning-free first launch on another Mac. Private keys, test data and signing-tool caches never belong in Git.
