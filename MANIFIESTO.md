# FolderLoop

A small local utility to make empty-directory cleanup understandable and reviewable.

The user chooses one root and one mode. Nothing moves during analysis. The preview is the maximum authorized set. Single-pass moves initially empty directories once. Cascade rechecks the approved empty subtree from the bottom upward. New candidates require a new preview. Original files and the chosen root are always protected. Hidden files count as content. Trash, never permanent deletion.

Initial platform: macOS 14+, Swift 6 toolchain, SwiftUI, Foundation and system SQLite. Native APIs avoid a bundled browser/runtime and give direct access to macOS Trash. Core rules, filesystem operations, persistence and UI have distinct module boundaries. Windows/Linux are future adapters, not current capabilities.

Success: both modes match their advertised semantics, modifications are previewed and approved, files remain in place, partial failures are recorded, settings survive reopening, source and installation instructions are public under GPL-3.0-or-later.

Non-goals: duplicates, hidden-file cleanup, cloud repair, permanent deletion, automatic scheduled cleanup, background daemon, network services, user accounts or telemetry.
