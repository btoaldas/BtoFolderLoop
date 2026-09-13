# BtoFolderLoop

Open-source native macOS utility. GPL-3.0-or-later. Initial release: preview.

## Product contract
Choose or drop one or multiple directories (or macOS folder aliases/symlinks resolved explicitly to real roots), inspect a complete preview, select candidates and explicitly approve moving only empty subdirectories to macOS Trash. Duplicate and overlapping roots are scanned only once. Batch execution is sequential, stops at an error/cancellation and journals each root independently. Every scan begins with all candidates deselected. Selection never expands to parents or children implicitly. Single-pass considers only initially empty leaves. Cascade includes only selected ancestors that become empty. Never remove any explicitly selected root, including nested ones, original shortcuts, files, symbolic links, packages, unreadable entries, or anything not in the approved subset. Never empty Trash. New or changed contents invalidate eligibility.

## Structure and commands
Swift Package targets: BtoFolderLoopCore (models/planner/executor and ports), BtoFolderLoopMac (native filesystem), BtoFolderLoopStorage (SQLite), BtoFolderLoopApp (SwiftUI). Sparkle 2.9.6 is pinned for signed application updates. Folder operations remain local; only public release checks, signed feeds and update downloads use the network. Never send folder paths, logs or system profiling.
`swift test`; `bash scripts/build-app.sh`; `python3 scripts/check-public.py`.

## Authority and safety
Announce changes and test only synthetic fixtures. User data, publication, signing credentials and destructive operations require their specific authorization. Never use permanent deletion as a Trash fallback. Preserve partial journals and fail closed. No automatic rollback: recovery uses the recorded Trash destinations and free original paths.
Local source -> tests -> commit -> authorized public repository -> verified release. No servers or deployments in this project. Public examples must be synthetic. No private paths, personal records, tokens, databases, or machine-specific governance in Git. The public v0.2.0 update (individual selection and application identity) is authorized at `btoaldas/BtoFolderLoop` on GitHub; v0.1.0 stays available. Future release authority must be established for its specific scope.

## Evidence and maintenance
Verify planning, filesystem failures, stale plans, no-file-loss, native Trash and SQLite persistence. UI smoke tests must cover preview/confirmation/results; a successful build alone is insufficient. Record reproducible results in docs/hitos. Update ROADMAP and dated bitacora on milestones. Known limits must be disclosed.

## Context economy
Use structural code indexing when available; inspect relevant symbols and small files before broader searches. Keep changes scoped and avoid dumping repository trees. Local tool configuration is untracked.
