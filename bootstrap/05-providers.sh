#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 05 — RESOURCE PROVIDER REGISTRATION
#
# An unregistered provider fails at APPLY time with "MissingSubscription
# Registration", which reads like a permissions problem and wastes time.
# Register up front, per subscription. Registration is idempotent.
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"

PROVIDERS=(
  Microsoft.Compute
  Microsoft.Network
  Microsoft.Storage
  Microsoft.KeyVault
  Microsoft.ContainerService      # AKS
  Microsoft.ContainerRegistry     # ACR
  Microsoft.ManagedIdentity
  Microsoft.OperationalInsights   # Log Analytics
  Microsoft.Insights              # diagnostic settings, App Insights
  Microsoft.Sql
  Microsoft.Web                   # App Service
  Microsoft.PolicyInsights        # Azure Policy compliance data
)

for ENV in "${ENVIRONMENTS[@]}"; do
  SUB_ID="$(sub_for_env "$ENV")"
  az account set --subscription "$SUB_ID"
  echo ""
  echo "── Registering providers in $ENV ──"

  for P in "${PROVIDERS[@]}"; do
    STATE=$(az provider show --namespace "$P" --query registrationState -o tsv 2>/dev/null || echo "NotFound")
    if [ "$STATE" = "Registered" ]; then
      echo "  $P: already registered"
    else
      az provider register --namespace "$P" --output none
      echo "  $P: registration submitted"
    fi
  done
done

echo ""
echo "Registration can take several minutes to complete in the background."
echo "Check with: az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv"
