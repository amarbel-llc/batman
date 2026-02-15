{
  description = "BATS testing skill plugin with bundled assertion libraries";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23d72dabcb3b12469f57b37170fcbc1789bd7457";
    nixpkgs-master.url = "github:NixOS/nixpkgs/b28c4999ed71543e71552ccfd0d7e68c581ba7e9";
    utils.url = "https://flakehub.com/f/numtide/flake-utils/0.1.102";
    shell.url = "github:friedenberg/eng?dir=devenvs/shell";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-master,
      utils,
      shell,
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
        };
      in
      {
        packages = {
          default = bats-libs;
          inherit bats-support bats-assert bats-assert-additions;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            just
            gum
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
