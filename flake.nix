{
  description = "Koka playground";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
      in
      {
        packages = rec {
          koka = pkgs.callPackage ./koka.nix { };
          default = koka;
        };

        devShells.default =
          with pkgs;
          mkShell {
            packages = [
              inputs.self.packages.${system}.koka
              vhs
              # VHS starts `bash` from PATH; the default one lacks readline and prints prompt escapes literally
              bashInteractive
            ];

            benchmark = writeShellScriptBin "bench" ''
              koka -O2 -isrc -c src/main.kk -o .koka/sudoku
              chmod +x .koka/sudoku
              hyperfine --warmup 1 --runs 5 .koka/sudoku
            '';

          };
      }
    );
}
