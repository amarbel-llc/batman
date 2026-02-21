{
  description = "BATS testing skill plugin with bundled assertion libraries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/6d41bc27aaf7b6a3ba6b169db3bd5d6159cfaa47";
    nixpkgs-master.url = "github:NixOS/nixpkgs/5b7e21f22978c4b740b3907f3251b470f466a9a2";
    utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102";
    shell.url = "github:friedenberg/eng?dir=devenvs/shell";
    purse-first = {
      url = "github:amarbel-llc/purse-first";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-master.follows = "nixpkgs-master";
    };
    sandcastle = {
      url = "github:amarbel-llc/sandcastle";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-master.follows = "nixpkgs-master";
      inputs.utils.follows = "utils";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-master,
      utils,
      shell,
      purse-first,
      sandcastle,
    }:
    utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        bats-support = pkgs.stdenvNoCC.mkDerivation {
          pname = "bats-support";
          version = "0.3.0";
          src = ./lib/bats-support;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/share/bats/bats-support/src
            cp load.bash $out/share/bats/bats-support/
            cp src/*.bash $out/share/bats/bats-support/src/
          '';
        };

        bats-assert = pkgs.stdenvNoCC.mkDerivation {
          pname = "bats-assert";
          version = "2.1.0";
          src = ./lib/bats-assert;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/share/bats/bats-assert/src
            cp load.bash $out/share/bats/bats-assert/
            cp src/*.bash $out/share/bats/bats-assert/src/
          '';
        };

        bats-assert-additions = pkgs.stdenvNoCC.mkDerivation {
          pname = "bats-assert-additions";
          version = "0.1.0";
          src = ./lib/bats-assert-additions;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/share/bats/bats-assert-additions/src
            cp load.bash $out/share/bats/bats-assert-additions/
            cp src/*.bash $out/share/bats/bats-assert-additions/src/
          '';
        };

        tap-writer = pkgs.stdenvNoCC.mkDerivation {
          pname = "tap-writer";
          version = "0.1.0";
          src = ./lib/tap-writer;
          dontBuild = true;
          installPhase = ''
            mkdir -p $out/share/bats/tap-writer/src
            cp load.bash $out/share/bats/tap-writer/
            cp src/*.bash $out/share/bats/tap-writer/src/
          '';
        };

        bats-libs = pkgs.symlinkJoin {
          name = "bats-libs";
          paths = [
            bats-support
            bats-assert
            bats-assert-additions
            tap-writer
          ];
          postBuild = ''
            mkdir -p $out/nix-support
            echo 'export BATS_LIB_PATH="'"$out"'/share/bats''${BATS_LIB_PATH:+:$BATS_LIB_PATH}"' > $out/nix-support/setup-hook
          '';
        };

        sandcastle-pkg = sandcastle.packages.${system}.default;

        bats = pkgs.writeShellApplication {
          name = "bats";
          runtimeInputs = [
            pkgs.bats
            sandcastle-pkg
          ];
          text = ''
            config="$(mktemp)"
            trap 'rm -f "$config"' EXIT

            cat >"$config" <<SANDCASTLE_CONFIG
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
            SANDCASTLE_CONFIG

            exec sandcastle --shell bash --config "$config" bats "$@"
          '';
        };

        robin = pkgs.stdenvNoCC.mkDerivation {
          pname = "robin";
          version = "0.1.0";
          src = ./.;
          dontBuild = true;

          nativeBuildInputs = [
            purse-first.packages.${system}.purse-first
          ];

          installPhase = ''
            mkdir -p $out/share/purse-first/robin/skills
            cp -r skills/* $out/share/purse-first/robin/skills/

            staging=$(mktemp -d)
            ln -s $out/share/purse-first/robin/skills $staging/skills
            mkdir -p $staging/.claude-plugin
            cp .claude-plugin/plugin.json $staging/.claude-plugin/plugin.json
            chmod u+w $staging/.claude-plugin/plugin.json
            purse-first generate-local-plugin --root $staging
            cp $staging/.claude-plugin/plugin.json $out/share/purse-first/robin/plugin.json
          '';
        };
      in
      {
        packages = {
          default = pkgs.symlinkJoin {
            name = "batman";
            paths = [
              bats-libs
              bats
              robin
            ];
          };
          inherit
            bats-support
            bats-assert
            bats-assert-additions
            tap-writer
            bats-libs
            bats
            robin
            ;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.just
            pkgs.gum
            bats-libs
            bats
          ];

          inputsFrom = [
            shell.devShells.${system}.default
          ];

          shellHook = ''
            echo "batman - dev environment"
          '';
        };
      }
    );
}
