#!/usr/bin/env bash
# Lists anything from this lab that can still cost money. Exit 1 if instances remain.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/lib.sh"
require_tools

region="$(aws_region)"
echo "Region: $region"

echo "--- EC2 instances tagged Project=$PROJECT_TAG (not terminated)"
ids="$(lab_instance_ids)"
if [[ -n "$ids" ]]; then
  read -r -a id_list <<<"$ids"
  aws ec2 describe-instances --region "$region" --instance-ids "${id_list[@]}" \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]' --output table
else
  echo "none"
fi

echo "--- Security groups named pfl-lab-* (free, but should be gone after destroy)"
aws ec2 describe-security-groups --region "$region" \
  --filters "Name=group-name,Values=pfl-lab-*" \
  --query 'SecurityGroups[].[GroupId,GroupName]' --output text || true

echo "--- State bucket (pennies; kept between sessions on purpose)"
state_bucket

if [[ -n "$ids" ]]; then
  echo "WARNING: lab instances are still running. Run 'make down'." >&2
  exit 1
fi
echo "OK: no lab instances running."
