# SurrealDB 3.0.0 RocksDB Startup Crash Repro

Minimal repro for intermittent process death during embedded RocksDB startup.

Configuration:

- `surrealdb = "=3.0.0"` with `kv-rocksdb`
- local `RocksDb` engine
- repeated start/stop cycles on the same DB path

## Run (no Nix)

Requirements:

- Rust toolchain (the repro was built with rustc `1.93.1`)

Commands:

```bash
chmod +x repro.sh
./repro.sh
```

Optional knobs:

```bash
RUNS=100 START_TIMEOUT_SECONDS=10 READY_GRACE_SECONDS=1 ./repro.sh
```

## Run (with Nix)

```bash
nix develop --command ./repro.sh
```

## GitHub Actions

Workflow: `.github/workflows/repro.yml`

- Runs this repro from the Nix devshell on:
  - `darwin-aarch64` (`macos-14`)
  - `linux-x86_64` (`ubuntu-24.04`)
- Trigger modes:
  - manual (`workflow_dispatch`) with optional inputs
  - push to `main`
- Uploads artifacts per platform:
  - `run-*.log`
  - RocksDB `db/LOG*`

## Findings

- Repro is strong on `darwin-aarch64` (`macos-14`) with frequent `SIGTRAP` exits.
- Repro is not currently observed on `linux-x86_64` (`ubuntu-24.04`) in equivalent loop runs.
- Latest CI run:
  - GitHub UI: **Actions** tab in this repo, open the newest run for **Repro (Nix Devshell)**.
  - CLI: `gh run list --workflow "Repro (Nix Devshell)" --limit 1`
  - Watch live: `gh run watch <run-id> --interval 30`

## Local reproduce

- Nix (recommended): `nix develop --command ./repro.sh`
- No Nix: `./repro.sh`
- Higher-signal run: `RUNS=100 START_TIMEOUT_SECONDS=10 READY_GRACE_SECONDS=1 ./repro.sh`

## What the script does

1. Deletes `./db` once before the first iteration.
2. Builds `surrealdb-rocksdb-repro`.
3. Repeats startup/shutdown for `RUNS` iterations.
4. Classifies outcomes:
   - `ok` (clean exit)
   - `sigtrap` (status `133`, i.e. `SIGTRAP`)
   - `timeout`
   - `other_fail`
5. Writes per-run logs: `run-<n>.log`.
