---
name: BATS Testing Setup
description: This skill should be used when the user asks to "set up BATS tests", "add integration tests", "create bats test files", "configure bats-support", "add test targets to justfile", "isolate tests with sandcastle", "write a .bats test", "set up test helpers", "add CLI tests", "add functional tests", "test my CLI tool", "set up bats-core", or mentions BATS testing, bats-core, bats-assert, bats-support, sandcastle test isolation, CLI integration testing, CLI testing, or functional testing.
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
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-assert-additions
```

The `bats_load_library` function searches `BATS_LIB_PATH` for each library. This is set automatically when `batman.packages.${system}.default` is in your devShell packages (see Nix Flake Integration below).

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

Two additional assertion functions in bats-assert-additions extend bats-assert for common CLI testing patterns:

- **`assert_output_unsorted`** -- Sorts output before comparing. Accepts `--regexp`, `--partial`, and stdin (`-`). Essential for testing commands with non-deterministic output ordering.
- **`assert_output_cut`** -- Pipes output through `cut` before comparing. Accepts `-d` (delimiter), `-f` (fields), and `-s` (also sort). Useful for field-based output validation.

See `references/patterns.md` for usage examples.

## Nix Flake Integration

Add `batman` as a flake input, then include `batman.packages.${system}.default` in the devShell packages. The default package bundles everything: assertion libraries (`bats-libs`), a sandcastle-wrapped `bats` binary, and the `robin` skill plugin. The `bats-libs` component includes a setup hook that automatically exports `BATS_LIB_PATH`, so `bats_load_library` works without any manual environment configuration.

```nix
inputs = {
  batman.url = "github:amarbel-llc/batman";
};
```

```nix
devShells.default = pkgs.mkShell {
  packages = (with pkgs; [
    just
    gum
  ]) ++ [
    batman.packages.${system}.default
  ];
};
```

Do **not** add `pkgs.bats` separately — batman provides its own `bats` binary that wraps sandcastle for automatic environment isolation. Adding `pkgs.bats` alongside would shadow it.

With this setup, `bats_load_library bats-support`, `bats_load_library bats-assert`, and `bats_load_library bats-assert-additions` all resolve automatically via `BATS_LIB_PATH`, and every `bats` invocation is sandboxed transparently.

## Sandcastle Environment Isolation

Sandcastle and XDG isolation are complementary layers:

- **Sandcastle** catches leaks by denying access to real `$HOME/.config`, `$HOME/.ssh`, etc. It is the enforcement mechanism: if a test accidentally reads or writes outside its sandbox, sandcastle makes it fail loudly.
- **XDG isolation** (`set_xdg`) prevents leaks by redirecting `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, etc. into `$BATS_TEST_TMPDIR`. It is the prevention mechanism: tests write to the right place in the first place.

Both layers are required. Without sandcastle, XDG isolation can silently fail (e.g. `GIT_CONFIG_GLOBAL` overriding `XDG_CONFIG_HOME`). Without XDG isolation, sandcastle will block legitimate test operations that need config directories.

### Git Config Isolation

`git config --global` uses `$XDG_CONFIG_HOME/git/config` by default, but **`GIT_CONFIG_GLOBAL` takes precedence** if set. Many dotfile setups (rcm, direnv) export `GIT_CONFIG_GLOBAL` to an absolute path, which bypasses `$HOME` and `$XDG_CONFIG_HOME` redirection entirely. Always override `GIT_CONFIG_GLOBAL` alongside the XDG vars in `setup_test_home`:

```bash
setup_test_home() {
  export REAL_HOME="$HOME"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  set_xdg "$BATS_TEST_TMPDIR"
  mkdir -p "$XDG_CONFIG_HOME/git"
  export GIT_CONFIG_GLOBAL="$XDG_CONFIG_HOME/git/config"
  git config --global user.name "Test User"
  git config --global user.email "test@example.com"
  git config --global init.defaultBranch main
}
```

The `mkdir -p "$XDG_CONFIG_HOME/git"` is required because `set_xdg` creates the top-level XDG directories but git needs the `git/` subdirectory to exist before it can write config files.

Batman's packaged `bats` binary wraps sandcastle transparently — every `bats` invocation is automatically sandboxed with sensible defaults:

- **Read denied:** `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config`, `~/.local`, `~/.password-store`, `~/.kube`
- **Write allowed:** `/tmp` only
- **Network:** unrestricted

No wrapper script or manual sandcastle configuration is needed. Just run `bats` normally.

For custom sandcastle policies beyond the defaults (e.g., network restrictions, additional deny paths), you can invoke sandcastle directly. See `references/sandcastle.md` for configuration details.

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
  BATS_TEST_TIMEOUT="{{bats_timeout}}" \
    bats --tap --jobs {{num_cpus()}} {{targets}}

test-tags *tags:
  BATS_TEST_TIMEOUT="{{bats_timeout}}" \
    bats --tap --jobs {{num_cpus()}} --filter-tags {{tags}} *.bats

test: (test-targets "*.bats")
```

Key patterns:
- TAP output via `--tap` for CI/pipeline compatibility (see `references/tap14.md` for the full TAP version 14 specification)
- Parallel execution via `--jobs {{num_cpus()}}`
- Per-test timeout via `BATS_TEST_TIMEOUT`
- Tag-based filtering via `--filter-tags`
- Sandcastle isolation is automatic — batman's `bats` binary handles it

## Setup Checklist

When setting up BATS in a new repo:

1. Add `batman` flake input to `flake.nix`
2. Add `batman.packages.${system}.default` to devShell packages (do not add `pkgs.bats` separately)
3. Create `zz-tests_bats/` directory structure
4. Create `common.bash` using `bats_load_library` to load assertion libraries
5. Add test justfile with `test-targets`, `test-tags`, and `test` recipes
6. Wire root justfile to delegate to `zz-tests_bats/test`
7. Create first `.bats` test file following the function-name pattern

## Additional Resources

### Bundled Libraries

All three libraries are packaged in `bats-libs` and available via `BATS_LIB_PATH` when the flake input is added to your devShell:
- **bats-support** -- Core support library (output formatting, error helpers, lang utilities)
- **bats-assert** -- Standard assertion library (assert_success, assert_output, assert_line, etc.)
- **bats-assert-additions** -- Custom assertions (assert_output_unsorted, assert_output_cut)

### Reference Files

For detailed patterns and advanced techniques, consult:
- **`references/patterns.md`** -- Common helper patterns, custom assertions, fixture management, XDG isolation, command wrappers, server testing
- **`references/sandcastle.md`** -- Sandcastle configuration format, security policies, network restrictions, advanced isolation patterns
- **`references/tap14.md`** -- TAP version 14 specification. Load this when you need to understand, produce, or validate TAP output format (version line, plan, test points, YAML diagnostics, subtests, directives, escaping rules)

### Example Files

Working templates in `examples/`:
- **`examples/common.bash`** -- Starter common.bash with XDG isolation and cleanup
- **`examples/example.bats`** -- Annotated example test file
- **`examples/justfile`** -- Test-suite justfile template
