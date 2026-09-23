#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are consumed by the scripts that source this
# ══════════════════════════════════════════════════════════════════════════════
# SHARED VARIABLES. Every other script sources this file.
#
# STACKS ARE DISCOVERED FROM FOLDERS
#   environments/<env>/shared/networking   -> stack id: networking
#   environments/<env>/shared/keyvault     -> stack id: keyvault
#   environments/<env>/<resource-group>    -> stack id: lowercased RG name
#   (every folder under environments/<env>/ except shared/ is a workload RG)
# Add a workload RG by creating environments/<env>/<rg-name>/ (and listing it in
# pipelines/templates/environments.yml; CI checks the two match).
#
# STATE TOPOLOGY
#   MANAGEMENT subscription
#   └── rg-terraform-state
#       └── tfstate<env>001   one container per stack: tfstate-<stack id>
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
SHARED_STACKS=(networking keyvault)
SUBNET_JOIN_ROLE="Terraform Subnet Joiner"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Storage account names share ONE global namespace across all of Azure.
# If creation fails with StorageAccountAlreadyTaken, bump 001 to 002 here AND
# in pipelines/templates/*-steps.yml and every workload's terraform.tfvars.
sa_for_env()          { echo "tfstate${1}001"; }
container_for_stack() { echo "tfstate-${1}"; }

sub_for_env() {
  case "$1" in
    dev)     echo "$SUB_DEV" ;;
    staging) echo "$SUB_STAGING" ;;
    prod)    echo "$SUB_PROD" ;;
    *)       echo "unknown environment: $1" >&2; return 1 ;;
  esac
}

lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }

# Workload RG names for an environment: every folder except shared/.
workload_rgs() {                                          # <env>
  local d name
  for d in "$REPO_ROOT/environments/$1"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    [ "$name" = "shared" ] && continue
    echo "$name"
  done
}

# Every stack id in an environment: shared first, then workloads.
# Ids become container and service connection names, so they are validated.
stack_ids() {                                             # <env>
  local rg id
  echo "${SHARED_STACKS[@]}"
  for rg in $(workload_rgs "$1"); do
    id="$(lower "$rg")"
    if ! echo "$id" | grep -Eq '^[a-z0-9]([a-z0-9]|-[a-z0-9]){1,54}$'; then
      echo "ERROR: '$rg' lowercases to '$id', which is not a valid stack id" >&2
      echo "       (3-55 chars, a-z 0-9 and single hyphens)." >&2
      return 1
    fi
    echo "$id"
  done
}

is_shared() { case "$1" in networking|keyvault) return 0 ;; *) return 1 ;; esac; }

# Resource group for a stack id: convention for shared, folder name for workloads.
rg_of() {                                                 # <env> <stack id>
  local rg
  if is_shared "$2"; then echo "rg-${2}-${1}"; return; fi
  for rg in $(workload_rgs "$1"); do
    [ "$(lower "$rg")" = "$2" ] && { echo "$rg"; return; }
  done
  echo "ERROR: no folder for stack $2 in $1" >&2; return 1
}

container_scope() {                                       # <env> <stack id>
  echo "/subscriptions/${SUB_MGMT}/resourceGroups/${STATE_RG}/providers/Microsoft.Storage/storageAccounts/$(sa_for_env "$1")/blobServices/default/containers/$(container_for_stack "$2")"
}

rg_scope() {                                              # <env> <resource group>
  echo "/subscriptions/$(sub_for_env "$1")/resourceGroups/$2"
}

# Shell-safe key for identities.env, e.g. DEV_RG_APP_DEV_PLAN
id_key() { echo "${1}_${2}_${3}" | tr '[:lower:]-' '[:upper:]_'; }
