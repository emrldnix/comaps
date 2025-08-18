{
  description = "CoMaps, a fork of Organic Maps";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ] (system: function (import nixpkgs {
        inherit system;
      }));
  in {
    packages = forAllSystems (pkgs: let
      inherit (pkgs) callPackage;
    in {
      comaps = callPackage ./. { };
    });
  };
}
