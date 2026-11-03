#!/usr/bin/env bash
# Inject: start an apply that holds the lock, then SIGKILL it mid-operation.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=01-stuck-lock
ed="$(evidence_dir "$SCENARIO")"
log="$ed/$(date +%Y%m%d-%H%M%S)-apply-killed.log"
marker="slow_apply_seconds=300"

if lock_exists; then
  echo "A lock already exists. Resolve it first (see README)." >&2
  exit 1
fi

echo "Starting a slow apply (holds the lock for up to 300 s)..."
tf apply -auto-approve -input=false -var "$marker" -var "run_id=$(date +%s)" >"$log" 2>&1 &

echo "Waiting for time_sleep to start..."
started=0
for _ in $(seq 1 180); do
  if grep -q 'time_sleep.slow\[0\]: Creating' "$log"; then started=1; break; fi
  sleep 1
done
if [[ $started -eq 0 ]]; then
  echo "time_sleep never started; see $log" >&2
  exit 1
fi
sleep 5

# Match every terraform process for this apply (covers tfenv/asdf shims too).
pids="$(pgrep -f "apply -auto-approve -input=false -var $marker" || true)"
if [[ -z "$pids" ]]; then
  echo "No matching terraform process found (did the apply already finish?). See $log" >&2
  exit 1
fi
echo "Sending SIGKILL to: $pids"
# shellcheck disable=SC2086
kill -9 $pids
wait 2>/dev/null || true

perl -pi -e 's/\e\[[0-9;]*m//g; s/\b\d{12}\b/<ACCOUNT_ID>/g' "$log"
echo "Apply killed. Log: ${log#"$LAB_ROOT"/}"

if lock_exists; then
  echo "Lock object is still in S3: s3://$(state_bucket)/$LOCK_KEY"
else
  echo "No lock object found. Unexpected — record it in the Actual column."
fi
echo "Next: ./scenarios/$SCENARIO/observe.sh"
