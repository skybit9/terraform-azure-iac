#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 04: WORKLOAD IDENTITY FEDERATION (no client secrets)
#
# First, in Azure DevOps, create one service connection per identity:
#   Azure Resource Manager > Workload identity federation (manual)
#   name exactly: SVC-TF-<env>-<stack id>-<plan|apply>
#   scope: that environment's workload subscription
# Then run this script, then Verify and save each connection.
#
# If a connection shows a different Subject identifier than the one printed
# here, the connection's value wins: use it for that credential.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/identities.env"

ISSUER="https://vstoken.dev.azure.com/${ADO_ORG_NAME}"

for ENV in "${ENVIRONMENTS[@]}"; do
  IDS="$(stack_ids "$ENV")"
  for ID in $IDS; do
    for KIND in plan apply; do
      V="APPID_$(id_key "$ENV" "$ID" "$KIND")"; APP_ID="${!V}"
      SC="SVC-TF-${ENV}-${ID}-${KIND}"
      SUBJECT="sc://${ADO_ORG_NAME}/${ADO_PROJECT}/${SC}"
      NAME="ado-${ENV}-${ID}-${KIND}"

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
