#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 04 — WORKLOAD IDENTITY FEDERATION
#
# Replaces client secrets entirely. The app registration trusts an OIDC token
# issued by Azure DevOps for one specific org, project, and service connection.
# Nothing to rotate, leak, or store in Key Vault.
#
# ORDER OF OPERATIONS:
#   1. In Azure DevOps create the service connection FIRST, choosing
#      "Workload Identity federation (manual)". It shows an Issuer and Subject.
#   2. Run this script to create the matching federated credential.
#   3. Return to Azure DevOps and click Verify and save.
#
# Service connection naming must match exactly:
#   SVC-TF-<env>-<stack>-<plan|apply>
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"
source "$(dirname "$0")/identities.env"

ISSUER="https://vstoken.dev.azure.com/$(basename "$ADO_ORG")"

for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    for KIND in plan apply; do
      KEY="$(echo "${ENV}_${STACK}_${KIND}" | tr '[:lower:]-' '[:upper:]_')"
      APP_ID=$(eval echo \$APPID_${KEY})

      SC_NAME="SVC-TF-${ENV}-${STACK}-${KIND}"
      SUBJECT="sc://$(basename "$ADO_ORG")/${ADO_PROJECT}/${SC_NAME}"

      echo "── $SC_NAME ──"
      az ad app federated-credential create \
        --id "$APP_ID" \
        --parameters "{
          \"name\": \"ado-${ENV}-${STACK}-${KIND}\",
          \"issuer\": \"${ISSUER}\",
          \"subject\": \"${SUBJECT}\",
          \"audiences\": [\"api://AzureADTokenExchange\"]
        }" --output none
      echo "  subject: $SUBJECT"
    done
  done
done

echo ""
echo "Federated credentials created."
echo "Return to Azure DevOps and click 'Verify and save' on each service connection."
