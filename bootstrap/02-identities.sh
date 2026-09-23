#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 02 — SERVICE PRINCIPALS
#
# Creates SIX app registrations: a plan (read-only) and an apply (write)
# identity per environment.
#
# Why split plan from apply:
#   The CI pipeline runs on every pull request, including PRs from people who
#   should not be able to change Azure. A plan needs Reader only. If CI ran as
#   Contributor, a malicious PR could add an apply step to the YAML and
#   escalate. Separate identities close that hole.
#
# No client secrets are created here. Secrets are the older pattern; script 03
# configures workload identity federation instead.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"

OUTFILE="$(dirname "$0")/identities.env"
: > "$OUTFILE"

for ENV in "${ENVIRONMENTS[@]}"; do
  SUB_ID="$(sub_for_env "$ENV")"

  for ROLE_KIND in plan apply; do
    APP_NAME="sp-terraform-${ENV}-${ROLE_KIND}"

    echo ""
    echo "── Creating $APP_NAME ──"

    # Create the app registration. --skip-assignment style: no role yet,
    # RBAC is granted explicitly in script 03.
    APP_ID=$(az ad app create \
      --display-name "$APP_NAME" \
      --query appId -o tsv)

    # Create the service principal for that app in this tenant
    az ad sp create --id "$APP_ID" --output none 2>/dev/null || true

    # Object ID of the SP (different from appId; needed for role assignment)
    SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)

    echo "  appId     : $APP_ID"
    echo "  spObjectId: $SP_OBJECT_ID"

    # Persist for later scripts
    UPPER_ENV=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
    UPPER_KIND=$(echo "$ROLE_KIND" | tr '[:lower:]' '[:upper:]')
    {
      echo "export APPID_${UPPER_ENV}_${UPPER_KIND}=\"$APP_ID\""
      echo "export SPOBJ_${UPPER_ENV}_${UPPER_KIND}=\"$SP_OBJECT_ID\""
    } >> "$OUTFILE"
  done
done

echo ""
echo "Six identities created. IDs written to: $OUTFILE"
echo "Source it before running 03: source ./identities.env"
