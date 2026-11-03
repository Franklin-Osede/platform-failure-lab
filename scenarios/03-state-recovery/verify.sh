#!/usr/bin/env bash
# Verify the scenario. Exit 1 on any failed check.
#   verify.sh --baseline       -> record the current instance ID (before injecting)
#   verify.sh --expect-failure -> injected: state lost the instance, AWS still has it,
#                                 and Terraform wants to create it again
#   verify.sh                  -> recovered: state tracks the ORIGINAL instance,
#                                 nothing pending, no duplicate
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=03-state-recovery
VERIFY_FAILED=0
mode="${1:-recovered}"
baseline="$(evidence_dir "$SCENARIO")/baseline-instance-id.txt"

in_state="$(tf state pull 2>/dev/null | jq -r '
  [.resources[]? | select(.mode=="managed" and .type=="aws_instance" and .name=="lab")
   | .instances[0].attributes.id][0] // empty')"
aws_ids="$(lab_instance_ids)"
count="$(wc -w <<<"$aws_ids" | tr -d ' ')"

case "$mode" in
  --baseline)
    capture "$SCENARIO" baseline-plan tf plan -detailed-exitcode -input=false
    check "plan -detailed-exitcode" "0" "$LAST_RC"
    if [[ -z "$in_state" ]]; then
      echo "FAIL  no aws_instance.lab in state; run 'make up' first"
      exit 1
    fi
    echo "$in_state" >"$baseline"
    echo "Baseline recorded: $in_state"
    ;;

  --expect-failure)
    check "instance missing from state" "<missing>" "${in_state:-<missing>}"
    check "original instance still exists in AWS" "yes" \
      "$(grep -qw "$(cat "$baseline" 2>/dev/null)" <<<"$aws_ids" && echo yes || echo no)"
    check "lab instances in AWS" "1" "$count"

    capture "$SCENARIO" verify-failure-plan tf plan -detailed-exitcode -input=false
    check "plan wants changes (exit 2)" "2" "$LAST_RC"
    log="$(ls -t "$(evidence_dir "$SCENARIO")"/*-verify-failure-plan.log | head -1)"
    if grep -q 'aws_instance.lab will be created' "$log"; then plan_cause="recreate instance"; else plan_cause="other"; fi
    check "plan would create the existing instance again" "recreate instance" "$plan_cause"
    ;;

  *)
    capture "$SCENARIO" verify-plan tf plan -detailed-exitcode -input=false
    check "plan -detailed-exitcode" "0" "$LAST_RC"
    check "instance in state is the original" "$(cat "$baseline" 2>/dev/null)" "${in_state:-<missing>}"
    check "lab instances in AWS (no duplicate)" "1" "$count"
    ;;
esac

exit "$VERIFY_FAILED"
