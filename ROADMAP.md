# Roadmap

Updated: 2026-09-13. Status: v0.1.0 verified locally; source and preview binary publication authorized. Level P (public preview, synthetic validation); actual user files are safety-critical and receive strict no-file-loss checks. General availability requires the signed distribution and broader OS/provider validation listed below.

## Now
Publish the reviewed v0.1.0 source and preview release to `btoaldas/BtoFolderLoop`; verify remote CI and the downloaded package. Both modes, reviewed plans, native Trash, SQLite persistence, UI flow, 23 tests, package and installation guide are complete locally.

## Next
Signed/notarized distribution and compatibility testing across supported macOS releases/cloud providers. Incremental features through separate operation strategies, never silent expansion of cleanup scope.

## Lifecycle decisions
| Module | Applies | Implementation |
|---|---|---|
| Requirements | P | RF/RNF and acceptance cases in docs/specs |
| Architecture | P | Four independent targets and explicit ports; desktop calls, no HTTP |
| Data | P | Local SQLite migrations, bound parameters, settings and operation journal |
| Security | P | Filesystem entry validation, symlink/package/root protection, no secrets or network/auth |
| Infrastructure | No | Desktop-only, no paid server/DNS/deployment |
| CI/CD | P | macOS tests/build and source privacy check; synthetic fixtures |
| Observability | P | Local journal and visible progress/errors; no telemetry, web health or remote alerts |
| Payments | No | Free software, no payments |
| Email | No | No email functionality |
| Mobile | No | macOS desktop only |
| Maintenance | P | Maintainers review issues/dependencies monthly, starting 2026-10-13; CI and compatibility matrix |

## Decisions pending
GPL selected as version 3 or later. Public binary notarization is not available without a selected signing identity; source builds remain available. Sanitized documentation snapshot for a personal knowledge vault is prepared at milestone; no live DBs or private data are exported.
