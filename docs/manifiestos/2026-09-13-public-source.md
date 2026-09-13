# Public source publication

## Prepared change

Create the public GitHub repository `BtoFolderLoop` on branch `main` under the confirmed owner and push the reviewed source history. Requested visibility: public. License: GPL-3.0-or-later. Proposed owner: `btoaldas`, pending confirmation before remote creation.

Contents: source modules, tests with synthetic data, build scripts, SQLite migration, license, project documentation and a macOS CI workflow. Excluded: local databases, raw logs/screenshots, temporary fixtures, build output, private paths, credentials and machine-specific context.

## Verification and impact

Run source privacy check, tests, package check, and inspect Git history before push. After creation, query visibility/license/default branch, compare the remote commit with local HEAD and verify the GitHub CI result. The source and its history will become publicly downloadable. The app itself sends no user files or telemetry to GitHub.

The release ZIP is prepared locally with its SHA-256, but has no Apple Developer notarization. Publishing a downloadable binary is a separate release decision; source instructions allow a local build.

## Recovery

Local Git history and the built package remain available. Public distribution cannot be recalled from existing downloads. Do not delete the repository, rewrite history or change visibility as an automatic rollback. A failed push is diagnosed and retried only after reading the remote state; no force push.
