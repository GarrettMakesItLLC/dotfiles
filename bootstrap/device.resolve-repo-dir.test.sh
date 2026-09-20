#!/usr/bin/env bash
# Unit test for device.sh's resolve_repo_dir — the fallback that decided
# between a legacy flat checkout ($WORKSPACE/<name>) and the Tools/ one
# ($WORKSPACE/Tools/<name>). It used to silently prefer the flat path
# whenever both existed, which is how one repo ended up checked out twice
# and drifting. This locks in: Tools/ by default, flat honoured only when
# it's the ONLY one present, and a loud refusal when both exist.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

pass() { printf '  ok    %s\n' "$1"; }
failed() { printf '  FAIL  %s\n' "$1"; fail=1; }

WORKSPACE="$(mktemp -d)"
export WORKSPACE
trap 'rm -rf "$WORKSPACE"' EXIT

DEVICE_SH_TEST_SOURCE=1 source "$HERE/device.sh"

# 1. Neither location exists yet — resolves to Tools/ (the default for new
#    clones of an infra/archive repo).
out="$(resolve_repo_dir infra widgets)"
[ "$out" = "$WORKSPACE/Tools/widgets" ] && pass "neither exists -> Tools/" \
  || failed "neither exists -> Tools/ (got: $out)"

# 2. Only the flat legacy path exists — honoured, not re-cloned into Tools/.
mkdir -p "$WORKSPACE/legacy/.git"
out="$(resolve_repo_dir infra legacy)"
[ "$out" = "$WORKSPACE/legacy" ] && pass "flat only -> flat (legacy honoured)" \
  || failed "flat only -> flat (got: $out)"

# 3. Only Tools/ exists — resolves there.
mkdir -p "$WORKSPACE/Tools/toolsonly/.git"
out="$(resolve_repo_dir infra toolsonly)"
[ "$out" = "$WORKSPACE/Tools/toolsonly" ] && pass "Tools/ only -> Tools/" \
  || failed "Tools/ only -> Tools/ (got: $out)"

# 4. BOTH exist — refuse loudly, naming both paths, rather than silently
#    preferring the flat one.
mkdir -p "$WORKSPACE/both/.git" "$WORKSPACE/Tools/both/.git"
out="$(resolve_repo_dir infra both)"
rc=$?
if [ "$rc" -ne 0 ] \
  && case "$out" in *"$WORKSPACE/both"*"$WORKSPACE/Tools/both"*) true ;; *) false ;; esac; then
  pass "both exist -> refuses, names both paths"
else
  failed "both exist -> refuses, names both paths (rc=$rc out='$out')"
fi

# 5. product/dotfiles roles always resolve flat, even if a Tools/ copy exists
#    (product repos are never grouped under Tools/).
mkdir -p "$WORKSPACE/Tools/MuscleBuddy/.git"
out="$(resolve_repo_dir product MuscleBuddy)"
[ "$out" = "$WORKSPACE/MuscleBuddy" ] && pass "product role -> always flat" \
  || failed "product role -> always flat (got: $out)"

if [ "$fail" -eq 0 ]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$fail"
