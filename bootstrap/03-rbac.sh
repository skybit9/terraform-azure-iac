#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 03: RESOURCE GROUPS AND RBAC
#
# Every grant here exists because a specific Terraform operation needs it:
#
#   All stacks, plan + apply
#     Storage Blob Data Contributor on OWN state container
#       (data plane: Contributor on a storage account does NOT grant blob access;
#        plan also writes state, since refresh updates it)
#   plan  : Reader on own RG            apply : Contributor on own RG
#
#   app stack only
#     Storage Blob Data Reader on networking + keyvault containers
#       (terraform_remote_state reads their outputs)
#     Reader on rg-keyvault             (read the vault's properties)
#     plan  : Key Vault Secrets User    (refresh reads existing secret values)
#     apply : Key Vault Secrets Officer (write the VM SSH key secrets)
#     apply : Terraform Subnet Joiner on rg-networking
#       (a NIC attaching to a subnet in ANOTHER resource group needs
#        subnets/join/action there; Contributor on rg-app does not cover it)
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

# ── Custom role: least privilege subnet join ─────────────────────────────────
# No built in role grants only subnet join. Network Contributor would also let
# the app stack modify the network itself.
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
  echo "Custom role created: $SUBNET_JOIN_ROLE (allow a minute to propagate)"
  sleep 60
fi

for ENV in "${ENVIRONMENTS[@]}"; do
  az account set --subscription "$(sub_for_env "$ENV")"

  for STACK in "${STACKS[@]}"; do
    RG="$(rg_for "$ENV" "$STACK")"
    echo "── $ENV / $STACK ($RG)"

    # A resource group must exist before it can be an RBAC scope.
    az group create --name "$RG" --location "$LOCATION" \
      --tags environment="$ENV" stack="$STACK" managed-by=terraform --output none

    grant "$(sp "$ENV" "$STACK" plan)"  "Reader"      "$(rg_scope "$ENV" "$STACK")"
    grant "$(sp "$ENV" "$STACK" apply)" "Contributor" "$(rg_scope "$ENV" "$STACK")"

    for KIND in plan apply; do
      grant "$(sp "$ENV" "$STACK" "$KIND")" "Storage Blob Data Contributor" "$(container_scope "$ENV" "$STACK")"
    done

    if [ "$NEEDS_RBAC_WRITE" = "true" ]; then
      grant "$(sp "$ENV" "$STACK" apply)" "User Access Administrator" "$(rg_scope "$ENV" "$STACK")"
    fi
  done

  # ── app stack cross-stack grants ───────────────────────────────────────────
  echo "── $ENV / app cross-stack"
  KV_RG_SCOPE="$(rg_scope "$ENV" keyvault)"
  for KIND in plan apply; do
    APP_SP="$(sp "$ENV" app "$KIND")"
    grant "$APP_SP" "Storage Blob Data Reader" "$(container_scope "$ENV" networking)"
    grant "$APP_SP" "Storage Blob Data Reader" "$(container_scope "$ENV" keyvault)"
    grant "$APP_SP" "Reader"                   "$KV_RG_SCOPE"
  done
  grant "$(sp "$ENV" app plan)"  "Key Vault Secrets User"    "$KV_RG_SCOPE"
  grant "$(sp "$ENV" app apply)" "Key Vault Secrets Officer" "$KV_RG_SCOPE"
  grant "$(sp "$ENV" app apply)" "$SUBNET_JOIN_ROLE"         "$(rg_scope "$ENV" networking)"

  # The module's optional VM role assignment targets the vault in rg-keyvault.
  if [ "$NEEDS_RBAC_WRITE" = "true" ]; then
    grant "$(sp "$ENV" app apply)" "User Access Administrator" "$KV_RG_SCOPE"
  fi
done

echo "RBAC complete. Role assignments can take a few minutes to propagate."
