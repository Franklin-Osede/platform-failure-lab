#!/usr/bin/env bash
# Verify the scenario in one of two modes. Exit 1 on any failed check.
#   verify.sh                  -> recovered: no drift, nothing pending, no ingress
#   verify.sh --expect-failure -> injected: both out-of-band changes really exist in AWS
#                                 and refresh-only reports drift
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=02-drift
VERIFY_FAILED=0
mode="${1:-recovered}"
region="$(aws_region)"
sg_id="$(tf output -raw security_group_id)"
instance_id="$(tf output -raw instance_id)"

# shellcheck disable=SC2016  # backticks are JMESPath literals, not shell
ingress="$(aws ec2 describe-security-group-rules --region "$region" \
  --filters "Name=group-id,Values=$sg_id" \
  --query 'length(SecurityGroupRules[?IsEgress==`false`])' --output text)"
owner="$(aws ec2 describe-tags --region "$region" \
  --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Owner" \
  --query 'Tags[0].Value' --output text)"

if [[ "$mode" == "--expect-failure" ]]; then
  # Check AWS directly first: the fault must exist independently of what Terraform says.
  check "Owner tag changed in AWS" "changed-in-console" "$owner"
  check "injected ingress rules in AWS" "1" "$ingress"

  capture "$SCENARIO" verify-failure-refresh-only tf plan -refresh-only -detailed-exitcode -input=false
  check "refresh-only reports outside changes" "2" "$LAST_RC"
else
  capture "$SCENARIO" verify-refresh-only tf plan -refresh-only -detailed-exitcode -input=false
  check "plan -refresh-only (no outside changes)" "0" "$LAST_RC"

  capture "$SCENARIO" verify-plan tf plan -detailed-exitcode -input=false
  check "plan (code matches state)" "0" "$LAST_RC"

  check "ingress rules in AWS" "0" "$ingress"
  # The Owner tag needs no separate check here: refresh-only = 0 and plan = 0
  # together prove AWS, state and code agree, whether you reverted or accepted.
  echo "INFO  Owner tag in AWS: $owner"
fi

exit "$VERIFY_FAILED"
