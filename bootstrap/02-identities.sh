#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 02 — SERVICE PRINCIPALS
#
# Creates one plan and one apply identity per environment, per stack.
#   3 environments x 3 stacks x 2 kinds = 18 identities
#
# Why per stack, not just per environment:
#   The container is the RBAC boundary for state. That boundary only means
#   something if a different identity uses each container. One identity per
#   environment holding data access to all three containers would defeat the
#   split entirely.
#
# Why plan is separate from apply:
#   CI runs on every pull request, including PRs from people who should not be
#   able to change Azure. A plan needs Reader. If CI ran as Contributor, a PR
#   could add an apply step to the YAML and escalate.
#
# No client secrets. Script 04 configures workload identity federation.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"

OUTFILE="$(dirname "$0")/identities.env"
: > "$OUTFILE"

for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    for KIND in plan apply; do
      APP_NAME="sp-tf-${ENV}-${STACK}-${KIND}"
      echo "── $APP_NAME ──"

      APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
      az ad sp create --id "$APP_ID" --output none 2>/dev/null || true
      SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

      echo "  appId: $APP_ID"

      # Uppercase, dashes to underscores, for use as shell variable names
      KEY="$(echo "${ENV}_${STACK}_${KIND}" | tr '[:lower:]-' '[:upper:]_')"
      {
        echo "export APPID_${KEY}=\"$APP_ID\""
        echo "export SPOBJ_${KEY}=\"$SP_OBJECT_ID\""
      } >> "$OUTFILE"
    done
  done
done

echo ""
echo "Identities written to: $OUTFILE"
echo "Source it before running 03: source ./identities.env"
