#!/usr/bin/env bash
# Inject: make the state forget the instance. Usage: inject.sh A|B
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=03-state-recovery
variant="${1:-}"
baseline="$(evidence_dir "$SCENARIO")/baseline-instance-id.txt"

if [[ ! -s "$baseline" ]]; then
  echo "No baseline recorded. Run: ./scenarios/$SCENARIO/verify.sh --baseline" >&2
  exit 1
fi

case "$variant" in
  A)
    echo "Variant A: removing aws_instance.lab from state (the instance keeps running)"
    tf state rm aws_instance.lab
    ;;
  B)
    echo "Variant B: deleting the state object in S3 (versioning keeps a delete marker)"
    aws s3 rm --region "$(aws_region)" "s3://$(state_bucket)/$STATE_KEY"
    ;;
  *)
    echo "Usage: $0 A|B" >&2
    exit 1
    ;;
esac

echo
echo "!!! Do NOT run 'terraform apply' now. That would be the incident. !!!"
echo "Next: ./scenarios/$SCENARIO/observe.sh"
