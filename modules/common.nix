# Shared across every host. Host-specific files should NOT repeat any of
# this — just import it and layer on top.
{ config, pkgs, lib, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    # Auto-GC mid-build once free space drops below 2G — matters a lot on
    # the sdcard-store hosts, which tend to be small/slow cards.
    min-free = 2 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
  nix.gc = {
    automatic = true;
    dates = "*-*-* 04:00:00";
    options = "--delete-older-than 2d";
  };
  nixpkgs.config = {
    allowUnfree = true;
    # 26.05 replaced the blanket allowBroken toggle with per-package
    # handlers. "warn" evaluates the package but prints a warning;
    # "ignore" is silent. Add an entry here whenever a broken-package
    # error names one — the attribute is the pname the error printed
    # (e.g. "dataset"), not the derivation's full store name.
    problems.handlers = {
      dataset.broken = "warn"; # pulled in transitively by androguard on hub
    };
  };

  networking.networkmanager.enable = lib.mkDefault true;
  networking.firewall.enable = true;

  # SSH is off by default — hosts that need headless/remote access
  # (frp, forensics, ios) turn it on explicitly and set their own
  # authorizedKeys. Never enabled with password auth anywhere.
  services.openssh = {
    enable = lib.mkDefault false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.mutableUsers = false;

  environment.systemPackages = with pkgs; [
    git curl wget tree htop ripgrep fd jq unzip
  ];

  environment.interactiveShellInit = ''
    alias rebuild="sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)"
    alias update="sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)"
    alias gc="sudo nix-collect-garbage -d && nix-collect-garbage -d"
    alias logs="journalctl -p 3 -xb"
  '';

  system.stateVersion = "25.05";
}
