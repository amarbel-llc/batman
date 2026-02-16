bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-assert-additions

# XDG isolation: route all XDG directories into test temp dir
set_xdg() {
  loc="$(realpath "$1" 2>/dev/null)"
  export XDG_DATA_HOME="$loc/.xdg/data"
  export XDG_CONFIG_HOME="$loc/.xdg/config"
  export XDG_STATE_HOME="$loc/.xdg/state"
  export XDG_CACHE_HOME="$loc/.xdg/cache"
  export XDG_RUNTIME_HOME="$loc/.xdg/runtime"
}

# Cleanup: remove immutable flags and delete test temp dir
chflags_and_rm() {
  chflags -R nouchg "$BATS_TEST_TMPDIR" 2>/dev/null || true
  rm -rf "$BATS_TEST_TMPDIR"
}

# Command wrapper: runs the binary under test with normalized defaults
cmd_defaults=(
  # Add project-specific default flags here to normalize output
  # -print-colors=false
  # -print-time=false
)

run_cmd() {
  subcmd="$1"
  shift
  run timeout --preserve-status "2s" "$CMD_BIN" "$subcmd" ${cmd_defaults[@]} "$@"
}
