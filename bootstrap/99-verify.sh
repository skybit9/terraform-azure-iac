#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 99 — VERIFY
#
# Run after 01 through 05. Confirms every prerequisite exists before you try
# a pipeline run, so a failure points at the pipeline rather than the setup.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"
source "$(dirname "$0")/identities.env"

FAIL=0
ok()   { echo "  PASS  $1"; }
bad()  { echo "  FAIL  $1"; FAIL=1; }

echo "── State backend ──"
az account set --subscription "$SUB_PROD"

az group show -n "$STATE_RG" -o none 2>/dev/null \
  && ok "resource group $STATE_RG" || bad "resource group $STATE_RG missing"

az storage account show -n "$STATE_SA" -g "$STATE_RG" -o none 2>/dev/null \
  && ok "storage account $STATE_SA" || bad "storage account $STATE_SA missing"

VERSIONING=$(az storage account blob-service-properties show \
  --account-name "$STATE_SA" -g "$STATE_RG" \
  --query isVersioningEnabled -o tsv 2>/dev/null || echo "false")
[ "$VERSIONING" = "true" ] && ok "blob versioning enabled" || bad "blob versioning NOT enabled"

PUBLIC=$(az storage account show -n "$STATE_SA" -g "$STATE_RG" \
  --query allowBlobPublicAccess -o tsv)
[ "$PUBLIC" = "false" ] && ok "public blob access disabled" || bad "public blob access is ENABLED"

echo ""
echo "── Identities and RBAC ──"
for ENV in "${ENVIRONMENTS[@]}"; do
  UPPER_ENV=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')
  for ROLE_KIND in plan apply; do
    UPPER_KIND=$(echo "$ROLE_KIND" | tr '[:lower:]' '[:upper:]')
    APP_ID=$(eval echo \$APPID_${UPPER_ENV}_${UPPER_KIND})
    SP_OBJ=$(eval echo \$SPOBJ_${UPPER_ENV}_${UPPER_KIND})

    az ad sp show --id "$APP_ID" -o none 2>/dev/null \
      && ok "sp-terraform-${ENV}-${ROLE_KIND} exists" \
      || bad "sp-terraform-${ENV}-${ROLE_KIND} missing"

    COUNT=$(az role assignment list --assignee "$SP_OBJ" --all \
      --query "length([?roleDefinitionName=='Storage Blob Data Contributor'])" -o tsv 2>/dev/null || echo 0)
    [ "$COUNT" -gt 0 ] \
      && ok "  data-plane role on state SA" \
      || bad "  MISSING Storage Blob Data Contributor (plan will 403)"

    FED=$(az ad app federated-credential list --id "$APP_ID" --query "length(@)" -o tsv 2>/dev/null || echo 0)
    [ "$FED" -gt 0 ] \
      && ok "  federated credential configured" \
      || bad "  no federated credential (service connection will fail)"
  done
done

echo ""
[ "$FAIL" -eq 0 ] && echo "All checks passed." || echo "One or more checks FAILED. Fix before running a pipeline."
exit $FAIL
