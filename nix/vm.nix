{ self }:

{ ... }:

{
  imports = [ self.nixosModules.default ];
  nixos-shell = {
    inheritPath = false;
    mounts = {
      mountHome = false;
      mountNixProfile = false;
    };
  };
  virtualisation = {
    sharedDirectories.qemu-mount = {
      source = "${builtins.getEnv "PWD"}/qemu-mount";
      target = "/srv";
    };
    # Needed for DistantHorizons' SQLite DB
    fileSystems."/srv".options = [ "cache=mmap" ];
    cores = 4;
    memorySize = 8 * 1024;
    diskSize = 5 * 1024;
    forwardPorts = [
      {
        from = "host";
        host.port = 25565;
        guest.port = 25565;
      }
    ];
  };
  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "26.05";
}
