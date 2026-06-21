{
  inputs,
  self,
  system,
}:

{
  config,
  pkgs,
  lib,
  ...
}:

let
  rconPassword = "minecraft";
  rconPort = 25575;
  mconsole = pkgs.writeScriptBin "mconsole" ''
    ${pkgs.rlwrap}/bin/rlwrap ${self.packages.${system}.mcrcon}/bin/mcrcon -p '${rconPassword}'
  '';

  inherit (inputs.nix-minecraft.lib) collectFiles;
  modpack = self.lib.packwiz2nix { src = self; };
  mcVersion = modpack.passthru.versions.minecraft;
  fabricVersion = modpack.passthru.versions.fabric;
  serverVersion = lib.replaceStrings [ "." ] [ "_" ] "fabric-${mcVersion}";

  minecraft-server-name = "vanillaqt";
  minecraft-server-service-name = "minecraft-server-${minecraft-server-name}";
  minecraft-server-service = config.systemd.services.${minecraft-server-service-name};
  minecraft-server-workdir = minecraft-server-service.serviceConfig.WorkingDirectory;
  minecraft-server-stdin-sock = config.services.minecraft-servers.managementSystem.systemd-socket.stdinSocket.path minecraft-server-name;

  hostname = "minecraft.mathiassven.com";

  cfg = config.${minecraft-server-name};
  inherit (lib) mkIf mkEnableOption;
in

{
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];

  options.${minecraft-server-name} = {
    dev = mkEnableOption "development mode";
  };

  config = {
    nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

    services.minecraft-servers = {
      enable = true;
      eula = true;
      openFirewall = true;
      openRcon = false;
      dataDir = "/srv/minecraft";
      runDir = "/run/minecraft";
      user = "minecraft";
      group = "minecraft";
      managementSystem.systemd-socket.enable = true;

      servers.${minecraft-server-name} = {
        enable = true;
        autoStart = true;
        enableReload = true;
        jvmOpts = builtins.concatStringsSep " " [
          "-Xms4G -Xmx7G"
          "-XX:+UseZGC -XX:+DisableExplicitGC -XX:+AlwaysPreTouch"
        ];
        # fastback requires git in the PATH
        path = [
          pkgs.git
          pkgs.git-lfs
        ];

        serverProperties = {
          difficulty = 2; # Normal
          gamemode = 0; # Survival
          max-players = 20;
          motd = "QT Gang Minecraft Server";
          online-mode = true;
          enforce-secure-profile = false;
          view-distance = 10;
          simulation-distance = 10;
          enable-rcon = true;
          "rcon.password" = rconPassword;
          "rcon.port" = rconPort;
        };

        package = pkgs.fabricServers.${serverVersion}.override {
          loaderVersion = fabricVersion;
          jre_headless = pkgs.openjdk25;
        };

        # symlinks will break mods/luckperms directory
        files = collectFiles modpack;
      };
    };
    environment.systemPackages = [
      mconsole
      pkgs.mcaselector
    ];

    assertions = [
      {
        assertion = !(lib.elem rconPort config.networking.firewall.allowedTCPPorts);
        message = "RCON Port (${rconPort}) must not be exposed";
      }
    ];

    systemd.services =
      let
        waitForMinecraftScript = ''
          echo "Waiting for Minecraft readiness"
          until grep -q "Done (" "${minecraft-server-workdir}/logs/latest.log"; do
            sleep 2
          done
          echo "Minecraft ready"
        '';

        writeToServerConsoleScript = commands: ''
          while IFS= read -r line; do
              printf '%s\n' "$line" > ${minecraft-server-stdin-sock}
              sleep 0.5
          done <<'EOF'
          ${lib.concatStringsSep "\n" commands}
          EOF
        '';
      in
      {
        "${minecraft-server-name}-init" = {
          after = [ "${minecraft-server-service-name}.service" ];
          requires = [ "${minecraft-server-service-name}.service" ];

          unitConfig.ConditionPathExists = "!${minecraft-server-workdir}/.initialized";

          serviceConfig.Type = "oneshot";

          script = ''
            ${waitForMinecraftScript}

            echo "DistantHorizons.*" > "${minecraft-server-workdir}/world/dimensions/.gitignore"

            ${writeToServerConsoleScript [
              "/execute in minecraft:overworld run worldborder set 16384"
              "/execute in minecraft:the_nether run worldborder set 2048"
              "/execute in minecraft:the_end run worldborder set 13824"
              "/setglobalmaxinvites 5"
              "/invite 904aa817-1d9c-4f44-9921-2df2d63db697"
              "/lp import defaultperms --replace"
              "/lp user 904aa817-1d9c-4f44-9921-2df2d63db697 parent set admin"
              "/backup init"
              "/backup set broadcast-enabled true"
              "/backup set mods-backup-enabled false"
              "/backup set retention-policy fixed 5"
              "/backup set autoback-wait 360"
              "/backup set shutdown-action full-gc"
              "/backup set restore-directory fastback_restore"
              "/gamerule playersSleepingPercentage 50"
            ]}

            touch "${minecraft-server-workdir}/.initialized";
          '';

          wantedBy = [ "multi-user.target" ];
        };

        "${minecraft-server-name}-post-start" = {
          after = [ "${minecraft-server-service-name}.service" ];
          requires = [ "${minecraft-server-service-name}.service" ];

          serviceConfig.Type = "oneshot";

          path = [
            pkgs.python313Packages.nbtlib
            pkgs.yq-go
          ];
          serviceConfig.WorkingDirectory = minecraft-server-workdir;

          script = ''
            ${waitForMinecraftScript}

            readarray -t spawn < <(nbt -r ./world/level.dat --path "Data.spawn.pos[]")
            export spawn_x="''${spawn[0]}"
            export spawn_z="''${spawn[2]}"
            echo "World Spawn: ''${spawn[@]}"

            yq -i '
              .["start-pos"].x = (env(spawn_x) | tonumber) |
              .["start-pos"].z = (env(spawn_z) | tonumber)
            ' ./config/bluemap/maps/world.conf
          '';

          wantedBy = [ "multi-user.target" ];
        };
      };

    # required for nginx to have access to the webroot
    users.users.nginx.extraGroups = [ "minecraft" ];

    services.nginx = {
      enable = mkIf cfg.dev true;
      virtualHosts.${if cfg.dev then hostname else "localhost"} = {
        enableACME = !cfg.dev;
        forceSSL = !cfg.dev;
        root = "${minecraft-server-workdir}/bluemap/web";

        locations."@empty".return = 204;

        extraConfig = ''
          location /maps/ {
            gzip_static always;
            location ~* ^/maps/[^/]*/tiles/ {
              error_page 404 = @empty;
            }
          }
          location ~* ^/maps/[^/]*/live/ {
            proxy_pass http://127.0.0.1:8100;
          }
        '';
      };
    };
  };
}
