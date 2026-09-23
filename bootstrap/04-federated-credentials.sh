#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 04: WORKLOAD IDENTITY FEDERATION (no client secrets)
#
# Order:
#   1. In Azure DevOps create 18 service connections:
#        Azure Resource Manager > Workload identity federation (manual)
#        name exactly: SVC-TF-<env>-<stack>-<plan|apply>
#        scope: the environment's workload subscription
#   2. Run this script.
#   3. Back in Azure DevOps, Verify and save each connection.
#
# The subject format below matches Azure DevOps' default for manual WIF
# connections. If a connection shows a different Subject identifier, that
# value wins: copy it in place of SUBJECT for that connection.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/identities.env"

ISSUER="https://vstoken.dev.azure.com/${ADO_ORG_NAME}"

for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    for KIND in plan apply; do
      V="APPID_$(id_key "$ENV" "$STACK" "$KIND")"; APP_ID="${!V}"
      SC="SVC-TF-${ENV}-${STACK}-${KIND}"
      SUBJECT="sc://${ADO_ORG_NAME}/${ADO_PROJECT}/${SC}"
      NAME="ado-${ENV}-${STACK}-${KIND}"

      if az ad app federated-credential list --id "$APP_ID" --query "[?name=='$NAME'] | [0].name" -o tsv | grep -q .; then
        echo "exists   $SC"; continue
      fi

      az ad app federated-credential create --id "$APP_ID" --parameters "{
        \"name\": \"$NAME\",
        \"issuer\": \"$ISSUER\",
        \"subject\": \"$SUBJECT\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
      }" --output none
      echo "created  $SC"
    done
  done
done

echo "Now Verify and save each service connection in Azure DevOps."
