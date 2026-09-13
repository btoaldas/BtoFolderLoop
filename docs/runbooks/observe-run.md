# Observe an existing cleanup without interference

The Python helper opens an **existing** SQLite database with `mode=ro` and `query_only=ON`. It uses short read transactions and never opens the selected tree, moves folders, runs maintenance or stops the application. It does not load the app's storage module, so it cannot trigger a migration or retention.

```sh
python3 scripts/observe-run.py \
  --database "$HOME/Library/Application Support/BtoFolderLoop/settings.sqlite"
```

For a bounded one-hour follow-up with one observation per minute:

```sh
python3 scripts/observe-run.py \
  --database "$HOME/Library/Application Support/BtoFolderLoop/settings.sqlite" \
  --follow --interval 60 --seconds 3600
```

The first observation binds to one run; use `--run UUID` to select it explicitly. Follow-up stops when that run has a closing status or the time limit expires. Output is JSONL with counts, status, last event time and observation time. No folder paths are printed. A temporary read failure is reported without writing to the database. This helper does not send notifications.

Compare successive `moved` event counts and the last activity time. In **v0.2.0**, `runs.moved` remains zero until the run finishes; it must not be treated as the progress counter. A `running` row left after a crash is not evidence of a live worker. If activity stops, report the uncertainty; do not restart or repair the app automatically.

If the user permits a filesystem spot check, inspect only a small sample of recent receipts: original absent, Trash entry a real empty directory, device/inode equal to the preceding prepared event. Missing Trash entries can also mean the user emptied the Trash. A sample does not prove the contents of every user file, and the recorded result does not prove completion of cloud synchronization.

Keep observations and any private evidence out of Git. Do not run native Trash fixtures or open a development app on the live database during the user's cleanup.
