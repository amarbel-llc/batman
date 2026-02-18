#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  export output
  BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
  TEST_TMPDIR="$(mktemp -d "${BATS_TMPDIR}/bats-wrapper-XXXXXX")"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

function bats_wrapper_runs_tests { # @test
  cat >"${TEST_TMPDIR}/truth.bats" <<'EOF'
#! /usr/bin/env bats
function truth { # @test
  true
}
EOF
  run bats --tap "${TEST_TMPDIR}/truth.bats"
  assert_success
  assert_output --partial "ok 1"
}

function bats_wrapper_denies_config_read { # @test
  # Verify sandcastle replaces $HOME/.config with empty tmpfs.
  # The inner test asserts the directory is empty or missing.
  cat >"${TEST_TMPDIR}/read_config.bats" <<'INNER'
#! /usr/bin/env bats
function config_dir_is_empty_or_missing { # @test
  if [[ -d "$HOME/.config" ]]; then
    contents="$(ls "$HOME/.config")"
    [ -z "$contents" ]
  fi
}
INNER
  run bats --tap "${TEST_TMPDIR}/read_config.bats"
  assert_success
  assert_output --partial "ok 1"
}

function bats_wrapper_allows_tmp_write { # @test
  cat >"${TEST_TMPDIR}/write_tmp.bats" <<'EOF'
#! /usr/bin/env bats
function write_tmp { # @test
  echo "test" > /tmp/bats-wrapper-test-$$
  rm -f /tmp/bats-wrapper-test-$$
}
EOF
  run bats --tap "${TEST_TMPDIR}/write_tmp.bats"
  assert_success
}
