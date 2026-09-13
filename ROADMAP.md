# Roadmap

Updated: 2026-09-13. Status: v0.2.0 selection and identity preview published; download and application resources verified. Level P (public preview, synthetic validation); actual user files are safety-critical and receive strict no-file-loss checks. General availability requires the signed distribution and broader OS/provider validation listed below.

## Now
Prepare v0.3.0 locally: live durable counters, worked-on folder history, per-run event pagination, typed rotating diagnostics, configurable retention a footer with signed one-click updates, and multiple-folder/alias inputs with independent root journals and overlap protection. See [scope and safeguards](docs/specs/003-history-retention.md). The observed v0.2.0 cleanup completed without reported errors; development kept its app and database untouched. Signed update/install/relaunch tests use independent synthetic applications. New publication and installation are not part of this stage.

The latest public release remains [v0.2.0](https://github.com/btoaldas/BtoFolderLoop/releases/tag/v0.2.0), with default-off selection and the original icon. Its [public milestone](docs/hitos/2026-09-13-v0.2.0-public.md) records package verification; v0.1.0 stays available.

## Next
Signed/notarized distribution, compatibility testing across macOS/cloud providers and cross-application drag-and-drop. Candidate improvements: hierarchical preview, explicit persistent exclusions and guided restoration from recorded Trash destinations while available. These ideas are not active implementation scope. Incremental features keep separate strategies and never silently expand approval.

## Lifecycle decisions
| Module | Applies | Implementation |
|---|---|---|
| Requirements | P | RF/RNF and acceptance cases in docs/specs |
| Architecture | P | Four independent targets and explicit ports; desktop ports, isolated release HTTP client and Sparkle adapter |
| Data | P | Local SQLite migrations, bound parameters, settings and operation journal |
| Security | P | Filesystem entry validation, symlink/package/root protection, public-key signed updates, no embedded secrets, login or telemetry |
| Infrastructure | No | Desktop-only, no paid server/DNS/deployment |
| CI/CD | P | macOS tests/build and source privacy check; synthetic fixtures |
| Observability | P | Local journal and visible progress/errors; no telemetry, web health or remote alerts |
| Payments | No | Free software, no payments |
| Email | No | No email functionality |
| Mobile | No | macOS desktop only |
| Maintenance | P | Maintainers review issues/dependencies monthly, starting 2026-10-13; CI and compatibility matrix |

## Decisions pending
GPL selected as version 3 or later. Public binary notarization is not available without a selected signing identity; source builds remain available. Sanitized documentation snapshot for a personal knowledge vault is prepared at milestone; no live DBs or private data are exported.
