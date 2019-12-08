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
          gitea-dbpassword = {
            keyFile = secrets/gitea-dbpassword;
            user = config.services.gitea.user;
            group = config.users.users.${config.services.gitea.user}.group;
            permissions = "0400";
          };
        };
      };
      users.users.${config.services.gitea.user}.extraGroups = [ "keys" ];
      systemd.services.gitea = {
        after = [ "gitea-dbpassword-key.service" ];
        wants = [ "gitea-dbpassword-key.service" ];
      };
    } // (import homeserver/configuration.nix { inherit config pkgs; });
}
