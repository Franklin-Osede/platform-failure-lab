# 03 — State recovery: the resource exists, the state forgot it

## What this proves

- I recognise the most dangerous plan in Terraform: **"+ create"** for something
  that already exists. Applying it creates a duplicate (or fails on a name clash).
- I can recover state from **S3 versioning**, and I know which Terraform safety
  checks (`serial`, `lineage`) that path bypasses.
- I can rebuild the link without old state, using an **`import` block**.

## Variants

| Variant | Inject | Realistic cause |
|---|---|---|
| A | `terraform state rm aws_instance.lab` | someone "cleaned up" state by hand |
| B | delete the state object in S3 | a bad script, a wrong bucket in a cleanup job |

## Hypothesis

| Check | Variant A expected | Variant B expected | Actual |
|---|---|---|---|
| `plan` | 1 to add (the instance) | 3 to add (everything) | |
| Original instance in AWS | still running | still running | |
| S3 shows | a new, smaller latest version | a delete marker as latest | |
| `state push` of the old version | refused (older serial) unless `-force` | n/a | |

## Setup

```bash
make up
./scenarios/03-state-recovery/verify.sh --baseline   # records the instance ID, must PASS
```

## Inject

```bash
./scenarios/03-state-recovery/inject.sh A    # or B
```

⚠️ After injecting, **do not run `terraform apply`**. That is the incident.

## Observe

```bash
./scenarios/03-state-recovery/observe.sh
./scenarios/03-state-recovery/verify.sh --expect-failure   # must PASS: proves the fault really happened
```

Captures the plan (wants to create), the state object versions and delete
markers in S3, and the instances that really exist.

## Diagnose

1. Does the plan want to create something that already exists? Compare the
   plan with `lab_instance_ids` in observe output.
2. What happened to the state object? Latest version smaller than before
   (variant A) or a delete marker (variant B)?
3. Which version is the last good one? Check `serial`, `lineage` and the
   resource list *before* restoring anything:

```bash
B=$(awk -F'"' '/^bucket/{print $2}' infra/backend.hcl)
K=platform-failure-lab/infra/terraform.tfstate
aws s3api get-object --bucket "$B" --key "$K" --version-id <VERSION_ID> /tmp/candidate.tfstate
jq '{serial, lineage, resources: [.resources[] | "\(.type).\(.name)"]}' /tmp/candidate.tfstate
```

## Recover — try each path at least once

**Path 1 — Terraform's own route first (variant A):**

```bash
terraform -chdir=infra state push /tmp/candidate.tfstate
```

Expect a refusal: the candidate has a lower serial than the current state.
That refusal is a safety feature. Record the error. `-force` overrides it — only
when you have verified the lineage matches and nobody else is writing.

**Path 2 — restore the S3 version (variant A):**

```bash
aws s3api copy-object --bucket "$B" --key "$K" --copy-source "$B/$K?versionId=<VERSION_ID>"
```

This bypasses Terraform completely: no lock, no serial check. Do it only when
no one else can be running Terraform against this state.

**Path 3 — remove the delete marker (variant B):**

```bash
aws s3api delete-object --bucket "$B" --key "$K" --version-id <DELETE_MARKER_VERSION_ID>
```

**Path 4 — re-adopt with an import block (variant A, no old state needed):**

```bash
cp scenarios/03-state-recovery/imports.tf.example infra/imports.tf
# edit the instance ID, then:
terraform -chdir=infra plan     # expect: 1 to import, 0 to add
terraform -chdir=infra apply
rm infra/imports.tf
```

For variant B, import alone means re-importing every resource; restoring the
version is the right tool there.

## Verify

```bash
./scenarios/03-state-recovery/verify.sh
```

- `plan -detailed-exitcode` = 0
- the instance in state is the **same ID** recorded at baseline
- exactly **one** lab instance exists in AWS (no duplicate)

## Cleanup

```bash
make down
```

## Prevention (what I'd put in a real team)

- Versioning on the state bucket is mandatory, with a retention window.
- Write access to the state bucket only for the pipeline role; humans read-only.
- `terraform state` subcommands in a reviewed runbook, not ad hoc.

## Results

_Paste curated excerpts from `evidence/03-state-recovery/` here._

## Interview angle

"The scariest plan output is '+ create' for a resource that already exists. In the
lab I lost state two ways and recovered it three ways — and I can explain which
of those bypass Terraform's own safety checks."
