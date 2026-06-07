{ pkgs, packwiz-installer-bootstrap }:

pkgs.writers.writePython3Bin "mk-prismpack" {
  libraries = [ pkgs.python3Packages.requests ];
  flakeIgnore = [ "E501" ];
} (pkgs.replaceVars ./main.py { inherit packwiz-installer-bootstrap; })
