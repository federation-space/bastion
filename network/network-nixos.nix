{
  homeserver =
    { config, pkgs, ... }:
    {
      deployment.targetHost = "192.168.0.113";
      services.znc = {
        config.User.satoshi = {
          # Definition of a network. A user can have multiple networks.
          Network.freenode = {
            # FIXME replace with your registered nick on Freenode
            Nick = "FIXME";
            # The IRC server. Prefix the port number with a '+' to enable SSL.
            # Syntax: <host> [[+]port] [password].
            # FIXME replace with the password for your nick on Freenode
            Server = "chat.freenode.net +6697 FIXME";
          };
        };
      };
      networking.wireguard.interfaces = {
        wg-subspace = {
          # FIXME replace with your assigned federation IP
          ips = [ "FIXME"];
        };
        wg-transporter = {
          # FIXME add your clients, mobile and desktop
          peers = [
            {
              publicKey = "FIXME";
              allowedIPs = [ "FIXME" ];
            }
          ];
        };
      };
    };
}
