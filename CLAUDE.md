# platform-failure-lab — working context

## What this repo is
A portfolio of reproducible infrastructure failures. Each scenario injects a
fault on purpose, observes it, diagnoses it, recovers, and verifies both the
failure and the recovery with automated checks that double as regression
tests. Owner: Franklin, Senior Platform & DevOps Engineer.

**Primary goal: technical understanding** of Terraform, IAM and Kubernetes
failure modes. **Secondary outcome:** verifiable evidence for a public
portfolio (READMEs, occasional short videos, posts). Everything runs in an
isolated lab AWS account.

The plan lives in `docs/roadmap.md` (4 phases, 20 scenarios). The scenario
format lives in `docs/experiment-template.md`. Read both before proposing work.

## Current focus
Phase 1, Lab 1: `00-fundamentals`, then `02-drift`. Do not start other
labs, multi-cloud work or new projects until the current scenario meets the
definition of done in the roadmap.

## Layout
- `bootstrap/` — S3 state bucket (local state, created once)
- `infra/` — lab stack; S3 backend with `use_lockfile = true` (no DynamoDB)
- `scenarios/NN-name/` — README + `inject.sh` / `observe.sh` / `verify.sh`
- `scripts/lib.sh` — shared helpers (`tf`, `capture`, `check`, `sanitize`)
- `evidence/` — sanitized command output, git-ignored

## Scenario contract (every scenario, no exceptions)
Setup → Inject → Observe → Diagnose → Recover → Verify → Cleanup.
- README sections: What this proves, Hypothesis (Expected/Actual table),
  the seven phases, Results, Interview angle.
- Acceptance criteria are objective and match the checks in `verify.sh`.
- `inject.sh` is reversible and only touches resources created by the lab.
- `observe.sh` changes nothing.
- `verify.sh` has two modes, both required:
  - `--expect-failure` proves the fault really happened, checking the actual
    mechanism (e.g. the lock object exists and *that* is why plan fails)
    and not just an exit code.
  - default mode proves the recovery, independently of the failure checks.
  Both exit non-zero on any failed `check`.
- Recovery that needs a judgement call (force-unlock, state push -force,
  restoring state versions, deleting resources) is documented, never scripted.

## Execution autonomy
- You may inspect, edit, refactor and test local repository files without
  asking for approval for each change: `fmt`, `validate`, shellcheck and
  `bash -n` included.
- Ask for explicit authorization before any cloud operation (`plan` included,
  since it calls AWS APIs), any destructive action, any external resource
  creation or anything that could cost money.
- Never run an injection against an environment that hasn't been positively
  identified as the isolated lab. Check the account with
  `aws sts get-caller-identity` and confirm it with me first.

## Hard rules
- Never automate `terraform force-unlock`.
- Security scenarios are simulation-first: policy simulation and Access
  Analyzer before any real call. Real calls only run in the isolated account,
  against resources created for that scenario.
- Never create, print, commit or publish real credentials, keys or tokens.
- All captured output goes through `sanitize` (account IDs masked). Flag
  anything else sensitive (ARNs, hostnames, IPs) before it reaches a README.
- No real employer names or internal details anywhere in the repo.

## Reproducibility
- Every scenario runs from a documented clean baseline (`make up` followed by
  a passing default-mode `verify.sh`).
- Document the Terraform, provider, AWS CLI and tool versions used for each
  recorded run, in the scenario's Results section.
- Terraform is pinned to a range (`>= 1.11.0, < 2.0.0`) and providers with
  `~>`. Commit `.terraform.lock.hcl`. Upgrade dependencies only on purpose,
  in a separate reviewed change, after checking provider compatibility.
- Don't assume earlier manual steps were done. If a step is required, it's
  in the README or a script.

## Verification quality
- A script exiting 0 is not proof of reproduction. The failure must be
  observed with `--expect-failure` before recovery, and that evidence kept.
- Keep evidence of both the failure and the recovery.
- Distinguish checks of infrastructure *state* (what exists) from checks of
  the failure *mechanism* (why it behaves that way).
- Never present a prediction as a result. Unverified behaviour stays in the
  Expected column until a run proves it.
- For version-specific behaviour (backends, import/moved/removed blocks,
  ephemeral values, write-only arguments, OIDC `sub` formats, provider
  changes), check the current official docs for the pinned version instead
  of relying on memory, and say when something is unverified.

## Learning methodology
- Optimize for understanding, not task completion speed.
- When investigating a failure, start with questions, then give progressively
  stronger hints. Don't reveal the root cause unless I ask for it.
- In `NOTES.md` and the Diagnose phase, don't give the answers unless I ask.
- Ask me to explain the mechanism and the production trade-offs in my own
  words. Push back if the explanation wouldn't hold up under senior
  questioning.

## Portfolio discipline
- Learning comes before content. A scenario can be complete without a
  video or a post.
- Publish only findings that are verified and that someone else can
  reproduce.
- Label every claim honestly: operated in production / observed / reproduced
  in a lab / would design. Don't overstate how lab results apply to
  production.

## Code conventions
- `default_tags` on every provider; `terraform fmt` clean; `validate` passing.
- Bash: `source scripts/lib.sh`, `set -euo pipefail`, shellcheck clean,
  macOS and Linux compatible (no GNU-only sed flags; use perl for regex).
- Smallest infrastructure that reproduces the failure. Every session must be
  cheap and end with `make down`.
- Before calling a scenario finished, check it against the definition of done
  in `docs/roadmap.md`, including the explain-without-notes gate.
