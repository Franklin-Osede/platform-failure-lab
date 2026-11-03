#!/usr/bin/env bash
# Verify the scenario in one of two modes. Exit 1 on any failed check.
#   verify.sh                  -> recovered: no lock left, nothing pending
#   verify.sh --expect-failure -> injected: the stale lock exists and blocks operations
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=01-stuck-lock
VERIFY_FAILED=0
mode="${1:-recovered}"

if lock_exists; then lock="present"; else lock="absent"; fi

if [[ "$mode" == "--expect-failure" ]]; then
  check "lock object (failure reproduced)" "present" "$lock"

  capture "$SCENARIO" verify-failure-plan tf plan -detailed-exitcode -input=false -lock-timeout=0s
  check "plan is blocked (exit 1)" "1" "$LAST_RC"

  # shellcheck disable=SC2012  # our own timestamped filenames, no odd characters
  log="$(ls -t "$(evidence_dir "$SCENARIO")"/*-verify-failure-plan.log | head -1)"
  if grep -q "Error acquiring the state lock" "$log"; then cause="lock error"; else cause="other error"; fi
  check "plan fails because of the lock, not something else" "lock error" "$cause"
else
  check "lock object" "absent" "$lock"

  capture "$SCENARIO" verify-plan tf plan -detailed-exitcode -input=false -lock-timeout=0s
  check "plan -detailed-exitcode" "0" "$LAST_RC"
fi

exit "$VERIFY_FAILED"
