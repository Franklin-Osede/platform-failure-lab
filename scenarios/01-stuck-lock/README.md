# 01 — Stuck state lock after an interrupted apply

## What this proves

- I can tell a **stale** lock from a **live** one before touching it.
- I know where the S3 native lock lives (`<key>.tflock`) and what it records.
- I release a lock only after proving no operation still owns it — and I never
  automate `force-unlock`.

## Hypothesis

`Ctrl-C` makes Terraform stop gracefully and release the lock. `kill -9` gives it
no chance to clean up, so the `.tflock` object stays in S3 and every later
operation fails with `Error acquiring the state lock` until a human resolves it.

| Check | Expected | Actual |
|---|---|---|
| `.tflock` exists after `kill -9` | yes | |
| `plan` after the kill | exit 1, lock error with Lock Info | |
| Resources half-created? | no (only `time_sleep` was in flight) | |
| `plan` after `force-unlock` | exit 0 | |

## Setup

```bash
make up            # baseline: instance + security group
./scenarios/01-stuck-lock/verify.sh   # should already PASS: no lock, no changes
```

## Inject

```bash
./scenarios/01-stuck-lock/inject.sh
```

Starts an apply that holds the lock for 300 s (`time_sleep`), waits until the
sleep is in progress, then sends `SIGKILL` to the Terraform process.

## Observe

```bash
./scenarios/01-stuck-lock/observe.sh
./scenarios/01-stuck-lock/verify.sh --expect-failure   # must PASS: proves the fault really happened
```

Captures the blocked `plan`, the content of the `.tflock` object, running
Terraform processes and the resources currently in state.

## Diagnose (manual on purpose)

Answer before recovering:

1. **Who holds the lock?** `Who`, `Operation` and `Created` in the lock info.
2. **Is that operation still alive?** No Terraform process on this machine
   (observe.sh) and — in a team — no CI job running against this state.
   If you can't prove it's dead, *wait*: a live apply releases its own lock.
3. **What did the interrupted apply leave behind?** Compare `state list` with the
   resources in AWS. Here the answer should be "nothing", because the only
   operation in flight was the sleep. With a real resource in flight, it could
   exist in AWS but not in state — that becomes scenario 03.

## Recover (manual on purpose)

```bash
LOCK_ID=<ID from the lock info>
terraform -chdir=infra force-unlock "$LOCK_ID"   # interactive confirmation; read it
```

Why not script this: the only safe input to `force-unlock` is a human decision
that the owner is dead. A script can't make that decision; it can only skip it.

## Verify

```bash
./scenarios/01-stuck-lock/verify.sh
```

- `.tflock` object no longer exists
- `plan -detailed-exitcode` returns 0 (state and AWS agree, nothing pending)

Regression guard: `verify.sh` is the test. Run it at the start and end of every
session; a leftover lock fails it immediately.

## Cleanup

```bash
make down    # destroy + check-costs
```

## Results

_Paste curated, reviewed excerpts from `evidence/01-stuck-lock/` here: the lock
error, the lock JSON, the PASS lines._

## Interview angle

"In a lab I reproduced a stuck S3 state lock by killing an apply with SIGKILL.
The fix is one command; the work is proving the lock owner is dead first. That's
why I'd never wire `force-unlock` into a pipeline."
