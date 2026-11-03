#!/usr/bin/env bash
# Shared helpers for scenario scripts. Source it, don't run it.

set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$LAB_ROOT/infra"
STATE_KEY="platform-failure-lab/infra/terraform.tfstate"
LOCK_KEY="${STATE_KEY}.tflock"
PROJECT_TAG="platform-failure-lab"
# shellcheck disable=SC2034  # read by the sourcing script after capture()
LAST_RC=0

tf() { terraform -chdir="$INFRA_DIR" "$@"; }

require_tools() {
  local missing=0
  for t in terraform aws jq perl; do
    command -v "$t" >/dev/null 2>&1 || { echo "missing tool: $t" >&2; missing=1; }
  done
  [[ -f "$INFRA_DIR/backend.hcl" ]] || { echo "infra/backend.hcl not found: run 'make bootstrap' first" >&2; missing=1; }
  [[ $missing -eq 0 ]] || exit 1
}

backend_value() { awk -F'"' -v k="$1" '$1 ~ "^"k"[[:space:]]*=" {print $2}' "$INFRA_DIR/backend.hcl"; }
state_bucket() { backend_value bucket; }
aws_region() { backend_value region; }

# Mask 12-digit AWS account IDs and strip ANSI colours, so evidence can be
# shown in videos and READMEs. Still review every log before publishing.
sanitize() { perl -pe 's/\e\[[0-9;]*m//g; s/\b\d{12}\b/<ACCOUNT_ID>/g'; }

evidence_dir() {
  local d="$LAB_ROOT/evidence/$1"
  mkdir -p "$d"
  echo "$d"
}

# capture <scenario> <name> <command...>
# Runs the command, prints and stores sanitized output, records the exit code
# in LAST_RC and in the log. Never aborts the calling script.
capture() {
  local scenario=$1 name=$2
  shift 2
  local out
  out="$(evidence_dir "$scenario")/$(date +%Y%m%d-%H%M%S)-$name.log"
  echo "\$ $*" | sanitize >"$out"
  set +e
  "$@" 2>&1 | sanitize | tee -a "$out"
  LAST_RC=${PIPESTATUS[0]}
  set -e
  echo "[exit code: $LAST_RC]" | tee -a "$out"
  echo "[evidence: ${out#"$LAB_ROOT"/}]"
}

check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    echo "PASS  $1 (expected $2, got $3)"
  else
    echo "FAIL  $1 (expected $2, got $3)"
    # shellcheck disable=SC2034  # read by the sourcing script
    VERIFY_FAILED=1
  fi
}

lock_exists() {
  aws s3api head-object --region "$(aws_region)" --bucket "$(state_bucket)" --key "$LOCK_KEY" >/dev/null 2>&1
}

lab_instance_ids() { # non-terminated instances tagged for this lab
  aws ec2 describe-instances --region "$(aws_region)" \
    --filters "Name=tag:Project,Values=$PROJECT_TAG" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text
}
