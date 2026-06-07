{ pkgs }:
rec {
  nbted = pkgs.callPackage ./nbted { };
  packwiz-installer-bootstrap = pkgs.callPackage ./packwiz-installer-bootstrap { };
  mk-prismpack = pkgs.callPackage ./mk-prismpack { inherit packwiz-installer-bootstrap; };
}
