{ pkgs }:

pkgs.mcrcon.overrideAttrs (_: {
  version = "unstable";
  src = pkgs.fetchFromGitHub {
    owner = "Tiiffi";
    repo = "mcrcon";
    rev = "2cd2fa66f6f55e1ec30a0515947f5ca6d2a5d3e3";
    sha256 = "sha256-txxv8lbwPDuZ0aclVdZKHYtMRjkZv6Apk2Lzo8J3eK0=";
  };
})
