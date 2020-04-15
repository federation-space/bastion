{ config, pkgs, lib, wgTransporterPeers, wgSubspaceIP, wgSubspacePort, homeDomain, ... }:
{
  imports =
    [ <nixos-hardware/pcengines/apu>
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  swapDevices =
    [ { device = "/dev/disk/by-label/swap-sda2"; }
      { device = "/dev/disk/by-label/swap-sdb2"; }
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" "/dev/sdb" ];

  networking.hostName = "homeserver"; # Define your hostname.

  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;

  networking.resolvconf = {
    dnsSingleRequest = true;
    extraConfig = ''
      unbound_conf=/var/lib/unbound/unbound-resolvconf.conf
    '';
  };

  time.timeZone = "UTC";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget mkpasswd git config.services.samba.package dmidecode
    (vim_configurable.customize {
      name = "vim";
      vimrcConfig.packages.myplugins = with vimPlugins; {
        start = [ vim-nix ]; # load plugin on startup
      };
    })
  ];

  security.sudo.wheelNeedsPassword = false;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = false;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.firewall = {
    enable = true;
    allowedTCPPorts =
      [ # Samba
        139 445
        # Bitcoind
        8332 8333
        # Nginx
        80 443
      ];
    allowedUDPPorts =
      [ config.networking.wireguard.interfaces.wg-transporter.listenPort
        # Samba
        137 138
        # Unbound
        53
      ];
  };

  networking.wireguard.interfaces = {
    # homeserver <-> federation.space
    wg-subspace = {
      ips = [ wgSubspaceIP ];

      privateKeyFile = config.deployment.keys.wg-subspace.path;

      peers = [
        # For a client configuration, one peer entry for the server will suffice.
        {
          publicKey = "MLw5mB8yA+wC9E91d5grLcd6Cc98h67WzH9WHpv5D18=";
          allowedIPs = [ "fd42::1/64" ];
          endpoint = "federation.space:51820";
          persistentKeepalive = 25;
        }
      ];
    };
    # homeserver <-> your device (iOS/Linux/macOS)
    wg-transporter = {
      ips = [ "10.42.0.1/24" ];
      listenPort = wgSubspacePort;

      privateKeyFile = config.deployment.keys.wg-transporter.path;

      peers = wgTransporterPeers;
    };
  };

  # For resolving federation.space
  systemd.services.wireguard-wg-subspace = {
    after = [ "wg-subspace-key.service" "nss-lookup.target" ];
    wants = [ "wg-subspace-key.service" "nss-lookup.target" ];
    before = [
      "acme-irc.${homeDomain}.service"
      "acme-${config.services.nextcloud.hostName}.service"
      "acme-bitwarden.${homeDomain}.service"
    ];
    requiredBy = [
      "acme-irc.${homeDomain}.service"
      "acme-${config.services.nextcloud.hostName}.service"
      "acme-bitwarden.${homeDomain}.service"
    ];
  };

  systemd.services.wireguard-wg-transporter = {
    after = [ "wg-transporter-key.service" ];
    wants = [ "wg-transporter-key.service" ];
  };


  services.thelounge = {
    enable = true;
    private = true;
    extraConfig = {
      maxHistory = -1;
      reverseProxy = true;
      port = 9000;
      host = "127.0.0.1";
      defaults = {
        name = "freenode";
        host = "chat.freenode.net";
        port = 6697;
        tls = true;
        rejectUnauthorized = true;
        nick = "homeserver%%%%";
        username = "homeserver";
        join = "##homeserver-testing,#freenode,#thelounge,#wireguard";
      };
    };
  };

  systemd.services.thelounge = {
    after = [ "nss-lookup.target" "network-online.target" ];
    wants = [ "nss-lookup.target" "network-online.target" ];
  };

  ##############
  # Data Shares
  ##############

  # Samba (macOS Time Machine)
  services = {
    samba = {
      enable = true;
      extraConfig = ''
        # This setting controls the minimum protocol version that the server
        # will allow the client to use.
        min protocol = SMB2

        # Apple extensions require support for extended attributes(xattr)
        ea support = yes

        # Load in modules (order is critical!) and enable AAPL extensions
        vfs objects = catia fruit streams_xattr

        # Enable Apple's SMB2+ extension codenamed AAPL
        fruit:aapl = yes

        # Store OS X metadata by passing the stream on to the next module in the
        # VFS stack (see vfs objects)
        fruit:metadata = stream

        # Defines the model string inside the AAPL extension and will determine
        # the appearance of the icon representing the Samba server in the Finder
        # window
        fruit:model = MacSamba

        ###############
        # File cleanup
        ###############

        # Whether to enable POSIX directory rename behaviour for OS X clients.
        # Without this, directories can't be renamed if any client has any file
        # inside it (recursive!) open.
        fruit:posix_rename = yes

        # Whether to return zero to queries of on-disk file identifier, if the client has negotiated AAPL.
        fruit:zero_file_id = yes


        fruit:veto_appledouble = no

        fruit:wipe_intentionally_left_blank_rfork = yes
        fruit:delete_empty_adfiles = yes
      '';
      shares = {
        time-machine = {
          path = "/home/satoshi/time-machine";
          "valid users" = "satoshi";
          public = "no";
          writeable = "yes";
          "force user" = "satoshi";
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:time machine" = "yes";
        };
        samba = {
          path = "/data";
          "valid users" = "satoshi";
          public = "no";
          writeable = "yes";
          browseable = "yes";
          "force user" = "satoshi";
          "force group" = "users";
          "vfs objects" = "catia fruit streams_xattr";
        };
      };
    };
    # Avahi allows autodetection of services on macOS
    avahi = {
      enable = true;
      nssmdns = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };
  };

  systemd.services.samba-smbd.unitConfig = {
    RequiresMountsFor = config.services.samba.shares.time-machine.path;
  };
  systemd.services.samba-nmbd.unitConfig = {
    RequiresMountsFor = config.services.samba.shares.time-machine.path;
  };
  systemd.services.samba-winbindd.unitConfig = {
    RequiresMountsFor = config.services.samba.shares.time-machine.path;
  };

  fileSystems."${config.services.samba.shares.time-machine.path}" = {
    device = "${config.services.samba.shares.time-machine.path}.img";
    fsType = "ext4";
    options = [ "defaults" "loop" ];
  };

  systemd.tmpfiles.rules = [
    "d '${config.services.samba.shares.time-machine.path}' 0755 '${config.services.samba.shares.time-machine."force user"}' '${config.users.users.${config.services.samba.shares.time-machine."force user"}.group}' - -"
    "d '${config.services.samba.shares.samba.path}' 0755 '${config.services.samba.shares.samba."force user"}' '${config.users.users.${config.services.samba.shares.samba."force user"}.group}' - -"
  ];

  # Restic (Linux backup server)
  services.restic.server = {
    enable = true;
    listenAddress = "127.0.0.1:8000";
  };

  # Nextcloud
  services.nextcloud = {
    enable = true;
    hostName = "nextcloud.${homeDomain}";
    https = true;
    nginx.enable = true;
    autoUpdateApps.enable = true;
    config = {
      adminuser = "satoshi";
      adminpassFile = config.deployment.keys.nextcloud-adminpass.path;
      overwriteProtocol = "https";
    };
    caching.apcu = true;
  };

  systemd.services.nextcloud-setup = {
    after = [ "nextcloud-adminpass-key.service" ];
    wants = [ "nextcloud-adminpass-key.service" ];
  };

  # Unbound
  services.unbound = {
    enable = true;
    allowedAccess = [ "10.42.0.1/24" "127.0.0.1/24" ];
    interfaces = [ "0.0.0.0" ];
    extraConfig = ''
      verbosity: 1

      do-ip6: no
      access-control-view: 10.42.0.1/24 "wgview"

      include: "/var/lib/unbound/unbound-resolvconf.conf"

      view:
          name: "wgview"
          local-data: "restic.${homeDomain}.  IN A 10.42.0.1"
          local-data: "bitwarden.${homeDomain}.  IN A 10.42.0.1"
          local-data: "irc.${homeDomain}.  IN A 10.42.0.1"
          local-data: "${config.services.nextcloud.hostName}.  IN A 10.42.0.1"
    '';
  };

  systemd.services.unbound = {
    after = [ "network-online.target" "resolvconf.service" ];
    wants = [ "network-online.target" ];
  };

  # Nginx
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    clientMaxBodySize = "0";

    commonHttpConfig = ''
      fastcgi_request_buffering off;
      proxy_buffering off;
    '';

    virtualHosts = {
      "restic.${homeDomain}" = {
        locations."/".proxyPass = "http://${config.services.restic.server.listenAddress}/";
      };
      "irc.${homeDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString(config.services.thelounge.extraConfig.port)}/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_read_timeout 1d;
          '';
        };
      };
      ${config.services.nextcloud.hostName} = {
        enableACME = true;
        forceSSL = true;
      };
      "bitwarden.${homeDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${toString(config.services.bitwarden_rs.config.rocketPort)}/";
          };
          "/notifications/hub" = {
            proxyPass = "http://127.0.0.1:${toString(config.services.bitwarden_rs.config.websocketPort)}/";
            proxyWebsockets = true;
          };
          "/notifications/hub/negotiate" = {
            proxyPass = "http://127.0.0.1:${toString(config.services.bitwarden_rs.config.rocketPort)}/";
          };
        };
      };
    };
  };

  # Bitwarden (Self-hosted Password Manager)
  services.bitwarden_rs = {
    enable = true;
    config = {
      rocketAddress = "127.0.0.1";
      rocketPort = 8222;
      websocketEnabled = true;
      websocketAddress = "127.0.0.1";
      websocketPort = 3012;
      domain = "https://bitwarden.${homeDomain}";
    };
  };

  # Bitcoin (Bitcoin Core)
  services.bitcoind = {
    enable = true;
    dbCache = 2000;
    extraConfig = ''
      server=1
      listenonion=0
      rpcauth=satoshi:8f6c93a5e35a6721c949f124d23b7959$$1b802ba3ed81d8c16b0729c233c62ddd7ddb988fe64ece067f130ba451a21d9f
      rpcbind=0.0.0.0
      rpcport=8332
      rpcallowip=10.42.0.0/24
      rpcallowip=127.0.0.1/8
      peerbloomfilters=1
      bind=0.0.0.0
      port=8333
      zmqpubrawblock=tcp://0.0.0.0:28332
      zmqpubrawtx=tcp://0.0.0.0:28333
    '';
  };

  systemd.services.bitcoind = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  users.users.satoshi = {
    isNormalUser = true;
    uid = 1000;
    hashedPassword = "$6$RS1BY0Tdq$WAIXkQVtbBn0rEM19yLFyqrm6696Zjmz7QVVc6P8o1OJd9MdoEDCFagJsGVILT4LHK6ne6RwVW0tR2wZJJY/C.";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.09"; # Did you read the comment?

}
