{
  description = "BATS testing skill plugin with bundled assertion libraries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23d72dabcb3b12469f57b37170fcbc1789bd7457";
    nixpkgs-master.url = "github:NixOS/nixpkgs/b28c4999ed71543e71552ccfd0d7e68c581ba7e9";
    utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102";
    shell.url = "github:friedenberg/eng?dir=devenvs/shell";
    purse-first = {
      url = "github:amarbel-llc/purse-first";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-master.follows = "nixpkgs-master";
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

        bats-libs = pkgs.symlinkJoin {
          name = "bats-libs";
          paths = [
            bats-support
            bats-assert
            bats-assert-additions
          ];
          postBuild = ''
            mkdir -p $out/nix-support
            echo 'export BATS_LIB_PATH="'"$out"'/share/bats''${BATS_LIB_PATH:+:$BATS_LIB_PATH}"' > $out/nix-support/setup-hook
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
              robin
            ];
          };
          inherit
            bats-support
            bats-assert
            bats-assert-additions
            bats-libs
            robin
            ;
        };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.just
            pkgs.gum
            bats-libs
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
