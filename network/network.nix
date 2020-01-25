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
          nextcloud-adminpass = {
            keyFile = secrets/nextcloud-adminpass;
            user = "nextcloud";
            group = "nginx";
            permissions = "0400";
          };
        };
      };
    } // (import homeserver/configuration.nix { inherit config pkgs wgTransporterPeers wgSubspaceIP wgSubspacePort homeDomain; });
}
