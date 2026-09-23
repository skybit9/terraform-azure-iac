#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are consumed by the scripts that source this
# ══════════════════════════════════════════════════════════════════════════════
# SHARED VARIABLES. Every other script sources this file.
#
# STATE TOPOLOGY
#   MANAGEMENT subscription
#   └── rg-terraform-state
#       ├── tfstatedev001      containers: tfstate-networking, -keyvault, -app
#       ├── tfstatestaging001  same
#       └── tfstateprod001     same
#
# State lives outside the subscriptions it describes: deleting or moving a
# workload subscription must not destroy the state that manages it.
# A container is an RBAC scope and a blob key is not, so each stack gets its
# own container and its identities are granted access to that container only.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Edit these ────────────────────────────────────────────────────────────────
LOCATION="canadacentral"
ORG_PREFIX="ishelar"          # used in tags only

SUB_MGMT="00000000-0000-0000-0000-000000000000"      # holds all state
SUB_DEV="00000000-0000-0000-0000-000000000000"
SUB_STAGING="00000000-0000-0000-0000-000000000000"
SUB_PROD="00000000-0000-0000-0000-000000000000"

ADO_ORG_NAME="yourorg"        # dev.azure.com/<this>
ADO_PROJECT="YourProject"

# Set true only if Terraform must create role assignments (for example the
# module's grant_vm_key_vault_read). Grants User Access Administrator.
NEEDS_RBAC_WRITE="false"

# ── Derived ───────────────────────────────────────────────────────────────────
STATE_RG="rg-terraform-state"
ENVIRONMENTS=(dev staging prod)
STACKS=(networking keyvault app)
SUBNET_JOIN_ROLE="Terraform Subnet Joiner"

# Storage account names share ONE global namespace across all of Azure.
# If creation fails with StorageAccountAlreadyTaken, bump 001 to 002 here AND
# in pipelines/templates/*.yml and environments/*/app/terraform.tfvars.
sa_for_env()          { echo "tfstate${1}001"; }
container_for_stack() { echo "tfstate-${1}"; }
rg_for()              { echo "rg-${2}-${1}"; }            # rg_for <env> <stack>

sub_for_env() {
  case "$1" in
    dev)     echo "$SUB_DEV" ;;
    staging) echo "$SUB_STAGING" ;;
    prod)    echo "$SUB_PROD" ;;
    *)       echo "unknown environment: $1" >&2; return 1 ;;
  esac
}

container_scope() {                                       # <env> <stack>
  echo "/subscriptions/${SUB_MGMT}/resourceGroups/${STATE_RG}/providers/Microsoft.Storage/storageAccounts/$(sa_for_env "$1")/blobServices/default/containers/$(container_for_stack "$2")"
}

rg_scope() {                                              # <env> <stack>
  echo "/subscriptions/$(sub_for_env "$1")/resourceGroups/$(rg_for "$1" "$2")"
}

# Shell-safe key for identities.env, e.g. DEV_APP_PLAN
id_key() { echo "${1}_${2}_${3}" | tr '[:lower:]-' '[:upper:]_'; }
