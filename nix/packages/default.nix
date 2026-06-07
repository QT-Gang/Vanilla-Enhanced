{ pkgs }:

pkgs.lib.makeScope pkgs.newScope (
  self: with self; {
    nbted = callPackage ./nbted { };
    packwiz-installer-bootstrap = callPackage ./packwiz-installer-bootstrap { };
    mk-prismpack = callPackage ./mk-prismpack { };
  }
)
