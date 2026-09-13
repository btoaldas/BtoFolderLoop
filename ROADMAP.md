# Roadmap

Updated: 2026-09-13. Status: v0.3.0 history, signed updates and multiple-folder preview published and installed; public download, feed and migration verified. Level P (public preview, synthetic validation); actual user files are safety-critical and receive strict no-file-loss checks. General availability requires the signed distribution and broader OS/provider validation listed below.

## Now
v0.3.0 is published and verified: live durable history, configurable diagnostic/history retention, signed one-click update footer, multiple-folder and explicit shortcut inputs, duplicate/nested-root protection. Public source/tag CI passed. The downloaded archive/feed signatures and source commit match the reviewed package. An authorized existing installation was upgraded only while idle; original journals and preferences were preserved and migration backup/integrity checks passed.

See [the public v0.3.0 milestone](docs/hitos/2026-09-13-v0.3.0-public.md) and [the release](https://github.com/btoaldas/BtoFolderLoop/releases/tag/v0.3.0). Older v0.1.0/v0.2.0 releases remain available. No folder cleanup starts automatically after updating.

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
