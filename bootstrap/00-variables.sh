#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# SHARED VARIABLES
# Source before any other script:  source ./00-variables.sh
#
# STATE TOPOLOGY
#   One MANAGEMENT subscription holds all state storage accounts.
#   One storage account per environment.
#   One container per stack (which maps 1:1 to a resource group).
#
#   Why state does not live in the subscription it describes: if that
#   subscription is deleted, disabled, or moved between tenants, the state
#   describing it dies with it and every resource must be re-imported by hand.
#
#   Why one container per stack rather than one container with many blob keys:
#   a CONTAINER is an RBAC scope, a blob key is not. Scoping
#   "Storage Blob Data Contributor" at the container means the AKS pipeline
#   identity cannot read the networking state. With one shared container,
#   any identity with data access reads every state file in it.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Edit these ────────────────────────────────────────────────────────────────
export LOCATION="canadacentral"
# Used in resource tags only. Storage account names no longer include it.
export ORG_PREFIX="ishelar"                 # short, lowercase, no dashes

# Management subscription: hosts ALL state storage accounts.
export SUB_MGMT="00000000-0000-0000-0000-000000000000"

# Workload subscriptions, one per environment.
export SUB_DEV="00000000-0000-0000-0000-000000000000"
export SUB_STAGING="00000000-0000-0000-0000-000000000000"
export SUB_PROD="00000000-0000-0000-0000-000000000000"

# Azure DevOps org and project (used by 04 for the federated subject)
export ADO_ORG="https://dev.azure.com/yourorg"
export ADO_PROJECT="YourProject"

# Stacks. Each stack is one resource group and gets its own container and
# its own state file. Add a stack here and every script picks it up.
export STACKS=("networking" "keyvault" "app")

# Set true only if Terraform creates role assignments. Grants User Access
# Administrator, which is privileged. Default false.
export NEEDS_RBAC_WRITE="false"

# ── Derived: do not edit ──────────────────────────────────────────────────────
export STATE_RG="rg-terraform-state"
export ENVIRONMENTS=("dev" "staging" "prod")

# Storage account per environment, all inside SUB_MGMT.
# Storage account names share ONE GLOBAL namespace across all of Azure, so a
# generic name can collide with another tenant and fail with
# StorageAccountAlreadyTaken. The 001 suffix is the increment if that happens.
# Rules: 3-24 chars, lowercase alphanumeric only, no dashes.
sa_for_env() { echo "tfstate${1}001"; }

# Container per stack. Container names: lowercase, dashes allowed.
container_for_stack() { echo "tfstate-$1"; }

# Workload subscription for an environment
sub_for_env() {
  case "$1" in
    dev)     echo "$SUB_DEV" ;;
    staging) echo "$SUB_STAGING" ;;
    prod)    echo "$SUB_PROD" ;;
    *)       echo "unknown environment: $1" >&2; return 1 ;;
  esac
}

# Full ARM scope of a container, used for container-scoped RBAC in script 03
container_scope() {
  local ENV=$1 STACK=$2
  echo "/subscriptions/${SUB_MGMT}/resourceGroups/${STATE_RG}/providers/Microsoft.Storage/storageAccounts/$(sa_for_env "$ENV")/blobServices/default/containers/$(container_for_stack "$STACK")"
}

echo "Variables loaded."
echo "  management subscription : $SUB_MGMT"
echo "  state accounts          : $(sa_for_env dev), $(sa_for_env staging), $(sa_for_env prod)"
echo "  stacks                  : ${STACKS[*]}"
