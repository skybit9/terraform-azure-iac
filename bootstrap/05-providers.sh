#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 05: RESOURCE PROVIDER REGISTRATION
# The stacks set resource_provider_registrations = "none", because azurerm 4.x
# otherwise tries to register providers at subscription scope and RG-scoped
# pipeline identities cannot. Registration happens here instead, once.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"

WORKLOAD_PROVIDERS=(
  Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault
  Microsoft.ManagedIdentity Microsoft.Insights Microsoft.OperationalInsights
  Microsoft.PolicyInsights
)

register() {                                # <subscription> <provider...>
  local SUB="$1"; shift
  az account set --subscription "$SUB"
  for P in "$@"; do
    STATE="$(az provider show --namespace "$P" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)"
    if [ "$STATE" = "Registered" ]; then
      echo "   $P registered"
    else
      az provider register --namespace "$P" --output none
      echo "   $P submitted"
    fi
  done
}

echo "── management"; register "$SUB_MGMT" Microsoft.Storage
for ENV in "${ENVIRONMENTS[@]}"; do
  echo "── $ENV"; register "$(sub_for_env "$ENV")" "${WORKLOAD_PROVIDERS[@]}"
done

echo "Registration completes in the background, usually within minutes."
