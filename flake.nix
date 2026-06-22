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
      packages.${system} =
        let
          scope = import ./nix/packages { inherit pkgs; };
        in
        scope.packages scope;

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
            with (pkgs // self.packages.${system});
            [
              act
              attr
              nixos-shell
              packwiz
              yq-go
              just
              openjdk25
              self.packages.${system}.nbted
              self.packages.${system}.headlessmc
            ]
            ++ pythonDev;

          PACKWIZ_INSTALLER_BOOTSTRAP_JAR = self.packages.${system}.packwiz-installer-bootstrap;

          shellHook = ''
            source ${./nix/shell/packwiz-server.bash}
            shopt -u checkjobs
          '';
        };

      formatter.${system} = pkgs.nixfmt-tree;

      nixosModules = {
        vanillaQT = import ./nix/module { inherit inputs self system; };
        vm = import ./nix/vm.nix { inherit self; };
        default = self.nixosModules.vanillaQT;
      };
    };
}
