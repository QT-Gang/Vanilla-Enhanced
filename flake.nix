{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (nixpkgs) lib;
    in
    {
      packages.${system} = import ./nix/packages { inherit pkgs; };

      lib = import ./nix/lib { inherit pkgs; };

      apps.${system} = {
        packwiz = {
          type = "app";
          program = lib.getExe pkgs.packwiz;
        };
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          act
          nbted
          nixos-container
          packwiz
        ];
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
