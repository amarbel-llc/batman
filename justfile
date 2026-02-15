# batman

default:
    @just --list

# Check lib scripts with shellcheck
check:
    nix develop --command shellcheck lib/*/load.bash lib/*/src/*.bash

# Format lib scripts with shfmt
fmt:
    nix develop --command shfmt -w -i 2 -ci lib/*/load.bash lib/*/src/*.bash

# Clean build artifacts
clean:
    rm -rf result
