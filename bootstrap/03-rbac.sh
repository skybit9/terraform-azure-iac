#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 03 — RBAC ASSIGNMENTS
#
# The trap this script avoids:
#   Contributor on a storage account is a MANAGEMENT plane role. It does not
#   grant read/write on the blobs inside. Terraform needs the DATA plane role
#   "Storage Blob Data Contributor" to touch the state file. Missing this is
#   the most common first-run failure: init succeeds, plan fails with a 403.
#
# Plan identities get Reader on the subscription, but still need WRITE on the
# state blob, because terraform plan refreshes and updates state metadata.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"
source "$(dirname "$0")/identities.env"

# Scope of the state storage account (lives in the prod subscription)
STATE_SA_SCOPE="/subscriptions/${SUB_PROD}/resourceGroups/${STATE_RG}/providers/Microsoft.Storage/storageAccounts/${STATE_SA}"

for ENV in "${ENVIRONMENTS[@]}"; do
  SUB_ID="$(sub_for_env "$ENV")"
  SUB_SCOPE="/subscriptions/${SUB_ID}"
  UPPER_ENV=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')

  PLAN_SP=$(eval echo \$SPOBJ_${UPPER_ENV}_PLAN)
  APPLY_SP=$(eval echo \$SPOBJ_${UPPER_ENV}_APPLY)

  echo ""
  echo "── RBAC for $ENV ──"

  # ── PLAN identity: read-only on the subscription ───────────────────────────
  az role assignment create \
    --assignee-object-id "$PLAN_SP" \
    --assignee-principal-type ServicePrincipal \
    --role "Reader" \
    --scope "$SUB_SCOPE" \
    --output none
  echo "  plan  : Reader on subscription"

  # Plan still writes state metadata on refresh, so it needs the data role.
  az role assignment create \
    --assignee-object-id "$PLAN_SP" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$STATE_SA_SCOPE" \
    --output none
  echo "  plan  : Storage Blob Data Contributor on state SA"

  # ── APPLY identity: Contributor on the subscription ────────────────────────
  az role assignment create \
    --assignee-object-id "$APPLY_SP" \
    --assignee-principal-type ServicePrincipal \
    --role "Contributor" \
    --scope "$SUB_SCOPE" \
    --output none
  echo "  apply : Contributor on subscription"

  az role assignment create \
    --assignee-object-id "$APPLY_SP" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$STATE_SA_SCOPE" \
    --output none
  echo "  apply : Storage Blob Data Contributor on state SA"

  # ── Optional: role assignment creation ─────────────────────────────────────
  # Only if Terraform itself creates role assignments. This is privileged:
  # User Access Administrator can grant any role to anyone. Default is off.
  if [ "$NEEDS_RBAC_WRITE" = "true" ]; then
    az role assignment create \
      --assignee-object-id "$APPLY_SP" \
      --assignee-principal-type ServicePrincipal \
      --role "User Access Administrator" \
      --scope "$SUB_SCOPE" \
      --output none
    echo "  apply : User Access Administrator on subscription (RBAC write enabled)"
  fi
done

echo ""
echo "RBAC complete. Note: assignments can take a few minutes to propagate."
