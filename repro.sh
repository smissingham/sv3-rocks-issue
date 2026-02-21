#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$ROOT_DIR/target/debug/surrealdb-rocksdb-repro"
DB_PATH="$ROOT_DIR/db"

RUNS="${RUNS:-30}"
START_TIMEOUT_SECONDS="${START_TIMEOUT_SECONDS:-10}"
READY_GRACE_SECONDS="${READY_GRACE_SECONDS:-1}"

echo "[repro] root: $ROOT_DIR"
echo "[repro] runs: $RUNS"
echo "[repro] start-timeout-seconds: $START_TIMEOUT_SECONDS"

cd "$ROOT_DIR"

echo "[repro] clearing database directory before first run"
rm -rf "$DB_PATH"
mkdir -p "$DB_PATH"

echo "[repro] building binary"
if command -v llvm-config >/dev/null 2>&1; then
	export LIBCLANG_PATH="$(llvm-config --libdir)"
fi
cargo build

ok_count=0
sigtrap_count=0
timeout_count=0
other_fail_count=0

WAIT_CODE=0

wait_status() {
	local pid="$1"
	set +e
	wait "$pid"
	WAIT_CODE=$?
	set -e
}

for run in $(seq 1 "$RUNS"); do
	log_path="$ROOT_DIR/run-$run.log"
	: >"$log_path"

	status=0
	started=0

	REPRO_DB_PATH="$DB_PATH" "$BIN_PATH" >"$log_path" 2>&1 &
	pid=$!

	for _ in $(seq 1 $((START_TIMEOUT_SECONDS * 10))); do
		if ! kill -0 "$pid" 2>/dev/null; then
			break
		fi

		if grep -q "READY" "$log_path"; then
			started=1
			break
		fi

		sleep 0.1
	done

	if kill -0 "$pid" 2>/dev/null; then
		if [[ "$started" -eq 1 ]]; then
			sleep "$READY_GRACE_SECONDS"
			kill -INT "$pid" 2>/dev/null || true
			wait_status "$pid"
			status="$WAIT_CODE"
		else
			kill -KILL "$pid" 2>/dev/null || true
			wait_status "$pid"
			status="$WAIT_CODE"
		fi
	else
		wait_status "$pid"
		status="$WAIT_CODE"
	fi

	case "$status" in
	0)
		ok_count=$((ok_count + 1))
		result="ok"
		;;
	133)
		sigtrap_count=$((sigtrap_count + 1))
		result="sigtrap"
		;;
	137)
		timeout_count=$((timeout_count + 1))
		result="timeout"
		;;
	*)
		other_fail_count=$((other_fail_count + 1))
		result="exit-$status"
		;;
	esac

	echo "RUN $run: result=$result status=$status started=$started log=$log_path"

	if [[ "$status" -ne 0 ]]; then
		echo "[repro] tail(run=$run)"
		tail -n 8 "$log_path" || true
	fi
done

echo
echo "[repro] summary"
echo "  ok=$ok_count"
echo "  sigtrap=$sigtrap_count"
echo "  timeout=$timeout_count"
echo "  other_fail=$other_fail_count"
