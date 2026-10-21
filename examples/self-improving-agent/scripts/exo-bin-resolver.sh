#!/usr/bin/env bash
#
# Binary-first install mechanics for Exo (exoharness/exo#98).
#
# Exo always needs its source tree available because it edits itself, but the
# first `cargo build` from a fresh checkout takes minutes. These helpers let a
# launch bootstrap from a prebuilt binary in seconds and rebuild from source
# in the background, so the binary in target/ is eventually replaced by one
# built from the exact source on disk.
#
# Sourcing this script defines:
#
#   exo_install_prebuilt <target_bin> <cache_root>
#       If <target_bin> is missing, install a prebuilt binary into it and
#       return 0. Sources are tried in order:
#         1. $EXO_PREBUILT_BIN — a local binary path
#         2. $EXO_PREBUILT_URL — a downloadable binary (cached by URL)
#         3. any binary previously cached under <cache_root>/.exo-cache/bin
#       Returns 1 when nothing is available (caller falls back to building).
#
#   exo_start_background_rebuild <root_dir> <log_file> <pid_file> [args...]
#       Start `cargo build [args...]` in <root_dir> in the background unless
#       another background rebuild (same pid file) is still alive. Override
#       the command with $EXO_REBUILD_COMMAND for testing.
#
#   Hosted binaries are not published yet; set EXO_PREBUILT_URL (or
#   EXO_PREBUILT_BIN) to opt in until official artifacts exist.

# Compute a short, filesystem-safe cache key for a URL.
exo_prebuilt_cache_key() {
  local url="$1"
  local hash
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$url" | sha256sum | cut -c1-16)"
  else
    hash="$(printf '%s' "$url" | shasum -a 256 | cut -c1-16)"
  fi
  printf 'prebuilt-%s' "$hash"
}

exo_prebuilt_cache_dir() {
  printf '%s' "${EXO_PREBUILT_CACHE_DIR:-$1/.exo-cache/bin}"
}

# Download $1 into the cache dir $2 and print the cached path.
exo_fetch_prebuilt() {
  local url="$1"
  local cache_dir="$2"
  local path key tmp
  key="$(exo_prebuilt_cache_key "$url")"
  path="$cache_dir/$key"
  if [[ -x "$path" ]]; then
    printf '%s' "$path"
    return 0
  fi
  mkdir -p "$cache_dir" || return 1
  tmp="$path.download.$$"
  if ! curl -fsSL "$url" -o "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  chmod +x "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$path"
  printf '%s\n' "$url" >"$path.source"
  printf '%s' "$path"
}

# Print the path of a usable prebuilt binary, or return 1.
exo_resolve_prebuilt() {
  local cache_dir
  cache_dir="$(exo_prebuilt_cache_dir "$2")"

  if [[ -n "${EXO_PREBUILT_BIN:-}" ]]; then
    if [[ -f "$EXO_PREBUILT_BIN" ]]; then
      chmod +x "$EXO_PREBUILT_BIN" 2>/dev/null || true
      if [[ -x "$EXO_PREBUILT_BIN" ]]; then
        printf '%s' "$EXO_PREBUILT_BIN"
        return 0
      fi
    fi
    echo "warning: EXO_PREBUILT_BIN=$EXO_PREBUILT_BIN is not a usable binary" >&2
  fi

  if [[ -n "${EXO_PREBUILT_URL:-}" ]]; then
    local fetched
    if fetched="$(exo_fetch_prebuilt "$EXO_PREBUILT_URL" "$cache_dir")"; then
      printf '%s' "$fetched"
      return 0
    fi
    echo "warning: could not download EXO_PREBUILT_URL=$EXO_PREBUILT_URL" >&2
  fi

  # Fall back to the newest previously cached prebuilt binary.
  local newest="" entry
  for entry in "$cache_dir"/prebuilt-*; do
    [[ -f "$entry" && -x "$entry" ]] || continue
    if [[ -z "$newest" || "$entry" -nt "$newest" ]]; then
      newest="$entry"
    fi
  done
  if [[ -n "$newest" ]]; then
    printf '%s' "$newest"
    return 0
  fi
  return 1
}

# Install a prebuilt binary into $1 (when missing). Returns 1 when nothing
# was installed (binary already present or no prebuilt source available).
exo_install_prebuilt() {
  local target_bin="$1"
  local cache_root="$2"

  if [[ -e "$target_bin" ]]; then
    return 1
  fi

  local source_bin
  if ! source_bin="$(exo_resolve_prebuilt "$target_bin" "$cache_root")"; then
    return 1
  fi

  mkdir -p "$(dirname "$target_bin")" || return 1
  cp "$source_bin" "$target_bin" || return 1
  chmod +x "$target_bin" || return 1
  echo "Bootstrapped exo binary from prebuilt install: $source_bin" >&2
  return 0
}

exo_background_rebuild_running() {
  local pid_file="$3"
  local pid
  [[ -f "$pid_file" ]] || return 1
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

exo_start_background_rebuild() {
  local root_dir="$1"
  local log_file="$2"
  local pid_file="$3"
  shift 3

  if exo_background_rebuild_running "" "" "$pid_file"; then
    echo "Background source rebuild already running (pid $(cat "$pid_file"))."
    return 0
  fi

  mkdir -p "$(dirname "$log_file")" "$(dirname "$pid_file")"
  : >"$log_file"
  local command
  command="${EXO_REBUILD_COMMAND:-CARGO_TARGET_DIR=target cargo build --ignore-rust-version $*}"
  (
    cd "$root_dir" && eval "$command"
  ) >>"$log_file" 2>&1 &
  echo $! >"$pid_file"
  echo "Rebuilding exo from source in the background (pid $(cat "$pid_file"), log: $log_file)."
}
