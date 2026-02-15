# Sandcastle Environment Isolation Reference

## Overview

Sandcastle wraps Anthropic's experimental `sandbox-runtime` project, providing filesystem and network isolation for command execution. It uses bubblewrap (bwrap) under the hood to create lightweight sandboxes without requiring root privileges.

**Source:** `github:amarbel-llc/sandcastle`

## CLI Interface

```
sandcastle [options] [command...]

Options:
  -d, --debug              Enable debug logging
  --config <path>          Path to config file (default: ~/.srt-settings.json)
  --shell <shell>          Shell to execute the command with
  --control-fd <fd>        Read config updates from file descriptor (JSON lines)
```

### Common Usage

```bash
# Run a command in sandbox with custom config
sandcastle --shell bash --config /path/to/config.json bats --tap tests.bats

# Enable debug logging for troubleshooting
sandcastle --debug --config /path/to/config.json my-command

# Pass through arguments
sandcastle --shell bash --config "$config" "$@"
```

## Configuration Format

The configuration is a JSON file with two top-level sections:

```json
{
  "filesystem": {
    "denyRead": [],
    "denyWrite": [],
    "allowWrite": []
  },
  "network": {
    "allowedDomains": [],
    "deniedDomains": []
  }
}
```

### Filesystem Section

| Field | Type | Purpose |
|-------|------|---------|
| `denyRead` | `string[]` | Paths blocked from reading |
| `denyWrite` | `string[]` | Paths blocked from writing |
| `allowWrite` | `string[]` | Paths explicitly allowed for writing |

### Network Section

| Field | Type | Purpose |
|-------|------|---------|
| `allowedDomains` | `string[]` | Domains that may be accessed (allowlist) |
| `deniedDomains` | `string[]` | Domains that are blocked (denylist) |

## Standard Security Policy for BATS Tests

The recommended deny list for integration tests:

```json
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
```

This policy:
- Blocks access to SSH keys, AWS credentials, GPG keys, and Kubernetes configs
- Blocks general config/local directories that may contain tokens or secrets
- Allows writing only to `/tmp` (where `$BATS_TEST_TMPDIR` lives)
- Leaves network unrestricted by default (empty lists = no restrictions)

## Runner Script Pattern

The standard `run-sandcastle-bats.bash` wrapper:

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

Key implementation details:
- Config is written to a temp file (expanded `$HOME` at runtime)
- Temp file is cleaned up on exit via trap
- `exec` replaces the shell process to avoid extra process overhead
- `"$@"` passes all arguments through to sandcastle

## Network-Restricted Policies

For tests that should not make network calls:

```json
{
  "filesystem": {
    "denyRead": ["$HOME/.ssh", "$HOME/.aws", "$HOME/.gnupg"],
    "denyWrite": [],
    "allowWrite": ["/tmp"]
  },
  "network": {
    "allowedDomains": ["localhost", "127.0.0.1"],
    "deniedDomains": []
  }
}
```

For tests that need specific external services:

```json
{
  "network": {
    "allowedDomains": ["api.example.com", "localhost"],
    "deniedDomains": []
  }
}
```

## Nix Integration

Add sandcastle to a flake:

```nix
{
  inputs = {
    sandcastle.url = "github:amarbel-llc/sandcastle";
  };

  outputs = { self, nixpkgs, sandcastle, ... }:
    # In devShell packages:
    sandcastle.packages.${system}.default
}
```

Sandcastle pulls in its own dependencies (bubblewrap, socat, ripgrep) via Nix.

## Troubleshooting

### Tests fail with permission denied
- Check that `allowWrite` includes `/tmp`
- Verify `$BATS_TEST_TMPDIR` is under `/tmp`
- Use `--debug` flag on sandcastle to see which paths are being denied

### Tests can't find binaries
- Ensure the binary path is not under a denied read directory
- The `$PATH` must be accessible from within the sandbox
- Nix store paths (`/nix/store/...`) are readable by default

### Slow test startup
- Sandcastle has minimal overhead per invocation
- Run it once wrapping the entire `bats` command, not per-test
- The wrapper should call `bats` as a single sandcastle invocation
