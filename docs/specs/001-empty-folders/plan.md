# Implementation plan

1. Bootstrap the repository, define acceptance criteria and module contracts.
2. Implement a metadata-only planner that produces immutable single/cascade previews.
3. Implement native Trash revalidation and a durable SQLite journal before exposing the action.
4. Build the SwiftUI choose/drop -> preview -> confirmation -> result flow.
5. Exercise pure planning, stale plans, failures, SQLite reopening, native synthetic Trash and the actual UI.
6. Package relocatable resources, inspect source/binary for private build paths, document limits and prepare public publication.

No production/user archive is used as a test fixture. No service, credential or network capability is introduced.
