#!/usr/bin/env bash
# Observe: compare what each plan mode reports with what AWS actually has.
source "$(dirname "$0")/../../scripts/lib.sh"
require_tools

SCENARIO=02-drift
sg_id="$(tf output -raw security_group_id)"

echo "== Normal plan: what Terraform would CHANGE"
capture "$SCENARIO" plan tf plan -detailed-exitcode -input=false

echo "== Refresh-only plan: what changed OUTSIDE Terraform"
capture "$SCENARIO" plan-refresh-only tf plan -refresh-only -detailed-exitcode -input=false

echo "== Reality: security group rules in AWS"
capture "$SCENARIO" sg-rules aws ec2 describe-security-group-rules --region "$(aws_region)" \
  --filters "Name=group-id,Values=$sg_id" \
  --query 'SecurityGroupRules[].{Egress:IsEgress,Proto:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4,Desc:Description}' \
  --output table
