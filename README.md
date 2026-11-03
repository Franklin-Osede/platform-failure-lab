# Platform Failure Lab

Reproducible infrastructure failures: inject them on purpose, observe the
symptoms, diagnose, recover, and verify with an automated check that also
catches the failure if it comes back.

Everything here runs in an **isolated lab AWS account**. Every result is
labelled as a lab reproduction, not production experience.

## Why

Deploying infrastructure that works once proves little. The hard parts of
Terraform and platform work are state, locking, drift, identity and recovery:
what happens when things go wrong and how you prove they're fixed. Each
scenario here is a small, repeatable experiment around one of those.

## Scenarios

| # | Scenario | What it demonstrates | Status |
|---|---|---|---|
| 00 | [Fundamentals](scenarios/00-fundamentals/) | backend, lock, state anatomy, plan vs refresh-only | ⬜ |
| 01 | [Stuck lock](scenarios/01-stuck-lock/) | stale vs live S3 locks, safe `force-unlock` | ⬜ |
| 02 | [Drift](scenarios/02-drift/) | refresh-only detection, unmanaged blind spots, revert vs accept | ⬜ |
| 03 | [State recovery](scenarios/03-state-recovery/) | S3 versioning, `state push` safety checks, `import` blocks | ⬜ |

Next deliverables: [docs/roadmap.md](docs/roadmap.md). Every scenario follows
[the same seven phases](docs/experiment-template.md):
**Setup → Inject → Observe → Diagnose → Recover → Verify → Cleanup**.

## Layout

```
bootstrap/          S3 state bucket (local state, created once)
infra/              the lab stack: EC2 + security group, S3 backend with use_lockfile
scenarios/NN-name/  README + inject.sh / observe.sh / verify.sh
scripts/            shared helpers, cost check
docs/               experiment template, roadmap
evidence/           sanitized command output (git-ignored; curate into READMEs)
```

Scripts **inject, observe and verify**. Recovery steps that need a judgement call
(force-unlock, restoring state) are documented but deliberately not scripted.

## Prerequisites

- Terraform ≥ 1.11 (S3 native locking), AWS CLI v2, `jq`, `perl`, `make`,
  `shellcheck`. On macOS, install Terraform from `hashicorp/tap`: the
  homebrew-core formula is frozen at 1.5.7, which is too old for this repo.
- `make lint` runs every offline check (fmt, init without backend, validate,
  shellcheck) without touching AWS.
- A **dedicated** AWS account for labs, with a default VPC in the chosen region
  (default `eu-west-1`) and a budget alert set
- Credentials for that account in your shell (e.g. `aws sso login --profile lab`
  and `export AWS_PROFILE=lab`)

Versions: Terraform is pinned to `>= 1.11.0, < 2.0.0` and providers with `~>`.
After the first `make init`, commit `infra/.terraform.lock.hcl` and
`bootstrap/.terraform.lock.hcl`. Each scenario's Results section records the
exact versions used for that run (`terraform version`, `aws --version`).

## Quick start

```bash
make bootstrap   # once: state bucket + infra/backend.hcl
make init
make up          # baseline
# work through scenarios/00 → 03
make down        # destroy + confirm nothing is left running
```

## Cost

One `t3.micro` while a session is running, plus a few cents of S3. `make down`
ends every session and runs `scripts/check-costs.sh`, which fails if any lab
instance is still alive. The state bucket stays between sessions; remove it with
`terraform -chdir=bootstrap destroy -var force_destroy=true` when you're done for good.

## Publishing evidence

`scripts/lib.sh` masks 12-digit account IDs and strips colours from every
captured log. That's a safety net, not a review: read every excerpt before it
goes into a README, a video or a post.
