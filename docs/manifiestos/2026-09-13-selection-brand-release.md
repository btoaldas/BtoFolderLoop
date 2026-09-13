# v0.2.0 selection and application identity

Authorized scope: update the public BtoFolderLoop application with individual selection, select-all/none controls, and an original AI-generated icon; commit, push and publish a new preview release at `btoaldas/BtoFolderLoop`.

Every completed scan starts with nothing selected. Approval is a frozen subset of the analyzed candidates, shown in full before execution. No parent/child is selected implicitly. An occupied parent remains even if selected. A new scan or mode/folder change invalidates selection and approval. No database migration or user-file cleanup is included.

Create an original folder/loop icon using the built-in image-generation tool, keep the generated source and provenance, and package native icon sizes. Apply it to the app bundle, Dock, main view, confirmation, history, About and public README. The generated source is raster, not an editable vector. Package exports preserve the design.

Validate selection with core tests, native synthetic filesystem tests and UI tests of default-off, individual/all/none, filtering, confirmation, reset and both cleanup modes. Check original bytes/identities, SQLite, packaged icon resources and a fresh release download. Scan public content for private paths and secrets.

Changes start from the existing Git history; v0.1.0 remains available. Build outputs use new directories. No application installation is overwritten and no release/tag is replaced. Recovery means selecting a prior release or preparing a normal corrective commit; no automatic destructive rollback, forced push or Trash emptying.
