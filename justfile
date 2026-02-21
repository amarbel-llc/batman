
default: build

build: build-nix

build-nix:
  nix build

check:
    nix develop --command shellcheck lib/*/load.bash lib/*/src/*.bash

fmt:
  nix develop --command shfmt -w -i 2 -ci lib/*/load.bash lib/*/src/*.bash

clean:
  rm -rf result

update: update-nix

update-nix:
  nix flake update
