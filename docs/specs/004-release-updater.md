# In-app release updates

Extend the footer with the installed version, a public release check and an explicit update button. Never interrupt cleanup or install automatically merely because a newer version exists.

- Query published GitHub releases, including this project's preview releases; ignore drafts, malformed tags, incompatible architectures and unexpected download origins. Compare numeric versions and never offer a downgrade.
- Display the latest compatible offer with a release-notes link. One explicit **Actualizar y reiniciar** action authorizes download, verified installation and relaunch; any OS authorization prompt remains under macOS control.
- Use pinned Sparkle 2.9.6 for archive signing validation, extraction, installation and relaunch. Keep folder planning/execution independent. Do not build a custom self-replacing shell installer.
- Require signed feeds and Ed25519 archive validation before extraction. Store the private signing key in the login Keychain, only the public key in the application. No system profiling, unsolicited downloads or silent install-on-quit.
- Block new folder work throughout the update; block installation while folder work is active. Revalidate these guards at the Sparkle delegate/driver boundaries.
- Include framework resources and upstream licensing in the package. A signed architecture-specific feed must accompany future release publication; a failed/missing feed never permits an unverified fallback.
- Validate version parsing, published-preview discovery, architecture/origin filtering, busy guards, error recovery and a completely isolated signed update/relaunch fixture. No test may replace the installed user's application or use the live data directory.
