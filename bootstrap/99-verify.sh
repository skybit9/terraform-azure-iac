#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# 99: VERIFY. Run after 01 to 05 so a pipeline failure points at the pipeline,
# not at missing setup. Exits non-zero if anything is missing.
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
  for STACK in "${STACKS[@]}"; do
    C="$(container_for_stack "$STACK")"
    check "  $C" "  $C missing" \
      exists az storage container show -n "$C" --account-name "$SA" --auth-mode login
  done
done

echo "── Identities"
for ENV in "${ENVIRONMENTS[@]}"; do
  for STACK in "${STACKS[@]}"; do
    for KIND in plan apply; do
      K="$(id_key "$ENV" "$STACK" "$KIND")"; A="APPID_$K"; S="SPOBJ_$K"
      LABEL="sp-tf-$ENV-$STACK-$KIND"
      check "$LABEL state access" "$LABEL MISSING state access (plan will 403)" \
        has_role "${!S}" "Storage Blob Data Contributor" "$(container_scope "$ENV" "$STACK")"
      check "$LABEL federated credential" "$LABEL no federated credential" \
        [ "$(az ad app federated-credential list --id "${!A}" --query 'length(@)' -o tsv)" -gt 0 ]
    done
  done
  APPLY_VAR="SPOBJ_$(id_key "$ENV" app apply)"; APP_APPLY="${!APPLY_VAR}"
  check "$ENV app-apply Key Vault Secrets Officer" "$ENV app-apply cannot write VM secrets" \
    has_role "$APP_APPLY" "Key Vault Secrets Officer" "$(rg_scope "$ENV" keyvault)"
  check "$ENV app-apply subnet join" "$ENV app-apply cannot join subnet" \
    has_role "$APP_APPLY" "$SUBNET_JOIN_ROLE" "$(rg_scope "$ENV" networking)"
done

echo
if [ "$FAIL" -eq 0 ]; then echo "All checks passed."; else echo "Checks FAILED. Fix before running a pipeline."; fi
exit "$FAIL"
