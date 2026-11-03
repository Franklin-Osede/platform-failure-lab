#!/usr/bin/env bash
# Observe: what Terraform wants to do vs what exists, and the state's history.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=03-state-recovery

echo "== Plan (read it; do not apply)"
capture "$SCENARIO" plan tf plan -detailed-exitcode -input=false

echo "== Baseline instance ID"
cat "$(evidence_dir "$SCENARIO")/baseline-instance-id.txt"

echo "== Lab instances that really exist in AWS"
capture "$SCENARIO" aws-instances bash -c "source '$LAB_ROOT/scripts/lib.sh'; lab_instance_ids"

echo "== State object history in S3 (versions and delete markers)"
# shellcheck disable=SC2016  # backticks are JMESPath literals, not shell
capture "$SCENARIO" state-versions aws s3api list-object-versions --region "$(aws_region)" \
  --bucket "$(state_bucket)" --prefix "$STATE_KEY" \
  --query '{Versions: Versions[?Key==`'"$STATE_KEY"'`].{Id:VersionId,Latest:IsLatest,Modified:LastModified,Size:Size},
           DeleteMarkers: DeleteMarkers[?Key==`'"$STATE_KEY"'`].{Id:VersionId,Latest:IsLatest,Modified:LastModified}}' \
  --output json
