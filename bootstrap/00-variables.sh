#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# SHARED VARIABLES
# Source this before running any other script:  source ./00-variables.sh
#
# Edit the values in this block only. Everything else is derived.
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Edit these ────────────────────────────────────────────────────────────────
export LOCATION="canadacentral"
export ORG_PREFIX="ishelar"                 # short, lowercase, no dashes

# One subscription ID per environment. If all three share one subscription,
# set all three to the same value; RBAC is then scoped per resource group.
export SUB_DEV="00000000-0000-0000-0000-000000000000"
export SUB_STAGING="00000000-0000-0000-0000-000000000000"
export SUB_PROD="00000000-0000-0000-0000-000000000000"

# Azure DevOps org and project (used by 04 for service connection guidance)
export ADO_ORG="https://dev.azure.com/yourorg"
export ADO_PROJECT="YourProject"

# Set true only if Terraform will create role assignments.
# Grants User Access Administrator, which is privileged. Default false.
export NEEDS_RBAC_WRITE="false"

# ── Derived: do not edit ──────────────────────────────────────────────────────
export STATE_RG="rg-terraform-state"
export STATE_SA="st${ORG_PREFIX}tfstate"    # must be globally unique, <=24 chars
export STATE_CONTAINER="tfstate"

export ENVIRONMENTS=("dev" "staging" "prod")

# Look up the subscription for an environment name
sub_for_env() {
  case "$1" in
    dev)     echo "$SUB_DEV" ;;
    staging) echo "$SUB_STAGING" ;;
    prod)    echo "$SUB_PROD" ;;
    *)       echo "unknown environment: $1" >&2; return 1 ;;
  esac
}

echo "Variables loaded. State SA will be: $STATE_SA"
