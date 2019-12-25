let
  fetchGitHub = repo: rev: builtins.fetchTarball "https://github.com/${repo}/archive/${rev}.tar.gz";
  nixpkgs = fetchGitHub "nixos/nixpkgs-channels" "821c7ed030bca86c8217e6d20df1f01c6474adf4";
  nixos-hardware = fetchGitHub "nixos/nixos-hardware" "5575153e2d96efc8caadfc46989b11c6e64454a4";
  pkgs = import nixpkgs {};
in
pkgs.stdenv.mkDerivation rec {
  name = "bastion-homeserver-environment";

  buildInputs = with pkgs; [
    nixops # So that we can run `nixops` commands
    figlet # So that we can display a nice banner
    wireguard-tools # So that we can generate wireguard keys
    apg # So that we can generate passwords
    arp-scan # So that we can search for homeservers
    iproute # some network introspection
    coreutils
    unixtools.column
    python3
    bashInteractive
    git
    findutils
    jq
    qrencode
  ];

  shellHook = ''
    export NIX_PATH="nixpkgs=${nixpkgs}:nixos-hardware=${nixos-hardware}"
    export NIXOPS_DEPLOYMENT=homeserver
    export PATH="''${PWD}/bin:''${PATH}"
    # ssh-agent and nixops don't play well together (see
    # https://github.com/NixOS/nixops/issues/256). I'm getting `Received disconnect
    # from 10.1.1.200 port 22:2: Too many authentication failures` if I have a few
    # keys already added to my ssh-agent.
    unset SSH_AUTH_SOCK
    figlet "Bastion Homeserver"
    find bin -type f -exec chmod +x {} \;
  '';
}
