# frp: MediaTek flashing/recovery box. Text-based, own dedicated sdcard.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "frpbox";

  sdcardStore.uuid = "e104fce5-e20c-4995-a3ca-f70cc1a71734";

  users.users.frp = {
    isNormalUser = true;
    extraGroups = [ "wheel" "plugdev" "dialout" ];
    hashedPasswordFile = "/etc/nixos/secrets/frp.hash";
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... your-key-comment"
    ];
  };
  users.groups.plugdev = {};

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    nixos-rebuild-ng
    python3
    libusb1
    usbutils
    gcc
    pkg-config
    unzip
    nodejs
    android-tools
    tcpdump
    browsh
  ];
}
