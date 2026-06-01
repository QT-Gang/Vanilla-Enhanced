{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage {
  pname = "nbted";
  version = "unstable";

  src = fetchFromGitHub {
    owner = "C4K3";
    repo = "nbted";
    rev = "8ae6d084fcc7b3068f2e26ca5fe5b8a813ffc029";
    hash = "sha256-ZtuYcNOVs13gTXnPBwzIQ9/TE5thSqIlmkYxBSmdMwA=";
  };

  cargoHash = "sha256-IMF5vc9p/+M/gMrUxOE3eojdATfera5dD62kcJEpzd8=";
  
  meta = {
    description = "Command-line NBT editor";
    homepage = "https://github.com/C4K3/nbted";
    license = lib.licenses.cc0;
    mainProgram = "nbted";
  };
}
