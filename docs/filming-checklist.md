# Filming-day checklist

One scenario per day. Resources are created the same day and destroyed the
same day. Nothing below runs against AWS until section 2.

## 1. The day before (offline, no AWS)

- [ ] `git status` clean, on `main`.
- [ ] `make lint` passes (fmt, init without backend, validate, shellcheck).
- [ ] The scenario's **Expected** column is filled in and committed, so the
      prediction is provably made before the run.
- [ ] `NOTES.md` questions for the scenario answered in your own words.
- [ ] You can say the scenario's hypothesis out loud in about 30 seconds.
- [ ] Terminal ready for recording: large font, a prompt that shows no
      hostname, username, account or profile; shell history cleared; no
      `env`, `aws configure list` or `~/.aws` on screen.
- [ ] Screen recorder set to one window only (no notifications, no browser
      tabs with the AWS console signed in).

## 2. Pre-flight on the day (AWS; off camera)

```bash
aws sso login --profile lab
export AWS_PROFILE=lab AWS_REGION=eu-west-1
```

- [ ] **Right account.** Off camera, because the output contains the account ID:

  ```bash
  aws sts get-caller-identity
  aws iam list-account-aliases   # a non-numeric alias is a safe on-camera check
  ```

  The `Account` must be the isolated lab account. If anything is unexpected,
  stop.

- [ ] **Default VPC exists in eu-west-1**, with default subnets:

  ```bash
  aws ec2 describe-vpcs --region eu-west-1 --filters Name=is-default,Values=true \
    --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock}' --output table
  aws ec2 describe-subnets --region eu-west-1 --filters Name=default-for-az,Values=true \
    --query 'length(Subnets)'
  ```

- [ ] **Budget alert exists** (output may include alert emails: off camera):

  ```bash
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  aws budgets describe-budgets --account-id "$ACCOUNT_ID" \
    --query 'Budgets[].{Name:BudgetName,Limit:BudgetLimit.Amount,Unit:BudgetLimit.Unit,Type:BudgetType}' \
    --output table
  aws budgets describe-notifications-for-budget --account-id "$ACCOUNT_ID" \
    --budget-name "<name from the table>"
  ```

  Billing data lags by hours, so a budget alert is a backstop, not a kill
  switch. `make down` is the real control.

- [ ] **Nothing left over** from a previous session: `make costs` reports
      no lab instances.
- [ ] **Versions recorded** for the Results section:

  ```bash
  terraform version
  aws --version
  grep -A1 'provider "registry' infra/.terraform.lock.hcl
  ```

## 3. Recording order

Start recording here. Follow the scenario README; the order is always:

1. **Hypothesis**: show the Expected column and say what you predict and why.
2. **Setup**: `make up` (first day only: `make bootstrap && make init` before
   it), then `./scenarios/NN-*/verify.sh` must **PASS** (baseline).
3. **Inject**: `./scenarios/NN-*/inject.sh`.
4. **Observe**: `./scenarios/NN-*/observe.sh`, then
   `./scenarios/NN-*/verify.sh --expect-failure` must **PASS**. This is the
   proof the fault happened; don't recover before you have it.
5. **Diagnose**: think out loud through the README questions *before*
   touching anything.
6. **Recover**: run the manual steps and say why you chose them.
7. **Verify**: `./scenarios/NN-*/verify.sh` must **PASS**.
8. **Cleanup**: `make down`. It must end with `OK: no lab instances running.`

### What is safe to show

- Script output (`observe.sh`, `verify.sh`) goes through `sanitize`, which
  masks account IDs and nothing else.
- Raw `terraform plan` / `apply` output is **not** sanitized and can contain
  ARNs with the account ID (e.g. `arn`, `owner_id`). On camera, save the plan
  and show it sanitized, then apply the saved plan (no prompt to get stuck in
  a pipe):

  ```bash
  terraform -chdir=infra plan -out=recover.tfplan 2>&1 \
    | perl -pe 's/\e\[[0-9;]*m//g; s/\b\d{12}\b/<ACCOUNT_ID>/g'
  terraform -chdir=infra apply recover.tfplan
  ```

  Otherwise blur in editing.
- Never show: credentials, `sts get-caller-identity`, budget subscribers,
  `infra/backend.hcl` contents.

## 4. After recording (same day)

- [ ] `make down` again if anything was re-created; `make costs` → OK.
- [ ] Review every file in `evidence/<scenario>/` before using it: account
      IDs masked, no ARNs, hostnames or IPs that shouldn't be public.
- [ ] Fill in the **Actual** column, including wrong predictions.
- [ ] Paste curated evidence of **both** failure and recovery into Results,
      with the versions from section 2.
- [ ] Record the 2-minute explain-without-notes voice note
      (see `docs/roadmap.md`, definition of done).
- [ ] Next day: check Cost Explorer / Billing for the session's cost.
