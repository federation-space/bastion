{ wgTransporterPeers, wgSubspaceIP, wgSubspacePort, targetHost, homeDomain, ... } : {
  network.description = "Bastion Homeserver";

  homeserver =
    { config, pkgs, lib, ... }:
    {
      deployment = {
        targetHost = targetHost;
        keys = {
          wg-subspace = {
            keyFile = secrets/wg-subspace;
            user = "root";
            group = "root";
            permissions = "0400";
          };
          wg-transporter = {
            keyFile = secrets/wg-transporter;
            user = "root";
            group = "root";
            permissions = "0400";
          };
          gitea-dbpassword = {
            keyFile = secrets/gitea-dbpassword;
            user = config.services.gitea.user;
            group = config.users.users.${config.services.gitea.user}.group;
            permissions = "0400";
          };
        };
      };

      # networking.wireguard.interfaces = {
      #   wg-subspace = {
      #     ips = [ wgSubspaceIP ];
      #   };
      #   wg-transporter = {
      #     peers = wgTransporterPeers;
      #     listenPort = wgSubspacePort;
      #   };
      # };
    } // (import homeserver/configuration.nix { inherit config pkgs homeDomain; });
}
