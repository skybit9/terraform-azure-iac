#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 03: RESOURCE GROUPS AND RBAC
#
# EVERY STACK (shared and workload)
#   plan  : Reader on its RG          apply : Contributor on its RG
#   both  : Storage Blob Data Contributor on its OWN state container
#           (data plane; Contributor on a storage account does not grant it;
#            plan also writes state because refresh updates it)
#
# EVERY WORKLOAD RG (defaults: a workload uses the shared VNet and vault)
#   both  : Storage Blob Data Reader on the networking + keyvault containers
#   both  : Reader on the shared keyvault RG
#   plan  : Key Vault Secrets User     apply : Key Vault Secrets Officer
#   apply : Terraform Subnet Joiner on the shared networking RG
#   A workload that does not use the shared vault or VNet does not need these;
#   remove them by hand for least privilege.
#
# EXISTING RESOURCE GROUPS ARE NEVER MODIFIED. "az group create" on an existing
# group replaces its tags, which would show up as drift the moment the RG is
# imported. Groups are only created when missing.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/identities.env"

sp() {
  local v
  v="SPOBJ_$(id_key "$1" "$2" "$3")"
  echo "${!v}"
}

grant() {                                   # <principal> <role> <scope>
  az role assignment create --assignee-object-id "$1" \
    --assignee-principal-type ServicePrincipal \
    --role "$2" --scope "$3" --output none
  echo "    $2  ->  ${3##*/}"
}

ensure_rg() {                               # <env> <rg> <stack id>
  if az group show --name "$2" --output none 2>/dev/null; then
    echo "   $2 exists: left untouched"
  else
    az group create --name "$2" --location "$LOCATION" \
      --tags environment="$1" stack="$3" managed-by=terraform --output none
    echo "   $2 created"
  fi
}

# ── Custom role: least privilege subnet join ─────────────────────────────────
SCOPES_JSON="$(printf '"/subscriptions/%s",' "$SUB_DEV" "$SUB_STAGING" "$SUB_PROD" | sed 's/,$//')"
if ! az role definition list --name "$SUBNET_JOIN_ROLE" --query '[0].id' -o tsv | grep -q .; then
  az role definition create --role-definition "{
    \"Name\": \"$SUBNET_JOIN_ROLE\",
    \"Description\": \"Read a VNet and join its subnets. Nothing else.\",
    \"Actions\": [
      \"Microsoft.Network/virtualNetworks/read\",
      \"Microsoft.Network/virtualNetworks/subnets/read\",
      \"Microsoft.Network/virtualNetworks/subnets/join/action\"
    ],
    \"AssignableScopes\": [ $SCOPES_JSON ]
  }" --output none
  echo "Custom role created: $SUBNET_JOIN_ROLE (waiting for propagation)"
  sleep 60
fi

for ENV in "${ENVIRONMENTS[@]}"; do
  az account set --subscription "$(sub_for_env "$ENV")"
  IDS="$(stack_ids "$ENV")"
  NET_RG="$(rg_of "$ENV" networking)"
  KV_RG="$(rg_of "$ENV" keyvault)"

  for ID in $IDS; do
    RG="$(rg_of "$ENV" "$ID")"
    echo "── $ENV / $ID ($RG)"
    ensure_rg "$ENV" "$RG" "$ID"

    grant "$(sp "$ENV" "$ID" plan)"  "Reader"      "$(rg_scope "$ENV" "$RG")"
    grant "$(sp "$ENV" "$ID" apply)" "Contributor" "$(rg_scope "$ENV" "$RG")"
    for KIND in plan apply; do
      grant "$(sp "$ENV" "$ID" "$KIND")" "Storage Blob Data Contributor" "$(container_scope "$ENV" "$ID")"
    done
    if [ "$NEEDS_RBAC_WRITE" = "true" ]; then
      grant "$(sp "$ENV" "$ID" apply)" "User Access Administrator" "$(rg_scope "$ENV" "$RG")"
    fi

    is_shared "$ID" && continue

    # Workload defaults: consume the shared VNet and vault.
    for KIND in plan apply; do
      W="$(sp "$ENV" "$ID" "$KIND")"
      grant "$W" "Storage Blob Data Reader" "$(container_scope "$ENV" networking)"
      grant "$W" "Storage Blob Data Reader" "$(container_scope "$ENV" keyvault)"
      grant "$W" "Reader"                   "$(rg_scope "$ENV" "$KV_RG")"
    done
    grant "$(sp "$ENV" "$ID" plan)"  "Key Vault Secrets User"    "$(rg_scope "$ENV" "$KV_RG")"
    grant "$(sp "$ENV" "$ID" apply)" "Key Vault Secrets Officer" "$(rg_scope "$ENV" "$KV_RG")"
    grant "$(sp "$ENV" "$ID" apply)" "$SUBNET_JOIN_ROLE"         "$(rg_scope "$ENV" "$NET_RG")"
    if [ "$NEEDS_RBAC_WRITE" = "true" ]; then
      grant "$(sp "$ENV" "$ID" apply)" "User Access Administrator" "$(rg_scope "$ENV" "$KV_RG")"
    fi
  done
done

echo "RBAC complete. Role assignments can take a few minutes to propagate."
