---
name: BATS Testing Setup
description: This skill should be used when the user asks to "set up BATS tests", "add integration tests", "create bats test files", "configure bats-support", "add test targets to justfile", "isolate tests with sandcastle", "write a .bats test", "set up test helpers", or mentions BATS testing, bats-assert, bats-support, sandcastle test isolation, or CLI integration testing.
version: 0.1.0
---

# BATS Testing Setup

This skill provides expert guidance for setting up BATS (Bash Automated Testing System) integration tests in Nix-backed repositories. It covers the full stack: bats-support assertion libraries, test helper infrastructure, justfile task integration, and sandcastle-based environment isolation.

## Directory Convention

Place all BATS tests in a `zz-tests_bats/` directory at the project root:

```
project/
├── zz-tests_bats/
│   ├── justfile
│   ├── common.bash
│   ├── bin/
│   │   └── run-sandcastle-bats.bash
│   ├── test_helper/
│   │   ├── bats-support/
│   │   ├── bats-assert/
│   │   └── bats-assert-additions/
│   ├── some_feature.bats
│   └── another_feature.bats
├── justfile                  (root justfile delegates to zz-tests_bats/)
└── flake.nix
```

## Test File Format

Use the function-name-based test declaration pattern with `# @test` annotation:

```bash
#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  export output
}

teardown() {
  chflags_and_rm
}

function descriptive_test_name { # @test
  run my_command arg1 arg2
  assert_success
  assert_output "expected output"
}

function another_descriptive_name { # @test
  run my_command --flag
  assert_failure
  assert_output --partial "error message"
}
```

Key conventions:
- Shebang: `#! /usr/bin/env bats`
- Test functions use `function name { # @test` (not `@test "description"`)
- Function names serve as test identifiers -- make them descriptive enough to avoid comments
- Always `export output` in setup for assertion access
- Load helpers relative to `$BATS_TEST_FILE`

## Common Test Helper (common.bash)

Create `zz-tests_bats/common.bash` to load assertion libraries and define shared utilities:

```bash
load "$BATS_CWD/test_helper/bats-support/load"
load "$BATS_CWD/test_helper/bats-assert/load"
load "$BATS_CWD/test_helper/bats-assert-additions/load"
```

Add project-specific helpers here: XDG isolation, command wrappers with default flags, fixture loaders, and cleanup functions. See `references/patterns.md` for detailed examples.

## Assertion Libraries

### Core Assertions (bats-assert)

| Function | Purpose |
|----------|---------|
| `assert_success` | Exit code is 0 |
| `assert_failure` | Exit code is non-zero |
| `assert_output "text"` | Exact match on full output |
| `assert_output --partial "text"` | Substring match |
| `assert_output --regexp "pattern"` | Regex match |
| `assert_output -` | Read expected from stdin (heredoc) |
| `refute_output "text"` | Output does NOT match |
| `assert_line "text"` | At least one line matches |
| `assert_line --index N "text"` | Specific line matches |
| `assert_equal "actual" "expected"` | String equality |

### Custom Assertions (bats-assert-additions)

All three assertion libraries are bundled in this plugin under `lib/`. Copy them into a project's `test_helper/` directory. Two additional assertion functions in bats-assert-additions extend bats-assert for common CLI testing patterns:

- **`assert_output_unsorted`** -- Sorts output before comparing. Accepts `--regexp`, `--partial`, and stdin (`-`). Essential for testing commands with non-deterministic output ordering.
- **`assert_output_cut`** -- Pipes output through `cut` before comparing. Accepts `-d` (delimiter), `-f` (fields), and `-s` (also sort). Useful for field-based output validation.

See `references/patterns.md` for usage examples.

## Nix Flake Integration

Add `bats` and `sandcastle` to the devShell in `flake.nix`:

```nix
devShells.default = pkgs.mkShell {
  packages = (with pkgs; [
    bats
    just
    gum
  ]) ++ [
    sandcastle.packages.${system}.default
  ];
};
```

For the sandcastle input, add to flake inputs:

```nix
inputs = {
  sandcastle.url = "github:amarbel-llc/sandcastle";
};
```

The bats-support, bats-assert, and bats-assert-additions libraries are bundled in this plugin's `lib/` directory. Copy all three into the project's `test_helper/` when setting up.

## Sandcastle Environment Isolation

Wrap BATS execution with sandcastle to prevent tests from accessing sensitive user data or writing outside `/tmp`. Create `zz-tests_bats/bin/run-sandcastle-bats.bash`:

```bash
#!/usr/bin/env bash
set -e

srt_config="$(mktemp)"
trap 'rm -f "$srt_config"' EXIT

cat >"$srt_config" <<SETTINGS
{
  "filesystem": {
    "denyRead": [
      "$HOME/.ssh",
      "$HOME/.aws",
      "$HOME/.gnupg",
      "$HOME/.config",
      "$HOME/.local",
      "$HOME/.password-store",
      "$HOME/.kube"
    ],
    "denyWrite": [],
    "allowWrite": [
      "/tmp"
    ]
  },
  "network": {
    "allowedDomains": [],
    "deniedDomains": []
  }
}
SETTINGS

exec sandcastle \
  --shell bash \
  --config "$srt_config" \
  "$@"
```

Mark it executable. Sandcastle uses bubblewrap under the hood to enforce filesystem and network restrictions. See `references/sandcastle.md` for configuration details.

## Justfile Integration

### Root justfile

Delegate test orchestration from the project root:

```makefile
test-bats: build test-bats-run

test-bats-run $PATH=(dir_build / "debug" + ":" + env("PATH")):
  just zz-tests_bats/test

test: test-go test-bats
```

### Test-suite justfile (zz-tests_bats/justfile)

```makefile
export CMD_BIN := "my-command"

bats_timeout := "5"

test-targets *targets="*.bats":
  BATS_TEST_TIMEOUT="{{bats_timeout}}" ./bin/run-sandcastle-bats.bash \
    bats --tap --jobs {{num_cpus()}} {{targets}}

test-tags *tags:
  BATS_TEST_TIMEOUT="{{bats_timeout}}" ./bin/run-sandcastle-bats.bash \
    bats --tap --jobs {{num_cpus()}} --filter-tags {{tags}} *.bats

test: (test-targets "*.bats")
```

Key patterns:
- TAP output via `--tap` for CI/pipeline compatibility
- Parallel execution via `--jobs {{num_cpus()}}`
- Per-test timeout via `BATS_TEST_TIMEOUT`
- Tag-based filtering via `--filter-tags`
- All execution routed through sandcastle wrapper

## Setup Checklist

When setting up BATS in a new repo:

1. Create `zz-tests_bats/` directory structure
2. Copy `lib/bats-support/`, `lib/bats-assert/`, and `lib/bats-assert-additions/` from this plugin into `test_helper/`
4. Create `common.bash` loading the assertion libraries
5. Create `bin/run-sandcastle-bats.bash` with appropriate filesystem deny lists
6. Add test justfile with `test-targets`, `test-tags`, and `test` recipes
7. Wire root justfile to delegate to `zz-tests_bats/test`
8. Add `bats`, `just`, and `sandcastle` to `flake.nix` devShell
9. Create first `.bats` test file following the function-name pattern

## Additional Resources

### Bundled Libraries

All three libraries live in `lib/` and should be copied into a project's `test_helper/`:
- **`lib/bats-support/`** -- Core support library (output formatting, error helpers, lang utilities)
- **`lib/bats-assert/`** -- Standard assertion library (assert_success, assert_output, assert_line, etc.)
- **`lib/bats-assert-additions/`** -- Custom assertions (assert_output_unsorted, assert_output_cut)

### Reference Files

For detailed patterns and advanced techniques, consult:
- **`references/patterns.md`** -- Common helper patterns, custom assertions, fixture management, XDG isolation, command wrappers, server testing
- **`references/sandcastle.md`** -- Sandcastle configuration format, security policies, network restrictions, advanced isolation patterns

### Example Files

Working templates in `examples/`:
- **`examples/common.bash`** -- Starter common.bash with XDG isolation and cleanup
- **`examples/run-sandcastle-bats.bash`** -- Sandcastle wrapper script template
- **`examples/example.bats`** -- Annotated example test file
- **`examples/justfile`** -- Test-suite justfile template
