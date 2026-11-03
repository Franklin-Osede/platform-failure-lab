# 02 — Drift: changes made outside Terraform

## What this proves

- I can separate **"the code changed"** from **"the world changed"**:
  `plan -detailed-exitcode` mixes both; `plan -refresh-only -detailed-exitcode`
  isolates changes made outside Terraform.
- I know Terraform only sees drift on what it **manages**. An unmanaged rule can
  be invisible to a normal plan.
- I choose deliberately between **reverting** the drift and **accepting** it.

## Hypothesis

Two out-of-band changes, made with the AWS CLI as if from the console:

1. The instance's `Owner` tag is changed → a **managed** attribute.
2. An SSH ingress rule is added to the security group → **no resource manages
   ingress** (rules are separate resources and none exists for ingress).
   The source CIDR is `203.0.113.0/24` (a documentation range) and the instance
   has no public IP, so nothing is actually exposed.

Fill in the Actual column; a wrong prediction is a finding, not a failure.

| Check | Expected | Actual |
|---|---|---|
| `plan -detailed-exitcode` | 2 — proposes reverting the tag | |
| …does it mention the SSH rule? | no — nothing manages ingress | |
| `plan -refresh-only -detailed-exitcode` | 2 — reports objects changed outside Terraform | |
| …does it mention the SSH rule? | probably, via the security group's read-only `ingress` attribute | |
| `terraform apply` removes the SSH rule? | no | |

## Setup

```bash
make up
./scenarios/02-drift/verify.sh    # baseline must PASS
```

## Inject

```bash
./scenarios/02-drift/inject.sh
```

## Observe

```bash
./scenarios/02-drift/observe.sh
./scenarios/02-drift/verify.sh --expect-failure   # must PASS: proves the fault really happened
```

Captures both plans and the actual security group rules from AWS.

## Diagnose

1. Which differences appear in refresh-only but **not** as proposed actions in
   the normal plan? Those are things Terraform sees but doesn't own.
2. Which appear in the normal plan? Those are things Terraform will overwrite.
3. In a real team: who made the change, and why? (CloudTrail: `CreateTags`,
   `AuthorizeSecurityGroupIngress`.) The answer decides revert vs accept.

## Recover — choose one per change

**Revert** (the code is right, the change was a mistake):

```bash
terraform -chdir=infra apply                 # puts the Owner tag back
SG=$(terraform -chdir=infra output -raw security_group_id)
aws ec2 revoke-security-group-ingress --group-id "$SG" \
  --ip-permissions 'IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=203.0.113.0/24}]'
terraform -chdir=infra apply -refresh-only   # record reality in state; changes no infra
```

The SSH rule needs the CLI because Terraform never owned it — `apply` can't
remove what no resource declares. (Alternative: adopt it with an `import` block
as an `aws_vpc_security_group_ingress_rule`, then delete it from code. That's
scenario-03 / Lab 4 material.)

**Accept** (the change was right, the code is outdated): change the code to match
(e.g. `owner` variable) until `plan` shows no changes. Note that
`apply -refresh-only` alone does **not** accept drift: it updates the state, but
the next normal plan still proposes to revert, because the code still disagrees.

## Verify

```bash
./scenarios/02-drift/verify.sh
```

- `plan -refresh-only -detailed-exitcode` = 0 (state matches reality)
- `plan -detailed-exitcode` = 0 (code matches state)
- the security group has zero ingress rules in AWS

Regression guard: in Deliverable 2 the refresh-only check runs on a schedule in
GitHub Actions and opens an issue when it returns 2.

## Cleanup

```bash
make down
```

## Results

_Paste curated excerpts from `evidence/02-drift/` here._

## Interview angle

"`plan` exit code 2 doesn't mean drift — it can just mean someone changed the code.
I detect drift with refresh-only, and I know its blind spot: anything Terraform
doesn't manage. In the lab, a hand-added SSH rule never showed up as a planned
change."
