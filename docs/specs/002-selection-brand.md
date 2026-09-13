# Selection and brand identity — v0.2.0

## Acceptance contract

- Every new scan, folder change or mode change starts with zero selected candidates. Selection is session-only and is never saved in SQLite.
- Individual checkboxes, select-all and clear-all are explicit actions. Filtering does not change selection; select-all is labeled with the full scan count.
- Zero selection disables approval. Unknown IDs and selections belonging to a different scan cannot generate an approved plan.
- Review freezes the selected subset and shows every selected path, including filtered-out rows. Cancel performs no filesystem operation. Execution consumes approval once.
- Cascade never expands selection. A parent with any unselected child remaining is preserved by the native emptiness check. The selected subset retains its scan identity, candidate order and ancestor identity checks.
- SQLite journals only the approved subset. No schema change, data reset or automatic cleanup is required.
- The new icon is included in the application bundle and its runtime resources. Dock, main view, review, history and About use the same image.

## Verification

Core cases: default-off, all/none, individual changes, foreign IDs, stale scan, immutable subset, leaf-only, full selected chain, missing intermediate child, single-pass boundaries and files created after approval. Opt-in native test verifies the real filesystem preserves unselected folders and control bytes. UI tests cover filtered selection, the complete review list, cancel, mode/re-scan/folder reset and both modes.

Build checks: native icon representations, bundled PNG, metadata version, relocatable resources, privacy scan and code signature. Release verification repeats a selection flow using the downloaded application on artificial data.
