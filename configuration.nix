{ config, pkgs, ... }:

{
  imports =
    [ <nixos-hardware/pcengines/apu>
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./personalizations.nix
    ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "bastion"; # Define your hostname.

  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.enp2s0.useDHCP = true;
  networking.interfaces.enp3s0.useDHCP = true;

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

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ config.services.thelounge.port ];
    allowedUDPPorts = [ config.networking.wireguard.interfaces.wg-transporter.listenPort ];
  };

  networking.wireguard.interfaces = {
    # Connection to the federation
    wg-subspace = {
      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/etc/nixos/keys/wg-subspace.private";

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
    # Transport your devices together into your transporter room
    wg-transporter = {
      ips = [ "10.42.0.1/24" ];

      # The port that Wireguard listens to. Must be accessible by the client.
      listenPort = 51820;

      privateKeyFile = "/etc/nixos/keys/wg-transporter.private";
    };
  };

  services.znc = {
    enable = true;
    mutable = false;
    useLegacyConfig = false;
    openFirewall = true;
    modulePackages = [ pkgs.zncModules.palaver pkgs.zncModules.playback ];
    config = {
      Listener.l = {
        AllowIRC = true;
        AllowWeb = false;
        Port = 6697;
        SSL = true;
      };
      LoadModule = [ "adminlog" "palaver" "playback" ]; # Write access logs to ~znc/moddata/adminlog/znc.log. 
      User.satoshi = {
        Admin = true;
        Pass.password = {
          Method = "sha256";
          Hash = "c572c4c4ccd5b39294acf759a566c11563f994e66c82bd4bba11e25a52c2c193";
          Salt = "hUG3/o,/6obZ:a+.PZTD";
        };
        Network.freenode = {
          Chan = { "#nixos" = {}; "#nixos-wiki" = {}; };
          LoadModule = [ "nickserv" ];
          JoinDelay = 2; # Avoid joining channels before authenticating.
        };
        extraConfig = [
          "AutoClearChanBuffer = false"
          "AutoClearQueryBuffer = false"
        ];
      };
    };
  };

  services.thelounge = {
    enable = true;
    extraConfig = {
      public = false;
      maxHistory = -1;
      defaults = {
        name = "ZNC Freenode";
        host = "localhost";
        port = 6697;
        tls = true;
        rejectUnauthorized = false;
        username = "satoshi/freenode";
      };
    };
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

