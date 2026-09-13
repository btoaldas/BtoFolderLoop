# BtoFolderLoop

Open-source native macOS utility. GPL-3.0-or-later. Initial release: preview.

## Product contract
Choose or drop one directory, inspect a complete preview, explicitly approve moving only empty subdirectories to macOS Trash. Single-pass considers only initially empty leaves. Cascade includes approved ancestors that become empty. Never remove the selected root, files, symbolic links, packages, unreadable entries, or anything not in the approved plan. Never empty Trash. New or changed contents invalidate eligibility.

## Structure and commands
Swift Package targets: BtoFolderLoopCore (models/planner/executor and ports), BtoFolderLoopMac (native filesystem), BtoFolderLoopStorage (SQLite), BtoFolderLoopApp (SwiftUI). No third-party dependencies or network API.
`swift test`; `bash scripts/build-app.sh`; `python3 scripts/check-public.py`.

## Authority and safety
Announce changes and test only synthetic fixtures. User data, publication, signing credentials and destructive operations require their specific authorization. Never use permanent deletion as a Trash fallback. Preserve partial journals and fail closed. No automatic rollback: recovery uses the recorded Trash destinations and free original paths.
Local source -> tests -> commit -> authorized public repository -> verified release. No servers or deployments in this project. Public examples must be synthetic. No private paths, personal records, tokens, databases, or machine-specific governance in Git. Explicit public publication was requested; confirm repository owner/name before creating the remote.

## Evidence and maintenance
Verify planning, filesystem failures, stale plans, no-file-loss, native Trash and SQLite persistence. UI smoke tests must cover preview/confirmation/results; a successful build alone is insufficient. Record reproducible results in docs/hitos. Update ROADMAP and dated bitacora on milestones. Known limits must be disclosed.

## Context economy
Use structural code indexing when available; inspect relevant symbols and small files before broader searches. Keep changes scoped and avoid dumping repository trees. Local tool configuration is untracked.
