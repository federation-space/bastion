{ config, pkgs, homeDomain, ... }:
{
  imports =
    [ <nixos-hardware/pcengines/apu>
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  fileSystems."/".device = pkgs.lib.mkForce "/dev/disk/by-label/nixos";

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" "/dev/sdb" ];

  networking.hostName = "homeserver"; # Define your hostname.

  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.enp2s0.useDHCP = true;
  networking.interfaces.enp3s0.useDHCP = true;

  networking.resolvconf.enable = true;
  networking.resolvconf.dnsSingleRequest = true;

  time.timeZone = "UTC";

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wget mkpasswd git
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

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.firewall = {
    enable = true;
    allowedTCPPorts =
      [ config.services.thelounge.port
        config.services.gitea.httpPort
        config.services.bitwarden_rs.config.rocketPort
        # Samba
        139 445
        # NFSv4
        2049
        # Bitcoind
        8333
        # Restic
        8000
        # Nginx
        80 443
        # temp esplora
        8888
        # electrs
        7000 50001
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

      listenPort = 51820;

      privateKeyFile = config.deployment.keys.wg-transporter.path;
    };
  };

  # For resolving federation.space
  systemd.services.wireguard-wg-subspace = {
    after = [ "unbound.service" ];
    wants = [ "unbound.service" ];
  };


  # services.znc = {
  #   enable = false;
  #   mutable = false;
  #   useLegacyConfig = false;
  #   openFirewall = true;
  #   modulePackages = [ pkgs.zncModules.palaver pkgs.zncModules.playback ];
  #   config = {
  #     Listener.l = {
  #       Host = "0.0.0.0";
  #       AllowIRC = true;
  #       AllowWeb = false;
  #       Port = 6697;
  #       SSL = true;
  #     };
  #     LoadModule = [ "adminlog" "palaver" "playback" "log" ]; # Write access logs to ~znc/moddata/adminlog/znc.log.
  #     User.satoshi = {
  #       Admin = true;
  #       Pass.password = {
  #         Method = "sha256";
  #         Hash = "c572c4c4ccd5b39294acf759a566c11563f994e66c82bd4bba11e25a52c2c193";
  #         Salt = "hUG3/o,/6obZ:a+.PZTD";
  #       };
  #       Network.freenode = {
  #         Chan = { "#nixos" = {}; "#nixos-wiki" = {}; };
  #         LoadModule = [ "nickserv" ];
  #         JoinDelay = 2; # Avoid joining channels before authenticating.
  #       };
  #       AutoClearChanBuffer = false;
  #       AutoClearQueryBuffer = false;
  #       ChanBufferSize = -1;
  #       QueryBufferSize = -1;
  #       MaxQueryBuffers = 0;
  #     };
  #   };
  # };

  systemd.services.thelounge = {
    after = [ "unbound.service" ];
    wants = [ "unbound.service" ];
  };

  services.thelounge = {
    enable = true;
    private = true;
    extraConfig = {
      maxHistory = -1;
      reverseProxy = true;
      port = 9000;
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

  ##############
  # Data Shares
  ##############

  # Samba (macOS Time Machine)
  services = {
    samba = {
      enable = true;
      extraConfig = ''
        min protocol = SMB2
        vfs objects = catia fruit streams_xattr
        fruit:aapl = yes
        fruit:metadata = stream
        fruit:model = TimeMachine
        fruit:posix_rename = yes
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

  systemd.tmpfiles.rules = [
    "d '${config.services.samba.shares.time-machine.path}' 0755 '${config.services.samba.shares.time-machine."force user"}' '${config.users.users.${config.services.samba.shares.time-machine."force user"}.group}' - -"
    "d '/export' 0755 'nobody' '${config.users.users.nobody.group}' - -"
    "d '/data' 0755 'nobody' '${config.users.users.nobody.group}' - -"
  ];

  # NFS (Normal data share)
  fileSystems."/export/data" = {
    device = "/data";
    options = [ "bind" ];
  };

  systemd.services.rpc-statd.enable = pkgs.lib.mkForce false; # No longer needed with NFSv4

  services = {
    nfs.server = {
      enable = true;
      exports = ''
        /export         *(insecure,rw,sync,no_subtree_check,crossmnt,fsid=0,all_squash)
        /export/data    *(insecure,rw,sync,no_subtree_check,all_squash)
      '';
    };
  };

  # Restic (Linux backup server)
  services.restic.server = {
    enable = true;
    appendOnly = true;
  };

  # Gitea (Self-hosted GitHub)
  services.gitea = {
    enable = true;
    database.passwordFile = config.deployment.keys.gitea-dbpassword.path;
    domain = "git.${homeDomain}";
    rootUrl = "https://${config.services.gitea.domain}";
    extraConfig = ''
      [server]
      DISABLE_SSH = true
    '';
  };
  users.users.${config.services.gitea.user}.extraGroups = [ "keys" ];
  systemd.services.gitea = {
    after = [ "gitea-dbpassword-key.service" ];
    wants = [ "gitea-dbpassword-key.service" ];
  };

  # Unbound
  services.unbound = {
    enable = true;
    allowedAccess = [ "10.42.0.1/24" "127.0.0.1/24" ];
    interfaces = [ "10.42.0.1" "127.0.0.1" "::1" ];
    extraConfig = ''
      verbosity: 1

      do-ip6: no

      private-address: 10.0.0.0/8
      private-address: 172.16.0.0/12
      private-address: 192.168.0.0/16
      private-address: 169.254.0.0/16

      private-domain: carldong.io

      local-zone: "${homeDomain}." static

      local-data: "${config.services.gitea.domain}.  IN A 10.42.0.1"
      local-data: "restic.${homeDomain}.  IN A 10.42.0.1"
      local-data: "bitwarden.${homeDomain}.  IN A 10.42.0.1"
      local-data: "irc.${homeDomain}.  IN A 10.42.0.1"
      local-data: "${config.services.tt-rss.virtualHost}.  IN A 10.42.0.1"

      local-data: "homeserver.carldong.io.  IN A 192.168.0.42"
    '';
  };

  # Nginx
  services.nginx = {
    enable = true;

    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    clientMaxBodySize = "200M";

    virtualHosts = {
      ${config.services.gitea.domain} = {
        serverAliases = [ "gitea.carldong.io" ];
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = "http://127.0.0.1:${toString(config.services.gitea.httpPort)}/";
      };
      "restic.${homeDomain}" = {
        locations."/".proxyPass = "http://127.0.0.1:8000/";
      };
      "irc.${homeDomain}" = {
        serverAliases = [ "irc.carldong.io" ];
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString(config.services.thelounge.extraConfig.port)}/";
          proxyWebsockets = true;
        };
      };
      "bitwarden.${homeDomain}" = {
        serverAliases = [ "bitwarden.carldong.io" ];
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
      ${config.services.tt-rss.virtualHost} = {
        serverAliases = [ "rss.carldong.io" ];
        forceSSL = true;
        enableACME = true;
      };
    };
  };

  # Bitwarden (Self-hosted Password Manager)
  services.bitwarden_rs = {
    enable = true;
    config = {
      rocketPort = 8222;
      websocketEnabled = true;
      websocketPort = 3012;
      domain = "https://bitwarden.${homeDomain}";
    };
  };

  # TT-RSS
  services.tt-rss = {
    enable = true;
    selfUrlPath = "https://${config.services.tt-rss.virtualHost}";
    virtualHost = "rss.${homeDomain}";
    themePackages = [ pkgs.tt-rss-theme-feedly ];
  };

  # Bitcoin (Bitcoin Core)
  services.bitcoind = {
    enable = true;
    dbCache = 2000;
    extraConfig = ''
      server=1
      listenonion=0
      rpcauth=satoshi:8f6c93a5e35a6721c949f124d23b7959$$1b802ba3ed81d8c16b0729c233c62ddd7ddb988fe64ece067f130ba451a21d9f
      rpcbind=0.0.0.0:8332
      rpcallowip=10.42.0.0/24
      rpcallowip=127.0.0.1/8
      peerbloomfilters=1
      bind=0.0.0.0:8333
      zmqpubrawblock=tcp://0.0.0.0:28332
      zmqpubrawtx=tcp://0.0.0.0:28333
    '';
  };

  # services.nextcloud = {
    
  # };

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
