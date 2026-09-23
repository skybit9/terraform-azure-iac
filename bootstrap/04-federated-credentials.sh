#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 04 — WORKLOAD IDENTITY FEDERATION
#
# Replaces client secrets entirely. The app registration trusts an OIDC token
# issued by Azure DevOps for a specific org / project / service connection.
# No secret exists, so there is nothing to rotate, leak, or store in Key Vault.
#
# ORDER OF OPERATIONS (this is the fiddly part):
#   1. In Azure DevOps, create the service connection FIRST, choosing
#      "Workload Identity federation (manual)". It shows you an Issuer and a
#      Subject identifier.
#   2. Run this script with those values to create the federated credential.
#   3. Return to Azure DevOps and click Verify and save.
#
# The subject follows the pattern:
#   sc://<org>/<project>/<service-connection-name>
# ══════════════════════════════════════════════════════════════════════════════

source "$(dirname "$0")/00-variables.sh"
source "$(dirname "$0")/identities.env"

# Issuer is the same for all Azure DevOps organisations
ISSUER="https://vstoken.dev.azure.com/$(basename "$ADO_ORG")"

for ENV in "${ENVIRONMENTS[@]}"; do
  UPPER_ENV=$(echo "$ENV" | tr '[:lower:]' '[:upper:]')

  for ROLE_KIND in plan apply; do
    UPPER_KIND=$(echo "$ROLE_KIND" | tr '[:lower:]' '[:upper:]')
    APP_ID=$(eval echo \$APPID_${UPPER_ENV}_${UPPER_KIND})

    # Must match the service connection name in Azure DevOps exactly
    SC_NAME="SVC-Terraform-${ENV}-${ROLE_KIND}"
    SUBJECT="sc://$(basename "$ADO_ORG")/${ADO_PROJECT}/${SC_NAME}"

    echo ""
    echo "── Federated credential for $SC_NAME ──"
    echo "  appId  : $APP_ID"
    echo "  subject: $SUBJECT"

    az ad app federated-credential create \
      --id "$APP_ID" \
      --parameters "{
        \"name\": \"ado-${ENV}-${ROLE_KIND}\",
        \"issuer\": \"${ISSUER}\",
        \"subject\": \"${SUBJECT}\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
      }" \
      --output none

    echo "  created"
  done
done

echo ""
echo "Federated credentials created."
echo "Now return to Azure DevOps and click 'Verify and save' on each service connection."
