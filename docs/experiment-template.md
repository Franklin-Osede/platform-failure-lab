# Experiment template

Every scenario follows the same seven phases. Copy this into a new
`scenarios/NN-name/README.md`.

```markdown
# NN — <incident in one line>

## What this proves
<2–3 bullets a senior engineer would actually ask about>

## Hypothesis
<what you expect and why>

| Check | Expected | Actual |
|---|---|---|

## Setup      — reach a known-good baseline; verify.sh must PASS before injecting
## Inject     — the controlled fault (inject.sh); reversible, isolated account only
## Observe    — symptoms and evidence, changes nothing (observe.sh);
##              then verify.sh --expect-failure must PASS (the fault really happened)
## Diagnose   — questions to answer before touching anything (manual)
## Recover    — the fix, with the reasoning; manual when it needs a judgement call
## Verify     — automated checks (verify.sh); doubles as the regression test
## Cleanup    — make down; check-costs must report nothing running

## Results
<curated, reviewed evidence excerpts>

## Interview angle
<how you'd tell it in 30 seconds, labelled as a lab>
```

## Rules

- **Isolated lab account only.** Never a shared or work account.
- **Predict before running.** Fill the Expected column first; a wrong prediction
  is a finding.
- **Recovery that needs a judgement call stays manual** (force-unlock, restoring
  state, state push -force). Scripts observe and verify; humans decide.
- **Evidence is sanitized and reviewed** before it goes in a README, a video or a
  post. No account IDs, ARNs with account IDs, keys or real hostnames.
- **Label it honestly:** operated in production / observed / reproduced in a lab /
  would design.
