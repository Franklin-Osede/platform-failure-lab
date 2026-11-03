#!/usr/bin/env bash
# Observe: capture symptoms and evidence. Changes nothing.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=01-stuck-lock

echo "== Symptom: any operation that needs the lock fails"
capture "$SCENARIO" plan-blocked tf plan -lock-timeout=0s -input=false

echo "== The lock object itself"
capture "$SCENARIO" lock-object aws s3 cp --region "$(aws_region)" "s3://$(state_bucket)/$LOCK_KEY" -

echo "== Is any Terraform process still running here?"
capture "$SCENARIO" processes bash -c "ps aux | grep '[t]erraform' || echo 'no terraform processes'"

echo "== What the state contains (reading does not need the lock)"
capture "$SCENARIO" state-resources bash -c \
  "terraform -chdir='$INFRA_DIR' state pull | jq -r '.serial as \$s | \"serial=\(\$s)\", (.resources[] | \"\(.mode).\(.type).\(.name)\")'"

echo "== What exists in AWS"
capture "$SCENARIO" aws-instances bash -c "source '$LAB_ROOT/scripts/lib.sh'; lab_instance_ids"
