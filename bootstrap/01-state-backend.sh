#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 01 — STATE BACKEND
#
# This is the chicken-and-egg resource: Terraform cannot manage the storage
# account that holds its own state, so it is created here by CLI.
#
# Run once per Azure DevOps organisation, not per environment. All three state
# files live in the same container with different blob keys.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"

# State backend lives in the PROD subscription: it is the most protected one.
az account set --subscription "$SUB_PROD"
echo "Creating state backend in subscription: $(az account show --query name -o tsv)"

# ── Resource group ────────────────────────────────────────────────────────────
az group create \
  --name "$STATE_RG" \
  --location "$LOCATION" \
  --tags purpose=terraform-state managed-by=bootstrap owner="$ORG_PREFIX"

# ── Storage account ───────────────────────────────────────────────────────────
# --allow-blob-public-access false : state contains secrets in plaintext
# --min-tls-version TLS1_2         : blocks legacy TLS
# --allow-shared-key-access false  : forces Entra auth, disables account keys
az storage account create \
  --name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false

# ── Blob versioning and soft delete ───────────────────────────────────────────
# Versioning is the recovery path for a corrupted or truncated state file.
az storage account blob-service-properties update \
  --account-name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 30

# ── Container ─────────────────────────────────────────────────────────────────
# --auth-mode login uses your Entra identity, required since shared key is off.
az storage container create \
  --name "$STATE_CONTAINER" \
  --account-name "$STATE_SA" \
  --auth-mode login

# ── Delete lock ───────────────────────────────────────────────────────────────
# Losing state is worse than losing infrastructure: you can rebuild resources,
# but orphaned state means every resource must be re-imported by hand.
az lock create \
  --name "lock-terraform-state" \
  --lock-type CanNotDelete \
  --resource-group "$STATE_RG" \
  --notes "Terraform state. Deleting this orphans all managed infrastructure."

echo ""
echo "State backend ready:"
echo "  resource_group_name  = \"$STATE_RG\""
echo "  storage_account_name = \"$STATE_SA\""
echo "  container_name       = \"$STATE_CONTAINER\""
