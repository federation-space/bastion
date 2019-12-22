{ wgTransporterPeers, wgSubspaceIP, targetHost, homeDomain, ... } : {
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

      networking.wireguard.interfaces = {
        wg-subspace = {
          ips = [ wgSubspaceIP ];
        };
        wg-transporter = {
          peers = wgTransporterPeers;
        };
      };
      users.users = {
        root.openssh.authorizedKeys.keys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDqzNm5npp/63xAETRNCx471svqDPjlGNRcKwU5+SkMG0s8IvuJNJ3cy7V+dink7kbZO/Jee5OxDTdOWc6jGZoc/Lhjp36TDQnfGRn9O8/N5JQOhsLKY0LS3L7i5same4A2qq+TXxl9wFuSZncG3Xvn1FgcwwYDNNNrEwMjAlVd4F9MP00n11XKexHDHEJmblBDoCnZry/UhVfwFHdeg6SZ0haa27s7b766iiLy1vqgW239VxwQPoLQBR/e5hu30449JI5cUAjNnWg9UakP/sQmHDwV/JoXRjpuhOq1tVtc1MGDxa/D7ijxXCf6J5nfvz/coeYUgADEcdsX5lJdnGRMMM4TYkEF/RdHDmhU7XlPWYn5LePjCyO5tbVhIJyfSs2PEAdW7fNBn9FDoON1Etk795xnpuxOttvpV1Q28+oMhHB0RHJoVV6deSM88lcrxPwCYN0QedHFTOO+GcaeL+NJhIYicvQQAsAAV1H6nhbhNzvsWcTAAD1PbU/iD7ACLGrZZp2rgglbIMQQq4RdwSRkpadn4w0rRivfKqBJhJ8CnTzgF86YYbsddFNfSKXqLa8r92LWWYPlvZzUdxoZwVtHDtvfmLrvZajeZf9LbHQgick78xM0kvCirMlljt46njn2Rv64kpo16002xYxZgUhkjEVpg1u2OC4Uow4uGiobsQ== cardno:000607838777"
        ];
      };
    } // (import homeserver/configuration.nix { inherit config pkgs homeDomain; });
}
