#!/usr/bin/env bash
#
# Tests for the binary-first install mechanics (exoharness/exo#98):
# examples/self-improving-agent/scripts/exo-bin-resolver.sh and its wiring
# into exo.sh / setup.sh.
#
# Usage: bash examples/self-improving-agent/tests/test-install-mechanics.sh

# Subshell-local env vars and dynamic source paths are intentional here.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$(dirname "$SCRIPT_DIR")"
RESOLVER="$AGENT_DIR/scripts/exo-bin-resolver.sh"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

assert_ok() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc (command: $*)"
  fi
}

assert_fail() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc (expected non-zero exit)"
  else
    PASS=$((PASS + 1))
  fi
}

new_sandbox() {
  mktemp -d
}

# ---- Syntax checks ---------------------------------------------------------

assert_ok "exo-bin-resolver.sh passes bash -n" bash -n "$RESOLVER"
assert_ok "exo.sh passes bash -n" bash -n "$AGENT_DIR/exo.sh"
assert_ok "setup.sh passes bash -n" bash -n "$AGENT_DIR/setup.sh"

# ---- EXO_PREBUILT_BIN installs a local binary into a missing target -------

sandbox="$(new_sandbox)"
fake_bin="$sandbox/fake-exo"
printf '#!/bin/sh\necho fake-exo\n' >"$fake_bin"
chmod +x "$fake_bin"
target="$sandbox/target/debug/exo"

(
  source "$RESOLVER"
  EXO_PREBUILT_BIN="$fake_bin" exo_install_prebuilt "$target" "$sandbox"
) >/dev/null 2>&1
assert_ok "EXO_PREBUILT_BIN is copied to the target path" test -x "$target"
assert_eq "installed binary is a copy, not the original" "fake-exo" "$("$target")"
rm -rf "$sandbox"

# ---- EXO_PREBUILT_URL downloads, caches, and reuses the cache -------------

sandbox="$(new_sandbox)"
fake_bin="$sandbox/hosted-exo"
printf '#!/bin/sh\necho hosted-exo\n' >"$fake_bin"
chmod +x "$fake_bin"
cache_dir="$sandbox/cache"
target="$sandbox/target/debug/exo"

(
  source "$RESOLVER"
  EXO_PREBUILT_CACHE_DIR="$cache_dir"
  EXO_PREBUILT_URL="file://$fake_bin" exo_install_prebuilt "$target" "$sandbox"
) >/dev/null 2>&1
assert_ok "EXO_PREBUILT_URL is downloaded and installed" test -x "$target"
assert_eq "downloaded binary runs" "hosted-exo" "$("$target")"
cached_count="$(find "$cache_dir" -name 'prebuilt-*' ! -name '*.source' | wc -l | tr -d ' ')"
assert_eq "exactly one cached prebuilt binary" "1" "$cached_count"

# Second install into a fresh target with no env set reuses the cache.
target2="$sandbox/target/other/exo"
(
  source "$RESOLVER"
  export EXO_PREBUILT_CACHE_DIR="$cache_dir"
  unset EXO_PREBUILT_URL EXO_PREBUILT_BIN
  exo_install_prebuilt "$target2" "$sandbox"
) >/dev/null 2>&1
assert_ok "cache is reused without env vars on a second install" test -x "$target2"
assert_eq "cache-reused binary runs" "hosted-exo" "$("$target2")"
rm -rf "$sandbox"

# ---- No prebuilt source available -> resolver fails, nothing installed ----

sandbox="$(new_sandbox)"
target="$sandbox/target/debug/exo"
(
  source "$RESOLVER"
  EXO_PREBUILT_CACHE_DIR="$sandbox/cache"
  unset EXO_PREBUILT_URL EXO_PREBUILT_BIN
  exo_install_prebuilt "$target" "$sandbox"
) >/dev/null 2>&1
assert_fail "with no source, nothing is installed" test -e "$target"

# ---- Existing target is left alone ---------------------------------------

sandbox="$(new_sandbox)"
target="$sandbox/target/debug/exo"
mkdir -p "$(dirname "$target")"
printf '#!/bin/sh\necho existing\n' >"$target"
chmod +x "$target"
fake_bin="$sandbox/fake-exo"
printf '#!/bin/sh\necho fake\n' >"$fake_bin"
chmod +x "$fake_bin"
(
  source "$RESOLVER"
  EXO_PREBUILT_BIN="$fake_bin" exo_install_prebuilt "$target" "$sandbox"
) >/dev/null 2>&1
assert_eq "existing target binary is not overwritten" "existing" "$("$target")"
rm -rf "$sandbox"

# ---- Background rebuild lifecycle ----------------------------------------

sandbox="$(new_sandbox)"
log="$sandbox/logs/build.log"
pid_file="$sandbox/run/build.pid"
(
  source "$RESOLVER"
  EXO_REBUILD_COMMAND="sleep 5"
  exo_start_background_rebuild "$sandbox" "$log" "$pid_file"
) >/dev/null 2>&1
assert_ok "background rebuild writes a pid file" test -s "$pid_file"
assert_ok "background rebuild writes its log" test -f "$log"

(
  source "$RESOLVER"
  EXO_REBUILD_COMMAND="echo should-not-run"
  exo_start_background_rebuild "$sandbox" "$log" "$pid_file"
) >"$sandbox/second.out" 2>&1
grep -q "already running" "$sandbox/second.out"
assert_ok "second rebuild while alive is skipped" test $? -eq 0

pid="$(cat "$pid_file")"
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null
rm -rf "$sandbox"

# ---- ensure_exo_bin wires the fast path in exo.sh ------------------------

sandbox="$(new_sandbox)"
mkdir -p "$sandbox/examples/self-improving-agent"
cp "$AGENT_DIR/exo.sh" "$sandbox/examples/self-improving-agent/exo.sh"
mkdir -p "$sandbox/examples/self-improving-agent/scripts"
cp "$RESOLVER" "$sandbox/examples/self-improving-agent/scripts/"
# exo.sh runs its command dispatch on source, so extract ensure_exo_bin and
# its dependencies by sourcing with COMMAND pointed at a no-op.
fake_bin="$sandbox/prebuilt-exo"
printf '#!/bin/sh\necho bootstrapped\n' >"$fake_bin"
chmod +x "$fake_bin"
fastpath="$sandbox/fastpath.out"
(
  cd "$sandbox" || exit 1
  # Stub the tail of exo.sh: run only the function definitions by sourcing up
  # to the dispatch case, then call ensure_exo_bin directly. The stub sits two
  # directories deep so exo.sh computes ROOT_DIR as the sandbox root.
  awk '/^case "\$COMMAND" in$/{exit} {print}' \
    examples/self-improving-agent/exo.sh >"$sandbox/examples/self-improving-agent/lib.sh"
  source "$sandbox/examples/self-improving-agent/lib.sh"
  export EXO_PREBUILT_BIN="$fake_bin"
  export EXO_REBUILD_COMMAND="true"
  ensure_exo_bin && echo ok
) >"$fastpath" 2>&1
assert_ok "ensure_exo_bin bootstraps from a prebuilt binary" test -x "$sandbox/target/debug/exo"
grep -q "Bootstrapped exo binary from prebuilt" "$fastpath"
assert_ok "ensure_exo_bin reports the bootstrap" test $? -eq 0
grep -q "Rebuilding exo from source in the background" "$fastpath"
assert_ok "ensure_exo_bin starts the background rebuild" test $? -eq 0
pid="$(cat "$sandbox/.exo-cache/build.pid" 2>/dev/null || true)"
[[ "$pid" =~ ^[0-9]+$ ]] && kill "$pid" 2>/dev/null
rm -rf "$sandbox"

# ---- setup.sh accepts and rejects --prebuilt ------------------------------

sandbox="$(new_sandbox)"
bash "$AGENT_DIR/setup.sh" --help 2>&1 | grep -q -- "--prebuilt"
assert_ok "setup.sh --help documents --prebuilt" test $? -eq 0
bash "$AGENT_DIR/setup.sh" --prebuilt 2>&1 | grep -q "requires a path or https URL"
assert_ok "setup.sh rejects --prebuilt without a value" test $? -eq 0
rm -rf "$sandbox"

echo
echo "install mechanics tests: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
