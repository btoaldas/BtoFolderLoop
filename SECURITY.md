# Security and privacy

This is an offline desktop utility. It has no network client, login, telemetry, cloud service or embedded credentials. Native macOS permissions remain in effect. Never grant extra permissions simply to silence an error; choose a folder the app can inspect.

The local SQLite file contains mode settings, timestamps, source/destination directory paths, operation state and error details. It is not encrypted by the app; the macOS user account and disk protection apply. It is created with user-only permissions and is never uploaded. History is retained locally to support recovery; no automatic purge is performed. The interface displays only the 30 most recent runs and 500 most recent events; the database retains the full journal. Do not post that database publicly.

## Filesystem boundaries

- The chosen root, files (including hidden files), symbolic links, packages, repository internals, filesystem/system folders and inaccessible entries are preserved.
- Targets of symbolic links discovered inside the scanned tree and their ancestors are preserved. References from outside the selected tree, Finder alias files and application-specific absolute paths cannot be inferred by this scanner.
- A preview is immutable and defines the maximum approved set. New folders require another scan and approval.
- Root, parent and candidate identities and emptiness are checked again before each native Trash move. The destination identity, emptiness and source absence are checked afterward.
- Native filesystem APIs cannot eliminate all races with concurrent writers. Pause other apps making changes to the selected tree. A post-move mismatch stops further work and reports the destination for review; the app never deletes or automatically restores uncertain content.
- File Provider may require bookkeeping to move an empty directory to Trash. The app temporarily permits that operation for the already-verified directory, then restores the previous process I/O policy. It does not read media contents, repair caches or force file downloads.
- No permanent-delete fallback exists. The application never empties Trash. Recovery availability depends on Trash still containing the moved directories.

If the app or computer stops during a move, consult the SQLite journal. A `prepared` event without a final result is uncertain, not proof of success or failure. Do not automatically retry it. Verify original path, inode and Trash before continuing. All confirmed destinations remain recorded.

Report security issues through the repository's private vulnerability reporting channel if available; otherwise contact the maintainer without posting private paths or exploit data publicly. No hosted authentication, payment, email or institution-specific data processing is part of this application. This document describes technical behavior, not a certification of legal compliance.
