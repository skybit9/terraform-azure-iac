#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 02: SERVICE PRINCIPALS. Two per stack per environment:
#   sp-tf-<env>-<stack id>-plan   read only, CI on every pull request
#   sp-tf-<env>-<stack id>-apply  write, CD after approval
# Idempotent: existing identities are reused. No client secrets are created.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"

OUT="$(dirname "$0")/identities.env"
: > "$OUT"

for ENV in "${ENVIRONMENTS[@]}"; do
  IDS="$(stack_ids "$ENV")"
  for ID in $IDS; do
    for KIND in plan apply; do
      NAME="sp-tf-${ENV}-${ID}-${KIND}"
      APP_ID="$(az ad app list --display-name "$NAME" --query '[0].appId' -o tsv)"
      if [ -z "$APP_ID" ]; then
        APP_ID="$(az ad app create --display-name "$NAME" --query appId -o tsv)"
      fi
      az ad sp show --id "$APP_ID" --output none 2>/dev/null \
        || az ad sp create --id "$APP_ID" --output none
      SP_OBJ="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

      KEY="$(id_key "$ENV" "$ID" "$KIND")"
      printf 'APPID_%s="%s"\nSPOBJ_%s="%s"\n' "$KEY" "$APP_ID" "$KEY" "$SP_OBJ" >> "$OUT"
      echo "$NAME  $APP_ID"
    done
  done
done

echo "Written: $OUT (gitignored). Next: ./03-rbac.sh"
