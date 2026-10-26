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

        devShells.default = pkgs.mkShell {
          packages = [ inputs.self.packages.${system}.koka ];
        };
      }
    );
}
