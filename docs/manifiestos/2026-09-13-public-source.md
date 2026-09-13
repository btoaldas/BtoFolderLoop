# Public source publication

## Prepared change

Create the public GitHub repository `btoaldas/BtoFolderLoop` on branch `main` and push the reviewed source history. Visibility: public. License: GPL-3.0-or-later. Source publication and the v0.1.0 preview binary release were authorized on 2026-09-13.

Contents: source modules, tests with synthetic data, build scripts, SQLite migration, license, project documentation and a macOS CI workflow. Excluded: local databases, raw logs/screenshots, temporary fixtures, build output, private paths, credentials and machine-specific context.

## Verification and impact

Run source privacy check, tests, package check, and inspect Git history before push. After creation, query visibility/license/default branch, compare the remote commit with local HEAD and verify the GitHub CI result. The source and its history will become publicly downloadable. The app itself sends no user files or telemetry to GitHub.

Publish v0.1.0 as a preview release with an Apple Silicon ZIP, portable SHA-256 checksum and build metadata identifying its source commit. The binary has a local ad-hoc signature and no Apple Developer notarization; disclose this in the release and installation guide. Download the published assets, verify their hashes and run the downloaded app against synthetic fixtures. Source builds remain available. No installation replacement or security setting changes are included.

## Recovery

Local Git history and the built package remain available. Public distribution cannot be recalled from existing downloads. Do not delete the repository, rewrite history or change visibility as an automatic rollback. A failed push is diagnosed and retried only after reading the remote state; no force push.
