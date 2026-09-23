#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 01 — STATE BACKEND
#
# Creates, in the MANAGEMENT subscription:
#   rg-terraform-state
#     st<prefix>tfstatedev      -> containers: tfstate-networking, tfstate-keyvault, tfstate-app
#     st<prefix>tfstatestaging  -> same containers
#     st<prefix>tfstateprod     -> same containers
#
# This is the chicken-and-egg resource: Terraform cannot manage the storage
# account that holds its own state, so it is created here by CLI.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"

az account set --subscription "$SUB_MGMT"
echo "State backend subscription: $(az account show --query name -o tsv)"

az group create \
  --name "$STATE_RG" \
  --location "$LOCATION" \
  --tags purpose=terraform-state managed-by=bootstrap owner="$ORG_PREFIX" \
  --output none
echo "Resource group $STATE_RG ready"

for ENV in "${ENVIRONMENTS[@]}"; do
  SA=$(sa_for_env "$ENV")
  echo ""
  echo "── $ENV: $SA ──"

  # --allow-shared-key-access false forces Entra auth and disables account keys,
  # so a leaked key cannot be used to read state.
  az storage account create \
    --name "$SA" \
    --resource-group "$STATE_RG" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags environment="$ENV" purpose=terraform-state \
    --output none
  echo "  storage account created"

  # Versioning is the recovery path for a corrupted or truncated state file.
  az storage account blob-service-properties update \
    --account-name "$SA" \
    --resource-group "$STATE_RG" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 30 \
    --enable-container-delete-retention true \
    --container-delete-retention-days 30 \
    --output none
  echo "  versioning and soft delete enabled"

  # One container per stack. The container is the RBAC boundary.
  for STACK in "${STACKS[@]}"; do
    CONTAINER=$(container_for_stack "$STACK")
    az storage container create \
      --name "$CONTAINER" \
      --account-name "$SA" \
      --auth-mode login \
      --output none
    echo "  container $CONTAINER"
  done
done

# Losing state is worse than losing infrastructure: resources can be rebuilt,
# but orphaned state means every resource must be re-imported by hand.
az lock create \
  --name "lock-terraform-state" \
  --lock-type CanNotDelete \
  --resource-group "$STATE_RG" \
  --notes "Terraform state. Deleting this orphans all managed infrastructure." \
  --output none

echo ""
echo "State backend ready. Backend config per stack:"
for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    echo "  $ENV/$STACK -> sa=$(sa_for_env "$ENV") container=$(container_for_stack "$STACK") key=terraform.tfstate"
  done
done
