{
  network.description = "Bastion Homeserver";

  homeserver =
    { config, pkgs, ... }:
    {
      deployment = {
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
        };
      };
    } // (import homeserver/configuration.nix { inherit config pkgs; });
}
