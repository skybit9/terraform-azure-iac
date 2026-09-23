#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 03 — RBAC ASSIGNMENTS
#
# THE TRAP THIS AVOIDS:
#   Contributor on a storage account is a MANAGEMENT plane role. It does not
#   grant read or write on the blobs inside. Terraform needs the DATA plane role
#   "Storage Blob Data Contributor" to touch the state file. Missing it means
#   init succeeds and plan fails with a 403, which reads like a bug rather than
#   a missing role assignment.
#
# SCOPES USED HERE:
#   State  -> scoped to the CONTAINER, not the storage account. The AKS identity
#             cannot read networking state.
#   Azure  -> scoped to the RESOURCE GROUP, not the subscription. The app stack
#             identity cannot modify networking resources.
#
# Plan identities still need WRITE on their own state container, because
# terraform plan refreshes and updates state metadata.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"
source "$(dirname "$0")/identities.env"

for ENV in "${ENVIRONMENTS[@]}"; do
  SUB_ID="$(sub_for_env "$ENV")"

  for STACK in "${STACKS[@]}"; do
    RG_NAME="rg-${STACK}-${ENV}"
    RG_SCOPE="/subscriptions/${SUB_ID}/resourceGroups/${RG_NAME}"
    STATE_SCOPE="$(container_scope "$ENV" "$STACK")"

    KEY_PLAN="$(echo "${ENV}_${STACK}_plan" | tr '[:lower:]-' '[:upper:]_')"
    KEY_APPLY="$(echo "${ENV}_${STACK}_apply" | tr '[:lower:]-' '[:upper:]_')"
    PLAN_SP=$(eval echo \$SPOBJ_${KEY_PLAN})
    APPLY_SP=$(eval echo \$SPOBJ_${KEY_APPLY})

    echo ""
    echo "── $ENV / $STACK ──"

    # The resource group must exist before it can be an RBAC scope.
    az account set --subscription "$SUB_ID"
    az group create --name "$RG_NAME" --location "$LOCATION" \
      --tags environment="$ENV" stack="$STACK" managed-by=terraform --output none

    # ── PLAN identity ────────────────────────────────────────────────────────
    az role assignment create \
      --assignee-object-id "$PLAN_SP" --assignee-principal-type ServicePrincipal \
      --role "Reader" --scope "$RG_SCOPE" --output none
    echo "  plan  : Reader on $RG_NAME"

    az role assignment create \
      --assignee-object-id "$PLAN_SP" --assignee-principal-type ServicePrincipal \
      --role "Storage Blob Data Contributor" --scope "$STATE_SCOPE" --output none
    echo "  plan  : Blob Data Contributor on state container"

    # ── APPLY identity ───────────────────────────────────────────────────────
    az role assignment create \
      --assignee-object-id "$APPLY_SP" --assignee-principal-type ServicePrincipal \
      --role "Contributor" --scope "$RG_SCOPE" --output none
    echo "  apply : Contributor on $RG_NAME"

    az role assignment create \
      --assignee-object-id "$APPLY_SP" --assignee-principal-type ServicePrincipal \
      --role "Storage Blob Data Contributor" --scope "$STATE_SCOPE" --output none
    echo "  apply : Blob Data Contributor on state container"

    if [ "$NEEDS_RBAC_WRITE" = "true" ]; then
      az role assignment create \
        --assignee-object-id "$APPLY_SP" --assignee-principal-type ServicePrincipal \
        --role "User Access Administrator" --scope "$RG_SCOPE" --output none
      echo "  apply : User Access Administrator on $RG_NAME"
    fi
  done
done

# ── CROSS-STACK READS ─────────────────────────────────────────────────────────
# The app stack consumes outputs from networking and keyvault via
# terraform_remote_state. That needs READ on those containers.
# Granted narrowly: Storage Blob Data READER on one container, never Reader on
# the whole account, which would undo the isolation above.
echo ""
echo "── Cross-stack remote state reads ──"
for ENV in "${ENVIRONMENTS[@]}"; do
  for KIND in plan apply; do
    KEY_APP="$(echo "${ENV}_app_${KIND}" | tr '[:lower:]-' '[:upper:]_')"
    APP_SP=$(eval echo \$SPOBJ_${KEY_APP})
    for UPSTREAM in networking keyvault; do
      az role assignment create \
        --assignee-object-id "$APP_SP" --assignee-principal-type ServicePrincipal \
        --role "Storage Blob Data Reader" \
        --scope "$(container_scope "$ENV" "$UPSTREAM")" --output none
      echo "  $ENV app-$KIND : Blob Data Reader on $UPSTREAM state"
    done
  done
done

echo ""
echo "RBAC complete. Assignments can take a few minutes to propagate."
