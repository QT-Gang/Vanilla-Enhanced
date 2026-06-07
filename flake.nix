{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-minecraft.url = "github:Infinidoge/nix-minecraft/pull/221/head";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
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
        mk-prismpack = {
          type = "app";
          program = lib.getExe self.packages.${system}.mk-prismpack;
        };
      };

      devShells.${system}.default =
        let
          pythonDev = with pkgs; [
            black
            isort

            (python3.withPackages (
              python-pkgs: with python-pkgs; [
                requests
              ]
            ))
          ];
        in
        pkgs.mkShellNoCC {
          packages =
            with pkgs;
            [
              act
              attr
              nbted
              nixos-shell
              packwiz
            ]
            ++ pythonDev;
        };

      formatter.${system} = pkgs.nixfmt-tree;

      nixosModules = {
        vanillaQT = import ./nix/module.nix { inherit inputs self; };
        vm = import ./nix/vm.nix { inherit self; };
        default = self.nixosModules.vanillaQT;
      };
    };
}
