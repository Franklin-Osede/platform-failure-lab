#!/usr/bin/env bash
# Inject: two out-of-band changes, as if made in the console.
# shellcheck source=scripts/lib.sh
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

region="$(aws_region)"
instance_id="$(tf output -raw instance_id)"
sg_id="$(tf output -raw security_group_id)"

echo "1/2 Changing Owner tag on the instance (managed attribute)"
aws ec2 create-tags --region "$region" --resources "$instance_id" \
  --tags Key=Owner,Value=changed-in-console

echo "2/2 Adding SSH ingress from 203.0.113.0/24 (unmanaged: no resource owns ingress)"
aws ec2 authorize-security-group-ingress --region "$region" --group-id "$sg_id" \
  --ip-permissions 'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=203.0.113.0/24,Description=pfl-drift-injection}]' \
  >/dev/null

echo "Drift injected. Next: ./scenarios/02-drift/observe.sh"
