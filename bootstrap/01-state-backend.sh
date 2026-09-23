#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 01: STATE BACKEND (management subscription)
# The one resource Terraform cannot manage for itself, so it is created by CLI.
# Idempotent: safe to re-run.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"

az account set --subscription "$SUB_MGMT"
echo "State backend subscription: $(az account show --query name -o tsv)"

az group create --name "$STATE_RG" --location "$LOCATION" \
  --tags purpose=terraform-state managed-by=bootstrap owner="$ORG_PREFIX" --output none

for ENV in "${ENVIRONMENTS[@]}"; do
  SA="$(sa_for_env "$ENV")"
  echo "── $ENV: $SA"

  # Shared key access disabled: a leaked account key cannot read state.
  # Terraform must then use use_azuread_auth=true, which the pipelines set.
  az storage account create \
    --name "$SA" --resource-group "$STATE_RG" --location "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 \
    --https-only true --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags environment="$ENV" purpose=terraform-state --output none

  # Versioning is the recovery path for a corrupted or truncated state file.
  az storage account blob-service-properties update \
    --account-name "$SA" --resource-group "$STATE_RG" \
    --enable-versioning true \
    --enable-delete-retention true --delete-retention-days 30 \
    --enable-container-delete-retention true --container-delete-retention-days 30 \
    --output none

  # Creating containers with --auth-mode login needs a data plane role for the
  # person running bootstrap. Grant it, then wait for propagation.
  ME="$(az ad signed-in-user show --query id -o tsv)"
  SA_ID="$(az storage account show -n "$SA" -g "$STATE_RG" --query id -o tsv)"
  az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
    --role "Storage Blob Data Contributor" --scope "$SA_ID" --output none 2>/dev/null || true

  for STACK in "${STACKS[@]}"; do
    C="$(container_for_stack "$STACK")"
    for attempt in 1 2 3 4 5 6; do
      if az storage container create --name "$C" --account-name "$SA" \
           --auth-mode login --output none 2>/dev/null; then
        echo "   container $C"; break
      fi
      [ "$attempt" -eq 6 ] && { echo "   FAILED container $C"; exit 1; }
      echo "   waiting for role propagation..."; sleep 20
    done
  done
done

az lock create --name lock-terraform-state --lock-type CanNotDelete \
  --resource-group "$STATE_RG" \
  --notes "Terraform state. Deleting this orphans all managed infrastructure." --output none

echo "State backend ready."
