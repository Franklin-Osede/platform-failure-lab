# 00 — Fundamentals: backend, lock, state, refresh, plan

Not an incident. Do this before breaking anything: every later scenario assumes
you can predict what these commands do and *why*.

Write your answers in `NOTES.md` in this folder, in your own words, before
looking anything up. The predictions you get wrong are the most useful part.

Prerequisite: `make bootstrap && make init && make up`.

## Hypothesis

Fill in Expected before running anything; fill in Actual from the run.
Exit codes with `-detailed-exitcode`: `0` no changes · `1` error · `2` changes present.

| Check | Expected | Actual |
|---|---|---|
| E1 `plan` after deleting `.terraform/`, without `init` | | |
| E2 `serial` changes after a no-change `apply`? | | |
| E3 `plan -lock-timeout=0s` while T1 holds the lock (exit code) | | |
| E3 `plan -lock-timeout=90s` while T1 holds the lock (exit code) | | |
| E3 `.tflock` object exists after T1 finishes? | | |
| E4 `plan` creates a new state version? | | |
| E4 no-change `apply` creates a new state version? | | |
| E5 `plan -detailed-exitcode`, nothing changed | | |
| E5 `plan -refresh-only -detailed-exitcode`, nothing changed | | |
| E5 `plan -detailed-exitcode -var owner=someone-else` | | |
| E5 `plan -refresh-only -detailed-exitcode -var owner=someone-else` | | |
| E6 `-refresh=false` faster? What does it stop seeing? | | |

---

## E1 — Where does the state actually live?

```bash
cat infra/.terraform/terraform.tfstate | jq '.backend'
aws s3 ls "s3://$(awk -F'"' '/^bucket/{print $2}' infra/backend.hcl)/platform-failure-lab/infra/"
```

- What is the local `.terraform/terraform.tfstate` file, if it is not the state?
- What happens if you delete `.terraform/` and run `terraform plan` without `init`?

## E2 — Anatomy of the state

```bash
terraform -chdir=infra state pull \
  | jq '{version, terraform_version, serial, lineage,
         resources: [.resources[] | "\(.mode).\(.type).\(.name)"]}'
```

- What do `serial` and `lineage` protect against? Which command checks them?
- Why do data sources (`data.aws_vpc.default`, …) appear in the state?
- Run `terraform apply` with no changes. Does `serial` change? Why or why not?

## E3 — Watch the lock live

Three terminals:

```bash
# T1: hold the lock for 60 s
terraform -chdir=infra apply -auto-approve -var slow_apply_seconds=60 -var run_id=$(date +%s)

# T2: while T1 runs, look at the lock object
B=$(awk -F'"' '/^bucket/{print $2}' infra/backend.hcl)
aws s3 cp "s3://$B/platform-failure-lab/infra/terraform.tfstate.tflock" - | jq .

# T3: try to plan while locked
terraform -chdir=infra plan -lock-timeout=0s
terraform -chdir=infra plan -lock-timeout=90s   # what changes?
```

- Which fields does the lock contain? Which one would you use to find who holds it?
- After T1 finishes, does the `.tflock` object still exist?
- Prediction for scenario 01: what happens to the lock on `Ctrl-C` vs `kill -9`?

Run `terraform -chdir=infra apply -auto-approve` afterwards so `time_sleep` is removed again.

## E4 — Every write is a version

```bash
B=$(awk -F'"' '/^bucket/{print $2}' infra/backend.hcl)
R=$(awk -F'"' '/^region/{print $2}' infra/backend.hcl)
aws s3api list-object-versions --region "$R" --bucket "$B" \
  --prefix platform-failure-lab/infra/terraform.tfstate \
  --query 'Versions[].{Key:Key,Latest:IsLatest,Modified:LastModified,Size:Size}' --output table
```

- Does a `plan` create a new version? Does an `apply` with no changes?
- How far back can you recover? (Hint: `bootstrap/main.tf`, lifecycle rule.)

## E5 — plan vs refresh-only

Change nothing and record the exit code of each:

```bash
terraform -chdir=infra plan -detailed-exitcode;               echo "exit=$?"
terraform -chdir=infra plan -refresh-only -detailed-exitcode; echo "exit=$?"
```

Now change the *code* (not AWS): `-var owner=someone-else`.

```bash
terraform -chdir=infra plan -detailed-exitcode -var owner=someone-else;               echo "exit=$?"
terraform -chdir=infra plan -refresh-only -detailed-exitcode -var owner=someone-else; echo "exit=$?"
```

Exit codes: `0` no changes · `1` error · `2` changes present.

- Why does the normal plan return 2 here and refresh-only return 0?
- So what does `plan -detailed-exitcode = 2` tell you about drift?
- What does `terraform apply -refresh-only` change, and what does it never change?

## E6 — Skipping refresh

```bash
time terraform -chdir=infra plan
time terraform -chdir=infra plan -refresh=false
```

- What do you gain with `-refresh=false`, and what can you no longer see?

---

When you can answer all of the above without notes, move to 01.
