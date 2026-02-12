#!/usr/bin/env bash
# Module: test/mock
# Version: 0.1.0
# Requires: (none)
# Provides: stdlib::mock::command, ::restore, ::fixture, ::cleanup
# Description: Command mocking and temporary fixture management for testing.

[[ -n "${_STDLIB_LOADED_TEST_MOCK:-}" ]] && return 0
readonly _STDLIB_LOADED_TEST_MOCK=1
readonly _STDLIB_MOD_VERSION="0.1.0"

# Internal registries
declare -gA _STDLIB_MOCK_ORIGINALS=()   # [cmd]=original_path
declare -g  _STDLIB_MOCK_DIR=""          # temp dir for mock scripts
declare -ga _STDLIB_MOCK_FIXTURES=()     # temp fixture paths

_stdlib_mock_ensure_dir() {
  if [[ -z "$_STDLIB_MOCK_DIR" ]]; then
    _STDLIB_MOCK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stdlib-mock.XXXXXXXXXX")"
  fi
}

# ---------- stdlib::mock::command --------------------------------------------
# Replace a command with a mock that outputs the given string and exits 0.
# Usage: stdlib::mock::command curl '{"status":"ok"}' [exit_code]
stdlib::mock::command() {
  local cmd="${1:?command name required}"
  local output="${2:-}"
  local exit_code="${3:-0}"

  _stdlib_mock_ensure_dir

  # Save original if not already saved
  if [[ -z "${_STDLIB_MOCK_ORIGINALS[$cmd]:-}" ]]; then
    _STDLIB_MOCK_ORIGINALS["$cmd"]="$(command -v "$cmd" 2>/dev/null || echo __none__)"
  fi

  # Create mock script
  local mock_path="${_STDLIB_MOCK_DIR}/${cmd}"
  cat > "$mock_path" <<MOCK_EOF
#!/usr/bin/env bash
printf '%s\n' $(printf '%q' "$output")
exit $exit_code
MOCK_EOF
  chmod +x "$mock_path"

  # Prepend mock dir to PATH
  case ":$PATH:" in
    *:"${_STDLIB_MOCK_DIR}":*) ;; # already in path
    *) export PATH="${_STDLIB_MOCK_DIR}:${PATH}" ;;
  esac
}

# ---------- stdlib::mock::restore --------------------------------------------
# Restore a previously mocked command.
stdlib::mock::restore() {
  local cmd="${1:?command name required}"
  local mock_path="${_STDLIB_MOCK_DIR}/${cmd}"
  [[ -f "$mock_path" ]] && rm -f "$mock_path"
  unset '_STDLIB_MOCK_ORIGINALS[$cmd]'
}

# ---------- stdlib::mock::fixture --------------------------------------------
# Create a temporary fixture file with given content. Prints path to stdout.
# Usage: path=$(stdlib::mock::fixture "file.txt" "content here")
stdlib::mock::fixture() {
  local name="${1:?fixture name required}" content="${2:-}"
  _stdlib_mock_ensure_dir
  local fpath="${_STDLIB_MOCK_DIR}/fixtures/${name}"
  mkdir -p "$(dirname "$fpath")"
  printf '%s' "$content" > "$fpath"
  _STDLIB_MOCK_FIXTURES+=("$fpath")
  printf '%s' "$fpath"
}

# ---------- stdlib::mock::cleanup --------------------------------------------
# Remove all mocks and fixtures.
stdlib::mock::cleanup() {
  if [[ -n "$_STDLIB_MOCK_DIR" && -d "$_STDLIB_MOCK_DIR" ]]; then
    rm -rf "$_STDLIB_MOCK_DIR"
  fi
  _STDLIB_MOCK_DIR=""
  _STDLIB_MOCK_ORIGINALS=()
  _STDLIB_MOCK_FIXTURES=()
  # Remove mock dir from PATH
  export PATH="${PATH//${_STDLIB_MOCK_DIR}:/}"
}
