# Empty-folder cleanup v1

RF-01: Drop or choose one real directory and see its name/path; reject files and symbolic roots.
RF-02: Analysis performs no moves, reads directory metadata only, includes hidden entries, skips packages/symlinks and reports read failures. Root is never a candidate.
RF-03: Single-pass preview contains only directories with zero entries now; parents becoming empty remain.
RF-04: Cascade preview also contains parents whose complete contents consist of eligible directories. List distinguishes currently empty from empty after children. Execution never expands beyond this approved set.
RF-05: Moving requires the current plan and explicit confirmation naming root, mode and count. Mode/root changes invalidate preview. No double submission; cancellation stops before the next operation.
RF-06: Revalidate root/ancestor/candidate identity and emptiness, use native Trash, verify destination and source, stop on ambiguous failure. Preserve files and occupied directories. No permanent-delete path.
RF-07: Remember selected mode in a lightweight local SQLite database. Journal a prepared event durably before moving and the result afterward; show history and local recovery paths.
RF-08: Show progress, skipped candidates and errors. Allow revealing journal storage in Finder. No restart auto-resume.

RNF: UI remains responsive while analysis/cleanup runs off the main thread. Stress-test 10,000 synthetic directories and record measured timing rather than promise capacity. Never read file contents to determine emptiness. Keyboard-accessible controls, scalable list, system colors, Spanish first UI. Zero runtime network/telemetry and zero third-party package dependencies.

API contract: analyze(root, mode, cancellation) -> immutable Plan(root identity, directory identities, candidates with dependency depth, issues); execute(plan, cancellation, progress) -> Report(moved, skipped, issues), through filesystem and journal ports. Settings store typed mode, not media. A failed journal write prevents further movement.

Acceptance: a chain A/B/C appears as C only in single mode and C,B,A in cascade; a file or hidden file blocks its ancestors; links/packages/read errors stay; changed inode or new file blocks execution; failed Trash never falls back to deletion; journal and settings persist after reopen; UI requires confirmation; native synthetic Trash smoke check verifies same identity and files unchanged.
