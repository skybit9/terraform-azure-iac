#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 02: SERVICE PRINCIPALS
# 3 environments x 3 stacks x {plan, apply} = 18 identities.
#   plan  : read only, used by CI on every pull request
#   apply : write, used by CD after approval
# A PR that adds an apply step to the YAML still cannot change Azure, because
# the CI connection only holds Reader. No client secrets are created.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"

OUT="$(dirname "$0")/identities.env"
: > "$OUT"

for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    for KIND in plan apply; do
      NAME="sp-tf-${ENV}-${STACK}-${KIND}"

      # Reuse if it already exists, so the script is re-runnable.
      APP_ID="$(az ad app list --display-name "$NAME" --query '[0].appId' -o tsv)"
      if [ -z "$APP_ID" ]; then
        APP_ID="$(az ad app create --display-name "$NAME" --query appId -o tsv)"
      fi
      az ad sp show --id "$APP_ID" --output none 2>/dev/null \
        || az ad sp create --id "$APP_ID" --output none
      SP_OBJ="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

      KEY="$(id_key "$ENV" "$STACK" "$KIND")"
      printf 'APPID_%s="%s"\nSPOBJ_%s="%s"\n' "$KEY" "$APP_ID" "$KEY" "$SP_OBJ" >> "$OUT"
      echo "$NAME  $APP_ID"
    done
  done
done

echo "Written: $OUT (gitignored). Next: ./03-rbac.sh"
