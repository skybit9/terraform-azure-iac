#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 99: VERIFY. Run after 01 to 05. Exits non-zero if anything is missing.
# ══════════════════════════════════════════════════════════════════════════════
# shellcheck source=bootstrap/00-variables.sh
source "$(dirname "$0")/00-variables.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/identities.env"
set +e

FAIL=0
ok()  { echo "  PASS  $1"; }
bad() { echo "  FAIL  $1"; FAIL=1; }

check() {                                   # <ok msg> <fail msg> <command...>
  local good="$1" badmsg="$2"; shift 2
  if "$@"; then ok "$good"; else bad "$badmsg"; fi
}

# shellcheck disable=SC2329  # called indirectly via check()
is_eq() { [ "$1" = "$2" ]; }
exists() { "$@" -o none 2>/dev/null; }

# shellcheck disable=SC2329  # called indirectly via check()
has_role() {                                # <principal> <role> <scope>
  local n
  n="$(az role assignment list --assignee "$1" --scope "$3" \
        --query "length([?roleDefinitionName=='$2'])" -o tsv 2>/dev/null)"
  [ "${n:-0}" -gt 0 ]
}

spobj() { local v; v="SPOBJ_$(id_key "$1" "$2" "$3")"; echo "${!v}"; }
appid() { local v; v="APPID_$(id_key "$1" "$2" "$3")"; echo "${!v}"; }

echo "── State backend"
az account set --subscription "$SUB_MGMT"
for ENV in "${ENVIRONMENTS[@]}"; do
  SA="$(sa_for_env "$ENV")"
  if ! exists az storage account show -n "$SA" -g "$STATE_RG"; then bad "$SA missing"; continue; fi
  ok "$SA"
  check "  shared key disabled" "  shared key ENABLED on $SA" \
    is_eq "$(az storage account show -n "$SA" -g "$STATE_RG" --query allowSharedKeyAccess -o tsv)" "false"
  check "  versioning on" "  versioning OFF on $SA" \
    is_eq "$(az storage account blob-service-properties show --account-name "$SA" -g "$STATE_RG" --query isVersioningEnabled -o tsv)" "true"
  for ID in $(stack_ids "$ENV"); do
    C="$(container_for_stack "$ID")"
    check "  $C" "  $C missing" \
      exists az storage container show -n "$C" --account-name "$SA" --auth-mode login
  done
done

echo "── Identities"
for ENV in "${ENVIRONMENTS[@]}"; do
  NET_RG="$(rg_of "$ENV" networking)"
  KV_RG="$(rg_of "$ENV" keyvault)"
  for ID in $(stack_ids "$ENV"); do
    for KIND in plan apply; do
      L="sp-tf-$ENV-$ID-$KIND"
      check "$L state access" "$L MISSING state access (plan will 403)" \
        has_role "$(spobj "$ENV" "$ID" "$KIND")" "Storage Blob Data Contributor" "$(container_scope "$ENV" "$ID")"
      check "$L federated credential" "$L no federated credential" \
        [ "$(az ad app federated-credential list --id "$(appid "$ENV" "$ID" "$KIND")" --query 'length(@)' -o tsv)" -gt 0 ]
    done
    is_shared "$ID" && continue
    A="$(spobj "$ENV" "$ID" apply)"
    check "$ENV/$ID apply: Key Vault Secrets Officer" "$ENV/$ID apply cannot write secrets" \
      has_role "$A" "Key Vault Secrets Officer" "$(rg_scope "$ENV" "$KV_RG")"
    check "$ENV/$ID apply: subnet join" "$ENV/$ID apply cannot join subnet" \
      has_role "$A" "$SUBNET_JOIN_ROLE" "$(rg_scope "$ENV" "$NET_RG")"
  done
done

echo
if [ "$FAIL" -eq 0 ]; then echo "All checks passed."; else echo "Checks FAILED. Fix before running a pipeline."; fi
exit "$FAIL"
