#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 99 — VERIFY
# Run after 01 through 05, so a pipeline failure points at the pipeline rather
# than at missing setup.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"
source "$(dirname "$0")/identities.env"

FAIL=0
ok()  { echo "  PASS  $1"; }
bad() { echo "  FAIL  $1"; FAIL=1; }

echo "── State backend (management subscription) ──"
az account set --subscription "$SUB_MGMT"

az group show -n "$STATE_RG" -o none 2>/dev/null \
  && ok "resource group $STATE_RG" || bad "resource group $STATE_RG missing"

for ENV in "${ENVIRONMENTS[@]}"; do
  SA=$(sa_for_env "$ENV")
  az storage account show -n "$SA" -g "$STATE_RG" -o none 2>/dev/null \
    && ok "storage account $SA" || bad "storage account $SA missing"

  VERS=$(az storage account blob-service-properties show \
    --account-name "$SA" -g "$STATE_RG" --query isVersioningEnabled -o tsv 2>/dev/null || echo false)
  [ "$VERS" = "true" ] && ok "  versioning on $SA" || bad "  versioning OFF on $SA"

  PUB=$(az storage account show -n "$SA" -g "$STATE_RG" --query allowBlobPublicAccess -o tsv)
  [ "$PUB" = "false" ] && ok "  public blob access disabled" || bad "  public blob access ENABLED on $SA"

  for STACK in "${STACKS[@]}"; do
    C=$(container_for_stack "$STACK")
    az storage container show --name "$C" --account-name "$SA" --auth-mode login -o none 2>/dev/null \
      && ok "  container $C" || bad "  container $C missing on $SA"
  done
done

echo ""
echo "── Identities, RBAC, federation ──"
for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    for KIND in plan apply; do
      KEY="$(echo "${ENV}_${STACK}_${KIND}" | tr '[:lower:]-' '[:upper:]_')"
      APP_ID=$(eval echo \$APPID_${KEY})
      SP_OBJ=$(eval echo \$SPOBJ_${KEY})
      LABEL="sp-tf-${ENV}-${STACK}-${KIND}"

      az ad sp show --id "$APP_ID" -o none 2>/dev/null \
        && ok "$LABEL exists" || bad "$LABEL missing"

      # The data-plane role is the one that breaks plan with a 403 when absent.
      SCOPE="$(container_scope "$ENV" "$STACK")"
      N=$(az role assignment list --assignee "$SP_OBJ" --scope "$SCOPE" \
        --query "length([?contains(roleDefinitionName,'Storage Blob Data')])" -o tsv 2>/dev/null || echo 0)
      [ "$N" -gt 0 ] && ok "  data-plane role on its state container" \
        || bad "  MISSING Storage Blob Data Contributor (plan will 403)"

      F=$(az ad app federated-credential list --id "$APP_ID" --query "length(@)" -o tsv 2>/dev/null || echo 0)
      [ "$F" -gt 0 ] && ok "  federated credential present" \
        || bad "  no federated credential (service connection will fail)"
    done
  done
done

echo ""
[ "$FAIL" -eq 0 ] && echo "All checks passed." || echo "One or more checks FAILED. Fix before running a pipeline."
exit $FAIL
