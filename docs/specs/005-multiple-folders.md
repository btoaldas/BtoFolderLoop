# Multiple folders and explicit shortcut inputs

Accept one drop/chooser operation containing several directories, Finder alias files or symbolic links. The existing one-folder flow remains a one-root batch. Each new input replaces the prior preview and resets all selection. Do not queue work behind an active cleanup/update.

## Boundaries

- Resolve shortcuts only at the explicit input boundary. Use local canonical paths, detect cycles/unsupported targets and never mount volumes or modify shortcut files. Windows `.lnk` and web links are unsupported.
- Show original shortcut and real root paths. Show the owning root in candidate/review rows so identical relative names in different trees remain distinguishable.
- Deduplicate by filesystem identity and canonical path; scan an overlapping subtree only under its outer root. Preserve every explicitly requested root and its ancestors, even when an input was also nested inside another input.
- Validate root identities before scanning. A changed explicit nested root blocks its containing tree rather than silently losing that protection. The native executor still checks identities and content before each approved move.
- Default-off batch selection is tied to the complete immutable scan ID. Approval contains only marked candidates; no selection expands to siblings, descendants or other roots. A consumed approval cannot be reused.
- Execute sequentially through the existing native executor and one journal per root. Stop the whole batch on error/cancellation. Never erase files, original shortcuts, pending trees or Trash contents.
- Bound input count to 128 and total scan to 250,000 directories. Cancellation/limit failure returns no partial actionable plan. Individual invalid input paths remain visible while valid independent trees can be reviewed.

## Components and evidence

`FolderInputResolver` is the macOS input adapter. `CleanupBatch`, `BatchPlanner`, `BatchSelection` and `BatchExecutor` stay in separate core files. `AppFolderInputModel` coordinates input and the existing model owns explicit execution approval. `FolderInputsView` presents resolved paths. Existing per-root SQLite journals need no additional migration for batches.

Tests cover independent roots, same-name candidates, duplicate/overlapping roots, nested-root preservation, partial selection, stale scans, changed roots, cancellation and a journal failure that stops before the next tree. Native fixture tests cover Finder bookmarks, symlink chains/cycles, broken/file/package targets, canonical case and unchanged shortcut bytes. An opt-in end-to-end model/native test moves exactly three synthetic empty directories, verifies their Trash identities/source absence, keeps files and selected roots unchanged, and checks two completed local journals. UI snapshots cover batch preview and final approval using synthetic data.
