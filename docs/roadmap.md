# Roadmap

Four phases, 20 scenarios, about 24 weeks. The durations are a guide, not a
deadline: CKA comes first, and every phase moves if the exam moves.

## Rules

- **One lab at a time.** Fixed cadence (one scenario per week). Publish only when
  there is a verifiable result, never to fill a calendar.
- **Isolated lab account only.** Every session ends with `make down`.
- **Security scenarios go simulation-first.** Policy simulation and controlled
  authorization tests come first. Real exploitation steps only run in the
  isolated account, against resources created for the scenario, with
  permissions granted explicitly for it.
- **Never publish real credentials**, not even "dead" ones, and never push a
  key to a public repo to "see what happens".

## Definition of done (every scenario)

1. `verify.sh --expect-failure` passed **after injecting and before
   recovering**, proving the fault really happened, and the default-mode
   `verify.sh` passes after recovery. Their checks match the scenario's
   acceptance criteria.
2. The Expected/Actual table is filled in, wrong predictions included.
3. Results contains sanitized, reviewed evidence of **both** the failure and
   the recovery, plus the Terraform, provider and AWS CLI versions used.
4. **Explain-without-notes gate:** without opening the README, you can explain
   - why the incident happened,
   - how you investigated it,
   - which alternatives you had and why you chose this one,
   - what you would do differently in production.

   Record a 2-minute voice note or video answering these four. If you can't,
   the scenario isn't done.

**Phase gate:** you move to the next phase when every scenario in the current one
meets the definition of done, not when the weeks run out.

---

## Phase 1 — Terraform core + CI/CD (≈ 6 weeks, alongside CKA prep)

### Lab 1: State & Drift

| # | Scenario | Acceptance criteria | Senior skill shown |
|---|---|---|---|
| 00 | Fundamentals | All E1–E6 questions answered in `NOTES.md` in your own words; every predicted exit code recorded next to the real one | Precise mental model of backend, lock, state, refresh and plan |
| 01 | Stuck lock | `.tflock` present after SIGKILL; lock owner proven dead before unlocking; afterwards lock absent and `plan` exit 0 | Tells a stale lock from a live one; won't automate `force-unlock` |
| 02 | Drift | Both changes classified (managed vs unmanaged); revert **and** accept each done once; refresh-only = 0, plan = 0, zero ingress rules | Separates "code changed" from "world changed"; knows the unmanaged blind spot |
| 03 | State recovery | Variants A and B both injected; `state push` refusal recorded; the original instance ID is back in state; exactly one instance exists | Spots "+ create" for an existing resource; knows which recovery paths bypass safety checks |

### Lab 2: GitHub Actions + OIDC

| # | Scenario | Acceptance criteria | Senior skill shown |
|---|---|---|---|
| 04 | OIDC trust conditions | See notes below. Matrix of trust-policy variants × caller repo/branch/environment, with the **observed** result of `AssumeRoleWithWebIdentity` for each; final policy pins `aud` and an exact `sub`; a test proves an unauthorized repo/branch is denied | Designs least-privilege federation and verifies it, instead of assuming it |
| 05 | Plan/apply pipeline | Plan posted on every PR; apply only after merge and manual approval in a protected environment; no static AWS keys in the repo or its secrets | Safe delivery workflow with human gates |
| 06 | Scheduled drift detection | Uses `plan -refresh-only -detailed-exitcode`; exit 2 opens one issue (no duplicates); exit 1 fails loudly; re-running scenario 02's injection triggers it | Turns an incident into continuous detection |

**Notes on 04.** A trust policy with weak `sub` conditions is dangerous, but how
dangerous depends on the real conditions: `aud`, the `sub` format (repo, branch,
environment, pull request) and whether AWS accepts the policy at all. GitHub's
documentation tells you to define at least one condition and recommends
evaluating `sub`. It also notes that repositories created after July 15, 2026
use immutable owner and repository IDs in `sub`, which changes what a correct
pattern looks like. Before writing the tests, re-check that claim and the
current `sub` format, trust-policy conditions and claim customization options
against the current GitHub and AWS documentation. So the scenario does not assert "any repository can assume
the role". It measures. Try to create each variant, record whether IAM accepts
it, and test who can assume it from two repos you own. If AWS rejects a weak
variant, that rejection is a result too.

**End of Phase 1:** Terraform Associate review (see the study track below).
The labs cover a lot of the syllabus, but not all of it. Book the exam only
after the independent review.

---

## Phase 2 — IAM + advanced Terraform (≈ 6 weeks, after CKA)

### Lab 3: IAM (simulation first)

Each IAM scenario has two stages:
- **(a) Simulate.** Use `aws iam simulate-principal-policy` / `simulate-custom-policy`
  and IAM Access Analyzer policy validation.
- **(b) Controlled authorization test.** Run real calls in the isolated account,
  against resources created for the scenario.

| # | Scenario | Acceptance criteria | Senior skill shown |
|---|---|---|---|
| 07 | `iam:PassRole` escalation | (a) simulation shows the risky combination as allowed; (b) a test role created for this proves the path; after the fix (scoped `PassRole` with `iam:PassedToService` + permission boundary) both simulation and test show denied | Reads policies as attack paths, not lists of actions |
| 08 | SCP explicit deny | Identity policy allows, SCP denies; simulation and real call both denied; you can explain the evaluation order. Needs an AWS Organization; if you don't want one, use a permission boundary to show the same "explicit deny wins" logic and mark the SCP part as studied, not reproduced | Policy evaluation logic across layers |
| 09 | KMS key policy lockout | Done on a throwaway key: the policy that would remove your own access is submitted **without** bypassing KMS's policy lockout safety check, and the refusal is recorded; the same mistake is caught earlier in plan review; recovery options documented, not exercised; key scheduled for deletion at the end | Knows KMS key policies are the primary control, not IAM, and which guardrails AWS already provides |
| 10 | Exposed access key | Simulated with a short-lived test user's key used from an unexpected context (never published); detection via CloudTrail queries; response = deactivate, investigate, delete; replacement = OIDC/roles | Incident response for credentials, and removing the root cause |

### Lab 4: Terraform refactoring

| # | Scenario | Acceptance criteria | Senior skill shown |
|---|---|---|---|
| 11 | Module extraction with `moved` | Code moved into a module; plan shows only moves, **0 to add, 0 to destroy**; resource IDs unchanged | Refactors production code without recreation |
| 12 | Adopt click-ops with `import` | Resources created by hand are imported with `import` blocks; plan = 0 after import; config generated with `-generate-config-out` reviewed and cleaned up | Brings unmanaged infrastructure under control |
| 13 | Major provider upgrade | Pinned old version → new major; every breaking change found from the plan and upgrade guide, fixed, plan = 0; `.terraform.lock.hcl` change reviewed | Controlled dependency upgrades |
| 14 | State split | One state split into two with `removed` + `import` (or `moved` across modules where it applies) without recreation; cross-stack references via outputs/data sources | Reduces blast radius with state boundaries |

---

## Phase 3 — Kubernetes + recovery (≈ 6 weeks)

### Lab 5: Workload identity and RBAC

| # | Scenario | Acceptance criteria | Senior skill shown |
|---|---|---|---|
| 15 | kubeadm cluster via Terraform | Multi-node kubeadm cluster on EC2 created and destroyed from code; reused for CKA practice (etcd backup, upgrades) | IaC for clusters, not just cloud services |
| 16 | Over-privileged ServiceAccount | `kubectl auth can-i --as=system:serviceaccount:…` shows excess rights; after the fix only the required verbs remain; test proves it | Least-privilege RBAC with evidence |
| 17 | Pod using the node role | On a short-lived EKS cluster (created and destroyed the same day): a pod inherits node permissions; fixed with Pod Identity/IRSA; `sts get-caller-identity` from the pod shows the dedicated role; IMDS access restricted | Workload isolation in the cloud |

### Lab 6: Destructive changes

| # | Scenario | Acceptance criteria | Senior skill shown |
|---|---|---|---|
| 18 | Rename that destroys | A rename produces destroy/create in the plan; caught by review + `prevent_destroy`; fixed with `moved` | Reads plans for blast radius before applying |
| 19 | Replacement without downtime | Force a replacement; with `create_before_destroy` the new resource exists before the old one is removed; availability check during the apply | Lifecycle control for zero-downtime changes |
| 20 | Secrets in state | Show a secret stored in state with a normal argument; remove it using ephemeral values / write-only arguments; `state pull` proves it's no longer stored | Secret handling in IaC (exam objective 4h too) |

---

## Phase 4 — Multi-cloud (≈ 6 weeks, not before Phases 1–3)

Replicate only the patterns where the comparison teaches something:

- **Azure:** azurerm backend (locking via blob lease), federated credentials for
  GitHub Actions, managed identity
- **GCP:** GCS backend, Workload Identity Federation, GKE Workload Identity
- **Output:** a comparison of locking, identity federation and failure modes
  across AWS, Azure and GCP, each claim backed by a scenario in this repo

---

## Terraform Associate (004) study track

The exam tests **Terraform 1.12**. Sources: the official
[exam content list](https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004)
and study guide. The labs cover part of the syllabus. This track covers the rest.

| Objective area | Covered by labs | Study separately |
|---|---|---|
| 1 IaC concepts, multi-cloud workflows | Phase 4 | Read-through |
| 2 Providers, multiple providers, state | 00, 13 | Provider aliases, multiple providers in one config |
| 3 Core workflow (init/validate/plan/apply/destroy/fmt) | all | — |
| 4a–e Resources, data, variables, types, expressions | infra code | Complex types, `for` expressions, functions |
| 4f Dependencies | 18, 19 | `depends_on` vs implicit dependencies |
| 4g Custom conditions | `variables.tf` validation | `precondition`, `postcondition`, `check` blocks |
| 4h Sensitive data, Vault, ephemeral values, write-only arguments | 20 | Vault provider basics |
| 5 Modules, sources, scope, versions | 11 | Registry modules, version constraints |
| 6 Local/remote backends, locking, drift | 00–03, 06 | Local backend behaviour |
| 7 Import, state CLI, verbose logging | 03, 12 | `TF_LOG` / `TF_LOG_PATH` |
| 8 HCP Terraform: workspaces, projects, governance, integration | — | **Hands-on with the free tier:** create a workspace and a project, VCS-driven run, variable sets, `cloud` block; read about policies and run tasks |

Before booking: two full practice exams, plus a revision pass on objective 8,
which none of the labs cover.

---

## Content

Learning comes first. A scenario is complete without a video or a post.
When a result is worth publishing: a 60–120 s video, one post, the README as
proof. Strongest
candidates: 02 (drift), 04 (OIDC conditions), 07 (PassRole), 17 (pod with the
node role), and the multi-cloud comparison. Every post is labelled as a lab.
The repo can be public now. It gets announced only after Lab 1 is done.

## Now

Complete `00-fundamentals`, then reproduce `02-drift` with verifiable evidence.
No multi-cloud work and no new projects until then.
